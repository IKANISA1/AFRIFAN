-- Forward correction: renewal cannot authorize a previously granted worker.
-- Unknown Storage outcomes retain their original command and never start a
-- second upload. Existing completed receipts remain read-only recoverable.
begin;
alter table public.admin_media_uploads
 add column lease_proof_id uuid,
 add column storage_attempt_reserved_at timestamptz,
 add column storage_attempt_lease_token uuid;
alter table public.admin_media_uploads add foreign key(operation_id,lease_proof_id)
 references public.admin_media_upload_proofs(operation_id,proof_id) deferrable initially deferred;
-- Legacy uncertain leases lack a provable immutable dispatch proof. Retire
-- those leases conservatively; retain any existing object for reconciliation.
-- admitted_at is the known historical command timestamp, not a provider ACK.
update public.admin_media_uploads set
 storage_attempt_reserved_at=case when attempts>0 then admitted_at end,
 storage_attempt_lease_token=case when attempts>0 then lease_token end,
 status=case when status='uploading' then case when object_id is null then 'unknown' else 'staged' end else status end,
 lease_token=null,lease_until=null
 where status<>'completed';
alter table public.admin_media_uploads add check(lease_token is null or lease_proof_id is not null);

create or replace function public.guard_admin_media_upload_immutable() returns trigger language plpgsql set search_path='' as $$
begin
 if TG_OP='DELETE' or TG_TABLE_NAME in('admin_media_upload_proofs','admin_media_upload_releases') then raise exception 'MEDIA_COMMAND_IMMUTABLE'; end if;
 if (new.operation_id,new.actor_id,new.club_id,new.kind,new.mime_type,new.byte_length,new.content_sha256,new.bucket,new.storage_path,new.admitted_at)
  is distinct from (old.operation_id,old.actor_id,old.club_id,old.kind,old.mime_type,old.byte_length,old.content_sha256,old.bucket,old.storage_path,old.admitted_at)
  or (old.status='completed' and new is distinct from old)
  or (old.storage_attempt_reserved_at is not null and (new.storage_attempt_reserved_at,new.storage_attempt_lease_token)
    is distinct from (old.storage_attempt_reserved_at,old.storage_attempt_lease_token))
  or (old.lease_token is not null and new.lease_token=old.lease_token and new.lease_proof_id is distinct from old.lease_proof_id)
 then raise exception 'MEDIA_COMMAND_IMMUTABLE'; end if;
 return new;
end $$;

-- Caller admission locks the lifecycle actor before the original operation.
-- Service workers must take that same order before waiting on the command.
-- The retained actor is immutable; no authority/proof is inferred from this
-- early read. Current grants, session and original proof remain checked after
-- command waits. An uncommitted/unadmitted command grants no service effect.
create function public.lock_admin_media_upload_operation(p_operation_id uuid) returns void
language plpgsql security definer set search_path='' as $$ declare actor uuid; begin
 select actor_id into actor from public.admin_media_uploads where operation_id=p_operation_id;
 if not found then raise exception 'MEDIA_ADMISSION_REQUIRED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,21000));
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21027));
end $$;

create function public.assert_admin_media_upload_lease(p_upload public.admin_media_uploads) returns void
language plpgsql security definer set search_path='' as $$ declare original public.admin_media_uploads:=p_upload; begin
 if p_upload.lease_token is null or p_upload.lease_until is null or p_upload.lease_proof_id is null then
  raise exception 'MEDIA_ORIGINAL_PROOF_REQUIRED' using errcode='42501'; end if;
 original.current_proof_id:=p_upload.lease_proof_id;
 perform public.assert_admin_media_upload_proof(original);
 if p_upload.lease_until<=clock_timestamp() then raise exception 'MEDIA_LEASE_LOST' using errcode='42501'; end if;
end $$;

create or replace function public.claim_admin_media_upload(p_operation_id uuid,p_lease_token uuid) returns jsonb
language plpgsql security definer set search_path='' as $$ declare u public.admin_media_uploads; begin
 if auth.role() is distinct from 'service_role' then raise exception 'MEDIA_SERVICE_REQUIRED' using errcode='42501'; end if;
 perform public.lock_admin_media_upload_operation(p_operation_id);
 select * into u from public.admin_media_uploads where operation_id=p_operation_id for update;
 if not found then raise exception 'MEDIA_ADMISSION_REQUIRED' using errcode='42501'; end if;
 perform public.lock_admin_media_upload_actor(u.actor_id,u.club_id);
 if u.status<>'completed' then raise exception 'MEDIA_ORIGINAL_PROOF_REQUIRED' using errcode='42501'; end if;
 return public.admin_media_upload_receipt(u)||jsonb_build_object('claimed',false,'lease_token',null);
end $$;

create function public.claim_admin_media_upload(p_operation_id uuid,p_lease_token uuid,p_dispatch_proof_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$ declare u public.admin_media_uploads; original public.admin_media_uploads; begin
 if auth.role() is distinct from 'service_role' then raise exception 'MEDIA_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_lease_token is null or p_lease_token::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'MEDIA_LEASE_INVALID' using errcode='22023'; end if;
 perform public.lock_admin_media_upload_operation(p_operation_id);
 select * into u from public.admin_media_uploads where operation_id=p_operation_id for update;
 if not found then raise exception 'MEDIA_ADMISSION_REQUIRED' using errcode='42501'; end if;
 perform public.lock_admin_media_upload_actor(u.actor_id,u.club_id);
 if u.status='completed' then return public.admin_media_upload_receipt(u)||jsonb_build_object('claimed',false,'lease_token',null); end if;
 if p_dispatch_proof_id is null or not exists(select 1 from public.admin_media_upload_proofs where operation_id=p_operation_id and proof_id=p_dispatch_proof_id) then
  raise exception 'MEDIA_ORIGINAL_PROOF_REQUIRED' using errcode='42501'; end if;
 original:=u;original.current_proof_id:=p_dispatch_proof_id;
 perform public.assert_admin_media_upload_proof(original);
 if u.lease_until>clock_timestamp() then return public.admin_media_upload_receipt(u)||jsonb_build_object('claimed',false,'lease_token',null); end if;
 if u.attempts>=32 then raise exception 'MEDIA_ATTEMPT_LIMIT' using errcode='54000'; end if;
 update public.admin_media_uploads set status='uploading',lease_token=p_lease_token,lease_until=clock_timestamp()+interval '60 seconds',
  lease_proof_id=p_dispatch_proof_id,attempts=attempts+1 where operation_id=p_operation_id returning * into u;
 perform public.assert_admin_media_upload_lease(u);
 return public.admin_media_upload_receipt(u)||jsonb_build_object('claimed',true,'lease_token',p_lease_token);
end $$;

create function public.begin_admin_media_upload(p_operation_id uuid,p_lease_token uuid) returns jsonb
language plpgsql security definer set search_path='' as $$ declare u public.admin_media_uploads; permitted boolean:=false; begin
 if auth.role() is distinct from 'service_role' then raise exception 'MEDIA_SERVICE_REQUIRED' using errcode='42501'; end if;
 perform public.lock_admin_media_upload_operation(p_operation_id);
 select * into u from public.admin_media_uploads where operation_id=p_operation_id for update;
 if not found then raise exception 'MEDIA_ADMISSION_REQUIRED' using errcode='42501'; end if;
 if u.status<>'uploading' or u.lease_token is distinct from p_lease_token then raise exception 'MEDIA_LEASE_LOST' using errcode='42501'; end if;
 perform public.assert_admin_media_upload_lease(u);
 if u.storage_attempt_reserved_at is null then
  update public.admin_media_uploads set storage_attempt_reserved_at=clock_timestamp(),storage_attempt_lease_token=p_lease_token
   where operation_id=p_operation_id returning * into u;
  permitted:=true;
 end if;
 perform public.assert_admin_media_upload_lease(u);
 return jsonb_build_object('operation_id',u.operation_id,'lease_token',p_lease_token,'upload_permitted',permitted);
end $$;

create or replace function public.admit_admin_media_upload(p_operation_id uuid,p_club_id bigint,p_kind text,p_mime_type text,p_byte_length integer,p_content_sha256 text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); claims jsonb:=auth.jwt(); u public.admin_media_uploads; proof public.admin_media_upload_proofs;
 session uuid; session_end timestamptz; jwt_exp bigint; mfa_time bigint; a jsonb; ts numeric; epoch numeric; deadline timestamptz; path text;
begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then
  raise exception 'MEDIA_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_staff_step_up(); perform public.assert_account_active();
 if p_operation_id is null or p_operation_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  or p_club_id is null or p_club_id<=0 or p_kind is null or p_kind not in('shop_product','news_article','home_banner','fan_club','match','squad_player','notification')
  or p_mime_type is null or p_mime_type not in('image/png','image/jpeg','image/webp') or p_byte_length is null or p_byte_length not between 1 and 5242880
  or p_content_sha256 is null or p_content_sha256 !~ '^[0-9a-f]{64}$' then raise exception 'MEDIA_INPUT_INVALID' using errcode='22023'; end if;
 path:='club-'||p_club_id||'/admin/'||p_kind||'/'||p_operation_id||case p_mime_type when 'image/png' then '.png' when 'image/jpeg' then '.jpg' else '.webp' end;
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21027));
 if exists(select 1 from public.admin_media_upload_releases where operation_id=p_operation_id) then
  raise exception 'MEDIA_OPERATION_RELEASED' using errcode='22023'; end if;
 select * into u from public.admin_media_uploads where operation_id=p_operation_id for update;
 if found and (u.actor_id,u.club_id,u.kind,u.mime_type,u.byte_length,u.content_sha256,u.storage_path) is distinct from
  (actor,p_club_id,p_kind,p_mime_type,p_byte_length,p_content_sha256,path) then raise exception 'MEDIA_COMMAND_BINDING_MISMATCH' using errcode='22023'; end if;
 perform public.lock_admin_media_upload_actor(actor,p_club_id);
 perform public.assert_staff_step_up();
 if coalesce(claims->>'session_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
  raise exception 'MEDIA_SESSION_REQUIRED' using errcode='42501'; end if;
 session:=(claims->>'session_id')::uuid;
 select not_after into session_end from auth.sessions where id=session and user_id=actor and aal='aal2' for share;
 if not found or (session_end is not null and session_end<=clock_timestamp()) then raise exception 'MEDIA_SESSION_REVOKED' using errcode='42501'; end if;
 perform 1 from storage.buckets where id='africlub-product-images' and public and file_size_limit=5242880
  and allowed_mime_types=array['image/png','image/jpeg','image/webp']::text[] for share;
 if not found then raise exception 'MEDIA_BUCKET_UNAVAILABLE'; end if;
 if u.status='completed' then return public.admin_media_upload_receipt(u); end if;
 jwt_exp:=(claims->>'exp')::numeric::bigint; epoch:=extract(epoch from clock_timestamp());
 for a in select value from jsonb_array_elements(claims->'amr') loop
  if a->>'method' in('totp','mfa/totp') and jsonb_typeof(a->'timestamp')='number' then
   ts:=(a->>'timestamp')::numeric;
   if ts between epoch-300 and epoch+30 and abs(ts)<=9007199254740991 and mod(ts,1)=0 then mfa_time:=greatest(mfa_time,ts::bigint); end if;
  end if;
 end loop;
 if mfa_time is null then raise exception 'STAFF_STEP_UP_REQUIRED' using errcode='42501'; end if;
 deadline:=least(to_timestamp(least(jwt_exp,mfa_time+300)::double precision),coalesce(session_end,'infinity'::timestamptz));
 if deadline<=clock_timestamp() then raise exception 'MEDIA_ASSURANCE_EXPIRED' using errcode='42501'; end if;
 if u.operation_id is null then
  insert into public.admin_media_uploads(operation_id,actor_id,club_id,kind,mime_type,byte_length,content_sha256,storage_path,current_proof_id)
   values(p_operation_id,actor,p_club_id,p_kind,p_mime_type,p_byte_length,p_content_sha256,path,gen_random_uuid()) returning * into u;
 end if;
 select * into proof from public.admin_media_upload_proofs where operation_id=p_operation_id and session_id=session
  and jwt_expires_at=jwt_exp and mfa_verified_at=mfa_time;
 if not found then
  if (select count(*) from public.admin_media_upload_proofs where operation_id=p_operation_id)>=32 then raise exception 'MEDIA_PROOF_LIMIT' using errcode='54000'; end if;
  insert into public.admin_media_upload_proofs(operation_id,proof_id,session_id,jwt_expires_at,mfa_verified_at,expires_at)
   values(p_operation_id,case when not exists(select 1 from public.admin_media_upload_proofs where operation_id=p_operation_id)
    then u.current_proof_id else gen_random_uuid() end,session,jwt_exp,mfa_time,deadline) returning * into proof;
 end if;
 update public.admin_media_uploads set current_proof_id=proof.proof_id where operation_id=p_operation_id returning * into u;
 perform public.assert_staff_step_up(); perform public.assert_admin_media_upload_proof(u);
 return public.admin_media_upload_receipt(u)||jsonb_build_object('dispatch_proof_id',proof.proof_id);
end $$;
create or replace function public.release_unadmitted_admin_media_upload(p_operation_id uuid,p_club_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); claims jsonb:=auth.jwt(); released public.admin_media_upload_releases;
 session uuid; session_end timestamptz;
begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then
  raise exception 'MEDIA_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_staff_step_up(); perform public.assert_account_active();
 if p_operation_id is null or p_operation_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  or p_club_id is null or p_club_id<=0 then raise exception 'MEDIA_INPUT_INVALID' using errcode='22023'; end if;
 -- Match caller admission: lifecycle actor first, then original command.
 -- An uncertain admitted command is never aborted or remotely deleted.
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21027));
 perform public.lock_admin_media_upload_actor(actor,p_club_id);
 perform public.assert_staff_step_up();
 if coalesce(claims->>'session_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
  raise exception 'MEDIA_SESSION_REQUIRED' using errcode='42501'; end if;
 session:=(claims->>'session_id')::uuid;
 select not_after into session_end from auth.sessions where id=session and user_id=actor and aal='aal2' for share;
 if not found or (session_end is not null and session_end<=clock_timestamp()) then
  raise exception 'MEDIA_SESSION_REVOKED' using errcode='42501'; end if;
 if exists(select 1 from public.admin_media_uploads where operation_id=p_operation_id) then
  raise exception 'MEDIA_RELEASE_UNAVAILABLE' using errcode='22023'; end if;
 select * into released from public.admin_media_upload_releases where operation_id=p_operation_id;
 if found and (released.actor_id,released.club_id) is distinct from (actor,p_club_id) then
  raise exception 'MEDIA_COMMAND_BINDING_MISMATCH' using errcode='22023'; end if;
 if not found then
  insert into public.admin_media_upload_releases(operation_id,actor_id,club_id) values(p_operation_id,actor,p_club_id)
   returning * into released;
 end if;
 -- A wait during the immutable write must not silently renew human assurance.
 perform public.assert_staff_step_up();
 if session_end is not null and session_end<=clock_timestamp() then
  raise exception 'MEDIA_SESSION_REVOKED' using errcode='42501'; end if;
 return jsonb_build_object('operation_id',released.operation_id,'actor_id',released.actor_id,
  'club_id',released.club_id,'released',true);
end $$;
create or replace function public.complete_admin_media_upload(p_operation_id uuid,p_lease_token uuid,p_outcome text,p_object_id uuid,p_verified_sha256 text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u public.admin_media_uploads; o storage.objects; assured boolean:=true; leased public.admin_media_uploads;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'MEDIA_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_outcome is null or p_outcome not in('stored','unknown','failed') then raise exception 'MEDIA_OUTCOME_INVALID' using errcode='22023'; end if;
 perform public.lock_admin_media_upload_operation(p_operation_id);
 select * into u from public.admin_media_uploads where operation_id=p_operation_id for update;
 if not found then raise exception 'MEDIA_ADMISSION_REQUIRED' using errcode='42501'; end if;
 if u.status='completed' then
  perform public.lock_admin_media_upload_actor(u.actor_id,u.club_id);
  if p_outcome<>'stored' or p_object_id is distinct from u.object_id or p_verified_sha256 is distinct from u.verified_sha256 then raise exception 'MEDIA_COMMAND_BINDING_MISMATCH'; end if;
  return public.admin_media_upload_receipt(u);
 end if;
 if p_lease_token is null or u.lease_token is null or u.lease_until is null
  or u.lease_token is distinct from p_lease_token or u.lease_until<=clock_timestamp() then raise exception 'MEDIA_LEASE_LOST' using errcode='42501'; end if;
 leased:=u;
 if p_outcome='stored' then
  if p_object_id is null or p_verified_sha256 is distinct from u.content_sha256 then raise exception 'MEDIA_OBJECT_MISMATCH'; end if;
  -- No object row lock here: Storage takes its object lock before this trigger's
  -- command lock. Managed object content/identity is immutable below.
  select * into o from storage.objects where id=p_object_id and bucket_id=u.bucket and name=u.storage_path;
  if not found or o.version='1' or o.user_metadata->>'operation_id' is distinct from u.operation_id::text
   or o.user_metadata->>'content_sha256' is distinct from u.content_sha256
   or o.metadata->>'mimetype' is distinct from u.mime_type or coalesce(o.metadata->>'size',o.metadata->>'contentLength') is distinct from u.byte_length::text then
   raise exception 'MEDIA_OBJECT_MISMATCH'; end if;
  begin perform public.assert_admin_media_upload_lease(leased); exception when sqlstate '42501' then assured:=false; end;
  update public.admin_media_uploads set status=case when assured then 'completed' else 'staged' end,object_id=p_object_id,
   verified_sha256=p_verified_sha256,completed_at=case when assured then clock_timestamp() end,lease_token=null,lease_until=null,lease_proof_id=null
   where operation_id=p_operation_id returning * into u;
  if assured then perform public.assert_admin_media_upload_lease(leased); end if;
 else
  if p_object_id is not null or p_verified_sha256 is not null then raise exception 'MEDIA_OUTCOME_INVALID' using errcode='22023'; end if;
  update public.admin_media_uploads set status=case when object_id is not null then 'staged' else p_outcome end,
   lease_token=null,lease_until=null,lease_proof_id=null where operation_id=p_operation_id returning * into u;
 end if;
 return public.admin_media_upload_receipt(u);
end $$;
create or replace function public.guard_admin_media_storage_write() returns trigger
language plpgsql security definer set search_path='' as $$
declare u public.admin_media_uploads; operation uuid; token uuid; managed boolean;
begin
 managed:=new.bucket_id='africlub-product-images' and new.name ~ '^club-[1-9][0-9]*/admin/(shop_product|news_article|home_banner|fan_club|match|squad_player|notification)/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(png|jpg|webp)$';
 if TG_OP='UPDATE' then managed:=managed or (old.bucket_id='africlub-product-images' and old.name ~ '^club-[1-9][0-9]*/admin/(shop_product|news_article|home_banner|fan_club|match|squad_player|notification)/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(png|jpg|webp)$'); end if;
 if not managed then return new; end if;
 if TG_OP='UPDATE' then
  if (new.id,new.bucket_id,new.name,new.version,new.metadata,new.user_metadata,new.owner,new.owner_id)
   is distinct from (old.id,old.bucket_id,old.name,old.version,old.metadata,old.user_metadata,old.owner,old.owner_id) then raise exception 'MEDIA_OBJECT_IMMUTABLE'; end if;
  return new;
 end if;
 if auth.role() is distinct from 'service_role' or coalesce(new.user_metadata->>'operation_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  or coalesce(new.user_metadata->>'lease_token','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'MEDIA_ADMISSION_REQUIRED' using errcode='42501'; end if;
 operation:=(new.user_metadata->>'operation_id')::uuid; token:=(new.user_metadata->>'lease_token')::uuid;
 perform public.lock_admin_media_upload_operation(operation);
 select * into u from public.admin_media_uploads where operation_id=operation for update;
 if not found or new.name is distinct from u.storage_path or new.bucket_id is distinct from u.bucket
  or new.user_metadata->>'content_sha256' is distinct from u.content_sha256
  or new.metadata->>'mimetype' is distinct from u.mime_type then raise exception 'MEDIA_OBJECT_MISMATCH'; end if;
 if u.status not in('uploading','staged') or u.lease_token is distinct from token or u.lease_until<=clock_timestamp() then raise exception 'MEDIA_LEASE_LOST' using errcode='42501'; end if;
 if u.storage_attempt_reserved_at is null or u.storage_attempt_lease_token is distinct from token then
  raise exception 'MEDIA_STORAGE_ATTEMPT_REQUIRED' using errcode='42501'; end if;
 if new.version is distinct from '1' and coalesce(new.metadata->>'size',new.metadata->>'contentLength') is distinct from u.byte_length::text then raise exception 'MEDIA_OBJECT_MISMATCH'; end if;
 perform public.assert_admin_media_upload_lease(u);
 if TG_WHEN='AFTER' and new.version is distinct from '1' then
  update public.admin_media_uploads set object_id=new.id,status='staged' where operation_id=operation;
  perform public.assert_admin_media_upload_lease(u);
 end if;
 return new;
end $$;

revoke all on function public.lock_admin_media_upload_operation(uuid),public.assert_admin_media_upload_lease(public.admin_media_uploads),
 public.claim_admin_media_upload(uuid,uuid,uuid),public.begin_admin_media_upload(uuid,uuid)
 from public,anon,authenticated,service_role;
grant execute on function public.claim_admin_media_upload(uuid,uuid,uuid),public.begin_admin_media_upload(uuid,uuid) to service_role;
commit;

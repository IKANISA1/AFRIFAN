-- Original human commands survive uncertain Storage responses. Only an actual
-- authenticated JWT can admit/renew assurance; the service records remote facts.
begin;
create table public.admin_media_uploads (
 operation_id uuid primary key,
 actor_id uuid not null references auth.users(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 kind text not null check(kind in('shop_product','news_article','home_banner','fan_club','match','squad_player','notification')),
 mime_type text not null check(mime_type in('image/png','image/jpeg','image/webp')),
 byte_length integer not null check(byte_length between 1 and 5242880),
 content_sha256 text not null check(content_sha256 ~ '^[0-9a-f]{64}$'),
 bucket text not null default 'africlub-product-images' check(bucket='africlub-product-images'),
 storage_path text not null unique,
 current_proof_id uuid not null,
 status text not null default 'pending' check(status in('pending','uploading','unknown','staged','completed','failed')),
 lease_token uuid, lease_until timestamptz,
 attempts integer not null default 0 check(attempts between 0 and 32),
 object_id uuid, verified_sha256 text,
 admitted_at timestamptz not null default clock_timestamp(),
 completed_at timestamptz,
 check((status='completed')=(completed_at is not null)),
 check(verified_sha256 is null or verified_sha256=content_sha256),
 check(status<>'completed' or (object_id is not null and verified_sha256=content_sha256))
);
create table public.admin_media_upload_proofs (
 operation_id uuid not null references public.admin_media_uploads(operation_id) on delete restrict,
 proof_id uuid not null default gen_random_uuid(), session_id uuid not null,
 jwt_expires_at bigint not null, mfa_verified_at bigint not null,
 expires_at timestamptz not null, admitted_at timestamptz not null default clock_timestamp(),
 primary key(operation_id,proof_id), unique(operation_id,session_id,jwt_expires_at,mfa_verified_at)
);
-- A released, never-admitted original UUID cannot later become a remote write.
-- No image, bearer or session material is retained in this immutable tombstone.
create table public.admin_media_upload_releases (
 operation_id uuid primary key check(operation_id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'),
 actor_id uuid not null references auth.users(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 released_at timestamptz not null default clock_timestamp()
);
alter table public.admin_media_uploads add foreign key(operation_id,current_proof_id)
 references public.admin_media_upload_proofs(operation_id,proof_id) deferrable initially deferred;
alter table public.admin_media_uploads enable row level security;
alter table public.admin_media_upload_proofs enable row level security;
alter table public.admin_media_upload_releases enable row level security;
revoke all on public.admin_media_uploads,public.admin_media_upload_proofs,public.admin_media_upload_releases from public,anon,authenticated,service_role;
do $$ declare t text; begin
 foreach t in array array['admin_media_uploads','admin_media_upload_proofs','admin_media_upload_releases'] loop
  execute format('create trigger account_lifecycle_statement_guard before insert or update or delete on public.%I for each statement execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create trigger account_lifecycle_mutation_guard before insert or update or delete on public.%I for each row execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create policy account_lifecycle_access on public.%I as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed())',t);
 end loop;
end $$;
insert into public.account_erasure_fk_inventory(constraint_oid,child_table,subject_table,deletion_action,retained)
 select c.oid,c.conrelid::regclass::text,c.confrelid::regclass::text,c.confdeltype::text,true from pg_constraint c
 where c.contype='f' and c.conrelid in('public.admin_media_uploads'::regclass,'public.admin_media_upload_releases'::regclass) and c.confrelid='auth.users'::regclass
 on conflict(constraint_oid) do nothing;

create function public.guard_admin_media_upload_immutable() returns trigger language plpgsql set search_path='' as $$
begin
 if TG_OP='DELETE' or TG_TABLE_NAME in('admin_media_upload_proofs','admin_media_upload_releases') then raise exception 'MEDIA_COMMAND_IMMUTABLE'; end if;
 if (new.operation_id,new.actor_id,new.club_id,new.kind,new.mime_type,new.byte_length,new.content_sha256,new.bucket,new.storage_path,new.admitted_at)
  is distinct from (old.operation_id,old.actor_id,old.club_id,old.kind,old.mime_type,old.byte_length,old.content_sha256,old.bucket,old.storage_path,old.admitted_at)
  or (old.status='completed' and new is distinct from old) then raise exception 'MEDIA_COMMAND_IMMUTABLE'; end if;
 return new;
end $$;
create trigger media_command_immutable before update or delete on public.admin_media_uploads
 for each row execute function public.guard_admin_media_upload_immutable();
create trigger media_proof_immutable before update or delete on public.admin_media_upload_proofs
 for each row execute function public.guard_admin_media_upload_immutable();
create trigger media_release_immutable before update or delete on public.admin_media_upload_releases
 for each row execute function public.guard_admin_media_upload_immutable();

create function public.admin_media_upload_receipt(p_upload public.admin_media_uploads) returns jsonb
language sql immutable set search_path='' as $$
 select jsonb_build_object('operation_id',(p_upload).operation_id,'actor_id',(p_upload).actor_id,'club_id',(p_upload).club_id,
 'kind',(p_upload).kind,'mime_type',(p_upload).mime_type,'byte_length',(p_upload).byte_length,'content_sha256',(p_upload).content_sha256,
 'bucket',(p_upload).bucket,'storage_path',(p_upload).storage_path,'status',(p_upload).status,'object_id',(p_upload).object_id);
$$;

create function public.lock_admin_media_upload_actor(p_actor uuid,p_club bigint) returns uuid
language plpgsql security definer set search_path='' as $$ declare assignment uuid; begin
 perform pg_advisory_xact_lock(hashtextextended(p_actor::text,21000));
 if exists(select 1 from public.account_erasure_jobs where user_id=p_actor) or not exists(select 1 from auth.users
  where id=p_actor and not is_anonymous and deleted_at is null and (banned_until is null or banned_until<=clock_timestamp())) then
  raise exception 'ACCOUNT_CLOSURE_PENDING' using errcode='42501'; end if;
 perform 1 from public.african_football_clubs where id=p_club and is_active for share;
 if not found then raise exception 'MEDIA_CLUB_UNAVAILABLE' using errcode='42501'; end if;
 select id into assignment from public.admin_role_assignments where user_id=p_actor and is_active and revoked_at is null
  and (role in('admin','super_admin') or (role in('club_admin','club_moderator') and club_id=p_club)) order by id limit 1 for share;
 if assignment is null then raise exception 'MEDIA_CLUB_AUTHORITY_REQUIRED' using errcode='42501'; end if;
 return assignment;
end $$;

create function public.assert_admin_media_upload_proof(p_upload public.admin_media_uploads) returns void
language plpgsql security definer set search_path='' as $$
declare proof public.admin_media_upload_proofs; session_end timestamptz;
begin
 perform public.lock_admin_media_upload_actor(p_upload.actor_id,p_upload.club_id);
 select * into strict proof from public.admin_media_upload_proofs
  where operation_id=p_upload.operation_id and proof_id=p_upload.current_proof_id for share;
 select not_after into session_end from auth.sessions where id=proof.session_id and user_id=p_upload.actor_id and aal='aal2' for share;
 if not found or (session_end is not null and session_end<=clock_timestamp()) then
  raise exception 'MEDIA_SESSION_REVOKED' using errcode='42501'; end if;
 if proof.expires_at<=clock_timestamp() or proof.jwt_expires_at<=extract(epoch from clock_timestamp())
  or proof.mfa_verified_at<extract(epoch from clock_timestamp())-300 then
  raise exception 'MEDIA_ASSURANCE_EXPIRED' using errcode='42501'; end if;
end $$;

create function public.admit_admin_media_upload(p_operation_id uuid,p_club_id bigint,p_kind text,p_mime_type text,p_byte_length integer,p_content_sha256 text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); claims jsonb:=auth.jwt(); u public.admin_media_uploads; proof public.admin_media_upload_proofs;
 session uuid; session_end timestamptz; jwt_exp bigint; mfa_time bigint; a jsonb; ts numeric; epoch numeric; deadline timestamptz; path text;
begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then
  raise exception 'MEDIA_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_staff_step_up();
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
  update public.admin_media_uploads set current_proof_id=proof.proof_id where operation_id=p_operation_id returning * into u;
 end if;
 perform public.assert_staff_step_up(); perform public.assert_admin_media_upload_proof(u);
 return public.admin_media_upload_receipt(u);
end $$;

create function public.get_admin_media_upload_status(p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$ declare u public.admin_media_uploads; begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then raise exception 'MEDIA_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_account_active();
 select * into u from public.admin_media_uploads where operation_id=p_operation_id and actor_id=auth.uid();
 if not found then return null; end if;
 perform public.lock_admin_media_upload_actor(u.actor_id,u.club_id);
 return public.admin_media_upload_receipt(u);
end $$;

create function public.release_unadmitted_admin_media_upload(p_operation_id uuid,p_club_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); claims jsonb:=auth.jwt(); released public.admin_media_upload_releases;
 session uuid; session_end timestamptz;
begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then
  raise exception 'MEDIA_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_staff_step_up();
 if p_operation_id is null or p_operation_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  or p_club_id is null or p_club_id<=0 then raise exception 'MEDIA_INPUT_INVALID' using errcode='22023'; end if;
 -- The exact same original-command lock serializes release against admission,
 -- service claims and Storage. An uncertain admitted command is never aborted.
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

create function public.claim_admin_media_upload(p_operation_id uuid,p_lease_token uuid) returns jsonb
language plpgsql security definer set search_path='' as $$ declare u public.admin_media_uploads; begin
 if auth.role() is distinct from 'service_role' then raise exception 'MEDIA_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_lease_token is null or p_lease_token::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'MEDIA_LEASE_INVALID' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21027));
 select * into u from public.admin_media_uploads where operation_id=p_operation_id for update;
 if not found then raise exception 'MEDIA_ADMISSION_REQUIRED' using errcode='42501'; end if;
 perform public.lock_admin_media_upload_actor(u.actor_id,u.club_id);
 if u.status='completed' then return public.admin_media_upload_receipt(u)||jsonb_build_object('claimed',false,'lease_token',null); end if;
 perform public.assert_admin_media_upload_proof(u);
 if u.lease_until>clock_timestamp() and u.lease_token is distinct from p_lease_token then
  return public.admin_media_upload_receipt(u)||jsonb_build_object('claimed',false,'lease_token',null); end if;
 if u.attempts>=32 then raise exception 'MEDIA_ATTEMPT_LIMIT' using errcode='54000'; end if;
 update public.admin_media_uploads set status='uploading',lease_token=p_lease_token,lease_until=clock_timestamp()+interval '60 seconds',attempts=attempts+1
  where operation_id=p_operation_id returning * into u;
 perform public.assert_admin_media_upload_proof(u);
 return public.admin_media_upload_receipt(u)||jsonb_build_object('claimed',true,'lease_token',p_lease_token);
end $$;

create function public.complete_admin_media_upload(p_operation_id uuid,p_lease_token uuid,p_outcome text,p_object_id uuid,p_verified_sha256 text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u public.admin_media_uploads; o storage.objects; assured boolean:=true;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'MEDIA_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_outcome is null or p_outcome not in('stored','unknown','failed') then raise exception 'MEDIA_OUTCOME_INVALID' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21027));
 select * into u from public.admin_media_uploads where operation_id=p_operation_id for update;
 if not found then raise exception 'MEDIA_ADMISSION_REQUIRED' using errcode='42501'; end if;
 if u.status='completed' then
  perform public.lock_admin_media_upload_actor(u.actor_id,u.club_id);
  if p_outcome<>'stored' or p_object_id is distinct from u.object_id or p_verified_sha256 is distinct from u.verified_sha256 then raise exception 'MEDIA_COMMAND_BINDING_MISMATCH'; end if;
  return public.admin_media_upload_receipt(u);
 end if;
 if p_lease_token is null or u.lease_token is null or u.lease_until is null
  or u.lease_token is distinct from p_lease_token or u.lease_until<=clock_timestamp() then raise exception 'MEDIA_LEASE_LOST' using errcode='42501'; end if;
 if p_outcome='stored' then
  if p_object_id is null or p_verified_sha256 is distinct from u.content_sha256 then raise exception 'MEDIA_OBJECT_MISMATCH'; end if;
  -- No object row lock here: Storage takes its object lock before this trigger's
  -- command lock. Managed object content/identity is immutable below.
  select * into o from storage.objects where id=p_object_id and bucket_id=u.bucket and name=u.storage_path;
  if not found or o.version='1' or o.user_metadata->>'operation_id' is distinct from u.operation_id::text
   or o.user_metadata->>'content_sha256' is distinct from u.content_sha256
   or o.metadata->>'mimetype' is distinct from u.mime_type or coalesce(o.metadata->>'size',o.metadata->>'contentLength') is distinct from u.byte_length::text then
   raise exception 'MEDIA_OBJECT_MISMATCH'; end if;
  begin perform public.assert_admin_media_upload_proof(u); exception when sqlstate '42501' then assured:=false; end;
  update public.admin_media_uploads set status=case when assured then 'completed' else 'staged' end,object_id=p_object_id,
   verified_sha256=p_verified_sha256,completed_at=case when assured then clock_timestamp() end,lease_token=null,lease_until=null
   where operation_id=p_operation_id returning * into u;
  if assured then perform public.assert_admin_media_upload_proof(u); end if;
 else
  if p_object_id is not null or p_verified_sha256 is not null then raise exception 'MEDIA_OUTCOME_INVALID' using errcode='22023'; end if;
  update public.admin_media_uploads set status=case when object_id is not null then 'staged' else p_outcome end,
   lease_token=null,lease_until=null where operation_id=p_operation_id returning * into u;
 end if;
 return public.admin_media_upload_receipt(u);
end $$;

-- Storage v1.68.10 tests INSERT permission before bytes and later upserts as
-- superuser after waiting on the object. Guard both actual boundaries. Metadata
-- is only a command locator; it cannot supply actor, tenant or assurance.
create function public.guard_admin_media_storage_write() returns trigger
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
 perform pg_advisory_xact_lock(hashtextextended(operation::text,21027));
 select * into u from public.admin_media_uploads where operation_id=operation for update;
 if not found or new.name is distinct from u.storage_path or new.bucket_id is distinct from u.bucket
  or new.user_metadata->>'content_sha256' is distinct from u.content_sha256
  or new.metadata->>'mimetype' is distinct from u.mime_type then raise exception 'MEDIA_OBJECT_MISMATCH'; end if;
 if u.status not in('uploading','staged') or u.lease_token is distinct from token or u.lease_until<=clock_timestamp() then raise exception 'MEDIA_LEASE_LOST' using errcode='42501'; end if;
 if new.version is distinct from '1' and coalesce(new.metadata->>'size',new.metadata->>'contentLength') is distinct from u.byte_length::text then raise exception 'MEDIA_OBJECT_MISMATCH'; end if;
 perform public.assert_admin_media_upload_proof(u);
 if TG_WHEN='AFTER' and new.version is distinct from '1' then
  update public.admin_media_uploads set object_id=new.id,status='staged' where operation_id=operation;
  perform public.assert_admin_media_upload_proof(u);
 end if;
 return new;
end $$;
create trigger admin_media_storage_before before insert or update on storage.objects
 for each row execute function public.guard_admin_media_storage_write();
create trigger admin_media_storage_after after insert on storage.objects
 for each row execute function public.guard_admin_media_storage_write();

revoke all on function public.guard_admin_media_upload_immutable(),public.admin_media_upload_receipt(public.admin_media_uploads),
 public.lock_admin_media_upload_actor(uuid,bigint),public.assert_admin_media_upload_proof(public.admin_media_uploads),
 public.admit_admin_media_upload(uuid,bigint,text,text,integer,text),public.get_admin_media_upload_status(uuid),public.release_unadmitted_admin_media_upload(uuid,bigint),
 public.claim_admin_media_upload(uuid,uuid),public.complete_admin_media_upload(uuid,uuid,text,uuid,text),
 public.guard_admin_media_storage_write() from public,anon,authenticated,service_role;
grant execute on function public.admit_admin_media_upload(uuid,bigint,text,text,integer,text),public.get_admin_media_upload_status(uuid),public.release_unadmitted_admin_media_upload(uuid,bigint) to authenticated;
grant execute on function public.claim_admin_media_upload(uuid,uuid),public.complete_admin_media_upload(uuid,uuid,text,uuid,text) to service_role;
commit;

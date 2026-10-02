-- A committed original human command permits one Gemini attempt. Response
-- evidence stays private until a fresh real caller publishes through SQL27.
begin;
create function public.lock_verified_staff_provider_actor(p_actor uuid,p_club bigint,p_require_global boolean) returns void
language plpgsql security definer set search_path='' as $$ declare assignment uuid; begin
 perform pg_advisory_xact_lock(hashtextextended(p_actor::text,21000));
 if p_actor is null or exists(select 1 from public.account_erasure_jobs where user_id=p_actor)
  or not exists(select 1 from auth.users where id=p_actor and not is_anonymous and deleted_at is null
   and (banned_until is null or banned_until<=clock_timestamp())) then raise exception 'ACCOUNT_CLOSURE_PENDING' using errcode='42501'; end if;
 perform 1 from public.african_football_clubs where id=p_club and is_active for share;
 if not found then raise exception 'PROVIDER_CLUB_UNAVAILABLE' using errcode='42501'; end if;
 select id into assignment from public.admin_role_assignments where user_id=p_actor and is_active and revoked_at is null
  and ((role in('admin','super_admin') and club_id is null)
   or (not p_require_global and role in('club_admin','club_moderator') and club_id=p_club)) order by id limit 1 for share;
 if assignment is null then raise exception 'PROVIDER_STAFF_AUTHORITY_REQUIRED' using errcode='42501'; end if;
end $$;

create function public.capture_verified_staff_provider_proof(p_club_id bigint,p_require_global boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); claims jsonb:=auth.jwt(); session uuid; session_end timestamptz;
 jwt_exp bigint; mfa_time bigint; a jsonb; ts numeric; epoch numeric; deadline timestamptz;
begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then
  raise exception 'PROVIDER_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_staff_step_up();
 if p_club_id is null or p_club_id<=0 or p_require_global is null then raise exception 'PROVIDER_INPUT_INVALID' using errcode='22023'; end if;
 perform public.lock_verified_staff_provider_actor(actor,p_club_id,p_require_global);
 if coalesce(claims->>'session_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
  raise exception 'PROVIDER_SESSION_REQUIRED' using errcode='42501'; end if;
 session:=(claims->>'session_id')::uuid;
 select not_after into session_end from auth.sessions where id=session and user_id=actor and aal='aal2' for share;
 if not found or (session_end is not null and session_end<=clock_timestamp()) then raise exception 'PROVIDER_SESSION_REVOKED' using errcode='42501'; end if;
 -- The original JWT is re-evaluated after every authority/session wait.
 perform public.assert_staff_step_up();
 jwt_exp:=(claims->>'exp')::numeric::bigint; epoch:=extract(epoch from clock_timestamp());
 for a in select value from jsonb_array_elements(claims->'amr') loop
  if a->>'method' in('totp','mfa/totp') and jsonb_typeof(a->'timestamp')='number' then
   ts:=(a->>'timestamp')::numeric;
   if ts between epoch-300 and epoch+30 and abs(ts)<=9007199254740991 and mod(ts,1)=0 then mfa_time:=greatest(mfa_time,ts::bigint); end if;
  end if;
 end loop;
 if mfa_time is null then raise exception 'STAFF_STEP_UP_REQUIRED' using errcode='42501'; end if;
 deadline:=least(to_timestamp(least(jwt_exp,mfa_time+300)::double precision),coalesce(session_end,'infinity'::timestamptz));
 if deadline<=clock_timestamp() then raise exception 'PROVIDER_ASSURANCE_EXPIRED' using errcode='42501'; end if;
 return jsonb_build_object('session_id',session,'jwt_expires_at',jwt_exp,'mfa_verified_at',mfa_time,'expires_at',deadline);
end $$;

create function public.assert_verified_staff_provider_proof(p_actor_id uuid,p_club_id bigint,p_require_global boolean,p_proof jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare session_end timestamptz; jwt_exp numeric; mfa_time numeric; deadline timestamptz; epoch numeric;
begin
 if p_proof is null or jsonb_typeof(p_proof)<>'object' or p_proof-array['session_id','jwt_expires_at','mfa_verified_at','expires_at']<>'{}'::jsonb
  or jsonb_typeof(p_proof->'jwt_expires_at') is distinct from 'number' or jsonb_typeof(p_proof->'mfa_verified_at') is distinct from 'number'
  or coalesce(p_proof->>'session_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  or jsonb_typeof(p_proof->'expires_at') is distinct from 'string' then raise exception 'PROVIDER_PROOF_INVALID' using errcode='42501'; end if;
 jwt_exp:=(p_proof->>'jwt_expires_at')::numeric; mfa_time:=(p_proof->>'mfa_verified_at')::numeric;
 if abs(jwt_exp)>9007199254740991 or abs(mfa_time)>9007199254740991 or mod(jwt_exp,1)<>0 or mod(mfa_time,1)<>0 then
  raise exception 'PROVIDER_PROOF_INVALID' using errcode='42501'; end if;
 deadline:=(p_proof->>'expires_at')::timestamptz;
 perform public.lock_verified_staff_provider_actor(p_actor_id,p_club_id,p_require_global);
 select not_after into session_end from auth.sessions where id=(p_proof->>'session_id')::uuid and user_id=p_actor_id and aal='aal2' for share;
 if not found or (session_end is not null and session_end<=clock_timestamp()) then raise exception 'PROVIDER_SESSION_REVOKED' using errcode='42501'; end if;
 epoch:=extract(epoch from clock_timestamp());
 if jwt_exp<=epoch or mfa_time<epoch-300 or mfa_time>epoch+30 or deadline<=clock_timestamp()
  or deadline>to_timestamp(least(jwt_exp,mfa_time+300)::double precision) or deadline>coalesce(session_end,'infinity'::timestamptz) then
  raise exception 'PROVIDER_ASSURANCE_EXPIRED' using errcode='42501'; end if;
end $$;

create table public.admin_image_generations (
 operation_id uuid primary key check(operation_id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'),
 actor_id uuid not null references auth.users(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 domain text not null check(domain in('admin_image','product_image')), kind text not null,
 request jsonb not null, brand_snapshot jsonb not null, target_snapshot jsonb,
 public_upload_id uuid not null unique default gen_random_uuid(), current_proof_id uuid not null,
 status text not null default 'pending' check(status in('pending','generating','unknown','staged','completed','failed')),
 provider_started_at timestamptz, provider_context jsonb,
 lease_token uuid,lease_proof_id uuid,lease_until timestamptz,
 mime_type text check(mime_type in('image/png','image/jpeg','image/webp')),
 byte_length integer check(byte_length between 1 and 5242880), content_sha256 text check(content_sha256 ~ '^[0-9a-f]{64}$'),
 staging_path text unique, staging_object_id uuid, stage_verified boolean not null default false,
 target_conflict boolean not null default false, admitted_at timestamptz not null default clock_timestamp(),completed_at timestamptz,
 check((status='completed')=(completed_at is not null)),
 check(status<>'completed' or (stage_verified and staging_object_id is not null)),
 check((provider_started_at is null)=(provider_context is null))
);
create table public.admin_image_generation_proofs (
 operation_id uuid not null references public.admin_image_generations(operation_id) on delete restrict,
 proof_id uuid not null default gen_random_uuid(),proof jsonb not null,
 primary key(operation_id,proof_id),unique(operation_id,proof)
);
alter table public.admin_image_generations add foreign key(operation_id,current_proof_id)
 references public.admin_image_generation_proofs(operation_id,proof_id) deferrable initially deferred;
alter table public.admin_image_generations add foreign key(operation_id,lease_proof_id)
 references public.admin_image_generation_proofs(operation_id,proof_id) deferrable initially deferred;
do $$ declare t text; begin
 foreach t in array array['admin_image_generations','admin_image_generation_proofs'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
  execute format('create trigger account_lifecycle_statement_guard before insert or update or delete on public.%I for each statement execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create trigger account_lifecycle_mutation_guard before insert or update or delete on public.%I for each row execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create policy account_lifecycle_access on public.%I as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed())',t);
 end loop;
end $$;
insert into public.account_erasure_fk_inventory(constraint_oid,child_table,subject_table,deletion_action,retained)
 select c.oid,c.conrelid::regclass::text,c.confrelid::regclass::text,c.confdeltype::text,true from pg_constraint c
 where c.contype='f' and c.conrelid='public.admin_image_generations'::regclass and c.confrelid='auth.users'::regclass on conflict(constraint_oid) do nothing;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 values('africlub-generated-image-staging','africlub-generated-image-staging',false,5242880,array['image/png','image/jpeg','image/webp']);
-- Existing Storage policies cannot accidentally publish response evidence.
create policy admin_generation_private_stage on storage.objects as restrictive for select to anon,authenticated
 using(bucket_id<>'africlub-generated-image-staging');

-- Authenticated admission/commit already lock their real caller's lifecycle.
-- A worker first reads only the immutable retained actor and takes that same
-- advisory lock before either operation domain. Current grants, session and
-- original proof are checked after command waits, not locked by this pre-read.
-- Generated publication takes SQL27's operation before its generation lock.
create function public.lock_admin_image_generation_operation(p_operation_id uuid) returns void
language plpgsql security definer set search_path='' as $$ declare upload uuid; actor uuid; begin
 select public_upload_id,actor_id into upload,actor from public.admin_image_generations where operation_id=p_operation_id;
 if actor is not null and auth.role()='service_role' then
  perform pg_advisory_xact_lock(hashtextextended(actor::text,21000));
 end if;
 if upload is not null then perform pg_advisory_xact_lock(hashtextextended(upload::text,21027)); end if;
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21028));
end $$;

create function public.guard_admin_image_generation_immutable() returns trigger language plpgsql set search_path='' as $$ begin
 if TG_OP='DELETE' or TG_TABLE_NAME='admin_image_generation_proofs' then raise exception 'GENERATION_COMMAND_IMMUTABLE'; end if;
 if (new.operation_id,new.actor_id,new.club_id,new.domain,new.kind,new.request,new.brand_snapshot,new.target_snapshot,new.public_upload_id,new.admitted_at)
  is distinct from (old.operation_id,old.actor_id,old.club_id,old.domain,old.kind,old.request,old.brand_snapshot,old.target_snapshot,old.public_upload_id,old.admitted_at)
  or (old.provider_started_at is not null and (new.provider_started_at,new.provider_context) is distinct from (old.provider_started_at,old.provider_context))
  or (old.content_sha256 is not null and (new.mime_type,new.byte_length,new.content_sha256,new.staging_path) is distinct from (old.mime_type,old.byte_length,old.content_sha256,old.staging_path))
  or (old.staging_object_id is not null and new.staging_object_id is distinct from old.staging_object_id)
  or (old.stage_verified and not new.stage_verified) or (old.status='completed' and new is distinct from old) then raise exception 'GENERATION_COMMAND_IMMUTABLE'; end if;
 return new;
end $$;
create trigger generation_command_immutable before update or delete on public.admin_image_generations for each row execute function public.guard_admin_image_generation_immutable();
create trigger generation_proof_immutable before update or delete on public.admin_image_generation_proofs for each row execute function public.guard_admin_image_generation_immutable();

create function public.admin_image_generation_receipt(g public.admin_image_generations) returns jsonb language sql volatile set search_path='' as $$
 select jsonb_build_object('operation_id',(g).operation_id,'actor_id',(g).actor_id,'club_id',(g).club_id,'domain',(g).domain,'kind',(g).kind,
 'status',case when (g).status='generating' and (g).lease_until<=clock_timestamp() then 'unknown' else (g).status end,
 'request',(g).request,'target_conflict',(g).target_conflict)
 || case when (g).status='completed' then jsonb_build_object('image_url',((g).provider_context->>'public_origin')||'/storage/v1/object/public/africlub-product-images/'||u.storage_path,
 'storage_path',u.storage_path,'prompt_used',(g).provider_context->>'prompt_used','model',(g).provider_context->>'model',
 'aspect_ratio',(g).provider_context->>'aspect_ratio','club',(g).brand_snapshot->>'club_name','success',true,'product_type',(g).request->>'productType') else '{}'::jsonb end
 from (select 1) dummy left join public.admin_media_uploads u on u.operation_id=(g).public_upload_id;
$$;

create function public.admit_admin_image_generation(p_operation_id uuid,p_club_id bigint,p_domain text,p_request jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); g public.admin_image_generations; v_proof jsonb; v_proof_id uuid; brand jsonb; target jsonb; target_id uuid; kind text;
begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then raise exception 'PROVIDER_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_account_active(); perform public.assert_staff_step_up();
 if p_operation_id is null or p_operation_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
  or p_domain is null or p_domain not in('admin_image','product_image') or p_request is null or jsonb_typeof(p_request)<>'object' then
  raise exception 'GENERATION_INPUT_INVALID' using errcode='22023'; end if;
 if p_domain='admin_image' then
  kind:=p_request->>'kind';
  if p_request-array['kind','prompt','subject','aspectRatio']<>'{}'::jsonb or kind is null or kind not in('shop_product','news_article','home_banner','fan_club','match','squad_player','notification')
   or jsonb_typeof(p_request->'prompt') is distinct from 'string' or length(btrim(p_request->>'prompt')) not between 1 and 4000
   or p_request->>'prompt'<>btrim(p_request->>'prompt') or not(p_request ?& array['subject','aspectRatio'])
   or (p_request->'subject'<>'null'::jsonb and (jsonb_typeof(p_request->'subject')<>'string' or length(btrim(p_request->>'subject')) not between 1 and 500 or p_request->>'subject'<>btrim(p_request->>'subject')))
   or jsonb_typeof(p_request->'aspectRatio') is distinct from 'string' or p_request->>'aspectRatio' not in('1:1','2:3','3:2','3:4','4:3','4:5','5:4','9:16','16:9','21:9') then raise exception 'GENERATION_INPUT_INVALID' using errcode='22023'; end if;
 else
  kind:=case when p_request->>'productType'='news' then 'news_article' else 'shop_product' end;
  if p_request-array['productType','productName','targetTable','targetId']<>'{}'::jsonb or not(p_request ?& array['productType','productName','targetTable','targetId'])
   or jsonb_typeof(p_request->'productType') is distinct from 'string' or p_request->>'productType' not in('kit','jacket','scarf','ball','guards','accessory','news')
   or (p_request->'productName'<>'null'::jsonb and (jsonb_typeof(p_request->'productName')<>'string' or length(btrim(p_request->>'productName')) not between 1 and 120 or p_request->>'productName'<>btrim(p_request->>'productName')))
   or ((p_request->'targetTable'='null'::jsonb) is distinct from (p_request->'targetId'='null'::jsonb))
   or (p_request->'targetTable'<>'null'::jsonb and (p_request->>'targetTable' not in('shop_products','news_articles')
    or coalesce(p_request->>'targetId','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')) then raise exception 'GENERATION_INPUT_INVALID' using errcode='22023'; end if;
 end if;
 perform public.lock_admin_image_generation_operation(p_operation_id);
 select * into g from public.admin_image_generations where operation_id=p_operation_id for update;
 if found and (g.actor_id,g.club_id,g.domain,g.request) is distinct from (actor,p_club_id,p_domain,p_request) then raise exception 'GENERATION_COMMAND_BINDING_MISMATCH' using errcode='22023'; end if;
 v_proof:=public.capture_verified_staff_provider_proof(p_club_id,false);
 if g.operation_id is null then
  select jsonb_build_object('club_name',club_name,'primary_brand_colors',primary_brand_colors,'nickname_brand_identity',nickname_brand_identity,'country_name',country_name,'region',region,'league',league)
   into brand from public.african_football_clubs where id=p_club_id;
  if p_domain='product_image' and p_request->'targetId'<>'null'::jsonb then
   target_id:=(p_request->>'targetId')::uuid;
   if p_request->>'targetTable'='shop_products' then
    select jsonb_build_object('image_url',image_url,'image_prompt',image_prompt,'updated_at',updated_at,'image_rights_approved',image_rights_approved,'image_provenance_id',image_provenance_id,'image_rights_approved_at',image_rights_approved_at,'image_rights_approved_by',image_rights_approved_by) into target from public.shop_products where id=target_id and club_id=p_club_id for share;
    perform public.assert_staff_commercial_role(jsonb_build_object('club_id',p_club_id),true);
   else
    select jsonb_build_object('image_url',image_url,'image_prompt',image_prompt,'updated_at',updated_at,'image_rights_approved',image_rights_approved,'image_provenance_id',image_provenance_id,'image_rights_approved_at',image_rights_approved_at,'image_rights_approved_by',image_rights_approved_by) into target from public.news_articles where id=target_id and club_id=p_club_id for share;
   end if;
   if target is null then raise exception 'GENERATION_TARGET_UNAVAILABLE' using errcode='22023'; end if;
  end if;
  perform public.assert_verified_staff_provider_proof(actor,p_club_id,false,v_proof);
  insert into public.admin_image_generations(operation_id,actor_id,club_id,domain,kind,request,brand_snapshot,target_snapshot,current_proof_id)
   values(p_operation_id,actor,p_club_id,p_domain,kind,p_request,brand,target,gen_random_uuid()) returning * into g;
 end if;
 if g.status='completed' then return public.admin_image_generation_receipt(g); end if;
 select p.proof_id into v_proof_id from public.admin_image_generation_proofs p where p.operation_id=p_operation_id and p.proof=v_proof;
 if v_proof_id is null then
  if (select count(*) from public.admin_image_generation_proofs where operation_id=p_operation_id)>=32 then raise exception 'GENERATION_PROOF_LIMIT' using errcode='54000'; end if;
  v_proof_id:=case when not exists(select 1 from public.admin_image_generation_proofs where operation_id=p_operation_id) then g.current_proof_id else gen_random_uuid() end;
  insert into public.admin_image_generation_proofs values(p_operation_id,v_proof_id,v_proof);
 end if;
 update public.admin_image_generations set current_proof_id=v_proof_id where operation_id=p_operation_id returning * into g;
 perform public.assert_verified_staff_provider_proof(actor,p_club_id,false,v_proof);
 return public.admin_image_generation_receipt(g)||jsonb_build_object('dispatch_proof_id',v_proof_id,'brand_snapshot',g.brand_snapshot);
end $$;

create function public.get_admin_image_generation_status(p_operation_id uuid,p_club_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$ declare g public.admin_image_generations; begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then raise exception 'PROVIDER_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_account_active();
 select * into g from public.admin_image_generations where operation_id=p_operation_id and actor_id=auth.uid() and club_id=p_club_id;
 if not found then return null; end if;
 perform public.lock_verified_staff_provider_actor(g.actor_id,g.club_id,false);
 return public.admin_image_generation_receipt(g);
end $$;

create function public.claim_admin_image_generation(p_operation_id uuid,p_lease_token uuid,p_dispatch_proof_id uuid,p_provider_context jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.admin_image_generations; proof jsonb; budget record; started boolean:=false; reconcile boolean:=false;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'GENERATION_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_lease_token is null or p_lease_token::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'GENERATION_LEASE_INVALID' using errcode='22023'; end if;
 perform public.lock_admin_image_generation_operation(p_operation_id);
 select * into g from public.admin_image_generations where operation_id=p_operation_id for update;
 if not found then raise exception 'GENERATION_ADMISSION_REQUIRED' using errcode='42501'; end if;
 perform public.lock_verified_staff_provider_actor(g.actor_id,g.club_id,false);
 select p.proof into proof from public.admin_image_generation_proofs p where p.operation_id=p_operation_id and p.proof_id=p_dispatch_proof_id;
 if proof is null then raise exception 'GENERATION_ADMISSION_PROOF_REQUIRED' using errcode='42501'; end if;
 perform public.assert_verified_staff_provider_proof(g.actor_id,g.club_id,false,proof);
 if g.status='completed' then return public.admin_image_generation_receipt(g)||jsonb_build_object('claimed',false,'reconcile',false); end if;
 if g.lease_until>clock_timestamp() and g.status='generating' then
  return public.admin_image_generation_receipt(g)||jsonb_build_object('claimed',false,'reconcile',false);
 end if;
 if g.provider_started_at is null then
  if p_provider_context is null or jsonb_typeof(p_provider_context)<>'object' or p_provider_context-array['model','public_origin','prompt_used','aspect_ratio']<>'{}'::jsonb
   or not(p_provider_context ?& array['model','public_origin','prompt_used','aspect_ratio'])
   or jsonb_typeof(p_provider_context->'model') is distinct from 'string' or jsonb_typeof(p_provider_context->'public_origin') is distinct from 'string' or jsonb_typeof(p_provider_context->'prompt_used') is distinct from 'string'
   or coalesce(p_provider_context->>'model','') !~ '^[a-zA-Z0-9._-]{1,120}$'
   or coalesce(p_provider_context->>'public_origin','') !~ '^https://[a-zA-Z0-9.-]+(:[0-9]{1,5})?$'
   or length(coalesce(p_provider_context->>'prompt_used','')) not between 1 and 20000
   or jsonb_typeof(p_provider_context->'aspect_ratio') is distinct from 'string' or p_provider_context->>'aspect_ratio' not in('1:1','2:3','3:2','3:4','4:3','4:5','5:4','9:16','16:9','21:9') then raise exception 'GENERATION_PROVIDER_CONTEXT_INVALID' using errcode='22023'; end if;
  select * into budget from public.consume_edge_rate_limit(replace(jsonb_build_array(g.actor_id,
   case g.domain when 'admin_image' then 'generate-admin-image' else 'generate-product-image' end,g.club_id)::text,', ',','),6,3600);
  if not budget.allowed then return public.admin_image_generation_receipt(g)||jsonb_build_object('claimed',false,'reconcile',false,'retry_after_seconds',budget.retry_after_seconds); end if;
  started:=true;
 elsif g.staging_object_id is not null then reconcile:=true;
 else
  update public.admin_image_generations set status=case when status='failed' then 'failed' else 'unknown' end where operation_id=p_operation_id returning * into g;
  return public.admin_image_generation_receipt(g)||jsonb_build_object('claimed',false,'reconcile',false);
 end if;
 update public.admin_image_generations set status=case when started then 'generating' else 'staged' end,
  provider_started_at=coalesce(provider_started_at,clock_timestamp()),provider_context=coalesce(provider_context,p_provider_context),
  lease_token=p_lease_token,lease_proof_id=p_dispatch_proof_id,lease_until=clock_timestamp()+interval '180 seconds'
  where operation_id=p_operation_id returning * into g;
 perform public.assert_verified_staff_provider_proof(g.actor_id,g.club_id,false,proof);
 return public.admin_image_generation_receipt(g)||jsonb_build_object('claimed',started,'reconcile',reconcile,'lease_token',p_lease_token,
 'public_upload_id',g.public_upload_id,'brand_snapshot',g.brand_snapshot,'provider_context',g.provider_context,
 'staging_path',g.staging_path,'staging_object_id',g.staging_object_id,'mime_type',g.mime_type,'byte_length',g.byte_length,'content_sha256',g.content_sha256);
end $$;

-- Recording the response of an already-started attempt is not permission to
-- publish. Clock expiry alone preserves private evidence; logout/revocation and
-- account closure still deny it, using the exact original leased session.
create function public.assert_admin_image_response_stage(g public.admin_image_generations) returns void
language plpgsql security definer set search_path='' as $$ declare proof jsonb; session_end timestamptz; begin
 perform public.lock_verified_staff_provider_actor(g.actor_id,g.club_id,false);
 if g.provider_started_at is null or g.lease_token is null or g.lease_until<=clock_timestamp() then raise exception 'GENERATION_LEASE_LOST' using errcode='42501'; end if;
 select p.proof into strict proof from public.admin_image_generation_proofs p where p.operation_id=g.operation_id and p.proof_id=g.lease_proof_id;
 select not_after into session_end from auth.sessions where id=(proof->>'session_id')::uuid and user_id=g.actor_id and aal='aal2' for share;
 if not found or (session_end is not null and session_end<=clock_timestamp()) then raise exception 'PROVIDER_SESSION_REVOKED' using errcode='42501'; end if;
 if g.lease_until<=clock_timestamp() then raise exception 'GENERATION_LEASE_LOST' using errcode='42501'; end if;
end $$;

create function public.record_admin_image_generation_result(p_operation_id uuid,p_lease_token uuid,p_outcome text,p_object_id uuid,p_content_sha256 text,p_mime_type text,p_byte_length integer)
returns jsonb language plpgsql security definer set search_path='' as $$ declare g public.admin_image_generations; o storage.objects; path text; begin
 if auth.role() is distinct from 'service_role' then raise exception 'GENERATION_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_outcome is null or p_outcome not in('prepared','stored','unknown','failed') then raise exception 'GENERATION_OUTCOME_INVALID' using errcode='22023'; end if;
 perform public.lock_admin_image_generation_operation(p_operation_id);
 select * into g from public.admin_image_generations where operation_id=p_operation_id for update;
 if not found then raise exception 'GENERATION_ADMISSION_REQUIRED' using errcode='42501'; end if;
 if g.lease_token is distinct from p_lease_token then raise exception 'GENERATION_LEASE_LOST' using errcode='42501'; end if;
 perform public.assert_admin_image_response_stage(g);
 if p_outcome in('prepared','stored') then
  if p_content_sha256 is null or p_content_sha256 !~ '^[0-9a-f]{64}$' or p_mime_type is null or p_mime_type not in('image/png','image/jpeg','image/webp')
   or p_byte_length is null or p_byte_length not between 1 and 5242880 then raise exception 'GENERATION_RESULT_INVALID' using errcode='22023'; end if;
  path:='club-'||g.club_id||'/'||g.operation_id||case p_mime_type when 'image/png' then '.png' when 'image/jpeg' then '.jpg' else '.webp' end;
  if g.content_sha256 is not null and (g.content_sha256,g.mime_type,g.byte_length,g.staging_path) is distinct from(p_content_sha256,p_mime_type,p_byte_length,path) then
   raise exception 'GENERATION_RESULT_BINDING_MISMATCH' using errcode='22023'; end if;
  if p_outcome='stored' then
   select * into o from storage.objects where id=p_object_id and bucket_id='africlub-generated-image-staging' and name=path;
   if not found or o.version='1' or o.user_metadata->>'operation_id' is distinct from g.operation_id::text
    or o.user_metadata->>'content_sha256' is distinct from p_content_sha256 or o.metadata->>'mimetype' is distinct from p_mime_type
    or coalesce(o.metadata->>'size',o.metadata->>'contentLength') is distinct from p_byte_length::text then raise exception 'GENERATION_OBJECT_MISMATCH'; end if;
  end if;
  update public.admin_image_generations set mime_type=p_mime_type,byte_length=p_byte_length,content_sha256=p_content_sha256,staging_path=path,
   staging_object_id=case when p_outcome='stored' then p_object_id else staging_object_id end,
   stage_verified=stage_verified or p_outcome='stored',status=case when p_outcome='stored' then 'staged' else status end
   where operation_id=p_operation_id returning * into g;
 else
  update public.admin_image_generations set status=case when staging_object_id is not null then 'staged' else p_outcome end,
   lease_until=clock_timestamp() where operation_id=p_operation_id returning * into g;
 end if;
 if p_outcome in('prepared','stored') then perform public.assert_admin_image_response_stage(g); end if;
 return public.admin_image_generation_receipt(g);
end $$;

create function public.guard_admin_image_staging_write() returns trigger language plpgsql security definer set search_path='' as $$
declare g public.admin_image_generations; operation uuid; proof jsonb; public_image boolean:=false; begin
 if new.bucket_id='africlub-product-images' then
  select * into g from public.admin_image_generations where public_upload_id::text=new.user_metadata->>'operation_id';
  public_image:=found;
 end if;
 if not public_image and new.bucket_id<>'africlub-generated-image-staging' and (TG_OP<>'UPDATE' or old.bucket_id<>'africlub-generated-image-staging') then return new; end if;
 if TG_OP='UPDATE' then
  if (new.id,new.bucket_id,new.name,new.version,new.metadata,new.user_metadata,new.owner,new.owner_id)
   is distinct from(old.id,old.bucket_id,old.name,old.version,old.metadata,old.user_metadata,old.owner,old.owner_id) then raise exception 'GENERATION_OBJECT_IMMUTABLE'; end if;
  return new;
 end if;
 if public_image then
  operation:=g.operation_id;
  perform public.lock_admin_image_generation_operation(operation);
  select * into strict g from public.admin_image_generations where operation_id=operation for update;
  if auth.role() is distinct from 'service_role' or not g.stage_verified or g.lease_token is null or g.lease_until<=clock_timestamp()
   or new.user_metadata->>'generation_operation_id' is distinct from g.operation_id::text
   or new.user_metadata->>'generation_lease_token' is distinct from g.lease_token::text
   or new.user_metadata->>'generation_proof_id' is distinct from g.lease_proof_id::text then raise exception 'GENERATION_PUBLICATION_PROOF_REQUIRED' using errcode='42501'; end if;
  select p.proof into strict proof from public.admin_image_generation_proofs p where p.operation_id=g.operation_id and p.proof_id=g.lease_proof_id;
  perform public.assert_verified_staff_provider_proof(g.actor_id,g.club_id,false,proof);
  if g.lease_until<=clock_timestamp() then raise exception 'GENERATION_LEASE_LOST' using errcode='42501'; end if;
  return new;
 end if;
 if auth.role() is distinct from 'service_role' or coalesce(new.user_metadata->>'operation_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'GENERATION_ADMISSION_REQUIRED' using errcode='42501'; end if;
 operation:=(new.user_metadata->>'operation_id')::uuid;
 perform public.lock_admin_image_generation_operation(operation);
 select * into g from public.admin_image_generations where operation_id=operation for update;
 if not found or new.name is distinct from g.staging_path or new.user_metadata->>'lease_token' is distinct from g.lease_token::text
  or new.user_metadata->>'content_sha256' is distinct from g.content_sha256 or new.metadata->>'mimetype' is distinct from g.mime_type
  or (new.version is distinct from '1' and coalesce(new.metadata->>'size',new.metadata->>'contentLength') is distinct from g.byte_length::text) then raise exception 'GENERATION_OBJECT_MISMATCH'; end if;
 perform public.assert_admin_image_response_stage(g);
 if TG_WHEN='BEFORE' then
  -- The real erasure Storage worker can find and remove private response bytes.
  new.owner:=g.actor_id; new.owner_id:=g.actor_id::text;
 end if;
 if TG_WHEN='AFTER' and new.version is distinct from '1' then
  update public.admin_image_generations set staging_object_id=new.id,status='staged' where operation_id=operation;
  perform public.assert_admin_image_response_stage(g);
 end if;
 return new;
end $$;
create trigger zz_admin_image_staging_before before insert or update on storage.objects for each row execute function public.guard_admin_image_staging_write();
create trigger zz_admin_image_staging_after after insert on storage.objects for each row execute function public.guard_admin_image_staging_write();

create function public.commit_admin_image_generation(p_operation_id uuid,p_club_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare g public.admin_image_generations; u public.admin_media_uploads; proof jsonb; target jsonb; url text; begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then raise exception 'PROVIDER_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_account_active();
 perform public.lock_admin_image_generation_operation(p_operation_id);
 select * into g from public.admin_image_generations where operation_id=p_operation_id for update;
 if not found or (g.actor_id,g.club_id) is distinct from(auth.uid(),p_club_id) then raise exception 'GENERATION_ADMISSION_REQUIRED' using errcode='42501'; end if;
 proof:=public.capture_verified_staff_provider_proof(p_club_id,false);
 if g.status='completed' then return public.admin_image_generation_receipt(g); end if;
 select * into u from public.admin_media_uploads where operation_id=g.public_upload_id and actor_id=g.actor_id and club_id=g.club_id and kind=g.kind
  and mime_type=g.mime_type and byte_length=g.byte_length and content_sha256=g.content_sha256 and status='completed' for share;
 if not found or not g.stage_verified then raise exception 'GENERATION_PUBLICATION_REQUIRED' using errcode='42501'; end if;
 url:=(g.provider_context->>'public_origin')||'/storage/v1/object/public/africlub-product-images/'||u.storage_path;
 if g.target_snapshot is not null then
  if g.request->>'targetTable'='shop_products' then
   select jsonb_build_object('image_url',image_url,'image_prompt',image_prompt,'updated_at',updated_at,'image_rights_approved',image_rights_approved,'image_provenance_id',image_provenance_id,'image_rights_approved_at',image_rights_approved_at,'image_rights_approved_by',image_rights_approved_by) into target from public.shop_products where id=(g.request->>'targetId')::uuid and club_id=g.club_id for update;
   perform public.assert_staff_commercial_role(jsonb_build_object('club_id',g.club_id),true);
  else
   select jsonb_build_object('image_url',image_url,'image_prompt',image_prompt,'updated_at',updated_at,'image_rights_approved',image_rights_approved,'image_provenance_id',image_provenance_id,'image_rights_approved_at',image_rights_approved_at,'image_rights_approved_by',image_rights_approved_by) into target from public.news_articles where id=(g.request->>'targetId')::uuid and club_id=g.club_id for update;
  end if;
  perform public.assert_verified_staff_provider_proof(g.actor_id,g.club_id,false,proof);
  if target is distinct from g.target_snapshot then
   update public.admin_image_generations set status='staged',target_conflict=true where operation_id=p_operation_id returning * into g;
   return public.admin_image_generation_receipt(g);
  end if;
  if g.request->>'targetTable'='shop_products' then
   update public.shop_products set image_url=url,image_prompt=g.provider_context->>'prompt_used',updated_at=clock_timestamp(),image_rights_approved=false,image_provenance_id=null,image_rights_approved_at=null,image_rights_approved_by=null where id=(g.request->>'targetId')::uuid and club_id=g.club_id;
  else
   update public.news_articles set image_url=url,image_prompt=g.provider_context->>'prompt_used',updated_at=clock_timestamp(),image_rights_approved=false,image_provenance_id=null,image_rights_approved_at=null,image_rights_approved_by=null where id=(g.request->>'targetId')::uuid and club_id=g.club_id;
  end if;
  if not found then raise exception 'GENERATION_TARGET_UNAVAILABLE' using errcode='22023'; end if;
 end if;
 perform public.assert_verified_staff_provider_proof(g.actor_id,g.club_id,false,proof);
 update public.admin_image_generations set status='completed',completed_at=clock_timestamp(),target_conflict=false,lease_token=null,lease_until=null where operation_id=p_operation_id returning * into g;
 perform public.assert_verified_staff_provider_proof(g.actor_id,g.club_id,false,proof);
 return public.admin_image_generation_receipt(g);
end $$;
revoke all on function public.lock_verified_staff_provider_actor(uuid,bigint,boolean),public.capture_verified_staff_provider_proof(bigint,boolean),
 public.assert_verified_staff_provider_proof(uuid,bigint,boolean,jsonb),public.lock_admin_image_generation_operation(uuid),public.guard_admin_image_generation_immutable(),public.admin_image_generation_receipt(public.admin_image_generations),
 public.admit_admin_image_generation(uuid,bigint,text,jsonb),public.get_admin_image_generation_status(uuid,bigint),public.claim_admin_image_generation(uuid,uuid,uuid,jsonb),
 public.assert_admin_image_response_stage(public.admin_image_generations),public.record_admin_image_generation_result(uuid,uuid,text,uuid,text,text,integer),
 public.guard_admin_image_staging_write(),public.commit_admin_image_generation(uuid,bigint) from public,anon,authenticated,service_role;
grant execute on function public.admit_admin_image_generation(uuid,bigint,text,jsonb),public.get_admin_image_generation_status(uuid,bigint),public.commit_admin_image_generation(uuid,bigint) to authenticated;
grant execute on function public.claim_admin_image_generation(uuid,uuid,uuid,jsonb),public.record_admin_image_generation_result(uuid,uuid,text,uuid,text,text,integer) to service_role;
commit;

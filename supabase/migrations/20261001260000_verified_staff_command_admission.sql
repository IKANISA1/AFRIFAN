-- Human authority reaches service-only financial engines through authenticated
-- JWT admission. Neither a caller-selected actor nor service-generated claims
-- can create assurance. Original commands and every verification attempt persist.
begin;

create table public.verified_staff_commands (
 operation_id uuid primary key,
 actor_id uuid not null references auth.users(id) on delete restrict,
 action text not null check(action in ('fixture_settle','predict_legacy_settle','predict_legacy_confirm','partner_legacy_settle')),
 resource_id uuid not null,
 club_id bigint references public.african_football_clubs(id) on delete restrict,
 arguments jsonb not null check(jsonb_typeof(arguments)='object'),
 current_proof_id uuid not null,
 result jsonb,
 admitted_at timestamptz not null default clock_timestamp(),
 completed_at timestamptz,
 check((result is null)=(completed_at is null))
);
create table public.verified_staff_command_proofs (
 operation_id uuid not null references public.verified_staff_commands(operation_id) on delete restrict,
 proof_id uuid not null default gen_random_uuid(),
 session_id uuid not null, -- No FK: Auth logout must be able to remove a session.
 jwt_expires_at bigint not null,
 mfa_verified_at bigint not null,
 expires_at timestamptz not null,
 admitted_at timestamptz not null default clock_timestamp(),
 primary key(operation_id,proof_id),
 unique(operation_id,session_id,jwt_expires_at,mfa_verified_at)
);
alter table public.verified_staff_commands add foreign key(operation_id,current_proof_id)
 references public.verified_staff_command_proofs(operation_id,proof_id) deferrable initially deferred;
alter table public.verified_staff_commands enable row level security;
alter table public.verified_staff_command_proofs enable row level security;
revoke all on public.verified_staff_commands,public.verified_staff_command_proofs from public,anon,authenticated,service_role;

create function public.guard_verified_staff_command_immutable() returns trigger
language plpgsql set search_path='' as $$
begin
 if TG_OP='DELETE' or TG_TABLE_NAME='verified_staff_command_proofs' then
  raise exception 'STAFF_COMMAND_IMMUTABLE'; end if;
 if (new.operation_id,new.actor_id,new.action,new.resource_id,new.club_id,new.arguments,new.admitted_at)
  is distinct from (old.operation_id,old.actor_id,old.action,old.resource_id,old.club_id,old.arguments,old.admitted_at)
  or (old.result is not null and (new.result,new.completed_at,new.current_proof_id)
   is distinct from (old.result,old.completed_at,old.current_proof_id)) then
  raise exception 'STAFF_COMMAND_IMMUTABLE'; end if;
 return new;
end $$;
create trigger staff_command_immutable before update or delete on public.verified_staff_commands
 for each row execute function public.guard_verified_staff_command_immutable();
create trigger staff_command_proof_immutable before update or delete on public.verified_staff_command_proofs
 for each row execute function public.guard_verified_staff_command_immutable();
do $$ declare t text; begin
 foreach t in array array['verified_staff_commands','verified_staff_command_proofs'] loop
  execute format('create trigger account_lifecycle_statement_guard before insert or update or delete on public.%I for each statement execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create trigger account_lifecycle_mutation_guard before insert or update or delete on public.%I for each row execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create policy account_lifecycle_access on public.%I as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed())',t);
 end loop;
end $$;
insert into public.account_erasure_fk_inventory(constraint_oid,child_table,subject_table,deletion_action,retained)
 select c.oid,c.conrelid::regclass::text,c.confrelid::regclass::text,c.confdeltype::text,true
 from pg_constraint c where c.contype='f' and c.conrelid='public.verified_staff_commands'::regclass
 and c.confrelid='auth.users'::regclass on conflict(constraint_oid) do nothing;

create function public.verified_staff_command_arguments(p_action text,p_arguments jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare a jsonb:=coalesce(p_arguments,'{}'::jsonb); h numeric; v numeric; hh numeric; vv numeric; reason text; source text;
begin
 if jsonb_typeof(a) is distinct from 'object' or pg_column_size(a)>8192 then
  raise exception 'STAFF_COMMAND_ARGUMENTS_INVALID' using errcode='22023'; end if;
 if p_action='partner_legacy_settle' then
  if a<>'{}'::jsonb then raise exception 'STAFF_COMMAND_ARGUMENTS_INVALID' using errcode='22023'; end if;
  return '{}'::jsonb;
 elsif p_action='predict_legacy_settle' then
  if a-array['void_reason']<>'{}'::jsonb or (a?'void_reason' and jsonb_typeof(a->'void_reason') not in ('string','null')) then
   raise exception 'STAFF_COMMAND_ARGUMENTS_INVALID' using errcode='22023'; end if;
  reason:=case when a->>'void_reason' is not null then trim(a->>'void_reason') end;
  if reason is not null and length(reason) not between 8 and 500 then
   raise exception 'STAFF_COMMAND_ARGUMENTS_INVALID' using errcode='22023'; end if;
  return jsonb_build_object('void_reason',reason);
 elsif p_action in ('fixture_settle','predict_legacy_confirm') then
  if a - (case when p_action='fixture_settle' then array['home_score','away_score','ht_home_score','ht_away_score']
   else array['home_score','away_score','source_url'] end) <> '{}'::jsonb
   or jsonb_typeof(a->'home_score') is distinct from 'number' or jsonb_typeof(a->'away_score') is distinct from 'number' then
   raise exception 'STAFF_COMMAND_ARGUMENTS_INVALID' using errcode='22023'; end if;
  h:=(a->>'home_score')::numeric; v:=(a->>'away_score')::numeric;
  if h not between 0 and 99 or v not between 0 and 99 or mod(h,1)<>0 or mod(v,1)<>0 then
   raise exception 'STAFF_COMMAND_ARGUMENTS_INVALID' using errcode='22023'; end if;
  if p_action='predict_legacy_confirm' then
   source:=a->>'source_url';
   if jsonb_typeof(a->'source_url') is distinct from 'string' or source !~ '^https://[^[:space:]]+$' or length(source)>2000 then
    raise exception 'STAFF_COMMAND_ARGUMENTS_INVALID' using errcode='22023'; end if;
   return jsonb_build_object('home_score',h::integer,'away_score',v::integer,'source_url',source);
  end if;
  if (a?'ht_home_score' and jsonb_typeof(a->'ht_home_score') not in ('number','null'))
   or (a?'ht_away_score' and jsonb_typeof(a->'ht_away_score') not in ('number','null')) then
   raise exception 'STAFF_COMMAND_ARGUMENTS_INVALID' using errcode='22023'; end if;
  hh:=(a->>'ht_home_score')::numeric; vv:=(a->>'ht_away_score')::numeric;
  if (hh is null)<>(vv is null) or hh not between 0 and h or vv not between 0 and v or mod(hh,1)<>0 or mod(vv,1)<>0 then
   raise exception 'STAFF_COMMAND_ARGUMENTS_INVALID' using errcode='22023'; end if;
  return jsonb_build_object('home_score',h::integer,'away_score',v::integer,'ht_home_score',hh::integer,'ht_away_score',vv::integer);
 end if;
 raise exception 'STAFF_COMMAND_ACTION_INVALID' using errcode='22023';
end $$;

-- Every financial path follows operation mutex -> target -> account -> grant ->
-- session/proof. A revoke committed while target acquisition waits wins.
create function public.lock_verified_staff_command_resource(p_action text,p_resource uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare c bigint; f uuid;
begin
 if p_resource is null then raise exception 'STAFF_COMMAND_RESOURCE_INVALID' using errcode='22023'; end if;
 if p_action='fixture_settle' then
  perform 1 from football.fixtures where id=p_resource for update;
  if not found then raise exception 'SETTLEMENT_FIXTURE_NOT_FOUND' using errcode='P0002'; end if;
  return jsonb_build_object('club_id',null,'fixture_id',p_resource);
 elsif p_action='partner_legacy_settle' then
  select club_id,fixture_id into c,f from football.partner_prediction_pools where id=p_resource;
 else
  select club_id,fixture_id into c,f from football.predict_pools where id=p_resource and economics_version='legacy_paid_v1';
 end if;
 if c is null then raise exception 'PREDICT_LEGACY_POOL_REQUIRED'; end if;
 perform 1 from football.fixtures where id=f for share;
 if not found then raise exception 'PREDICT_LEGACY_POOL_REQUIRED'; end if;
 if p_action='partner_legacy_settle' then
  perform 1 from football.partner_prediction_pools where id=p_resource and club_id=c and fixture_id=f for update;
 else
  perform 1 from football.predict_pools where id=p_resource and club_id=c and fixture_id=f and economics_version='legacy_paid_v1' for update;
 end if;
 if not found then raise exception 'PREDICT_LEGACY_POOL_REQUIRED'; end if;
 return jsonb_build_object('club_id',c,'fixture_id',f);
end $$;

create function public.assert_verified_staff_actor(p_actor uuid,p_action text) returns uuid
language plpgsql security definer set search_path='' as $$
declare assignment uuid;
begin
 if p_actor is null then raise exception 'STAFF_COMMAND_ACTOR_REQUIRED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_actor::text,21000));
 if exists(select 1 from public.account_erasure_jobs where user_id=p_actor) or not exists(
  select 1 from auth.users where id=p_actor and not is_anonymous and deleted_at is null) then
  raise exception 'ACCOUNT_CLOSURE_PENDING' using errcode='42501'; end if;
 select id into assignment from public.admin_role_assignments where user_id=p_actor and is_active and revoked_at is null
  and role in ('admin','super_admin') order by id limit 1 for share;
 if assignment is null then
  raise exception using errcode='42501',message=case when p_action='fixture_settle' then 'SETTLEMENT_GLOBAL_ADMIN_REQUIRED' else 'PREDICT_GLOBAL_ADMIN_REQUIRED' end;
 end if;
 return assignment;
end $$;

create function public.admit_verified_staff_command(p_operation_id uuid,p_action text,p_resource_id uuid,p_arguments jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); a jsonb; resource jsonb; cmd public.verified_staff_commands; proof public.verified_staff_command_proofs;
 claims jsonb:=auth.jwt(); session uuid; jwt_exp bigint; mfa_time bigint; session_end timestamptz; deadline timestamptz;
 prior football.predict_service_operations; engine text; now_epoch numeric; amr jsonb; amr_time numeric;
begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then
  raise exception 'STAFF_COMMAND_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_staff_step_up();
 if p_operation_id is null or p_operation_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
  raise exception 'STAFF_COMMAND_OPERATION_INVALID' using errcode='22023'; end if;
 a:=public.verified_staff_command_arguments(p_action,p_arguments);
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21026));
 resource:=public.lock_verified_staff_command_resource(p_action,p_resource_id);
 perform public.assert_verified_staff_actor(actor,p_action);
 perform public.assert_staff_step_up();
 if coalesce(claims->>'session_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
  raise exception 'STAFF_COMMAND_SESSION_REQUIRED' using errcode='42501'; end if;
 session:=(claims->>'session_id')::uuid;
 select not_after into session_end from auth.sessions where id=session and user_id=actor and aal='aal2' for share;
 if not found or (session_end is not null and session_end<=clock_timestamp()) then
  raise exception 'STAFF_COMMAND_SESSION_REVOKED' using errcode='42501'; end if;
 -- This is the gateway-verified original JWT, never a service parameter.
 jwt_exp:=(claims->>'exp')::numeric::bigint; now_epoch:=extract(epoch from clock_timestamp());
 for amr in select value from jsonb_array_elements(claims->'amr') loop
  if amr->>'method' in ('totp','mfa/totp') and jsonb_typeof(amr->'timestamp')='number' then
   amr_time:=(amr->>'timestamp')::numeric;
   if amr_time between now_epoch-300 and now_epoch+30 and abs(amr_time)<=9007199254740991 and mod(amr_time,1)=0 then
    mfa_time:=greatest(mfa_time,amr_time::bigint);
   end if;
  end if;
 end loop;
 if mfa_time is null then raise exception 'STAFF_STEP_UP_REQUIRED' using errcode='42501'; end if;
 deadline:=least(to_timestamp(least(jwt_exp,mfa_time+300)::double precision),coalesce(session_end,'infinity'::timestamptz));
 if deadline<=clock_timestamp() then raise exception 'STAFF_COMMAND_ASSURANCE_EXPIRED' using errcode='42501'; end if;
 select * into cmd from public.verified_staff_commands where operation_id=p_operation_id for update;
 if found then
  if (cmd.actor_id,cmd.action,cmd.resource_id,cmd.club_id,cmd.arguments)
   is distinct from (actor,p_action,p_resource_id,(resource->>'club_id')::bigint,a) then
   raise exception 'STAFF_COMMAND_BINDING_MISMATCH'; end if;
  if cmd.result is not null then return jsonb_build_object('operation_id',p_operation_id,'actor_id',actor,'action',p_action,
   'resource_id',p_resource_id,'club_id',cmd.club_id,'status','completed','expires_at',null); end if;
 else
  -- Completed pre-forward receipts are preserved. Admission cannot reopen them.
  engine:=case p_action when 'predict_legacy_settle' then 'predict_settle' when 'predict_legacy_confirm' then 'predict_confirm' when 'partner_legacy_settle' then 'partner_settle' end;
  select * into prior from football.predict_service_operations where operation_id=p_operation_id for update;
  if found then
   if (prior.actor_id,prior.engine,prior.pool_id,prior.command_args) is distinct from (actor,engine,p_resource_id,a) then
    raise exception 'PREDICT_OPERATION_BINDING_MISMATCH'; end if;
   if prior.result is not null then return jsonb_build_object('operation_id',p_operation_id,'actor_id',actor,'action',p_action,
    'resource_id',p_resource_id,'club_id',(resource->>'club_id')::bigint,'status','completed','expires_at',null); end if;
  end if;
  insert into public.verified_staff_commands(operation_id,actor_id,action,resource_id,club_id,arguments,current_proof_id)
   values(p_operation_id,actor,p_action,p_resource_id,(resource->>'club_id')::bigint,a,gen_random_uuid()) returning * into cmd;
 end if;
 select * into proof from public.verified_staff_command_proofs where operation_id=p_operation_id and session_id=session
  and jwt_expires_at=jwt_exp and mfa_verified_at=mfa_time;
 if not found then
  if (select count(*) from public.verified_staff_command_proofs where operation_id=p_operation_id)>=32 then
   raise exception 'STAFF_COMMAND_PROOF_LIMIT' using errcode='54000'; end if;
  insert into public.verified_staff_command_proofs(operation_id,proof_id,session_id,jwt_expires_at,mfa_verified_at,expires_at)
   values(p_operation_id,case when not exists(select 1 from public.verified_staff_command_proofs where operation_id=p_operation_id)
    then cmd.current_proof_id else gen_random_uuid() end,session,jwt_exp,mfa_time,deadline) returning * into proof;
  update public.verified_staff_commands set current_proof_id=proof.proof_id where operation_id=p_operation_id;
 end if;
 perform public.assert_staff_step_up();
 if proof.expires_at<=clock_timestamp() then raise exception 'STAFF_COMMAND_ASSURANCE_EXPIRED' using errcode='42501'; end if;
 return jsonb_build_object('operation_id',p_operation_id,'actor_id',actor,'action',p_action,'resource_id',p_resource_id,
  'club_id',cmd.club_id,'status','admitted','expires_at',proof.expires_at);
end $$;

create function public.consume_verified_staff_command(p_operation_id uuid,p_action text,p_resource_id uuid,p_actor_id uuid,p_arguments jsonb)
returns public.verified_staff_commands language plpgsql security definer set search_path='' as $$
declare cmd public.verified_staff_commands; proof public.verified_staff_command_proofs; resource jsonb; session_end timestamptz;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'STAFF_COMMAND_SERVICE_REQUIRED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21026));
 resource:=public.lock_verified_staff_command_resource(p_action,p_resource_id);
 perform public.assert_verified_staff_actor(p_actor_id,p_action);
 select * into cmd from public.verified_staff_commands where operation_id=p_operation_id for update;
 if not found then raise exception 'STAFF_COMMAND_ADMISSION_REQUIRED' using errcode='42501'; end if;
 perform public.assert_verified_staff_actor(p_actor_id,p_action);
 if (cmd.actor_id,cmd.action,cmd.resource_id,cmd.club_id,cmd.arguments) is distinct from
  (p_actor_id,p_action,p_resource_id,(resource->>'club_id')::bigint,public.verified_staff_command_arguments(p_action,p_arguments)) then
  raise exception 'STAFF_COMMAND_BINDING_MISMATCH'; end if;
 if cmd.result is not null then return cmd; end if;
 select * into strict proof from public.verified_staff_command_proofs where operation_id=p_operation_id and proof_id=cmd.current_proof_id for share;
 select not_after into session_end from auth.sessions where id=proof.session_id and user_id=p_actor_id and aal='aal2' for share;
 if not found or (session_end is not null and session_end<=clock_timestamp()) then
  raise exception 'STAFF_COMMAND_SESSION_REVOKED' using errcode='42501'; end if;
 if proof.expires_at<=clock_timestamp() or proof.jwt_expires_at<=extract(epoch from clock_timestamp())
  or proof.mfa_verified_at<extract(epoch from clock_timestamp())-300 then
  raise exception 'STAFF_COMMAND_ASSURANCE_EXPIRED' using errcode='42501'; end if;
 return cmd;
end $$;

create function public.finish_verified_staff_command(p_operation_id uuid,p_action text,p_resource_id uuid,p_actor_id uuid,p_arguments jsonb,p_result jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare cmd public.verified_staff_commands;
begin
 cmd:=public.consume_verified_staff_command(p_operation_id,p_action,p_resource_id,p_actor_id,p_arguments);
 if cmd.result is not null then return cmd.result; end if;
 if jsonb_typeof(p_result) is distinct from 'object' or p_result->>'operation_id' is distinct from p_operation_id::text then
  raise exception 'STAFF_COMMAND_RECEIPT_INVALID'; end if;
 update public.verified_staff_commands set result=p_result,completed_at=clock_timestamp() where operation_id=p_operation_id;
 return p_result;
end $$;

create or replace function public.prediction_admin_settle_as_actor(
 p_fixture_id uuid,p_home_score integer,p_away_score integer,p_actor_id uuid,p_operation_id uuid,
 p_ht_home_score integer default null,p_ht_away_score integer default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare cmd public.verified_staff_commands; args jsonb; result jsonb; assignment uuid;
begin
 if coalesce(auth.role(),'')<>'service_role' or p_actor_id is null or p_operation_id is null then
  raise exception 'SETTLEMENT_AUTHORITY_REQUIRED' using errcode='42501'; end if;
 args:=public.verified_staff_command_arguments('fixture_settle',jsonb_build_object('home_score',p_home_score,'away_score',p_away_score,
  'ht_home_score',p_ht_home_score,'ht_away_score',p_ht_away_score));
 cmd:=public.consume_verified_staff_command(p_operation_id,'fixture_settle',p_fixture_id,p_actor_id,args);
 if cmd.result is not null then return cmd.result; end if;
 assignment:=public.assert_verified_staff_actor(p_actor_id,'fixture_settle');
 result:=public.prediction_admin_settle_internal(p_fixture_id,p_home_score,p_away_score,'finished',p_ht_home_score,p_ht_away_score);
 if result->>'status'<>'success' then raise exception 'SETTLEMENT_NOT_CONFIRMED'; end if;
 result:=result||jsonb_build_object('operation_id',p_operation_id);
 insert into public.admin_audit_log(actor_id,user_id,action,target_table,target_id,entity_type,entity_id,metadata)
  values(p_actor_id,p_actor_id,'prediction.global_fixture_settle','football.fixtures',p_fixture_id::text,'fixture',p_fixture_id::text,
   jsonb_build_object('operation_id',p_operation_id,'assignment_id',assignment,'home_score',p_home_score,'away_score',p_away_score,
    'verified_command',p_operation_id,'proof_id',cmd.current_proof_id));
 return public.finish_verified_staff_command(p_operation_id,'fixture_settle',p_fixture_id,p_actor_id,args,result);
end $$;

-- Preserve the public service identities and the private historical engine.
-- A stored pre-forward completed operation is read-only recovery; new effects
-- require actual caller admission. Claims below serve legacy tenant/account
-- checks only and explicitly do not fabricate assurance.
create or replace function public.predict_service_command_internal(
 p_engine text,p_pool_id uuid,p_actor_id uuid,p_operation_id uuid,p_args jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_club bigint; v_assignment uuid; v_result jsonb; v_op football.predict_service_operations;
 cmd public.verified_staff_commands; resource jsonb; action text;
 v_claims text:=coalesce(current_setting('request.jwt.claims',true),'');
 v_sub text:=coalesce(current_setting('request.jwt.claim.sub',true),'');
 v_role text:=coalesce(current_setting('request.jwt.claim.role',true),'');
begin
 perform public.assert_account_active();
 if coalesce(auth.role(),'')<>'service_role' or p_actor_id is null or p_operation_id is null
  or p_engine not in ('predict_settle','partner_settle','predict_confirm') then
  raise exception 'PREDICT_GLOBAL_SERVICE_REQUIRED' using errcode='42501'; end if;
 action:=case p_engine when 'predict_settle' then 'predict_legacy_settle' when 'predict_confirm' then 'predict_legacy_confirm' else 'partner_legacy_settle' end;
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21026));
 resource:=public.lock_verified_staff_command_resource(action,p_pool_id); v_club:=(resource->>'club_id')::bigint;
 v_assignment:=public.assert_verified_staff_actor(p_actor_id,action);
 select * into v_op from football.predict_service_operations where operation_id=p_operation_id for update;
 if found then
  v_assignment:=public.assert_verified_staff_actor(p_actor_id,action);
  if v_op.engine<>p_engine or v_op.pool_id<>p_pool_id or v_op.actor_id<>p_actor_id
   or v_op.command_args is distinct from p_args then raise exception 'PREDICT_OPERATION_BINDING_MISMATCH'; end if;
  if v_op.result is not null then return v_op.result; end if;
 end if;
 cmd:=public.consume_verified_staff_command(p_operation_id,action,p_pool_id,p_actor_id,p_args);
 if cmd.result is not null then return cmd.result; end if;
 insert into football.predict_service_operations(operation_id,engine,pool_id,actor_id,command_args)
  values(p_operation_id,p_engine,p_pool_id,p_actor_id,p_args) on conflict(operation_id) do nothing;
 -- Enter the preserved engine with its original actor/tenant semantics.
 perform set_config('request.jwt.claims',jsonb_build_object('sub',p_actor_id,'role','authenticated',
  'club_id',v_club,'app_metadata',jsonb_build_object('club_id',v_club))::text,true);
 perform set_config('request.jwt.claim.sub',p_actor_id::text,true);
 perform set_config('request.jwt.claim.role','authenticated',true);
 if p_engine='predict_settle' then v_result:=public.predict_legacy_paid_settle_internal(p_pool_id,p_args->>'void_reason');
 elsif p_engine='predict_confirm' then v_result:=public.predict_legacy_confirm_result_internal(p_pool_id,(p_args->>'home_score')::integer,
  (p_args->>'away_score')::integer,p_args->>'source_url');
 else v_result:=public.partner_prediction_pool_settle_legacy_internal(p_pool_id); end if;
 perform set_config('request.jwt.claims',v_claims,true); perform set_config('request.jwt.claim.sub',v_sub,true);
 perform set_config('request.jwt.claim.role',v_role,true);
 v_result:=v_result||jsonb_build_object('operation_id',p_operation_id,'economics_version','legacy_paid_v1');
 update football.predict_service_operations set result=v_result,completed_at=clock_timestamp() where operation_id=p_operation_id;
 insert into public.admin_audit_log(actor_id,user_id,action,target_table,target_id,club_id,metadata)
  values(p_actor_id,p_actor_id,'predict.global_service.'||p_engine,
   case when p_engine='partner_settle' then 'football.partner_prediction_pools' else 'football.predict_pools' end,
   p_pool_id::text,v_club,jsonb_build_object('operation_id',p_operation_id,'assignment_id',v_assignment,
    'economics_version','legacy_paid_v1','command_args',p_args,'verified_command',p_operation_id,'proof_id',cmd.current_proof_id));
 -- Recheck after every engine, receipt and audit write. A nested wait may
 -- outlast admission: denial rolls back all financial and acknowledgement rows.
 return public.finish_verified_staff_command(p_operation_id,action,p_pool_id,p_actor_id,p_args,v_result);
exception when others then
 perform set_config('request.jwt.claims',v_claims,true); perform set_config('request.jwt.claim.sub',v_sub,true);
 perform set_config('request.jwt.claim.role',v_role,true); raise;
end $$;

revoke all on function public.guard_verified_staff_command_immutable(),public.verified_staff_command_arguments(text,jsonb),
 public.lock_verified_staff_command_resource(text,uuid),public.assert_verified_staff_actor(uuid,text),
 public.admit_verified_staff_command(uuid,text,uuid,jsonb),
 public.consume_verified_staff_command(uuid,text,uuid,uuid,jsonb),
 public.finish_verified_staff_command(uuid,text,uuid,uuid,jsonb,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.admit_verified_staff_command(uuid,text,uuid,jsonb) to authenticated;
-- CREATE OR REPLACE preserves the four existing wrapper identities and ACLs.
-- The shared historical dispatcher remains private even to service callers.
revoke all on function public.predict_service_command_internal(text,uuid,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
commit;

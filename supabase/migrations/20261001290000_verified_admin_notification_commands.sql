-- Human commands use the private SQL28 verified provider-proof helpers.
-- One immutable original command; every device crosses a committed started barrier.
begin;
create table public.admin_notification_commands (
 operation_id uuid primary key,
 notification_id uuid not null unique references public.notifications(id) on delete restrict,
 actor_id uuid references auth.users(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 arguments jsonb not null, arguments_sha256 text not null check(arguments_sha256 ~ '^[0-9a-f]{64}$'),
 delivery_mode text not null check(delivery_mode in('send_now','schedule')),
 authority_kind text not null check(authority_kind in('human_immediate','scheduled','legacy_scheduled')),
 current_proof_id uuid,
 state text not null check(state in('admitted','scheduled','processing','completed','unknown','blocked')),
 lease_token uuid, lease_until timestamptz, lease_proof_id uuid,
 targets_initialized boolean not null default false,
 admitted_at timestamptz not null default clock_timestamp(),
 check((authority_kind='legacy_scheduled')=(current_proof_id is null)),
 check(authority_kind='legacy_scheduled' or (actor_id is not null and operation_id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
 check((lease_token is null)=(lease_until is null)),
 check(lease_token is null or authority_kind<>'human_immediate' or lease_proof_id is not null)
);
create table public.admin_notification_proofs (
 operation_id uuid not null references public.admin_notification_commands(operation_id) on delete restrict,
 proof_id uuid not null default gen_random_uuid(), proof jsonb not null,
 admitted_at timestamptz not null default clock_timestamp(),
 primary key(operation_id,proof_id),unique(operation_id,proof),
 check(jsonb_typeof(proof)='object' and proof-array['session_id','jwt_expires_at','mfa_verified_at','expires_at']='{}'::jsonb)
);
alter table public.admin_notification_commands add foreign key(operation_id,current_proof_id)
 references public.admin_notification_proofs(operation_id,proof_id) deferrable initially deferred;
alter table public.admin_notification_commands add foreign key(operation_id,lease_proof_id)
 references public.admin_notification_proofs(operation_id,proof_id) deferrable initially deferred;
create table public.admin_notification_devices (
 delivery_id uuid primary key default gen_random_uuid(),
 operation_id uuid not null references public.admin_notification_commands(operation_id) on delete restrict,
 token_id uuid not null, -- Tokens can be removed without deleting the duplicate barrier.
 target_user_sha256 text not null check(target_user_sha256 ~ '^[0-9a-f]{64}$'),
 token_sha256 text not null check(token_sha256 ~ '^[0-9a-f]{64}$'),
 state text not null default 'ready' check(state in('ready','started','accepted','rejected','unknown','skipped')),
 lease_token uuid, started_at timestamptz, completed_at timestamptz,
 provider_message_name text, error_code text check(error_code in('UNREGISTERED','NOT_FOUND','UNKNOWN')),
 cleaned_token boolean not null default false,
 unique(operation_id,token_id),
 check(state<>'ready' or (started_at is null and lease_token is null)),
 check(state<>'accepted' or (provider_message_name is not null and length(provider_message_name) between 1 and 512))
);
do $$ declare t text; begin
 foreach t in array array['admin_notification_commands','admin_notification_proofs','admin_notification_devices'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
  execute format('create trigger account_lifecycle_statement_guard before insert or update or delete on public.%I for each statement execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create trigger account_lifecycle_mutation_guard before insert or update or delete on public.%I for each row execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create policy account_lifecycle_access on public.%I as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed())',t);
 end loop;
end $$;
insert into public.account_erasure_fk_inventory(constraint_oid,child_table,subject_table,deletion_action,retained)
 select c.oid,c.conrelid::regclass::text,c.confrelid::regclass::text,c.confdeltype::text,true from pg_constraint c
 where c.contype='f' and c.conrelid='public.admin_notification_commands'::regclass and c.confrelid='auth.users'::regclass
 on conflict(constraint_oid) do nothing;
-- Human notifications are admitted atomically through the original command only.
-- Existing safe read projections and independent trusted service jobs are retained.
revoke insert,update,delete on public.notifications from authenticated;
alter table public.notifications drop constraint rs_notifications_status_check;
alter table public.notifications add constraint rs_notifications_status_check check(status=any(array['draft','scheduled','processing','sent','partial','failed','unknown']));

create function public.guard_admin_notification_immutable() returns trigger language plpgsql set search_path='' as $$ begin
 if TG_OP='DELETE' or TG_TABLE_NAME='admin_notification_proofs' then raise exception 'NOTIFICATION_COMMAND_IMMUTABLE'; end if;
 if TG_TABLE_NAME='admin_notification_commands' then
  if (new.operation_id,new.notification_id,new.actor_id,new.club_id,new.arguments,new.arguments_sha256,new.delivery_mode,new.authority_kind,new.admitted_at)
   is distinct from (old.operation_id,old.notification_id,old.actor_id,old.club_id,old.arguments,old.arguments_sha256,old.delivery_mode,old.authority_kind,old.admitted_at)
   or (old.state in('completed','unknown') and new is distinct from old) then raise exception 'NOTIFICATION_COMMAND_IMMUTABLE'; end if;
 else
  if (new.delivery_id,new.operation_id,new.token_id,new.target_user_sha256,new.token_sha256) is distinct from
   (old.delivery_id,old.operation_id,old.token_id,old.target_user_sha256,old.token_sha256)
   or (old.state in('accepted','rejected','unknown','skipped') and new is distinct from old)
   or (old.state='started' and new.state='ready') then raise exception 'NOTIFICATION_DEVICE_IMMUTABLE'; end if;
 end if; return new;
end $$;
create trigger notification_command_immutable before update or delete on public.admin_notification_commands for each row execute function public.guard_admin_notification_immutable();
create trigger notification_proof_immutable before update or delete on public.admin_notification_proofs for each row execute function public.guard_admin_notification_immutable();
create trigger notification_device_immutable before update or delete on public.admin_notification_devices for each row execute function public.guard_admin_notification_immutable();

create function public.admin_notification_canonical_json(p_arguments jsonb) returns text language sql immutable set search_path='' as $$
 select '{'||string_agg(to_json(key)::text||':'||value::text,',' order by key collate "C")||'}' from jsonb_each(p_arguments);
$$;

create function public.admin_notification_arguments(p_arguments jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare a jsonb:=p_arguments; k text; title text; body text; audience text; tier text; gid uuid; gn text; mode text; scheduled timestamptz; image text;
begin
 if jsonb_typeof(a) is distinct from 'object' or a-array['title','body','audience','tier','group_id','group_name','delivery_mode','scheduled_at','image_url']<>'{}'::jsonb then
  raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if;
 for k in select jsonb_object_keys(a) loop
  if jsonb_typeof(a->k) not in('string','null') then raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if;
 end loop;
 title:=trim(a->>'title');body:=trim(a->>'body');audience:=a->>'audience';mode:=a->>'delivery_mode';image:=nullif(trim(a->>'image_url'),'');
 if title is null or length(title) not between 1 and 120 or body is null or length(body) not between 1 and 500
  or audience is null or mode is null or audience not in('all_fans','by_tier','by_group') or mode not in('send_now','schedule')
  or (image is not null and (length(image)>2048 or image !~ '^https?://[^[:space:]]+$')) then
  raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if;
 if audience='by_tier' then tier:=a->>'tier'; if tier is null or tier not in('fan','bronze','gold','platinum') then raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if; end if;
 if audience='by_group' then
  if coalesce(a->>'group_id','') !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if;
  gid:=(a->>'group_id')::uuid;gn:=nullif(trim(a->>'group_name'),'');
  if length(gn)>160 then raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if;
 end if;
 if mode='schedule' then
  if a->>'scheduled_at' is null then raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if;
  begin scheduled:=(a->>'scheduled_at')::timestamptz;
  exception when others then raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end;
  if not isfinite(scheduled) then raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if;
 end if;
 a:=jsonb_build_object('title',title,'body',body,'audience',audience,'tier',tier,'group_id',gid,'group_name',gn,'delivery_mode',mode,
  'scheduled_at',case when scheduled is not null then to_char(scheduled at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') end,'image_url',image);
 if octet_length(public.admin_notification_canonical_json(a))>4096 then raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if;
 return a;
end $$;

create function public.admin_notification_receipt(p_cmd public.admin_notification_commands) returns jsonb
language sql volatile security definer set search_path='' as $$
 with devices as(select *,case when state='started' and (p_cmd).lease_until<=clock_timestamp() then 'unknown' else state end effective_state
  from public.admin_notification_devices where operation_id=(p_cmd).operation_id),
 totals as(select count(*) filter(where effective_state='accepted')::integer sent,
  count(*) filter(where effective_state in('rejected','skipped'))::integer failed,
  count(*) filter(where effective_state='unknown')::integer unknowns,
  count(*) filter(where effective_state in('ready','started'))::integer pending,
  count(*) filter(where cleaned_token)::integer cleaned,count(distinct target_user_sha256)::integer recipients from devices),
 per_users as(select bool_or(effective_state='accepted') ok,bool_or(effective_state in('ready','started','unknown')) uncertain from devices group by target_user_sha256),
 users as(select count(*) filter(where ok)::integer success,count(*) filter(where not ok and not uncertain)::integer failed from per_users),
 stats as(select totals.*,users.success,users.failed failed_users,
  case when (p_cmd).state='scheduled' then 'scheduled' when totals.unknowns>0 then 'unknown'
   when totals.pending>0 or (p_cmd).state in('admitted','processing','blocked') then 'processing'
   when totals.sent>0 and totals.failed=0 then 'sent' when totals.sent>0 then 'partial' else 'failed' end delivery_status from totals cross join users)
 select jsonb_build_object('command',jsonb_build_object('version',1,'operation_id',(p_cmd).operation_id,'actor_id',(p_cmd).actor_id,'club_id',(p_cmd).club_id,
  'arguments_sha256',(p_cmd).arguments_sha256,'notification_id',(p_cmd).notification_id,'delivery_mode',(p_cmd).delivery_mode,'state',(p_cmd).state),
  'notification',to_jsonb(n)||jsonb_build_object('status',stats.delivery_status),'delivery',jsonb_build_object('status',stats.delivery_status,'requested_recipient_count',stats.recipients,
  'successful_user_count',stats.success,'failed_user_count',stats.failed_users,'sent_count',stats.sent,'failed_count',stats.failed,
  'cleaned_tokens',stats.cleaned,'unknown_count',stats.unknowns,'pending_count',stats.pending,'scheduled_at',n.scheduled_at))
 from public.notifications n cross join stats where n.id=(p_cmd).notification_id;
$$;

create function public.admit_admin_notification(p_operation_id uuid,p_club_id bigint,p_arguments jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); a jsonb; hash text; cmd public.admin_notification_commands; v_proof jsonb; pid uuid; nid uuid;
begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then raise exception 'NOTIFICATION_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_account_active();perform public.assert_staff_step_up();
 if p_operation_id is null or p_operation_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'NOTIFICATION_OPERATION_INVALID' using errcode='22023'; end if;
 a:=public.admin_notification_arguments(p_arguments);hash:=encode(extensions.digest(convert_to(public.admin_notification_canonical_json(a),'UTF8'),'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21029));
 select * into cmd from public.admin_notification_commands where operation_id=p_operation_id for update;
 if found and (cmd.actor_id,cmd.club_id,cmd.arguments) is distinct from (actor,p_club_id,a) then raise exception 'NOTIFICATION_COMMAND_BINDING_MISMATCH'; end if;
 if a->>'audience'='by_group' then
  perform 1 from public.groups where id=(a->>'group_id')::uuid and club_id=p_club_id and is_active and not is_closed for share;
  if not found then raise exception 'NOTIFICATION_GROUP_UNAVAILABLE' using errcode='42501'; end if;
 end if;
 v_proof:=public.capture_verified_staff_provider_proof(p_club_id,true);
 perform public.assert_admin_notification_feature(p_club_id);
 if cmd.operation_id is not null and cmd.state in('completed','unknown') then return public.admin_notification_receipt(cmd); end if;
 if cmd.operation_id is null then
  insert into public.notifications(club_id,created_by,title,body,image_url,audience_type,audience_tier,audience_group_id,audience_group_name,delivery_mode,scheduled_at,status)
   values(p_club_id,actor,a->>'title',a->>'body',a->>'image_url',a->>'audience',a->>'tier',(a->>'group_id')::uuid,a->>'group_name',a->>'delivery_mode',
    (a->>'scheduled_at')::timestamptz,case when a->>'delivery_mode'='schedule' then 'scheduled' else 'processing' end) returning id into nid;
  pid:=gen_random_uuid();
  insert into public.admin_notification_commands(operation_id,notification_id,actor_id,club_id,arguments,arguments_sha256,delivery_mode,authority_kind,current_proof_id,state)
   values(p_operation_id,nid,actor,p_club_id,a,hash,a->>'delivery_mode',case when a->>'delivery_mode'='schedule' then 'scheduled' else 'human_immediate' end,pid,
    case when a->>'delivery_mode'='schedule' then 'scheduled' else 'admitted' end) returning * into cmd;
 end if;
 select proof_id into pid from public.admin_notification_proofs where operation_id=p_operation_id and admin_notification_proofs.proof=v_proof;
 if not found then
  if (select count(*) from public.admin_notification_proofs where operation_id=p_operation_id)>=32 then raise exception 'NOTIFICATION_PROOF_LIMIT' using errcode='54000'; end if;
  pid:=case when not exists(select 1 from public.admin_notification_proofs where operation_id=p_operation_id) then cmd.current_proof_id else gen_random_uuid() end;
  insert into public.admin_notification_proofs(operation_id,proof_id,proof) values(p_operation_id,pid,v_proof);
 end if;
 update public.admin_notification_commands set current_proof_id=pid,state=case when state='blocked' then 'admitted' else state end where operation_id=p_operation_id returning * into cmd;
 perform public.assert_verified_staff_provider_proof(actor,p_club_id,true,v_proof);
 return public.admin_notification_receipt(cmd)||case when cmd.authority_kind='human_immediate' then jsonb_build_object('dispatch_proof_id',pid) else '{}'::jsonb end;
end $$;

create function public.recover_admin_notification(p_operation_id uuid,p_club_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare cmd public.admin_notification_commands; v_proof jsonb; actor uuid:=auth.uid();
begin
 if auth.role() is distinct from 'authenticated' or current_setting('role',true)='service_role' then raise exception 'NOTIFICATION_CALLER_REQUIRED' using errcode='42501'; end if;
 perform public.assert_account_active();perform public.assert_staff_step_up();
 if p_operation_id is null or p_operation_id::text !~ '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'NOTIFICATION_OPERATION_INVALID' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21029));
 select * into cmd from public.admin_notification_commands where operation_id=p_operation_id for share;
 v_proof:=public.capture_verified_staff_provider_proof(p_club_id,true);
 if cmd.operation_id is null then return jsonb_build_object('command',jsonb_build_object('version',1,'operation_id',p_operation_id,'actor_id',actor,
  'club_id',p_club_id,'arguments_sha256',null,'notification_id',null,'delivery_mode',null,'state','not_admitted'),'notification',null,'delivery',null); end if;
 if (cmd.actor_id,cmd.club_id) is distinct from (actor,p_club_id) then raise exception 'NOTIFICATION_COMMAND_BINDING_MISMATCH'; end if;
 perform public.assert_verified_staff_provider_proof(actor,p_club_id,true,v_proof);
 return public.admin_notification_receipt(cmd);
end $$;

create function public.assert_admin_notification_feature(p_club bigint) returns void language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.african_football_clubs where id=p_club and is_active for share;
 if not found then raise exception 'NOTIFICATION_CLUB_UNAVAILABLE' using errcode='42501'; end if;
 perform 1 from public.platform_features where public.canonicalize_platform_feature_key(feature_key)='notifications' and (club_id is null or club_id=p_club) for share;
 perform 1 from public.platform_feature_channels where feature_id in(select id from public.platform_features where public.canonicalize_platform_feature_key(feature_key)='notifications' and (club_id is null or club_id=p_club)) for share;
 perform 1 from public.platform_feature_rules where feature_id in(select id from public.platform_features where public.canonicalize_platform_feature_key(feature_key)='notifications' and (club_id is null or club_id=p_club)) for share;
 if (public.get_feature_access_state('notifications','mobile',p_club,true,array['admin','super_admin'])->>'is_available')::boolean is distinct from true then
  raise exception 'NOTIFICATION_FEATURE_UNAVAILABLE' using errcode='42501'; end if;
end $$;

create function public.assert_admin_notification_dispatch_authority(p_cmd public.admin_notification_commands) returns timestamptz
language plpgsql security definer set search_path='' as $$ declare p jsonb; begin
 perform public.assert_admin_notification_feature(p_cmd.club_id);
 if p_cmd.authority_kind='human_immediate' then
  select proof into strict p from public.admin_notification_proofs where operation_id=p_cmd.operation_id and proof_id=case when p_cmd.lease_token is not null then p_cmd.lease_proof_id else p_cmd.current_proof_id end for share;
  perform public.assert_verified_staff_provider_proof(p_cmd.actor_id,p_cmd.club_id,true,p);
  return (p->>'expires_at')::timestamptz;
 end if;
 -- A scheduled job was independently committed while its human creator was
 -- authorized. Cron executes that stored job; it never renews a human proof.
 if p_cmd.delivery_mode is distinct from 'schedule' or (p_cmd.arguments->>'scheduled_at')::timestamptz>clock_timestamp() then
  raise exception 'NOTIFICATION_JOB_NOT_DUE' using errcode='42501'; end if;
 return clock_timestamp()+interval '60 seconds';
end $$;

create function public.initialize_admin_notification_targets(p_cmd public.admin_notification_commands) returns void
language plpgsql security definer set search_path='' as $$ begin
 -- Preserve existing bounded recipient/device limits before freezing target IDs.
 if (select count(*) from public.user_fcm_tokens where club_id=p_cmd.club_id)>500
  or (select count(*) from public.user_notification_settings where club_id=p_cmd.club_id and push_enabled)>500
  or exists(select 1 from public.user_fcm_tokens where club_id=p_cmd.club_id group by user_id having count(*)>20) then
  raise exception 'NOTIFICATION_TARGET_BUDGET_EXCEEDED' using errcode='54000'; end if;
 insert into public.admin_notification_devices(operation_id,token_id,target_user_sha256,token_sha256)
 select p_cmd.operation_id,t.id,encode(extensions.digest(convert_to(t.user_id::text,'UTF8'),'sha256'),'hex'),
  encode(extensions.digest(convert_to(t.token,'UTF8'),'sha256'),'hex')
 from public.user_fcm_tokens t join public.user_notification_settings s on s.user_id=t.user_id and s.club_id=p_cmd.club_id and s.push_enabled
 join auth.users u on u.id=t.user_id and u.deleted_at is null and (u.banned_until is null or u.banned_until<=clock_timestamp())
 where t.club_id=p_cmd.club_id and length(t.token) between 1 and 4096
 and not exists(select 1 from public.account_erasure_jobs where user_id=t.user_id)
 and (p_cmd.arguments->>'audience'='all_fans'
  or (p_cmd.arguments->>'audience'='by_tier' and exists(select 1 from public.fan_memberships m where m.user_id=t.user_id and m.club_id=p_cmd.club_id and m.tier=p_cmd.arguments->>'tier'))
  or (p_cmd.arguments->>'audience'='by_group' and exists(select 1 from public.group_members m join public.groups g on g.id=m.group_id
    where m.user_id=t.user_id and m.group_id=(p_cmd.arguments->>'group_id')::uuid and g.club_id=p_cmd.club_id and g.is_active and not g.is_closed)))
 on conflict(operation_id,token_id) do nothing;
 update public.admin_notification_commands set targets_initialized=true where operation_id=p_cmd.operation_id;
end $$;

create function public.list_due_admin_notification_commands(p_limit integer default 25) returns jsonb
language plpgsql security definer set search_path='' as $$ begin
 if auth.role() is distinct from 'service_role' then raise exception 'NOTIFICATION_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_limit is null or p_limit not between 1 and 50 then raise exception 'NOTIFICATION_LIMIT_INVALID' using errcode='22023'; end if;
 return coalesce((select jsonb_agg(jsonb_build_object('operation_id',operation_id)) from
  (select operation_id from public.admin_notification_commands where authority_kind in('scheduled','legacy_scheduled') and state in('scheduled','processing')
   and (arguments->>'scheduled_at')::timestamptz<=clock_timestamp() and (lease_until is null or lease_until<=clock_timestamp())
   order by (arguments->>'scheduled_at')::timestamptz,operation_id limit p_limit) due),'[]'::jsonb);
end $$;

-- Human workers match admission's actor-before-operation order. Device claims
-- also lock their bounded recipient set before any command/row lock; two human
-- creators who are each other's recipients must acquire the same ordered keys.
-- These early locks grant no authority: all original proof, current grant,
-- session and recipient eligibility checks still run after the command waits.
create function public.lock_admin_notification_command(p_operation_id uuid,p_lock_recipients boolean default false) returns uuid[]
language plpgsql security definer set search_path='' as $$
declare v_actor uuid;v_kind text;v_club bigint;v_current_actor uuid;v_current_kind text;v_current_club bigint;
 v_users uuid[];v_key bigint;
begin
 select c.actor_id,c.authority_kind,c.club_id into v_actor,v_kind,v_club
  from public.admin_notification_commands c where c.operation_id=p_operation_id;
 if not found then raise exception 'NOTIFICATION_ADMISSION_REQUIRED' using errcode='42501'; end if;
 if p_lock_recipients is null then raise exception 'NOTIFICATION_ARGUMENTS_INVALID' using errcode='22023'; end if;
 select coalesce(array_agg(u.id order by u.id),'{}'::uuid[]) into v_users from (
  select v_actor id where v_kind='human_immediate'
  union
  select t.user_id from public.admin_notification_devices d join public.user_fcm_tokens t on t.id=d.token_id
   where p_lock_recipients and d.operation_id=p_operation_id and d.state='ready' and t.club_id=v_club
    and encode(extensions.digest(convert_to(t.token,'UTF8'),'sha256'),'hex')=d.token_sha256
    and encode(extensions.digest(convert_to(t.user_id::text,'UTF8'),'sha256'),'hex')=d.target_user_sha256
 )u;
 if cardinality(v_users)>501 then raise exception 'NOTIFICATION_TARGET_BUDGET_EXCEEDED' using errcode='54000'; end if;
 -- Order actual advisory keys, including any hash collision, consistently.
 for v_key in select distinct hashtextextended(u.id::text,21000) from unnest(v_users)u(id) order by 1 loop
  perform pg_advisory_xact_lock(v_key);
 end loop;
 perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,21029));
 select c.actor_id,c.authority_kind,c.club_id into v_current_actor,v_current_kind,v_current_club
  from public.admin_notification_commands c where c.operation_id=p_operation_id for update;
 if not found or (v_current_actor,v_current_kind,v_current_club) is distinct from (v_actor,v_kind,v_club) then
  raise exception 'NOTIFICATION_COMMAND_BINDING_MISMATCH'; end if;
 return v_users;
end $$;

create function public.claim_admin_notification_command(p_operation_id uuid,p_lease_token uuid,p_proof_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare cmd public.admin_notification_commands; deadline timestamptz;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'NOTIFICATION_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_lease_token is null then raise exception 'NOTIFICATION_LEASE_INVALID' using errcode='22023'; end if;
 perform public.lock_admin_notification_command(p_operation_id);
 select * into cmd from public.admin_notification_commands where operation_id=p_operation_id for update;
 if not found then raise exception 'NOTIFICATION_ADMISSION_REQUIRED' using errcode='42501'; end if;
 if cmd.state in('completed','unknown','blocked') or cmd.lease_until>clock_timestamp() then return jsonb_build_object('claimed',false); end if;
 -- A replacement worker consumes the newly reviewed proof, not the expired
 -- previous lease proof. Existing started device barriers remain unreplayable.
 cmd.lease_token:=null;cmd.lease_until:=null;cmd.lease_proof_id:=null;
 if cmd.authority_kind='human_immediate' then
  if p_proof_id is null or not exists(select 1 from public.admin_notification_proofs where operation_id=p_operation_id and proof_id=p_proof_id) then
   raise exception 'NOTIFICATION_ORIGINAL_PROOF_REQUIRED' using errcode='42501'; end if;
  cmd.current_proof_id:=p_proof_id;
 elsif p_proof_id is not null then raise exception 'NOTIFICATION_CRON_PROOF_INVALID' using errcode='22023'; end if;
 deadline:=least(clock_timestamp()+interval '60 seconds',public.assert_admin_notification_dispatch_authority(cmd));
 if deadline<=clock_timestamp() then raise exception 'NOTIFICATION_ASSURANCE_EXPIRED' using errcode='42501'; end if;
 -- A crashed worker can never reclaim a started device, even when its response
 -- was lost before the provider received it. Only never-started rows are eligible.
 update public.admin_notification_devices set state='unknown',error_code='UNKNOWN',completed_at=clock_timestamp()
  where operation_id=p_operation_id and state='started';
 if not cmd.targets_initialized then perform public.initialize_admin_notification_targets(cmd); end if;
 perform public.assert_admin_notification_dispatch_authority(cmd);
 update public.admin_notification_commands set state='processing',lease_token=p_lease_token,lease_until=deadline,lease_proof_id=case when authority_kind='human_immediate' then p_proof_id end
  where operation_id=p_operation_id returning * into cmd;
 update public.notifications set status='processing',last_error=null,updated_at=clock_timestamp() where id=cmd.notification_id;
 -- The notification row may have been locked by another writer. A successful
 -- claim must still own the original proof and unexpired lease after that wait.
 perform public.assert_admin_notification_dispatch_authority(cmd);
 if cmd.lease_until<=clock_timestamp() then raise exception 'NOTIFICATION_LEASE_LOST' using errcode='42501'; end if;
 return jsonb_build_object('claimed',true,'operation_id',cmd.operation_id,'actor_id',cmd.actor_id,'club_id',cmd.club_id,
  'notification_id',cmd.notification_id,'arguments',cmd.arguments,'arguments_sha256',cmd.arguments_sha256,
  'lease_token',p_lease_token,'lease_expires_at',cmd.lease_until,'authority_kind',cmd.authority_kind,'lease_proof_id',cmd.lease_proof_id);
end $$;

create function public.claim_admin_notification_device(p_operation_id uuid,p_lease_token uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare cmd public.admin_notification_commands; d public.admin_notification_devices; t public.user_fcm_tokens; deadline timestamptz; eligible boolean; locked_users uuid[];
begin
 if auth.role() is distinct from 'service_role' then raise exception 'NOTIFICATION_SERVICE_REQUIRED' using errcode='42501'; end if;
 locked_users:=public.lock_admin_notification_command(p_operation_id,true);
 select * into strict cmd from public.admin_notification_commands where operation_id=p_operation_id for update;
 if cmd.state<>'processing' or cmd.lease_token is distinct from p_lease_token or cmd.lease_until<=clock_timestamp() then raise exception 'NOTIFICATION_LEASE_LOST' using errcode='42501'; end if;
 deadline:=least(cmd.lease_until,public.assert_admin_notification_dispatch_authority(cmd));
 loop
  select * into d from public.admin_notification_devices where operation_id=p_operation_id and state='ready' order by delivery_id limit 1 for update;
  if not found then return null; end if;
  select * into t from public.user_fcm_tokens where id=d.token_id and club_id=cmd.club_id;
  eligible:=found and encode(extensions.digest(convert_to(t.token,'UTF8'),'sha256'),'hex')=d.token_sha256
   and encode(extensions.digest(convert_to(t.user_id::text,'UTF8'),'sha256'),'hex')=d.target_user_sha256;
  if eligible then
   -- A concurrent target/token change cannot introduce a later out-of-order
   -- lifecycle lock. A fresh read-only retry may rebuild the original lock set.
   if not(t.user_id=any(locked_users)) then raise exception 'NOTIFICATION_RECIPIENT_SNAPSHOT_CHANGED' using errcode='42501'; end if;
   select * into t from public.user_fcm_tokens where id=d.token_id and club_id=cmd.club_id
    and encode(extensions.digest(convert_to(token,'UTF8'),'sha256'),'hex')=d.token_sha256
    and encode(extensions.digest(convert_to(user_id::text,'UTF8'),'sha256'),'hex')=d.target_user_sha256 for share;
   eligible:=found;
   perform 1 from public.user_notification_settings where user_id=t.user_id and club_id=cmd.club_id and push_enabled for share;
   eligible:=eligible and found and not exists(select 1 from public.account_erasure_jobs where user_id=t.user_id)
    and exists(select 1 from auth.users where id=t.user_id and deleted_at is null and (banned_until is null or banned_until<=clock_timestamp()));
   if eligible and cmd.arguments->>'audience'='by_tier' then
    perform 1 from public.fan_memberships where user_id=t.user_id and club_id=cmd.club_id and tier=cmd.arguments->>'tier' for share; eligible:=found;
   elsif eligible and cmd.arguments->>'audience'='by_group' then
    perform 1 from public.group_members m join public.groups g on g.id=m.group_id where m.user_id=t.user_id
     and m.group_id=(cmd.arguments->>'group_id')::uuid and g.club_id=cmd.club_id and g.is_active and not g.is_closed for share;eligible:=found;
   end if;
  end if;
  -- These checks occur after all recipient/account/config row waits.
  deadline:=least(cmd.lease_until,public.assert_admin_notification_dispatch_authority(cmd));
  if deadline<=clock_timestamp() then raise exception 'NOTIFICATION_LEASE_LOST' using errcode='42501'; end if;
  if not eligible then update public.admin_notification_devices set state='skipped',completed_at=clock_timestamp() where delivery_id=d.delivery_id;continue; end if;
  update public.admin_notification_devices set state='started',lease_token=p_lease_token,started_at=clock_timestamp() where delivery_id=d.delivery_id;
  return jsonb_build_object('operation_id',p_operation_id,'lease_token',p_lease_token,'delivery_id',d.delivery_id,'token_id',t.id,'target_user_id',t.user_id,
   'notification_id',cmd.notification_id,'club_id',cmd.club_id,'audience_type',cmd.arguments->>'audience','audience_tier',cmd.arguments->>'tier',
   'audience_group_id',cmd.arguments->>'group_id','token',t.token,'title',cmd.arguments->>'title','body',cmd.arguments->>'body','image_url',cmd.arguments->>'image_url','deadline_at',deadline);
 end loop;
end $$;

create function public.complete_admin_notification_device(p_operation_id uuid,p_lease_token uuid,p_delivery_id uuid,p_outcome text,p_provider_message_name text default null,p_error_code text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare cmd public.admin_notification_commands; d public.admin_notification_devices; cleaned boolean:=false;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'NOTIFICATION_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_outcome not in('accepted','rejected','unknown') or (p_outcome='accepted' and (p_provider_message_name is null or length(p_provider_message_name) not between 1 and 512))
  or (p_error_code is not null and p_error_code not in('UNREGISTERED','NOT_FOUND','UNKNOWN')) then raise exception 'NOTIFICATION_DEVICE_RESULT_INVALID' using errcode='22023'; end if;
 perform public.lock_admin_notification_command(p_operation_id);
 select * into strict cmd from public.admin_notification_commands where operation_id=p_operation_id for update;
 select * into strict d from public.admin_notification_devices where operation_id=p_operation_id and delivery_id=p_delivery_id for update;
 if cmd.state<>'processing' or cmd.lease_token is distinct from p_lease_token or cmd.lease_until<=clock_timestamp()
  or d.state<>'started' or d.lease_token is distinct from p_lease_token then raise exception 'NOTIFICATION_LEASE_LOST' using errcode='42501'; end if;
 perform public.assert_admin_notification_dispatch_authority(cmd);
 if p_outcome='rejected' and p_error_code in('UNREGISTERED','NOT_FOUND') then
  delete from public.user_fcm_tokens where id=d.token_id and club_id=cmd.club_id and encode(extensions.digest(convert_to(token,'UTF8'),'sha256'),'hex')=d.token_sha256;
  cleaned:=found;
 end if;
 -- Cleanup may wait for a token/closure row. Recheck original authority after it.
 perform public.assert_admin_notification_dispatch_authority(cmd);
 if cmd.lease_until<=clock_timestamp() then raise exception 'NOTIFICATION_LEASE_LOST' using errcode='42501'; end if;
 update public.admin_notification_devices set state=p_outcome,completed_at=clock_timestamp(),provider_message_name=case when p_outcome='accepted' then p_provider_message_name end,
  error_code=case when p_outcome<>'accepted' then coalesce(p_error_code,'UNKNOWN') end,cleaned_token=cleaned where delivery_id=p_delivery_id;
 return jsonb_build_object('recorded',true);
end $$;

create function public.finish_admin_notification_command(p_operation_id uuid,p_lease_token uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare cmd public.admin_notification_commands; accepted integer; rejected integer; unknowns integer; pending integer; cleaned integer; recipients integer;
 success_users integer; failed_users integer; delivery_status text; command_state text;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'NOTIFICATION_SERVICE_REQUIRED' using errcode='42501'; end if;
 perform public.lock_admin_notification_command(p_operation_id);
 select * into strict cmd from public.admin_notification_commands where operation_id=p_operation_id for update;
 if cmd.state<>'processing' or cmd.lease_token is distinct from p_lease_token or cmd.lease_until<=clock_timestamp() then raise exception 'NOTIFICATION_LEASE_LOST' using errcode='42501'; end if;
 perform public.assert_admin_notification_dispatch_authority(cmd);
 update public.admin_notification_devices set state='unknown',completed_at=clock_timestamp(),error_code='UNKNOWN' where operation_id=p_operation_id and state='started' and lease_token=p_lease_token;
 select count(*) filter(where state='accepted'),count(*) filter(where state in('rejected','skipped')),count(*) filter(where state='unknown'),count(*) filter(where state='ready'),count(*) filter(where cleaned_token),count(distinct target_user_sha256)
  into accepted,rejected,unknowns,pending,cleaned,recipients from public.admin_notification_devices where operation_id=p_operation_id;
 select count(*) filter(where has_accepted),count(*) filter(where not has_accepted and not has_unknown and not has_pending) into success_users,failed_users from
  (select bool_or(state='accepted') has_accepted,bool_or(state='unknown') has_unknown,bool_or(state='ready') has_pending
   from public.admin_notification_devices where operation_id=p_operation_id group by target_user_sha256) per_user;
 delivery_status:=case when unknowns>0 then 'unknown' when pending>0 then 'processing' when accepted>0 and rejected=0 then 'sent' when accepted>0 then 'partial' else 'failed' end;
 command_state:=case when pending>0 then 'processing' when unknowns>0 then 'unknown' else 'completed' end;
 update public.notifications set status=delivery_status,requested_recipient_count=recipients,successful_user_count=success_users,failed_user_count=failed_users,
  sent_count=accepted,failed_count=rejected,cleaned_tokens=cleaned,delivery_summary=jsonb_build_object('unknown_count',unknowns,'pending_count',pending),
  sent_at=case when pending=0 then clock_timestamp() else sent_at end,updated_at=clock_timestamp(),last_error=case when unknowns>0 then 'Some device outcomes could not be confirmed. They will not be resent.' end
  where id=cmd.notification_id;
 perform public.assert_admin_notification_dispatch_authority(cmd);
 if cmd.lease_until<=clock_timestamp() then raise exception 'NOTIFICATION_LEASE_LOST' using errcode='42501'; end if;
 update public.admin_notification_commands set state=command_state,lease_token=null,lease_until=null,lease_proof_id=null where operation_id=p_operation_id returning * into cmd;
 return public.admin_notification_receipt(cmd);
end $$;

-- Freeze existing queued jobs under their already committed service scheduling
-- authority. Preserve all existing notification identifiers, content and dates.
insert into public.admin_notification_commands(operation_id,notification_id,actor_id,club_id,arguments,arguments_sha256,delivery_mode,authority_kind,state)
 select n.id,n.id,n.created_by,n.club_id,a.value,encode(extensions.digest(convert_to(public.admin_notification_canonical_json(a.value),'UTF8'),'sha256'),'hex'),
  'schedule','legacy_scheduled','scheduled'
 from public.notifications n cross join lateral(select public.admin_notification_arguments(jsonb_build_object('title',n.title,'body',n.body,'audience',n.audience_type,
 'tier',n.audience_tier,'group_id',n.audience_group_id,'group_name',n.audience_group_name,'delivery_mode','schedule','scheduled_at',n.scheduled_at,'image_url',n.image_url)) value) a
 where n.status='scheduled' and n.delivery_mode='schedule' and n.scheduled_at is not null;

-- Private engines and helpers have no direct execute capability in any app role.
do $$ declare f regprocedure; begin
 for f in select p.oid::regprocedure from pg_proc p join pg_namespace ns on ns.oid=p.pronamespace where ns.nspname='public' and p.proname in(
  'guard_admin_notification_immutable','admin_notification_arguments','admin_notification_canonical_json','admin_notification_receipt',
  'assert_admin_notification_feature','assert_admin_notification_dispatch_authority','initialize_admin_notification_targets','lock_admin_notification_command',
  'admit_admin_notification','recover_admin_notification','list_due_admin_notification_commands','claim_admin_notification_command',
  'claim_admin_notification_device','complete_admin_notification_device','finish_admin_notification_command') loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f);
 end loop;
end $$;
grant execute on function public.admit_admin_notification(uuid,bigint,jsonb),public.recover_admin_notification(uuid,bigint) to authenticated;
grant execute on function public.list_due_admin_notification_commands(integer),public.claim_admin_notification_command(uuid,uuid,uuid),public.claim_admin_notification_device(uuid,uuid),
 public.complete_admin_notification_device(uuid,uuid,uuid,text,text,text),public.finish_admin_notification_command(uuid,uuid) to service_role;
commit;

begin;

-- Version existing liabilities without changing any amount or outcome.
alter table football.predict_pools add column economics_version text not null default 'legacy_paid_v1';
alter table football.predict_entries add column economics_version text not null default 'legacy_paid_v1';
alter table football.predict_entries add column score_points integer not null default 0;
alter table football.predict_pools alter column economics_version set default 'free_v1';
alter table football.predict_entries alter column economics_version set default 'free_v1';
alter table football.predict_settings drop constraint predict_settings_entry_fet_check;
alter table football.predict_settings add constraint predict_settings_entry_fet_check check (entry_fet between 0 and 100000);
alter table football.predict_settings alter column entry_fet set default 0;
alter table football.predict_settings alter column welcome_fet set default 0;
alter table football.predict_pools drop constraint predict_pools_stake_fet_check;
alter table football.predict_pools add constraint predict_pools_economics_check check (
  (economics_version='legacy_paid_v1' and stake_fet between 1 and 100000)
  or (economics_version='free_v1' and stake_fet=0 and staked_fet=0 and paid_fet=0)
);
alter table football.predict_pools add constraint predict_pool_version_identity unique(id,club_id,economics_version);
alter table football.predict_entries drop constraint predict_entries_stake_fet_check;
alter table football.predict_entries add constraint predict_entries_economics_check check (
  (economics_version='legacy_paid_v1' and stake_fet>0 and score_points=0)
  or (economics_version='free_v1' and stake_fet=0 and payout_fet=0
    and score_points=case when outcome='won' then 1 else 0 end)
);
alter table football.predict_entries add constraint predict_entry_pool_version
  foreign key(pool_id,club_id,economics_version) references football.predict_pools(id,club_id,economics_version);

-- Rename the installed historical bodies, including the lifecycle guard injected
-- by the prior migration. Their financial algorithms and prior rows remain intact.
alter function public.predict_admin_settle(uuid,text) rename to predict_legacy_paid_settle_internal;
alter function public.predict_admin_confirm_result(uuid,integer,integer,text) rename to predict_legacy_confirm_result_internal;
alter function public.partner_prediction_pool_settle(uuid) rename to partner_prediction_pool_settle_legacy_internal;
revoke all on function public.predict_legacy_paid_settle_internal(uuid,text),
 public.predict_legacy_confirm_result_internal(uuid,integer,integer,text),
 public.partner_prediction_pool_settle_legacy_internal(uuid) from public,anon,authenticated,service_role;

create or replace function public.predict_require_member(p_club_id bigint) returns uuid
language plpgsql volatile security definer set search_path='' as $$
declare v_user uuid:=auth.uid();
begin
  perform public.assert_account_active();
  perform public.fet_require_club_context(p_club_id);
  if v_user is null or not exists(select 1 from auth.users u where u.id=v_user
    and u.phone_confirmed_at is not null and coalesce(u.is_anonymous,false)=false) then
    raise exception 'PREDICT_SIGN_IN_REQUIRED' using errcode='42501';
  end if;
  if exists(select 1 from public.fan_memberships m where m.user_id=v_user and m.club_id=p_club_id
    and m.status not in ('active','pending')) then
    raise exception 'PREDICT_MEMBERSHIP_UNAVAILABLE' using errcode='42501';
  end if;
  return v_user;
end; $$;

create or replace function public.predict_require_admin(p_club_id bigint) returns void
language plpgsql volatile security definer set search_path='' as $$
begin
  perform public.assert_account_active();
  perform public.fet_require_club_context(p_club_id);
  if auth.uid() is null or not (public.is_super_admin() or public.is_club_admin(p_club_id))
    or not exists(select 1 from public.admin_role_assignments a where a.user_id=auth.uid()
      and a.is_active and a.revoked_at is null and (a.role in ('admin','super_admin')
        or (a.club_id=p_club_id and a.role in ('club_admin','club_moderator','partner','rayon_sport','bank')))) then
    raise exception 'PREDICT_ADMIN_REQUIRED' using errcode='42501';
  end if;
end; $$;

-- No new welcome credit is part of the free policy.
create or replace function public.predict_ensure_welcome(p_club_id bigint,p_user_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform public.assert_account_active();
  return;
end; $$;

create or replace function public.predict_place(p_club_id bigint,p_fixture_id uuid,p_selection text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_user uuid; v_pool football.predict_pools; v_fixture football.fixtures; v_entry football.predict_entries; v_balance integer;
begin
  perform public.assert_account_active();
  v_user:=public.predict_require_member(p_club_id);
  if p_selection is null or p_selection not in ('home','draw','away') then raise exception 'PREDICT_INVALID_SELECTION'; end if;
  select * into v_fixture from football.fixtures where id=p_fixture_id for share;
  select * into v_pool from football.predict_pools where club_id=p_club_id and fixture_id=p_fixture_id for update;
  perform public.assert_account_active();
  perform public.predict_require_member(p_club_id);
  if v_pool.id is null then raise exception 'PREDICT_POOL_UNAVAILABLE'; end if;
  select points into v_balance from public.fan_memberships where club_id=p_club_id and user_id=v_user;
  select * into v_entry from football.predict_entries where pool_id=v_pool.id and user_id=v_user;
  if v_entry.id is not null then
    if v_entry.selection<>p_selection then raise exception 'PREDICT_ALREADY_ENTERED'; end if;
    return public.predict_fixture_json(v_pool.id)||jsonb_build_object('balance_fet',v_balance);
  end if;
  if v_pool.economics_version<>'free_v1' then raise exception 'PREDICT_LEGACY_ENTRY_CLOSED'; end if;
  perform 1 from football.predict_settings where club_id=p_club_id and enabled for share;
  if not found or v_pool.status<>'open' or v_fixture.status<>'scheduled'
    or clock_timestamp()<v_pool.opens_at or clock_timestamp()>=v_pool.locks_at
    or v_fixture.kickoff_at is null or clock_timestamp()>=v_fixture.kickoff_at then raise exception 'PREDICT_POOL_CLOSED'; end if;
  perform public.assert_account_active();
  perform public.predict_require_member(p_club_id);
  if not exists(select 1 from football.teams h,football.teams a,football.competitions c
    where h.id=v_fixture.home_team_id and a.id=v_fixture.away_team_id and c.id=v_fixture.competition_id
      and h.is_active and a.is_active and c.is_active and nullif(h.crest_url,'') is not null and nullif(a.crest_url,'') is not null) then
    raise exception 'PREDICT_FIXTURE_UNAVAILABLE';
  end if;
  insert into football.predict_entries(club_id,pool_id,user_id,selection,stake_fet,economics_version)
    values(p_club_id,v_pool.id,v_user,p_selection,0,'free_v1');
  update football.predict_pools set entry_count=entry_count+1,updated_at=now() where id=v_pool.id;
  return public.predict_fixture_json(v_pool.id)||jsonb_build_object('balance_fet',v_balance);
end; $$;

create or replace function public.predict_admin_settings(p_club_id bigint,p_enabled boolean,p_entry_fet integer) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform public.assert_account_active();
  perform public.predict_require_admin(p_club_id);
  if p_entry_fet is distinct from 0 then raise exception 'PREDICT_FREE_ENTRY_REQUIRED'; end if;
  if p_enabled is null then raise exception 'PREDICT_INVALID_SETTINGS'; end if;
  insert into football.predict_settings(club_id,enabled,entry_fet,welcome_fet) values(p_club_id,p_enabled,0,0)
    on conflict(club_id) do update set enabled=excluded.enabled,updated_at=now();
  perform public.assert_account_active();
  perform public.predict_require_admin(p_club_id);
  return jsonb_build_object('enabled',p_enabled,'entry_fet',0,'welcome_fet',0,'economics_version','free_v1');
end; $$;

create or replace function public.predict_admin_prepare(p_club_id bigint,p_fixture_id uuid,p_source_url text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_fixture football.fixtures; v_pool football.predict_pools;
begin
  perform public.assert_account_active();
  perform public.predict_require_admin(p_club_id);
  if p_source_url is null or length(p_source_url)>2000 or p_source_url !~ '^https://[^/[:space:]]+' then raise exception 'PREDICT_SOURCE_REQUIRED'; end if;
  select * into v_fixture from football.fixtures where id=p_fixture_id for share;
  perform public.assert_account_active();
  perform public.predict_require_admin(p_club_id);
  if v_fixture.id is null or v_fixture.status<>'scheduled' or v_fixture.kickoff_at<=clock_timestamp()
    or v_fixture.kickoff_at is null then raise exception 'PREDICT_CONFIRMED_FUTURE_FIXTURE_REQUIRED'; end if;
  if not exists(select 1 from football.teams h,football.teams a,football.competitions c
    where h.id=v_fixture.home_team_id and a.id=v_fixture.away_team_id and c.id=v_fixture.competition_id
      and h.is_active and a.is_active and c.is_active and nullif(h.crest_url,'') is not null and nullif(a.crest_url,'') is not null) then
    raise exception 'PREDICT_REGISTERED_TEAMS_REQUIRED';
  end if;
  insert into football.predict_settings(club_id) values(p_club_id) on conflict do nothing;
  insert into football.predict_pools(club_id,fixture_id,stake_fet,economics_version,locks_at,source_url,approved_by)
    values(p_club_id,p_fixture_id,0,'free_v1',v_fixture.kickoff_at,p_source_url,auth.uid()) on conflict(club_id,fixture_id) do nothing;
  select * into v_pool from football.predict_pools where club_id=p_club_id and fixture_id=p_fixture_id for update;
  perform public.assert_account_active();
  perform public.predict_require_admin(p_club_id);
  if v_fixture.kickoff_at<=clock_timestamp() then raise exception 'PREDICT_CONFIRMED_FUTURE_FIXTURE_REQUIRED'; end if;
  if v_pool.economics_version<>'free_v1' then raise exception 'PREDICT_LEGACY_POOL_PRESENT'; end if;
  return public.predict_fixture_json(v_pool.id);
end; $$;

create function public.predict_admin_confirm_result(p_pool_id uuid,p_home_score integer,p_away_score integer,p_source_url text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_pool football.predict_pools;
begin
  perform public.assert_account_active();
  select * into v_pool from football.predict_pools where id=p_pool_id;
  if v_pool.id is null then raise exception 'PREDICT_POOL_UNAVAILABLE'; end if;
  perform public.predict_require_admin(v_pool.club_id);
  perform 1 from football.fixtures where id=v_pool.fixture_id for share;
  select * into v_pool from football.predict_pools where id=p_pool_id for update;
  perform public.assert_account_active();
  perform public.predict_require_admin(v_pool.club_id);
  if v_pool.economics_version<>'free_v1' then raise exception 'PREDICT_LEGACY_SETTLEMENT_SERVICE_REQUIRED' using errcode='42501'; end if;
  return public.predict_legacy_confirm_result_internal(p_pool_id,p_home_score,p_away_score,p_source_url)
    ||jsonb_build_object('economics_version','free_v1');
end; $$;

create function public.predict_admin_settle(p_pool_id uuid,p_void_reason text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_pool football.predict_pools; v_fixture football.fixtures; v_void boolean:=p_void_reason is not null; v_winners integer;
begin
  perform public.assert_account_active();
  select * into v_pool from football.predict_pools where id=p_pool_id;
  if v_pool.id is null then raise exception 'PREDICT_POOL_UNAVAILABLE'; end if;
  perform public.predict_require_admin(v_pool.club_id);
  select * into v_fixture from football.fixtures where id=v_pool.fixture_id for share;
  select * into v_pool from football.predict_pools where id=p_pool_id for update;
  perform public.assert_account_active();
  perform public.predict_require_admin(v_pool.club_id);
  if v_pool.economics_version<>'free_v1' then raise exception 'PREDICT_LEGACY_SETTLEMENT_SERVICE_REQUIRED' using errcode='42501'; end if;
  if v_pool.status in ('settled','refunded') then
    return jsonb_build_object('status',v_pool.status,'paid_fet',0,'winner_count',v_pool.winner_count,'economics_version','free_v1');
  end if;
  if v_void then
    if length(trim(p_void_reason)) not between 8 and 500 then raise exception 'PREDICT_VOID_REASON_REQUIRED'; end if;
  elsif v_fixture.status<>'finished' or v_pool.result_confirmed_at is null
    or v_fixture.home_score is null or v_fixture.away_score is null
    or v_pool.result_selection is distinct from(case when v_fixture.home_score>v_fixture.away_score then 'home'
      when v_fixture.home_score<v_fixture.away_score then 'away' else 'draw' end) then
    raise exception 'PREDICT_CONFIRMED_RESULT_REQUIRED';
  end if;
  select count(*) filter(where selection=v_pool.result_selection) into v_winners from football.predict_entries where pool_id=p_pool_id;
  update football.predict_entries set payout_fet=0,score_points=case when not v_void and selection=v_pool.result_selection then 1 else 0 end,
    outcome=case when v_void then 'refunded' when selection=v_pool.result_selection then 'won' else 'lost' end,settled_at=now()
    where pool_id=p_pool_id;
  update football.predict_pools set status=case when v_void then 'refunded' else 'settled' end,
    winner_count=case when v_void then 0 else v_winners end,refund_reason=case when v_void then trim(p_void_reason) end,
    settled_at=now(),updated_at=now() where id=p_pool_id;
  return jsonb_build_object('status',case when v_void then 'refunded' else 'settled' end,
    'paid_fet',0,'winner_count',case when v_void then 0 else v_winners end,'economics_version','free_v1');
end; $$;

create or replace function public.predict_fixture_json(p_pool_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', f.id, 'pool_id', p.id, 'competition_id', c.id, 'competition', c.name,
    'competition_logo', c.logo_url, 'round', f.round_name, 'kickoff_at', f.kickoff_at,
    'home_team', h.name, 'home_crest', h.crest_url, 'away_team', a.name, 'away_crest', a.crest_url,
    'stake_fet', p.stake_fet, 'economics_version', p.economics_version, 'locks_at', least(p.locks_at, f.kickoff_at), 'status', p.status,
    'selection', e.selection, 'outcome', e.outcome, 'payout_fet', e.payout_fet, 'score_points', coalesce(e.score_points, 0)
  ) from football.predict_pools p join football.fixtures f on f.id = p.fixture_id
    join football.competitions c on c.id = f.competition_id
    join football.teams h on h.id = f.home_team_id join football.teams a on a.id = f.away_team_id
    left join football.predict_entries e on e.pool_id = p.id and e.user_id = auth.uid()
  where p.id = p_pool_id;
$$;

create or replace function public.predict_dashboard(p_club_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_club bigint; v_user uuid; v_enabled boolean; v_fixtures jsonb; v_history jsonb := '[]';
  v_wallet jsonb; v_ledger jsonb := '[]';
begin
  perform public.assert_account_active();
  v_club := public.fet_resolve_public_club_id(p_club_id);
  if v_club is null then raise exception 'PREDICT_CLUB_REQUIRED'; end if;
  if auth.uid() is not null then perform public.fet_require_club_context(v_club); end if;
  select enabled into v_enabled from football.predict_settings where club_id = v_club;
  if exists (select 1 from auth.users u where u.id = auth.uid()
    and u.phone_confirmed_at is not null and coalesce(u.is_anonymous, false) = false) then
    v_user := public.predict_require_member(v_club);
    select jsonb_build_object('balance_fet', m.points) into v_wallet
      from public.fan_memberships m where m.club_id = v_club and m.user_id = v_user;
    select coalesce(jsonb_agg(q.item order by q.created_at desc, q.id), '[]') into v_ledger from (
      select l.id, l.created_at, jsonb_build_object('id', l.id, 'created_at', l.created_at,
        'delta_fet', case when l.direction = 'credit' then l.amount else -l.amount end,
        'description', l.note, 'entry_type', l.entry_type) as item
      from public.fet_wallet_ledger_entries l where l.club_id = v_club and l.user_id = v_user
      order by l.created_at desc, l.id limit 100
    ) q;
    select coalesce(jsonb_agg(q.item order by q.placed_at desc, q.id), '[]') into v_history from (
      select e.id, e.placed_at, public.predict_fixture_json(e.pool_id) as item
      from football.predict_entries e where e.club_id = v_club and e.user_id = v_user
      order by e.placed_at desc, e.id limit 100
    ) q;
  end if;
  select coalesce(jsonb_agg(q.item order by q.kickoff_at, q.id), '[]') into v_fixtures from (
    select f.id, f.kickoff_at, public.predict_fixture_json(p.id) as item
    from football.predict_pools p join football.fixtures f on f.id = p.fixture_id
      join football.competitions c on c.id = f.competition_id
      join football.teams h on h.id = f.home_team_id join football.teams a on a.id = f.away_team_id
    where p.club_id = v_club and p.economics_version = 'free_v1' and coalesce(v_enabled, false) and p.status = 'open'
      and p.opens_at <= clock_timestamp() and p.locks_at > clock_timestamp()
      and f.status = 'scheduled' and f.kickoff_at > clock_timestamp()
      and c.is_active and h.is_active and a.is_active
      and nullif(h.crest_url, '') is not null and nullif(a.crest_url, '') is not null
    order by f.kickoff_at, f.id limit 500
  ) q;
  return jsonb_build_object('enabled', coalesce(v_enabled, false), 'member_session', v_user is not null,
    'fixtures', v_fixtures, 'history', v_history, 'wallet', v_wallet, 'ledger', v_ledger);
end;
$$;

create or replace function public.predict_admin_dashboard(p_club_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_rows jsonb; v_settings jsonb;
begin
  perform public.assert_account_active();
  perform public.predict_require_admin(p_club_id);
  perform public.predict_lock_due(p_club_id);
  perform public.assert_account_active();
  perform public.predict_require_admin(p_club_id);
  select jsonb_build_object('enabled', enabled, 'entry_fet', 0, 'welcome_fet', 0, 'economics_version', 'free_v1', 'legacy_entry_fet', entry_fet, 'legacy_welcome_fet', welcome_fet)
    into v_settings from football.predict_settings where club_id = p_club_id;
  select coalesce(jsonb_agg(q.item order by q.kickoff_at desc, q.id), '[]') into v_rows from (
    select f.id, f.kickoff_at, jsonb_build_object('id', f.id, 'pool_id', p.id,
      'competition', c.name, 'home_team', h.name, 'away_team', a.name,
      'kickoff_at', f.kickoff_at, 'fixture_status', f.status, 'status', coalesce(p.status, 'no_pool'),
      'home_score', f.home_score, 'away_score', f.away_score, 'stake_fet', p.stake_fet,
      'entry_count', coalesce(p.entry_count, 0), 'staked_fet', coalesce(p.staked_fet, 0),
      'paid_fet', coalesce(p.paid_fet, 0), 'result_confirmed', p.result_confirmed_at is not null,
      'economics_version', p.economics_version, 'winner_count', coalesce(p.winner_count, 0)) as item
    from football.fixtures f join football.competitions c on c.id = f.competition_id
      join football.teams h on h.id = f.home_team_id join football.teams a on a.id = f.away_team_id
      left join football.predict_pools p on p.fixture_id = f.id and p.club_id = p_club_id
    where p.id is not null or (f.status = 'scheduled' and f.kickoff_at > clock_timestamp() and c.is_active)
    order by f.kickoff_at desc, f.id limit 1000
  ) q;
  return jsonb_build_object('fixtures', v_rows, 'settings', coalesce(v_settings,
    '{"enabled":false,"entry_fet":0,"welcome_fet":0,"economics_version":"free_v1","legacy_entry_fet":null,"legacy_welcome_fet":null}'::jsonb));
end;
$$;

create or replace function public.predict_public_preview(p_club_id bigint)
returns table(id uuid,home_team text,away_team text,home_crest text,away_crest text,competition text,kickoff_at timestamptz,locks_at timestamptz)
language plpgsql volatile security definer set search_path='' as $$
begin
  perform public.assert_account_active();
  return query select f.id,h.name,a.name,h.crest_url,a.crest_url,c.name,f.kickoff_at,least(p.locks_at,f.kickoff_at)
  from football.predict_pools p join football.predict_settings s on s.club_id=p.club_id and s.enabled
  join football.fixtures f on f.id=p.fixture_id join football.competitions c on c.id=f.competition_id
  join football.teams h on h.id=f.home_team_id join football.teams a on a.id=f.away_team_id
  where p.club_id=public.fet_resolve_public_club_id(p_club_id) and p.economics_version='free_v1'
    and p.status='open' and p.opens_at<=clock_timestamp() and p.locks_at>clock_timestamp()
    and f.status='scheduled' and f.kickoff_at>clock_timestamp() and c.is_active and h.is_active and a.is_active
    and nullif(h.crest_url,'') is not null and nullif(a.crest_url,'') is not null
  order by f.kickoff_at,f.id limit 3;
end; $$;


create table football.predict_service_operations (
  operation_id uuid primary key,
  engine text not null check(engine in ('predict_settle','partner_settle','predict_confirm')),
  pool_id uuid not null,
  actor_id uuid not null references auth.users(id),
  command_args jsonb not null,
  result jsonb,
  created_at timestamptz not null default clock_timestamp(),
  completed_at timestamptz,
  check ((result is null)=(completed_at is null))
);
alter table football.predict_service_operations enable row level security;
create trigger account_lifecycle_statement_guard before insert or update or delete on football.predict_service_operations
  for each statement execute function public.guard_account_lifecycle_mutation();
create trigger account_lifecycle_mutation_guard before insert or update or delete on football.predict_service_operations
  for each row execute function public.guard_account_lifecycle_mutation();
create policy account_lifecycle_access on football.predict_service_operations as restrictive for all to authenticated
  using(public.account_access_allowed()) with check(public.account_access_allowed());
insert into public.account_erasure_fk_inventory(constraint_oid,child_table,subject_table,deletion_action,retained)
select c.oid,c.conrelid::regclass::text,c.confrelid::regclass::text,c.confdeltype::text,true
from pg_constraint c where c.contype='f' and c.conrelid='football.predict_service_operations'::regclass
  and c.confrelid='auth.users'::regclass on conflict(constraint_oid) do nothing;
revoke all on football.predict_service_operations from public,anon,authenticated,service_role;
grant select on football.predict_service_operations to service_role;

-- Only the service entrypoints below may enter this dispatcher. Caller-supplied
-- JWT actor claims are never authority: the actual global assignment is locked
-- and rechecked after every contended fixture/pool/operation wait.
create function public.predict_service_command_internal(
 p_engine text,p_pool_id uuid,p_actor_id uuid,p_operation_id uuid,p_args jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_club bigint; v_fixture uuid; v_assignment uuid; v_result jsonb;
 v_op football.predict_service_operations;
 v_claims text:=coalesce(current_setting('request.jwt.claims',true),'');
 v_sub text:=coalesce(current_setting('request.jwt.claim.sub',true),'');
 v_role text:=coalesce(current_setting('request.jwt.claim.role',true),'');
begin
  perform public.assert_account_active();
  if coalesce(auth.role(),'')<>'service_role' or p_actor_id is null or p_operation_id is null
    or p_engine not in ('predict_settle','partner_settle','predict_confirm') then
    raise exception 'PREDICT_GLOBAL_SERVICE_REQUIRED' using errcode='42501';
  end if;
  if p_engine='partner_settle' then
    select club_id,fixture_id into v_club,v_fixture from football.partner_prediction_pools where id=p_pool_id;
  else
    select club_id,fixture_id into v_club,v_fixture from football.predict_pools where id=p_pool_id and economics_version='legacy_paid_v1';
  end if;
  if v_club is null then raise exception 'PREDICT_LEGACY_POOL_REQUIRED'; end if;

  -- Claims are bound to the validated resource, solely for the preserved internal
  -- engine's tenant checks and its actor audit, after service entry authorization.
  perform set_config('request.jwt.claims',jsonb_build_object('sub',p_actor_id,'role','authenticated',
    'club_id',v_club,'app_metadata',jsonb_build_object('club_id',v_club))::text,true);
  perform set_config('request.jwt.claim.sub',p_actor_id::text,true);
  perform set_config('request.jwt.claim.role','authenticated',true);
  perform public.assert_account_active();
  perform 1 from football.fixtures where id=v_fixture for share;
  if p_engine='partner_settle' then
    perform 1 from football.partner_prediction_pools where id=p_pool_id and club_id=v_club and fixture_id=v_fixture for update;
  else
    perform 1 from football.predict_pools where id=p_pool_id and club_id=v_club and fixture_id=v_fixture
      and economics_version='legacy_paid_v1' for update;
  end if;
  if not found then raise exception 'PREDICT_LEGACY_POOL_REQUIRED'; end if;
  perform public.assert_account_active();
  select a.id into v_assignment from public.admin_role_assignments a where a.user_id=p_actor_id
    and a.is_active and a.revoked_at is null and a.role in ('admin','super_admin') order by a.id limit 1 for share;
  if v_assignment is null then raise exception 'PREDICT_GLOBAL_ADMIN_REQUIRED' using errcode='42501'; end if;

  insert into football.predict_service_operations(operation_id,engine,pool_id,actor_id,command_args)
    values(p_operation_id,p_engine,p_pool_id,p_actor_id,p_args) on conflict(operation_id) do nothing;
  select * into strict v_op from football.predict_service_operations where operation_id=p_operation_id for update;
  perform public.assert_account_active();
  select a.id into v_assignment from public.admin_role_assignments a where a.user_id=p_actor_id
    and a.is_active and a.revoked_at is null and a.role in ('admin','super_admin') order by a.id limit 1 for share;
  if v_assignment is null then raise exception 'PREDICT_GLOBAL_ADMIN_REQUIRED' using errcode='42501'; end if;
  if v_op.engine<>p_engine or v_op.pool_id<>p_pool_id or v_op.actor_id<>p_actor_id
    or v_op.command_args is distinct from p_args then raise exception 'PREDICT_OPERATION_BINDING_MISMATCH'; end if;
  if v_op.result is not null then
    v_result:=v_op.result;
  else
    if p_engine='predict_settle' then
      v_result:=public.predict_legacy_paid_settle_internal(p_pool_id,p_args->>'void_reason');
    elsif p_engine='predict_confirm' then
      v_result:=public.predict_legacy_confirm_result_internal(p_pool_id,(p_args->>'home_score')::integer,
        (p_args->>'away_score')::integer,p_args->>'source_url');
    else
      v_result:=public.partner_prediction_pool_settle_legacy_internal(p_pool_id);
    end if;
    v_result:=v_result||jsonb_build_object('operation_id',p_operation_id,'economics_version','legacy_paid_v1');
    update football.predict_service_operations set result=v_result,completed_at=clock_timestamp() where operation_id=p_operation_id;
    insert into public.admin_audit_log(actor_id,user_id,action,target_table,target_id,club_id,metadata)
      values(p_actor_id,p_actor_id,'predict.global_service.'||p_engine,
        case when p_engine='partner_settle' then 'football.partner_prediction_pools' else 'football.predict_pools' end,
        p_pool_id::text,v_club,jsonb_build_object('operation_id',p_operation_id,'assignment_id',v_assignment,
          'economics_version','legacy_paid_v1','command_args',p_args));
  end if;
  perform set_config('request.jwt.claims',v_claims,true);
  perform set_config('request.jwt.claim.sub',v_sub,true);
  perform set_config('request.jwt.claim.role',v_role,true);
  return v_result;
exception when others then
  perform set_config('request.jwt.claims',v_claims,true);
  perform set_config('request.jwt.claim.sub',v_sub,true);
  perform set_config('request.jwt.claim.role',v_role,true);
  raise;
end; $$;

create function public.predict_admin_settle_for_actor(
 p_pool_id uuid,p_actor_id uuid,p_operation_id uuid,p_void_reason text default null
) returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform public.assert_account_active();
  return public.predict_service_command_internal('predict_settle',p_pool_id,p_actor_id,p_operation_id,
    jsonb_build_object('void_reason',case when p_void_reason is not null then trim(p_void_reason) end));
end; $$;

create function public.partner_prediction_pool_settle_for_actor(
 p_pool_id uuid,p_actor_id uuid,p_operation_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform public.assert_account_active();
  return public.predict_service_command_internal('partner_settle',p_pool_id,p_actor_id,p_operation_id,'{}'::jsonb);
end; $$;

create function public.predict_admin_confirm_result_for_actor(
 p_pool_id uuid,p_home_score integer,p_away_score integer,p_source_url text,p_actor_id uuid,p_operation_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform public.assert_account_active();
  return public.predict_service_command_internal('predict_confirm',p_pool_id,p_actor_id,p_operation_id,
    jsonb_build_object('home_score',p_home_score,'away_score',p_away_score,'source_url',p_source_url));
end; $$;
revoke all on function public.predict_service_command_internal(text,uuid,uuid,uuid,jsonb),
 public.predict_admin_settle_for_actor(uuid,uuid,uuid,text),
 public.partner_prediction_pool_settle_for_actor(uuid,uuid,uuid),
 public.predict_admin_confirm_result_for_actor(uuid,integer,integer,text,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.predict_admin_settle_for_actor(uuid,uuid,uuid,text),
 public.partner_prediction_pool_settle_for_actor(uuid,uuid,uuid),
 public.predict_admin_confirm_result_for_actor(uuid,integer,integer,text,uuid,uuid) to service_role;

create or replace function public.partner_prediction_pool_create(
 p_partner_id uuid,p_fixture_id uuid,p_title text,p_partner_stake_fet integer,p_fan_entry_fet integer,
 p_initiative_id uuid default null,p_eligibility_mode text default 'open_to_all',p_max_entries integer default null,
 p_idempotency_key text default null,p_metadata jsonb default '{}',p_club_id bigint default null
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_club bigint;
begin
  perform public.assert_account_active();
  v_club:=public.fet_require_club_context(p_club_id);
  if auth.uid() is null or not (public.is_super_admin() or public.is_club_admin(v_club) or public.is_partner_admin(p_partner_id)) then
    raise exception 'PREDICT_ADMIN_REQUIRED' using errcode='42501';
  end if;
  raise exception 'PREDICT_LEGACY_ENTRY_CLOSED';
end; $$;

create or replace function public.partner_prediction_pool_join(p_pool_id uuid,p_selected_outcome text,p_idempotency_key text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_pool football.partner_prediction_pools; v_fixture uuid; v_entry football.partner_prediction_pool_entries;
begin
  perform public.assert_account_active();
  if auth.uid() is null then raise exception 'PREDICT_SIGN_IN_REQUIRED' using errcode='42501'; end if;
  select fixture_id into v_fixture from football.partner_prediction_pools where id=p_pool_id;
  perform 1 from football.fixtures where id=v_fixture for share;
  select * into v_pool from football.partner_prediction_pools where id=p_pool_id for update;
  perform public.assert_account_active();
  if v_pool.id is null then raise exception 'PREDICT_POOL_UNAVAILABLE'; end if;
  perform public.fet_require_club_context(v_pool.club_id);
  select * into v_entry from football.partner_prediction_pool_entries where pool_id=p_pool_id and user_id=auth.uid();
  if v_entry.id is not null then
    if v_entry.selected_outcome is distinct from lower(trim(p_selected_outcome)) then raise exception 'PREDICT_ALREADY_ENTERED'; end if;
    return public.partner_prediction_pool_summary_json(p_pool_id,auth.uid());
  end if;
  raise exception 'PREDICT_LEGACY_ENTRY_CLOSED';
end; $$;

-- Existing caller-authenticated signatures retain their original ACL boundary.
revoke all on function public.predict_admin_confirm_result(uuid,integer,integer,text),public.predict_admin_settle(uuid,text)
 from public,anon,authenticated,service_role;
grant execute on function public.predict_admin_confirm_result(uuid,integer,integer,text),public.predict_admin_settle(uuid,text) to authenticated;

commit;

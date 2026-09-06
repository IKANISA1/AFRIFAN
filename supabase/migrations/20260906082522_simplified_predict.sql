begin;

-- Gikundiro's simplified Home / Draw / Away contract, using AFRICLUB's
-- existing tenant, fixture and immutable wallet authorities.
create table football.predict_settings (
  club_id bigint primary key references public.african_football_clubs(id),
  enabled boolean not null default false,
  entry_fet integer not null default 100 check (entry_fet between 1 and 100000),
  welcome_fet integer not null default 500 check (welcome_fet between 0 and 100000),
  updated_at timestamptz not null default now()
);

create table football.predict_pools (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id),
  fixture_id uuid not null references football.fixtures(id),
  stake_fet integer not null check (stake_fet between 1 and 100000),
  status text not null default 'open' check (status in ('open', 'locked', 'settled', 'refunded')),
  opens_at timestamptz not null default now(),
  locks_at timestamptz not null,
  source_url text not null check (source_url ~ '^https://[^/[:space:]]+'),
  approved_by uuid not null references auth.users(id),
  approved_at timestamptz not null default now(),
  result_selection text check (result_selection in ('home', 'draw', 'away')),
  result_source_url text,
  result_confirmed_by uuid references auth.users(id),
  result_confirmed_at timestamptz,
  entry_count integer not null default 0 check (entry_count >= 0),
  staked_fet bigint not null default 0 check (staked_fet >= 0),
  paid_fet bigint not null default 0 check (paid_fet >= 0),
  winner_count integer not null default 0 check (winner_count >= 0),
  refund_reason text,
  settled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (club_id, fixture_id),
  unique (id, club_id),
  check (locks_at > opens_at),
  check (paid_fet <= staked_fet)
);

create table football.predict_entries (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null,
  pool_id uuid not null,
  user_id uuid not null references auth.users(id),
  selection text not null check (selection in ('home', 'draw', 'away')),
  stake_fet integer not null check (stake_fet > 0),
  payout_fet bigint not null default 0 check (payout_fet >= 0),
  outcome text not null default 'pending' check (outcome in ('pending', 'won', 'lost', 'refunded')),
  placed_at timestamptz not null default clock_timestamp(),
  settled_at timestamptz,
  unique (pool_id, user_id),
  foreign key (pool_id, club_id) references football.predict_pools(id, club_id)
);
create index predict_open_pools on football.predict_pools(club_id, locks_at) where status = 'open';
create index predict_user_entries on football.predict_entries(club_id, user_id, placed_at desc);

alter table football.predict_settings enable row level security;
alter table football.predict_pools enable row level security;
alter table football.predict_entries enable row level security;
revoke all on football.predict_settings, football.predict_pools, football.predict_entries from public, anon, authenticated, service_role;

alter table public.fet_wallet_ledger_entries drop constraint fet_wallet_ledger_entries_type_check;
alter table public.fet_wallet_ledger_entries add constraint fet_wallet_ledger_entries_type_check check (
  entry_type in ('earn', 'transfer_in', 'transfer_out', 'redeem', 'admin_adjustment', 'opening_balance',
    'partner_promotion_earn', 'partner_pool_entry', 'partner_pool_payout', 'partner_pool_refund',
    'predict_welcome', 'predict_entry', 'predict_payout', 'predict_refund')
);

create function public.predict_require_member(p_club_id bigint) returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare v_user uuid := auth.uid();
begin
  perform public.fet_require_club_context(p_club_id);
  if v_user is null or not exists (
    select 1 from auth.users u where u.id = v_user
      and u.phone_confirmed_at is not null and coalesce(u.is_anonymous, false) = false
  ) then raise exception 'PREDICT_SIGN_IN_REQUIRED' using errcode = '42501'; end if;
  return v_user;
end;
$$;

-- Both (user_id, club_id) and the older (user_id, partner_id) are unique.
-- Targeting just one constraint in an UPSERT can fail under concurrent first
-- use. Accept either conflict, then lock and return the actual tenant wallet.
create or replace function public.fet_wallet_ensure_membership(p_user_id uuid, p_club_id bigint)
returns public.fan_memberships language plpgsql security definer set search_path = '' as $$
declare v_membership public.fan_memberships;
begin
  insert into public.fan_memberships(user_id, club_id, partner_id, tier, points, renewed_at)
    values (p_user_id, p_club_id, public.fet_wallet_resolve_partner_id(p_club_id, null),
      public.resolve_fan_tier(0), 0, timezone('utc', now()))
    on conflict do nothing;
  select * into strict v_membership from public.fan_memberships
    where user_id = p_user_id and club_id = p_club_id for update;
  return v_membership;
end;
$$;

-- Serialize the balance first, then check the key. The ledger and balance
-- change belong to the caller's transaction and always commit or roll back together.
create function public.predict_post_entry(
  p_club_id bigint, p_user_id uuid, p_delta integer, p_type text, p_key text,
  p_reference uuid, p_note text
) returns integer language plpgsql security definer set search_path = '' as $$
declare v_member public.fan_memberships; v_balance integer;
begin
  if p_delta = 0 then raise exception 'PREDICT_INVALID_AMOUNT'; end if;
  perform public.fet_wallet_ensure_membership(p_user_id, p_club_id);
  select * into strict v_member from public.fan_memberships
    where club_id = p_club_id and user_id = p_user_id for update;
  if exists (select 1 from public.fet_wallet_ledger_entries
    where club_id = p_club_id and user_id = p_user_id and idempotency_key = p_key) then
    return v_member.points;
  end if;
  if p_delta < 0 and v_member.status not in ('active', 'pending') then
    raise exception 'PREDICT_MEMBERSHIP_UNAVAILABLE' using errcode = '42501';
  end if;
  v_balance := v_member.points + p_delta;
  if v_balance < 0 then raise exception 'PREDICT_INSUFFICIENT_FET'; end if;
  update public.fan_memberships set points = v_balance,
    tier = public.resolve_fan_tier(v_balance), updated_at = now() where id = v_member.id;
  perform public.fet_wallet_append_entry(
    p_club_id, p_user_id, v_member.id, p_type,
    case when p_delta > 0 then 'credit' else 'debit' end,
    abs(p_delta), v_balance, null, 'predict', p_reference::text, p_key, p_note, '{}'::jsonb, auth.uid()
  );
  return v_balance;
end;
$$;

create function public.predict_ensure_welcome(p_club_id bigint, p_user_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare v_grant integer;
begin
  select welcome_fet into v_grant from football.predict_settings where club_id = p_club_id and enabled;
  if coalesce(v_grant, 0) > 0 and not exists (select 1 from public.fan_memberships
    where club_id = p_club_id and user_id = p_user_id and status not in ('active', 'pending')) then
    perform public.predict_post_entry(p_club_id, p_user_id, v_grant, 'predict_welcome',
      'predict-welcome', null, 'Welcome to Predict');
  end if;
end;
$$;

create function public.predict_fixture_json(p_pool_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', f.id, 'pool_id', p.id, 'competition_id', c.id, 'competition', c.name,
    'competition_logo', c.logo_url, 'round', f.round_name, 'kickoff_at', f.kickoff_at,
    'home_team', h.name, 'home_crest', h.crest_url, 'away_team', a.name, 'away_crest', a.crest_url,
    'stake_fet', p.stake_fet, 'locks_at', least(p.locks_at, f.kickoff_at), 'status', p.status,
    'selection', e.selection, 'outcome', e.outcome, 'payout_fet', e.payout_fet
  ) from football.predict_pools p join football.fixtures f on f.id = p.fixture_id
    join football.competitions c on c.id = f.competition_id
    join football.teams h on h.id = f.home_team_id join football.teams a on a.id = f.away_team_id
    left join football.predict_entries e on e.pool_id = p.id and e.user_id = auth.uid()
  where p.id = p_pool_id;
$$;

create function public.predict_dashboard(p_club_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_club bigint; v_user uuid; v_enabled boolean; v_fixtures jsonb; v_history jsonb := '[]';
  v_wallet jsonb; v_ledger jsonb := '[]';
begin
  v_club := public.fet_resolve_public_club_id(p_club_id);
  if v_club is null then raise exception 'PREDICT_CLUB_REQUIRED'; end if;
  if auth.uid() is not null then perform public.fet_require_club_context(v_club); end if;
  select enabled into v_enabled from football.predict_settings where club_id = v_club;
  if exists (select 1 from auth.users u where u.id = auth.uid()
    and u.phone_confirmed_at is not null and coalesce(u.is_anonymous, false) = false) then
    v_user := public.predict_require_member(v_club);
    perform public.predict_ensure_welcome(v_club, v_user);
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
    where p.club_id = v_club and coalesce(v_enabled, false) and p.status = 'open'
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

create function public.predict_place(p_club_id bigint, p_fixture_id uuid, p_selection text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_user uuid; v_pool football.predict_pools; v_fixture football.fixtures;
  v_entry football.predict_entries; v_balance integer;
begin
  v_user := public.predict_require_member(p_club_id);
  if p_selection is null or p_selection not in ('home', 'draw', 'away') then
    raise exception 'PREDICT_INVALID_SELECTION';
  end if;
  -- Every writer takes fixture then pool. A delayed request is checked again
  -- after lock acquisition with clock_timestamp(), not transaction-start now().
  select * into v_fixture from football.fixtures where id = p_fixture_id for share;
  select * into v_pool from football.predict_pools
    where club_id = p_club_id and fixture_id = p_fixture_id for update;
  if v_pool.id is null then raise exception 'PREDICT_POOL_UNAVAILABLE'; end if;
  select * into v_entry from football.predict_entries where pool_id = v_pool.id and user_id = v_user;
  if v_entry.id is not null then
    if v_entry.selection <> p_selection then raise exception 'PREDICT_ALREADY_ENTERED'; end if;
    return public.predict_fixture_json(v_pool.id);
  end if;
  if not exists (select 1 from football.predict_settings where club_id = p_club_id and enabled)
    or v_pool.status <> 'open' or v_fixture.status <> 'scheduled'
    or clock_timestamp() < v_pool.opens_at or clock_timestamp() >= v_pool.locks_at
    or v_fixture.kickoff_at is null or clock_timestamp() >= v_fixture.kickoff_at then
    raise exception 'PREDICT_POOL_CLOSED';
  end if;
  if not exists (select 1 from football.teams h, football.teams a, football.competitions c
    where h.id = v_fixture.home_team_id and a.id = v_fixture.away_team_id and c.id = v_fixture.competition_id
      and h.is_active and a.is_active and c.is_active
      and nullif(h.crest_url, '') is not null and nullif(a.crest_url, '') is not null) then
    raise exception 'PREDICT_FIXTURE_UNAVAILABLE';
  end if;
  perform public.predict_ensure_welcome(p_club_id, v_user);
  insert into football.predict_entries(club_id, pool_id, user_id, selection, stake_fet)
    values (p_club_id, v_pool.id, v_user, p_selection, v_pool.stake_fet) returning * into v_entry;
  v_balance := public.predict_post_entry(p_club_id, v_user, -v_pool.stake_fet,
    'predict_entry', 'predict-entry:' || v_entry.id, v_entry.id, 'Predict entry');
  update football.predict_pools set entry_count = entry_count + 1,
    staked_fet = staked_fet + v_pool.stake_fet, updated_at = now() where id = v_pool.id;
  return public.predict_fixture_json(v_pool.id) || jsonb_build_object('balance_fet', v_balance);
end;
$$;

create function public.predict_require_admin(p_club_id bigint) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not (public.is_super_admin() or public.is_club_admin(p_club_id)) then
    raise exception 'PREDICT_ADMIN_REQUIRED' using errcode = '42501';
  end if;
end;
$$;

create function public.predict_admin_settings(p_club_id bigint, p_enabled boolean, p_entry_fet integer) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform public.predict_require_admin(p_club_id);
  insert into football.predict_settings(club_id, enabled, entry_fet)
    values (p_club_id, p_enabled, p_entry_fet)
    on conflict (club_id) do update set enabled = excluded.enabled, entry_fet = excluded.entry_fet, updated_at = now();
  return jsonb_build_object('enabled', p_enabled, 'entry_fet', p_entry_fet);
end;
$$;

create function public.predict_admin_prepare(p_club_id bigint, p_fixture_id uuid, p_source_url text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_fixture football.fixtures; v_pool football.predict_pools; v_stake integer;
begin
  perform public.predict_require_admin(p_club_id);
  if p_source_url is null or length(p_source_url) > 2000 or p_source_url !~ '^https://[^/[:space:]]+' then
    raise exception 'PREDICT_SOURCE_REQUIRED';
  end if;
  select * into v_fixture from football.fixtures where id = p_fixture_id for share;
  if v_fixture.id is null or v_fixture.status <> 'scheduled' or v_fixture.kickoff_at <= clock_timestamp()
    or v_fixture.kickoff_at is null then raise exception 'PREDICT_CONFIRMED_FUTURE_FIXTURE_REQUIRED'; end if;
  if not exists (select 1 from football.teams h, football.teams a, football.competitions c
    where h.id = v_fixture.home_team_id and a.id = v_fixture.away_team_id and c.id = v_fixture.competition_id
      and h.is_active and a.is_active and c.is_active
      and nullif(h.crest_url, '') is not null and nullif(a.crest_url, '') is not null) then
    raise exception 'PREDICT_REGISTERED_TEAMS_REQUIRED';
  end if;
  insert into football.predict_settings(club_id) values (p_club_id) on conflict do nothing;
  select entry_fet into v_stake from football.predict_settings where club_id = p_club_id;
  insert into football.predict_pools(club_id, fixture_id, stake_fet, locks_at, source_url, approved_by)
    values (p_club_id, p_fixture_id, v_stake, v_fixture.kickoff_at, p_source_url, auth.uid())
    on conflict (club_id, fixture_id) do nothing;
  select * into v_pool from football.predict_pools where club_id = p_club_id and fixture_id = p_fixture_id;
  return public.predict_fixture_json(v_pool.id);
end;
$$;

create function public.predict_lock_due(p_club_id bigint default null) returns integer
language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  update football.predict_pools p set status = 'locked', updated_at = now()
    from football.fixtures f where p.fixture_id = f.id and p.status = 'open' and (p_club_id is null or p.club_id = p_club_id)
      and (p.locks_at <= clock_timestamp() or f.kickoff_at <= clock_timestamp() or f.status <> 'scheduled');
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

create function public.predict_admin_confirm_result(p_pool_id uuid, p_home_score integer, p_away_score integer, p_source_url text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_pool football.predict_pools; v_fixture football.fixtures; v_selection text;
begin
  select * into v_pool from football.predict_pools where id = p_pool_id;
  if v_pool.id is null then raise exception 'PREDICT_POOL_UNAVAILABLE'; end if;
  perform public.predict_require_admin(v_pool.club_id);
  select * into v_fixture from football.fixtures where id = v_pool.fixture_id for share;
  select * into v_pool from football.predict_pools where id = p_pool_id for update;
  if v_fixture.status <> 'finished' or v_fixture.home_score is null or v_fixture.away_score is null
    or p_home_score is distinct from v_fixture.home_score or p_away_score is distinct from v_fixture.away_score
    or v_fixture.kickoff_at > clock_timestamp() then raise exception 'PREDICT_CONFIRMED_RESULT_REQUIRED'; end if;
  if v_pool.status not in ('open', 'locked') then raise exception 'PREDICT_ALREADY_SETTLED'; end if;
  if p_source_url is null or length(p_source_url) > 2000 or p_source_url !~ '^https://[^/[:space:]]+' then
    raise exception 'PREDICT_SOURCE_REQUIRED'; end if;
  v_selection := case when p_home_score > p_away_score then 'home' when p_home_score < p_away_score then 'away' else 'draw' end;
  update football.predict_pools set status = 'locked', result_selection = v_selection,
    result_source_url = p_source_url, result_confirmed_by = auth.uid(), result_confirmed_at = now(), updated_at = now()
    where id = p_pool_id;
  return jsonb_build_object('result', v_selection);
end;
$$;

create function public.predict_admin_settle(p_pool_id uuid, p_void_reason text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_pool football.predict_pools; v_fixture football.fixtures; v_winners integer;
  v_total bigint; v_paid bigint := 0; v_index integer := 0; v_payout integer; v_entry record; v_refund boolean;
begin
  select * into v_pool from football.predict_pools where id = p_pool_id;
  if v_pool.id is null then raise exception 'PREDICT_POOL_UNAVAILABLE'; end if;
  perform public.predict_require_admin(v_pool.club_id);
  select * into v_fixture from football.fixtures where id = v_pool.fixture_id for share;
  select * into v_pool from football.predict_pools where id = p_pool_id for update;
  if v_pool.status in ('settled', 'refunded') then
    return jsonb_build_object('status', v_pool.status, 'paid_fet', v_pool.paid_fet, 'winner_count', v_pool.winner_count);
  end if;
  v_refund := p_void_reason is not null;
  if v_refund then
    if length(trim(p_void_reason)) not between 8 and 500 then raise exception 'PREDICT_VOID_REASON_REQUIRED'; end if;
  elsif v_fixture.status <> 'finished' or v_pool.result_confirmed_at is null
    or v_fixture.home_score is null or v_fixture.away_score is null
    or v_pool.result_selection is distinct from (case when v_fixture.home_score > v_fixture.away_score then 'home'
      when v_fixture.home_score < v_fixture.away_score then 'away' else 'draw' end) then
    raise exception 'PREDICT_CONFIRMED_RESULT_REQUIRED';
  end if;
  select count(*) filter (where selection = v_pool.result_selection), coalesce(sum(stake_fet), 0)
    into v_winners, v_total from football.predict_entries where pool_id = p_pool_id;
  if v_total <> v_pool.staked_fet then raise exception 'PREDICT_LEDGER_MISMATCH'; end if;
  v_refund := v_refund or v_winners = 0;
  -- Global user order avoids two simultaneous settlements locking wallets in opposite orders.
  perform 1 from public.fan_memberships m join football.predict_entries e
    on e.user_id = m.user_id and e.club_id = m.club_id
    where e.pool_id = p_pool_id order by m.user_id for update of m;
  for v_entry in select * from football.predict_entries where pool_id = p_pool_id order by placed_at, id loop
    v_payout := 0;
    if v_refund then v_payout := v_entry.stake_fet;
    elsif v_entry.selection = v_pool.result_selection then
      v_index := v_index + 1;
      v_payout := (v_total / v_winners) + case when v_index <= v_total % v_winners then 1 else 0 end;
    end if;
    if v_payout > 0 then
      perform public.predict_post_entry(v_pool.club_id, v_entry.user_id, v_payout,
        case when v_refund then 'predict_refund' else 'predict_payout' end,
        'predict-settlement:' || v_entry.id, v_entry.id,
        case when v_refund then 'Predict entry refunded' else 'Predict pool payout' end);
    end if;
    update football.predict_entries set payout_fet = v_payout, settled_at = now(),
      outcome = case when v_refund then 'refunded' when v_payout > 0 then 'won' else 'lost' end where id = v_entry.id;
    v_paid := v_paid + v_payout;
  end loop;
  if v_paid <> v_total then raise exception 'PREDICT_PAYOUT_MISMATCH'; end if;
  update football.predict_pools set status = case when v_refund then 'refunded' else 'settled' end,
    paid_fet = v_paid, winner_count = case when v_refund then 0 else v_winners end,
    refund_reason = case when v_refund then coalesce(trim(p_void_reason), 'No correct entries') end,
    settled_at = now(), updated_at = now() where id = p_pool_id;
  return jsonb_build_object('status', case when v_refund then 'refunded' else 'settled' end,
    'paid_fet', v_paid, 'winner_count', case when v_refund then 0 else v_winners end);
end;
$$;

create function public.predict_admin_dashboard(p_club_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_rows jsonb; v_settings jsonb;
begin
  perform public.predict_require_admin(p_club_id);
  perform public.predict_lock_due(p_club_id);
  select jsonb_build_object('enabled', enabled, 'entry_fet', entry_fet, 'welcome_fet', welcome_fet)
    into v_settings from football.predict_settings where club_id = p_club_id;
  select coalesce(jsonb_agg(q.item order by q.kickoff_at desc, q.id), '[]') into v_rows from (
    select f.id, f.kickoff_at, jsonb_build_object('id', f.id, 'pool_id', p.id,
      'competition', c.name, 'home_team', h.name, 'away_team', a.name,
      'kickoff_at', f.kickoff_at, 'fixture_status', f.status, 'status', coalesce(p.status, 'no_pool'),
      'home_score', f.home_score, 'away_score', f.away_score, 'stake_fet', p.stake_fet,
      'entry_count', coalesce(p.entry_count, 0), 'staked_fet', coalesce(p.staked_fet, 0),
      'paid_fet', coalesce(p.paid_fet, 0), 'result_confirmed', p.result_confirmed_at is not null) as item
    from football.fixtures f join football.competitions c on c.id = f.competition_id
      join football.teams h on h.id = f.home_team_id join football.teams a on a.id = f.away_team_id
      left join football.predict_pools p on p.fixture_id = f.id and p.club_id = p_club_id
    where p.id is not null or (f.status = 'scheduled' and f.kickoff_at > clock_timestamp() and c.is_active)
    order by f.kickoff_at desc, f.id limit 1000
  ) q;
  return jsonb_build_object('fixtures', v_rows, 'settings', coalesce(v_settings,
    '{"enabled":false,"entry_fet":100,"welcome_fet":500}'::jsonb));
end;
$$;

-- Reuse the existing tenant audit authority. Entry-count updates are not
-- operator changes; preparation, result confirmation, settings and settlement are.
create function public.predict_audit_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_table_name = 'predict_pools' and tg_op = 'UPDATE'
    and (to_jsonb(old) - array['entry_count','staked_fet','updated_at']) =
        (to_jsonb(new) - array['entry_count','staked_fet','updated_at']) then return new; end if;
  insert into public.admin_audit_log(actor_id, action, target_table, target_id, club_id, old_data, new_data)
  values (auth.uid(), 'predict.' || lower(tg_op), 'football.' || tg_table_name,
    coalesce(to_jsonb(new)->>'id', new.club_id::text), new.club_id,
    case when tg_op = 'UPDATE' then to_jsonb(old) end, to_jsonb(new));
  return new;
end;
$$;
create trigger predict_settings_audit after insert or update on football.predict_settings
  for each row execute function public.predict_audit_change();
create trigger predict_pools_audit after insert or update on football.predict_pools
  for each row execute function public.predict_audit_change();

-- Revoke defaults before selectively exposing the contract. Internal helpers
-- never accept client-controlled wallet identities through the public API.
do $$ declare f record; begin
  for f in select oid::regprocedure as signature from pg_proc
    where pronamespace = 'public'::regnamespace and proname like 'predict\_%' escape '\' loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', f.signature);
  end loop;
end $$;
grant execute on function public.predict_dashboard(bigint) to anon, authenticated;
grant execute on function public.predict_place(bigint, uuid, text) to authenticated;
grant execute on function public.predict_admin_dashboard(bigint), public.predict_admin_settings(bigint, boolean, integer),
  public.predict_admin_prepare(bigint, uuid, text), public.predict_admin_confirm_result(uuid, integer, integer, text),
  public.predict_admin_settle(uuid, text) to authenticated;
grant execute on function public.predict_lock_due(bigint) to service_role;

-- Retire the exact-score product only after every stake has a final outcome.
do $$ begin
  if exists (select 1 from football.prediction_challenge_entries where status = 'active')
    or exists (select 1 from football.prediction_challenges where status in ('open', 'locked') and total_pool_fet > 0) then
    raise exception 'Reconcile outstanding Challenge stakes before applying the Predict replacement.';
  end if;
end $$;
create schema if not exists retired;
revoke all on schema retired from public, anon, authenticated, service_role;
do $$ declare j record; f record; begin
  for j in select jobid from cron.job where command ilike '%prediction_challenge_%' loop
    perform cron.unschedule(j.jobid);
  end loop;
  for f in select oid::regprocedure as signature from pg_proc where pronamespace = 'public'::regnamespace
    and (proname like 'prediction_challenge\_%' escape '\'
      or proname in ('prediction_admin_get_challenges', 'prediction_get_challenge_detail',
        'prediction_get_challenge_feed', 'prediction_get_my_challenges')) loop
    execute format('drop function %s', f.signature);
  end loop;
end $$;
do $$ begin
  if not exists (select 1 from football.prediction_challenges)
    and not exists (select 1 from football.prediction_challenge_entries)
    and not exists (select 1 from football.prediction_challenge_settlements) then
    drop table football.prediction_challenge_settlements, football.prediction_challenge_entries, football.prediction_challenges;
  else
    alter table football.prediction_challenges set schema retired;
    alter table football.prediction_challenge_entries set schema retired;
    alter table football.prediction_challenge_settlements set schema retired;
  end if;
end $$;
revoke all on all tables in schema retired from public, anon, authenticated, service_role;

-- Replace live discovery metadata in place, preserving the feature ID and
-- existing rollout approvals. Custom stake options have no role in Predict.
update public.platform_features set feature_key = 'predict', display_name = 'Predict',
  description = 'Pick Home, Draw or Away on prepared fixtures.', updated_at = now()
  where feature_key = 'challenge';
update public.platform_route_registry set route_key = 'predict', feature_key = 'predict',
  path_pattern = '/predict', label = 'Predict', auth_required = false, updated_at = now()
  where path_pattern = '/challenge';
delete from public.platform_route_registry where path_pattern like '/challenge/%';
update public.platform_route_registry set route_key = 'admin_predict', feature_key = 'admin',
  path_pattern = '/admin/predict', label = 'Predict', updated_at = now()
  where path_pattern = '/admin/challenges';
update public.platform_feature_channels set route_key = '/predict', updated_at = now()
  where route_key in ('challenge', '/challenge');
update public.platform_feature_rules set auth_required = false, updated_at = now()
  where feature_id in (select id from public.platform_features where feature_key = 'predict');
update public.admin_dashboard_actions set action_key = 'predict', title = 'Predict',
  subtitle = 'Prepare fixtures, confirm results and settle FET.', route = '/admin/predict'
  where route = '/admin/challenges';
delete from public.platform_option_values where option_set_id in
  (select id from public.platform_option_sets where option_set_key = 'challenge_stake_fet');
delete from public.platform_option_sets where option_set_key = 'challenge_stake_fet';

select cron.schedule('predict-pool-locks', '* * * * *', 'select public.predict_lock_due();');
notify pgrst, 'reload schema';
commit;

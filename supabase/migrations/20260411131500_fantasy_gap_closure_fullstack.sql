-- Fantasy gap-closure runtime:
-- - league lifecycle RPCs and head-to-head fixtures
-- - richer fixture payloads for World Cup bracket rendering
-- - notification topic preferences
-- - transfer audit logging with best-effort client IP hashing
-- - worker discovery RPC for multi-competition ingestion

alter table fantasy.fantasy_fixtures
  add column if not exists kickoff_at timestamptz,
  add column if not exists round_label text,
  add column if not exists home_team_id integer,
  add column if not exists home_team_name text,
  add column if not exists home_team_short text,
  add column if not exists home_logo_url text,
  add column if not exists away_team_id integer,
  add column if not exists away_team_name text,
  add column if not exists away_team_short text,
  add column if not exists away_logo_url text,
  add column if not exists home_goals integer,
  add column if not exists away_goals integer,
  add column if not exists metadata jsonb not null default '{}'::jsonb;

create table if not exists fantasy.fixture_injuries (
  id             uuid primary key default uuid_generate_v4(),
  competition_id uuid not null references fantasy.competitions(id) on delete cascade,
  player_id      integer not null,
  player_name    text not null,
  team_id        integer,
  team_name      text,
  status         text not null default 'unknown',
  reason         text,
  source         text,
  last_synced_at timestamptz not null default now(),
  unique (competition_id, player_id)
);

create index if not exists idx_fixture_injuries_competition
  on fantasy.fixture_injuries (competition_id, status);

grant select on fantasy.fixture_injuries to anon, authenticated, service_role;
grant insert, update, delete on fantasy.fixture_injuries to service_role;

alter table fantasy.fixture_injuries enable row level security;

drop policy if exists "fixture_injuries_public_read" on fantasy.fixture_injuries;
create policy "fixture_injuries_public_read"
on fantasy.fixture_injuries
for select
using (true);

drop policy if exists "fixture_injuries_service_write" on fantasy.fixture_injuries;
create policy "fixture_injuries_service_write"
on fantasy.fixture_injuries
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create table if not exists fantasy.transfer_audit_log (
  id             uuid primary key default uuid_generate_v4(),
  entry_id       uuid not null references fantasy.fantasy_entries(id) on delete cascade,
  gameweek_id    uuid not null references fantasy.gameweeks(id) on delete cascade,
  player_out_id  integer not null,
  player_in_id   integer not null,
  actor_user_id  uuid,
  client_ip_hash text,
  metadata       jsonb not null default '{}'::jsonb,
  created_at     timestamptz not null default now()
);

create index if not exists idx_transfer_audit_log_entry_gameweek
  on fantasy.transfer_audit_log (entry_id, gameweek_id, created_at desc);

grant select on fantasy.transfer_audit_log to authenticated, service_role;
grant insert on fantasy.transfer_audit_log to service_role;

alter table fantasy.transfer_audit_log enable row level security;

drop policy if exists "transfer_audit_owner_read" on fantasy.transfer_audit_log;
create policy "transfer_audit_owner_read"
on fantasy.transfer_audit_log
for select
using (
  exists (
    select 1
    from fantasy.fantasy_entries fe
    where fe.id = transfer_audit_log.entry_id
      and fe.user_id = auth.uid()
  )
);

drop policy if exists "transfer_audit_service_write" on fantasy.transfer_audit_log;
create policy "transfer_audit_service_write"
on fantasy.transfer_audit_log
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create table if not exists fantasy.fantasy_notification_preferences (
  user_id          uuid not null references auth.users(id) on delete cascade,
  competition_id   uuid not null references fantasy.competitions(id) on delete cascade,
  topic_enabled    boolean not null default true,
  deadline_alerts  boolean not null default true,
  gameplay_alerts  boolean not null default true,
  league_alerts    boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  primary key (user_id, competition_id)
);

grant select, insert, update, delete
on fantasy.fantasy_notification_preferences
to authenticated, service_role;

alter table fantasy.fantasy_notification_preferences enable row level security;

drop policy if exists "fantasy_notification_preferences_owner_read" on fantasy.fantasy_notification_preferences;
create policy "fantasy_notification_preferences_owner_read"
on fantasy.fantasy_notification_preferences
for select
using (user_id = auth.uid());

drop policy if exists "fantasy_notification_preferences_owner_write" on fantasy.fantasy_notification_preferences;
create policy "fantasy_notification_preferences_owner_write"
on fantasy.fantasy_notification_preferences
for insert
with check (user_id = auth.uid());

drop policy if exists "fantasy_notification_preferences_owner_update" on fantasy.fantasy_notification_preferences;
create policy "fantasy_notification_preferences_owner_update"
on fantasy.fantasy_notification_preferences
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "fantasy_notification_preferences_owner_delete" on fantasy.fantasy_notification_preferences;
create policy "fantasy_notification_preferences_owner_delete"
on fantasy.fantasy_notification_preferences
for delete
using (user_id = auth.uid());

drop trigger if exists fantasy_notification_preferences_updated_at
on fantasy.fantasy_notification_preferences;
create trigger fantasy_notification_preferences_updated_at
before update on fantasy.fantasy_notification_preferences
for each row execute function fantasy.set_updated_at();

create table if not exists fantasy.league_h2h_fixtures (
  id              uuid primary key default uuid_generate_v4(),
  league_id       uuid not null references fantasy.leagues(id) on delete cascade,
  gameweek_id     uuid not null references fantasy.gameweeks(id) on delete cascade,
  round_number    integer not null,
  home_entry_id   uuid not null references fantasy.fantasy_entries(id) on delete cascade,
  away_entry_id   uuid not null references fantasy.fantasy_entries(id) on delete cascade,
  home_points     integer,
  away_points     integer,
  winner_entry_id uuid references fantasy.fantasy_entries(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  unique (league_id, gameweek_id, home_entry_id, away_entry_id)
);

create index if not exists idx_league_h2h_fixtures_league_gameweek
  on fantasy.league_h2h_fixtures (league_id, gameweek_id, round_number);

grant select on fantasy.league_h2h_fixtures to authenticated, service_role;
grant insert, update, delete on fantasy.league_h2h_fixtures to service_role;

alter table fantasy.league_h2h_fixtures enable row level security;

drop policy if exists "league_h2h_fixture_member_read" on fantasy.league_h2h_fixtures;
create policy "league_h2h_fixture_member_read"
on fantasy.league_h2h_fixtures
for select
using (
  exists (
    select 1
    from fantasy.league_memberships lm
    join fantasy.fantasy_entries fe
      on fe.id = lm.entry_id
    where lm.league_id = league_h2h_fixtures.league_id
      and fe.user_id = auth.uid()
  )
);

drop policy if exists "league_h2h_fixture_service_write" on fantasy.league_h2h_fixtures;
create policy "league_h2h_fixture_service_write"
on fantasy.league_h2h_fixtures
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop trigger if exists league_h2h_fixtures_updated_at
on fantasy.league_h2h_fixtures;
create trigger league_h2h_fixtures_updated_at
before update on fantasy.league_h2h_fixtures
for each row execute function fantasy.set_updated_at();

create or replace function fantasy.request_ip_hash()
returns text
language plpgsql
stable
as $$
declare
  v_headers jsonb;
  v_ip text;
begin
  begin
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  exception
    when others then
      v_headers := null;
  end;

  if v_headers is null then
    return null;
  end if;

  v_ip := coalesce(
    v_headers ->> 'cf-connecting-ip',
    v_headers ->> 'x-real-ip',
    split_part(coalesce(v_headers ->> 'x-forwarded-for', ''), ',', 1)
  );

  if nullif(btrim(v_ip), '') is null then
    return null;
  end if;

  return encode(digest(btrim(v_ip), 'sha256'), 'hex');
end;
$$;

create or replace function fantasy.topic_for_competition(
  p_competition_id uuid
) returns text
language sql
stable
as $$
  select 'fantasy_' || replace(slug, '-', '_')
  from fantasy.competitions
  where id = p_competition_id;
$$;

create or replace function fantasy.audit_transfer_history()
returns trigger
language plpgsql
security definer
set search_path = public, fantasy
as $$
begin
  insert into fantasy.transfer_audit_log (
    entry_id,
    gameweek_id,
    player_out_id,
    player_in_id,
    actor_user_id,
    client_ip_hash,
    metadata
  )
  values (
    new.entry_id,
    new.gameweek_id,
    new.player_out_id,
    new.player_in_id,
    auth.uid(),
    fantasy.request_ip_hash(),
    jsonb_build_object(
      'sell_price', new.sell_price,
      'buy_price', new.buy_price
    )
  );

  return new;
end;
$$;

drop trigger if exists transfer_history_audit_row
on fantasy.transfer_history;
create trigger transfer_history_audit_row
after insert on fantasy.transfer_history
for each row execute function fantasy.audit_transfer_history();

create or replace function fantasy.league_member_count(
  p_league_id uuid
) returns integer
language sql
stable
as $$
  select count(*)::integer
  from fantasy.league_memberships
  where league_id = p_league_id;
$$;

create or replace function fantasy.stage_from_round(
  p_round_label text,
  p_gameweek_name text,
  p_gameweek_number integer
) returns text
language plpgsql
stable
as $$
declare
  v_round text := lower(coalesce(p_round_label, ''));
  v_name text := lower(coalesce(p_gameweek_name, ''));
begin
  if v_round like '%group%' or v_name like '%group%' then
    return 'Groups';
  elsif v_round like '%round of 32%' or v_round like '%r32%' or v_name like '%opening%' then
    return 'R32';
  elsif v_round like '%round of 16%' or v_round like '%r16%' or v_round like '%1/8%' then
    return 'R16';
  elsif v_round like '%quarter%' or v_round like '%qf%' then
    return 'QF';
  elsif v_round like '%semi%' or v_round like '%sf%' then
    return 'SF';
  elsif v_round like '%final%' or v_name like '%final%' then
    return 'Final';
  end if;

  return case
    when p_gameweek_number <= 3 then 'Groups'
    when p_gameweek_number = 4 then 'R32'
    when p_gameweek_number = 5 then 'R16'
    when p_gameweek_number = 6 then 'QF'
    when p_gameweek_number = 7 then 'SF'
    else 'Final'
  end;
end;
$$;

create or replace function fantasy.stage_order(
  p_stage text
) returns integer
language sql
stable
as $$
  select case p_stage
    when 'Groups' then 1
    when 'R32' then 2
    when 'R16' then 3
    when 'QF' then 4
    when 'SF' then 5
    when 'Final' then 6
    else 99
  end;
$$;

create or replace function fantasy.rebuild_h2h_schedule(
  p_league_id uuid
) returns integer
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_type fantasy.league_type;
  v_competition_id uuid;
  v_started boolean := false;
  v_original uuid[];
  v_working uuid[];
  v_gameweeks uuid[];
  v_count integer := 0;
  v_rounds integer := 0;
  v_half integer := 0;
  v_round integer;
  v_cycle integer;
  v_gameweek_index integer;
  v_match integer;
  v_home uuid;
  v_away uuid;
  v_tmp uuid;
  v_inserted integer := 0;
begin
  select type, competition_id
  into v_type, v_competition_id
  from fantasy.leagues
  where id = p_league_id;

  if v_type is null then
    raise exception 'Fantasy league not found.';
  end if;

  if v_type <> 'head_to_head' then
    delete from fantasy.league_h2h_fixtures
    where league_id = p_league_id;
    return 0;
  end if;

  select exists (
    select 1
    from fantasy.gameweeks
    where competition_id = v_competition_id
      and deadline_at <= now()
  )
  into v_started;

  if v_started then
    raise exception 'Head-to-head schedules cannot change after the competition deadline has passed.';
  end if;

  select array_agg(lm.entry_id order by fe.created_at asc, lm.joined_at asc, lm.entry_id asc)
  into v_original
  from fantasy.league_memberships lm
  join fantasy.fantasy_entries fe
    on fe.id = lm.entry_id
  where lm.league_id = p_league_id;

  if coalesce(array_length(v_original, 1), 0) < 2 then
    delete from fantasy.league_h2h_fixtures
    where league_id = p_league_id;
    return 0;
  end if;

  if mod(array_length(v_original, 1), 2) = 1 then
    v_original := v_original || null::uuid;
  end if;

  select array_agg(id order by number asc)
  into v_gameweeks
  from fantasy.gameweeks
  where competition_id = v_competition_id;

  if coalesce(array_length(v_gameweeks, 1), 0) = 0 then
    return 0;
  end if;

  delete from fantasy.league_h2h_fixtures
  where league_id = p_league_id;

  v_count := array_length(v_original, 1);
  v_rounds := greatest(v_count - 1, 1);
  v_half := v_count / 2;
  v_gameweek_index := 1;

  for v_cycle in 1..2 loop
    v_working := v_original;

    for v_round in 1..v_rounds loop
      exit when v_gameweek_index > array_length(v_gameweeks, 1);

      for v_match in 1..v_half loop
        v_home := v_working[v_match];
        v_away := v_working[v_count - v_match + 1];

        if v_home is not null and v_away is not null then
          if v_cycle = 2 then
            v_tmp := v_home;
            v_home := v_away;
            v_away := v_tmp;
          end if;

          insert into fantasy.league_h2h_fixtures (
            league_id,
            gameweek_id,
            round_number,
            home_entry_id,
            away_entry_id
          )
          values (
            p_league_id,
            v_gameweeks[v_gameweek_index],
            ((v_cycle - 1) * v_rounds) + v_round,
            v_home,
            v_away
          );

          v_inserted := v_inserted + 1;
        end if;
      end loop;

      v_gameweek_index := v_gameweek_index + 1;
      exit when v_gameweek_index > array_length(v_gameweeks, 1);

      v_working := array_cat(
        array[v_working[1], v_working[v_count]],
        v_working[2:v_count - 1]
      );
    end loop;
  end loop;

  return v_inserted;
end;
$$;

create or replace function public.fantasy_create_league(
  p_competition_id uuid,
  p_name text,
  p_type text default 'classic',
  p_is_public boolean default false,
  p_max_entries integer default 50,
  p_entry_id uuid default null
) returns table (
  id uuid,
  competition_id uuid,
  name text,
  code text,
  type fantasy.league_type,
  created_by uuid,
  max_entries integer,
  is_public boolean,
  created_at timestamptz,
  member_count integer
)
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_user_id uuid;
  v_type fantasy.league_type;
  v_league fantasy.leagues;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication is required to create a fantasy league.';
  end if;

  perform fantasy.assert_competition_access(p_competition_id, true, false);

  if lower(coalesce(p_type, 'classic')) = 'head_to_head' then
    v_type := 'head_to_head';
  else
    v_type := 'classic';
  end if;

  if p_entry_id is not null then
    perform fantasy.assert_entry_owner(p_entry_id);
    perform fantasy.assert_entry_gameweek_matches_competition(
      p_entry_id,
      (
        select gw.id
        from fantasy.gameweeks gw
        where gw.competition_id = p_competition_id
        order by gw.number asc
        limit 1
      )
    );
  end if;

  insert into fantasy.leagues (
    competition_id,
    name,
    type,
    created_by,
    max_entries,
    is_public
  )
  values (
    p_competition_id,
    coalesce(nullif(btrim(p_name), ''), 'Private League'),
    v_type,
    v_user_id,
    greatest(coalesce(p_max_entries, 50), 2),
    coalesce(p_is_public, false)
  )
  returning * into v_league;

  if p_entry_id is not null then
    insert into fantasy.league_memberships (league_id, entry_id)
    values (v_league.id, p_entry_id)
    on conflict (league_id, entry_id) do nothing;

    if v_type = 'head_to_head' then
      perform fantasy.rebuild_h2h_schedule(v_league.id);
    end if;
  end if;

  return query
  select
    v_league.id,
    v_league.competition_id,
    v_league.name,
    v_league.code,
    v_league.type,
    v_league.created_by,
    v_league.max_entries,
    v_league.is_public,
    v_league.created_at,
    fantasy.league_member_count(v_league.id);
end;
$$;

create or replace function public.fantasy_join_league(
  p_league_code text,
  p_entry_id uuid
) returns table (
  id uuid,
  competition_id uuid,
  name text,
  code text,
  type fantasy.league_type,
  created_by uuid,
  max_entries integer,
  is_public boolean,
  created_at timestamptz,
  member_count integer
)
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_league fantasy.leagues;
  v_entry_competition_id uuid;
begin
  perform fantasy.assert_entry_owner(p_entry_id);

  select competition_id
  into v_entry_competition_id
  from fantasy.fantasy_entries
  where id = p_entry_id;

  select *
  into v_league
  from fantasy.leagues
  where code = upper(coalesce(p_league_code, ''));

  if v_league.id is null then
    raise exception 'Fantasy league code not found.';
  end if;

  if v_league.competition_id <> v_entry_competition_id then
    raise exception 'This fantasy entry belongs to a different competition.';
  end if;

  if fantasy.league_member_count(v_league.id) >= v_league.max_entries then
    raise exception 'This fantasy league is full.';
  end if;

  if v_league.type = 'head_to_head' and exists (
    select 1
    from fantasy.gameweeks
    where competition_id = v_league.competition_id
      and deadline_at <= now()
  ) then
    raise exception 'Head-to-head leagues close once the competition starts.';
  end if;

  insert into fantasy.league_memberships (
    league_id,
    entry_id
  )
  values (
    v_league.id,
    p_entry_id
  )
  on conflict (league_id, entry_id) do nothing;

  if v_league.type = 'head_to_head' then
    perform fantasy.rebuild_h2h_schedule(v_league.id);
  end if;

  return query
  select
    v_league.id,
    v_league.competition_id,
    v_league.name,
    v_league.code,
    v_league.type,
    v_league.created_by,
    v_league.max_entries,
    v_league.is_public,
    v_league.created_at,
    fantasy.league_member_count(v_league.id);
end;
$$;

create or replace function public.fantasy_leave_league(
  p_league_id uuid,
  p_entry_id uuid
) returns void
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_type fantasy.league_type;
begin
  perform fantasy.assert_entry_owner(p_entry_id);

  delete from fantasy.league_memberships
  where league_id = p_league_id
    and entry_id = p_entry_id;

  select type into v_type
  from fantasy.leagues
  where id = p_league_id;

  if v_type = 'head_to_head' and not exists (
    select 1
    from fantasy.gameweeks gw
    join fantasy.leagues l
      on l.competition_id = gw.competition_id
    where l.id = p_league_id
      and gw.deadline_at <= now()
  ) then
    perform fantasy.rebuild_h2h_schedule(p_league_id);
  end if;
end;
$$;

create or replace function public.fantasy_get_my_leagues(
  p_competition_id uuid
) returns table (
  id uuid,
  competition_id uuid,
  name text,
  code text,
  type fantasy.league_type,
  created_by uuid,
  max_entries integer,
  is_public boolean,
  created_at timestamptz,
  member_count integer
)
language sql
security definer
set search_path = public, fantasy
as $$
  with my_entries as (
    select fe.id
    from fantasy.fantasy_entries fe
    where fe.user_id = auth.uid()
      and fe.competition_id = p_competition_id
  )
  select
    l.id,
    l.competition_id,
    l.name,
    l.code,
    l.type,
    l.created_by,
    l.max_entries,
    l.is_public,
    l.created_at,
    fantasy.league_member_count(l.id) as member_count
  from fantasy.league_memberships lm
  join my_entries me
    on me.id = lm.entry_id
  join fantasy.leagues l
    on l.id = lm.league_id
  order by l.created_at desc, l.name asc;
$$;

create or replace function public.fantasy_get_h2h_fixtures(
  p_league_id uuid,
  p_limit integer default 100
) returns table (
  id uuid,
  league_id uuid,
  gameweek_id uuid,
  gameweek_number integer,
  gameweek_name text,
  round_number integer,
  home_entry_id uuid,
  home_team_name text,
  away_entry_id uuid,
  away_team_name text,
  home_points integer,
  away_points integer,
  winner_entry_id uuid,
  status text
)
language plpgsql
security definer
set search_path = public, fantasy
as $$
begin
  perform fantasy.assert_competition_access(
    (
      select competition_id
      from fantasy.leagues
      where id = p_league_id
    ),
    false,
    false
  );

  return query
  select
    f.id,
    f.league_id,
    f.gameweek_id,
    gw.number,
    gw.name,
    f.round_number,
    f.home_entry_id,
    home.team_name,
    f.away_entry_id,
    away.team_name,
    f.home_points,
    f.away_points,
    f.winner_entry_id,
    gw.status::text
  from fantasy.league_h2h_fixtures f
  join fantasy.gameweeks gw
    on gw.id = f.gameweek_id
  join fantasy.fantasy_entries home
    on home.id = f.home_entry_id
  join fantasy.fantasy_entries away
    on away.id = f.away_entry_id
  where f.league_id = p_league_id
  order by gw.number asc, f.round_number asc, home.team_name asc
  limit greatest(coalesce(p_limit, 100), 1);
end;
$$;

create or replace function public.fantasy_get_league_members(
  p_league_id uuid
) returns table (
  entry_id uuid,
  team_name text,
  overall_points integer,
  overall_rank integer,
  joined_at timestamptz
)
language sql
security definer
set search_path = public, fantasy
as $$
  select
    fe.id,
    fe.team_name,
    fe.overall_points,
    fe.overall_rank,
    lm.joined_at
  from fantasy.league_memberships lm
  join fantasy.fantasy_entries fe
    on fe.id = lm.entry_id
  where lm.league_id = p_league_id
  order by fe.overall_rank asc nulls last, fe.overall_points desc, lm.joined_at asc;
$$;

create or replace function public.fantasy_refresh_gameweek_h2h_results(
  p_gameweek_id uuid
) returns integer
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_updated integer := 0;
begin
  update fantasy.league_h2h_fixtures h2h
  set
    home_points = home_score.points,
    away_points = away_score.points,
    winner_entry_id = case
      when coalesce(home_score.points, 0) > coalesce(away_score.points, 0) then h2h.home_entry_id
      when coalesce(away_score.points, 0) > coalesce(home_score.points, 0) then h2h.away_entry_id
      else null
    end,
    updated_at = now()
  from fantasy.entry_gameweek_scores home_score
  join fantasy.entry_gameweek_scores away_score
    on away_score.gameweek_id = home_score.gameweek_id
  where h2h.gameweek_id = p_gameweek_id
    and home_score.gameweek_id = p_gameweek_id
    and home_score.entry_id = h2h.home_entry_id
    and away_score.entry_id = h2h.away_entry_id;

  get diagnostics v_updated = row_count;
  return v_updated;
end;
$$;

create or replace function public.fantasy_get_competition_bracket(
  p_competition_id uuid
) returns table (
  stage text,
  stage_order integer,
  label text,
  fixture_id uuid,
  external_fixture_id bigint,
  kickoff_at timestamptz,
  status_short text,
  round_label text,
  home_team_name text,
  away_team_name text,
  home_goals integer,
  away_goals integer
)
language sql
security definer
set search_path = public, fantasy
as $$
  with guard as (
    select fantasy.assert_competition_access(p_competition_id, false, false)
  )
  select
    fantasy.stage_from_round(ff.round_label, gw.name, gw.number) as stage,
    fantasy.stage_order(fantasy.stage_from_round(ff.round_label, gw.name, gw.number)) as stage_order,
    coalesce(ff.round_label, gw.name) as label,
    ff.id,
    ff.external_fixture_id,
    ff.kickoff_at,
    ff.status_short,
    ff.round_label,
    coalesce(ff.home_team_name, 'TBD') as home_team_name,
    coalesce(ff.away_team_name, 'TBD') as away_team_name,
    ff.home_goals,
    ff.away_goals
  from fantasy.fantasy_fixtures ff
  join guard
    on true
  join fantasy.gameweeks gw
    on gw.id = ff.gameweek_id
  where ff.competition_id = p_competition_id
  order by
    fantasy.stage_order(fantasy.stage_from_round(ff.round_label, gw.name, gw.number)) asc,
    ff.kickoff_at asc nulls last,
    ff.external_fixture_id asc;
$$;

create or replace function public.fantasy_get_notification_topics()
returns table (
  competition_id uuid,
  slug text,
  topic text,
  enabled boolean,
  deadline_alerts boolean,
  gameplay_alerts boolean,
  league_alerts boolean
)
language sql
security definer
set search_path = public, fantasy
as $$
  select
    c.id as competition_id,
    c.slug,
    fantasy.topic_for_competition(c.id) as topic,
    coalesce(pref.topic_enabled, true) as enabled,
    coalesce(pref.deadline_alerts, true) as deadline_alerts,
    coalesce(pref.gameplay_alerts, true) as gameplay_alerts,
    coalesce(pref.league_alerts, true) as league_alerts
  from fantasy.competitions c
  join public.fantasy_competition_enablements e
    on e.competition_id = c.id
  left join fantasy.fantasy_notification_preferences pref
    on pref.competition_id = c.id
   and pref.user_id = auth.uid()
  where e.club_id = nullif(public.requesting_club_id(), '')::bigint
    and e.is_visible = true
  order by e.sort_order asc, c.start_date asc;
$$;

create or replace function public.fantasy_update_notification_preference(
  p_competition_id uuid,
  p_topic_enabled boolean default true,
  p_deadline_alerts boolean default true,
  p_gameplay_alerts boolean default true,
  p_league_alerts boolean default true
) returns fantasy.fantasy_notification_preferences
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_user_id uuid;
  v_row fantasy.fantasy_notification_preferences;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  perform fantasy.assert_competition_access(p_competition_id, false, false);

  insert into fantasy.fantasy_notification_preferences (
    user_id,
    competition_id,
    topic_enabled,
    deadline_alerts,
    gameplay_alerts,
    league_alerts
  )
  values (
    v_user_id,
    p_competition_id,
    coalesce(p_topic_enabled, true),
    coalesce(p_deadline_alerts, true),
    coalesce(p_gameplay_alerts, true),
    coalesce(p_league_alerts, true)
  )
  on conflict (user_id, competition_id)
  do update set
    topic_enabled = excluded.topic_enabled,
    deadline_alerts = excluded.deadline_alerts,
    gameplay_alerts = excluded.gameplay_alerts,
    league_alerts = excluded.league_alerts,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.fantasy_get_active_sync_competitions()
returns table (
  competition_id uuid,
  slug text,
  external_league_id integer,
  external_season integer,
  competition_type text,
  gameweek_id uuid,
  gameweek_number integer,
  deadline_at timestamptz,
  topic text
)
language sql
security definer
set search_path = public, fantasy
as $$
  with ranked_gameweeks as (
    select
      gw.competition_id,
      gw.id as gameweek_id,
      gw.number as gameweek_number,
      gw.deadline_at,
      row_number() over (
        partition by gw.competition_id
        order by
          case gw.status
            when 'live' then 0
            when 'scoring' then 1
            when 'upcoming' then 2
            else 3
          end,
          gw.number asc
      ) as rn
    from fantasy.gameweeks gw
    where gw.status in ('live', 'scoring', 'upcoming')
  )
  select
    c.id as competition_id,
    c.slug,
    c.external_league_id,
    coalesce(
      nullif(substring(c.season from '([0-9]{4})'), '')::integer,
      extract(year from c.start_date)::integer
    ) as external_season,
    c.competition_type::text as competition_type,
    rg.gameweek_id,
    rg.gameweek_number,
    rg.deadline_at,
    fantasy.topic_for_competition(c.id) as topic
  from fantasy.competitions c
  join ranked_gameweeks rg
    on rg.competition_id = c.id
   and rg.rn = 1
  where c.status = 'active'
    and c.external_league_id is not null
  order by c.start_date asc, c.slug asc;
$$;

grant execute on function public.fantasy_create_league(uuid, text, text, boolean, integer, uuid)
  to authenticated, service_role;
grant execute on function public.fantasy_join_league(text, uuid)
  to authenticated, service_role;
grant execute on function public.fantasy_leave_league(uuid, uuid)
  to authenticated, service_role;
grant execute on function public.fantasy_get_my_leagues(uuid)
  to authenticated, service_role;
grant execute on function public.fantasy_get_h2h_fixtures(uuid, integer)
  to authenticated, service_role;
grant execute on function public.fantasy_get_league_members(uuid)
  to authenticated, service_role;
grant execute on function public.fantasy_refresh_gameweek_h2h_results(uuid)
  to service_role;
grant execute on function public.fantasy_get_competition_bracket(uuid)
  to anon, authenticated, service_role;
grant execute on function public.fantasy_get_notification_topics()
  to authenticated, service_role;
grant execute on function public.fantasy_update_notification_preference(uuid, boolean, boolean, boolean, boolean)
  to authenticated, service_role;
grant execute on function public.fantasy_get_active_sync_competitions()
  to service_role;

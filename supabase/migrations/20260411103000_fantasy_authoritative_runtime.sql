-- Authoritative fantasy runtime fixes:
-- - server-side budget and transfer enforcement
-- - club-scoped competition visibility/playability enforcement
-- - chip availability and free-transfer state
-- - fixture-level stat persistence for DGW-safe scoring
-- - public manager-name privacy hardening

create table if not exists fantasy.fantasy_fixtures (
  id                  uuid primary key default uuid_generate_v4(),
  external_fixture_id bigint not null unique,
  competition_id      uuid not null references fantasy.competitions(id) on delete cascade,
  gameweek_id         uuid not null references fantasy.gameweeks(id) on delete cascade,
  provider            text,
  external_league_id  integer,
  external_season     integer,
  status_short        text not null,
  elapsed_minutes     integer,
  last_synced_at      timestamptz not null default now()
);

create index if not exists idx_fantasy_fixtures_gameweek
  on fantasy.fantasy_fixtures(gameweek_id, status_short);

create table if not exists fantasy.player_fixture_stats (
  id                        uuid primary key default uuid_generate_v4(),
  fixture_id                uuid not null references fantasy.fantasy_fixtures(id) on delete cascade,
  player_id                 integer not null references fantasy.players(external_id),
  gameweek_id               uuid not null references fantasy.gameweeks(id) on delete cascade,
  minutes_played            integer not null default 0,
  goals                     integer not null default 0,
  assists                   integer not null default 0,
  clean_sheet               boolean not null default false,
  goals_conceded            integer not null default 0,
  yellow_cards              integer not null default 0,
  red_cards                 integer not null default 0,
  penalties_saved           integer not null default 0,
  penalties_missed          integer not null default 0,
  own_goals                 integer not null default 0,
  saves                     integer not null default 0,
  bonus_points              integer not null default 0,
  bps_score                 integer not null default 0,
  defensive_contributions   integer not null default 0,
  stage_advanced            boolean not null default false,
  raw_points                integer not null default 0,
  last_synced_at            timestamptz not null default now(),
  unique (fixture_id, player_id)
);

create index if not exists idx_player_fixture_stats_gameweek
  on fantasy.player_fixture_stats(gameweek_id, player_id);

grant select on fantasy.fantasy_fixtures to anon, authenticated, service_role;
grant select on fantasy.player_fixture_stats to anon, authenticated, service_role;

alter table fantasy.fantasy_fixtures enable row level security;
alter table fantasy.player_fixture_stats enable row level security;

drop policy if exists "fixtures_public_read" on fantasy.fantasy_fixtures;
create policy "fixtures_public_read"
on fantasy.fantasy_fixtures
for select
using (true);

drop policy if exists "player_fixture_stats_public_read" on fantasy.player_fixture_stats;
create policy "player_fixture_stats_public_read"
on fantasy.player_fixture_stats
for select
using (true);

drop policy if exists "fixtures_service_write" on fantasy.fantasy_fixtures;
create policy "fixtures_service_write"
on fantasy.fantasy_fixtures
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists "player_fixture_stats_service_write" on fantasy.player_fixture_stats;
create policy "player_fixture_stats_service_write"
on fantasy.player_fixture_stats
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

create or replace function fantasy.assert_entry_gameweek_matches_competition(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns uuid
language plpgsql
as $$
declare
  v_competition_id uuid;
  v_gameweek_competition_id uuid;
begin
  select competition_id
  into v_competition_id
  from fantasy.fantasy_entries
  where id = p_entry_id;

  if v_competition_id is null then
    raise exception 'Fantasy entry not found.';
  end if;

  select competition_id
  into v_gameweek_competition_id
  from fantasy.gameweeks
  where id = p_gameweek_id;

  if v_gameweek_competition_id is null then
    raise exception 'Gameweek not found.';
  end if;

  if v_gameweek_competition_id <> v_competition_id then
    raise exception 'Gameweek does not belong to the same competition as the fantasy entry.';
  end if;

  return v_competition_id;
end;
$$;

create or replace function fantasy.assert_competition_access(
  p_competition_id uuid,
  p_require_playable boolean default false,
  p_require_entry_window boolean default false
) returns void
language plpgsql
as $$
declare
  v_club_id bigint;
  v_visible boolean;
  v_playable boolean;
  v_open_at timestamptz;
  v_close_at timestamptz;
  v_status fantasy.competition_status;
begin
  if auth.role() = 'service_role' then
    return;
  end if;

  v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  if v_club_id is null then
    raise exception 'Club context required for fantasy competition access.';
  end if;

  select
    c.status,
    e.is_visible,
    e.is_playable,
    e.entry_window_opens_at,
    e.entry_window_closes_at
  into
    v_status,
    v_visible,
    v_playable,
    v_open_at,
    v_close_at
  from fantasy.competitions c
  left join public.fantasy_competition_enablements e
    on e.competition_id = c.id
   and e.club_id = v_club_id
  where c.id = p_competition_id;

  if v_status is null then
    raise exception 'Fantasy competition not found.';
  end if;

  if coalesce(v_visible, false) = false then
    raise exception 'Fantasy competition is not enabled for this club.';
  end if;

  if p_require_playable and (v_status <> 'active' or coalesce(v_playable, false) = false) then
    raise exception 'Fantasy competition is not currently playable.';
  end if;

  if p_require_entry_window then
    if v_open_at is not null and now() < v_open_at then
      raise exception 'Fantasy entry window is not open yet.';
    end if;

    if v_close_at is not null and now() > v_close_at then
      raise exception 'Fantasy entry window has closed.';
    end if;
  end if;
end;
$$;

create or replace function fantasy.resolve_chip_window(
  p_competition_id uuid,
  p_gameweek_id uuid
) returns text
language plpgsql
stable
as $$
declare
  v_gameweek_number integer;
  v_max_gameweek_number integer;
  v_boundary integer;
begin
  select gw.number
  into v_gameweek_number
  from fantasy.gameweeks gw
  where gw.id = p_gameweek_id
    and gw.competition_id = p_competition_id;

  if v_gameweek_number is null then
    raise exception 'Gameweek not found for competition.';
  end if;

  select coalesce(max(number), 1)
  into v_max_gameweek_number
  from fantasy.gameweeks
  where competition_id = p_competition_id;

  v_boundary := greatest(ceil(v_max_gameweek_number::numeric / 2.0)::integer, 1);

  if v_gameweek_number <= v_boundary then
    return 'H1';
  end if;

  return 'H2';
end;
$$;

create or replace function fantasy.resolve_effective_squad_gameweek(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns uuid
language sql
stable
as $$
  with target as (
    select gw.id, gw.number, gw.competition_id
    from fantasy.gameweeks gw
    join fantasy.fantasy_entries fe
      on fe.competition_id = gw.competition_id
    where fe.id = p_entry_id
      and gw.id = p_gameweek_id
  )
  select gw.id
  from fantasy.gameweeks gw
  join target t
    on t.competition_id = gw.competition_id
   and gw.number <= t.number
  where exists (
      select 1
      from fantasy.squad_selections ss
      where ss.entry_id = p_entry_id
        and ss.gameweek_id = gw.id
    )
    and (
      gw.id = p_gameweek_id
      or not exists (
        select 1
        from fantasy.entry_gameweek_scores egs
        where egs.entry_id = p_entry_id
          and egs.gameweek_id = gw.id
          and egs.chip_played = 'free_hit'
      )
    )
  order by gw.number desc
  limit 1;
$$;

create or replace function fantasy.materialize_squad_for_gameweek(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns integer
language plpgsql
as $$
declare
  v_existing_count integer := 0;
  v_source_gameweek_id uuid;
begin
  select count(*)
  into v_existing_count
  from fantasy.squad_selections
  where entry_id = p_entry_id
    and gameweek_id = p_gameweek_id;

  if v_existing_count > 0 then
    return v_existing_count;
  end if;

  v_source_gameweek_id := fantasy.resolve_effective_squad_gameweek(p_entry_id, p_gameweek_id);
  if v_source_gameweek_id is null or v_source_gameweek_id = p_gameweek_id then
    return 0;
  end if;

  insert into fantasy.squad_selections (
    entry_id,
    gameweek_id,
    player_id,
    position,
    is_starter,
    bench_order,
    is_captain,
    is_vice_captain,
    purchase_price,
    multiplier
  )
  select
    entry_id,
    p_gameweek_id,
    player_id,
    position,
    is_starter,
    bench_order,
    is_captain,
    is_vice_captain,
    purchase_price,
    multiplier
  from fantasy.squad_selections
  where entry_id = p_entry_id
    and gameweek_id = v_source_gameweek_id;

  get diagnostics v_existing_count = row_count;
  return v_existing_count;
end;
$$;

create or replace function fantasy.ensure_entry_gameweek_score_row(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns fantasy.entry_gameweek_scores
language plpgsql
as $$
declare
  v_row fantasy.entry_gameweek_scores;
begin
  insert into fantasy.entry_gameweek_scores (
    entry_id,
    gameweek_id
  )
  values (
    p_entry_id,
    p_gameweek_id
  )
  on conflict (entry_id, gameweek_id)
  do update set
    entry_id = excluded.entry_id
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function fantasy.get_base_free_transfers(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns integer
language plpgsql
stable
as $$
declare
  v_competition_id uuid;
  v_target_number integer;
  v_free_transfers integer := 1;
  v_max_banked integer := 5;
  v_available integer := 1;
  rec record;
begin
  select
    fe.competition_id,
    gw.number,
    coalesce((c.transfer_config ->> 'free_transfers')::integer, 1),
    coalesce((c.transfer_config ->> 'max_banked_transfers')::integer, 5)
  into
    v_competition_id,
    v_target_number,
    v_free_transfers,
    v_max_banked
  from fantasy.fantasy_entries fe
  join fantasy.competitions c
    on c.id = fe.competition_id
  join fantasy.gameweeks gw
    on gw.id = p_gameweek_id
   and gw.competition_id = c.id
  where fe.id = p_entry_id;

  if v_target_number is null then
    raise exception 'Unable to resolve fantasy transfer state.';
  end if;

  v_available := greatest(v_free_transfers, 1);

  for rec in
    select
      gw.number,
      coalesce(egs.transfers_made, 0) as transfers_made,
      coalesce(egs.chip_played, '') as chip_played
    from fantasy.gameweeks gw
    left join fantasy.entry_gameweek_scores egs
      on egs.gameweek_id = gw.id
     and egs.entry_id = p_entry_id
    where gw.competition_id = v_competition_id
      and gw.number < v_target_number
    order by gw.number asc
  loop
    if rec.chip_played in ('wildcard', 'free_hit') then
      v_available := least(v_available + v_free_transfers, v_max_banked);
    else
      v_available := least(
        greatest(v_available - rec.transfers_made, 0) + v_free_transfers,
        v_max_banked
      );
    end if;
  end loop;

  return greatest(v_available, 1);
end;
$$;

create or replace function fantasy.compute_player_fixture_points(
  p_fixture_stats_id uuid,
  p_position fantasy.player_position,
  p_rules jsonb
) returns integer
language plpgsql
stable
as $$
declare
  s fantasy.player_fixture_stats;
  pts integer := 0;
  goals_pts integer := 0;
  cs_pts integer := 0;
  dc_threshold integer := 0;
  conceded_penalty integer := coalesce((p_rules ->> 'goals_conceded_per_2')::integer, -1);
  save_bonus integer := coalesce((p_rules ->> 'saves_per_3')::integer, 1);
begin
  select *
  into s
  from fantasy.player_fixture_stats
  where id = p_fixture_stats_id;

  if not found then
    return 0;
  end if;

  if s.minutes_played > 0 and s.minutes_played < 60 then
    pts := pts + coalesce((p_rules ->> 'points_sub_60')::integer, 1);
  elsif s.minutes_played >= 60 then
    pts := pts + coalesce((p_rules ->> 'points_60_plus')::integer, 2);
  end if;

  case p_position
    when 'GK', 'DEF' then goals_pts := coalesce((p_rules -> 'goals' ->> 'GK_DEF')::integer, 6);
    when 'MID' then goals_pts := coalesce((p_rules -> 'goals' ->> 'MID')::integer, 5);
    when 'FWD' then goals_pts := coalesce((p_rules -> 'goals' ->> 'FWD')::integer, 4);
  end case;
  pts := pts + (s.goals * goals_pts);

  pts := pts + (s.assists * coalesce((p_rules ->> 'assists_all')::integer, 3));

  if s.clean_sheet and s.minutes_played >= 60 then
    case p_position
      when 'GK', 'DEF' then cs_pts := coalesce((p_rules -> 'clean_sheet' ->> 'GK_DEF')::integer, 4);
      when 'MID' then cs_pts := coalesce((p_rules -> 'clean_sheet' ->> 'MID')::integer, 1);
      else cs_pts := 0;
    end case;
    pts := pts + cs_pts;
  end if;

  if p_position in ('GK', 'DEF') and s.goals_conceded > 0 then
    pts := pts + ((floor(s.goals_conceded::numeric / 2) * conceded_penalty)::integer);
  end if;

  if p_position = 'GK' and s.saves >= 3 then
    pts := pts + (floor(s.saves::numeric / 3)::integer * save_bonus);
  end if;

  pts := pts + (s.penalties_saved * coalesce((p_rules ->> 'penalty_save')::integer, 5));
  pts := pts + (s.penalties_missed * coalesce((p_rules ->> 'penalty_miss')::integer, -2));
  pts := pts + (s.yellow_cards * coalesce((p_rules ->> 'yellow_card')::integer, -1));
  pts := pts + (s.red_cards * coalesce((p_rules ->> 'red_card')::integer, -3));
  pts := pts + (s.own_goals * coalesce((p_rules ->> 'own_goal')::integer, -2));
  pts := pts + s.bonus_points;

  case p_position
    when 'DEF', 'GK' then
      dc_threshold := coalesce((p_rules -> 'defensive_contributions' ->> 'DEF_threshold')::integer, 10);
    else
      dc_threshold := coalesce((p_rules -> 'defensive_contributions' ->> 'MID_FWD_threshold')::integer, 12);
  end case;

  if s.defensive_contributions >= dc_threshold then
    pts := pts + coalesce((p_rules -> 'defensive_contributions' ->> 'points')::integer, 2);
  end if;

  if s.stage_advanced then
    pts := pts + coalesce((p_rules ->> 'stage_advance')::integer, 0);
  end if;

  return pts;
end;
$$;

create or replace function fantasy.refresh_player_gameweek_stats(
  p_gameweek_id uuid
) returns integer
language plpgsql
as $$
declare
  v_rules jsonb;
  v_upserted integer := 0;
begin
  select c.scoring_rules
  into v_rules
  from fantasy.gameweeks gw
  join fantasy.competitions c
    on c.id = gw.competition_id
  where gw.id = p_gameweek_id;

  if v_rules is null then
    raise exception 'Scoring rules not found for gameweek %.', p_gameweek_id;
  end if;

  update fantasy.player_fixture_stats pfs
  set raw_points = fantasy.compute_player_fixture_points(pfs.id, p.position, v_rules)
  from fantasy.players p
  where p.external_id = pfs.player_id
    and pfs.gameweek_id = p_gameweek_id;

  insert into fantasy.player_gameweek_stats (
    player_id,
    gameweek_id,
    minutes_played,
    goals,
    assists,
    clean_sheet,
    goals_conceded,
    yellow_cards,
    red_cards,
    penalties_saved,
    penalties_missed,
    own_goals,
    saves,
    bps_score,
    bonus_points,
    defensive_contributions,
    raw_points,
    stage_advanced,
    last_synced_at
  )
  select
    pfs.player_id,
    p_gameweek_id,
    coalesce(sum(pfs.minutes_played), 0)::integer,
    coalesce(sum(pfs.goals), 0)::integer,
    coalesce(sum(pfs.assists), 0)::integer,
    bool_or(pfs.clean_sheet),
    coalesce(sum(pfs.goals_conceded), 0)::integer,
    coalesce(sum(pfs.yellow_cards), 0)::integer,
    coalesce(sum(pfs.red_cards), 0)::integer,
    coalesce(sum(pfs.penalties_saved), 0)::integer,
    coalesce(sum(pfs.penalties_missed), 0)::integer,
    coalesce(sum(pfs.own_goals), 0)::integer,
    coalesce(sum(pfs.saves), 0)::integer,
    coalesce(sum(pfs.bps_score), 0)::integer,
    coalesce(sum(pfs.bonus_points), 0)::integer,
    coalesce(sum(pfs.defensive_contributions), 0)::integer,
    coalesce(sum(pfs.raw_points), 0)::integer,
    bool_or(pfs.stage_advanced),
    now()
  from fantasy.player_fixture_stats pfs
  where pfs.gameweek_id = p_gameweek_id
  group by pfs.player_id
  on conflict (player_id, gameweek_id)
  do update set
    minutes_played = excluded.minutes_played,
    goals = excluded.goals,
    assists = excluded.assists,
    clean_sheet = excluded.clean_sheet,
    goals_conceded = excluded.goals_conceded,
    yellow_cards = excluded.yellow_cards,
    red_cards = excluded.red_cards,
    penalties_saved = excluded.penalties_saved,
    penalties_missed = excluded.penalties_missed,
    own_goals = excluded.own_goals,
    saves = excluded.saves,
    bps_score = excluded.bps_score,
    bonus_points = excluded.bonus_points,
    defensive_contributions = excluded.defensive_contributions,
    raw_points = excluded.raw_points,
    stage_advanced = excluded.stage_advanced,
    last_synced_at = now();

  get diagnostics v_upserted = row_count;
  return v_upserted;
end;
$$;

create or replace function fantasy.player_gameweek_points(
  p_stats_id uuid,
  p_position fantasy.player_position,
  p_rules jsonb
) returns integer
language plpgsql
stable
as $$
declare
  v_points integer := 0;
begin
  select raw_points
  into v_points
  from fantasy.player_gameweek_stats
  where id = p_stats_id;

  if v_points is null then
    return fantasy.compute_player_points(p_stats_id, p_position, p_rules);
  end if;

  return v_points;
end;
$$;

create or replace function fantasy.compute_player_points(
  p_stats_id uuid,
  p_position fantasy.player_position,
  p_rules jsonb
) returns integer
language plpgsql
stable
as $$
declare
  s fantasy.player_gameweek_stats;
  pts integer := 0;
  goals_pts integer := 0;
  cs_pts integer := 0;
  dc_threshold integer := 0;
  conceded_penalty integer := coalesce((p_rules ->> 'goals_conceded_per_2')::integer, -1);
  save_bonus integer := coalesce((p_rules ->> 'saves_per_3')::integer, 1);
begin
  select *
  into s
  from fantasy.player_gameweek_stats
  where id = p_stats_id;

  if not found then
    return 0;
  end if;

  if s.raw_points > 0 then
    return s.raw_points;
  end if;

  if s.minutes_played > 0 and s.minutes_played < 60 then
    pts := pts + coalesce((p_rules ->> 'points_sub_60')::integer, 1);
  elsif s.minutes_played >= 60 then
    pts := pts + coalesce((p_rules ->> 'points_60_plus')::integer, 2);
  end if;

  case p_position
    when 'GK', 'DEF' then goals_pts := coalesce((p_rules -> 'goals' ->> 'GK_DEF')::integer, 6);
    when 'MID' then goals_pts := coalesce((p_rules -> 'goals' ->> 'MID')::integer, 5);
    when 'FWD' then goals_pts := coalesce((p_rules -> 'goals' ->> 'FWD')::integer, 4);
  end case;
  pts := pts + (s.goals * goals_pts);

  pts := pts + (s.assists * coalesce((p_rules ->> 'assists_all')::integer, 3));

  if s.clean_sheet and s.minutes_played >= 60 then
    case p_position
      when 'GK', 'DEF' then cs_pts := coalesce((p_rules -> 'clean_sheet' ->> 'GK_DEF')::integer, 4);
      when 'MID' then cs_pts := coalesce((p_rules -> 'clean_sheet' ->> 'MID')::integer, 1);
      else cs_pts := 0;
    end case;
    pts := pts + cs_pts;
  end if;

  if p_position in ('GK', 'DEF') and s.goals_conceded > 0 then
    pts := pts + ((floor(s.goals_conceded::numeric / 2) * conceded_penalty)::integer);
  end if;

  if p_position = 'GK' and s.saves >= 3 then
    pts := pts + (floor(s.saves::numeric / 3)::integer * save_bonus);
  end if;

  pts := pts + (s.penalties_saved * coalesce((p_rules ->> 'penalty_save')::integer, 5));
  pts := pts + (s.penalties_missed * coalesce((p_rules ->> 'penalty_miss')::integer, -2));
  pts := pts + (s.yellow_cards * coalesce((p_rules ->> 'yellow_card')::integer, -1));
  pts := pts + (s.red_cards * coalesce((p_rules ->> 'red_card')::integer, -3));
  pts := pts + (s.own_goals * coalesce((p_rules ->> 'own_goal')::integer, -2));
  pts := pts + s.bonus_points;

  case p_position
    when 'DEF', 'GK' then
      dc_threshold := coalesce((p_rules -> 'defensive_contributions' ->> 'DEF_threshold')::integer, 10);
    else
      dc_threshold := coalesce((p_rules -> 'defensive_contributions' ->> 'MID_FWD_threshold')::integer, 12);
  end case;

  if s.defensive_contributions >= dc_threshold then
    pts := pts + coalesce((p_rules -> 'defensive_contributions' ->> 'points')::integer, 2);
  end if;

  if s.stage_advanced then
    pts := pts + coalesce((p_rules ->> 'stage_advance')::integer, 0);
  end if;

  return pts;
end;
$$;

create or replace function fantasy.save_squad_selections(
  p_entry_id uuid,
  p_gameweek_id uuid,
  p_selections jsonb
) returns integer
language plpgsql
as $$
declare
  v_competition_id uuid;
  v_squad_config jsonb;
  v_total integer;
  v_distinct_players integer;
  v_starters integer;
  v_captains integer;
  v_vice_captains integer;
  v_purchase_total integer;
  v_squad_size integer;
  v_starters_required integer;
  v_budget integer;
  v_source_gameweek_id uuid;
begin
  perform fantasy.assert_entry_owner(p_entry_id);
  perform fantasy.assert_gameweek_open(p_gameweek_id);
  v_competition_id := fantasy.assert_entry_gameweek_matches_competition(p_entry_id, p_gameweek_id);
  perform fantasy.assert_competition_access(v_competition_id, true, false);

  select c.squad_config
  into v_squad_config
  from fantasy.fantasy_entries fe
  join fantasy.competitions c
    on c.id = fe.competition_id
  where fe.id = p_entry_id;

  if v_competition_id is null then
    raise exception 'Fantasy entry not found.';
  end if;

  v_source_gameweek_id := fantasy.resolve_effective_squad_gameweek(p_entry_id, p_gameweek_id);

  with payload as (
    select *
    from jsonb_to_recordset(p_selections) as payload(
      player_id integer,
      position fantasy.player_position,
      is_starter boolean,
      bench_order integer,
      is_captain boolean,
      is_vice_captain boolean,
      purchase_price integer,
      multiplier integer
    )
  ),
  resolved_prices as (
    select
      payload.player_id,
      coalesce(existing.purchase_price, prices.price) as resolved_purchase_price
    from payload
    join fantasy.player_competition_prices prices
      on prices.player_id = payload.player_id
     and prices.competition_id = v_competition_id
    left join fantasy.squad_selections existing
      on existing.entry_id = p_entry_id
     and existing.gameweek_id = v_source_gameweek_id
     and existing.player_id = payload.player_id
  )
  select
    count(*)::integer,
    count(distinct payload.player_id)::integer,
    count(*) filter (where payload.is_starter)::integer,
    count(*) filter (where payload.is_captain)::integer,
    count(*) filter (where payload.is_vice_captain)::integer,
    coalesce(sum(resolved_prices.resolved_purchase_price), 0)::integer
  into
    v_total,
    v_distinct_players,
    v_starters,
    v_captains,
    v_vice_captains,
    v_purchase_total
  from payload
  join resolved_prices
    on resolved_prices.player_id = payload.player_id;

  v_squad_size := coalesce((v_squad_config ->> 'squad_size')::integer, 15);
  v_starters_required := coalesce((v_squad_config ->> 'starters')::integer, 11);
  v_budget := coalesce((v_squad_config ->> 'budget')::integer, 1000);

  if v_total <> v_squad_size then
    raise exception 'Expected % squad members, received %.', v_squad_size, v_total;
  end if;

  if v_distinct_players <> v_total then
    raise exception 'Duplicate players are not allowed in a fantasy squad.';
  end if;

  if v_starters <> v_starters_required then
    raise exception 'Expected % starters, received %.', v_starters_required, v_starters;
  end if;

  if v_captains <> 1 or v_vice_captains <> 1 then
    raise exception 'Exactly one captain and one vice-captain are required.';
  end if;

  if v_purchase_total > v_budget then
    raise exception 'Squad budget exceeded.';
  end if;

  if exists (
    select 1
    from (
      select bench_order, count(*) as occurrences
      from jsonb_to_recordset(p_selections) as payload(
        player_id integer,
        position fantasy.player_position,
        is_starter boolean,
        bench_order integer,
        is_captain boolean,
        is_vice_captain boolean,
        purchase_price integer,
        multiplier integer
      )
      where bench_order is not null
      group by bench_order
      having count(*) > 1
    ) duplicate_orders
  ) then
    raise exception 'Bench order values must be unique.';
  end if;

  if exists (
    with payload as (
      select *
      from jsonb_to_recordset(p_selections) as payload(
        player_id integer,
        position fantasy.player_position,
        is_starter boolean,
        bench_order integer,
        is_captain boolean,
        is_vice_captain boolean,
        purchase_price integer,
        multiplier integer
      )
    )
    select 1
    from payload
    left join fantasy.players p
      on p.external_id = payload.player_id
    left join fantasy.player_competition_prices prices
      on prices.player_id = payload.player_id
     and prices.competition_id = v_competition_id
    where p.external_id is null
      or p.position is distinct from payload.position
      or prices.player_id is null
  ) then
    raise exception 'Every selection must map to a valid priced player with a matching position.';
  end if;

  if exists (
    with payload as (
      select *
      from jsonb_to_recordset(p_selections) as payload(
        player_id integer,
        position fantasy.player_position,
        is_starter boolean,
        bench_order integer,
        is_captain boolean,
        is_vice_captain boolean,
        purchase_price integer,
        multiplier integer
      )
    ),
    club_counts as (
      select p.team_id, count(*) as club_count
      from payload
      join fantasy.players p
        on p.external_id = payload.player_id
      group by p.team_id
    )
    select 1
    from club_counts
    where club_count > coalesce((v_squad_config ->> 'max_per_club')::integer, 3)
  ) then
    raise exception 'Maximum players per club exceeded for this competition.';
  end if;

  if exists (
    with payload as (
      select *
      from jsonb_to_recordset(p_selections) as payload(
        player_id integer,
        position fantasy.player_position,
        is_starter boolean,
        bench_order integer,
        is_captain boolean,
        is_vice_captain boolean,
        purchase_price integer,
        multiplier integer
      )
      where is_starter = true
    )
    select 1
    from (
      select
        count(*) filter (where position = 'GK') as gk_count,
        count(*) filter (where position = 'DEF') as def_count,
        count(*) filter (where position = 'MID') as mid_count,
        count(*) filter (where position = 'FWD') as fwd_count
      from payload
    ) counts
    where gk_count <> 1
      or def_count < coalesce((v_squad_config ->> 'min_def')::integer, 3)
      or def_count > coalesce((v_squad_config ->> 'max_def')::integer, 5)
      or mid_count < coalesce((v_squad_config ->> 'min_mid')::integer, 2)
      or mid_count > coalesce((v_squad_config ->> 'max_mid')::integer, 5)
      or fwd_count < coalesce((v_squad_config ->> 'min_fwd')::integer, 1)
      or fwd_count > coalesce((v_squad_config ->> 'max_fwd')::integer, 3)
  ) then
    raise exception 'Selected starting formation is invalid.';
  end if;

  delete from fantasy.squad_selections
  where entry_id = p_entry_id
    and gameweek_id = p_gameweek_id;

  insert into fantasy.squad_selections (
    entry_id,
    gameweek_id,
    player_id,
    position,
    is_starter,
    bench_order,
    is_captain,
    is_vice_captain,
    purchase_price,
    multiplier
  )
  with payload as (
    select *
    from jsonb_to_recordset(p_selections) as payload(
      player_id integer,
      position fantasy.player_position,
      is_starter boolean,
      bench_order integer,
      is_captain boolean,
      is_vice_captain boolean,
      purchase_price integer,
      multiplier integer
    )
  ),
  resolved_prices as (
    select
      payload.player_id,
      coalesce(existing.purchase_price, prices.price) as resolved_purchase_price
    from payload
    join fantasy.player_competition_prices prices
      on prices.player_id = payload.player_id
     and prices.competition_id = v_competition_id
    left join fantasy.squad_selections existing
      on existing.entry_id = p_entry_id
     and existing.gameweek_id = v_source_gameweek_id
     and existing.player_id = payload.player_id
  )
  select
    p_entry_id,
    p_gameweek_id,
    payload.player_id,
    payload.position,
    coalesce(payload.is_starter, true),
    payload.bench_order,
    coalesce(payload.is_captain, false),
    coalesce(payload.is_vice_captain, false),
    resolved_prices.resolved_purchase_price,
    case
      when coalesce(payload.is_captain, false) then greatest(coalesce(payload.multiplier, 2), 2)
      else coalesce(payload.multiplier, 1)
    end
  from payload
  join resolved_prices
    on resolved_prices.player_id = payload.player_id;

  update fantasy.fantasy_entries
  set
    team_value = v_purchase_total,
    bank_balance = greatest(v_budget - v_purchase_total, 0),
    updated_at = now()
  where id = p_entry_id;

  return v_total;
end;
$$;

create or replace function fantasy.aggregate_entry_score(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns integer
language plpgsql
as $$
declare
  rules jsonb;
  squad_config jsonb;
  total_pts integer := 0;
  transfer_cost integer := 0;
  chip text;
  captain_mult integer;
  min_def integer;
  min_mid integer;
  min_fwd integer;
  starter_gk_count integer := 0;
  starter_def_count integer := 0;
  starter_mid_count integer := 0;
  starter_fwd_count integer := 0;
  missing_gk integer := 0;
  missing_outfield integer := 0;
  gk_bench_points integer := 0;
  gk_bench_available boolean := false;
  gk_bench_used boolean := false;
  captain_player_id integer := 0;
  vice_player_id integer := 0;
  captain_played boolean := false;
  vice_played boolean := false;
  captain_points integer := 0;
  vice_points integer := 0;
  bench_orders integer[] := '{}';
  bench_positions fantasy.player_position[] := '{}';
  bench_points integer[] := '{}';
  bench_played boolean[] := '{}';
  bench_player_ids integer[] := '{}';
  bench_count integer := 0;
  best_mask integer := 0;
  best_size integer := -1;
  best_orders integer[] := '{}';
  current_size integer;
  current_orders integer[] := '{}';
  current_def integer;
  current_mid integer;
  current_fwd integer;
  mask integer;
  idx integer;
  include_player boolean;
  rec record;
begin
  select
    c.scoring_rules,
    c.squad_config
  into
    rules,
    squad_config
  from fantasy.competitions c
  join fantasy.gameweeks gw
    on gw.competition_id = c.id
  where gw.id = p_gameweek_id;

  if rules is null then
    raise exception 'Scoring rules not found for gameweek %.', p_gameweek_id;
  end if;

  captain_mult := coalesce((rules ->> 'captain_multiplier')::integer, 2);
  min_def := coalesce((squad_config ->> 'min_def')::integer, 3);
  min_mid := coalesce((squad_config ->> 'min_mid')::integer, 2);
  min_fwd := coalesce((squad_config ->> 'min_fwd')::integer, 1);

  select chip_played, coalesce(transfer_cost, 0)
  into chip, transfer_cost
  from fantasy.entry_gameweek_scores
  where entry_id = p_entry_id
    and gameweek_id = p_gameweek_id;

  if chip = 'triple_captain' then
    captain_mult := coalesce((rules ->> 'triple_captain_multiplier')::integer, 3);
  end if;

  if chip = 'bench_boost' then
    for rec in
      select
        ss.player_id,
        ss.is_captain,
        ss.is_vice_captain,
        p.position,
        coalesce(pgs.id, null) as stats_id,
        coalesce(pgs.minutes_played, 0) as minutes_played,
        coalesce(pgs.raw_points, 0) as raw_points
      from fantasy.squad_selections ss
      join fantasy.players p
        on p.external_id = ss.player_id
      left join fantasy.player_gameweek_stats pgs
        on pgs.player_id = ss.player_id
       and pgs.gameweek_id = p_gameweek_id
      where ss.entry_id = p_entry_id
        and ss.gameweek_id = p_gameweek_id
    loop
      if rec.stats_id is not null then
        total_pts := total_pts + rec.raw_points;
      end if;

      if rec.is_captain then
        captain_player_id := rec.player_id;
        captain_played := rec.minutes_played > 0;
        captain_points := rec.raw_points;
      elsif rec.is_vice_captain then
        vice_player_id := rec.player_id;
        vice_played := rec.minutes_played > 0;
        vice_points := rec.raw_points;
      end if;
    end loop;
  else
    for rec in
      select
        ss.player_id,
        ss.is_starter,
        ss.is_captain,
        ss.is_vice_captain,
        ss.bench_order,
        p.position,
        pgs.id as stats_id,
        coalesce(pgs.minutes_played, 0) as minutes_played,
        coalesce(pgs.raw_points, 0) as raw_points
      from fantasy.squad_selections ss
      join fantasy.players p
        on p.external_id = ss.player_id
      left join fantasy.player_gameweek_stats pgs
        on pgs.player_id = ss.player_id
       and pgs.gameweek_id = p_gameweek_id
      where ss.entry_id = p_entry_id
        and ss.gameweek_id = p_gameweek_id
      order by ss.is_starter desc, ss.bench_order nulls last
    loop
      include_player := rec.stats_id is not null and rec.minutes_played > 0;

      if rec.is_captain then
        captain_player_id := rec.player_id;
        captain_played := include_player;
        captain_points := rec.raw_points;
      elsif rec.is_vice_captain then
        vice_player_id := rec.player_id;
        vice_played := include_player;
        vice_points := rec.raw_points;
      end if;

      if rec.is_starter then
        if include_player then
          total_pts := total_pts + rec.raw_points;
          case rec.position
            when 'GK' then starter_gk_count := starter_gk_count + 1;
            when 'DEF' then starter_def_count := starter_def_count + 1;
            when 'MID' then starter_mid_count := starter_mid_count + 1;
            when 'FWD' then starter_fwd_count := starter_fwd_count + 1;
          end case;
        else
          if rec.position = 'GK' then
            missing_gk := missing_gk + 1;
          else
            missing_outfield := missing_outfield + 1;
          end if;
        end if;
      else
        bench_count := bench_count + 1;
        bench_orders := array_append(bench_orders, coalesce(rec.bench_order, bench_count));
        bench_positions := array_append(bench_positions, rec.position);
        bench_player_ids := array_append(bench_player_ids, rec.player_id);
        bench_played := array_append(bench_played, include_player);
        bench_points := array_append(bench_points, case when include_player then rec.raw_points else 0 end);

        if rec.position = 'GK' and include_player then
          gk_bench_available := true;
          gk_bench_points := rec.raw_points;
        end if;
      end if;
    end loop;

    if missing_gk > 0 and gk_bench_available then
      total_pts := total_pts + gk_bench_points;
      gk_bench_used := true;
    end if;

    if missing_outfield > 0 and bench_count > 0 then
      for mask in 0..(power(2::numeric, bench_count)::integer - 1) loop
        current_size := 0;
        current_orders := '{}';
        current_def := starter_def_count;
        current_mid := starter_mid_count;
        current_fwd := starter_fwd_count;

        for idx in 1..bench_count loop
          if bench_positions[idx] = 'GK' then
            continue;
          end if;

          if ((mask >> (idx - 1)) & 1) = 1 then
            if not bench_played[idx] then
              current_size := -1;
              exit;
            end if;

            current_size := current_size + 1;
            current_orders := array_append(current_orders, bench_orders[idx]);

            case bench_positions[idx]
              when 'DEF' then current_def := current_def + 1;
              when 'MID' then current_mid := current_mid + 1;
              when 'FWD' then current_fwd := current_fwd + 1;
              else null;
            end case;
          end if;
        end loop;

        if current_size < 0 or current_size > missing_outfield then
          continue;
        end if;

        if current_def < min_def or current_mid < min_mid or current_fwd < min_fwd then
          continue;
        end if;

        if current_size > best_size
          or (current_size = best_size and (best_orders = '{}' or current_orders < best_orders)) then
          best_mask := mask;
          best_size := current_size;
          best_orders := current_orders;
        end if;
      end loop;

      if best_size > 0 then
        for idx in 1..bench_count loop
          if ((best_mask >> (idx - 1)) & 1) = 1 and bench_positions[idx] <> 'GK' then
            total_pts := total_pts + bench_points[idx];
          end if;
        end loop;
      end if;
    end if;

    if not captain_played and vice_player_id <> 0 then
      vice_played := false;
      if best_size > 0 or gk_bench_used or starter_gk_count > 0 or starter_def_count > 0 or starter_mid_count > 0 or starter_fwd_count > 0 then
        for idx in 1..bench_count loop
          if bench_player_ids[idx] = vice_player_id then
            if bench_positions[idx] = 'GK' then
              vice_played := gk_bench_used and bench_played[idx];
            else
              vice_played := ((best_mask >> (idx - 1)) & 1) = 1 and bench_played[idx];
            end if;
          end if;
        end loop;
      end if;
    end if;
  end if;

  if captain_player_id <> 0 and captain_played then
    total_pts := total_pts + (captain_points * greatest(captain_mult - 1, 0));
  elsif vice_player_id <> 0 and vice_played then
    total_pts := total_pts + (vice_points * greatest(captain_mult - 1, 0));
  end if;

  total_pts := total_pts + transfer_cost;

  insert into fantasy.entry_gameweek_scores (
    entry_id,
    gameweek_id,
    points,
    calculated_at
  )
  values (
    p_entry_id,
    p_gameweek_id,
    total_pts,
    now()
  )
  on conflict (entry_id, gameweek_id)
  do update set
    points = excluded.points,
    calculated_at = now();

  update fantasy.fantasy_entries
  set
    overall_points = (
      select coalesce(sum(points), 0)
      from fantasy.entry_gameweek_scores
      where entry_id = p_entry_id
    ),
    updated_at = now()
  where id = p_entry_id;

  return total_pts;
end;
$$;

create or replace function public.fantasy_create_entry(
  p_competition_slug text,
  p_team_name text default null
) returns uuid
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_user_id uuid;
  v_competition_id uuid;
  v_entry_id uuid;
  v_budget integer := 1000;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication is required to create a fantasy entry.';
  end if;

  select id, coalesce((squad_config ->> 'budget')::integer, 1000)
  into v_competition_id, v_budget
  from fantasy.competitions
  where slug = p_competition_slug;

  if v_competition_id is null then
    raise exception 'Fantasy competition % was not found.', p_competition_slug;
  end if;

  perform fantasy.assert_competition_access(v_competition_id, true, true);

  insert into fantasy.fantasy_entries (
    user_id,
    competition_id,
    team_name,
    bank_balance
  )
  values (
    v_user_id,
    v_competition_id,
    coalesce(nullif(btrim(p_team_name), ''), 'My Fantasy XI'),
    v_budget
  )
  on conflict (user_id, competition_id)
  do update set
    updated_at = now()
  returning id into v_entry_id;

  return v_entry_id;
end;
$$;

create or replace function public.fantasy_get_mobile_competitions()
returns setof fantasy.competitions
language sql
security definer
set search_path = public, fantasy
as $$
  select c.*
  from fantasy.competitions c
  join public.fantasy_competition_enablements e
    on e.competition_id = c.id
  where e.club_id = nullif(public.requesting_club_id(), '')::bigint
    and e.is_visible = true
  order by e.sort_order asc, c.start_date asc;
$$;

create or replace function public.fantasy_get_mobile_competition(
  p_slug text
) returns fantasy.competitions
language sql
security definer
set search_path = public, fantasy
as $$
  select c
  from fantasy.competitions c
  join public.fantasy_competition_enablements e
    on e.competition_id = c.id
  where e.club_id = nullif(public.requesting_club_id(), '')::bigint
    and e.is_visible = true
    and c.slug = p_slug
  limit 1;
$$;

create or replace function public.fantasy_get_player_pool_by_competition_id(
  p_competition_id uuid
) returns table (
  external_id integer,
  name text,
  short_name text,
  photo_url text,
  "position" text,
  team_id integer,
  team_name text,
  team_short text,
  team_logo_url text,
  nationality text,
  price integer,
  price_change integer,
  ownership_percent numeric,
  form_points integer,
  total_points integer,
  recent_points integer[],
  fixture_difficulty jsonb
)
language sql
security definer
set search_path = public, fantasy
as $$
  with guard as (
    select fantasy.assert_competition_access(p_competition_id, false, false)
  ),
  competition_gameweeks as (
    select id, number
    from fantasy.gameweeks
    where competition_id = p_competition_id
  ),
  aggregated as (
    select
      pgs.player_id,
      coalesce(sum(pgs.raw_points), 0)::integer as total_points,
      coalesce(
        round(
          avg(recent.raw_points)
        )::integer,
        0
      ) as form_points
    from fantasy.player_gameweek_stats pgs
    left join lateral (
      select pgs_recent.raw_points
      from fantasy.player_gameweek_stats pgs_recent
      join competition_gameweeks gw_recent
        on gw_recent.id = pgs_recent.gameweek_id
      where pgs_recent.player_id = pgs.player_id
      order by gw_recent.number desc
      limit 5
    ) recent on true
    join competition_gameweeks gw
      on gw.id = pgs.gameweek_id
    group by pgs.player_id
  )
  select
    p.external_id,
    p.name,
    p.short_name,
    p.photo_url,
    p.position::text as position,
    p.team_id,
    p.team_name,
    p.team_short,
    p.team_logo_url,
    p.nationality,
    pr.price,
    pr.price_change,
    pr.ownership_percent,
    coalesce(agg.form_points, 0) as form_points,
    coalesce(agg.total_points, 0) as total_points,
    coalesce((
      select array_agg(recent_rows.raw_points order by recent_rows.number desc)
      from (
        select
          pgs_recent.raw_points,
          gw_recent.number
        from fantasy.player_gameweek_stats pgs_recent
        join competition_gameweeks gw_recent
          on gw_recent.id = pgs_recent.gameweek_id
        where pgs_recent.player_id = p.external_id
        order by gw_recent.number desc
        limit 5
      ) recent_rows
    ), '{}'::integer[]) as recent_points,
    '[]'::jsonb as fixture_difficulty
  from fantasy.player_competition_prices pr
  join guard
    on true
  join fantasy.players p
    on p.external_id = pr.player_id
  left join aggregated agg
    on agg.player_id = p.external_id
  where pr.competition_id = p_competition_id
  order by
    case p.position
      when 'GK' then 0
      when 'DEF' then 1
      when 'MID' then 2
      else 3
    end,
    pr.price desc,
    p.team_name asc,
    p.name asc;
$$;

create or replace function public.fantasy_get_player_by_competition_id(
  p_competition_id uuid,
  p_player_id integer
) returns table (
  external_id integer,
  name text,
  short_name text,
  photo_url text,
  "position" text,
  team_id integer,
  team_name text,
  team_short text,
  team_logo_url text,
  nationality text,
  price integer,
  price_change integer,
  ownership_percent numeric,
  form_points integer,
  total_points integer,
  recent_points integer[],
  fixture_difficulty jsonb
)
language sql
security definer
set search_path = public, fantasy
as $$
  select *
  from public.fantasy_get_player_pool_by_competition_id(p_competition_id)
  where external_id = p_player_id;
$$;

create or replace function public.fantasy_get_entry_gameweek_state(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns table (
  entry_id uuid,
  gameweek_id uuid,
  free_transfers_available integer,
  free_transfers_remaining integer,
  transfers_made integer,
  transfer_cost integer,
  chip_played text,
  bank_balance integer,
  team_value integer
)
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_row fantasy.entry_gameweek_scores;
  v_base_free integer := 1;
  v_remaining integer := 1;
  v_chip text;
  v_bank integer := 0;
  v_team_value integer := 0;
begin
  perform fantasy.assert_entry_owner(p_entry_id);
  perform fantasy.assert_entry_gameweek_matches_competition(p_entry_id, p_gameweek_id);

  v_row := fantasy.ensure_entry_gameweek_score_row(p_entry_id, p_gameweek_id);
  v_base_free := fantasy.get_base_free_transfers(p_entry_id, p_gameweek_id);
  v_chip := v_row.chip_played;

  if v_chip in ('wildcard', 'free_hit') then
    v_remaining := v_base_free;
  else
    v_remaining := greatest(v_base_free - coalesce(v_row.transfers_made, 0), 0);
  end if;

  select bank_balance, team_value
  into v_bank, v_team_value
  from fantasy.fantasy_entries
  where id = p_entry_id;

  return query
  select
    p_entry_id,
    p_gameweek_id,
    v_base_free,
    v_remaining,
    coalesce(v_row.transfers_made, 0),
    coalesce(v_row.transfer_cost, 0),
    v_chip,
    coalesce(v_bank, 0),
    coalesce(v_team_value, 0);
end;
$$;

create or replace function fantasy.calculate_chip_projected_points(
  p_entry_id uuid,
  p_gameweek_id uuid,
  p_chip text
) returns integer
language plpgsql
stable
as $$
declare
  v_source_gameweek_id uuid;
  v_points integer := 0;
begin
  v_source_gameweek_id := fantasy.resolve_effective_squad_gameweek(p_entry_id, p_gameweek_id);
  if v_source_gameweek_id is null then
    return 0;
  end if;

  if p_chip = 'bench_boost' then
    select coalesce(sum(coalesce(pgs.raw_points, 0)), 0)::integer
    into v_points
    from fantasy.squad_selections ss
    left join fantasy.player_gameweek_stats pgs
      on pgs.player_id = ss.player_id
     and pgs.gameweek_id = p_gameweek_id
    where ss.entry_id = p_entry_id
      and ss.gameweek_id = v_source_gameweek_id
      and ss.is_starter = false;

    return coalesce(v_points, 0);
  end if;

  if p_chip = 'triple_captain' then
    select coalesce(pgs.raw_points, 0)::integer
    into v_points
    from fantasy.squad_selections ss
    left join fantasy.player_gameweek_stats pgs
      on pgs.player_id = ss.player_id
     and pgs.gameweek_id = p_gameweek_id
    where ss.entry_id = p_entry_id
      and ss.gameweek_id = v_source_gameweek_id
      and ss.is_captain = true
    limit 1;

    return coalesce(v_points, 0);
  end if;

  return 0;
end;
$$;

create or replace function public.fantasy_get_chip_statuses(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns table (
  chip text,
  is_available boolean,
  is_activated boolean,
  is_consumed boolean,
  description text,
  projected_points integer,
  gameweek_id uuid
)
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_competition_id uuid;
  v_chip_config jsonb;
  v_chips_used jsonb := '[]'::jsonb;
  v_current_chip text;
  v_window text;
begin
  perform fantasy.assert_entry_owner(p_entry_id);
  v_competition_id := fantasy.assert_entry_gameweek_matches_competition(p_entry_id, p_gameweek_id);

  select
    c.chip_config,
    fe.chips_used,
    egs.chip_played
  into
    v_chip_config,
    v_chips_used,
    v_current_chip
  from fantasy.fantasy_entries fe
  join fantasy.competitions c
    on c.id = fe.competition_id
  left join fantasy.entry_gameweek_scores egs
    on egs.entry_id = fe.id
   and egs.gameweek_id = p_gameweek_id
  where fe.id = p_entry_id;

  v_window := fantasy.resolve_chip_window(v_competition_id, p_gameweek_id);

  return query
  with chip_catalog as (
    select *
    from (
      values
        ('wildcard', 'Unlimited free transfers that permanently update your squad.'),
        ('free_hit', 'Unlimited free transfers for this gameweek only.'),
        ('triple_captain', 'Triple your captain''s score instead of doubling it.'),
        ('bench_boost', 'Count the points from every player on your bench.')
    ) as catalog(chip, description)
  )
  select
    catalog.chip,
    coalesce((v_chip_config ->> catalog.chip)::boolean, false)
      and not exists (
        select 1
        from jsonb_array_elements(coalesce(v_chips_used, '[]'::jsonb)) as used_chip
        where used_chip ->> 'chip' = catalog.chip
          and used_chip ->> 'window' = v_window
      ) as is_available,
    coalesce(v_current_chip, '') = catalog.chip as is_activated,
    exists (
      select 1
      from jsonb_array_elements(coalesce(v_chips_used, '[]'::jsonb)) as used_chip
      where used_chip ->> 'chip' = catalog.chip
        and used_chip ->> 'window' = v_window
    ) as is_consumed,
    catalog.description,
    fantasy.calculate_chip_projected_points(p_entry_id, p_gameweek_id, catalog.chip),
    p_gameweek_id
  from chip_catalog catalog;
end;
$$;

create or replace function public.fantasy_activate_chip(
  p_entry_id uuid,
  p_gameweek_id uuid,
  p_chip text
) returns text
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_competition_id uuid;
  v_chip_config jsonb;
  v_chips_used jsonb := '[]'::jsonb;
  v_window text;
  v_current_chip text;
  v_gameweek_number integer;
begin
  if p_chip not in ('wildcard', 'free_hit', 'triple_captain', 'bench_boost') then
    raise exception 'Unsupported fantasy chip: %.', p_chip;
  end if;

  perform fantasy.assert_entry_owner(p_entry_id);
  perform fantasy.assert_gameweek_open(p_gameweek_id);
  v_competition_id := fantasy.assert_entry_gameweek_matches_competition(p_entry_id, p_gameweek_id);
  perform fantasy.assert_competition_access(v_competition_id, true, false);

  select
    c.chip_config,
    fe.chips_used,
    gw.number,
    egs.chip_played
  into
    v_chip_config,
    v_chips_used,
    v_gameweek_number,
    v_current_chip
  from fantasy.fantasy_entries fe
  join fantasy.competitions c
    on c.id = fe.competition_id
  join fantasy.gameweeks gw
    on gw.id = p_gameweek_id
   and gw.competition_id = c.id
  left join fantasy.entry_gameweek_scores egs
    on egs.entry_id = fe.id
   and egs.gameweek_id = p_gameweek_id
  where fe.id = p_entry_id;

  if coalesce((v_chip_config ->> p_chip)::boolean, false) = false then
    raise exception 'This chip is not enabled for the selected competition.';
  end if;

  if v_gameweek_number = 1 and p_chip in ('wildcard', 'free_hit') then
    raise exception '% cannot be activated in Gameweek 1.', replace(initcap(p_chip), '_', ' ');
  end if;

  v_window := fantasy.resolve_chip_window(v_competition_id, p_gameweek_id);

  if exists (
    select 1
    from jsonb_array_elements(coalesce(v_chips_used, '[]'::jsonb)) as used_chip
    where used_chip ->> 'chip' = p_chip
      and used_chip ->> 'window' = v_window
  ) then
    raise exception 'This chip has already been used in %.', v_window;
  end if;

  if v_current_chip is not null and v_current_chip <> p_chip then
    raise exception 'A chip has already been activated for this gameweek.';
  end if;

  insert into fantasy.entry_gameweek_scores (
    entry_id,
    gameweek_id,
    chip_played,
    transfers_made,
    transfer_cost
  )
  values (
    p_entry_id,
    p_gameweek_id,
    p_chip,
    case when p_chip in ('wildcard', 'free_hit') then 0 else 0 end,
    0
  )
  on conflict (entry_id, gameweek_id)
  do update set
    chip_played = excluded.chip_played,
    transfers_made = case
      when excluded.chip_played in ('wildcard', 'free_hit') then 0
      else fantasy.entry_gameweek_scores.transfers_made
    end,
    transfer_cost = 0;

  update fantasy.fantasy_entries
  set
    chips_used = coalesce(chips_used, '[]'::jsonb) || jsonb_build_array(
      jsonb_build_object(
        'chip', p_chip,
        'window', v_window,
        'gameweek_id', p_gameweek_id,
        'activated_at', now()
      )
    ),
    updated_at = now()
  where id = p_entry_id;

  return p_chip;
end;
$$;

create or replace function public.fantasy_make_transfer(
  p_entry_id uuid,
  p_gameweek_id uuid,
  p_player_out_id integer,
  p_player_in_id integer
) returns table (
  transfers_made integer,
  transfer_cost integer,
  free_transfers_remaining integer,
  bank_balance integer,
  team_value integer
)
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_competition_id uuid;
  v_selection_id uuid;
  v_out_position fantasy.player_position;
  v_out_price integer;
  v_in_position fantasy.player_position;
  v_in_price integer;
  v_in_team_id integer;
  v_max_per_club integer := 3;
  v_club_count integer := 0;
  v_bank_balance integer := 0;
  v_team_value integer := 0;
  v_base_free integer := 1;
  v_transfers_made integer := 0;
  v_transfer_cost integer := 0;
  v_chip text;
begin
  perform fantasy.assert_entry_owner(p_entry_id);
  perform fantasy.assert_gameweek_open(p_gameweek_id);
  v_competition_id := fantasy.assert_entry_gameweek_matches_competition(p_entry_id, p_gameweek_id);
  perform fantasy.assert_competition_access(v_competition_id, true, false);
  perform fantasy.materialize_squad_for_gameweek(p_entry_id, p_gameweek_id);
  perform fantasy.ensure_entry_gameweek_score_row(p_entry_id, p_gameweek_id);

  select
    ss.id,
    ss.position,
    ss.purchase_price
  into
    v_selection_id,
    v_out_position,
    v_out_price
  from fantasy.squad_selections ss
  where ss.entry_id = p_entry_id
    and ss.gameweek_id = p_gameweek_id
    and ss.player_id = p_player_out_id
  limit 1;

  if v_selection_id is null then
    raise exception 'Player % is not in the current fantasy squad.', p_player_out_id;
  end if;

  if exists (
    select 1
    from fantasy.squad_selections ss
    where ss.entry_id = p_entry_id
      and ss.gameweek_id = p_gameweek_id
      and ss.player_id = p_player_in_id
  ) then
    raise exception 'Player % is already in the current fantasy squad.', p_player_in_id;
  end if;

  select
    p.position,
    p.team_id,
    pr.price
  into
    v_in_position,
    v_in_team_id,
    v_in_price
  from fantasy.players p
  join fantasy.player_competition_prices pr
    on pr.player_id = p.external_id
   and pr.competition_id = v_competition_id
  where p.external_id = p_player_in_id;

  if v_in_position is null then
    raise exception 'Incoming player is not priced for this competition.';
  end if;

  if v_in_position <> v_out_position then
    raise exception 'Transfers must keep the same player position.';
  end if;

  select coalesce((c.squad_config ->> 'max_per_club')::integer, 3)
  into v_max_per_club
  from fantasy.competitions c
  where c.id = v_competition_id;

  select count(*)
  into v_club_count
  from fantasy.squad_selections ss
  join fantasy.players p
    on p.external_id = ss.player_id
  where ss.entry_id = p_entry_id
    and ss.gameweek_id = p_gameweek_id
    and p.team_id = v_in_team_id
    and ss.player_id <> p_player_out_id;

  if v_club_count >= v_max_per_club then
    raise exception 'Maximum players per club exceeded for this competition.';
  end if;

  select
    fe.bank_balance,
    egs.chip_played,
    coalesce(egs.transfers_made, 0)
  into
    v_bank_balance,
    v_chip,
    v_transfers_made
  from fantasy.fantasy_entries fe
  left join fantasy.entry_gameweek_scores egs
    on egs.entry_id = fe.id
   and egs.gameweek_id = p_gameweek_id
  where fe.id = p_entry_id
  for update;

  v_bank_balance := coalesce(v_bank_balance, 0) + coalesce(v_out_price, 0) - coalesce(v_in_price, 0);
  if v_bank_balance < 0 then
    raise exception 'Insufficient fantasy budget for this transfer.';
  end if;

  update fantasy.squad_selections
  set
    player_id = p_player_in_id,
    position = v_in_position,
    purchase_price = v_in_price
  where id = v_selection_id;

  insert into fantasy.transfer_history (
    entry_id,
    gameweek_id,
    player_out_id,
    player_in_id,
    sell_price,
    buy_price
  )
  values (
    p_entry_id,
    p_gameweek_id,
    p_player_out_id,
    p_player_in_id,
    v_out_price,
    v_in_price
  );

  v_base_free := fantasy.get_base_free_transfers(p_entry_id, p_gameweek_id);

  if v_chip in ('wildcard', 'free_hit') then
    v_transfers_made := 0;
    v_transfer_cost := 0;
  else
    v_transfers_made := coalesce(v_transfers_made, 0) + 1;
    v_transfer_cost := greatest(v_transfers_made - v_base_free, 0) * -4;
  end if;

  insert into fantasy.entry_gameweek_scores (
    entry_id,
    gameweek_id,
    transfers_made,
    transfer_cost,
    chip_played
  )
  values (
    p_entry_id,
    p_gameweek_id,
    v_transfers_made,
    v_transfer_cost,
    v_chip
  )
  on conflict (entry_id, gameweek_id)
  do update set
    transfers_made = excluded.transfers_made,
    transfer_cost = excluded.transfer_cost,
    chip_played = excluded.chip_played;

  select coalesce(sum(purchase_price), 0)::integer
  into v_team_value
  from fantasy.squad_selections
  where entry_id = p_entry_id
    and gameweek_id = p_gameweek_id;

  update fantasy.fantasy_entries
  set
    bank_balance = v_bank_balance,
    team_value = v_team_value,
    total_transfers = case
      when coalesce(v_chip, '') in ('wildcard', 'free_hit') then total_transfers
      else total_transfers + 1
    end,
    updated_at = now()
  where id = p_entry_id;

  return query
  select
    v_transfers_made,
    v_transfer_cost,
    case
      when coalesce(v_chip, '') in ('wildcard', 'free_hit') then v_base_free
      else greatest(v_base_free - v_transfers_made, 0)
    end,
    v_bank_balance,
    v_team_value;
end;
$$;

create or replace function public.fantasy_refresh_player_gameweek_stats(
  p_gameweek_id uuid
) returns integer
language sql
security definer
set search_path = public, fantasy
as $$
  select fantasy.refresh_player_gameweek_stats(p_gameweek_id);
$$;

drop function if exists public.fantasy_get_squad(uuid, uuid);

create or replace function public.fantasy_get_squad(
  p_entry_id uuid,
  p_gameweek_id uuid default null
) returns table (
  selection_id uuid,
  gameweek_id uuid,
  player_id integer,
  name text,
  short_name text,
  photo_url text,
  player_position text,
  team_id integer,
  team_name text,
  team_short text,
  team_logo_url text,
  purchase_price integer,
  is_starter boolean,
  bench_order integer,
  is_captain boolean,
  is_vice_captain boolean,
  multiplier integer
)
language plpgsql
security definer
set search_path = public, fantasy
as $$
declare
  v_gameweek_id uuid := p_gameweek_id;
  v_effective_gameweek_id uuid;
begin
  perform fantasy.assert_entry_owner(p_entry_id);

  if v_gameweek_id is null then
    select gw.id
    into v_gameweek_id
    from fantasy.gameweeks gw
    join fantasy.fantasy_entries fe
      on fe.competition_id = gw.competition_id
    where fe.id = p_entry_id
    order by
      case gw.status
        when 'live' then 0
        when 'scoring' then 1
        when 'upcoming' then 2
        else 3
      end,
      gw.number asc
    limit 1;
  end if;

  if v_gameweek_id is null then
    return;
  end if;

  v_effective_gameweek_id := fantasy.resolve_effective_squad_gameweek(p_entry_id, v_gameweek_id);
  if v_effective_gameweek_id is null then
    return;
  end if;

  return query
  select
    ss.id as selection_id,
    v_gameweek_id as gameweek_id,
    ss.player_id,
    p.name,
    p.short_name,
    p.photo_url,
    p.position::text as player_position,
    p.team_id,
    p.team_name,
    p.team_short,
    p.team_logo_url,
    ss.purchase_price,
    ss.is_starter,
    ss.bench_order,
    ss.is_captain,
    ss.is_vice_captain,
    ss.multiplier
  from fantasy.squad_selections ss
  join fantasy.players p
    on p.external_id = ss.player_id
  where ss.entry_id = p_entry_id
    and ss.gameweek_id = v_effective_gameweek_id
  order by
    ss.is_starter desc,
    case p.position
      when 'GK' then 0
      when 'DEF' then 1
      when 'MID' then 2
      else 3
    end,
    ss.bench_order asc nulls last,
    p.name asc;
end;
$$;

create or replace function public.fantasy_get_leaderboard(
  p_competition_slug text,
  p_limit integer default 20
) returns table (
  team_name text,
  total_points integer,
  overall_rank integer,
  manager_name text,
  is_current_user boolean
)
language sql
security definer
set search_path = public, fantasy
as $$
  with competition as (
    select id
    from fantasy.competitions
    where slug = p_competition_slug
    limit 1
  ),
  guard as (
    select fantasy.assert_competition_access(id, false, false)
    from competition
  )
  select
    fe.team_name,
    fe.overall_points as total_points,
    fe.overall_rank,
    coalesce(
      nullif(u.official_name, ''),
      nullif(u.full_name, ''),
      'Manager'
    ) as manager_name,
    fe.user_id = auth.uid() as is_current_user
  from guard
  join competition c
    on true
  join fantasy.fantasy_entries fe
    on fe.competition_id = c.id
  left join public.users u
    on u.id = fe.user_id
  order by fe.overall_rank asc nulls last, fe.overall_points desc, fe.created_at asc
  limit greatest(coalesce(p_limit, 20), 1);
$$;

create or replace view fantasy.public_entry_summaries as
select
  fe.id,
  fe.user_id,
  fe.competition_id,
  fe.team_name,
  fe.overall_points,
  fe.overall_rank,
  coalesce(
    nullif(u.official_name, ''),
    nullif(u.full_name, ''),
    'Manager'
  ) as manager_name
from fantasy.fantasy_entries fe
left join public.users u
  on u.id = fe.user_id;

update fantasy.competitions
set
  scoring_rules = jsonb_set(
    jsonb_set(
      scoring_rules,
      '{goals}',
      jsonb_build_object('GK_DEF', 6, 'MID', 5, 'FWD', 4)
    ),
    '{clean_sheet}',
    jsonb_build_object('GK_DEF', 4, 'MID', 1)
  ),
  transfer_config = coalesce(transfer_config, '{}'::jsonb) || jsonb_build_object(
    'free_transfers', coalesce((transfer_config ->> 'free_transfers')::integer, 1),
    'max_banked_transfers', coalesce((transfer_config ->> 'max_banked_transfers')::integer, 5),
    'max_transfers_per_round', coalesce((transfer_config ->> 'max_transfers_per_round')::integer, 20)
  ),
  updated_at = now();

drop policy if exists "entry_owner_insert" on fantasy.fantasy_entries;
drop policy if exists "entry_owner_update" on fantasy.fantasy_entries;
drop policy if exists "squad_owner_all" on fantasy.squad_selections;
drop policy if exists "scores_owner_write" on fantasy.entry_gameweek_scores;
drop policy if exists "scores_owner_update" on fantasy.entry_gameweek_scores;
drop policy if exists "transfers_owner_insert" on fantasy.transfer_history;

drop policy if exists "squad_owner_select" on fantasy.squad_selections;
create policy "squad_owner_select"
on fantasy.squad_selections
for select
using (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

drop policy if exists "transfers_owner_write_via_rpc" on fantasy.transfer_history;
create policy "transfers_owner_write_via_rpc"
on fantasy.transfer_history
for select
using (
  entry_id in (
    select id
    from fantasy.fantasy_entries
    where user_id = auth.uid()
  )
);

grant execute on function public.fantasy_get_mobile_competitions() to authenticated, service_role;
grant execute on function public.fantasy_get_mobile_competition(text) to authenticated, service_role;
grant execute on function public.fantasy_get_player_pool_by_competition_id(uuid) to authenticated, service_role;
grant execute on function public.fantasy_get_player_by_competition_id(uuid, integer) to authenticated, service_role;
grant execute on function public.fantasy_get_entry_gameweek_state(uuid, uuid) to authenticated, service_role;
grant execute on function public.fantasy_get_chip_statuses(uuid, uuid) to authenticated, service_role;
grant execute on function public.fantasy_activate_chip(uuid, uuid, text) to authenticated, service_role;
grant execute on function public.fantasy_make_transfer(uuid, uuid, integer, integer) to authenticated, service_role;
grant execute on function public.fantasy_refresh_player_gameweek_stats(uuid) to authenticated, service_role;

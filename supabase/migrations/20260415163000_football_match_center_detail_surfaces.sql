-- ============================================================================
-- Football match-center detail surfaces
-- - Adds normalized fixture stats, events, and lineups tables
-- - Exposes a single match-center RPC for the mobile match detail screen
-- - Keeps derived H2H as a function surface while using structured tables
--   for stats/events/lineups
-- ============================================================================

create table if not exists football.fixture_stats (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  stat_key text not null,
  stat_label text not null,
  home_value numeric not null default 0,
  away_value numeric not null default 0,
  home_display text,
  away_display text,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (fixture_id, stat_key)
);

create table if not exists football.fixture_events (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  team_id uuid references football.teams(id) on delete set null,
  player_id uuid references football.players(id) on delete set null,
  event_type text not null,
  minute integer,
  stoppage_minute integer,
  event_label text,
  event_detail text,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists football.fixture_lineups (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  team_id uuid not null references football.teams(id) on delete cascade,
  formation text,
  coach_name text,
  is_confirmed boolean not null default false,
  source text not null default 'manual',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (fixture_id, team_id)
);

create table if not exists football.fixture_lineup_players (
  id uuid primary key default gen_random_uuid(),
  fixture_lineup_id uuid not null references football.fixture_lineups(id) on delete cascade,
  player_id uuid references football.players(id) on delete set null,
  player_name text not null,
  squad_number integer,
  position text,
  lineup_role text not null default 'starter',
  sort_order integer not null default 0,
  minute_on integer,
  minute_off integer,
  is_captain boolean not null default false,
  is_goalkeeper boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint fixture_lineup_players_role_check
    check (lineup_role in ('starter', 'substitute', 'reserve'))
);

create index if not exists idx_fixture_stats_fixture_sort
  on football.fixture_stats (fixture_id, sort_order, stat_key);

create index if not exists idx_fixture_events_fixture_sort
  on football.fixture_events (fixture_id, minute, stoppage_minute, sort_order);

create index if not exists idx_fixture_lineup_players_lineup_sort
  on football.fixture_lineup_players (fixture_lineup_id, lineup_role, sort_order);

drop trigger if exists fixture_stats_set_updated_at on football.fixture_stats;
create trigger fixture_stats_set_updated_at
before update on football.fixture_stats
for each row execute function public.set_updated_at();

drop trigger if exists fixture_events_set_updated_at on football.fixture_events;
create trigger fixture_events_set_updated_at
before update on football.fixture_events
for each row execute function public.set_updated_at();

drop trigger if exists fixture_lineups_set_updated_at on football.fixture_lineups;
create trigger fixture_lineups_set_updated_at
before update on football.fixture_lineups
for each row execute function public.set_updated_at();

drop trigger if exists fixture_lineup_players_set_updated_at on football.fixture_lineup_players;
create trigger fixture_lineup_players_set_updated_at
before update on football.fixture_lineup_players
for each row execute function public.set_updated_at();

alter table football.fixture_stats enable row level security;
alter table football.fixture_events enable row level security;
alter table football.fixture_lineups enable row level security;
alter table football.fixture_lineup_players enable row level security;

drop policy if exists fixture_stats_public_read on football.fixture_stats;
create policy fixture_stats_public_read
on football.fixture_stats
for select
using (true);

drop policy if exists fixture_events_public_read on football.fixture_events;
create policy fixture_events_public_read
on football.fixture_events
for select
using (true);

drop policy if exists fixture_lineups_public_read on football.fixture_lineups;
create policy fixture_lineups_public_read
on football.fixture_lineups
for select
using (true);

drop policy if exists fixture_lineup_players_public_read on football.fixture_lineup_players;
create policy fixture_lineup_players_public_read
on football.fixture_lineup_players
for select
using (true);

drop policy if exists fixture_stats_service_write on football.fixture_stats;
create policy fixture_stats_service_write
on football.fixture_stats
for all
to service_role
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists fixture_events_service_write on football.fixture_events;
create policy fixture_events_service_write
on football.fixture_events
for all
to service_role
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists fixture_lineups_service_write on football.fixture_lineups;
create policy fixture_lineups_service_write
on football.fixture_lineups
for all
to service_role
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists fixture_lineup_players_service_write on football.fixture_lineup_players;
create policy fixture_lineup_players_service_write
on football.fixture_lineup_players
for all
to service_role
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

grant select on football.fixture_stats to anon, authenticated;
grant select on football.fixture_events to anon, authenticated;
grant select on football.fixture_lineups to anon, authenticated;
grant select on football.fixture_lineup_players to anon, authenticated;
grant all on football.fixture_stats to service_role;
grant all on football.fixture_events to service_role;
grant all on football.fixture_lineups to service_role;
grant all on football.fixture_lineup_players to service_role;

create or replace function public.prediction_get_match_center(
  p_fixture_id uuid
) returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_fixture record;
  v_stats jsonb := '[]'::jsonb;
  v_h2h jsonb := '[]'::jsonb;
  v_events jsonb := '[]'::jsonb;
  v_home_lineup jsonb := '{}'::jsonb;
  v_away_lineup jsonb := '{}'::jsonb;
begin
  select *
    into v_fixture
  from public.football_fixtures_catalog fixture
  where fixture.id = p_fixture_id
  limit 1;

  if v_fixture.id is null then
    return null;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'label', stat.stat_label,
        'left_value', stat.home_value,
        'right_value', stat.away_value,
        'left_display', coalesce(stat.home_display, trim(to_char(stat.home_value, 'FM999999990.##'))),
        'right_display', coalesce(stat.away_display, trim(to_char(stat.away_value, 'FM999999990.##')))
      )
      order by stat.sort_order, stat.stat_label
    ),
    '[]'::jsonb
  )
    into v_stats
  from football.fixture_stats stat
  where stat.fixture_id = p_fixture_id;

  if v_stats = '[]'::jsonb and v_fixture.status in ('live', 'finished') then
    v_stats := jsonb_build_array(
      jsonb_build_object(
        'label', 'Goals',
        'left_value', coalesce(v_fixture.home_score, 0),
        'right_value', coalesce(v_fixture.away_score, 0),
        'left_display', coalesce(v_fixture.home_score, 0)::text,
        'right_display', coalesce(v_fixture.away_score, 0)::text
      ),
      jsonb_build_object(
        'label', 'Total Goals',
        'left_value', coalesce(v_fixture.home_score, 0) + coalesce(v_fixture.away_score, 0),
        'right_value', coalesce(v_fixture.home_score, 0) + coalesce(v_fixture.away_score, 0),
        'left_display', (coalesce(v_fixture.home_score, 0) + coalesce(v_fixture.away_score, 0))::text,
        'right_display', (coalesce(v_fixture.home_score, 0) + coalesce(v_fixture.away_score, 0))::text
      )
    );
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'home_team', h2h.home_team_name,
        'away_team', h2h.away_team_name,
        'home_score', h2h.home_score,
        'away_score', h2h.away_score,
        'date', h2h.kickoff_at,
        'competition', h2h.competition_name
      )
      order by h2h.kickoff_at desc
    ),
    '[]'::jsonb
  )
    into v_h2h
  from (
    select history.*
    from public.football_fixtures_catalog history
    where history.status = 'finished'
      and history.id <> p_fixture_id
      and (
        (
          history.home_team_slug = v_fixture.home_team_slug
          and history.away_team_slug = v_fixture.away_team_slug
        ) or (
          history.home_team_slug = v_fixture.away_team_slug
          and history.away_team_slug = v_fixture.home_team_slug
        )
      )
    order by history.kickoff_at desc
    limit 5
  ) h2h;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'event_type', event.event_type,
        'event_label', coalesce(event.event_label, initcap(replace(event.event_type, '_', ' '))),
        'event_detail', event.event_detail,
        'team_id', event.team_id,
        'player_id', event.player_id,
        'minute', event.minute,
        'stoppage_minute', event.stoppage_minute
      )
      order by event.minute nulls last, event.stoppage_minute nulls last, event.sort_order, event.created_at
    ),
    '[]'::jsonb
  )
    into v_events
  from football.fixture_events event
  where event.fixture_id = p_fixture_id;

  select coalesce((
    select jsonb_build_object(
      'formation', lineup.formation,
      'coach_name', lineup.coach_name,
      'is_confirmed', lineup.is_confirmed,
      'source', lineup.source,
      'starters', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'name', player.player_name,
            'number', player.squad_number,
            'position', player.position,
            'is_starter', player.lineup_role = 'starter',
            'role', player.lineup_role
          )
          order by player.sort_order, player.squad_number nulls last, player.player_name
        )
        from football.fixture_lineup_players player
        where player.fixture_lineup_id = lineup.id
          and player.lineup_role = 'starter'
      ), '[]'::jsonb),
      'substitutes', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'name', player.player_name,
            'number', player.squad_number,
            'position', player.position,
            'is_starter', player.lineup_role = 'starter',
            'role', player.lineup_role
          )
          order by player.sort_order, player.squad_number nulls last, player.player_name
        )
        from football.fixture_lineup_players player
        where player.fixture_lineup_id = lineup.id
          and player.lineup_role <> 'starter'
      ), '[]'::jsonb)
    )
    from football.fixture_lineups lineup
    where lineup.fixture_id = p_fixture_id
      and lineup.team_id = v_fixture.home_team_id
    limit 1
  ), jsonb_build_object(
    'formation', null,
    'coach_name', null,
    'is_confirmed', false,
    'source', 'roster_proxy',
    'starters', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', roster.player_name,
          'number', roster.squad_number,
          'position', roster.position,
          'is_starter', true,
          'role', 'starter'
        )
        order by roster.squad_number nulls last, roster.player_name
      )
      from (
        select *
        from public.football_roster_catalog roster
        where roster.team_slug = v_fixture.home_team_slug
          and roster.is_active = true
        order by roster.squad_number nulls last, roster.player_name
        limit 11
      ) roster
    ), '[]'::jsonb),
    'substitutes', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', roster.player_name,
          'number', roster.squad_number,
          'position', roster.position,
          'is_starter', false,
          'role', 'substitute'
        )
        order by roster.squad_number nulls last, roster.player_name
      )
      from (
        select *
        from public.football_roster_catalog roster
        where roster.team_slug = v_fixture.home_team_slug
          and roster.is_active = true
        order by roster.squad_number nulls last, roster.player_name
        offset 11
        limit 7
      ) roster
    ), '[]'::jsonb)
  ))
    into v_home_lineup;

  select coalesce((
    select jsonb_build_object(
      'formation', lineup.formation,
      'coach_name', lineup.coach_name,
      'is_confirmed', lineup.is_confirmed,
      'source', lineup.source,
      'starters', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'name', player.player_name,
            'number', player.squad_number,
            'position', player.position,
            'is_starter', player.lineup_role = 'starter',
            'role', player.lineup_role
          )
          order by player.sort_order, player.squad_number nulls last, player.player_name
        )
        from football.fixture_lineup_players player
        where player.fixture_lineup_id = lineup.id
          and player.lineup_role = 'starter'
      ), '[]'::jsonb),
      'substitutes', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'name', player.player_name,
            'number', player.squad_number,
            'position', player.position,
            'is_starter', player.lineup_role = 'starter',
            'role', player.lineup_role
          )
          order by player.sort_order, player.squad_number nulls last, player.player_name
        )
        from football.fixture_lineup_players player
        where player.fixture_lineup_id = lineup.id
          and player.lineup_role <> 'starter'
      ), '[]'::jsonb)
    )
    from football.fixture_lineups lineup
    where lineup.fixture_id = p_fixture_id
      and lineup.team_id = v_fixture.away_team_id
    limit 1
  ), jsonb_build_object(
    'formation', null,
    'coach_name', null,
    'is_confirmed', false,
    'source', 'roster_proxy',
    'starters', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', roster.player_name,
          'number', roster.squad_number,
          'position', roster.position,
          'is_starter', true,
          'role', 'starter'
        )
        order by roster.squad_number nulls last, roster.player_name
      )
      from (
        select *
        from public.football_roster_catalog roster
        where roster.team_slug = v_fixture.away_team_slug
          and roster.is_active = true
        order by roster.squad_number nulls last, roster.player_name
        limit 11
      ) roster
    ), '[]'::jsonb),
    'substitutes', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'name', roster.player_name,
          'number', roster.squad_number,
          'position', roster.position,
          'is_starter', false,
          'role', 'substitute'
        )
        order by roster.squad_number nulls last, roster.player_name
      )
      from (
        select *
        from public.football_roster_catalog roster
        where roster.team_slug = v_fixture.away_team_slug
          and roster.is_active = true
        order by roster.squad_number nulls last, roster.player_name
        offset 11
        limit 7
      ) roster
    ), '[]'::jsonb)
  ))
    into v_away_lineup;

  return jsonb_build_object(
    'fixture_id', v_fixture.id,
    'stats', v_stats,
    'h2h', v_h2h,
    'events', v_events,
    'lineups', jsonb_build_object(
      'home', v_home_lineup,
      'away', v_away_lineup
    )
  );
end;
$$;

grant execute on function public.prediction_get_match_center(uuid) to anon, authenticated, service_role;

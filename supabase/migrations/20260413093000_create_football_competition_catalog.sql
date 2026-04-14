create schema if not exists football;

grant usage on schema football to anon, authenticated, service_role;

do $$
begin
  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'football'
      and t.typname = 'competition_kind'
  ) then
    create type football.competition_kind as enum ('league', 'cup', 'tournament');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'football'
      and t.typname = 'season_status'
  ) then
    create type football.season_status as enum ('planned', 'active', 'finished', 'archived');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'football'
      and t.typname = 'team_type'
  ) then
    create type football.team_type as enum ('club', 'national');
  end if;

  if not exists (
    select 1
    from pg_type t
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'football'
      and t.typname = 'fixture_status'
  ) then
    create type football.fixture_status as enum (
      'scheduled',
      'live',
      'finished',
      'postponed',
      'cancelled'
    );
  end if;
end
$$;

create table if not exists football.competitions (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  short_name text not null,
  competition_kind football.competition_kind not null default 'league',
  region text not null default 'global',
  country_code text,
  country_name text,
  organizer text,
  gender text not null default 'men',
  format_notes text not null default '',
  external_provider text,
  external_competition_id text,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (external_provider, external_competition_id)
);

create table if not exists football.seasons (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references football.competitions(id) on delete cascade,
  slug text not null unique,
  label text not null,
  year_start integer,
  year_end integer,
  starts_on date,
  ends_on date,
  status football.season_status not null default 'planned',
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (competition_id, label)
);

create table if not exists football.teams (
  id uuid primary key default gen_random_uuid(),
  slug text unique,
  name text not null,
  short_name text,
  team_type football.team_type not null default 'club',
  country_code text,
  country_name text,
  city text,
  founded_year integer,
  crest_url text,
  source_club_id bigint references public.african_football_clubs(id) on delete set null,
  external_provider text,
  external_team_id text,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (external_provider, external_team_id)
);

create table if not exists football.season_teams (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references football.seasons(id) on delete cascade,
  team_id uuid not null references football.teams(id) on delete cascade,
  group_name text not null default '',
  seeded_rank integer,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (season_id, team_id)
);

create table if not exists football.players (
  id uuid primary key default gen_random_uuid(),
  slug text unique,
  full_name text not null,
  short_name text,
  nationality_code text,
  nationality_name text,
  date_of_birth date,
  primary_position text,
  preferred_foot text,
  height_cm integer,
  weight_kg integer,
  photo_url text,
  external_provider text,
  external_player_id text,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (external_provider, external_player_id)
);

create table if not exists football.player_registrations (
  id uuid primary key default gen_random_uuid(),
  player_id uuid not null references football.players(id) on delete cascade,
  team_id uuid not null references football.teams(id) on delete cascade,
  season_id uuid not null references football.seasons(id) on delete cascade,
  squad_number integer,
  position text,
  joined_on date,
  left_on date,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (player_id, team_id, season_id)
);

create table if not exists football.fixtures (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references football.competitions(id) on delete cascade,
  season_id uuid not null references football.seasons(id) on delete cascade,
  stage_name text not null default 'regular_season',
  group_name text not null default '',
  round_name text,
  matchday integer,
  fixture_number integer,
  kickoff_at timestamptz,
  venue_name text,
  venue_city text,
  venue_country text,
  home_team_id uuid not null references football.teams(id) on delete restrict,
  away_team_id uuid not null references football.teams(id) on delete restrict,
  home_score integer,
  away_score integer,
  leg_number smallint not null default 1,
  status football.fixture_status not null default 'scheduled',
  external_provider text,
  external_fixture_id text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (home_team_id <> away_team_id),
  unique (external_provider, external_fixture_id)
);

create table if not exists football.standings (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references football.competitions(id) on delete cascade,
  season_id uuid not null references football.seasons(id) on delete cascade,
  team_id uuid not null references football.teams(id) on delete cascade,
  stage_name text not null default 'overall',
  group_name text not null default '',
  position integer not null,
  played integer not null default 0,
  won integer not null default 0,
  drawn integer not null default 0,
  lost integer not null default 0,
  goals_for integer not null default 0,
  goals_against integer not null default 0,
  goal_difference integer not null default 0,
  points integer not null default 0,
  form text[] not null default '{}'::text[],
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (season_id, stage_name, group_name, team_id)
);

create index if not exists idx_football_competitions_country
  on football.competitions (country_code, competition_kind)
  where is_active = true;

create index if not exists idx_football_seasons_competition_status
  on football.seasons (competition_id, status, year_start desc);

create index if not exists idx_football_teams_country_type
  on football.teams (country_code, team_type)
  where is_active = true;

create index if not exists idx_football_season_teams_group
  on football.season_teams (season_id, group_name);

create index if not exists idx_football_player_registrations_team_season
  on football.player_registrations (team_id, season_id)
  where is_active = true;

create index if not exists idx_football_fixtures_season_kickoff
  on football.fixtures (season_id, kickoff_at, status);

create index if not exists idx_football_fixtures_team_lookup
  on football.fixtures (home_team_id, away_team_id, kickoff_at);

create index if not exists idx_football_standings_position
  on football.standings (season_id, stage_name, group_name, position);

grant select on all tables in schema football to anon, authenticated, service_role;
grant insert, update, delete on all tables in schema football to service_role;
grant usage, select on all sequences in schema football to service_role;

alter default privileges in schema football
  grant select on tables to anon, authenticated, service_role;

alter default privileges in schema football
  grant insert, update, delete on tables to service_role;

alter default privileges in schema football
  grant usage, select on sequences to service_role;

alter table football.competitions enable row level security;
alter table football.seasons enable row level security;
alter table football.teams enable row level security;
alter table football.season_teams enable row level security;
alter table football.players enable row level security;
alter table football.player_registrations enable row level security;
alter table football.fixtures enable row level security;
alter table football.standings enable row level security;

drop policy if exists "football_competitions_public_read" on football.competitions;
create policy "football_competitions_public_read"
on football.competitions
for select
using (true);

drop policy if exists "football_seasons_public_read" on football.seasons;
create policy "football_seasons_public_read"
on football.seasons
for select
using (true);

drop policy if exists "football_teams_public_read" on football.teams;
create policy "football_teams_public_read"
on football.teams
for select
using (true);

drop policy if exists "football_season_teams_public_read" on football.season_teams;
create policy "football_season_teams_public_read"
on football.season_teams
for select
using (true);

drop policy if exists "football_players_public_read" on football.players;
create policy "football_players_public_read"
on football.players
for select
using (true);

drop policy if exists "football_player_registrations_public_read" on football.player_registrations;
create policy "football_player_registrations_public_read"
on football.player_registrations
for select
using (true);

drop policy if exists "football_fixtures_public_read" on football.fixtures;
create policy "football_fixtures_public_read"
on football.fixtures
for select
using (true);

drop policy if exists "football_standings_public_read" on football.standings;
create policy "football_standings_public_read"
on football.standings
for select
using (true);

drop policy if exists "football_competitions_service_write" on football.competitions;
create policy "football_competitions_service_write"
on football.competitions
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists "football_seasons_service_write" on football.seasons;
create policy "football_seasons_service_write"
on football.seasons
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists "football_teams_service_write" on football.teams;
create policy "football_teams_service_write"
on football.teams
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists "football_season_teams_service_write" on football.season_teams;
create policy "football_season_teams_service_write"
on football.season_teams
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists "football_players_service_write" on football.players;
create policy "football_players_service_write"
on football.players
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists "football_player_registrations_service_write" on football.player_registrations;
create policy "football_player_registrations_service_write"
on football.player_registrations
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists "football_fixtures_service_write" on football.fixtures;
create policy "football_fixtures_service_write"
on football.fixtures
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop policy if exists "football_standings_service_write" on football.standings;
create policy "football_standings_service_write"
on football.standings
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

drop trigger if exists football_competitions_set_updated_at on football.competitions;
create trigger football_competitions_set_updated_at
before update on football.competitions
for each row execute function public.set_updated_at();

drop trigger if exists football_seasons_set_updated_at on football.seasons;
create trigger football_seasons_set_updated_at
before update on football.seasons
for each row execute function public.set_updated_at();

drop trigger if exists football_teams_set_updated_at on football.teams;
create trigger football_teams_set_updated_at
before update on football.teams
for each row execute function public.set_updated_at();

drop trigger if exists football_season_teams_set_updated_at on football.season_teams;
create trigger football_season_teams_set_updated_at
before update on football.season_teams
for each row execute function public.set_updated_at();

drop trigger if exists football_players_set_updated_at on football.players;
create trigger football_players_set_updated_at
before update on football.players
for each row execute function public.set_updated_at();

drop trigger if exists football_player_registrations_set_updated_at on football.player_registrations;
create trigger football_player_registrations_set_updated_at
before update on football.player_registrations
for each row execute function public.set_updated_at();

drop trigger if exists football_fixtures_set_updated_at on football.fixtures;
create trigger football_fixtures_set_updated_at
before update on football.fixtures
for each row execute function public.set_updated_at();

drop trigger if exists football_standings_set_updated_at on football.standings;
create trigger football_standings_set_updated_at
before update on football.standings
for each row execute function public.set_updated_at();

insert into football.competitions (
  slug,
  name,
  short_name,
  competition_kind,
  region,
  country_code,
  country_name,
  organizer,
  format_notes,
  metadata
)
values
  (
    'rwanda-premier-league',
    'Rwanda Premier League',
    'RPL',
    'league',
    'africa',
    'RW',
    'Rwanda',
    'Rwanda Football Federation',
    'Domestic top-flight competition for clubs in Rwanda.',
    jsonb_build_object('tier', 1, 'supports_tables', true, 'supports_fixtures', true, 'supports_player_registrations', true)
  ),
  (
    'drc-premier-league',
    'DRC Premier League',
    'DRC Premier League',
    'league',
    'africa',
    'CD',
    'Democratic Republic of the Congo',
    'Congolese Football Federation',
    'Domestic top-flight competition for clubs in the DRC.',
    jsonb_build_object('tier', 1, 'supports_tables', true, 'supports_fixtures', true, 'supports_player_registrations', true)
  ),
  (
    'zambia-super-league',
    'Zambia Super League',
    'Zambia Super League',
    'league',
    'africa',
    'ZM',
    'Zambia',
    'Football Association of Zambia',
    'Domestic top-flight competition for clubs in Zambia.',
    jsonb_build_object('tier', 1, 'supports_tables', true, 'supports_fixtures', true, 'supports_player_registrations', true)
  ),
  (
    'english-premier-league',
    'English Premier League',
    'EPL',
    'league',
    'europe',
    'ENG',
    'England',
    'Premier League',
    'Top-flight league competition for clubs in England.',
    jsonb_build_object('tier', 1, 'supports_tables', true, 'supports_fixtures', true, 'supports_player_registrations', true)
  ),
  (
    'fifa-world-cup-2026',
    'FIFA World Cup 2026',
    'World Cup 2026',
    'tournament',
    'international',
    null,
    'Global',
    'FIFA',
    'National-team tournament with group and knockout stages.',
    jsonb_build_object('team_type', 'national', 'supports_groups', true, 'supports_knockout', true, 'supports_fixtures', true)
  )
on conflict (slug) do update
set
  name = excluded.name,
  short_name = excluded.short_name,
  competition_kind = excluded.competition_kind,
  region = excluded.region,
  country_code = excluded.country_code,
  country_name = excluded.country_name,
  organizer = excluded.organizer,
  format_notes = excluded.format_notes,
  metadata = football.competitions.metadata || excluded.metadata,
  is_active = true;

insert into football.seasons (
  competition_id,
  slug,
  label,
  year_start,
  year_end,
  status,
  metadata
)
select
  c.id,
  s.slug,
  s.label,
  s.year_start,
  s.year_end,
  s.status,
  s.metadata
from (
  values
    (
      'rwanda-premier-league',
      'rwanda-premier-league-2026',
      '2026',
      2026,
      2026,
      'active'::football.season_status,
      jsonb_build_object('default_stage', 'league')
    ),
    (
      'drc-premier-league',
      'drc-premier-league-2026',
      '2026',
      2026,
      2026,
      'active'::football.season_status,
      jsonb_build_object('default_stage', 'league')
    ),
    (
      'zambia-super-league',
      'zambia-super-league-2026',
      '2026',
      2026,
      2026,
      'active'::football.season_status,
      jsonb_build_object('default_stage', 'league')
    ),
    (
      'english-premier-league',
      'english-premier-league-2025-2026',
      '2025/2026',
      2025,
      2026,
      'active'::football.season_status,
      jsonb_build_object('default_stage', 'league')
    ),
    (
      'fifa-world-cup-2026',
      'fifa-world-cup-2026',
      '2026',
      2026,
      2026,
      'planned'::football.season_status,
      jsonb_build_object('default_stage', 'group_stage', 'supports_knockout', true)
    )
) as s(competition_slug, slug, label, year_start, year_end, status, metadata)
join football.competitions c
  on c.slug = s.competition_slug
on conflict (competition_id, label) do update
set
  slug = excluded.slug,
  year_start = excluded.year_start,
  year_end = excluded.year_end,
  status = excluded.status,
  metadata = football.seasons.metadata || excluded.metadata,
  is_active = true;

create or replace view public.football_competitions_catalog
with (security_invoker = true) as
select
  c.id,
  c.slug,
  c.name,
  c.short_name,
  c.competition_kind,
  c.region,
  c.country_code,
  c.country_name,
  c.organizer,
  c.gender,
  c.format_notes,
  c.is_active,
  c.metadata,
  c.created_at,
  c.updated_at
from football.competitions c;

create or replace view public.football_seasons_catalog
with (security_invoker = true) as
select
  s.id,
  s.competition_id,
  c.slug as competition_slug,
  c.name as competition_name,
  s.slug,
  s.label,
  s.year_start,
  s.year_end,
  s.starts_on,
  s.ends_on,
  s.status,
  s.is_active,
  s.metadata,
  s.created_at,
  s.updated_at
from football.seasons s
join football.competitions c
  on c.id = s.competition_id;

create or replace view public.football_teams_catalog
with (security_invoker = true) as
select
  t.id,
  t.slug,
  t.name,
  t.short_name,
  t.team_type,
  t.country_code,
  t.country_name,
  t.city,
  t.founded_year,
  t.crest_url,
  t.source_club_id,
  afc.club_slug as source_club_slug,
  afc.club_name as source_club_name,
  t.is_active,
  t.metadata,
  t.created_at,
  t.updated_at
from football.teams t
left join public.african_football_clubs afc
  on afc.id = t.source_club_id;

create or replace view public.football_players_catalog
with (security_invoker = true) as
select
  p.id,
  p.slug,
  p.full_name,
  p.short_name,
  p.nationality_code,
  p.nationality_name,
  p.date_of_birth,
  p.primary_position,
  p.preferred_foot,
  p.height_cm,
  p.weight_kg,
  p.photo_url,
  p.is_active,
  p.metadata,
  p.created_at,
  p.updated_at
from football.players p;

create or replace view public.football_roster_catalog
with (security_invoker = true) as
select
  pr.id,
  pr.season_id,
  s.slug as season_slug,
  s.label as season_label,
  pr.team_id,
  t.slug as team_slug,
  t.name as team_name,
  t.short_name as team_short_name,
  pr.player_id,
  p.slug as player_slug,
  p.full_name as player_name,
  p.short_name as player_short_name,
  coalesce(pr.position, p.primary_position) as position,
  pr.squad_number,
  pr.joined_on,
  pr.left_on,
  pr.is_active,
  pr.metadata,
  pr.created_at,
  pr.updated_at
from football.player_registrations pr
join football.seasons s
  on s.id = pr.season_id
join football.teams t
  on t.id = pr.team_id
join football.players p
  on p.id = pr.player_id;

create or replace view public.football_fixtures_catalog
with (security_invoker = true) as
select
  f.id,
  f.competition_id,
  c.slug as competition_slug,
  c.name as competition_name,
  f.season_id,
  s.slug as season_slug,
  s.label as season_label,
  f.stage_name,
  f.group_name,
  f.round_name,
  f.matchday,
  f.fixture_number,
  f.kickoff_at,
  f.venue_name,
  f.venue_city,
  f.venue_country,
  f.home_team_id,
  ht.slug as home_team_slug,
  ht.name as home_team_name,
  ht.short_name as home_team_short_name,
  f.away_team_id,
  at.slug as away_team_slug,
  at.name as away_team_name,
  at.short_name as away_team_short_name,
  f.home_score,
  f.away_score,
  f.leg_number,
  f.status,
  f.metadata,
  f.created_at,
  f.updated_at
from football.fixtures f
join football.competitions c
  on c.id = f.competition_id
join football.seasons s
  on s.id = f.season_id
join football.teams ht
  on ht.id = f.home_team_id
join football.teams at
  on at.id = f.away_team_id;

create or replace view public.football_standings_catalog
with (security_invoker = true) as
select
  st.id,
  st.competition_id,
  c.slug as competition_slug,
  c.name as competition_name,
  st.season_id,
  s.slug as season_slug,
  s.label as season_label,
  st.team_id,
  t.slug as team_slug,
  t.name as team_name,
  t.short_name as team_short_name,
  st.stage_name,
  st.group_name,
  st.position,
  st.played,
  st.won,
  st.drawn,
  st.lost,
  st.goals_for,
  st.goals_against,
  st.goal_difference,
  st.points,
  st.form,
  st.notes,
  st.metadata,
  st.created_at,
  st.updated_at
from football.standings st
join football.competitions c
  on c.id = st.competition_id
join football.seasons s
  on s.id = st.season_id
join football.teams t
  on t.id = st.team_id;

grant select on public.football_competitions_catalog to anon, authenticated, service_role;
grant select on public.football_seasons_catalog to anon, authenticated, service_role;
grant select on public.football_teams_catalog to anon, authenticated, service_role;
grant select on public.football_players_catalog to anon, authenticated, service_role;
grant select on public.football_roster_catalog to anon, authenticated, service_role;
grant select on public.football_fixtures_catalog to anon, authenticated, service_role;
grant select on public.football_standings_catalog to anon, authenticated, service_role;

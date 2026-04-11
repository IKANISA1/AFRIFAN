-- Enable required extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Create schema
create schema if not exists fantasy;

-- ─────────────────────────────────────────────
-- PLATFORM INTEGRATION
-- Repairs club-scoped CMS/config tables expected by
-- the mobile and web surfaces.
-- ─────────────────────────────────────────────
alter table if exists public.home_banners
  add column if not exists club_id bigint references public.african_football_clubs(id);

alter table if exists public.ai_content
  add column if not exists club_id bigint references public.african_football_clubs(id);

create table if not exists public.club_app_config (
  id          uuid primary key default gen_random_uuid(),
  club_id     bigint not null references public.african_football_clubs(id) on delete cascade,
  key         text not null,
  value       text not null default '',
  description text,
  country     text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- ENUMS
-- ─────────────────────────────────────────────
create type fantasy.competition_type as enum ('season_long', 'tournament');
create type fantasy.competition_status as enum ('draft', 'active', 'finished');
create type fantasy.gameweek_status as enum ('upcoming', 'live', 'scoring', 'finished');
create type fantasy.player_position as enum ('GK', 'DEF', 'MID', 'FWD');
create type fantasy.league_type as enum ('classic', 'head_to_head');

-- ─────────────────────────────────────────────
-- COMPETITIONS
-- ─────────────────────────────────────────────
create table fantasy.competitions (
  id                 uuid primary key default uuid_generate_v4(),
  slug               text unique not null,
  name               text not null,
  short_name         text not null,
  competition_type   fantasy.competition_type not null default 'season_long',
  season             text not null,
  description        text not null default '',
  logo_url           text,
  primary_color      text not null default '#1A7A4E',
  country_code       text,
  provider           text,
  scoring_rules      jsonb not null default '{}'::jsonb,
  squad_config       jsonb not null default '{}'::jsonb,
  chip_config        jsonb not null default '{}'::jsonb,
  transfer_config    jsonb not null default '{}'::jsonb,
  status             fantasy.competition_status not null default 'draft',
  start_date         timestamptz not null,
  end_date           timestamptz not null,
  external_league_id integer,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- GAMEWEEKS
-- ─────────────────────────────────────────────
create table fantasy.gameweeks (
  id                         uuid primary key default uuid_generate_v4(),
  competition_id             uuid not null references fantasy.competitions(id) on delete cascade,
  number                     integer not null,
  name                       text not null,
  deadline_at                timestamptz not null,
  start_at                   timestamptz not null,
  end_at                     timestamptz not null,
  status                     fantasy.gameweek_status not null default 'upcoming',
  is_double_gw               boolean not null default false,
  average_score              integer,
  highest_score              integer,
  most_captained_player_id   integer,
  created_at                 timestamptz not null default now(),
  unique (competition_id, number)
);

-- ─────────────────────────────────────────────
-- FANTASY PLAYERS (cached from sports API)
-- ─────────────────────────────────────────────
create table fantasy.players (
  id             serial primary key,
  external_id    integer unique not null,
  name           text not null,
  short_name     text not null,
  photo_url      text,
  position       fantasy.player_position not null,
  team_id        integer not null,
  team_name      text not null,
  team_short     text not null,
  team_logo_url  text,
  nationality    text,
  last_synced_at timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- PLAYER PRICES PER COMPETITION
-- ─────────────────────────────────────────────
create table fantasy.player_competition_prices (
  id                uuid primary key default uuid_generate_v4(),
  player_id         integer not null references fantasy.players(external_id),
  competition_id    uuid not null references fantasy.competitions(id) on delete cascade,
  price             integer not null,
  price_change      integer not null default 0,
  ownership_percent numeric(5,2) not null default 0,
  updated_at        timestamptz not null default now(),
  unique (player_id, competition_id)
);

-- ─────────────────────────────────────────────
-- FANTASY ENTRIES
-- ─────────────────────────────────────────────
create table fantasy.fantasy_entries (
  id               uuid primary key default uuid_generate_v4(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  competition_id   uuid not null references fantasy.competitions(id) on delete cascade,
  team_name        text not null default 'My Team',
  overall_points   integer not null default 0,
  overall_rank     integer,
  total_transfers  integer not null default 0,
  chips_used       jsonb not null default '[]'::jsonb,
  bank_balance     integer not null default 0,
  team_value       integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (user_id, competition_id)
);

-- ─────────────────────────────────────────────
-- SQUAD SELECTIONS
-- ─────────────────────────────────────────────
create table fantasy.squad_selections (
  id               uuid primary key default uuid_generate_v4(),
  entry_id         uuid not null references fantasy.fantasy_entries(id) on delete cascade,
  gameweek_id      uuid not null references fantasy.gameweeks(id) on delete cascade,
  player_id        integer not null references fantasy.players(external_id),
  position         fantasy.player_position not null,
  is_starter       boolean not null default true,
  bench_order      integer,
  is_captain       boolean not null default false,
  is_vice_captain  boolean not null default false,
  purchase_price   integer not null,
  multiplier       integer not null default 1,
  unique (entry_id, gameweek_id, player_id),
  constraint valid_bench_order check (
    (is_starter = true and bench_order is null) or
    (is_starter = false and bench_order between 1 and 4)
  ),
  constraint single_captain check (not (is_captain and is_vice_captain)),
  constraint valid_multiplier check (multiplier between 1 and 3)
);

-- ─────────────────────────────────────────────
-- PLAYER GAMEWEEK STATS
-- ─────────────────────────────────────────────
create table fantasy.player_gameweek_stats (
  id                        uuid primary key default uuid_generate_v4(),
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
  bps_score                 integer not null default 0,
  bonus_points              integer not null default 0,
  defensive_contributions   integer not null default 0,
  raw_points                integer not null default 0,
  last_synced_at            timestamptz not null default now(),
  unique (player_id, gameweek_id)
);

-- ─────────────────────────────────────────────
-- ENTRY GAMEWEEK SCORES
-- ─────────────────────────────────────────────
create table fantasy.entry_gameweek_scores (
  id                uuid primary key default uuid_generate_v4(),
  entry_id          uuid not null references fantasy.fantasy_entries(id) on delete cascade,
  gameweek_id       uuid not null references fantasy.gameweeks(id) on delete cascade,
  points            integer not null default 0,
  transfers_made    integer not null default 0,
  transfer_cost     integer not null default 0,
  chip_played       text,
  rank              integer,
  percentile        numeric(5,2),
  calculated_at     timestamptz,
  unique (entry_id, gameweek_id)
);

-- ─────────────────────────────────────────────
-- LEAGUES
-- ─────────────────────────────────────────────
create table fantasy.leagues (
  id              uuid primary key default uuid_generate_v4(),
  competition_id  uuid not null references fantasy.competitions(id) on delete cascade,
  name            text not null,
  code            text unique not null,
  type            fantasy.league_type not null default 'classic',
  created_by      uuid not null references auth.users(id),
  max_entries     integer not null default 50,
  is_public       boolean not null default false,
  created_at      timestamptz not null default now()
);

create table fantasy.league_memberships (
  id         uuid primary key default uuid_generate_v4(),
  league_id  uuid not null references fantasy.leagues(id) on delete cascade,
  entry_id   uuid not null references fantasy.fantasy_entries(id) on delete cascade,
  joined_at  timestamptz not null default now(),
  unique (league_id, entry_id)
);

-- ─────────────────────────────────────────────
-- TRANSFER HISTORY
-- ─────────────────────────────────────────────
create table fantasy.transfer_history (
  id             uuid primary key default uuid_generate_v4(),
  entry_id       uuid not null references fantasy.fantasy_entries(id) on delete cascade,
  gameweek_id    uuid not null references fantasy.gameweeks(id),
  player_out_id  integer not null references fantasy.players(external_id),
  player_in_id   integer not null references fantasy.players(external_id),
  sell_price     integer not null,
  buy_price      integer not null,
  created_at     timestamptz not null default now()
);

-- ─────────────────────────────────────────────
-- CLUB-SCOPED ENABLEMENTS
-- Allows each club website/app to decide which global
-- competitions are visible and how they are promoted.
-- ─────────────────────────────────────────────
create table public.fantasy_competition_enablements (
  id                       uuid primary key default gen_random_uuid(),
  competition_id           uuid not null references fantasy.competitions(id) on delete cascade,
  club_id                  bigint not null references public.african_football_clubs(id) on delete cascade,
  promo_title              text,
  promo_body               text,
  badge_label              text,
  cta_label                text,
  hero_image_url           text,
  sort_order               integer not null default 0,
  is_visible               boolean not null default true,
  is_featured              boolean not null default false,
  is_playable              boolean not null default false,
  entry_window_opens_at    timestamptz,
  entry_window_closes_at   timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),
  unique (competition_id, club_id)
);

-- ─────────────────────────────────────────────
-- INDEXES
-- ─────────────────────────────────────────────
create index idx_gameweeks_competition on fantasy.gameweeks(competition_id, status);
create index idx_squad_entry_gw on fantasy.squad_selections(entry_id, gameweek_id);
create index idx_stats_player_gw on fantasy.player_gameweek_stats(player_id, gameweek_id);
create index idx_scores_entry_gw on fantasy.entry_gameweek_scores(entry_id, gameweek_id);
create index idx_scores_rank on fantasy.entry_gameweek_scores(gameweek_id, rank);
create index idx_entries_competition on fantasy.fantasy_entries(competition_id, overall_rank);
create index idx_players_team on fantasy.players(team_id, position);
create index idx_prices_competition on fantasy.player_competition_prices(competition_id, price);
create unique index idx_squad_single_captain on fantasy.squad_selections(entry_id, gameweek_id) where is_captain;
create unique index idx_squad_single_vice on fantasy.squad_selections(entry_id, gameweek_id) where is_vice_captain;
create unique index idx_squad_bench_order on fantasy.squad_selections(entry_id, gameweek_id, bench_order) where bench_order is not null;
create unique index if not exists idx_club_app_config_club_key
  on public.club_app_config (club_id, key);
create index if not exists idx_home_banners_club_sort
  on public.home_banners (club_id, sort_order);
create index if not exists idx_ai_content_club_type_sort
  on public.ai_content (club_id, content_type, sort_order);
create index idx_fantasy_enablements_club_sort
  on public.fantasy_competition_enablements(club_id, is_visible, sort_order);
create unique index idx_fantasy_enablements_competition_club
  on public.fantasy_competition_enablements(competition_id, club_id);

-- ─────────────────────────────────────────────
-- UTILITY FUNCTIONS
-- ─────────────────────────────────────────────
create or replace function fantasy.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function fantasy.generate_short_code(p_length integer default 6)
returns text
language plpgsql
as $$
declare
  v_code text;
begin
  if p_length < 4 then
    raise exception 'Short code length must be at least 4.';
  end if;

  v_code := upper(substr(encode(gen_random_bytes(greatest(p_length, 6)), 'hex'), 1, p_length));
  return v_code;
end;
$$;

create or replace function fantasy.ensure_league_code()
returns trigger
language plpgsql
as $$
declare
  v_attempt integer := 0;
begin
  if new.code is not null and btrim(new.code) <> '' then
    new.code := upper(btrim(new.code));
    return new;
  end if;

  loop
    new.code := fantasy.generate_short_code(6);
    exit when not exists (
      select 1
      from fantasy.leagues
      where code = new.code
    );

    v_attempt := v_attempt + 1;
    if v_attempt > 8 then
      raise exception 'Unable to generate a unique fantasy league code.';
    end if;
  end loop;

  return new;
end;
$$;

create or replace function fantasy.assert_entry_owner(p_entry_id uuid)
returns void
language plpgsql
as $$
declare
  v_owner uuid;
begin
  if auth.role() = 'service_role' then
    return;
  end if;

  select user_id
  into v_owner
  from fantasy.fantasy_entries
  where id = p_entry_id;

  if v_owner is null then
    raise exception 'Fantasy entry not found.';
  end if;

  if auth.uid() is distinct from v_owner then
    raise exception 'You do not own this fantasy entry.';
  end if;
end;
$$;

create or replace function fantasy.assert_gameweek_open(p_gameweek_id uuid)
returns void
language plpgsql
as $$
declare
  v_deadline timestamptz;
begin
  if auth.role() = 'service_role' then
    return;
  end if;

  select deadline_at
  into v_deadline
  from fantasy.gameweeks
  where id = p_gameweek_id;

  if v_deadline is null then
    raise exception 'Gameweek not found.';
  end if;

  if now() > v_deadline then
    raise exception 'This gameweek is locked because the deadline has passed.';
  end if;
end;
$$;

create or replace function fantasy.validate_squad_selection_row()
returns trigger
language plpgsql
as $$
declare
  v_player_position fantasy.player_position;
  v_team_id integer;
  v_max_per_club integer := 3;
  v_existing_from_team integer := 0;
begin
  perform fantasy.assert_entry_owner(new.entry_id);
  perform fantasy.assert_gameweek_open(new.gameweek_id);

  select position, team_id
  into v_player_position, v_team_id
  from fantasy.players
  where external_id = new.player_id;

  if v_player_position is null then
    raise exception 'Player % does not exist.', new.player_id;
  end if;

  if new.position is distinct from v_player_position then
    raise exception 'Selected position % does not match player position %.', new.position, v_player_position;
  end if;

  select coalesce((c.squad_config ->> 'max_per_club')::integer, 3)
  into v_max_per_club
  from fantasy.fantasy_entries fe
  join fantasy.competitions c
    on c.id = fe.competition_id
  where fe.id = new.entry_id;

  select count(*)
  into v_existing_from_team
  from fantasy.squad_selections ss
  join fantasy.players p
    on p.external_id = ss.player_id
  where ss.entry_id = new.entry_id
    and ss.gameweek_id = new.gameweek_id
    and p.team_id = v_team_id
    and (tg_op <> 'UPDATE' or ss.id <> new.id);

  if v_existing_from_team >= v_max_per_club then
    raise exception 'Maximum % players from the same club is allowed.', v_max_per_club;
  end if;

  return new;
end;
$$;

create or replace function fantasy.guard_transfer_history_row()
returns trigger
language plpgsql
as $$
begin
  perform fantasy.assert_entry_owner(new.entry_id);
  perform fantasy.assert_gameweek_open(new.gameweek_id);
  return new;
end;
$$;

create or replace function fantasy.guard_score_owner_mutation()
returns trigger
language plpgsql
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  perform fantasy.assert_entry_owner(new.entry_id);
  perform fantasy.assert_gameweek_open(new.gameweek_id);

  if tg_op = 'UPDATE' then
    if new.points is distinct from old.points
      or new.rank is distinct from old.rank
      or new.percentile is distinct from old.percentile
      or new.calculated_at is distinct from old.calculated_at then
      raise exception 'Only fantasy scoring automation can update protected score fields.';
    end if;
  end if;

  return new;
end;
$$;

-- ─────────────────────────────────────────────
-- TRIGGERS
-- ─────────────────────────────────────────────
create trigger competitions_updated_at
before update on fantasy.competitions
for each row execute function fantasy.set_updated_at();

create trigger entries_updated_at
before update on fantasy.fantasy_entries
for each row execute function fantasy.set_updated_at();

create trigger prices_updated_at
before update on fantasy.player_competition_prices
for each row execute function fantasy.set_updated_at();

create trigger leagues_generate_code
before insert on fantasy.leagues
for each row execute function fantasy.ensure_league_code();

create trigger squad_validate_row
before insert or update on fantasy.squad_selections
for each row execute function fantasy.validate_squad_selection_row();

create trigger transfer_history_guard_row
before insert or update on fantasy.transfer_history
for each row execute function fantasy.guard_transfer_history_row();

create trigger entry_scores_guard_row
before insert or update on fantasy.entry_gameweek_scores
for each row execute function fantasy.guard_score_owner_mutation();

create trigger club_app_config_updated_at
before update on public.club_app_config
for each row execute function public.set_updated_at();

create trigger fantasy_enablements_updated_at
before update on public.fantasy_competition_enablements
for each row execute function public.set_updated_at();

-- ─────────────────────────────────────────────
-- PUBLIC READ MODELS
-- Keep public reads simple for web/mobile while writes
-- stay on the canonical fantasy schema.
-- ─────────────────────────────────────────────
create or replace view public.fantasy_competitions as
select
  c.id,
  c.slug,
  c.name,
  c.short_name,
  c.competition_type,
  c.competition_type as competition_mode,
  c.season,
  c.description,
  c.logo_url,
  c.primary_color,
  c.country_code,
  c.provider,
  c.status as backend_status,
  case
    when c.status = 'active' then 'playable'
    when c.status = 'finished' then 'archived'
    when now() >= (c.start_date - interval '90 days') then 'preview'
    else 'planned'
  end as status,
  c.start_date as start_at,
  c.end_date as end_at
from fantasy.competitions c;

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
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception 'Authentication is required to create a fantasy entry.';
  end if;

  select id
  into v_competition_id
  from fantasy.competitions
  where slug = p_competition_slug;

  if v_competition_id is null then
    raise exception 'Fantasy competition % was not found.', p_competition_slug;
  end if;

  insert into fantasy.fantasy_entries (
    user_id,
    competition_id,
    team_name
  )
  values (
    v_user_id,
    v_competition_id,
    coalesce(nullif(btrim(p_team_name), ''), 'My Fantasy XI')
  )
  on conflict (user_id, competition_id)
  do update set
    updated_at = now()
  returning id into v_entry_id;

  return v_entry_id;
end;
$$;

create or replace function public.fantasy_get_my_entries()
returns table (
  entry_id uuid,
  competition_id uuid,
  team_name text,
  overall_points integer,
  overall_rank integer,
  created_at timestamptz
)
language sql
security definer
set search_path = public, fantasy
as $$
  select
    fe.id as entry_id,
    fe.competition_id,
    fe.team_name,
    fe.overall_points,
    fe.overall_rank,
    fe.created_at
  from fantasy.fantasy_entries fe
  where fe.user_id = auth.uid()
  order by fe.created_at desc;
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
  select
    fe.team_name,
    fe.overall_points as total_points,
    fe.overall_rank,
    coalesce(
      nullif(u.official_name, ''),
      nullif(u.full_name, ''),
      nullif(u.phone, ''),
      'Manager'
    ) as manager_name,
    fe.user_id = auth.uid() as is_current_user
  from fantasy.fantasy_entries fe
  left join public.users u
    on u.id = fe.user_id
  join fantasy.competitions c
    on c.id = fe.competition_id
  where c.slug = p_competition_slug
  order by fe.overall_rank asc nulls last, fe.overall_points desc, fe.created_at asc
  limit greatest(coalesce(p_limit, 20), 1);
$$;

grant select on public.club_app_config to anon, authenticated, service_role;
grant select on public.fantasy_competition_enablements to anon, authenticated, service_role;
grant select on public.fantasy_competitions to anon, authenticated, service_role;
grant execute on function public.fantasy_create_entry(text, text) to authenticated, service_role;
grant execute on function public.fantasy_get_my_entries() to authenticated, service_role;
grant execute on function public.fantasy_get_leaderboard(text, integer) to anon, authenticated, service_role;

-- ─────────────────────────────────────────────
-- DEFAULT SEED DATA
-- Provides launch-ready competitions for the first club
-- while keeping the model multi-tenant.
-- ─────────────────────────────────────────────
do $$
declare
  v_default_club_id bigint;
  v_world_cup_id uuid;
  v_premier_league_id uuid;
  v_rwanda_league_id uuid;
  v_default_scoring_rules jsonb := jsonb_build_object(
    'points_sub_60', 1,
    'points_60_plus', 2,
    'assists_all', 3,
    'captain_multiplier', 2,
    'triple_captain_multiplier', 3,
    'penalty_save', 5,
    'penalty_miss', -2,
    'yellow_card', -1,
    'red_card', -3,
    'own_goal', -2,
    'goals_conceded_per_2', -1,
    'saves_per_3', 1,
    'goals', jsonb_build_object('GK_DEF', 10, 'MID', 6, 'FWD', 4),
    'clean_sheet', jsonb_build_object('GK_DEF', 6, 'MID', 1),
    'defensive_contributions', jsonb_build_object(
      'DEF_threshold', 10,
      'MID_FWD_threshold', 12,
      'points', 2
    )
  );
  v_default_squad_config jsonb := jsonb_build_object(
    'budget', 1000,
    'squad_size', 15,
    'starters', 11,
    'max_per_club', 3,
    'min_def', 3,
    'max_def', 5,
    'min_mid', 2,
    'max_mid', 5,
    'min_fwd', 1,
    'max_fwd', 3
  );
begin
  select id
  into v_default_club_id
  from public.african_football_clubs
  where club_slug = 'rayon_sports_rw'
  limit 1;

  if v_default_club_id is null then
    v_default_club_id := 24;
  end if;

  update public.home_banners
  set club_id = v_default_club_id
  where club_id is null;

  update public.ai_content
  set club_id = v_default_club_id
  where club_id is null;

  insert into public.club_app_config (club_id, key, value, description, country)
  select
    v_default_club_id,
    config.key,
    config.value,
    config.description,
    config.country
  from public.app_config as config
  on conflict (club_id, key) do nothing;

  insert into public.app_config (key, value, description, country)
  values
    ('feature_fantasy_enabled', 'true', 'Master feature flag for fantasy football across mobile and web.', null),
    ('feature_fantasy_home_promo_enabled', 'true', 'Show the fantasy promo/banner on club home surfaces.', null),
    ('feature_fantasy_web_enabled', 'true', 'Expose fantasy pages on the public club website.', null)
  on conflict (key) do update
    set value = excluded.value,
        description = excluded.description,
        country = excluded.country;

  insert into fantasy.competitions (
    slug,
    name,
    short_name,
    competition_type,
    season,
    description,
    logo_url,
    primary_color,
    country_code,
    provider,
    scoring_rules,
    squad_config,
    chip_config,
    transfer_config,
    status,
    start_date,
    end_date,
    external_league_id
  )
  values
    (
      'wc-2026',
      'World Cup Fantasy',
      'World Cup',
      'tournament',
      '2026',
      'Tournament fantasy for the FIFA World Cup 2026, with fast decision cycles, captain swings, and knockout pressure.',
      null,
      '#0EA5E9',
      'INTL',
      'manual-seed',
      v_default_scoring_rules,
      v_default_squad_config,
      jsonb_build_object('wildcard', true, 'triple_captain', true, 'bench_boost', true),
      jsonb_build_object('free_transfers', 1, 'max_transfers_per_round', 2),
      'draft',
      '2026-06-11T00:00:00Z',
      '2026-07-19T23:59:59Z',
      null
    ),
    (
      'pl-2026-27',
      'Premier League Fantasy',
      'Premier League',
      'season_long',
      '2026/27',
      'Season-long fantasy for the Premier League, built around weekly transfers, captaincy, and leaderboard consistency.',
      null,
      '#22C55E',
      'GB',
      'manual-seed',
      v_default_scoring_rules,
      v_default_squad_config,
      jsonb_build_object('wildcard', true, 'triple_captain', true, 'bench_boost', true, 'free_hit', true),
      jsonb_build_object('free_transfers', 1, 'max_transfers_per_round', 20),
      'draft',
      '2026-08-15T00:00:00Z',
      '2027-05-23T23:59:59Z',
      null
    ),
    (
      'rwanda-nsl-2026-27',
      'Rwanda League Fantasy',
      'Rwanda League',
      'season_long',
      '2026/27',
      'Localized fantasy for the Rwanda National League, designed for club-native storytelling and country-specific supporter growth.',
      null,
      '#2563EB',
      'RW',
      'manual-seed',
      v_default_scoring_rules,
      v_default_squad_config,
      jsonb_build_object('wildcard', true, 'triple_captain', true),
      jsonb_build_object('free_transfers', 1, 'max_transfers_per_round', 10),
      'draft',
      '2026-08-29T00:00:00Z',
      '2027-05-30T23:59:59Z',
      null
    )
  on conflict (slug) do update
    set
      name = excluded.name,
      short_name = excluded.short_name,
      competition_type = excluded.competition_type,
      season = excluded.season,
      description = excluded.description,
      primary_color = excluded.primary_color,
      country_code = excluded.country_code,
      provider = excluded.provider,
      scoring_rules = excluded.scoring_rules,
      squad_config = excluded.squad_config,
      chip_config = excluded.chip_config,
      transfer_config = excluded.transfer_config,
      start_date = excluded.start_date,
      end_date = excluded.end_date,
      updated_at = now();

  select id into v_world_cup_id from fantasy.competitions where slug = 'wc-2026';
  select id into v_premier_league_id from fantasy.competitions where slug = 'pl-2026-27';
  select id into v_rwanda_league_id from fantasy.competitions where slug = 'rwanda-nsl-2026-27';

  insert into fantasy.gameweeks (competition_id, number, name, deadline_at, start_at, end_at, status)
  values
    (v_world_cup_id, 1, 'Opening Round', '2026-06-11T15:00:00Z', '2026-06-11T16:00:00Z', '2026-06-17T23:59:59Z', 'upcoming'),
    (v_premier_league_id, 1, 'Gameweek 1', '2026-08-15T10:00:00Z', '2026-08-15T11:00:00Z', '2026-08-17T23:59:59Z', 'upcoming'),
    (v_rwanda_league_id, 1, 'Matchweek 1', '2026-08-29T10:00:00Z', '2026-08-29T11:00:00Z', '2026-08-31T23:59:59Z', 'upcoming')
  on conflict (competition_id, number) do update
    set
      name = excluded.name,
      deadline_at = excluded.deadline_at,
      start_at = excluded.start_at,
      end_at = excluded.end_at,
      status = excluded.status;

  insert into public.fantasy_competition_enablements (
    competition_id,
    club_id,
    promo_title,
    promo_body,
    badge_label,
    cta_label,
    sort_order,
    is_visible,
    is_featured,
    is_playable,
    entry_window_opens_at,
    entry_window_closes_at
  )
  values
    (
      v_world_cup_id,
      v_default_club_id,
      'World Cup fantasy is coming to the home page.',
      'Launch a club-native fantasy program around the 2026 World Cup, then expand into league-specific localized fantasy products.',
      'NEW',
      'Preview fantasy',
      0,
      true,
      true,
      false,
      '2026-04-10T00:00:00Z',
      '2026-06-11T15:00:00Z'
    ),
    (
      v_premier_league_id,
      v_default_club_id,
      'Premier League fantasy is in the rollout queue.',
      'Use the public website and mobile app to stage a broader fantasy launch before the 2026/27 season.',
      'GLOBAL',
      'Explore format',
      1,
      true,
      false,
      false,
      '2026-06-01T00:00:00Z',
      '2026-08-15T10:00:00Z'
    ),
    (
      v_rwanda_league_id,
      v_default_club_id,
      'Localized Rwanda fantasy is part of the core roadmap.',
      'This localized competition is designed to become the flagship country-specific fantasy product once player and fixture data are production-ready.',
      'LOCAL',
      'See roadmap',
      2,
      true,
      false,
      false,
      '2026-06-15T00:00:00Z',
      '2026-08-29T10:00:00Z'
    )
  on conflict (competition_id, club_id) do update
    set
      promo_title = excluded.promo_title,
      promo_body = excluded.promo_body,
      badge_label = excluded.badge_label,
      cta_label = excluded.cta_label,
      sort_order = excluded.sort_order,
      is_visible = excluded.is_visible,
      is_featured = excluded.is_featured,
      is_playable = excluded.is_playable,
      entry_window_opens_at = excluded.entry_window_opens_at,
      entry_window_closes_at = excluded.entry_window_closes_at,
      updated_at = now();
end;
$$;

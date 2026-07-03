-- ============================================================================
-- Enhance Catalog Views with Logo URLs & API Metadata
-- ============================================================================
-- Adds team crest URLs, competition logos, and external IDs to the public
-- catalog views so consumer apps can display logos via hotlinking.
-- Also updates unified_matches and unified_standings to expose these fields.
-- ============================================================================

ALTER TABLE football.competitions ADD COLUMN IF NOT EXISTS logo_url text;

-- ── 1. Enhanced Fixtures Catalog ──

CREATE OR REPLACE VIEW public.football_fixtures_catalog
WITH (security_invoker = true) AS
SELECT
  f.id,
  f.competition_id,
  c.slug AS competition_slug,
  c.name AS competition_name,
  f.season_id,
  s.slug AS season_slug,
  s.label AS season_label,
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
  ht.slug AS home_team_slug,
  ht.name AS home_team_name,
  ht.short_name AS home_team_short_name,
  f.away_team_id,
  at.slug AS away_team_slug,
  at.name AS away_team_name,
  at.short_name AS away_team_short_name,
  f.home_score,
  f.away_score,
  f.leg_number,
  f.status,
  f.metadata,
  f.created_at,
  f.updated_at,
  ht.crest_url AS home_team_logo_url,
  at.crest_url AS away_team_logo_url,
  COALESCE(
    c.logo_url,
    c.metadata ->> 'api_league_logo',
    c.metadata ->> 'storage_league_logo_url'
  ) AS competition_logo_url,
  f.external_provider,
  f.external_fixture_id,
  -- Computed: API metadata for logos (fallback from metadata JSONB)
  COALESCE(
    ht.crest_url,
    (f.metadata ->> 'home_team_logo')
  ) AS home_team_logo,
  COALESCE(
    at.crest_url,
    (f.metadata ->> 'away_team_logo')
  ) AS away_team_logo,
  COALESCE(
    c.metadata ->> 'api_league_logo',
    c.metadata ->> 'storage_league_logo_url',
    c.logo_url
  ) AS competition_logo,
  -- Live elapsed from API sync
  COALESCE(
    (f.metadata ->> 'api_elapsed')::integer,
    0
  ) AS live_elapsed,
  (f.metadata ->> 'api_status_short') AS api_status_short
FROM football.fixtures f
JOIN football.competitions c ON c.id = f.competition_id
JOIN football.seasons s ON s.id = f.season_id
JOIN football.teams ht ON ht.id = f.home_team_id
JOIN football.teams at ON at.id = f.away_team_id;

-- ── 2. Enhanced Standings Catalog ──

CREATE OR REPLACE VIEW public.football_standings_catalog
WITH (security_invoker = true) AS
SELECT
  st.id,
  st.competition_id,
  c.slug AS competition_slug,
  c.name AS competition_name,
  st.season_id,
  s.slug AS season_slug,
  s.label AS season_label,
  st.team_id,
  t.slug AS team_slug,
  t.name AS team_name,
  t.short_name AS team_short_name,
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
  st.updated_at,
  t.crest_url AS team_crest_url,
  COALESCE(
    t.crest_url,
    (st.metadata ->> 'api_team_logo')
  ) AS team_logo
FROM football.standings st
JOIN football.competitions c ON c.id = st.competition_id
JOIN football.seasons s ON s.id = st.season_id
JOIN football.teams t ON t.id = st.team_id;

-- ── 3. Enhanced Teams Catalog ──

CREATE OR REPLACE VIEW public.football_teams_catalog
WITH (security_invoker = true) AS
SELECT
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
  club.club_slug AS source_club_slug,
  club.club_name AS source_club_name,
  t.is_active,
  t.metadata,
  t.created_at,
  t.updated_at,
  COALESCE(
    t.crest_url,
    (t.metadata ->> 'api_logo')
  ) AS team_logo,
  t.external_provider,
  t.external_team_id
FROM football.teams t
LEFT JOIN public.african_football_clubs club ON club.id = t.source_club_id;

-- ── 4. Enhanced Unified Matches View ──

CREATE OR REPLACE VIEW public.unified_matches AS
SELECT
  COALESCE(m.id, f.id) AS id,
  f.id AS fixture_id,
  m.id AS legacy_match_id,
  m.club_id,
  COALESCE(f.home_team_name, m.home_team) AS home_team,
  COALESCE(f.away_team_name, m.away_team) AS away_team,
  COALESCE(f.competition_name, m.competition) AS competition,
  COALESCE(f.venue_name, m.venue) AS venue,
  COALESCE(f.kickoff_at::date, m.match_date) AS match_date,
  COALESCE(f.kickoff_at::time, m.kickoff_time) AS kickoff_time,
  f.kickoff_at,
  COALESCE(m.is_on_sale, false) AS is_on_sale,
  COALESCE(m.ticket_general_price, 0) AS ticket_general_price,
  COALESCE(m.ticket_vip_price, 0) AS ticket_vip_price,
  COALESCE(f.status::text, m.match_status) AS match_status,
  COALESCE(f.home_score, m.home_score) AS home_score,
  COALESCE(f.away_score, m.away_score) AS away_score,
  COALESCE(f.live_elapsed, m.live_minute) AS live_minute,
  m.live_stats,
  m.live_events,
  m.image_url,
  COALESCE(m.is_featured, false) AS is_featured,
  m.capacity,
  m.sold_count,
  f.competition_slug,
  f.season_slug,
  -- New: team logos (hotlinked from API-Football CDN)
  f.home_team_logo,
  f.away_team_logo,
  f.competition_logo,
  f.home_team_logo_url AS home_team_crest_url,
  f.away_team_logo_url AS away_team_crest_url,
  f.home_team_slug,
  f.away_team_slug,
  f.home_team_short_name,
  f.away_team_short_name,
  f.api_status_short,
  f.external_fixture_id
FROM public.football_fixtures_catalog f
LEFT JOIN public.matches m
  ON m.fixture_id = f.id
  OR (
    m.fixture_id IS NULL
    AND m.match_date = f.kickoff_at::date
    AND lower(trim(coalesce(m.home_team, ''))) = lower(trim(coalesce(f.home_team_name, '')))
    AND lower(trim(coalesce(m.away_team, ''))) = lower(trim(coalesce(f.away_team_name, '')))
    AND (
      nullif(trim(coalesce(m.competition, '')), '') IS NULL
      OR lower(trim(m.competition)) = lower(trim(coalesce(f.competition_name, '')))
    )
  );

-- ── 5. Enhanced Unified Standings View ──

CREATE OR REPLACE VIEW public.unified_standings AS
SELECT
  COALESCE(s.id, st.id) AS id,
  st.id AS fixture_standing_id,
  s.club_id,
  COALESCE(st.team_name, s.club_name) AS club_name,
  COALESCE(st.team_slug, s.club_slug) AS club_slug,
  COALESCE(st.position, s.position) AS position,
  COALESCE(st.played, s.played) AS played,
  COALESCE(st.won, s.won) AS won,
  COALESCE(st.drawn, s.drawn) AS drawn,
  COALESCE(st.lost, s.lost) AS lost,
  COALESCE(st.goals_for, s.goals_for) AS goals_for,
  COALESCE(st.goals_against, s.goals_against) AS goals_against,
  COALESCE(st.goal_difference, s.goal_difference) AS goal_difference,
  COALESCE(st.points, s.points) AS points,
  COALESCE(st.form, s.form) AS form,
  st.competition_slug,
  st.season_slug,
  -- New: team logos
  st.team_crest_url,
  st.team_logo
FROM public.football_standings_catalog st
LEFT JOIN public.standings s ON s.club_slug = st.team_slug;

-- Re-grant permissions
GRANT SELECT ON public.football_fixtures_catalog TO anon, authenticated, service_role;
GRANT SELECT ON public.football_standings_catalog TO anon, authenticated, service_role;
GRANT SELECT ON public.football_teams_catalog TO anon, authenticated, service_role;
GRANT SELECT ON public.unified_matches TO anon, authenticated, service_role;
GRANT SELECT ON public.unified_standings TO anon, authenticated, service_role;

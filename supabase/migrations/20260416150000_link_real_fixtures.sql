-- ============================================================================
-- Link Real Fixtures and Standings
-- ============================================================================
-- Connects legacy public tables with the new structured football schema.
-- ============================================================================

-- 1. Add link column to matches
ALTER TABLE public.matches ADD COLUMN IF NOT EXISTS fixture_id uuid REFERENCES football.fixtures(id) ON DELETE SET NULL;
COMMENT ON COLUMN public.matches.fixture_id IS 'Link to the structured fixture in football schema.';

-- Backfill links for legacy matches using the stable fields shared by both
-- schemas. The legacy table does not carry external fixture identifiers.
UPDATE public.matches m
SET fixture_id = f.id
FROM public.football_fixtures_catalog f
WHERE m.fixture_id IS NULL
  AND m.match_date = f.kickoff_at::date
  AND lower(trim(coalesce(m.home_team, ''))) = lower(trim(coalesce(f.home_team_name, '')))
  AND lower(trim(coalesce(m.away_team, ''))) = lower(trim(coalesce(f.away_team_name, '')))
  AND (
    nullif(trim(coalesce(m.competition, '')), '') IS NULL
    OR lower(trim(m.competition)) = lower(trim(coalesce(f.competition_name, '')))
  );

-- 2. Create a unified view for matches
-- This view prefers data from football.fixtures but includes ticketing from public.matches
CREATE OR REPLACE VIEW public.unified_matches AS
SELECT 
  COALESCE(m.id, f.id) as id,
  f.id as fixture_id,
  m.id as legacy_match_id,
  m.club_id,
  COALESCE(f.home_team_name, m.home_team) as home_team,
  COALESCE(f.away_team_name, m.away_team) as away_team,
  COALESCE(f.competition_name, m.competition) as competition,
  COALESCE(f.venue_name, m.venue) as venue,
  COALESCE(f.kickoff_at::date, m.match_date) as match_date,
  COALESCE(f.kickoff_at::time, m.kickoff_time) as kickoff_time,
  f.kickoff_at,
  COALESCE(m.is_on_sale, false) as is_on_sale,
  COALESCE(m.ticket_general_price, 0) as ticket_general_price,
  COALESCE(m.ticket_vip_price, 0) as ticket_vip_price,
  COALESCE(f.status::text, m.match_status) as match_status,
  COALESCE(f.home_score, m.home_score) as home_score,
  COALESCE(f.away_score, m.away_score) as away_score,
  m.live_minute,
  m.live_stats,
  m.live_events,
  m.image_url,
  COALESCE(m.is_featured, false) as is_featured,
  m.capacity,
  m.sold_count,
  f.competition_slug,
  f.season_slug
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

-- 3. Create a unified view for standings
CREATE OR REPLACE VIEW public.unified_standings AS
SELECT
  COALESCE(s.id, st.id) as id,
  st.id as fixture_standing_id,
  s.club_id,
  COALESCE(st.team_name, s.club_name) as club_name,
  COALESCE(st.team_slug, s.club_slug) as club_slug,
  COALESCE(st.position, s.position) as position,
  COALESCE(st.played, s.played) as played,
  COALESCE(st.won, s.won) as won,
  COALESCE(st.drawn, s.drawn) as drawn,
  COALESCE(st.lost, s.lost) as lost,
  COALESCE(st.goals_for, s.goals_for) as goals_for,
  COALESCE(st.goals_against, s.goals_against) as goals_against,
  COALESCE(st.goal_difference, s.goal_difference) as goal_difference,
  COALESCE(st.points, s.points) as points,
  COALESCE(st.form, s.form) as form,
  st.competition_slug,
  st.season_slug
FROM public.football_standings_catalog st
LEFT JOIN public.standings s ON s.club_slug = st.team_slug;

-- Permissions
GRANT SELECT ON public.unified_matches TO anon, authenticated, service_role;
GRANT SELECT ON public.unified_standings TO anon, authenticated, service_role;

-- 4. Create a unified view for the roster
CREATE OR REPLACE VIEW public.unified_roster AS
SELECT
  COALESCE(s.id, r.id) as id,
  r.id as registration_id,
  s.club_id,
  COALESCE(r.player_name, s.name) as name,
  COALESCE(r.position, s.position) as role,
  COALESCE(r.squad_number, s.shirt_number) as number,
  s.nationality,
  s.bio,
  COALESCE(s.photo_url, s.image_url) as image_url,
  s.is_active,
  r.season_slug
FROM public.football_roster_catalog r
LEFT JOIN public.squad_players s ON s.name = r.player_name;

GRANT SELECT ON public.unified_roster TO anon, authenticated, service_role;

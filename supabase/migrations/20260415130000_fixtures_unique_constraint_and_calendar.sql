-- ============================================================================
-- 1) Unique constraint to prevent duplicate fixtures permanently
-- 2) Calendar-friendly RPCs for fixtures by date range
-- ============================================================================

-- ── Step 1: Immutable date extraction for index ────────────────────────────
CREATE OR REPLACE FUNCTION football.kickoff_date(ts timestamptz)
RETURNS date
LANGUAGE sql
IMMUTABLE PARALLEL SAFE
AS $$ SELECT ts::date; $$;

-- Unique index using immutable function: same teams on same day = duplicate
CREATE UNIQUE INDEX IF NOT EXISTS uq_fixtures_match_per_day
ON football.fixtures (
  competition_id,
  home_team_id,
  away_team_id,
  football.kickoff_date(kickoff_at)
)
WHERE kickoff_at IS NOT NULL;

-- ── Step 2: Calendar RPC – fixtures by date range with optional filters ────
CREATE OR REPLACE FUNCTION public.fixtures_calendar(
  p_date_from date DEFAULT CURRENT_DATE,
  p_date_to   date DEFAULT CURRENT_DATE,
  p_competition_slug text DEFAULT NULL,
  p_status     text DEFAULT NULL,
  p_limit      int  DEFAULT 200
)
RETURNS TABLE (
  id uuid,
  competition_id uuid,
  competition_slug text,
  competition_name text,
  season_id uuid,
  season_slug text,
  season_label text,
  stage_name text,
  group_name text,
  round_name text,
  matchday int,
  fixture_number int,
  kickoff_at timestamptz,
  venue_name text,
  venue_city text,
  venue_country text,
  home_team_id uuid,
  home_team_slug text,
  home_team_name text,
  home_team_short_name text,
  away_team_id uuid,
  away_team_slug text,
  away_team_name text,
  away_team_short_name text,
  home_score int,
  away_score int,
  leg_number int,
  status text,
  metadata jsonb,
  created_at timestamptz,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    f.id, f.competition_id, f.competition_slug, f.competition_name,
    f.season_id, f.season_slug, f.season_label,
    f.stage_name, f.group_name, f.round_name,
    f.matchday, f.fixture_number, f.kickoff_at,
    f.venue_name, f.venue_city, f.venue_country,
    f.home_team_id, f.home_team_slug, f.home_team_name, f.home_team_short_name,
    f.away_team_id, f.away_team_slug, f.away_team_name, f.away_team_short_name,
    f.home_score, f.away_score, f.leg_number,
    f.status::text, f.metadata, f.created_at, f.updated_at
  FROM prediction_supported_fixtures_catalog f
  WHERE (f.kickoff_at::date >= p_date_from)
    AND (f.kickoff_at::date <= p_date_to)
    AND (p_competition_slug IS NULL OR f.competition_slug = p_competition_slug)
    AND (p_status IS NULL OR f.status::text = p_status)
  ORDER BY f.kickoff_at ASC, f.competition_name ASC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.fixtures_calendar TO anon, authenticated;

-- ── Step 3: Fixture date summary – counts per date for calendar dots ───────
CREATE OR REPLACE FUNCTION public.fixtures_date_summary(
  p_date_from date DEFAULT (CURRENT_DATE - 7),
  p_date_to   date DEFAULT (CURRENT_DATE + 30),
  p_competition_slug text DEFAULT NULL
)
RETURNS TABLE (
  match_date date,
  fixture_count int,
  has_live boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    f.kickoff_at::date AS match_date,
    count(*)::int AS fixture_count,
    bool_or(f.status::text = 'live') AS has_live
  FROM prediction_supported_fixtures_catalog f
  WHERE (f.kickoff_at::date >= p_date_from)
    AND (f.kickoff_at::date <= p_date_to)
    AND (p_competition_slug IS NULL OR f.competition_slug = p_competition_slug)
  GROUP BY f.kickoff_at::date
  ORDER BY match_date;
$$;

GRANT EXECUTE ON FUNCTION public.fixtures_date_summary TO anon, authenticated;

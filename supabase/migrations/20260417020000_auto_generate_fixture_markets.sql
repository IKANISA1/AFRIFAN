-- ============================================================================
-- Auto-Generate Fixture Markets + Odds Update Infrastructure
-- ============================================================================
-- 1. Function to auto-create fixture_markets for a fixture using all active
--    prediction_markets from the catalog
-- 2. Trigger on football.fixtures to auto-create markets when fixtures are
--    inserted with status = 'scheduled'
-- 3. Function for the multiplier edge function to update outcome odds
-- 4. View for user voting volume (used by liability adjustment)
-- ============================================================================

-- ── 1. Auto-Generate Fixture Markets ──────────────────────────────────────

CREATE OR REPLACE FUNCTION football.generate_fixture_markets(p_fixture_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, football
AS $$
DECLARE
  v_count integer := 0;
  v_market record;
BEGIN
  -- Iterate over all active prediction markets
  FOR v_market IN
    SELECT id, outcome_template, default_fet_value
    FROM football.prediction_markets
    WHERE is_active = true
  LOOP
    -- Skip if already exists (idempotent)
    INSERT INTO football.fixture_markets (fixture_id, market_id, outcomes)
    VALUES (p_fixture_id, v_market.id, v_market.outcome_template)
    ON CONFLICT (fixture_id, market_id) DO NOTHING;

    IF FOUND THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION football.generate_fixture_markets(uuid) IS
  'Auto-creates fixture_markets for all active prediction_markets. Idempotent.';

-- ── 2. Trigger: Auto-create markets on fixture insert ─────────────────────

CREATE OR REPLACE FUNCTION football.trg_auto_generate_fixture_markets()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, football
AS $$
BEGIN
  -- Only generate for scheduled fixtures
  IF NEW.status = 'scheduled' THEN
    -- Only on INSERT, or on UPDATE when status changes TO scheduled
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND OLD.status IS DISTINCT FROM 'scheduled') THEN
      PERFORM football.generate_fixture_markets(NEW.id);
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS auto_generate_fixture_markets ON football.fixtures;
CREATE TRIGGER auto_generate_fixture_markets
  AFTER INSERT OR UPDATE OF status ON football.fixtures
  FOR EACH ROW
  EXECUTE FUNCTION football.trg_auto_generate_fixture_markets();

-- ── 3. Update Fixture Market Odds ─────────────────────────────────────────

CREATE OR REPLACE FUNCTION football.update_fixture_market_odds(
  p_fixture_market_id uuid,
  p_outcomes jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, football
AS $$
BEGIN
  UPDATE football.fixture_markets
  SET outcomes = p_outcomes,
      updated_at = now()
  WHERE id = p_fixture_market_id;
END;
$$;

COMMENT ON FUNCTION football.update_fixture_market_odds(uuid, jsonb) IS
  'Updates the outcomes JSONB (with odds) for a specific fixture_market.';

-- ── 4. Batch Update All Markets for a Fixture ─────────────────────────────

CREATE OR REPLACE FUNCTION football.update_fixture_odds_batch(
  p_fixture_id uuid,
  p_market_odds jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, football
AS $$
DECLARE
  v_entry jsonb;
  v_market_slug text;
  v_outcomes jsonb;
  v_updated integer := 0;
BEGIN
  -- p_market_odds is an array of { market_slug, outcomes }
  FOR v_entry IN SELECT * FROM jsonb_array_elements(p_market_odds)
  LOOP
    v_market_slug := v_entry ->> 'market_slug';
    v_outcomes := v_entry -> 'outcomes';

    UPDATE football.fixture_markets fm
    SET outcomes = v_outcomes,
        updated_at = now()
    FROM football.prediction_markets pm
    WHERE fm.market_id = pm.id
      AND fm.fixture_id = p_fixture_id
      AND pm.slug = v_market_slug;

    IF FOUND THEN
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  RETURN v_updated;
END;
$$;

COMMENT ON FUNCTION football.update_fixture_odds_batch(uuid, jsonb) IS
  'Batch-updates odds for all markets of a fixture. Called by generate-multipliers edge function.';

-- ── 5. User Voting Volume View ────────────────────────────────────────────

CREATE OR REPLACE VIEW football.prediction_volume AS
SELECT
  fm.fixture_id,
  fm.id AS fixture_market_id,
  pm.slug AS market_slug,
  p.selected_outcome,
  COUNT(*) AS vote_count,
  COUNT(*)::numeric / NULLIF(SUM(COUNT(*)) OVER (PARTITION BY fm.id), 0) AS vote_pct
FROM football.predictions p
JOIN football.fixture_markets fm ON fm.id = p.fixture_market_id
JOIN football.prediction_markets pm ON pm.id = fm.market_id
WHERE p.status = 'pending'
GROUP BY fm.fixture_id, fm.id, pm.slug, p.selected_outcome;

COMMENT ON VIEW football.prediction_volume IS
  'Aggregated user voting percentages per fixture market outcome. Used for liability adjustment.';

-- ── 6. Feature Stats View (for probability engine) ────────────────────────

CREATE OR REPLACE VIEW football.fixture_features AS
SELECT
  f.id AS fixture_id,
  f.competition_id,
  f.home_team_id,
  f.away_team_id,
  f.kickoff_at,
  f.status,
  -- Home team stats
  (
    SELECT COUNT(*) FILTER (WHERE fx.home_score > fx.away_score)::numeric
         / NULLIF(COUNT(*), 0)
    FROM football.fixtures fx
    WHERE fx.home_team_id = f.home_team_id
      AND fx.status = 'finished'
      AND fx.id != f.id
  ) AS home_team_win_rate,
  (
    SELECT COUNT(*) FILTER (WHERE fx.away_score > fx.home_score)::numeric
         / NULLIF(COUNT(*), 0)
    FROM football.fixtures fx
    WHERE fx.away_team_id = f.away_team_id
      AND fx.status = 'finished'
      AND fx.id != f.id
  ) AS away_team_win_rate,
  (
    SELECT COUNT(*) FILTER (WHERE fx.home_score = fx.away_score)::numeric
         / NULLIF(COUNT(*), 0)
    FROM football.fixtures fx
    WHERE fx.home_team_id = f.home_team_id
      AND fx.status = 'finished'
      AND fx.id != f.id
  ) AS home_team_draw_rate,
  (
    SELECT COALESCE(AVG(fx.home_score), 0)
    FROM football.fixtures fx
    WHERE fx.home_team_id = f.home_team_id
      AND fx.status = 'finished'
      AND fx.id != f.id
  ) AS home_goals_scored_avg,
  (
    SELECT COALESCE(AVG(fx.away_score), 0)
    FROM football.fixtures fx
    WHERE fx.home_team_id = f.home_team_id
      AND fx.status = 'finished'
      AND fx.id != f.id
  ) AS home_goals_conceded_avg,
  (
    SELECT COALESCE(AVG(fx.away_score), 0)
    FROM football.fixtures fx
    WHERE fx.away_team_id = f.away_team_id
      AND fx.status = 'finished'
      AND fx.id != f.id
  ) AS away_goals_scored_avg,
  (
    SELECT COALESCE(AVG(fx.home_score), 0)
    FROM football.fixtures fx
    WHERE fx.away_team_id = f.away_team_id
      AND fx.status = 'finished'
      AND fx.id != f.id
  ) AS away_goals_conceded_avg,
  -- H2H stats
  (
    SELECT COUNT(*) FILTER (WHERE
      (fx.home_team_id = f.home_team_id AND fx.home_score > fx.away_score) OR
      (fx.away_team_id = f.home_team_id AND fx.away_score > fx.home_score)
    )
    FROM football.fixtures fx
    WHERE fx.status = 'finished'
      AND (
        (fx.home_team_id = f.home_team_id AND fx.away_team_id = f.away_team_id) OR
        (fx.home_team_id = f.away_team_id AND fx.away_team_id = f.home_team_id)
      )
  ) AS h2h_home_wins,
  (
    SELECT COUNT(*) FILTER (WHERE
      (fx.home_team_id = f.away_team_id AND fx.home_score > fx.away_score) OR
      (fx.away_team_id = f.away_team_id AND fx.away_score > fx.home_score)
    )
    FROM football.fixtures fx
    WHERE fx.status = 'finished'
      AND (
        (fx.home_team_id = f.home_team_id AND fx.away_team_id = f.away_team_id) OR
        (fx.home_team_id = f.away_team_id AND fx.away_team_id = f.home_team_id)
      )
  ) AS h2h_away_wins,
  (
    SELECT COUNT(*) FILTER (WHERE fx.home_score = fx.away_score)
    FROM football.fixtures fx
    WHERE fx.status = 'finished'
      AND (
        (fx.home_team_id = f.home_team_id AND fx.away_team_id = f.away_team_id) OR
        (fx.home_team_id = f.away_team_id AND fx.away_team_id = f.home_team_id)
      )
  ) AS h2h_draws,
  -- Standing positions (latest)
  (
    SELECT st.position FROM football.standings st
    WHERE st.team_id = f.home_team_id
      AND st.competition_id = f.competition_id
    ORDER BY st.updated_at DESC LIMIT 1
  ) AS home_league_position,
  (
    SELECT st.position FROM football.standings st
    WHERE st.team_id = f.away_team_id
      AND st.competition_id = f.competition_id
    ORDER BY st.updated_at DESC LIMIT 1
  ) AS away_league_position
FROM football.fixtures f
WHERE f.status = 'scheduled';

COMMENT ON VIEW football.fixture_features IS
  'Pre-computed features for the probability engine. Reads historical fixture stats, h2h, and standings.';

-- Grants
GRANT EXECUTE ON FUNCTION football.generate_fixture_markets(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION football.update_fixture_market_odds(uuid, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION football.update_fixture_odds_batch(uuid, jsonb) TO service_role;
GRANT SELECT ON football.prediction_volume TO service_role;
GRANT SELECT ON football.fixture_features TO service_role;

-- ============================================================================
-- Fix: Rename DRC Premier League → Linafoot & tighten seeding league filter
-- 1. Rename competition slug/name/short_name
-- 2. Replace ILIKE-based EPL matching that falsely matched DRC/Rwanda
-- 3. Clean up mis-seeded EPL-only markets from non-EPL fixtures
-- ============================================================================

-- ── 1. Rename DRC competition to Linafoot ──────────────────────────────────

UPDATE football.competitions
SET
  slug = 'linafoot',
  short_name = 'Linafoot',
  name = 'Linafoot (DRC)'
WHERE slug = 'drc-premier-league'
  AND NOT EXISTS (
    SELECT 1 FROM football.competitions WHERE slug = 'linafoot'
  );

-- ── 2. Clean mis-seeded EPL-only markets from non-EPL/non-La-Liga fixtures ─

DELETE FROM football.fixture_markets
WHERE market_id IN (
  SELECT id FROM football.prediction_markets
  WHERE NOT ('All' = ANY(league_availability))
    AND ('EPL' = ANY(league_availability) OR 'La Liga' = ANY(league_availability))
)
AND fixture_id IN (
  SELECT f.id FROM football.fixtures f
  JOIN football.competitions c ON c.id = f.competition_id
  WHERE c.slug NOT IN ('english-premier-league', 'la-liga')
);

-- ── 3. Replace seeding function with exact-match league filter ─────────────

CREATE OR REPLACE FUNCTION football.seed_fixture_prediction_markets(
  p_fixture_id uuid,
  p_force boolean DEFAULT false
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, football
AS $$
DECLARE
  v_seeded integer := 0;
BEGIN
  WITH fixture_state AS (
    SELECT
      fixture.id,
      fixture.kickoff_at,
      fixture.status,
      comp.slug AS competition_slug,
      comp.short_name AS competition_short_name,
      (
        fixture.status IN ('live', 'finished')
        OR (fixture.kickoff_at IS NOT NULL AND fixture.kickoff_at <= now())
      ) AS is_locked_now
    FROM football.fixtures fixture
    JOIN football.competitions comp ON comp.id = fixture.competition_id
    WHERE fixture.id = p_fixture_id
  ),
  seed_rows AS (
    SELECT
      fs.id AS fixture_id,
      market.id AS market_id,
      football.prediction_seed_outcomes(
        market.slug,
        market.outcome_template
      ) AS outcomes,
      fs.is_locked_now AS is_locked,
      CASE WHEN fs.is_locked_now THEN coalesce(fs.kickoff_at, now()) END AS locked_at
    FROM fixture_state fs
    JOIN football.prediction_markets market ON market.is_active = true
    WHERE
      -- Must have resolvable outcomes
      jsonb_array_length(
        football.prediction_seed_outcomes(market.slug, market.outcome_template)
      ) > 0
      -- Skip outright markets (they are not per-fixture)
      AND market.market_group != 'outright'
      -- Filter by league_availability using EXACT slug/short_name matching
      AND (
        'All' = ANY(market.league_availability)
        OR fs.competition_slug = ANY(market.league_availability)
        OR fs.competition_short_name = ANY(market.league_availability)
        OR (EXISTS (
          SELECT 1 FROM unnest(market.league_availability) AS avail(val)
          WHERE
            -- EPL: exact slug match only (prevents false-positive on rwanda/drc)
            (avail.val = 'EPL' AND (
              fs.competition_slug = 'english-premier-league'
              OR fs.competition_short_name = 'EPL'
            ))
            OR (avail.val = 'La Liga' AND (
              fs.competition_slug = 'la-liga'
              OR fs.competition_short_name = 'La Liga'
            ))
            OR (avail.val = 'RPL' AND (
              fs.competition_slug = 'rwanda-premier-league'
              OR fs.competition_short_name = 'RPL'
            ))
            OR (avail.val = 'ZSL' AND (
              fs.competition_slug = 'zambia-super-league'
              OR fs.competition_short_name ILIKE '%Zambia%'
            ))
            OR (avail.val = 'Linafoot' AND (
              fs.competition_slug = 'linafoot'
              OR fs.competition_short_name = 'Linafoot'
            ))
            OR (avail.val ILIKE '%world%cup%' AND (
              fs.competition_slug ILIKE '%world-cup%'
              OR fs.competition_short_name ILIKE '%World Cup%'
            ))
        ))
      )
  ),
  upserted AS (
    INSERT INTO football.fixture_markets (
      fixture_id,
      market_id,
      outcomes,
      is_locked,
      locked_at
    )
    SELECT
      fixture_id,
      market_id,
      outcomes,
      is_locked,
      locked_at
    FROM seed_rows
    ON CONFLICT (fixture_id, market_id) DO UPDATE
      SET outcomes = CASE
            WHEN p_force THEN excluded.outcomes
            ELSE football.fixture_markets.outcomes
          END,
          is_locked = excluded.is_locked,
          locked_at = excluded.locked_at,
          updated_at = now()
    RETURNING 1
  )
  SELECT count(*) INTO v_seeded
  FROM upserted;

  RETURN coalesce(v_seeded, 0);
END;
$$;

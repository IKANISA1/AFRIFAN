-- ============================================================================
-- Add market_category and bet_type to prediction_get_fixture_markets RPC
-- so the Flutter app can group markets by detailed category.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.prediction_get_fixture_markets(
  p_fixture_id uuid
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, football
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_rows jsonb;
BEGIN
  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_order), '[]'::jsonb)
    INTO v_rows
  FROM (
    SELECT
      jsonb_build_object(
        'fixture_market_id', fm.id,
        'market_id', pm.id,
        'market_slug', pm.slug,
        'market_name', pm.name,
        'market_short_name', pm.short_name,
        'market_group', pm.market_group,
        'market_category', pm.market_category,
        'bet_type', pm.bet_type,
        'difficulty_tier', pm.difficulty_tier,
        'description', pm.description,
        'fet_value', coalesce(fm.fet_value_override, pm.default_fet_value),
        'outcomes', fm.outcomes,
        'is_locked',
          fm.is_locked
          OR f.status IN ('live', 'finished')
          OR (f.kickoff_at IS NOT NULL AND f.kickoff_at <= now()),
        'user_prediction', (
          SELECT jsonb_build_object(
            'prediction_id', up.id,
            'selected_outcome', up.selected_outcome,
            'status', up.status
          )
          FROM football.predictions up
          WHERE up.fixture_market_id = fm.id
            AND up.user_id = v_user_id
            AND up.status IN ('pending', 'won', 'lost', 'void')
          LIMIT 1
        )
      ) AS row_data,
      pm.sort_order
    FROM football.fixture_markets fm
    JOIN football.prediction_markets pm ON pm.id = fm.market_id
    JOIN football.fixtures f ON f.id = fm.fixture_id
    WHERE fm.fixture_id = p_fixture_id
      AND pm.is_active = true
      AND jsonb_array_length(fm.outcomes) > 0
    ORDER BY pm.sort_order
  ) sub;

  RETURN v_rows;
END;
$$;

-- ============================================================================
-- prediction_admin_settle: One-click fixture settlement
-- Admin enters score → outcomes auto-computed → predictions graded → notifications queued
-- ============================================================================

CREATE OR REPLACE FUNCTION public.prediction_admin_settle(
  p_fixture_id UUID,
  p_home_score INT,
  p_away_score INT,
  p_status TEXT DEFAULT 'finished'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'football'
AS $function$
declare
  v_settlements jsonb := '[]'::jsonb;
  v_fm record;
  v_correct_outcome text;
  v_total_goals int;
  v_ht_result text;  -- not auto-derivable from FT score, will be skipped
  v_settle_result jsonb;
  v_acca_result jsonb;
  v_notif_result jsonb;
  v_streak_user record;
begin
  -- ── Auth: service_role only ──
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  -- ── Validate fixture exists ──
  if not exists (select 1 from football.fixtures where id = p_fixture_id) then
    return jsonb_build_object('status', 'error', 'message', 'Fixture not found.');
  end if;

  -- ── 1. Update fixture with score + status ──
  UPDATE football.fixtures
  SET home_score = p_home_score,
      away_score = p_away_score,
      status = p_status,
      updated_at = now()
  WHERE id = p_fixture_id;

  -- ── 2. Auto-compute correct outcomes per market ──
  v_total_goals := p_home_score + p_away_score;

  FOR v_fm IN
    SELECT fm.id as fm_id, pm.slug as market_slug
    FROM football.fixture_markets fm
    JOIN football.prediction_markets pm ON pm.id = fm.market_id
    WHERE fm.fixture_id = p_fixture_id
  LOOP
    v_correct_outcome := NULL;

    CASE v_fm.market_slug
      -- Match winner (1X2)
      WHEN '1x2' THEN
        v_correct_outcome := CASE
          WHEN p_home_score > p_away_score THEN 'Home'
          WHEN p_home_score = p_away_score THEN 'Draw'
          ELSE 'Away'
        END;

      -- Both teams to score
      WHEN 'btts' THEN
        v_correct_outcome := CASE
          WHEN p_home_score > 0 AND p_away_score > 0 THEN 'Yes'
          ELSE 'No'
        END;

      -- Over/Under 1.5
      WHEN 'over-under-1-5' THEN
        v_correct_outcome := CASE
          WHEN v_total_goals > 1 THEN 'Over 1.5'
          ELSE 'Under 1.5'
        END;

      -- Over/Under 2.5
      WHEN 'over-under-2-5' THEN
        v_correct_outcome := CASE
          WHEN v_total_goals > 2 THEN 'Over 2.5'
          ELSE 'Under 2.5'
        END;

      -- Half-time result — cannot derive from FT score, skip
      WHEN 'half-time-result' THEN
        v_correct_outcome := NULL;

      ELSE
        v_correct_outcome := NULL;
    END CASE;

    IF v_correct_outcome IS NOT NULL THEN
      v_settlements := v_settlements || jsonb_build_object(
        'market_slug', v_fm.market_slug,
        'correct_outcome', v_correct_outcome
      );
    END IF;
  END LOOP;

  -- ── 3. Settle predictions ──
  v_settle_result := '{"status":"skipped"}'::jsonb;
  IF jsonb_array_length(v_settlements) > 0 THEN
    v_settle_result := public.prediction_settle_fixture(p_fixture_id, v_settlements);
  END IF;

  -- ── 4. Settle acca slips ──
  v_acca_result := public.prediction_settle_acca_slips(p_fixture_id);

  -- ── 5. Queue push notifications ──
  v_notif_result := public.prediction_queue_settlement_notifications(p_fixture_id);

  -- ── 6. Check streak rewards for all users with settled predictions ──
  FOR v_streak_user IN
    SELECT DISTINCT p.user_id
    FROM football.predictions p
    WHERE p.fixture_id = p_fixture_id
      AND p.status IN ('won', 'lost')
      AND p.settled_at >= now() - interval '10 seconds'
  LOOP
    BEGIN
      PERFORM public.prediction_check_streak_reward(v_streak_user.user_id);
    EXCEPTION WHEN OTHERS THEN
      RAISE NOTICE 'Streak check failed for user %: %', v_streak_user.user_id, SQLERRM;
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'status', 'success',
    'fixture_id', p_fixture_id,
    'score', format('%s - %s', p_home_score, p_away_score),
    'markets_settled', jsonb_array_length(v_settlements),
    'settlement', v_settle_result,
    'acca', v_acca_result,
    'notifications', v_notif_result
  );
END;
$function$;

-- Grant execute to service_role only
REVOKE ALL ON FUNCTION public.prediction_admin_settle(UUID, INT, INT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.prediction_admin_settle(UUID, INT, INT, TEXT) TO service_role;

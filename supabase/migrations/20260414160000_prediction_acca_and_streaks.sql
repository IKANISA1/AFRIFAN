-- ============================================================================
-- Phase 3: Acca prediction support + streak milestone rewards
-- Adds multi-leg acca placement RPC, enhanced acca settlement logic,
-- and streak-based FET bonus rewards.
-- ============================================================================

-- ── Acca placement RPC ────────────────────────────────────────────────────
-- Places multiple predictions in one acca slip.
-- All legs must be from different fixture_markets.
-- FET multiplier: base acca FET = sum of individual FET values × multiplier.
-- Multiplier: 2 legs = 1.5x, 3 legs = 2x, 4+ legs = 3x.

create or replace function public.prediction_place_acca(
  p_selections jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_selection jsonb;
  v_fm record;
  v_slip_id uuid;
  v_prediction_id uuid;
  v_leg_count integer;
  v_total_base_fet integer := 0;
  v_multiplier numeric;
  v_placed_ids uuid[] := '{}';
  v_errors text[] := '{}';
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'error', 'message', 'Authentication required.');
  end if;

  v_leg_count := jsonb_array_length(p_selections);

  if v_leg_count < 2 then
    return jsonb_build_object('status', 'error', 'message', 'Acca requires at least 2 selections.');
  end if;

  if v_leg_count > 10 then
    return jsonb_build_object('status', 'error', 'message', 'Maximum 10 selections per acca.');
  end if;

  -- Determine multiplier
  v_multiplier := case
    when v_leg_count = 2 then 1.5
    when v_leg_count = 3 then 2.0
    when v_leg_count >= 4 then 3.0
    else 1.0
  end;

  -- Create acca slip
  insert into football.prediction_slips (user_id, slip_type, leg_count)
  values (v_user_id, 'acca', v_leg_count)
  returning id into v_slip_id;

  -- Process each selection
  for v_selection in select * from jsonb_array_elements(p_selections)
  loop
    declare
      v_fm_id uuid := (v_selection->>'fixture_market_id')::uuid;
      v_outcome text := v_selection->>'selected_outcome';
      v_fet_value integer;
    begin
      -- Resolve fixture market
      select fm.*, f.status as fixture_status, f.kickoff_at,
             coalesce(fm.fet_value_override, pm.default_fet_value) as resolved_fet
      into v_fm
      from football.fixture_markets fm
      join football.fixtures f on f.id = fm.fixture_id
      join football.prediction_markets pm on pm.id = fm.market_id
      where fm.id = v_fm_id;

      if v_fm is null then
        v_errors := v_errors || format('Market %s not found.', v_fm_id);
        continue;
      end if;

      if v_fm.is_locked then
        v_errors := v_errors || format('Market %s is locked.', v_fm_id);
        continue;
      end if;

      if v_fm.fixture_status in ('live', 'finished') then
        v_errors := v_errors || format('Fixture for market %s already started.', v_fm_id);
        continue;
      end if;

      if v_fm.kickoff_at is not null and v_fm.kickoff_at <= now() then
        v_errors := v_errors || format('Market %s past kickoff.', v_fm_id);
        continue;
      end if;

      v_fet_value := v_fm.resolved_fet;
      v_total_base_fet := v_total_base_fet + v_fet_value;

      -- Insert prediction (skip if duplicate)
      insert into football.predictions (
        user_id, fixture_id, fixture_market_id, slip_id,
        selected_outcome, fet_staked
      )
      values (
        v_user_id, v_fm.fixture_id, v_fm_id, v_slip_id,
        v_outcome, 0
      )
      on conflict (user_id, fixture_id, fixture_market_id) do update
      set selected_outcome = excluded.selected_outcome,
          slip_id = excluded.slip_id,
          placed_at = now()
      returning id into v_prediction_id;

      v_placed_ids := v_placed_ids || v_prediction_id;
    end;
  end loop;

  -- If no legs were placed, cancel the slip
  if array_length(v_placed_ids, 1) is null or array_length(v_placed_ids, 1) < 2 then
    update football.prediction_slips
    set status = 'cancelled'
    where id = v_slip_id;

    return jsonb_build_object(
      'status', 'error',
      'message', 'Could not place acca — fewer than 2 valid selections.',
      'errors', to_jsonb(v_errors)
    );
  end if;

  -- Update slip leg count to actual placed count
  update football.prediction_slips
  set leg_count = array_length(v_placed_ids, 1)
  where id = v_slip_id;

  return jsonb_build_object(
    'status', 'placed',
    'slip_id', v_slip_id,
    'legs_placed', array_length(v_placed_ids, 1),
    'base_fet', v_total_base_fet,
    'multiplier', v_multiplier,
    'potential_fet', floor(v_total_base_fet * v_multiplier),
    'errors', to_jsonb(v_errors),
    'message', format('%s-leg acca placed successfully.', array_length(v_placed_ids, 1))
  );
end;
$$;

grant execute on function public.prediction_place_acca(jsonb) to authenticated;

-- ── Enhanced acca settlement in predict_settle_fixture ──────────────────
-- The existing settlement already handles slips; this adds the acca
-- multiplier bonus. After the main settlement loop, check acca slips
-- where ALL legs are now settled.

create or replace function public.prediction_settle_acca_slips(
  p_fixture_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_slip record;
  v_all_won boolean;
  v_total_base_fet integer;
  v_leg_count integer;
  v_multiplier numeric;
  v_bonus_fet integer;
  v_club_id bigint;
  v_settled_count integer := 0;
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  -- Resolve club
  select id into v_club_id from public.african_football_clubs limit 1;

  -- Find acca slips that have legs in this fixture and are still pending
  for v_slip in
    select distinct ps.id as slip_id, ps.user_id, ps.leg_count
    from football.prediction_slips ps
    join football.predictions p on p.slip_id = ps.id
    where p.fixture_id = p_fixture_id
      and ps.slip_type = 'acca'
      and ps.status = 'pending'
  loop
    -- Check if ALL legs in this slip are now settled
    if exists (
      select 1 from football.predictions p
      where p.slip_id = v_slip.slip_id
        and p.status = 'pending'
    ) then
      continue; -- Still has unsettled legs
    end if;

    -- Check if ALL settled legs are won
    v_all_won := not exists (
      select 1 from football.predictions p
      where p.slip_id = v_slip.slip_id
        and p.status != 'won'
    );

    -- Calculate totals
    select count(*), coalesce(sum(p.fet_earned), 0)
    into v_leg_count, v_total_base_fet
    from football.predictions p
    where p.slip_id = v_slip.slip_id;

    -- Determine multiplier
    v_multiplier := case
      when v_leg_count = 2 then 1.5
      when v_leg_count = 3 then 2.0
      when v_leg_count >= 4 then 3.0
      else 1.0
    end;

    if v_all_won then
      -- Acca won — apply multiplier bonus
      v_bonus_fet := floor(v_total_base_fet * (v_multiplier - 1.0));

      update football.prediction_slips
      set status = 'won',
          total_fet_earned = floor(v_total_base_fet * v_multiplier),
          settled_at = now()
      where id = v_slip.slip_id;

      -- Credit bonus FET (individual leg credits already applied)
      if v_club_id is not null and v_bonus_fet > 0 then
        begin
          perform public.add_fan_points(
            p_user_id   := v_slip.user_id,
            p_partner_id := v_club_id::text,
            p_points    := v_bonus_fet,
            p_reason    := 'acca_bonus'
          );
        exception when others then
          raise notice 'Acca bonus FET failed for slip %: %',
            v_slip.slip_id, sqlerrm;
        end;
      end if;
    else
      -- Acca lost
      update football.prediction_slips
      set status = 'lost',
          total_fet_earned = v_total_base_fet, -- individual leg winnings stay
          settled_at = now()
      where id = v_slip.slip_id;
    end if;

    v_settled_count := v_settled_count + 1;
  end loop;

  return jsonb_build_object(
    'status', 'ok',
    'acca_slips_settled', v_settled_count
  );
end;
$$;

grant execute on function public.prediction_settle_acca_slips(uuid) to service_role;

-- ── Streak milestone FET rewards ──────────────────────────────────────────
-- Checks if a user just hit a streak milestone and awards bonus FET.
-- Call after settlement. Milestones: 3-win = 50 FET, 5-win = 150 FET,
-- 10-win = 500 FET.

create or replace function public.prediction_check_streak_reward(
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_streak integer;
  v_streak_type text;
  v_reward_fet integer := 0;
  v_milestone text;
  v_club_id bigint;
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  -- Get current streak
  select
    current_streak, streak_type
  into v_streak, v_streak_type
  from public.prediction_user_stats
  where user_id = p_user_id;

  if v_streak_type != 'won' then
    return jsonb_build_object('status', 'ok', 'streak', 0, 'reward', 0);
  end if;

  -- Check milestone (only reward exact milestone hits)
  if v_streak = 3 then
    v_reward_fet := 50;
    v_milestone := 'streak_3';
  elsif v_streak = 5 then
    v_reward_fet := 150;
    v_milestone := 'streak_5';
  elsif v_streak = 10 then
    v_reward_fet := 500;
    v_milestone := 'streak_10';
  elsif v_streak = 20 then
    v_reward_fet := 1000;
    v_milestone := 'streak_20';
  else
    return jsonb_build_object('status', 'ok', 'streak', v_streak, 'reward', 0);
  end if;

  select id into v_club_id from public.african_football_clubs limit 1;

  if v_club_id is not null then
    begin
      perform public.add_fan_points(
        p_user_id   := p_user_id,
        p_partner_id := v_club_id::text,
        p_points    := v_reward_fet,
        p_reason    := v_milestone
      );
    exception when others then
      raise notice 'Streak reward failed for user %: %', p_user_id, sqlerrm;
    end;
  end if;

  return jsonb_build_object(
    'status', 'ok',
    'streak', v_streak,
    'milestone', v_milestone,
    'reward_fet', v_reward_fet
  );
end;
$$;

grant execute on function public.prediction_check_streak_reward(uuid) to service_role;

create or replace function public.prediction_place_acca(p_selections jsonb)
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
  v_placed_ids uuid[] := array[]::uuid[];
  v_errors text[] := array[]::text[];
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

  v_multiplier := case
    when v_leg_count = 2 then 1.5
    when v_leg_count = 3 then 2.0
    when v_leg_count >= 4 then 3.0
    else 1.0
  end;

  insert into football.prediction_slips (user_id, slip_type, leg_count)
  values (v_user_id, 'acca', v_leg_count)
  returning id into v_slip_id;

  for v_selection in select * from jsonb_array_elements(p_selections)
  loop
    declare
      v_fm_id uuid := (v_selection->>'fixture_market_id')::uuid;
      v_outcome text := v_selection->>'selected_outcome';
      v_fet_value integer;
    begin
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

  if array_length(v_placed_ids, 1) is null or array_length(v_placed_ids, 1) < 2 then
    update football.prediction_slips
    set status = 'cancelled'
    where id = v_slip_id;

    return jsonb_build_object(
      'status', 'error',
      'message', 'Could not place acca - fewer than 2 valid selections.',
      'errors', to_jsonb(v_errors)
    );
  end if;

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

create or replace function public.prediction_place_jackpot_entry(
  p_round_id uuid,
  p_selections jsonb,
  p_idempotency_key text default null::text
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_round football.jackpot_rounds;
  v_leg record;
  v_existing_entries integer := 0;
  v_bonus_entries integer := 0;
  v_selection_map jsonb := '{}'::jsonb;
  v_selected_outcome text;
  v_slip_id uuid;
  v_prediction_id uuid;
  v_legs_placed integer := 0;
  v_consumed_bonus_id uuid;
begin
  perform p_idempotency_key;

  if v_user_id is null then
    return jsonb_build_object('status', 'error', 'message', 'Authentication required.');
  end if;

  select *
    into v_round
  from football.jackpot_rounds round
  where round.id = p_round_id
  limit 1;

  if v_round.id is null then
    return jsonb_build_object('status', 'error', 'message', 'Jackpot round not found.');
  end if;

  if v_round.status <> 'open' or timezone('utc', now()) >= v_round.entry_deadline_at then
    return jsonb_build_object('status', 'error', 'message', 'Jackpot entry window is closed.');
  end if;

  select count(*)
    into v_existing_entries
  from football.prediction_slips slip
  where slip.user_id = v_user_id
    and slip.jackpot_round_id = v_round.id
    and slip.slip_type = 'jackpot'
    and slip.status <> 'cancelled';

  select count(*)
    into v_bonus_entries
  from public.fet_reward_redemptions redemption
  where redemption.user_id = v_user_id
    and redemption.reward_slug = 'jackpot-extra-entry'
    and redemption.consumed_at is null
    and redemption.status in ('pending', 'processing', 'fulfilled')
    and (v_round.club_id is null or redemption.club_id = v_round.club_id);

  if v_existing_entries >= (v_round.max_entries_per_user + v_bonus_entries) then
    return jsonb_build_object('status', 'error', 'message', 'No jackpot entries remaining.');
  end if;

  select coalesce(
    jsonb_object_agg(
      selection.value ->> 'fixture_market_id',
      lower(coalesce(selection.value ->> 'selected_outcome', ''))
    ),
    '{}'::jsonb
  )
    into v_selection_map
  from jsonb_array_elements(p_selections) as selection(value);

  if jsonb_typeof(v_selection_map) <> 'object' then
    return jsonb_build_object('status', 'error', 'message', 'Selections payload is invalid.');
  end if;

  insert into football.prediction_slips (
    user_id,
    slip_type,
    status,
    leg_count,
    jackpot_round_id
  )
  values (
    v_user_id,
    'jackpot',
    'pending',
    0,
    v_round.id
  )
  returning id into v_slip_id;

  for v_leg in
    select
      leg.sort_order,
      leg.fixture_id,
      leg.fixture_market_id,
      fixture_market.outcomes
    from football.jackpot_round_legs leg
    join football.fixture_markets fixture_market
      on fixture_market.id = leg.fixture_market_id
    where leg.jackpot_round_id = v_round.id
    order by leg.sort_order asc
  loop
    v_selected_outcome := lower(coalesce(v_selection_map ->> v_leg.fixture_market_id::text, ''));

    if nullif(btrim(v_selected_outcome), '') is null then
      update football.prediction_slips
      set status = 'cancelled'
      where id = v_slip_id;

      return jsonb_build_object(
        'status', 'error',
        'message', format('Missing selection for jackpot leg %s.', v_leg.sort_order)
      );
    end if;

    if not exists (
      select 1
      from jsonb_array_elements(v_leg.outcomes) outcome
      where lower(coalesce(outcome ->> 'key', outcome ->> 'label', '')) = v_selected_outcome
         or lower(coalesce(outcome ->> 'label', outcome ->> 'key', '')) = v_selected_outcome
    ) then
      update football.prediction_slips
      set status = 'cancelled'
      where id = v_slip_id;

      return jsonb_build_object(
        'status', 'error',
        'message', format('Invalid selection for jackpot leg %s.', v_leg.sort_order)
      );
    end if;

    insert into football.predictions (
      user_id,
      fixture_id,
      fixture_market_id,
      slip_id,
      selected_outcome,
      fet_staked
    )
    values (
      v_user_id,
      v_leg.fixture_id,
      v_leg.fixture_market_id,
      v_slip_id,
      v_selected_outcome,
      0
    )
    on conflict (user_id, fixture_id, fixture_market_id) do update
      set selected_outcome = excluded.selected_outcome,
          slip_id = excluded.slip_id,
          placed_at = timezone('utc', now())
    returning id into v_prediction_id;

    perform v_prediction_id;
    v_legs_placed := v_legs_placed + 1;
  end loop;

  update football.prediction_slips
  set leg_count = v_legs_placed
  where id = v_slip_id;

  if v_existing_entries >= v_round.max_entries_per_user then
    with candidate as (
      select redemption.id
      from public.fet_reward_redemptions redemption
      where redemption.user_id = v_user_id
        and redemption.reward_slug = 'jackpot-extra-entry'
        and redemption.consumed_at is null
        and redemption.status in ('pending', 'processing', 'fulfilled')
        and (v_round.club_id is null or redemption.club_id = v_round.club_id)
      order by redemption.created_at asc
      limit 1
      for update
    )
    update public.fet_reward_redemptions redemption
    set consumed_at = timezone('utc', now()),
        status = case
          when redemption.status = 'pending' then 'fulfilled'
          else redemption.status
        end,
        metadata = redemption.metadata || jsonb_build_object(
          'jackpot_round_id', v_round.id,
          'jackpot_slip_id', v_slip_id
        ),
        updated_at = timezone('utc', now())
    from candidate
    where redemption.id = candidate.id
    returning redemption.id into v_consumed_bonus_id;
  end if;

  return jsonb_build_object(
    'status', 'placed',
    'slip_id', v_slip_id,
    'round_id', v_round.id,
    'legs_placed', v_legs_placed,
    'bonus_entry_consumed', v_consumed_bonus_id is not null,
    'message', format('%s-leg jackpot entry submitted.', v_legs_placed)
  );
end;
$$;

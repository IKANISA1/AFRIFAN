-- ─────────────────────────────────────────────
-- CORE SCORING FUNCTION
-- Computes raw_points for a player in a gameweek
-- based on the competition's scoring_rules JSONB
-- ─────────────────────────────────────────────
create or replace function fantasy.compute_player_points(
  p_stats_id uuid,
  p_position fantasy.player_position,
  p_rules jsonb
) returns integer
language plpgsql
stable
as $$
declare
  s fantasy.player_gameweek_stats;
  pts integer := 0;
  goals_pts integer := 0;
  cs_pts integer := 0;
  dc_threshold integer := 0;
  conceded_penalty integer := coalesce((p_rules ->> 'goals_conceded_per_2')::integer, -1);
  save_bonus integer := coalesce((p_rules ->> 'saves_per_3')::integer, 1);
begin
  select *
  into s
  from fantasy.player_gameweek_stats
  where id = p_stats_id;

  if not found then
    return 0;
  end if;

  if s.minutes_played > 0 and s.minutes_played < 60 then
    pts := pts + coalesce((p_rules ->> 'points_sub_60')::integer, 1);
  elsif s.minutes_played >= 60 then
    pts := pts + coalesce((p_rules ->> 'points_60_plus')::integer, 2);
  end if;

  case p_position
    when 'GK', 'DEF' then goals_pts := coalesce((p_rules -> 'goals' ->> 'GK_DEF')::integer, 10);
    when 'MID' then goals_pts := coalesce((p_rules -> 'goals' ->> 'MID')::integer, 6);
    when 'FWD' then goals_pts := coalesce((p_rules -> 'goals' ->> 'FWD')::integer, 4);
  end case;
  pts := pts + (s.goals * goals_pts);

  pts := pts + (s.assists * coalesce((p_rules ->> 'assists_all')::integer, 3));

  if s.clean_sheet and s.minutes_played >= 60 then
    case p_position
      when 'GK', 'DEF' then cs_pts := coalesce((p_rules -> 'clean_sheet' ->> 'GK_DEF')::integer, 6);
      when 'MID' then cs_pts := coalesce((p_rules -> 'clean_sheet' ->> 'MID')::integer, 1);
      else cs_pts := 0;
    end case;
    pts := pts + cs_pts;
  end if;

  if p_position in ('GK', 'DEF') and s.goals_conceded > 0 then
    pts := pts + ((floor(s.goals_conceded::numeric / 2) * conceded_penalty)::integer);
  end if;

  if p_position = 'GK' and s.saves >= 3 then
    pts := pts + (floor(s.saves::numeric / 3)::integer * save_bonus);
  end if;

  pts := pts + (s.penalties_saved * coalesce((p_rules ->> 'penalty_save')::integer, 5));
  pts := pts + (s.penalties_missed * coalesce((p_rules ->> 'penalty_miss')::integer, -2));
  pts := pts + (s.yellow_cards * coalesce((p_rules ->> 'yellow_card')::integer, -1));
  pts := pts + (s.red_cards * coalesce((p_rules ->> 'red_card')::integer, -3));
  pts := pts + (s.own_goals * coalesce((p_rules ->> 'own_goal')::integer, -2));
  pts := pts + s.bonus_points;

  case p_position
    when 'DEF', 'GK' then
      dc_threshold := coalesce((p_rules -> 'defensive_contributions' ->> 'DEF_threshold')::integer, 10);
    else
      dc_threshold := coalesce((p_rules -> 'defensive_contributions' ->> 'MID_FWD_threshold')::integer, 12);
  end case;

  if s.defensive_contributions >= dc_threshold then
    pts := pts + coalesce((p_rules -> 'defensive_contributions' ->> 'points')::integer, 2);
  end if;

  return pts;
end;
$$;

create or replace function fantasy.save_squad_selections(
  p_entry_id uuid,
  p_gameweek_id uuid,
  p_selections jsonb
) returns integer
language plpgsql
as $$
declare
  v_competition_id uuid;
  v_squad_config jsonb;
  v_budget integer;
  v_squad_size integer;
  v_starters_required integer;
  v_total integer;
  v_distinct_players integer;
  v_starters integer;
  v_captains integer;
  v_vice_captains integer;
  v_purchase_total integer;
begin
  perform fantasy.assert_entry_owner(p_entry_id);
  perform fantasy.assert_gameweek_open(p_gameweek_id);

  if jsonb_typeof(p_selections) is distinct from 'array' then
    raise exception 'Selections payload must be a JSON array.';
  end if;

  select fe.competition_id, c.squad_config
  into v_competition_id, v_squad_config
  from fantasy.fantasy_entries fe
  join fantasy.competitions c
    on c.id = fe.competition_id
  where fe.id = p_entry_id;

  if v_competition_id is null then
    raise exception 'Fantasy entry not found.';
  end if;

  select
    count(*)::integer,
    count(distinct player_id)::integer,
    count(*) filter (where is_starter)::integer,
    count(*) filter (where is_captain)::integer,
    count(*) filter (where is_vice_captain)::integer,
    coalesce(sum(purchase_price), 0)::integer
  into
    v_total,
    v_distinct_players,
    v_starters,
    v_captains,
    v_vice_captains,
    v_purchase_total
  from jsonb_to_recordset(p_selections) as payload(
    player_id integer,
    position fantasy.player_position,
    is_starter boolean,
    bench_order integer,
    is_captain boolean,
    is_vice_captain boolean,
    purchase_price integer,
    multiplier integer
  );

  v_squad_size := coalesce((v_squad_config ->> 'squad_size')::integer, 15);
  v_starters_required := coalesce((v_squad_config ->> 'starters')::integer, 11);
  v_budget := coalesce((v_squad_config ->> 'budget')::integer, 1000);

  if v_total <> v_squad_size then
    raise exception 'Expected % squad members, received %.', v_squad_size, v_total;
  end if;

  if v_distinct_players <> v_total then
    raise exception 'Duplicate players are not allowed in a fantasy squad.';
  end if;

  if v_starters <> v_starters_required then
    raise exception 'Expected % starters, received %.', v_starters_required, v_starters;
  end if;

  if v_captains <> 1 or v_vice_captains <> 1 then
    raise exception 'Exactly one captain and one vice-captain are required.';
  end if;

  if v_purchase_total > v_budget then
    raise exception 'Squad budget exceeded.';
  end if;

  if exists (
    select 1
    from (
      select bench_order, count(*) as occurrences
      from jsonb_to_recordset(p_selections) as payload(
        player_id integer,
        position fantasy.player_position,
        is_starter boolean,
        bench_order integer,
        is_captain boolean,
        is_vice_captain boolean,
        purchase_price integer,
        multiplier integer
      )
      where bench_order is not null
      group by bench_order
      having count(*) > 1
    ) duplicate_orders
  ) then
    raise exception 'Bench order values must be unique.';
  end if;

  if exists (
    with payload as (
      select *
      from jsonb_to_recordset(p_selections) as payload(
        player_id integer,
        position fantasy.player_position,
        is_starter boolean,
        bench_order integer,
        is_captain boolean,
        is_vice_captain boolean,
        purchase_price integer,
        multiplier integer
      )
    )
    select 1
    from payload
    left join fantasy.players p
      on p.external_id = payload.player_id
    where p.external_id is null or p.position is distinct from payload.position
  ) then
    raise exception 'Every selection must map to a valid player with a matching position.';
  end if;

  if exists (
    with payload as (
      select *
      from jsonb_to_recordset(p_selections) as payload(
        player_id integer,
        position fantasy.player_position,
        is_starter boolean,
        bench_order integer,
        is_captain boolean,
        is_vice_captain boolean,
        purchase_price integer,
        multiplier integer
      )
    ),
    club_counts as (
      select p.team_id, count(*) as club_count
      from payload
      join fantasy.players p
        on p.external_id = payload.player_id
      group by p.team_id
    )
    select 1
    from club_counts
    where club_count > coalesce((v_squad_config ->> 'max_per_club')::integer, 3)
  ) then
    raise exception 'Maximum players per club exceeded for this competition.';
  end if;

  if exists (
    with payload as (
      select *
      from jsonb_to_recordset(p_selections) as payload(
        player_id integer,
        position fantasy.player_position,
        is_starter boolean,
        bench_order integer,
        is_captain boolean,
        is_vice_captain boolean,
        purchase_price integer,
        multiplier integer
      )
      where is_starter = true
    )
    select 1
    from (
      select
        count(*) filter (where position = 'GK') as gk_count,
        count(*) filter (where position = 'DEF') as def_count,
        count(*) filter (where position = 'MID') as mid_count,
        count(*) filter (where position = 'FWD') as fwd_count
      from payload
    ) counts
    where gk_count <> 1
      or def_count < coalesce((v_squad_config ->> 'min_def')::integer, 3)
      or def_count > coalesce((v_squad_config ->> 'max_def')::integer, 5)
      or mid_count < coalesce((v_squad_config ->> 'min_mid')::integer, 2)
      or mid_count > coalesce((v_squad_config ->> 'max_mid')::integer, 5)
      or fwd_count < coalesce((v_squad_config ->> 'min_fwd')::integer, 1)
      or fwd_count > coalesce((v_squad_config ->> 'max_fwd')::integer, 3)
  ) then
    raise exception 'Selected starting formation is invalid.';
  end if;

  delete from fantasy.squad_selections
  where entry_id = p_entry_id
    and gameweek_id = p_gameweek_id;

  insert into fantasy.squad_selections (
    entry_id,
    gameweek_id,
    player_id,
    position,
    is_starter,
    bench_order,
    is_captain,
    is_vice_captain,
    purchase_price,
    multiplier
  )
  select
    p_entry_id,
    p_gameweek_id,
    payload.player_id,
    payload.position,
    coalesce(payload.is_starter, true),
    payload.bench_order,
    coalesce(payload.is_captain, false),
    coalesce(payload.is_vice_captain, false),
    payload.purchase_price,
    case
      when coalesce(payload.is_captain, false) then greatest(coalesce(payload.multiplier, 2), 2)
      else coalesce(payload.multiplier, 1)
    end
  from jsonb_to_recordset(p_selections) as payload(
    player_id integer,
    position fantasy.player_position,
    is_starter boolean,
    bench_order integer,
    is_captain boolean,
    is_vice_captain boolean,
    purchase_price integer,
    multiplier integer
  );

  update fantasy.fantasy_entries
  set
    team_value = v_purchase_total,
    bank_balance = greatest(v_budget - v_purchase_total, 0),
    updated_at = now()
  where id = p_entry_id;

  return v_total;
end;
$$;

-- ─────────────────────────────────────────────
-- AGGREGATE ENTRY POINTS FOR A GAMEWEEK
-- Includes vice-captain fallback and automatic substitution.
-- ─────────────────────────────────────────────
create or replace function fantasy.aggregate_entry_score(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns integer
language plpgsql
as $$
declare
  rules jsonb;
  squad_config jsonb;
  total_pts integer := 0;
  transfer_cost integer := 0;
  chip text;
  captain_mult integer;
  min_def integer;
  min_mid integer;
  min_fwd integer;
  starter_gk_count integer := 0;
  starter_def_count integer := 0;
  starter_mid_count integer := 0;
  starter_fwd_count integer := 0;
  missing_gk integer := 0;
  missing_outfield integer := 0;
  gk_bench_points integer := 0;
  gk_bench_available boolean := false;
  gk_bench_used boolean := false;
  captain_player_id integer := 0;
  vice_player_id integer := 0;
  captain_played boolean := false;
  vice_played boolean := false;
  captain_points integer := 0;
  vice_points integer := 0;
  bench_orders integer[] := '{}';
  bench_positions fantasy.player_position[] := '{}';
  bench_points integer[] := '{}';
  bench_played boolean[] := '{}';
  bench_player_ids integer[] := '{}';
  bench_count integer := 0;
  best_mask integer := 0;
  best_size integer := -1;
  best_orders integer[] := '{}';
  current_size integer;
  current_orders integer[] := '{}';
  current_def integer;
  current_mid integer;
  current_fwd integer;
  mask integer;
  idx integer;
  include_player boolean;
  rec record;
begin
  select
    c.scoring_rules,
    c.squad_config
  into
    rules,
    squad_config
  from fantasy.competitions c
  join fantasy.gameweeks gw
    on gw.competition_id = c.id
  where gw.id = p_gameweek_id;

  if rules is null then
    raise exception 'Scoring rules not found for gameweek %.', p_gameweek_id;
  end if;

  captain_mult := coalesce((rules ->> 'captain_multiplier')::integer, 2);
  min_def := coalesce((squad_config ->> 'min_def')::integer, 3);
  min_mid := coalesce((squad_config ->> 'min_mid')::integer, 2);
  min_fwd := coalesce((squad_config ->> 'min_fwd')::integer, 1);

  select chip_played, coalesce(transfer_cost, 0)
  into chip, transfer_cost
  from fantasy.entry_gameweek_scores
  where entry_id = p_entry_id
    and gameweek_id = p_gameweek_id;

  if chip = 'triple_captain' then
    captain_mult := coalesce((rules ->> 'triple_captain_multiplier')::integer, 3);
  end if;

  if chip = 'bench_boost' then
    for rec in
      select
        ss.player_id,
        ss.is_captain,
        ss.is_vice_captain,
        p.position,
        coalesce(pgs.id, null) as stats_id,
        coalesce(pgs.minutes_played, 0) as minutes_played
      from fantasy.squad_selections ss
      join fantasy.players p
        on p.external_id = ss.player_id
      left join fantasy.player_gameweek_stats pgs
        on pgs.player_id = ss.player_id
       and pgs.gameweek_id = p_gameweek_id
      where ss.entry_id = p_entry_id
        and ss.gameweek_id = p_gameweek_id
    loop
      if rec.stats_id is not null then
        total_pts := total_pts + fantasy.compute_player_points(rec.stats_id, rec.position, rules);
      end if;

      if rec.is_captain then
        captain_player_id := rec.player_id;
        captain_played := rec.minutes_played > 0;
        if rec.stats_id is not null then
          captain_points := fantasy.compute_player_points(rec.stats_id, rec.position, rules);
        end if;
      elsif rec.is_vice_captain then
        vice_player_id := rec.player_id;
        vice_played := rec.minutes_played > 0;
        if rec.stats_id is not null then
          vice_points := fantasy.compute_player_points(rec.stats_id, rec.position, rules);
        end if;
      end if;
    end loop;
  else
    for rec in
      select
        ss.player_id,
        ss.is_starter,
        ss.is_captain,
        ss.is_vice_captain,
        ss.bench_order,
        p.position,
        pgs.id as stats_id,
        coalesce(pgs.minutes_played, 0) as minutes_played
      from fantasy.squad_selections ss
      join fantasy.players p
        on p.external_id = ss.player_id
      left join fantasy.player_gameweek_stats pgs
        on pgs.player_id = ss.player_id
       and pgs.gameweek_id = p_gameweek_id
      where ss.entry_id = p_entry_id
        and ss.gameweek_id = p_gameweek_id
      order by ss.is_starter desc, ss.bench_order nulls last
    loop
      include_player := rec.stats_id is not null and rec.minutes_played > 0;

      if rec.is_captain then
        captain_player_id := rec.player_id;
        captain_played := include_player;
        if rec.stats_id is not null then
          captain_points := fantasy.compute_player_points(rec.stats_id, rec.position, rules);
        end if;
      elsif rec.is_vice_captain then
        vice_player_id := rec.player_id;
        vice_played := include_player;
        if rec.stats_id is not null then
          vice_points := fantasy.compute_player_points(rec.stats_id, rec.position, rules);
        end if;
      end if;

      if rec.is_starter then
        if include_player then
          total_pts := total_pts + fantasy.compute_player_points(rec.stats_id, rec.position, rules);
          case rec.position
            when 'GK' then starter_gk_count := starter_gk_count + 1;
            when 'DEF' then starter_def_count := starter_def_count + 1;
            when 'MID' then starter_mid_count := starter_mid_count + 1;
            when 'FWD' then starter_fwd_count := starter_fwd_count + 1;
          end case;
        else
          if rec.position = 'GK' then
            missing_gk := missing_gk + 1;
          else
            missing_outfield := missing_outfield + 1;
          end if;
        end if;
      else
        bench_count := bench_count + 1;
        bench_orders := array_append(bench_orders, coalesce(rec.bench_order, bench_count));
        bench_positions := array_append(bench_positions, rec.position);
        bench_player_ids := array_append(bench_player_ids, rec.player_id);
        bench_played := array_append(bench_played, include_player);
        if include_player and rec.stats_id is not null then
          bench_points := array_append(bench_points, fantasy.compute_player_points(rec.stats_id, rec.position, rules));
        else
          bench_points := array_append(bench_points, 0);
        end if;

        if rec.position = 'GK' and include_player then
          gk_bench_available := true;
          gk_bench_points := case
            when rec.stats_id is not null then fantasy.compute_player_points(rec.stats_id, rec.position, rules)
            else 0
          end;
        end if;
      end if;
    end loop;

    if missing_gk > 0 and gk_bench_available then
      total_pts := total_pts + gk_bench_points;
      gk_bench_used := true;
    end if;

    if missing_outfield > 0 and bench_count > 0 then
      for mask in 0..(power(2::numeric, bench_count)::integer - 1) loop
        current_size := 0;
        current_orders := '{}';
        current_def := starter_def_count;
        current_mid := starter_mid_count;
        current_fwd := starter_fwd_count;

        for idx in 1..bench_count loop
          if bench_positions[idx] = 'GK' then
            continue;
          end if;

          if ((mask >> (idx - 1)) & 1) = 1 then
            if not bench_played[idx] then
              current_size := -1;
              exit;
            end if;

            current_size := current_size + 1;
            current_orders := array_append(current_orders, bench_orders[idx]);

            case bench_positions[idx]
              when 'DEF' then current_def := current_def + 1;
              when 'MID' then current_mid := current_mid + 1;
              when 'FWD' then current_fwd := current_fwd + 1;
              else null;
            end case;
          end if;
        end loop;

        if current_size < 0 or current_size > missing_outfield then
          continue;
        end if;

        if current_def < min_def or current_mid < min_mid or current_fwd < min_fwd then
          continue;
        end if;

        if current_size > best_size
          or (current_size = best_size and (best_orders = '{}' or current_orders < best_orders)) then
          best_mask := mask;
          best_size := current_size;
          best_orders := current_orders;
        end if;
      end loop;

      if best_size > 0 then
        for idx in 1..bench_count loop
          if ((best_mask >> (idx - 1)) & 1) = 1 and bench_positions[idx] <> 'GK' then
            total_pts := total_pts + bench_points[idx];
          end if;
        end loop;
      end if;
    end if;

    if not captain_played and vice_player_id <> 0 then
      vice_played := false;
      if best_size > 0 or gk_bench_used or starter_gk_count > 0 or starter_def_count > 0 or starter_mid_count > 0 or starter_fwd_count > 0 then
        for idx in 1..bench_count loop
          if bench_player_ids[idx] = vice_player_id then
            if bench_positions[idx] = 'GK' then
              vice_played := gk_bench_used and bench_played[idx];
            else
              vice_played := ((best_mask >> (idx - 1)) & 1) = 1 and bench_played[idx];
            end if;
          end if;
        end loop;
      end if;
    end if;
  end if;

  if captain_player_id <> 0 and captain_played then
    total_pts := total_pts + (captain_points * greatest(captain_mult - 1, 0));
  elsif vice_player_id <> 0 and vice_played then
    total_pts := total_pts + (vice_points * greatest(captain_mult - 1, 0));
  end if;

  total_pts := total_pts + transfer_cost;

  insert into fantasy.entry_gameweek_scores (
    entry_id,
    gameweek_id,
    points,
    calculated_at
  )
  values (
    p_entry_id,
    p_gameweek_id,
    total_pts,
    now()
  )
  on conflict (entry_id, gameweek_id)
  do update set
    points = excluded.points,
    calculated_at = now();

  update fantasy.fantasy_entries
  set
    overall_points = (
      select coalesce(sum(points), 0)
      from fantasy.entry_gameweek_scores
      where entry_id = p_entry_id
    ),
    updated_at = now()
  where id = p_entry_id;

  return total_pts;
end;
$$;

-- ─────────────────────────────────────────────
-- RANK ENTRIES FOR A GAMEWEEK
-- ─────────────────────────────────────────────
create or replace function fantasy.rank_gameweek_entries(p_gameweek_id uuid)
returns void
language plpgsql
as $$
begin
  with ranked as (
    select
      id,
      rank() over (order by points desc, calculated_at asc nulls last, entry_id asc) as rnk,
      percent_rank() over (order by points desc, calculated_at asc nulls last, entry_id asc) * 100 as pctile
    from fantasy.entry_gameweek_scores
    where gameweek_id = p_gameweek_id
  )
  update fantasy.entry_gameweek_scores egs
  set
    rank = ranked.rnk,
    percentile = ranked.pctile
  from ranked
  where egs.id = ranked.id;

  with overall_ranked as (
    select
      egs.entry_id,
      rank() over (
        order by sum(egs.points) desc, max(egs.calculated_at) asc nulls last, egs.entry_id asc
      ) as rnk
    from fantasy.entry_gameweek_scores egs
    join fantasy.fantasy_entries fe
      on fe.id = egs.entry_id
    where fe.competition_id = (
      select competition_id
      from fantasy.gameweeks
      where id = p_gameweek_id
    )
    group by egs.entry_id
  )
  update fantasy.fantasy_entries fe
  set overall_rank = overall_ranked.rnk
  from overall_ranked
  where fe.id = overall_ranked.entry_id;
end;
$$;

-- ─────────────────────────────────────────────
-- PUBLIC RPC WRAPPERS
-- Keep RPC names stable for Flutter and Edge callers.
-- ─────────────────────────────────────────────
create or replace function public.fantasy_aggregate_entry_score(
  p_entry_id uuid,
  p_gameweek_id uuid
) returns integer
language sql
security definer
set search_path = public, fantasy
as $$
  select fantasy.aggregate_entry_score(p_entry_id, p_gameweek_id);
$$;

create or replace function public.fantasy_rank_gameweek_entries(
  p_gameweek_id uuid
) returns void
language sql
security definer
set search_path = public, fantasy
as $$
  select fantasy.rank_gameweek_entries(p_gameweek_id);
$$;

create or replace function public.fantasy_save_squad_selections(
  p_entry_id uuid,
  p_gameweek_id uuid,
  p_selections jsonb
) returns integer
language sql
security definer
set search_path = public, fantasy
as $$
  select fantasy.save_squad_selections(p_entry_id, p_gameweek_id, p_selections);
$$;

grant execute on function public.fantasy_aggregate_entry_score(uuid, uuid) to authenticated, service_role;
grant execute on function public.fantasy_rank_gameweek_entries(uuid) to authenticated, service_role;
grant execute on function public.fantasy_save_squad_selections(uuid, uuid, jsonb) to authenticated, service_role;

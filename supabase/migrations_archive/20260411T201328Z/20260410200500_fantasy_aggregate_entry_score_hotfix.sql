-- Fix ambiguous transfer_cost reference inside aggregate_entry_score.
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

  select egs.chip_played, coalesce(egs.transfer_cost, 0)
  into chip, transfer_cost
  from fantasy.entry_gameweek_scores egs
  where egs.entry_id = p_entry_id
    and egs.gameweek_id = p_gameweek_id;

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

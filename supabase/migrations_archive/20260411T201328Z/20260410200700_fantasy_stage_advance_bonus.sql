alter table fantasy.player_gameweek_stats
  add column if not exists stage_advanced boolean not null default false;

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

  if s.stage_advanced then
    pts := pts + coalesce((p_rules ->> 'stage_advance_bonus')::integer, 0);
  end if;

  return pts;
end;
$$;

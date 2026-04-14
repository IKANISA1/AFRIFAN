-- ============================================================================
-- Phase 2: Settlement → FET wallet credit pipeline
-- Enhances prediction_settle_fixture to credit winning users' FET wallets
-- via the existing add_fan_points() pipeline (wallet ledger + xp_events).
-- ============================================================================

-- Replace the settlement function with FET wallet integration
create or replace function public.prediction_settle_fixture(
  p_fixture_id uuid,
  p_settlements jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_settlement jsonb;
  v_market_slug text;
  v_correct_outcome text;
  v_market_id uuid;
  v_fm_id uuid;
  v_fet_value integer;
  v_won_count integer := 0;
  v_lost_count integer := 0;
  v_total_awarded integer := 0;
  v_pred record;
  v_club_id bigint;
  v_total_won integer := 0;
  v_total_lost integer := 0;
  v_markets_processed integer := 0;
begin
  -- Verify caller is service_role
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  -- Resolve club context from the fixture teams.
  -- The football catalog links teams back to african_football_clubs via
  -- source_club_id, which is the only club mapping guaranteed in this repo.
  select coalesce(home_team.source_club_id, away_team.source_club_id)
    into v_club_id
  from football.fixtures f
  join football.teams home_team on home_team.id = f.home_team_id
  join football.teams away_team on away_team.id = f.away_team_id
  where f.id = p_fixture_id
  limit 1;

  -- Fallback: use the first club in the system (single-tenant assumption)
  if v_club_id is null then
    select id into v_club_id from public.african_football_clubs limit 1;
  end if;

  -- Process each market settlement
  for v_settlement in select * from jsonb_array_elements(p_settlements)
  loop
    v_market_slug := v_settlement->>'market_slug';
    v_correct_outcome := v_settlement->>'correct_outcome';
    v_won_count := 0;
    v_lost_count := 0;

    -- Find the market and fixture_market
    select pm.id, fm.id, coalesce(fm.fet_value_override, pm.default_fet_value)
    into v_market_id, v_fm_id, v_fet_value
    from football.fixture_markets fm
    join football.prediction_markets pm on pm.id = fm.market_id
    where fm.fixture_id = p_fixture_id
      and pm.slug = v_market_slug;

    if v_market_id is null then
      continue;
    end if;

    -- Lock the market
    update football.fixture_markets
    set is_locked = true, locked_at = now()
    where id = v_fm_id;

    -- Settle winning predictions
    update football.predictions
    set status = 'won',
        fet_earned = v_fet_value,
        settled_at = now()
    where fixture_market_id = v_fm_id
      and status = 'pending'
      and lower(selected_outcome) = lower(v_correct_outcome);

    get diagnostics v_won_count = row_count;

    -- Settle losing predictions
    update football.predictions
    set status = 'lost',
        fet_earned = 0,
        settled_at = now()
    where fixture_market_id = v_fm_id
      and status = 'pending'
      and lower(selected_outcome) != lower(v_correct_outcome);

    get diagnostics v_lost_count = row_count;

    -- ══ FET WALLET CREDIT for winners ══
    -- Credit each winning user's FET wallet via add_fan_points
    if v_club_id is not null and v_won_count > 0 then
      for v_pred in
        select p.user_id, p.id as prediction_id
        from football.predictions p
        where p.fixture_market_id = v_fm_id
          and p.status = 'won'
          and p.settled_at >= now() - interval '5 seconds'
      loop
        begin
          perform public.add_fan_points(
            p_user_id   := v_pred.user_id,
            p_partner_id := v_club_id::text,
            p_points    := v_fet_value,
            p_reason    := 'prediction_win'
          );
        exception when others then
          -- Log but don't fail the entire settlement if one user credit fails
          raise notice 'FET credit failed for user % prediction %: %',
            v_pred.user_id, v_pred.prediction_id, sqlerrm;
        end;
      end loop;
    end if;

    v_total_awarded := v_total_awarded + (v_won_count * v_fet_value);
    v_total_won := v_total_won + v_won_count;
    v_total_lost := v_total_lost + v_lost_count;
    v_markets_processed := v_markets_processed + 1;

    -- Record settlement
    insert into football.prediction_settlements (
      fixture_id, market_id, correct_outcome,
      predictions_won, predictions_lost, total_fet_awarded
    )
    values (
      p_fixture_id, v_market_id, v_correct_outcome,
      v_won_count, v_lost_count, v_won_count * v_fet_value
    )
    on conflict (fixture_id, market_id) do update
    set correct_outcome = excluded.correct_outcome,
        predictions_won = excluded.predictions_won,
        predictions_lost = excluded.predictions_lost,
        total_fet_awarded = excluded.total_fet_awarded,
        settled_at = now();
  end loop;

  -- Update slip statuses for settled predictions
  update football.prediction_slips ps
  set status = case
    when ps.slip_type = 'single' then
      (select p.status from football.predictions p where p.slip_id = ps.id limit 1)
    else ps.status
  end,
  total_fet_earned = (
    select coalesce(sum(p.fet_earned), 0)
    from football.predictions p
    where p.slip_id = ps.id
  ),
  settled_at = now()
  where ps.id in (
    select distinct p.slip_id
    from football.predictions p
    where p.fixture_id = p_fixture_id
      and p.slip_id is not null
      and p.status in ('won', 'lost')
  );

  return jsonb_build_object(
    'status', 'settled',
    'fixture_id', p_fixture_id,
    'markets_processed', v_markets_processed,
    'total_won', v_total_won,
    'total_lost', v_total_lost,
    'total_fet_awarded', v_total_awarded
  );
end;
$$;

-- ── Auto-lock trigger: lock markets at kickoff ────────────────────────────

create or replace function football.auto_lock_fixture_markets()
returns trigger
language plpgsql
security definer
as $$
begin
  -- When a fixture transitions to 'live' or 'finished', lock all its markets
  if new.status in ('live', 'finished') and old.status = 'scheduled' then
    update football.fixture_markets
    set is_locked = true, locked_at = now()
    where fixture_id = new.id
      and is_locked = false;
  end if;

  return new;
end;
$$;

drop trigger if exists trigger_auto_lock_markets on football.fixtures;
create trigger trigger_auto_lock_markets
  after update of status on football.fixtures
  for each row
  when (new.status is distinct from old.status)
  execute function football.auto_lock_fixture_markets();

-- ── User prediction stats view ────────────────────────────────────────────

create or replace view public.prediction_user_stats
with (security_invoker = true) as
select
  p.user_id,
  count(*) filter (where p.status in ('won', 'lost')) as total_predictions,
  count(*) filter (where p.status = 'won') as total_won,
  count(*) filter (where p.status = 'lost') as total_lost,
  count(*) filter (where p.status = 'pending') as total_pending,
  coalesce(sum(p.fet_earned), 0) as total_fet_earned,
  case
    when count(*) filter (where p.status in ('won', 'lost')) > 0 then
      round(
        count(*) filter (where p.status = 'won')::numeric /
        count(*) filter (where p.status in ('won', 'lost'))::numeric * 100, 1
      )
    else 0
  end as win_rate,
  -- Current streak
  (
    select count(*)
    from (
      select p2.status,
             row_number() over (order by p2.settled_at desc) as rn
      from football.predictions p2
      where p2.user_id = p.user_id
        and p2.status in ('won', 'lost')
    ) streak
    where streak.status = (
      select p3.status
      from football.predictions p3
      where p3.user_id = p.user_id
        and p3.status in ('won', 'lost')
      order by p3.settled_at desc
      limit 1
    )
    and streak.rn <= 50
  ) as current_streak,
  (
    select p4.status
    from football.predictions p4
    where p4.user_id = p.user_id
      and p4.status in ('won', 'lost')
    order by p4.settled_at desc
    limit 1
  ) as streak_type
from football.predictions p
group by p.user_id;

grant select on public.prediction_user_stats to authenticated;

-- ── Prediction leaderboard view ───────────────────────────────────────────

create or replace view public.prediction_leaderboard
with (security_invoker = true) as
select
  p.user_id,
  coalesce(pr.display_name, pr.full_name, u.public_user_id, 'Supporter') as display_name,
  count(*) filter (where p.status = 'won') as wins,
  count(*) filter (where p.status in ('won', 'lost')) as total_settled,
  coalesce(sum(p.fet_earned), 0) as total_fet_earned,
  case
    when count(*) filter (where p.status in ('won', 'lost')) > 0 then
      round(
        count(*) filter (where p.status = 'won')::numeric /
        count(*) filter (where p.status in ('won', 'lost'))::numeric * 100, 1
      )
    else 0
  end as win_rate
from football.predictions p
join public.profiles pr on pr.id = p.user_id
left join public.users u on u.id = p.user_id
where p.status in ('won', 'lost')
group by p.user_id, pr.display_name, pr.full_name, u.public_user_id
order by total_fet_earned desc, wins desc;

grant select on public.prediction_leaderboard to anon, authenticated;

-- ── RPC: Get user prediction stats ────────────────────────────────────────

create or replace function public.prediction_get_user_stats()
returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_stats record;
begin
  if v_user_id is null then
    return jsonb_build_object(
      'total_predictions', 0,
      'total_won', 0,
      'total_lost', 0,
      'total_pending', 0,
      'total_fet_earned', 0,
      'win_rate', 0,
      'current_streak', 0,
      'streak_type', null
    );
  end if;

  select * into v_stats
  from public.prediction_user_stats
  where user_id = v_user_id;

  if v_stats is null then
    return jsonb_build_object(
      'total_predictions', 0,
      'total_won', 0,
      'total_lost', 0,
      'total_pending', 0,
      'total_fet_earned', 0,
      'win_rate', 0,
      'current_streak', 0,
      'streak_type', null
    );
  end if;

  return jsonb_build_object(
    'total_predictions', v_stats.total_predictions,
    'total_won', v_stats.total_won,
    'total_lost', v_stats.total_lost,
    'total_pending', v_stats.total_pending,
    'total_fet_earned', v_stats.total_fet_earned,
    'win_rate', v_stats.win_rate,
    'current_streak', v_stats.current_streak,
    'streak_type', v_stats.streak_type
  );
end;
$$;

grant execute on function public.prediction_get_user_stats() to authenticated;

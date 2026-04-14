-- ============================================================================
-- Phase 3: Prediction runtime hardening
-- - Seeds fixture markets automatically for published fixtures
-- - Adds idempotent FET crediting for prediction wins
-- - Exposes dashboard/detail RPCs used by mobile prediction screens
-- - Tightens market lock state returned to the client around kickoff/live
-- ============================================================================

-- ── 1. Helpers ──────────────────────────────────────────────────────────────

create or replace function football.prediction_fixture_club_id(
  p_fixture_id uuid
) returns bigint
language sql
stable
as $$
  select coalesce(home_team.source_club_id, away_team.source_club_id, fallback.id)
  from football.fixtures fixture
  join football.teams home_team on home_team.id = fixture.home_team_id
  join football.teams away_team on away_team.id = fixture.away_team_id
  cross join lateral (
    select club.id
    from public.african_football_clubs club
    order by club.id
    limit 1
  ) fallback
  where fixture.id = p_fixture_id
  limit 1;
$$;

create or replace function football.prediction_seed_outcomes(
  p_market_slug text,
  p_outcome_template jsonb
) returns jsonb
language plpgsql
immutable
as $$
begin
  if jsonb_typeof(p_outcome_template) = 'array'
     and jsonb_array_length(p_outcome_template) > 0 then
    return p_outcome_template;
  end if;

  return case lower(coalesce(p_market_slug, ''))
    when 'correct-score' then
      '[
        {"key":"0-0","label":"0-0"},
        {"key":"1-0","label":"1-0"},
        {"key":"1-1","label":"1-1"},
        {"key":"2-0","label":"2-0"},
        {"key":"2-1","label":"2-1"},
        {"key":"2-2","label":"2-2"},
        {"key":"0-1","label":"0-1"},
        {"key":"0-2","label":"0-2"},
        {"key":"1-2","label":"1-2"},
        {"key":"3-1","label":"3-1"},
        {"key":"1-3","label":"1-3"},
        {"key":"other","label":"Other"}
      ]'::jsonb
    else '[]'::jsonb
  end;
end;
$$;

create or replace function football.seed_fixture_prediction_markets(
  p_fixture_id uuid,
  p_force boolean default false
) returns integer
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_seeded integer := 0;
begin
  with fixture_state as (
    select
      fixture.id,
      fixture.kickoff_at,
      fixture.status,
      (
        fixture.status in ('live', 'finished')
        or (fixture.kickoff_at is not null and fixture.kickoff_at <= now())
      ) as is_locked_now
    from football.fixtures fixture
    where fixture.id = p_fixture_id
  ),
  seed_rows as (
    select
      fs.id as fixture_id,
      market.id as market_id,
      football.prediction_seed_outcomes(
        market.slug,
        market.outcome_template
      ) as outcomes,
      fs.is_locked_now as is_locked,
      case when fs.is_locked_now then coalesce(fs.kickoff_at, now()) end as locked_at
    from fixture_state fs
    join football.prediction_markets market on market.is_active = true
    where jsonb_array_length(
      football.prediction_seed_outcomes(market.slug, market.outcome_template)
    ) > 0
  ),
  upserted as (
    insert into football.fixture_markets (
      fixture_id,
      market_id,
      outcomes,
      is_locked,
      locked_at
    )
    select
      fixture_id,
      market_id,
      outcomes,
      is_locked,
      locked_at
    from seed_rows
    on conflict (fixture_id, market_id) do update
      set outcomes = case
            when p_force then excluded.outcomes
            else football.fixture_markets.outcomes
          end,
          is_locked = excluded.is_locked,
          locked_at = excluded.locked_at,
          updated_at = now()
    returning 1
  )
  select count(*) into v_seeded
  from upserted;

  return coalesce(v_seeded, 0);
end;
$$;

create or replace function football.seed_fixture_prediction_markets_trigger()
returns trigger
language plpgsql
security definer
set search_path = public, football
as $$
begin
  perform football.seed_fixture_prediction_markets(new.id);
  return new;
end;
$$;

drop trigger if exists trigger_seed_prediction_markets on football.fixtures;
create trigger trigger_seed_prediction_markets
  after insert on football.fixtures
  for each row
  execute function football.seed_fixture_prediction_markets_trigger();

create or replace function football.award_prediction_fet(
  p_prediction_id uuid,
  p_user_id uuid,
  p_club_id bigint,
  p_amount integer,
  p_fixture_id uuid,
  p_market_slug text
) returns boolean
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_membership public.fan_memberships;
  v_existing public.fet_wallet_ledger_entries;
  v_points integer := greatest(coalesce(p_amount, 0), 0);
  v_idempotency_key text := 'prediction-win:' || p_prediction_id::text;
begin
  if p_prediction_id is null or p_user_id is null or p_club_id is null or v_points <= 0 then
    return false;
  end if;

  select entry.*
    into v_existing
  from public.fet_wallet_ledger_entries entry
  where entry.club_id = p_club_id
    and entry.user_id = p_user_id
    and entry.idempotency_key = v_idempotency_key
  order by entry.created_at desc, entry.id desc
  limit 1;

  if v_existing.id is not null then
    return false;
  end if;

  insert into public.fan_memberships (
    user_id,
    club_id,
    partner_id,
    points,
    tier
  )
  values (
    p_user_id,
    p_club_id,
    public.fet_wallet_resolve_partner_id(p_club_id, p_club_id::text),
    v_points,
    public.resolve_fan_tier(v_points)
  )
  on conflict (user_id, club_id)
  do update set
    points = public.fan_memberships.points + v_points,
    tier = public.resolve_fan_tier(public.fan_memberships.points + v_points),
    renewed_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  returning * into v_membership;

  insert into public.xp_events (
    user_id,
    club_id,
    event_type,
    xp_awarded,
    metadata,
    event_at
  )
  select
    p_user_id,
    p_club_id,
    'prediction_win',
    v_points,
    jsonb_build_object(
      'prediction_id', p_prediction_id,
      'fixture_id', p_fixture_id,
      'market_slug', p_market_slug,
      'source', 'prediction_settlement'
    ),
    timezone('utc', now())
  where not exists (
    select 1
    from public.xp_events event
    where event.user_id = p_user_id
      and event.event_type = 'prediction_win'
      and event.metadata ->> 'prediction_id' = p_prediction_id::text
  );

  perform public.fet_wallet_append_entry(
    p_club_id := p_club_id,
    p_user_id := p_user_id,
    p_membership_id := v_membership.id,
    p_entry_type := 'earn',
    p_direction := 'credit',
    p_amount := v_points,
    p_balance_after := v_membership.points,
    p_counterparty_user_id := null,
    p_reference_type := 'prediction',
    p_reference_id := p_prediction_id::text,
    p_idempotency_key := v_idempotency_key,
    p_note := 'prediction_win',
    p_metadata := jsonb_build_object(
      'prediction_id', p_prediction_id,
      'fixture_id', p_fixture_id,
      'market_slug', p_market_slug,
      'source', 'prediction_settlement'
    ),
    p_created_by := auth.uid()
  );

  return true;
end;
$$;

-- ── 2. Backfill existing fixtures with markets ─────────────────────────────

do $$
declare
  fixture_row record;
begin
  for fixture_row in
    select fixture.id
    from football.fixtures fixture
  loop
    perform football.seed_fixture_prediction_markets(fixture_row.id);
  end loop;
end;
$$;

-- ── 3. RPC hardening ───────────────────────────────────────────────────────

create or replace function public.prediction_get_fixture_markets(
  p_fixture_id uuid
) returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_rows jsonb;
begin
  select coalesce(jsonb_agg(row_data order by sort_order), '[]'::jsonb)
    into v_rows
  from (
    select
      jsonb_build_object(
        'fixture_market_id', fm.id,
        'market_id', pm.id,
        'market_slug', pm.slug,
        'market_name', pm.name,
        'market_short_name', pm.short_name,
        'market_group', pm.market_group,
        'difficulty_tier', pm.difficulty_tier,
        'description', pm.description,
        'fet_value', coalesce(fm.fet_value_override, pm.default_fet_value),
        'outcomes', fm.outcomes,
        'is_locked',
          fm.is_locked
          or f.status in ('live', 'finished')
          or (f.kickoff_at is not null and f.kickoff_at <= now()),
        'user_prediction', (
          select jsonb_build_object(
            'prediction_id', up.id,
            'selected_outcome', up.selected_outcome,
            'status', up.status
          )
          from football.predictions up
          where up.fixture_market_id = fm.id
            and up.user_id = v_user_id
            and up.status in ('pending', 'won', 'lost', 'void')
          limit 1
        )
      ) as row_data,
      pm.sort_order
    from football.fixture_markets fm
    join football.prediction_markets pm on pm.id = fm.market_id
    join football.fixtures f on f.id = fm.fixture_id
    where fm.fixture_id = p_fixture_id
      and pm.is_active = true
      and jsonb_array_length(fm.outcomes) > 0
    order by pm.sort_order
  ) sub;

  return v_rows;
end;
$$;

create or replace function public.prediction_get_dashboard()
returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_active_count integer := 0;
  v_settled_count integer := 0;
  v_won_count integer := 0;
  v_lost_count integer := 0;
  v_total_fet integer := 0;
  v_current_streak integer := 0;
  v_win_rate numeric := 0;
begin
  if v_user_id is null then
    return jsonb_build_object(
      'active_count', 0,
      'settled_count', 0,
      'won_count', 0,
      'lost_count', 0,
      'total_fet_earned', 0,
      'current_streak', 0,
      'win_rate', 0
    );
  end if;

  select count(*)
    into v_active_count
  from football.predictions prediction
  where prediction.user_id = v_user_id
    and prediction.status = 'pending';

  select
    count(*) filter (where prediction.status in ('won', 'lost', 'void')),
    count(*) filter (where prediction.status = 'won'),
    count(*) filter (where prediction.status = 'lost'),
    coalesce(sum(prediction.fet_earned), 0)
    into v_settled_count,
         v_won_count,
         v_lost_count,
         v_total_fet
  from football.predictions prediction
  where prediction.user_id = v_user_id;

  select
    coalesce(stats.current_streak, 0),
    coalesce(stats.win_rate, 0)
    into v_current_streak,
         v_win_rate
  from public.prediction_user_stats stats
  where stats.user_id = v_user_id;

  return jsonb_build_object(
    'active_count', coalesce(v_active_count, 0),
    'settled_count', coalesce(v_settled_count, 0),
    'won_count', coalesce(v_won_count, 0),
    'lost_count', coalesce(v_lost_count, 0),
    'total_fet_earned', coalesce(v_total_fet, 0),
    'current_streak', coalesce(v_current_streak, 0),
    'win_rate', coalesce(v_win_rate, 0)
  );
end;
$$;

create or replace function public.prediction_get_detail(
  p_prediction_id uuid
) returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_row jsonb;
begin
  if v_user_id is null then
    return null;
  end if;

  select jsonb_build_object(
      'id', prediction.id,
      'slip_id', prediction.slip_id,
      'fixture_id', prediction.fixture_id,
      'market_slug', market.slug,
      'market_name', market.name,
      'market_short_name', market.short_name,
      'market_group', market.market_group,
      'difficulty_tier', market.difficulty_tier,
      'competition_name', competition.short_name,
      'home_team', home_team.name,
      'home_team_short', home_team.short_name,
      'away_team', away_team.name,
      'away_team_short', away_team.short_name,
      'venue_name', fixture.venue_name,
      'kickoff_at', fixture.kickoff_at,
      'fixture_status', fixture.status,
      'home_score', fixture.home_score,
      'away_score', fixture.away_score,
      'selected_outcome', prediction.selected_outcome,
      'correct_outcome', settlement.correct_outcome,
      'status', prediction.status,
      'fet_potential', coalesce(fixture_market.fet_value_override, market.default_fet_value),
      'fet_earned', prediction.fet_earned,
      'placed_at', prediction.placed_at,
      'settled_at', prediction.settled_at
    )
    into v_row
  from football.predictions prediction
  join football.fixture_markets fixture_market on fixture_market.id = prediction.fixture_market_id
  join football.prediction_markets market on market.id = fixture_market.market_id
  join football.fixtures fixture on fixture.id = prediction.fixture_id
  join football.teams home_team on home_team.id = fixture.home_team_id
  join football.teams away_team on away_team.id = fixture.away_team_id
  join football.competitions competition on competition.id = fixture.competition_id
  left join football.prediction_settlements settlement
    on settlement.fixture_id = prediction.fixture_id
   and settlement.market_id = market.id
  where prediction.id = p_prediction_id
    and prediction.user_id = v_user_id
  limit 1;

  return v_row;
end;
$$;

create or replace function public.prediction_settle_fixture(
  p_fixture_id uuid,
  p_settlements jsonb
) returns jsonb
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
  v_total_won integer := 0;
  v_total_lost integer := 0;
  v_markets_processed integer := 0;
  v_club_id bigint;
  v_pred record;
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  v_club_id := football.prediction_fixture_club_id(p_fixture_id);

  for v_settlement in
    select * from jsonb_array_elements(p_settlements)
  loop
    v_market_slug := lower(coalesce(v_settlement ->> 'market_slug', ''));
    v_correct_outcome := coalesce(v_settlement ->> 'correct_outcome', '');
    v_won_count := 0;
    v_lost_count := 0;

    select
      market.id,
      fixture_market.id,
      coalesce(fixture_market.fet_value_override, market.default_fet_value)
      into v_market_id, v_fm_id, v_fet_value
    from football.fixture_markets fixture_market
    join football.prediction_markets market on market.id = fixture_market.market_id
    where fixture_market.fixture_id = p_fixture_id
      and lower(market.slug) = v_market_slug
    limit 1;

    if v_market_id is null or v_fm_id is null then
      continue;
    end if;

    update football.fixture_markets
    set is_locked = true,
        locked_at = coalesce(locked_at, now()),
        updated_at = now()
    where id = v_fm_id;

    update football.predictions
    set status = case
          when lower(selected_outcome) = lower(v_correct_outcome) then 'won'
          else 'lost'
        end,
        fet_earned = case
          when lower(selected_outcome) = lower(v_correct_outcome) then v_fet_value
          else 0
        end,
        settled_at = now()
    where fixture_market_id = v_fm_id
      and status in ('pending', 'won', 'lost', 'void');

    select count(*) filter (where prediction.status = 'won'),
           count(*) filter (where prediction.status = 'lost')
      into v_won_count, v_lost_count
    from football.predictions prediction
    where prediction.fixture_market_id = v_fm_id
      and prediction.status in ('won', 'lost');

    if v_club_id is not null and v_won_count > 0 then
      for v_pred in
        select prediction.id, prediction.user_id
        from football.predictions prediction
        where prediction.fixture_market_id = v_fm_id
          and prediction.status = 'won'
      loop
        perform football.award_prediction_fet(
          p_prediction_id := v_pred.id,
          p_user_id := v_pred.user_id,
          p_club_id := v_club_id,
          p_amount := v_fet_value,
          p_fixture_id := p_fixture_id,
          p_market_slug := v_market_slug
        );
      end loop;
    end if;

    insert into football.prediction_settlements (
      fixture_id,
      market_id,
      correct_outcome,
      predictions_won,
      predictions_lost,
      total_fet_awarded,
      settled_at,
      metadata
    )
    values (
      p_fixture_id,
      v_market_id,
      v_correct_outcome,
      v_won_count,
      v_lost_count,
      v_won_count * v_fet_value,
      now(),
      jsonb_build_object('club_id', v_club_id)
    )
    on conflict (fixture_id, market_id) do update
      set correct_outcome = excluded.correct_outcome,
          predictions_won = excluded.predictions_won,
          predictions_lost = excluded.predictions_lost,
          total_fet_awarded = excluded.total_fet_awarded,
          settled_at = excluded.settled_at,
          metadata = excluded.metadata;

    v_total_awarded := v_total_awarded + (v_won_count * v_fet_value);
    v_total_won := v_total_won + v_won_count;
    v_total_lost := v_total_lost + v_lost_count;
    v_markets_processed := v_markets_processed + 1;
  end loop;

  update football.prediction_slips slip
  set status = case
        when exists (
          select 1
          from football.predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'pending'
        ) then 'pending'
        when exists (
          select 1
          from football.predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'won'
        ) then 'won'
        when exists (
          select 1
          from football.predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'lost'
        ) then 'lost'
        else slip.status
      end,
      total_fet_earned = (
        select coalesce(sum(prediction.fet_earned), 0)
        from football.predictions prediction
        where prediction.slip_id = slip.id
      ),
      settled_at = case
        when exists (
          select 1
          from football.predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'pending'
        ) then null
        else now()
      end
  where slip.id in (
    select distinct prediction.slip_id
    from football.predictions prediction
    where prediction.fixture_id = p_fixture_id
      and prediction.slip_id is not null
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

grant execute on function public.prediction_get_dashboard() to authenticated;
grant execute on function public.prediction_get_detail(uuid) to authenticated;


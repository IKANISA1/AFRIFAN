-- ============================================================================
-- Prediction Engine — database schema, RLS, and RPCs
-- Builds on the existing football.* schema (competitions, fixtures, teams).
-- Integrates with FET wallet ledger for settlement payouts.
-- ============================================================================

-- ── 1. Prediction Markets Catalog ──────────────────────────────────────────

create table if not exists football.prediction_markets (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  short_name text not null,
  market_group text not null default 'match_result',
  difficulty_tier text not null default 'entry',
  default_fet_value integer not null default 100,
  description text not null default '',
  outcome_template jsonb not null default '[]'::jsonb,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint ck_prediction_markets_group
    check (market_group in ('match_result', 'goals', 'scorers', 'specials')),
  constraint ck_prediction_markets_difficulty
    check (difficulty_tier in ('entry', 'mid', 'hard', 'advanced'))
);

create index if not exists idx_prediction_markets_group_sort
  on football.prediction_markets (market_group, sort_order)
  where is_active = true;

-- ── 2. Fixture Markets (markets available per fixture) ─────────────────────

create table if not exists football.fixture_markets (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  market_id uuid not null references football.prediction_markets(id) on delete cascade,
  outcomes jsonb not null default '[]'::jsonb,
  fet_value_override integer,
  is_locked boolean not null default false,
  locked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (fixture_id, market_id)
);

create index if not exists idx_fixture_markets_fixture
  on football.fixture_markets (fixture_id)
  where is_locked = false;

-- ── 3. Prediction Slips (grouping container for singles + accas) ──────────

create table if not exists football.prediction_slips (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  slip_type text not null default 'single',
  status text not null default 'pending',
  leg_count integer not null default 1,
  total_fet_earned integer not null default 0,
  created_at timestamptz not null default now(),
  settled_at timestamptz,

  constraint ck_prediction_slips_type
    check (slip_type in ('single', 'acca')),
  constraint ck_prediction_slips_status
    check (status in ('pending', 'won', 'lost', 'partial', 'cancelled', 'void'))
);

create index if not exists idx_prediction_slips_user_status
  on football.prediction_slips (user_id, status, created_at desc);

-- ── 4. Predictions (individual user predictions) ──────────────────────────

create table if not exists football.predictions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid(),
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  fixture_market_id uuid not null references football.fixture_markets(id) on delete cascade,
  slip_id uuid references football.prediction_slips(id) on delete set null,
  selected_outcome text not null,
  status text not null default 'pending',
  fet_staked integer not null default 0,
  fet_earned integer not null default 0,
  placed_at timestamptz not null default now(),
  settled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,

  constraint ck_predictions_status
    check (status in ('pending', 'won', 'lost', 'cancelled', 'void')),
  unique (user_id, fixture_id, fixture_market_id)
);

create index if not exists idx_predictions_user_status
  on football.predictions (user_id, status, placed_at desc);

create index if not exists idx_predictions_fixture
  on football.predictions (fixture_id, status);

create index if not exists idx_predictions_slip
  on football.predictions (slip_id)
  where slip_id is not null;

-- ── 5. Prediction Settlements (audit trail per fixture+market) ────────────

create table if not exists football.prediction_settlements (
  id uuid primary key default gen_random_uuid(),
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  market_id uuid not null references football.prediction_markets(id) on delete cascade,
  correct_outcome text not null,
  settled_by text not null default 'system',
  predictions_won integer not null default 0,
  predictions_lost integer not null default 0,
  total_fet_awarded integer not null default 0,
  settled_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,

  unique (fixture_id, market_id)
);

-- ── 6. Auto-update timestamps ─────────────────────────────────────────────

drop trigger if exists prediction_markets_set_updated_at on football.prediction_markets;
create trigger prediction_markets_set_updated_at
  before update on football.prediction_markets
  for each row execute function public.set_updated_at();

drop trigger if exists fixture_markets_set_updated_at on football.fixture_markets;
create trigger fixture_markets_set_updated_at
  before update on football.fixture_markets
  for each row execute function public.set_updated_at();

-- ── 7. RLS Policies ──────────────────────────────────────────────────────

alter table football.prediction_markets enable row level security;
alter table football.fixture_markets enable row level security;
alter table football.prediction_slips enable row level security;
alter table football.predictions enable row level security;
alter table football.prediction_settlements enable row level security;

-- prediction_markets: public read, service_role write
drop policy if exists "prediction_markets_public_read" on football.prediction_markets;
create policy "prediction_markets_public_read"
  on football.prediction_markets for select using (true);

drop policy if exists "prediction_markets_service_write" on football.prediction_markets;
create policy "prediction_markets_service_write"
  on football.prediction_markets for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- fixture_markets: public read, service_role write
drop policy if exists "fixture_markets_public_read" on football.fixture_markets;
create policy "fixture_markets_public_read"
  on football.fixture_markets for select using (true);

drop policy if exists "fixture_markets_service_write" on football.fixture_markets;
create policy "fixture_markets_service_write"
  on football.fixture_markets for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- prediction_slips: user reads/writes own, service_role full access
drop policy if exists "prediction_slips_owner_read" on football.prediction_slips;
create policy "prediction_slips_owner_read"
  on football.prediction_slips for select
  using (auth.uid() = user_id);

drop policy if exists "prediction_slips_owner_insert" on football.prediction_slips;
create policy "prediction_slips_owner_insert"
  on football.prediction_slips for insert
  with check (auth.uid() = user_id);

drop policy if exists "prediction_slips_service_all" on football.prediction_slips;
create policy "prediction_slips_service_all"
  on football.prediction_slips for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- predictions: user reads/writes own, service_role full access
drop policy if exists "predictions_owner_read" on football.predictions;
create policy "predictions_owner_read"
  on football.predictions for select
  using (auth.uid() = user_id);

drop policy if exists "predictions_owner_insert" on football.predictions;
create policy "predictions_owner_insert"
  on football.predictions for insert
  with check (auth.uid() = user_id);

drop policy if exists "predictions_owner_update" on football.predictions;
create policy "predictions_owner_update"
  on football.predictions for update
  using (auth.uid() = user_id and status = 'pending')
  with check (auth.uid() = user_id);

drop policy if exists "predictions_service_all" on football.predictions;
create policy "predictions_service_all"
  on football.predictions for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- prediction_settlements: public read (transparency), service_role write
drop policy if exists "prediction_settlements_public_read" on football.prediction_settlements;
create policy "prediction_settlements_public_read"
  on football.prediction_settlements for select using (true);

drop policy if exists "prediction_settlements_service_write" on football.prediction_settlements;
create policy "prediction_settlements_service_write"
  on football.prediction_settlements for all
  using (auth.role() = 'service_role')
  with check (auth.role() = 'service_role');

-- ── 8. Grants ─────────────────────────────────────────────────────────────

grant select on football.prediction_markets to anon, authenticated;
grant select on football.fixture_markets to anon, authenticated;
grant select, insert on football.prediction_slips to authenticated;
grant select, insert, update on football.predictions to authenticated;
grant select on football.prediction_settlements to anon, authenticated;

grant all on football.prediction_markets to service_role;
grant all on football.fixture_markets to service_role;
grant all on football.prediction_slips to service_role;
grant all on football.predictions to service_role;
grant all on football.prediction_settlements to service_role;

-- ── 9. Seed MVP Markets ───────────────────────────────────────────────────

insert into football.prediction_markets (slug, name, short_name, market_group, difficulty_tier, default_fet_value, description, outcome_template, sort_order)
values
  (
    '1x2',
    'Match Result',
    '1X2',
    'match_result',
    'entry',
    100,
    'Predict the match result: Home Win, Draw, or Away Win.',
    '[{"key": "home", "label": "Home Win"}, {"key": "draw", "label": "Draw"}, {"key": "away", "label": "Away Win"}]'::jsonb,
    10
  ),
  (
    'btts',
    'Both Teams to Score',
    'BTTS',
    'goals',
    'entry',
    100,
    'Predict whether both teams will score during the match.',
    '[{"key": "yes", "label": "Yes"}, {"key": "no", "label": "No"}]'::jsonb,
    20
  ),
  (
    'over-under-1-5',
    'Over/Under 1.5 Goals',
    'O/U 1.5',
    'goals',
    'entry',
    100,
    'Predict whether the total goals will be over or under 1.5.',
    '[{"key": "over", "label": "Over 1.5"}, {"key": "under", "label": "Under 1.5"}]'::jsonb,
    30
  ),
  (
    'over-under-2-5',
    'Over/Under 2.5 Goals',
    'O/U 2.5',
    'goals',
    'entry',
    100,
    'Predict whether the total goals will be over or under 2.5.',
    '[{"key": "over", "label": "Over 2.5"}, {"key": "under", "label": "Under 2.5"}]'::jsonb,
    40
  ),
  (
    'over-under-3-5',
    'Over/Under 3.5 Goals',
    'O/U 3.5',
    'goals',
    'mid',
    150,
    'Predict whether the total goals will be over or under 3.5.',
    '[{"key": "over", "label": "Over 3.5"}, {"key": "under", "label": "Under 3.5"}]'::jsonb,
    50
  ),
  (
    'correct-score',
    'Correct Score',
    'CS',
    'match_result',
    'hard',
    500,
    'Predict the exact final scoreline of the match.',
    '[]'::jsonb,
    60
  ),
  (
    'half-time-result',
    'Half-Time Result',
    'HT 1X2',
    'match_result',
    'mid',
    150,
    'Predict the result at half-time: Home Win, Draw, or Away Win.',
    '[{"key": "home", "label": "Home Win"}, {"key": "draw", "label": "Draw"}, {"key": "away", "label": "Away Win"}]'::jsonb,
    70
  ),
  (
    'first-goalscorer',
    'First Goalscorer',
    'FGS',
    'scorers',
    'advanced',
    200,
    'Predict which player will score the first goal of the match.',
    '[]'::jsonb,
    80
  )
on conflict (slug) do update
set
  name = excluded.name,
  short_name = excluded.short_name,
  market_group = excluded.market_group,
  difficulty_tier = excluded.difficulty_tier,
  default_fet_value = excluded.default_fet_value,
  description = excluded.description,
  outcome_template = excluded.outcome_template,
  sort_order = excluded.sort_order,
  is_active = true;

-- ── 10. Public Views ──────────────────────────────────────────────────────

create or replace view public.prediction_markets_catalog
with (security_invoker = true) as
select
  pm.id,
  pm.slug,
  pm.name,
  pm.short_name,
  pm.market_group,
  pm.difficulty_tier,
  pm.default_fet_value,
  pm.description,
  pm.outcome_template,
  pm.sort_order,
  pm.is_active,
  pm.metadata,
  pm.created_at
from football.prediction_markets pm
where pm.is_active = true;

create or replace view public.fixture_markets_catalog
with (security_invoker = true) as
select
  fm.id,
  fm.fixture_id,
  f.competition_id,
  f.season_id,
  f.home_team_id,
  ht.name as home_team_name,
  ht.short_name as home_team_short_name,
  f.away_team_id,
  at.name as away_team_name,
  at.short_name as away_team_short_name,
  f.kickoff_at,
  f.status as fixture_status,
  fm.market_id,
  pm.slug as market_slug,
  pm.name as market_name,
  pm.short_name as market_short_name,
  pm.market_group,
  pm.difficulty_tier,
  coalesce(fm.fet_value_override, pm.default_fet_value) as fet_value,
  fm.outcomes,
  fm.is_locked,
  fm.locked_at,
  fm.created_at
from football.fixture_markets fm
join football.fixtures f on f.id = fm.fixture_id
join football.teams ht on ht.id = f.home_team_id
join football.teams at on at.id = f.away_team_id
join football.prediction_markets pm on pm.id = fm.market_id
where pm.is_active = true;

grant select on public.prediction_markets_catalog to anon, authenticated, service_role;
grant select on public.fixture_markets_catalog to anon, authenticated, service_role;

-- ── 11. RPCs ──────────────────────────────────────────────────────────────

-- Place a single prediction (idempotent upsert)
create or replace function public.prediction_place(
  p_fixture_market_id uuid,
  p_selected_outcome text
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_fm record;
  v_existing record;
  v_slip_id uuid;
  v_prediction_id uuid;
  v_fet_value integer;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'error', 'message', 'Authentication required.');
  end if;

  -- Resolve fixture market
  select fm.*, f.status as fixture_status, f.kickoff_at,
         coalesce(fm.fet_value_override, pm.default_fet_value) as resolved_fet
  into v_fm
  from football.fixture_markets fm
  join football.fixtures f on f.id = fm.fixture_id
  join football.prediction_markets pm on pm.id = fm.market_id
  where fm.id = p_fixture_market_id;

  if v_fm is null then
    return jsonb_build_object('status', 'error', 'message', 'Market not found.');
  end if;

  -- Check market is not locked
  if v_fm.is_locked then
    return jsonb_build_object('status', 'error', 'message', 'This market is locked. Predictions are no longer accepted.');
  end if;

  -- Check fixture has not started
  if v_fm.fixture_status in ('live', 'finished') then
    return jsonb_build_object('status', 'error', 'message', 'This fixture has already started or finished.');
  end if;

  if v_fm.kickoff_at is not null and v_fm.kickoff_at <= now() then
    return jsonb_build_object('status', 'error', 'message', 'Predictions close at kickoff.');
  end if;

  v_fet_value := v_fm.resolved_fet;

  -- Check for existing prediction (idempotent)
  select id, selected_outcome into v_existing
  from football.predictions
  where user_id = v_user_id
    and fixture_market_id = p_fixture_market_id
    and status = 'pending';

  if v_existing.id is not null then
    -- Update existing prediction
    update football.predictions
    set selected_outcome = p_selected_outcome,
        placed_at = now()
    where id = v_existing.id;

    return jsonb_build_object(
      'status', 'updated',
      'prediction_id', v_existing.id,
      'selected_outcome', p_selected_outcome,
      'fet_potential', v_fet_value,
      'message', 'Prediction updated.'
    );
  end if;

  -- Create slip for single prediction
  insert into football.prediction_slips (user_id, slip_type, leg_count)
  values (v_user_id, 'single', 1)
  returning id into v_slip_id;

  -- Create prediction
  insert into football.predictions (
    user_id, fixture_id, fixture_market_id, slip_id,
    selected_outcome, fet_staked
  )
  values (
    v_user_id, v_fm.fixture_id, p_fixture_market_id, v_slip_id,
    p_selected_outcome, 0
  )
  returning id into v_prediction_id;

  return jsonb_build_object(
    'status', 'placed',
    'prediction_id', v_prediction_id,
    'slip_id', v_slip_id,
    'selected_outcome', p_selected_outcome,
    'fet_potential', v_fet_value,
    'message', 'Prediction placed successfully.'
  );
end;
$$;

-- Cancel a pending prediction
create or replace function public.prediction_cancel(
  p_prediction_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_pred record;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'error', 'message', 'Authentication required.');
  end if;

  select p.*, f.status as fixture_status, f.kickoff_at
  into v_pred
  from football.predictions p
  join football.fixtures f on f.id = p.fixture_id
  where p.id = p_prediction_id
    and p.user_id = v_user_id;

  if v_pred is null then
    return jsonb_build_object('status', 'error', 'message', 'Prediction not found.');
  end if;

  if v_pred.status != 'pending' then
    return jsonb_build_object('status', 'error', 'message', 'Only pending predictions can be cancelled.');
  end if;

  if v_pred.fixture_status in ('live', 'finished') then
    return jsonb_build_object('status', 'error', 'message', 'Cannot cancel — fixture already started.');
  end if;

  update football.predictions
  set status = 'cancelled'
  where id = p_prediction_id;

  -- Update slip status if single
  update football.prediction_slips
  set status = 'cancelled'
  where id = v_pred.slip_id
    and slip_type = 'single';

  return jsonb_build_object(
    'status', 'cancelled',
    'prediction_id', p_prediction_id,
    'message', 'Prediction cancelled.'
  );
end;
$$;

-- Get user's active (unsettled) predictions
create or replace function public.prediction_get_active(
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_rows jsonb;
begin
  if v_user_id is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_data order by placed_at desc), '[]'::jsonb)
  into v_rows
  from (
    select jsonb_build_object(
      'id', p.id,
      'fixture_id', p.fixture_id,
      'market_slug', pm.slug,
      'market_name', pm.short_name,
      'market_group', pm.market_group,
      'home_team', ht.name,
      'home_team_short', ht.short_name,
      'away_team', att.name,
      'away_team_short', att.short_name,
      'kickoff_at', f.kickoff_at,
      'fixture_status', f.status,
      'competition_name', c.short_name,
      'selected_outcome', p.selected_outcome,
      'status', p.status,
      'fet_potential', coalesce(fm.fet_value_override, pm.default_fet_value),
      'placed_at', p.placed_at,
      'slip_id', p.slip_id
    ) as row_data,
    p.placed_at
    from football.predictions p
    join football.fixture_markets fm on fm.id = p.fixture_market_id
    join football.prediction_markets pm on pm.id = fm.market_id
    join football.fixtures f on f.id = p.fixture_id
    join football.teams ht on ht.id = f.home_team_id
    join football.teams att on att.id = f.away_team_id
    join football.competitions c on c.id = f.competition_id
    where p.user_id = v_user_id
      and p.status = 'pending'
    order by p.placed_at desc
    limit p_limit
    offset p_offset
  ) sub;

  return v_rows;
end;
$$;

-- Get user's settled prediction history
create or replace function public.prediction_get_history(
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_rows jsonb;
begin
  if v_user_id is null then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_data order by settled_at desc), '[]'::jsonb)
  into v_rows
  from (
    select jsonb_build_object(
      'id', p.id,
      'fixture_id', p.fixture_id,
      'market_slug', pm.slug,
      'market_name', pm.short_name,
      'market_group', pm.market_group,
      'home_team', ht.name,
      'home_team_short', ht.short_name,
      'away_team', att.name,
      'away_team_short', att.short_name,
      'home_score', f.home_score,
      'away_score', f.away_score,
      'kickoff_at', f.kickoff_at,
      'competition_name', c.short_name,
      'selected_outcome', p.selected_outcome,
      'status', p.status,
      'fet_earned', p.fet_earned,
      'placed_at', p.placed_at,
      'settled_at', p.settled_at,
      'slip_id', p.slip_id
    ) as row_data,
    p.settled_at
    from football.predictions p
    join football.fixture_markets fm on fm.id = p.fixture_market_id
    join football.prediction_markets pm on pm.id = fm.market_id
    join football.fixtures f on f.id = p.fixture_id
    join football.teams ht on ht.id = f.home_team_id
    join football.teams att on att.id = f.away_team_id
    join football.competitions c on c.id = f.competition_id
    where p.user_id = v_user_id
      and p.status in ('won', 'lost', 'void')
    order by p.settled_at desc
    limit p_limit
    offset p_offset
  ) sub;

  return v_rows;
end;
$$;

-- Get available markets for a specific fixture
create or replace function public.prediction_get_fixture_markets(
  p_fixture_id uuid
)
returns jsonb
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
    select jsonb_build_object(
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
      'is_locked', fm.is_locked,
      'user_prediction', (
        select jsonb_build_object(
          'prediction_id', up.id,
          'selected_outcome', up.selected_outcome,
          'status', up.status
        )
        from football.predictions up
        where up.fixture_market_id = fm.id
          and up.user_id = v_user_id
          and up.status in ('pending', 'won', 'lost')
        limit 1
      )
    ) as row_data,
    pm.sort_order
    from football.fixture_markets fm
    join football.prediction_markets pm on pm.id = fm.market_id
    where fm.fixture_id = p_fixture_id
      and pm.is_active = true
    order by pm.sort_order
  ) sub;

  return v_rows;
end;
$$;

-- Settle predictions for a completed fixture (service_role only)
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
begin
  -- Verify caller is service_role
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  -- Process each market settlement
  for v_settlement in select * from jsonb_array_elements(p_settlements)
  loop
    v_market_slug := v_settlement->>'market_slug';
    v_correct_outcome := v_settlement->>'correct_outcome';

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

    v_total_awarded := v_total_awarded + (v_won_count * v_fet_value);

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
    'total_awarded', v_total_awarded,
    'settlements_processed', jsonb_array_length(p_settlements)
  );
end;
$$;

-- Grant execute
grant execute on function public.prediction_place(uuid, text) to authenticated;
grant execute on function public.prediction_cancel(uuid) to authenticated;
grant execute on function public.prediction_get_active(integer, integer) to authenticated;
grant execute on function public.prediction_get_history(integer, integer) to authenticated;
grant execute on function public.prediction_get_fixture_markets(uuid) to anon, authenticated;
grant execute on function public.prediction_settle_fixture(uuid, jsonb) to service_role;

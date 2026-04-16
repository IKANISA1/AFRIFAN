-- ============================================================================
-- Prediction jackpot rounds
-- - First-class jackpot round + featured-leg schema
-- - Authenticated RPCs to read the active round and submit an entry
-- - Supports extra entries redeemed via the reward store
-- ============================================================================

create table if not exists football.jackpot_rounds (
  id uuid primary key default gen_random_uuid(),
  club_id bigint references public.african_football_clubs(id) on delete cascade,
  slug text not null unique,
  title text not null,
  description text not null default '',
  status text not null default 'draft',
  opens_at timestamptz not null default timezone('utc', now()),
  entry_deadline_at timestamptz not null,
  kickoff_window_start_at timestamptz,
  kickoff_window_end_at timestamptz,
  prize_pool_fet integer not null default 0,
  max_legs integer not null default 10,
  max_entries_per_user integer not null default 1,
  sponsor_name text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint jackpot_rounds_status_check
    check (status in ('draft', 'open', 'locked', 'settling', 'settled', 'cancelled')),
  constraint jackpot_rounds_prize_pool_check
    check (prize_pool_fet >= 0),
  constraint jackpot_rounds_max_legs_check
    check (max_legs > 0),
  constraint jackpot_rounds_max_entries_check
    check (max_entries_per_user > 0)
);

create table if not exists football.jackpot_round_legs (
  id uuid primary key default gen_random_uuid(),
  jackpot_round_id uuid not null references football.jackpot_rounds(id) on delete cascade,
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  fixture_market_id uuid not null references football.fixture_markets(id) on delete cascade,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  unique (jackpot_round_id, fixture_market_id)
);

create index if not exists idx_jackpot_round_legs_round_sort
  on football.jackpot_round_legs (jackpot_round_id, sort_order, created_at);

create table if not exists football.jackpot_entry_predictions (
  id uuid primary key default gen_random_uuid(),
  slip_id uuid not null references football.prediction_slips(id) on delete cascade,
  user_id uuid not null default auth.uid(),
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  fixture_market_id uuid not null references football.fixture_markets(id) on delete cascade,
  selected_outcome text not null,
  status text not null default 'pending',
  placed_at timestamptz not null default timezone('utc', now()),
  settled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint jackpot_entry_predictions_status_check
    check (status in ('pending', 'won', 'lost', 'cancelled', 'void')),
  unique (slip_id, fixture_market_id)
);

create index if not exists idx_jackpot_entry_predictions_slip
  on football.jackpot_entry_predictions (slip_id, status, placed_at desc);

create index if not exists idx_jackpot_entry_predictions_fixture
  on football.jackpot_entry_predictions (fixture_id, fixture_market_id, status);

drop trigger if exists jackpot_rounds_set_updated_at on football.jackpot_rounds;
create trigger jackpot_rounds_set_updated_at
before update on football.jackpot_rounds
for each row execute function public.set_updated_at();

alter table football.jackpot_rounds enable row level security;
alter table football.jackpot_round_legs enable row level security;
alter table football.jackpot_entry_predictions enable row level security;

drop policy if exists jackpot_rounds_public_read on football.jackpot_rounds;
create policy jackpot_rounds_public_read
on football.jackpot_rounds
for select
using (true);

drop policy if exists jackpot_rounds_admin_manage on football.jackpot_rounds;
create policy jackpot_rounds_admin_manage
on football.jackpot_rounds
for all
to authenticated
using (public.is_admin_user() or public.is_super_admin())
with check (public.is_admin_user() or public.is_super_admin());

drop policy if exists jackpot_round_legs_public_read on football.jackpot_round_legs;
create policy jackpot_round_legs_public_read
on football.jackpot_round_legs
for select
using (true);

drop policy if exists jackpot_round_legs_admin_manage on football.jackpot_round_legs;
create policy jackpot_round_legs_admin_manage
on football.jackpot_round_legs
for all
to authenticated
using (public.is_admin_user() or public.is_super_admin())
with check (public.is_admin_user() or public.is_super_admin());

drop policy if exists jackpot_entry_predictions_owner_read on football.jackpot_entry_predictions;
create policy jackpot_entry_predictions_owner_read
on football.jackpot_entry_predictions
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists jackpot_entry_predictions_service_all on football.jackpot_entry_predictions;
create policy jackpot_entry_predictions_service_all
on football.jackpot_entry_predictions
for all
to service_role
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');

grant select on football.jackpot_rounds to anon, authenticated;
grant select on football.jackpot_round_legs to anon, authenticated;
grant select on football.jackpot_entry_predictions to authenticated;
grant all on football.jackpot_rounds to service_role;
grant all on football.jackpot_round_legs to service_role;
grant all on football.jackpot_entry_predictions to service_role;

alter table football.prediction_slips
  add column if not exists jackpot_round_id uuid references football.jackpot_rounds(id) on delete set null;

alter table football.prediction_slips
  add column if not exists idempotency_key text;

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conname = 'ck_prediction_slips_type'
      and conrelid = 'football.prediction_slips'::regclass
  ) then
    alter table football.prediction_slips
      drop constraint ck_prediction_slips_type;
  end if;
end;
$$;

alter table football.prediction_slips
  add constraint ck_prediction_slips_type
  check (slip_type in ('single', 'acca', 'jackpot'));

create index if not exists idx_prediction_slips_jackpot_round
  on football.prediction_slips (jackpot_round_id, user_id, created_at desc)
  where jackpot_round_id is not null;

create unique index if not exists idx_prediction_slips_jackpot_idempotency
  on football.prediction_slips (user_id, jackpot_round_id, idempotency_key)
  where slip_type = 'jackpot'
    and jackpot_round_id is not null
    and idempotency_key is not null;

do $$
declare
  v_round_id uuid;
  v_seed_fixture_count integer := 0;
begin
  if not exists (
    select 1
    from football.jackpot_rounds round
    where round.status in ('open', 'locked')
      and round.entry_deadline_at > timezone('utc', now()) - interval '14 days'
  ) then
    select count(*)
      into v_seed_fixture_count
    from (
      select fixture.id
      from public.prediction_supported_fixtures_catalog fixture
      join football.fixture_markets fixture_market
        on fixture_market.fixture_id = fixture.id
      join football.prediction_markets market
        on market.id = fixture_market.market_id
      where fixture.status = 'scheduled'
        and fixture.kickoff_at > timezone('utc', now())
        and market.slug = '1x2'
      order by fixture.kickoff_at asc
      limit 10
    ) seed;

    if v_seed_fixture_count >= 4 then
      insert into football.jackpot_rounds (
        club_id,
        slug,
        title,
        description,
        status,
        opens_at,
        entry_deadline_at,
        kickoff_window_start_at,
        kickoff_window_end_at,
        prize_pool_fet,
        max_legs,
        max_entries_per_user,
        metadata
      )
      select
        null,
        'fanzone-weekly-jackpot-' || to_char(timezone('utc', now()), 'YYYYMMDDHH24MISS'),
        'FANZONE Weekly Jackpot',
        'Pick the featured 1X2 fixtures before the round locks.',
        'open',
        timezone('utc', now()),
        least(kickoff_bounds.first_kickoff - interval '1 hour', kickoff_bounds.first_kickoff),
        kickoff_bounds.first_kickoff,
        kickoff_bounds.last_kickoff,
        10000,
        least(kickoff_bounds.fixture_count, 10),
        1,
        jsonb_build_object('seeded_by', '20260415162000_prediction_jackpot_rounds')
      from (
        select
          min(fixture.kickoff_at) as first_kickoff,
          max(fixture.kickoff_at) as last_kickoff,
          count(*)::integer as fixture_count
        from (
          select fixture.*
          from public.prediction_supported_fixtures_catalog fixture
          join football.fixture_markets fixture_market
            on fixture_market.fixture_id = fixture.id
          join football.prediction_markets market
            on market.id = fixture_market.market_id
          where fixture.status = 'scheduled'
            and fixture.kickoff_at > timezone('utc', now())
            and market.slug = '1x2'
          order by fixture.kickoff_at asc
          limit 10
        ) fixture
      ) kickoff_bounds
      returning id into v_round_id;

      insert into football.jackpot_round_legs (
        jackpot_round_id,
        fixture_id,
        fixture_market_id,
        sort_order
      )
      select
        v_round_id,
        fixture.id,
        fixture_market.id,
        row_number() over (order by fixture.kickoff_at asc)
      from (
        select fixture.*
        from public.prediction_supported_fixtures_catalog fixture
        join football.fixture_markets fixture_market
          on fixture_market.fixture_id = fixture.id
        join football.prediction_markets market
          on market.id = fixture_market.market_id
        where fixture.status = 'scheduled'
          and fixture.kickoff_at > timezone('utc', now())
          and market.slug = '1x2'
        order by fixture.kickoff_at asc
        limit 10
      ) fixture
      join football.fixture_markets fixture_market
        on fixture_market.fixture_id = fixture.id
      join football.prediction_markets market
        on market.id = fixture_market.market_id
       and market.slug = '1x2';
    end if;
  end if;
end;
$$;

create or replace function public.prediction_get_active_jackpot_round(
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
stable
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint := coalesce(p_club_id, nullif(public.requesting_club_id(), '')::bigint);
  v_round football.jackpot_rounds;
  v_user_entries integer := 0;
  v_bonus_entries integer := 0;
begin
  select round.*
    into v_round
  from football.jackpot_rounds round
  where round.status in ('open', 'locked')
    and (round.club_id is null or round.club_id = v_club_id)
  order by
    case when round.club_id = v_club_id then 0 else 1 end,
    round.entry_deadline_at asc,
    round.created_at desc
  limit 1;

  if v_round.id is null then
    return null;
  end if;

  if v_user_id is not null then
    select count(*)
      into v_user_entries
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
  end if;

  return jsonb_build_object(
    'id', v_round.id,
    'club_id', v_round.club_id,
    'slug', v_round.slug,
    'title', v_round.title,
    'description', v_round.description,
    'status', v_round.status,
    'opens_at', v_round.opens_at,
    'entry_deadline_at', v_round.entry_deadline_at,
    'kickoff_window_start_at', v_round.kickoff_window_start_at,
    'kickoff_window_end_at', v_round.kickoff_window_end_at,
    'prize_pool_fet', v_round.prize_pool_fet,
    'max_legs', v_round.max_legs,
    'max_entries_per_user', v_round.max_entries_per_user,
    'user_entry_count', v_user_entries,
    'bonus_entry_count', v_bonus_entries,
    'remaining_entries', greatest((v_round.max_entries_per_user + v_bonus_entries) - v_user_entries, 0),
    'can_enter',
      v_round.status = 'open'
      and timezone('utc', now()) < v_round.entry_deadline_at
      and greatest((v_round.max_entries_per_user + v_bonus_entries) - v_user_entries, 0) > 0,
    'fixtures',
      coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'fixture_market_id', leg.fixture_market_id,
            'fixture_id', fixture.id,
            'competition_name', fixture.competition_name,
            'competition_slug', fixture.competition_slug,
            'home_team_name', fixture.home_team_name,
            'home_team_short_name', fixture.home_team_short_name,
            'away_team_name', fixture.away_team_name,
            'away_team_short_name', fixture.away_team_short_name,
            'kickoff_at', fixture.kickoff_at,
            'status', fixture.status,
            'market_name', market.name,
            'market_short_name', market.short_name,
            'outcomes', fixture_market.outcomes
          )
          order by leg.sort_order
        )
        from football.jackpot_round_legs leg
        join public.prediction_supported_fixtures_catalog fixture
          on fixture.id = leg.fixture_id
        join football.fixture_markets fixture_market
          on fixture_market.id = leg.fixture_market_id
        join football.prediction_markets market
          on market.id = fixture_market.market_id
        where leg.jackpot_round_id = v_round.id
      ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.prediction_place_jackpot_entry(
  p_round_id uuid,
  p_selections jsonb,
  p_idempotency_key text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_user_id uuid := auth.uid();
  v_round football.jackpot_rounds;
  v_existing_slip football.prediction_slips;
  v_leg record;
  v_existing_entries integer := 0;
  v_bonus_entries integer := 0;
  v_selection_map jsonb := '{}'::jsonb;
  v_selected_outcome text;
  v_slip_id uuid;
  v_legs_placed integer := 0;
  v_consumed_bonus_id uuid;
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
begin
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

  if v_idempotency_key is not null then
    select *
      into v_existing_slip
    from football.prediction_slips slip
    where slip.user_id = v_user_id
      and slip.slip_type = 'jackpot'
      and slip.jackpot_round_id = v_round.id
      and slip.idempotency_key = v_idempotency_key
    order by slip.created_at desc, slip.id desc
    limit 1;

    if v_existing_slip.id is not null then
      return jsonb_build_object(
        'status', 'placed',
        'already_processed', true,
        'slip_id', v_existing_slip.id,
        'round_id', v_round.id,
        'legs_placed', v_existing_slip.leg_count,
        'bonus_entry_consumed', false,
        'message', format('%s-leg jackpot entry already submitted.', v_existing_slip.leg_count)
      );
    end if;
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
    jackpot_round_id,
    idempotency_key
  )
  values (
    v_user_id,
    'jackpot',
    'pending',
    0,
    v_round.id,
    v_idempotency_key
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

    insert into football.jackpot_entry_predictions (
      user_id,
      fixture_id,
      fixture_market_id,
      slip_id,
      selected_outcome
    )
    values (
      v_user_id,
      v_leg.fixture_id,
      v_leg.fixture_market_id,
      v_slip_id,
      v_selected_outcome
    )
    on conflict (slip_id, fixture_market_id) do update
      set selected_outcome = excluded.selected_outcome,
          placed_at = timezone('utc', now())
      ;

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
    'already_processed', false,
    'slip_id', v_slip_id,
    'round_id', v_round.id,
    'legs_placed', v_legs_placed,
    'bonus_entry_consumed', v_consumed_bonus_id is not null,
    'message', format('%s-leg jackpot entry submitted.', v_legs_placed)
  );
end;
$$;

create or replace function public.prediction_settle_jackpot_entries(
  p_fixture_id uuid
) returns integer
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_prediction_count integer := 0;
begin
  with resolved as (
    select
      prediction.id,
      case
        when lower(prediction.selected_outcome) = lower(settlement.correct_outcome) then 'won'
        else 'lost'
      end as resolved_status
    from football.jackpot_entry_predictions prediction
    join football.fixture_markets fixture_market
      on fixture_market.id = prediction.fixture_market_id
    join football.prediction_settlements settlement
      on settlement.fixture_id = prediction.fixture_id
     and settlement.market_id = fixture_market.market_id
    where prediction.fixture_id = p_fixture_id
      and prediction.status = 'pending'
  )
  update football.jackpot_entry_predictions prediction
  set status = resolved.resolved_status,
      settled_at = timezone('utc', now())
  from resolved
  where prediction.id = resolved.id;

  get diagnostics v_prediction_count = row_count;

  update football.prediction_slips slip
  set status = case
        when exists (
          select 1
          from football.jackpot_entry_predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'pending'
        ) then 'pending'
        when exists (
          select 1
          from football.jackpot_entry_predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'lost'
        ) then 'lost'
        when exists (
          select 1
          from football.jackpot_entry_predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'won'
        ) then 'won'
        else slip.status
      end,
      settled_at = case
        when exists (
          select 1
          from football.jackpot_entry_predictions prediction
          where prediction.slip_id = slip.id
            and prediction.status = 'pending'
        ) then null
        else timezone('utc', now())
      end
  where slip.slip_type = 'jackpot'
    and slip.jackpot_round_id is not null
    and exists (
      select 1
      from football.jackpot_entry_predictions prediction
      where prediction.slip_id = slip.id
        and prediction.fixture_id = p_fixture_id
    );

  return coalesce(v_prediction_count, 0);
end;
$$;

create or replace function public.prediction_refresh_jackpot_entries_from_settlement()
returns trigger
language plpgsql
security definer
set search_path = public, football
as $$
begin
  perform public.prediction_settle_jackpot_entries(new.fixture_id);
  return new;
end;
$$;

drop trigger if exists prediction_settlements_refresh_jackpot on football.prediction_settlements;
create trigger prediction_settlements_refresh_jackpot
after insert or update of correct_outcome, settled_at
on football.prediction_settlements
for each row
execute function public.prediction_refresh_jackpot_entries_from_settlement();

grant execute on function public.prediction_get_active_jackpot_round(bigint) to authenticated;
grant execute on function public.prediction_get_active_jackpot_round(bigint) to service_role;
grant execute on function public.prediction_place_jackpot_entry(uuid, jsonb, text) to authenticated;
grant execute on function public.prediction_place_jackpot_entry(uuid, jsonb, text) to service_role;
grant execute on function public.prediction_settle_jackpot_entries(uuid) to service_role;

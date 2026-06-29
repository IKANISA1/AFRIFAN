-- Partner-centered WDW prediction pools for AFRICLUB launch gamification.
-- This is the FANZONE-aligned model with partner initiatives replacing venue/order eligibility.

begin;

alter table public.fet_wallet_ledger_entries
  drop constraint if exists fet_wallet_ledger_entries_type_check;

alter table public.fet_wallet_ledger_entries
  add constraint fet_wallet_ledger_entries_type_check check (
    entry_type = any (
      array[
        'earn'::text,
        'transfer_in'::text,
        'transfer_out'::text,
        'redeem'::text,
        'admin_adjustment'::text,
        'opening_balance'::text,
        'partner_promotion_earn'::text,
        'partner_pool_entry'::text,
        'partner_pool_payout'::text,
        'partner_pool_refund'::text
      ]
    )
  );

comment on column public.fet_wallet_ledger_entries.entry_type is
  'Wallet operation type: earn, partner_promotion_earn, partner_pool_entry, partner_pool_payout, partner_pool_refund, transfer_in, transfer_out, redeem, admin_adjustment, or opening_balance. Public transfers/redeems are legacy-disabled for launch.';

revoke execute on function public.fet_transfer(uuid, integer, text, text, bigint) from anon, authenticated;
revoke execute on function public.fet_redeem(integer, text, text, bigint) from anon, authenticated;
grant execute on function public.fet_transfer(uuid, integer, text, text, bigint) to service_role;
grant execute on function public.fet_redeem(integer, text, text, bigint) to service_role;

create table if not exists public.partner_fet_initiatives (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete restrict,
  title text not null,
  description text not null default '',
  initiative_type text not null default 'promotion',
  verification_mode text not null default 'manual_review',
  fet_budget integer,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint partner_fet_initiatives_title_check check (length(btrim(title)) > 0),
  constraint partner_fet_initiatives_type_check check (
    initiative_type = any (
      array[
        'promotion'::text,
        'campaign'::text,
        'matchday_activation'::text,
        'referral'::text,
        'receipt_verification'::text,
        'manual_reward'::text
      ]
    )
  ),
  constraint partner_fet_initiatives_verification_check check (
    verification_mode = any (
      array[
        'manual_review'::text,
        'api_confirmation'::text,
        'receipt_scan'::text,
        'event_qr'::text,
        'referral_conversion'::text,
        'partner_file'::text
      ]
    )
  ),
  constraint partner_fet_initiatives_budget_check check (fet_budget is null or fet_budget >= 0),
  constraint partner_fet_initiatives_window_check check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create index if not exists idx_partner_fet_initiatives_partner_active
  on public.partner_fet_initiatives (club_id, partner_id, is_active, starts_at desc);

drop trigger if exists partner_fet_initiatives_set_updated_at on public.partner_fet_initiatives;
create trigger partner_fet_initiatives_set_updated_at
before update on public.partner_fet_initiatives
for each row execute function public.set_updated_at();

alter table public.partner_fet_initiatives enable row level security;

drop policy if exists partner_fet_initiatives_read_active on public.partner_fet_initiatives;
create policy partner_fet_initiatives_read_active
on public.partner_fet_initiatives
for select
using (
  is_active = true
  and club_id::text = public.requesting_club_id()
);

drop policy if exists partner_fet_initiatives_admin_all on public.partner_fet_initiatives;
create policy partner_fet_initiatives_admin_all
on public.partner_fet_initiatives
to authenticated
using (
  public.is_super_admin()
  or public.is_club_admin(club_id)
  or public.is_partner_admin(partner_id)
)
with check (
  public.is_super_admin()
  or public.is_club_admin(club_id)
  or public.is_partner_admin(partner_id)
);

create table if not exists public.partner_fet_earn_events (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete restrict,
  initiative_id uuid references public.partner_fet_initiatives(id) on delete set null,
  user_id uuid not null references public.users(id) on delete cascade,
  amount_fet integer not null,
  status text not null default 'approved',
  reference_type text,
  reference_id text,
  idempotency_key text,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  approved_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint partner_fet_earn_events_amount_check check (amount_fet > 0),
  constraint partner_fet_earn_events_status_check check (
    status = any (array['pending'::text, 'approved'::text, 'rejected'::text, 'revoked'::text])
  )
);

create unique index if not exists idx_partner_fet_earn_events_idempotency
  on public.partner_fet_earn_events (club_id, partner_id, user_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists idx_partner_fet_earn_events_user_approved
  on public.partner_fet_earn_events (club_id, user_id, partner_id, initiative_id, approved_at desc)
  where status = 'approved';

drop trigger if exists partner_fet_earn_events_set_updated_at on public.partner_fet_earn_events;
create trigger partner_fet_earn_events_set_updated_at
before update on public.partner_fet_earn_events
for each row execute function public.set_updated_at();

alter table public.partner_fet_earn_events enable row level security;

drop policy if exists partner_fet_earn_events_owner_read on public.partner_fet_earn_events;
create policy partner_fet_earn_events_owner_read
on public.partner_fet_earn_events
for select
using (
  auth.uid() = user_id
  and club_id::text = public.requesting_club_id()
);

drop policy if exists partner_fet_earn_events_admin_read on public.partner_fet_earn_events;
create policy partner_fet_earn_events_admin_read
on public.partner_fet_earn_events
for select
to authenticated
using (
  public.is_super_admin()
  or public.is_club_admin(club_id)
  or public.is_partner_admin(partner_id)
);

create table if not exists football.partner_prediction_pools (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete restrict,
  initiative_id uuid references public.partner_fet_initiatives(id) on delete set null,
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  title text not null,
  description text not null default '',
  prediction_kind text not null default 'wdw',
  partner_stake_fet integer not null,
  fan_entry_fet integer not null,
  eligibility_mode text not null default 'open_to_all',
  status text not null default 'open',
  lock_at timestamptz not null,
  max_entries integer,
  total_entries integer not null default 0,
  total_fan_entry_fet integer not null default 0,
  settled_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  idempotency_key text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint partner_prediction_pools_title_check check (length(btrim(title)) > 0),
  constraint partner_prediction_pools_kind_check check (prediction_kind = 'wdw'),
  constraint partner_prediction_pools_partner_stake_check check (partner_stake_fet > 0),
  constraint partner_prediction_pools_fan_entry_check check (fan_entry_fet > 0),
  constraint partner_prediction_pools_eligibility_check check (
    eligibility_mode = any (
      array['open_to_all'::text, 'partner_earn_required'::text, 'initiative_earn_required'::text]
    )
  ),
  constraint partner_prediction_pools_status_check check (
    status = any (array['open'::text, 'locked'::text, 'settled'::text, 'void'::text, 'cancelled'::text])
  ),
  constraint partner_prediction_pools_max_entries_check check (max_entries is null or max_entries > 0)
);

create index if not exists idx_partner_prediction_pools_fixture_status
  on football.partner_prediction_pools (fixture_id, status, lock_at);

create index if not exists idx_partner_prediction_pools_partner_status
  on football.partner_prediction_pools (club_id, partner_id, status, lock_at);

create unique index if not exists idx_partner_prediction_pools_idempotency
  on football.partner_prediction_pools (club_id, partner_id, idempotency_key)
  where idempotency_key is not null;

drop trigger if exists partner_prediction_pools_set_updated_at on football.partner_prediction_pools;
create trigger partner_prediction_pools_set_updated_at
before update on football.partner_prediction_pools
for each row execute function public.set_updated_at();

alter table football.partner_prediction_pools enable row level security;

drop policy if exists partner_prediction_pools_read_active on football.partner_prediction_pools;
create policy partner_prediction_pools_read_active
on football.partner_prediction_pools
for select
using (
  status in ('open', 'locked', 'settled')
  and club_id::text = public.requesting_club_id()
);

drop policy if exists partner_prediction_pools_admin_all on football.partner_prediction_pools;
create policy partner_prediction_pools_admin_all
on football.partner_prediction_pools
to authenticated
using (
  public.is_super_admin()
  or public.is_club_admin(club_id)
  or public.is_partner_admin(partner_id)
)
with check (
  public.is_super_admin()
  or public.is_club_admin(club_id)
  or public.is_partner_admin(partner_id)
);

create table if not exists football.partner_prediction_pool_entries (
  id uuid primary key default gen_random_uuid(),
  pool_id uuid not null references football.partner_prediction_pools(id) on delete cascade,
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  partner_id uuid not null references public.partners(id) on delete restrict,
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  selected_outcome text not null,
  fan_entry_fet integer not null,
  eligibility_status text not null default 'pending',
  status text not null default 'active',
  payout_fet integer not null default 0,
  refunded_fet integer not null default 0,
  joined_at timestamptz not null default timezone('utc', now()),
  settled_at timestamptz,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint partner_pool_entries_outcome_check check (
    selected_outcome = any (array['home_win'::text, 'draw'::text, 'away_win'::text])
  ),
  constraint partner_pool_entries_fet_check check (fan_entry_fet > 0),
  constraint partner_pool_entries_eligibility_check check (
    eligibility_status = any (
      array['pending'::text, 'eligible'::text, 'ineligible_no_partner_earn'::text]
    )
  ),
  constraint partner_pool_entries_status_check check (
    status = any (
      array['active'::text, 'winner'::text, 'loser'::text, 'ineligible_winner'::text, 'refunded'::text, 'void'::text]
    )
  ),
  unique (pool_id, user_id)
);

create unique index if not exists idx_partner_pool_entries_idempotency
  on football.partner_prediction_pool_entries (pool_id, user_id, idempotency_key)
  where idempotency_key is not null;

create index if not exists idx_partner_pool_entries_user
  on football.partner_prediction_pool_entries (club_id, user_id, status, joined_at desc);

create index if not exists idx_partner_pool_entries_pool_status
  on football.partner_prediction_pool_entries (pool_id, status, selected_outcome);

drop trigger if exists partner_prediction_pool_entries_set_updated_at on football.partner_prediction_pool_entries;
create trigger partner_prediction_pool_entries_set_updated_at
before update on football.partner_prediction_pool_entries
for each row execute function public.set_updated_at();

alter table football.partner_prediction_pool_entries enable row level security;

drop policy if exists partner_pool_entries_owner_read on football.partner_prediction_pool_entries;
create policy partner_pool_entries_owner_read
on football.partner_prediction_pool_entries
for select
using (
  auth.uid() = user_id
  and club_id::text = public.requesting_club_id()
);

drop policy if exists partner_pool_entries_admin_read on football.partner_prediction_pool_entries;
create policy partner_pool_entries_admin_read
on football.partner_prediction_pool_entries
for select
to authenticated
using (
  public.is_super_admin()
  or public.is_club_admin(club_id)
  or public.is_partner_admin(partner_id)
);

create table if not exists football.partner_prediction_pool_settlements (
  id uuid primary key default gen_random_uuid(),
  pool_id uuid not null unique references football.partner_prediction_pools(id) on delete cascade,
  fixture_id uuid not null references football.fixtures(id) on delete cascade,
  official_outcome text,
  total_entries integer not null default 0,
  logical_winners integer not null default 0,
  eligible_winners integer not null default 0,
  ineligible_winners integer not null default 0,
  partner_stake_fet integer not null default 0,
  fan_entry_fet integer not null default 0,
  total_paid_fet integer not null default 0,
  total_refunded_fet integer not null default 0,
  unawarded_partner_fet integer not null default 0,
  settlement_mode text not null,
  metadata jsonb not null default '{}'::jsonb,
  settled_by uuid references auth.users(id) on delete set null,
  settled_at timestamptz not null default timezone('utc', now()),
  constraint partner_pool_settlements_outcome_check check (
    official_outcome is null
    or official_outcome = any (array['home_win'::text, 'draw'::text, 'away_win'::text])
  )
);

alter table football.partner_prediction_pool_settlements enable row level security;

drop policy if exists partner_pool_settlements_read on football.partner_prediction_pool_settlements;
create policy partner_pool_settlements_read
on football.partner_prediction_pool_settlements
for select
using (
  exists (
    select 1
    from football.partner_prediction_pools pool
    where pool.id = partner_prediction_pool_settlements.pool_id
      and pool.club_id::text = public.requesting_club_id()
  )
);

create or replace function public.partner_fet_adjust_wallet(
  p_club_id bigint,
  p_user_id uuid,
  p_amount_fet integer,
  p_direction text,
  p_entry_type text,
  p_reference_type text,
  p_reference_id text,
  p_idempotency_key text default null,
  p_note text default null,
  p_metadata jsonb default '{}'::jsonb
) returns integer
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_membership public.fan_memberships;
  v_existing public.fet_wallet_ledger_entries;
  v_direction text := lower(btrim(coalesce(p_direction, '')));
  v_entry_type text := lower(btrim(coalesce(p_entry_type, '')));
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_amount integer := greatest(coalesce(p_amount_fet, 0), 0);
  v_new_balance integer;
begin
  if p_club_id is null then
    raise exception 'Club scope is required.';
  end if;

  if p_user_id is null then
    raise exception 'Target user is required.';
  end if;

  if v_amount <= 0 then
    raise exception 'FET amount must be greater than zero.';
  end if;

  if v_direction not in ('credit', 'debit') then
    raise exception 'Invalid wallet direction: %.', p_direction;
  end if;

  if v_entry_type not in (
    'partner_promotion_earn',
    'partner_pool_entry',
    'partner_pool_payout',
    'partner_pool_refund'
  ) then
    raise exception 'Invalid partner wallet entry type: %.', p_entry_type;
  end if;

  if v_idempotency_key is not null then
    select *
      into v_existing
      from public.fet_wallet_ledger_entries ledger
     where ledger.club_id = p_club_id
       and ledger.user_id = p_user_id
       and ledger.idempotency_key = v_idempotency_key
     order by ledger.created_at desc, ledger.id desc
     limit 1;

    if v_existing.id is not null then
      return v_existing.balance_after;
    end if;
  end if;

  perform public.fet_wallet_ensure_membership(p_user_id, p_club_id);

  select *
    into v_membership
    from public.fan_memberships membership
   where membership.user_id = p_user_id
     and membership.club_id = p_club_id
   for update;

  if v_membership.id is null then
    raise exception 'Wallet membership not found.';
  end if;

  if v_direction = 'debit' then
    if coalesce(v_membership.points, 0) < v_amount then
      raise exception 'Insufficient FET balance.';
    end if;
    v_new_balance := coalesce(v_membership.points, 0) - v_amount;
  else
    v_new_balance := coalesce(v_membership.points, 0) + v_amount;
  end if;

  update public.fan_memberships
     set points = v_new_balance,
         tier = public.resolve_fan_tier(v_new_balance),
         renewed_at = case when v_direction = 'credit' then timezone('utc', now()) else renewed_at end,
         updated_at = timezone('utc', now())
   where id = v_membership.id
  returning * into v_membership;

  perform public.fet_wallet_append_entry(
    p_club_id := p_club_id,
    p_user_id := p_user_id,
    p_membership_id := v_membership.id,
    p_entry_type := v_entry_type,
    p_direction := v_direction,
    p_amount := v_amount,
    p_balance_after := v_membership.points,
    p_counterparty_user_id := null,
    p_reference_type := nullif(btrim(coalesce(p_reference_type, '')), ''),
    p_reference_id := nullif(btrim(coalesce(p_reference_id, '')), ''),
    p_idempotency_key := v_idempotency_key,
    p_note := p_note,
    p_metadata := coalesce(p_metadata, '{}'::jsonb),
    p_created_by := auth.uid()
  );

  return v_membership.points;
end;
$$;

create or replace function public.partner_fet_record_earn_event(
  p_partner_id uuid,
  p_user_id uuid,
  p_amount_fet integer,
  p_initiative_id uuid default null,
  p_reference_type text default null,
  p_reference_id text default null,
  p_idempotency_key text default null,
  p_note text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_club_id bigint;
  v_existing public.partner_fet_earn_events;
  v_event public.partner_fet_earn_events;
  v_amount integer := greatest(coalesce(p_amount_fet, 0), 0);
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
begin
  if p_partner_id is null then
    raise exception 'Partner is required.';
  end if;

  if p_user_id is null then
    raise exception 'User is required.';
  end if;

  if v_amount <= 0 then
    raise exception 'FET amount must be greater than zero.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  if auth.role() <> 'service_role'
     and not (
       public.is_super_admin()
       or public.is_club_admin(v_club_id)
       or public.is_partner_admin(p_partner_id)
     ) then
    raise exception 'Partner reward approval requires admin access.';
  end if;

  if p_initiative_id is not null
     and not exists (
       select 1
       from public.partner_fet_initiatives initiative
       where initiative.id = p_initiative_id
         and initiative.club_id = v_club_id
         and initiative.partner_id = p_partner_id
     ) then
    raise exception 'Initiative does not belong to this partner and club.';
  end if;

  if v_idempotency_key is not null then
    select *
      into v_existing
      from public.partner_fet_earn_events event
     where event.club_id = v_club_id
       and event.partner_id = p_partner_id
       and event.user_id = p_user_id
       and event.idempotency_key = v_idempotency_key
     order by event.created_at desc
     limit 1;

    if v_existing.id is not null then
      return jsonb_build_object(
        'status', 'already_processed',
        'event_id', v_existing.id,
        'amount_fet', v_existing.amount_fet
      );
    end if;
  end if;

  insert into public.partner_fet_earn_events (
    club_id,
    partner_id,
    initiative_id,
    user_id,
    amount_fet,
    status,
    reference_type,
    reference_id,
    idempotency_key,
    note,
    metadata,
    approved_at,
    created_by
  )
  values (
    v_club_id,
    p_partner_id,
    p_initiative_id,
    p_user_id,
    v_amount,
    'approved',
    nullif(btrim(coalesce(p_reference_type, '')), ''),
    nullif(btrim(coalesce(p_reference_id, '')), ''),
    v_idempotency_key,
    p_note,
    coalesce(p_metadata, '{}'::jsonb),
    timezone('utc', now()),
    auth.uid()
  )
  returning * into v_event;

  perform public.partner_fet_adjust_wallet(
    p_club_id := v_club_id,
    p_user_id := p_user_id,
    p_amount_fet := v_amount,
    p_direction := 'credit',
    p_entry_type := 'partner_promotion_earn',
    p_reference_type := coalesce(nullif(btrim(coalesce(p_reference_type, '')), ''), 'partner_earn_event'),
    p_reference_id := v_event.id::text,
    p_idempotency_key := 'partner-earn:' || v_event.id::text,
    p_note := coalesce(p_note, 'Partner promotion FET earned'),
    p_metadata := coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'partner_id', p_partner_id,
      'initiative_id', p_initiative_id,
      'earn_event_id', v_event.id
    )
  );

  return jsonb_build_object(
    'status', 'success',
    'event_id', v_event.id,
    'amount_fet', v_amount
  );
end;
$$;

create or replace function public.partner_prediction_pool_user_eligible(
  p_pool_id uuid,
  p_user_id uuid
) returns boolean
language sql
stable
security definer
set search_path = public, football
as $$
  select coalesce((
    select case
      when pool.eligibility_mode = 'open_to_all' then true
      when pool.eligibility_mode = 'partner_earn_required' then exists (
        select 1
        from public.partner_fet_earn_events event
        where event.club_id = pool.club_id
          and event.partner_id = pool.partner_id
          and event.user_id = p_user_id
          and event.status = 'approved'
          and event.approved_at is not null
      )
      when pool.eligibility_mode = 'initiative_earn_required' then exists (
        select 1
        from public.partner_fet_earn_events event
        where event.club_id = pool.club_id
          and event.partner_id = pool.partner_id
          and event.initiative_id = pool.initiative_id
          and event.user_id = p_user_id
          and event.status = 'approved'
          and event.approved_at is not null
      )
      else false
    end
    from football.partner_prediction_pools pool
    where pool.id = p_pool_id
  ), false);
$$;

create or replace function public.partner_prediction_pool_summary_json(
  p_pool_id uuid,
  p_viewer_user_id uuid default auth.uid()
) returns jsonb
language sql
stable
security definer
set search_path = public, football
as $$
  select '{}'::jsonb;
$$;

create or replace function public.partner_prediction_pool_create(
  p_partner_id uuid,
  p_fixture_id uuid,
  p_title text,
  p_partner_stake_fet integer,
  p_fan_entry_fet integer,
  p_initiative_id uuid default null,
  p_eligibility_mode text default 'open_to_all',
  p_max_entries integer default null,
  p_idempotency_key text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_club_id bigint;
  v_fixture record;
  v_pool football.partner_prediction_pools;
  v_existing_pool_id uuid;
  v_title text := nullif(btrim(coalesce(p_title, '')), '');
  v_eligibility_mode text := lower(btrim(coalesce(p_eligibility_mode, 'open_to_all')));
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  if p_partner_id is null then
    raise exception 'Partner is required.';
  end if;

  if v_title is null then
    raise exception 'Pool title is required.';
  end if;

  if coalesce(p_partner_stake_fet, 0) <= 0 then
    raise exception 'Partner FET stake must be greater than zero.';
  end if;

  if coalesce(p_fan_entry_fet, 0) <= 0 then
    raise exception 'Fan entry FET must be greater than zero.';
  end if;

  if v_eligibility_mode not in ('open_to_all', 'partner_earn_required', 'initiative_earn_required') then
    raise exception 'Invalid eligibility mode.';
  end if;

  if v_eligibility_mode = 'initiative_earn_required' and p_initiative_id is null then
    raise exception 'Initiative eligibility requires an initiative.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  if not (
    public.is_super_admin()
    or public.is_club_admin(v_club_id)
    or public.is_partner_admin(p_partner_id)
  ) then
    raise exception 'Pool creation requires club or partner admin access.';
  end if;

  select fixture.id, fixture.kickoff_at, fixture.status
    into v_fixture
    from football.fixtures fixture
   where fixture.id = p_fixture_id
   limit 1;

  if v_fixture.id is null then
    raise exception 'Fixture not found.';
  end if;

  if v_fixture.kickoff_at is null or v_fixture.kickoff_at <= timezone('utc', now()) then
    raise exception 'Partner pools can only be created before kickoff.';
  end if;

  if coalesce(v_fixture.status::text, 'scheduled') not in ('scheduled', 'pending') then
    raise exception 'Partner pools can only be created for upcoming fixtures.';
  end if;

  if p_initiative_id is not null
     and not exists (
       select 1
       from public.partner_fet_initiatives initiative
       where initiative.id = p_initiative_id
         and initiative.club_id = v_club_id
         and initiative.partner_id = p_partner_id
         and initiative.is_active = true
     ) then
    raise exception 'Initiative does not belong to this active partner scope.';
  end if;

  if v_idempotency_key is not null then
    select pool.id
      into v_existing_pool_id
      from football.partner_prediction_pools pool
     where pool.club_id = v_club_id
       and pool.partner_id = p_partner_id
       and pool.idempotency_key = v_idempotency_key
     order by pool.created_at desc
     limit 1;

    if v_existing_pool_id is not null then
      return public.partner_prediction_pool_summary_json(v_existing_pool_id, auth.uid());
    end if;
  end if;

  insert into football.partner_prediction_pools (
    club_id,
    partner_id,
    initiative_id,
    fixture_id,
    title,
    prediction_kind,
    partner_stake_fet,
    fan_entry_fet,
    eligibility_mode,
    status,
    lock_at,
    max_entries,
    idempotency_key,
    metadata,
    created_by
  )
  values (
    v_club_id,
    p_partner_id,
    p_initiative_id,
    p_fixture_id,
    v_title,
    'wdw',
    p_partner_stake_fet,
    p_fan_entry_fet,
    v_eligibility_mode,
    'open',
    v_fixture.kickoff_at,
    p_max_entries,
    v_idempotency_key,
    coalesce(p_metadata, '{}'::jsonb),
    auth.uid()
  )
  returning * into v_pool;

  return public.partner_prediction_pool_summary_json(v_pool.id, auth.uid());
end;
$$;

create or replace function public.partner_prediction_pool_join(
  p_pool_id uuid,
  p_selected_outcome text,
  p_idempotency_key text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_user_id uuid := auth.uid();
  v_pool football.partner_prediction_pools;
  v_entry football.partner_prediction_pool_entries;
  v_selected_outcome text := lower(btrim(coalesce(p_selected_outcome, '')));
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_is_eligible boolean;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if v_selected_outcome not in ('home_win', 'draw', 'away_win') then
    raise exception 'WDW prediction must be home_win, draw, or away_win.';
  end if;

  select *
    into v_pool
    from football.partner_prediction_pools pool
   where pool.id = p_pool_id
   for update;

  if v_pool.id is null then
    raise exception 'Partner prediction pool not found.';
  end if;

  if v_pool.status <> 'open' then
    raise exception 'Partner prediction pool is not open.';
  end if;

  if v_pool.lock_at <= timezone('utc', now()) then
    raise exception 'Partner prediction pool has locked.';
  end if;

  if v_pool.max_entries is not null and v_pool.total_entries >= v_pool.max_entries then
    raise exception 'Partner prediction pool is full.';
  end if;

  select *
    into v_entry
    from football.partner_prediction_pool_entries entry
   where entry.pool_id = p_pool_id
     and entry.user_id = v_user_id
   limit 1;

  if v_entry.id is not null then
    return public.partner_prediction_pool_summary_json(p_pool_id, v_user_id);
  end if;

  v_is_eligible := public.partner_prediction_pool_user_eligible(p_pool_id, v_user_id);

  perform public.partner_fet_adjust_wallet(
    p_club_id := v_pool.club_id,
    p_user_id := v_user_id,
    p_amount_fet := v_pool.fan_entry_fet,
    p_direction := 'debit',
    p_entry_type := 'partner_pool_entry',
    p_reference_type := 'partner_prediction_pool',
    p_reference_id := p_pool_id::text,
    p_idempotency_key := coalesce(v_idempotency_key, 'partner-pool-entry:' || p_pool_id::text || ':' || v_user_id::text),
    p_note := 'Partner WDW pool entry',
    p_metadata := jsonb_build_object(
      'pool_id', p_pool_id,
      'partner_id', v_pool.partner_id,
      'fixture_id', v_pool.fixture_id,
      'selected_outcome', v_selected_outcome,
      'kind', 'partner_pool_entry'
    )
  );

  insert into football.partner_prediction_pool_entries (
    pool_id,
    club_id,
    partner_id,
    fixture_id,
    user_id,
    selected_outcome,
    fan_entry_fet,
    eligibility_status,
    status,
    idempotency_key
  )
  values (
    p_pool_id,
    v_pool.club_id,
    v_pool.partner_id,
    v_pool.fixture_id,
    v_user_id,
    v_selected_outcome,
    v_pool.fan_entry_fet,
    case when v_is_eligible then 'eligible' else 'ineligible_no_partner_earn' end,
    'active',
    v_idempotency_key
  )
  returning * into v_entry;

  update football.partner_prediction_pools
     set total_entries = total_entries + 1,
         total_fan_entry_fet = total_fan_entry_fet + v_pool.fan_entry_fet,
         updated_at = timezone('utc', now())
   where id = p_pool_id;

  return public.partner_prediction_pool_summary_json(p_pool_id, v_user_id);
end;
$$;

create or replace function public.partner_prediction_pool_summary_json(
  p_pool_id uuid,
  p_viewer_user_id uuid default auth.uid()
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, football
as $$
declare
  v_payload jsonb;
begin
  select jsonb_build_object(
    'id', pool.id,
    'club_id', pool.club_id,
    'partner_id', pool.partner_id,
    'partner_name', partner.name,
    'partner_slug', partner.slug,
    'initiative_id', pool.initiative_id,
    'fixture_id', pool.fixture_id,
    'title', pool.title,
    'prediction_kind', pool.prediction_kind,
    'partner_stake_fet', pool.partner_stake_fet,
    'fan_entry_fet', pool.fan_entry_fet,
    'eligibility_mode', pool.eligibility_mode,
    'status', pool.status,
    'lock_at', pool.lock_at,
    'total_entries', pool.total_entries,
    'total_fan_entry_fet', pool.total_fan_entry_fet,
    'metadata', pool.metadata,
    'viewer_entry', case
      when entry.id is null then null
      else jsonb_build_object(
        'id', entry.id,
        'selected_outcome', entry.selected_outcome,
        'eligibility_status', entry.eligibility_status,
        'status', entry.status,
        'payout_fet', entry.payout_fet,
        'refunded_fet', entry.refunded_fet,
        'joined_at', entry.joined_at
      )
    end,
    'settlement', case
      when settlement.id is null then null
      else jsonb_build_object(
        'official_outcome', settlement.official_outcome,
        'logical_winners', settlement.logical_winners,
        'eligible_winners', settlement.eligible_winners,
        'ineligible_winners', settlement.ineligible_winners,
        'total_paid_fet', settlement.total_paid_fet,
        'total_refunded_fet', settlement.total_refunded_fet,
        'unawarded_partner_fet', settlement.unawarded_partner_fet,
        'settlement_mode', settlement.settlement_mode,
        'settled_at', settlement.settled_at
      )
    end
  )
    into v_payload
    from football.partner_prediction_pools pool
    join public.partners partner
      on partner.id = pool.partner_id
    left join football.partner_prediction_pool_entries entry
      on entry.pool_id = pool.id
     and entry.user_id = p_viewer_user_id
    left join football.partner_prediction_pool_settlements settlement
      on settlement.pool_id = pool.id
   where pool.id = p_pool_id;

  return coalesce(v_payload, '{}'::jsonb);
end;
$$;

create or replace function public.partner_prediction_pool_feed(
  p_club_id bigint default null,
  p_statuses text[] default array['open', 'locked']::text[],
  p_limit integer default 50,
  p_offset integer default 0
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, football
as $$
declare
  v_club_id bigint;
  v_viewer uuid := auth.uid();
  v_payload jsonb;
begin
  v_club_id := public.fet_require_club_context(p_club_id);

  select coalesce(
    jsonb_agg(public.partner_prediction_pool_summary_json(scoped.id, v_viewer) order by scoped.lock_at asc, scoped.created_at desc),
    '[]'::jsonb
  )
    into v_payload
    from (
      select pool.id, pool.lock_at, pool.created_at
      from football.partner_prediction_pools pool
      where pool.club_id = v_club_id
        and (
          p_statuses is null
          or array_length(p_statuses, 1) is null
          or pool.status = any(p_statuses)
        )
      order by pool.lock_at asc, pool.created_at desc
      limit greatest(coalesce(p_limit, 50), 1)
      offset greatest(coalesce(p_offset, 0), 0)
    ) scoped;

  return v_payload;
end;
$$;

create or replace function public.partner_prediction_pool_settle(
  p_pool_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, football, auth
as $$
declare
  v_pool football.partner_prediction_pools;
  v_fixture record;
  v_official_outcome text;
  v_total_active integer;
  v_logical_winners integer;
  v_eligible_winners integer;
  v_ineligible_winners integer;
  v_distributable_fet integer;
  v_payout_per_winner integer;
  v_remainder_fet integer;
  v_total_paid integer := 0;
  v_total_refunded integer := 0;
  v_entry football.partner_prediction_pool_entries;
  v_entry_eligible boolean;
  v_mode text;
begin
  select *
    into v_pool
    from football.partner_prediction_pools pool
   where pool.id = p_pool_id
   for update;

  if v_pool.id is null then
    raise exception 'Partner prediction pool not found.';
  end if;

  if auth.role() <> 'service_role'
     and not (
       public.is_super_admin()
       or public.is_club_admin(v_pool.club_id)
       or public.is_partner_admin(v_pool.partner_id)
     ) then
    raise exception 'Settlement requires service, club admin, or partner admin access.';
  end if;

  if v_pool.status in ('settled', 'void', 'cancelled') then
    return public.partner_prediction_pool_summary_json(p_pool_id, auth.uid());
  end if;

  select fixture.id, fixture.status, fixture.home_score, fixture.away_score
    into v_fixture
    from football.fixtures fixture
   where fixture.id = v_pool.fixture_id
   limit 1;

  if v_fixture.id is null then
    raise exception 'Fixture not found.';
  end if;

  if coalesce(v_fixture.status::text, '') not in ('finished', 'completed') then
    raise exception 'Fixture is not ready for WDW settlement.';
  end if;

  if v_fixture.home_score is null or v_fixture.away_score is null then
    raise exception 'Fixture final score is required for WDW settlement.';
  end if;

  v_official_outcome := case
    when v_fixture.home_score > v_fixture.away_score then 'home_win'
    when v_fixture.home_score = v_fixture.away_score then 'draw'
    else 'away_win'
  end;

  select count(*)
    into v_total_active
    from football.partner_prediction_pool_entries entry
   where entry.pool_id = p_pool_id
     and entry.status = 'active';

  if v_total_active = 0 then
    v_mode := 'no_entries';
    insert into football.partner_prediction_pool_settlements (
      pool_id, fixture_id, official_outcome, settlement_mode, partner_stake_fet, unawarded_partner_fet, settled_by
    )
    values (
      p_pool_id, v_pool.fixture_id, v_official_outcome, v_mode, v_pool.partner_stake_fet, v_pool.partner_stake_fet, auth.uid()
    )
    on conflict (pool_id) do nothing;

    update football.partner_prediction_pools
       set status = 'void',
           settled_at = timezone('utc', now())
     where id = p_pool_id;

    return public.partner_prediction_pool_summary_json(p_pool_id, auth.uid());
  end if;

  update football.partner_prediction_pool_entries entry
     set eligibility_status = case
           when public.partner_prediction_pool_user_eligible(p_pool_id, entry.user_id)
             then 'eligible'
           else 'ineligible_no_partner_earn'
         end
   where entry.pool_id = p_pool_id
     and entry.status = 'active';

  select count(*)
    into v_logical_winners
    from football.partner_prediction_pool_entries entry
   where entry.pool_id = p_pool_id
     and entry.status = 'active'
     and entry.selected_outcome = v_official_outcome;

  select count(*)
    into v_eligible_winners
    from football.partner_prediction_pool_entries entry
   where entry.pool_id = p_pool_id
     and entry.status = 'active'
     and entry.selected_outcome = v_official_outcome
     and entry.eligibility_status = 'eligible';

  v_ineligible_winners := greatest(v_logical_winners - v_eligible_winners, 0);

  if v_logical_winners = 0 or v_eligible_winners = 0 then
    v_mode := case when v_logical_winners = 0 then 'no_wdw_winner' else 'no_eligible_winner' end;

    for v_entry in
      select *
      from football.partner_prediction_pool_entries entry
      where entry.pool_id = p_pool_id
        and entry.status = 'active'
    loop
      perform public.partner_fet_adjust_wallet(
        p_club_id := v_entry.club_id,
        p_user_id := v_entry.user_id,
        p_amount_fet := v_entry.fan_entry_fet,
        p_direction := 'credit',
        p_entry_type := 'partner_pool_refund',
        p_reference_type := 'partner_prediction_pool',
        p_reference_id := p_pool_id::text,
        p_idempotency_key := 'partner-pool-refund:' || p_pool_id::text || ':' || v_entry.id::text,
        p_note := 'Partner WDW pool refunded',
        p_metadata := jsonb_build_object(
          'pool_id', p_pool_id,
          'entry_id', v_entry.id,
          'partner_id', v_entry.partner_id,
          'fixture_id', v_entry.fixture_id,
          'settlement_mode', v_mode
        )
      );

      update football.partner_prediction_pool_entries
         set status = 'refunded',
             refunded_fet = v_entry.fan_entry_fet,
             settled_at = timezone('utc', now())
       where id = v_entry.id;

      v_total_refunded := v_total_refunded + v_entry.fan_entry_fet;
    end loop;

    insert into football.partner_prediction_pool_settlements (
      pool_id,
      fixture_id,
      official_outcome,
      total_entries,
      logical_winners,
      eligible_winners,
      ineligible_winners,
      partner_stake_fet,
      fan_entry_fet,
      total_paid_fet,
      total_refunded_fet,
      unawarded_partner_fet,
      settlement_mode,
      settled_by
    )
    values (
      p_pool_id,
      v_pool.fixture_id,
      v_official_outcome,
      v_total_active,
      v_logical_winners,
      v_eligible_winners,
      v_ineligible_winners,
      v_pool.partner_stake_fet,
      v_pool.total_fan_entry_fet,
      0,
      v_total_refunded,
      v_pool.partner_stake_fet,
      v_mode,
      auth.uid()
    )
    on conflict (pool_id) do nothing;

    update football.partner_prediction_pools
       set status = 'void',
           settled_at = timezone('utc', now())
     where id = p_pool_id;

    return public.partner_prediction_pool_summary_json(p_pool_id, auth.uid());
  end if;

  v_distributable_fet := v_pool.partner_stake_fet + v_pool.total_fan_entry_fet;
  v_payout_per_winner := floor(v_distributable_fet / v_eligible_winners);
  v_remainder_fet := mod(v_distributable_fet, v_eligible_winners);

  for v_entry in
    select *
    from football.partner_prediction_pool_entries entry
    where entry.pool_id = p_pool_id
      and entry.status = 'active'
    order by entry.joined_at asc, entry.id asc
  loop
    v_entry_eligible := v_entry.eligibility_status = 'eligible';

    if v_entry.selected_outcome = v_official_outcome and v_entry_eligible then
      perform public.partner_fet_adjust_wallet(
        p_club_id := v_entry.club_id,
        p_user_id := v_entry.user_id,
        p_amount_fet := v_payout_per_winner + case when v_remainder_fet > 0 then 1 else 0 end,
        p_direction := 'credit',
        p_entry_type := 'partner_pool_payout',
        p_reference_type := 'partner_prediction_pool',
        p_reference_id := p_pool_id::text,
        p_idempotency_key := 'partner-pool-payout:' || p_pool_id::text || ':' || v_entry.id::text,
        p_note := 'Partner WDW pool payout',
        p_metadata := jsonb_build_object(
          'pool_id', p_pool_id,
          'entry_id', v_entry.id,
          'partner_id', v_entry.partner_id,
          'fixture_id', v_entry.fixture_id,
          'official_outcome', v_official_outcome
        )
      );

      update football.partner_prediction_pool_entries
         set status = 'winner',
             payout_fet = v_payout_per_winner + case when v_remainder_fet > 0 then 1 else 0 end,
             settled_at = timezone('utc', now())
       where id = v_entry.id;

      v_total_paid := v_total_paid + v_payout_per_winner + case when v_remainder_fet > 0 then 1 else 0 end;
      if v_remainder_fet > 0 then
        v_remainder_fet := v_remainder_fet - 1;
      end if;
    elsif v_entry.selected_outcome = v_official_outcome and not v_entry_eligible then
      update football.partner_prediction_pool_entries
         set status = 'ineligible_winner',
             payout_fet = 0,
             settled_at = timezone('utc', now())
       where id = v_entry.id;
    else
      update football.partner_prediction_pool_entries
         set status = 'loser',
             payout_fet = 0,
             settled_at = timezone('utc', now())
       where id = v_entry.id;
    end if;
  end loop;

  insert into football.partner_prediction_pool_settlements (
    pool_id,
    fixture_id,
    official_outcome,
    total_entries,
    logical_winners,
    eligible_winners,
    ineligible_winners,
    partner_stake_fet,
    fan_entry_fet,
    total_paid_fet,
    total_refunded_fet,
    unawarded_partner_fet,
    settlement_mode,
    settled_by
  )
  values (
    p_pool_id,
    v_pool.fixture_id,
    v_official_outcome,
    v_total_active,
    v_logical_winners,
    v_eligible_winners,
    v_ineligible_winners,
    v_pool.partner_stake_fet,
    v_pool.total_fan_entry_fet,
    v_total_paid,
    0,
    greatest(v_distributable_fet - v_total_paid, 0),
    'wdw_settled',
    auth.uid()
  )
  on conflict (pool_id) do nothing;

  update football.partner_prediction_pools
     set status = 'settled',
         settled_at = timezone('utc', now())
   where id = p_pool_id;

  return public.partner_prediction_pool_summary_json(p_pool_id, auth.uid());
end;
$$;

revoke all on function public.partner_fet_adjust_wallet(bigint, uuid, integer, text, text, text, text, text, text, jsonb) from public, anon, authenticated;
grant execute on function public.partner_fet_adjust_wallet(bigint, uuid, integer, text, text, text, text, text, text, jsonb) to service_role;

grant execute on function public.partner_fet_record_earn_event(uuid, uuid, integer, uuid, text, text, text, text, jsonb, bigint) to authenticated, service_role;
grant execute on function public.partner_prediction_pool_user_eligible(uuid, uuid) to authenticated, service_role;
grant execute on function public.partner_prediction_pool_create(uuid, uuid, text, integer, integer, uuid, text, integer, text, jsonb, bigint) to authenticated, service_role;
grant execute on function public.partner_prediction_pool_join(uuid, text, text) to authenticated;
grant execute on function public.partner_prediction_pool_summary_json(uuid, uuid) to authenticated, service_role;
grant execute on function public.partner_prediction_pool_feed(bigint, text[], integer, integer) to authenticated, service_role;
grant execute on function public.partner_prediction_pool_settle(uuid) to authenticated, service_role;

commit;

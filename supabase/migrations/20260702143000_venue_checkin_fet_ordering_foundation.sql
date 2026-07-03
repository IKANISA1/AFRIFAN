-- Venue check-in, drinks ordering, and venue-scoped FET foundations.
-- Additive migration for the Rayon venue/FET rollout.

create table if not exists public.venues (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  slug text not null,
  display_name text not null,
  status text not null default 'pending_review',
  venue_type text not null default 'partner_bar',
  address_line text,
  city text,
  country_code text not null default 'RW',
  timezone text not null default 'Africa/Kigali',
  approved_public_profile boolean not null default false,
  public_summary text,
  checkin_radius_meters integer not null default 150,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint venues_status_check check (
    status = any (array['pending_review', 'approved', 'suspended', 'archived'])
  ),
  constraint venues_radius_check check (checkin_radius_meters between 10 and 5000),
  constraint venues_slug_check check (slug ~ '^[a-z0-9][a-z0-9-]{1,80}$')
);

create unique index if not exists idx_venues_club_slug
  on public.venues (club_id, slug);
create index if not exists idx_venues_club_status
  on public.venues (club_id, status, approved_public_profile);

drop trigger if exists venues_set_updated_at on public.venues;
create trigger venues_set_updated_at
before update on public.venues
for each row execute function public.set_updated_at();

create table if not exists public.venue_staff_memberships (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  user_id uuid not null,
  role text not null default 'staff',
  is_active boolean not null default true,
  granted_by uuid,
  granted_at timestamp with time zone not null default timezone('utc', now()),
  revoked_at timestamp with time zone,
  notes text,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint venue_staff_role_check check (
    role = any (array['owner', 'manager', 'staff', 'reviewer'])
  )
);

create unique index if not exists idx_venue_staff_active_unique
  on public.venue_staff_memberships (club_id, venue_id, user_id)
  where is_active;
create index if not exists idx_venue_staff_user
  on public.venue_staff_memberships (user_id, is_active, club_id, venue_id);

drop trigger if exists venue_staff_memberships_set_updated_at on public.venue_staff_memberships;
create trigger venue_staff_memberships_set_updated_at
before update on public.venue_staff_memberships
for each row execute function public.set_updated_at();

create table if not exists public.venue_fet_wallets (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  available_balance integer not null default 0,
  reserved_balance integer not null default 0,
  lifetime_funded integer not null default 0,
  lifetime_awarded integer not null default 0,
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint venue_fet_wallets_available_check check (available_balance >= 0),
  constraint venue_fet_wallets_reserved_check check (reserved_balance >= 0),
  constraint venue_fet_wallets_lifetime_check check (
    lifetime_funded >= 0 and lifetime_awarded >= 0
  )
);

create unique index if not exists idx_venue_fet_wallets_venue
  on public.venue_fet_wallets (club_id, venue_id);

drop trigger if exists venue_fet_wallets_set_updated_at on public.venue_fet_wallets;
create trigger venue_fet_wallets_set_updated_at
before update on public.venue_fet_wallets
for each row execute function public.set_updated_at();

create table if not exists public.venue_checkin_campaigns (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  campaign_name text not null,
  status text not null default 'draft',
  starts_at timestamp with time zone not null,
  ends_at timestamp with time zone not null,
  fet_award_per_checkin integer not null default 0,
  fet_budget integer not null default 0,
  awarded_fet integer not null default 0,
  max_checkins_per_user integer not null default 1,
  require_location boolean not null default false,
  min_location_accuracy_meters integer,
  approved_by uuid,
  approved_at timestamp with time zone,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint venue_checkin_campaigns_status_check check (
    status = any (array['draft', 'pending_review', 'approved', 'paused', 'ended'])
  ),
  constraint venue_checkin_campaigns_window_check check (ends_at > starts_at),
  constraint venue_checkin_campaigns_fet_check check (
    fet_award_per_checkin >= 0 and fet_budget >= 0 and awarded_fet >= 0
  ),
  constraint venue_checkin_campaigns_user_limit_check check (max_checkins_per_user between 1 and 20)
);

create index if not exists idx_venue_campaigns_active
  on public.venue_checkin_campaigns (club_id, venue_id, status, starts_at, ends_at);

drop trigger if exists venue_checkin_campaigns_set_updated_at on public.venue_checkin_campaigns;
create trigger venue_checkin_campaigns_set_updated_at
before update on public.venue_checkin_campaigns
for each row execute function public.set_updated_at();

create table if not exists public.venue_checkin_codes (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  campaign_id uuid not null references public.venue_checkin_campaigns(id) on delete cascade,
  code_hash text not null,
  code_nonce text not null,
  status text not null default 'active',
  rotates_at timestamp with time zone,
  expires_at timestamp with time zone not null,
  created_by uuid,
  created_at timestamp with time zone not null default timezone('utc', now()),
  constraint venue_checkin_codes_status_check check (
    status = any (array['active', 'expired', 'revoked'])
  ),
  constraint venue_checkin_codes_expiry_check check (expires_at > created_at)
);

create unique index if not exists idx_venue_checkin_codes_hash
  on public.venue_checkin_codes (club_id, code_hash);
create index if not exists idx_venue_checkin_codes_campaign
  on public.venue_checkin_codes (campaign_id, status, expires_at);

create table if not exists public.venue_checkins (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  campaign_id uuid references public.venue_checkin_campaigns(id) on delete set null,
  code_id uuid references public.venue_checkin_codes(id) on delete set null,
  user_id uuid not null,
  status text not null default 'confirmed',
  idempotency_key text,
  location_verification_status text not null default 'not_requested',
  location_accuracy_meters numeric,
  fet_awarded integer not null default 0,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  review_reason text,
  metadata jsonb not null default '{}'::jsonb,
  checked_in_at timestamp with time zone not null default timezone('utc', now()),
  created_at timestamp with time zone not null default timezone('utc', now()),
  constraint venue_checkins_status_check check (
    status = any (array['confirmed', 'pending_review', 'rejected', 'reversed'])
  ),
  constraint venue_checkins_location_check check (
    location_verification_status = any (
      array['not_requested', 'verified', 'denied', 'too_far', 'low_accuracy', 'pending_review']
    )
  ),
  constraint venue_checkins_fet_check check (fet_awarded >= 0)
);

create unique index if not exists idx_venue_checkins_idempotency
  on public.venue_checkins (club_id, user_id, idempotency_key)
  where idempotency_key is not null;
create index if not exists idx_venue_checkins_venue_created
  on public.venue_checkins (club_id, venue_id, checked_in_at desc);
create index if not exists idx_venue_checkins_campaign_user
  on public.venue_checkins (club_id, campaign_id, user_id, checked_in_at desc);

create table if not exists public.venue_drink_items (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  item_name text not null,
  description text,
  price_amount integer not null,
  currency_code text not null default 'RWF',
  is_active boolean not null default true,
  is_alcohol boolean not null,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint venue_drink_items_price_check check (price_amount >= 0)
);

create index if not exists idx_venue_drink_items_active
  on public.venue_drink_items (club_id, venue_id, is_active, sort_order);

drop trigger if exists venue_drink_items_set_updated_at on public.venue_drink_items;
create trigger venue_drink_items_set_updated_at
before update on public.venue_drink_items
for each row execute function public.set_updated_at();

create table if not exists public.venue_drink_orders (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  checkin_id uuid references public.venue_checkins(id) on delete set null,
  user_id uuid not null,
  status text not null default 'created',
  idempotency_key text,
  total_amount integer not null default 0,
  currency_code text not null default 'RWF',
  payment_status text not null default 'external_pending',
  age_gate_confirmed boolean not null default false,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint venue_drink_orders_status_check check (
    status = any (array['created', 'accepted', 'preparing', 'ready', 'served', 'cancelled'])
  ),
  constraint venue_drink_orders_payment_check check (
    payment_status = any (array['external_pending', 'externally_paid', 'waived', 'refunded'])
  ),
  constraint venue_drink_orders_total_check check (total_amount >= 0)
);

create unique index if not exists idx_venue_drink_orders_idempotency
  on public.venue_drink_orders (club_id, user_id, idempotency_key)
  where idempotency_key is not null;
create index if not exists idx_venue_drink_orders_queue
  on public.venue_drink_orders (club_id, venue_id, status, created_at);

drop trigger if exists venue_drink_orders_set_updated_at on public.venue_drink_orders;
create trigger venue_drink_orders_set_updated_at
before update on public.venue_drink_orders
for each row execute function public.set_updated_at();

create table if not exists public.venue_drink_order_items (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  order_id uuid not null references public.venue_drink_orders(id) on delete cascade,
  drink_item_id uuid not null references public.venue_drink_items(id) on delete restrict,
  item_name text not null,
  quantity integer not null,
  unit_price_amount integer not null,
  line_total_amount integer not null,
  is_alcohol boolean not null,
  created_at timestamp with time zone not null default timezone('utc', now()),
  constraint venue_drink_order_items_quantity_check check (quantity between 1 and 20),
  constraint venue_drink_order_items_amount_check check (
    unit_price_amount >= 0 and line_total_amount >= 0
  )
);

create index if not exists idx_venue_drink_order_items_order
  on public.venue_drink_order_items (order_id);

create table if not exists public.venue_order_events (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  order_id uuid not null references public.venue_drink_orders(id) on delete cascade,
  event_type text not null,
  from_status text,
  to_status text,
  actor_id uuid,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default timezone('utc', now())
);

create index if not exists idx_venue_order_events_order
  on public.venue_order_events (order_id, created_at);

create table if not exists public.venue_promotion_events (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid not null references public.venues(id) on delete cascade,
  campaign_id uuid references public.venue_checkin_campaigns(id) on delete set null,
  checkin_id uuid references public.venue_checkins(id) on delete set null,
  event_type text not null,
  user_id uuid,
  fet_amount integer not null default 0,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default timezone('utc', now()),
  constraint venue_promotion_events_fet_check check (fet_amount >= 0)
);

create unique index if not exists idx_venue_promotion_events_idempotency
  on public.venue_promotion_events (club_id, venue_id, idempotency_key)
  where idempotency_key is not null;
create index if not exists idx_venue_promotion_events_campaign
  on public.venue_promotion_events (club_id, campaign_id, created_at desc);

create table if not exists public.fet_ledger_reservations (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  venue_id uuid references public.venues(id) on delete set null,
  user_id uuid not null,
  amount integer not null,
  status text not null default 'reserved',
  reference_type text not null,
  reference_id text not null,
  idempotency_key text,
  expires_at timestamp with time zone not null,
  released_at timestamp with time zone,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint fet_ledger_reservations_amount_check check (amount > 0),
  constraint fet_ledger_reservations_status_check check (
    status = any (array['reserved', 'captured', 'released', 'expired', 'reversed'])
  )
);

create unique index if not exists idx_fet_ledger_reservations_idempotency
  on public.fet_ledger_reservations (club_id, user_id, idempotency_key)
  where idempotency_key is not null;
create index if not exists idx_fet_ledger_reservations_reference
  on public.fet_ledger_reservations (club_id, reference_type, reference_id);

drop trigger if exists fet_ledger_reservations_set_updated_at on public.fet_ledger_reservations;
create trigger fet_ledger_reservations_set_updated_at
before update on public.fet_ledger_reservations
for each row execute function public.set_updated_at();

create or replace function public.venue_staff_can_access(
  p_venue_id uuid,
  p_roles text[] default null
) returns boolean
language sql
stable
security definer
set search_path to 'public'
as $$
  select exists (
    select 1
    from public.venue_staff_memberships staff
    where staff.venue_id = p_venue_id
      and staff.user_id = auth.uid()
      and staff.is_active
      and (p_roles is null or staff.role = any (p_roles))
  );
$$;

create or replace function public.venue_enforce_active_drink_limit()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_active_count integer;
begin
  if new.is_active then
    select count(*)
      into v_active_count
      from public.venue_drink_items item
     where item.club_id = new.club_id
       and item.venue_id = new.venue_id
       and item.is_active
       and item.id <> new.id;

    if v_active_count >= 10 then
      raise exception 'A venue can have at most 10 active drinks.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists venue_drink_items_active_limit on public.venue_drink_items;
create trigger venue_drink_items_active_limit
before insert or update on public.venue_drink_items
for each row execute function public.venue_enforce_active_drink_limit();

create or replace function public.venue_checkin_validate(
  p_club_id bigint,
  p_code_hash text,
  p_idempotency_key text default null,
  p_location_accuracy_meters numeric default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_code public.venue_checkin_codes;
  v_campaign public.venue_checkin_campaigns;
  v_checkin public.venue_checkins;
  v_user_id uuid := auth.uid();
  v_now timestamp with time zone := timezone('utc', now());
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_location_status text := 'not_requested';
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'error', 'code', 'auth_required');
  end if;

  if v_idempotency_key is not null then
    select *
      into v_checkin
      from public.venue_checkins
     where club_id = p_club_id
       and user_id = v_user_id
       and idempotency_key = v_idempotency_key
     limit 1;

    if v_checkin.id is not null then
      return jsonb_build_object(
        'status', v_checkin.status,
        'code', 'idempotent_replay',
        'checkin_id', v_checkin.id,
        'venue_id', v_checkin.venue_id,
        'fet_awarded', v_checkin.fet_awarded
      );
    end if;
  end if;

  select *
    into v_code
    from public.venue_checkin_codes
   where club_id = p_club_id
     and code_hash = p_code_hash
   limit 1;

  if v_code.id is null then
    return jsonb_build_object('status', 'error', 'code', 'invalid_code');
  end if;

  if v_code.status <> 'active' or v_code.expires_at <= v_now then
    return jsonb_build_object('status', 'error', 'code', 'expired_code');
  end if;

  select *
    into v_campaign
    from public.venue_checkin_campaigns
   where id = v_code.campaign_id
     and club_id = p_club_id
   limit 1;

  if v_campaign.id is null or v_campaign.status <> 'approved' then
    return jsonb_build_object('status', 'error', 'code', 'campaign_paused');
  end if;

  if v_campaign.starts_at > v_now or v_campaign.ends_at <= v_now then
    return jsonb_build_object('status', 'error', 'code', 'campaign_inactive');
  end if;

  if v_campaign.fet_budget > 0 and
     v_campaign.awarded_fet + v_campaign.fet_award_per_checkin > v_campaign.fet_budget then
    return jsonb_build_object('status', 'error', 'code', 'campaign_budget_exhausted');
  end if;

  if v_campaign.require_location then
    if p_location_accuracy_meters is null then
      v_location_status := 'pending_review';
    elsif v_campaign.min_location_accuracy_meters is not null and
          p_location_accuracy_meters > v_campaign.min_location_accuracy_meters then
      v_location_status := 'low_accuracy';
    else
      v_location_status := 'verified';
    end if;
  end if;

  if (
    select count(*)
    from public.venue_checkins previous
    where previous.club_id = p_club_id
      and previous.campaign_id = v_campaign.id
      and previous.user_id = v_user_id
      and previous.status in ('confirmed', 'pending_review')
  ) >= v_campaign.max_checkins_per_user then
    return jsonb_build_object('status', 'error', 'code', 'already_checked_in');
  end if;

  insert into public.venue_checkins (
    club_id,
    venue_id,
    campaign_id,
    code_id,
    user_id,
    status,
    idempotency_key,
    location_verification_status,
    location_accuracy_meters,
    fet_awarded,
    metadata
  )
  values (
    p_club_id,
    v_code.venue_id,
    v_campaign.id,
    v_code.id,
    v_user_id,
    case when v_location_status in ('pending_review', 'low_accuracy') then 'pending_review' else 'confirmed' end,
    v_idempotency_key,
    v_location_status,
    p_location_accuracy_meters,
    v_campaign.fet_award_per_checkin,
    jsonb_build_object('source', 'venue_checkin_validate')
  )
  returning * into v_checkin;

  update public.venue_checkin_campaigns
     set awarded_fet = awarded_fet + v_campaign.fet_award_per_checkin
   where id = v_campaign.id;

  insert into public.venue_promotion_events (
    club_id,
    venue_id,
    campaign_id,
    checkin_id,
    event_type,
    user_id,
    fet_amount,
    idempotency_key
  )
  values (
    p_club_id,
    v_code.venue_id,
    v_campaign.id,
    v_checkin.id,
    'checkin_reward_recorded',
    v_user_id,
    v_campaign.fet_award_per_checkin,
    v_idempotency_key
  )
  on conflict do nothing;

  return jsonb_build_object(
    'status', v_checkin.status,
    'code', 'ok',
    'checkin_id', v_checkin.id,
    'venue_id', v_checkin.venue_id,
    'campaign_id', v_campaign.id,
    'fet_awarded', v_checkin.fet_awarded,
    'location_verification_status', v_checkin.location_verification_status
  );
end;
$$;

create or replace function public.venue_order_create(
  p_club_id bigint,
  p_venue_id uuid,
  p_checkin_id uuid,
  p_items jsonb,
  p_age_gate_confirmed boolean,
  p_idempotency_key text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_order public.venue_drink_orders;
  v_item jsonb;
  v_drink public.venue_drink_items;
  v_quantity integer;
  v_total integer := 0;
  v_has_alcohol boolean := false;
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'error', 'code', 'auth_required');
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    return jsonb_build_object('status', 'error', 'code', 'items_required');
  end if;

  if v_idempotency_key is not null then
    select *
      into v_order
      from public.venue_drink_orders
     where club_id = p_club_id
       and user_id = v_user_id
       and idempotency_key = v_idempotency_key
     limit 1;

    if v_order.id is not null then
      return jsonb_build_object(
        'status', v_order.status,
        'code', 'idempotent_replay',
        'order_id', v_order.id,
        'total_amount', v_order.total_amount
      );
    end if;
  end if;

  insert into public.venue_drink_orders (
    club_id,
    venue_id,
    checkin_id,
    user_id,
    status,
    idempotency_key,
    total_amount,
    age_gate_confirmed
  )
  values (
    p_club_id,
    p_venue_id,
    p_checkin_id,
    v_user_id,
    'created',
    v_idempotency_key,
    0,
    p_age_gate_confirmed
  )
  returning * into v_order;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_quantity := greatest(coalesce((v_item ->> 'quantity')::integer, 1), 1);

    select *
      into v_drink
      from public.venue_drink_items
     where id = (v_item ->> 'drink_item_id')::uuid
       and club_id = p_club_id
       and venue_id = p_venue_id
       and is_active
     limit 1;

    if v_drink.id is null then
      raise exception 'Drink item is unavailable.';
    end if;

    v_has_alcohol := v_has_alcohol or v_drink.is_alcohol;
    v_total := v_total + (v_drink.price_amount * v_quantity);

    insert into public.venue_drink_order_items (
      club_id,
      venue_id,
      order_id,
      drink_item_id,
      item_name,
      quantity,
      unit_price_amount,
      line_total_amount,
      is_alcohol
    )
    values (
      p_club_id,
      p_venue_id,
      v_order.id,
      v_drink.id,
      v_drink.item_name,
      v_quantity,
      v_drink.price_amount,
      v_drink.price_amount * v_quantity,
      v_drink.is_alcohol
    );
  end loop;

  if v_has_alcohol and not p_age_gate_confirmed then
    raise exception 'Age gate confirmation is required for alcohol items.';
  end if;

  update public.venue_drink_orders
     set total_amount = v_total,
         age_gate_confirmed = p_age_gate_confirmed
   where id = v_order.id
   returning * into v_order;

  insert into public.venue_order_events (
    club_id,
    venue_id,
    order_id,
    event_type,
    to_status,
    actor_id,
    metadata
  )
  values (
    p_club_id,
    p_venue_id,
    v_order.id,
    'order_created',
    'created',
    v_user_id,
    jsonb_build_object('item_count', jsonb_array_length(p_items))
  );

  return jsonb_build_object(
    'status', v_order.status,
    'code', 'ok',
    'order_id', v_order.id,
    'total_amount', v_order.total_amount,
    'currency_code', v_order.currency_code
  );
exception
  when others then
    if v_order.id is not null then
      delete from public.venue_drink_orders where id = v_order.id;
    end if;
    raise;
end;
$$;

create or replace function public.venue_order_update_status(
  p_club_id bigint,
  p_order_id uuid,
  p_status text,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_order public.venue_drink_orders;
  v_previous_status text;
  v_actor uuid := auth.uid();
  v_next_status text := lower(btrim(coalesce(p_status, '')));
begin
  if v_actor is null then
    return jsonb_build_object('status', 'error', 'code', 'auth_required');
  end if;

  select *
    into v_order
    from public.venue_drink_orders
   where id = p_order_id
     and club_id = p_club_id
   for update;

  if v_order.id is null then
    return jsonb_build_object('status', 'error', 'code', 'order_not_found');
  end if;

  if not public.venue_staff_can_access(v_order.venue_id, array['owner', 'manager', 'staff']) and
     not public.is_club_admin(p_club_id) and
     not public.is_super_admin() then
    return jsonb_build_object('status', 'error', 'code', 'permission_denied');
  end if;

  if v_next_status <> all (array['accepted', 'preparing', 'ready', 'served', 'cancelled']) then
    return jsonb_build_object('status', 'error', 'code', 'invalid_status');
  end if;

  v_previous_status := v_order.status;

  update public.venue_drink_orders
     set status = v_next_status
   where id = p_order_id
   returning * into v_order;

  insert into public.venue_order_events (
    club_id,
    venue_id,
    order_id,
    event_type,
    from_status,
    to_status,
    actor_id,
    reason
  )
  values (
    p_club_id,
    v_order.venue_id,
    v_order.id,
    'order_status_changed',
    v_previous_status,
    v_next_status,
    v_actor,
    nullif(btrim(coalesce(p_reason, '')), '')
  );

  return jsonb_build_object(
    'status', v_order.status,
    'code', 'ok',
    'order_id', v_order.id
  );
end;
$$;

alter table public.venues enable row level security;
alter table public.venue_staff_memberships enable row level security;
alter table public.venue_fet_wallets enable row level security;
alter table public.venue_checkin_campaigns enable row level security;
alter table public.venue_checkin_codes enable row level security;
alter table public.venue_checkins enable row level security;
alter table public.venue_drink_items enable row level security;
alter table public.venue_drink_orders enable row level security;
alter table public.venue_drink_order_items enable row level security;
alter table public.venue_order_events enable row level security;
alter table public.venue_promotion_events enable row level security;
alter table public.fet_ledger_reservations enable row level security;

create policy venues_public_approved_read
on public.venues for select
using (status = 'approved' and approved_public_profile);

create policy venues_admin_read
on public.venues for select
to authenticated
using (public.is_club_admin(club_id) or public.is_super_admin() or public.venue_staff_can_access(id));

create policy venue_staff_self_read
on public.venue_staff_memberships for select
to authenticated
using (user_id = auth.uid() or public.is_club_admin(club_id) or public.is_super_admin());

create policy venue_staff_admin_write
on public.venue_staff_memberships for all
to authenticated
using (public.is_club_admin(club_id) or public.is_super_admin())
with check (public.is_club_admin(club_id) or public.is_super_admin());

create policy venue_fet_wallets_staff_admin_read
on public.venue_fet_wallets for select
to authenticated
using (
  public.is_club_admin(club_id) or public.is_super_admin() or
  public.venue_staff_can_access(venue_id, array['owner', 'manager'])
);

create policy venue_campaigns_staff_admin_read
on public.venue_checkin_campaigns for select
to authenticated
using (
  public.is_club_admin(club_id) or public.is_super_admin() or
  public.venue_staff_can_access(venue_id)
);

create policy venue_campaigns_admin_write
on public.venue_checkin_campaigns for all
to authenticated
using (public.is_club_admin(club_id) or public.is_super_admin())
with check (public.is_club_admin(club_id) or public.is_super_admin());

create policy venue_codes_staff_admin_read
on public.venue_checkin_codes for select
to authenticated
using (
  public.is_club_admin(club_id) or public.is_super_admin() or
  public.venue_staff_can_access(venue_id)
);

create policy venue_checkins_owner_staff_admin_read
on public.venue_checkins for select
to authenticated
using (
  user_id = auth.uid() or public.is_club_admin(club_id) or
  public.is_super_admin() or public.venue_staff_can_access(venue_id)
);

create policy venue_drink_items_public_active_read
on public.venue_drink_items for select
using (is_active);

create policy venue_drink_items_staff_admin_write
on public.venue_drink_items for all
to authenticated
using (
  public.is_club_admin(club_id) or public.is_super_admin() or
  public.venue_staff_can_access(venue_id, array['owner', 'manager'])
)
with check (
  public.is_club_admin(club_id) or public.is_super_admin() or
  public.venue_staff_can_access(venue_id, array['owner', 'manager'])
);

create policy venue_orders_owner_staff_admin_read
on public.venue_drink_orders for select
to authenticated
using (
  user_id = auth.uid() or public.is_club_admin(club_id) or
  public.is_super_admin() or public.venue_staff_can_access(venue_id)
);

create policy venue_order_items_owner_staff_admin_read
on public.venue_drink_order_items for select
to authenticated
using (
  exists (
    select 1
    from public.venue_drink_orders orders
    where orders.id = order_id
      and (
        orders.user_id = auth.uid() or public.is_club_admin(orders.club_id) or
        public.is_super_admin() or public.venue_staff_can_access(orders.venue_id)
      )
  )
);

create policy venue_order_events_staff_admin_read
on public.venue_order_events for select
to authenticated
using (
  public.is_club_admin(club_id) or public.is_super_admin() or
  public.venue_staff_can_access(venue_id)
);

create policy venue_promotion_events_staff_admin_read
on public.venue_promotion_events for select
to authenticated
using (
  public.is_club_admin(club_id) or public.is_super_admin() or
  public.venue_staff_can_access(venue_id)
);

create policy fet_reservations_owner_staff_admin_read
on public.fet_ledger_reservations for select
to authenticated
using (
  user_id = auth.uid() or public.is_club_admin(club_id) or
  public.is_super_admin() or (venue_id is not null and public.venue_staff_can_access(venue_id))
);

comment on table public.venues is 'Venue-scoped operator locations for Rayon venue app, TV QR, mobile check-in, and drinks-ordering MVP.';
comment on table public.venue_checkin_codes is 'Stores hashed rotating TV/QR check-in codes only. Raw codes must never be persisted.';
comment on table public.venue_drink_items is 'Drinks-only MVP menu. Server trigger enforces at most 10 active drinks per venue.';
comment on table public.fet_ledger_reservations is 'Closed-loop FET reservation records for future reward/spend flows; no cash-out semantics.';

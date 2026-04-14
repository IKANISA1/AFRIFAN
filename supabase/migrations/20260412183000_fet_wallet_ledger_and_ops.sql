-- FET wallet ledger, supporter transfer/redeem flows, and admin wallet operations.
-- Keeps public.fan_memberships.points as the current balance while adding an auditable
-- transaction history for supporter-facing wallet journeys and admin investigations.

create table if not exists public.fet_wallet_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  membership_id uuid references public.fan_memberships(id) on delete set null,
  entry_type text not null,
  direction text not null,
  amount integer not null,
  balance_after integer not null,
  counterparty_user_id uuid references public.users(id) on delete set null,
  reference_type text,
  reference_id text,
  idempotency_key text,
  note text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamp with time zone not null default timezone('utc', now()),
  updated_at timestamp with time zone not null default timezone('utc', now()),
  constraint fet_wallet_ledger_entries_type_check check (
    entry_type = any (
      array[
        'earn'::text,
        'transfer_in'::text,
        'transfer_out'::text,
        'redeem'::text,
        'admin_adjustment'::text,
        'opening_balance'::text
      ]
    )
  ),
  constraint fet_wallet_ledger_entries_direction_check check (
    direction = any (array['credit'::text, 'debit'::text])
  ),
  constraint fet_wallet_ledger_entries_amount_check check (amount > 0),
  constraint fet_wallet_ledger_entries_balance_after_check check (balance_after >= 0)
);

create index if not exists idx_fet_wallet_ledger_entries_user_created
  on public.fet_wallet_ledger_entries (club_id, user_id, created_at desc, id desc);

create index if not exists idx_fet_wallet_ledger_entries_counterparty
  on public.fet_wallet_ledger_entries (club_id, counterparty_user_id, created_at desc);

create unique index if not exists idx_fet_wallet_ledger_entries_idempotency
  on public.fet_wallet_ledger_entries (club_id, user_id, idempotency_key)
  where idempotency_key is not null;

drop trigger if exists fet_wallet_ledger_entries_set_updated_at on public.fet_wallet_ledger_entries;
create trigger fet_wallet_ledger_entries_set_updated_at
before update on public.fet_wallet_ledger_entries
for each row execute function public.set_updated_at();

comment on table public.fet_wallet_ledger_entries is 'Auditable supporter FET wallet ledger. fan_memberships.points remains the current wallet balance.';
comment on column public.fet_wallet_ledger_entries.entry_type is 'Wallet operation type: earn, transfer_in, transfer_out, redeem, admin_adjustment, or opening_balance.';
comment on column public.fet_wallet_ledger_entries.idempotency_key is 'Optional client-generated operation key used to make transfer/redeem/admin actions retry-safe.';

alter table public.fet_wallet_ledger_entries enable row level security;

drop policy if exists fet_wallet_ledger_entries_owner_read on public.fet_wallet_ledger_entries;
create policy fet_wallet_ledger_entries_owner_read
on public.fet_wallet_ledger_entries
for select
using (
  auth.uid() = user_id
  and club_id::text = public.requesting_club_id()
);

drop policy if exists fet_wallet_ledger_entries_admin_read on public.fet_wallet_ledger_entries;
create policy fet_wallet_ledger_entries_admin_read
on public.fet_wallet_ledger_entries
for select
to authenticated
using (public.is_club_admin(club_id) or public.is_super_admin());

create or replace function public.fet_require_club_context(
  p_club_id bigint default null
) returns bigint
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint;
begin
  v_club_id := coalesce(
    p_club_id,
    nullif(public.requesting_club_id(), '')::bigint,
    (
      select p.club_id
      from public.profiles p
      where p.id = auth.uid()
      limit 1
    )
  );

  if v_club_id is null then
    raise exception 'Club context required for FET wallet operations.';
  end if;

  return v_club_id;
end;
$$;

create or replace function public.fet_wallet_resolve_partner_id(
  p_club_id bigint,
  p_partner_hint text default null
) returns uuid
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_partner_id uuid;
begin
  if nullif(btrim(coalesce(p_partner_hint, '')), '') ~*
    '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
    v_partner_id := lower(btrim(p_partner_hint))::uuid;
  end if;

  if v_partner_id is null then
    v_partner_id := (public.resolve_partner_ids_for_club(p_club_id))[1];
  end if;

  if v_partner_id is null then
    raise exception 'Partner scope required for club %.', p_club_id;
  end if;

  return v_partner_id;
end;
$$;

create or replace function public.fet_wallet_ensure_membership(
  p_user_id uuid,
  p_club_id bigint
) returns public.fan_memberships
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_membership public.fan_memberships;
begin
  insert into public.fan_memberships (
    user_id,
    club_id,
    partner_id,
    tier,
    points,
    renewed_at
  )
  values (
    p_user_id,
    p_club_id,
    public.fet_wallet_resolve_partner_id(p_club_id, null),
    public.resolve_fan_tier(0),
    0,
    timezone('utc', now())
  )
  on conflict (user_id, club_id)
  do update set updated_at = public.fan_memberships.updated_at
  returning * into v_membership;

  return v_membership;
end;
$$;

create or replace function public.fet_wallet_append_entry(
  p_club_id bigint,
  p_user_id uuid,
  p_membership_id uuid,
  p_entry_type text,
  p_direction text,
  p_amount integer,
  p_balance_after integer,
  p_counterparty_user_id uuid default null,
  p_reference_type text default null,
  p_reference_id text default null,
  p_idempotency_key text default null,
  p_note text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_created_by uuid default null
) returns public.fet_wallet_ledger_entries
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_entry public.fet_wallet_ledger_entries;
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
begin
  insert into public.fet_wallet_ledger_entries (
    club_id,
    user_id,
    membership_id,
    entry_type,
    direction,
    amount,
    balance_after,
    counterparty_user_id,
    reference_type,
    reference_id,
    idempotency_key,
    note,
    metadata,
    created_by
  )
  values (
    p_club_id,
    p_user_id,
    p_membership_id,
    lower(btrim(coalesce(p_entry_type, ''))),
    lower(btrim(coalesce(p_direction, ''))),
    greatest(coalesce(p_amount, 0), 0),
    greatest(coalesce(p_balance_after, 0), 0),
    p_counterparty_user_id,
    nullif(btrim(coalesce(p_reference_type, '')), ''),
    nullif(btrim(coalesce(p_reference_id, '')), ''),
    v_idempotency_key,
    nullif(btrim(coalesce(p_note, '')), ''),
    coalesce(p_metadata, '{}'::jsonb),
    p_created_by
  )
  returning * into v_entry;

  return v_entry;
exception
  when unique_violation then
    if v_idempotency_key is null then
      raise;
    end if;

    select *
      into v_entry
      from public.fet_wallet_ledger_entries
     where club_id = p_club_id
       and user_id = p_user_id
       and idempotency_key = v_idempotency_key
     order by created_at desc, id desc
     limit 1;

    if v_entry.id is null then
      raise;
    end if;

    return v_entry;
end;
$$;

create or replace function public.add_fan_points(
  p_user_id uuid,
  p_partner_id text,
  p_points integer,
  p_reason text default null::text
) returns public.fan_memberships
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint;
  v_membership public.fan_memberships;
  v_points integer := greatest(coalesce(p_points, 0), 0);
  v_reason text := coalesce(nullif(trim(coalesce(p_reason, '')), ''), 'manual_adjustment');
begin
  v_club_id := coalesce(
    public.compat_parse_partner_id(p_partner_id),
    nullif(public.requesting_club_id(), '')::bigint
  );

  if v_club_id is null then
    raise exception 'Club context required for fan points.';
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
    v_club_id,
    public.fet_wallet_resolve_partner_id(v_club_id, p_partner_id),
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
  values (
    p_user_id,
    v_club_id,
    v_reason,
    v_points,
    jsonb_build_object(
      'reason',
      p_reason,
      'source',
      'add_fan_points',
      'source_table',
      'cool_events'
    ),
    timezone('utc', now())
  );

  if v_points > 0 then
    perform public.fet_wallet_append_entry(
      p_club_id := v_club_id,
      p_user_id := p_user_id,
      p_membership_id := v_membership.id,
      p_entry_type := 'earn',
      p_direction := 'credit',
      p_amount := v_points,
      p_balance_after := v_membership.points,
      p_counterparty_user_id := null,
      p_reference_type := 'cool_event',
      p_reference_id := v_reason,
      p_idempotency_key := null,
      p_note := v_reason,
      p_metadata := jsonb_build_object('reason', p_reason, 'source', 'add_fan_points'),
      p_created_by := auth.uid()
    );
  end if;

  return v_membership;
end;
$$;

create or replace function public.fet_get_wallet(
  p_club_id bigint default null
) returns table(
  user_id uuid,
  club_id bigint,
  membership_id uuid,
  balance integer,
  tier text,
  weekly_earned integer,
  monthly_earned integer,
  lifetime_earned integer,
  lifetime_spent integer,
  transaction_count integer,
  legacy_balance_gap integer
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_membership public.fan_memberships;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);
  perform public.fet_wallet_ensure_membership(v_user_id, v_club_id);

  select *
    into v_membership
    from public.fan_memberships
   where fan_memberships.user_id = v_user_id
     and fan_memberships.club_id = v_club_id
   limit 1;

  return query
  with ledger as (
    select e.*
    from public.fet_wallet_ledger_entries e
    where e.club_id = v_club_id
      and e.user_id = v_user_id
  ),
  aggregates as (
    select
      coalesce(sum(case when direction = 'credit' and entry_type = 'earn' and created_at >= timezone('utc', now()) - interval '7 days' then amount else 0 end), 0)::integer as weekly_earned,
      coalesce(sum(case when direction = 'credit' and entry_type = 'earn' and created_at >= timezone('utc', now()) - interval '30 days' then amount else 0 end), 0)::integer as monthly_earned,
      coalesce(sum(case when direction = 'credit' then amount else 0 end), 0)::integer as lifetime_earned,
      coalesce(sum(case when direction = 'debit' then amount else 0 end), 0)::integer as lifetime_spent,
      count(*)::integer as transaction_count,
      coalesce(sum(case when direction = 'credit' then amount else -amount end), 0)::integer as ledger_net
    from ledger
  )
  select
    v_user_id,
    v_club_id,
    v_membership.id,
    coalesce(v_membership.points, 0)::integer,
    coalesce(v_membership.tier, public.resolve_fan_tier(coalesce(v_membership.points, 0))),
    aggregates.weekly_earned,
    aggregates.monthly_earned,
    greatest(aggregates.lifetime_earned, coalesce(v_membership.points, 0))::integer,
    aggregates.lifetime_spent,
    aggregates.transaction_count,
    greatest(coalesce(v_membership.points, 0) - greatest(aggregates.ledger_net, 0), 0)::integer
  from aggregates;
end;
$$;

create or replace function public.fet_get_wallet_transactions(
  p_club_id bigint default null,
  p_limit integer default 50,
  p_offset integer default 0
) returns table(
  id uuid,
  entry_type text,
  direction text,
  amount integer,
  balance_after integer,
  counterparty_user_id uuid,
  counterparty_display_name text,
  counterparty_public_user_id text,
  note text,
  reference_type text,
  reference_id text,
  created_at timestamp with time zone,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  return query
  with scoped as (
    select
      e.id,
      e.entry_type,
      e.direction,
      e.amount,
      e.balance_after,
      e.counterparty_user_id,
      coalesce(
        nullif(btrim(cp.display_name), ''),
        nullif(btrim(cp.full_name), ''),
        nullif(btrim(cu.public_user_id), ''),
        'Supporter'
      ) as counterparty_display_name,
      cp.public_user_id as counterparty_public_user_id,
      e.note,
      e.reference_type,
      e.reference_id,
      e.created_at,
      count(*) over() as total_count
    from public.fet_wallet_ledger_entries e
    left join public.profiles cp
      on cp.id = e.counterparty_user_id
    left join public.users cu
      on cu.id = e.counterparty_user_id
    where e.club_id = v_club_id
      and e.user_id = v_user_id
  )
  select
    scoped.id,
    scoped.entry_type,
    scoped.direction,
    scoped.amount,
    scoped.balance_after,
    scoped.counterparty_user_id,
    scoped.counterparty_display_name,
    scoped.counterparty_public_user_id,
    scoped.note,
    scoped.reference_type,
    scoped.reference_id,
    scoped.created_at,
    scoped.total_count
  from scoped
  order by scoped.created_at desc, scoped.id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.fet_find_supporters(
  p_query text,
  p_club_id bigint default null,
  p_limit integer default 8
) returns table(
  user_id uuid,
  public_user_id text,
  display_name text,
  tier text,
  balance integer
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_query text := nullif(btrim(coalesce(p_query, '')), '');
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if v_query is null then
    return;
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  return query
  with scoped as (
    select
      p.id as user_id,
      coalesce(nullif(btrim(p.public_user_id), ''), u.public_user_id) as public_user_id,
      coalesce(
        nullif(btrim(p.display_name), ''),
        nullif(btrim(p.full_name), ''),
        nullif(btrim(u.public_user_id), ''),
        'Supporter'
      ) as display_name,
      coalesce(fm.tier, public.resolve_fan_tier(coalesce(fm.points, 0))) as tier,
      coalesce(fm.points, 0)::integer as balance
    from public.profiles p
    left join public.users u
      on u.id = p.id
    left join public.fan_memberships fm
      on fm.user_id = p.id
     and fm.club_id = v_club_id
    where p.club_id = v_club_id
      and p.id <> v_user_id
      and (
        coalesce(p.public_user_id, '') ilike '%' || v_query || '%'
        or coalesce(p.display_name, '') ilike '%' || v_query || '%'
        or coalesce(p.full_name, '') ilike '%' || v_query || '%'
        or coalesce(p.phone, '') ilike '%' || v_query || '%'
      )
  )
  select
    scoped.user_id,
    scoped.public_user_id,
    scoped.display_name,
    scoped.tier,
    scoped.balance
  from scoped
  order by scoped.balance desc, scoped.display_name asc
  limit greatest(coalesce(p_limit, 8), 1);
end;
$$;

create or replace function public.fet_transfer(
  p_recipient_user_id uuid,
  p_amount integer,
  p_note text default null,
  p_idempotency_key text default null,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_sender_id uuid := auth.uid();
  v_club_id bigint;
  v_sender public.fan_memberships;
  v_recipient public.fan_memberships;
  v_existing public.fet_wallet_ledger_entries;
  v_amount integer := greatest(coalesce(p_amount, 0), 0);
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_reference_id text := gen_random_uuid()::text;
begin
  if v_sender_id is null then
    raise exception 'Authentication is required.';
  end if;

  if p_recipient_user_id is null then
    raise exception 'Recipient is required.';
  end if;

  if p_recipient_user_id = v_sender_id then
    raise exception 'You cannot transfer FET to yourself.';
  end if;

  if v_amount <= 0 then
    raise exception 'Transfer amount must be greater than zero.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  if v_idempotency_key is not null then
    select *
      into v_existing
      from public.fet_wallet_ledger_entries e
     where e.club_id = v_club_id
       and e.user_id = v_sender_id
       and e.idempotency_key = v_idempotency_key
       and e.entry_type = 'transfer_out'
     order by e.created_at desc, e.id desc
     limit 1;

    if v_existing.id is not null then
      return jsonb_build_object(
        'status', 'success',
        'already_processed', true,
        'amount', v_existing.amount,
        'balance', v_existing.balance_after,
        'reference_id', v_existing.reference_id
      );
    end if;
  end if;

  perform public.fet_wallet_ensure_membership(v_sender_id, v_club_id);
  perform public.fet_wallet_ensure_membership(p_recipient_user_id, v_club_id);

  select *
    into v_sender
    from public.fan_memberships
   where user_id = v_sender_id
     and club_id = v_club_id
   for update;

  select *
    into v_recipient
    from public.fan_memberships
   where user_id = p_recipient_user_id
     and club_id = v_club_id
   for update;

  if coalesce(v_sender.points, 0) < v_amount then
    raise exception 'Insufficient FET balance.';
  end if;

  update public.fan_memberships
     set points = points - v_amount,
         tier = public.resolve_fan_tier(points - v_amount),
         updated_at = timezone('utc', now())
   where id = v_sender.id
  returning * into v_sender;

  update public.fan_memberships
     set points = points + v_amount,
         tier = public.resolve_fan_tier(points + v_amount),
         renewed_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
   where id = v_recipient.id
  returning * into v_recipient;

  perform public.fet_wallet_append_entry(
    p_club_id := v_club_id,
    p_user_id := v_sender_id,
    p_membership_id := v_sender.id,
    p_entry_type := 'transfer_out',
    p_direction := 'debit',
    p_amount := v_amount,
    p_balance_after := v_sender.points,
    p_counterparty_user_id := p_recipient_user_id,
    p_reference_type := 'transfer',
    p_reference_id := v_reference_id,
    p_idempotency_key := v_idempotency_key,
    p_note := v_note,
    p_metadata := jsonb_build_object('channel', 'wallet_transfer'),
    p_created_by := v_sender_id
  );

  perform public.fet_wallet_append_entry(
    p_club_id := v_club_id,
    p_user_id := p_recipient_user_id,
    p_membership_id := v_recipient.id,
    p_entry_type := 'transfer_in',
    p_direction := 'credit',
    p_amount := v_amount,
    p_balance_after := v_recipient.points,
    p_counterparty_user_id := v_sender_id,
    p_reference_type := 'transfer',
    p_reference_id := v_reference_id,
    p_idempotency_key := v_idempotency_key,
    p_note := v_note,
    p_metadata := jsonb_build_object('channel', 'wallet_transfer'),
    p_created_by := v_sender_id
  );

  return jsonb_build_object(
    'status', 'success',
    'amount', v_amount,
    'balance', v_sender.points,
    'reference_id', v_reference_id,
    'recipient_user_id', p_recipient_user_id
  );
end;
$$;

create or replace function public.fet_redeem(
  p_amount integer,
  p_note text default null,
  p_idempotency_key text default null,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_membership public.fan_memberships;
  v_existing public.fet_wallet_ledger_entries;
  v_amount integer := greatest(coalesce(p_amount, 0), 0);
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_reference_id text := gen_random_uuid()::text;
begin
  if v_user_id is null then
    raise exception 'Authentication is required.';
  end if;

  if v_amount <= 0 then
    raise exception 'Redemption amount must be greater than zero.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  if v_idempotency_key is not null then
    select *
      into v_existing
      from public.fet_wallet_ledger_entries e
     where e.club_id = v_club_id
       and e.user_id = v_user_id
       and e.idempotency_key = v_idempotency_key
       and e.entry_type = 'redeem'
     order by e.created_at desc, e.id desc
     limit 1;

    if v_existing.id is not null then
      return jsonb_build_object(
        'status', 'success',
        'already_processed', true,
        'amount', v_existing.amount,
        'balance', v_existing.balance_after,
        'reference_id', v_existing.reference_id
      );
    end if;
  end if;

  perform public.fet_wallet_ensure_membership(v_user_id, v_club_id);

  select *
    into v_membership
    from public.fan_memberships
   where user_id = v_user_id
     and club_id = v_club_id
   for update;

  if coalesce(v_membership.points, 0) < v_amount then
    raise exception 'Insufficient FET balance.';
  end if;

  update public.fan_memberships
     set points = points - v_amount,
         tier = public.resolve_fan_tier(points - v_amount),
         updated_at = timezone('utc', now())
   where id = v_membership.id
  returning * into v_membership;

  perform public.fet_wallet_append_entry(
    p_club_id := v_club_id,
    p_user_id := v_user_id,
    p_membership_id := v_membership.id,
    p_entry_type := 'redeem',
    p_direction := 'debit',
    p_amount := v_amount,
    p_balance_after := v_membership.points,
    p_counterparty_user_id := null,
    p_reference_type := 'redemption',
    p_reference_id := v_reference_id,
    p_idempotency_key := v_idempotency_key,
    p_note := coalesce(v_note, 'Wallet redemption request'),
    p_metadata := jsonb_build_object('channel', 'wallet_redemption'),
    p_created_by := v_user_id
  );

  return jsonb_build_object(
    'status', 'success',
    'amount', v_amount,
    'balance', v_membership.points,
    'reference_id', v_reference_id
  );
end;
$$;

create or replace function public.fet_admin_adjust_balance(
  p_user_id uuid,
  p_amount integer,
  p_reason text,
  p_idempotency_key text default null,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_caller_id uuid := auth.uid();
  v_club_id bigint;
  v_membership public.fan_memberships;
  v_existing public.fet_wallet_ledger_entries;
  v_amount integer := coalesce(p_amount, 0);
  v_abs_amount integer := abs(coalesce(p_amount, 0));
  v_reason text := nullif(btrim(coalesce(p_reason, '')), '');
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
  v_direction text;
  v_reference_id text := gen_random_uuid()::text;
begin
  if v_caller_id is null then
    raise exception 'Authentication is required.';
  end if;

  v_club_id := public.fet_require_club_context(p_club_id);

  if not (public.is_club_admin(v_club_id) or public.is_super_admin()) then
    raise exception 'Club admin access is required.';
  end if;

  if p_user_id is null then
    raise exception 'A target user is required.';
  end if;

  if v_reason is null then
    raise exception 'Adjustment reason is required.';
  end if;

  if v_abs_amount = 0 then
    raise exception 'Adjustment amount must be non-zero.';
  end if;

  if v_idempotency_key is not null then
    select *
      into v_existing
      from public.fet_wallet_ledger_entries e
     where e.club_id = v_club_id
       and e.user_id = p_user_id
       and e.idempotency_key = v_idempotency_key
       and e.entry_type = 'admin_adjustment'
     order by e.created_at desc, e.id desc
     limit 1;

    if v_existing.id is not null then
      return jsonb_build_object(
        'status', 'success',
        'already_processed', true,
        'amount', case when v_existing.direction = 'debit' then -v_existing.amount else v_existing.amount end,
        'balance', v_existing.balance_after,
        'reference_id', v_existing.reference_id
      );
    end if;
  end if;

  perform public.fet_wallet_ensure_membership(p_user_id, v_club_id);

  select *
    into v_membership
    from public.fan_memberships
   where user_id = p_user_id
     and club_id = v_club_id
   for update;

  if v_amount < 0 and coalesce(v_membership.points, 0) < v_abs_amount then
    raise exception 'Adjustment would overdraw the supporter wallet.';
  end if;

  if v_amount > 0 then
    update public.fan_memberships
       set points = points + v_abs_amount,
           tier = public.resolve_fan_tier(points + v_abs_amount),
           renewed_at = timezone('utc', now()),
           updated_at = timezone('utc', now())
     where id = v_membership.id
    returning * into v_membership;
    v_direction := 'credit';

    insert into public.xp_events (
      user_id,
      club_id,
      event_type,
      xp_awarded,
      metadata,
      event_at
    )
    values (
      p_user_id,
      v_club_id,
      'admin_adjustment',
      v_abs_amount,
      jsonb_build_object(
        'reason',
        v_reason,
        'source',
        'fet_admin_adjust_balance',
        'source_table',
        'cool_events'
      ),
      timezone('utc', now())
    );
  else
    update public.fan_memberships
       set points = points - v_abs_amount,
           tier = public.resolve_fan_tier(points - v_abs_amount),
           updated_at = timezone('utc', now())
     where id = v_membership.id
    returning * into v_membership;
    v_direction := 'debit';
  end if;

  perform public.fet_wallet_append_entry(
    p_club_id := v_club_id,
    p_user_id := p_user_id,
    p_membership_id := v_membership.id,
    p_entry_type := 'admin_adjustment',
    p_direction := v_direction,
    p_amount := v_abs_amount,
    p_balance_after := v_membership.points,
    p_counterparty_user_id := null,
    p_reference_type := 'admin_adjustment',
    p_reference_id := v_reference_id,
    p_idempotency_key := v_idempotency_key,
    p_note := v_reason,
    p_metadata := jsonb_build_object('requested_amount', v_amount),
    p_created_by := v_caller_id
  );

  return jsonb_build_object(
    'status', 'success',
    'amount', v_amount,
    'balance', v_membership.points,
    'reference_id', v_reference_id
  );
end;
$$;

create or replace function public.fet_admin_get_wallet_overview(
  p_club_id bigint default null,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
) returns table(
  user_id uuid,
  public_user_id text,
  display_name text,
  tier text,
  balance integer,
  transaction_count integer,
  last_transaction_at timestamp with time zone,
  lifetime_earned integer,
  lifetime_spent integer,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint;
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
begin
  v_club_id := public.fet_require_club_context(p_club_id);

  if not (public.is_club_admin(v_club_id) or public.is_super_admin()) then
    raise exception 'Club admin access is required.';
  end if;

  return query
  with ledger_agg as (
    select
      e.user_id,
      count(*)::integer as transaction_count,
      max(e.created_at) as last_transaction_at,
      coalesce(sum(case when e.direction = 'credit' then e.amount else 0 end), 0)::integer as lifetime_earned,
      coalesce(sum(case when e.direction = 'debit' then e.amount else 0 end), 0)::integer as lifetime_spent
    from public.fet_wallet_ledger_entries e
    where e.club_id = v_club_id
    group by e.user_id
  ),
  scoped as (
    select
      p.id as user_id,
      coalesce(nullif(btrim(p.public_user_id), ''), u.public_user_id) as public_user_id,
      coalesce(
        nullif(btrim(p.display_name), ''),
        nullif(btrim(p.full_name), ''),
        nullif(btrim(u.public_user_id), ''),
        'Supporter'
      ) as display_name,
      coalesce(fm.tier, public.resolve_fan_tier(coalesce(fm.points, 0))) as tier,
      coalesce(fm.points, 0)::integer as balance,
      coalesce(la.transaction_count, 0)::integer as transaction_count,
      la.last_transaction_at,
      greatest(coalesce(la.lifetime_earned, 0), coalesce(fm.points, 0))::integer as lifetime_earned,
      coalesce(la.lifetime_spent, 0)::integer as lifetime_spent,
      count(*) over() as total_count
    from public.profiles p
    left join public.users u
      on u.id = p.id
    left join public.fan_memberships fm
      on fm.user_id = p.id
     and fm.club_id = v_club_id
    left join ledger_agg la
      on la.user_id = p.id
    where p.club_id = v_club_id
      and (
        v_search is null
        or coalesce(p.public_user_id, '') ilike '%' || v_search || '%'
        or coalesce(p.display_name, '') ilike '%' || v_search || '%'
        or coalesce(p.full_name, '') ilike '%' || v_search || '%'
        or coalesce(p.phone, '') ilike '%' || v_search || '%'
      )
  )
  select
    scoped.user_id,
    scoped.public_user_id,
    scoped.display_name,
    scoped.tier,
    scoped.balance,
    scoped.transaction_count,
    scoped.last_transaction_at,
    scoped.lifetime_earned,
    scoped.lifetime_spent,
    scoped.total_count
  from scoped
  order by scoped.balance desc, scoped.display_name asc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.fet_admin_get_wallet_ledger(
  p_club_id bigint default null,
  p_search text default null,
  p_user_id uuid default null,
  p_limit integer default 100,
  p_offset integer default 0
) returns table(
  id uuid,
  user_id uuid,
  public_user_id text,
  display_name text,
  entry_type text,
  direction text,
  amount integer,
  balance_after integer,
  counterparty_user_id uuid,
  counterparty_display_name text,
  counterparty_public_user_id text,
  note text,
  reference_type text,
  reference_id text,
  created_at timestamp with time zone,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path to 'public'
as $$
declare
  v_club_id bigint;
  v_search text := nullif(btrim(coalesce(p_search, '')), '');
begin
  v_club_id := public.fet_require_club_context(p_club_id);

  if not (public.is_club_admin(v_club_id) or public.is_super_admin()) then
    raise exception 'Club admin access is required.';
  end if;

  return query
  with scoped as (
    select
      e.id,
      e.user_id,
      coalesce(nullif(btrim(p.public_user_id), ''), u.public_user_id) as public_user_id,
      coalesce(
        nullif(btrim(p.display_name), ''),
        nullif(btrim(p.full_name), ''),
        nullif(btrim(u.public_user_id), ''),
        'Supporter'
      ) as display_name,
      e.entry_type,
      e.direction,
      e.amount,
      e.balance_after,
      e.counterparty_user_id,
      coalesce(
        nullif(btrim(cp.display_name), ''),
        nullif(btrim(cp.full_name), ''),
        nullif(btrim(cu.public_user_id), ''),
        'Supporter'
      ) as counterparty_display_name,
      coalesce(nullif(btrim(cp.public_user_id), ''), cu.public_user_id) as counterparty_public_user_id,
      e.note,
      e.reference_type,
      e.reference_id,
      e.created_at,
      count(*) over() as total_count
    from public.fet_wallet_ledger_entries e
    left join public.profiles p
      on p.id = e.user_id
    left join public.users u
      on u.id = e.user_id
    left join public.profiles cp
      on cp.id = e.counterparty_user_id
    left join public.users cu
      on cu.id = e.counterparty_user_id
    where e.club_id = v_club_id
      and (p_user_id is null or e.user_id = p_user_id)
      and (
        v_search is null
        or coalesce(p.public_user_id, '') ilike '%' || v_search || '%'
        or coalesce(p.display_name, '') ilike '%' || v_search || '%'
        or coalesce(p.full_name, '') ilike '%' || v_search || '%'
        or coalesce(cp.public_user_id, '') ilike '%' || v_search || '%'
        or coalesce(cp.display_name, '') ilike '%' || v_search || '%'
        or coalesce(cp.full_name, '') ilike '%' || v_search || '%'
        or coalesce(e.reference_id, '') ilike '%' || v_search || '%'
      )
  )
  select
    scoped.id,
    scoped.user_id,
    scoped.public_user_id,
    scoped.display_name,
    scoped.entry_type,
    scoped.direction,
    scoped.amount,
    scoped.balance_after,
    scoped.counterparty_user_id,
    scoped.counterparty_display_name,
    scoped.counterparty_public_user_id,
    scoped.note,
    scoped.reference_type,
    scoped.reference_id,
    scoped.created_at,
    scoped.total_count
  from scoped
  order by scoped.created_at desc, scoped.id desc
  limit greatest(coalesce(p_limit, 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.fet_require_club_context(bigint) to authenticated;
grant execute on function public.fet_require_club_context(bigint) to service_role;
grant execute on function public.fet_wallet_resolve_partner_id(bigint, text) to authenticated;
grant execute on function public.fet_wallet_resolve_partner_id(bigint, text) to service_role;
grant execute on function public.fet_wallet_ensure_membership(uuid, bigint) to authenticated;
grant execute on function public.fet_wallet_ensure_membership(uuid, bigint) to service_role;
grant execute on function public.fet_wallet_append_entry(bigint, uuid, uuid, text, text, integer, integer, uuid, text, text, text, text, jsonb, uuid) to authenticated;
grant execute on function public.fet_wallet_append_entry(bigint, uuid, uuid, text, text, integer, integer, uuid, text, text, text, text, jsonb, uuid) to service_role;
grant execute on function public.fet_get_wallet(bigint) to authenticated;
grant execute on function public.fet_get_wallet(bigint) to service_role;
grant execute on function public.fet_get_wallet_transactions(bigint, integer, integer) to authenticated;
grant execute on function public.fet_get_wallet_transactions(bigint, integer, integer) to service_role;
grant execute on function public.fet_find_supporters(text, bigint, integer) to authenticated;
grant execute on function public.fet_find_supporters(text, bigint, integer) to service_role;
grant execute on function public.fet_transfer(uuid, integer, text, text, bigint) to authenticated;
grant execute on function public.fet_transfer(uuid, integer, text, text, bigint) to service_role;
grant execute on function public.fet_redeem(integer, text, text, bigint) to authenticated;
grant execute on function public.fet_redeem(integer, text, text, bigint) to service_role;
grant execute on function public.fet_admin_adjust_balance(uuid, integer, text, text, bigint) to authenticated;
grant execute on function public.fet_admin_adjust_balance(uuid, integer, text, text, bigint) to service_role;
grant execute on function public.fet_admin_get_wallet_overview(bigint, text, integer, integer) to authenticated;
grant execute on function public.fet_admin_get_wallet_overview(bigint, text, integer, integer) to service_role;
grant execute on function public.fet_admin_get_wallet_ledger(bigint, text, uuid, integer, integer) to authenticated;
grant execute on function public.fet_admin_get_wallet_ledger(bigint, text, uuid, integer, integer) to service_role;

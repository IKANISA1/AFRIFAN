begin;

-- Ticket purchase and lifecycle changes are RPC-only. The previous clean
-- replay had no usable Data API DML grant for purchases, while ten overlapping
-- legacy policies still described broad direct-update paths. Reset both sides
-- of that contradiction before exposing the minimum read surface.
revoke all privileges on table public.tickets
from public, anon, authenticated, service_role;

grant select (
  id,
  match_id,
  user_id,
  seat_type,
  amount_paid,
  qr_code,
  momo_reference,
  status,
  purchased_at,
  updated_at,
  club_id,
  created_at,
  confirmed_at
) on table public.tickets to authenticated;

grant all privileges on table public.tickets to service_role;

-- Production had drifted to table-wide ALL privileges for both API roles.
-- Reset that surface before granting the public fixture projection and the
-- smaller authenticated editor contract. Column grants keep internal mock and
-- media-rights governance fields out of both public and supporter queries.
revoke all privileges on table public.matches
from public, anon, authenticated, service_role;

grant select (
  id,
  home_team,
  away_team,
  competition,
  venue,
  match_date,
  kickoff_time,
  is_on_sale,
  ticket_general_price,
  ticket_vip_price,
  capacity,
  sold_count,
  image_url,
  club_id,
  match_status,
  home_score,
  away_score,
  live_minute,
  live_stats,
  live_events,
  is_featured,
  fixture_id
) on table public.matches to anon, authenticated;

grant select (
  partner_id,
  sale_starts_at,
  roster,
  match_summary
) on table public.matches to authenticated;

grant insert (
  partner_id,
  home_team,
  away_team,
  competition,
  venue,
  match_date,
  kickoff_time,
  is_on_sale,
  ticket_general_price,
  ticket_vip_price,
  capacity,
  match_status,
  home_score,
  away_score,
  live_minute,
  match_summary
) on table public.matches to authenticated;

grant update (
  partner_id,
  home_team,
  away_team,
  competition,
  venue,
  match_date,
  kickoff_time,
  is_on_sale,
  ticket_general_price,
  ticket_vip_price,
  capacity,
  match_status,
  home_score,
  away_score,
  live_minute,
  match_summary
) on table public.matches to authenticated;

grant all privileges on table public.matches to service_role;

drop policy if exists matches_admin_all on public.matches;
drop policy if exists matches_public_read on public.matches;
drop policy if exists matches_select_club on public.matches;
drop policy if exists rs_matches_delete_admin on public.matches;
drop policy if exists rs_matches_insert_admin on public.matches;
drop policy if exists rs_matches_select_authenticated on public.matches;
drop policy if exists rs_matches_update_admin on public.matches;

create policy matches_public_read
on public.matches
for select
to anon, authenticated
using (true);

create policy matches_admin_insert
on public.matches
for insert
to authenticated
with check (
  club_id::text = public.requesting_club_id()
  and public.is_club_admin(club_id)
);

create policy matches_admin_update
on public.matches
for update
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and public.is_club_admin(club_id)
)
with check (
  club_id::text = public.requesting_club_id()
  and public.is_club_admin(club_id)
);

drop policy if exists rs_tickets_delete_admin on public.tickets;
drop policy if exists rs_tickets_insert_own on public.tickets;
drop policy if exists rs_tickets_select_own on public.tickets;
drop policy if exists rs_tickets_update_admin on public.tickets;
drop policy if exists rs_tickets_update_own on public.tickets;
drop policy if exists tickets_admin_manage on public.tickets;
drop policy if exists tickets_insert_own on public.tickets;
drop policy if exists tickets_multitenant_select on public.tickets;
drop policy if exists tickets_select_own on public.tickets;
drop policy if exists tickets_update_own_or_admin on public.tickets;

create policy tickets_select_own
on public.tickets
for select
to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);

create policy tickets_admin_select
on public.tickets
for select
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and public.is_club_admin(club_id)
);

create index if not exists idx_tickets_purchase_reference
on public.tickets (user_id, match_id, momo_reference)
where momo_reference is not null;

-- Serialize every insert for a match, including trusted service-role inserts,
-- and reject a club mismatch before capacity is evaluated.
create or replace function public.rs_check_ticket_capacity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_capacity integer;
  v_club_id bigint;
  v_sold integer;
begin
  select match.capacity, match.club_id
    into v_capacity, v_club_id
    from public.matches as match
   where match.id = new.match_id
   for update;

  if not found then
    raise exception 'Ticket match was not found.';
  end if;

  if new.club_id is distinct from v_club_id then
    raise exception 'Ticket club must match the selected match.';
  end if;

  if coalesce(v_capacity, 0) <= 0 then
    raise exception 'Ticket capacity is not configured for this match.';
  end if;

  select pg_catalog.count(*)::integer
    into v_sold
    from public.tickets as ticket
   where ticket.match_id = new.match_id
     and ticket.status in ('pending', 'valid', 'used');

  if v_sold >= v_capacity then
    raise exception 'Match is sold out. Capacity: %, Sold: %',
      v_capacity,
      v_sold;
  end if;

  return new;
end;
$$;

-- Keep the catalog counter aligned with the statuses that consume capacity.
-- Refresh both matches if a trusted operation ever moves a ticket between
-- fixtures.
create or replace function public.refresh_match_ticket_sales()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_new_match_id uuid;
  v_old_match_id uuid;
begin
  if tg_op <> 'DELETE' then
    v_new_match_id := new.match_id;
  end if;
  if tg_op <> 'INSERT' then
    v_old_match_id := old.match_id;
  end if;

  if v_new_match_id is not null then
    update public.matches as match
       set sold_count = (
             select pg_catalog.count(*)::integer
               from public.tickets as ticket
              where ticket.match_id = v_new_match_id
                and ticket.status in ('pending', 'valid', 'used')
           ),
           updated_at = pg_catalog.timezone('utc', pg_catalog.now())
     where match.id = v_new_match_id;
  end if;

  if v_old_match_id is not null
     and v_old_match_id is distinct from v_new_match_id then
    update public.matches as match
       set sold_count = (
             select pg_catalog.count(*)::integer
               from public.tickets as ticket
              where ticket.match_id = v_old_match_id
                and ticket.status in ('pending', 'valid', 'used')
           ),
           updated_at = pg_catalog.timezone('utc', pg_catalog.now())
     where match.id = v_old_match_id;
  end if;

  return coalesce(new, old);
end;
$$;

create or replace function public.purchase_club_tickets(
  p_match_id uuid,
  p_user_id uuid,
  p_seat_type text,
  p_quantity integer,
  p_payment_reference text
)
returns table(id uuid)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_club_id bigint;
  v_match public.matches;
  v_payment_reference text := pg_catalog.btrim(
    coalesce(p_payment_reference, '')
  );
  v_seat_type text := pg_catalog.lower(
    pg_catalog.btrim(coalesce(p_seat_type, ''))
  );
  v_ticket_amount integer;
  v_existing_count integer;
  v_matching_count integer;
  v_sold_count integer;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  if v_actor_id is distinct from p_user_id then
    raise exception 'Authenticated user must match the requested ticket owner.';
  end if;

  begin
    v_actor_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A trusted club scope is required.';
  end;

  if v_actor_club_id is null then
    raise exception 'A trusted club scope is required.';
  end if;

  if p_match_id is null then
    raise exception 'A ticket match is required.';
  end if;

  if p_quantity is null or p_quantity < 1 or p_quantity > 10 then
    raise exception 'Ticket quantity must be between 1 and 10.';
  end if;

  if v_seat_type not in ('general', 'vip') then
    raise exception 'Ticket type must be general or vip.';
  end if;

  if v_payment_reference = ''
     or pg_catalog.length(v_payment_reference) > 120 then
    raise exception 'A valid payment reference is required.';
  end if;

  -- A retried request with the same actor, match, and reference must observe
  -- the first result instead of issuing a second ticket batch.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_actor_id::text || ':' || p_match_id::text || ':' || v_payment_reference,
      0
    )
  );

  select match.*
    into v_match
    from public.matches as match
   where match.id = p_match_id
     and match.club_id = v_actor_club_id
   for update;

  if not found then
    raise exception 'Match was not found in the active club.';
  end if;

  select
    pg_catalog.count(*)::integer,
    pg_catalog.count(*) filter (
      where ticket.seat_type = v_seat_type
    )::integer
    into v_existing_count, v_matching_count
    from public.tickets as ticket
   where ticket.match_id = p_match_id
     and ticket.user_id = v_actor_id
     and ticket.momo_reference = v_payment_reference;

  if v_existing_count > 0 then
    if v_existing_count <> p_quantity
       or v_matching_count <> v_existing_count then
      raise exception 'Payment reference was already used for a different ticket request.';
    end if;

    return query
    select ticket.id
      from public.tickets as ticket
     where ticket.match_id = p_match_id
       and ticket.user_id = v_actor_id
       and ticket.momo_reference = v_payment_reference
       and ticket.seat_type = v_seat_type
     order by ticket.created_at, ticket.id;
    return;
  end if;

  if v_match.is_on_sale is not true then
    raise exception 'Tickets are not on sale for this match.';
  end if;

  if v_match.sale_starts_at > pg_catalog.now() then
    raise exception 'Ticket sales have not started for this match.';
  end if;

  if v_match.match_date < current_date then
    raise exception 'Tickets cannot be issued for a completed match date.';
  end if;

  if coalesce(v_match.capacity, 0) <= 0 then
    raise exception 'Ticket capacity is not configured for this match.';
  end if;

  select pg_catalog.count(*)::integer
    into v_sold_count
    from public.tickets as ticket
   where ticket.match_id = p_match_id
     and ticket.status in ('pending', 'valid', 'used');

  if v_sold_count + p_quantity > v_match.capacity then
    raise exception 'Requested quantity exceeds the remaining ticket capacity.';
  end if;

  v_ticket_amount := case v_seat_type
    when 'vip' then coalesce(v_match.ticket_vip_price, 0)
    else coalesce(v_match.ticket_general_price, 0)
  end;

  insert into public.tickets (
    match_id,
    user_id,
    club_id,
    seat_type,
    amount_paid,
    momo_reference,
    status,
    purchased_at,
    confirmed_at
  )
  select
    p_match_id,
    v_actor_id,
    v_actor_club_id,
    v_seat_type,
    v_ticket_amount,
    v_payment_reference,
    'pending',
    pg_catalog.timezone('utc', pg_catalog.now()),
    null
  from pg_catalog.generate_series(1, p_quantity);

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  )
  select
    v_actor_id,
    v_actor_id,
    'supporter_ticket_purchase',
    'tickets',
    ticket.id::text,
    null,
    pg_catalog.jsonb_build_object(
      'status', ticket.status,
      'seat_type', ticket.seat_type,
      'amount_paid', ticket.amount_paid
    ),
    v_actor_club_id,
    'ticket',
    ticket.id::text,
    pg_catalog.jsonb_build_object(
      'scope', 'active_club',
      'source', 'mobile_ticket_purchase',
      'batch_quantity', p_quantity
    )
  from public.tickets as ticket
  where ticket.match_id = p_match_id
    and ticket.user_id = v_actor_id
    and ticket.momo_reference = v_payment_reference;

  return query
  select ticket.id
    from public.tickets as ticket
   where ticket.match_id = p_match_id
     and ticket.user_id = v_actor_id
     and ticket.momo_reference = v_payment_reference
     and ticket.seat_type = v_seat_type
   order by ticket.created_at, ticket.id;
end;
$$;

create or replace function public.cancel_ticket_if_unchanged(
  p_ticket_id uuid,
  p_expected_updated_at timestamp with time zone
)
returns public.tickets
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_club_id bigint;
  v_previous public.tickets;
  v_updated public.tickets;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  begin
    v_actor_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A trusted club scope is required.';
  end;

  if v_actor_club_id is null then
    raise exception 'A trusted club scope is required.';
  end if;

  if p_ticket_id is null or p_expected_updated_at is null then
    raise exception 'Ticket id and loaded version are required.';
  end if;

  select ticket.*
    into v_previous
    from public.tickets as ticket
   where ticket.id = p_ticket_id
     and ticket.user_id = v_actor_id
     and ticket.club_id = v_actor_club_id
   for update;

  if not found then
    raise exception 'Ticket was not found in the active supporter account.';
  end if;

  if v_previous.status <> 'pending' then
    raise exception 'Ticket can no longer be cancelled. Refresh ticket history.';
  end if;

  if v_previous.updated_at is distinct from p_expected_updated_at then
    raise exception
      'Ticket changed after it was loaded. Refresh ticket history and review before retrying.';
  end if;

  update public.tickets as ticket
     set status = 'cancelled'
   where ticket.id = v_previous.id
  returning ticket.* into v_updated;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  ) values (
    v_actor_id,
    v_actor_id,
    'supporter_ticket_cancel',
    'tickets',
    v_updated.id::text,
    pg_catalog.jsonb_build_object(
      'status', v_previous.status,
      'updated_at', v_previous.updated_at
    ),
    pg_catalog.jsonb_build_object(
      'status', v_updated.status,
      'updated_at', v_updated.updated_at
    ),
    v_actor_club_id,
    'ticket',
    v_updated.id::text,
    pg_catalog.jsonb_build_object(
      'scope', 'active_club',
      'source', 'mobile_ticket_history',
      'optimistic_concurrency', true
    )
  );

  return v_updated;
end;
$$;

-- The admin queue submits the exact version displayed for every selected row.
-- Lock and validate the entire selection before changing any record so a
-- single stale, foreign-club, or invalid transition rolls back the batch.
create or replace function public.admin_bulk_update_ticket_status_if_unchanged(
  p_ticket_ids uuid[],
  p_expected_updated_ats timestamp with time zone[],
  p_status text,
  p_club_id bigint,
  p_actor_id uuid,
  p_role text,
  p_is_super_admin boolean default false
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_requested_count integer := coalesce(pg_catalog.cardinality(p_ticket_ids), 0);
  v_expected_count integer := coalesce(
    pg_catalog.cardinality(p_expected_updated_ats),
    0
  );
  v_matched_count integer;
  v_action text;
  v_previous public.tickets;
  v_updated public.tickets;
begin
  if v_requested_count < 1 or v_requested_count > 100 then
    raise exception 'Select between 1 and 100 ticket records.';
  end if;

  if v_expected_count <> v_requested_count then
    raise exception 'Every selected ticket requires its loaded version.';
  end if;

  if p_actor_id is null then
    raise exception 'An authenticated audit actor is required.';
  end if;

  if p_club_id is null then
    raise exception 'An active club is required.';
  end if;

  if exists (
    select 1
      from pg_catalog.unnest(p_ticket_ids) with ordinality
        as requested(ticket_id, position)
      join pg_catalog.unnest(p_expected_updated_ats) with ordinality
        as expected(expected_updated_at, position)
        using (position)
     where requested.ticket_id is null
        or expected.expected_updated_at is null
  ) then
    raise exception 'Ticket ids and loaded versions are required.';
  end if;

  if (
    select pg_catalog.count(distinct requested.ticket_id)
      from pg_catalog.unnest(p_ticket_ids) as requested(ticket_id)
  ) <> v_requested_count then
    raise exception 'Duplicate ticket identifiers are not allowed.';
  end if;

  if p_status not in ('valid', 'used', 'cancelled') then
    raise exception 'Unsupported ticket status action.';
  end if;

  if not coalesce(p_is_super_admin, false)
     and coalesce(p_role, '') not in (
       'super_admin',
       'admin',
       'club_admin',
       'club_moderator'
     ) then
    raise exception 'Your role cannot operate ticket status changes.';
  end if;

  if p_status = 'cancelled'
     and not coalesce(p_is_super_admin, false)
     and coalesce(p_role, '') not in (
       'super_admin',
       'admin',
       'club_admin'
     ) then
    raise exception 'Ticket cancellation requires club-admin authority.';
  end if;

  -- Deterministic lock order prevents two overlapping bulk selections from
  -- deadlocking while preserving the all-or-nothing review contract.
  perform 1
    from public.tickets as ticket
   where ticket.id = any(p_ticket_ids)
     and ticket.club_id = p_club_id
   order by ticket.id
   for update;

  select pg_catalog.count(*)::integer
    into v_matched_count
    from public.tickets as ticket
   where ticket.id = any(p_ticket_ids)
     and ticket.club_id = p_club_id;

  if v_matched_count <> v_requested_count then
    raise exception 'One or more tickets are missing or outside the active club.';
  end if;

  if exists (
    select 1
      from pg_catalog.unnest(p_ticket_ids) with ordinality
        as requested(ticket_id, position)
      join pg_catalog.unnest(p_expected_updated_ats) with ordinality
        as expected(expected_updated_at, position)
        using (position)
      join public.tickets as ticket
        on ticket.id = requested.ticket_id
       and ticket.club_id = p_club_id
     where ticket.updated_at is distinct from expected.expected_updated_at
  ) then
    raise exception
      'One or more tickets changed after they were loaded. Refresh the ticket queue and review before retrying.';
  end if;

  if exists (
    select 1
      from public.tickets as ticket
     where ticket.id = any(p_ticket_ids)
       and ticket.club_id = p_club_id
       and not (
         (ticket.status = 'pending' and p_status in ('valid', 'cancelled'))
         or (ticket.status = 'valid' and p_status in ('used', 'cancelled'))
       )
  ) then
    raise exception 'One or more selected tickets have an invalid status transition.';
  end if;

  v_action := case
    when v_requested_count = 1 then 'ticket_status_update'
    else 'bulk_ticket_status_update'
  end;

  for v_previous in
    select ticket.*
      from public.tickets as ticket
     where ticket.id = any(p_ticket_ids)
       and ticket.club_id = p_club_id
     order by ticket.id
  loop
    update public.tickets as ticket
       set status = p_status
     where ticket.id = v_previous.id
    returning ticket.* into v_updated;

    insert into public.admin_audit_log (
      actor_id,
      user_id,
      action,
      target_table,
      target_id,
      old_data,
      new_data,
      club_id,
      entity_type,
      entity_id,
      metadata
    ) values (
      p_actor_id,
      p_actor_id,
      v_action,
      'tickets',
      v_updated.id::text,
      pg_catalog.jsonb_build_object(
        'status', v_previous.status,
        'updated_at', v_previous.updated_at
      ),
      pg_catalog.jsonb_build_object(
        'status', v_updated.status,
        'updated_at', v_updated.updated_at
      ),
      p_club_id,
      'ticket',
      v_updated.id::text,
      pg_catalog.jsonb_build_object(
        'scope', 'active_club',
        'selection_count', v_requested_count,
        'source', 'admin_ticket_queue',
        'optimistic_concurrency', true
      )
    );
  end loop;

  return v_requested_count;
end;
$$;

revoke all on function public.rs_check_ticket_capacity()
from public, anon, authenticated, service_role;

revoke all on function public.refresh_match_ticket_sales()
from public, anon, authenticated, service_role;

revoke all on function public.purchase_club_tickets(
  uuid,
  uuid,
  text,
  integer,
  text
) from public, anon, authenticated, service_role;

grant execute on function public.purchase_club_tickets(
  uuid,
  uuid,
  text,
  integer,
  text
) to authenticated;

revoke all on function public.cancel_ticket_if_unchanged(
  uuid,
  timestamp with time zone
) from public, anon, authenticated, service_role;

grant execute on function public.cancel_ticket_if_unchanged(
  uuid,
  timestamp with time zone
) to authenticated;

-- Remove the status-only mutation route once the exact-version replacement is
-- present. Keeping the old definition unexecutable avoids PostgREST overload
-- ambiguity while making accidental legacy calls fail closed.
revoke all on function public.admin_bulk_update_ticket_status(
  uuid[],
  text,
  bigint,
  uuid,
  text,
  boolean
) from public, anon, authenticated, service_role;

revoke all on function public.admin_bulk_update_ticket_status_if_unchanged(
  uuid[],
  timestamp with time zone[],
  text,
  bigint,
  uuid,
  text,
  boolean
) from public, anon, authenticated, service_role;

grant execute on function public.admin_bulk_update_ticket_status_if_unchanged(
  uuid[],
  timestamp with time zone[],
  text,
  bigint,
  uuid,
  text,
  boolean
) to service_role;

commit;

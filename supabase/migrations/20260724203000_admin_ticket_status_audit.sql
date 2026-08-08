-- Atomic, role-safe ticket status updates with immutable audit records.
--
-- This function is intentionally service-role only. The admin API resolves the
-- authenticated actor, role, and club scope before invoking it. Every selected
-- record must belong to the requested club and have a valid transition, or the
-- full operation rolls back.

create or replace function public.admin_bulk_update_ticket_status(
  p_ticket_ids uuid[],
  p_status text,
  p_club_id bigint,
  p_actor_id uuid,
  p_role text,
  p_is_super_admin boolean default false
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_requested_count integer;
  v_matched_count integer;
  v_action text;
begin
  v_requested_count := coalesce(cardinality(p_ticket_ids), 0);

  if v_requested_count < 1 or v_requested_count > 100 then
    raise exception 'Select between 1 and 100 ticket records.';
  end if;

  if p_actor_id is null then
    raise exception 'An authenticated audit actor is required.';
  end if;

  if (
    select count(distinct ticket_id)
    from unnest(p_ticket_ids) as ticket_id
  ) <> v_requested_count then
    raise exception 'Duplicate ticket identifiers are not allowed.';
  end if;

  if p_status not in ('valid', 'used', 'cancelled') then
    raise exception 'Unsupported ticket status action.';
  end if;

  if not coalesce(p_is_super_admin, false)
     and coalesce(p_role, '') not in ('super_admin', 'admin', 'club_admin', 'club_moderator') then
    raise exception 'Your role cannot operate ticket status changes.';
  end if;

  if p_status = 'cancelled'
     and not coalesce(p_is_super_admin, false)
     and coalesce(p_role, '') not in ('super_admin', 'admin', 'club_admin') then
    raise exception 'Ticket cancellation requires club-admin authority.';
  end if;

  select count(*)
    into v_matched_count
    from public.tickets
   where id = any(p_ticket_ids)
     and club_id = p_club_id;

  if v_matched_count <> v_requested_count then
    raise exception 'One or more tickets are missing or outside the active club.';
  end if;

  if exists (
    select 1
      from public.tickets
     where id = any(p_ticket_ids)
       and club_id = p_club_id
       and not (
         (status = 'pending' and p_status in ('valid', 'cancelled'))
         or (status = 'valid' and p_status in ('used', 'cancelled'))
       )
  ) then
    raise exception 'One or more selected tickets have a stale or invalid status transition.';
  end if;

  v_action := case
    when v_requested_count = 1 then 'ticket_status_update'
    else 'bulk_ticket_status_update'
  end;

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
    p_actor_id,
    p_actor_id,
    v_action,
    'tickets',
    ticket.id::text,
    jsonb_build_object('status', ticket.status),
    jsonb_build_object('status', p_status),
    p_club_id,
    'ticket',
    ticket.id::text,
    jsonb_build_object(
      'scope', 'active_club',
      'selection_count', v_requested_count,
      'source', 'admin_ticket_queue'
    )
  from public.tickets as ticket
  where ticket.id = any(p_ticket_ids)
    and ticket.club_id = p_club_id;

  update public.tickets
     set status = p_status
   where id = any(p_ticket_ids)
     and club_id = p_club_id;

  return v_requested_count;
end;
$$;

revoke all on function public.admin_bulk_update_ticket_status(
  uuid[],
  text,
  bigint,
  uuid,
  text,
  boolean
) from public, anon, authenticated, service_role;

grant execute on function public.admin_bulk_update_ticket_status(
  uuid[],
  text,
  bigint,
  uuid,
  text,
  boolean
) to service_role;

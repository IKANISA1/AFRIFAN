-- Bind immutable retries to their original request and recheck event access.
begin;

-- Preserve historical audit rows. Their unknown request version must not be
-- guessed from a mutable credential; retries of those rows require a new scan.
alter table public.ticket_redemption_events
  add column request_credential_version integer
  constraint ticket_redemption_events_request_credential_version_check
  check (request_credential_version > 0);

comment on column public.ticket_redemption_events.request_credential_version is
  'Version supplied for this immutable operation. Null denotes an older audit row whose request version was not recorded.';

create or replace function public.redeem_ticket_for_verifier(
  p_actor_id uuid,
  p_credential_id uuid,
  p_credential_version integer,
  p_operation_id uuid,
  p_gate_code text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamp with time zone;
  v_gate_code text := nullif(upper(btrim(coalesce(p_gate_code, ''))), '');
  v_credential public.ticket_wallet_credentials;
  v_ticket public.tickets;
  v_event public.ticket_events;
  v_assignment public.ticket_verifier_assignments;
  v_existing public.ticket_redemption_events;
  v_first_admission public.ticket_redemption_events;
  v_decision text;
  v_result jsonb;
begin
  if p_actor_id is null
     or p_credential_id is null
     or p_credential_version is null
     or p_credential_version < 1
     or p_operation_id is null then
    raise exception 'Verifier, credential, version, and operation id are required.';
  end if;

  if v_gate_code is not null
     and v_gate_code !~ '^[A-Z0-9][A-Z0-9_-]{0,31}$' then
    raise exception 'Gate code is invalid.';
  end if;

  -- Serialize the same verifier operation before reading its immutable result.
  -- Credential locking alone happens too late: simultaneous retries can both
  -- miss this lookup and then collide on the audit operation's unique key.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'africlub.ticket-redemption:' || p_actor_id::text || ':' || p_operation_id::text,
      0
    )
  );

  select redemption.*
  into v_existing
  from public.ticket_redemption_events as redemption
  where redemption.verifier_user_id = p_actor_id
    and redemption.operation_id = p_operation_id;

  if found then
    if v_existing.credential_id is distinct from p_credential_id
       or v_existing.request_credential_version is distinct from p_credential_version
       or v_existing.gate_code is distinct from v_gate_code then
      -- A reused key is not evidence that this different scan was admitted.
      -- Keep the original audit unchanged and reveal no original ticket data.
      return jsonb_build_object(
        'status', 'rejected',
        'code', 'operation_conflict',
        'replayed', false
      );
    end if;
    return v_existing.result || jsonb_build_object('replayed', true);
  end if;

  select credential.*
  into v_credential
  from public.ticket_wallet_credentials as credential
  where credential.id = p_credential_id
  for update;

  if not found then
    return jsonb_build_object(
      'status', 'rejected',
      'code', 'credential_invalid',
      'replayed', false
    );
  end if;

  select ticket.*
  into v_ticket
  from public.tickets as ticket
  where ticket.id = v_credential.ticket_id
  for update;

  select event.*
  into v_event
  from public.ticket_events as event
  where event.id = v_credential.ticket_event_id;

  -- Any earlier row or operation lock can wait past a shift or event deadline.
  -- Read wall-clock time after each wait, including the assignment lock itself.
  -- If a selected shift expired while locked, look for another current shift.
  loop
    v_now := pg_catalog.clock_timestamp();
    select assignment.*
    into v_assignment
    from public.ticket_verifier_assignments as assignment
    where assignment.user_id = p_actor_id
      and assignment.ticket_event_id = v_credential.ticket_event_id
      and assignment.organization_id = v_credential.organization_id
      and assignment.club_id = v_credential.club_id
      and assignment.venue_id = v_event.venue_id
      and assignment.is_active
      and assignment.starts_at <= v_now
      and assignment.ends_at > v_now
      and (
        assignment.gate_code is null
        or assignment.gate_code = v_gate_code
      )
    order by
      case when assignment.gate_code = v_gate_code then 0 else 1 end,
      assignment.granted_at,
      assignment.id
    limit 1
    for update;

    -- An event may have been disabled or moved while assignment locking waited.
    -- Re-read and hold its current state through the admission commit. A SHARE
    -- lock also prevents a later non-key event update from racing the decision.
    select event.*
    into v_event
    from public.ticket_events as event
    where event.id = v_credential.ticket_event_id
    for share;

    v_now := pg_catalog.clock_timestamp();
    exit when v_assignment.id is null
      or (v_assignment.is_active
          and v_assignment.starts_at <= v_now
          and v_assignment.ends_at > v_now);
  end loop;

  if v_assignment.id is null then
    if exists (
      select 1
      from public.ticket_verifier_assignments as assignment
      where assignment.user_id = p_actor_id
        and assignment.ticket_event_id = v_credential.ticket_event_id
        and assignment.organization_id = v_credential.organization_id
        and assignment.club_id = v_credential.club_id
        and assignment.venue_id = v_event.venue_id
        and assignment.is_active
        and assignment.starts_at <= v_now
        and assignment.ends_at > v_now
    ) then
      v_decision := 'wrong_gate';
    else
      v_decision := 'permission_denied';
    end if;
  elsif v_assignment.venue_id is distinct from v_event.venue_id
        or v_event.club_id is distinct from v_credential.club_id
        or v_event.organization_id is distinct from v_credential.organization_id
        or v_event.match_id is distinct from v_ticket.match_id then
    v_decision := 'permission_denied';
  elsif v_credential.status <> 'active'
        or v_credential.credential_version <> p_credential_version then
    v_decision := 'credential_inactive';
  elsif v_event.status <> 'active' or not v_event.verification_enabled then
    v_decision := 'permission_denied';
  elsif v_now < v_event.entry_opens_at then
    v_decision := 'outside_window';
  elsif v_now >= v_event.entry_closes_at then
    v_decision := 'expired';
  elsif v_ticket.status = 'valid' and v_ticket.confirmed_at is not null then
    v_decision := 'admitted';
  elsif v_ticket.status = 'used' then
    v_decision := 'already_used';
  elsif v_ticket.status = 'pending' then
    v_decision := 'pending_payment';
  elsif v_ticket.status in ('cancelled', 'refunded', 'voided') then
    v_decision := v_ticket.status;
  else
    v_decision := 'permission_denied';
  end if;

  if v_decision = 'already_used' then
    select redemption.*
    into v_first_admission
    from public.ticket_redemption_events as redemption
    where redemption.ticket_id = v_ticket.id
      and redemption.decision = 'admitted'
    order by redemption.scanned_at, redemption.id
    limit 1;
  end if;

  if v_decision = 'admitted' then
    update public.tickets as ticket
    set status = 'used'
    where ticket.id = v_ticket.id
      and ticket.status = 'valid';

    if not found then
      v_decision := 'already_used';
      select redemption.*
      into v_first_admission
      from public.ticket_redemption_events as redemption
      where redemption.ticket_id = v_ticket.id
        and redemption.decision = 'admitted'
      order by redemption.scanned_at, redemption.id
      limit 1;
    end if;
  end if;

  if v_decision = 'permission_denied' then
    -- Do not disclose ticket details to an authenticated account that has no
    -- live assignment for this event. The internal audit row retains scope.
    v_result := jsonb_build_object(
      'status', 'rejected',
      'code', v_decision,
      'scanned_at', v_now,
      'replayed', false
    );
  else
    v_result := jsonb_build_object(
      'status', case when v_decision = 'admitted' then 'admitted' else 'rejected' end,
      'code', v_decision,
      'ticket_id', v_ticket.id,
      'ticket_number', right(replace(v_ticket.id::text, '-', ''), 12),
      'seat_type', v_ticket.seat_type,
      'ticket_event_id', v_event.id,
      'organization_id', v_credential.organization_id,
      'venue_id', v_event.venue_id,
      'gate_code', v_gate_code,
      'scanned_at', v_now,
      'first_admitted_at', v_first_admission.scanned_at,
      'replayed', false
    );
  end if;

  insert into public.ticket_redemption_events (
    club_id,
    organization_id,
    ticket_event_id,
    venue_id,
    ticket_id,
    credential_id,
    request_credential_version,
    verifier_assignment_id,
    verifier_user_id,
    operation_id,
    gate_code,
    decision,
    result,
    scanned_at
  ) values (
    v_credential.club_id,
    v_credential.organization_id,
    v_credential.ticket_event_id,
    v_event.venue_id,
    v_ticket.id,
    v_credential.id,
    p_credential_version,
    v_assignment.id,
    p_actor_id,
    p_operation_id,
    v_gate_code,
    v_decision,
    v_result,
    v_now
  );

  return v_result;
end;
$$;

revoke all on function public.redeem_ticket_for_verifier(
  uuid, uuid, integer, uuid, text
) from public, anon, authenticated, service_role;
grant execute on function public.redeem_ticket_for_verifier(
  uuid, uuid, integer, uuid, text
) to service_role;

commit;

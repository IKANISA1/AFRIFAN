-- Give a paired native-TV installation a least-privilege authenticated
-- identity for club/session-scoped Realtime invalidation events.
--
-- The high-entropy device credential remains the only credential accepted by
-- the authoritative TV projection RPC. The bound anonymous-auth identity is
-- used only by RLS to decide whether this installation may observe privacy-
-- safe refresh hints for an actively assigned session.

begin;

alter table africlub_game.tv_devices
  add column if not exists device_auth_user_id uuid
    references auth.users(id) on delete set null;

create unique index if not exists idx_tv_devices_active_auth_identity
  on africlub_game.tv_devices (device_auth_user_id)
  where device_auth_user_id is not null
    and status = 'paired'
    and credential_revoked_at is null;

create or replace function africlub_game.clear_tv_realtime_identity()
returns trigger
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
begin
  if new.status <> 'paired'
     or new.credential_revoked_at is not null
     or new.credential_token_hash is distinct from old.credential_token_hash then
    new.device_auth_user_id := null;
  end if;
  return new;
end;
$$;

drop trigger if exists tv_devices_clear_realtime_identity
on africlub_game.tv_devices;
create trigger tv_devices_clear_realtime_identity
before update of status, credential_revoked_at, credential_token_hash
on africlub_game.tv_devices
for each row execute function africlub_game.clear_tv_realtime_identity();

create or replace function public.bind_tv_realtime_identity_v2(
  p_device_token text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_club_id bigint := africlub_game.current_club_id();
  v_token text := btrim(coalesce(p_device_token, ''));
  v_display africlub_game.tv_devices%rowtype;
begin
  if v_actor is null then
    return jsonb_build_object('status', 'error', 'code', 'authentication_required');
  end if;
  if v_club_id is null then
    return jsonb_build_object('status', 'error', 'code', 'club_context_required');
  end if;
  if length(v_token) <> 64 or v_token !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('status', 'error', 'code', 'credential_invalid');
  end if;

  select * into v_display
  from africlub_game.tv_devices
  where credential_token_hash = encode(digest(v_token, 'sha256'), 'hex')
  limit 1
  for update;

  if v_display.id is null
     or v_display.status <> 'paired'
     or v_display.credential_revoked_at is not null then
    return jsonb_build_object('status', 'error', 'code', 'credential_revoked_or_invalid');
  end if;
  if v_display.club_id <> v_club_id then
    return jsonb_build_object('status', 'error', 'code', 'club_scope_mismatch');
  end if;
  if v_display.device_auth_user_id is not null
     and v_display.device_auth_user_id <> v_actor then
    return jsonb_build_object('status', 'error', 'code', 'identity_already_bound');
  end if;
  if exists (
    select 1
    from africlub_game.tv_devices other_display
    where other_display.device_auth_user_id = v_actor
      and other_display.id <> v_display.id
      and other_display.status = 'paired'
      and other_display.credential_revoked_at is null
  ) then
    return jsonb_build_object('status', 'error', 'code', 'identity_in_use');
  end if;

  if v_display.device_auth_user_id is null then
    update africlub_game.tv_devices
    set device_auth_user_id = v_actor,
        last_seen_at = timezone('utc', now()),
        updated_at = timezone('utc', now())
    where id = v_display.id
    returning * into v_display;

    insert into africlub_game.audit_log (
      club_id, actor_id, action, entity_type, entity_id, after_json
    ) values (
      v_display.club_id,
      v_actor,
      'tv_realtime_identity_bound',
      'tv_device',
      v_display.id,
      jsonb_build_object('authorization', 'assigned_session_events_only')
    );
  end if;

  return jsonb_build_object(
    'status', 'ready',
    'display_id', v_display.id::text,
    'club_id', v_display.club_id::text,
    'authorization', 'assigned_session_events_only'
  );
end;
$$;

create or replace function africlub_game.is_tv_session_subscriber(
  p_session_id uuid
) returns boolean
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select exists (
    select 1
    from africlub_game.display_assignments assignment
    join africlub_game.tv_devices display
      on display.id = assignment.display_id
     and display.club_id = assignment.club_id
    where assignment.session_id = p_session_id
      and assignment.unassigned_at is null
      and display.device_auth_user_id = auth.uid()
      and display.status = 'paired'
      and display.credential_revoked_at is null
  )
$$;

drop policy if exists game_events_participant_read
on africlub_game.game_events;
drop policy if exists game_events_authorized_subscriber_read
on africlub_game.game_events;
create policy game_events_authorized_subscriber_read
on africlub_game.game_events for select to authenticated
using (
  club_id = africlub_game.current_club_id()
  and (
    africlub_game.is_session_participant(session_id)
    or africlub_game.can_organize_session(session_id)
    or africlub_game.is_tv_session_subscriber(session_id)
  )
);

revoke all on function public.bind_tv_realtime_identity_v2(text) from public;
grant execute on function public.bind_tv_realtime_identity_v2(text)
to authenticated;
revoke all on function africlub_game.is_tv_session_subscriber(uuid) from public;
grant execute on function africlub_game.is_tv_session_subscriber(uuid)
to authenticated;

comment on column africlub_game.tv_devices.device_auth_user_id is
  'Bound anonymous-auth identity used only for assigned-session Realtime RLS.';
comment on function public.bind_tv_realtime_identity_v2(text) is
  'Binds one paired device credential to one authenticated TV identity without exposing the credential to Realtime.';
comment on function africlub_game.is_tv_session_subscriber(uuid) is
  'True only when the current authenticated TV identity owns an active display assignment for the session.';

commit;

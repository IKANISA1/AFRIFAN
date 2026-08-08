-- Replace artifact-embedded TV identifiers with a one-time pairing exchange and
-- a revocable, high-entropy device credential. Only hashes are persisted.

alter table africlub_game.tv_devices
  add column if not exists pairing_code_hash text,
  add column if not exists pairing_expires_at timestamptz,
  add column if not exists credential_token_hash text,
  add column if not exists credential_issued_at timestamptz,
  add column if not exists credential_revoked_at timestamptz;

create unique index if not exists idx_tv_devices_credential_token_hash
  on africlub_game.tv_devices (credential_token_hash)
  where credential_token_hash is not null;

create or replace function africlub_game.prepare_tv_pairing_code()
returns trigger
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
begin
  if new.credential_token_hash is null and
     new.pairing_code_hash is null and
     (tg_op = 'INSERT' or new.pairing_code is distinct from old.pairing_code) then
    new.pairing_code_hash := encode(digest(upper(btrim(new.pairing_code)), 'sha256'), 'hex');
    new.pairing_expires_at := timezone('utc', now()) + interval '15 minutes';
    new.pairing_code := 'HASHED-' || new.id::text;
  end if;
  return new;
end;
$$;

drop trigger if exists tv_devices_prepare_pairing_code on africlub_game.tv_devices;
create trigger tv_devices_prepare_pairing_code
before insert or update of pairing_code on africlub_game.tv_devices
for each row execute function africlub_game.prepare_tv_pairing_code();

revoke execute on function africlub_game.prepare_tv_pairing_code()
  from public, anon, authenticated, service_role;

update africlub_game.tv_devices
set pairing_code_hash = encode(digest(upper(btrim(pairing_code)), 'sha256'), 'hex'),
    pairing_expires_at = coalesce(pairing_expires_at, timezone('utc', now()) + interval '15 minutes'),
    pairing_code = 'HASHED-' || id::text
where credential_token_hash is null
  and pairing_code_hash is null;

create or replace function africlub_game.admin_pair_tv_device(
  p_club_id bigint,
  p_device_label text,
  p_pairing_code text,
  p_session_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_device africlub_game.tv_devices%rowtype;
  v_session africlub_game.game_sessions%rowtype;
  v_label text := nullif(btrim(coalesce(p_device_label, '')), '');
  v_code text := upper(nullif(btrim(coalesce(p_pairing_code, '')), ''));
  v_hash text;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to pair TV devices';
  end if;
  if v_label is null then raise exception 'device_label is required'; end if;
  if v_code is null or length(v_code) < 8 or length(v_code) > 32 then
    raise exception 'pairing_code must contain 8 to 32 characters';
  end if;
  v_hash := encode(digest(v_code, 'sha256'), 'hex');

  if p_session_id is not null then
    select * into v_session from africlub_game.game_sessions
    where id = p_session_id and club_id = p_club_id;
    if v_session.id is null then raise exception 'Game session not found'; end if;
  end if;

  select * into v_device from africlub_game.tv_devices
  where club_id = p_club_id and pairing_code_hash = v_hash
  limit 1 for update;

  if v_device.id is null then
    insert into africlub_game.tv_devices (
      club_id, device_label, pairing_code, status, current_session_id,
      last_seen_at, created_by
    ) values (
      p_club_id, left(v_label, 80), v_code, 'paired', p_session_id,
      null, auth.uid()
    ) returning * into v_device;
  else
    update africlub_game.tv_devices
    set device_label = left(v_label, 80),
        pairing_code = v_code,
        status = 'paired',
        current_session_id = p_session_id,
        pairing_code_hash = null,
        credential_token_hash = null,
        credential_issued_at = null,
        credential_revoked_at = null,
        last_seen_at = null,
        updated_at = timezone('utc', now())
    where id = v_device.id
    returning * into v_device;
  end if;

  if p_session_id is not null then
    update africlub_game.game_sessions
    set tv_device_id = v_device.id, updated_at = timezone('utc', now())
    where id = p_session_id;
  end if;

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    p_club_id, auth.uid(), 'tv_device_pairing_issued', 'tv_device', v_device.id,
    jsonb_build_object('session_id', p_session_id, 'expires_at', v_device.pairing_expires_at)
  );

  return jsonb_build_object(
    'tvDeviceId', v_device.id,
    'deviceLabel', v_device.device_label,
    'pairingCode', v_code,
    'pairingExpiresAt', v_device.pairing_expires_at,
    'sessionId', v_device.current_session_id,
    'status', v_device.status
  );
end;
$$;

update africlub_game.audit_log
set after_json = after_json - 'pairing_code'
where entity_type = 'tv_device' and after_json ? 'pairing_code';

create or replace function africlub_game.admin_revoke_tv_device(
  p_club_id bigint,
  p_device_id uuid,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_device africlub_game.tv_devices%rowtype;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to revoke TV devices';
  end if;

  update africlub_game.tv_devices
  set status = 'disabled',
      credential_revoked_at = timezone('utc', now()),
      current_session_id = null,
      updated_at = timezone('utc', now())
  where id = p_device_id and club_id = p_club_id
  returning * into v_device;

  if v_device.id is null then raise exception 'TV device not found'; end if;

  update africlub_game.game_sessions
  set tv_device_id = null, updated_at = timezone('utc', now())
  where tv_device_id = v_device.id and club_id = p_club_id;

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    p_club_id, auth.uid(), 'tv_device_revoked', 'tv_device', v_device.id,
    jsonb_build_object('reason', nullif(btrim(coalesce(p_reason, '')), ''))
  );

  return jsonb_build_object('tvDeviceId', v_device.id, 'status', v_device.status);
end;
$$;

create or replace function public.exchange_tv_pairing_code(
  p_pairing_code text,
  p_club_id bigint default null
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_code text := upper(nullif(btrim(coalesce(p_pairing_code, '')), ''));
  v_code_hash text;
  v_token text;
  v_device africlub_game.tv_devices%rowtype;
begin
  if v_code is null or length(v_code) < 6 or length(v_code) > 32 then
    return jsonb_build_object('status', 'error', 'code', 'invalid_pairing_code');
  end if;

  v_code_hash := encode(digest(v_code, 'sha256'), 'hex');

  select * into v_device
  from africlub_game.tv_devices
  where (p_club_id is null or club_id = p_club_id)
    and status = 'paired'
    and credential_token_hash is null
    and (pairing_code_hash = v_code_hash or upper(pairing_code) = v_code)
    and (pairing_expires_at is null or pairing_expires_at > timezone('utc', now()))
  order by updated_at desc
  limit 1
  for update;

  if v_device.id is null then
    return jsonb_build_object('status', 'error', 'code', 'pairing_code_invalid_or_expired');
  end if;

  v_token := encode(gen_random_bytes(32), 'hex');
  update africlub_game.tv_devices
  set pairing_code_hash = coalesce(pairing_code_hash, v_code_hash),
      pairing_code = 'REDEEMED-' || id::text,
      credential_token_hash = encode(digest(v_token, 'sha256'), 'hex'),
      credential_issued_at = timezone('utc', now()),
      credential_revoked_at = null,
      last_seen_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = v_device.id;

  return jsonb_build_object(
    'status', 'success',
    'code', 'paired',
    'device_id', v_device.id,
    'device_token', v_token
  );
end;
$$;

create or replace function public.get_tv_display_state_with_credential(
  p_device_token text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_token text := nullif(btrim(coalesce(p_device_token, '')), '');
  v_device africlub_game.tv_devices%rowtype;
  v_result jsonb;
begin
  if v_token is null or length(v_token) <> 64 then
    return jsonb_build_object('status', 'error', 'code', 'credential_invalid');
  end if;

  select * into v_device
  from africlub_game.tv_devices
  where credential_token_hash = encode(digest(v_token, 'sha256'), 'hex')
  limit 1;

  if v_device.id is null or v_device.status <> 'paired' or v_device.credential_revoked_at is not null then
    return jsonb_build_object('status', 'error', 'code', 'credential_revoked_or_invalid');
  end if;

  update africlub_game.tv_devices
  set last_seen_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = v_device.id;

  select jsonb_build_object(
    'status', 'ready',
    'device_id', v_device.id,
    'club_id', v_device.club_id,
    'venue_name', coalesce(v.display_name, nullif(v_device.metadata->>'venue_name', ''), v_device.device_label),
    'session_id', s.id,
    'session_title', s.title,
    'session_code', coalesce(s.join_code, nullif(v_device.metadata->>'session_code', '')),
    'phase', coalesce(s.status, 'lobby'),
    'prompt', coalesce(
      nullif(s.metadata->>'tv_prompt', ''),
      nullif(v_device.metadata->>'tv_prompt', ''),
      'Open Fan Zone in the supporter app to join this live experience.'
    ),
    'fet_reward', coalesce(
      campaign.fet_award_per_checkin,
      case when nullif(s.metadata->>'fet_reward', '') ~ '^[0-9]+$'
        then (s.metadata->>'fet_reward')::integer end,
      case when nullif(v_device.metadata->>'fet_reward', '') ~ '^[0-9]+$'
        then (v_device.metadata->>'fet_reward')::integer end,
      0
    ),
    'expires_at', coalesce(campaign.ends_at::text, s.ended_at::text, nullif(v_device.metadata->>'expires_at', '')),
    'campaign_id', campaign.id,
    'campaign_name', campaign.campaign_name,
    'updated_at', coalesce(s.updated_at, v_device.updated_at)
  ) into v_result
  from (select 1) base
  left join africlub_game.game_sessions s
    on s.id = v_device.current_session_id and s.club_id = v_device.club_id
  left join public.venues v
    on v.club_id = v_device.club_id
   and v.id = case
     when nullif(v_device.metadata->>'venue_id', '') ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
       then (v_device.metadata->>'venue_id')::uuid
     else null
   end
  left join lateral (
    select c.id, c.campaign_name, c.fet_award_per_checkin, c.ends_at
    from public.venue_checkin_campaigns c
    where c.club_id = v_device.club_id
      and c.venue_id = v.id
      and c.status = 'approved'
      and timezone('utc', now()) >= c.starts_at
      and timezone('utc', now()) < c.ends_at
    order by c.ends_at asc
    limit 1
  ) campaign on true;

  return v_result || jsonb_build_object('credential_status', 'valid');
end;
$$;

revoke all on function africlub_game.admin_pair_tv_device(bigint, text, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.admin_pair_tv_device(bigint, text, text, uuid)
  to authenticated, service_role;
revoke all on function africlub_game.admin_revoke_tv_device(bigint, uuid, text)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.admin_revoke_tv_device(bigint, uuid, text)
  to authenticated, service_role;

revoke all on function public.exchange_tv_pairing_code(text, bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.exchange_tv_pairing_code(text, bigint) to anon, authenticated;
revoke all on function public.get_tv_display_state_with_credential(text)
  from public, anon, authenticated, service_role;
grant execute on function public.get_tv_display_state_with_credential(text) to anon, authenticated;

-- Device IDs and pairing codes are no longer bearer credentials for public clients.
revoke execute on function public.get_tv_display_state(uuid, text, bigint)
  from public, anon, authenticated, service_role;
revoke execute on function africlub_game.get_tv_display_state(uuid, text, bigint)
  from public, anon, authenticated, service_role;
grant execute on function public.get_tv_display_state(uuid, text, bigint) to authenticated, service_role;
grant execute on function africlub_game.get_tv_display_state(uuid, text, bigint) to authenticated, service_role;

comment on function public.exchange_tv_pairing_code(text, bigint) is
  'One-time TV pairing exchange. Returns a device credential once and stores only its SHA-256 hash.';
comment on function public.get_tv_display_state_with_credential(text) is
  'Returns screen-safe TV state only for a live, revocable device credential.';

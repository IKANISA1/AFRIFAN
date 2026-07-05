-- Clean remaining easy warnings after removing broken legacy RPCs.

drop function if exists public.allocate_transaction_to_member(uuid, uuid, uuid);

create or replace function public.purchase_club_tickets(
  p_match_id uuid,
  p_user_id uuid,
  p_seat_type text,
  p_quantity integer,
  p_payment_reference text
) returns table(id uuid)
language plpgsql
set search_path = public
as $$
declare
  v_match record;
  v_ticket_amount integer;
  v_seat_type text;
begin
  if auth.uid() is distinct from p_user_id then
    raise exception 'Authenticated user must match the requested ticket owner.';
  end if;

  if p_quantity is null or p_quantity < 1 then
    raise exception 'Ticket quantity must be at least 1.';
  end if;

  v_seat_type := case
    when lower(coalesce(p_seat_type, '')) = 'vip' then 'vip'
    else 'general'
  end;

  select
    m.id,
    m.club_id,
    m.is_on_sale,
    m.ticket_general_price,
    m.ticket_vip_price
  into v_match
  from public.matches as m
  where m.id = p_match_id
  for update;

  if not found then
    raise exception 'Match % was not found.', p_match_id;
  end if;

  if coalesce(v_match.is_on_sale, false) is not true then
    raise exception 'Tickets are not on sale for this match.';
  end if;

  v_ticket_amount := case
    when v_seat_type = 'vip' then coalesce(v_match.ticket_vip_price, 0)
    else coalesce(v_match.ticket_general_price, 0)
  end;

  return query
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
    p_user_id,
    v_match.club_id,
    v_seat_type,
    v_ticket_amount,
    nullif(btrim(coalesce(p_payment_reference, '')), ''),
    'pending',
    timezone('utc', now()),
    null
  from generate_series(1, p_quantity)
  returning tickets.id;
end;
$$;

create or replace function public.activate_referral_invite_for_user(
  p_referral_invite_id uuid,
  p_invitee_id uuid,
  p_qualifying_event_type text,
  p_qualifying_event_id text,
  p_inviter_points integer default 0,
  p_invitee_points integer default 0
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Referral tables are not present in the current schema. Keep this as a
  -- compatibility no-op so payment workflows do not fail on old invite fields.
  perform p_referral_invite_id,
          p_invitee_id,
          p_qualifying_event_type,
          p_qualifying_event_id,
          p_inviter_points,
          p_invitee_points;
  return false;
end;
$$;

create or replace function africlub_game.admin_pair_tv_device(
  p_club_id bigint,
  p_device_label text,
  p_pairing_code text,
  p_session_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_device africlub_game.tv_devices%rowtype;
  v_device_label text;
  v_pairing_code text;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to pair TV devices';
  end if;

  v_device_label := nullif(btrim(coalesce(p_device_label, '')), '');
  v_pairing_code := upper(nullif(btrim(coalesce(p_pairing_code, '')), ''));
  if v_device_label is null then
    raise exception 'device_label is required';
  end if;
  if v_pairing_code is null then
    raise exception 'pairing_code is required';
  end if;

  if p_session_id is not null then
    perform 1
    from africlub_game.game_sessions
    where id = p_session_id
      and club_id = p_club_id;

    if not found then
      raise exception 'Game session not found';
    end if;
  end if;

  insert into africlub_game.tv_devices (
    club_id,
    device_label,
    pairing_code,
    status,
    current_session_id,
    last_seen_at,
    created_by
  )
  values (
    p_club_id,
    left(v_device_label, 80),
    left(v_pairing_code, 32),
    'paired',
    p_session_id,
    timezone('utc', now()),
    auth.uid()
  )
  on conflict (club_id, pairing_code) do update
     set device_label = excluded.device_label,
         status = 'paired',
         current_session_id = excluded.current_session_id,
         last_seen_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
  returning * into v_device;

  if p_session_id is not null then
    update africlub_game.game_sessions
       set tv_device_id = v_device.id,
           updated_at = timezone('utc', now())
     where id = p_session_id;
  end if;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    p_club_id,
    auth.uid(),
    'tv_device_paired',
    'tv_device',
    v_device.id,
    jsonb_build_object(
      'pairing_code', v_device.pairing_code,
      'session_id', p_session_id
    )
  );

  return jsonb_build_object(
    'tvDeviceId', v_device.id,
    'deviceLabel', v_device.device_label,
    'pairingCode', v_device.pairing_code,
    'sessionId', v_device.current_session_id,
    'status', v_device.status
  );
end;
$$;

create or replace function africlub_game.admin_create_session(
  p_club_id bigint,
  p_title text,
  p_pack_id uuid default null,
  p_tv_device_id uuid default null,
  p_join_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_pack africlub_game.question_packs%rowtype;
  v_title text;
  v_join_code text;
  v_first_session_question_id uuid;
  v_question_total integer := 0;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to create game sessions';
  end if;

  v_title := nullif(btrim(coalesce(p_title, '')), '');
  if v_title is null then
    raise exception 'title is required';
  end if;

  if p_pack_id is not null then
    select *
      into v_pack
    from africlub_game.question_packs
    where id = p_pack_id
      and club_id = p_club_id
      and status = 'published';

    if not found then
      raise exception 'Published question pack not found';
    end if;
  end if;

  if p_tv_device_id is not null then
    perform 1
    from africlub_game.tv_devices
    where id = p_tv_device_id
      and club_id = p_club_id;

    if not found then
      raise exception 'TV device not found';
    end if;
  end if;

  v_join_code := upper(nullif(btrim(coalesce(p_join_code, '')), ''));
  if v_join_code is null then
    v_join_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  end if;

  insert into africlub_game.game_sessions (
    club_id,
    pack_id,
    template_id,
    tv_device_id,
    title,
    status,
    join_code,
    created_by
  )
  values (
    p_club_id,
    p_pack_id,
    v_pack.template_id,
    p_tv_device_id,
    left(v_title, 120),
    'lobby',
    left(v_join_code, 32),
    auth.uid()
  )
  returning * into v_session;

  if p_pack_id is not null then
    insert into africlub_game.session_questions (
      club_id,
      session_id,
      question_id,
      ordinal
    )
    select p_club_id,
           v_session.id,
           qpq.question_id,
           qpq.ordinal
      from africlub_game.question_pack_questions qpq
     where qpq.pack_id = p_pack_id
     order by qpq.ordinal;
  end if;

  select count(*)
    into v_question_total
  from africlub_game.session_questions
  where session_id = v_session.id;

  select id
    into v_first_session_question_id
  from africlub_game.session_questions
  where session_id = v_session.id
  order by ordinal asc
  limit 1;

  if p_tv_device_id is not null then
    update africlub_game.tv_devices
       set status = 'paired',
           current_session_id = v_session.id,
           updated_at = timezone('utc', now())
     where id = p_tv_device_id;
  end if;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    p_club_id,
    auth.uid(),
    'game_session_created',
    'game_session',
    v_session.id,
    jsonb_build_object(
      'pack_id', p_pack_id,
      'tv_device_id', p_tv_device_id,
      'question_total', v_question_total
    )
  );

  return jsonb_build_object(
    'sessionId', v_session.id,
    'joinCode', v_session.join_code,
    'title', v_session.title,
    'status', v_session.status,
    'questionTotal', v_question_total,
    'firstSessionQuestionId', v_first_session_question_id,
    'tvDeviceId', p_tv_device_id
  );
end;
$$;

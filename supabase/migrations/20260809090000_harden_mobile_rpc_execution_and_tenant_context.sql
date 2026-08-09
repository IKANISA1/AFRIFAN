begin;

-- A client-supplied club identifier is a filter, never authority. Anonymous
-- Auth users still carry the authenticated database role and must resolve the
-- same server-controlled tenant as every other signed-in caller.
create or replace function public.fet_require_club_context(
  p_club_id bigint default null
) returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_claims jsonb := coalesce(
    nullif(pg_catalog.current_setting('request.jwt.claims', true), '')::jsonb,
    '{}'::jsonb
  );
  v_role text;
  v_trusted_club_id bigint;
begin
  v_role := coalesce(
    nullif(pg_catalog.current_setting('request.jwt.claim.role', true), ''),
    nullif(v_claims ->> 'role', '')
  );

  begin
    v_trusted_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A valid trusted club context is required.';
  end;

  if v_role = 'service_role' then
    v_trusted_club_id := coalesce(p_club_id, v_trusted_club_id);
  else
    if v_actor_id is null then
      raise exception 'Authentication is required.';
    end if;

    if v_trusted_club_id is null then
      raise exception 'A trusted club context is required.';
    end if;

    if p_club_id is not null and p_club_id is distinct from v_trusted_club_id then
      raise exception 'Requested club does not match the authenticated club context.';
    end if;
  end if;

  if v_trusted_club_id is null then
    raise exception 'Club context required for FET wallet operations.';
  end if;

  return v_trusted_club_id;
end;
$$;

-- These routines are implementation helpers for trusted definer functions,
-- not public Data API endpoints. Their bodies already qualify application
-- objects, so an empty path is safe and prevents name shadowing.
alter function public.fet_wallet_resolve_partner_id(bigint, text)
  set search_path = '';
alter function public.fet_wallet_ensure_membership(uuid, bigint)
  set search_path = '';
alter function public.fet_wallet_append_entry(
  bigint,
  uuid,
  uuid,
  text,
  text,
  integer,
  integer,
  uuid,
  text,
  text,
  text,
  text,
  jsonb,
  uuid
) set search_path = '';
alter function public.add_fan_points(uuid, text, integer, text)
  set search_path = '';

revoke execute on function public.fet_require_club_context(bigint)
  from public, anon, authenticated, service_role;
revoke execute on function public.fet_wallet_resolve_partner_id(bigint, text)
  from public, anon, authenticated, service_role;
revoke execute on function public.fet_wallet_ensure_membership(uuid, bigint)
  from public, anon, authenticated, service_role;
revoke execute on function public.fet_wallet_append_entry(
  bigint,
  uuid,
  uuid,
  text,
  text,
  integer,
  integer,
  uuid,
  text,
  text,
  text,
  text,
  jsonb,
  uuid
) from public, anon, authenticated, service_role;

grant execute on function public.fet_require_club_context(bigint)
  to service_role;
grant execute on function public.fet_wallet_resolve_partner_id(bigint, text)
  to service_role;
grant execute on function public.fet_wallet_ensure_membership(uuid, bigint)
  to service_role;
grant execute on function public.fet_wallet_append_entry(
  bigint,
  uuid,
  uuid,
  text,
  text,
  integer,
  integer,
  uuid,
  text,
  text,
  text,
  text,
  jsonb,
  uuid
) to service_role;

-- Preserve the mature venue implementations behind non-API helper names and
-- expose wrappers that prove the request tenant before any lookup or write.
alter function public.venue_checkin_validate(bigint, text, text, numeric)
  rename to venue_checkin_validate_unscoped_internal;

revoke execute on function public.venue_checkin_validate_unscoped_internal(
  bigint,
  text,
  text,
  numeric
) from public, anon, authenticated, service_role;
grant execute on function public.venue_checkin_validate_unscoped_internal(
  bigint,
  text,
  text,
  numeric
) to service_role;

create function public.venue_checkin_validate(
  p_club_id bigint,
  p_code_hash text,
  p_idempotency_key text default null,
  p_location_accuracy_meters numeric default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id bigint;
begin
  v_club_id := public.fet_require_club_context(p_club_id);
  return public.venue_checkin_validate_unscoped_internal(
    v_club_id,
    p_code_hash,
    p_idempotency_key,
    p_location_accuracy_meters
  );
end;
$$;

alter function public.venue_order_create(bigint, uuid, uuid, jsonb, boolean, text)
  rename to venue_order_create_unscoped_internal;

revoke execute on function public.venue_order_create_unscoped_internal(
  bigint,
  uuid,
  uuid,
  jsonb,
  boolean,
  text
) from public, anon, authenticated, service_role;
grant execute on function public.venue_order_create_unscoped_internal(
  bigint,
  uuid,
  uuid,
  jsonb,
  boolean,
  text
) to service_role;

create function public.venue_order_create(
  p_club_id bigint,
  p_venue_id uuid,
  p_checkin_id uuid,
  p_items jsonb,
  p_age_gate_confirmed boolean,
  p_idempotency_key text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id bigint;
begin
  v_club_id := public.fet_require_club_context(p_club_id);
  return public.venue_order_create_unscoped_internal(
    v_club_id,
    p_venue_id,
    p_checkin_id,
    p_items,
    p_age_gate_confirmed,
    p_idempotency_key
  );
end;
$$;

-- Reset every directly invoked mobile RPC first. This removes inherited
-- PUBLIC execution before the reviewed role matrix is re-applied.
revoke execute on function public.add_fan_points(uuid,text,integer,text) from public, anon, authenticated, service_role;
revoke execute on function public.cancel_shop_order_if_unchanged(uuid,timestamptz) from public, anon, authenticated, service_role;
revoke execute on function public.cancel_ticket_if_unchanged(uuid,timestamptz) from public, anon, authenticated, service_role;
revoke execute on function public.fet_find_supporters(text,bigint,integer) from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_catalog(bigint,boolean) from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_friends(bigint,integer,text) from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_leaderboard(bigint,integer) from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_partner_offers(bigint,boolean,integer) from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_reward_redemptions(integer,integer,bigint) from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_wallet(bigint) from public, anon, authenticated, service_role;
revoke execute on function public.fet_get_wallet_transactions(bigint,integer,integer) from public, anon, authenticated, service_role;
revoke execute on function public.fet_redeem(integer,text,text,bigint) from public, anon, authenticated, service_role;
revoke execute on function public.fet_redeem_reward(uuid,text,text,bigint) from public, anon, authenticated, service_role;
revoke execute on function public.fet_request_friend(uuid,bigint,text) from public, anon, authenticated, service_role;
revoke execute on function public.fet_respond_friend_request(uuid,text,bigint) from public, anon, authenticated, service_role;
revoke execute on function public.fet_search_supporters(text,bigint,integer) from public, anon, authenticated, service_role;
revoke execute on function public.fet_transfer(uuid,integer,text,text,bigint) from public, anon, authenticated, service_role;
revoke execute on function public.fixtures_calendar(date,date,text,text,integer) from public, anon, authenticated, service_role;
revoke execute on function public.fixtures_date_summary(date,date,text) from public, anon, authenticated, service_role;
revoke execute on function public.get_eligible_game_sessions_v2(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.get_momo_sms_operational_summary() from public, anon, authenticated, service_role;
revoke execute on function public.get_participant_game_projection_v2(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.get_platform_config(text,bigint) from public, anon, authenticated, service_role;
revoke execute on function public.is_super_admin() from public, anon, authenticated, service_role;
revoke execute on function public.partner_prediction_pool_feed(bigint,text[],integer,integer) from public, anon, authenticated, service_role;
revoke execute on function public.partner_prediction_pool_join(uuid,text,text) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_admin_get_challenges(bigint,text[],integer,integer) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_cancel(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_admin_retry_settlement(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_cancel(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_create(uuid,integer,integer,bigint,bigint) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_challenge_join(uuid,integer,integer) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_create_friend_challenge(uuid,uuid,text,text) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_active(integer,integer) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_active_jackpot_round(bigint) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_challenge_detail(uuid,bigint) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_challenge_feed(bigint,text[],text,integer,integer,boolean) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_detail(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_fixture_markets(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_history(integer,integer) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_match_center(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_my_challenges(bigint,text[],text,integer,integer) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_user_badges(uuid) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_get_user_stats() from public, anon, authenticated, service_role;
revoke execute on function public.prediction_place(uuid,text) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_place_acca(jsonb) from public, anon, authenticated, service_role;
revoke execute on function public.prediction_place_jackpot_entry(uuid,jsonb,text) from public, anon, authenticated, service_role;
revoke execute on function public.purchase_club_tickets(uuid,uuid,text,integer,text) from public, anon, authenticated, service_role;
revoke execute on function public.submit_participant_answer_v2(uuid,uuid,text,bigint,bigint,text) from public, anon, authenticated, service_role;
revoke execute on function public.venue_checkin_validate(bigint,text,text,numeric) from public, anon, authenticated, service_role;
revoke execute on function public.venue_order_create(bigint,uuid,uuid,jsonb,boolean,text) from public, anon, authenticated, service_role;

-- Trusted service-only award entry point. The released client does not mint
-- arbitrary points.
grant execute on function public.add_fan_points(uuid,text,integer,text)
  to service_role;

-- Public, read-only catalog/configuration endpoints.
grant execute on function public.fet_get_catalog(bigint,boolean)
  to anon, authenticated, service_role;
grant execute on function public.fet_get_leaderboard(bigint,integer)
  to anon, authenticated, service_role;
grant execute on function public.fet_get_partner_offers(bigint,boolean,integer)
  to anon, authenticated, service_role;
grant execute on function public.get_platform_config(text,bigint)
  to anon, authenticated, service_role;
grant execute on function public.prediction_get_match_center(uuid)
  to anon, authenticated, service_role;

grant execute on function public.fixtures_calendar(date,date,text,text,integer)
  to anon, authenticated;
grant execute on function public.fixtures_date_summary(date,date,text)
  to anon, authenticated;
grant execute on function public.prediction_get_fixture_markets(uuid)
  to anon, authenticated;

-- Authenticated supporter endpoints also used by trusted server operations.
grant execute on function public.fet_find_supporters(text,bigint,integer) to authenticated, service_role;
grant execute on function public.fet_get_friends(bigint,integer,text) to authenticated, service_role;
grant execute on function public.fet_get_reward_redemptions(integer,integer,bigint) to authenticated, service_role;
grant execute on function public.fet_get_wallet(bigint) to authenticated, service_role;
grant execute on function public.fet_get_wallet_transactions(bigint,integer,integer) to authenticated, service_role;
grant execute on function public.fet_redeem(integer,text,text,bigint) to authenticated, service_role;
grant execute on function public.fet_redeem_reward(uuid,text,text,bigint) to authenticated, service_role;
grant execute on function public.fet_request_friend(uuid,bigint,text) to authenticated, service_role;
grant execute on function public.fet_respond_friend_request(uuid,text,bigint) to authenticated, service_role;
grant execute on function public.fet_search_supporters(text,bigint,integer) to authenticated, service_role;
grant execute on function public.fet_transfer(uuid,integer,text,text,bigint) to authenticated, service_role;
grant execute on function public.partner_prediction_pool_feed(bigint,text[],integer,integer) to authenticated, service_role;
grant execute on function public.prediction_create_friend_challenge(uuid,uuid,text,text) to authenticated, service_role;
grant execute on function public.prediction_get_active_jackpot_round(bigint) to authenticated, service_role;
grant execute on function public.prediction_place_jackpot_entry(uuid,jsonb,text) to authenticated, service_role;

-- User/session-bound endpoints. Their bodies perform the finer role and object
-- authorization checks, but an unauthenticated API role cannot enter them.
grant execute on function public.cancel_shop_order_if_unchanged(uuid,timestamptz) to authenticated;
grant execute on function public.cancel_ticket_if_unchanged(uuid,timestamptz) to authenticated;
grant execute on function public.get_eligible_game_sessions_v2(uuid) to authenticated;
grant execute on function public.get_momo_sms_operational_summary() to authenticated;
grant execute on function public.get_participant_game_projection_v2(uuid) to authenticated;
grant execute on function public.is_super_admin() to authenticated;
grant execute on function public.partner_prediction_pool_join(uuid,text,text) to authenticated;
grant execute on function public.prediction_admin_get_challenges(bigint,text[],integer,integer) to authenticated;
grant execute on function public.prediction_cancel(uuid) to authenticated;
grant execute on function public.prediction_challenge_admin_retry_settlement(uuid) to authenticated;
grant execute on function public.prediction_challenge_cancel(uuid) to authenticated;
grant execute on function public.prediction_challenge_create(uuid,integer,integer,bigint,bigint) to authenticated;
grant execute on function public.prediction_challenge_join(uuid,integer,integer) to authenticated;
grant execute on function public.prediction_get_active(integer,integer) to authenticated;
grant execute on function public.prediction_get_challenge_detail(uuid,bigint) to authenticated;
grant execute on function public.prediction_get_challenge_feed(bigint,text[],text,integer,integer,boolean) to authenticated;
grant execute on function public.prediction_get_detail(uuid) to authenticated;
grant execute on function public.prediction_get_history(integer,integer) to authenticated;
grant execute on function public.prediction_get_my_challenges(bigint,text[],text,integer,integer) to authenticated;
grant execute on function public.prediction_get_user_badges(uuid) to authenticated;
grant execute on function public.prediction_get_user_stats() to authenticated;
grant execute on function public.prediction_place(uuid,text) to authenticated;
grant execute on function public.prediction_place_acca(jsonb) to authenticated;
grant execute on function public.purchase_club_tickets(uuid,uuid,text,integer,text) to authenticated;
grant execute on function public.submit_participant_answer_v2(uuid,uuid,text,bigint,bigint,text) to authenticated;
grant execute on function public.venue_checkin_validate(bigint,text,text,numeric) to authenticated;
grant execute on function public.venue_order_create(bigint,uuid,uuid,jsonb,boolean,text) to authenticated;

commit;

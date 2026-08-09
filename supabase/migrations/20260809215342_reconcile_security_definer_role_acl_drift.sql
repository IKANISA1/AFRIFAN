-- Reconcile hosted direct grants to the exact ACL produced by a clean replay.
-- This removes historical Dashboard/API drift while preserving only the
-- reviewed anonymous and authenticated RPC/RLS-helper contracts.
do $migration$
declare
  function_signature text;
begin
  for function_signature in
    select p.oid::regprocedure::text
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where p.prosecdef
      and n.nspname in ('public', 'football', 'africlub_game')
  loop
    execute format(
      'revoke execute on function %s from anon, authenticated',
      function_signature
    );
  end loop;
end
$migration$;

-- Exact anonymous allowlist.
grant execute on function public.check_feature_enabled(text,text,bigint) to anon;
grant execute on function public.create_display_pairing_challenge_v2(text,text,jsonb) to anon;
grant execute on function public.exchange_display_pairing_challenge_v2(text,text) to anon;
grant execute on function public.exchange_tv_pairing_code(text,bigint) to anon;
grant execute on function public.fet_get_catalog(bigint,boolean) to anon;
grant execute on function public.fet_resolve_public_club_id(bigint) to anon;
grant execute on function public.fixtures_calendar(date,date,text,text,integer) to anon;
grant execute on function public.fixtures_date_summary(date,date,text) to anon;
grant execute on function public.get_feature_access_state(text,text,bigint,boolean,text[]) to anon;
grant execute on function public.get_platform_config(text,bigint) to anon;
grant execute on function public.get_platform_option_set(text,text,bigint) to anon;
grant execute on function public.get_runtime_app_config(text,bigint) to anon;
grant execute on function public.get_tv_display_state_with_credential(text) to anon;
grant execute on function public.get_tv_game_projection_v2(text) to anon;
grant execute on function public.is_admin() to anon;
grant execute on function public.is_club_admin(bigint) to anon;
grant execute on function public.prediction_get_fixture_markets(uuid) to anon;
grant execute on function public.prediction_get_match_center(uuid) to anon;
grant execute on function public.requesting_club_id() to anon;

-- Exact authenticated allowlist.
grant execute on function africlub_game.admin_advance_question(uuid) to authenticated;
grant execute on function africlub_game.admin_close_session(uuid) to authenticated;
grant execute on function africlub_game.admin_create_session(bigint,text,uuid,uuid,text) to authenticated;
grant execute on function africlub_game.admin_list_audit_log(bigint,integer,text,text,integer) to authenticated;
grant execute on function africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer) to authenticated;
grant execute on function africlub_game.admin_open_question(uuid) to authenticated;
grant execute on function africlub_game.admin_pair_tv_device(bigint,text,text,uuid) to authenticated;
grant execute on function africlub_game.admin_reveal_question(uuid) to authenticated;
grant execute on function africlub_game.admin_review_question_draft(uuid,text,text) to authenticated;
grant execute on function africlub_game.admin_revoke_tv_device(bigint,uuid,text) to authenticated;
grant execute on function africlub_game.allowed_session_phases_v2(uuid) to authenticated;
grant execute on function africlub_game.can_assign_display_to_session(uuid,uuid) to authenticated;
grant execute on function africlub_game.can_manage_display(uuid) to authenticated;
grant execute on function africlub_game.can_organize_session(uuid) to authenticated;
grant execute on function africlub_game.can_plan_games(bigint) to authenticated;
grant execute on function africlub_game.get_tv_display_state(uuid,text,bigint) to authenticated;
grant execute on function africlub_game.has_role(bigint,text,uuid) to authenticated;
grant execute on function africlub_game.is_game_admin(bigint) to authenticated;
grant execute on function africlub_game.is_session_participant(uuid) to authenticated;
grant execute on function africlub_game.is_tv_session_subscriber(uuid) to authenticated;
grant execute on function public.activate_free_fan_membership() to authenticated;
grant execute on function public.admin_get_shop_products(integer,integer,boolean) to authenticated;
grant execute on function public.assign_game_organizer_v2(uuid,uuid,text) to authenticated;
grant execute on function public.assign_managed_game_display_v2(uuid,uuid,text) to authenticated;
grant execute on function public.bind_tv_realtime_identity_v2(text) to authenticated;
grant execute on function public.bootstrap_supporter_profile(bigint,text,text,text,text) to authenticated;
grant execute on function public.cancel_pending_group_contribution_payment_launch(uuid) to authenticated;
grant execute on function public.cancel_shop_order_if_unchanged(uuid,timestamp with time zone) to authenticated;
grant execute on function public.cancel_ticket_if_unchanged(uuid,timestamp with time zone) to authenticated;
grant execute on function public.check_feature_enabled(text,text,bigint) to authenticated;
grant execute on function public.claim_display_bootstrap_challenge_v2(text,text,text,uuid) to authenticated;
grant execute on function public.create_display_pairing_challenge_v2(text,text,jsonb) to authenticated;
grant execute on function public.create_managed_game_session_v2(uuid,timestamp with time zone,text,uuid[],text,uuid[],uuid[]) to authenticated;
grant execute on function public.create_pending_group_contribution(uuid,integer,text,text) to authenticated;
grant execute on function public.end_managed_game_session_v2(uuid,bigint,text,text) to authenticated;
grant execute on function public.exchange_display_pairing_challenge_v2(text,text) to authenticated;
grant execute on function public.exchange_tv_pairing_code(text,bigint) to authenticated;
grant execute on function public.fet_admin_adjust_balance(uuid,integer,text,text,bigint) to authenticated;
grant execute on function public.fet_admin_get_wallet_ledger(bigint,text,uuid,integer,integer) to authenticated;
grant execute on function public.fet_admin_get_wallet_overview(bigint,text,integer,integer) to authenticated;
grant execute on function public.fet_admin_update_reward_redemption(uuid,text,text,text,text) to authenticated;
grant execute on function public.fet_get_catalog(bigint,boolean) to authenticated;
grant execute on function public.fet_get_reward_redemptions(integer,integer,bigint) to authenticated;
grant execute on function public.fet_get_wallet_transactions(bigint,integer,integer) to authenticated;
grant execute on function public.fet_get_wallet(bigint) to authenticated;
grant execute on function public.fet_resolve_public_club_id(bigint) to authenticated;
grant execute on function public.fixtures_calendar(date,date,text,text,integer) to authenticated;
grant execute on function public.fixtures_date_summary(date,date,text) to authenticated;
grant execute on function public.get_admin_game_projection_v2(uuid) to authenticated;
grant execute on function public.get_club_fan_analytics(bigint) to authenticated;
grant execute on function public.get_club_member_registry(bigint,text,text,text,integer,integer) to authenticated;
grant execute on function public.get_eligible_game_sessions_v2(uuid) to authenticated;
grant execute on function public.get_feature_access_state(text,text,bigint,boolean,text[]) to authenticated;
grant execute on function public.get_game_planner_options_v2() to authenticated;
grant execute on function public.get_managed_game_sessions_v2() to authenticated;
grant execute on function public.get_momo_sms_operational_summary() to authenticated;
grant execute on function public.get_organizer_game_projection_v2(uuid) to authenticated;
grant execute on function public.get_owned_displays_v2() to authenticated;
grant execute on function public.get_participant_game_projection_v2(uuid) to authenticated;
grant execute on function public.get_partner_member_registry(uuid,text,text,text,integer,integer) to authenticated;
grant execute on function public.get_platform_config(text,bigint) to authenticated;
grant execute on function public.get_platform_option_set(text,text,bigint) to authenticated;
grant execute on function public.get_runtime_app_config(text,bigint) to authenticated;
grant execute on function public.get_tv_display_state_with_credential(text) to authenticated;
grant execute on function public.get_tv_display_state(uuid,text,bigint) to authenticated;
grant execute on function public.get_tv_game_projection_v2(text) to authenticated;
grant execute on function public.is_admin_user() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_club_admin(bigint) to authenticated;
grant execute on function public.is_group_member(uuid,uuid) to authenticated;
grant execute on function public.is_partner_admin(uuid) to authenticated;
grant execute on function public.is_super_admin() to authenticated;
grant execute on function public.partner_fet_record_earn_event(uuid,uuid,integer,uuid,text,text,text,text,jsonb,bigint) to authenticated;
grant execute on function public.prediction_admin_get_challenges(bigint,text[],integer,integer) to authenticated;
grant execute on function public.prediction_cancel(uuid) to authenticated;
grant execute on function public.prediction_challenge_admin_retry_settlement(uuid) to authenticated;
grant execute on function public.prediction_challenge_cancel(uuid) to authenticated;
grant execute on function public.prediction_challenge_fixture_json(uuid) to authenticated;
grant execute on function public.prediction_get_active(integer,integer) to authenticated;
grant execute on function public.prediction_get_dashboard() to authenticated;
grant execute on function public.prediction_get_detail(uuid) to authenticated;
grant execute on function public.prediction_get_fixture_markets(uuid) to authenticated;
grant execute on function public.prediction_get_history(integer,integer) to authenticated;
grant execute on function public.prediction_get_match_center(uuid) to authenticated;
grant execute on function public.prediction_get_user_badges(uuid) to authenticated;
grant execute on function public.prediction_get_user_stats() to authenticated;
grant execute on function public.prediction_place_acca(jsonb) to authenticated;
grant execute on function public.prediction_place(uuid,text) to authenticated;
grant execute on function public.recover_owned_display_from_bootstrap_v2(uuid,text,text) to authenticated;
grant execute on function public.requesting_club_id() to authenticated;
grant execute on function public.resolve_partner_ids_for_club(bigint) to authenticated;
grant execute on function public.revoke_owned_display_v2(uuid,text) to authenticated;
grant execute on function public.rs_is_partner_admin(uuid) to authenticated;
grant execute on function public.skip_managed_game_question_v2(uuid,uuid,bigint,text,text) to authenticated;
grant execute on function public.submit_participant_answer_v2(uuid,uuid,text,bigint,bigint,text) to authenticated;
grant execute on function public.transition_managed_game_session_v2(uuid,text,bigint,text,uuid,timestamp with time zone,text) to authenticated;
grant execute on function public.unassign_managed_game_display_v2(uuid,uuid,text) to authenticated;
grant execute on function public.update_owned_display_v2(uuid,text,text,uuid,text) to authenticated;
grant execute on function public.user_has_admin_workspace_access(bigint,uuid) to authenticated;
grant execute on function public.venue_checkin_validate(bigint,text,text,numeric) to authenticated;
grant execute on function public.venue_menu_upsert(uuid,uuid,text,text,integer,text,boolean,boolean,integer) to authenticated;
grant execute on function public.venue_order_create(bigint,uuid,uuid,jsonb,boolean,text) to authenticated;
grant execute on function public.venue_promotion_launch(uuid,uuid,text) to authenticated;
grant execute on function public.venue_staff_can_access(uuid,text[]) to authenticated;

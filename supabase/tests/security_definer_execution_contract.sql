begin;

select plan(8);

create temporary table expected_anonymous_security_definer_functions (
  signature text primary key
) on commit drop;

insert into expected_anonymous_security_definer_functions (signature) values
  ('public.check_feature_enabled(p_feature_key text, p_channel text, p_club_id bigint)'),
  ('public.create_display_pairing_challenge_v2(p_installation_nonce text, p_app_version text, p_capabilities jsonb)'),
  ('public.exchange_display_pairing_challenge_v2(p_challenge text, p_installation_nonce text)'),
  ('public.exchange_tv_pairing_code(p_pairing_code text, p_club_id bigint)'),
  ('public.fet_get_catalog(p_club_id bigint, p_include_inactive boolean)'),
  ('public.fet_resolve_public_club_id(p_club_id bigint)'),
  ('public.fixtures_calendar(p_date_from date, p_date_to date, p_competition_slug text, p_status text, p_limit integer)'),
  ('public.fixtures_date_summary(p_date_from date, p_date_to date, p_competition_slug text)'),
  ('public.get_feature_access_state(p_feature_key text, p_channel text, p_club_id bigint, p_is_authenticated boolean, p_roles text[])'),
  ('public.get_platform_config(p_channel text, p_club_id bigint)'),
  ('public.get_platform_option_set(p_option_set_key text, p_channel text, p_club_id bigint)'),
  ('public.get_runtime_app_config(p_key text, p_club_id bigint)'),
  ('public.get_tv_display_state_with_credential(p_device_token text)'),
  ('public.get_tv_game_projection_v2(p_device_token text)'),
  ('public.is_admin()'),
  ('public.is_club_admin(p_club_id bigint)'),
  ('public.prediction_get_fixture_markets(p_fixture_id uuid)'),
  ('public.prediction_get_match_center(p_fixture_id uuid)'),
  ('public.requesting_club_id()');

create temporary view actual_anonymous_security_definer_functions as
select
  n.nspname || '.' || p.proname || '(' ||
    pg_get_function_identity_arguments(p.oid) || ')' as signature
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.prosecdef
  and n.nspname in ('public', 'football', 'africlub_game')
  and has_function_privilege('anon', p.oid, 'execute');

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(
      coalesce(p.proacl, acldefault('f', p.proowner))
    ) acl
    where p.prosecdef
      and n.nspname in ('public', 'football', 'africlub_game')
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  0,
  'no exposed security-definer function inherits PUBLIC execute'
);

select is(
  (select count(*)::integer from actual_anonymous_security_definer_functions),
  19,
  'anonymous execution is limited to the governed endpoint count'
);

select is(
  (
    select count(*)::integer
    from actual_anonymous_security_definer_functions actual
    left join expected_anonymous_security_definer_functions expected
      using (signature)
    where expected.signature is null
  ),
  0,
  'no unexpected security-definer endpoint is anonymous-executable'
);

select is(
  (
    select count(*)::integer
    from expected_anonymous_security_definer_functions expected
    left join actual_anonymous_security_definer_functions actual
      using (signature)
    where actual.signature is null
  ),
  0,
  'every governed anonymous endpoint retains its explicit grant'
);

select is(
  (
    select count(*)::integer
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'football', 'africlub_game')
      and p.prokind = 'f'
      and p.proconfig is null
  ),
  0,
  'all exposed application functions have a governed search path'
);


create temporary table expected_authenticated_security_definer_functions (
  signature text primary key
) on commit drop;

insert into expected_authenticated_security_definer_functions (signature) values
  ('africlub_game.admin_advance_question(uuid)'),
  ('africlub_game.admin_close_session(uuid)'),
  ('africlub_game.admin_create_session(bigint,text,uuid,uuid,text)'),
  ('africlub_game.admin_list_audit_log(bigint,integer,text,text,integer)'),
  ('africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer)'),
  ('africlub_game.admin_open_question(uuid)'),
  ('africlub_game.admin_pair_tv_device(bigint,text,text,uuid)'),
  ('africlub_game.admin_reveal_question(uuid)'),
  ('africlub_game.admin_review_question_draft(uuid,text,text)'),
  ('africlub_game.admin_revoke_tv_device(bigint,uuid,text)'),
  ('africlub_game.allowed_session_phases_v2(uuid)'),
  ('africlub_game.can_assign_display_to_session(uuid,uuid)'),
  ('africlub_game.can_manage_display(uuid)'),
  ('africlub_game.can_organize_session(uuid)'),
  ('africlub_game.can_plan_games(bigint)'),
  ('africlub_game.get_tv_display_state(uuid,text,bigint)'),
  ('africlub_game.has_role(bigint,text,uuid)'),
  ('africlub_game.is_game_admin(bigint)'),
  ('africlub_game.is_session_participant(uuid)'),
  ('africlub_game.is_tv_session_subscriber(uuid)'),
  ('activate_free_fan_membership()'),
  ('admin_get_shop_products(integer,integer,boolean)'),
  ('assign_game_organizer_v2(uuid,uuid,text)'),
  ('assign_managed_game_display_v2(uuid,uuid,text)'),
  ('bind_tv_realtime_identity_v2(text)'),
  ('bootstrap_supporter_profile(bigint,text,text,text,text)'),
  ('cancel_pending_group_contribution_payment_launch(uuid)'),
  ('cancel_shop_order_if_unchanged(uuid,timestamp with time zone)'),
  ('cancel_ticket_if_unchanged(uuid,timestamp with time zone)'),
  ('check_feature_enabled(text,text,bigint)'),
  ('claim_display_bootstrap_challenge_v2(text,text,text,uuid)'),
  ('create_display_pairing_challenge_v2(text,text,jsonb)'),
  ('create_managed_game_session_v2(uuid,timestamp with time zone,text,uuid[],text,uuid[],uuid[])'),
  ('create_pending_group_contribution(uuid,integer,text,text)'),
  ('end_managed_game_session_v2(uuid,bigint,text,text)'),
  ('exchange_display_pairing_challenge_v2(text,text)'),
  ('exchange_tv_pairing_code(text,bigint)'),
  ('fet_admin_adjust_balance(uuid,integer,text,text,bigint)'),
  ('fet_admin_get_wallet_ledger(bigint,text,uuid,integer,integer)'),
  ('fet_admin_get_wallet_overview(bigint,text,integer,integer)'),
  ('fet_admin_update_reward_redemption(uuid,text,text,text,text)'),
  ('fet_get_catalog(bigint,boolean)'),
  ('fet_get_reward_redemptions(integer,integer,bigint)'),
  ('fet_get_wallet_transactions(bigint,integer,integer)'),
  ('fet_get_wallet(bigint)'),
  ('fet_resolve_public_club_id(bigint)'),
  ('fixtures_calendar(date,date,text,text,integer)'),
  ('fixtures_date_summary(date,date,text)'),
  ('get_admin_game_projection_v2(uuid)'),
  ('get_club_fan_analytics(bigint)'),
  ('get_club_member_registry(bigint,text,text,text,integer,integer)'),
  ('get_eligible_game_sessions_v2(uuid)'),
  ('get_feature_access_state(text,text,bigint,boolean,text[])'),
  ('get_game_planner_options_v2()'),
  ('get_managed_game_sessions_v2()'),
  ('get_momo_sms_operational_summary()'),
  ('get_organizer_game_projection_v2(uuid)'),
  ('get_owned_displays_v2()'),
  ('get_participant_game_projection_v2(uuid)'),
  ('get_partner_member_registry(uuid,text,text,text,integer,integer)'),
  ('get_platform_config(text,bigint)'),
  ('get_platform_option_set(text,text,bigint)'),
  ('get_runtime_app_config(text,bigint)'),
  ('get_tv_display_state_with_credential(text)'),
  ('get_tv_display_state(uuid,text,bigint)'),
  ('get_tv_game_projection_v2(text)'),
  ('is_admin_user()'),
  ('is_admin()'),
  ('is_club_admin(bigint)'),
  ('is_group_member(uuid,uuid)'),
  ('is_partner_admin(uuid)'),
  ('is_super_admin()'),
  ('partner_fet_record_earn_event(uuid,uuid,integer,uuid,text,text,text,text,jsonb,bigint)'),
  ('prediction_admin_get_challenges(bigint,text[],integer,integer)'),
  ('prediction_cancel(uuid)'),
  ('prediction_challenge_admin_retry_settlement(uuid)'),
  ('prediction_challenge_cancel(uuid)'),
  ('prediction_challenge_fixture_json(uuid)'),
  ('prediction_get_active(integer,integer)'),
  ('prediction_get_dashboard()'),
  ('prediction_get_detail(uuid)'),
  ('prediction_get_fixture_markets(uuid)'),
  ('prediction_get_history(integer,integer)'),
  ('prediction_get_match_center(uuid)'),
  ('prediction_get_user_badges(uuid)'),
  ('prediction_get_user_stats()'),
  ('prediction_place_acca(jsonb)'),
  ('prediction_place(uuid,text)'),
  ('recover_owned_display_from_bootstrap_v2(uuid,text,text)'),
  ('requesting_club_id()'),
  ('resolve_partner_ids_for_club(bigint)'),
  ('revoke_owned_display_v2(uuid,text)'),
  ('rs_is_partner_admin(uuid)'),
  ('skip_managed_game_question_v2(uuid,uuid,bigint,text,text)'),
  ('submit_participant_answer_v2(uuid,uuid,text,bigint,bigint,text)'),
  ('transition_managed_game_session_v2(uuid,text,bigint,text,uuid,timestamp with time zone,text)'),
  ('unassign_managed_game_display_v2(uuid,uuid,text)'),
  ('update_owned_display_v2(uuid,text,text,uuid,text)'),
  ('user_has_admin_workspace_access(bigint,uuid)'),
  ('venue_checkin_validate(bigint,text,text,numeric)'),
  ('venue_menu_upsert(uuid,uuid,text,text,integer,text,boolean,boolean,integer)'),
  ('venue_order_create(bigint,uuid,uuid,jsonb,boolean,text)'),
  ('venue_promotion_launch(uuid,uuid,text)'),
  ('venue_staff_can_access(uuid,text[])');

create temporary view actual_authenticated_security_definer_functions as
select p.oid::regprocedure::text as signature
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.prosecdef
  and n.nspname in ('public', 'football', 'africlub_game')
  and has_function_privilege('authenticated', p.oid, 'execute');

select is(
  (select count(*)::integer from actual_authenticated_security_definer_functions),
  104,
  'authenticated execution is limited to the governed endpoint count'
);

select is(
  (
    select count(*)::integer
    from actual_authenticated_security_definer_functions actual
    left join expected_authenticated_security_definer_functions expected
      using (signature)
    where expected.signature is null
  ),
  0,
  'no unexpected security-definer endpoint is authenticated-executable'
);

select is(
  (
    select count(*)::integer
    from expected_authenticated_security_definer_functions expected
    left join actual_authenticated_security_definer_functions actual
      using (signature)
    where actual.signature is null
  ),
  0,
  'every governed authenticated endpoint retains its explicit grant'
);

select * from finish();
rollback;

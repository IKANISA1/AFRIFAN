begin;

select plan(8);

create temporary table expected_anonymous_security_definer_functions (
  signature text primary key
) on commit drop;

insert into expected_anonymous_security_definer_functions (signature) values
  ('public.resolve_club_public_link_v1(p_club_id bigint, p_source_path text)'),
  ('public.club_public_content_manifest_v1(p_club_id bigint)'),
  ('public.club_public_overview(p_club_id bigint)'),
  ('public.club_public_history(p_club_id bigint)'),
  ('public.predict_dashboard(p_club_id bigint)'),
  ('public.check_feature_enabled(p_feature_key text, p_channel text, p_club_id bigint)'),
  ('public.fet_get_catalog(p_club_id bigint, p_include_inactive boolean)'),
  ('public.fet_resolve_public_club_id(p_club_id bigint)'),
  ('public.fixtures_calendar(p_date_from date, p_date_to date, p_competition_slug text, p_status text, p_limit integer)'),
  ('public.fixtures_date_summary(p_date_from date, p_date_to date, p_competition_slug text)'),
  ('public.get_feature_access_state(p_feature_key text, p_channel text, p_club_id bigint, p_is_authenticated boolean, p_roles text[])'),
  ('public.get_platform_config(p_channel text, p_club_id bigint)'),
  ('public.get_platform_option_set(p_option_set_key text, p_channel text, p_club_id bigint)'),
  ('public.get_runtime_app_config(p_key text, p_club_id bigint)'),
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
  and n.nspname in ('public', 'football')
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
      and n.nspname in ('public', 'football')
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
    where n.nspname in ('public', 'football')
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
  ('resolve_club_public_link_v1(bigint,text)'),
  ('club_public_content_manifest_v1(bigint)'),
  ('membership_qualification_v1(bigint)'),
  ('prepare_membership_payment(text)'),
  ('allocate_momo_manual_review(uuid,uuid,text)'),
  ('admin_reject_momo_sms_manual_review(uuid,text)'),
  ('admin_get_shop_products(integer,integer,boolean)'),
  ('bootstrap_supporter_profile(bigint,text,text,text,text)'),
  ('cancel_pending_group_contribution_payment_launch(uuid)'),
  ('cancel_shop_order_if_unchanged(uuid,timestamp with time zone)'),
  ('cancel_ticket_if_unchanged(uuid,timestamp with time zone)'),
  ('check_feature_enabled(text,text,bigint)'),
  ('create_pending_group_contribution(uuid,integer,text,text)'),
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
  ('get_club_fan_analytics(bigint)'),
  ('get_club_member_registry(bigint,text,text,text,integer,integer)'),
  ('get_feature_access_state(text,text,bigint,boolean,text[])'),
  ('get_momo_sms_operational_summary()'),
  ('get_momo_sms_manual_review_queue(integer,integer)'),
  ('get_partner_member_registry(uuid,text,text,text,integer,integer)'),
  ('get_platform_config(text,bigint)'),
  ('get_platform_option_set(text,text,bigint)'),
  ('get_runtime_app_config(text,bigint)'),
  ('is_admin_user()'),
  ('is_admin()'),
  ('is_club_admin(bigint)'),
  ('is_group_member(uuid,uuid)'),
  ('is_partner_admin(uuid)'),
  ('is_super_admin()'),
  ('partner_fet_record_earn_event(uuid,uuid,integer,uuid,text,text,text,text,jsonb,bigint)'),
  ('prepare_google_wallet_ticket(uuid)'),
  ('create_member_contribution_intent(uuid,integer)'),
  ('club_public_overview(bigint)'),
  ('club_public_history(bigint)'),
  ('predict_dashboard(bigint)'),
  ('predict_place(bigint,uuid,text)'),
  ('predict_admin_dashboard(bigint)'),
  ('predict_admin_settings(bigint,boolean,integer)'),
  ('predict_admin_prepare(bigint,uuid,text)'),
  ('predict_admin_confirm_result(uuid,integer,integer,text)'),
  ('predict_admin_settle(uuid,text)'),
  ('prediction_cancel(uuid)'),
  ('prediction_get_active(integer,integer)'),
  ('prediction_get_dashboard()'),
  ('prediction_get_detail(uuid)'),
  ('prediction_get_fixture_markets(uuid)'),
  ('prediction_get_history(integer,integer)'),
  ('prediction_get_match_center(uuid)'),
  ('prediction_get_user_badges(uuid)'),
  ('prediction_get_user_stats()'),
  ('requesting_club_id()'),
  ('resolve_partner_ids_for_club(bigint)'),
  ('rs_is_partner_admin(uuid)'),
  ('user_has_admin_workspace_access(bigint,uuid)');

create temporary view actual_authenticated_security_definer_functions as
select p.oid::regprocedure::text as signature
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where p.prosecdef
  and n.nspname in ('public', 'football')
  and has_function_privilege('authenticated', p.oid, 'execute');

select is(
  (select count(*)::integer from actual_authenticated_security_definer_functions),
  66,
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

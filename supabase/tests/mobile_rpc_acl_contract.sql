-- Exact mobile RPC execution and tenant-helper contract.

create extension if not exists pgtap with schema extensions;

begin;

select plan(9);

create temporary table expected_mobile_rpc_acl (
  signature text primary key,
  anon_execute boolean not null,
  authenticated_execute boolean not null,
  service_execute boolean not null
) on commit drop;

insert into expected_mobile_rpc_acl values
  ('public.add_fan_points(uuid,text,integer,text)', false, false, true),
  ('public.cancel_shop_order_if_unchanged(uuid,timestamp with time zone)', false, true, false),
  ('public.cancel_ticket_if_unchanged(uuid,timestamp with time zone)', false, true, false),
  ('public.fet_find_supporters(text,bigint,integer)', false, false, true),
  ('public.fet_get_catalog(bigint,boolean)', true, true, true),
  ('public.fet_get_friends(bigint,integer,text)', false, false, true),
  ('public.fet_get_leaderboard(bigint,integer)', false, false, true),
  ('public.fet_get_partner_offers(bigint,boolean,integer)', false, false, true),
  ('public.fet_get_reward_redemptions(integer,integer,bigint)', false, true, true),
  ('public.fet_get_wallet(bigint)', false, true, true),
  ('public.fet_get_wallet_transactions(bigint,integer,integer)', false, true, true),
  ('public.fet_redeem(integer,text,text,bigint)', false, false, true),
  ('public.fet_redeem_reward(uuid,text,text,bigint)', false, false, true),
  ('public.fet_request_friend(uuid,bigint,text)', false, false, true),
  ('public.fet_respond_friend_request(uuid,text,bigint)', false, false, true),
  ('public.fet_search_supporters(text,bigint,integer)', false, false, true),
  ('public.fet_transfer(uuid,integer,text,text,bigint)', false, false, true),
  ('public.fixtures_calendar(date,date,text,text,integer)', true, true, false),
  ('public.fixtures_date_summary(date,date,text)', true, true, false),
  ('public.get_momo_sms_operational_summary()', false, true, false),
  ('public.get_platform_config(text,bigint)', true, true, true),
  ('public.is_super_admin()', false, true, false),
  ('public.partner_prediction_pool_feed(bigint,text[],integer,integer)', false, false, true),
  ('public.partner_prediction_pool_join(uuid,text,text)', false, false, true),
  ('public.predict_dashboard(bigint)', true, true, false),
  ('public.predict_place(bigint,uuid,text)', false, true, false),
  ('public.predict_admin_dashboard(bigint)', false, true, false),
  ('public.predict_admin_settings(bigint,boolean,integer)', false, true, false),
  ('public.predict_admin_prepare(bigint,uuid,text)', false, true, false),
  ('public.predict_admin_confirm_result(uuid,integer,integer,text)', false, true, false),
  ('public.predict_admin_settle(uuid,text)', false, true, false),
  ('public.predict_lock_due(bigint)', false, false, true),
  ('public.prediction_cancel(uuid)', false, true, false),
  ('public.prediction_get_active(integer,integer)', false, true, false),
  ('public.prediction_get_detail(uuid)', false, true, false),
  ('public.prediction_get_fixture_markets(uuid)', true, true, false),
  ('public.prediction_get_history(integer,integer)', false, true, false),
  ('public.prediction_get_match_center(uuid)', true, true, true),
  ('public.prediction_get_user_badges(uuid)', false, true, false),
  ('public.prediction_get_user_stats()', false, true, false),
  ('public.prepare_membership_payment(text)', false, true, true),
  ('public.prepare_membership_payment_for_club(text,bigint)', false, true, false),
  ('public.purchase_club_tickets(uuid,uuid,text,integer,text)', false, false, true);

select is(
  (select count(*)::integer from expected_mobile_rpc_acl),
  43,
  'the current mobile and supporting service RPC denominator includes both paid membership entrypoints'
);

-- The 20260906082522 migration deliberately removed Challenge after stake
-- reconciliation. The current Predict repositories and football-sync use the
-- eight replacement entry points above; retired APIs must not reappear.
select is(
  (
    select count(*)::integer
    from pg_proc
    where pronamespace = 'public'::regnamespace
      and (
        proname like 'prediction_challenge\_%' escape '\'
        or proname in (
          'prediction_admin_get_challenges', 'prediction_get_challenge_detail',
          'prediction_get_challenge_feed', 'prediction_get_my_challenges'
        )
      )
  ),
  0,
  'retired Challenge functions are absent from the exposed schema'
);

select is(
  (
    select count(*)::integer
    from expected_mobile_rpc_acl as expected
    where pg_catalog.to_regprocedure(expected.signature) is null
  ),
  0,
  'every reviewed mobile RPC signature exists'
);

select ok(
  (
    select pg_catalog.bool_and(
      pg_catalog.has_function_privilege(
        'anon',
        pg_catalog.to_regprocedure(expected.signature),
        'EXECUTE'
      ) = expected.anon_execute
    )
    from expected_mobile_rpc_acl as expected
  ),
  'anon execution matches the exact reviewed matrix'
);

select ok(
  (
    select pg_catalog.bool_and(
      pg_catalog.has_function_privilege(
        'authenticated',
        pg_catalog.to_regprocedure(expected.signature),
        'EXECUTE'
      ) = expected.authenticated_execute
    )
    from expected_mobile_rpc_acl as expected
  ),
  'authenticated execution matches the exact reviewed matrix'
);

select ok(
  (
    select pg_catalog.bool_and(
      pg_catalog.has_function_privilege(
        'service_role',
        pg_catalog.to_regprocedure(expected.signature),
        'EXECUTE'
      ) = expected.service_execute
    )
    from expected_mobile_rpc_acl as expected
  ),
  'service-role execution matches the exact reviewed matrix'
);

select ok(
  not exists (
    select 1
    from expected_mobile_rpc_acl as expected
    join pg_proc as procedure
      on procedure.oid = pg_catalog.to_regprocedure(expected.signature)
    cross join lateral pg_catalog.aclexplode(
      coalesce(
        procedure.proacl,
        pg_catalog.acldefault('f', procedure.proowner)
      )
    ) as acl
    where acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'none of the reviewed functions inherits execution through PUBLIC'
);

select ok(
  exists (
    select 1
    from pg_proc as procedure
    where procedure.oid = 'public.fet_require_club_context(bigint)'::regprocedure
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'p_club_id is distinct from v_trusted_club_id'
      and procedure.prosrc ~ 'service_role'
  )
  and not has_function_privilege(
    'authenticated',
    'public.fet_require_club_context(bigint)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.fet_require_club_context(bigint)',
    'EXECUTE'
  ),
  'tenant context is fixed-path, mismatch-aware, and internal-only'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.fet_wallet_ensure_membership(uuid,bigint)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.fet_wallet_append_entry(bigint,uuid,uuid,text,text,integer,integer,uuid,text,text,text,text,jsonb,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.add_fan_points(uuid,text,integer,text)',
    'EXECUTE'
  ),
  'wallet internals and arbitrary point minting are not client-callable'
);

select * from finish();

rollback;

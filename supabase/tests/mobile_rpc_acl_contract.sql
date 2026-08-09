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
  ('public.fet_find_supporters(text,bigint,integer)', false, true, true),
  ('public.fet_get_catalog(bigint,boolean)', true, true, true),
  ('public.fet_get_friends(bigint,integer,text)', false, true, true),
  ('public.fet_get_leaderboard(bigint,integer)', true, true, true),
  ('public.fet_get_partner_offers(bigint,boolean,integer)', true, true, true),
  ('public.fet_get_reward_redemptions(integer,integer,bigint)', false, true, true),
  ('public.fet_get_wallet(bigint)', false, true, true),
  ('public.fet_get_wallet_transactions(bigint,integer,integer)', false, true, true),
  ('public.fet_redeem(integer,text,text,bigint)', false, true, true),
  ('public.fet_redeem_reward(uuid,text,text,bigint)', false, true, true),
  ('public.fet_request_friend(uuid,bigint,text)', false, true, true),
  ('public.fet_respond_friend_request(uuid,text,bigint)', false, true, true),
  ('public.fet_search_supporters(text,bigint,integer)', false, true, true),
  ('public.fet_transfer(uuid,integer,text,text,bigint)', false, true, true),
  ('public.fixtures_calendar(date,date,text,text,integer)', true, true, false),
  ('public.fixtures_date_summary(date,date,text)', true, true, false),
  ('public.get_eligible_game_sessions_v2(uuid)', false, true, false),
  ('public.get_momo_sms_operational_summary()', false, true, false),
  ('public.get_participant_game_projection_v2(uuid)', false, true, false),
  ('public.get_platform_config(text,bigint)', true, true, true),
  ('public.is_super_admin()', false, true, false),
  ('public.partner_prediction_pool_feed(bigint,text[],integer,integer)', false, true, true),
  ('public.partner_prediction_pool_join(uuid,text,text)', false, true, false),
  ('public.prediction_admin_get_challenges(bigint,text[],integer,integer)', false, true, false),
  ('public.prediction_cancel(uuid)', false, true, false),
  ('public.prediction_challenge_admin_retry_settlement(uuid)', false, true, false),
  ('public.prediction_challenge_cancel(uuid)', false, true, false),
  ('public.prediction_challenge_create(uuid,integer,integer,bigint,bigint)', false, true, false),
  ('public.prediction_challenge_join(uuid,integer,integer)', false, true, false),
  ('public.prediction_create_friend_challenge(uuid,uuid,text,text)', false, true, true),
  ('public.prediction_get_active(integer,integer)', false, true, false),
  ('public.prediction_get_active_jackpot_round(bigint)', false, true, true),
  ('public.prediction_get_challenge_detail(uuid,bigint)', false, true, false),
  ('public.prediction_get_challenge_feed(bigint,text[],text,integer,integer,boolean)', false, true, false),
  ('public.prediction_get_detail(uuid)', false, true, false),
  ('public.prediction_get_fixture_markets(uuid)', true, true, false),
  ('public.prediction_get_history(integer,integer)', false, true, false),
  ('public.prediction_get_match_center(uuid)', true, true, true),
  ('public.prediction_get_my_challenges(bigint,text[],text,integer,integer)', false, true, false),
  ('public.prediction_get_user_badges(uuid)', false, true, false),
  ('public.prediction_get_user_stats()', false, true, false),
  ('public.prediction_place(uuid,text)', false, true, false),
  ('public.prediction_place_acca(jsonb)', false, true, false),
  ('public.prediction_place_jackpot_entry(uuid,jsonb,text)', false, true, true),
  ('public.purchase_club_tickets(uuid,uuid,text,integer,text)', false, true, false),
  ('public.submit_participant_answer_v2(uuid,uuid,text,bigint,bigint,text)', false, true, false),
  ('public.venue_checkin_validate(bigint,text,text,numeric)', false, true, false),
  ('public.venue_order_create(bigint,uuid,uuid,jsonb,boolean,text)', false, true, false);

select is(
  (select count(*)::integer from expected_mobile_rpc_acl),
  51,
  'the reviewed mobile RPC denominator remains 51'
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
  'none of the 51 functions inherits execution through PUBLIC'
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

select ok(
  exists (
    select 1
    from pg_proc as procedure
    where procedure.oid =
      'public.venue_checkin_validate(bigint,text,text,numeric)'::regprocedure
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'fet_require_club_context'
  )
  and exists (
    select 1
    from pg_proc as procedure
    where procedure.oid =
      'public.venue_order_create(bigint,uuid,uuid,jsonb,boolean,text)'::regprocedure
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'fet_require_club_context'
  ),
  'venue write entry points validate the authenticated club before delegation'
);

select * from finish();

rollback;

-- Store-release mutation, cross-user privacy and contribution-route boundary.

create extension if not exists pgtap with schema extensions;

begin;

select plan(31);

create temporary table expected_internal_service_function (
  signature text primary key
) on commit drop;

insert into expected_internal_service_function values
  ('public.apply_membership_points(uuid,uuid,integer,text)'),
  ('public.rs_apply_membership_points(uuid,uuid,integer,text)'),
  ('public.partner_prediction_pool_summary_json(uuid,uuid)'),
  ('public.partner_prediction_pool_user_eligible(uuid,uuid)'),
  ('public.fet_get_friendship_row(uuid,uuid,bigint)'),
  ('public.get_momo_validation_issues()'),
  ('public.redact_momo_sms_artifacts_due(interval,interval,integer)'),
  ('public.run_momo_sms_migration_safety_check()'),
  ('public.cleanup_stale_fcm_tokens()'),
  ('public.find_auth_user_by_phone_or_email(text,text)'),
  ('public.consume_request_rate_limit(text,integer,integer)'),
  ('public.get_partner_payment_route(uuid,text)'),
  ('public.record_admin_action(text,text,text,jsonb,jsonb,text)'),
  ('public.get_admin_access_for_user(uuid)'),
  ('public.get_nearby_drivers(double precision,double precision,text,text,double precision)'),
  ('public.get_scheduled_trips(double precision,double precision,text,text,text,double precision)');

select is(
  (
    select count(*)::integer
    from expected_internal_service_function
    where pg_catalog.to_regprocedure(signature) is null
  ),
  0,
  'all reviewed internal SECURITY DEFINER signatures exist'
);

select ok(
  not exists (
    select 1
    from expected_internal_service_function as expected
    join pg_catalog.pg_proc as procedure
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
  'internal helpers do not inherit execution through PUBLIC'
);

select ok(
  (
    select pg_catalog.bool_and(
      not pg_catalog.has_function_privilege(
        'anon',
        pg_catalog.to_regprocedure(signature),
        'EXECUTE'
      )
      and not pg_catalog.has_function_privilege(
        'authenticated',
        pg_catalog.to_regprocedure(signature),
        'EXECUTE'
      )
    )
    from expected_internal_service_function
  ),
  'anon and authenticated cannot invoke internal helpers'
);

select ok(
  (
    select pg_catalog.bool_and(
      pg_catalog.has_function_privilege(
        'service_role',
        pg_catalog.to_regprocedure(signature),
        'EXECUTE'
      )
    )
    from expected_internal_service_function
  ),
  'reviewed operational service functions remain service-role callable'
);

create temporary table expected_store_disabled_function (
  signature text primary key
) on commit drop;

insert into expected_store_disabled_function values
  ('public.fet_redeem(integer,text,text,bigint)'),
  ('public.fet_redeem_reward(uuid,text,text,bigint)'),
  ('public.fet_transfer(uuid,integer,text,text,bigint)'),
  ('public.fet_request_friend(uuid,bigint,text)'),
  ('public.fet_respond_friend_request(uuid,text,bigint)'),
  ('public.fet_find_supporters(text,bigint,integer)'),
  ('public.fet_get_friends(bigint,integer,text)'),
  ('public.fet_search_supporters(text,bigint,integer)'),
  ('public.fet_get_leaderboard(bigint,integer)'),
  ('public.fet_get_partner_offers(bigint,boolean,integer)'),
  ('public.partner_prediction_pool_join(uuid,text,text)'),
  ('public.partner_prediction_pool_feed(bigint,text[],integer,integer)');

select is(
  (
    select count(*)::integer
    from expected_store_disabled_function
    where pg_catalog.to_regprocedure(signature) is null
  ),
  0,
  'all store-disabled mutation and cross-user RPC signatures exist'
);

select ok(
  not exists (
    select 1
    from expected_store_disabled_function as expected
    join pg_catalog.pg_proc as procedure
      on procedure.oid = pg_catalog.to_regprocedure(expected.signature)
    cross join lateral pg_catalog.aclexplode(
      coalesce(
        procedure.proacl,
        pg_catalog.acldefault('f', procedure.proowner)
      )
    ) as acl
    where acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  )
  and (
    select pg_catalog.bool_and(
      not pg_catalog.has_function_privilege(
        'anon', pg_catalog.to_regprocedure(signature), 'EXECUTE'
      )
      and not pg_catalog.has_function_privilege(
        'authenticated', pg_catalog.to_regprocedure(signature), 'EXECUTE'
      )
    )
    from expected_store_disabled_function
  ),
  'store-disabled RPCs are unavailable to public release clients'
);

select ok(
  (
    select pg_catalog.bool_and(
      pg_catalog.has_function_privilege(
        'service_role', pg_catalog.to_regprocedure(signature), 'EXECUTE'
      )
    )
    from expected_store_disabled_function
  ),
  'store-disabled RPCs remain available only to trusted server operations'
);

select ok(
  not pg_catalog.has_function_privilege(
    'anon',
    'public.admin_review_membership_application_if_unchanged(uuid,timestamp with time zone,text,text,bigint,uuid,uuid)',
    'EXECUTE'
  )
  and not pg_catalog.has_function_privilege(
    'authenticated',
    'public.admin_review_membership_application_if_unchanged(uuid,timestamp with time zone,text,text,bigint,uuid,uuid)',
    'EXECUTE'
  )
  and not pg_catalog.has_function_privilege(
    'service_role',
    'public.admin_review_membership_application_if_unchanged(uuid,timestamp with time zone,text,text,bigint,uuid,uuid)',
    'EXECUTE'
  ),
  'the legacy membership reviewer cannot bypass authoritative package checks'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'fan_memberships'
      and policyname = 'fan_memberships_owner_or_admin_read'
      and qual ~ 'auth.uid'
      and qual ~ 'is_club_admin'
      and qual ~ 'requesting_club_id'
  )
  and not exists (
    select 1
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'fan_memberships'
      and policyname = 'fan_memberships_club_directory_read'
  ),
  'membership rows are owner-or-admin scoped rather than a raw club directory'
);

select ok(
  pg_catalog.has_column_privilege(
    'anon', 'public.contribution_groups', 'name', 'SELECT'
  )
  and not pg_catalog.has_column_privilege(
    'anon', 'public.contribution_groups', 'momo_recipient_code', 'SELECT'
  )
  and not pg_catalog.has_column_privilege(
    'anon', 'public.contribution_groups', 'creator_id', 'SELECT'
  )
  and pg_catalog.has_column_privilege(
    'authenticated',
    'public.contribution_groups',
    'momo_recipient_code',
    'SELECT'
  )
  and not pg_catalog.has_column_privilege(
    'authenticated', 'public.contribution_groups', 'momo_number', 'SELECT'
  ),
  'the compatibility view separates public fields from the canonical payment route'
);

select ok(
  pg_catalog.has_column_privilege(
    'anon', 'public.groups', 'name', 'SELECT'
  )
  and not pg_catalog.has_column_privilege(
    'anon', 'public.groups', 'receiving_momo_code', 'SELECT'
  )
  and pg_catalog.has_column_privilege(
    'authenticated', 'public.groups', 'receiving_momo_code', 'SELECT'
  )
  and not pg_catalog.has_column_privilege(
    'authenticated', 'public.groups', 'momo_number', 'SELECT'
  )
  and not pg_catalog.has_column_privilege(
    'authenticated', 'public.groups', 'momo_code', 'SELECT'
  )
  and not pg_catalog.has_column_privilege(
    'authenticated', 'public.groups', 'bank_partner_id', 'SELECT'
  )
  and not pg_catalog.has_column_privilege(
    'authenticated', 'public.groups', 'creator_id', 'SELECT'
  ),
  'base-table grants do not expose raw payment, bank, or creator fields'
);

select ok(
  pg_catalog.pg_get_viewdef('public.contribution_groups'::regclass, true)
    ~ 'NULL::uuid AS creator_id'
  and pg_catalog.pg_get_viewdef('public.contribution_groups'::regclass, true)
    ~ 'receiving_momo_code AS momo_recipient_code'
  and pg_catalog.pg_get_viewdef('public.contribution_groups'::regclass, true)
    ~ 'NULL::text AS bank_partner_id'
  and pg_catalog.pg_get_viewdef('public.contribution_groups'::regclass, true)
    ~ 'NULL::text AS momo_number',
  'the view emits only the canonical route and nulls legacy sensitive aliases'
);

select ok(
  exists (
    select 1
    from pg_catalog.pg_class as relation
    where relation.oid = 'public.contribution_groups'::regclass
      and relation.reloptions @> array['security_invoker=true']
  ),
  'the contribution compatibility view remains security invoker'
);

select ok(
  pg_catalog.has_column_privilege(
    'anon', 'public.home_banners', 'title', 'SELECT'
  )
  and not pg_catalog.has_table_privilege(
    'anon', 'public.home_banners', 'INSERT'
  )
  and pg_catalog.has_table_privilege(
    'service_role', 'public.home_banners', 'SELECT,INSERT,UPDATE,DELETE'
  ),
  'public banners are explicitly readable while CMS mutation stays service-only'
);

select ok(
  not pg_catalog.has_table_privilege(
    'anon', 'public.pwa_engagement_events', 'INSERT'
  )
  and not pg_catalog.has_table_privilege(
    'authenticated', 'public.pwa_engagement_events', 'INSERT'
  )
  and pg_catalog.has_table_privilege(
    'service_role', 'public.pwa_engagement_events', 'INSERT'
  )
  and not pg_catalog.has_table_privilege(
    'anon', 'public.web_push_subscriptions', 'SELECT,INSERT,UPDATE'
  )
  and not pg_catalog.has_table_privilege(
    'authenticated',
    'public.web_push_subscriptions',
    'SELECT,INSERT,UPDATE'
  )
  and pg_catalog.has_table_privilege(
    'service_role',
    'public.web_push_subscriptions',
    'SELECT,INSERT,UPDATE'
  )
  and not pg_catalog.has_table_privilege(
    'service_role', 'public.web_push_subscriptions', 'DELETE'
  ),
  'PWA event and push persistence has the minimum service-role privileges'
);

create temporary table expected_release_service_function (
  signature text primary key
) on commit drop;

insert into expected_release_service_function values
  ('football.award_prediction_fet(uuid,uuid,bigint,integer,uuid,text)'),
  ('football.seed_fixture_prediction_markets(uuid,boolean)'),
  ('football.generate_fixture_markets(uuid)'),
  ('football.update_fixture_market_odds(uuid,jsonb)'),
  ('football.update_fixture_odds_batch(uuid,jsonb)'),
  ('football.seed_fixture_prediction_markets_trigger()'),
  ('football.trg_auto_generate_fixture_markets()'),
  ('public.partner_prediction_pool_create(uuid,uuid,text,integer,integer,uuid,text,integer,text,jsonb,bigint)'),
  ('public.partner_prediction_pool_settle_for_actor(uuid,uuid,uuid)'),
  ('public.predict_admin_settle_for_actor(uuid,uuid,uuid,text)'),
  ('public.predict_admin_confirm_result_for_actor(uuid,integer,integer,text,uuid,uuid)'),
  ('public.get_trusted_sms_gateway_key(uuid)'),
  ('public.admit_trusted_sms_gateway_evidence(uuid,uuid,timestamp with time zone,timestamp with time zone,text,jsonb)'),
  ('public.get_trusted_sms_gateway_event(uuid)'),
  ('public.process_trusted_sms_gateway_evidence(uuid)'),
  ('public.get_trusted_payment_refund_gateway_key(uuid)'),
  ('public.admit_trusted_payment_refund_evidence(uuid,uuid,timestamp with time zone,timestamp with time zone,text,jsonb)'),
  ('public.process_trusted_payment_refund_evidence(uuid)'),
  ('public.claim_admin_media_upload(uuid,uuid)'),
  ('public.complete_admin_media_upload(uuid,uuid,text,uuid,text)'),
  ('public.refresh_admin_phone_access_for_user(uuid)'),
  ('public.next_public_user_id()');

select is(
  (
    select count(*)::integer
      from expected_release_service_function
     where pg_catalog.to_regprocedure(signature) is null
  ),
  0,
  'all residual fixture, store-policy, identity and admin service functions exist'
);

select ok(
  not exists (
    select 1
      from expected_release_service_function as expected
      join pg_catalog.pg_proc as procedure
        on procedure.oid = pg_catalog.to_regprocedure(expected.signature)
      cross join lateral pg_catalog.aclexplode(
        coalesce(
          procedure.proacl,
          pg_catalog.acldefault('f', procedure.proowner)
        )
      ) as acl
     where acl.grantee = 0
       and acl.privilege_type = 'EXECUTE'
  )
  and (
    select pg_catalog.bool_and(
      not pg_catalog.has_function_privilege(
        'anon', pg_catalog.to_regprocedure(signature), 'EXECUTE'
      )
      and not pg_catalog.has_function_privilege(
        'authenticated', pg_catalog.to_regprocedure(signature), 'EXECUTE'
      )
      and pg_catalog.has_function_privilege(
        'service_role', pg_catalog.to_regprocedure(signature), 'EXECUTE'
      )
    )
      from expected_release_service_function
  ),
  'residual privileged functions are service-only with no PUBLIC inheritance'
);

select ok(
  not pg_catalog.has_function_privilege(
    'anon',
    'public.purchase_club_tickets(uuid,uuid,text,integer,text)',
    'EXECUTE'
  )
  and not pg_catalog.has_function_privilege(
    'authenticated',
    'public.purchase_club_tickets(uuid,uuid,text,integer,text)',
    'EXECUTE'
  )
  and pg_catalog.has_function_privilege(
    'service_role',
    'public.purchase_club_tickets(uuid,uuid,text,integer,text)',
    'EXECUTE'
  )
  and not pg_catalog.has_function_privilege(
    'anon', 'public.create_shop_order(jsonb,text,text)', 'EXECUTE'
  )
  and not pg_catalog.has_function_privilege(
    'authenticated', 'public.create_shop_order(jsonb,text,text)', 'EXECUTE'
  )
  and pg_catalog.has_function_privilege(
    'service_role', 'public.create_shop_order(jsonb,text,text)', 'EXECUTE'
  )
  and pg_catalog.has_function_privilege(
    'authenticated',
    'public.cancel_ticket_if_unchanged(uuid,timestamp with time zone)',
    'EXECUTE'
  )
  and pg_catalog.has_function_privilege(
    'authenticated',
    'public.cancel_shop_order_if_unchanged(uuid,timestamp with time zone)',
    'EXECUTE'
  ),
  'unreconciled checkout creation is service-only while safe cancellation remains authenticated'
);

select ok(
  exists (
    select 1
      from pg_catalog.pg_proc as procedure
     where procedure.oid =
       'public.fet_get_catalog(bigint,boolean)'::regprocedure
       and procedure.proconfig = array['search_path=""']::text[]
       and procedure.prosrc ~ 'null::text as implementation_notes'
       and procedure.prosrc !~ 'catalog[.]implementation_notes'
  )
  and pg_catalog.has_function_privilege(
    'anon', 'public.fet_get_catalog(bigint,boolean)', 'EXECUTE'
  )
  and pg_catalog.has_function_privilege(
    'authenticated', 'public.fet_get_catalog(bigint,boolean)', 'EXECUTE'
  ),
  'the public FET catalog preserves its row shape but returns no implementation notes'
);

select ok(
  exists (
    select 1
      from pg_catalog.pg_proc as procedure
     where procedure.oid =
       'public.enforce_ticket_provider_attestation()'::regprocedure
       and procedure.prosecdef
       and procedure.proconfig = array['search_path=""']::text[]
       and procedure.prosrc ~ 'momo_reconciliations'
       and procedure.prosrc ~ 'momo_sms_parsed'
       and procedure.prosrc ~ 'momo_ledger_entries'
       and procedure.prosrc ~ 'old.status = ''pending'''
       and procedure.prosrc ~ 'new.status = ''valid'''
  )
  and exists (
    select 1
      from information_schema.triggers
     where event_object_schema = 'public'
       and event_object_table = 'tickets'
       and trigger_name = 'trg_tickets_require_provider_attestation'
       and event_manipulation = 'UPDATE'
  )
  and not pg_catalog.has_function_privilege(
    'anon', 'public.enforce_ticket_provider_attestation()', 'EXECUTE'
  )
  and not pg_catalog.has_function_privilege(
    'authenticated', 'public.enforce_ticket_provider_attestation()', 'EXECUTE'
  ),
  'ticket validation has a fixed-path internal provider-attestation trigger'
);

set local role anon;
do $$
declare
  denied boolean := false;
begin
  begin
    perform public.predict_lock_due();
  exception
    when insufficient_privilege then denied := true;
  end;

  if not denied then
    raise exception 'anonymous service-only RPC execution unexpectedly succeeded';
  end if;
end;
$$;
reset role;
select pass('an anonymous call to a service-only release RPC is denied at execution time');

create temporary table store_release_ticket_probe (
  id uuid primary key,
  user_id uuid not null,
  club_id bigint not null,
  status text not null,
  momo_reference text,
  amount_paid integer not null,
  confirmed_at timestamptz
) on commit drop;

create trigger trg_store_release_ticket_probe
before update of status on store_release_ticket_probe
for each row execute function public.enforce_ticket_provider_attestation();

insert into store_release_ticket_probe (
  id,user_id,club_id,status,momo_reference,amount_paid
) values
  (
    '99470000-0000-4000-8000-000000000101',
    '99470000-0000-4000-8000-000000000001',
    9947001,
    'pending',
    'CLIENTONLY001',
    5000
  ),
  (
    '99470000-0000-4000-8000-000000000102',
    '99470000-0000-4000-8000-000000000001',
    9947001,
    'pending',
    'CLIENTONLY002',
    5000
  );

update store_release_ticket_probe
   set status = 'cancelled'
 where id = '99470000-0000-4000-8000-000000000101';

select is(
  (
    select status
      from store_release_ticket_probe
     where id = '99470000-0000-4000-8000-000000000101'
  ),
  'cancelled',
  'a pending ticket may still be safely cancelled without provider evidence'
);

do $$
declare
  denied boolean := false;
begin
  begin
    update store_release_ticket_probe
       set status = 'valid'
     where id = '99470000-0000-4000-8000-000000000102';
  exception
    when others then
      denied := sqlerrm ~* 'provider payment is required';
  end;

  if not denied then
    raise exception 'pending ticket validation did not require provider evidence';
  end if;
end;
$$;
select pass('pending-to-valid ticket attestation fails closed without matched provider evidence');

select ok(
  not pg_catalog.has_table_privilege(
    'anon', 'public.momo_sms_sync_runs', 'SELECT,INSERT,UPDATE,DELETE'
  )
  and pg_catalog.has_table_privilege(
    'authenticated', 'public.momo_sms_sync_runs', 'SELECT,INSERT'
  )
  and not pg_catalog.has_table_privilege(
    'authenticated', 'public.momo_sms_sync_runs', 'UPDATE,DELETE'
  )
  and pg_catalog.has_table_privilege(
    'service_role',
    'public.momo_sms_sync_runs',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'MoMo sync audit grants allow only authenticated append and own-row read'
);

select ok(
  (
    select count(*) = 2
      from pg_catalog.pg_policies
     where schemaname = 'public'
       and tablename = 'momo_sms_sync_runs'
       and policyname in (
         'momo_sms_sync_runs_insert_own',
         'momo_sms_sync_runs_select_own'
       )
       and roles = array['authenticated']::name[]
       and (
         (cmd = 'INSERT' and with_check ~ 'auth.uid' and with_check ~ 'user_id')
         or (cmd = 'SELECT' and qual ~ 'auth.uid' and qual ~ 'user_id')
       )
  )
  and not exists (
    select 1
      from pg_catalog.pg_policies
     where schemaname = 'public'
       and tablename = 'momo_sms_sync_runs'
       and cmd in ('UPDATE', 'DELETE')
  ),
  'MoMo sync audit RLS remains owner-only with no client mutation policy'
);

insert into auth.users (id, aud, role)
values
  ('99470000-0000-4000-8000-000000000001', 'authenticated', 'authenticated'),
  ('99470000-0000-4000-8000-000000000002', 'authenticated', 'authenticated');

insert into public.users (id, phone, full_name, country, language_code)
values
  (
    '99470000-0000-4000-8000-000000000001',
    '+250700947001',
    'Store Release Owner',
    'RW',
    'en'
  ),
  (
    '99470000-0000-4000-8000-000000000002',
    '+250700947002',
    'Store Release Outsider',
    'RW',
    'en'
  );

select set_config(
  'request.jwt.claim.sub',
  '99470000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99470000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9947001"}',
  true
);
set local role authenticated;
do $$
declare
  cross_user_denied boolean := false;
  visible_count integer;
begin
  insert into public.momo_sms_sync_runs (
    user_id,trigger,status,lookback_days,incremental
  ) values (
    '99470000-0000-4000-8000-000000000001',
    'manual',
    'succeeded',
    30,
    true
  );

  select count(*)::integer
    into visible_count
    from public.momo_sms_sync_runs;

  begin
    insert into public.momo_sms_sync_runs (
      user_id,trigger,status,lookback_days,incremental
    ) values (
      '99470000-0000-4000-8000-000000000002',
      'manual',
      'succeeded',
      30,
      true
    );
  exception
    when insufficient_privilege then cross_user_denied := true;
  end;

  if visible_count <> 1 or not cross_user_denied then
    raise exception
      'sync audit owner boundary failed: visible %, cross-user denied %',
      visible_count,
      cross_user_denied;
  end if;
end;
$$;
reset role;
select pass('authenticated sync audit insert/read succeeds only for the JWT owner');

set local role anon;
do $$
declare
  denied boolean := false;
begin
  begin
    insert into public.momo_sms_sync_runs (user_id,trigger,status)
    values (
      '99470000-0000-4000-8000-000000000001',
      'manual',
      'succeeded'
    );
  exception
    when insufficient_privilege then denied := true;
  end;

  if not denied then
    raise exception 'anonymous sync audit insert unexpectedly succeeded';
  end if;
end;
$$;
reset role;
select pass('anonymous sync audit insertion is denied at execution time');

select ok(
  exists (
    select 1
      from pg_catalog.pg_proc as procedure
     where procedure.oid =
       'public.cancel_pending_group_contribution_payment_launch(uuid)'::regprocedure
       and procedure.prosecdef
       and procedure.proconfig = array['search_path=""']::text[]
       and procedure.prosrc ~ 'auth.uid'
       and procedure.prosrc ~ 'requesting_club_id'
       and procedure.prosrc ~ 'momo_reference is not null'
       and procedure.prosrc ~ 'supporter_contribution_payment_launch_cancelled'
  )
  and pg_catalog.has_function_privilege(
    'authenticated',
    'public.cancel_pending_group_contribution_payment_launch(uuid)',
    'EXECUTE'
  )
  and not pg_catalog.has_function_privilege(
    'anon',
    'public.cancel_pending_group_contribution_payment_launch(uuid)',
    'EXECUTE'
  )
  and not pg_catalog.has_function_privilege(
    'service_role',
    'public.cancel_pending_group_contribution_payment_launch(uuid)',
    'EXECUTE'
  )
  and exists (
    select 1
      from pg_catalog.pg_constraint
     where conrelid = 'public.group_contributions'::regclass
       and conname = 'group_contributions_status_check'
       and pg_catalog.pg_get_constraintdef(oid) ~ 'cancelled'
  ),
  'payment-launch cancellation is fixed-path, authenticated-only, and has an allowed terminal state'
);

insert into public.african_football_clubs (
  id,club_name,country_name,club_slug
) overriding system value values (
  9947001,
  'Store Release Contract Club',
  'Rwanda',
  'store-release-contract-club'
);

insert into public.groups (
  id,creator_id,name,group_type,target_amount,club_id,currency,visibility,
  is_active,is_closed,receiving_momo_route_type,receiving_momo_code
) values (
  '99470000-0000-4000-8000-000000000110',
  '99470000-0000-4000-8000-000000000001',
  'Store Release Contribution Group',
  'community',
  100000,
  9947001,
  'RWF',
  'public',
  true,
  false,
  'code',
  '994700'
);

insert into public.group_contributions (
  id,group_id,user_id,amount,status,payment_status,
  client_request_reference,idempotency_key,momo_reference
) values (
  '99470000-0000-4000-8000-000000000120',
  '99470000-0000-4000-8000-000000000110',
  '99470000-0000-4000-8000-000000000001',
  5000,
  'pending',
  'pending_verification'::public.payment_status,
  'STORECANCEL001',
  'store:cancel:001',
  null
);

set local role authenticated;
do $$
declare
  cancelled boolean;
begin
  cancelled := public.cancel_pending_group_contribution_payment_launch(
    '99470000-0000-4000-8000-000000000120'
  );
  if not cancelled then
    raise exception 'owner contribution cancellation did not return true';
  end if;
end;
$$;
reset role;

select ok(
  exists (
    select 1
      from public.group_contributions as contribution
     where contribution.id = '99470000-0000-4000-8000-000000000120'
       and contribution.status = 'cancelled'
       and contribution.momo_reference is null
       and contribution.updated_at is not null
  )
  and exists (
    select 1
      from public.admin_audit_log as audit
     where audit.action = 'supporter_contribution_payment_launch_cancelled'
       and audit.target_table = 'group_contributions'
       and audit.target_id = '99470000-0000-4000-8000-000000000120'
       and audit.actor_id = '99470000-0000-4000-8000-000000000001'
       and audit.club_id = 9947001
       and audit.old_data ? 'updated_at'
       and audit.new_data ? 'updated_at'
  ),
  'the owner can cancel an unbound pending contribution with version and audit evidence'
);

select set_config(
  'request.jwt.claim.sub',
  '99470000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99470000-0000-4000-8000-000000000002","role":"authenticated","club_id":"9947001"}',
  true
);
set local role authenticated;
do $$
declare
  denied boolean := false;
begin
  begin
    perform public.cancel_pending_group_contribution_payment_launch(
      '99470000-0000-4000-8000-000000000120'
    );
  exception
    when others then denied := sqlerrm ~ 'active supporter account';
  end;

  if not denied then
    raise exception 'outsider contribution cancellation unexpectedly succeeded';
  end if;
end;
$$;
reset role;
select pass('a same-club outsider cannot cancel another supporter contribution');

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
do $$
declare
  denied boolean := false;
begin
  begin
    perform public.cancel_pending_group_contribution_payment_launch(
      '99470000-0000-4000-8000-000000000120'
    );
  exception
    when insufficient_privilege then denied := true;
  end;

  if not denied then
    raise exception 'anonymous contribution cancellation unexpectedly succeeded';
  end if;
end;
$$;
reset role;
select pass('anonymous contribution payment-launch cancellation is denied at execution time');

select * from finish();

rollback;

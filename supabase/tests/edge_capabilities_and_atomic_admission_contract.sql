begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

insert into public.african_football_clubs(id, club_name, country_name, club_slug)
  overriding system value values
  (9951001, 'Capability Contract A', 'Rwanda', 'capability-contract-a'),
  (9951002, 'Capability Contract B', 'Rwanda', 'capability-contract-b');
insert into auth.users(id, aud, role, raw_app_meta_data)
  select ('99510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
    'authenticated', 'authenticated', '{"role":"super_admin","is_admin":true}'::jsonb
    from generate_series(1, 7) n;
-- Use the actual Auth vendor session schema. Metadata above remains untrusted;
-- positive service mutations require this actor's authenticated caller proof.
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
  select ('99510000-0000-4000-8000-' || lpad((n+550)::text,12,'0'))::uuid,
    ('99510000-0000-4000-8000-' || lpad(n::text,12,'0'))::uuid,
    clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour'
    from generate_series(1,7) n;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
insert into public.users(id, phone, full_name, is_admin)
  select ('99510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
    '+25079951000' || n, 'Synthetic capability actor ' || n, n = 1
    from generate_series(1, 7) n;
insert into public.admin_role_assignments(user_id, role, club_id, is_active, revoked_at) values
  ('99510000-0000-4000-8000-000000000002', 'club_admin', 9951001, true, null),
  ('99510000-0000-4000-8000-000000000003', 'club_moderator', 9951001, true, null),
  ('99510000-0000-4000-8000-000000000004', 'admin', null, true, null),
  ('99510000-0000-4000-8000-000000000005', 'super_admin', null, true, null),
  ('99510000-0000-4000-8000-000000000006', 'super_admin', null, true, now()),
  ('99510000-0000-4000-8000-000000000007', 'admin', null, false, null);

create function pg_temp.capability_actor(n integer) returns void language plpgsql as $$ begin
  perform set_config('request.jwt.claim.sub', '99510000-0000-4000-8000-' || lpad(n::text, 12, '0'), true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub',
    '99510000-0000-4000-8000-' || lpad(n::text, 12, '0'),
    'role', 'authenticated', 'club_id', '9951001', 'is_admin', true,
    'aal','aal2','is_anonymous',false,'exp',floor(extract(epoch from clock_timestamp()))::bigint+3600,
    'session_id','99510000-0000-4000-8000-' || lpad((n+550)::text,12,'0'),
    'amr',jsonb_build_array(jsonb_build_object('method','totp',
      'timestamp',floor(extract(epoch from clock_timestamp()))::bigint-1)))::text, true);
end $$;

select pg_temp.capability_actor(1);
select ok(not public.is_admin(), 'legacy user flag cannot grant platform authority');
select ok(not public.is_admin_user(), 'metadata cannot grant current admin authority');
select ok(not public.is_super_admin(), 'metadata cannot grant super-admin authority');
select ok(not public.is_club_admin(9951001), 'metadata-only actor cannot administer a club');
select pg_temp.capability_actor(2);
select ok(public.is_club_admin(9951001), 'active club assignment authorizes its club');
select ok(not public.is_club_admin(9951002), 'club assignment cannot cross tenant boundary');
select ok(not public.is_admin(), 'club assignment cannot authorize global operations');
select pg_temp.capability_actor(3);
select ok(public.is_club_admin(9951001), 'moderator retains existing scoped capability');
select ok(not public.is_admin_user(), 'moderator cannot gain global capability');
select pg_temp.capability_actor(4);
select ok(public.is_admin() and public.is_admin_user(), 'active platform admin is authorized');
select ok(public.is_club_admin(9951002), 'platform admin retains legitimate cross-club capability');
select ok(not public.is_super_admin(), 'admin does not silently gain super-admin capability');
select pg_temp.capability_actor(5);
select ok(public.is_super_admin(), 'active super-admin is authorized');
select pg_temp.capability_actor(6);
select ok(not public.is_admin() and not public.is_super_admin(), 'revoked_at overrides a stale active flag');
select pg_temp.capability_actor(7);
select ok(not public.is_admin(), 'inactive assignment cannot authorize global operations');

select ok(not has_function_privilege('authenticated', 'public.consume_edge_rate_limit(text,integer,integer)', 'execute'),
  'supporter cannot directly consume or change security budgets');
select ok(not has_function_privilege('anon', 'public.consume_edge_rate_limit(text,integer,integer)', 'execute'),
  'anonymous role cannot consume security budgets');
select ok(not has_table_privilege('authenticated', 'public.edge_rate_limit_buckets', 'select'),
  'private admission state is not client-readable');
select ok(not has_table_privilege('service_role', 'public.edge_rate_limit_buckets', 'update'),
  'service caller uses the admitted function rather than arbitrary counter writes');
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select is((select allowed from public.consume_edge_rate_limit('contract-a', 1, 60)), true,
  'first request is atomically admitted');
select is((select allowed from public.consume_edge_rate_limit('contract-a', 1, 60)), false,
  'second request is denied without an additional accepted timestamp');
select is((select cardinality(accepted_at) from public.edge_rate_limit_buckets where bucket_key = 'contract-a'), 1,
  'denied requests do not grow the state');
select ok((select retry_after_seconds between 1 and 60 from public.consume_edge_rate_limit('contract-a', 1, 60)),
  'denial includes bounded retry timing');
select is((select allowed from public.consume_edge_rate_limit('contract-b', 1, 60)), true,
  'different subject and tenant buckets remain independent');
update public.edge_rate_limit_buckets set accepted_at = array[clock_timestamp() - interval '61 seconds'],
  expires_at = clock_timestamp() - interval '1 second' where bucket_key = 'contract-a';
select is((select allowed from public.consume_edge_rate_limit('contract-a', 1, 60)), true,
  'rolling expiry admits the next request');
select throws_ok($$select public.consume_edge_rate_limit('invalid', 0, 60)$$, '22023',
  'EDGE_ADMISSION_INVALID_BUDGET', 'zero budget cannot disable protection');
select throws_ok($$select public.consume_edge_rate_limit('invalid', 1001, 60)$$, '22023',
  'EDGE_ADMISSION_INVALID_BUDGET', 'per-bucket state is capped');
select throws_ok($$select public.consume_edge_rate_limit('invalid', 1, 86401)$$, '22023',
  'EDGE_ADMISSION_INVALID_BUDGET', 'window retention is bounded');
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select throws_ok($$select public.consume_edge_rate_limit('forged', 1, 60)$$, '42501',
  'EDGE_ADMISSION_SERVICE_REQUIRED', 'JWT role alone cannot bypass service-only implementation check');

-- Fixture setup is owner maintenance, not the unauthenticated role-only
-- negative above. Actual human effects below still require caller admission.
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select set_config('request.jwt.claim.sub', '', true);
insert into football.competitions(id, slug, name, short_name) values
  ('99510000-0000-4000-8000-000000000200', 'capability-contract', 'Capability League', 'Test');
insert into football.seasons(id, competition_id, slug, label) values
  ('99510000-0000-4000-8000-000000000201', '99510000-0000-4000-8000-000000000200', 'capability-season', '2026');
insert into football.teams(id, name, crest_url) values
  ('99510000-0000-4000-8000-000000000210', 'Capability Home', 'https://example.test/home.png'),
  ('99510000-0000-4000-8000-000000000211', 'Capability Away', 'https://example.test/away.png');
insert into football.fixtures(id, competition_id, season_id, home_team_id, away_team_id, kickoff_at) values
  ('99510000-0000-4000-8000-000000000301', '99510000-0000-4000-8000-000000000200',
   '99510000-0000-4000-8000-000000000201', '99510000-0000-4000-8000-000000000210',
   '99510000-0000-4000-8000-000000000211', now() + interval '1 day');
select ok(to_regprocedure('public.prediction_admin_settle(uuid,integer,integer,text)') is null
  and to_regprocedure('public.prediction_admin_settle(uuid,integer,integer,text,integer,integer)') is null,
  'both old unattributed service entrypoints are retired');
select ok(not has_function_privilege('service_role', 'public.prediction_admin_settle_internal(uuid,integer,integer,text,integer,integer)', 'execute'),
  'historical engine cannot be invoked directly with service credentials');
select ok(not has_function_privilege('service_role', 'public.prediction_admin_settle_legacy_internal(uuid,integer,integer,text)', 'execute'),
  'legacy overload cannot bypass actor authorization');
select ok(not has_function_privilege('authenticated', 'public.prediction_admin_settle_as_actor(uuid,integer,integer,uuid,uuid,integer,integer)', 'execute'),
  'supporter cannot forge a human actor on the service RPC');
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select throws_ok($$select public.prediction_admin_settle_as_actor('99510000-0000-4000-8000-000000000301', 2, 1,
  '99510000-0000-4000-8000-000000000002', '99510000-0000-4000-8000-000000000400')$$,
  '42501', 'SETTLEMENT_GLOBAL_ADMIN_REQUIRED', 'club admin cannot settle shared global fixture');
select throws_ok($$select public.prediction_admin_settle_as_actor('99510000-0000-4000-8000-000000000301', 2, 1,
  '99510000-0000-4000-8000-000000000003', '99510000-0000-4000-8000-000000000400')$$,
  '42501', 'SETTLEMENT_GLOBAL_ADMIN_REQUIRED', 'moderator cannot settle shared global fixture');
select throws_ok($$select public.prediction_admin_settle_as_actor('99510000-0000-4000-8000-000000000301', 2, 1,
  '99510000-0000-4000-8000-000000000006', '99510000-0000-4000-8000-000000000400')$$,
  '42501', 'SETTLEMENT_GLOBAL_ADMIN_REQUIRED', 'revoked actor fails at mutation boundary');
select is((select status::text from football.fixtures where id = '99510000-0000-4000-8000-000000000301'),
  'scheduled', 'denied mutation leaves fixture unchanged');
select pg_temp.capability_actor(4);
set local role authenticated;
select is(public.admit_verified_staff_command('99510000-0000-4000-8000-000000000400',
  'fixture_settle','99510000-0000-4000-8000-000000000301',
  '{"home_score":2,"away_score":1,"ht_home_score":null,"ht_away_score":null}')->>'status',
  'admitted','current global caller admits the exact original fixture command');
reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
select is((public.prediction_admin_settle_as_actor('99510000-0000-4000-8000-000000000301', 2, 1,
  '99510000-0000-4000-8000-000000000004', '99510000-0000-4000-8000-000000000400'))->>'status',
  'success', 'current platform assignment settles through retained engine');
select is((select actor_id from public.admin_audit_log
  where action = 'prediction.global_fixture_settle' and metadata->>'operation_id' = '99510000-0000-4000-8000-000000000400'),
  '99510000-0000-4000-8000-000000000004'::uuid, 'mutation audit records verified initiating actor');
select ok((select metadata->>'assignment_id' is not null from public.admin_audit_log
  where action = 'prediction.global_fixture_settle' and metadata->>'operation_id' = '99510000-0000-4000-8000-000000000400'),
  'mutation audit binds the current authorizing assignment');
select * from finish();
rollback;

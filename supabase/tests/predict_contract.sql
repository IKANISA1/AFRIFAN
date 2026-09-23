begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

insert into public.african_football_clubs(id,club_name,country_name,club_slug) overriding system value values
 (9946001,'Predict Test Club','Rwanda','predict-test-club'),(9946002,'Predict Other Club','Rwanda','predict-other-club');
insert into public.partners(id,name,slug,is_active) values
 ('99460000-0000-4000-8000-000000000100','Predict Test Club','predict-test-club',true),
 ('99460000-0000-4000-8000-000000000101','Predict Other Club','predict-other-club',true);
insert into public.membership_packages(partner_id,club_id,tier,title,subtitle) values
 ('99460000-0000-4000-8000-000000000100',9946001,'fan','Test package','Test only'),
 ('99460000-0000-4000-8000-000000000101',9946002,'fan','Other test package','Test only');
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous)
 select ('99460000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',
 case when n <> 7 then now() end,n=8 from generate_series(1,8) n;
insert into public.users(id,phone,full_name)
 select ('99460000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+25079946000'||n,'Synthetic Predict '||n from generate_series(1,8) n;
insert into public.profiles(id,club_id)
 select ('99460000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,case when n=6 then 9946002 else 9946001 end from generate_series(1,8) n;
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99460000-0000-4000-8000-000000000005','club_admin',9946001);
insert into football.competitions(id,slug,name,short_name) values ('99460000-0000-4000-8000-000000000200','predict-test','Test League','Test');
insert into football.seasons(id,competition_id,slug,label) values
 ('99460000-0000-4000-8000-000000000201','99460000-0000-4000-8000-000000000200','predict-season','2026');
insert into football.teams(id,name,crest_url) values
 ('99460000-0000-4000-8000-000000000210','Home Test','https://example.com/home.png'),
 ('99460000-0000-4000-8000-000000000211','Away Test','https://example.com/away.png');
insert into football.fixtures(id,competition_id,season_id,home_team_id,away_team_id,kickoff_at)
 select ('99460000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'99460000-0000-4000-8000-000000000200',
 '99460000-0000-4000-8000-000000000201','99460000-0000-4000-8000-000000000210','99460000-0000-4000-8000-000000000211',now()+make_interval(days=>n-300) from generate_series(301,308)n;

-- Helper is transaction-local test setup, never part of the deployed API.
create function pg_temp.actor(n int) returns void language plpgsql as $$ begin
 perform set_config('request.jwt.claim.sub','99460000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub','99460000-0000-4000-8000-'||lpad(n::text,12,'0'), 'role','authenticated')::text,true);
end $$;
select pg_temp.actor(5);
select lives_ok($$select public.predict_admin_settings(9946001,true,101)$$,'admin enables Predict with fixed price');
select lives_ok($$select public.predict_admin_prepare(9946001,'99460000-0000-4000-8000-000000000301','https://example.com/fixture')$$,'admin prepares verified fixture');
select public.predict_admin_prepare(9946001,id,'https://example.com/fixture') from football.fixtures where id::text like '99460000%' and id::text > '99460000-0000-4000-8000-000000000301';
select public.predict_admin_settings(9946001,true,100);
select is((select stake_fet from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301'),101,'price changes do not alter prepared pools');
select is((select count(*) from football.predict_pools)::int,8,'one pool per fixture');
select public.predict_admin_prepare(9946001,'99460000-0000-4000-8000-000000000301','https://example.com/fixture');
select is((select count(*) from football.predict_pools)::int,8,'preparation retries are idempotent');
select throws_ok($$select public.predict_admin_settings(9946002,true,100)$$,'42501','PREDICT_ADMIN_REQUIRED','club admin cannot change another club');
select pg_temp.actor(1);
select is((public.predict_dashboard(9946001)->'wallet'->>'balance_fet')::int,500,'verified session receives 500 welcome FET');
select is((public.predict_dashboard(9946001)->'wallet'->>'balance_fet')::int,500,'refresh does not repeat welcome grant');
select throws_ok($$select public.predict_dashboard(9946002)$$,'P0001','Requested club does not match the authenticated club context.','private dashboard rejects foreign tenant');
select throws_ok($$select public.predict_admin_dashboard(9946001)$$,'42501','PREDICT_ADMIN_REQUIRED','member cannot access operations');
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','2-1')$$,'P0001','PREDICT_INVALID_SELECTION','exact scores are not accepted');
select lives_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home')$$,'member places home result');
select lives_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home')$$,'same selection retry succeeds');
select is((select points from public.fan_memberships where user_id=auth.uid()),399,'one stored-price debit');
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','away')$$,'P0001','PREDICT_ALREADY_ENTERED','choice is immutable');
select pg_temp.actor(2); select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home');
select pg_temp.actor(3); select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','away');
select pg_temp.actor(7);
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home')$$,'42501','PREDICT_SIGN_IN_REQUIRED','unverified session cannot enter');
select pg_temp.actor(8);
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home')$$,'42501','PREDICT_SIGN_IN_REQUIRED','anonymous session cannot enter');
select pg_temp.actor(4);
select public.predict_dashboard(9946001);
update public.fan_memberships set points=0 where user_id=auth.uid();
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','away')$$,'P0001','PREDICT_INSUFFICIENT_FET','insufficient balance fails atomically');
select is((select count(*) from football.predict_entries where user_id=auth.uid())::int,0,'failed debit creates no entry');
select pg_temp.actor(5);
select throws_ok($$select public.predict_admin_settle(id) from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301'$$,'P0001','PREDICT_CONFIRMED_RESULT_REQUIRED','settlement requires verified final result');
update football.fixtures set kickoff_at=now()-interval '1 day',status='finished',home_score=2,away_score=1 where id='99460000-0000-4000-8000-000000000301';
select public.predict_admin_confirm_result(id,2,1,'https://example.com/result') from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301';
select public.predict_admin_settle(id) from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301';
select is((select sum(payout_fet) from football.predict_entries where pool_id in(select id from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301'))::int,303,'entire pool distributed without fee');
select is((select payout_fet from football.predict_entries where user_id='99460000-0000-4000-8000-000000000001')::int,152,'earlier winning entry receives remainder');
select is((select payout_fet from football.predict_entries where user_id='99460000-0000-4000-8000-000000000002')::int,151,'other winner receives equal base share');
select public.predict_admin_settle(id) from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301';
select is((select count(*) from public.fet_wallet_ledger_entries where entry_type='predict_payout')::int,2,'settlement retries never repeat credits');
-- No winner and voided fixtures refund every entry, including suspended wallets.
select pg_temp.actor(1); select public.predict_place(9946001,'99460000-0000-4000-8000-000000000302','away');
select public.predict_place(9946001,'99460000-0000-4000-8000-000000000303','draw');
update public.fan_memberships set status='suspended' where user_id=auth.uid();
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000304','home')$$,'42501','PREDICT_MEMBERSHIP_UNAVAILABLE','suspended member cannot place');
select pg_temp.actor(5);
update football.fixtures set kickoff_at=now()-interval '2 days',status='finished',home_score=2,away_score=1 where id='99460000-0000-4000-8000-000000000302';
select public.predict_admin_confirm_result(id,2,1,'https://example.com/result') from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000302';
select public.predict_admin_settle(id) from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000302';
select public.predict_admin_settle(id,'Fixture cancelled') from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000303';
select is((select count(*) from football.predict_entries where outcome='refunded')::int,2,'no-winner and void refund suspended wallets');
update football.fixtures set kickoff_at=clock_timestamp()-interval '1 second' where id='99460000-0000-4000-8000-000000000304';
select pg_temp.actor(2);
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000304','home')$$,'P0001','PREDICT_POOL_CLOSED','actual kickoff rejects entry before cron runs');
select public.predict_lock_due();
select is((select status from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000304'),'locked','automatic kickoff locking');
select ok(not has_table_privilege('authenticated','football.predict_entries','INSERT'),'clients cannot bypass place RPC');
select ok(not has_function_privilege('authenticated','public.predict_post_entry(bigint,uuid,integer,text,text,uuid,text)','EXECUTE'),'internal wallet helper cannot be called');
select ok(not has_function_privilege('anon','public.predict_place(bigint,uuid,text)','EXECUTE'),'guest cannot place');
select ok(has_function_privilege('anon','public.predict_dashboard(bigint)','EXECUTE'),'guest can browse');
select is(to_regprocedure('public.prediction_challenge_create(uuid,integer,integer,integer,bigint)')::text,null,'exact-score creation RPC retired');
select ok(to_regclass('football.prediction_challenges') is null,'old Challenge tables removed from exposed schema');
select ok(not has_schema_privilege('authenticated','retired','USAGE'),'historical records inaccessible to clients');
select ok((select count(*)>0 from public.admin_audit_log where action like 'predict.%'),'operator changes audited');
select * from finish();
rollback;

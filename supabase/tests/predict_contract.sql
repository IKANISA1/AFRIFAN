begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

insert into public.african_football_clubs(id,club_name,country_name,club_slug) overriding system value values
 (9946001,'Predict Test Club','Rwanda','predict-test-club'),(9946002,'Predict Other Club','Rwanda','predict-other-club');
insert into public.partners(id,name,slug,is_active) values
 ('99460000-0000-4000-8000-000000000100','Predict Test Club','predict-test-club',true),
 ('99460000-0000-4000-8000-000000000101','Predict Other Club','predict-other-club',true);
insert into public.membership_packages(partner_id,club_id,tier,title,subtitle,annual_price) values
 ('99460000-0000-4000-8000-000000000100',9946001,'fan','Test package','Test only',1000),
 ('99460000-0000-4000-8000-000000000101',9946002,'fan','Other test package','Test only',1000);
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

-- The public fixture projection must preserve the existing media gate.
insert into public.matches(id,partner_id,club_id,fixture_id,home_team,away_team,
 competition,venue,match_date,kickoff_time,image_url) values
 ('99460000-0000-4000-8000-000000000400','99460000-0000-4000-8000-000000000100',9946001,
 '99460000-0000-4000-8000-000000000301','Home Test','Away Test','Test League','Test Stadium',
 current_date+1,'18:00','https://example.com/fixture.webp');
set local role anon;
select is((select image_rights_approved from public.unified_matches where id='99460000-0000-4000-8000-000000000400'),false,
 'unreviewed fixture photo is marked unavailable in the public feed');
select ok(not has_column_privilege('authenticated','public.matches','image_rights_approved','UPDATE'),
 'supporter cannot approve fixture photography');
reset role;
update public.matches set image_rights_approved=true,image_provenance_id='isolated-fixture-only',
 image_rights_approved_at=now(),image_rights_approved_by='99460000-0000-4000-8000-000000000005'
 where id='99460000-0000-4000-8000-000000000400';
set local role anon;
select is((select image_provenance_id from public.unified_matches where id='99460000-0000-4000-8000-000000000400'),
 'isolated-fixture-only','public fixture feed carries approved-photo provenance');
select is((select image_rights_approved from public.unified_matches where id='99460000-0000-4000-8000-000000000400'),true,
 'approved fixture photograph can be displayed by Home and Club');
reset role;
update public.matches set image_rights_approved=false where id='99460000-0000-4000-8000-000000000400';
set local role anon;
select is((select image_rights_approved from public.unified_matches where id='99460000-0000-4000-8000-000000000400'),false,
 'withdrawn approval immediately hides the photograph in clients');
reset role;

-- Helper is transaction-local test setup, never part of the deployed API.
create function pg_temp.actor(n int) returns void language plpgsql as $$ begin
 perform set_config('request.jwt.claim.sub','99460000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 perform set_config('request.jwt.claim.role','authenticated',true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub','99460000-0000-4000-8000-'||lpad(n::text,12,'0'),
 'role','authenticated','is_anonymous',n=8,'aal',case when n=5 then 'aal2' else 'aal1' end,
 'exp',floor(extract(epoch from clock_timestamp()))+3600,'amr',jsonb_build_array(jsonb_build_object('method',case when n=5 then 'totp' else 'otp' end,'timestamp',floor(extract(epoch from clock_timestamp())))),
 'app_metadata',jsonb_build_object('club_id',case when n=6 then 9946002 else 9946001 end))::text,true);
end $$;
select pg_temp.actor(5);
select lives_ok($$select public.predict_admin_settings(9946001,true,0)$$,'admin enables fixed free policy');
select throws_ok($$select public.predict_admin_settings(9946001,true,100)$$,'P0001','PREDICT_FREE_ENTRY_REQUIRED','admin cannot reopen a paid price');
select public.predict_admin_prepare(9946001,id,'https://example.com/fixture') from football.fixtures where id::text like '99460000%';
select is((select count(*) from football.predict_pools where club_id=9946001)::int,8,'one prepared free pool per fixture');
select ok(not exists(select 1 from football.predict_pools where club_id=9946001 and (stake_fet<>0 or economics_version<>'free_v1')),'all new pools explicitly free');
select public.predict_admin_prepare(9946001,'99460000-0000-4000-8000-000000000301','https://example.com/fixture');
select is((select count(*) from football.predict_pools where club_id=9946001)::int,8,'free preparation retries are idempotent');
select is((public.predict_admin_dashboard(9946001)->'settings'->>'entry_fet')::int,0,'operations exposes fixed zero entry');
select is((public.predict_admin_dashboard(9946001)->'settings'->>'welcome_fet')::int,0,'operations exposes zero new welcome credit');
select throws_ok($$select public.predict_admin_settings(9946002,true,0)$$,'P0001','Requested club does not match the authenticated club context.','admin rejects foreign tenant');
set local role anon;
select is((select count(*)::int from public.predict_public_preview(9946001)),3,'public preview bounds selected free fixtures');
select is((select count(*)::int from public.predict_public_preview(9946002)),0,'public preview stays club scoped');
reset role;
select is((select count(*)::int from public.fan_memberships where club_id=9946001),0,'public discovery creates no wallet');
update football.predict_settings set enabled=false where club_id=9946001;
select is((select count(*)::int from public.predict_public_preview(9946001)),0,'disabled Predict publishes no free entries');
update football.predict_settings set enabled=true where club_id=9946001;
update football.teams set is_active=false where id='99460000-0000-4000-8000-000000000210';
select is((select count(*)::int from public.predict_public_preview(9946001)),0,'withdrawn teams cannot be offered');
update football.teams set is_active=true where id='99460000-0000-4000-8000-000000000210';
select pg_temp.actor(1);
select is(public.predict_dashboard(9946001)->'wallet','null'::jsonb,'free dashboard does not invent a welcome balance');
select public.predict_dashboard(9946001);
select is((select count(*)::int from public.fet_wallet_ledger_entries where club_id=9946001),0,'dashboard refresh creates no financial credit');
select throws_ok($$select public.predict_dashboard(9946002)$$,'P0001','Requested club does not match the authenticated club context.','private history rejects foreign tenant');
select throws_ok($$select public.predict_admin_dashboard(9946001)$$,'42501','PREDICT_ADMIN_REQUIRED','member cannot operate Predict');
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','2-1')$$,'P0001','PREDICT_INVALID_SELECTION','free entry accepts only selected result choices');
select lives_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home')$$,'verified member places a free pick with no wallet');
select lives_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home')$$,'same-choice retry returns original free receipt');
select is((select count(*) from football.predict_entries where user_id=auth.uid())::int,1,'retry stores only one entry');
select is((select count(*) from public.fan_memberships where user_id=auth.uid())::int,0,'free entry does not create a monetary wallet');
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','away')$$,'P0001','PREDICT_ALREADY_ENTERED','selection remains immutable');
select pg_temp.actor(2);select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home');
select pg_temp.actor(3);select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','away');
select pg_temp.actor(4);select public.fet_wallet_ensure_membership(auth.uid(),9946001);
select lives_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','away')$$,'zero-balance member can enter without FET');
select is((select points from public.fan_memberships where user_id=auth.uid()),0,'free entry leaves an existing zero balance unchanged');
select pg_temp.actor(7);
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home')$$,'42501','PREDICT_SIGN_IN_REQUIRED','unverified subject cannot enter');
select pg_temp.actor(8);
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000301','home')$$,'42501','PREDICT_SIGN_IN_REQUIRED','anonymous subject cannot enter');
select pg_temp.actor(5);
select throws_ok($$select public.predict_admin_settle(id) from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301'$$,'P0001','PREDICT_CONFIRMED_RESULT_REQUIRED','free outcomes require verified finished result');
-- Provider-owned official fixture setup is distinct from the human operator.
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.role','service_role',true);
update football.fixtures set kickoff_at=now()-interval '1 day',status='finished',home_score=2,away_score=1 where id='99460000-0000-4000-8000-000000000301';
select pg_temp.actor(5);
select throws_ok($$select public.predict_admin_confirm_result(id,1,2,'https://example.com/result') from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301'$$,'P0001','PREDICT_CONFIRMED_RESULT_REQUIRED','operator cannot invent the official result');
select public.predict_admin_confirm_result(id,2,1,'https://example.com/result') from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301';
select public.predict_admin_settle(id) from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301';
select is((select count(*) from football.predict_entries where club_id=9946001 and outcome='won')::int,2,'correctness records both correct predictions even with zero payout');
select is((select count(*) from football.predict_entries where club_id=9946001 and outcome='lost')::int,2,'incorrect predictions remain incorrect');
select is((select sum(score_points) from football.predict_entries where club_id=9946001)::int,2,'correct outcomes earn separate accuracy points');
select is((select sum(payout_fet) from football.predict_entries where club_id=9946001)::int,0,'accuracy does not create financial rewards');
select public.predict_admin_settle(id) from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000301';
select is((select sum(score_points) from football.predict_entries where club_id=9946001)::int,2,'settlement retry does not duplicate points');
select is((select count(*) from public.fet_wallet_ledger_entries where club_id=9946001)::int,0,'free settlement never appends money or FET ledger entries');
select pg_temp.actor(1);select public.predict_place(9946001,'99460000-0000-4000-8000-000000000302','away');
select public.predict_place(9946001,'99460000-0000-4000-8000-000000000303','draw');
select public.fet_wallet_ensure_membership(auth.uid(),9946001);
update public.fan_memberships set status='suspended' where user_id=auth.uid();
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000304','home')$$,'42501','PREDICT_MEMBERSHIP_UNAVAILABLE','suspended membership cannot create a free pick');
select pg_temp.actor(5);
-- Provider-owned official fixture setup is distinct from the human operator.
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.role','service_role',true);
update football.fixtures set kickoff_at=now()-interval '2 days',status='finished',home_score=2,away_score=1 where id='99460000-0000-4000-8000-000000000302';
select pg_temp.actor(5);
select public.predict_admin_confirm_result(id,2,1,'https://example.com/result') from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000302';
select public.predict_admin_settle(id) from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000302';
select is((select outcome from football.predict_entries where pool_id in(select id from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000302')),'lost','zero correct entrants is settled as incorrect, independent of payout');
select public.predict_admin_settle(id,'Fixture cancelled') from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000303';
select is((select count(*) from football.predict_entries where club_id=9946001 and outcome='refunded')::int,1,'explicit free void records only the voided pick');
select is((select score_points from football.predict_entries where club_id=9946001 and outcome='refunded'),0,'void creates no accuracy or financial credit');
-- Provider-owned official fixture setup is distinct from the human operator.
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.role','service_role',true);
update football.fixtures set kickoff_at=clock_timestamp()-interval '1 second' where id='99460000-0000-4000-8000-000000000304';
select pg_temp.actor(5);
select pg_temp.actor(2);
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000304','home')$$,'P0001','PREDICT_POOL_CLOSED','kickoff closes entry before cron runs');
select public.predict_lock_due();
select is((select status from football.predict_pools where fixture_id='99460000-0000-4000-8000-000000000304'),'locked','automatic lock bookkeeping remains supported');
update football.predict_settings set enabled=false where club_id=9946001;
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000305','home')$$,'P0001','PREDICT_POOL_CLOSED','disabled programme rejects new free entry');
insert into public.account_erasure_jobs(user_id) values(auth.uid());
select throws_ok($$select public.predict_place(9946001,'99460000-0000-4000-8000-000000000306','home')$$,'42501','ACCOUNT_CLOSURE_PENDING','closed current account cannot use the replacement place routine');
select throws_ok($$select public.predict_dashboard(9946001)$$,'42501','ACCOUNT_CLOSURE_PENDING','closed current account cannot read private replacement dashboard');
select ok(not has_table_privilege('authenticated','football.predict_entries','INSERT'),'client cannot bypass authoritative entry RPC');
select ok(not has_function_privilege('authenticated','public.predict_post_entry(bigint,uuid,integer,text,text,uuid,text)','EXECUTE'),'wallet helper stays private');
select ok(not has_function_privilege('anon','public.predict_place(bigint,uuid,text)','EXECUTE'),'guest cannot enter');
select ok(has_function_privilege('anon','public.predict_dashboard(bigint)','EXECUTE'),'guest can browse public free fixtures');
select is(to_regprocedure('public.prediction_challenge_create(uuid,integer,integer,integer,bigint)')::text,null,'retired exact-score creation stays retired');
select ok((select count(*)>0 from public.admin_audit_log where action like 'predict.%'),'operator changes retain audit evidence');
select * from finish();
rollback;

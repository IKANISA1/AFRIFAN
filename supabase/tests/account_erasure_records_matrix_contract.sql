begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.sub','',true);

insert into public.african_football_clubs(id,club_name,country_name,club_slug,country_iso_code,currency_code,momo_ussd_template,is_active) overriding system value values
 (9996501,'Erasure Matrix Club','Rwanda','erasure-matrix-test-club','RW','RWF','*182*8*1*{amount}*{recipient}#',true),
 (9996502,'Predict Other Club','Rwanda','predict-other-club','RW','RWF','*182*8*1*{amount}*{recipient}#',true);
insert into public.partners(id,name,slug,is_active) values
 ('99965000-0000-4000-8000-000000000100','Erasure Matrix Club','erasure-matrix-test-club',true),
 ('99965000-0000-4000-8000-000000000101','Predict Other Club','predict-other-club',true);
insert into public.membership_packages(partner_id,club_id,tier,title,subtitle,annual_price) values
 ('99965000-0000-4000-8000-000000000100',9996501,'fan','Test package','Test only',1000),
 ('99965000-0000-4000-8000-000000000101',9996502,'fan','Other test package','Test only',1000);
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous)
 select ('99965000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',
 case when n <> 7 then now() end,n=8 from generate_series(1,8) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('99965000-0000-4000-8000-'||lpad((n+950)::text,12,'0'))::uuid,
 ('99965000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour' from generate_series(1,8) n;
insert into public.users(id,phone,full_name)
 select ('99965000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+25079996500'||n,'Synthetic Predict '||n from generate_series(1,8) n;
insert into public.profiles(id,club_id)
 select ('99965000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,case when n=6 then 9996502 else 9996501 end from generate_series(1,8) n;
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99965000-0000-4000-8000-000000000005','club_admin',9996501),
 ('99965000-0000-4000-8000-000000000005','admin',null);
insert into football.competitions(id,slug,name,short_name) values ('99965000-0000-4000-8000-000000000200','erasure-matrix-test','Test League','Test');
insert into football.seasons(id,competition_id,slug,label) values
 ('99965000-0000-4000-8000-000000000201','99965000-0000-4000-8000-000000000200','erasure-matrix-season','2026');
insert into football.teams(id,name,crest_url) values
 ('99965000-0000-4000-8000-000000000210','Home Test','https://example.com/home.png'),
 ('99965000-0000-4000-8000-000000000211','Away Test','https://example.com/away.png');
insert into football.fixtures(id,competition_id,season_id,home_team_id,away_team_id,kickoff_at)
 select ('99965000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'99965000-0000-4000-8000-000000000200',
 '99965000-0000-4000-8000-000000000201','99965000-0000-4000-8000-000000000210','99965000-0000-4000-8000-000000000211',now()+make_interval(days=>n-300) from generate_series(301,308)n;

-- The public fixture projection must preserve the existing media gate.
insert into public.matches(id,partner_id,club_id,fixture_id,home_team,away_team,
 competition,venue,match_date,kickoff_time,image_url) values
 ('99965000-0000-4000-8000-000000000400','99965000-0000-4000-8000-000000000100',9996501,
 '99965000-0000-4000-8000-000000000301','Home Test','Away Test','Test League','Test Stadium',
 current_date+1,'18:00','https://example.com/fixture.webp');
set local role anon;
select is((select image_rights_approved from public.unified_matches where id='99965000-0000-4000-8000-000000000400'),false,
 'unreviewed fixture photo is marked unavailable in the public feed');
select ok(not has_column_privilege('authenticated','public.matches','image_rights_approved','UPDATE'),
 'supporter cannot approve fixture photography');
reset role;
update public.matches set image_rights_approved=true,image_provenance_id='isolated-fixture-only',
 image_rights_approved_at=now(),image_rights_approved_by='99965000-0000-4000-8000-000000000005'
 where id='99965000-0000-4000-8000-000000000400';
set local role anon;
select is((select image_provenance_id from public.unified_matches where id='99965000-0000-4000-8000-000000000400'),
 'isolated-fixture-only','public fixture feed carries approved-photo provenance');
select is((select image_rights_approved from public.unified_matches where id='99965000-0000-4000-8000-000000000400'),true,
 'approved fixture photograph can be displayed by Home and Club');
reset role;
update public.matches set image_rights_approved=false where id='99965000-0000-4000-8000-000000000400';
set local role anon;
select is((select image_rights_approved from public.unified_matches where id='99965000-0000-4000-8000-000000000400'),false,
 'withdrawn approval immediately hides the photograph in clients');
reset role;

-- Helper is transaction-local test setup, never part of the deployed API.
create function pg_temp.actor(n int) returns void language plpgsql as $$ begin
 perform set_config('request.jwt.claim.sub','99965000-0000-4000-8000-'||lpad(n::text,12,'0'),true);
 perform set_config('request.jwt.claims',jsonb_build_object('sub','99965000-0000-4000-8000-'||lpad(n::text,12,'0'),
 'role','authenticated','club_id',9996501,'aal','aal2','is_anonymous',n=8,
 'exp',floor(extract(epoch from clock_timestamp()))::bigint+3600,
 'session_id','99965000-0000-4000-8000-'||lpad((n+950)::text,12,'0'),
 'amr',jsonb_build_array(jsonb_build_object('method','totp',
 'timestamp',floor(extract(epoch from clock_timestamp()))::bigint-1)))::text,true);
end $$;

-- Synthetic historical records exercise retained paid liabilities. New public
-- Predict entrypoints admit only free entries and cannot create this history.
select set_config('request.jwt.claims','{"role":"service_role"}',true); select set_config('request.jwt.claim.sub','',true);
insert into football.predict_settings(club_id,enabled,entry_fet,welcome_fet) values(9996501,true,100,500);
insert into football.predict_pools(id,club_id,fixture_id,stake_fet,economics_version,locks_at,source_url,approved_by,entry_count,staked_fet)
 select ('99965000-0000-4000-8000-'||lpad((n+600)::text,12,'0'))::uuid,9996501,
 ('99965000-0000-4000-8000-'||lpad((n+300)::text,12,'0'))::uuid,100,'legacy_paid_v1',now()+make_interval(days=>n),
 'https://example.com/historical-closure-matrix','99965000-0000-4000-8000-000000000005',1,100 from generate_series(1,2)n;
insert into football.predict_entries(id,club_id,pool_id,user_id,selection,stake_fet,economics_version)
 select ('99965000-0000-4000-8000-'||lpad((n+700)::text,12,'0'))::uuid,9996501,
 ('99965000-0000-4000-8000-'||lpad((n+600)::text,12,'0'))::uuid,'99965000-0000-4000-8000-000000000001',
 case when n=1 then 'home' else 'away' end,100,'legacy_paid_v1' from generate_series(1,2)n;
select public.predict_post_entry(9996501,'99965000-0000-4000-8000-000000000001',500,'predict_welcome','closure-historical-wallet-seed',null,'Synthetic historical fixture credit');
select public.predict_post_entry(club_id,user_id,-stake_fet,'predict_entry','predict-entry:'||id,id,'Synthetic historical entry')
 from football.predict_entries where club_id=9996501 order by id;
update football.fixtures set kickoff_at=now()-interval '1 day',status='finished',home_score=2,away_score=1 where id='99965000-0000-4000-8000-000000000301';
select pg_temp.actor(5);
set local role authenticated;
select is(public.admit_verified_staff_command('99965000-0000-4000-8000-000000000801','predict_legacy_confirm',
 '99965000-0000-4000-8000-000000000601',
 '{"home_score":2,"away_score":1,"source_url":"https://example.com/closed-result"}')->>'status','admitted',
 'the current global caller admits exact historical result confirmation');
select is(public.admit_verified_staff_command('99965000-0000-4000-8000-000000000802','predict_legacy_settle',
 '99965000-0000-4000-8000-000000000601','{"void_reason":null}')->>'status','admitted',
 'the current global caller admits the original historical payout');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true); select set_config('request.jwt.claim.sub','',true);
select public.predict_admin_confirm_result_for_actor(id,2,1,'https://example.com/closed-result',
 '99965000-0000-4000-8000-000000000005','99965000-0000-4000-8000-000000000801') from football.predict_pools where fixture_id='99965000-0000-4000-8000-000000000301';
select public.predict_admin_settle_for_actor(id,'99965000-0000-4000-8000-000000000005','99965000-0000-4000-8000-000000000802')
 from football.predict_pools where fixture_id='99965000-0000-4000-8000-000000000301';
select set_config('request.jwt.claims','{"role":"service_role"}',true); select set_config('request.jwt.claim.sub','',true);
insert into public.admin_role_assignments(user_id,role) values('99965000-0000-4000-8000-000000000001','admin');
insert into public.payment_receiver_accounts(id,partner_id,payee_number_or_code,purpose,is_active) values
 ('99965000-0000-4000-8000-000000000500','99965000-0000-4000-8000-000000000100','12345','club_shop',true);
insert into public.membership_payment_orders(user_id,club_id,partner_id,package_id,tier,amount,currency,receiving_account_id,activated_at)
select '99965000-0000-4000-8000-000000000001',9996501,'99965000-0000-4000-8000-000000000100',id,'fan',1000,'RWF',
 '99965000-0000-4000-8000-000000000500',case when n=2 then now() end from public.membership_packages cross join generate_series(1,2)n where club_id=9996501;
insert into public.partner_payment_routes(id,club_id,partner_id,country,provider,recipient_code,reconciliation_label,status) values
 ('99965000-0000-4000-8000-000000000510',9996501,'99965000-0000-4000-8000-000000000100','RW','mtn','12345','Closure QA','active');
insert into public.shop_products(id,club_id,partner_id,name,category,price,stock,is_active,currency) values
 ('99965000-0000-4000-8000-000000000520',9996501,'99965000-0000-4000-8000-000000000100','Closure QA Shirt','shirt',2500,4,true,'RWF');
update public.fan_memberships set payment_status='verified',status='active',expires_at=now()+interval '1 year'
 where user_id='99965000-0000-4000-8000-000000000001' and club_id=9996501;
select pg_temp.actor(1);
create temporary table matrix_receipt as select public.prepare_shop_checkout_for_club('[{"product_id":"99965000-0000-4000-8000-000000000520","quantity":1}]','Private address QA','order-99965000-0000-4000-8000-000000000530',9996501) body;
select set_config('request.jwt.claims','{"role":"service_role"}',true); select set_config('request.jwt.claim.sub','',true);
insert into storage.buckets(id,name) values('closure-fixture-bucket','closure-fixture-bucket');
insert into storage.objects(bucket_id,name,owner,owner_id) values('closure-fixture-bucket','private-avatar.png','99965000-0000-4000-8000-000000000001','99965000-0000-4000-8000-000000000001');
create temporary table closure_matrix_jobs as select public.request_account_erasure('99965000-0000-4000-8000-000000000001') receipt;
select is((select count(*)::integer from public.membership_payment_orders where user_id='99965000-0000-4000-8000-000000000001'),2,'pending and paid membership obligations both retain Auth subject');
select is((select count(*)::integer from football.predict_entries where user_id='99965000-0000-4000-8000-000000000001'),2,'open and settled entries survive closure');
select is((select sum(amount)::integer from public.membership_payment_orders where user_id='99965000-0000-4000-8000-000000000001'),2000,'membership financial amount unchanged');
create temporary table closure_matrix_claim as select public.claim_account_erasure_jobs(1)->0 job;
create function pg_temp.erase_shop_projection(extra_receipt jsonb default '{}',tamper text default null) returns void
 language plpgsql as $$ begin
 update public.shop_orders set delivery_address=null,payment_receipt=(payment_receipt-'delivery_address')||extra_receipt,
 total=case when tamper='total' then total+1 else total end,
 items=case when tamper='items' then '[]'::jsonb else items end,
 momo_reference=case when tamper='reference' then 'order-99965000-0000-4000-8000-000000000599' else momo_reference end
 where momo_reference='order-99965000-0000-4000-8000-000000000530';
 end $$;
select throws_ok($$select pg_temp.erase_shop_projection()$$,'P0001','SHOP_RECEIPT_IMMUTABLE','service alone cannot erase a frozen receipt');
select set_config('account_erasure.job_id',(select job->>'request_id' from closure_matrix_claim),true);
select set_config('account_erasure.lease_token','99965000-0000-4000-8000-000000000599',true);
select throws_ok($$select pg_temp.erase_shop_projection()$$,'P0001','SHOP_RECEIPT_IMMUTABLE','wrong worker lease cannot erase receipt');
select throws_ok($$select public.erase_account_local_batch((select (job->>'request_id')::uuid from closure_matrix_claim),'99965000-0000-4000-8000-000000000599',500)$$,'P0001','ERASURE_LEASE_LOST','worker RPC rejects wrong lease');
select set_config('account_erasure.lease_token',(select job->>'lease_token' from closure_matrix_claim),true);
update public.account_erasure_jobs set lease_until=clock_timestamp()-interval '1 second' where id=(select (job->>'request_id')::uuid from closure_matrix_claim);
select throws_ok($$select pg_temp.erase_shop_projection()$$,'P0001','SHOP_RECEIPT_IMMUTABLE','expired lease cannot erase receipt');
select throws_ok($$select public.erase_account_local_batch((select (job->>'request_id')::uuid from closure_matrix_claim),(select (job->>'lease_token')::uuid from closure_matrix_claim),500)$$,'P0001','ERASURE_LEASE_LOST','worker RPC rejects expired lease');
update public.account_erasure_jobs set lease_until=clock_timestamp()+interval '2 minutes',state='failed' where id=(select (job->>'request_id')::uuid from closure_matrix_claim);
select throws_ok($$select pg_temp.erase_shop_projection()$$,'P0001','SHOP_RECEIPT_IMMUTABLE','nonpending subject cannot erase frozen receipt');
select throws_ok($$select public.erase_account_local_batch((select (job->>'request_id')::uuid from closure_matrix_claim),(select (job->>'lease_token')::uuid from closure_matrix_claim),500)$$,'P0001','ERASURE_LEASE_LOST','worker requires an active pending job');
update public.account_erasure_jobs set state='deletion_pending' where id=(select (job->>'request_id')::uuid from closure_matrix_claim);
select throws_ok($$select pg_temp.erase_shop_projection('{}','total')$$,'P0001','SHOP_RECEIPT_IMMUTABLE','privacy work cannot alter authoritative total');
select throws_ok($$select pg_temp.erase_shop_projection('{}','items')$$,'P0001','SHOP_RECEIPT_IMMUTABLE','privacy work cannot alter commercial lines');
select throws_ok($$select pg_temp.erase_shop_projection('{}','reference')$$,'P0001','SHOP_RECEIPT_IMMUTABLE','privacy work cannot replace payment reference');
select throws_ok($$select pg_temp.erase_shop_projection('{"currency":"USD"}')$$,'P0001','SHOP_RECEIPT_IMMUTABLE','privacy work cannot relabel receipt currency');
select throws_ok($$select pg_temp.erase_shop_projection('{"receiver_id":"99965000-0000-4000-8000-000000000599"}')$$,'P0001','SHOP_RECEIPT_IMMUTABLE','privacy work cannot replace receiver authority');
select throws_ok($$select pg_temp.erase_shop_projection('{"total":1}')$$,'P0001','SHOP_RECEIPT_IMMUTABLE','privacy work cannot tamper with frozen receipt total');
select pg_temp.actor(5);
select throws_ok($$select pg_temp.erase_shop_projection()$$,'P0001','SHOP_RECEIPT_IMMUTABLE','authenticated staff cannot use a service privacy lease');
select set_config('request.jwt.claims','{"role":"service_role"}',true); select set_config('request.jwt.claim.sub','',true);
select set_config('account_erasure.job_id','',true); select set_config('account_erasure.lease_token','',true);
select public.erase_account_local_batch((select (job->>'request_id')::uuid from closure_matrix_claim),(select (job->>'lease_token')::uuid from closure_matrix_claim),500);
select is(current_setting('account_erasure.job_id',true),'','worker restores its internal privacy context');
select is((select total from public.shop_orders where momo_reference='order-99965000-0000-4000-8000-000000000530'),2500,'immutable shop money preserved during address erasure');
select ok((select delivery_address is null and payment_receipt=(select (body->'receipt')-'delivery_address'::text from matrix_receipt) from public.shop_orders where momo_reference='order-99965000-0000-4000-8000-000000000530'),'only delivery address is removed from immutable receipt');
select throws_ok($$update public.shop_orders set status='paid' where momo_reference='order-99965000-0000-4000-8000-000000000530'$$,'P0001','SHOP_RECEIPT_EVIDENCE_MISMATCH','address erasure never authorizes an unpaid order');
select throws_ok($$select public.record_account_erasure_step((select (job->>'request_id')::uuid from closure_matrix_claim),(select (job->>'lease_token')::uuid from closure_matrix_claim),'storage',true,'fake storage completion')$$,'P0001','STORAGE_NOT_ERASED','owned Storage object prevents false completion');
select is(jsonb_array_length(public.account_erasure_storage_batch((select (job->>'request_id')::uuid from closure_matrix_claim),(select (job->>'lease_token')::uuid from closure_matrix_claim),100)),1,'worker discovers exact owned Storage object');
select throws_ok($$update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='99965000-0000-4000-8000-000000000001'$$,'42501','CLOSED_SUBJECT_AUTHORITY_DENIED','service cannot restore closed staff authority');
select pg_temp.actor(5);
set local role authenticated;
select is(public.admit_verified_staff_command('99965000-0000-4000-8000-000000000803','predict_legacy_settle',
 '99965000-0000-4000-8000-000000000602','{"void_reason":"Closure prior liability refund"}')->>'status','admitted',
 'a distinct current global caller admits retained liability without renewing the closed subject');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true); select set_config('request.jwt.claim.sub','',true);
select lives_ok($$select public.predict_admin_settle_for_actor(id,'99965000-0000-4000-8000-000000000005','99965000-0000-4000-8000-000000000803','Closure prior liability refund') from football.predict_pools where fixture_id='99965000-0000-4000-8000-000000000302'$$,'active global service actor settles prior financial liability after subject closure');
select is((select points from public.fan_memberships where user_id='99965000-0000-4000-8000-000000000001'),500,'prior stake refund restores balance without deleting ledger');
select set_config('request.jwt.claims','{"role":"service_role"}',true); select set_config('request.jwt.claim.sub','',true);
select is(public.request_account_erasure('99965000-0000-4000-8000-000000000002')->>'status','deletion_pending','no-financial-record account also has a durable pending journey');
select ok(exists(select 1 from public.account_erasure_fk_inventory where child_table like 'retired.%'),'retired schema relationships inventoried and retained');
select * from finish();
rollback;

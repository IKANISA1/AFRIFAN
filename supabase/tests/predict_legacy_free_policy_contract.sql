begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

insert into public.african_football_clubs(id,club_name,country_name,club_slug) overriding system value values
 (9946101,'Predict Test Club','Rwanda','predict-legacy-contract-club'),(9946102,'Predict Other Club','Rwanda','predict-legacy-other-club');
insert into public.partners(id,name,slug,is_active) values
 ('99461000-0000-4000-8000-000000000100','Predict Test Club','predict-legacy-contract-club',true),
 ('99461000-0000-4000-8000-000000000101','Predict Other Club','predict-legacy-other-club',true);
insert into public.membership_packages(partner_id,club_id,tier,title,subtitle,annual_price) values
 ('99461000-0000-4000-8000-000000000100',9946101,'fan','Test package','Test only',1000),
 ('99461000-0000-4000-8000-000000000101',9946102,'fan','Other test package','Test only',1000);
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous)
 select ('99461000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',
 case when n <> 7 then now() end,n=8 from generate_series(1,8) n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('99461000-0000-4000-8000-000000000555','99461000-0000-4000-8000-000000000005',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
insert into public.users(id,phone,full_name)
 select ('99461000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+25079946100'||n,'Synthetic Predict '||n from generate_series(1,8) n;
insert into public.profiles(id,club_id)
 select ('99461000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,case when n=6 then 9946102 else 9946101 end from generate_series(1,8) n;
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99461000-0000-4000-8000-000000000005','club_admin',9946101);
insert into football.competitions(id,slug,name,short_name) values ('99461000-0000-4000-8000-000000000200','predict-legacy-contract','Test League','Test');
insert into football.seasons(id,competition_id,slug,label) values
 ('99461000-0000-4000-8000-000000000201','99461000-0000-4000-8000-000000000200','predict-legacy-contract-season','2026');
insert into football.teams(id,name,crest_url) values
 ('99461000-0000-4000-8000-000000000210','Home Test','https://example.com/home.png'),
 ('99461000-0000-4000-8000-000000000211','Away Test','https://example.com/away.png');
insert into football.fixtures(id,competition_id,season_id,home_team_id,away_team_id,kickoff_at)
 select ('99461000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'99461000-0000-4000-8000-000000000200',
 '99461000-0000-4000-8000-000000000201','99461000-0000-4000-8000-000000000210','99461000-0000-4000-8000-000000000211',now()+make_interval(days=>n-300) from generate_series(301,308)n;


-- Owner fixture explicitly represents retained liabilities; public paid creation is closed.
create function pg_temp.actor(n int, service boolean default false) returns void language plpgsql as $$
declare u text:='99461000-0000-4000-8000-'||lpad(n::text,12,'0'); e bigint:=floor(extract(epoch from clock_timestamp()));
begin
 perform set_config('request.jwt.claim.sub',case when service then '' else u end,true);
 perform set_config('request.jwt.claim.role',case when service then 'service_role' else 'authenticated' end,true);
 perform set_config('request.jwt.claims',case when service then '{"role":"service_role"}' else jsonb_build_object('sub',u,'role','authenticated',
 'is_anonymous',n=8,'aal',case when n=5 then 'aal2' else 'aal1' end,'exp',e+3600,
 'session_id','99461000-0000-4000-8000-000000000555',
 'amr',jsonb_build_array(jsonb_build_object('method',case when n=5 then 'totp' else 'otp' end,'timestamp',e)),
 'app_metadata',jsonb_build_object('club_id',9946101))::text end,true);
end $$;
insert into public.admin_role_assignments(user_id,role) values ('99461000-0000-4000-8000-000000000005','super_admin');
insert into football.predict_settings(club_id,enabled,entry_fet,welcome_fet) values(9946101,true,101,500);
insert into football.predict_pools(id,club_id,fixture_id,stake_fet,locks_at,economics_version,entry_count,staked_fet,source_url,approved_by)
 select ('99461000-0000-4000-8000-'||lpad((n+200)::text,12,'0'))::uuid,9946101,
 ('99461000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,101,now()+interval '1 day','legacy_paid_v1',case when n=301 then 3 else 1 end,case when n=301 then 303 else 101 end,'https://example.com/historical-fixture','99461000-0000-4000-8000-000000000005'
 from generate_series(301,303)n;
select pg_temp.actor(5);
select public.predict_post_entry(9946101,('99461000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,500,'predict_welcome','predict-welcome',null,'Historical welcome') from generate_series(1,4)n;
insert into football.predict_entries(id,pool_id,club_id,user_id,selection,stake_fet,economics_version,placed_at)
 select ('99461000-0000-4000-8000-'||lpad((n+600)::text,12,'0'))::uuid,'99461000-0000-4000-8000-000000000501',9946101,
 ('99461000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,case when n<3 then 'home' else 'away' end,101,'legacy_paid_v1',now()+make_interval(secs=>n) from generate_series(1,3)n;
insert into football.predict_entries(id,pool_id,club_id,user_id,selection,stake_fet,economics_version) values
 ('99461000-0000-4000-8000-000000000604','99461000-0000-4000-8000-000000000502',9946101,'99461000-0000-4000-8000-000000000004','away',101,'legacy_paid_v1'),
 ('99461000-0000-4000-8000-000000000605','99461000-0000-4000-8000-000000000503',9946101,'99461000-0000-4000-8000-000000000001','draw',101,'legacy_paid_v1');
select public.predict_post_entry(9946101,user_id,-stake_fet,'predict_entry','predict-entry:'||id,id,'Historical charged entry') from football.predict_entries where club_id=9946101 order by id;
select is((select points from public.fan_memberships where club_id=9946101 and user_id='99461000-0000-4000-8000-000000000001'),298,'historical debits exist before service settlement');
select pg_temp.actor(4);
select throws_ok($$select public.predict_place(9946101,'99461000-0000-4000-8000-000000000301','home')$$,'P0001','PREDICT_LEGACY_ENTRY_CLOSED','new charged entry is closed');
select pg_temp.actor(1);
select lives_ok($$select public.predict_place(9946101,'99461000-0000-4000-8000-000000000301','home')$$,'historical same-choice lost-response retry reads the original receipt');
select is((select count(*) from public.predict_public_preview(9946101))::int,0,'historical paid pools are never offered as new free fixtures');
select is(jsonb_array_length(public.predict_dashboard(9946101)->'fixtures'),0,'private active journey excludes paid pools');
select is(jsonb_array_length(public.predict_dashboard(9946101)->'history'),2,'historical charged picks remain readable');
select pg_temp.actor(5);
select throws_ok($$select public.predict_admin_prepare(9946101,'99461000-0000-4000-8000-000000000301','https://example.com/fixture')$$,'P0001','PREDICT_LEGACY_POOL_PRESENT','free prepare cannot convert a paid liability');
select throws_ok($$select public.predict_admin_settle('99461000-0000-4000-8000-000000000501')$$,'42501','PREDICT_LEGACY_SETTLEMENT_SERVICE_REQUIRED','ordinary client settlement cannot alter historical money');
select is((public.predict_admin_dashboard(9946101)->'settings'->>'legacy_entry_fet')::int,101,'historical configured amount remains retained separately');
select is((public.predict_admin_dashboard(9946101)->'settings'->>'entry_fet')::int,0,'active settings expose only the new zero price');
select throws_ok($$select public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000501','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000701',null)$$,'42501','PREDICT_GLOBAL_SERVICE_REQUIRED','JWT caller alone cannot invoke service dispatcher');
update football.fixtures set status='finished',home_score=2,away_score=1,kickoff_at=now()-make_interval(days=>right(id::text,3)::int-300) where id::text like '99461000%' and id in(select fixture_id from football.predict_pools where club_id=9946101);
-- Human admission executes as the actual authenticated role against its real
-- vendor Auth session; the original service wrapper is a separate role.
select pg_temp.actor(5);
set local role authenticated;
select throws_ok($$select public.admit_verified_staff_command('99461000-0000-4000-8000-000000000698','predict_legacy_confirm','99461000-0000-4000-8000-000000000501','{"home_score":2,"away_score":1,"source_url":"http://example.com/result"}')$$,'22023','STAFF_COMMAND_ARGUMENTS_INVALID','historical result requires HTTPS at actual human admission');
select public.admit_verified_staff_command('99461000-0000-4000-8000-000000000699','predict_legacy_confirm','99461000-0000-4000-8000-000000000501','{"home_score":1,"away_score":2,"source_url":"https://example.com/result"}');
reset role;
select pg_temp.actor(5,true);
set local role service_role;
select throws_ok($$select public.predict_admin_confirm_result_for_actor('99461000-0000-4000-8000-000000000501',2,1,'https://example.com/result','99461000-0000-4000-8000-000000000004','99461000-0000-4000-8000-000000000700')$$,'42501','PREDICT_GLOBAL_ADMIN_REQUIRED','service caller must name an actually authorized global actor');
select throws_ok($$select public.predict_admin_confirm_result_for_actor('99461000-0000-4000-8000-000000000501',1,2,'https://example.com/result','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000699')$$,'P0001','PREDICT_CONFIRMED_RESULT_REQUIRED','even admitted global actor cannot invent a historical official result');
reset role;
select pg_temp.actor(5);
set local role authenticated;
select public.admit_verified_staff_command('99461000-0000-4000-8000-000000000700','predict_legacy_confirm','99461000-0000-4000-8000-000000000501','{"home_score":2,"away_score":1,"source_url":"https://example.com/result"}');
reset role;
select pg_temp.actor(5,true);
set local role service_role;
select lives_ok($$select public.predict_admin_confirm_result_for_actor('99461000-0000-4000-8000-000000000501',2,1,'https://example.com/result','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000700')$$,'actual admitted service/global actor records immutable historical result');
reset role;
select pg_temp.actor(5);
set local role authenticated;
select public.admit_verified_staff_command('99461000-0000-4000-8000-000000000701','predict_legacy_settle','99461000-0000-4000-8000-000000000501','{"void_reason":null}');
reset role;
select pg_temp.actor(5,true);
set local role service_role;
create temp table receipt as select public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000501','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000701',null) as value;
select is((select value->>'economics_version' from receipt),'legacy_paid_v1','historical service receipt carries explicit version');
reset role;
select is((select sum(payout_fet) from football.predict_entries where pool_id='99461000-0000-4000-8000-000000000501')::int,303,'preserved financial engine pays exactly the old charged total');
select is((select payout_fet from football.predict_entries where id='99461000-0000-4000-8000-000000000601')::int,152,'preserved remainder ordering pays earlier winner 152');
select is((select payout_fet from football.predict_entries where id='99461000-0000-4000-8000-000000000602')::int,151,'preserved remainder pays later winner 151');
set local role service_role;
select is(public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000501','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000701',null),(select value from receipt),'lost response replay returns the identical stored operation result');
reset role;
select is((select count(*) from public.fet_wallet_ledger_entries where club_id=9946101 and entry_type='predict_payout')::int,2,'replay never pays twice');
set local role service_role;
select throws_ok($$select public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000501','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000701','Changed reason')$$,'P0001','PREDICT_OPERATION_BINDING_MISMATCH','operation identity binds the original settlement reason');
select throws_ok($$select public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000502','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000701',null)$$,'P0001','PREDICT_OPERATION_BINDING_MISMATCH','operation identity binds the original pool');
select throws_ok($$select public.predict_admin_confirm_result_for_actor('99461000-0000-4000-8000-000000000501',2,1,'https://example.com/changed','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000700')$$,'P0001','PREDICT_OPERATION_BINDING_MISMATCH','result confirmation operation binds the exact source');
reset role;
select pg_temp.actor(5);
set local role authenticated;
select public.admit_verified_staff_command('99461000-0000-4000-8000-000000000702','predict_legacy_confirm','99461000-0000-4000-8000-000000000502','{"home_score":2,"away_score":1,"source_url":"https://example.com/result"}');
reset role;
select pg_temp.actor(5,true);
set local role service_role;
select public.predict_admin_confirm_result_for_actor('99461000-0000-4000-8000-000000000502',2,1,'https://example.com/result','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000702');
reset role;
select pg_temp.actor(5);
set local role authenticated;
select public.admit_verified_staff_command('99461000-0000-4000-8000-000000000703','predict_legacy_settle','99461000-0000-4000-8000-000000000502','{"void_reason":null}');
reset role;
select pg_temp.actor(5,true);
set local role service_role;
select public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000502','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000703',null);
reset role;
select is((select outcome from football.predict_entries where id='99461000-0000-4000-8000-000000000604'),'refunded','old zero-winner engine keeps historical refund semantics');
select pg_temp.actor(5);
insert into public.account_erasure_jobs(user_id) values('99461000-0000-4000-8000-000000000001');
update public.fan_memberships set status='suspended' where club_id=9946101 and user_id='99461000-0000-4000-8000-000000000001';
select pg_temp.actor(5);
set local role authenticated;
select public.admit_verified_staff_command('99461000-0000-4000-8000-000000000704','predict_legacy_settle','99461000-0000-4000-8000-000000000503','{"void_reason":"Fixture cancelled"}');
reset role;
select pg_temp.actor(5,true);
set local role service_role;
select lives_ok($$select public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000503','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000704','Fixture cancelled')$$,'active global operator can refund a retained closed-subject liability');
reset role;
select is((select payout_fet from football.predict_entries where id='99461000-0000-4000-8000-000000000605')::int,101,'closure does not erase the historical refund amount');
set local role service_role;

-- The older partner engine has its own retained liability, reachable only by attributed service.
reset role;
select pg_temp.actor(5);
insert into football.partner_prediction_pools(id,club_id,partner_id,fixture_id,title,partner_stake_fet,fan_entry_fet,lock_at,total_entries,total_fan_entry_fet,created_by) values
 ('99461000-0000-4000-8000-000000000801',9946101,'99461000-0000-4000-8000-000000000100','99461000-0000-4000-8000-000000000304','Historical partner',200,100,now()+interval '1 day',1,100,'99461000-0000-4000-8000-000000000005');
insert into football.partner_prediction_pool_entries(id,pool_id,club_id,partner_id,fixture_id,user_id,selected_outcome,fan_entry_fet) values
 ('99461000-0000-4000-8000-000000000802','99461000-0000-4000-8000-000000000801',9946101,'99461000-0000-4000-8000-000000000100','99461000-0000-4000-8000-000000000304','99461000-0000-4000-8000-000000000002','home_win',100);
select public.predict_post_entry(9946101,'99461000-0000-4000-8000-000000000002',-100,'partner_pool_entry','historical-partner-entry','99461000-0000-4000-8000-000000000802','Historical partner charge');
select throws_ok($$select public.partner_prediction_pool_create('99461000-0000-4000-8000-000000000100','99461000-0000-4000-8000-000000000305','New paid pool',200,100,p_club_id=>9946101)$$,'P0001','PREDICT_LEGACY_ENTRY_CLOSED','old partner paid creation is closed too');
select pg_temp.actor(4);
select throws_ok($$select public.partner_prediction_pool_join('99461000-0000-4000-8000-000000000801','home_win')$$,'P0001','PREDICT_LEGACY_ENTRY_CLOSED','old partner new paid join cannot bypass policy');
select pg_temp.actor(5);
update football.fixtures set status='finished',home_score=2,away_score=1,kickoff_at=now()-interval '4 days' where id='99461000-0000-4000-8000-000000000304';
set local role authenticated;
select public.admit_verified_staff_command('99461000-0000-4000-8000-000000000705','partner_legacy_settle','99461000-0000-4000-8000-000000000801','{}');
reset role;
select pg_temp.actor(5,true);
set local role service_role;
select lives_ok($$select public.partner_prediction_pool_settle_for_actor('99461000-0000-4000-8000-000000000801','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000705')$$,'historical partner engine remains reachable through actual global service command');
reset role;
select is((select payout_fet from football.partner_prediction_pool_entries where id='99461000-0000-4000-8000-000000000802'),300,'historical partner engine preserves sponsor plus fan distribution');
set local role service_role;
select public.partner_prediction_pool_settle_for_actor('99461000-0000-4000-8000-000000000801','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000705');
reset role;
select is((select count(*) from public.fet_wallet_ledger_entries where club_id=9946101 and entry_type='partner_pool_payout')::int,1,'partner operation retry does not duplicate credit');
set local role service_role;
select throws_ok($$select public.partner_prediction_pool_settle_for_actor('99461000-0000-4000-8000-000000000801','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000701')$$,'P0001','PREDICT_OPERATION_BINDING_MISMATCH','operation UUID cannot move between settlement engines');
reset role;
select pg_temp.actor(5);
insert into public.admin_role_assignments(user_id,role) values('99461000-0000-4000-8000-000000000003','super_admin');
select pg_temp.actor(5,true);
set local role service_role;
select throws_ok($$select public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000501','99461000-0000-4000-8000-000000000003','99461000-0000-4000-8000-000000000701',null)$$,'P0001','PREDICT_OPERATION_BINDING_MISMATCH','operation UUID binds the actual original authorized actor');
select throws_ok($$select public.predict_admin_confirm_result_for_actor('99461000-0000-4000-8000-000000000501',1,2,'https://example.com/result','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000700')$$,'P0001','PREDICT_OPERATION_BINDING_MISMATCH','confirmation UUID cannot change the immutable score');
reset role;
select pg_temp.actor(5);
update public.admin_role_assignments set is_active=false,revoked_at=now() where user_id='99461000-0000-4000-8000-000000000005' and role='super_admin';
select pg_temp.actor(5,true);
set local role service_role;
select throws_ok($$select public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000501','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000701',null)$$,'42501','PREDICT_GLOBAL_ADMIN_REQUIRED','successful operation replay still reauthorizes current global role');
reset role;
select pg_temp.actor(5);
insert into public.account_erasure_jobs(user_id) values('99461000-0000-4000-8000-000000000005');
select pg_temp.actor(5,true);
set local role service_role;
select throws_ok($$select public.predict_admin_settle_for_actor('99461000-0000-4000-8000-000000000501','99461000-0000-4000-8000-000000000005','99461000-0000-4000-8000-000000000701',null)$$,'42501','ACCOUNT_CLOSURE_PENDING','closed operator cannot replay even previously committed historical operation');
reset role;
-- Stored relation names were captured with search_path='', while this test has
-- public in its path. Compare catalogue identities, not regclass display text.
create temporary view current_subject_fk_inventory_mismatches as
 select c.oid,c.conname,c.conrelid::regclass::text child_table,c.confrelid::regclass::text subject_table,
  c.confdeltype::text deletion_action,to_jsonb(stored) inventory_row
 from pg_constraint c left join public.account_erasure_fk_inventory stored on stored.constraint_oid=c.oid
 where c.contype='f' and c.confrelid in ('auth.users'::regclass,'public.users'::regclass,'public.profiles'::regclass)
  and not exists(select 1 from public.account_erasure_fk_inventory i where i.constraint_oid=c.oid
   and to_regclass(i.child_table)=c.conrelid and to_regclass(i.subject_table)=c.confrelid
   and i.deletion_action=c.confdeltype::text and i.retained);
select diag(format('Missing or mismatched retained subject FK: oid=%s constraint=%s child=%s subject=%s action=%s inventory=%s',
 oid,conname,child_table,subject_table,deletion_action,coalesce(inventory_row::text,'absent')))
 from current_subject_fk_inventory_mismatches order by child_table,conname;
select ok(not exists(select 1 from current_subject_fk_inventory_mismatches),
 'complete current subject FK catalogue remains inventoried after forward migration');
select ok((select relrowsecurity from pg_class where oid='football.predict_service_operations'::regclass),'service operation receipts enable RLS');
select ok(not has_table_privilege('authenticated','football.predict_service_operations','SELECT,INSERT,UPDATE,DELETE'),'client has no operation receipt table privileges');
select ok(has_table_privilege('service_role','football.predict_service_operations','SELECT') and not has_table_privilege('service_role','football.predict_service_operations','INSERT,UPDATE,DELETE'),'service can inspect receipts only through direct table grant');
select ok(not exists(select 1 from unnest(array['public.predict_legacy_paid_settle_internal(uuid,text)','public.predict_legacy_confirm_result_internal(uuid,integer,integer,text)','public.partner_prediction_pool_settle_legacy_internal(uuid)','public.predict_service_command_internal(text,uuid,uuid,uuid,jsonb)']) signature
 cross join unnest(array['anon','authenticated','service_role']) r where has_function_privilege(r,signature,'EXECUTE')), 'all historical engines and dispatcher stay private even to service role');
select ok(not exists(select 1 from unnest(array['public.predict_admin_settle_for_actor(uuid,uuid,uuid,text)','public.partner_prediction_pool_settle_for_actor(uuid,uuid,uuid)','public.predict_admin_confirm_result_for_actor(uuid,integer,integer,text,uuid,uuid)']) signature
 cross join unnest(array['anon','authenticated']) r where has_function_privilege(r,signature,'EXECUTE')), 'only the three attributed wrappers are granted to service, never clients');
select ok((select count(*)=6 from public.admin_audit_log where club_id=9946101 and action like 'predict.global_service.%'),'each committed operation has one actual global actor audit and retries add none');
select * from finish();
rollback;

begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claim.sub','',true);

insert into public.african_football_clubs(id,club_name,country_name,country_iso_code,club_slug) overriding system value values
 (9996701,'Staff Admission A','Rwanda','RW','staff-admission-a'),(9996702,'Staff Admission B','Rwanda','RW','staff-admission-b');
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous)
 select ('99967000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',now(),false from generate_series(1,6)n;
insert into public.users(id,phone,full_name)
 select ('99967000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+25079996700'||n,'Synthetic staff command '||n from generate_series(1,6)n;
insert into public.profiles(id,club_id)
 select ('99967000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,9996701 from generate_series(1,6)n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('99967000-0000-4000-8000-'||lpad((n+550)::text,12,'0'))::uuid,
 ('99967000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour' from generate_series(1,6)n;
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99967000-0000-4000-8000-000000000001','super_admin',null),
 ('99967000-0000-4000-8000-000000000002','admin',null),
 ('99967000-0000-4000-8000-000000000003','club_admin',9996701);
insert into public.partners(id,name,slug,is_active) values
 ('99967000-0000-4000-8000-000000000100','Staff Admission A','staff-admission-a',true);
insert into public.membership_packages(partner_id,club_id,tier,title,subtitle,annual_price) values
 ('99967000-0000-4000-8000-000000000100',9996701,'fan','Admission fixture package','Synthetic only',1000);
insert into football.competitions(id,slug,name,short_name) values
 ('99967000-0000-4000-8000-000000000200','staff-admission-league','Staff Admission League','Staff');
insert into football.seasons(id,competition_id,slug,label) values
 ('99967000-0000-4000-8000-000000000201','99967000-0000-4000-8000-000000000200','staff-admission-season','2026');
insert into football.teams(id,name,crest_url) values
 ('99967000-0000-4000-8000-000000000210','Staff Admission Home','https://example.test/staff-home.png'),
 ('99967000-0000-4000-8000-000000000211','Staff Admission Away','https://example.test/staff-away.png');
insert into football.fixtures(id,competition_id,season_id,home_team_id,away_team_id,kickoff_at,status,home_score,away_score)
 select ('99967000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'99967000-0000-4000-8000-000000000200',
 '99967000-0000-4000-8000-000000000201','99967000-0000-4000-8000-000000000210','99967000-0000-4000-8000-000000000211',
 now()-make_interval(days=>n-299),'finished',2,1 from generate_series(301,308)n;
insert into football.predict_settings(club_id,enabled,entry_fet,welcome_fet) values(9996701,true,100,500);
insert into football.predict_pools(id,club_id,fixture_id,stake_fet,created_at,opens_at,locks_at,economics_version,entry_count,staked_fet,source_url,approved_by)
 select ('99967000-0000-4000-8000-'||lpad((n+200)::text,12,'0'))::uuid,9996701,
 ('99967000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,100,now()-make_interval(days=>n-297),now()-make_interval(days=>n-297),now()-make_interval(days=>n-298),'legacy_paid_v1',1,100,
 'https://example.test/staff-historical','99967000-0000-4000-8000-000000000001' from generate_series(302,304)n;
select public.predict_post_entry(9996701,'99967000-0000-4000-8000-000000000005',500,'predict_welcome','staff-historical-welcome',null,'Historical financial fixture');
insert into football.predict_entries(id,pool_id,club_id,user_id,selection,stake_fet,economics_version)
 select ('99967000-0000-4000-8000-'||lpad((n+600)::text,12,'0'))::uuid,
 ('99967000-0000-4000-8000-'||lpad((n+200)::text,12,'0'))::uuid,9996701,'99967000-0000-4000-8000-000000000005','home',100,'legacy_paid_v1' from generate_series(302,304)n;
select public.predict_post_entry(9996701,user_id,-stake_fet,'predict_entry','staff-historical-entry:'||id,id,'Historical charged entry') from football.predict_entries where club_id=9996701;

create function pg_temp.staff_actor(n int,age int default 1,ttl int default 3600,service boolean default false) returns void language plpgsql as $$
declare u text:='99967000-0000-4000-8000-'||lpad(n::text,12,'0'); e bigint:=floor(extract(epoch from clock_timestamp()));
begin
 perform set_config('request.jwt.claim.sub',case when service then '' else u end,true);
 perform set_config('request.jwt.claim.role',case when service then 'service_role' else 'authenticated' end,true);
 perform set_config('request.jwt.claims',case when service then '{"role":"service_role"}' else jsonb_build_object('sub',u,'role','authenticated',
  'club_id',9996701,'aal','aal2','is_anonymous',false,'exp',e+ttl,'session_id','99967000-0000-4000-8000-'||lpad((n+550)::text,12,'0'),
  'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',e-age)))::text end,true);
end $$;

select ok(has_function_privilege('authenticated','public.admit_verified_staff_command(uuid,text,uuid,jsonb)','EXECUTE')
 and not has_function_privilege('service_role','public.admit_verified_staff_command(uuid,text,uuid,jsonb)','EXECUTE'),
 'only the actual caller JWT may create or renew assurance');
select ok(not exists(select 1 from unnest(array['verified_staff_commands','verified_staff_command_proofs'])t
 cross join unnest(array['anon','authenticated','service_role'])r where has_table_privilege(r,'public.'||t,'SELECT,INSERT,UPDATE,DELETE')),
 'no app identity can manufacture, alter, list or delete assurance rows');
select ok(not exists(select 1 from unnest(array['public.lock_verified_staff_command_resource(text,uuid)',
 'public.assert_verified_staff_actor(uuid,text)','public.consume_verified_staff_command(uuid,text,uuid,uuid,jsonb)',
 'public.finish_verified_staff_command(uuid,text,uuid,uuid,jsonb,jsonb)'])f cross join unnest(array['anon','authenticated','service_role'])r
 where has_function_privilege(r,f,'EXECUTE')),'all bridge consumers and authority helpers remain private');
select ok(not exists(select 1 from unnest(array['public.prediction_admin_settle_as_actor(uuid,integer,integer,uuid,uuid,integer,integer)',
 'public.predict_admin_settle_for_actor(uuid,uuid,uuid,text)','public.partner_prediction_pool_settle_for_actor(uuid,uuid,uuid)',
 'public.predict_admin_confirm_result_for_actor(uuid,integer,integer,text,uuid,uuid)'])f
 where not has_function_privilege('service_role',f,'EXECUTE') or has_function_privilege('authenticated',f,'EXECUTE')),
 'the exact four financial service identities and ACLs are preserved');
select ok((select count(*)=2 from pg_policy where polrelid in('public.verified_staff_commands'::regclass,'public.verified_staff_command_proofs'::regclass)
 and polname='account_lifecycle_access' and not polpermissive and polcmd='*' and polroles=array[(select oid from pg_roles where rolname='authenticated')]),
 'both private tables retain exact restrictive lifecycle denial guards');
select ok((select retained and deletion_action='r' from public.account_erasure_fk_inventory i join pg_constraint c on c.oid=i.constraint_oid
 where c.conrelid='public.verified_staff_commands'::regclass and c.confrelid='auth.users'::regclass),
 'financial actor reference is retained and catalogued');
select ok(not exists(select 1 from pg_constraint where conrelid='public.verified_staff_command_proofs'::regclass and confrelid='auth.sessions'::regclass),
 'retained proof does not prevent logout deleting the actual Auth session');

select pg_temp.staff_actor(1,1,3600,true);
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000301','{"home_score":2,"away_score":1}')$$,
 '42501','STAFF_COMMAND_CALLER_REQUIRED','service cannot fabricate a verified human admission');
set local role service_role;
select is(current_user::text,'service_role','the service boundary uses the actual application SQL role');
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000301','{"home_score":2,"away_score":1}')$$,
 '42501','permission denied for function admit_verified_staff_command','real service role lacks caller admission EXECUTE');
select throws_ok($$select public.prediction_admin_settle_as_actor('99967000-0000-4000-8000-000000000301',2,1,'99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000701')$$,
 '42501','STAFF_COMMAND_ADMISSION_REQUIRED','active global actor alone no longer authorizes fresh service effects');
reset role;
select pg_temp.staff_actor(3);
set local role authenticated;
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000301','{"home_score":2,"away_score":1}')$$,
 '42501','SETTLEMENT_GLOBAL_ADMIN_REQUIRED','club staff cannot admit a global financial command');
reset role;
select pg_temp.staff_actor(1,301);
set local role authenticated;
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000301','{"home_score":2,"away_score":1}')$$,
 '42501','STAFF_STEP_UP_REQUIRED','stale original MFA cannot create admission');
reset role;
select pg_temp.staff_actor(1);
select set_config('request.jwt.claims',jsonb_set(auth.jwt(),'{session_id}','"99967000-0000-4000-8000-000000000552"')::text,true);
set local role authenticated;
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000301','{"home_score":2,"away_score":1}')$$,
 '42501','STAFF_COMMAND_SESSION_REVOKED','a foreign valid Auth session cannot establish caller assurance');
reset role;
select pg_temp.staff_actor(1);
set local role authenticated;
select is(current_user::text,'authenticated','human admission uses the actual caller SQL role');
select is(public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000301','{"away_score":1,"home_score":2}')->>'status','admitted',
 'actual authenticated caller admits canonical fixture scores');
select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000301','{"home_score":2,"away_score":1,"ht_home_score":null,"ht_away_score":null}');
select throws_ok($$select public.prediction_admin_settle_as_actor('99967000-0000-4000-8000-000000000301',2,1,'99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000701')$$,
 '42501','permission denied for function prediction_admin_settle_as_actor','even an admitted human cannot invoke the service wrapper directly');
reset role;
select is((select count(*) from public.verified_staff_command_proofs where operation_id='99967000-0000-4000-8000-000000000701')::int,1,
 'duplicate original admission reuses the immutable proof rather than growing state');
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000301','{"home_score":3,"away_score":1}')$$,
 'P0001','STAFF_COMMAND_BINDING_MISMATCH','same operation cannot change its canonical scores');
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000307','{"home_score":2,"away_score":1}')$$,
 'P0001','STAFF_COMMAND_BINDING_MISMATCH','original operation cannot move to a different actual fixture');
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','predict_legacy_settle','99967000-0000-4000-8000-000000000502','{}')$$,
 'P0001','STAFF_COMMAND_BINDING_MISMATCH','original operation cannot move between financial engines');
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000709','fixture_settle','99967000-0000-4000-8000-000000000307','{"home_score":2,"away_score":1,"mfa_verified":true,"actor_id":"forged"}')$$,
 '22023','STAFF_COMMAND_ARGUMENTS_INVALID','caller-selected actor and MFA flags are not command facts');
select pg_temp.staff_actor(2);
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000701','fixture_settle','99967000-0000-4000-8000-000000000301','{"home_score":2,"away_score":1}')$$,
 'P0001','STAFF_COMMAND_BINDING_MISMATCH','a different global actor cannot take the original command');
select pg_temp.staff_actor(1,1,3600,true);
create temp table fixture_receipt(value jsonb); grant select,insert on fixture_receipt to service_role;
set local role service_role;
insert into fixture_receipt select public.prediction_admin_settle_as_actor('99967000-0000-4000-8000-000000000301',2,1,
 '99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000701') value;
select is(public.prediction_admin_settle_as_actor('99967000-0000-4000-8000-000000000301',2,1,'99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000701'),
 (select value from fixture_receipt),'lost fixture response replays the original durable receipt exactly');
reset role;
select is((select count(*) from public.admin_audit_log where action='prediction.global_fixture_settle' and metadata->>'operation_id'='99967000-0000-4000-8000-000000000701')::int,1,
 'fixture replay creates no second effect audit');
select throws_ok($$select public.prediction_admin_settle_as_actor('99967000-0000-4000-8000-000000000301',3,1,'99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000701')$$,
 'P0001','STAFF_COMMAND_BINDING_MISMATCH','completed fixture UUID cannot change the score');
select pg_temp.staff_actor(1);
set local role authenticated;
select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000709','predict_legacy_settle','99967000-0000-4000-8000-000000000504','{"void_reason":"Fixture delayed"}');
reset role;
select pg_temp.staff_actor(1,1,3600,true);
update auth.sessions set not_after=clock_timestamp()-interval '1 second' where id='99967000-0000-4000-8000-000000000551';
select throws_ok($$select public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000504','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000709','Fixture delayed')$$,
 '42501','STAFF_COMMAND_SESSION_REVOKED','actual session not_after overrides an unexpired original JWT');
update auth.sessions set not_after=clock_timestamp()+interval '1 hour',aal='aal1' where id='99967000-0000-4000-8000-000000000551';
select throws_ok($$select public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000504','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000709','Fixture delayed')$$,
 '42501','STAFF_COMMAND_SESSION_REVOKED','session AAL downgrade denies stale aal2 token effects');
update auth.sessions set aal='aal2' where id='99967000-0000-4000-8000-000000000551';
insert into public.account_erasure_jobs(user_id) values('99967000-0000-4000-8000-000000000001');
select throws_ok($$select public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000504','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000709','Fixture delayed')$$,
 '42501','ACCOUNT_CLOSURE_PENDING','pending account closure revokes already admitted human authority');
delete from public.account_erasure_jobs where user_id='99967000-0000-4000-8000-000000000001';
select is((select payout_fet from football.predict_entries where id='99967000-0000-4000-8000-000000000904'),0::bigint,
 'not_after, session downgrade and closure denials preserve the actual retained liability');

-- Genuine retained charged history; admission gates the actual old financial
-- engine rather than a substitute handler or synthetic receipt writer.
select pg_temp.staff_actor(1);
set local role authenticated;
select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000702','predict_legacy_confirm','99967000-0000-4000-8000-000000000502','{"home_score":2,"away_score":1,"source_url":"https://example.test/result"}');
reset role;
select pg_temp.staff_actor(1,1,3600,true);
set local role service_role;
select lives_ok($$select public.predict_admin_confirm_result_for_actor('99967000-0000-4000-8000-000000000502',2,1,'https://example.test/result','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000702')$$,
 'admitted actual historical result confirmation preserves engine behavior');
reset role;
select pg_temp.staff_actor(1,297);
set local role authenticated;
select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000703','predict_legacy_settle','99967000-0000-4000-8000-000000000502','{"void_reason":null}');
reset role;
create function pg_temp.delay_actual_payout() returns trigger language plpgsql as $$ begin
 if new.club_id=9996701 and new.entry_type='predict_payout' then perform pg_sleep(3.2); end if;
 return new; end $$;
create trigger staff_contract_actual_payout_wait before insert on public.fet_wallet_ledger_entries for each row execute function pg_temp.delay_actual_payout();
select pg_temp.staff_actor(1,1,3600,true);
set local role service_role;
select throws_ok($$select public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000502','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000703',null)$$,
 '42501','STAFF_COMMAND_ASSURANCE_EXPIRED','original MFA expiry during actual nested money write rolls back the complete engine');
reset role;
drop trigger staff_contract_actual_payout_wait on public.fet_wallet_ledger_entries;
select is((select count(*) from public.fet_wallet_ledger_entries where club_id=9996701 and entry_type='predict_payout')::int,0,
 'post-effect assurance denial leaves no wallet payout');
select is((select points from public.fan_memberships where club_id=9996701 and user_id='99967000-0000-4000-8000-000000000005'),200,
 'failed financial attempt preserves original charged wallet balance');
select ok((select result is null from public.verified_staff_commands where operation_id='99967000-0000-4000-8000-000000000703'),
 'expired attempt never claims a completed command');
select pg_temp.staff_actor(1);
set local role authenticated;
select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000703','predict_legacy_settle','99967000-0000-4000-8000-000000000502','{"void_reason":null}');
reset role;
select is((select count(*) from public.verified_staff_command_proofs where operation_id='99967000-0000-4000-8000-000000000703')::int,2,
 'explicit fresh authentication appends evidence under the original immutable operation');
select pg_temp.staff_actor(1,1,3600,true);
create temp table paid_receipt(value jsonb); grant select,insert on paid_receipt to service_role;
set local role service_role;
insert into paid_receipt select public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000502',
 '99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000703',null) value;
reset role;
select is((select payout_fet from football.predict_entries where id='99967000-0000-4000-8000-000000000902'),100::bigint,'fresh original-command retry preserves the actual old paid amount');
select is(public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000502','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000703',null),
 (select value from paid_receipt),'paid lost-response replay returns the same receipt');
select is((select count(*) from public.fet_wallet_ledger_entries where club_id=9996701 and entry_type='predict_payout')::int,1,'paid replay cannot credit twice');

select pg_temp.staff_actor(1);
set local role authenticated;
select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000704','predict_legacy_settle','99967000-0000-4000-8000-000000000503','{"void_reason":"Fixture cancelled"}');
reset role;
select pg_temp.staff_actor(1,1,3600,true);
delete from auth.sessions where id='99967000-0000-4000-8000-000000000551';
set local role service_role;
select throws_ok($$select public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000503','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000704','Fixture cancelled')$$,
 '42501','STAFF_COMMAND_SESSION_REVOKED','actual Auth logout after admission denies fresh retained-liability refunds');
reset role;
select is((select payout_fet from football.predict_entries where id='99967000-0000-4000-8000-000000000903'),0::bigint,'session revocation preserves original financial entry');
select is(public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000502','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000703',null),
 (select value from paid_receipt),'completed read-only receipt survives session removal without rerunning effects');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('99967000-0000-4000-8000-000000000551','99967000-0000-4000-8000-000000000001',now(),now(),'aal2',now()+interval '1 hour');
select pg_temp.staff_actor(1);
set local role authenticated;
select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000704','predict_legacy_settle','99967000-0000-4000-8000-000000000503','{"void_reason":"Fixture cancelled"}');
reset role;
select pg_temp.staff_actor(1,1,3600,true);
update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='99967000-0000-4000-8000-000000000001';
set local role service_role;
select throws_ok($$select public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000503','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000704','Fixture cancelled')$$,
 '42501','PREDICT_GLOBAL_ADMIN_REQUIRED','current grant revocation wins over a fresh stored proof');
reset role;
update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='99967000-0000-4000-8000-000000000001';
set local role service_role;
select lives_ok($$select public.predict_admin_settle_for_actor('99967000-0000-4000-8000-000000000503','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000704','Fixture cancelled')$$,
 'restored current actor and admitted session refund the real old liability');
reset role;
select is((select payout_fet from football.predict_entries where id='99967000-0000-4000-8000-000000000903'),100::bigint,'actual retained liability refund amount is unchanged');

insert into football.partner_prediction_pools(id,club_id,partner_id,fixture_id,title,partner_stake_fet,fan_entry_fet,lock_at,total_entries,total_fan_entry_fet,created_by) values
 ('99967000-0000-4000-8000-000000000801',9996701,'99967000-0000-4000-8000-000000000100','99967000-0000-4000-8000-000000000305','Staff retained partner',200,100,now()-interval '1 day',1,100,'99967000-0000-4000-8000-000000000001');
insert into football.partner_prediction_pool_entries(id,pool_id,club_id,partner_id,fixture_id,user_id,selected_outcome,fan_entry_fet) values
 ('99967000-0000-4000-8000-000000000802','99967000-0000-4000-8000-000000000801',9996701,'99967000-0000-4000-8000-000000000100','99967000-0000-4000-8000-000000000305','99967000-0000-4000-8000-000000000005','home_win',100);
select public.predict_post_entry(9996701,'99967000-0000-4000-8000-000000000005',-100,'partner_pool_entry','staff-partner-entry','99967000-0000-4000-8000-000000000802','Historical partner charge');
select pg_temp.staff_actor(1);
set local role authenticated;
select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000705','partner_legacy_settle','99967000-0000-4000-8000-000000000801','{}');
reset role;
select pg_temp.staff_actor(1,1,3600,true);
set local role service_role;
select lives_ok($$select public.partner_prediction_pool_settle_for_actor('99967000-0000-4000-8000-000000000801','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000705')$$,
 'the fourth actual financial wrapper consumes real human admission');
reset role;
select is((select payout_fet from football.partner_prediction_pool_entries where id='99967000-0000-4000-8000-000000000802'),300,'old partner sponsor plus fan amount is preserved');
select public.partner_prediction_pool_settle_for_actor('99967000-0000-4000-8000-000000000801','99967000-0000-4000-8000-000000000001','99967000-0000-4000-8000-000000000705');
select is((select count(*) from public.fet_wallet_ledger_entries where club_id=9996701 and entry_type='partner_pool_payout')::int,1,'partner replay cannot credit twice');

select throws_ok($$update public.verified_staff_commands set arguments='{"void_reason":"Forged overwrite"}' where operation_id='99967000-0000-4000-8000-000000000704'$$,
 'P0001','STAFF_COMMAND_IMMUTABLE','even owner maintenance cannot silently rewrite admitted financial facts');
select throws_ok($$update public.verified_staff_command_proofs set mfa_verified_at=extract(epoch from clock_timestamp())::bigint$$,
 'P0001','STAFF_COMMAND_IMMUTABLE','recorded verification attempts are append-only');
select pg_temp.staff_actor(1);
do $$ begin for i in 1..32 loop perform pg_temp.staff_actor(1,1,3600+i);
 perform public.admit_verified_staff_command('99967000-0000-4000-8000-000000000799','fixture_settle','99967000-0000-4000-8000-000000000308','{"home_score":2,"away_score":1}'); end loop; end $$;
select is((select count(*) from public.verified_staff_command_proofs where operation_id='99967000-0000-4000-8000-000000000799')::int,32,'pathological distinct verification growth is bounded');
select pg_temp.staff_actor(1,1,3700);
select throws_ok($$select public.admit_verified_staff_command('99967000-0000-4000-8000-000000000799','fixture_settle','99967000-0000-4000-8000-000000000308','{"home_score":2,"away_score":1}')$$,
 '54000','STAFF_COMMAND_PROOF_LIMIT','a new proof cannot bypass the per-command state bound');
select * from finish();
rollback;

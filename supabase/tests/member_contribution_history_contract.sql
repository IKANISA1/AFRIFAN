-- Exact totals, stable pagination, privacy and strict intent-route validation.
begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
insert into public.african_football_clubs(id,club_name,country_name,club_slug,momo_ussd_template) overriding system value values
 (9959001,'History Club','Rwanda','history-club','*182*8*1*{momo}*{amount}#'),
 (9959002,'Foreign History Club','Rwanda','history-foreign','*182*8*1*{momo}*{amount}#');
insert into public.partners(id,name,slug,is_active,momo_code) values
 ('99590000-0000-4000-8000-000000000100','History Club','history-club',true,'123456');
insert into auth.users(id,aud,role,is_anonymous) values
 ('99590000-0000-4000-8000-000000000001','authenticated','authenticated',false),
 ('99590000-0000-4000-8000-000000000002','authenticated','authenticated',false);
insert into public.users(id,phone,full_name) values
 ('99590000-0000-4000-8000-000000000001','+250799590001','History Owner'),
 ('99590000-0000-4000-8000-000000000002','+250799590002','Other Owner');
insert into public.profiles(id,club_id) values
 ('99590000-0000-4000-8000-000000000001',9959001),
 ('99590000-0000-4000-8000-000000000002',9959001);
insert into public.fan_memberships(user_id,partner_id,club_id,tier,status) values
 ('99590000-0000-4000-8000-000000000001','99590000-0000-4000-8000-000000000100',9959001,'fan','active');
insert into public.initiatives(id,partner_id,club_id,title,category) values
 ('99590000-0000-4000-8000-000000000200','99590000-0000-4000-8000-000000000100',9959001,'History fund','membership'),
 ('99590000-0000-4000-8000-000000000201','99590000-0000-4000-8000-000000000100',9959002,'Foreign fund','membership');
-- Identical timestamps exercise the UUID tie-breaker; dates avoid intent throttling.
insert into public.initiative_contributions(id,initiative_id,user_id,club_id,amount,status,momo_reference,created_at)
select ('99590000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '99590000-0000-4000-8000-000000000200','99590000-0000-4000-8000-000000000001',9959001,
 case when n<=421 then 1000 else 9000 end,
 case when n<=421 then 'confirmed' when n=422 then 'pending' when n=423 then 'failed' else 'cancelled' end,
 'QA-HISTORY-'||n,now()-interval '2 days'
from generate_series(401,424) n;
insert into public.initiative_contributions(initiative_id,user_id,club_id,amount,status,momo_reference) values
 ('99590000-0000-4000-8000-000000000200','99590000-0000-4000-8000-000000000002',9959001,777777,'confirmed','OTHER-OWNER'),
 ('99590000-0000-4000-8000-000000000201','99590000-0000-4000-8000-000000000001',9959002,888888,'confirmed','OTHER-CLUB');
select ok(not (select prosecdef from pg_proc where oid='public.member_contribution_history(timestamptz,uuid)'::regprocedure),'history executes with caller privileges');
select is((select provolatile::text from pg_proc where oid='public.member_contribution_history(timestamptz,uuid)'::regprocedure),'s','history uses one stable statement snapshot');
select ok(not has_function_privilege('anon','public.member_contribution_history(timestamptz,uuid)','EXECUTE'),'anonymous history execution denied');
select set_config('request.jwt.claim.sub','99590000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"99590000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9959001"}',true);
set local role authenticated;
select is(public.member_contribution_history()->>'confirmed_total','21000','complete confirmed total excludes pending/failed/cancelled and foreign rows');
select is(jsonb_array_length(public.member_contribution_history()->'entries'),20,'first page remains bounded');
select ok(public.member_contribution_history()->'next_cursor' <> 'null'::jsonb,'first page exposes an older-history cursor');
select ok(not exists(select 1 from jsonb_array_elements(public.member_contribution_history()->'entries') e where e->>'momo_reference' in ('OTHER-OWNER','OTHER-CLUB')),'page has no other-user/club private receipt');
select is(public.member_contribution_history()->'entries'->0->>'id','99590000-0000-4000-8000-000000000424','equal timestamps sort by UUID descending');
select is(jsonb_array_length(public.member_contribution_history((public.member_contribution_history()->'next_cursor'->>'created_at')::timestamptz,(public.member_contribution_history()->'next_cursor'->>'id')::uuid)->'entries'),4,'older page returns every remaining row once');
select is(public.member_contribution_history((public.member_contribution_history()->'next_cursor'->>'created_at')::timestamptz,(public.member_contribution_history()->'next_cursor'->>'id')::uuid)->>'confirmed_total','21000','older page retains full confirmed total');
select is(public.member_contribution_history((public.member_contribution_history()->'next_cursor'->>'created_at')::timestamptz,(public.member_contribution_history()->'next_cursor'->>'id')::uuid)->'next_cursor','null'::jsonb,'last page terminates');
select throws_ok($$select public.member_contribution_history(now(),null)$$,'22023','Both history cursor fields are required.','partial cursor is rejected');
select throws_ok($$select public.member_contribution_history(null,'99590000-0000-4000-8000-000000000424')$$,'22023','Both history cursor fields are required.','inverse partial cursor is rejected');
select lives_ok($$select public.create_member_contribution_intent('99590000-0000-4000-8000-000000000200',5000)$$,'valid official route creates a pending intent');
select is((select status from public.initiative_contributions where amount=5000),'pending','intent remains unconfirmed');
select is(public.member_contribution_history()->>'confirmed_total','21000','pending intent does not change confirmed total');
select lives_ok($$select public.create_member_contribution_intent('99590000-0000-4000-8000-000000000200',5000)$$,'unchanged retry succeeds');
select is((select count(*)::int from public.initiative_contributions where amount=5000),1,'unchanged retry reuses one pending intent');
reset role;
update public.african_football_clubs set momo_ussd_template='182*8*1*{momo}*{amount}#' where id=9959001;
set local role authenticated;
select throws_ok($$select public.create_member_contribution_intent('99590000-0000-4000-8000-000000000200',6000)$$,'P0001','The official Rayon Sports MoMo route is invalid.','route missing leading asterisk is rejected');
select is((select count(*)::int from public.initiative_contributions where amount=6000),0,'invalid route creates no pending row');
reset role;
-- A total larger than an integer is returned exactly as a decimal string.
update public.initiative_contributions set amount=2147483647 where id in ('99590000-0000-4000-8000-000000000401','99590000-0000-4000-8000-000000000402');
set local role authenticated;
select is(public.member_contribution_history()->>'confirmed_total','4294986294','sum uses bigint and serializes exact digits');
reset role;
insert into public.initiative_contributions(initiative_id,user_id,club_id,amount,status,created_at)
select '99590000-0000-4000-8000-000000000200','99590000-0000-4000-8000-000000000001',9959001,1,'confirmed',now()-interval '10 days'
from generate_series(1,1005);
set local role authenticated;
select is(public.member_contribution_history()->>'confirmed_total','4294987299','total is not capped at the REST maximum of 1000 rows');
select is(jsonb_array_length(public.member_contribution_history()->'entries'),20,'large history still returns a bounded page');
select ok(not (public.member_contribution_history()->'entries'->0 ? 'supporter_name'),'private columns are absent from the history projection');
reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{}',true);
set local role authenticated;
select throws_ok($$select public.member_contribution_history()$$,'42501','Authentication is required.','authenticated role without an actual subject is rejected');
reset role;
select * from finish();
rollback;

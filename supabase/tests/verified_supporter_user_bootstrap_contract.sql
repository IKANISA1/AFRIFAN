begin;
create extension if not exists pgtap with schema extensions;
select plan(17);
insert into public.african_football_clubs(id,club_name,country_name,club_slug)
overriding system value values(9988001,'Onboarding Contract Club','Rwanda','onboarding-contract-club');
insert into public.partners(id,name,slug,is_active) values
 ('99880000-0000-4000-8000-000000000100','Onboarding Contract Operator','onboarding-contract-operator',true);
insert into public.membership_packages(partner_id,club_id,tier,title,subtitle) values
 ('99880000-0000-4000-8000-000000000100',9988001,'fan','Synthetic package','Contract fixture');
insert into auth.users(id,aud,role,is_anonymous,raw_user_meta_data) values
 ('99880000-0000-4000-8000-000000000001','authenticated','authenticated',false,'{"phone":"+250799880099","is_admin":true}');
select set_config('request.jwt.claim.sub','99880000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"99880000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9988001"}',true);
set local role authenticated;
select public.bootstrap_supporter_profile(9988001,'Unverified supporter','RW','en',null);
reset role;
select is((select count(*)::integer from public.users where id='99880000-0000-4000-8000-000000000001'),0,
 'user-editable phone metadata does not create a verified application identity');
update auth.users set phone='+250799880001',phone_confirmed_at=now()
 where id='99880000-0000-4000-8000-000000000001';
select is((select count(*)::integer from public.users where id='99880000-0000-4000-8000-000000000001'),1,
 'server phone confirmation bridges an already-created profile');
select is((select phone from public.users where id='99880000-0000-4000-8000-000000000001'),'+250799880001',
 'only the confirmed Auth phone is copied');
select is((select public_user_id from public.users where id='99880000-0000-4000-8000-000000000001'),
 (select public_user_id from public.profiles where id='99880000-0000-4000-8000-000000000001'),
 'the new operational record preserves the supporter public identity');
select is((select is_admin from public.users where id='99880000-0000-4000-8000-000000000001'),false,
 'client metadata cannot grant an administrative role');
set local role authenticated;
select lives_ok($$select * from public.fet_get_wallet(9988001)$$,
 'a verified bootstrapped supporter can read the wallet without manual user insertion');
select results_eq($$select balance from public.fet_get_wallet(9988001)$$,array[0],
 'the initial wallet is authoritative and starts at zero');
update public.profiles set display_name='Updated supporter' where id=auth.uid();
reset role;
select is((select full_name from public.users where id='99880000-0000-4000-8000-000000000001'),'Updated supporter',
 'a permitted profile name change reaches its corresponding operational record');
select is((select count(*)::integer from public.users where id='99880000-0000-4000-8000-000000000001'),1,
 'repeated synchronization does not duplicate the user');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
update public.users set is_admin=true where id='99880000-0000-4000-8000-000000000001';
reset role;
select set_config('request.jwt.claims','{"sub":"99880000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9988001"}',true);
update public.profiles set display_name='Later supporter' where id='99880000-0000-4000-8000-000000000001';
select is((select is_admin from public.users where id='99880000-0000-4000-8000-000000000001'),true,
 'synchronization preserves separately controlled existing privileges');
update auth.users set phone='+250799880011' where id='99880000-0000-4000-8000-000000000001';
select is((select phone from public.users where id='99880000-0000-4000-8000-000000000001'),'+250799880011',
 'a trusted verified Auth phone change updates the same application identity');
select is((select count(*)::integer from public.fan_memberships where user_id='99880000-0000-4000-8000-000000000001'),1,
 'a phone change retains the existing wallet membership');
insert into auth.users(id,aud,role,is_anonymous,phone,phone_confirmed_at) values
 ('99880000-0000-4000-8000-000000000002','authenticated','authenticated',false,'+250799880002',now());
insert into public.profiles(id,club_id,display_name) values
 ('99880000-0000-4000-8000-000000000002',9988001,'Verified first');
select is((select count(*)::integer from public.users where id='99880000-0000-4000-8000-000000000002'),1,
 'profile creation also bridges a phone verified before profile bootstrap');
select ok(coalesce((select bool_and(not has_function_privilege(role,signature,'EXECUTE'))
 from unnest(array['anon','authenticated','service_role']) role
 cross join unnest(array[to_regprocedure('public.sync_verified_supporter_user(uuid)'),
 to_regprocedure('public.sync_verified_supporter_user_from_auth()'),
 to_regprocedure('public.sync_verified_supporter_user_from_profile()')]) signature),false)
 and to_regprocedure('public.sync_verified_supporter_user(uuid)') is not null,
 'API roles cannot directly call identity synchronization helpers');
select ok((select count(*)=3 from pg_proc where oid in
 (to_regprocedure('public.sync_verified_supporter_user(uuid)'),to_regprocedure('public.sync_verified_supporter_user_from_auth()'),
 to_regprocedure('public.sync_verified_supporter_user_from_profile()')) and prosecdef and proconfig=array['search_path=""']),
 'all synchronization functions use a fixed empty search path');
delete from auth.users where id='99880000-0000-4000-8000-000000000001';
select is((select count(*)::integer from public.users where id='99880000-0000-4000-8000-000000000001'),0,
 'Auth deletion cascades to the operational identity');
insert into auth.users(id,aud,role,is_anonymous,phone,phone_confirmed_at) values
 ('99880000-0000-4000-8000-000000000003','authenticated','authenticated',false,'+250799880003',now());
insert into public.users(id,phone,full_name) values
 ('99880000-0000-4000-8000-000000000003','+250799880003','Existing supporter');
insert into public.profiles(id,club_id) values
 ('99880000-0000-4000-8000-000000000003',9988001);
select is((select full_name from public.users where id='99880000-0000-4000-8000-000000000003'),'Existing supporter',
 'a profile without a name does not erase an existing operational name');
select * from finish();
rollback;

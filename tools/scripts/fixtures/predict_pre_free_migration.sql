-- Synthetic history created by the actual paid RPCs BEFORE the free forward migration.
-- Distinct996800 namespace; no provider calls or existing fixture collisions.
begin;
set search_path = public, extensions;

insert into public.african_football_clubs(id,club_name,country_name,club_slug) overriding system value values
 (9968001,'Migration Paid History','Rwanda','migration-paid-history'),(9968002,'Migration Other Club','Rwanda','migration-other-history');
insert into public.partners(id,name,slug,is_active) values
 ('99680000-0000-4000-8000-000000000100','Migration Paid History','migration-paid-history',true),
 ('99680000-0000-4000-8000-000000000101','Migration Other Club','migration-other-history',true);
insert into public.membership_packages(partner_id,club_id,tier,title,subtitle,annual_price) values
 ('99680000-0000-4000-8000-000000000100',9968001,'fan','Test package','Test only',1000),
 ('99680000-0000-4000-8000-000000000101',9968002,'fan','Other test package','Test only',1000);
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous)
 select ('99680000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',
 case when n <> 7 then now() end,n=8 from generate_series(1,8) n;
insert into public.users(id,phone,full_name,public_user_id)
 select ('99680000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+25079968000'||n,'Synthetic Predict '||n,(968000+n)::text from generate_series(1,8) n;
insert into public.profiles(id,club_id)
 select ('99680000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,case when n=6 then 9968002 else 9968001 end from generate_series(1,8) n;
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99680000-0000-4000-8000-000000000005','club_admin',9968001);
insert into football.competitions(id,slug,name,short_name) values ('99680000-0000-4000-8000-000000000200','migration-paid-snapshot','Test League','Test');
insert into football.seasons(id,competition_id,slug,label) values
 ('99680000-0000-4000-8000-000000000201','99680000-0000-4000-8000-000000000200','migration-paid-season','2026');
insert into football.teams(id,name,crest_url) values
 ('99680000-0000-4000-8000-000000000210','Home Test','https://example.com/home.png'),
 ('99680000-0000-4000-8000-000000000211','Away Test','https://example.com/away.png');
insert into football.fixtures(id,competition_id,season_id,home_team_id,away_team_id,kickoff_at)
 select ('99680000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'99680000-0000-4000-8000-000000000200',
 '99680000-0000-4000-8000-000000000201','99680000-0000-4000-8000-000000000210','99680000-0000-4000-8000-000000000211',now()+make_interval(days=>n-300) from generate_series(301,308)n;

select set_config('request.jwt.claim.sub','99680000-0000-4000-8000-000000000005',true); select set_config('request.jwt.claims','{"sub":"99680000-0000-4000-8000-000000000005","role":"authenticated"}',true);
select public.predict_admin_settings(9968001,true,100);
select public.predict_admin_prepare(9968001,'99680000-0000-4000-8000-000000000301','https://example.com/pre-forward-fixture');
select public.predict_admin_prepare(9968001,'99680000-0000-4000-8000-000000000302','https://example.com/pre-forward-fixture');
select public.predict_admin_prepare(9968001,'99680000-0000-4000-8000-000000000303','https://example.com/pre-forward-fixture');
select set_config('request.jwt.claim.sub','99680000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"99680000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.predict_place(9968001,'99680000-0000-4000-8000-000000000301','home');
select set_config('request.jwt.claim.sub','99680000-0000-4000-8000-000000000002',true); select set_config('request.jwt.claims','{"sub":"99680000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select public.predict_place(9968001,'99680000-0000-4000-8000-000000000301','away');
select set_config('request.jwt.claim.sub','99680000-0000-4000-8000-000000000001',true); select set_config('request.jwt.claims','{"sub":"99680000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select public.predict_place(9968001,'99680000-0000-4000-8000-000000000302','home');
select set_config('request.jwt.claim.sub','99680000-0000-4000-8000-000000000002',true); select set_config('request.jwt.claims','{"sub":"99680000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select public.predict_place(9968001,'99680000-0000-4000-8000-000000000302','home');
select set_config('request.jwt.claim.sub','99680000-0000-4000-8000-000000000003',true); select set_config('request.jwt.claims','{"sub":"99680000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select public.predict_place(9968001,'99680000-0000-4000-8000-000000000302','away');
select set_config('request.jwt.claim.sub','99680000-0000-4000-8000-000000000003',true); select set_config('request.jwt.claims','{"sub":"99680000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select public.predict_place(9968001,'99680000-0000-4000-8000-000000000303','draw');
select set_config('request.jwt.claim.sub','99680000-0000-4000-8000-000000000005',true); select set_config('request.jwt.claims','{"sub":"99680000-0000-4000-8000-000000000005","role":"authenticated"}',true);
update football.fixtures set kickoff_at=now()-interval '1 day',status='finished',home_score=2,away_score=1 where id='99680000-0000-4000-8000-000000000302';
select public.predict_admin_confirm_result(id,2,1,'https://example.com/pre-forward-official-result') from football.predict_pools where fixture_id='99680000-0000-4000-8000-000000000302';
select public.predict_admin_settle(id) from football.predict_pools where fixture_id='99680000-0000-4000-8000-000000000302';
select public.predict_admin_settle(id,'Synthetic pre-forward void') from football.predict_pools where fixture_id='99680000-0000-4000-8000-000000000303';
insert into public.admin_role_assignments(user_id,role) values ('99680000-0000-4000-8000-000000000005','admin');
commit;

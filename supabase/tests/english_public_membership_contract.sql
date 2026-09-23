-- Execute only against an isolated migrated database. Every record is synthetic.
begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
insert into public.african_football_clubs(id,club_name,country_name,club_slug) overriding system value values
 (9947001,'Content Test Club','Rwanda','content-test-club'),(9947002,'Other Content Club','Rwanda','content-other-club');
insert into public.partners(id,name,slug,is_active) values
 ('99470000-0000-4000-8000-000000000100','Content Test Partner','content-test-partner',true);
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous) values
 ('99470000-0000-4000-8000-000000000001','authenticated','authenticated',now(),false);
insert into public.users(id,phone,full_name) values
 ('99470000-0000-4000-8000-000000000001','+250799470001','Synthetic Supporter');
insert into public.profiles(id,club_id,language_code) values
 ('99470000-0000-4000-8000-000000000001',9947001,'retired');
select is((select language_code from public.profiles where club_id=9947001),'en','profile writes are normalized to English');
update public.african_football_clubs set default_language='retired',supported_languages=array['retired'] where id=9947001;
select is((select supported_languages from public.african_football_clubs where id=9947001),array['en'],'club updates cannot restore a retired language');
select ok(not has_function_privilege('anon','public.membership_qualification_v1(bigint)','EXECUTE'),'guest cannot read a private qualification');
select ok(not has_table_privilege('authenticated','public.membership_qualification_tiers','INSERT'),'supporter cannot change qualification thresholds');
select ok(not has_table_privilege('authenticated','public.club_public_links','INSERT'),'supporter cannot publish entity mappings');
select set_config('request.jwt.claim.sub','99470000-0000-4000-8000-000000000001',true);
set local role authenticated;
select is(public.membership_qualification_v1(9947001)->>'available','false','unpublished programme is explicitly unavailable');
select throws_ok($$select public.membership_qualification_v1(9947002)$$,'42501','Membership access denied','cross-club qualification is denied');
reset role;
insert into public.initiatives(id,partner_id,club_id,title,category) values
 ('99470000-0000-4000-8000-000000000200','99470000-0000-4000-8000-000000000100',9947001,'Membership fund','membership'),
 ('99470000-0000-4000-8000-000000000201','99470000-0000-4000-8000-000000000100',9947001,'Unrelated project','project');
insert into public.club_membership_programmes(club_id,is_published) values(9947001,true);
insert into public.membership_qualifying_initiatives values(9947001,'99470000-0000-4000-8000-000000000200');
insert into public.membership_qualification_tiers(club_id,tier,title,threshold_rwf,is_published) values
 (9947001,'bronze','Bronze',100000,true),(9947001,'silver','Silver',400000,true);
insert into public.initiative_contributions(id,initiative_id,user_id,club_id,amount,status,confirmed_at,is_mock) values
 ('99470000-0000-4000-8000-000000000301','99470000-0000-4000-8000-000000000200','99470000-0000-4000-8000-000000000001',9947001,90000,'confirmed',now()-interval '1 month',false),
 ('99470000-0000-4000-8000-000000000302','99470000-0000-4000-8000-000000000200','99470000-0000-4000-8000-000000000001',9947001,20000,'pending',null,false),
 ('99470000-0000-4000-8000-000000000303','99470000-0000-4000-8000-000000000200','99470000-0000-4000-8000-000000000001',9947001,800000,'confirmed',now()-interval '14 months',false),
 ('99470000-0000-4000-8000-000000000304','99470000-0000-4000-8000-000000000201','99470000-0000-4000-8000-000000000001',9947001,800000,'confirmed',now(),false),
 ('99470000-0000-4000-8000-000000000305','99470000-0000-4000-8000-000000000200','99470000-0000-4000-8000-000000000001',9947001,800000,'confirmed',now()+interval '1 day',false),
 ('99470000-0000-4000-8000-000000000306','99470000-0000-4000-8000-000000000200','99470000-0000-4000-8000-000000000001',9947001,800000,'confirmed',now(),true);
set local role authenticated;
select is((public.membership_qualification_v1(9947001)->>'confirmed_total_rwf')::int,90000,'only current confirmed designated contributions qualify');
select is((public.membership_qualification_v1(9947001)->>'remaining_rwf')::int,10000,'remaining contribution is derived from the published threshold');
select is(public.membership_qualification_v1(9947001)->>'tier',null::text,'no unearned tier is invented below the minimum');
reset role;
insert into public.fan_memberships(user_id,partner_id,club_id,tier,points) values
 ('99470000-0000-4000-8000-000000000001','99470000-0000-4000-8000-000000000100',9947001,'gold',999999);
set local role authenticated;
select is(public.membership_qualification_v1(9947001)->>'tier',null::text,'a large FET balance and legacy Gold tier cannot qualify membership');
reset role;
update public.initiative_contributions set status='confirmed',confirmed_at=now() where id='99470000-0000-4000-8000-000000000302';
set local role authenticated;
select is(public.membership_qualification_v1(9947001)->>'tier','bronze','confirmed contribution crosses the threshold');
reset role;
update public.initiative_contributions set status='cancelled' where id='99470000-0000-4000-8000-000000000301';
set local role authenticated;
select is((public.membership_qualification_v1(9947001)->>'confirmed_total_rwf')::int,20000,'cancelled contributions stop qualifying immediately');
reset role;
insert into public.news_articles(id,club_id,title,body,is_published) values
 ('99470000-0000-4000-8000-000000000400',9947001,'Synthetic article','Test content',false);
insert into public.club_public_links(club_id,source_path,native_path,published_at) values
 (9947001,'/news/story','/club/news/99470000-0000-4000-8000-000000000400',now()),
 (9947002,'/news/story','/club/news/99470000-0000-4000-8000-000000000400',now());
set local role anon;
select is(public.resolve_club_public_link_v1(9947001,'/news/story'),null::text,'mapping does not publish an unpublished article');
reset role;
update public.news_articles set is_published=true where id='99470000-0000-4000-8000-000000000400';
set local role anon;
select is(public.resolve_club_public_link_v1(9947001,'/news/story'),'/club/news/99470000-0000-4000-8000-000000000400','published mapping resolves to the exact scoped entity');
select is(public.resolve_club_public_link_v1(9947002,'/news/story'),null::text,'a wrong-club mapping cannot expose the record');
reset role;
update public.news_articles set is_published=false where id='99470000-0000-4000-8000-000000000400';
set local role anon;
select is(public.resolve_club_public_link_v1(9947001,'/news/story'),null::text,'revoked publication invalidates the link');
select is(public.club_public_content_manifest_v1(9947001)->>'language','en','manifest declares English');
reset role;
select * from finish();
rollback;

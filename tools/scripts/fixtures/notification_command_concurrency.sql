-- Independent synthetic namespace for actual SQL29 command/lease races.
-- Auth sessions are real rows in the pinned vendor schema; no provider runs.
begin;
set local request.jwt.claim.sub='';
set local request.jwt.claim.role='service_role';
set local request.jwt.claims='{"role":"service_role"}';
insert into public.african_football_clubs(id,club_name,country_name,country_iso_code,club_slug)
 overriding system value values
 (9996941,'Notification concurrency QA','Rwanda','RW','notification-concurrency-qa'),
 (9996942,'Notification cross-recipient A','Rwanda','RW','notification-cross-recipient-a'),
 (9996943,'Notification cross-recipient B','Rwanda','RW','notification-cross-recipient-b');
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous)
 select ('99969400-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'authenticated','authenticated',clock_timestamp(),false from generate_series(1,3)n;
insert into public.users(id,phone,full_name)
 select ('99969400-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '+25079996940'||n,'Synthetic notification concurrency '||n from generate_series(1,3)n;
insert into public.profiles(id,club_id)
 select ('99969400-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,case when n=3 then 9996942 else 9996941 end from generate_series(1,3)n;
insert into public.admin_role_assignments(user_id,role,club_id)
 values('99969400-0000-4000-8000-000000000001','super_admin',null),
 ('99969400-0000-4000-8000-000000000003','super_admin',null);
insert into public.user_notification_settings(user_id,club_id,push_enabled)
 values('99969400-0000-4000-8000-000000000002',9996941,true),
 ('99969400-0000-4000-8000-000000000003',9996942,true),
 ('99969400-0000-4000-8000-000000000001',9996943,true);
insert into public.user_fcm_tokens(id,user_id,club_id,token) values
 ('99969400-0000-4000-8000-000000000601','99969400-0000-4000-8000-000000000002',9996941,'synthetic-notification-race-device-a'),
 ('99969400-0000-4000-8000-000000000602','99969400-0000-4000-8000-000000000002',9996941,'synthetic-notification-race-device-b'),
 ('99969400-0000-4000-8000-000000000603','99969400-0000-4000-8000-000000000003',9996942,'synthetic-notification-cross-recipient-a'),
 ('99969400-0000-4000-8000-000000000604','99969400-0000-4000-8000-000000000001',9996943,'synthetic-notification-cross-recipient-b');
commit;

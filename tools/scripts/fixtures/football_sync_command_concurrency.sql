-- Independent genuine Auth/session namespace. No provider invocation.
begin;
set local request.jwt.claims='{"role":"service_role"}';set local request.jwt.claim.role='service_role';set local request.jwt.claim.sub='';
insert into public.african_football_clubs(id,club_name,country_name,country_iso_code,club_slug) overriding system value values(9996981,'Football Command Concurrency QA','Rwanda','RW','football-command-concurrency-qa');
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous) values('99969800-0000-4000-8000-000000000001','authenticated','authenticated',clock_timestamp(),false);
insert into public.users(id,phone,full_name) values('99969800-0000-4000-8000-000000000001','+250799969801','Synthetic football concurrency operator');
insert into public.profiles(id,club_id) values('99969800-0000-4000-8000-000000000001',9996981);
insert into public.admin_role_assignments(user_id,role,club_id) values('99969800-0000-4000-8000-000000000001','super_admin',null);
insert into football.competitions(id,slug,name,short_name,external_provider,external_competition_id) values('99969800-0000-4000-8000-000000000610','football-concurrency-test','Football Concurrency Test','FCT','api-football','199698');
insert into public.football_sync_config(id,competition_id,external_league_id,league_name,season_year) values('99969800-0000-4000-8000-000000000601','99969800-0000-4000-8000-000000000610','199698','Synthetic concurrency league',2026);
insert into football.teams(id,name,external_provider,external_team_id,crest_url) values
 ('99969800-0000-4000-8000-000000000620','Synthetic upload-wait team','api-football','199698','https://media.api-sports.io/football/teams/199698.png'),
 ('99969800-0000-4000-8000-000000000621','Synthetic readback-wait team','api-football','199699','https://media.api-sports.io/football/teams/199699.png'),
 ('99969800-0000-4000-8000-000000000622','Synthetic Storage overlap team','api-football','199700','https://media.api-sports.io/football/teams/199700.png');
insert into storage.buckets(id,name,public) values('football-assets','football-assets',true) on conflict(id) do nothing;
insert into public.fet_events(id,user_id,club_id,event_type,fet_awarded,metadata) values('99969800-0000-4000-8000-000000000650','99969800-0000-4000-8000-000000000001',9996981,'prediction_win',3,'{"source":"synthetic-football-compat-wait"}');
commit;

-- Synthetic identities in the actual vendor Auth/session and canonical app
-- schema. SQL admission, rather than fixture-written proof JSON, supplies each
-- immutable human proof. No Google call or hosted Storage ACK is represented.
set request.jwt.claim.sub='';
set request.jwt.claims='{"role":"service_role"}';
insert into public.african_football_clubs(id,club_name,country_name,country_iso_code,club_slug,is_active)
 overriding system value values(9996741,'Generation Wait QA','Rwanda','RW','generation-wait-qa',true);
insert into auth.users(id,aud,role,is_anonymous)
 select ('99967400-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',false
 from generate_series(1,12)n;
insert into public.users(id,phone,full_name)
 select ('99967400-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+250799674'||lpad(n::text,3,'0'),'Synthetic generation waiter '||n
 from generate_series(1,12)n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('99967400-0000-4000-8000-'||lpad((n+950)::text,12,'0'))::uuid,
 ('99967400-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour'
 from generate_series(1,12)n;
insert into public.admin_role_assignments(user_id,role,club_id)
 select ('99967400-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'admin',null
 from generate_series(1,12)n;
insert into public.news_articles(id,club_id,title)
 select ('99967400-0000-4000-8000-'||lpad((n+500)::text,12,'0'))::uuid,9996741,'Synthetic generation target '||n
 from generate_series(1,3)n;

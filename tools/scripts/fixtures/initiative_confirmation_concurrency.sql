-- Synthetic Predict actors already exist in the owned disposable database.
-- Separate partner makes reward assertions independent of earlier wallet work.
insert into public.partners(id,name,slug,is_active) values
 ('99460000-0000-4000-8000-000000000800','Contribution race QA','contribution-race-qa',true);
insert into public.initiatives(id,partner_id,club_id,title,category) values
 ('99460000-0000-4000-8000-000000000801','99460000-0000-4000-8000-000000000800',9946001,'Contribution race QA','club');
insert into public.initiative_contributions(id,initiative_id,user_id,club_id,amount,status,momo_reference)
select ('99460000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 '99460000-0000-4000-8000-000000000801','99460000-0000-4000-8000-000000000005',9946001,
 1000,'pending','RS-SUPPORT-CONCURRENT-'||n from generate_series(802,807) n;

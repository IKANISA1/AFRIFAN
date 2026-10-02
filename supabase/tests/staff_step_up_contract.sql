begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
insert into public.african_football_clubs(id,club_name,country_name,club_slug,currency_code,country_iso_code)
 overriding system value values(25,'Selected staff QA club','Rwanda','staff-selected-qa','RWF','RW');
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous) values
 ('99465000-0000-4000-8000-000000000001','authenticated','authenticated',now(),false),
 ('99465000-0000-4000-8000-000000000002','authenticated','authenticated',now(),false),
 ('99465000-0000-4000-8000-000000000003','authenticated','authenticated',now(),false);
insert into public.users(id,phone,full_name) values
 ('99465000-0000-4000-8000-000000000001','+250799465001','Staff assurance fixture'),
 ('99465000-0000-4000-8000-000000000002','+250799465002','Closing staff fixture'),
 ('99465000-0000-4000-8000-000000000003','+250799465003','Unassigned staff fixture');
insert into public.profiles(id,club_id) values
 ('99465000-0000-4000-8000-000000000001',24),('99465000-0000-4000-8000-000000000002',24),('99465000-0000-4000-8000-000000000003',24);
insert into public.admin_role_assignments(user_id,role) values
 ('99465000-0000-4000-8000-000000000001','super_admin'),('99465000-0000-4000-8000-000000000002','super_admin');
create function pg_temp.staff_claims(p_claims jsonb,p_subject text default '99465000-0000-4000-8000-000000000001') returns void language plpgsql as $$ begin
 perform set_config('request.jwt.claims',p_claims::text,true);
 perform set_config('request.jwt.claim.sub',p_subject,true);
 perform set_config('request.jwt.claim.role',coalesce(p_claims->>'role',''),true);
end $$;
create function pg_temp.staff_token(p_age numeric default 0,p_method text default 'totp',p_aal text default 'aal2') returns jsonb language sql as $$
 select jsonb_build_object('sub','99465000-0000-4000-8000-000000000001','role','authenticated','is_anonymous',false,'aal',p_aal,'exp',floor(extract(epoch from clock_timestamp()))+3600,
 'app_metadata',jsonb_build_object('club_id',24),'amr',jsonb_build_array(jsonb_build_object('method',p_method,'timestamp',floor(extract(epoch from clock_timestamp())-p_age))))
$$;
select pg_temp.staff_claims(pg_temp.staff_token());
select ok(public.staff_step_up_allowed(),'current authenticated TOTP aal2 is allowed');
select lives_ok($$select public.assert_staff_step_up()$$,'canonical assertion admits current TOTP');
select pg_temp.staff_claims(pg_temp.staff_token(0,'mfa/totp'));
select ok(public.staff_step_up_allowed(),'provider mfa/totp method is explicitly recognized');
select pg_temp.staff_claims(pg_temp.staff_token(0,'totp','aal1'));
select ok(not public.staff_step_up_allowed(),'aal1 never creates staff assurance');
select throws_ok($$select public.predict_admin_settings(24,true,0)$$,'42501','STAFF_STEP_UP_REQUIRED','actual protected Predict settings reject aal1 before mutation');
select pg_temp.staff_claims(pg_temp.staff_token(301));
select ok(not public.staff_step_up_allowed(),'old TOTP is denied using wall clock');
select pg_temp.staff_claims(pg_temp.staff_token(-31));
select ok(not public.staff_step_up_allowed(),'future TOTP beyond thirty seconds is denied');
select pg_temp.staff_claims(pg_temp.staff_token(-20));
select ok(public.staff_step_up_allowed(),'bounded thirty-second provider skew is accepted');
select pg_temp.staff_claims(pg_temp.staff_token(0,'otp'));
select ok(not public.staff_step_up_allowed(),'phone OTP aal2 claim is not a TOTP step-up');
select pg_temp.staff_claims(pg_temp.staff_token(0,'totp-ish'));
select ok(not public.staff_step_up_allowed(),'unknown method remains closed');
select pg_temp.staff_claims(pg_temp.staff_token()-'amr');
select ok(not public.staff_step_up_allowed(),'missing AMR is denied');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"amr":"totp"}'::jsonb);
select ok(not public.staff_step_up_allowed(),'non-array AMR is denied');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"amr":[{"method":"totp","timestamp":"now"}]}'::jsonb);
select ok(not public.staff_step_up_allowed(),'string timestamp is denied');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"amr":[{"method":"totp","timestamp":"Infinity"}]}'::jsonb);
select ok(not public.staff_step_up_allowed(),'nonfinite timestamp text is denied');
select pg_temp.staff_claims(pg_temp.staff_token()-'exp');
select ok(not public.staff_step_up_allowed(),'missing JWT expiration is denied');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"exp":999999999999999999}'::jsonb);
select ok(not public.staff_step_up_allowed(),'unsafe expiration value is denied');
select pg_temp.staff_claims(pg_temp.staff_token()||jsonb_build_object('amr',(select jsonb_agg(jsonb_build_object('method','totp','timestamp',floor(extract(epoch from clock_timestamp())))) from generate_series(1,17))));
select ok(not public.staff_step_up_allowed(),'oversized AMR list is denied');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"exp":1}'::jsonb);
select ok(not public.staff_step_up_allowed(),'expired JWT cannot grant staff assurance');
select pg_temp.staff_claims(pg_temp.staff_token(),'99465000-0000-4000-8000-000000000002');
select ok(not public.staff_step_up_allowed(),'JWT subject binds the actual current authenticated subject');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"role":"service_role"}'::jsonb);
select ok(not public.staff_step_up_allowed(),'service JWT cannot claim human MFA');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"is_anonymous":true}'::jsonb);
select ok(not public.staff_step_up_allowed(),'anonymous session cannot claim staff MFA');
select pg_temp.staff_claims(pg_temp.staff_token()-'is_anonymous');
select ok(not public.staff_step_up_allowed(),'absent anonymous claim cannot grant staff assurance');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"is_anonymous":"false"}'::jsonb);
select ok(not public.staff_step_up_allowed(),'string anonymous claim cannot grant staff assurance');
select pg_temp.staff_claims(pg_temp.staff_token()-'aal'||'{"user_metadata":{"aal":"aal2","mfa":true}}'::jsonb);
select ok(not public.staff_step_up_allowed(),'client metadata cannot supply assurance');
select pg_temp.staff_claims(pg_temp.staff_token());
select lives_ok($$select public.predict_admin_settings(24,true,0)$$,'actual protected Predict settings retain free mechanics with valid step-up');
select throws_ok($$select public.admin_update_platform_feature_if_unchanged((select id from public.platform_features limit 1),now(),24,'{}','99465000-0000-4000-8000-000000000002')$$,'42501','STAFF_ACTOR_MISMATCH','feature RPC binds its audit actor to actual JWT subject');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
select ok(public.staff_step_up_allowed(),'MFA alone is independent of a staff role');
select throws_ok($$update public.quick_actions set title=title where false$$,'42501','STAFF_ADMIN_REQUIRED','protected direct DML checks current role independently of MFA');
select throws_ok($$select public.admin_update_platform_feature_if_unchanged((select id from public.platform_features limit 1),now(),24,'{}','99465000-0000-4000-8000-000000000003')$$,'42501','STAFF_ADMIN_REQUIRED','fresh MFA does not authorize a fan through security-definer feature mutation');
select pg_temp.staff_claims('{}'::jsonb,null);
insert into public.admin_role_assignments(user_id,role,club_id) values('99465000-0000-4000-8000-000000000003','club_admin',25);
select pg_temp.staff_claims(pg_temp.staff_token()||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
select throws_ok($$select public.admin_update_platform_feature_if_unchanged((select id from public.platform_features limit 1),now(),24,'{}','99465000-0000-4000-8000-000000000003')$$,'42501','STAFF_ADMIN_REQUIRED','other-club assignment does not authorize selected-club feature mutation');
select lives_ok($$update public.quick_actions set title=title where false$$,'entry guard admits a current assignment before any scoped row is changed');
set local role authenticated;
select lives_ok($$select id,user_id,role,club_id,partner_scope_id,granted_by,granted_at,is_active,revoked_at from public.admin_role_assignments where user_id=auth.uid() and is_active and revoked_at is null$$,'actual native and Web current-role projection has only necessary column access');
select is((select count(*)::int from public.admin_role_assignments where user_id=auth.uid() and is_active and revoked_at is null),1,'actual selected-club caller reads its own active assignment');
select is((select count(*)::int from public.admin_role_assignments where user_id='99465000-0000-4000-8000-000000000001'),0,'club staff cannot disclose another user global assignment');
select ok(not has_table_privilege('authenticated','public.admin_role_assignments','SELECT') and has_column_privilege('authenticated','public.admin_role_assignments','revoked_at','SELECT'),'revocation read remains a column grant without table-wide SELECT');
select lives_ok($$insert into public.news_articles(id,club_id,title) values('99465000-0000-4000-8000-000000000801',25,'Selected assigned club')$$,'actual staff row and policy admit selected assigned club despite preferred club 24');
select throws_ok($$insert into public.news_articles(id,club_id,title) values('99465000-0000-4000-8000-000000000802',24,'Other club')$$,'42501','STAFF_ADMIN_REQUIRED','actual selected row rejects unassigned club');
reset role;
select pg_temp.staff_claims(pg_temp.staff_token(301));
select throws_ok($$update public.quick_actions set title=title where false$$,'42501','STAFF_STEP_UP_REQUIRED','protected direct DML rejects stale assurance before zero-row writes');
select pg_temp.staff_claims(pg_temp.staff_token());
select lives_ok($$update public.quick_actions set title=title where false$$,'staff-only direct DML admits fresh authority');
select ok(not has_function_privilege('anon','public.staff_step_up_allowed()','EXECUTE') and not has_function_privilege('service_role','public.staff_step_up_allowed()','EXECUTE'),'helper has no anon/service human grant');
select ok(has_function_privilege('authenticated','public.staff_step_up_allowed()','EXECUTE') and has_function_privilege('authenticated','public.assert_staff_step_up()','EXECUTE'),'only authenticated callers can check their own step-up');
select ok(not exists(select 1 from unnest(array['public.guard_staff_configuration_mutation()','public.guard_staff_role_mutation()','public.assert_staff_configuration_role(jsonb,boolean)','public.staff_shop_counter_allowed(jsonb,jsonb)','public.assert_staff_commercial_role(jsonb,boolean)','public.assert_staff_commercial_partner(jsonb)','public.staff_ticket_counter_allowed(jsonb,jsonb)','public.refresh_match_ticket_sales()','public.rs_decrement_stock_on_order()','public.restock_cancelled_shop_order()']) f cross join unnest(array['anon','authenticated','service_role']) r where has_function_privilege(r,f,'EXECUTE')),'trigger guards stay private');
select is((select count(*)::int from pg_policy where polname like 'staff_step_up_%' and not polpermissive),60,'exact twenty staff tables have three restrictive write policies each');

select ok(not exists(select 1 from unnest(array['public.matches','public.news_articles','public.shop_products'])t cross join unnest(array['image_rights_approved','image_rights_approved_at','image_rights_approved_by'])c cross join unnest(array['INSERT','UPDATE'])p where has_column_privilege('authenticated',t,c,p)),'content writers cannot insert or alter media approval authority');
select ok(not has_column_privilege('authenticated','public.shop_products','image_prompt','INSERT') and not has_column_privilege('authenticated','public.news_articles','image_prompt','UPDATE') and not has_column_privilege('authenticated','public.membership_packages','benefit_scope','UPDATE') and not has_column_privilege('authenticated','public.membership_packages','store_billing_required','INSERT'),'internal prompts and membership classification remain outside caller writes');
set local role authenticated;
select throws_ok($$update public.news_articles set image_rights_approved=true where false$$,'42501','permission denied for table news_articles','actual verified global caller cannot self-approve media even before row matching');
select throws_ok($$update public.membership_packages set store_billing_required=false where false$$,'42501','permission denied for table membership_packages','actual verified global caller cannot overwrite reviewed store classification');
reset role;
-- Actual pending ticket cancellation remains a fan action at aal1.
select pg_temp.staff_claims('{}'::jsonb,null);
insert into public.partners(id,name,slug) values('99465000-0000-4000-8000-000000000883','Ticket counter proof partner','staff-ticket-counter-proof');
insert into public.matches(id,partner_id,club_id,home_team,away_team,competition,venue,match_date,kickoff_time,capacity,is_on_sale,ticket_general_price) values
 ('99465000-0000-4000-8000-000000000880','99465000-0000-4000-8000-000000000883',24,'Ticket Home','Ticket Away','Counter League','Counter Stadium',current_date+1,'18:00',10,true,100),
 ('99465000-0000-4000-8000-000000000881','99465000-0000-4000-8000-000000000883',25,'Selected Home','Selected Away','Counter League','Counter Stadium',current_date+2,'18:00',10,true,100);
insert into public.tickets(id,match_id,user_id,club_id,seat_type,amount_paid,status) values
 ('99465000-0000-4000-8000-000000000882','99465000-0000-4000-8000-000000000880','99465000-0000-4000-8000-000000000003',24,'general',100,'pending');
select is((select sold_count from public.matches where id='99465000-0000-4000-8000-000000000880'),1,'stored pending ticket is counted before fan cancellation');
select pg_temp.staff_claims(pg_temp.staff_token(0,'otp','aal1')||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
set local role authenticated;
select lives_ok($$select public.cancel_ticket_if_unchanged('99465000-0000-4000-8000-000000000882',(select updated_at from public.tickets where id='99465000-0000-4000-8000-000000000882'))$$,'actual fan cancellation uses stored-ticket counter without staff MFA');
select throws_ok($$update public.matches set sold_count=9 where id='99465000-0000-4000-8000-000000000880'$$,'42501','permission denied for table matches','fan has no direct counter update grant');
select throws_ok($$insert into public.staff_ticket_counter_context values(txid_current(),'99465000-0000-4000-8000-000000000882','99465000-0000-4000-8000-000000000880','{}')$$,'42501','permission denied for table staff_ticket_counter_context','fan cannot manufacture a private ticket counter context');
reset role;
select is((select sold_count from public.matches where id='99465000-0000-4000-8000-000000000880'),0,'actual cancellation decrements canonical counter once');
select is((select status from public.tickets where id='99465000-0000-4000-8000-000000000882'),'cancelled','actual owner ticket changes its lifecycle');
create temporary table unrelated_ticket_trigger(id integer);
create function pg_temp.unrelated_ticket_write() returns trigger language plpgsql security definer set search_path='' as $$ begin
 update public.matches set sold_count=9,updated_at=timezone('utc',now()) where id='99465000-0000-4000-8000-000000000880';return new;
end $$;
create trigger unrelated_counter after insert on unrelated_ticket_trigger for each row execute function pg_temp.unrelated_ticket_write();
select throws_ok($$insert into unrelated_ticket_trigger values(1)$$,'42501','STAFF_STEP_UP_REQUIRED','nested unrelated trigger cannot impersonate ticket accounting');
alter table unrelated_ticket_trigger owner to authenticated;
set local role authenticated;
select throws_ok($$create trigger forged_ticket after insert on unrelated_ticket_trigger for each row execute function public.refresh_match_ticket_sales()$$,'42501',null,'fan cannot attach canonical ticket trigger to an owned temp table');
reset role;
select pg_temp.staff_claims(pg_temp.staff_token()||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
set local role authenticated;
select lives_ok($$update public.matches set match_summary='Scoped caller edit' where id='99465000-0000-4000-8000-000000000881' returning id,updated_at$$,'actual selected-club edit returns its safe optimistic version');
select lives_ok($$delete from public.matches where id='99465000-0000-4000-8000-000000000881'$$,'actual selected-assignment staff delete is reachable');
reset role;
select is((select count(*)::int from public.matches where id='99465000-0000-4000-8000-000000000881'),0,'scoped match delete actually changes the admitted row');
select pg_temp.staff_claims(pg_temp.staff_token());

-- Original trigger attachment cannot fabricate a stored-order context.
select pg_temp.staff_claims('{}'::jsonb,null);
insert into public.shop_products(id,club_id,name,category,price,stock,is_active,currency)
 values('99465000-0000-4000-8000-000000000810',24,'Counter authority proof','shirt',1250,20,true,'RWF');
select pg_temp.staff_claims(pg_temp.staff_token());
set local role authenticated;
select lives_ok($$select id,club_id,name,subtitle,description,category,price,image_url,sizes,is_active,collection,sort_order,created_at,updated_at from public.shop_products where id='99465000-0000-4000-8000-000000000810'$$,'actual Web product projection includes safe creation and optimistic version timestamps');
reset role;
select pg_temp.staff_claims('{}'::jsonb,null);
create temporary table unrelated_inventory_trigger(id integer);
create function pg_temp.unrelated_inventory_write() returns trigger language plpgsql security definer set search_path='' as $$ begin
 update public.shop_products set stock=stock-1 where id='99465000-0000-4000-8000-000000000810'; return new;
end $$;
create trigger unrelated_counter after insert on unrelated_inventory_trigger for each row execute function pg_temp.unrelated_inventory_write();
select pg_temp.staff_claims(pg_temp.staff_token(0,'totp','aal1')||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
select throws_ok($$update public.shop_products set stock=stock-1 where id='99465000-0000-4000-8000-000000000810'$$,'42501','STAFF_STEP_UP_REQUIRED','direct supporter stock mutation cannot use counter exception');
select throws_ok($$insert into unrelated_inventory_trigger values(1)$$,'42501','STAFF_STEP_UP_REQUIRED','nested unrelated trigger cannot create counter authority');
select is((select stock from public.shop_products where id='99465000-0000-4000-8000-000000000810'),20,'denied stock writes preserve the actual counter');
alter table unrelated_inventory_trigger owner to authenticated;
set local role authenticated;
select throws_ok($$insert into public.staff_shop_counter_context values(txid_current(),'99465000-0000-4000-8000-000000000999','99465000-0000-4000-8000-000000000810',-1)$$,'42501','permission denied for table staff_shop_counter_context','caller cannot forge private context');
select throws_ok($$create trigger forged_order after insert on unrelated_inventory_trigger for each row execute function public.rs_decrement_stock_on_order()$$,'42501',null,'caller cannot attach the private inventory engine to a temp table');
reset role;
select pg_temp.staff_claims(pg_temp.staff_token());
-- Commercial writes use exact current club_admin, not broader CMS roles.
select pg_temp.staff_claims('{}'::jsonb,null);
insert into public.partners(id,name) values
 ('99465000-0000-4000-8000-000000000840','Mapped partner'),('99465000-0000-4000-8000-000000000841','Foreign partner');
insert into public.shop_products(id,club_id,partner_id,name,category,price,stock,currency) values
 ('99465000-0000-4000-8000-000000000842',25,'99465000-0000-4000-8000-000000000840','Stored selected mapping','shirt',1000,5,'RWF'),
 ('99465000-0000-4000-8000-000000000843',24,'99465000-0000-4000-8000-000000000841','Stored foreign mapping','shirt',1000,5,'RWF');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
set local role authenticated;
select lives_ok($$insert into public.membership_packages(id,club_id,partner_id,tier,title,subtitle,annual_price,price) values('99465000-0000-4000-8000-000000000844',25,'99465000-0000-4000-8000-000000000840','bronze','Mapped membership','Actual caller',1000,1000)$$,'actual selected club membership accepts its existing canonical partner');
select throws_ok($$insert into public.membership_packages(id,club_id,partner_id,tier,title,subtitle,annual_price,price) values('99465000-0000-4000-8000-000000000845',25,'99465000-0000-4000-8000-000000000841','silver','Foreign membership','Denied caller',1000,1000)$$,'42501','STAFF_COMMERCIAL_PARTNER_REQUIRED','current club admin cannot insert a foreign-club membership partner');
select throws_ok($$insert into public.shop_products(id,club_id,partner_id,name,category,price,currency) values('99465000-0000-4000-8000-000000000846',25,'99465000-0000-4000-8000-000000000841','Foreign merchandise','shirt',1000,'RWF')$$,'42501','STAFF_COMMERCIAL_PARTNER_REQUIRED','current club admin cannot insert a foreign-club merchandise partner');
select is((select count(*)::int from public.membership_packages where id='99465000-0000-4000-8000-000000000844'),1,'successful mapped membership exists before actual association update');
select throws_ok($$update public.membership_packages set partner_id='99465000-0000-4000-8000-000000000841' where id='99465000-0000-4000-8000-000000000844'$$,'42501','STAFF_COMMERCIAL_PARTNER_REQUIRED','changing an existing association cannot qualify through its NEW row');
select lives_ok($$update public.shop_products set price=price+1 where id='99465000-0000-4000-8000-000000000842'$$,'unchanged retained partner associations allow ordinary authorized edits');
reset role;
select pg_temp.staff_claims(pg_temp.staff_token());
set local role authenticated;
select lives_ok($$insert into public.membership_packages(id,club_id,partner_id,tier,title,subtitle,annual_price,price) values('99465000-0000-4000-8000-000000000847',null,'99465000-0000-4000-8000-000000000841','gold','Global catalog','Global caller',1000,1000)$$,'global NULL-club catalog semantics remain reachable');
reset role;
select pg_temp.staff_claims('{}'::jsonb,null);
update public.admin_role_assignments set role='club_moderator' where user_id='99465000-0000-4000-8000-000000000003';
select pg_temp.staff_claims(pg_temp.staff_token()||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
select throws_ok($$update public.shop_products set price=price+1 where id='99465000-0000-4000-8000-000000000810'$$,'42501','STAFF_COMMERCIAL_ADMIN_REQUIRED','club moderator cannot mutate commercial price');
select pg_temp.staff_claims('{}'::jsonb,null);
update public.admin_role_assignments set role='club_admin' where user_id='99465000-0000-4000-8000-000000000003';
select pg_temp.staff_claims(pg_temp.staff_token()||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
select throws_ok($$update public.shop_products set price=price+1 where id='99465000-0000-4000-8000-000000000810'$$,'42501','STAFF_COMMERCIAL_ADMIN_REQUIRED','other club admin cannot mutate retained product price');
select is((select price::integer from public.shop_products where id='99465000-0000-4000-8000-000000000810'),1250,'denied commercial edits preserve price');
select pg_temp.staff_claims(pg_temp.staff_token());
set local role authenticated;
select lives_ok($$insert into football.competitions(id,slug,name,short_name) values('99465000-0000-4000-8000-000000000820','staff-actual-global-write','Actual global fixture write','Proof')$$,'actual caller JWT global football configuration write is reachable');
reset role;
select pg_temp.staff_claims(pg_temp.staff_token()||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
set local role authenticated;
select throws_ok($$insert into football.competitions(id,slug,name,short_name) values('99465000-0000-4000-8000-000000000821','staff-forbidden-global-write','Forbidden global write','Proof')$$,'42501','STAFF_ADMIN_REQUIRED','club assignment cannot mutate globally shared fixture configuration');
reset role;
select pg_temp.staff_claims(pg_temp.staff_token());
set local role authenticated;
select lives_ok($$insert into football.prediction_markets(id,slug,name,short_name) values('99465000-0000-4000-8000-000000000830','staff-actual-market','Actual global market','Proof')$$,'actual global caller can write shared market configuration');
select lives_ok($$insert into public.livescore_competition_sources(id,club_id,source_key,display_name,match_aliases) values('99465000-0000-4000-8000-000000000831',null,'staff-global-source','Global source',array['Proof'])$$,'actual global caller can write NULL-club LiveScore configuration');
reset role;
select pg_temp.staff_claims(pg_temp.staff_token()||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
set local role authenticated;
select throws_ok($$insert into football.prediction_markets(id,slug,name,short_name) values('99465000-0000-4000-8000-000000000832','staff-forbidden-market','Forbidden market','Proof')$$,'42501','STAFF_ADMIN_REQUIRED','club staff cannot mutate globally shared markets');
select lives_ok($$insert into public.livescore_competition_sources(id,club_id,source_key,display_name,match_aliases) values('99465000-0000-4000-8000-000000000833',25,'staff-selected-source','Selected source',array['Proof'])$$,'actual current club_admin can write selected assigned LiveScore club');
select throws_ok($$insert into public.livescore_competition_sources(id,club_id,source_key,display_name,match_aliases) values('99465000-0000-4000-8000-000000000834',24,'staff-foreign-source','Other source',array['Proof'])$$,'42501','STAFF_COMMERCIAL_ADMIN_REQUIRED','other club source remains protected');
select throws_ok($$insert into public.livescore_competition_sources(id,club_id,source_key,display_name,match_aliases) values('99465000-0000-4000-8000-000000000835',null,'staff-null-source','Null source',array['Proof'])$$,'42501','STAFF_COMMERCIAL_ADMIN_REQUIRED','NULL-club LiveScore configuration requires global role');
reset role;
select pg_temp.staff_claims('{}'::jsonb,null);
update public.admin_role_assignments set role='club_moderator' where user_id='99465000-0000-4000-8000-000000000003';
select pg_temp.staff_claims(pg_temp.staff_token()||'{"sub":"99465000-0000-4000-8000-000000000003"}'::jsonb,'99465000-0000-4000-8000-000000000003');
set local role authenticated;
select throws_ok($$delete from public.livescore_competition_sources where id='99465000-0000-4000-8000-000000000833'$$,'42501','STAFF_COMMERCIAL_ADMIN_REQUIRED','moderator cannot delete LiveScore configuration');
reset role;
select pg_temp.staff_claims(pg_temp.staff_token());
-- Expiry progresses inside a single transaction. now() would incorrectly admit it.
select pg_temp.staff_claims(pg_temp.staff_token(299));
select ok(public.staff_step_up_allowed(),'nearly expired step-up starts valid');
select pg_sleep(1.1);
select throws_ok($$select public.predict_admin_settings(24,true,0)$$,'42501','STAFF_STEP_UP_REQUIRED','same-transaction wall-clock expiry rejects the actual mutation');
-- Closure uses its actual service capability; human mutations retain all
-- account guards. No closure exception grants an authenticated mutation.
select pg_temp.staff_claims(pg_temp.staff_token(0,'totp','aal1')||'{"sub":"99465000-0000-4000-8000-000000000002"}'::jsonb,'99465000-0000-4000-8000-000000000002');
select pg_temp.staff_claims('{"role":"service_role"}'::jsonb,null);
set local role service_role;
select lives_ok($$select public.request_account_erasure('99465000-0000-4000-8000-000000000002','99465000-0000-4000-8000-000000000099')$$,'actual service closure revokes the caller subject without requiring fan MFA');
reset role;
select pg_temp.staff_claims(pg_temp.staff_token(0,'totp','aal1')||'{"sub":"99465000-0000-4000-8000-000000000002"}'::jsonb,'99465000-0000-4000-8000-000000000002');
select ok(not has_function_privilege('authenticated','public.request_account_erasure(uuid,uuid)','EXECUTE'),'human cannot invoke account erasure service capability directly');
select ok(not exists(select 1 from public.admin_role_assignments where user_id='99465000-0000-4000-8000-000000000002' and (is_active or revoked_at is null)),'service closure revokes the exact closed subject');
select ok(not public.staff_step_up_allowed(),'closed subject never retains assurance');
select throws_ok($$update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='99465000-0000-4000-8000-000000000002'$$,'42501','ACCOUNT_CLOSURE_PENDING','closed human cannot restore a role');
select throws_ok($$update public.admin_role_assignments set role='club_admin',is_active=false,revoked_at=now() where user_id='99465000-0000-4000-8000-000000000002'$$,'42501','ACCOUNT_CLOSURE_PENDING','closed human cannot change assignment authority');
-- Actual service-role EXECUTE preserves the reachable historical confirmation.
select pg_temp.staff_claims('{}'::jsonb,null);
insert into football.competitions(id,slug,name,short_name) values('99465000-0000-4000-8000-000000000200','staff-step-up-proof','Staff proof league','Proof');
insert into football.seasons(id,competition_id,slug,label) values('99465000-0000-4000-8000-000000000201','99465000-0000-4000-8000-000000000200','staff-step-up-proof-season','2026');
insert into football.teams(id,name,crest_url) values('99465000-0000-4000-8000-000000000210','Staff Home','https://example.com/home.png'),('99465000-0000-4000-8000-000000000211','Staff Away','https://example.com/away.png');
insert into football.fixtures(id,competition_id,season_id,home_team_id,away_team_id,kickoff_at,status,home_score,away_score)
 values('99465000-0000-4000-8000-000000000301','99465000-0000-4000-8000-000000000200','99465000-0000-4000-8000-000000000201','99465000-0000-4000-8000-000000000210','99465000-0000-4000-8000-000000000211',now()-interval '1 day','finished',2,1);
insert into football.predict_pools(id,club_id,fixture_id,stake_fet,opens_at,locks_at,economics_version,source_url,approved_by)
 values('99465000-0000-4000-8000-000000000501',24,'99465000-0000-4000-8000-000000000301',100,now()-interval '2 days',now()-interval '1 day','legacy_paid_v1','https://example.com/official','99465000-0000-4000-8000-000000000001');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('99465000-0000-4000-8000-000000000551','99465000-0000-4000-8000-000000000001',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
select pg_temp.staff_claims(pg_temp.staff_token()||'{"session_id":"99465000-0000-4000-8000-000000000551"}'::jsonb);
set local role authenticated;
select public.admit_verified_staff_command('99465000-0000-4000-8000-000000000701','predict_legacy_confirm','99465000-0000-4000-8000-000000000501','{"home_score":2,"away_score":1,"source_url":"https://example.com/official"}');
reset role;
select pg_temp.staff_claims('{"role":"service_role"}'::jsonb,null);
set local role service_role;
select lives_ok($$select public.predict_admin_confirm_result_for_actor('99465000-0000-4000-8000-000000000501',2,1,'https://example.com/official','99465000-0000-4000-8000-000000000001','99465000-0000-4000-8000-000000000701')$$,'actual service grant preserves attributed historical confirmation');
reset role;
select ok((select result_confirmed_at is not null from football.predict_pools where id='99465000-0000-4000-8000-000000000501'),'historical immutable result really confirmed');
select ok(not has_function_privilege('authenticated','public.predict_admin_confirm_result_for_actor(uuid,integer,integer,text,uuid,uuid)','EXECUTE'),'human authenticated role cannot invoke the service wrapper');
select * from finish();
rollback;

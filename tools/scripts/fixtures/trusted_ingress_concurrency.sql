begin;
insert into public.african_football_clubs(id,club_name,country_name,club_slug,currency_code,country_iso_code,momo_ussd_template)
 overriding system value values(9996601,'Gateway QA','Rwanda','gateway-qa','RWF','RW','*182*8*1*{amount}*{recipient}#'),
 (9996602,'Foreign Gateway QA','Rwanda','foreign-gateway-qa','RWF','RW','*182*8*1*{amount}*{recipient}#');
insert into public.partners(id,name,slug,is_active) values('99966000-0000-4000-8000-000000000100','Gateway QA','gateway-qa',true);
insert into auth.users(id,aud,role,is_anonymous,phone_confirmed_at,phone) values
 ('99966000-0000-4000-8000-000000000001','authenticated','authenticated',false,now(),'+250799966001'),
 ('99966000-0000-4000-8000-000000000002','authenticated','authenticated',false,now(),'+250799966002'),
 ('99966000-0000-4000-8000-000000000003','authenticated','authenticated',true,null,'+250799966003');
insert into public.users(id,phone,full_name) values
 ('99966000-0000-4000-8000-000000000001','+250799966001','Receipt owner'),
 ('99966000-0000-4000-8000-000000000002','+250799966002','Receipt outsider'),
 ('99966000-0000-4000-8000-000000000003','+250799966003','Receipt guest');
insert into public.profiles(id,club_id) values
 ('99966000-0000-4000-8000-000000000001',9996601),
 ('99966000-0000-4000-8000-000000000002',9996602),
 ('99966000-0000-4000-8000-000000000003',9996601);
insert into public.fan_memberships(user_id,club_id,partner_id,tier,membership_number,payment_status,status,expires_at)
 values('99966000-0000-4000-8000-000000000001',9996601,'99966000-0000-4000-8000-000000000100','gold','INGRESS-QA','verified','active',now()+interval '1 year');
insert into public.shop_products(id,club_id,partner_id,name,category,price,stock,is_active,currency)
 values('99966000-0000-4000-8000-000000000110',9996601,'99966000-0000-4000-8000-000000000100','QA Shirt','shirt',1250,20,true,'RWF');
insert into public.partner_payment_routes(id,club_id,partner_id,country,provider,recipient_code,reconciliation_label,status)
 values('99966000-0000-4000-8000-000000000120',9996601,'99966000-0000-4000-8000-000000000100','RW','mtn','66612345','Gateway QA','active');
insert into public.payment_receiver_accounts(id,partner_id,payee_number_or_code,purpose,is_active)
 values('99966000-0000-4000-8000-000000000130','99966000-0000-4000-8000-000000000100','66612345','club_shop',true);
create temporary table receipts(label text primary key,body jsonb);
grant all on receipts to authenticated;
create function pg_temp.prepare(ref text) returns jsonb language sql security invoker as $$
 select public.prepare_shop_checkout_for_club('[{"product_id":"99966000-0000-4000-8000-000000000110","quantity":2,"price":1}]',
   'QA Kigali address',ref,9996601);
$$;
grant execute on function pg_temp.prepare(text) to authenticated;
select set_config('request.jwt.claim.sub','99966000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"99966000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9996601","is_anonymous":false}',true);
set local role authenticated;
insert into receipts values('first',pg_temp.prepare('order-99966000-0000-4000-8000-000000000201'));

reset role;
insert into public.trusted_sms_gateways(id,receiver_account_id,club_id,provider,country,currency,source_review_reference,provider_acceptance_reference)
 values('99966000-0000-4000-8000-000000000500','99966000-0000-4000-8000-000000000130',9996601,'mtn_rwanda','RW','RWF','synthetic-local-source-review','synthetic-local-provider-acceptance');
insert into public.trusted_sms_gateway_keys(id,gateway_id,secret_env_name,enabled,expires_at)
 values('99966000-0000-4000-8000-000000000510','99966000-0000-4000-8000-000000000500','SMS_GATEWAY_KEY_QA',true,now()+interval '1 day');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
reset role;
update public.trusted_sms_gateways set enabled=true where id='99966000-0000-4000-8000-000000000500';
update public.trusted_sms_ingress_config set enabled=true where id;
reset role;
commit;

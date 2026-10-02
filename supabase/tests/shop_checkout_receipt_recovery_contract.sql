begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select ok(not has_function_privilege('anon','public.prepare_shop_checkout_for_club(jsonb,text,text,bigint)','execute'),'anonymous preparation denied');
select ok(has_function_privilege('authenticated','public.prepare_shop_checkout_for_club(jsonb,text,text,bigint)','execute'),'explicit supporter preparation is callable');
select ok(not has_function_privilege('authenticated','public.create_shop_order(jsonb,text,text)','execute'),'legacy creator remains service-only');
select ok(not has_function_privilege('authenticated','public.shop_checkout_receipt_response(public.shop_orders)','execute'),'internal projection cannot disclose arbitrary orders');

insert into public.african_football_clubs(id,club_name,country_name,club_slug,currency_code,country_iso_code,momo_ussd_template)
 overriding system value values(9996201,'Receipt QA','Rwanda','receipt-qa','RWF','RW','*182*8*1*{amount}*{recipient}#'),
 (9996202,'Foreign Receipt QA','Rwanda','foreign-receipt-qa','RWF','RW','*182*8*1*{amount}*{recipient}#');
insert into public.partners(id,name,slug,is_active) values('99962000-0000-4000-8000-000000000100','Receipt QA','receipt-qa',true);
insert into auth.users(id,aud,role,is_anonymous,phone_confirmed_at) values
 ('99962000-0000-4000-8000-000000000001','authenticated','authenticated',false,now()),
 ('99962000-0000-4000-8000-000000000002','authenticated','authenticated',false,now()),
 ('99962000-0000-4000-8000-000000000003','authenticated','authenticated',true,null);
insert into public.users(id,phone,full_name) values
 ('99962000-0000-4000-8000-000000000001','+250799962001','Receipt owner'),
 ('99962000-0000-4000-8000-000000000002','+250799962002','Receipt outsider'),
 ('99962000-0000-4000-8000-000000000003','+250799962003','Receipt guest');
insert into public.profiles(id,club_id) values
 ('99962000-0000-4000-8000-000000000001',9996201),
 ('99962000-0000-4000-8000-000000000002',9996202),
 ('99962000-0000-4000-8000-000000000003',9996201);
insert into public.fan_memberships(user_id,club_id,partner_id,tier,membership_number,payment_status,status,expires_at)
 values('99962000-0000-4000-8000-000000000001',9996201,'99962000-0000-4000-8000-000000000100','gold','RECEIPT-QA','verified','active',now()+interval '1 year');
insert into public.shop_products(id,club_id,partner_id,name,category,price,stock,is_active,currency)
 values('99962000-0000-4000-8000-000000000110',9996201,'99962000-0000-4000-8000-000000000100','QA Shirt','shirt',1250,20,true,'RWF');
insert into public.partner_payment_routes(id,club_id,partner_id,country,provider,recipient_code,reconciliation_label,status)
 values('99962000-0000-4000-8000-000000000120',9996201,'99962000-0000-4000-8000-000000000100','RW','mtn','12345','Receipt QA','active');
insert into public.payment_receiver_accounts(id,partner_id,payee_number_or_code,purpose,is_active)
 values('99962000-0000-4000-8000-000000000130','99962000-0000-4000-8000-000000000100','12345','club_shop',true);
create temporary table receipts(label text primary key,body jsonb);
grant all on receipts to authenticated;
create function pg_temp.prepare(ref text) returns jsonb language sql security invoker as $$
 select public.prepare_shop_checkout_for_club('[{"product_id":"99962000-0000-4000-8000-000000000110","quantity":2,"price":1}]',
   'QA Kigali address',ref,9996201);
$$;
grant execute on function pg_temp.prepare(text) to authenticated;
select set_config('request.jwt.claim.sub','99962000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"99962000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9996201","is_anonymous":false}',true);
set local role authenticated;
insert into receipts values('first',pg_temp.prepare('order-99962000-0000-4000-8000-000000000201'));
select is((select body->'receipt'->>'total' from receipts where label='first'),'2500','server price wins over the stale supplied price');
select is((select body->'receipt'->>'ussd_code' from receipts where label='first'),'*182*8*1*2500*12345#','exact frozen total and receiver form the dialer instruction');
select is((select body->'receipt'->>'currency' from receipts where label='first'),'RWF','currency is server resolved');
select ok((select (body->>'can_pay')::boolean from receipts where label='first'),'new pending receipt can be reviewed');
insert into receipts values('retry',pg_temp.prepare('order-99962000-0000-4000-8000-000000000201'));
select is((select body->'order'->>'id' from receipts where label='retry'),(select body->'order'->>'id' from receipts where label='first'),'same operation recovers the original order');
select is((select body->'receipt' from receipts where label='retry'),(select body->'receipt' from receipts where label='first'),'restart recovery preserves every frozen receipt fact');
select throws_ok($$select public.validate_shop_checkout_for_club((select (body->'order'->>'id')::uuid from receipts where label='first'),9996201,'{}')$$,'P0001','SHOP_REVIEW_CHANGED','unreviewed instructions cannot validate');
reset role;
select is((select stock from public.shop_products where club_id=9996201),18,'recovery never reserves stock again');
select is((select amount from public.pending_transactions where reference='order-99962000-0000-4000-8000-000000000201'),2500,'reconciliation request uses the frozen amount');
select is((select recipient_momo from public.pending_transactions where reference='order-99962000-0000-4000-8000-000000000201'),'12345','reconciliation request uses the frozen receiver');
-- Operator setup has a service identity; reset role alone retains the fan JWT.
select set_config('request.jwt.claims','{"role":"service_role"}',true);
update public.shop_products set price=1750 where club_id=9996201;
select set_config('request.jwt.claims','{"sub":"99962000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9996201","is_anonymous":false}',true);
set local role authenticated;
select is(public.recover_shop_checkout_for_club('order-99962000-0000-4000-8000-000000000201',9996201)->'receipt'->>'total','2500','later repricing does not rewrite the original order');
reset role;
update public.partner_payment_routes set recipient_code='67890' where club_id=9996201;
set local role authenticated;
select is(public.validate_shop_checkout_for_club((select (body->'order'->>'id')::uuid from receipts where label='first'),9996201,
 (select body->'receipt' from receipts where label='first'))->>'can_pay','false','changed receiver prevents stale dialer handoff');
reset role;
update public.partner_payment_routes set recipient_code='12345' where club_id=9996201;
update public.payment_receiver_accounts set is_active=false where id='99962000-0000-4000-8000-000000000130';
set local role authenticated;
select is(public.recover_shop_checkout_for_club('order-99962000-0000-4000-8000-000000000201',9996201)->>'can_pay','false','receiver revocation blocks payment without erasing recovery');
reset role;
update public.payment_receiver_accounts set is_active=true where id='99962000-0000-4000-8000-000000000130';
update public.african_football_clubs set currency_code='USD' where id=9996201;
set local role authenticated;
select is(public.recover_shop_checkout_for_club('order-99962000-0000-4000-8000-000000000201',9996201)->>'can_pay','false','changed club currency cannot relabel an old instruction');
select throws_ok($$select pg_temp.prepare('order-99962000-0000-4000-8000-000000000202')$$,'P0001','SHOP_CURRENCY_INVALID','mixed product and club currency rolls back preparation');
reset role;
update public.african_football_clubs set currency_code='RWF' where id=9996201;
select is((select count(*)::integer from public.shop_orders where club_id=9996201),1,'failed preparation creates no durable second order');
select is((select stock from public.shop_products where club_id=9996201),18,'failed preparation rolls back its stock reservation');
select throws_ok($$update public.shop_orders set total=1 where club_id=9996201$$,'P0001','SHOP_RECEIPT_IMMUTABLE','receipt financial facts cannot be rewritten');
select throws_ok($$update public.shop_orders set status='paid' where club_id=9996201$$,'P0001','SHOP_RECEIPT_EVIDENCE_MISMATCH','receipt cannot become paid without exact matching evidence');
-- Synthetic persisted evidence exercises the real service confirmation RPC.
-- This is a database atomicity contract, not provider-authenticity acceptance.
insert into public.momo_sms_raw(id,user_id,device_message_key,sender,sms_body,provider,country_code,sms_received_at,parse_status,club_id)
 values('99962000-0000-4000-8000-000000001201','99962000-0000-4000-8000-000000000001',
 'frozen-shop-receipt-qa','M-Money','Synthetic exact frozen checkout payment','mtn_rwanda','RW',clock_timestamp(),'parsed',9996201);
insert into public.momo_sms_parsed(id,raw_sms_id,user_id,parser_provider,parser_model,parse_status,tx_direction,tx_type,momo_tx_id,amount,currency,payee_number_or_code,country_code,club_id)
 values('99962000-0000-4000-8000-000000002201','99962000-0000-4000-8000-000000001201',
 '99962000-0000-4000-8000-000000000001','contract','frozen-receipt-v1','parsed','debit','payment',
 'SYNTHETIC-FROZEN-SHOP-201',2500,'RWF','12345','RW',9996201);
create function pg_temp.confirm_frozen_shop(amount integer default 2500,payee text default '12345') returns jsonb
 language sql security invoker as $$
 select public.confirm_club_commerce_payment('shop',
 array[(select id from public.shop_orders where momo_reference='order-99962000-0000-4000-8000-000000000201')],
 '99962000-0000-4000-8000-000000000001','order-99962000-0000-4000-8000-000000000201',
 amount,9996201,'99962000-0000-4000-8000-000000000100','mtn_rwanda',payee,'RWF','RW',
 '99962000-0000-4000-8000-000000002201');
$$;
grant execute on function pg_temp.confirm_frozen_shop(integer,text) to service_role;
set local role service_role;
select is(pg_temp.confirm_frozen_shop(2499)->>'status','manual_review','underpayment cannot confirm frozen receipt');
select is(pg_temp.confirm_frozen_shop(2500,'67890')->>'status','manual_review','different receiver cannot confirm frozen receipt');
select is(pg_temp.confirm_frozen_shop()->>'newly_confirmed','true','exact persisted evidence confirms the frozen receipt through real RPC');
select ok((select status='paid' and confirmed_at is not null and not inventory_reserved
 from public.shop_orders where momo_reference='order-99962000-0000-4000-8000-000000000201'),
 'paid state and reservation fulfillment commit together');
select is(pg_temp.confirm_frozen_shop()->>'newly_confirmed','false','lost confirmation response replays the same operation idempotently');
select is((select stock from public.shop_products where club_id=9996201),18,'confirmation and duplicate replay never reserve or deduct stock twice');
select is((select count(*)::integer from public.momo_ledger_entries where club_id=9996201 and ledger_status='posted'),1,'only one exact frozen receipt ledger is posted');
select is((select count(*)::integer from public.momo_reconciliations where club_id=9996201 and match_status='matched'),1,'only one exact frozen receipt reconciliation is matched');
select is((select points from public.fan_memberships where user_id='99962000-0000-4000-8000-000000000001'),25,'original financial reward semantics apply once');
reset role;
set local role authenticated;
select is(public.recover_shop_checkout_for_club('order-99962000-0000-4000-8000-000000000201',9996201)->'order'->>'status','paid','restart recovery reads actual confirmed paid status');
select is(public.recover_shop_checkout_for_club('order-99962000-0000-4000-8000-000000000201',9996201)->>'can_pay','false','a posted original receipt cannot enable a second payment');
reset role;
select set_config('request.jwt.claim.sub','99962000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"99962000-0000-4000-8000-000000000002","role":"authenticated","club_id":"9996202","is_anonymous":false}',true);
set local role authenticated;
select is(public.recover_shop_checkout_for_club('order-99962000-0000-4000-8000-000000000201',9996202),null::jsonb,'foreign user and tenant cannot discover a receipt');
select throws_ok($$select public.recover_shop_checkout_for_club('order-99962000-0000-4000-8000-000000000201',9996201)$$,'P0001','SHOP_AUTH_REQUIRED','client club hint cannot authorize another tenant');
reset role;
select set_config('request.jwt.claim.sub','99962000-0000-4000-8000-000000000003',true);
select set_config('request.jwt.claims','{"sub":"99962000-0000-4000-8000-000000000003","role":"authenticated","club_id":"9996201","is_anonymous":true}',true);
set local role authenticated;
select throws_ok($$select pg_temp.prepare('order-99962000-0000-4000-8000-000000000203')$$,'P0001','SHOP_AUTH_REQUIRED','anonymous subject cannot create a financial order');
reset role;
select * from finish();
rollback;

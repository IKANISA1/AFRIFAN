begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
-- BEGIN REFUND ENTITLEMENT FIXTURE: synthetic local proof, no provider acceptance.
insert into public.african_football_clubs(id,club_name,country_name,club_slug,currency_code,country_iso_code,momo_ussd_template)
 overriding system value values(9996801,'Refund QA','Rwanda','refund-entitlement-qa','RWF','RW','*182*8*1*{amount}*{recipient}#'),
 (9996802,'Foreign Refund QA','Rwanda','foreign-refund-entitlement-qa','RWF','RW','*182*8*1*{amount}*{recipient}#');
insert into public.partners(id,name,slug,is_active) values('99968000-0000-4000-8000-000000000100','Refund QA','refund-entitlement-qa',true);
insert into auth.users(id,aud,role,is_anonymous,phone_confirmed_at,phone) values
 ('99968000-0000-4000-8000-000000000001','authenticated','authenticated',false,now(),'+250799968001'),
 ('99968000-0000-4000-8000-000000000002','authenticated','authenticated',false,now(),'+250799968002'),
 ('99968000-0000-4000-8000-000000000003','authenticated','authenticated',false,now(),'+250799968003'),
 ('99968000-0000-4000-8000-000000000004','authenticated','authenticated',false,now(),'+250799968004');
insert into public.users(id,phone,full_name) values
 ('99968000-0000-4000-8000-000000000001','+250799968001','Refund maker'),
 ('99968000-0000-4000-8000-000000000002','+250799968002','Refund checker'),
 ('99968000-0000-4000-8000-000000000003','+250799968003','Refund payer'),
 ('99968000-0000-4000-8000-000000000004','+250799968004','Club operator');
insert into public.profiles(id,club_id) select id,9996801 from auth.users where id::text like '99968000-%';
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99968000-0000-4000-8000-000000000001','super_admin',null),
 ('99968000-0000-4000-8000-000000000002','admin',null),
 ('99968000-0000-4000-8000-000000000004','club_admin',9996801);
insert into public.fan_memberships(user_id,club_id,partner_id,tier,membership_number,payment_status,status,expires_at)
 values('99968000-0000-4000-8000-000000000003',9996801,'99968000-0000-4000-8000-000000000100','gold','REFUND-QA','verified','active',now()+interval '1 year');
insert into public.shop_products(id,club_id,partner_id,name,category,price,stock,is_active,currency)
 values('99968000-0000-4000-8000-000000000110',9996801,'99968000-0000-4000-8000-000000000100','QA Shirt','shirt',1250,20,true,'RWF');
insert into public.partner_payment_routes(id,club_id,partner_id,country,provider,recipient_code,reconciliation_label,status)
 values('99968000-0000-4000-8000-000000000120',9996801,'99968000-0000-4000-8000-000000000100','RW','mtn','12345','Refund QA','active');
insert into public.payment_receiver_accounts(id,partner_id,payee_number_or_code,purpose,is_active)
 values('99968000-0000-4000-8000-000000000130','99968000-0000-4000-8000-000000000100','12345','club_shop',true);
create function pg_temp.actor(n integer,aal text default 'aal2') returns text language plpgsql as $$
declare subject text:='99968000-0000-4000-8000-'||lpad(n::text,12,'0');begin
 perform set_config('request.jwt.claim.sub',subject,true);
 return set_config('request.jwt.claims',jsonb_build_object('sub',subject,'role','authenticated','is_anonymous',false,
  'club_id',9996801,'aal',aal,'exp',floor(extract(epoch from clock_timestamp()))::bigint+3600,
  'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',floor(extract(epoch from clock_timestamp()))::bigint)))::text,true);
end; $$;
grant execute on function pg_temp.actor(integer,text) to authenticated;
select pg_temp.actor(3);
set local role authenticated;
select public.prepare_shop_checkout_for_club('[{"product_id":"99968000-0000-4000-8000-000000000110","quantity":2}]','Synthetic QA Kigali delivery address',
 'order-99968000-0000-4000-8000-000000000201',9996801);
reset role;
insert into public.trusted_sms_gateways(id,receiver_account_id,club_id,provider,country,currency,enabled,source_review_reference,provider_acceptance_reference)
 values('99968000-0000-4000-8000-000000000500','99968000-0000-4000-8000-000000000130',9996801,'mtn_rwanda','RW','RWF',true,
 'synthetic-payment-source-review','synthetic-payment-provider-acceptance');
insert into public.trusted_sms_gateway_keys(id,gateway_id,secret_env_name,enabled,expires_at)
 values('99968000-0000-4000-8000-000000000510','99968000-0000-4000-8000-000000000500','SMS_GATEWAY_KEY_REFUND_ENTITLEMENT_QA',true,now()+interval '1 day');
update public.trusted_sms_ingress_config set enabled=true where id;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select public.admit_trusted_sms_gateway_evidence('99968000-0000-4000-8000-000000000510','99968000-0000-4000-8000-000000000530',
 clock_timestamp()-interval '1 second',clock_timestamp()+interval '2 minutes','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=',
 jsonb_build_object('protocol','africlub.receiver-settlement.v1','eventId','99968000-0000-4000-8000-000000000520',
 'checkoutReference','order-99968000-0000-4000-8000-000000000201','providerTransactionId','SYNTHETIC-ORIGINAL-TX-201',
 'receiver','12345','provider','mtn_rwanda','country','RW','currency','RWF','amount',2500,
 'settledAt',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
 'payerAccountDigest',encode(extensions.digest('africlub-payer-v1:mtn_rwanda:RW:250799968003','sha256'),'hex'),
 'settlementStatus','settled','settlementRecordId','synthetic-original-statement-201','settlementRecordDigest',repeat('a',64)));
select public.process_trusted_sms_gateway_evidence('99968000-0000-4000-8000-000000000520');
reset role;

-- Entitlement consequence proof uses actual preparation, payment, review and evidence RPCs.
-- Synthetic approvals exercise local mechanics only; no provider acceptance is asserted.
insert into public.payment_refund_gateway_approvals(gateway_id,enabled,policy_version,source_review_reference,provider_acceptance_reference,terms_reference,ticket_policy,membership_policy)
 values('99968000-0000-4000-8000-000000000500',true,'synthetic-entitlement-v1','synthetic-refund-source-review','synthetic-refund-provider-acceptance','synthetic-refund-contract-terms','revoke_unused','suspend_current');
insert into public.membership_packages(id,partner_id,club_id,tier,title,subtitle,annual_price,price)
 values('99968000-0000-4000-8000-000000000150','99968000-0000-4000-8000-000000000100',9996801,'imena','Synthetic paid membership','Local refund consequence fixture',1000,1000);
create temporary table entitlement_receipts(label text primary key,body jsonb);
grant all on entitlement_receipts to authenticated,service_role;
create function pg_temp.original(checkout text,amount integer,tx text,event uuid,payer text) returns jsonb language plpgsql security invoker as $$
declare receipt jsonb;begin
 perform public.admit_trusted_sms_gateway_evidence('99968000-0000-4000-8000-000000000510',gen_random_uuid(),
  clock_timestamp()-interval '1 second',clock_timestamp()+interval '2 minutes','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=',
  jsonb_build_object('protocol','africlub.receiver-settlement.v1','eventId',event,'checkoutReference',checkout,
  'providerTransactionId',tx,'receiver','12345','provider','mtn_rwanda','country','RW','currency','RWF','amount',amount,
  'settledAt',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'payerAccountDigest',encode(extensions.digest('africlub-payer-v1:mtn_rwanda:RW:'||payer,'sha256'),'hex'),
  'settlementStatus','settled','settlementRecordId','synthetic-source-'||event,'settlementRecordDigest',repeat('a',64)));
 receipt:=public.process_trusted_sms_gateway_evidence(event);
 set constraints all immediate; set constraints all deferred;
 return receipt;
end; $$;
create function pg_temp.issue(event uuid,amount integer) returns jsonb language plpgsql security invoker as $$
declare receipt jsonb;begin
 perform pg_temp.actor(1);
 receipt:=public.admin_prepare_payment_refund(9996801,event,amount,'membership_adjustment',gen_random_uuid());
 perform pg_temp.actor(2);
 perform public.admin_review_payment_refund((receipt->>'id')::uuid,9996801,1,true,gen_random_uuid());
 perform pg_temp.actor(1);
 return public.admin_dispatch_payment_refund((receipt->>'id')::uuid,9996801,gen_random_uuid());
end; $$;
create function pg_temp.return_cash(receipt jsonb,amount integer,tx text,event uuid) returns jsonb language plpgsql security invoker as $$
declare p jsonb:=receipt->'payment';begin
 perform public.admit_trusted_payment_refund_evidence('99968000-0000-4000-8000-000000000510',gen_random_uuid(),
  clock_timestamp()-interval '1 second',clock_timestamp()+interval '2 minutes','bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=',
  jsonb_build_object('protocol','africlub.receiver-refund-settlement.v1','eventId',event,'refundId',receipt->>'id',
  'instructionId',receipt->>'instruction_id','originalPaymentEventId',p->>'event_id',
  'originalProviderTransactionId',p->>'provider_transaction_id','originalSettlementRecordId',p->>'settlement_record_id',
  'receiver',p->>'receiver','provider',p->>'provider','country',p->>'country','currency',p->>'currency','amount',amount,
  'providerRefundTransactionId',tx,'settlementRecordId','synthetic-refund-'||event,'settlementRecordDigest',repeat('b',64),
  'settlementStatus','settled','settledAt',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')));
 return public.process_trusted_payment_refund_evidence(event);
end; $$;
grant execute on function pg_temp.original(text,integer,text,uuid,text),pg_temp.return_cash(jsonb,integer,text,uuid) to service_role;
grant execute on function pg_temp.issue(uuid,integer) to authenticated;
select pg_temp.actor(4);set local role authenticated;
insert into entitlement_receipts values('membership1',public.prepare_membership_payment_for_club('imena',9996801));
reset role;select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.original((select payment_intent_id::text from public.membership_payment_orders where id=(select (body->>'id')::uuid from entitlement_receipts where label='membership1')),1000,'MEMBERSHIP-ORIGINAL-1','99968000-0000-4000-8000-000000000701','250799968004');
reset role;
select is((select status from public.fan_memberships where user_id='99968000-0000-4000-8000-000000000004'),'active','actual original membership payment activates entitlement');
select pg_temp.actor(1);set local role authenticated;
insert into entitlement_receipts values('membership_refund1',pg_temp.issue('99968000-0000-4000-8000-000000000701',1000));
reset role;select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.return_cash((select body from entitlement_receipts where label='membership_refund1'),400,'MEMBERSHIP-RETURN-1','99968000-0000-4000-8000-000000000711');
reset role;
select is((select status from public.fan_memberships where user_id='99968000-0000-4000-8000-000000000004'),'active','partial cash return never removes paid membership');
-- A later genuinely matched renewal supersedes this original payment's entitlement.
select pg_temp.actor(4);set local role authenticated;
insert into entitlement_receipts values('membership2',public.prepare_membership_payment_for_club('imena',9996801));
reset role;select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.original((select payment_intent_id::text from public.membership_payment_orders where id=(select (body->>'id')::uuid from entitlement_receipts where label='membership2')),1000,'MEMBERSHIP-ORIGINAL-2','99968000-0000-4000-8000-000000000702','250799968004');
reset role;
select is((select count(distinct activated_at)::integer from public.membership_payment_orders where user_id='99968000-0000-4000-8000-000000000004'),1,'actual paid renewals share the transaction timestamp; it cannot order entitlement');
select is((select payment_order_id from public.payment_refund_membership_activations where subject_id='99968000-0000-4000-8000-000000000004' order by activation_sequence desc limit 1),
 (select (body->>'id')::uuid from entitlement_receipts where label='membership2'),'actual activation sequence binds latest paid renewal');
select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.return_cash((select body from entitlement_receipts where label='membership_refund1'),600,'MEMBERSHIP-RETURN-2','99968000-0000-4000-8000-000000000712');
reset role;
select is((select status from public.fan_memberships where user_id='99968000-0000-4000-8000-000000000004'),'active','full older refund cannot remove later paid renewal');
select is((select result->>'membership' from public.payment_refund_consequences where payment_event_id='99968000-0000-4000-8000-000000000701'),'later_paid_membership_retained','immutable consequence records superseding entitlement');
select pg_temp.actor(1);set local role authenticated;
insert into entitlement_receipts values('membership_refund2',pg_temp.issue('99968000-0000-4000-8000-000000000702',1000));
reset role;select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.return_cash((select body from entitlement_receipts where label='membership_refund2'),1000,'MEMBERSHIP-RETURN-3','99968000-0000-4000-8000-000000000713');
select is(public.process_trusted_payment_refund_evidence('99968000-0000-4000-8000-000000000713')->>'replay','true','latest membership return replays original provider receipt');
reset role;
select is((select status from public.fan_memberships where user_id='99968000-0000-4000-8000-000000000004'),'suspended','approved full current refund suspends only current entitlement');
select is((select count(*)::integer from public.membership_payment_orders where user_id='99968000-0000-4000-8000-000000000004' and activated_at is not null),2,'both original paid membership records stay retained');
select throws_ok($$update public.payment_refund_membership_activations set membership_id=gen_random_uuid()$$,'P0001','REFUND_RECORD_IMMUTABLE','activation binding is immutable even for database owner');
select ok(not has_table_privilege('authenticated','public.payment_refund_membership_activations','INSERT')
 and not has_function_privilege('authenticated','public.payment_refund_record_membership_activation()','EXECUTE')
 and not has_function_privilege('service_role','public.payment_refund_record_membership_activation()','EXECUTE'),'activation journal has no client setter or public definer execution');
select ok(exists(select 1 from public.account_erasure_fk_inventory i join pg_constraint c on c.oid=i.constraint_oid
 where c.conrelid='public.payment_refund_membership_activations'::regclass and c.confrelid='auth.users'::regclass
 and i.retained and c.confdeltype='r'),'activation subject binding is retained with restrictive account erasure inventory');
-- Represent an activation preceding migration 25 by disabling only its new
-- journal trigger. The payment still uses real ingress, allocation and deferred
-- activation; no money or timestamp is fabricated to guess historical order.
alter table public.membership_payment_orders disable trigger refund_paid_membership_activation;
select pg_temp.actor(3);set local role authenticated;
insert into entitlement_receipts values('membership_unbound',public.prepare_membership_payment_for_club('imena',9996801));
reset role;select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.original((select payment_intent_id::text from public.membership_payment_orders where id=(select (body->>'id')::uuid from entitlement_receipts where label='membership_unbound')),1000,'MEMBERSHIP-ORIGINAL-UNBOUND','99968000-0000-4000-8000-000000000704','250799968003');
reset role;
alter table public.membership_payment_orders enable trigger refund_paid_membership_activation;
select pg_temp.actor(1);set local role authenticated;
insert into entitlement_receipts values('membership_refund_unbound',pg_temp.issue('99968000-0000-4000-8000-000000000704',1000));
reset role;select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.return_cash((select body from entitlement_receipts where label='membership_refund_unbound'),1000,'MEMBERSHIP-RETURN-UNBOUND','99968000-0000-4000-8000-000000000716');
reset role;
select is((select status from public.fan_memberships where user_id='99968000-0000-4000-8000-000000000003'),'active','ambiguous pre-migration paid history cannot revoke membership');
select is((select result->>'membership' from public.payment_refund_consequences where payment_event_id='99968000-0000-4000-8000-000000000704'),'retained_unresolved_membership_binding','unresolved history records truthful retained entitlement consequence');
select is((select count(*)::integer from public.payment_refund_membership_activations),2,'historical activation has no invented journal record');
-- Ticket bundle confirmation uses exact original provider reference attestation.
insert into public.matches(id,club_id,partner_id,home_team,away_team,competition,venue,match_date,kickoff_time,capacity,ticket_general_price)
 values('99968000-0000-4000-8000-000000000200',9996801,'99968000-0000-4000-8000-000000000100','Refund QA','Synthetic opponent','QA league','QA stadium',current_date+3,'15:00',100,1000);
insert into public.tickets(id,match_id,user_id,club_id,seat_type,amount_paid,momo_reference,status)
 select ('99968000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'99968000-0000-4000-8000-000000000200',
 '99968000-0000-4000-8000-000000000003',9996801,'general',1000,'REFUND-TICKET-ORIGINAL-1','pending' from generate_series(801,802)n;
insert into public.pending_transactions(user_id,reference,recipient_momo,provider,amount)
 values('99968000-0000-4000-8000-000000000003','REFUND-TICKET-ORIGINAL-1','12345','mtn_rwanda',2000);
select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.original('REFUND-TICKET-ORIGINAL-1',2000,'REFUND-TICKET-ORIGINAL-1','99968000-0000-4000-8000-000000000703','250799968003');
reset role;
select is((select count(*)::integer from public.tickets where club_id=9996801 and status='valid'),2,'actual original provider payment confirms whole ticket bundle');
update public.tickets set status='used' where id='99968000-0000-4000-8000-000000000801';
select pg_temp.actor(1);set local role authenticated;
insert into entitlement_receipts values('ticket_refund',pg_temp.issue('99968000-0000-4000-8000-000000000703',2000));
reset role;select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.return_cash((select body from entitlement_receipts where label='ticket_refund'),500,'TICKET-RETURN-1','99968000-0000-4000-8000-000000000714');
reset role;
select is((select status from public.tickets where id='99968000-0000-4000-8000-000000000802'),'valid','partial bundle refund does not revoke admission');
select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select pg_temp.return_cash((select body from entitlement_receipts where label='ticket_refund'),1500,'TICKET-RETURN-2','99968000-0000-4000-8000-000000000715');
select is(public.process_trusted_payment_refund_evidence('99968000-0000-4000-8000-000000000715')->>'replay','true','bundle return and admission consequences replay once');
reset role;
select is((select status from public.tickets where id='99968000-0000-4000-8000-000000000802'),'refunded','full approved bundle return revokes unused admission');
select is((select status from public.tickets where id='99968000-0000-4000-8000-000000000801'),'used','full bundle return retains actual used admission history');
select is((select count(*)::integer from public.momo_ledger_entries where club_id=9996801 and ledger_status='posted'),5,'original shop/membership/ticket debits remain unchanged');
select is((select sum(amount)::integer from public.payment_refund_compensations where club_id=9996801),5000,'all immutable cash credits tie to exactly refunded original amounts');
select * from finish();rollback;

begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
-- BEGIN REFUND CONCURRENCY FIXTURE: synthetic local proof, no provider acceptance.
insert into public.african_football_clubs(id,club_name,country_name,club_slug,currency_code,country_iso_code,momo_ussd_template)
 overriding system value values(9996701,'Refund QA','Rwanda','refund-qa','RWF','RW','*182*8*1*{amount}*{recipient}#'),
 (9996702,'Foreign Refund QA','Rwanda','foreign-refund-qa','RWF','RW','*182*8*1*{amount}*{recipient}#');
insert into public.partners(id,name,slug,is_active) values('99967000-0000-4000-8000-000000000100','Refund QA','refund-qa',true);
insert into auth.users(id,aud,role,is_anonymous,phone_confirmed_at,phone) values
 ('99967000-0000-4000-8000-000000000001','authenticated','authenticated',false,now(),'+250799967001'),
 ('99967000-0000-4000-8000-000000000002','authenticated','authenticated',false,now(),'+250799967002'),
 ('99967000-0000-4000-8000-000000000003','authenticated','authenticated',false,now(),'+250799967003'),
 ('99967000-0000-4000-8000-000000000004','authenticated','authenticated',false,now(),'+250799967004');
insert into public.users(id,phone,full_name) values
 ('99967000-0000-4000-8000-000000000001','+250799967001','Refund maker'),
 ('99967000-0000-4000-8000-000000000002','+250799967002','Refund checker'),
 ('99967000-0000-4000-8000-000000000003','+250799967003','Refund payer'),
 ('99967000-0000-4000-8000-000000000004','+250799967004','Club operator');
insert into public.profiles(id,club_id) select id,9996701 from auth.users where id::text like '99967000-%';
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99967000-0000-4000-8000-000000000001','super_admin',null),
 ('99967000-0000-4000-8000-000000000002','admin',null),
 ('99967000-0000-4000-8000-000000000004','club_admin',9996701);
insert into public.fan_memberships(user_id,club_id,partner_id,tier,membership_number,payment_status,status,expires_at)
 values('99967000-0000-4000-8000-000000000003',9996701,'99967000-0000-4000-8000-000000000100','gold','REFUND-QA','verified','active',now()+interval '1 year');
insert into public.shop_products(id,club_id,partner_id,name,category,price,stock,is_active,currency)
 values('99967000-0000-4000-8000-000000000110',9996701,'99967000-0000-4000-8000-000000000100','QA Shirt','shirt',1250,20,true,'RWF');
insert into public.partner_payment_routes(id,club_id,partner_id,country,provider,recipient_code,reconciliation_label,status)
 values('99967000-0000-4000-8000-000000000120',9996701,'99967000-0000-4000-8000-000000000100','RW','mtn','12345','Refund QA','active');
insert into public.payment_receiver_accounts(id,partner_id,payee_number_or_code,purpose,is_active)
 values('99967000-0000-4000-8000-000000000130','99967000-0000-4000-8000-000000000100','12345','club_shop',true);
create function pg_temp.actor(n integer,aal text default 'aal2') returns text language plpgsql as $$
declare subject text:='99967000-0000-4000-8000-'||lpad(n::text,12,'0');begin
 perform set_config('request.jwt.claim.sub',subject,true);
 return set_config('request.jwt.claims',jsonb_build_object('sub',subject,'role','authenticated','is_anonymous',false,
  'club_id',9996701,'aal',aal,'exp',floor(extract(epoch from clock_timestamp()))::bigint+3600,
  'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',floor(extract(epoch from clock_timestamp()))::bigint)))::text,true);
end; $$;
grant execute on function pg_temp.actor(integer,text) to authenticated;
select pg_temp.actor(3);
set local role authenticated;
select public.prepare_shop_checkout_for_club('[{"product_id":"99967000-0000-4000-8000-000000000110","quantity":2}]','Synthetic QA Kigali delivery address',
 'order-99967000-0000-4000-8000-000000000201',9996701);
reset role;
insert into public.trusted_sms_gateways(id,receiver_account_id,club_id,provider,country,currency,enabled,source_review_reference,provider_acceptance_reference)
 values('99967000-0000-4000-8000-000000000500','99967000-0000-4000-8000-000000000130',9996701,'mtn_rwanda','RW','RWF',true,
 'synthetic-payment-source-review','synthetic-payment-provider-acceptance');
insert into public.trusted_sms_gateway_keys(id,gateway_id,secret_env_name,enabled,expires_at)
 values('99967000-0000-4000-8000-000000000510','99967000-0000-4000-8000-000000000500','SMS_GATEWAY_KEY_REFUND_QA',true,now()+interval '1 day');
update public.trusted_sms_ingress_config set enabled=true where id;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select public.admit_trusted_sms_gateway_evidence('99967000-0000-4000-8000-000000000510','99967000-0000-4000-8000-000000000530',
 clock_timestamp()-interval '1 second',clock_timestamp()+interval '2 minutes','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=',
 jsonb_build_object('protocol','africlub.receiver-settlement.v1','eventId','99967000-0000-4000-8000-000000000520',
 'checkoutReference','order-99967000-0000-4000-8000-000000000201','providerTransactionId','SYNTHETIC-ORIGINAL-TX-201',
 'receiver','12345','provider','mtn_rwanda','country','RW','currency','RWF','amount',2500,
 'settledAt',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
 'payerAccountDigest',encode(extensions.digest('africlub-payer-v1:mtn_rwanda:RW:250799967003','sha256'),'hex'),
 'settlementStatus','settled','settlementRecordId','synthetic-original-statement-201','settlementRecordDigest',repeat('a',64)));
select public.process_trusted_sms_gateway_evidence('99967000-0000-4000-8000-000000000520');
reset role;
-- END REFUND CONCURRENCY FIXTURE. The original paid event is now immutable.
create temporary table refund_receipts(label text primary key,body jsonb);
grant all on refund_receipts to authenticated,service_role;
create function pg_temp.prepare(amount integer default 2500,op uuid default '99967000-0000-4000-8000-000000000601') returns jsonb language sql security invoker as $$
 select public.admin_prepare_payment_refund(9996701,'99967000-0000-4000-8000-000000000520',amount,'cancelled_order',op);
$$;
create function pg_temp.review(approve boolean default true,op uuid default '99967000-0000-4000-8000-000000000602') returns jsonb language sql security invoker as $$
 select public.admin_review_payment_refund((select (body->>'id')::uuid from refund_receipts where label='prepared'),9996701,1,approve,op);
$$;
create function pg_temp.dispatch(op uuid default '99967000-0000-4000-8000-000000000603') returns jsonb language sql security invoker as $$
 select public.admin_dispatch_payment_refund((select (body->>'id')::uuid from refund_receipts where label='prepared'),9996701,op);
$$;
grant execute on function pg_temp.prepare(integer,uuid),pg_temp.review(boolean,uuid),pg_temp.dispatch(uuid) to authenticated;
select ok(not has_table_privilege('service_role','public.payment_refund_gateway_approvals','update'),'ingress cannot self-enable refund acceptance');
select ok(not has_function_privilege('authenticated','public.admit_trusted_payment_refund_evidence(uuid,uuid,timestamptz,timestamptz,text,jsonb)','execute'),'supporter cannot attest a provider refund');
select ok(not has_function_privilege('authenticated','public.payment_refund_receipt(uuid)','execute'),'arbitrary-subject projection is private');
select is((select count(*)::integer from public.payment_refund_gateway_approvals),0,'no provider refund acceptance is seeded');
select pg_temp.actor(4);set local role authenticated;
select throws_ok($$select pg_temp.prepare()$$,'42501','REFUND_GLOBAL_ADMIN_REQUIRED','club operator cannot initiate cash refund');
reset role;select pg_temp.actor(1,'aal1');set local role authenticated;
select throws_ok($$select pg_temp.prepare()$$,'42501','STAFF_STEP_UP_REQUIRED','global assignment alone cannot issue refund');
reset role;select pg_temp.actor(1);set local role authenticated;
insert into refund_receipts values('prepared',pg_temp.prepare());
select is(pg_temp.prepare(),(select body from refund_receipts where label='prepared'),'lost preparation response returns original receipt and instruction ID');
select is(public.admin_recover_payment_refund_operation(9996701,'99967000-0000-4000-8000-000000000601'),(select body from refund_receipts where label='prepared'),'relaunch uses original operation key');
select throws_ok($$select pg_temp.prepare(2499)$$,'P0001','REFUND_OPERATION_BINDING_MISMATCH','same key cannot silently change requested amount');
select throws_ok($$select pg_temp.prepare(1,'99967000-0000-4000-8000-000000000609')$$,'P0001','REFUND_AMOUNT_RESERVED','pending review reserves full original payment');
select throws_ok($$select pg_temp.review()$$,'P0001','REFUND_DISTINCT_CHECKER_REQUIRED','maker cannot check own instruction');
select throws_ok($$select public.admin_prepare_payment_refund(9996702,'99967000-0000-4000-8000-000000000520',1,'cancelled_order','99967000-0000-4000-8000-000000000610')$$,'P0001','REFUND_PAYMENT_NOT_FOUND','wrong requested tenant cannot bind original payment');
reset role;select pg_temp.actor(2);set local role authenticated;
select is(public.admin_recover_payment_refund_operation(9996701,'99967000-0000-4000-8000-000000000601'),null::jsonb,'another global actor cannot recover maker operation');
select throws_ok($$select pg_temp.review()$$,'P0001','REFUND_CAPABILITY_CLOSED','distinct checker cannot assume provider approval');
reset role;
insert into public.payment_refund_gateway_approvals(gateway_id,enabled,policy_version,source_review_reference,provider_acceptance_reference,terms_reference,shop_stock_policy)
 values('99967000-0000-4000-8000-000000000500',true,'synthetic-local-v1','synthetic-refund-source-review','synthetic-refund-provider-acceptance','synthetic-refund-contract-terms','restore_unfulfilled');
select pg_temp.actor(2);set local role authenticated;
insert into refund_receipts values('approved',pg_temp.review());
select is((select body->>'status' from refund_receipts where label='approved'),'approved','current distinct checker approves exact frozen amount');
select is(pg_temp.review(),(select body from refund_receipts where label='approved'),'lost review response recovers original decision');
reset role;
-- REFUND APPROVED RACE FIXTURE READY: commit this prefix for actual lock-wait probes.
update public.payment_receiver_accounts set is_active=false where id='99967000-0000-4000-8000-000000000130';
select pg_temp.actor(1);set local role authenticated;
select throws_ok($$select pg_temp.dispatch()$$,'P0001','REFUND_RECEIVER_CHANGED','revoked receiver cannot issue an approved instruction');
reset role;
update public.payment_receiver_accounts set is_active=true where id='99967000-0000-4000-8000-000000000130';
update public.african_football_clubs set currency_code='USD' where id=9996701;
select pg_temp.actor(1);set local role authenticated;
select throws_ok($$select pg_temp.dispatch()$$,'P0001','REFUND_RECEIVER_CHANGED','changed club currency requires original money authority');
reset role;update public.african_football_clubs set currency_code='RWF' where id=9996701;
update public.payment_refund_gateway_approvals set policy_version='changed-synthetic-v2';
select pg_temp.actor(1);set local role authenticated;
select throws_ok($$select pg_temp.dispatch()$$,'P0001','REFUND_APPROVAL_CHANGED','changed accepted terms require a new review');
reset role;update public.payment_refund_gateway_approvals set policy_version='synthetic-local-v1';
select pg_temp.actor(1);set local role authenticated;
insert into refund_receipts values('dispatched',pg_temp.dispatch());
select is(pg_temp.dispatch(),(select body from refund_receipts where label='dispatched'),'lost issue response never creates a second instruction');
select is((select body->>'status' from refund_receipts where label='dispatched'),'pending','instruction issuance never claims provider cash refund');
reset role;
select is((select count(*)::integer from public.payment_refund_instructions),1,'one original key binds one provider instruction');
select is((select count(*)::integer from public.payment_refund_compensations),0,'review and instruction are financially inert');
insert into refund_receipts select 'original_order_receipt',payment_receipt from public.shop_orders where club_id=9996701;
select is((select count(*)::integer from public.admin_audit_log where club_id=9996701 and action like 'payment_refund.%'),3,'prepare/check/issue have one attributed audit each');
select throws_ok($$update public.payment_refund_requests set amount=1$$,'P0001','REFUND_RECORD_IMMUTABLE','request financial snapshot cannot change');
select throws_ok($$update public.payment_refund_instructions set instruction='{}'$$,'P0001','REFUND_RECORD_IMMUTABLE','issued instruction is immutable');
select throws_ok($$delete from public.payment_refund_operations$$,'P0001','REFUND_RECORD_IMMUTABLE','recovery identity cannot be deleted');

create function pg_temp.refund_evidence(patch jsonb default '{}') returns jsonb language sql as $$
 select jsonb_build_object('protocol','africlub.receiver-refund-settlement.v1','eventId','99967000-0000-4000-8000-000000000620',
 'refundId',body->>'id','instructionId',body->>'instruction_id','originalPaymentEventId','99967000-0000-4000-8000-000000000520',
 'originalProviderTransactionId','SYNTHETIC-ORIGINAL-TX-201','originalSettlementRecordId','synthetic-original-statement-201',
 'receiver','12345','provider','mtn_rwanda','country','RW','currency','RWF','amount',1000,
 'providerRefundTransactionId','SYNTHETIC-REFUND-TX-1','settlementRecordId','synthetic-refund-row-1','settlementRecordDigest',repeat('b',64),
 'settlementStatus','settled','settledAt',to_char(transaction_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'))||patch from refund_receipts where label='prepared';
$$;
create function pg_temp.admit(p jsonb,nonce uuid default '99967000-0000-4000-8000-000000000630') returns jsonb language sql security invoker as $$
 select public.admit_trusted_payment_refund_evidence('99967000-0000-4000-8000-000000000510',nonce,
 clock_timestamp()-interval '1 second',clock_timestamp()+interval '2 minutes','bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=',p);
$$;
grant execute on function pg_temp.refund_evidence(jsonb),pg_temp.admit(jsonb,uuid) to service_role;
select set_config('request.jwt.claim.sub','',true);select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
select throws_ok($$select pg_temp.admit(pg_temp.refund_evidence('{"receiver":"67890"}'))$$,'P0001','REFUND_INSTRUCTION_BINDING_MISMATCH','changed receiver cannot redirect provider refund');
select throws_ok($$select pg_temp.admit(pg_temp.refund_evidence('{"originalProviderTransactionId":"foreign"}'))$$,'P0001','REFUND_INSTRUCTION_BINDING_MISMATCH','refund must reference exact original provider payment');
select throws_ok($$select pg_temp.admit(pg_temp.refund_evidence('{"currency":"USD"}'))$$,'P0001','REFUND_INSTRUCTION_BINDING_MISMATCH','refund currency cannot relabel original money');
select throws_ok($$select pg_temp.admit(pg_temp.refund_evidence('{"payerPhone":"+250799967003"}'))$$,'P0001','REFUND_INVALID_EVIDENCE','caller cannot supply a new refund recipient');
select throws_ok($$select pg_temp.admit(pg_temp.refund_evidence('{"settlementStatus":"failed","amount":1}'))$$,'P0001','REFUND_INVALID_EVIDENCE','failure is never a settled amount');
insert into refund_receipts values('admitted',pg_temp.admit(pg_temp.refund_evidence()));
select is(pg_temp.admit(pg_temp.refund_evidence())->>'replay','true','duplicate signed evidence recovers original event');
reset role;
create function pg_temp.fail_refund_completion() returns trigger language plpgsql as $$begin
 if new.completed_at is not null then raise exception 'SYNTHETIC_REFUND_COMPLETION_FAILURE'; end if;return new;end $$;
create trigger qa_refund_completion_failure before update on public.payment_refund_evidence for each row execute function pg_temp.fail_refund_completion();
set local role service_role;
select throws_ok($$select public.process_trusted_payment_refund_evidence('99967000-0000-4000-8000-000000000620')$$,'P0001','SYNTHETIC_REFUND_COMPLETION_FAILURE','late final failure rolls back compensation and outcome together');
reset role;
select is((select count(*)::integer from public.payment_refund_compensations),0,'failed final acknowledgement leaves no partial credit');
select is((select confirmed_amount from public.payment_refund_requests),0,'failed final acknowledgement preserves original pending amount');
drop trigger qa_refund_completion_failure on public.payment_refund_evidence;
set local role service_role;
insert into refund_receipts values('partial',public.process_trusted_payment_refund_evidence('99967000-0000-4000-8000-000000000620'));
select is((select body->>'status' from refund_receipts where label='partial'),'partially_refunded','partial confirmed return is explicit');
select is((select body->>'confirmed_amount' from refund_receipts where label='partial'),'1000','only exact trusted settled amount is credited');
select is(public.process_trusted_payment_refund_evidence('99967000-0000-4000-8000-000000000620')->>'replay','true','response loss replays immutable original credit receipt');
reset role;
select is((select stock from public.shop_products where club_id=9996701),18,'partial refund does not restore stock');
select is((select status from public.fan_memberships where user_id='99967000-0000-4000-8000-000000000003'),'active','partial refund does not remove existing membership entitlement');
select is((select count(*)::integer from public.payment_refund_compensations),1,'duplicate evidence cannot create a second compensation');
select is((select count(*)::integer from public.momo_ledger_entries where club_id=9996701),1,'original debit remains intact');
-- Closed financial subjects remain addressable through retained keys.
insert into public.account_erasure_jobs(user_id) values('99967000-0000-4000-8000-000000000003');
set local role service_role;
select pg_temp.admit(pg_temp.refund_evidence('{"eventId":"99967000-0000-4000-8000-000000000621","settlementStatus":"unknown","amount":0,"providerRefundTransactionId":"SYNTHETIC-REFUND-TX-2","settlementRecordId":"synthetic-refund-row-2"}'),
 '99967000-0000-4000-8000-000000000631');
select is(public.process_trusted_payment_refund_evidence('99967000-0000-4000-8000-000000000621')->>'confirmed_amount','1000','unknown acknowledgement preserves prior partial amount');
select pg_temp.admit(pg_temp.refund_evidence('{"eventId":"99967000-0000-4000-8000-000000000622","amount":1500,"providerRefundTransactionId":"SYNTHETIC-REFUND-TX-2","settlementRecordId":"synthetic-refund-row-3"}'),
 '99967000-0000-4000-8000-000000000632');
reset role;
create function pg_temp.expire_refund_key_at_consequence() returns trigger language plpgsql security definer set search_path='' as $$begin
 if new.status='cancelled' then update public.trusted_sms_gateway_keys set not_before=clock_timestamp()-interval '2 days',
 expires_at=clock_timestamp()-interval '1 second' where id='99967000-0000-4000-8000-000000000510';end if;return new;end $$;
create trigger qa_refund_key_expiry before update on public.shop_orders for each row execute function pg_temp.expire_refund_key_at_consequence();
set local role service_role;
select throws_ok($$select public.process_trusted_payment_refund_evidence('99967000-0000-4000-8000-000000000622')$$,'42501','REFUND_CAPABILITY_CLOSED','key expiry after consequence authority rejects whole final refund');
reset role;
select is((select sum(amount)::integer from public.payment_refund_compensations),1000,'post-consequence expiry rolls back new financial credit');
select is((select stock from public.shop_products where club_id=9996701),18,'post-consequence expiry rolls back stock restoration');
select is((select status from public.shop_orders where club_id=9996701),'paid','post-consequence expiry retains original fulfillment state');
drop trigger qa_refund_key_expiry on public.shop_orders;
set local role service_role;
insert into refund_receipts values('full',public.process_trusted_payment_refund_evidence('99967000-0000-4000-8000-000000000622'));
select is((select body->>'status' from refund_receipts where label='full'),'refunded','late trusted provider completion reconciles same pending instruction');
select is((select body->>'confirmed_amount' from refund_receipts where label='full'),'2500','partial returns never exceed original approved amount');
select is(public.process_trusted_payment_refund_evidence('99967000-0000-4000-8000-000000000622')->>'replay','true','completion replay cannot repeat stock or refund');
reset role;
select is((select stock from public.shop_products where club_id=9996701),20,'approved full unfulfilled return restores stock exactly once');
select is((select status from public.shop_orders where club_id=9996701),'cancelled','approved full unfulfilled refund closes fulfillment');
select is((select count(*)::integer from public.payment_refund_compensations),2,'two actual partial settlements have two immutable credits');
select is((select count(*)::integer from public.payment_refund_consequences),1,'full financial consequence is recorded once');
select is((select sum(amount)::integer from public.payment_refund_compensations),2500,'compensation total ties to original posted amount');
select is((select payment_receipt from public.shop_orders where club_id=9996701),(select body from refund_receipts where label='original_order_receipt'),'refund leaves immutable original checkout receipt intact');
select throws_ok($$update public.payment_refund_compensations set amount=1$$,'P0001','REFUND_RECORD_IMMUTABLE','compensating credit is immutable');
select ok(not exists(select 1 from pg_constraint c where c.contype='f' and c.conrelid::regclass::text like 'payment_refund_%'
 and c.confrelid='auth.users'::regclass and (c.confdeltype<>'r' or not exists(select 1 from public.account_erasure_fk_inventory i where i.constraint_oid=c.oid and i.retained))),
 'every refund subject/actor FK is retained RESTRICT and inventoried');
select pg_temp.actor(1);set local role authenticated;
select is(public.admin_payment_refund_dashboard(9996701)->'requests'->0->>'status','refunded','actual status readback survives subject closure');
reset role;
insert into public.account_erasure_jobs(user_id) values('99967000-0000-4000-8000-000000000001');
set local role authenticated;
select throws_ok($$select public.admin_recover_payment_refund_operation(9996701,'99967000-0000-4000-8000-000000000601')$$,'42501','STAFF_STEP_UP_REQUIRED','closed human operator cannot replay privileged command');
reset role;
select * from finish();
rollback;

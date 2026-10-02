begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select ok(not has_function_privilege('authenticated','public.admit_trusted_sms_gateway_evidence(uuid,uuid,timestamptz,timestamptz,text,jsonb)','execute'),'supporter cannot admit settlement records');
select ok(not has_function_privilege('anon','public.process_trusted_sms_gateway_evidence(uuid)','execute'),'anonymous cannot process settlement records');
select ok(not has_table_privilege('authenticated','public.momo_sms_raw','insert'),'supporter raw insertion is closed');
select ok(not has_table_privilege('authenticated','public.momo_sms_raw','update'),'supporter raw rewrite is closed');
select ok(not has_table_privilege('authenticated','public.momo_sms_raw','delete'),'supporter raw removal is closed');
select is((select count(*)::integer from pg_policies where schemaname='public' and tablename='momo_sms_raw' and permissive='PERMISSIVE' and cmd in ('INSERT','UPDATE','DELETE','ALL')),0,'no permissive supporter evidence write policies remain');
select ok(not has_table_privilege('service_role','public.trusted_sms_gateways','update'),'Edge cannot self-provision approval');
select is((select enabled from public.trusted_sms_ingress_config where id),false,'authoritative ingestion is closed by default');
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
 values('99966000-0000-4000-8000-000000000001',9996601,'99966000-0000-4000-8000-000000000100','gold','RECEIPT-QA','verified','active',now()+interval '1 year');
insert into public.shop_products(id,club_id,partner_id,name,category,price,stock,is_active,currency)
 values('99966000-0000-4000-8000-000000000110',9996601,'99966000-0000-4000-8000-000000000100','QA Shirt','shirt',1250,20,true,'RWF');
insert into public.partner_payment_routes(id,club_id,partner_id,country,provider,recipient_code,reconciliation_label,status)
 values('99966000-0000-4000-8000-000000000120',9996601,'99966000-0000-4000-8000-000000000100','RW','mtn','12345','Gateway QA','active');
insert into public.payment_receiver_accounts(id,partner_id,payee_number_or_code,purpose,is_active)
 values('99966000-0000-4000-8000-000000000130','99966000-0000-4000-8000-000000000100','12345','club_shop',true);
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
select throws_ok($$insert into public.trusted_sms_gateways(id,receiver_account_id,club_id,provider,country,currency,enabled)
 values('99966000-0000-4000-8000-000000000599','99966000-0000-4000-8000-000000000130',9996601,'mtn_rwanda','RW','RWF',true)$$,'23514',null,'missing review references cannot enable a gateway');
insert into public.trusted_sms_gateway_keys(id,gateway_id,secret_env_name,enabled,expires_at)
 values('99966000-0000-4000-8000-000000000510','99966000-0000-4000-8000-000000000500','SMS_GATEWAY_KEY_QA',true,now()+interval '1 day');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select is(public.get_trusted_sms_gateway_key('99966000-0000-4000-8000-000000000510'),null::jsonb,'unaccepted source stays unavailable');
reset role;
update public.trusted_sms_gateways set enabled=true where id='99966000-0000-4000-8000-000000000500';
update public.trusted_sms_ingress_config set enabled=true where id;
create function pg_temp.evidence(p_patch jsonb default '{}') returns jsonb language sql as $$
 select jsonb_build_object('protocol','africlub.receiver-settlement.v1','eventId','99966000-0000-4000-8000-000000000520',
 'checkoutReference','order-99966000-0000-4000-8000-000000000201','providerTransactionId','SYNTHETIC-GATEWAY-TX-201',
 'receiver','12345','provider','mtn_rwanda','country','RW','currency','RWF','amount',2500,
 'settledAt',to_char(clock_timestamp() at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
 'payerAccountDigest','1c0926b20c42ad64dbf0c8355f40ad8bd7546775f74183598cc5fb27a494c151',
 'settlementStatus','settled','settlementRecordId','synthetic-receiver-statement-row-201','settlementRecordDigest',repeat('a',64))||p_patch;
$$;
create function pg_temp.admit(p_evidence jsonb,p_nonce uuid default '99966000-0000-4000-8000-000000000530',p_digest text default 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=') returns jsonb language sql security invoker as $$
 select public.admit_trusted_sms_gateway_evidence('99966000-0000-4000-8000-000000000510',p_nonce,
 clock_timestamp()-interval '1 second',clock_timestamp()+interval '2 minutes',p_digest,p_evidence);
$$;
grant execute on function pg_temp.evidence(jsonb),pg_temp.admit(jsonb,uuid,text) to service_role,authenticated;
create temporary table evidence_receipts(label text primary key,body jsonb);
grant all on evidence_receipts to service_role;
set local role service_role;
select is(public.get_trusted_sms_gateway_key('99966000-0000-4000-8000-000000000510')->>'club_id','9996601','provisioned key binds exact server tenant');
select throws_ok($$select pg_temp.admit(pg_temp.evidence('{"receiver":"67890"}'))$$,'P0001','GATEWAY_RECEIVER_BINDING_MISMATCH','wrong receiver cannot repair evidence');
select throws_ok($$select pg_temp.admit(pg_temp.evidence('{"provider":"airtel"}'))$$,'P0001','GATEWAY_RECEIVER_BINDING_MISMATCH','wrong provider denied');
select throws_ok($$select pg_temp.admit(pg_temp.evidence('{"country":"UG"}'))$$,'P0001','GATEWAY_RECEIVER_BINDING_MISMATCH','wrong country denied');
select throws_ok($$select pg_temp.admit(pg_temp.evidence('{"currency":"USD"}'))$$,'P0001','GATEWAY_RECEIVER_BINDING_MISMATCH','wrong currency denied');
select throws_ok($$select pg_temp.admit(pg_temp.evidence('{"amount":2499}'))$$,'P0001','GATEWAY_CHECKOUT_BINDING_MISMATCH','amount does not choose an equal-priced payer');
select throws_ok($$select pg_temp.admit(pg_temp.evidence('{"checkoutReference":"unknown-order"}'))$$,'P0001','GATEWAY_CHECKOUT_NOT_FOUND','missing exact target cannot auto-match');
select throws_ok($$select pg_temp.admit(pg_temp.evidence('{"userId":"99966000-0000-4000-8000-000000000002"}'))$$,'P0001','GATEWAY_INVALID_EVIDENCE','caller-selected payer field rejected');
select throws_ok($$select pg_temp.admit(pg_temp.evidence('{"settlementStatus":"pending"}'))$$,'P0001','GATEWAY_INVALID_EVIDENCE','pending receiver record never confirms payment');
select throws_ok($$select pg_temp.admit(pg_temp.evidence('{"settlementRecordDigest":null}'))$$,'P0001','GATEWAY_INVALID_EVIDENCE','missing source-record digest rejected');
select throws_ok($$select public.admit_trusted_sms_gateway_evidence('99966000-0000-4000-8000-000000000510','99966000-0000-4000-8000-000000000530',clock_timestamp()-interval '10 minutes',clock_timestamp()+interval '2 minutes','aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=',pg_temp.evidence())$$,'P0001','GATEWAY_EXPIRED_EVIDENCE','stale signed request rejected');
select throws_ok($$select pg_temp.admit(pg_temp.evidence(jsonb_build_object('payerAccountDigest',repeat('b',64))))$$,'P0001','GATEWAY_PAYER_BINDING_MISMATCH','foreign payer account cannot fund another checkout');
-- throws_ok catches and rolls back this actual closure+admission subtransaction,
-- preserving the separate authentic payment scenario and the TAP assertion.
select throws_ok($$do $scenario$ begin
 perform public.request_account_erasure('99966000-0000-4000-8000-000000000001','99966000-0000-4000-8000-000000000590');
 perform pg_temp.admit(pg_temp.evidence());
end $scenario$;$$,'P0001','GATEWAY_SUBJECT_CLOSED','closed payer cannot admit a new payment through a still-provisioned gateway');
insert into evidence_receipts values('projection',pg_temp.evidence());
insert into evidence_receipts values('admitted',pg_temp.admit((select body from evidence_receipts where label='projection')));
insert into evidence_receipts values('retry',pg_temp.admit((select body from evidence_receipts where label='projection')));
select is((select body->>'raw_sms_id' from evidence_receipts where label='admitted'),(select body->>'raw_sms_id' from evidence_receipts where label='retry'),'identical signature replay recovers original immutable evidence');
select is((select body->>'replay' from evidence_receipts where label='retry'),'true','exact replay creates no new raw record');
select throws_ok($$select pg_temp.admit((select body||'{"providerTransactionId":"changed"}' from evidence_receipts where label='projection'))$$,'P0001','GATEWAY_EVENT_CHANGED','same event cannot change financial identity');
select throws_ok($$select pg_temp.admit((select body||'{"eventId":"99966000-0000-4000-8000-000000000521"}' from evidence_receipts where label='projection'))$$,'P0001','GATEWAY_NONCE_REUSED','nonce cannot sign another event');
reset role;
select is((select count(*)::integer from public.momo_sms_raw where club_id=9996601),1,'negative admissions leave only the one authentic synthetic source');
select is((select user_id from public.momo_sms_raw where club_id=9996601),'99966000-0000-4000-8000-000000000001'::uuid,'payer derives from canonical checkout');
select ok(not (select projection ? 'payerAccountDigest' from public.trusted_sms_gateway_events where club_id=9996601),'payer contact digest is minimized immediately after admission');
select is((select club_id from public.momo_sms_raw where club_id=9996601),9996601::bigint,'raw tenant is provisioned server-side');
select is((select status from public.shop_orders where club_id=9996601),'pending','admission alone never claims payment');
select throws_ok($$update public.trusted_sms_gateway_events set projection=projection||'{"amount":1}' where club_id=9996601$$,'P0001','GATEWAY_EVIDENCE_IMMUTABLE','admitted financial projection is immutable');
select throws_ok($$delete from public.trusted_sms_gateway_events where club_id=9996601$$,'P0001','GATEWAY_EVIDENCE_IMMUTABLE','durable anti-reuse identity cannot be deleted');
select throws_ok($$update public.trusted_sms_gateway_keys set secret_env_name='SMS_GATEWAY_KEY_REBOUND' where id='99966000-0000-4000-8000-000000000510'$$,'P0001','GATEWAY_KEY_IDENTITY_IMMUTABLE','key identity cannot be rebound to different credential material');
update public.payment_receiver_accounts set is_active=false where id='99966000-0000-4000-8000-000000000130';
set local role service_role;
select throws_ok($$select public.process_trusted_sms_gateway_evidence('99966000-0000-4000-8000-000000000520')$$,'42501','GATEWAY_NOT_PROVISIONED','receiver revocation before processing prevents financial effects');
reset role;
select is((select status from public.shop_orders where club_id=9996601),'pending','revoked receiver leaves actual order pending');
update public.payment_receiver_accounts set is_active=true where id='99966000-0000-4000-8000-000000000130';
update public.trusted_sms_gateways set enabled=false where id='99966000-0000-4000-8000-000000000500';
set local role service_role;
select throws_ok($$select public.process_trusted_sms_gateway_evidence('99966000-0000-4000-8000-000000000520')$$,'42501','GATEWAY_NOT_PROVISIONED','gateway revocation before processing prevents financial effects');
reset role;
select is((select count(*)::integer from public.momo_ledger_entries where club_id=9996601),0,'source revocation creates no posting');
update public.trusted_sms_gateways set enabled=true where id='99966000-0000-4000-8000-000000000500';
-- Force the actual final completion to fail after the canonical money writer.
-- The whole processing transaction must roll back financial/parse effects.
create function pg_temp.fail_gateway_completion() returns trigger language plpgsql as $$begin
 if new.club_id=9996601 and new.parse_status='parsed' then raise exception 'SYNTHETIC_COMPLETION_FAILURE';end if;return new;end $$;
create trigger qa_gateway_completion_failure before update on public.momo_sms_raw for each row execute function pg_temp.fail_gateway_completion();
set local role service_role;
select throws_ok($$select public.process_trusted_sms_gateway_evidence('99966000-0000-4000-8000-000000000520')$$,'P0001','SYNTHETIC_COMPLETION_FAILURE','completion failure does not commit paid state');
reset role;
select is((select status from public.shop_orders where club_id=9996601),'pending','failed final persistence rolls back paid order');
select is((select count(*)::integer from public.momo_ledger_entries where club_id=9996601),0,'failed final persistence rolls back financial posting');
select is((select count(*)::integer from public.momo_sms_parsed where club_id=9996601),0,'failed final persistence rolls back interpretation');
select is((select count(*)::integer from public.momo_parse_leases l join public.momo_sms_raw r on r.id=l.raw_sms_id where r.club_id=9996601),0,'failed atomic transaction leaves no abandoned lease');
drop trigger qa_gateway_completion_failure on public.momo_sms_raw;
set local role service_role;
insert into evidence_receipts values('processed',public.process_trusted_sms_gateway_evidence('99966000-0000-4000-8000-000000000520'));
insert into evidence_receipts values('processed_retry',public.process_trusted_sms_gateway_evidence('99966000-0000-4000-8000-000000000520'));
select is((select body->>'status' from evidence_receipts where label='processed'),'confirmed','receiver/order facts confirm through the actual canonical writer');
select is((select body->>'replay' from evidence_receipts where label='processed_retry'),'true','lost final response recovers committed receipt');
reset role;
select is((select status from public.shop_orders where club_id=9996601),'paid','actual shop paid state is committed');
select is((select count(*)::integer from public.momo_ledger_entries where club_id=9996601 and ledger_status='posted'),1,'one provider transaction produces one financial posting');
select is((select count(*)::integer from public.momo_reconciliations where club_id=9996601 and match_status='matched'),1,'one target has one matching reconciliation');
select is((select stock from public.shop_products where club_id=9996601),18,'processing/replay does not deduct stock twice');
select is((select amount from public.momo_sms_parsed where club_id=9996601),2500,'AI cannot alter signed financial amount');
select is((select parser_provider from public.momo_sms_parsed where club_id=9996601),'management_gateway','deterministic interpretation records actual management source');
select is((select sender from public.momo_sms_raw where club_id=9996601),'mtn_rwanda','source identity does not use a declared carrier sender label');
update public.trusted_sms_gateways set enabled=false where id='99966000-0000-4000-8000-000000000500';
set local role service_role;
select is(public.process_trusted_sms_gateway_evidence('99966000-0000-4000-8000-000000000520')->>'replay','true','revocation preserves receipt recovery without new effects');
select throws_ok($$select pg_temp.admit((select body from evidence_receipts where label='projection'),'99966000-0000-4000-8000-000000000531')$$,'42501','GATEWAY_NOT_PROVISIONED','revoked gateway cannot admit a new request');
reset role;
select * from finish();
rollback;

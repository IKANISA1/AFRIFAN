-- Full-schema payment lifecycle. Synthetic SMS proves local allocation rules,
-- never independent provider confirmation or authenticity of a device SMS.
begin;
select no_plan();

insert into auth.users(id,aud,role,phone,phone_confirmed_at,raw_app_meta_data)
values ('99670000-0000-4000-8000-000000000001','authenticated','authenticated',
 '+250796700001',now(),'{"club_id":24}');
insert into public.profiles(id,club_id)
values ('99670000-0000-4000-8000-000000000001',24);
insert into public.partners(id,name,slug,country)
values ('99670000-0000-4000-8000-000000000002','QA paid membership','qa-paid-membership','RW');
-- Owned transaction fixtures take precedence over the seeded public catalog.
update public.membership_packages set is_active=false where club_id=24;
update public.african_football_clubs set momo_ussd_template='*182*8*1*{amount}*{momo}#'
where id=24;
insert into public.membership_packages(id,partner_id,club_id,tier,title,subtitle,annual_price,price)
values ('99670000-0000-4000-8000-000000000003',
 '99670000-0000-4000-8000-000000000002',24,'imena','QA paid tier','Synthetic test',1000,1000);
insert into public.payment_receiver_accounts(id,partner_id,payee_number_or_code,purpose)
values ('99670000-0000-4000-8000-000000000004',
 '99670000-0000-4000-8000-000000000002','967004','subscription');
insert into public.partner_payment_routes(partner_id,club_id,country,provider,recipient_code,reconciliation_label,status)
values ('99670000-0000-4000-8000-000000000002',24,'RW','mtn_rwanda','967004','QA membership','active');

select set_config('request.jwt.claim.sub','99670000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"99670000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"club_id":24}}',true);
create temporary table paid_contract_orders(response jsonb);
grant all on paid_contract_orders to authenticated;
set local role authenticated;
insert into paid_contract_orders select public.prepare_membership_payment_for_club('imena',24);
select is((select (response->>'amount')::integer from paid_contract_orders),1000,'server catalog sets the checkout amount');
select is((select response->>'ussd_code' from paid_contract_orders),'*182*8*1*1000*967004#','checkout uses the configured route');
select is(public.prepare_membership_payment('imena')->>'id',
 (select response->>'id' from paid_contract_orders),'unchanged checkout is reused');
select throws_ok($$select public.prepare_membership_payment_for_club('imena',26)$$,
 '42501','MEMBER_CLUB_MISMATCH','foreign club cannot prepare this account payment');
reset role;

insert into public.momo_sms_raw(id,user_id,club_id,country_code,provider,
 device_message_key,sender,sms_body,sms_received_at,parse_status)
select ('99670000-0000-4000-8000-'||lpad((10+n)::text,12,'0'))::uuid,
 '99670000-0000-4000-8000-000000000001',24,'RW','mtn_rwanda',
 'qa-paid-lifecycle-'||n,'M-Money','Synthetic allocation evidence',now(),'parsed'
from generate_series(1,2)n;
insert into public.momo_sms_parsed(id,raw_sms_id,user_id,club_id,country_code,
 parser_provider,parser_model,parse_status,tx_direction,tx_type,momo_tx_id,
 amount,currency,payee_number_or_code)
select ('99670000-0000-4000-8000-'||lpad((20+n)::text,12,'0'))::uuid,
 ('99670000-0000-4000-8000-'||lpad((10+n)::text,12,'0'))::uuid,
 '99670000-0000-4000-8000-000000000001',24,'RW','contract','contract','parsed',
 'debit','payment','QA-PAID-LIFECYCLE-'||n,1000,'RWF','967004'
from generate_series(1,2)n;

create function pg_temp.pay_membership(n integer) returns jsonb language plpgsql as $$
declare receipt jsonb;
begin
 select public.allocate_momo_payment_intent(
  ('99670000-0000-4000-8000-'||lpad((20+n)::text,12,'0'))::uuid,
  payment_intent_id) into receipt
 from public.membership_payment_orders
 where id=(select response->>'id' from paid_contract_orders)::uuid;
 -- Flush the real deferred activation and financial consistency triggers.
 set constraints all immediate;
 set constraints all deferred;
 return receipt;
end $$;
grant select on paid_contract_orders to service_role;
grant execute on function pg_temp.pay_membership(integer) to service_role;
set local role service_role;
select lives_ok($$select pg_temp.pay_membership(1)$$,'full-schema allocation and deferred membership activation succeed');
reset role;
select is((select tier||'/'||payment_status||'/'||status from public.fan_memberships
 where user_id='99670000-0000-4000-8000-000000000001'),'imena/verified/active','paid tier is preserved by all baseline triggers');
select is((select count(*)::integer from public.momo_ledger_entries
 where user_id='99670000-0000-4000-8000-000000000001' and ledger_status='posted'),1,'one posted payment');
select is((select metadata->>'business_target_fulfilled' from public.momo_reconciliations
 where parsed_sms_id='99670000-0000-4000-8000-000000000021'),'true','reconciliation includes membership fulfillment');
create temporary table paid_contract_expiry as select expires_at from public.fan_memberships
 where user_id='99670000-0000-4000-8000-000000000001';

update public.payment_receiver_accounts set payee_number_or_code='967999',is_active=false
 where id='99670000-0000-4000-8000-000000000004';
set local role service_role;
select lives_ok($$select pg_temp.pay_membership(1)$$,'a committed receipt recovers after receiver rotation or retirement');
reset role;
select is((select expires_at from public.fan_memberships where user_id='99670000-0000-4000-8000-000000000001'),
 (select expires_at from paid_contract_expiry),'receipt recovery never extends entitlement');
update public.payment_receiver_accounts set payee_number_or_code='967004',is_active=true
 where id='99670000-0000-4000-8000-000000000004';

update public.fan_memberships set status='suspended'
 where user_id='99670000-0000-4000-8000-000000000001';
set local role authenticated;
update paid_contract_orders set response=public.prepare_membership_payment('imena');
reset role;
set local role service_role;
select lives_ok($$select pg_temp.pay_membership(2)$$,'renewal records a valid payment for a restricted account');
reset role;
select is((select status from public.fan_memberships where user_id='99670000-0000-4000-8000-000000000001'),
 'suspended','paying cannot lift an administrative suspension');
select is((select expires_at from public.fan_memberships where user_id='99670000-0000-4000-8000-000000000001'),
 (select expires_at+interval '1 year' from paid_contract_expiry),'renewal records exactly one year of paid entitlement');
select is((select count(*)::integer from public.membership_payment_orders
 where user_id='99670000-0000-4000-8000-000000000001' and activated_at is not null),2,'both payments are accounted for');
select * from finish();
rollback;

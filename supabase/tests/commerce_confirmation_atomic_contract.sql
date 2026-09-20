begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
insert into public.african_football_clubs(id,club_name,country_name,club_slug,currency_code,country_iso_code) overriding system value
 values(9975001,'Commerce QA','Rwanda','commerce-qa','RWF','RW');
insert into public.partners(id,name,slug,is_active) values('99750000-0000-4000-8000-000000000100','Commerce QA','commerce-qa',true);
insert into auth.users(id,aud,role,is_anonymous) values('99750000-0000-4000-8000-000000000001','authenticated','authenticated',false);
insert into public.users(id,phone,full_name) values('99750000-0000-4000-8000-000000000001','+250799750001','Commerce QA');
insert into public.profiles(id,club_id) values('99750000-0000-4000-8000-000000000001',9975001);
insert into public.matches(id,club_id,partner_id,home_team,away_team,competition,venue,match_date,kickoff_time,capacity,ticket_general_price)
 values('99750000-0000-4000-8000-000000000200',9975001,'99750000-0000-4000-8000-000000000100','Commerce QA','QA opponent','QA league','QA stadium',current_date+3,'15:00',100,1000);
insert into public.tickets(id,match_id,user_id,club_id,seat_type,amount_paid,momo_reference,status)
 select ('99750000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'99750000-0000-4000-8000-000000000200',
 '99750000-0000-4000-8000-000000000001',9975001,'general',1000,'RS-TICKET-QA-'||case when n=502 then 501 else n end,
 case when n=503 then 'cancelled' else 'pending' end from generate_series(501,506) n;
insert into public.shop_orders(id,user_id,club_id,partner_id,subtotal,total,momo_reference,status,inventory_reserved,reservation_expires_at)
 select ('99750000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'99750000-0000-4000-8000-000000000001',9975001,
 '99750000-0000-4000-8000-000000000100',1000,1000,'RS-SHOP-QA-'||case when n=607 then 606 else n end,
 case when n=602 then 'cancelled' when n=605 then 'fulfilled' else 'pending' end,
 n=604,case when n=604 then clock_timestamp()-interval '1 minute' else null end from generate_series(601,607) n;
insert into public.pending_transactions(user_id,reference,recipient_momo,provider,amount)
 select '99750000-0000-4000-8000-000000000001',ref,'250788111222','mtn_rwanda',amount from (
 select distinct momo_reference ref,case when momo_reference='RS-TICKET-QA-501' then 2000 else 1000 end amount from public.tickets where club_id=9975001
 union all select distinct momo_reference,1000 from public.shop_orders where club_id=9975001) refs;


insert into public.momo_sms_raw(id,user_id,device_message_key,sender,sms_body,provider,country_code,sms_received_at,parse_status,club_id)
 select ('99750000-0000-4000-8000-'||lpad((n+1000)::text,12,'0'))::uuid,'99750000-0000-4000-8000-000000000001',
 'commerce-raw-'||n,'M-Money','Synthetic commerce payment '||n,'mtn_rwanda','RW',clock_timestamp(),'parsed',9975001
 from generate_series(501,607) n;
insert into public.momo_sms_parsed(id,raw_sms_id,user_id,parser_provider,parser_model,parse_status,tx_direction,tx_type,momo_tx_id,amount,currency,payee_number_or_code,country_code,club_id)
 select ('99750000-0000-4000-8000-'||lpad((n+2000)::text,12,'0'))::uuid,
 ('99750000-0000-4000-8000-'||lpad((n+1000)::text,12,'0'))::uuid,'99750000-0000-4000-8000-000000000001',
 'contract','contract-v1','parsed','debit','payment',case when n<600 then 'RS-TICKET-QA-'||n else 'PROVIDER-SHOP-'||n end,
 case when n=501 then 2000 else 1000 end,'RWF','250788111222','RW',9975001 from generate_series(501,607) n;

-- Helper uses caller privileges, including every actual service-role assertion.
create function pg_temp.commerce(kind text, ids integer[], ref text, amount integer, overrides jsonb default '{}') returns jsonb
 language sql security invoker as $$
 select public.confirm_club_commerce_payment(kind,
   array(select ('99750000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid from unnest(ids) n),
   coalesce(overrides->>'user','99750000-0000-4000-8000-000000000001')::uuid,ref,amount,
   coalesce(overrides->>'club','9975001')::bigint,
   coalesce(overrides->>'partner','99750000-0000-4000-8000-000000000100')::uuid,
   coalesce(overrides->>'provider','mtn_rwanda'),coalesce(overrides->>'payee','250788111222'),
   coalesce(overrides->>'currency','RWF'),coalesce(overrides->>'country','RW'),
   ('99750000-0000-4000-8000-'||lpad((coalesce((overrides->>'parsed')::integer,ids[1])+2000)::text,12,'0'))::uuid);
$$;
grant execute on function pg_temp.commerce(text,integer[],text,integer,jsonb) to authenticated,service_role;
select ok(not (select prosecdef from pg_proc where oid='public.confirm_club_commerce_payment(text,uuid[],uuid,text,integer,bigint,uuid,text,text,text,text,uuid)'::regprocedure),'commerce RPC uses caller privileges');
select ok(not has_function_privilege('anon','public.confirm_club_commerce_payment(text,uuid[],uuid,text,integer,bigint,uuid,text,text,text,text,uuid)','execute'),'anonymous RPC denied');
select ok(not has_function_privilege('authenticated','public.confirm_club_commerce_payment(text,uuid[],uuid,text,integer,bigint,uuid,text,text,text,text,uuid)','execute'),'supporter RPC denied');
set local role authenticated;
select throws_ok($$select pg_temp.commerce('ticket','{501,502}','RS-TICKET-QA-501',2000)$$,'42501',null,'actual supporter execution denied');
reset role;
set local role service_role;
select is(pg_temp.commerce('ticket','{501,502}','RS-TICKET-QA-501',1)->>'status','manual_review','underpayment cannot confirm bundle');
select is(pg_temp.commerce('ticket','{501,502}','RS-TICKET-QA-501',2000,'{"user":"99750000-0000-4000-8000-000000000002"}')->>'status','manual_review','foreign payer denied');
select is(pg_temp.commerce('ticket','{501,502}','RS-TICKET-QA-501',2000,'{"provider":"airtel"}')->>'status','manual_review','provider mismatch denied');
select is(pg_temp.commerce('ticket','{501,502}','RS-TICKET-QA-501',2000,'{"payee":"250788999999"}')->>'status','manual_review','payee mismatch denied');
select is(pg_temp.commerce('ticket','{501,502}','RS-TICKET-QA-501',2000,'{"currency":"USD"}')->>'status','manual_review','currency mismatch denied');
select is(pg_temp.commerce('ticket','{501,502}','RS-TICKET-QA-501',2000,'{"country":"ZM"}')->>'status','manual_review','country mismatch denied');
select is(pg_temp.commerce('ticket','{501}','RS-TICKET-QA-501',2000)->>'status','manual_review','omitted bundle record denied');
select is(pg_temp.commerce('ticket','{501,501}','RS-TICKET-QA-501',2000)->>'status','manual_review','duplicate target denied');
select is(pg_temp.commerce('ticket','{503}','RS-TICKET-QA-503',1000)->>'status','manual_review','cancelled ticket never reopens');
select is(pg_temp.commerce('shop','{602}','RS-SHOP-QA-602',1000)->>'status','manual_review','cancelled shop order never reopens');
select is(pg_temp.commerce('shop','{604}','RS-SHOP-QA-604',1000)->>'status','manual_review','expired reservation cannot become paid');
select is(pg_temp.commerce('shop','{606}','RS-SHOP-QA-606',1000)->>'status','manual_review','ambiguous order reference denied');
select is((select count(*)::integer from public.fan_memberships where user_id='99750000-0000-4000-8000-000000000001'),0,'rejected evidence grants no rewards');
select is(pg_temp.commerce('ticket','{501,502}','RS-TICKET-QA-501',2000)->>'points_awarded','100','ticket bundle awards existing fifty points per ticket');
select is((select count(*)::integer from public.tickets where id in ('99750000-0000-4000-8000-000000000501','99750000-0000-4000-8000-000000000502') and status='valid' and confirmed_at is not null),2,'whole bundle and confirmation timestamps commit');
select is(pg_temp.commerce('ticket','{501,502}','RS-TICKET-QA-501',2000)->>'newly_confirmed','false','exact ticket replay is idempotent');
select is(pg_temp.commerce('shop','{601}','RS-SHOP-QA-601',1000)->>'points_awarded','10','shop points preserve total/100 arithmetic');
select ok((select status='paid' and confirmed_at is not null from public.shop_orders where id='99750000-0000-4000-8000-000000000601'),'shop status and timestamp commit');
select is(pg_temp.commerce('shop','{601}','RS-SHOP-QA-601',1000)->>'newly_confirmed','false','exact order replay is idempotent');
select is(pg_temp.commerce('shop','{605}','RS-SHOP-QA-605',1000)->>'status','manual_review','previously fulfilled order requires its original receipt');
select is((select status from public.shop_orders where id='99750000-0000-4000-8000-000000000605'),'fulfilled','fulfilled order cannot regress');
select is((select points from public.fan_memberships where user_id='99750000-0000-4000-8000-000000000001' and partner_id='99750000-0000-4000-8000-000000000100'),110,'duplicate/fulfilled outcomes add no further points');
select is((select count(*)::integer from public.momo_ledger_entries where club_id=9975001 and ledger_status='posted'),2,'ticket and shop each post exactly one ledger entry');
select is((select count(*)::integer from public.momo_reconciliations where club_id=9975001 and match_status='matched' and metadata->>'commerce_persisted'='true'),2,'both reconciliations persist with their targets');
select throws_ok($$update public.momo_reconciliations set match_status='manual_review' where parsed_sms_id='99750000-0000-4000-8000-000000002501'$$,'P0001','COMMERCE_POSTING_COMMITTED','response-loss fallback cannot overwrite committed commerce');
reset role;
create function pg_temp.fail_commerce_reward() returns trigger language plpgsql as $$begin raise exception 'Synthetic late commerce reward failure'; end;$$;
create trigger qa_fail_commerce_reward before update on public.fan_memberships for each row execute function pg_temp.fail_commerce_reward();
set local role service_role;
select throws_ok($$select pg_temp.commerce('ticket','{504}','RS-TICKET-QA-504',1000)$$,'P0001','Synthetic late commerce reward failure','late ticket reward failure aborts');
select ok((select status='pending' and confirmed_at is null from public.tickets where id='99750000-0000-4000-8000-000000000504'),'ticket state rolls back after reward failure');
select throws_ok($$select pg_temp.commerce('shop','{603}','RS-SHOP-QA-603',1000)$$,'P0001','Synthetic late commerce reward failure','late shop reward failure aborts');
select ok((select status='pending' and confirmed_at is null from public.shop_orders where id='99750000-0000-4000-8000-000000000603'),'order state rolls back after reward failure');
select is((select points from public.fan_memberships where user_id='99750000-0000-4000-8000-000000000001' and partner_id='99750000-0000-4000-8000-000000000100'),110,'failed rewards cannot partially change points');
select is((select count(*)::integer from public.momo_ledger_entries where club_id=9975001 and ledger_status='posted'),2,'late failures roll back ledger inserts');
select is((select count(*)::integer from public.momo_reconciliations where club_id=9975001),2,'late failures roll back reconciliation inserts');
reset role;
drop trigger qa_fail_commerce_reward on public.fan_memberships;
set local role service_role;
select is(pg_temp.commerce('ticket','{504}','RS-TICKET-QA-504',1000)->>'newly_confirmed','true','identical ticket request recovers after failure');
select is(pg_temp.commerce('shop','{603}','RS-SHOP-QA-603',1000)->>'newly_confirmed','true','identical shop request recovers after failure');
select is((select points from public.fan_memberships where user_id='99750000-0000-4000-8000-000000000001' and partner_id='99750000-0000-4000-8000-000000000100'),170,'successful retries commit each reward once');
reset role;
select * from finish();
rollback;

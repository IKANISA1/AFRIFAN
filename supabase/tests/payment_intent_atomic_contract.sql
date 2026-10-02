begin;
select no_plan();

-- Synthetic, transaction-owned fixture shared by pgTAP and concurrency checks.
insert into public.countries (id,name,dialing_code) values ('RW','Rwanda','+250')
  on conflict (id) do nothing;
insert into public.african_football_clubs (id, club_name, country_name, club_slug)
overriding system value values
  (9952001, 'Intent Atomic Contract Club', 'Rwanda', 'intent-atomic-contract'),
  (9952002, 'Foreign Intent Atomic Club', 'Rwanda', 'intent-atomic-contract-foreign');

insert into auth.users (id, aud, role)
select ('99520000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'authenticated', 'authenticated' from generate_series(1, 5) n;
insert into public.users (id, phone, full_name, is_admin)
select ('99520000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '+25079520000' || n, 'Allocation Actor ' || n, n = 3
from generate_series(1, 5) n;
insert into public.profiles (id, club_id)
select ('99520000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  case when n = 4 then 9952002 else 9952001 end
from generate_series(1, 5) n;
insert into public.admin_role_assignments (user_id, role, club_id)
values
  ('99520000-0000-4000-8000-000000000003', 'admin', null),
  ('99520000-0000-4000-8000-000000000005', 'club_admin', 9952001);

insert into public.partners (id, name, slug)
values ('99520000-0000-4000-8000-000000000110',
  'Intent Atomic Club', 'intent-atomic-club');
insert into public.initiatives (id, partner_id, title, category, club_id)
values ('99520000-0000-4000-8000-000000000120',
  '99520000-0000-4000-8000-000000000110', 'Allocation Campaign', 'community', 9952001);
insert into public.payment_receiver_accounts
  (id, payee_number_or_code, purpose, owner_user_id, partner_id, is_active)
select ('99520000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '995200' || n, 'club_shop',
  case when n = 101 then null else '99520000-0000-4000-8000-000000000002'::uuid end,
  '99520000-0000-4000-8000-000000000110', n <> 102
from generate_series(100, 103) n;

insert into public.initiative_contributions (id, initiative_id, user_id, amount, club_id)
select ('99520000-0000-4000-8000-' || lpad((600+n)::text, 12, '0'))::uuid,
  '99520000-0000-4000-8000-000000000120',
  '99520000-0000-4000-8000-000000000001', 1000, 9952001
from generate_series(1, 40) n;
insert into public.payment_intents
  (id, user_id, receiving_account_id, target_table, target_record_id,
   expected_amount, currency, expires_at)
select ('99520000-0000-4000-8000-' || lpad((500+n)::text, 12, '0'))::uuid,
  '99520000-0000-4000-8000-000000000001',
  '99520000-0000-4000-8000-000000000100', 'initiative_contributions',
  ('99520000-0000-4000-8000-' || lpad((600+n)::text, 12, '0'))::uuid,
  1000, 'RWF', clock_timestamp() + interval '1 hour'
from generate_series(1, 40) n;
insert into public.momo_sms_raw
  (id, user_id, device_message_key, sender, sms_body, provider,
   country_code, sms_received_at, parse_status, club_id)
select ('99520000-0000-4000-8000-' || lpad((200+n)::text, 12, '0'))::uuid,
  '99520000-0000-4000-8000-000000000001', 'intent-raw-' || n,
  'M-Money', 'Synthetic payment for allocation contract ' || n,
  'mtn_rwanda', 'RW', clock_timestamp(), 'parsed', 9952001
from generate_series(1, 40) n;
insert into public.momo_sms_parsed
  (id, raw_sms_id, user_id, parser_provider, parser_model, parse_status,
   tx_direction, tx_type, momo_tx_id, amount, currency, payee_number_or_code,
   country_code, club_id)
select ('99520000-0000-4000-8000-' || lpad((300+n)::text, 12, '0'))::uuid,
  ('99520000-0000-4000-8000-' || lpad((200+n)::text, 12, '0'))::uuid,
  '99520000-0000-4000-8000-000000000001', 'contract', 'contract-v1', 'parsed',
  'debit', 'payment', 'INTENT-TX-' || n, 1000, 'RWF', '995200100', 'RW', 9952001
from generate_series(1, 40) n;
insert into public.momo_reconciliations
  (id, parsed_sms_id, user_id, match_status, country_code, club_id)
select ('99520000-0000-4000-8000-' || lpad((400+n)::text, 12, '0'))::uuid,
  ('99520000-0000-4000-8000-' || lpad((300+n)::text, 12, '0'))::uuid,
  '99520000-0000-4000-8000-000000000001', 'manual_review', 'RW', 9952001
from generate_series(1, 40) n;


create function pg_temp.intent_call(n integer) returns jsonb language sql as $$
 select public.allocate_momo_payment_intent(
  ('99520000-0000-4000-8000-'||lpad((300+n)::text,12,'0'))::uuid,
  ('99520000-0000-4000-8000-'||lpad((500+n)::text,12,'0'))::uuid);
$$;
create function pg_temp.intent_call_sql(n integer) returns text language sql as $$
 select format('select pg_temp.intent_call(%s)',n);
$$;
grant execute on function pg_temp.intent_call(integer),pg_temp.intent_call_sql(integer) to authenticated,service_role;
select ok(not (select prosecdef from pg_proc where oid='public.allocate_momo_payment_intent(uuid,uuid)'::regprocedure),'allocation uses caller privileges');
select ok(not has_function_privilege('anon','public.allocate_momo_payment_intent(uuid,uuid)','execute'),'anonymous execution denied');
select ok(not has_function_privilege('authenticated','public.allocate_momo_payment_intent(uuid,uuid)','execute'),'supporter execution denied');
set local role authenticated;
select throws_ok($$select public.allocate_momo_payment_intent(null,null)$$,'42501',null,'actual supporter cannot allocate');
reset role;
set local role service_role;
select throws_ok($$select public.allocate_momo_payment_intent(null,null)$$,'P0001','INTENT_ALLOCATION_IDS_REQUIRED','empty input is rejected');
select is(pg_temp.intent_call(1)->>'newly_allocated','true','first allocation commits');
select is((select status from public.payment_intents where id='99520000-0000-4000-8000-000000000501'),'fulfilled','intent allocation status committed');
select ok((select ledger_status='posted' and amount=1000 and currency='RWF' and user_id='99520000-0000-4000-8000-000000000001' and club_id=9952001 and external_reference='INTENT-TX-1' from public.momo_ledger_entries where parsed_sms_id='99520000-0000-4000-8000-000000000301'),'exact owner tenant amount currency and reference posted');
select ok((select match_status='matched' and metadata->>'allocation_persisted'='true' and metadata->>'business_target_fulfilled'='false' from public.momo_reconciliations where parsed_sms_id='99520000-0000-4000-8000-000000000301'),'reconciliation truthfully records allocation only');
select is((select status from public.initiative_contributions where id='99520000-0000-4000-8000-000000000601'),'pending','allocation does not assert target fulfillment');
select is(pg_temp.intent_call(1)->>'newly_allocated','false','same input retry recovers committed allocation');
select is((select count(*) from public.momo_ledger_entries where parsed_sms_id='99520000-0000-4000-8000-000000000301'),1::bigint,'retry creates no second debit');
select throws_ok($$update public.momo_reconciliations set match_status='manual_review' where parsed_sms_id='99520000-0000-4000-8000-000000000301'$$,'P0001','INTENT_ALLOCATION_COMMITTED','lost-response fallback cannot overwrite committed allocation');
select throws_ok($$update public.momo_reconciliations set target_record_id='99520000-0000-4000-8000-000000000602' where parsed_sms_id='99520000-0000-4000-8000-000000000301'$$,'P0001','INTENT_ALLOCATION_COMMITTED','committed target cannot be relabelled');
reset role;
update public.payment_intents set currency='USD' where id='99520000-0000-4000-8000-000000000502';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(2),'P0001','INTENT_ALLOCATION_CURRENCY_MISMATCH','foreign currency cannot allocate');
reset role;
update public.payment_intents set user_id='99520000-0000-4000-8000-000000000004' where id='99520000-0000-4000-8000-000000000503';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(3),'P0001','INTENT_ALLOCATION_OWNER_MISMATCH','foreign owner cannot allocate');
reset role;
update public.payment_intents set receiving_account_id='99520000-0000-4000-8000-000000000103' where id='99520000-0000-4000-8000-000000000504';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(4),'P0001','INTENT_ALLOCATION_RECEIVER_MISMATCH','changed receiver cannot allocate');
reset role;
update public.momo_sms_parsed set payee_number_or_code='995200102' where id='99520000-0000-4000-8000-000000000305';update public.payment_intents set receiving_account_id='99520000-0000-4000-8000-000000000102' where id='99520000-0000-4000-8000-000000000505';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(5),'P0001','INTENT_ALLOCATION_RECEIVER_MISMATCH','inactive receiver cannot allocate');
reset role;
update public.payment_intents set expires_at=clock_timestamp()-interval '1 second' where id='99520000-0000-4000-8000-000000000506';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(6),'P0001','INTENT_ALLOCATION_EXPIRED','expired intent cannot allocate');
reset role;
update public.momo_sms_parsed set parse_status='needs_review' where id='99520000-0000-4000-8000-000000000307';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(7),'P0001','INTENT_ALLOCATION_INVALID_EVIDENCE','unreviewed parse cannot allocate');
reset role;
update public.momo_sms_parsed set tx_direction='credit' where id='99520000-0000-4000-8000-000000000308';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(8),'P0001','INTENT_ALLOCATION_INVALID_EVIDENCE','incoming payment cannot allocate');
reset role;
update public.momo_sms_raw set provider=null where id='99520000-0000-4000-8000-000000000209';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(9),'P0001','INTENT_ALLOCATION_INVALID_EVIDENCE','missing provider cannot allocate');
reset role;
update public.momo_sms_parsed set momo_tx_id=null where id='99520000-0000-4000-8000-000000000310';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(10),'P0001','INTENT_ALLOCATION_INVALID_EVIDENCE','missing transaction cannot allocate');
reset role;
update public.payment_intents set expected_amount=2000 where id='99520000-0000-4000-8000-000000000511';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(11),'P0001','INTENT_ALLOCATION_AMOUNT_MISMATCH','changed amount cannot allocate');
reset role;
update public.momo_sms_raw set club_id=9952002 where id='99520000-0000-4000-8000-000000000212';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(12),'P0001','INTENT_ALLOCATION_TENANT_MISMATCH','foreign raw tenant cannot allocate');
reset role;
update public.momo_reconciliations set club_id=9952002 where parsed_sms_id='99520000-0000-4000-8000-000000000313';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(13),'P0001','INTENT_ALLOCATION_STATE_CONFLICT','foreign review tenant cannot allocate');
reset role;
update public.payment_intents set status='cancelled' where id='99520000-0000-4000-8000-000000000514';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(14),'P0001','INTENT_ALLOCATION_STATE_CONFLICT','cancelled intent cannot allocate');
reset role;
update public.momo_sms_parsed set is_mock=true where id='99520000-0000-4000-8000-000000000315';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(15),'P0001','INTENT_ALLOCATION_INVALID_EVIDENCE','mock parse cannot allocate');
reset role;
update public.momo_sms_raw set is_mock=true where id='99520000-0000-4000-8000-000000000216';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(16),'P0001','INTENT_ALLOCATION_INVALID_EVIDENCE','mock raw evidence cannot allocate');
reset role;
insert into public.momo_ledger_entries(parsed_sms_id,user_id,entry_type,amount,currency,ledger_status,club_id) values ('99520000-0000-4000-8000-000000000317','99520000-0000-4000-8000-000000000001','debit',1000,'RWF','reversed',9952001);
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(17),'P0001','INTENT_ALLOCATION_LEDGER_CONFLICT','reversed ledger cannot allocate');
reset role;
update public.momo_sms_raw set user_id='99520000-0000-4000-8000-000000000002' where id='99520000-0000-4000-8000-000000000220';
update public.momo_sms_parsed set user_id='99520000-0000-4000-8000-000000000002',momo_tx_id='INTENT-TX-1' where id='99520000-0000-4000-8000-000000000320';
update public.payment_intents set user_id='99520000-0000-4000-8000-000000000002' where id='99520000-0000-4000-8000-000000000520';
update public.momo_reconciliations set user_id='99520000-0000-4000-8000-000000000002' where parsed_sms_id='99520000-0000-4000-8000-000000000320';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(20),'P0001','INTENT_ALLOCATION_TRANSACTION_USED','reused provider transaction cannot allocate');
reset role;
update public.momo_sms_raw set country_code='ZM' where id='99520000-0000-4000-8000-000000000223';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(23),'P0001','INTENT_ALLOCATION_TENANT_MISMATCH','foreign raw country cannot allocate');
reset role;
update public.momo_reconciliations set match_status='rejected' where parsed_sms_id='99520000-0000-4000-8000-000000000324';
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(24),'P0001','INTENT_ALLOCATION_STATE_CONFLICT','operator rejection cannot allocate');
reset role;

create function pg_temp.fail_intent_ledger() returns trigger language plpgsql as $$begin
 if new.parsed_sms_id='99520000-0000-4000-8000-000000000318' then raise exception 'Synthetic ledger failure'; end if; return new;
end;$$;
create trigger qa_intent_ledger_failure before insert on public.momo_ledger_entries for each row execute function pg_temp.fail_intent_ledger();
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(18),'P0001','Synthetic ledger failure','ledger failure aborts earlier intent write');
select is((select status from public.payment_intents where id='99520000-0000-4000-8000-000000000518'),'pending','ledger failure rolls back intent');
select is((select match_status from public.momo_reconciliations where parsed_sms_id='99520000-0000-4000-8000-000000000318'),'manual_review','ledger failure preserves review');
reset role;
drop trigger qa_intent_ledger_failure on public.momo_ledger_entries;
create function pg_temp.fail_intent_review() returns trigger language plpgsql as $$begin
 if new.parsed_sms_id='99520000-0000-4000-8000-000000000319' then raise exception 'Synthetic review failure'; end if; return new;
end;$$;
create trigger qa_intent_review_failure before update on public.momo_reconciliations for each row execute function pg_temp.fail_intent_review();
set local role service_role;
select throws_ok(pg_temp.intent_call_sql(19),'P0001','Synthetic review failure','late review failure aborts all posting writes');
select is((select status from public.payment_intents where id='99520000-0000-4000-8000-000000000519'),'pending','late failure rolls back intent');
select is((select count(*) from public.momo_ledger_entries where parsed_sms_id='99520000-0000-4000-8000-000000000319'),0::bigint,'late failure rolls back ledger');
reset role;
drop trigger qa_intent_review_failure on public.momo_reconciliations;
set local role service_role;
select is(pg_temp.intent_call(18)->>'newly_allocated','true','unchanged retry after ledger recovery succeeds');
select is(pg_temp.intent_call(19)->>'newly_allocated','true','unchanged retry after review recovery succeeds');
select is(pg_temp.intent_call(19)->>'newly_allocated','false','recovered posting still idempotent');
reset role;
update public.payment_intents set expires_at=clock_timestamp()-interval '1 second' where id='99520000-0000-4000-8000-000000000501';
set local role service_role;
select is(pg_temp.intent_call(1)->>'newly_allocated','false','committed allocation remains recoverable after intent expires');
reset role;
select * from finish();
rollback;

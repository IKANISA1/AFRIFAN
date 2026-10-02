begin;
select no_plan();

-- Synthetic, transaction-owned fixture shared by pgTAP and concurrency checks.
insert into public.countries (id,name,dialing_code) values ('RW','Rwanda','+250')
  on conflict (id) do nothing;
insert into public.african_football_clubs (id, club_name, country_name, club_slug)
overriding system value values
  (9951001, 'Allocation Contract Club', 'Rwanda', 'allocation-contract'),
  (9951002, 'Foreign Allocation Club', 'Rwanda', 'allocation-contract-foreign');

insert into auth.users (id, aud, role)
select ('99510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  'authenticated', 'authenticated' from generate_series(1, 5) n;
insert into public.users (id, phone, full_name, is_admin)
select ('99510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '+25079510000' || n, 'Allocation Actor ' || n, n = 3
from generate_series(1, 5) n;
insert into public.profiles (id, club_id)
select ('99510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  case when n = 4 then 9951002 else 9951001 end
from generate_series(1, 5) n;
insert into public.admin_role_assignments (user_id, role, club_id)
values
  ('99510000-0000-4000-8000-000000000003', 'admin', null),
  ('99510000-0000-4000-8000-000000000005', 'club_admin', 9951001);

insert into public.partners (id, name, slug)
values ('99510000-0000-4000-8000-000000000110',
  'Allocation Club', 'allocation-club');
insert into public.initiatives (id, partner_id, title, category, club_id)
values ('99510000-0000-4000-8000-000000000120',
  '99510000-0000-4000-8000-000000000110', 'Allocation Campaign', 'community', 9951001);
insert into public.payment_receiver_accounts
  (id, payee_number_or_code, purpose, owner_user_id, partner_id, is_active)
select ('99510000-0000-4000-8000-' || lpad(n::text, 12, '0'))::uuid,
  '995100' || n, 'club_shop',
  case when n = 101 then null else '99510000-0000-4000-8000-000000000002'::uuid end,
  '99510000-0000-4000-8000-000000000110', n <> 102
from generate_series(100, 103) n;

insert into public.initiative_contributions (id, initiative_id, user_id, amount, club_id)
select ('99510000-0000-4000-8000-' || lpad((600+n)::text, 12, '0'))::uuid,
  '99510000-0000-4000-8000-000000000120',
  '99510000-0000-4000-8000-000000000001', 1000, 9951001
from generate_series(1, 40) n;
insert into public.payment_intents
  (id, user_id, receiving_account_id, target_table, target_record_id,
   expected_amount, currency, expires_at)
select ('99510000-0000-4000-8000-' || lpad((500+n)::text, 12, '0'))::uuid,
  '99510000-0000-4000-8000-000000000001',
  '99510000-0000-4000-8000-000000000100', 'initiative_contributions',
  ('99510000-0000-4000-8000-' || lpad((600+n)::text, 12, '0'))::uuid,
  1000, 'RWF', clock_timestamp() + interval '1 hour'
from generate_series(1, 40) n;
insert into public.momo_sms_raw
  (id, user_id, device_message_key, sender, sms_body, provider,
   country_code, sms_received_at, parse_status, club_id)
select ('99510000-0000-4000-8000-' || lpad((200+n)::text, 12, '0'))::uuid,
  '99510000-0000-4000-8000-000000000001', 'allocation-raw-' || n,
  'M-Money', 'Synthetic payment for allocation contract ' || n,
  'mtn_rwanda', 'RW', clock_timestamp(), 'parsed', 9951001
from generate_series(1, 40) n;
insert into public.momo_sms_parsed
  (id, raw_sms_id, user_id, parser_provider, parser_model, parse_status,
   tx_direction, tx_type, momo_tx_id, amount, currency, payee_number_or_code,
   country_code, club_id)
select ('99510000-0000-4000-8000-' || lpad((300+n)::text, 12, '0'))::uuid,
  ('99510000-0000-4000-8000-' || lpad((200+n)::text, 12, '0'))::uuid,
  '99510000-0000-4000-8000-000000000001', 'contract', 'contract-v1', 'parsed',
  'debit', 'payment', 'ALLOCATION-TX-' || n, 1000, 'RWF', '995100100', 'RW', 9951001
from generate_series(1, 40) n;
insert into public.momo_reconciliations
  (id, parsed_sms_id, user_id, match_status, country_code, club_id)
select ('99510000-0000-4000-8000-' || lpad((400+n)::text, 12, '0'))::uuid,
  ('99510000-0000-4000-8000-' || lpad((300+n)::text, 12, '0'))::uuid,
  '99510000-0000-4000-8000-000000000001', 'manual_review', 'RW', 9951001
from generate_series(1, 40) n;

-- Helper functions and assertions

create function pg_temp.allocation_call(n integer) returns text language sql as $$
  select format('select * from public.allocate_momo_manual_review(%L,%L,%L)',
    '99510000-0000-4000-8000-' || lpad((400+n)::text,12,'0'),
    '99510000-0000-4000-8000-' || lpad((500+n)::text,12,'0'), 'Contract review');
$$;
grant execute on function pg_temp.allocation_call(integer) to authenticated, service_role;

select ok(has_function_privilege('authenticated',
  'public.allocate_momo_manual_review(uuid,uuid,text)', 'EXECUTE')
  and not has_function_privilege('anon',
  'public.allocate_momo_manual_review(uuid,uuid,text)', 'EXECUTE'),
  'authenticated operators can reach the guarded RPC; anonymous callers cannot');

-- Service role deliberately supplies a real actor here so this reproduces
-- the status-check failure even on the pre-fix ACL, before testing client ACLs.
set local role service_role;
set local request.jwt.claim.sub = '99510000-0000-4000-8000-000000000003';
select lives_ok(pg_temp.allocation_call(1), 'valid manual allocation commits');
reset role;

select is((select status from public.payment_intents
  where id='99510000-0000-4000-8000-000000000501'), 'fulfilled',
  'intent uses the declared fulfilled status');
select ok(exists(select 1 from public.momo_reconciliations r
  join public.momo_ledger_entries l on l.parsed_sms_id=r.parsed_sms_id
  where r.id='99510000-0000-4000-8000-000000000401'
    and r.match_status='matched' and l.ledger_status='posted'
    and l.entry_type='debit' and l.amount=1000 and l.currency='RWF'
    and l.club_id=9951001 and l.target_record_id=r.target_record_id
    and l.external_reference='ALLOCATION-TX-1'),
  'review and ledger persist the same outgoing payment, target and tenant');
select is((select count(*)::integer from public.admin_audit_log
  where action='momo_manual_allocation' and target_id='99510000-0000-4000-8000-000000000401'),
  1, 'allocation records one durable actor/reason audit');

set local role authenticated;
select lives_ok(pg_temp.allocation_call(1), 'lost-response retry reads the committed allocation');
reset role;
select is((select count(*)::integer from public.admin_audit_log
  where action='momo_manual_allocation' and target_id='99510000-0000-4000-8000-000000000401'),
  1, 'retry does not post or audit twice');

update public.payment_intents set user_id='99510000-0000-4000-8000-000000000004'
  where id='99510000-0000-4000-8000-000000000502';
update public.payment_intents set receiving_account_id='99510000-0000-4000-8000-000000000103'
  where id='99510000-0000-4000-8000-000000000503';
update public.payment_intents set currency='USD' where id='99510000-0000-4000-8000-000000000504';
update public.payment_intents set expires_at=clock_timestamp()-interval '1 second'
  where id='99510000-0000-4000-8000-000000000505';
update public.payment_intents set status='cancelled' where id='99510000-0000-4000-8000-000000000506';
update public.momo_reconciliations set club_id=9951002 where id='99510000-0000-4000-8000-000000000407';
update public.momo_sms_raw set user_id='99510000-0000-4000-8000-000000000004'
  where id='99510000-0000-4000-8000-000000000208';
update public.momo_sms_parsed set tx_direction='credit' where id='99510000-0000-4000-8000-000000000309';
update public.momo_sms_parsed set amount=2000 where id='99510000-0000-4000-8000-000000000310';
update public.momo_sms_parsed set momo_tx_id=null where id='99510000-0000-4000-8000-000000000311';
update public.momo_sms_parsed set payee_number_or_code='unknown' where id='99510000-0000-4000-8000-000000000312';
update public.payment_intents set receiving_account_id='99510000-0000-4000-8000-000000000102'
  where id='99510000-0000-4000-8000-000000000513';
update public.momo_sms_parsed set payee_number_or_code='995100102' where id='99510000-0000-4000-8000-000000000313';
update public.momo_sms_parsed set parse_status='failed' where id='99510000-0000-4000-8000-000000000314';
insert into public.momo_ledger_entries
  (parsed_sms_id,user_id,entry_type,ledger_status,amount,currency,target_table,target_record_id,club_id)
select ('99510000-0000-4000-8000-'||lpad((300+n)::text,12,'0'))::uuid,
  '99510000-0000-4000-8000-000000000001','debit',
  case n when 15 then 'posted' when 16 then 'reversed' else 'draft' end,
  case n when 17 then 2000 else 1000 end,'RWF',
  case when n=15 then 'initiative_contributions' end,
  case when n=15 then '99510000-0000-4000-8000-000000000601'::uuid end,9951001
from generate_series(15,17) n;
update public.momo_sms_raw set user_id='99510000-0000-4000-8000-000000000002'
  where id='99510000-0000-4000-8000-000000000218';
update public.momo_reconciliations set user_id='99510000-0000-4000-8000-000000000002'
  where id='99510000-0000-4000-8000-000000000418';
update public.payment_intents set user_id='99510000-0000-4000-8000-000000000002'
  where id='99510000-0000-4000-8000-000000000518';
update public.momo_sms_parsed set momo_tx_id='ALLOCATION-TX-1',
  user_id='99510000-0000-4000-8000-000000000002'
  where id='99510000-0000-4000-8000-000000000318';

set local role authenticated;
select throws_ok(pg_temp.allocation_call(2),'P0001','MANUAL_ALLOCATION_OWNER_MISMATCH','foreign payer intent rejected');
select throws_ok(pg_temp.allocation_call(3),'P0001','MANUAL_ALLOCATION_RECEIVER_MISMATCH','different receiver rejected');
select throws_ok(pg_temp.allocation_call(4),'P0001','MANUAL_ALLOCATION_CURRENCY_MISMATCH','different currency rejected');
select throws_ok(pg_temp.allocation_call(5),'P0001','MANUAL_ALLOCATION_EXPIRED','expired intent rejected');
select throws_ok(pg_temp.allocation_call(6),'P0001','MANUAL_ALLOCATION_STATE_CONFLICT','cancelled intent rejected');
select throws_ok(pg_temp.allocation_call(7),'P0001','MANUAL_ALLOCATION_TENANT_MISMATCH','contradictory tenant rejected');
select throws_ok(pg_temp.allocation_call(8),'P0001','MANUAL_ALLOCATION_OWNER_MISMATCH','raw SMS belongs to another payer');
select throws_ok(pg_temp.allocation_call(9),'P0001','MANUAL_ALLOCATION_INVALID_EVIDENCE','credit cannot confirm outgoing payment');
select throws_ok(pg_temp.allocation_call(10),'P0001','MANUAL_ALLOCATION_AMOUNT_MISMATCH','amount mismatch rejected');
select throws_ok(pg_temp.allocation_call(11),'P0001','MANUAL_ALLOCATION_INVALID_EVIDENCE','missing transaction reference is not invented');
select throws_ok(pg_temp.allocation_call(12),'P0001','MANUAL_ALLOCATION_RECEIVER_MISMATCH','unknown receiver rejected');
select throws_ok(pg_temp.allocation_call(13),'P0001','MANUAL_ALLOCATION_RECEIVER_MISMATCH','inactive receiver rejected');
select throws_ok(pg_temp.allocation_call(14),'P0001','MANUAL_ALLOCATION_INVALID_EVIDENCE','failed parse cannot allocate value');
select throws_ok(pg_temp.allocation_call(15),'P0001','MANUAL_ALLOCATION_LEDGER_CONFLICT','posted ledger cannot be rebound');
select throws_ok(pg_temp.allocation_call(16),'P0001','MANUAL_ALLOCATION_LEDGER_CONFLICT','reversed ledger cannot be reposted');
select throws_ok(pg_temp.allocation_call(17),'P0001','MANUAL_ALLOCATION_LEDGER_CONFLICT','draft amount cannot be silently rewritten');
select throws_ok(pg_temp.allocation_call(18),'P0001','MANUAL_ALLOCATION_TRANSACTION_USED','transaction cannot fund a second intent');
reset role;

-- An unowned receiver must not make NOT(false OR NULL) authorize an outsider.
update public.payment_intents set receiving_account_id='99510000-0000-4000-8000-000000000101'
  where id='99510000-0000-4000-8000-000000000524';
update public.momo_sms_parsed set payee_number_or_code='995100101' where id='99510000-0000-4000-8000-000000000324';
set local request.jwt.claim.sub='99510000-0000-4000-8000-000000000004';
set local role authenticated;
select throws_ok(pg_temp.allocation_call(23),'P0001','MANUAL_ALLOCATION_FORBIDDEN','unrelated operator rejected');
select throws_ok(pg_temp.allocation_call(24),'P0001','MANUAL_ALLOCATION_FORBIDDEN','null receiver owner fails closed');
reset role;
set local request.jwt.claim.sub='';
set local role service_role;
select throws_ok(pg_temp.allocation_call(22),'P0001','MANUAL_ALLOCATION_AUTH_REQUIRED','service call without an actor rejected');
reset role;

set local request.jwt.claim.sub='99510000-0000-4000-8000-000000000002';
set local role authenticated;
select lives_ok(pg_temp.allocation_call(25),'receiver account owner can allocate matching evidence');
reset role;
set local request.jwt.claim.sub='99510000-0000-4000-8000-000000000005';
set local role authenticated;
select lives_ok(pg_temp.allocation_call(26),'scoped club operator can allocate matching evidence');
reset role;

create function pg_temp.reject_allocation_audit() returns trigger language plpgsql as $$
begin
  if new.action='momo_manual_allocation'
    and new.target_id='99510000-0000-4000-8000-000000000419' then
    raise exception 'SYNTHETIC_AUDIT_FAILURE';
  end if;
  return new;
end;
$$;
create trigger reject_allocation_audit before insert on public.admin_audit_log
for each row execute function pg_temp.reject_allocation_audit();
set local request.jwt.claim.sub='99510000-0000-4000-8000-000000000003';
set local role authenticated;
select throws_ok(pg_temp.allocation_call(19),'P0001','SYNTHETIC_AUDIT_FAILURE','late audit failure is visible');
reset role;
select ok((select status='pending' from public.payment_intents where id='99510000-0000-4000-8000-000000000519')
  and (select match_status='manual_review' from public.momo_reconciliations where id='99510000-0000-4000-8000-000000000419')
  and not exists(select 1 from public.momo_ledger_entries where parsed_sms_id='99510000-0000-4000-8000-000000000319'),
  'late failure rolls back intent, reconciliation and ledger together');
select is((select count(*)::integer from public.payment_intents where status='fulfilled'
  and id::text like '99510000-%'),3,'only three accepted allocations changed financial state');

set local role authenticated;
select lives_ok('select * from public.get_momo_sms_manual_review_queue(50,0)',
  'actual admin session can load the review queue');
select lives_ok('select id,user_id,target_table,target_record_id,expected_amount,currency,status,expires_at,created_at from public.payment_intents',
  'admin session can read the minimal pending-intent fields');
select is((select count(*)::integer from public.users where id::text like '99510000-%'),5,
  'platform operator can resolve pending-intent supporter names');
select lives_ok($$select * from public.admin_reject_momo_sms_manual_review(
  '99510000-0000-4000-8000-000000000420','No matching payment')$$,
  'authorized operator can reject an unallocated review');
select lives_ok($$select * from public.admin_reject_momo_sms_manual_review(
  '99510000-0000-4000-8000-000000000420','Retry')$$,
  'rejection retry reads the original decision');
reset role;
select is((select count(*)::integer from public.admin_audit_log
  where action='reject_sms_manual_review' and target_id='99510000-0000-4000-8000-000000000420'),1,
  'one rejection audit survives an unchanged-input retry');
select is((select notes from public.momo_reconciliations
  where id='99510000-0000-4000-8000-000000000420'),'No matching payment',
  'retry preserves original decision reason');
set local request.jwt.claim.sub='99510000-0000-4000-8000-000000000004';
set local role authenticated;
select is((select count(*)::integer from public.get_momo_sms_manual_review_queue(50,0)),0,
  'ordinary foreign supporter sees no private SMS queue');
select is((select count(*)::integer from public.users where id::text like '99510000-%'),1,
  'ordinary supporter can read only their own minimal user fields');
select throws_ok($$select * from public.admin_reject_momo_sms_manual_review(
  '99510000-0000-4000-8000-000000000424','Forbidden')$$,
  'P0001','MANUAL_REVIEW_FORBIDDEN','unowned receiver cannot authorize rejection');
reset role;
select ok(not has_table_privilege('authenticated','public.payment_intents','UPDATE')
  and not has_table_privilege('authenticated','public.payment_intents','INSERT')
  and not has_column_privilege('authenticated','public.payment_intents','metadata','SELECT'),
  'queue reads grant no financial write or private metadata privileges');
select ok(not has_column_privilege('authenticated','public.users','phone','SELECT')
  and not has_table_privilege('authenticated','public.users','UPDATE'),
  'supporter-name projection grants no phone disclosure or identity writes');
select * from finish();
rollback;

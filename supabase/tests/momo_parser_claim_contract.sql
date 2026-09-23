begin;
select no_plan();
insert into public.countries(id,name,dialing_code) values('RW','Rwanda','+250') on conflict do nothing;
insert into public.african_football_clubs(id,club_name,country_name,club_slug)
  overriding system value values(9969001,'Parser Claim Contract','Rwanda','parser-claim-contract');
insert into auth.users(id,aud,role) values('99690000-0000-4000-8000-000000000001','authenticated','authenticated');
insert into public.users(id,phone,full_name) values('99690000-0000-4000-8000-000000000001','+250799690001','Parser claim actor');
insert into public.profiles(id,club_id) values('99690000-0000-4000-8000-000000000001',9969001);
insert into public.momo_sms_raw(id,user_id,device_message_key,sender,sms_body,provider,country_code,sms_received_at,club_id)
select ('99690000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  '99690000-0000-4000-8000-000000000001','parser-claim-'||n,'M-Money','Synthetic parser lease SMS',
  'mtn_rwanda','RW',clock_timestamp(),9969001 from generate_series(101,110) n;

-- Reused by the existing real lock-observed concurrency runner.
create function pg_temp.parse_claim(n integer, force_parse boolean default false) returns jsonb language sql as $$
  select public.claim_momo_sms_parse(id,user_id,updated_at,force_parse) from public.momo_sms_raw
    where id=('99690000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
$$;
create function pg_temp.parse_payload() returns jsonb language sql as $$
 select '{"parser_provider":"contract","parser_model":"contract-v1","parse_status":"needs_review",
   "tx_direction":"unknown","tx_type":"unknown","tx_category":"uncategorized","cashflow_bucket":"unknown",
   "amount":1000,"currency":"RWF","user_id":"99690000-0000-4000-8000-000000000999","club_id":9999999}'::jsonb;
$$;
create function pg_temp.parse_persist(n integer, token uuid) returns jsonb language sql as $$
 select public.persist_momo_sms_parse(('99690000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
  '99690000-0000-4000-8000-000000000001',token,pg_temp.parse_payload());
$$;
grant execute on function pg_temp.parse_claim(integer,boolean),pg_temp.parse_payload(),pg_temp.parse_persist(integer,uuid) to service_role,authenticated;
create temporary table claims(label text primary key, token uuid);
grant select,insert on claims to service_role;

select ok((select relrowsecurity from pg_class where oid='public.momo_parse_leases'::regclass),'lease rows have RLS');
select ok(not has_table_privilege('authenticated','public.momo_parse_leases','select,insert,update,delete'),'supporters cannot inspect or mutate worker tokens');
select ok(not has_function_privilege('anon','public.claim_momo_sms_parse(uuid,uuid,timestamptz,boolean)','execute'),'anonymous claims denied');
select ok(not has_function_privilege('authenticated','public.persist_momo_sms_parse(uuid,uuid,uuid,jsonb)','execute'),'supporter interpretation writes denied');
select ok(not has_function_privilege('authenticated','public.finish_momo_sms_parse(uuid,uuid,uuid,boolean,uuid,jsonb,jsonb,text)','execute'),'supporter completion denied');
set local role authenticated;
select throws_ok($$select public.claim_momo_sms_parse(null,null,null,false)$$,'42501',null,'actual supporter cannot claim work');
reset role;
set local role service_role;
select is(public.claim_momo_sms_parse('99690000-0000-4000-8000-000000000101','99690000-0000-4000-8000-000000000999',null,false)->>'status','not_found','foreign owner is rejected');
select is(public.claim_momo_sms_parse('99690000-0000-4000-8000-000000000101','99690000-0000-4000-8000-000000000001','2000-01-01',false)->>'status','changed','old read version cannot claim');
insert into claims select 'first',(pg_temp.parse_claim(101)->>'token')::uuid;
select ok((select token is not null from claims where label='first'),'initial worker receives an opaque token');
select is(pg_temp.parse_claim(101)->>'status','busy','overlapping worker cannot take the live claim');
select is(pg_temp.parse_claim(101,true)->>'status','busy','force cannot overtake a live worker');
select throws_ok($$select pg_temp.parse_persist(101,'99690000-0000-4000-8000-000000000999')$$,'P0001','MOMO_PARSE_LEASE_LOST','foreign token cannot write an interpretation');
insert into public.momo_parse_attempts(id,raw_sms_id,user_id,provider,model,attempt_number,status)
  values('99690000-0000-4000-8000-000000000201','99690000-0000-4000-8000-000000000101','99690000-0000-4000-8000-000000000001','openai','test',1,'pending');
update public.momo_parse_leases set expires_at=clock_timestamp()-interval '1 second' where raw_sms_id='99690000-0000-4000-8000-000000000101';
select throws_ok($$select pg_temp.parse_persist(101,(select token from claims where label='first'))$$,'P0001','MOMO_PARSE_LEASE_LOST','expired worker cannot publish even before takeover');
insert into claims select 'replacement',(pg_temp.parse_claim(101)->>'token')::uuid;
select ok((select token from claims where label='first')<>(select token from claims where label='replacement'),'expired pre-parse claim is replaced');
select is((select status from public.momo_parse_attempts where id='99690000-0000-4000-8000-000000000201'),'failed','abandoned pending attempt is closed');
select is(public.finish_momo_sms_parse('99690000-0000-4000-8000-000000000101','99690000-0000-4000-8000-000000000001',(select token from claims where label='first'),false),false,'late error cannot fail the replacement worker');
select is((select parse_status from public.momo_sms_raw where id='99690000-0000-4000-8000-000000000101'),'processing','replacement remains in progress');
select throws_ok($$select pg_temp.parse_persist(101,(select token from claims where label='first'))$$,'P0001','MOMO_PARSE_LEASE_LOST','replaced worker remains fenced');
select ok(pg_temp.parse_persist(101,(select token from claims where label='replacement'))->>'id' is not null,'replacement interpretation persists');
select ok((select user_id='99690000-0000-4000-8000-000000000001' and club_id=9969001 and country_code='RW' from public.momo_sms_parsed where raw_sms_id='99690000-0000-4000-8000-000000000101'),'payload cannot spoof owner or tenant');
select is((select phase from public.momo_parse_leases where raw_sms_id='99690000-0000-4000-8000-000000000101'),'persisted','saved interpretation advances the same transaction');
update public.momo_parse_leases set expires_at=clock_timestamp()-interval '1 second' where raw_sms_id='99690000-0000-4000-8000-000000000101';
select is(pg_temp.parse_claim(101)->>'status','review_required','persisted interruption cannot be blindly reinterpreted');
select throws_ok($$select public.finish_momo_sms_parse('99690000-0000-4000-8000-000000000101','99690000-0000-4000-8000-000000000001',(select token from claims where label='replacement'),true,'99690000-0000-4000-8000-000000000999')$$,'P0001','MOMO_PARSE_ATTEMPT_REQUIRED','missing selected attempt rolls back completion');
select is((select parse_status from public.momo_sms_raw where id='99690000-0000-4000-8000-000000000101'),'processing','failed completion does not report parsed');
insert into public.momo_parse_attempts(id,raw_sms_id,user_id,provider,model,attempt_number,status)
  values('99690000-0000-4000-8000-000000000202','99690000-0000-4000-8000-000000000101','99690000-0000-4000-8000-000000000001','openai','test',2,'pending');
reset role;
create function pg_temp.fail_raw_completion() returns trigger language plpgsql as $$
begin if new.parse_status='parsed' then raise exception 'SYNTHETIC_COMPLETION_FAILURE'; end if; return new; end; $$;
create trigger qa_completion_failure before update on public.momo_sms_raw for each row execute function pg_temp.fail_raw_completion();
set local role service_role;
select throws_ok($$select public.finish_momo_sms_parse('99690000-0000-4000-8000-000000000101','99690000-0000-4000-8000-000000000001',(select token from claims where label='replacement'),true,'99690000-0000-4000-8000-000000000202','{}','{}')$$,'P0001','SYNTHETIC_COMPLETION_FAILURE','late raw failure propagates');
select is((select status from public.momo_parse_attempts where id='99690000-0000-4000-8000-000000000202'),'pending','late raw failure rolls back attempt success');
select is((select phase from public.momo_parse_leases where raw_sms_id='99690000-0000-4000-8000-000000000101'),'persisted','late raw failure retains recoverable ownership');
reset role;
drop trigger qa_completion_failure on public.momo_sms_raw;
set local role service_role;
select is(public.finish_momo_sms_parse('99690000-0000-4000-8000-000000000101','99690000-0000-4000-8000-000000000001',(select token from claims where label='replacement'),true,'99690000-0000-4000-8000-000000000202','{}','{}'),true,'the persisted owner can finish after lease time without a second worker');
select ok((select parse_status='parsed' from public.momo_sms_raw where id='99690000-0000-4000-8000-000000000101') and (select status='success' from public.momo_parse_attempts where id='99690000-0000-4000-8000-000000000202'),'attempt and raw completion commit together');
select is((select count(*) from public.momo_parse_leases where raw_sms_id='99690000-0000-4000-8000-000000000101'),0::bigint,'completion removes the claim');
select is(public.finish_momo_sms_parse('99690000-0000-4000-8000-000000000101','99690000-0000-4000-8000-000000000001',(select token from claims where label='replacement'),false),false,'late failure cannot undo committed completion');
select is(pg_temp.parse_claim(101)->>'status','already_parsed','ordinary completed retry does not start new work');
update public.momo_sms_raw set parse_status='processing' where id='99690000-0000-4000-8000-000000000102';
select is(pg_temp.parse_claim(102)->>'status','review_required','unfenced legacy workers require review, not unsafe takeover');
insert into claims select 'changed-source',(pg_temp.parse_claim(103)->>'token')::uuid;
update public.momo_sms_raw set sms_body='Changed while AI was working',updated_at=clock_timestamp() where id='99690000-0000-4000-8000-000000000103';
-- The baseline timestamp trigger uses transaction time; change the actual field
-- below in a later statement via the trigger-free owner fixture only.
reset role;
alter table public.momo_sms_raw disable trigger trg_momo_sms_raw_set_updated_at;
update public.momo_sms_raw set updated_at=clock_timestamp()+interval '1 second' where id='99690000-0000-4000-8000-000000000103';
alter table public.momo_sms_raw enable trigger trg_momo_sms_raw_set_updated_at;
set local role service_role;
select throws_ok($$select pg_temp.parse_persist(103,(select token from claims where label='changed-source'))$$,'P0001','MOMO_PARSE_LEASE_LOST','changed raw content cannot receive an old interpretation');
select is(public.finish_momo_sms_parse('99690000-0000-4000-8000-000000000103','99690000-0000-4000-8000-000000000001',(select token from claims where label='changed-source'),false),false,'cleanup cannot overwrite a changed source');
insert into claims select 'external-reset',(pg_temp.parse_claim(104)->>'token')::uuid;
select pg_temp.parse_persist(104,(select token from claims where label='external-reset'));
update public.momo_parse_leases set expires_at=clock_timestamp()-interval '1 second' where raw_sms_id='99690000-0000-4000-8000-000000000104';
update public.momo_sms_raw set parse_status='failed' where id='99690000-0000-4000-8000-000000000104';
select is(pg_temp.parse_claim(104)->>'status','review_required','changing raw status cannot bypass persisted ownership');
select is((select token from public.momo_parse_leases where raw_sms_id='99690000-0000-4000-8000-000000000104'),(select token from claims where label='external-reset'),'external status reset cannot replace the saved interpretation owner');
reset role;
select * from finish();
rollback;

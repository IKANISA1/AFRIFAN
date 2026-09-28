"""Isolated PostgreSQL regression harness for automatic paid memberships.
Set PG_BIN and ordinary libpq connection variables for a local test server.
Requires existing anon/authenticated/service_role roles and database-creation rights.
The minimal schema exercises the real migration, not a complete Supabase replay.
"""
from pathlib import Path
import subprocess,uuid,json,os,shutil,re,time,concurrent.futures
ROOT=Path(__file__).resolve().parents[2]
binary=Path(os.environ.get('PG_BIN',str(Path(shutil.which('psql') or '/usr/bin/psql').parent)))
args=[]  # libpq reads PGHOST, PGPORT, PGUSER and PGPASSWORD from the environment.
name='qa_membership_'+uuid.uuid4().hex[:8]
def sql(text,check=True):
 r=subprocess.run([str(binary/'psql'),*args,'-d',name,'-X','-v','ON_ERROR_STOP=1','-At'],input=text,text=True,capture_output=True,timeout=30)
 if check and r.returncode:raise RuntimeError(r.stderr[-3500:])
 return r

def allocate_while_checkout_waits(intent_id,parsed_id,checkout):
 """Observe the intent lock before allowing allocation and checkout to race."""
 held=subprocess.Popen([str(binary/'psql'),*args,'-d',name,'-X','-qAt','-v','ON_ERROR_STOP=1'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 try:
  held.stdin.write(f"set application_name='qa_membership_held';set statement_timeout='10s';begin;select id from payment_intents where id='{intent_id}' for update;\n");held.stdin.flush()
  for _ in range(100):
   if sql("select count(*) from pg_stat_activity where application_name='qa_membership_held' and state='idle in transaction';").stdout.strip()=='1':break
   time.sleep(.02)
  else:raise AssertionError('Allocation did not acquire the intent lock')
  with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
   pending=pool.submit(sql,"set application_name='qa_membership_checkout';set statement_timeout='10s';"+checkout,False)
   for _ in range(100):
    if sql("select count(*) from pg_stat_activity where application_name='qa_membership_checkout' and wait_event_type='Lock';").stdout.strip()=='1':break
    time.sleep(.02)
   else:raise AssertionError('Checkout did not reach the held intent')
   held.stdin.write(f"select allocate_momo_payment_intent('{parsed_id}','{intent_id}');commit;\n");held.stdin.flush()
   out,err=held.communicate(timeout=15)
   checkout_result=pending.result(timeout=15)
   assert held.returncode==0 and checkout_result.returncode==0, f'Allocation and checkout must not deadlock: {err} {checkout_result.stderr}'
   return json.loads(checkout_result.stdout.splitlines()[-1])
 finally:
  if held.poll() is None:held.communicate('rollback;\n',timeout=15)
subprocess.run([str(binary/'createdb'),*args,name],check=True,timeout=15)
try:
 sql('''create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create function public.requesting_club_id() returns text language sql as $$select current_setting('request.club',true)$$;
create table public.african_football_clubs(id bigint primary key,country_iso_code text,momo_ussd_template text,is_active bool);
create table public.partners(id uuid primary key,country text, constraint partners_country_supported_check check(country in ('RW','CD','ZM')));
create table public.membership_packages(id uuid primary key,partner_id uuid,club_id bigint,tier text,is_active bool,annual_price numeric(12,2),price numeric(12,2),sort_order int,benefit_scope text default 'unclassified');
create table public.partner_payment_routes(id uuid primary key,partner_id uuid,club_id bigint,recipient_code text,country text,status text,provider text default 'mtn',reconciliation_label text default 'membership',constraint partner_payment_routes_country_supported_check check(country in ('RW','CD','ZM')));
create table public.payment_receiver_accounts(id uuid primary key,partner_id uuid,payee_number_or_code text,is_active bool);
create table public.payment_intents(id uuid primary key default gen_random_uuid(),user_id uuid,receiving_account_id uuid,target_table text,target_record_id uuid,expected_amount int,currency text,status text default 'pending',expires_at timestamptz,updated_at timestamptz);
create table public.fan_memberships(id uuid primary key default gen_random_uuid(),user_id uuid,partner_id uuid,club_id bigint,tier text,points int,chapter text,membership_number text,payment_status text,status text,renewed_at timestamptz,expires_at timestamptz,updated_at timestamptz,unique(user_id,club_id));
create table public.momo_ledger_entries(id uuid primary key default gen_random_uuid(),parsed_sms_id uuid unique,user_id uuid,club_id bigint,ledger_status text,entry_type text,ledger_scope text,target_table text,target_record_id uuid,amount int,currency text,external_reference text,metadata jsonb,tx_datetime timestamptz,description text,country_code text,updated_at timestamptz);
create table public.momo_reconciliations(id uuid primary key default gen_random_uuid(),parsed_sms_id uuid unique,user_id uuid,club_id bigint,target_table text,target_record_id uuid,match_status text,metadata jsonb,notes text,match_type text,confidence numeric,reconciled_at timestamptz,country_code text,updated_at timestamptz);
create table public.momo_sms_raw(id uuid primary key,user_id uuid,club_id bigint,country_code text,provider text,is_mock bool default false,sms_received_at timestamptz default now());
create table public.momo_sms_parsed(id uuid primary key,user_id uuid,club_id bigint,amount int,currency text,tx_direction text,momo_tx_id text,payee_number_or_code text,raw_sms_id uuid references public.momo_sms_raw(id),country_code text,parse_status text default 'parsed',is_mock bool default false,tx_datetime timestamptz default now(),confidence numeric default 1);
create function public.resolve_club_currency_code(bigint) returns text language sql as $$select 'RWF'::text$$;
create function public.activate_free_fan_membership() returns void language plpgsql as $$begin null;end$$;
create function public.activate_free_fan_membership_for_club(bigint) returns void language plpgsql as $$begin null;end$$;
create function public.submit_membership_application(text,text,text) returns void language plpgsql as $$begin null;end$$;
create function public.rs_sync_membership_fields() returns trigger language plpgsql as $$begin
IF new.tier IN ('fan', 'bronze', 'gold', 'platinum') THEN return new; ELSE new.tier:='fan'; RETURN new; END IF;
end$$;
create trigger tier_sync before insert or update on public.fan_memberships for each row execute function public.rs_sync_membership_fields();
insert into auth.users values ('99660000-0000-4000-8000-000000000001');
insert into african_football_clubs values(24,'RW','*182*8*1*{amount}*{momo}#',true),(44,'BI','*999*{amount}*{momo}#',true),(26,'ZM','*999*{amount}*{momo}#',true),(6,'CD','*999*{amount}*{momo}#',true);
insert into partners(id) values ('99660000-0000-4000-8000-000000000002');
insert into membership_packages(id,partner_id,club_id,tier,is_active,annual_price,price,sort_order) values
('99660000-0000-4000-8000-000000000003','99660000-0000-4000-8000-000000000002',24,'imena',true,1000,1000,1),
('99660000-0000-4000-8000-000000000004','99660000-0000-4000-8000-000000000002',24,'gold',true,2000,2000,2),
('99660000-0000-4000-8000-000000000005','99660000-0000-4000-8000-000000000002',24,'fan',true,0,0,3);
insert into partner_payment_routes(id,partner_id,club_id,recipient_code,country,status) values('99660000-0000-4000-8000-000000000006','99660000-0000-4000-8000-000000000002',24,'12345','RW','active');
insert into payment_receiver_accounts values('99660000-0000-4000-8000-000000000007','99660000-0000-4000-8000-000000000002','12345',true);
''')
 # Install the production allocation and its committed-reconciliation guard,
 # then the membership trigger. Testing either migration alone misses conflicts.
 sql((ROOT/'supabase/migrations/20260919232000_atomic_payment_intent_allocation.sql').read_text())
 sql((ROOT/'supabase/migrations/20260920123000_automatic_paid_membership.sql').read_text())
 sql('''create table public.membership_applications(id uuid,status text);
 grant select(status),update(status) on public.membership_applications to authenticated;
 grant all on public.membership_applications to service_role;
 create function public.review_membership_application() returns void language plpgsql as $$begin null;end$$;
 create function public.admin_review_membership_application_if_unchanged() returns void language plpgsql as $$begin null;end$$;
 create table public.partner_services(country text,constraint partner_services_country_supported_check check(country in ('RW','CD','ZM')));
 create table public.quick_actions(action_key text,route text,country text,constraint quick_actions_country_supported_check check(country in ('RW','CD','ZM')));
 create table public.platform_features(feature_key text);
 create table public.platform_feature_channels(route_key text);
 create table public.platform_route_registry(feature_key text,path_pattern text);
 create table public.site_navigation_items(feature_key text,href text);
 create table public.site_search_items(feature_key text,href text);
 create function public.normalize_partner_payment_provider(text) returns text language sql as $$select lower(btrim($1))$$;
 create function public.normalize_momo_code_for_country(text,text) returns text language sql as $$select nullif(btrim($2),'')$$;
 ''')
 # Exercise the real Predict balance mutation against a paid membership too.
 sql('''create function public.resolve_fan_tier(integer) returns text language sql as $$select 'fan'::text$$;
 create table public.fet_wallet_ledger_entries(club_id bigint,user_id uuid,idempotency_key text);
 create function public.fet_wallet_ensure_membership(uuid,bigint) returns public.fan_memberships language sql as $$select * from public.fan_memberships where user_id=$1 and club_id=$2$$;
 create function public.fet_wallet_append_entry(bigint,uuid,uuid,text,text,integer,integer,uuid,text,text,text,text,jsonb,uuid) returns void language sql as $$insert into public.fet_wallet_ledger_entries values($1,$2,$11)$$;''')
 predict=(ROOT/'supabase/migrations/20260906082522_simplified_predict.sql').read_text()
 sql(re.search(r'create function public.predict_post_entry\([\s\S]*?\n\$\$;',predict).group())
 sql((ROOT/'supabase/migrations/20260920150000_revised_product_enforcement.sql').read_text())
 sql((ROOT/'supabase/migrations/20260920164901_matched_membership_reconciliation.sql').read_text())
 sql((ROOT/'supabase/migrations/20260920165224_membership_payment_lock_order.sql').read_text())
 sql((ROOT/'supabase/migrations/20260920165540_membership_payment_evidence_binding.sql').read_text())
 sql((ROOT/'supabase/migrations/20260923101604_preserve_paid_membership_restrictions_and_receipt_recovery.sql').read_text())
 # This minimal fixture has no commerce/operator/parser schemas. Replay its
 # allocation definition here; the complete seven-function migration is covered
 # by tools/scripts/test_predict_database.py against the real vendor schemas.
 evidence_locks=(ROOT/'supabase/migrations/20260923102734_serialize_momo_evidence_before_row_locks.sql').read_text()
 sql(re.search(r'create or replace function public.allocate_momo_payment_intent\([\s\S]*?\n\$\$;',evidence_locks).group())
 sql('''grant usage on schema auth,public to service_role;
 grant select,insert,update on public.payment_intents,public.payment_receiver_accounts,
 public.momo_sms_raw,public.momo_sms_parsed,public.momo_ledger_entries,
 public.momo_reconciliations,public.fan_memberships to service_role;''')
 sql('create trigger validate_route before insert or update on public.partner_payment_routes for each row execute function public.enforce_partner_payment_route_fields();')
 actor="set role authenticated;set request.jwt.claim.sub='99660000-0000-4000-8000-000000000001';set request.club='24';"
 sql("grant usage on schema auth to authenticated;grant select on public.membership_packages to anon,authenticated;alter table public.membership_packages enable row level security;")
 assert sql(actor+"select count(*) from membership_packages;").stdout.splitlines()[-1]=='2'
 assert sql(actor+"set request.club='26';select count(*) from membership_packages;").stdout.splitlines()[-1]=='0'
 assert sql("update membership_packages set is_active=true where tier='fan';",False).returncode!=0
 r=sql(actor+"select prepare_membership_payment('imena');");order=json.loads(r.stdout.splitlines()[-1]);assert order['amount']==1000 and order['recipient_code']=='12345'
 assert order['ussd_code']=='*182*8*1*1000*12345#' and order['club_id']==24
 assert json.loads(sql(actor+"select prepare_membership_payment_for_club('imena',24);").stdout.splitlines()[-1])['id']==order['id']
 assert sql(actor+"select prepare_membership_payment_for_club('imena',26);",False).returncode!=0
 same=json.loads(sql(actor+"select prepare_membership_payment('imena');").stdout.splitlines()[-1]);assert same['id']==order['id']
 assert sql(actor+"select prepare_membership_payment('fan');",False).returncode!=0
 assert sql(actor+"set request.club='26';select prepare_membership_payment('imena');",False).returncode!=0
 assert sql(actor+"set role authenticated;insert into membership_payment_orders(user_id) values(auth.uid());",False).returncode!=0
 # Price changes after order preparation cannot rewrite the paid snapshot.
 sql("update membership_packages set annual_price=9000 where tier='imena';")
 intent=sql(f"select payment_intent_id from membership_payment_orders where id='{order['id']}';").stdout.strip()
 assert sql(f"update payment_intents set status='fulfilled' where id='{intent}';",False).returncode!=0
 assert sql('select count(*) from fan_memberships;').stdout.strip()=='0'
 evidence=f'''
insert into momo_sms_raw(id,user_id,club_id,country_code,provider) values('99660000-0000-4000-8000-000000000009','99660000-0000-4000-8000-000000000001',24,'RW','mtn');
insert into momo_sms_parsed(id,user_id,club_id,amount,currency,tx_direction,momo_tx_id,payee_number_or_code,raw_sms_id,country_code) values('99660000-0000-4000-8000-000000000008','99660000-0000-4000-8000-000000000001',24,1000,'RWF','debit','TX-TEST','12345','99660000-0000-4000-8000-000000000009','RW');'''
 sql(evidence)
 allocation=f"set role service_role;select allocate_momo_payment_intent('99660000-0000-4000-8000-000000000008','{intent}');"
 assert sql(actor+allocation.replace('set role service_role;',''),False).returncode!=0
 sql("update momo_sms_raw set provider='airtel';")
 assert sql(allocation,False).returncode!=0, 'A foreign provider must not activate a membership purchased through MTN'
 assert sql('select count(*) from fan_memberships;').stdout.strip()=='0'
 assert sql('select count(*) from momo_ledger_entries;').stdout.strip()=='0'
 sql("update momo_sms_raw set provider='mtn',country_code='ZM';update momo_sms_parsed set country_code='ZM';")
 assert sql(allocation,False).returncode!=0, 'Evidence country must match the purchased club payment route'
 sql("update momo_sms_raw set country_code='RW';update momo_sms_parsed set country_code='RW';")
 sql("update payment_receiver_accounts set payee_number_or_code='54321';")
 assert sql(allocation,False).returncode!=0
 sql("update payment_receiver_accounts set payee_number_or_code='12345',is_active=false;")
 assert sql(allocation,False).returncode!=0
 sql("update payment_receiver_accounts set is_active=true;")
 sql(allocation)
 member=sql("select tier||'/'||payment_status||'/'||status from fan_memberships;").stdout.strip();assert member=='imena/verified/active',member
 sql("select predict_post_entry(24,'99660000-0000-4000-8000-000000000001',50,'reward','paid-member-credit',null,'Contract');")
 assert sql("select tier||'/'||points from fan_memberships;").stdout.strip()=='imena/50'
 sql("select predict_post_entry(24,'99660000-0000-4000-8000-000000000001',-10,'stake','paid-member-debit',null,'Contract');")
 assert sql("select tier||'/'||points from fan_memberships;").stdout.strip()=='imena/40'
 expiry=sql('select expires_at from fan_memberships;').stdout.strip()
 sql(f"update payment_intents set status='fulfilled' where id='{intent}';")
 assert sql('select expires_at from fan_memberships;').stdout.strip()==expiry
 assert sql("select metadata->>'business_target_fulfilled' from momo_ledger_entries;").stdout.strip()=='true'
 assert sql("select metadata->>'business_target_fulfilled' from momo_reconciliations;").stdout.strip()=='true', 'Activated membership must also be fulfilled in the committed reconciliation'
 assert json.loads(sql(f"select allocate_momo_payment_intent('99660000-0000-4000-8000-000000000008','{intent}');").stdout.strip())['newly_allocated'] is False
 assert sql('select expires_at from fan_memberships;').stdout.strip()==expiry
 receipt=sql('select metadata from momo_reconciliations;').stdout.strip()
 membership_id=sql('select id from fan_memberships;').stdout.strip()
 # A delayed parser response cannot erase fulfillment or replace its identity.
 sql('''update momo_reconciliations set metadata='{"business_target_fulfilled":false,"membership_id":"99660000-0000-4000-8000-000000000099","intent_id":"wrong"}';''')
 recovered=json.loads(sql('select metadata from momo_reconciliations;').stdout.strip())
 assert recovered['business_target_fulfilled'] is True and recovered['membership_id']==membership_id and recovered['intent_id']==intent
 assert sql("update momo_reconciliations set match_status='manual_review';",False).returncode!=0
 assert sql("update momo_reconciliations set club_id=26;",False).returncode!=0
 assert sql("update momo_reconciliations set country_code='BI';",False).returncode!=0
 assert sql("update momo_reconciliations set target_record_id=gen_random_uuid();",False).returncode!=0
 # Unknown / allocation-only targets cannot forge fulfillment in a PATCH.
 sql("""insert into momo_reconciliations(parsed_sms_id,user_id,club_id,country_code,target_table,target_record_id,match_status,metadata)
 values(gen_random_uuid(),'99660000-0000-4000-8000-000000000001',24,'RW','initiative_contributions',gen_random_uuid(),'matched','{"allocation_persisted":true,"business_target_fulfilled":false,"intent_id":"unfulfilled"}');
 update momo_reconciliations set metadata='{"business_target_fulfilled":true,"membership_id":"99660000-0000-4000-8000-000000000099"}' where target_table='initiative_contributions';""")
 unfulfilled=json.loads(sql("select metadata from momo_reconciliations where target_table='initiative_contributions';").stdout.strip())
 assert unfulfilled['business_target_fulfilled'] is False and 'membership_id' not in unfulfilled
 assert sql("select has_function_privilege('authenticated','public.activate_free_fan_membership()','execute');").stdout.strip()=='f'
 assert sql("select has_function_privilege('service_role','review_membership_application()','execute');").stdout.strip()=='f'
 assert sql("select has_function_privilege('service_role','admin_review_membership_application_if_unchanged()','execute');").stdout.strip()=='f'
 assert sql("select has_column_privilege('authenticated','membership_applications','status','select');").stdout.strip()=='f'
 assert sql("select has_column_privilege('service_role','membership_applications','status','update');").stdout.strip()=='f'
 assert sql("update partner_payment_routes set country='BI' where club_id=24;",False).returncode!=0
 # Each retained club preserves its own country. These are synthetic routes,
 # not provider-verified dialing instructions or production merchant codes.
 for club,country in [(44,'BI'),(26,'ZM'),(6,'CD')]:
  sql(f"insert into partner_payment_routes(id,partner_id,club_id,recipient_code,country,status) values(gen_random_uuid(),'99660000-0000-4000-8000-000000000002',{club},'56789{club}','{country}','active');")
  assert sql(f"select country from partner_payment_routes where club_id={club};").stdout.strip()==country
 for table,columns,values in [
   ('platform_features','feature_key',"'fanzone'"),
   ('platform_feature_channels','route_key',"'/challenge'"),
   ('platform_route_registry','feature_key,path_pattern',"'predict','/challenge/123'"),
   ('quick_actions','action_key,route',"'custom','/fanzone'"),
   ('site_navigation_items','feature_key,href',"'predict','/fanzone/match/1'"),
   ('site_search_items','feature_key,href',"'challenge','/predict'")]:
  assert sql(f'insert into {table}({columns}) values({values});',False).returncode!=0
 # An allocation can hold the intent while a tier change is preparing a new
 # order. Both must finish without receiver/advisory lock-order deadlocks.
 gold=json.loads(sql(actor+"select prepare_membership_payment('gold');").stdout.splitlines()[-1])
 gold_intent=sql(f"select payment_intent_id from membership_payment_orders where id='{gold['id']}';").stdout.strip()
 sql("""insert into momo_sms_raw(id,user_id,club_id,country_code,provider) values('99660000-0000-4000-8000-000000000010','99660000-0000-4000-8000-000000000001',24,'RW','mtn');
 insert into momo_sms_parsed(id,user_id,club_id,amount,currency,tx_direction,momo_tx_id,payee_number_or_code,raw_sms_id,country_code) values('99660000-0000-4000-8000-000000000011','99660000-0000-4000-8000-000000000001',24,2000,'RWF','debit','TX-RACE','12345','99660000-0000-4000-8000-000000000010','RW');""")
 changed=allocate_while_checkout_waits(gold_intent,'99660000-0000-4000-8000-000000000011',actor+"select prepare_membership_payment('imena');")
 assert changed['tier']=='imena' and changed['amount']==9000
 assert sql('select tier from fan_memberships;').stdout.strip()=='gold'
 assert sql(f"select count(*) from membership_payment_orders where id='{gold['id']}' and activated_at is not null;").stdout.strip()=='1'
 # Parallel checkout retries reuse the same server-owned order.
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
  retries=list(pool.map(lambda _:json.loads(sql(actor+"select prepare_membership_payment('imena');").stdout.splitlines()[-1]),range(4)))
 assert all(o['id']==changed['id'] for o in retries)
 changed_intent=sql(f"select payment_intent_id from membership_payment_orders where id='{changed['id']}';").stdout.strip()
 sql("""insert into momo_sms_raw(id,user_id,club_id,country_code,provider) values('99660000-0000-4000-8000-000000000012','99660000-0000-4000-8000-000000000001',24,'RW','mtn rwanda');
 insert into momo_sms_parsed(id,user_id,club_id,amount,currency,tx_direction,momo_tx_id,payee_number_or_code,raw_sms_id,country_code) values('99660000-0000-4000-8000-000000000013','99660000-0000-4000-8000-000000000001',24,9000,'RWF','debit','TX-RETRY','12345','99660000-0000-4000-8000-000000000012','RW');
 create function public.qa_fail_activation() returns trigger language plpgsql as $$begin raise exception 'Synthetic late activation failure';end$$;
 create trigger qa_fail_activation before update on public.fan_memberships for each row execute function public.qa_fail_activation();""")
 retry_sql=f"set role service_role;select allocate_momo_payment_intent('99660000-0000-4000-8000-000000000013','{changed_intent}');"
 failed=sql(retry_sql,False);assert failed.returncode!=0 and 'Synthetic late activation failure' in failed.stderr
 assert sql(f"select status from payment_intents where id='{changed_intent}';").stdout.strip()=='pending'
 assert sql(f"select activated_at is null from membership_payment_orders where id='{changed['id']}';").stdout.strip()=='t'
 assert sql("select count(*) from momo_ledger_entries where parsed_sms_id='99660000-0000-4000-8000-000000000013';").stdout.strip()=='0'
 assert sql("select count(*) from momo_reconciliations where parsed_sms_id='99660000-0000-4000-8000-000000000013';").stdout.strip()=='0'
 assert sql('select tier from fan_memberships;').stdout.strip()=='gold'
 sql('drop trigger qa_fail_activation on fan_memberships;')
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
  allocated=list(pool.map(lambda _:json.loads(sql(retry_sql).stdout.splitlines()[-1]),range(4)))
 assert sum(o['newly_allocated'] for o in allocated)==1
 assert sql('select tier from fan_memberships;').stdout.strip()=='imena'
 assert sql("select count(*) from momo_ledger_entries where parsed_sms_id='99660000-0000-4000-8000-000000000013';").stdout.strip()=='1'
 expiry=sql('select expires_at from fan_memberships;').stdout.strip()
 sql(retry_sql)
 assert sql('select expires_at from fan_memberships;').stdout.strip()==expiry
 # Reapply the historical guard to reproduce an already-activated old receipt,
 # then verify the forward repair changes neither membership nor payment value.
 old=(ROOT/'supabase/migrations/20260919232000_atomic_payment_intent_allocation.sql').read_text()
 sql(re.search(r'create or replace function public.protect_committed_intent_reconciliation\(\)[\s\S]*?\n\$\$;',old).group())
 sql("update momo_reconciliations set metadata=metadata where parsed_sms_id='99660000-0000-4000-8000-000000000013';")
 assert sql("select metadata->>'business_target_fulfilled' from momo_reconciliations where parsed_sms_id='99660000-0000-4000-8000-000000000013';").stdout.strip()=='false'
 sql((ROOT/'supabase/migrations/20260920164901_matched_membership_reconciliation.sql').read_text())
 assert sql("select metadata->>'business_target_fulfilled' from momo_reconciliations where parsed_sms_id='99660000-0000-4000-8000-000000000013';").stdout.strip()=='true'
 assert sql('select expires_at from fan_memberships;').stdout.strip()==expiry
 renewal=json.loads(sql(actor+"select prepare_membership_payment('imena');").stdout.splitlines()[-1])
 renewal_intent=sql(f"select payment_intent_id from membership_payment_orders where id='{renewal['id']}';").stdout.strip()
 sql("""insert into momo_sms_raw(id,user_id,club_id,country_code,provider) values('99660000-0000-4000-8000-000000000014','99660000-0000-4000-8000-000000000001',24,'RW','mtn');
 insert into momo_sms_parsed(id,user_id,club_id,amount,currency,tx_direction,momo_tx_id,payee_number_or_code,raw_sms_id,country_code) values('99660000-0000-4000-8000-000000000015','99660000-0000-4000-8000-000000000001',24,9000,'RWF','debit','TX-RETRY','12345','99660000-0000-4000-8000-000000000014','RW');""")
 renewal_sql=f"set role service_role;select allocate_momo_payment_intent('99660000-0000-4000-8000-000000000015','{renewal_intent}');"
 reused=sql(renewal_sql,False);assert reused.returncode!=0 and 'INTENT_ALLOCATION_TRANSACTION_USED' in reused.stderr
 assert sql('select expires_at from fan_memberships;').stdout.strip()==expiry
 sql("update momo_sms_parsed set momo_tx_id='TX-RENEWAL' where id='99660000-0000-4000-8000-000000000015';")
 sql(renewal_sql)
 assert sql(f"select expires_at='{expiry}'::timestamptz+interval '1 year' from fan_memberships;").stdout.strip()=='t'
 renewed=sql('select expires_at from fan_memberships;').stdout.strip()
 sql(renewal_sql)
 assert sql('select expires_at from fan_memberships;').stdout.strip()==renewed
 assert sql('select points from fan_memberships;').stdout.strip()=='40'
 # A provider edit makes a fresh checkout; it cannot silently repurpose a
 # pending order or borrow provider authority from an old unbound order.
 pending=json.loads(sql(actor+"select prepare_membership_payment('imena');").stdout.splitlines()[-1])
 sql("update partner_payment_routes set provider='airtel' where club_id=24;")
 rerouted=json.loads(sql(actor+"select prepare_membership_payment('imena');").stdout.splitlines()[-1])
 assert rerouted['id']!=pending['id']
 assert sql(f"select i.status from payment_intents i join membership_payment_orders o on o.payment_intent_id=i.id where o.id='{pending['id']}';").stdout.strip()=='cancelled'
 assert sql(f"select payment_provider from membership_payment_orders where id='{rerouted['id']}';").stdout.strip()=='airtel'
 sql(f"update membership_payment_orders set payment_provider=null where id='{rerouted['id']}';")
 bound=json.loads(sql(actor+"select prepare_membership_payment('imena');").stdout.splitlines()[-1])
 assert bound['id']!=rerouted['id']
 print('PASS: distinct payment renews exactly once, reused provider transaction is rejected, paid tier/points survive, changed or missing provider snapshots cannot reuse checkout.')
 print('PASS: provider/country/receiver refusal, actual service-role allocation, four concurrent checkouts, late activation rollback, four concurrent allocation retries and historical receipt repair.')
 print('PASS: actual allocation/activation/reconciliation, immutable fulfilled receipt, allocation-only refusal and lock-observed checkout race.')
 print('PASS: club-bound dialer, retired review ACLs, four-country route preservation, runtime feature rejection; ')
 print('PASS: paid-tier selection, authoritative price snapshot, reuse, zero-price refusal, tenant isolation, write restrictions, unpaid refusal, matched automatic activation, official tier retention and idempotent renewal.')
finally:
 subprocess.run([str(binary/'dropdb'),*args,name],check=True,timeout=15)

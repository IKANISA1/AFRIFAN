begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select ok(not has_function_privilege('authenticated','public.request_account_erasure(uuid,uuid)','execute'),'supporter cannot submit a foreign subject directly to privileged RPC');
select ok(not has_function_privilege('anon','public.claim_account_erasure_jobs(integer)','execute'),'anonymous workers denied');
select ok(not has_table_privilege('authenticated','public.account_erasure_jobs','SELECT'),'job subjects and processor evidence remain private');
select diag(coalesce((select jsonb_agg(jsonb_build_object('table',n.nspname||'.'||c.relname,
 'lifecycle_policies',(select jsonb_agg(jsonb_build_object('name',p.polname,'permissive',p.polpermissive,
 'command',p.polcmd,'roles',p.polroles,'using',pg_get_expr(p.polqual,p.polrelid),
 'with_check',pg_get_expr(p.polwithcheck,p.polrelid))) from pg_policy p
 where p.polrelid=c.oid and p.polname='account_lifecycle_access')))
 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where c.relkind='r' and c.relrowsecurity and (n.nspname in ('public','football') or n.nspname like 'retired%')
 and c.relname not like 'account_erasure%' and c.relname not like 'sms_evidence%'
 and not exists(select 1 from pg_policy p where p.polrelid=c.oid and p.polname='account_lifecycle_access'
 and not p.polpermissive and p.polcmd='*' and p.polroles=array['authenticated'::regrole::oid]
 and pg_get_expr(p.polqual,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$'
 and pg_get_expr(p.polwithcheck,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$')),
 '[]'::jsonb)::text);
select ok(not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where c.relkind='r' and c.relrowsecurity and (n.nspname in ('public','football') or n.nspname like 'retired%')
 and c.relname not like 'account_erasure%' and c.relname not like 'sms_evidence%'
 and not exists(select 1 from pg_policy p where p.polrelid=c.oid and p.polname='account_lifecycle_access'
 and not p.polpermissive and p.polcmd='*' and p.polroles=array['authenticated'::regrole::oid]
 and pg_get_expr(p.polqual,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$'
 and pg_get_expr(p.polwithcheck,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$')),
 'every original public/football/retired RLS table has the exact restrictive authenticated lifecycle guard');
select ok((select count(*)=2 from pg_policy p
 where p.polrelid in('public.verified_staff_commands'::regclass,'public.verified_staff_command_proofs'::regclass)
 and p.polname='account_lifecycle_access' and not p.polpermissive and p.polcmd='*'
 and p.polroles=array['authenticated'::regrole::oid]
 and pg_get_expr(p.polqual,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$'
 and pg_get_expr(p.polwithcheck,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$')
 and not exists(select 1 from unnest(array['public.verified_staff_commands'::regclass,
 'public.verified_staff_command_proofs'::regclass]) t cross join unnest(array['account_lifecycle_statement_guard',
 'account_lifecycle_mutation_guard']) name where not exists(select 1 from pg_trigger g
 where g.tgrelid=t and g.tgname=name and not g.tgisinternal
 and g.tgfoid='public.guard_account_lifecycle_mutation()'::regprocedure)),
 'both new private command/proof tables carry exact lifecycle policy and statement/row guards');
select ok((select count(*)=5 from pg_policy p
 where p.polrelid in('public.trusted_sms_ingress_config'::regclass,'public.trusted_sms_gateways'::regclass,
 'public.trusted_sms_gateway_keys'::regclass,'public.trusted_sms_gateway_events'::regclass,'public.trusted_sms_gateway_nonces'::regclass)
 and p.polname='account_lifecycle_access' and not p.polpermissive and p.polcmd='*'
 and p.polroles=array['authenticated'::regrole::oid]
 and pg_get_expr(p.polqual,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$'
 and pg_get_expr(p.polwithcheck,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$')
 and not exists(select 1 from unnest(array['public.trusted_sms_ingress_config'::regclass,
 'public.trusted_sms_gateways'::regclass,'public.trusted_sms_gateway_keys'::regclass,
 'public.trusted_sms_gateway_events'::regclass,'public.trusted_sms_gateway_nonces'::regclass]) t
 cross join unnest(array['account_lifecycle_statement_guard','account_lifecycle_mutation_guard']) name
 where not exists(select 1 from pg_trigger g where g.tgrelid=t and g.tgname=name and not g.tgisinternal
 and g.tgfoid='public.guard_account_lifecycle_mutation()'::regprocedure)),
 'all five private gateway authority/evidence tables carry exact lifecycle policy and statement/row guards');
select ok(exists(select 1 from pg_constraint c join public.account_erasure_fk_inventory i on i.constraint_oid=c.oid
 where c.contype='f' and c.conrelid='public.sms_evidence_holds'::regclass and c.confrelid='auth.users'::regclass
 and c.conkey=array[(select attnum from pg_attribute where attrelid=c.conrelid and attname='actor_user_id')]::smallint[]
 and c.confdeltype='a' and i.deletion_action=c.confdeltype::text and i.retained
 and to_regclass(i.child_table)=c.conrelid and to_regclass(i.subject_table)=c.confrelid),
 'the actual post-capture hold actor FK is retained with its original restrictive deletion action');
select ok(exists(select 1 from pg_policy where polrelid='storage.objects'::regclass and polname='account_lifecycle_storage_access'
 and not polpermissive and polcmd='*' and polroles=array['authenticated'::regrole::oid]),'Storage retains the authenticated restrictive guard');

insert into public.african_football_clubs(id,club_name,country_name,club_slug) overriding system value values(9996301,'Erasure QA','Rwanda','erasure-qa');
insert into public.partners(id,name,slug,is_active) values('99963000-0000-4000-8000-000000000100','Erasure QA','erasure-qa',true);
insert into auth.users(id,aud,role,phone,phone_confirmed_at,is_anonymous) select
 ('99963000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated','+25079996300'||n,now(),false from generate_series(1,3)n;
insert into public.users(id,phone,full_name,identity_data) select
 ('99963000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+25079996300'||n,'Personal QA '||n,'{"national_id":"personal"}' from generate_series(1,3)n;
insert into public.profiles(id,club_id,full_name,display_name,avatar_url) select
 ('99963000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,9996301,'Personal QA '||n,'Personal QA '||n,'https://local.invalid/personal.png' from generate_series(1,3)n;
insert into public.admin_role_assignments(user_id,role) values('99963000-0000-4000-8000-000000000001','admin'),('99963000-0000-4000-8000-000000000003','admin');
insert into public.fan_memberships(user_id,club_id,partner_id,tier,membership_number,payment_status,status,points) values
 ('99963000-0000-4000-8000-000000000001',9996301,'99963000-0000-4000-8000-000000000100','fan','ERASURE-QA','verified','active',700);
insert into public.fet_wallet_ledger_entries(club_id,user_id,entry_type,direction,amount,balance_after,idempotency_key,note) values
 (9996301,'99963000-0000-4000-8000-000000000001','opening_balance','credit',700,700,'erasure-opening','Personal QA note');
insert into public.momo_sms_raw(id,user_id,device_message_key,sender,sms_body,sms_received_at,club_id) values
 ('99963000-0000-4000-8000-000000000200','99963000-0000-4000-8000-000000000001','erasure-evidence-identity','M-Money','Personal QA SMS',now(),9996301);
insert into public.momo_sms_parsed(id,raw_sms_id,user_id,parser_provider,parser_model,momo_tx_id,amount,club_id,payer_name,structured_data) values
 ('99963000-0000-4000-8000-000000000201','99963000-0000-4000-8000-000000000200','99963000-0000-4000-8000-000000000001','qa','qa','ERASURE-UNIQUE-TX',1000,9996301,'Personal QA','{"payer_name":"Personal QA","amount":1000}');
insert into public.momo_ledger_entries(parsed_sms_id,user_id,entry_type,amount,external_reference,ledger_status,club_id,description) values
 ('99963000-0000-4000-8000-000000000201','99963000-0000-4000-8000-000000000001','credit',1000,'ERASURE-UNIQUE-TX','posted',9996301,'Personal QA');
insert into auth.sessions(id,user_id,created_at,updated_at) values('99963000-0000-4000-8000-000000000300','99963000-0000-4000-8000-000000000001',now(),now());
create temporary table erasure_receipts(label text primary key,data jsonb); grant all on erasure_receipts to service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true); select set_config('request.jwt.claim.sub','',true);
set local role service_role;
insert into erasure_receipts values('first',public.request_account_erasure('99963000-0000-4000-8000-000000000001','99963000-0000-4000-8000-000000000999'));
insert into erasure_receipts values('retry',public.request_account_erasure('99963000-0000-4000-8000-000000000001','99963000-0000-4000-8000-000000000999'));
select is((select data->>'request_id' from erasure_receipts where label='first'),(select data->>'request_id' from erasure_receipts where label='retry'),'same subject recovers one durable request');
select is((select data->>'request_id' from erasure_receipts where label='first'),'99963000-0000-4000-8000-000000000999','durable original native capability is the job ID');
select is(public.get_account_erasure_status('99963000-0000-4000-8000-000000000999')->>'status','deletion_pending','lost first HTTP response recovers status using pre-persisted capability');
select ok(not (public.get_account_erasure_status('99963000-0000-4000-8000-000000000999') ? 'user_id'),'capability projection never discloses subject UUID');
select is(public.get_account_erasure_status('99963000-0000-4000-8000-000000000998'),null::jsonb,'unissued capability cannot recover a job');
select throws_ok($$select public.request_account_erasure('99963000-0000-4000-8000-000000000002','99963000-0000-4000-8000-000000000999')$$,'42501','ACCOUNT_CAPABILITY_CONFLICT','foreign subject cannot reuse another closure capability');
select is((select count(*)::integer from public.account_erasure_jobs where user_id='99963000-0000-4000-8000-000000000002'),0,'collision cannot close foreign account');
select is((select data->>'status' from erasure_receipts where label='first'),'deletion_pending','receipt never claims completed erasure');
select is((select data->>'access_revoked' from erasure_receipts where label='first'),'true','pending request confirms immediate access revocation');
reset role;
select throws_ok($$delete from auth.users where id='99963000-0000-4000-8000-000000000001'$$,'42501','RETAINED_FINANCIAL_SUBJECT','physical Auth deletion cannot cascade retained financial history');
select is((select count(*)::integer from auth.sessions where user_id='99963000-0000-4000-8000-000000000001'),0,'captured sessions are revoked atomically');
select ok((select not is_active and revoked_at is not null from public.admin_role_assignments where user_id='99963000-0000-4000-8000-000000000001'),'staff assignment revoked');
select ok((select banned_until is not null and raw_app_meta_data->>'account_lifecycle'='deletion_pending' from auth.users where id='99963000-0000-4000-8000-000000000001'),'current Auth metadata and ban carry closure state');
select set_config('request.jwt.claim.sub','99963000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claims','{"sub":"99963000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9996301"}',true);
set local role authenticated;
select throws_ok($$select public.bootstrap_supporter_profile(9996301,'Restored PII')$$,'42501','ACCOUNT_CLOSURE_PENDING','old JWT cannot bootstrap a profile via definer');
select throws_ok($$select public.predict_dashboard(9996301)$$,'42501','ACCOUNT_CLOSURE_PENDING','private definer dashboard rejects old JWT before nested reads');
select throws_ok($$select public.prepare_membership_payment('fan')$$,'42501','ACCOUNT_CLOSURE_PENDING','old JWT cannot prepare a financial operation');
select is((select count(*)::integer from public.profiles where id='99963000-0000-4000-8000-000000000001'),0,'direct sensitive read is denied by restrictive policy');
reset role;
-- Trigger also guards nested writes issued under a definer's elevated database role.
select throws_ok($$update public.fan_memberships set points=1 where user_id='99963000-0000-4000-8000-000000000001'$$,'42501','ACCOUNT_CLOSURE_PENDING','elevated write with stale actor claims denied');
select throws_ok(format('update public.%I set %I=%I where false',t,col,col),'42501','ACCOUNT_CLOSURE_PENDING',
 'nested elevated stale-bearer statement cannot write gateway table '||t)
from (values('trusted_sms_ingress_config','enabled'),('trusted_sms_gateways','enabled'),
 ('trusted_sms_gateway_keys','enabled'),('trusted_sms_gateway_events','status'),
 ('trusted_sms_gateway_nonces','body_digest')) tables(t,col);
select set_config('request.jwt.claim.sub','99963000-0000-4000-8000-000000000002',true);
select set_config('request.jwt.claims','{"sub":"99963000-0000-4000-8000-000000000002","role":"authenticated","club_id":"9996301"}',true);
select ok(public.account_access_allowed(),'unrelated account retains access');
select set_config('request.jwt.claims','{"role":"service_role"}',true); select set_config('request.jwt.claim.sub','',true);
set local role service_role;
insert into erasure_receipts values('claim',public.claim_account_erasure_jobs(1)->0);
select throws_ok($$select public.erase_account_local_batch((select (data->>'request_id')::uuid from erasure_receipts where label='claim'),gen_random_uuid(),10)$$,'P0001','ERASURE_LEASE_LOST','foreign lease cannot erase');
select throws_ok($$select public.claim_account_erasure_jobs(1000)$$,'P0001','INVALID_BATCH_SIZE','claim work budget capped');
select lives_ok($$select public.erase_account_local_batch((select (data->>'request_id')::uuid from erasure_receipts where label='claim'),(select (data->>'lease_token')::uuid from erasure_receipts where label='claim'),500)$$,'bounded local PII erasure executes');
reset role;
select is((select phone from public.users where id='99963000-0000-4000-8000-000000000001'),'closed:99963000-0000-4000-8000-000000000001','retained public subject has pseudonymous phone');
select ok((select full_name is null and display_name is null and avatar_url is null from public.profiles where id='99963000-0000-4000-8000-000000000001'),'compatibility profile trigger cannot restore personal fields');
select is((select points from public.fan_memberships where user_id='99963000-0000-4000-8000-000000000001'),700,'existing FET balance preserved');
select is((select balance_after from public.fet_wallet_ledger_entries where idempotency_key='erasure-opening'),700,'financial ledger balance preserved');
select is((select amount from public.momo_ledger_entries where external_reference='ERASURE-UNIQUE-TX'),1000,'posted amount and global evidence reference preserved');
select is((select momo_tx_id from public.momo_sms_parsed where id='99963000-0000-4000-8000-000000000201'),'ERASURE-UNIQUE-TX','anti-reuse parsed transaction identity preserved');
select is((select device_message_key from public.momo_sms_raw where id='99963000-0000-4000-8000-000000000200'),'erasure-evidence-identity','ingest identity preserved');
select is((select full_name from public.users where id='99963000-0000-4000-8000-000000000002'),'Personal QA 2','foreign subject PII unchanged');
set local role service_role;
select throws_ok($$select public.record_account_erasure_step((select (data->>'request_id')::uuid from erasure_receipts where label='claim'),(select (data->>'lease_token')::uuid from erasure_receipts where label='claim'),'auth',true,'fake acknowledgement')$$,'P0001','AUTH_NOT_SOFT_DELETED','fake Auth completion rejected by authoritative readback');
select lives_ok($$select public.record_account_erasure_step((select (data->>'request_id')::uuid from erasure_receipts where label='claim'),(select (data->>'lease_token')::uuid from erasure_receipts where label='claim'),'storage',false,null)$$,'provider failure is durably recorded');
select is((select state from public.account_erasure_jobs where user_id='99963000-0000-4000-8000-000000000001'),'failed','failure never becomes completed');
select throws_ok($$select public.acknowledge_account_erasure_obligation((select (data->>'request_id')::uuid from erasure_receipts where label='claim'),'99963000-0000-4000-8000-000000000001','processors','approved evidence QA')$$,'42501','ACTIVE_GLOBAL_ADMIN_REQUIRED','closed staff cannot acknowledge obligations');
select lives_ok($$select public.acknowledge_account_erasure_obligation((select (data->>'request_id')::uuid from erasure_receipts where label='claim'),'99963000-0000-4000-8000-000000000003','processors','processor evidence QA')$$,'current global actor records processor evidence');
select is((select state from public.account_erasure_jobs where user_id='99963000-0000-4000-8000-000000000001'),'failed','one processor acknowledgement does not fabricate completion');
reset role;
select ok(exists(select 1 from public.account_erasure_fk_inventory where subject_table='auth.users' and deletion_action='c'),'inventory includes cascading Auth relationships');
select ok(exists(select 1 from public.account_erasure_fk_inventory where child_table='football.predict_entries'),'restrictive prediction relationship inventoried');
select * from finish();
rollback;

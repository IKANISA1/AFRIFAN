begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.role','service_role',true);
select set_config('request.jwt.claim.sub','',true);
insert into public.african_football_clubs(id,club_name,country_name,country_iso_code,club_slug) overriding system value values
 (9996901,'Notification Command A','Rwanda','RW','notification-command-a'),(9996902,'Notification Command B','Rwanda','RW','notification-command-b');
insert into auth.users(id,aud,role,phone_confirmed_at,is_anonymous)
 select ('99969000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',now(),false from generate_series(1,4)n;
insert into public.users(id,phone,full_name)
 select ('99969000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+25079996900'||n,'Synthetic notification command '||n from generate_series(1,4)n;
insert into public.profiles(id,club_id)
 select ('99969000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,9996901 from generate_series(1,4)n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('99969000-0000-4000-8000-'||lpad((n+500)::text,12,'0'))::uuid,
 ('99969000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour' from generate_series(1,4)n;
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99969000-0000-4000-8000-000000000001','super_admin',null),
 ('99969000-0000-4000-8000-000000000002','club_admin',9996901);
insert into public.user_notification_settings(user_id,club_id,push_enabled) values('99969000-0000-4000-8000-000000000004',9996901,true);
insert into public.user_fcm_tokens(id,user_id,club_id,token) values
 ('99969000-0000-4000-8000-000000000601','99969000-0000-4000-8000-000000000004',9996901,'synthetic-notification-device-a'),
 ('99969000-0000-4000-8000-000000000602','99969000-0000-4000-8000-000000000004',9996901,'synthetic-notification-device-b');
create function pg_temp.notification_actor(n integer,age integer default 1,ttl integer default 3600,service boolean default false) returns void language plpgsql as $$
declare u text:='99969000-0000-4000-8000-'||lpad(n::text,12,'0');e bigint:=floor(extract(epoch from clock_timestamp()));begin
 perform set_config('request.jwt.claim.sub',case when service then '' else u end,true);
 perform set_config('request.jwt.claim.role',case when service then 'service_role' else 'authenticated' end,true);
 perform set_config('request.jwt.claims',case when service then '{"role":"service_role"}' else jsonb_build_object('sub',u,'role','authenticated',
 'is_anonymous',false,'aal','aal2','exp',e+ttl,'session_id','99969000-0000-4000-8000-'||lpad((n+500)::text,12,'0'),
 'app_metadata',jsonb_build_object('club_id',9996901),'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',e-age)))::text end,true);
end $$;
create function pg_temp.notification_args(p_mode text default 'send_now') returns jsonb language sql as $$
 select jsonb_build_object('title','Matchday alert','body','Kickoff soon.','audience','all_fans','tier',null,'group_id',null,'group_name',null,
 'delivery_mode',p_mode,'scheduled_at',case when p_mode='schedule' then to_char((clock_timestamp()-interval '1 minute') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"') end,'image_url',null);
$$;
grant execute on function pg_temp.notification_args(text) to authenticated,service_role;
create temporary table notification_receipts(key text primary key,value jsonb);
grant select,insert,update on notification_receipts to authenticated,service_role;
select ok(not exists(select 1 from unnest(array['admin_notification_commands','admin_notification_proofs','admin_notification_devices'])t
 cross join unnest(array['anon','authenticated','service_role'])r where has_table_privilege(r,'public.'||t,'SELECT,INSERT,UPDATE,DELETE')),'app/service identities cannot manufacture or alter command/proof/device barriers');
select ok(not exists(select 1 from unnest(array['public.admin_notification_arguments(jsonb)','public.admin_notification_canonical_json(jsonb)',
 'public.admin_notification_receipt(public.admin_notification_commands)','public.assert_admin_notification_feature(bigint)',
 'public.assert_admin_notification_dispatch_authority(public.admin_notification_commands)','public.initialize_admin_notification_targets(public.admin_notification_commands)',
 'public.lock_admin_notification_command(uuid,boolean)'])f
 cross join unnest(array['anon','authenticated','service_role'])r where has_function_privilege(r,f,'EXECUTE')),'all private notification engines/helpers remain ungranted');
select ok(has_function_privilege('authenticated','public.admit_admin_notification(uuid,bigint,jsonb)','EXECUTE')
 and not has_function_privilege('service_role','public.admit_admin_notification(uuid,bigint,jsonb)','EXECUTE'),'only actual caller JWT admits or renews human notification proof');
select ok(has_function_privilege('service_role','public.claim_admin_notification_device(uuid,uuid)','EXECUTE')
 and not has_function_privilege('authenticated','public.claim_admin_notification_device(uuid,uuid)','EXECUTE'),'per-device provider token/started admission is service-only');
select ok((select count(*)=3 from pg_policy where polrelid in('public.admin_notification_commands'::regclass,'public.admin_notification_proofs'::regclass,'public.admin_notification_devices'::regclass)
 and polname='account_lifecycle_access' and not polpermissive and polcmd='*' and polroles=array[(select oid from pg_roles where rolname='authenticated')]),'all new private tables retain exact restrictive lifecycle policies');
select is(encode(extensions.digest(convert_to(public.admin_notification_canonical_json(public.admin_notification_arguments(pg_temp.notification_args())),'UTF8'),'sha256'),'hex'),
 'c33bcee02a35aa9aaf21b2d42c475b68316e248c970b4db4e8e8eeebaa67ec6b','actual SQL command hash matches Edge fixed UTF8 JSON vector');
select pg_temp.notification_actor(1,1,3600,true);
set local role service_role;
select throws_ok($$select public.lock_admin_notification_command('99969000-0000-4000-8000-000000000701',true)$$,
 '42501',null,'actual service cannot turn private lock acquisition into dispatch authority');
select throws_ok($$select public.admit_admin_notification('99969000-0000-4000-8000-000000000701',9996901,pg_temp.notification_args())$$,'42501',null,'service role cannot mint a human notification command');
reset role;
select pg_temp.notification_actor(2);
set local role authenticated;
select throws_ok($$select public.lock_admin_notification_command('99969000-0000-4000-8000-000000000701',true)$$,
 '42501',null,'actual caller cannot directly lock other recipient or creator accounts');
select throws_ok($$select public.admit_admin_notification('99969000-0000-4000-8000-000000000701',9996901,pg_temp.notification_args())$$,'42501',null,'club staff cannot expand historical GLOBAL notification authority');
reset role;
select pg_temp.notification_actor(3);
set local role authenticated;
select throws_ok($$select public.admit_admin_notification('99969000-0000-4000-8000-000000000701',9996901,pg_temp.notification_args())$$,'42501',null,'fresh MFA alone never authorizes a fan');
reset role;
select pg_temp.notification_actor(1,301);
set local role authenticated;
select throws_ok($$select public.admit_admin_notification('99969000-0000-4000-8000-000000000701',9996901,pg_temp.notification_args())$$,'42501','STAFF_STEP_UP_REQUIRED','stale actual original TOTP cannot admit a command');
reset role;
select pg_temp.notification_actor(1);
select set_config('request.jwt.claims',jsonb_set(auth.jwt(),'{session_id}','"99969000-0000-4000-8000-000000000502"')::text,true);
set local role authenticated;
select throws_ok($$select public.admit_admin_notification('99969000-0000-4000-8000-000000000701',9996901,pg_temp.notification_args())$$,'42501',null,'actual vendor session of another user cannot authorize the actor');
reset role;
select pg_temp.notification_actor(1);
set local role authenticated;
select is(public.recover_admin_notification('99969000-0000-4000-8000-000000000701',9996901)->'command'->>'state','not_admitted','read-only status before send reports no admitted operation');
insert into notification_receipts values('admitted',public.admit_admin_notification('99969000-0000-4000-8000-000000000701',9996901,pg_temp.notification_args()));
select is((select value->'command'->>'state' from notification_receipts where key='admitted'),'admitted','actual valid global JWT admits the selected club command');
select lives_ok($$select public.admit_admin_notification('99969000-0000-4000-8000-000000000701',9996901,pg_temp.notification_args())$$,'same original ID/payload recovers its original admission');
select throws_ok($$select public.admit_admin_notification('99969000-0000-4000-8000-000000000701',9996901,pg_temp.notification_args()||'{"body":"changed"}')$$,'P0001','NOTIFICATION_COMMAND_BINDING_MISMATCH','changed payload never reuses an admitted ID');
select throws_ok($$select public.recover_admin_notification('99969000-0000-4000-8000-000000000701',9996902)$$,'P0001','NOTIFICATION_COMMAND_BINDING_MISMATCH','status cannot cross the original selected club');
reset role;
select is((select count(*)::integer from public.notifications where club_id=9996901),1,'status/repeat admission create exactly one notification');
select is((select count(*)::integer from public.admin_notification_proofs where operation_id='99969000-0000-4000-8000-000000000701'),1,'same issuer proof is immutable and not duplicated');
select pg_temp.notification_actor(1,1,3600,true);
set local role service_role;
select throws_ok($$select public.claim_admin_notification_command('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000809')$$,'42501','NOTIFICATION_ORIGINAL_PROOF_REQUIRED','immediate work cannot consume an unspecified later current proof');
insert into notification_receipts values('claim',public.claim_admin_notification_command('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000801',(select (value->>'dispatch_proof_id')::uuid from notification_receipts where key='admitted')));
select is((select (value->>'claimed')::boolean from notification_receipts where key='claim'),true,'service consumes the actual stored human proof');
select is(public.claim_admin_notification_command('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000802',(select (value->>'dispatch_proof_id')::uuid from notification_receipts where key='admitted'))->>'claimed','false','second worker cannot acquire a live lease');
insert into notification_receipts values('device-a',public.claim_admin_notification_device('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000801'));
reset role;
select is((select state from public.admin_notification_devices where delivery_id=(select (value->>'delivery_id')::uuid from notification_receipts where key='device-a')),'started','actual provider device RPC establishes durable started before provider work');
set local role service_role;
select throws_ok($$select public.complete_admin_notification_device('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000802',(select (value->>'delivery_id')::uuid from notification_receipts where key='device-a'),'accepted','projects/mock/messages/original')$$,
 '42501','NOTIFICATION_LEASE_LOST','foreign lease cannot publish a known provider result');
select lives_ok($$select public.complete_admin_notification_device('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000801',(select (value->>'delivery_id')::uuid from notification_receipts where key='device-a'),'accepted','projects/mock/messages/original')$$,'same live lease records an acknowledged provider name');
insert into notification_receipts values('device-b',public.claim_admin_notification_device('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000801'));
select lives_ok($$select public.complete_admin_notification_device('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000801',(select (value->>'delivery_id')::uuid from notification_receipts where key='device-b'),'unknown',null,'UNKNOWN')$$,'lost provider response records terminal unknown');
select ok(public.claim_admin_notification_device('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000801') is null,'known and unknown devices are never offered a second time');
insert into notification_receipts values('finished',public.finish_admin_notification_command('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000801'));
select is((select value->'delivery'->>'status' from notification_receipts where key='finished'),'unknown','one uncertain device prevents false whole-command success');
select is((select (value->'delivery'->>'sent_count')::integer from notification_receipts where key='finished'),1,'known accepted device remains accounted once');
select is((select (value->'delivery'->>'unknown_count')::integer from notification_receipts where key='finished'),1,'uncertain device remains accounted once');
select is(public.claim_admin_notification_command('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000802',(select (value->>'dispatch_proof_id')::uuid from notification_receipts where key='admitted'))->>'claimed','false','finished unknown command never reopens delivery');
reset role;
select pg_temp.notification_actor(1);
set local role authenticated;
select is(public.recover_admin_notification('99969000-0000-4000-8000-000000000701',9996901)->'delivery'->>'status','unknown','actual same-caller recovery returns the unknown result without delivery');
reset role;
select is((select count(*)::integer from public.admin_notification_devices where operation_id='99969000-0000-4000-8000-000000000701'),2,'recovery did not duplicate device targets');
-- A newly reviewed session cannot be borrowed by an older in-flight worker.
select pg_temp.notification_actor(3,1,3600,true);
insert into public.admin_role_assignments(user_id,role,club_id) values('99969000-0000-4000-8000-000000000003','admin',null);
select pg_temp.notification_actor(3);
set local role authenticated;
insert into notification_receipts values('old-session-admission',public.admit_admin_notification('99969000-0000-4000-8000-000000000703',9996901,pg_temp.notification_args()));
reset role;
select pg_temp.notification_actor(3,1,3600,true);
set local role service_role;
select lives_ok($$select public.claim_admin_notification_command('99969000-0000-4000-8000-000000000703','99969000-0000-4000-8000-000000000804',(select (value->>'dispatch_proof_id')::uuid from notification_receipts where key='old-session-admission'))$$,'old worker captures its original assurance proof in its lease');
insert into notification_receipts values('old-session-device',public.claim_admin_notification_device('99969000-0000-4000-8000-000000000703','99969000-0000-4000-8000-000000000804'));
reset role;
delete from auth.sessions where id='99969000-0000-4000-8000-000000000503';
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('99969000-0000-4000-8000-000000000553','99969000-0000-4000-8000-000000000003',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
select pg_temp.notification_actor(3);
select set_config('request.jwt.claims',jsonb_set(auth.jwt(),'{session_id}','"99969000-0000-4000-8000-000000000553"')::text,true);
set local role authenticated;
insert into notification_receipts values('new-session-admission',public.admit_admin_notification('99969000-0000-4000-8000-000000000703',9996901,pg_temp.notification_args()));
reset role;
select ok((select current_proof_id<>lease_proof_id from public.admin_notification_commands where operation_id='99969000-0000-4000-8000-000000000703'),'renewal retains original worker proof ownership');
select pg_temp.notification_actor(3,1,3600,true);
set local role service_role;
select throws_ok($$select public.complete_admin_notification_device('99969000-0000-4000-8000-000000000703','99969000-0000-4000-8000-000000000804',(select (value->>'delivery_id')::uuid from notification_receipts where key='old-session-device'),'accepted','projects/mock/messages/old')$$,
 '42501',null,'old delayed completion cannot borrow new session proof after logout');
reset role;
update public.admin_notification_commands set lease_until=clock_timestamp()-interval '1 second' where operation_id='99969000-0000-4000-8000-000000000703';
set local role service_role;
select throws_ok($$select public.claim_admin_notification_command('99969000-0000-4000-8000-000000000703','99969000-0000-4000-8000-000000000807',(select (value->>'dispatch_proof_id')::uuid from notification_receipts where key='old-session-admission'))$$,'42501',null,'old delayed claim cannot borrow the newly current proof after logout');
select lives_ok($$select public.claim_admin_notification_command('99969000-0000-4000-8000-000000000703','99969000-0000-4000-8000-000000000805',(select (value->>'dispatch_proof_id')::uuid from notification_receipts where key='new-session-admission'))$$,'new lease consumes actual newly reviewed proof after expired old lease');
insert into notification_receipts values('new-session-device',public.claim_admin_notification_device('99969000-0000-4000-8000-000000000703','99969000-0000-4000-8000-000000000805'));
select isnt((select value->>'delivery_id' from notification_receipts where key='new-session-device'),(select value->>'delivery_id' from notification_receipts where key='old-session-device'),'new worker receives only the other never-started device');
select lives_ok($$select public.complete_admin_notification_device('99969000-0000-4000-8000-000000000703','99969000-0000-4000-8000-000000000805',(select (value->>'delivery_id')::uuid from notification_receipts where key='new-session-device'),'accepted','projects/mock/messages/new')$$,'new reviewed lease records only its own device result');
select is(public.finish_admin_notification_command('99969000-0000-4000-8000-000000000703','99969000-0000-4000-8000-000000000805')->'delivery'->>'unknown_count','1','expired old device stays unknown permanently after same-user reauthentication');
reset role;

-- Exercise real wall-clock expiry inside the actual notification UPDATE. The
-- test-only trigger delays that mutation after the earlier proof check; no
-- device provider is invoked, and the failed claim must roll back its barriers.
select pg_temp.notification_actor(3);
select set_config('request.jwt.claims',jsonb_set(jsonb_set(auth.jwt(),'{session_id}',
 '"99969000-0000-4000-8000-000000000553"'),'{exp}',to_jsonb(floor(extract(epoch from clock_timestamp()))::bigint+3))::text,true);
set local role authenticated;
insert into notification_receipts values('expiry-admitted',public.admit_admin_notification('99969000-0000-4000-8000-000000000704',9996901,pg_temp.notification_args()));
reset role;
create function pg_temp.delay_notification_claim_mutation() returns trigger language plpgsql as $$ begin
 if new.id=(select (value->'command'->>'notification_id')::uuid from pg_temp.notification_receipts where key='expiry-admitted') then
  perform pg_sleep(4);
 end if;
 return new;
end $$;
create trigger notification_contract_expiry_delay before update on public.notifications
 for each row execute function pg_temp.delay_notification_claim_mutation();
select pg_temp.notification_actor(3,1,3600,true);
set local role service_role;
select throws_ok($$select public.claim_admin_notification_command('99969000-0000-4000-8000-000000000704','99969000-0000-4000-8000-000000000806',(select (value->>'dispatch_proof_id')::uuid from notification_receipts where key='expiry-admitted'))$$,
 '42501','PROVIDER_ASSURANCE_EXPIRED','notification mutation delay cannot return an already expired successful claim');
reset role;
drop trigger notification_contract_expiry_delay on public.notifications;
select is((select state from public.admin_notification_commands where operation_id='99969000-0000-4000-8000-000000000704'),'admitted','expired claim rolls back command lease acquisition');
select is((select count(*)::integer from public.admin_notification_devices where operation_id='99969000-0000-4000-8000-000000000704'),0,'expired claim rolls back target/device barriers before provider dispatch');

-- A later session cannot make a previous proof live; cron has a separate already
-- committed scheduling authority instead of a fabricated human assurance waiver.
select pg_temp.notification_actor(1);
set local role authenticated;
insert into notification_receipts values('scheduled',public.admit_admin_notification('99969000-0000-4000-8000-000000000702',9996901,pg_temp.notification_args('schedule')));
reset role;
select pg_temp.notification_actor(1,1,3600,true);
delete from auth.sessions where id='99969000-0000-4000-8000-000000000501';
update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='99969000-0000-4000-8000-000000000001';
update auth.users set deleted_at=clock_timestamp() where id='99969000-0000-4000-8000-000000000001';
set local role service_role;
select is(public.claim_admin_notification_command('99969000-0000-4000-8000-000000000702','99969000-0000-4000-8000-000000000803')->>'claimed','true','committed due schedule remains independent cron authority after creator logout/revocation/soft deletion');
reset role;
-- Model an original pre-migration due job whose creator was already absent.
-- Owner-only fixture setup is separate from actual service claim capability.
insert into public.notifications(id,club_id,created_by,title,body,audience_type,delivery_mode,scheduled_at,status)
 values('99969000-0000-4000-8000-000000000750',9996901,null,'Retained legacy due job','No provider invocation.',
 'all_fans','schedule',clock_timestamp()-interval '1 minute','scheduled');
insert into public.admin_notification_commands(operation_id,notification_id,actor_id,club_id,arguments,arguments_sha256,delivery_mode,authority_kind,state)
 select n.id,n.id,n.created_by,n.club_id,a.value,encode(extensions.digest(convert_to(public.admin_notification_canonical_json(a.value),'UTF8'),'sha256'),'hex'),
 'schedule','legacy_scheduled','scheduled' from public.notifications n
 cross join lateral(select public.admin_notification_arguments(jsonb_build_object('title',n.title,'body',n.body,'audience','all_fans',
 'delivery_mode','schedule','scheduled_at',n.scheduled_at)) value)a where n.id='99969000-0000-4000-8000-000000000750';
set local role service_role;
insert into notification_receipts values('legacy-null-creator',public.claim_admin_notification_command(
 '99969000-0000-4000-8000-000000000750','99969000-0000-4000-8000-000000000850'));
select is((select value->>'claimed' from notification_receipts where key='legacy-null-creator'),'true',
 'actual service can claim independently committed legacy job with NULL creator');
select ok((select value->'actor_id'='null'::jsonb and value->'lease_proof_id'='null'::jsonb and value->>'authority_kind'='legacy_scheduled'
 from notification_receipts where key='legacy-null-creator'),'legacy NULL creator acquires no invented actor or human proof');
reset role;
select ok(not exists(select 1 from pg_constraint c where c.contype='f' and c.confrelid in('auth.users'::regclass,'public.users'::regclass,'public.profiles'::regclass)
 and not exists(select 1 from public.account_erasure_fk_inventory i where i.constraint_oid=c.oid and i.child_table=c.conrelid::regclass::text and i.subject_table=c.confrelid::regclass::text and i.deletion_action=c.confdeltype::text)),
 'complete current original subject FK inventory remains exact after new command actor relationship');
select * from finish();
rollback;

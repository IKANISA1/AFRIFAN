begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','service_role',true);
insert into public.african_football_clubs(id,club_name,country_name,country_iso_code,club_slug,is_active) overriding system value values
 (9996901,'Media Admission A','Rwanda','RW','media-admission-a',true),(9996902,'Media Admission B','Rwanda','RW','media-admission-b',true);
insert into auth.users(id,aud,role,is_anonymous) select ('99969000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',false from generate_series(1,4)n;
insert into public.users(id,phone,full_name) select ('99969000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+25079996900'||n,'Synthetic media actor '||n from generate_series(1,4)n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('99969000-0000-4000-8000-'||lpad((n+950)::text,12,'0'))::uuid,('99969000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour' from generate_series(1,4)n;
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99969000-0000-4000-8000-000000000001','club_admin',9996901),('99969000-0000-4000-8000-000000000002','admin',null),
 ('99969000-0000-4000-8000-000000000003','club_admin',9996902);
create function pg_temp.media_actor(n int,age int default 1,ttl int default 3600,service boolean default false) returns void language plpgsql as $$
declare u text:='99969000-0000-4000-8000-'||lpad(n::text,12,'0'); e bigint:=floor(extract(epoch from clock_timestamp())); begin
 perform set_config('request.jwt.claim.sub',case when service then '' else u end,true);
 perform set_config('request.jwt.claim.role',case when service then 'service_role' else 'authenticated' end,true);
 perform set_config('request.jwt.claims',case when service then '{"role":"service_role"}' else jsonb_build_object('sub',u,'role','authenticated','club_id',9996901,
 'aal','aal2','is_anonymous',false,'exp',e+ttl,'session_id','99969000-0000-4000-8000-'||lpad((n+950)::text,12,'0'),
 'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',e-age)))::text end,true);
end $$;
create function pg_temp.media_admit(n int) returns jsonb language sql as $$
 select public.admit_admin_media_upload(('99969000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,9996901,'shop_product','image/png',9,repeat('a',64));
$$;
-- Real vendor row/trigger projection, not a hosted provider acknowledgement.
-- The Edge suite separately verifies actual downloaded bytes against the digest.
create function pg_temp.media_store(op int,token int,obj int) returns void language plpgsql security definer set search_path='' as $$
declare u public.admin_media_uploads; begin
 select * into strict u from public.admin_media_uploads where operation_id=('99969000-0000-4000-8000-'||lpad(op::text,12,'0'))::uuid;
 insert into storage.objects(id,bucket_id,name,version,metadata,user_metadata) values
 (('99969000-0000-4000-8000-'||lpad(obj::text,12,'0'))::uuid,u.bucket,u.storage_path,gen_random_uuid()::text,
 jsonb_build_object('mimetype',u.mime_type,'size',u.byte_length),jsonb_build_object('operation_id',u.operation_id,
 'lease_token','99969000-0000-4000-8000-'||lpad(token::text,12,'0'),'content_sha256',u.content_sha256));
end $$;
revoke all on function pg_temp.media_actor(int,int,int,boolean),pg_temp.media_admit(int),pg_temp.media_store(int,int,int)
 from public,anon,authenticated,service_role;
grant execute on function pg_temp.media_admit(int) to authenticated;
grant execute on function pg_temp.media_store(int,int,int) to service_role;
select ok(has_function_privilege('authenticated','public.admit_admin_media_upload(uuid,bigint,text,text,integer,text)','EXECUTE')
 and has_function_privilege('authenticated','public.get_admin_media_upload_status(uuid)','EXECUTE')
 and not has_function_privilege('service_role','public.admit_admin_media_upload(uuid,bigint,text,text,integer,text)','EXECUTE'),'only original caller admits or renews media assurance');
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role'])r cross join unnest(array['admin_media_uploads','admin_media_upload_proofs','admin_media_upload_releases'])t
 where has_table_privilege(r,'public.'||t,'SELECT,INSERT,UPDATE,DELETE')),'all private receipts and proofs deny direct app access');
select ok(not exists(select 1 from unnest(array['public.claim_admin_media_upload(uuid,uuid)','public.complete_admin_media_upload(uuid,uuid,text,uuid,text)'])f
 where has_function_privilege('authenticated',f,'EXECUTE') or not has_function_privilege('service_role',f,'EXECUTE')),'service consumes already admitted commands only');
select ok((select count(*)=2 from pg_policy where polrelid in('public.admin_media_uploads'::regclass,'public.admin_media_upload_proofs'::regclass)
 and polname='account_lifecycle_access' and not polpermissive and polcmd='*' and polroles=array['authenticated'::regrole::oid]),'both private tables carry exact lifecycle policies');
select ok(exists(select 1 from public.account_erasure_fk_inventory i join pg_constraint c on c.oid=i.constraint_oid
 where c.conrelid='public.admin_media_uploads'::regclass and c.confrelid='auth.users'::regclass and i.retained and i.deletion_action='r')
 and not exists(select 1 from pg_constraint where conrelid='public.admin_media_upload_proofs'::regclass and confrelid='auth.sessions'::regclass),'retained actors inventoried without blocking Auth logout');
select pg_temp.media_actor(1,1,3600,true);
select throws_ok($$select public.claim_admin_media_upload('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000901')$$,'42501','MEDIA_ADMISSION_REQUIRED','service cannot invent human command');
select throws_ok($$select pg_temp.media_admit(701)$$,'42501','MEDIA_CALLER_REQUIRED','service cannot fabricate JWT admission');
select pg_temp.media_actor(1,301);
select throws_ok($$select pg_temp.media_admit(701)$$,'42501','STAFF_STEP_UP_REQUIRED','stale MFA denies admission');
select pg_temp.media_actor(4);
select throws_ok($$select pg_temp.media_admit(701)$$,'42501','MEDIA_CLUB_AUTHORITY_REQUIRED','supporter AAL2 is not staff authority');
select pg_temp.media_actor(3);
select throws_ok($$select pg_temp.media_admit(701)$$,'42501','MEDIA_CLUB_AUTHORITY_REQUIRED','foreign club cannot repair tenant');
select pg_temp.media_actor(1);
select set_config('request.jwt.claims',jsonb_set(auth.jwt(),'{session_id}','"99969000-0000-4000-8000-000000000952"')::text,true);
select throws_ok($$select pg_temp.media_admit(701)$$,'42501','MEDIA_SESSION_REVOKED','foreign live session cannot establish proof');
select pg_temp.media_actor(1);
set local role authenticated;
select is(pg_temp.media_admit(701)->>'status','pending','actual club caller persists pending before provider I/O');
select is(pg_temp.media_admit(701)->>'operation_id','99969000-0000-4000-8000-000000000701','repeat admission preserves original command');
select is(public.get_admin_media_upload_status('99969000-0000-4000-8000-000000000799'),null::jsonb,'unissued original cannot fabricate pending');
select throws_ok($$select public.admit_admin_media_upload('99969000-0000-4000-8000-000000000701',9996901,'shop_product','image/png',10,repeat('a',64))$$,'22023','MEDIA_COMMAND_BINDING_MISMATCH','original cannot change immutable byte count');
reset role;
select is((select count(*)::int from public.admin_media_upload_proofs where operation_id='99969000-0000-4000-8000-000000000701'),1,'duplicate token does not grow proofs');
select pg_temp.media_actor(2);
set local role authenticated;
select is(public.get_admin_media_upload_status('99969000-0000-4000-8000-000000000701'),null::jsonb,'another global actor cannot recover foreign owner');
select throws_ok($$select pg_temp.media_admit(701)$$,'22023','MEDIA_COMMAND_BINDING_MISMATCH','global actor cannot take over another operation');
reset role;
select pg_temp.media_actor(1,1,3600,true);
set local role service_role;
select is(public.claim_admin_media_upload('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000901')->>'status','uploading','service persists bounded lease before remote call');
select is((public.claim_admin_media_upload('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000902')->>'claimed')::boolean,false,'overlapping lease cannot repeat effect');
select throws_ok($$select pg_temp.media_store(701,902,801)$$,'42501','MEDIA_LEASE_LOST','another lease cannot create object');
select lives_ok($$select pg_temp.media_store(701,901,801)$$,'actual vendor row passes exact lease/authority/object guard');
reset role;
select is((select status from public.admin_media_uploads where operation_id='99969000-0000-4000-8000-000000000701'),'staged','committed object alone never proves completion');
select throws_ok($$update storage.objects set name='unguarded-renamed.png' where id='99969000-0000-4000-8000-000000000801'$$,'P0001','MEDIA_OBJECT_IMMUTABLE','rename outside namespace cannot bypass immutable object');
select throws_ok($$update storage.objects set version=gen_random_uuid()::text where id='99969000-0000-4000-8000-000000000801'$$,'P0001','MEDIA_OBJECT_IMMUTABLE','upsert cannot replace committed bytes');
select pg_temp.media_actor(1,1,3600,true);
set local role service_role;
select throws_ok($$select public.complete_admin_media_upload('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000901','stored','99969000-0000-4000-8000-000000000801',repeat('b',64))$$,'P0001','MEDIA_OBJECT_MISMATCH','provider ack cannot forge canonical digest');
select is(public.complete_admin_media_upload('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000901','stored','99969000-0000-4000-8000-000000000801',repeat('a',64))->>'status','completed','current proof and exact readback projection confirm receipt');
select is(public.complete_admin_media_upload('99969000-0000-4000-8000-000000000701','99969000-0000-4000-8000-000000000901','stored','99969000-0000-4000-8000-000000000801',repeat('a',64))->>'operation_id','99969000-0000-4000-8000-000000000701','lost completion ack recovers original receipt');
reset role;
select throws_ok($$update public.admin_media_upload_proofs set expires_at=clock_timestamp()+interval '1 day'$$,'P0001','MEDIA_COMMAND_IMMUTABLE','maintenance cannot silently extend proofs');
select throws_ok($$update public.admin_media_uploads set content_sha256=repeat('b',64) where operation_id='99969000-0000-4000-8000-000000000701'$$,'P0001','MEDIA_COMMAND_IMMUTABLE','completed original cannot be replaced');

select pg_temp.media_actor(1,1,3);
set local role authenticated; select pg_temp.media_admit(702); reset role;
select pg_temp.media_actor(1,1,3600,true);
set local role service_role;
select public.claim_admin_media_upload('99969000-0000-4000-8000-000000000702','99969000-0000-4000-8000-000000000912');
select pg_temp.media_store(702,912,802);
select pg_sleep(3.2);
select is(public.complete_admin_media_upload('99969000-0000-4000-8000-000000000702','99969000-0000-4000-8000-000000000912','stored','99969000-0000-4000-8000-000000000802',repeat('a',64))->>'status','staged','post-provider proof expiry never claims success or erasure');
reset role;
select pg_temp.media_actor(1);
set local role authenticated; select pg_temp.media_admit(702); reset role;
select pg_temp.media_actor(1,1,3600,true);
set local role service_role;
select public.claim_admin_media_upload('99969000-0000-4000-8000-000000000702','99969000-0000-4000-8000-000000000913');
select is(public.complete_admin_media_upload('99969000-0000-4000-8000-000000000702','99969000-0000-4000-8000-000000000913','stored','99969000-0000-4000-8000-000000000802',repeat('a',64))->>'status','completed','fresh same-command proof reconciles original stored image');
reset role;
select is((select count(*)::int from storage.objects where name='club-9996901/admin/shop_product/99969000-0000-4000-8000-000000000702.png'),1,'fresh reconciliation retains one object');
select is((select count(*)::int from public.admin_media_upload_proofs where operation_id='99969000-0000-4000-8000-000000000702'),2,'fresh retry appends proof instead of overwriting');

select pg_temp.media_actor(1,297);
set local role authenticated; select pg_temp.media_admit(703); reset role;
select pg_temp.media_actor(1,1,3600,true);
select public.claim_admin_media_upload('99969000-0000-4000-8000-000000000703','99969000-0000-4000-8000-000000000923');
create function pg_temp.media_delay() returns trigger language plpgsql as $$ begin
 if new.name='club-9996901/admin/shop_product/99969000-0000-4000-8000-000000000703.png' then perform pg_sleep(3.2); end if;return new;end $$;
create trigger zz_media_delay before insert on storage.objects for each row execute function pg_temp.media_delay();
select throws_ok($$select pg_temp.media_store(703,923,803)$$,'42501','MEDIA_ASSURANCE_EXPIRED','AFTER guard rejects proof expiring during actual insert wait');
select is((select count(*)::int from storage.objects where id='99969000-0000-4000-8000-000000000803'),0,'late denial rolls back object publication');
drop trigger zz_media_delay on storage.objects;
select pg_temp.media_actor(1);
set local role authenticated; select pg_temp.media_admit(704); reset role;
delete from auth.sessions where id='99969000-0000-4000-8000-000000000951';
select pg_temp.media_actor(1,1,3600,true);
select throws_ok($$select public.claim_admin_media_upload('99969000-0000-4000-8000-000000000704','99969000-0000-4000-8000-000000000924')$$,'42501','MEDIA_SESSION_REVOKED','actual logout denies fresh Storage effects');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('99969000-0000-4000-8000-000000000951','99969000-0000-4000-8000-000000000001',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
select pg_temp.media_actor(1);
set local role authenticated; select pg_temp.media_admit(705); reset role;
select pg_temp.media_actor(1,1,3600,true);
update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='99969000-0000-4000-8000-000000000001';
select throws_ok($$select public.claim_admin_media_upload('99969000-0000-4000-8000-000000000705','99969000-0000-4000-8000-000000000925')$$,'42501','MEDIA_CLUB_AUTHORITY_REQUIRED','current scoped grant revocation denies effects');
update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='99969000-0000-4000-8000-000000000001';
select public.request_account_erasure('99969000-0000-4000-8000-000000000001','99969000-0000-4000-8000-000000000999');
select throws_ok($$select public.claim_admin_media_upload('99969000-0000-4000-8000-000000000705','99969000-0000-4000-8000-000000000925')$$,'42501','ACCOUNT_CLOSURE_PENDING','closure denies sensitive resume without destroying evidence');
select is((select count(*)::int from public.admin_media_uploads where actor_id='99969000-0000-4000-8000-000000000001'),5,'closure retains original accountable commands');
select ok(has_function_privilege('authenticated','public.release_unadmitted_admin_media_upload(uuid,bigint)','EXECUTE')
 and not has_function_privilege('service_role','public.release_unadmitted_admin_media_upload(uuid,bigint)','EXECUTE')
 and not has_function_privilege('anon','public.release_unadmitted_admin_media_upload(uuid,bigint)','EXECUTE'),
 'only the original current human caller can create a release tombstone');
select ok(exists(select 1 from pg_constraint c join public.account_erasure_fk_inventory i on i.constraint_oid=c.oid
 where c.conrelid='public.admin_media_upload_releases'::regclass and c.confrelid='auth.users'::regclass and c.confdeltype='r'
 and i.retained and i.deletion_action='r' and to_regclass(i.child_table)=c.conrelid and to_regclass(i.subject_table)=c.confrelid)
 and exists(select 1 from pg_policy p where p.polrelid='public.admin_media_upload_releases'::regclass
 and p.polname='account_lifecycle_access' and not p.polpermissive and p.polcmd='*'
 and p.polroles=array['authenticated'::regrole::oid]
 and pg_get_expr(p.polqual,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$'
 and pg_get_expr(p.polwithcheck,p.polrelid) ~ '^(public\.)?account_access_allowed\(\)$'),
 'opaque release actor is retained and the private tombstone has exact restrictive lifecycle policy');
select pg_temp.media_actor(2,1,3600,true);
set local role service_role;
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000799',9996901)$$,
 '42501','permission denied for function release_unadmitted_admin_media_upload','actual service role cannot invent human release assurance');
reset role;
select pg_temp.media_actor(2,301);
set local role authenticated;
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000799',9996901)$$,
 '42501','STAFF_STEP_UP_REQUIRED','stale original authenticator denies release');
reset role;
select pg_temp.media_actor(3);
set local role authenticated;
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000799',9996901)$$,
 '42501','MEDIA_CLUB_AUTHORITY_REQUIRED','foreign club cannot release an original UUID in this club');
reset role;
select pg_temp.media_actor(2);
select set_config('request.jwt.claims',jsonb_set(auth.jwt(),'{session_id}','"99969000-0000-4000-8000-000000000953"')::text,true);
set local role authenticated;
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000799',9996901)$$,
 '42501','MEDIA_SESSION_REVOKED','foreign live session cannot authenticate a release');
reset role;
select pg_temp.media_actor(2);
set local role authenticated;
select is(public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000799',9996901),
 jsonb_build_object('operation_id','99969000-0000-4000-8000-000000000799','actor_id','99969000-0000-4000-8000-000000000002','club_id',9996901,'released',true),
 'actual current global caller releases a never-admitted original with bound receipt');
select is(public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000799',9996901),
 jsonb_build_object('operation_id','99969000-0000-4000-8000-000000000799','actor_id','99969000-0000-4000-8000-000000000002','club_id',9996901,'released',true),
 'lost release response replays exact original bound acknowledgement');
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000799',9996902)$$,
 '22023','MEDIA_COMMAND_BINDING_MISMATCH','even a global caller cannot change released original club');
select throws_ok($$select pg_temp.media_admit(799)$$,'22023','MEDIA_OPERATION_RELEASED','released original can never be admitted for later remote effects');
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000701',9996901)$$,
 '22023','MEDIA_RELEASE_UNAVAILABLE','completed original cannot be released or claim provider deletion');
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000705',9996901)$$,
 '22023','MEDIA_RELEASE_UNAVAILABLE','pending original cannot be released or aborted after admission');
reset role;
select pg_temp.media_actor(3);
set local role authenticated;
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000799',9996902)$$,
 '22023','MEDIA_COMMAND_BINDING_MISMATCH','another valid club actor cannot take a released original UUID');
reset role;
select pg_temp.media_actor(1);
set local role authenticated;
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000797',9996901)$$,
 '42501','STAFF_STEP_UP_REQUIRED','closed actor with revoked assignment fails the first staff guard before unadmitted release');
reset role;
select pg_temp.media_actor(2,1,3600,true);
select is((select count(*)::int from public.admin_media_upload_releases where operation_id='99969000-0000-4000-8000-000000000797'),0,
 'closed caller denial creates no release tombstone');
select is((select count(*)::int from public.admin_media_uploads where operation_id='99969000-0000-4000-8000-000000000797'),0,
 'closed caller denial creates no admission or remote-write authority');
select is((select count(*)::int from public.admin_media_upload_releases),1,'only one immutable release tombstone exists after exact replay');
select is((select count(*)::int from public.admin_media_uploads where operation_id='99969000-0000-4000-8000-000000000799'),0,'release has no admitted command or upload proof');
select throws_ok($$update public.admin_media_upload_releases set club_id=9996902$$,'P0001','MEDIA_COMMAND_IMMUTABLE','tombstone identity cannot be reassigned');
select throws_ok($$delete from public.admin_media_upload_releases$$,'P0001','MEDIA_COMMAND_IMMUTABLE','maintenance cannot revive released originals by deletion');
select pg_temp.media_actor(2,1,3600,true);
set local role service_role;
select throws_ok($$select public.claim_admin_media_upload('99969000-0000-4000-8000-000000000799','99969000-0000-4000-8000-000000000929')$$,
 '42501','MEDIA_ADMISSION_REQUIRED','released unadmitted original has no service claim or remote effect');
reset role;
-- An actual write wait expiring the original JWT must roll back the tombstone.
create function pg_temp.delay_media_release() returns trigger language plpgsql as $$ begin
 if new.operation_id='99969000-0000-4000-8000-000000000798' then perform pg_sleep(3.2); end if; return new; end $$;
create trigger zz_media_release_wait after insert on public.admin_media_upload_releases for each row execute function pg_temp.delay_media_release();
select pg_temp.media_actor(2,1,3);
set local role authenticated;
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000798',9996901)$$,
 '42501','STAFF_STEP_UP_REQUIRED','actual tombstone write wait cannot outlive original JWT assurance');
reset role;
drop trigger zz_media_release_wait on public.admin_media_upload_releases;
select is((select count(*)::int from public.admin_media_upload_releases where operation_id='99969000-0000-4000-8000-000000000798'),0,'late denial rolls back release and provides no false acknowledgement');
select pg_temp.media_actor(2,1,3600,true);
delete from auth.sessions where id='99969000-0000-4000-8000-000000000952';
select pg_temp.media_actor(2);
set local role authenticated;
select throws_ok($$select public.release_unadmitted_admin_media_upload('99969000-0000-4000-8000-000000000799',9996901)$$,
 '42501','MEDIA_SESSION_REVOKED','deleted original Auth session cannot recover even a release receipt');
reset role;
select * from finish();
rollback;

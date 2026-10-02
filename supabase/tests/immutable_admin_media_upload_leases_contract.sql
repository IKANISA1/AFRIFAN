begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','service_role',true);
insert into public.african_football_clubs(id,club_name,country_name,country_iso_code,club_slug,is_active)
 overriding system value values(9996731,'Immutable Upload Lease QA','Rwanda','RW','immutable-upload-lease-qa',true);
insert into auth.users(id,aud,role,is_anonymous) values
 ('99967300-0000-4000-8000-000000000001','authenticated','authenticated',false);
insert into public.users(id,phone,full_name) values
 ('99967300-0000-4000-8000-000000000001','+250799967301','Synthetic immutable upload actor');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('99967300-0000-4000-8000-000000000951','99967300-0000-4000-8000-000000000001',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99967300-0000-4000-8000-000000000001','club_admin',9996731);
create temp table media_lease_receipts(n int primary key,receipt jsonb,first_proof uuid);
grant select,insert,update on media_lease_receipts to authenticated;
grant select on media_lease_receipts to service_role;
create function pg_temp.lease_actor(ttl int default 600,session_n int default 951,service boolean default false) returns void language plpgsql as $$
declare u text:='99967300-0000-4000-8000-000000000001';e bigint:=floor(extract(epoch from clock_timestamp()));begin
 perform set_config('request.jwt.claim.sub',case when service then '' else u end,true);
 perform set_config('request.jwt.claim.role',case when service then 'service_role' else 'authenticated' end,true);
 perform set_config('request.jwt.claims',case when service then '{"role":"service_role"}' else jsonb_build_object('sub',u,'role','authenticated',
  'is_anonymous',false,'aal','aal2','exp',e+ttl,'session_id','99967300-0000-4000-8000-'||lpad(session_n::text,12,'0'),
  'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',e)))::text end,true);
end $$;
create function pg_temp.lease_admit(n int) returns jsonb language plpgsql as $$declare r jsonb;begin
 r:=public.admit_admin_media_upload(('99967300-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,9996731,'shop_product','image/png',9,repeat('a',64));
 insert into pg_temp.media_lease_receipts(n,receipt,first_proof) values(n,r,(r->>'dispatch_proof_id')::uuid)
 on conflict on constraint media_lease_receipts_pkey do update set receipt=excluded.receipt;
 return r;
end $$;
create function pg_temp.lease_claim(n int,token int,original boolean default false) returns jsonb language sql as $$
 select public.claim_admin_media_upload(('99967300-0000-4000-8000-'||lpad($1::text,12,'0'))::uuid,
 ('99967300-0000-4000-8000-'||lpad($2::text,12,'0'))::uuid,
 case when $3 then first_proof else (receipt->>'dispatch_proof_id')::uuid end) from pg_temp.media_lease_receipts where n=$1;
$$;
create function pg_temp.lease_begin(n int,token int) returns jsonb language sql as $$
 select public.begin_admin_media_upload(('99967300-0000-4000-8000-'||lpad($1::text,12,'0'))::uuid,
 ('99967300-0000-4000-8000-'||lpad($2::text,12,'0'))::uuid);
$$;
-- Exact vendor row projection only; actual downloaded bytes are tested in Deno.
create function pg_temp.lease_store(n int,token int,obj int) returns void language plpgsql security definer set search_path='' as $$declare u public.admin_media_uploads;begin
 select * into strict u from public.admin_media_uploads where operation_id=('99967300-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
 insert into storage.objects(id,bucket_id,name,version,metadata,user_metadata) values
 (('99967300-0000-4000-8000-'||lpad(obj::text,12,'0'))::uuid,u.bucket,u.storage_path,gen_random_uuid()::text,
 jsonb_build_object('mimetype',u.mime_type,'size',u.byte_length),jsonb_build_object('operation_id',u.operation_id,
 'lease_token','99967300-0000-4000-8000-'||lpad(token::text,12,'0'),'content_sha256',u.content_sha256));
end $$;
create function pg_temp.lease_complete(n int,token int,outcome text,obj int default null) returns jsonb language sql as $$
 select public.complete_admin_media_upload(('99967300-0000-4000-8000-'||lpad($1::text,12,'0'))::uuid,
 ('99967300-0000-4000-8000-'||lpad($2::text,12,'0'))::uuid,$3,
 case when $4 is not null then ('99967300-0000-4000-8000-'||lpad($4::text,12,'0'))::uuid end,
 case when $3='stored' then repeat('a',64) end);
$$;
revoke all on function pg_temp.lease_actor(int,int,boolean),pg_temp.lease_admit(int),pg_temp.lease_claim(int,int,boolean),
 pg_temp.lease_begin(int,int),pg_temp.lease_store(int,int,int),pg_temp.lease_complete(int,int,text,int) from public,anon,authenticated,service_role;
grant execute on function pg_temp.lease_admit(int) to authenticated;
grant execute on function pg_temp.lease_claim(int,int,boolean),pg_temp.lease_begin(int,int),pg_temp.lease_store(int,int,int),pg_temp.lease_complete(int,int,text,int) to service_role;
select ok(not exists(select 1 from unnest(array['public.claim_admin_media_upload(uuid,uuid,uuid)','public.begin_admin_media_upload(uuid,uuid)'])f
 where has_function_privilege('authenticated',f,'EXECUTE') or has_function_privilege('anon',f,'EXECUTE') or not has_function_privilege('service_role',f,'EXECUTE')),
 'only service consumes exact caller proof and original attempt barrier');
select ok(not has_function_privilege('service_role','public.assert_admin_media_upload_lease(public.admin_media_uploads)','EXECUTE')
 and not exists(select 1 from pg_constraint where conrelid='public.admin_media_uploads'::regclass and confrelid='auth.sessions'::regclass),
 'service cannot fabricate lease assurance and real Auth logout remains unblocked');
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role'])r
 where has_function_privilege(r,'public.lock_admin_media_upload_operation(uuid)','EXECUTE')),
 'private actor-before-operation lock helper grants no caller or service authority');
select pg_temp.lease_actor();set local role authenticated;
select throws_ok($$select public.lock_admin_media_upload_operation('99967300-0000-4000-8000-000000000701')$$,
 '42501',null,'actual authenticated role cannot use the private lock helper');
select is(pg_temp.lease_admit(701)->>'status','pending','actual caller commits pending under actual session');reset role;
select pg_temp.lease_actor(600,951,true);set local role service_role;
select throws_ok($$select public.lock_admin_media_upload_operation('99967300-0000-4000-8000-000000000701')$$,
 '42501',null,'actual service role cannot acquire private locks as authority');
select throws_ok($$select public.claim_admin_media_upload('99967300-0000-4000-8000-000000000701','99967300-0000-4000-8000-000000000901')$$,
 '42501','MEDIA_ORIGINAL_PROOF_REQUIRED','legacy service identity cannot invent a current human command');
select throws_ok($$select public.claim_admin_media_upload('99967300-0000-4000-8000-000000000701','99967300-0000-4000-8000-000000000901',gen_random_uuid())$$,
 '42501','MEDIA_ORIGINAL_PROOF_REQUIRED','unknown proof UUID grants no effect');
select is((pg_temp.lease_claim(701,901)->>'claimed')::boolean,true,'exact original authenticated proof grants one lease');
select throws_ok($$select pg_temp.lease_store(701,901,801)$$,'42501','MEDIA_STORAGE_ATTEMPT_REQUIRED','claim alone cannot dispatch Storage');
select is((pg_temp.lease_begin(701,901)->>'upload_permitted')::boolean,true,'durable original attempt reservation precedes Storage');
select is((pg_temp.lease_begin(701,901)->>'upload_permitted')::boolean,false,'lost begin ACK cannot grant a repeated upload');
select lives_ok($$select pg_temp.lease_store(701,901,801)$$,'original reserved attempt passes actual vendor guards');
select is(pg_temp.lease_complete(701,901,'stored',801)->>'status','completed','exact readback and original leased proof complete');
select is(public.claim_admin_media_upload('99967300-0000-4000-8000-000000000701','99967300-0000-4000-8000-000000000999')->>'status','completed',
 'legacy completed receipt recovery remains read only');reset role;

-- A new admission changes only the current review pointer. The old worker
-- keeps its immutable original proof through BEFORE and AFTER Storage guards.
select pg_temp.lease_actor(4);set local role authenticated;select pg_temp.lease_admit(702);reset role;
select pg_temp.lease_actor(600,951,true);set local role service_role;select pg_temp.lease_claim(702,902);select pg_temp.lease_begin(702,902);reset role;
select pg_temp.lease_actor();set local role authenticated;select pg_temp.lease_admit(702);reset role;
select ok((select current_proof_id<>lease_proof_id from public.admin_media_uploads where operation_id='99967300-0000-4000-8000-000000000702'),
 'renewal does not replace the old worker lease proof');
create function pg_temp.lease_delay() returns trigger language plpgsql as $$begin
 if new.name='club-9996731/admin/shop_product/99967300-0000-4000-8000-000000000702.png' then perform pg_sleep(4.2);end if;return new;end $$;
create trigger zz_media_lease_delay before insert on storage.objects for each row execute function pg_temp.lease_delay();
select pg_temp.lease_actor(600,951,true);set local role service_role;
select throws_ok($$select pg_temp.lease_store(702,902,802)$$,'42501','MEDIA_ASSURANCE_EXPIRED','AFTER wait cannot borrow a newer current proof');reset role;
drop trigger zz_media_lease_delay on storage.objects;
select is((select count(*)::int from storage.objects where id='99967300-0000-4000-8000-000000000802'),0,'old worker expiry rolls back publication');
select throws_ok($$update public.admin_media_uploads set lease_proof_id=current_proof_id where operation_id='99967300-0000-4000-8000-000000000702'$$,
 'P0001','MEDIA_COMMAND_IMMUTABLE','an existing lease cannot be silently renewed');

-- Original dispatch itself also stays bound even before it receives a lease.
select pg_temp.lease_actor(3);set local role authenticated;select pg_temp.lease_admit(703);reset role;
select pg_temp.lease_actor();set local role authenticated;select pg_temp.lease_admit(703);reset role;select pg_sleep(3.2);
select pg_temp.lease_actor(600,951,true);set local role service_role;
select throws_ok($$select pg_temp.lease_claim(703,903,true)$$,'42501','MEDIA_ASSURANCE_EXPIRED','delayed old dispatch cannot consume a renewed review');reset role;
select ok((select lease_token is null and storage_attempt_reserved_at is null from public.admin_media_uploads where operation_id='99967300-0000-4000-8000-000000000703'),
 'expired dispatch gives no lease or cost permission');

-- Failed/lost provider response leaves one original uncertain attempt forever.
select pg_temp.lease_actor();set local role authenticated;select pg_temp.lease_admit(704);reset role;
select pg_temp.lease_actor(600,951,true);set local role service_role;
select pg_temp.lease_claim(704,904);select pg_temp.lease_begin(704,904);
select is(pg_temp.lease_complete(704,904,'unknown')->>'status','unknown','unconfirmed original is durable unknown');reset role;
select pg_temp.lease_actor();set local role authenticated;select pg_temp.lease_admit(704);reset role;
select pg_temp.lease_actor(600,951,true);set local role service_role;
select pg_temp.lease_claim(704,914);
select is((pg_temp.lease_begin(704,914)->>'upload_permitted')::boolean,false,'fresh review may reconcile unknown but cannot buy a new upload');
select throws_ok($$select pg_temp.lease_store(704,914,804)$$,'42501','MEDIA_STORAGE_ATTEMPT_REQUIRED','replacement reconciliation lease cannot dispatch another original upload');reset role;
select is((select count(*)::int from storage.objects where name='club-9996731/admin/shop_product/99967300-0000-4000-8000-000000000704.png'),0,
 'unknown original has no invented object');

-- A stored original survives logout but no old worker can borrow the new login.
select pg_temp.lease_actor();set local role authenticated;select pg_temp.lease_admit(705);reset role;
select pg_temp.lease_actor(600,951,true);set local role service_role;
select pg_temp.lease_claim(705,905);select pg_temp.lease_begin(705,905);select pg_temp.lease_store(705,905,805);reset role;
delete from auth.sessions where id='99967300-0000-4000-8000-000000000951';
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values
 ('99967300-0000-4000-8000-000000000961','99967300-0000-4000-8000-000000000001',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
select pg_temp.lease_actor(600,961);set local role authenticated;select pg_temp.lease_admit(705);reset role;
select pg_temp.lease_actor(600,961,true);set local role service_role;
select is(pg_temp.lease_complete(705,905,'stored',805)->>'status','staged','old logged-out lease cannot complete using new current proof');
select pg_temp.lease_claim(705,915);
select is((pg_temp.lease_begin(705,915)->>'upload_permitted')::boolean,false,'new login reconciles stored original without repeating Storage');
select is(pg_temp.lease_complete(705,915,'stored',805)->>'status','completed','fresh same-command lease confirms actual original stored object');reset role;
select is((select count(*)::int from storage.objects where name='club-9996731/admin/shop_product/99967300-0000-4000-8000-000000000705.png'),1,
 'logout/new-session recovery preserves one original object');
select * from finish();rollback;

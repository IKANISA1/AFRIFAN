begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','service_role',true);
insert into public.african_football_clubs(id,club_name,country_name,country_iso_code,club_slug,is_active) overriding system value values
 (9996801,'Generation A','Rwanda','RW','generation-a',true),(9996802,'Generation B','Rwanda','RW','generation-b',true);
insert into auth.users(id,aud,role,is_anonymous) select ('99968000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'authenticated','authenticated',false from generate_series(1,4)n;
insert into public.users(id,phone,full_name) select ('99968000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'+25079996800'||n,'Synthetic generation actor '||n from generate_series(1,4)n;
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after)
 select ('99968000-0000-4000-8000-'||lpad((n+950)::text,12,'0'))::uuid,('99968000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour' from generate_series(1,4)n;
insert into public.admin_role_assignments(user_id,role,club_id) values
 ('99968000-0000-4000-8000-000000000001','club_admin',9996801),('99968000-0000-4000-8000-000000000002','admin',null),
 ('99968000-0000-4000-8000-000000000003','club_admin',9996802);
insert into public.news_articles(id,club_id,title) values ('99968000-0000-4000-8000-000000000501',9996801,'Generation target'),
 ('99968000-0000-4000-8000-000000000502',9996802,'Foreign generation target');
create temp table generation_test_receipts(n int primary key,admission jsonb,first_proof uuid,claim jsonb,media_admission jsonb);
grant select,insert,update on generation_test_receipts to authenticated;
grant select,update on generation_test_receipts to service_role;
create function pg_temp.gen_actor(n int,ttl int default 3600,age int default 1,service boolean default false) returns void language plpgsql as $$
declare u text:='99968000-0000-4000-8000-'||lpad(n::text,12,'0'); e bigint:=floor(extract(epoch from clock_timestamp())); begin
 perform set_config('request.jwt.claim.sub',case when service then '' else u end,true);
 perform set_config('request.jwt.claim.role',case when service then 'service_role' else 'authenticated' end,true);
 perform set_config('request.jwt.claims',case when service then '{"role":"service_role"}' else jsonb_build_object('sub',u,'role','authenticated','club_id',9996801,
 'aal','aal2','is_anonymous',false,'exp',e+ttl,'session_id','99968000-0000-4000-8000-'||lpad((n+950)::text,12,'0'),
 'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',e-age)))::text end,true);
end $$;
create function pg_temp.gen_admit(n int,d text default 'admin_image',r jsonb default null) returns jsonb language plpgsql as $$ declare a jsonb; begin
 a:=public.admit_admin_image_generation(('99968000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,9996801,d,
 coalesce(r,'{"kind":"home_banner","prompt":"Synthetic","subject":null,"aspectRatio":"16:9"}'));
 insert into pg_temp.generation_test_receipts(n,admission,first_proof) values(n,a,(a->>'dispatch_proof_id')::uuid)
 on conflict on constraint generation_test_receipts_pkey do update set admission=excluded.admission;
 return a;
end $$;
create function pg_temp.gen_claim(n int,token int,original boolean default false) returns jsonb language plpgsql as $$ declare a jsonb;p uuid;begin
 select case when original then first_proof else (admission->>'dispatch_proof_id')::uuid end into p from pg_temp.generation_test_receipts where generation_test_receipts.n=gen_claim.n;
 a:=public.claim_admin_image_generation(('99968000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('99968000-0000-4000-8000-'||lpad(token::text,12,'0'))::uuid,p,'{"model":"gemini-2.5-flash-image","public_origin":"https://qa.invalid","prompt_used":"Synthetic frozen prompt","aspect_ratio":"16:9"}');
 -- A truthful busy response has no private publication capability. Preserve
 -- the original successful claim locally instead of replacing it with NULLs.
 if a ? 'public_upload_id' then
  update pg_temp.generation_test_receipts set claim=a where generation_test_receipts.n=gen_claim.n;
 end if;return a;
end $$;
create function pg_temp.gen_record(n int,token int,outcome text,obj int default null) returns jsonb language sql as $$
 select public.record_admin_image_generation_result(('99968000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 ('99968000-0000-4000-8000-'||lpad(token::text,12,'0'))::uuid,outcome,
 case when obj is not null then ('99968000-0000-4000-8000-'||lpad(obj::text,12,'0'))::uuid end,repeat('a',64),'image/png',9);
$$;
create function pg_temp.gen_store(n int,token int,obj int) returns void language plpgsql security definer set search_path='' as $$ declare g public.admin_image_generations;begin
 select * into strict g from public.admin_image_generations where operation_id=('99968000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
 insert into storage.objects(id,bucket_id,name,version,metadata,user_metadata) values(('99968000-0000-4000-8000-'||lpad(obj::text,12,'0'))::uuid,
 'africlub-generated-image-staging',g.staging_path,gen_random_uuid()::text,jsonb_build_object('mimetype',g.mime_type,'size',g.byte_length),
 jsonb_build_object('operation_id',g.operation_id,'lease_token','99968000-0000-4000-8000-'||lpad(token::text,12,'0'),'content_sha256',g.content_sha256));
end $$;
create function pg_temp.gen_media_admit(n int) returns jsonb language plpgsql as $$declare r jsonb;begin
 select public.admit_admin_media_upload((claim->>'public_upload_id')::uuid,9996801,claim->>'kind','image/png',9,repeat('a',64)) into r from pg_temp.generation_test_receipts where generation_test_receipts.n=gen_media_admit.n;
 update pg_temp.generation_test_receipts set media_admission=r where generation_test_receipts.n=gen_media_admit.n;
 return r;end $$;
create function pg_temp.gen_media_store(n int,token int,obj int) returns jsonb language plpgsql security definer set search_path='' as $$ declare g public.admin_image_generations;u public.admin_media_uploads;r jsonb;proof uuid;begin
 select * into strict g from public.admin_image_generations where operation_id=('99968000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid;
 select (media_admission->>'dispatch_proof_id')::uuid into proof from pg_temp.generation_test_receipts where generation_test_receipts.n=gen_media_store.n;
 r:=public.claim_admin_media_upload(g.public_upload_id,('99968000-0000-4000-8000-'||lpad(token::text,12,'0'))::uuid,proof);
 perform public.begin_admin_media_upload(g.public_upload_id,('99968000-0000-4000-8000-'||lpad(token::text,12,'0'))::uuid);
 select * into strict u from public.admin_media_uploads where operation_id=g.public_upload_id;
 insert into storage.objects(id,bucket_id,name,version,metadata,user_metadata) values(('99968000-0000-4000-8000-'||lpad(obj::text,12,'0'))::uuid,u.bucket,u.storage_path,gen_random_uuid()::text,
 jsonb_build_object('mimetype',u.mime_type,'size',u.byte_length),jsonb_build_object('operation_id',u.operation_id,'lease_token','99968000-0000-4000-8000-'||lpad(token::text,12,'0'),'content_sha256',u.content_sha256,
 'generation_operation_id',g.operation_id,'generation_lease_token',g.lease_token,'generation_proof_id',g.lease_proof_id));
 return public.complete_admin_media_upload(g.public_upload_id,('99968000-0000-4000-8000-'||lpad(token::text,12,'0'))::uuid,'stored',('99968000-0000-4000-8000-'||lpad(obj::text,12,'0'))::uuid,repeat('a',64));
end $$;
create function pg_temp.gen_global() returns jsonb language sql security definer set search_path='' as $$select public.capture_verified_staff_provider_proof(9996801,true)$$;
revoke all on function pg_temp.gen_actor(int,int,int,boolean),pg_temp.gen_admit(int,text,jsonb),pg_temp.gen_claim(int,int,boolean),pg_temp.gen_record(int,int,text,int),pg_temp.gen_store(int,int,int),pg_temp.gen_media_admit(int),pg_temp.gen_media_store(int,int,int),pg_temp.gen_global() from public,anon,authenticated,service_role;
grant execute on function pg_temp.gen_admit(int,text,jsonb),pg_temp.gen_media_admit(int),pg_temp.gen_global() to authenticated;
grant execute on function pg_temp.gen_claim(int,int,boolean),pg_temp.gen_record(int,int,text,int),pg_temp.gen_store(int,int,int),pg_temp.gen_media_store(int,int,int) to service_role;
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role'])r cross join unnest(array['public.capture_verified_staff_provider_proof(bigint,boolean)','public.assert_verified_staff_provider_proof(uuid,bigint,boolean,jsonb)','public.lock_admin_image_generation_operation(uuid)'])f where has_function_privilege(r,f,'EXECUTE')),'shared proof and ordering primitives cannot fabricate app/service human proof');
select ok(has_function_privilege('authenticated','public.admit_admin_image_generation(uuid,bigint,text,jsonb)','EXECUTE') and not has_function_privilege('service_role','public.admit_admin_image_generation(uuid,bigint,text,jsonb)','EXECUTE') and not has_function_privilege('authenticated','public.claim_admin_image_generation(uuid,uuid,uuid,jsonb)','EXECUTE'),'actual issuer and worker ACLs stay separate');
select ok(not exists(select 1 from unnest(array['anon','authenticated','service_role'])r cross join unnest(array['admin_image_generations','admin_image_generation_proofs'])t where has_table_privilege(r,'public.'||t,'SELECT,INSERT,UPDATE,DELETE')),'private commands/proofs deny direct app access');
select ok((select not public and file_size_limit=5242880 and allowed_mime_types=array['image/png','image/jpeg','image/webp'] from storage.buckets where id='africlub-generated-image-staging'),'response evidence bucket is private and bounded');
select ok((select count(*)=2 from pg_policy where polrelid in('public.admin_image_generations'::regclass,'public.admin_image_generation_proofs'::regclass) and polname='account_lifecycle_access' and not polpermissive and polcmd='*' and polroles=array['authenticated'::regrole::oid]),'both tables have exact lifecycle denial policy');
select ok(exists(select 1 from public.account_erasure_fk_inventory i join pg_constraint c on c.oid=i.constraint_oid where c.conrelid='public.admin_image_generations'::regclass and c.confrelid='auth.users'::regclass and i.retained and i.deletion_action='r') and not exists(select 1 from pg_constraint where conrelid='public.admin_image_generation_proofs'::regclass and confrelid='auth.sessions'::regclass),'actor inventory retained without preventing real session deletion');
select pg_temp.gen_actor(1,3600,301);set local role authenticated;
select throws_ok($$select pg_temp.gen_admit(701)$$,'42501','STAFF_STEP_UP_REQUIRED','stale human assurance cannot admit');reset role;
select pg_temp.gen_actor(3);set local role authenticated;
select throws_ok($$select pg_temp.gen_admit(701)$$,'42501','PROVIDER_STAFF_AUTHORITY_REQUIRED','foreign tenant cannot repair authority');reset role;
select pg_temp.gen_actor(4);set local role authenticated;
select throws_ok($$select pg_temp.gen_admit(701)$$,'42501','PROVIDER_STAFF_AUTHORITY_REQUIRED','supporter AAL2 is not staff');reset role;
select pg_temp.gen_actor(1);set local role authenticated;
select throws_ok($$select pg_temp.gen_global()$$,'42501','PROVIDER_STAFF_AUTHORITY_REQUIRED','club assignment cannot establish GLOBAL proof');
select is(pg_temp.gen_admit(701)->>'status','pending','actual caller persists original pending before provider');
select is(pg_temp.gen_admit(701)->>'operation_id','99968000-0000-4000-8000-000000000701','same command survives lost first response');
select throws_ok($$select pg_temp.gen_admit(701,'admin_image','{"kind":"home_banner","prompt":"Changed","subject":null,"aspectRatio":"16:9"}')$$,'22023','GENERATION_COMMAND_BINDING_MISMATCH','same original cannot change approved args');
select throws_ok($$select pg_temp.gen_admit(709,'product_image','{"productType":"news","productName":null,"targetTable":"news_articles","targetId":"99968000-0000-4000-8000-000000000502"}')$$,'22023','GENERATION_TARGET_UNAVAILABLE','foreign target denied before charge');reset role;
select is((select count(*)::int from public.admin_image_generation_proofs where operation_id='99968000-0000-4000-8000-000000000701'),1,'duplicate admission cannot inflate proof history');
select pg_temp.gen_actor(2);set local role authenticated;
select ok(pg_temp.gen_global() ? 'session_id','actual GLOBAL actor captures real vendor session');
select is(public.get_admin_image_generation_status('99968000-0000-4000-8000-000000000701',9996801),null::jsonb,'global actor cannot recover foreign owner command');reset role;
select pg_temp.gen_actor(1,3600,1,true);set local role service_role;
select throws_ok($$select public.claim_admin_image_generation('99968000-0000-4000-8000-000000000799','99968000-0000-4000-8000-000000000899',gen_random_uuid(),'{}')$$,'42501','GENERATION_ADMISSION_REQUIRED','service cannot manufacture original command');
select is((pg_temp.gen_claim(701,871)->>'claimed')::boolean,true,'service records one attempt under exact admission proof');
select is((pg_temp.gen_claim(701,872)->>'claimed')::boolean,false,'overlapping request cannot repeat provider attempt');
reset role;
select is((select claim->>'public_upload_id' from pg_temp.generation_test_receipts where n=701),
 (select public_upload_id::text from public.admin_image_generations where operation_id='99968000-0000-4000-8000-000000000701'),
 'busy acknowledgement preserves the successful original publication capability in fixture recovery');
set local role service_role;
select lives_ok($$select pg_temp.gen_record(701,871,'prepared')$$,'original provider result binds immutable size/hash before Storage');
select throws_ok($$select pg_temp.gen_store(701,872,801)$$,'P0001','GENERATION_OBJECT_MISMATCH','foreign lease cannot stage evidence');
select lives_ok($$select pg_temp.gen_store(701,871,801)$$,'actual vendor row records private original response');
select is(pg_temp.gen_record(701,871,'stored',801)->>'status','staged','verified private evidence alone is not publication');reset role;
select is((select owner_id from storage.objects where id='99968000-0000-4000-8000-000000000801'),'99968000-0000-4000-8000-000000000001','private bytes remain discoverable by real account erasure worker');
select throws_ok($$update storage.objects set name='escaped.png' where id='99968000-0000-4000-8000-000000000801'$$,'P0001','GENERATION_OBJECT_IMMUTABLE','stage rename cannot escape command guard');
select pg_temp.gen_actor(1);set local role authenticated;
select is(pg_temp.gen_media_admit(701)->>'status','pending','publication uses genuine fresh caller JWT through unchanged27');reset role;
select pg_temp.gen_actor(1,3600,1,true);set local role service_role;
select is(pg_temp.gen_media_store(701,881,901)->>'status','completed','actual27 Storage proof remains authoritative');reset role;
select pg_temp.gen_actor(1);set local role authenticated;
select is(public.commit_admin_image_generation('99968000-0000-4000-8000-000000000701',9996801)->>'status','completed','fresh caller commits generated receipt');
select is(public.commit_admin_image_generation('99968000-0000-4000-8000-000000000701',9996801)->>'operation_id','99968000-0000-4000-8000-000000000701','lost completion ack recovers same immutable original');reset role;
select is((select count(*)::int from public.admin_image_generations where operation_id='99968000-0000-4000-8000-000000000701' and provider_started_at is not null),1,'one durable provider start survives replay');

select pg_temp.gen_actor(1,3);set local role authenticated;select pg_temp.gen_admit(702);reset role;
select pg_temp.gen_actor(1,3600,1,true);set local role service_role;select pg_temp.gen_claim(702,872);select pg_sleep(3.2);
select lives_ok($$select pg_temp.gen_record(702,872,'prepared')$$,'expired clock can retain response from already-admitted cost');
select lives_ok($$select pg_temp.gen_store(702,872,802)$$,'response stays private after original JWT expiry');
select is(pg_temp.gen_record(702,872,'stored',802)->>'status','staged','provider outcome never fakes expired human publication');reset role;
select pg_temp.gen_actor(1,0);set local role authenticated;
select throws_ok($$select pg_temp.gen_media_admit(702)$$,'42501','STAFF_STEP_UP_REQUIRED','expired original cannot publish private evidence');reset role;
select pg_temp.gen_actor(1);set local role authenticated;select pg_temp.gen_admit(702);reset role;
select pg_temp.gen_actor(1,3600,1,true);set local role service_role;
select is((pg_temp.gen_claim(702,882)->>'claimed')::boolean,false,'fresh reconciliation never repeats Gemini');
select is((select claim->>'reconcile' from pg_temp.generation_test_receipts where n=702),'true','fresh same-command proof can reconcile private response');reset role;
select is((select count(*)::int from public.admin_image_generation_proofs where operation_id='99968000-0000-4000-8000-000000000702'),2,'fresh original proof is appended');

select pg_temp.gen_actor(1,3);set local role authenticated;select pg_temp.gen_admit(703);reset role;
select pg_temp.gen_actor(1);set local role authenticated;select pg_temp.gen_admit(703);reset role;
select pg_sleep(3.2);select pg_temp.gen_actor(1,3600,1,true);set local role service_role;
select throws_ok($$select pg_temp.gen_claim(703,873,true)$$,'42501','PROVIDER_ASSURANCE_EXPIRED','old delayed worker cannot borrow newer current proof');reset role;
select is((select provider_started_at from public.admin_image_generations where operation_id='99968000-0000-4000-8000-000000000703'),null::timestamptz,'old proof denial precedes any provider start');
select pg_temp.gen_actor(1);set local role authenticated;select pg_temp.gen_admit(704);reset role;
select pg_temp.gen_actor(1,3600,1,true);set local role service_role;select pg_temp.gen_claim(704,874);reset role;
delete from auth.sessions where id='99968000-0000-4000-8000-000000000951';
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('99968000-0000-4000-8000-000000000961','99968000-0000-4000-8000-000000000001',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
select pg_temp.gen_actor(1);select set_config('request.jwt.claims',jsonb_set(auth.jwt(),'{session_id}','"99968000-0000-4000-8000-000000000961"')::text,true);set local role authenticated;select pg_temp.gen_admit(704);reset role;
select pg_temp.gen_actor(1,3600,1,true);set local role service_role;
select throws_ok($$select pg_temp.gen_record(704,874,'prepared')$$,'42501','PROVIDER_SESSION_REVOKED','old started worker cannot borrow a new login session');reset role;
select is((select content_sha256 from public.admin_image_generations where operation_id='99968000-0000-4000-8000-000000000704'),null::text,'logout blocks response write despite newer current proof');
insert into auth.sessions(id,user_id,created_at,updated_at,aal,not_after) values('99968000-0000-4000-8000-000000000951','99968000-0000-4000-8000-000000000001',clock_timestamp(),clock_timestamp(),'aal2',clock_timestamp()+interval '1 hour');
select pg_temp.gen_actor(1);set local role authenticated;select pg_temp.gen_admit(705);reset role;
select pg_temp.gen_actor(1,3600,1,true);set local role service_role;select pg_temp.gen_claim(705,875);
select is(pg_temp.gen_record(705,875,'unknown')->>'status','unknown','unknown provider response is durable');reset role;
select pg_temp.gen_actor(1);set local role authenticated;select pg_temp.gen_admit(705);reset role;
select pg_temp.gen_actor(1,3600,1,true);set local role service_role;
select is((pg_temp.gen_claim(705,885)->>'claimed')::boolean,false,'unknown original never attempts provider again');reset role;
-- Original dispatch proof also binds public Storage, even when SQL27 itself
-- receives a new current proof. This exercises actual vendor permission/commit.
select pg_temp.gen_actor(2,3);set local role authenticated;select pg_temp.gen_admit(708);reset role;
select pg_temp.gen_actor(2,3600,1,true);set local role service_role;select pg_temp.gen_claim(708,878);
select pg_temp.gen_record(708,878,'prepared');select pg_temp.gen_store(708,878,808);select pg_temp.gen_record(708,878,'stored',808);reset role;
select pg_sleep(3.2);select pg_temp.gen_actor(2);set local role authenticated;select pg_temp.gen_admit(708);select pg_temp.gen_media_admit(708);reset role;
select pg_temp.gen_actor(2,3600,1,true);set local role service_role;
select throws_ok($$select pg_temp.gen_media_store(708,888,908)$$,'42501','PROVIDER_ASSURANCE_EXPIRED','old publisher cannot borrow renewed27 current proof');reset role;
select is((select count(*)::int from storage.objects where id='99968000-0000-4000-8000-000000000908'),0,'old publisher denial rolls back public object');
select pg_temp.gen_actor(2,3600,1,true);set local role service_role;select pg_temp.gen_claim(708,898);
select is(pg_temp.gen_media_store(708,889,909)->>'status','completed','fresh leased original can publish same verified private result');reset role;
select pg_temp.gen_actor(2);set local role authenticated;
select is(public.commit_admin_image_generation('99968000-0000-4000-8000-000000000708',9996801)->>'status','completed','fresh generation commitment keeps original receipt');reset role;

-- A provider-start write that waits beyond original expiry rolls back before
-- HTTP, including its accepted rate timestamp.
select pg_temp.gen_actor(2,3);set local role authenticated;select pg_temp.gen_admit(707);reset role;
create function pg_temp.gen_delay() returns trigger language plpgsql as $$begin if new.operation_id='99968000-0000-4000-8000-000000000707' and new.provider_started_at is not null then perform pg_sleep(3.2);end if;return new;end$$;
create trigger zz_gen_delay after update on public.admin_image_generations for each row execute function pg_temp.gen_delay();
select pg_temp.gen_actor(2,3600,1,true);set local role service_role;
select throws_ok($$select pg_temp.gen_claim(707,877)$$,'42501','PROVIDER_ASSURANCE_EXPIRED','post-write clock recheck denies waited provider start');reset role;
drop trigger zz_gen_delay on public.admin_image_generations;
select is((select provider_started_at from public.admin_image_generations where operation_id='99968000-0000-4000-8000-000000000707'),null::timestamptz,'late denial leaves no cost permission');

-- Actual product target capability uses caller JWT and immutable target version.
select pg_temp.gen_actor(2);set local role authenticated;
select pg_temp.gen_admit(710,'product_image','{"productType":"news","productName":null,"targetTable":"news_articles","targetId":"99968000-0000-4000-8000-000000000501"}');reset role;
select pg_temp.gen_actor(2,3600,1,true);set local role service_role;select pg_temp.gen_claim(710,870);
select pg_temp.gen_record(710,870,'prepared');select pg_temp.gen_store(710,870,810);select pg_temp.gen_record(710,870,'stored',810);reset role;
select pg_temp.gen_actor(2);set local role authenticated;select pg_temp.gen_media_admit(710);reset role;
select pg_temp.gen_actor(2,3600,1,true);set local role service_role;select pg_temp.gen_media_store(710,890,910);reset role;
select pg_temp.gen_actor(2);set local role authenticated;
select is(public.commit_admin_image_generation('99968000-0000-4000-8000-000000000710',9996801)->>'status','completed','actual fresh product target commit completes');reset role;
select is((select image_prompt from public.news_articles where id='99968000-0000-4000-8000-000000000501'),'Synthetic frozen prompt','original generated prompt stored with target');
select pg_temp.gen_actor(2);set local role authenticated;
select pg_temp.gen_admit(711,'product_image','{"productType":"news","productName":null,"targetTable":"news_articles","targetId":"99968000-0000-4000-8000-000000000501"}');
update public.news_articles set image_url='https://qa.invalid/intervening.png' where id='99968000-0000-4000-8000-000000000501';reset role;
select pg_temp.gen_actor(2,3600,1,true);set local role service_role;select pg_temp.gen_claim(711,871);
select pg_temp.gen_record(711,871,'prepared');select pg_temp.gen_store(711,871,811);select pg_temp.gen_record(711,871,'stored',811);reset role;
select pg_temp.gen_actor(2);set local role authenticated;select pg_temp.gen_media_admit(711);reset role;
select pg_temp.gen_actor(2,3600,1,true);set local role service_role;select pg_temp.gen_media_store(711,891,911);reset role;
select pg_temp.gen_actor(2);set local role authenticated;
select is(public.commit_admin_image_generation('99968000-0000-4000-8000-000000000711',9996801)->>'status','staged','intervening target update retains staged command');reset role;
select is((select image_url from public.news_articles where id='99968000-0000-4000-8000-000000000501'),'https://qa.invalid/intervening.png','generation does not overwrite intervening content');
select is((select target_conflict from public.admin_image_generations where operation_id='99968000-0000-4000-8000-000000000711'),true,'target conflict is durably acknowledged');

select pg_temp.gen_actor(1);set local role authenticated;select pg_temp.gen_admit(706);reset role;
select pg_temp.gen_actor(1,3600,1,true);
update public.admin_role_assignments set is_active=false,revoked_at=clock_timestamp() where user_id='99968000-0000-4000-8000-000000000001';set local role service_role;
select throws_ok($$select pg_temp.gen_claim(706,876)$$,'42501','PROVIDER_STAFF_AUTHORITY_REQUIRED','current revocation denies provider effect');reset role;
update public.admin_role_assignments set is_active=true,revoked_at=null where user_id='99968000-0000-4000-8000-000000000001';
select public.request_account_erasure('99968000-0000-4000-8000-000000000001','99968000-0000-4000-8000-000000000999');set local role service_role;
select throws_ok($$select pg_temp.gen_claim(706,876)$$,'42501','ACCOUNT_CLOSURE_PENDING','closure denies new costs while retaining accountable history');reset role;
select ok((select count(*)>0 from public.admin_image_generations where actor_id='99968000-0000-4000-8000-000000000001'),'closure keeps original command reference');
select * from finish();
rollback;

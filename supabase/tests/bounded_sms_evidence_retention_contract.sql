begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
select ok(not has_function_privilege('authenticated','public.redact_momo_sms_artifacts_due(interval,interval,integer)','execute'),'supporter cannot drive retention');
select is((select approval_status from public.sms_evidence_retention_policy),'technical_proposal','technical default is not legal approval');
insert into public.african_football_clubs(id,club_name,country_name,club_slug) overriding system value values(9996401,'Retention QA','Rwanda','retention-qa');
insert into auth.users(id,aud,role) values('99964000-0000-4000-8000-000000000001','authenticated','authenticated');
insert into public.users(id,phone,full_name) values('99964000-0000-4000-8000-000000000001','+250799964001','Retention QA');
insert into public.profiles(id,club_id) values('99964000-0000-4000-8000-000000000001',9996401);
insert into public.admin_role_assignments(user_id,role) values('99964000-0000-4000-8000-000000000001','admin');
insert into public.momo_sms_raw(id,user_id,device_message_key,sender,sms_body,sms_received_at,club_id,parse_status,created_at,otp_whatsapp_number)
select ('99964000-0000-4000-8000-'||lpad((100+n)::text,12,'0'))::uuid,'99964000-0000-4000-8000-000000000001',
 'retention-identity-'||n,'M-Money','Person QA +250799900000 private balance',now()-interval '20 days',9996401,
 (array['pending','processing','parsed','failed','ignored','parsed','parsed'])[n],now()-case when n=7 then interval '1 day' else interval '20 days' end,'+250799900000' from generate_series(1,7)n;
insert into public.momo_parse_attempts(raw_sms_id,user_id,provider,model,request_payload,response_payload,status)
select id,user_id,'qa','qa','{"sms":"Person QA"}','{"phone":"+250799900000"}','pending' from public.momo_sms_raw where club_id=9996401;
insert into public.momo_sms_parsed(id,raw_sms_id,user_id,parser_provider,parser_model,momo_tx_id,amount,club_id,payer_name,payer_number_full,balance_after,structured_data)
select ('99964000-0000-4000-8000-'||lpad((200+n)::text,12,'0'))::uuid,
 ('99964000-0000-4000-8000-'||lpad((100+n)::text,12,'0'))::uuid,'99964000-0000-4000-8000-000000000001','qa','qa','RETENTION-TX-'||n,1234,9996401,'Person QA','+250799900000',9876,'{"phone":"+250799900000"}' from generate_series(1,7)n;
insert into public.momo_reconciliations(parsed_sms_id,user_id,match_status,club_id,notes,metadata)
select id,user_id,'manual_review',9996401,'Person QA','{"payer_name":"Person QA","amount":1234,"reference":"RETAIN"}' from public.momo_sms_parsed where club_id=9996401;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select lives_ok($$select public.hold_sms_evidence('99964000-0000-4000-8000-000000000106','99964000-0000-4000-8000-000000000001',now()+interval '1 day','active investigation QA')$$,'bounded attributable hold accepted');
select throws_ok($$select public.redact_momo_sms_artifacts_due('15 days','14 days',500)$$,'P0001','RETENTION_EXTENSION_REQUIRES_POLICY','caller cannot silently extend retention');
select throws_ok($$select public.redact_momo_sms_artifacts_due('14 days','14 days',5000)$$,'P0001','INVALID_BATCH_SIZE','catch-up work is bounded');
select is((public.redact_momo_sms_artifacts_due('14 days','14 days',2)->>'raw_redacted')::integer,2,'first catch-up batch respects budget');
select ok((select has_more from public.sms_evidence_retention_runs order by executed_at desc limit 1),'catch-up backlog is observable');
select public.redact_momo_sms_artifacts_due('14 days','14 days',500);
reset role;
select is((select count(*)::integer from public.momo_sms_raw where club_id=9996401 and sms_body_redacted_at is not null),5,'all five processing statuses are redacted even unmatched');
select is((select count(*)::integer from public.momo_parse_attempts where user_id='99964000-0000-4000-8000-000000000001' and request_payload='{}' and response_payload='{}'),5,'all AI attempt statuses cleared');
select is((select count(*)::integer from public.momo_sms_parsed where club_id=9996401 and payer_name is null and payer_number_full is null and balance_after is null and structured_data='{}'),5,'structured direct and JSON PII cleared');
select is((select count(*)::integer from public.momo_sms_parsed where club_id=9996401 and amount=1234 and momo_tx_id like 'RETENTION-TX-%'),7,'money and anti-reuse identities preserved');
select ok((select sms_body_redacted_at is null from public.momo_sms_raw where id='99964000-0000-4000-8000-000000000106'),'active hold preserves evidence');
select ok((select sms_body_redacted_at is null from public.momo_sms_raw where id='99964000-0000-4000-8000-000000000107'),'young evidence retained within source window');
update public.sms_evidence_holds set expires_at=now()-interval '1 second';
set local role service_role;
select public.redact_momo_sms_artifacts_due('14 days','14 days',500);
reset role;
select ok((select sms_body_redacted_at is not null from public.momo_sms_raw where id='99964000-0000-4000-8000-000000000106'),'expired held record resumes catch-up');
update public.momo_parse_attempts set request_payload='{"phone":"Restored PII"}',response_payload='{"name":"Restored PII"}' where raw_sms_id='99964000-0000-4000-8000-000000000101';
select is((select request_payload from public.momo_parse_attempts where raw_sms_id='99964000-0000-4000-8000-000000000101'),'{}'::jsonb,'late provider attempt cannot restore PII');
update public.momo_sms_parsed set payer_name='Restored PII',structured_data='{"phone":"Restored PII"}' where id='99964000-0000-4000-8000-000000000201';
select ok((select payer_name is null and structured_data='{}' from public.momo_sms_parsed where id='99964000-0000-4000-8000-000000000201'),'late parse cannot restore PII');
select is((select device_message_key from public.momo_sms_raw where id='99964000-0000-4000-8000-000000000101'),'retention-identity-1','redaction retains duplicate identity');
select * from finish();
rollback;

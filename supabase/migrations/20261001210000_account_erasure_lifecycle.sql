-- Account closure retains durable subject keys. No Auth/users deletion or FK cascade.
-- External processor and backup obligations require evidence; policy acceptance is not implied.
begin;
create table public.account_erasure_jobs (
 id uuid primary key default gen_random_uuid(), user_id uuid not null unique references auth.users(id),
 state text not null default 'deletion_pending' check(state in ('deletion_pending','failed','completed')),
 requested_at timestamptz not null default now(), completed_at timestamptz,
 lease_token uuid, lease_until timestamptz, attempts integer not null default 0,
 last_error_code text, updated_at timestamptz not null default now()
);
create table public.account_erasure_steps (
 job_id uuid not null references public.account_erasure_jobs(id), step text not null
 check(step in ('local_data','storage','auth','processors','backups')),
 state text not null default 'pending' check(state in ('pending','completed','failed')),
 evidence_reference text, completed_at timestamptz, primary key(job_id,step)
);
create table public.account_erasure_field_policy (
 schema_name text not null, table_name text not null, subject_column text not null,
 column_name text not null, replacement text not null check(replacement in ('null','empty','pseudonym','json','shop_receipt_address')),
 policy_status text not null default 'technical_proposal' check(policy_status in ('technical_proposal','approved')),
 primary key(schema_name,table_name,subject_column,column_name)
);
create table public.account_erasure_fk_inventory (
 constraint_oid oid primary key, child_table text not null, subject_table text not null,
 deletion_action text not null, retained boolean not null default true
);
insert into public.account_erasure_fk_inventory
select c.oid,c.conrelid::regclass::text,c.confrelid::regclass::text,c.confdeltype::text,true
from pg_constraint c where c.contype='f' and c.confrelid in ('auth.users'::regclass,'public.users'::regclass,'public.profiles'::regclass);
-- Explicit erasure fields across active and retired schemas; financial facts and references remain.
insert into public.account_erasure_field_policy(schema_name,table_name,subject_column,column_name,replacement)
select n.nspname,c.relname,subject.attname,a.attname,
 case when a.atttypid='jsonb'::regtype then 'json'
 when a.attname in ('phone','full_name','normalized_name','number_last_3','sms_body','sender','body','description') then 'empty'
 else 'null' end
from pg_class c join pg_namespace n on n.oid=c.relnamespace
join pg_attribute subject on subject.attrelid=c.oid and subject.attnum>0 and not subject.attisdropped
 and subject.attname in ('user_id','payer_user_id','owner_user_id') and subject.atttypid='uuid'::regtype
join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
where c.relkind='r' and (n.nspname in ('public','football') or n.nspname like 'retired%')
 and c.relname not like 'account_erasure%'
 and a.attname in ('display_name','supporter_name','payer_name','payer_number_full','payer_number_last3',
 'payee_name','payee_number_or_code','counterparty_name','ai_summary','recurring_pattern_hint','narrative','balance_after',
 'otp_whatsapp_number','sms_body','note','statement_label','request_payload','response_payload','raw_payload','metadata','structured_data',
 'payload','notes','error_message','normalized_name','number_full','number_last_3','delivery_address','phone','normalized_phone','body','description')
 and (a.attname<>'balance_after' or c.relname='momo_sms_parsed')
 and not (c.relname='payment_receiver_accounts' and a.attname='payee_number_or_code');
-- The id-bearing profile tables keep subject IDs and public pseudonyms, while personal fields are erased.
insert into public.account_erasure_field_policy(schema_name,table_name,subject_column,column_name,replacement)
select 'public',c.relname,'id',a.attname,
 case when a.attname in ('phone','full_name','momo_provider') and c.relname='users' then
 case when a.attname='phone' then 'pseudonym' else 'empty' end else 'null' end
from pg_class c join pg_namespace n on n.oid=c.relnamespace
join pg_attribute a on a.attrelid=c.oid and a.attnum>0 and not a.attisdropped
where n.nspname='public' and c.relname in ('users','profiles')
and a.attname in ('phone','full_name','momo_number','momo_provider','avatar_url','official_name','official_phone',
 'date_of_birth','national_id_number','vehicle_type','momo_code','momo_route_type','display_name','favorite_team_slug','country_code');
insert into public.account_erasure_field_policy values('public','users','id','identity_data','json','technical_proposal'),
('public','shop_orders','user_id','payment_receipt','shop_receipt_address','technical_proposal');
insert into public.account_erasure_field_policy(schema_name,table_name,subject_column,column_name,replacement)
select 'public','user_private_contacts','user_id',attname,'null' from pg_attribute
where attrelid='public.user_private_contacts'::regclass and attname in ('momo_number','momo_provider','whatsapp_number','country_code');

create function public.account_erasure_scrub_json(p_value jsonb) returns jsonb
language plpgsql immutable security definer set search_path='' as $$
declare v_result jsonb; v_key text; v_value jsonb;
begin
 if jsonb_typeof(p_value)='object' then
  v_result:='{}';
  for v_key,v_value in select key,value from jsonb_each(p_value) loop
   if lower(v_key) ~ '(name|phone|email|contact|address|birth|national_id|identity_data|sms_body|narrative|summary|notes|error_message|request_payload|response_payload|balance_after)' then continue; end if;
   v_result:=v_result||jsonb_build_object(v_key,public.account_erasure_scrub_json(v_value));
  end loop; return v_result;
 elsif jsonb_typeof(p_value)='array' then
  select coalesce(jsonb_agg(public.account_erasure_scrub_json(value)),'[]') into v_result from jsonb_array_elements(p_value); return v_result;
 end if; return p_value;
end $$;


-- Only the leased worker can remove the address projection. All frozen commercial
-- facts and the original paid-evidence guard remain authoritative.
create or replace function public.guard_shop_checkout_receipt() returns trigger
language plpgsql security definer set search_path='' as $$
declare privacy_erasure boolean;
begin
 privacy_erasure:=auth.role()='service_role' and new.delivery_address is null
   and new.payment_receipt=old.payment_receipt-'delivery_address' and new.status=old.status
   and exists(select 1 from public.account_erasure_jobs j where j.user_id=old.user_id
     and j.state='deletion_pending' and j.lease_until>clock_timestamp()
     and j.id::text=current_setting('account_erasure.job_id',true)
     and j.lease_token::text=current_setting('account_erasure.lease_token',true));
 if old.payment_receipt is not null then
   if new.payment_receipt is distinct from (case when privacy_erasure then old.payment_receipt-'delivery_address' else old.payment_receipt end)
     or new.user_id is distinct from old.user_id or new.club_id is distinct from old.club_id or new.partner_id is distinct from old.partner_id
     or new.items is distinct from old.items or new.total is distinct from old.total
     or new.subtotal is distinct from old.subtotal or new.discount_amount is distinct from old.discount_amount
     or new.discount is distinct from old.discount or new.delivery_fee is distinct from old.delivery_fee
     or new.delivery_address is distinct from (case when privacy_erasure then null else old.delivery_address end)
     or new.momo_reference is distinct from old.momo_reference or new.reservation_expires_at is distinct from old.reservation_expires_at then
     raise exception 'SHOP_RECEIPT_IMMUTABLE'; end if;
   if old.status='pending' and new.status in ('paid','confirmed','packed','shipped','fulfilled','delivered')
     and not exists(select 1 from public.momo_ledger_entries l
       join public.momo_reconciliations m on m.parsed_sms_id=l.parsed_sms_id
       where l.user_id=old.user_id and l.club_id=old.club_id and l.target_table='shop_orders' and l.target_record_id=old.id
         and l.amount=old.total and l.currency=old.payment_receipt->>'currency' and l.ledger_status='posted'
         and l.entry_type='debit' and m.match_status='matched' and m.target_table=l.target_table and m.target_record_id=old.id
         and l.metadata->'commerce_request'->>'p_reference'=old.momo_reference
         and l.metadata->'commerce_request'->>'p_payee'=old.payment_receipt->>'recipient_code'
         and (case lower(btrim(l.metadata->'commerce_request'->>'p_provider')) when 'mtn' then 'mtn_rwanda'
           when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(l.metadata->'commerce_request'->>'p_provider')) end)=old.payment_receipt->>'provider'
         and l.metadata->'commerce_request'->>'p_country'=old.payment_receipt->>'country') then
     raise exception 'SHOP_RECEIPT_EVIDENCE_MISMATCH'; end if;
 end if;
 return new;
end $$;

create function public.account_access_allowed() returns boolean language sql volatile security definer set search_path='' as $$
 select auth.uid() is null or auth.role()='service_role' or not exists(select 1 from public.account_erasure_jobs where user_id=auth.uid());
$$;
create function public.assert_account_active() returns void language plpgsql volatile security definer set search_path='' as $$
begin
 if auth.uid() is not null and auth.role() is distinct from 'service_role' then perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,21000)); end if;
 if not public.account_access_allowed() then raise exception using errcode='42501',message='ACCOUNT_CLOSURE_PENDING'; end if; end $$;
create function public.guard_account_lifecycle_mutation() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_level='ROW' and tg_table_name in ('admin_role_assignments','ticket_verifier_assignments','venue_staff_memberships') and tg_op<>'DELETE'
 and (to_jsonb(new)->>'is_active')::boolean and exists(select 1 from public.account_erasure_jobs where user_id=(to_jsonb(new)->>'user_id')::uuid) then
 raise exception using errcode='42501',message='CLOSED_SUBJECT_AUTHORITY_DENIED'; end if;
 if auth.uid() is not null and auth.role() is distinct from 'service_role' then
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,21000));
  perform public.assert_account_active();
 end if;
 if tg_level='STATEMENT' then return null; end if;
 if tg_op='DELETE' then return old; end if; return new;
end $$;
create policy account_lifecycle_storage_access on storage.objects as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed());
-- Cover row writes, including SECURITY DEFINER writes with a stale bearer.
do $$ declare r record; begin
 for r in select n.nspname,c.relname,c.relrowsecurity from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where c.relkind='r' and (n.nspname in ('public','football') or n.nspname like 'retired%')
 and c.relname not like 'account_erasure%' loop
 execute format('create trigger account_lifecycle_statement_guard before insert or update or delete on %I.%I for each statement execute function public.guard_account_lifecycle_mutation()',r.nspname,r.relname);
 execute format('create trigger account_lifecycle_mutation_guard before insert or update or delete on %I.%I for each row execute function public.guard_account_lifecycle_mutation()',r.nspname,r.relname);
 if r.relrowsecurity then
 execute format('create policy account_lifecycle_access on %I.%I as restrictive for all to authenticated using (public.account_access_allowed()) with check (public.account_access_allowed())',r.nspname,r.relname);
 end if;
 end loop;
end $$;
-- Authenticated SECURITY DEFINER reads bypass table RLS. Add a guard without changing
-- signatures or grants. Row triggers serialize their subsequent writes against closure.
do $$ declare r record; v_source text; v_definition text; begin
 for r in select p.oid,p.prosrc,l.lanname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 join pg_language l on l.oid=p.prolang where n.nspname in ('public','football') and p.prosecdef
 and p.prokind='f' and has_function_privilege('authenticated',p.oid,'EXECUTE')
 and p.prorettype not in ('trigger'::regtype,'event_trigger'::regtype)
 and p.proname not in ('account_access_allowed','assert_account_active','account_erasure_scrub_json') loop
 if r.lanname='plpgsql' then v_source:=regexp_replace(r.prosrc,'(^|\n)([ \t]*)begin\M','\1\2begin perform public.assert_account_active();','i');
 elsif r.lanname='sql' then v_source:='select public.assert_account_active(); '||r.prosrc;
 else raise exception 'Unsupported account guard language for function %',r.oid::regprocedure; end if;
 if v_source=r.prosrc then raise exception 'No guard insertion point for %',r.oid::regprocedure; end if;
 v_definition:=pg_get_functiondef(r.oid);
 -- pg_get_functiondef's dollar quote encloses the exact source.
 v_definition:=replace(v_definition,r.prosrc,v_source); execute v_definition;
 if (select prosrc from pg_proc where oid=r.oid)<>v_source then raise exception 'Account guard verification failed for %',r.oid::regprocedure; end if;
 end loop;
end $$;

create function public.prevent_closed_subject_cascade() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.account_erasure_jobs where user_id=old.id) then raise exception using errcode='42501',message='RETAINED_FINANCIAL_SUBJECT'; end if;
 return old;
end $$;
create trigger retained_auth_subject_guard before delete on auth.users for each row execute function public.prevent_closed_subject_cascade();
create trigger retained_user_subject_guard before delete on public.users for each row execute function public.prevent_closed_subject_cascade();
create trigger retained_profile_subject_guard before delete on public.profiles for each row execute function public.prevent_closed_subject_cascade();

create function public.request_account_erasure(p_user_id uuid,p_request_id uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.account_erasure_jobs; r record;
begin
 if p_request_id is not null and p_request_id::text !~ '^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$' then raise exception 'INVALID_REQUEST_CAPABILITY'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,21000));
 if exists(select 1 from public.account_erasure_jobs where id=p_request_id and user_id<>p_user_id) then raise exception using errcode='42501',message='ACCOUNT_CAPABILITY_CONFLICT'; end if;
 perform 1 from auth.users where id=p_user_id for update;
 if not found then raise exception using errcode='22023',message='ACCOUNT_NOT_FOUND'; end if;
 insert into public.account_erasure_jobs(id,user_id) values(coalesce(p_request_id,gen_random_uuid()),p_user_id) on conflict(user_id) do nothing;
 select * into j from public.account_erasure_jobs where user_id=p_user_id for update;
 insert into public.account_erasure_steps(job_id,step) select j.id,unnest(array['local_data','storage','auth','processors','backups']) on conflict do nothing;
 update public.admin_role_assignments set is_active=false,revoked_at=coalesce(revoked_at,now()) where user_id=p_user_id;
 update public.profiles set is_active=false,is_admin=false,privacy_show_real_name=false,privacy_findable_by_phone=false where id=p_user_id;
 update public.users set is_admin=false where id=p_user_id;
 -- Revoke any currently retained assignment class found in the real catalog;
 -- removed products are never referenced or recreated.
 for r in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where c.relkind='r' and (n.nspname in ('public','football') or n.nspname like 'retired%')
 and exists(select 1 from pg_attribute where attrelid=c.oid and attname='user_id' and atttypid='uuid'::regtype and not attisdropped)
 and exists(select 1 from pg_attribute where attrelid=c.oid and attname='is_active' and atttypid='boolean'::regtype and not attisdropped)
 and exists(select 1 from pg_attribute where attrelid=c.oid and attname='revoked_at' and atttypid='timestamptz'::regtype and not attisdropped) loop
 execute format('update %I.%I set is_active=false,revoked_at=coalesce(revoked_at,now()) where user_id=$1',r.nspname,r.relname) using p_user_id;
 end loop;
 delete from public.user_fcm_tokens where user_id=p_user_id;
 delete from public.admin_phone_access where user_id=p_user_id;
 update public.payment_receiver_accounts set is_active=false where owner_user_id=p_user_id;
 update public.user_notification_settings set push_enabled=false,allow_all=false where user_id=p_user_id;
 update public.user_privacy_settings set analytics_enabled=false,momo_sms_autoread_enabled=false,show_activity_status=false,group_visibility='private' where user_id=p_user_id;
 -- Explicit session revocation closes refresh/session-aware routes before any worker runs.
 delete from auth.sessions where user_id=p_user_id;
 delete from auth.refresh_tokens where user_id=p_user_id::text;
 update auth.users set raw_app_meta_data=coalesce(raw_app_meta_data,'{}')||'{"account_lifecycle":"deletion_pending","is_admin":false,"role":"closed"}'::jsonb,
  banned_until='infinity'::timestamptz,updated_at=now() where id=p_user_id;
 return jsonb_build_object('request_id',j.id,'status',j.state,'access_revoked',true,'requested_at',j.requested_at);
end $$;

create function public.claim_account_erasure_jobs(p_limit integer default 5) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if p_limit not between 1 and 20 then raise exception 'INVALID_BATCH_SIZE'; end if;
 with candidates as (select id from public.account_erasure_jobs where state<>'completed' and (lease_until is null or lease_until<now())
 and exists(select 1 from public.account_erasure_steps s where s.job_id=account_erasure_jobs.id and s.step in ('local_data','storage','auth') and s.state<>'completed')
 order by requested_at for update skip locked limit p_limit), claimed as (
 update public.account_erasure_jobs j set state='deletion_pending',last_error_code=null,lease_token=gen_random_uuid(),lease_until=now()+interval '2 minutes',attempts=attempts+1,updated_at=now()
 from candidates c where j.id=c.id returning j.*)
 select coalesce(jsonb_agg(jsonb_build_object('request_id',id,'user_id',user_id,'lease_token',lease_token,'steps',
 (select jsonb_object_agg(step,state) from public.account_erasure_steps where job_id=claimed.id))),'[]') into result from claimed;
 return result;
end $$;

create function public.erase_account_local_batch(p_job_id uuid,p_lease_token uuid,p_batch_size integer default 250) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.account_erasure_jobs; r record; f record; expression text; assignments text; predicate text; affected integer; total integer:=0; remaining boolean:=false;
 previous_job text:=current_setting('account_erasure.job_id',true); previous_lease text:=current_setting('account_erasure.lease_token',true);
begin
 if p_batch_size not between 1 and 500 then raise exception 'INVALID_BATCH_SIZE'; end if;
 select * into j from public.account_erasure_jobs where id=p_job_id and state='deletion_pending' and lease_token=p_lease_token and lease_until>clock_timestamp() for update;
 if not found then raise exception 'ERASURE_LEASE_LOST'; end if;
 perform set_config('account_erasure.job_id',j.id::text,true);
 perform set_config('account_erasure.lease_token',p_lease_token::text,true);
 for r in select distinct schema_name,table_name,subject_column from public.account_erasure_field_policy order by schema_name,table_name,subject_column loop
 assignments:=''; predicate:='';
 for f in select * from public.account_erasure_field_policy where schema_name=r.schema_name and table_name=r.table_name and subject_column=r.subject_column order by column_name loop
 expression:=case f.replacement when 'json' then case when f.column_name in ('identity_data','request_payload','response_payload','raw_payload','structured_data','payload') then quote_literal('{}')||'::jsonb' else format('public.account_erasure_scrub_json(%I)',f.column_name) end
 when 'shop_receipt_address' then format('%I-''delivery_address''',f.column_name)
 when 'empty' then quote_literal('') when 'pseudonym' then quote_literal('closed:'||j.user_id::text) else 'null' end;
 assignments:=assignments||case when assignments='' then '' else ',' end||format('%I=%s',f.column_name,expression);
 predicate:=predicate||case when predicate='' then '' else ' or ' end||format('%I is distinct from %s',f.column_name,expression);
 end loop;
 execute format('with selected as (select ctid from %I.%I where %I=$1 and (%s) limit $2 for update) update %I.%I t set %s from selected s where t.ctid=s.ctid',
 r.schema_name,r.table_name,r.subject_column,predicate,r.schema_name,r.table_name,assignments)
 using j.user_id,greatest(p_batch_size-total,0); get diagnostics affected=row_count; total:=total+affected;
 if total>=p_batch_size then remaining:=true; exit; end if;
 end loop;
 if not remaining then update public.account_erasure_steps set state='completed',completed_at=now(),evidence_reference='database-field-policy-v1' where job_id=j.id and step='local_data'; end if;
 perform set_config('account_erasure.job_id',coalesce(previous_job,''),true);
 perform set_config('account_erasure.lease_token',coalesce(previous_lease,''),true);
 return jsonb_build_object('processed_records',total,'has_more',remaining);
end $$;

create function public.account_erasure_storage_batch(p_job_id uuid,p_lease_token uuid,p_limit integer default 100) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.account_erasure_jobs; result jsonb;
begin
 if p_limit not between 1 and 100 then raise exception 'INVALID_BATCH_SIZE'; end if;
 select * into j from public.account_erasure_jobs where id=p_job_id and lease_token=p_lease_token and lease_until>now();
 if not found then raise exception 'ERASURE_LEASE_LOST'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('bucket',bucket_id,'name',name)),'[]') into result from
 (select bucket_id,name from storage.objects where owner=j.user_id or owner_id=j.user_id::text order by bucket_id,name limit p_limit) objects;
 return result;
end $$;
create function public.record_account_erasure_step(p_job_id uuid,p_lease_token uuid,p_step text,p_success boolean,p_evidence_reference text default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.account_erasure_jobs;
begin
 select * into j from public.account_erasure_jobs where id=p_job_id and lease_token=p_lease_token and lease_until>now() for update;
 if not found then raise exception 'ERASURE_LEASE_LOST'; end if;
 if p_step not in ('local_data','storage','auth') or (p_step='local_data' and p_success) then raise exception 'INVALID_WORKER_STEP'; end if;
 if p_success and p_step='storage' and exists(select 1 from storage.objects where owner=j.user_id or owner_id=j.user_id::text) then raise exception 'STORAGE_NOT_ERASED'; end if;
 if p_success and p_step='auth' and exists(select 1 from auth.users where id=j.user_id and deleted_at is null) then raise exception 'AUTH_NOT_SOFT_DELETED'; end if;
 update public.account_erasure_steps set state=case when p_success then 'completed' else 'failed' end,
 completed_at=case when p_success then now() end,evidence_reference=case when p_success then left(p_evidence_reference,200) end where job_id=j.id and step=p_step;
 update public.account_erasure_jobs set state=case when p_success then 'deletion_pending' else 'failed' end,
 last_error_code=case when not p_success then 'ERASURE_'||upper(p_step)||'_FAILED' end,updated_at=now() where id=j.id;
 if not exists(select 1 from public.account_erasure_steps where job_id=j.id and state<>'completed') then
 update public.account_erasure_jobs set state='completed',completed_at=now(),last_error_code=null where id=j.id; end if;
 return (select jsonb_build_object('request_id',id,'status',state) from public.account_erasure_jobs where id=j.id);
end $$;
create function public.release_account_erasure_lease(p_job_id uuid,p_lease_token uuid) returns void
language sql security definer set search_path='' as $$
 update public.account_erasure_jobs set lease_until=null,lease_token=null where id=p_job_id and lease_token=p_lease_token;
$$;
-- Operator acknowledgement is attributable, has evidence, and cannot fabricate storage/Auth completion.
create function public.acknowledge_account_erasure_obligation(p_job_id uuid,p_actor_user_id uuid,p_step text,p_evidence_reference text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.account_erasure_jobs;
begin
 if p_step not in ('processors','backups') or length(trim(coalesce(p_evidence_reference,''))) not between 12 and 200 then raise exception 'EVIDENCE_REQUIRED'; end if;
 perform 1 from public.admin_role_assignments where user_id=p_actor_user_id and role in ('admin','super_admin') and is_active and revoked_at is null for share;
 if not found or exists(select 1 from public.account_erasure_jobs where user_id=p_actor_user_id) then raise exception using errcode='42501',message='ACTIVE_GLOBAL_ADMIN_REQUIRED'; end if;
 select * into j from public.account_erasure_jobs where id=p_job_id for update;
 if not found then raise exception 'ACCOUNT_REQUEST_NOT_FOUND'; end if;
 update public.account_erasure_steps set state='completed',completed_at=now(),evidence_reference=p_actor_user_id::text||':'||p_evidence_reference where job_id=j.id and step=p_step;
 if not exists(select 1 from public.account_erasure_steps where job_id=j.id and state<>'completed') then
 update public.account_erasure_jobs set state='completed',completed_at=now(),last_error_code=null where id=j.id;
 end if;
 return (select jsonb_build_object('request_id',id,'status',state) from public.account_erasure_jobs where id=j.id);
end $$;

-- An opaque UUID receipt permits privacy-safe status recovery after sessions are revoked.
-- It discloses neither subject UUID nor processor/evidence identifiers.
create function public.get_account_erasure_status(p_request_id uuid) returns jsonb
language sql security definer set search_path='' as $$
 select jsonb_build_object('request_id',id,'status',state,'access_revoked',true,'requested_at',requested_at,
 'completed_at',completed_at,'steps',(select jsonb_object_agg(step,state) from public.account_erasure_steps where job_id=j.id))
 from public.account_erasure_jobs j where id=p_request_id;
$$;

alter table public.account_erasure_jobs enable row level security;
alter table public.account_erasure_steps enable row level security;
alter table public.account_erasure_field_policy enable row level security;
alter table public.account_erasure_fk_inventory enable row level security;
revoke all on public.account_erasure_jobs,public.account_erasure_steps,public.account_erasure_field_policy,public.account_erasure_fk_inventory from public,anon,authenticated;
grant select,insert,update on public.account_erasure_jobs,public.account_erasure_steps to service_role;
grant select on public.account_erasure_field_policy,public.account_erasure_fk_inventory to service_role;
do $$ declare r record; begin
 for r in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
 and p.proname in ('account_erasure_scrub_json','account_access_allowed','assert_account_active','guard_account_lifecycle_mutation','prevent_closed_subject_cascade','request_account_erasure','claim_account_erasure_jobs','erase_account_local_batch','account_erasure_storage_batch','record_account_erasure_step','release_account_erasure_lease','acknowledge_account_erasure_obligation','get_account_erasure_status') loop
 execute format('revoke all on function %s from public,anon,authenticated',r.signature);
 execute format('grant execute on function %s to service_role',r.signature);
 end loop;
end $$;
grant execute on function public.account_access_allowed(),public.assert_account_active() to authenticated;
select cron.schedule('process-account-erasure-jobs','*/5 * * * *',$job$
 select net.http_post(
 url:='https://mmpbzcdhfvplxplnfucy.supabase.co/functions/v1/delete-account?action=process',
 headers:=jsonb_build_object('Content-Type','application/json','x-cron-secret',
 (select decrypted_secret from vault.decrypted_secrets where name='africlub_cron_job_secret' limit 1)),
 body:='{}'::jsonb,timeout_milliseconds:=50000);
$job$);
commit;

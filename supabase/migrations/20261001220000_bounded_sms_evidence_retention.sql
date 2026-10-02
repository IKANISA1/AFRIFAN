begin;
-- Existing 14-day source retention becomes an explicit technical field policy.
-- Jurisdiction schedules and processor deletion acceptance remain unverified.
create table public.sms_evidence_retention_policy (
 id boolean primary key default true check(id), raw_days integer not null default 14 check(raw_days between 1 and 14),
 ai_days integer not null default 14 check(ai_days between 1 and 14), structured_days integer not null default 14 check(structured_days between 1 and 14),
 approval_status text not null default 'technical_proposal' check(approval_status in ('technical_proposal','approved')),
 evidence_reference text, updated_at timestamptz not null default now()
);
insert into public.sms_evidence_retention_policy(id) values(true);
create table public.sms_evidence_holds (
 raw_sms_id uuid primary key references public.momo_sms_raw(id), expires_at timestamptz not null,
 actor_user_id uuid not null references auth.users(id), evidence_reference text not null,
 created_at timestamptz not null default now(), check(length(evidence_reference) between 12 and 200)
);
-- The accountable hold actor is a retained subject added after the original
-- lifecycle catalog capture. Record the real constraint and deletion action.
insert into public.account_erasure_fk_inventory(constraint_oid,child_table,subject_table,deletion_action,retained)
select c.oid,c.conrelid::regclass::text,c.confrelid::regclass::text,c.confdeltype::text,true
from pg_constraint c
where c.contype='f' and c.conrelid='public.sms_evidence_holds'::regclass
 and c.confrelid='auth.users'::regclass
 and c.conkey=array[(select attnum from pg_attribute where attrelid=c.conrelid and attname='actor_user_id')]::smallint[]
on conflict(constraint_oid) do nothing;
create table public.sms_evidence_retention_runs (
 id uuid primary key default gen_random_uuid(), executed_at timestamptz not null default now(),
 batch_size integer not null, raw_redacted integer not null, attempts_redacted integer not null,
 structured_redacted integer not null, reconciliations_redacted integer not null,
 oldest_remaining_due_at timestamptz, has_more boolean not null
);
alter table public.momo_sms_parsed add column pii_redacted_at timestamptz;
alter table public.momo_reconciliations add column pii_redacted_at timestamptz;
create index momo_sms_raw_retention_due on public.momo_sms_raw(created_at,id) where sms_body_redacted_at is null;
create index momo_parse_attempt_retention_due on public.momo_parse_attempts(created_at,id) where payloads_redacted_at is null;
create index momo_sms_parsed_retention_due on public.momo_sms_parsed(created_at,id) where pii_redacted_at is null;
create index momo_reconciliation_retention_due on public.momo_reconciliations(created_at,id) where pii_redacted_at is null;

create function public.hold_sms_evidence(p_raw_sms_id uuid,p_actor_user_id uuid,p_expires_at timestamptz,p_evidence_reference text) returns void
language plpgsql security definer set search_path='' as $$
declare v_club bigint;
begin
 if p_expires_at<=now() or p_expires_at>now()+interval '90 days' or length(trim(coalesce(p_evidence_reference,''))) not between 12 and 200 then raise exception 'BOUNDED_HOLD_EVIDENCE_REQUIRED'; end if;
 select club_id into v_club from public.momo_sms_raw where id=p_raw_sms_id and sms_body_redacted_at is null for update;
 if not found then raise exception 'UNREDACTED_SMS_REQUIRED'; end if;
 perform 1 from public.admin_role_assignments where user_id=p_actor_user_id and is_active and revoked_at is null
 and (role in ('admin','super_admin') or (role in ('club_admin','club_moderator') and club_id=v_club)) for share;
 if not found or exists(select 1 from public.account_erasure_jobs where user_id=p_actor_user_id) then raise exception using errcode='42501',message='ACTIVE_SCOPED_ADMIN_REQUIRED'; end if;
 insert into public.sms_evidence_holds values(p_raw_sms_id,p_expires_at,p_actor_user_id,p_evidence_reference,now())
 on conflict(raw_sms_id) do update set expires_at=excluded.expires_at,actor_user_id=excluded.actor_user_id,evidence_reference=excluded.evidence_reference,created_at=now();
end $$;

create or replace function public.redact_momo_sms_artifacts_due(p_raw_retention interval default interval '14 days',p_attempt_retention interval default interval '14 days',p_batch_size integer default 500) returns jsonb
language plpgsql security definer set search_path='' set statement_timeout='8s' as $$
declare v_now timestamptz:=clock_timestamp(); v_raw integer; v_attempt integer; v_parsed integer; v_reconciliation integer; v_oldest timestamptz; v_run uuid; v_policy public.sms_evidence_retention_policy;
begin
 if p_batch_size not between 1 and 500 then raise exception 'INVALID_BATCH_SIZE'; end if;
 select * into v_policy from public.sms_evidence_retention_policy where id;
 if p_raw_retention<=interval '0 days' or p_raw_retention>make_interval(days=>v_policy.raw_days)
 or p_attempt_retention<=interval '0 days' or p_attempt_retention>make_interval(days=>v_policy.ai_days) then raise exception 'RETENTION_EXTENSION_REQUIRES_POLICY'; end if;
 with selected as (select r.id from public.momo_sms_raw r where r.sms_body_redacted_at is null and r.created_at<=v_now-p_raw_retention
 and not exists(select 1 from public.sms_evidence_holds h where h.raw_sms_id=r.id and h.expires_at>v_now)
 order by r.created_at,r.id limit p_batch_size for update skip locked)
 update public.momo_sms_raw r set sms_body='[REDACTED BY RETENTION POLICY]',sender=coalesce(r.provider,'provider'),otp_whatsapp_number=null,sms_body_redacted_at=v_now,updated_at=v_now,
 parse_status=case when r.parse_status in ('pending','processing') then 'ignored' else r.parse_status end
 from selected s where r.id=s.id; get diagnostics v_raw=row_count;
 with selected as (select a.id from public.momo_parse_attempts a join public.momo_sms_raw r on r.id=a.raw_sms_id
 where a.payloads_redacted_at is null and r.created_at<=v_now-p_attempt_retention
 and not exists(select 1 from public.sms_evidence_holds h where h.raw_sms_id=r.id and h.expires_at>v_now)
 order by a.created_at,a.id limit p_batch_size for update of a skip locked)
 update public.momo_parse_attempts a set request_payload='{}',response_payload='{}',error_message=null,payloads_redacted_at=v_now from selected s where a.id=s.id;
 get diagnostics v_attempt=row_count;
 with selected as (select p.id from public.momo_sms_parsed p join public.momo_sms_raw r on r.id=p.raw_sms_id
 where p.pii_redacted_at is null and r.created_at<=v_now-make_interval(days=>v_policy.structured_days)
 and not exists(select 1 from public.sms_evidence_holds h where h.raw_sms_id=r.id and h.expires_at>v_now)
 order by p.created_at,p.id limit p_batch_size for update of p skip locked)
 update public.momo_sms_parsed p set payer_name=null,payer_number_last3=null,payer_number_full=null,payee_name=null,payee_number_or_code=null,
 counterparty_name=null,ai_summary=null,recurring_pattern_hint=null,narrative=null,balance_after=null,structured_data='{}',pii_redacted_at=v_now,updated_at=v_now
 from selected s where p.id=s.id; get diagnostics v_parsed=row_count;
 with selected as (select m.id from public.momo_reconciliations m join public.momo_sms_parsed p on p.id=m.parsed_sms_id
 join public.momo_sms_raw r on r.id=p.raw_sms_id where m.pii_redacted_at is null and r.created_at<=v_now-make_interval(days=>v_policy.structured_days)
 and not exists(select 1 from public.sms_evidence_holds h where h.raw_sms_id=r.id and h.expires_at>v_now)
 order by m.created_at,m.id limit p_batch_size for update of m skip locked)
 update public.momo_reconciliations m set notes=null,metadata=public.account_erasure_scrub_json(metadata),pii_redacted_at=v_now,updated_at=v_now
 from selected s where m.id=s.id; get diagnostics v_reconciliation=row_count;
 -- Ledger references, amount, currency, status and consumed evidence IDs are unchanged.
 with selected as (select l.id from public.momo_ledger_entries l join public.momo_sms_parsed p on p.id=l.parsed_sms_id
 where p.pii_redacted_at is not null and (l.counterparty_name is not null or l.description is not null or l.metadata is distinct from public.account_erasure_scrub_json(l.metadata))
 order by l.created_at,l.id limit p_batch_size for update of l skip locked)
 update public.momo_ledger_entries l set counterparty_name=null,description=null,metadata=public.account_erasure_scrub_json(metadata) from selected s where l.id=s.id;
 select min(due_at) into v_oldest from (
 select min(r.created_at) due_at from public.momo_sms_raw r where r.sms_body_redacted_at is null and r.created_at<=v_now-p_raw_retention and not exists(select 1 from public.sms_evidence_holds h where h.raw_sms_id=r.id and h.expires_at>v_now)
 union all select min(a.created_at) from public.momo_parse_attempts a join public.momo_sms_raw r on r.id=a.raw_sms_id where a.payloads_redacted_at is null and r.created_at<=v_now-p_attempt_retention and not exists(select 1 from public.sms_evidence_holds h where h.raw_sms_id=r.id and h.expires_at>v_now)
 union all select min(p.created_at) from public.momo_sms_parsed p join public.momo_sms_raw r on r.id=p.raw_sms_id where p.pii_redacted_at is null and r.created_at<=v_now-make_interval(days=>v_policy.structured_days) and not exists(select 1 from public.sms_evidence_holds h where h.raw_sms_id=r.id and h.expires_at>v_now)
 union all select min(m.created_at) from public.momo_reconciliations m join public.momo_sms_parsed p on p.id=m.parsed_sms_id join public.momo_sms_raw r on r.id=p.raw_sms_id where m.pii_redacted_at is null and r.created_at<=v_now-make_interval(days=>v_policy.structured_days) and not exists(select 1 from public.sms_evidence_holds h where h.raw_sms_id=r.id and h.expires_at>v_now)
 union all select min(l.created_at) from public.momo_ledger_entries l join public.momo_sms_parsed p on p.id=l.parsed_sms_id where p.pii_redacted_at is not null and (l.counterparty_name is not null or l.description is not null or l.metadata is distinct from public.account_erasure_scrub_json(l.metadata))
 ) due;
 insert into public.sms_evidence_retention_runs(batch_size,raw_redacted,attempts_redacted,structured_redacted,reconciliations_redacted,oldest_remaining_due_at,has_more)
 values(p_batch_size,v_raw,v_attempt,v_parsed,v_reconciliation,v_oldest,v_oldest is not null) returning id into v_run;
 with expired as (select id from public.sms_evidence_retention_runs where executed_at<v_now-interval '30 days' order by executed_at limit 500) delete from public.sms_evidence_retention_runs r using expired e where r.id=e.id;
 return jsonb_build_object('run_id',v_run,'raw_redacted',v_raw,'attempt_payloads_redacted',v_attempt,'structured_redacted',v_parsed,
 'reconciliations_redacted',v_reconciliation,'oldest_remaining_due_at',v_oldest,'has_more',v_oldest is not null,'batch_size',p_batch_size,'approval_status',v_policy.approval_status);
end $$;
-- A parser response arriving after redaction cannot restore expired PII.
create function public.guard_expired_sms_evidence() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.momo_sms_raw where id=new.raw_sms_id and sms_body_redacted_at is not null) then
 if tg_table_name='momo_parse_attempts' then new.request_payload:='{}';new.response_payload:='{}';new.error_message:=null;new.payloads_redacted_at:=now();
 else new.payer_name:=null;new.payer_number_full:=null;new.payer_number_last3:=null;new.payee_name:=null;new.payee_number_or_code:=null;
 new.counterparty_name:=null;new.ai_summary:=null;new.narrative:=null;new.recurring_pattern_hint:=null;new.balance_after:=null;new.structured_data:='{}';new.pii_redacted_at:=now(); end if;
 end if; return new;
end $$;
create trigger expired_sms_attempt_guard before insert or update on public.momo_parse_attempts for each row execute function public.guard_expired_sms_evidence();
create trigger expired_sms_parsed_guard before insert or update on public.momo_sms_parsed for each row execute function public.guard_expired_sms_evidence();
alter table public.sms_evidence_retention_policy enable row level security;
alter table public.sms_evidence_holds enable row level security;
alter table public.sms_evidence_retention_runs enable row level security;
revoke all on public.sms_evidence_retention_policy,public.sms_evidence_holds,public.sms_evidence_retention_runs from public,anon,authenticated;
grant select on public.sms_evidence_retention_policy,public.sms_evidence_holds,public.sms_evidence_retention_runs to service_role;
revoke all on function public.hold_sms_evidence(uuid,uuid,timestamptz,text),public.guard_expired_sms_evidence(),public.redact_momo_sms_artifacts_due(interval,interval,integer) from public,anon,authenticated;
grant execute on function public.hold_sms_evidence(uuid,uuid,timestamptz,text),public.redact_momo_sms_artifacts_due(interval,interval,integer) to service_role;
-- Existing daily job becomes bounded catch-up every ten minutes; no network calls.
do $$ declare j bigint; begin
 for j in select jobid from cron.job where jobname='redact-momo-sms-artifacts-daily' loop perform cron.unschedule(j); end loop;
 perform cron.schedule('redact-momo-sms-artifacts-daily','*/10 * * * *',$cron$select public.redact_momo_sms_artifacts_due('14 days','14 days',500);$cron$);
end $$;
commit;

-- Cash refunds require separately reviewed provider capability. No approval is seeded.
-- A signed gateway attests origin; external settlement authenticity remains an approval obligation.
begin;

create table public.payment_refund_gateway_approvals (
 gateway_id uuid primary key references public.trusted_sms_gateways(id) on delete restrict,
 enabled boolean not null default false, policy_version text,
 source_review_reference text, provider_acceptance_reference text, terms_reference text,
 shop_stock_policy text not null default 'retain' check(shop_stock_policy in ('retain','restore_unfulfilled')),
 ticket_policy text not null default 'retain' check(ticket_policy in ('retain','revoke_unused')),
 membership_policy text not null default 'retain' check(membership_policy in ('retain','suspend_current')),
 check(not enabled or coalesce(length(trim(policy_version)) between 1 and 80
  and length(trim(source_review_reference)) between 12 and 200
  and length(trim(provider_acceptance_reference)) between 12 and 200
  and length(trim(terms_reference)) between 12 and 200,false))
);
create table public.payment_refund_requests (
 id uuid primary key default gen_random_uuid(), instruction_id uuid not null unique default gen_random_uuid(),
 payment_event_id uuid not null references public.trusted_sms_gateway_events(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 subject_id uuid not null references auth.users(id) on delete restrict,
 maker_id uuid not null references auth.users(id) on delete restrict,
 checker_id uuid references auth.users(id) on delete restrict,
 payment jsonb not null, amount integer not null check(amount>0), reason text not null
  check(reason in ('duplicate_payment','cancelled_order','unavailable_item','cancelled_event','membership_adjustment','other_reviewed')),
 approval jsonb, revision integer not null default 1 check(revision>0),
 status text not null default 'awaiting_review' check(status in
  ('awaiting_review','approved','rejected','pending','unknown','failed','partially_refunded','refunded')),
 confirmed_amount integer not null default 0 check(confirmed_amount>=0 and confirmed_amount<=amount),
 created_at timestamptz not null default clock_timestamp(), updated_at timestamptz not null default clock_timestamp()
);
create table public.payment_refund_operations (
 operation_id uuid primary key, actor_id uuid not null references auth.users(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 action text not null check(action in ('prepare','review','dispatch')), args jsonb not null,
 result jsonb not null, created_at timestamptz not null default clock_timestamp()
);
create table public.payment_refund_instructions (
 id uuid primary key, refund_id uuid not null unique references public.payment_refund_requests(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 subject_id uuid not null references auth.users(id) on delete restrict,
 maker_id uuid not null references auth.users(id) on delete restrict,
 checker_id uuid not null references auth.users(id) on delete restrict,
 instruction jsonb not null, created_at timestamptz not null default clock_timestamp(),
 check(maker_id<>checker_id)
);
create table public.payment_refund_provider_attempts (
 provider text not null, provider_refund_transaction_id text not null,
 refund_id uuid not null references public.payment_refund_requests(id) on delete restrict,
 instruction_id uuid not null references public.payment_refund_instructions(id) on delete restrict,
 primary key(provider,provider_refund_transaction_id)
);
create table public.payment_refund_evidence (
 id uuid primary key, refund_id uuid not null references public.payment_refund_requests(id) on delete restrict,
 gateway_id uuid not null references public.trusted_sms_gateways(id) on delete restrict,
 key_id uuid not null references public.trusted_sms_gateway_keys(id) on delete restrict,
 body_digest text not null, projection jsonb not null,
 status text not null default 'pending' check(status in ('pending','settled','failed','unknown')),
 result jsonb, admitted_at timestamptz not null default clock_timestamp(), completed_at timestamptz,
 check((result is null)=(completed_at is null))
);
create table public.payment_refund_nonces (
 key_id uuid not null references public.trusted_sms_gateway_keys(id) on delete restrict, nonce uuid not null,
 event_id uuid not null references public.payment_refund_evidence(id) on delete restrict,
 body_digest text not null, expires_at timestamptz not null, primary key(key_id,nonce)
);
create table public.payment_refund_compensations (
 id uuid primary key default gen_random_uuid(), refund_id uuid not null references public.payment_refund_requests(id) on delete restrict,
 evidence_id uuid not null unique references public.payment_refund_evidence(id) on delete restrict,
 original_ledger_id uuid not null references public.momo_ledger_entries(id) on delete restrict,
 payment_event_id uuid not null references public.trusted_sms_gateway_events(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 subject_id uuid not null references auth.users(id) on delete restrict,
 entry_type text not null default 'credit' check(entry_type='credit'), amount integer not null check(amount>0),
 currency text not null, provider text not null, provider_refund_transaction_id text not null,
 settlement_record_id text not null, settlement_record_digest text not null,
 settled_at timestamptz not null, created_at timestamptz not null default clock_timestamp(),
 unique(provider,provider_refund_transaction_id)
);
create table public.payment_refund_consequences (
 payment_event_id uuid primary key references public.trusted_sms_gateway_events(id) on delete restrict,
 evidence_id uuid not null references public.payment_refund_evidence(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 subject_id uuid not null references auth.users(id) on delete restrict,
 policy jsonb not null, result jsonb not null, created_at timestamptz not null default clock_timestamp()
);

-- Transaction timestamps and random order UUIDs cannot identify the current
-- renewal. Record the actual paid activation while its membership is locked.
-- Existing history has no invented ordering and remains conservatively retained.
create table public.payment_refund_membership_activations (
 payment_order_id uuid primary key references public.membership_payment_orders(id) on delete restrict,
 membership_id uuid not null references public.fan_memberships(id) on delete restrict,
 club_id bigint not null references public.african_football_clubs(id) on delete restrict,
 subject_id uuid not null references auth.users(id) on delete restrict,
 intent_id uuid not null unique references public.payment_intents(id) on delete restrict,
 ledger_id uuid not null unique references public.momo_ledger_entries(id) on delete restrict,
 entitlement jsonb not null,
 activation_sequence bigint generated always as identity unique,
 activated_at timestamptz not null default clock_timestamp()
);
create index payment_refund_membership_current on public.payment_refund_membership_activations(membership_id,activation_sequence desc);
revoke all on sequence public.payment_refund_membership_activations_activation_sequence_seq from public,anon,authenticated,service_role;
create function public.payment_refund_record_membership_activation() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_membership public.fan_memberships;v_ledger uuid;
begin
 if old.activated_at is not null or new.activated_at is null then return new; end if;
 select * into v_membership from public.fan_memberships
  where user_id=new.user_id and club_id=new.club_id for update;
 if v_membership.id is null or v_membership.tier is distinct from new.tier
  or v_membership.payment_status is distinct from 'verified' then raise exception 'REFUND_MEMBERSHIP_ACTIVATION_BINDING_MISMATCH'; end if;
 select l.id into v_ledger from public.payment_intents i
  join public.momo_ledger_entries l on l.metadata->>'intent_id'=i.id::text
  join public.momo_reconciliations rec on rec.parsed_sms_id=l.parsed_sms_id and rec.metadata->>'intent_id'=i.id::text
  join public.momo_sms_parsed p on p.id=l.parsed_sms_id
  join public.momo_sms_raw raw on raw.id=p.raw_sms_id
  join public.payment_receiver_accounts receiver on receiver.id=new.receiving_account_id
 where i.id=new.payment_intent_id and i.status='fulfilled'
  and i.target_table='membership_payment_orders' and i.target_record_id=new.id
  and i.user_id=new.user_id and i.expected_amount=new.amount and i.currency=new.currency
  and i.receiving_account_id=new.receiving_account_id
  and l.target_table='membership_payment_orders' and l.target_record_id=new.id
  and rec.target_table=l.target_table and rec.target_record_id=l.target_record_id
  and l.user_id=new.user_id and rec.user_id=l.user_id and p.user_id=l.user_id and raw.user_id=l.user_id
  and l.club_id=new.club_id and rec.club_id=l.club_id and p.club_id=l.club_id and raw.club_id=l.club_id
  and l.ledger_status='posted' and l.entry_type='debit' and rec.match_status='matched'
  and l.amount=new.amount and p.amount=l.amount and l.currency=new.currency and p.currency=l.currency
  and p.tx_direction='debit' and p.momo_tx_id=l.external_reference
  and receiver.is_active and receiver.partner_id=new.partner_id
  and p.payee_number_or_code=receiver.payee_number_or_code and p.payee_number_or_code=new.payment_recipient
  and p.parse_status in ('parsed','needs_review') and not p.is_mock and not raw.is_mock
  and upper(p.country_code)=new.payment_country and upper(raw.country_code)=new.payment_country
  and (case lower(btrim(raw.provider)) when 'mtn' then 'mtn_rwanda'
   when 'mtn rwanda' then 'mtn_rwanda' else nullif(lower(btrim(raw.provider)),'') end)=new.payment_provider;
 if v_ledger is null then raise exception 'REFUND_MEMBERSHIP_ACTIVATION_BINDING_MISMATCH'; end if;
 insert into public.payment_refund_membership_activations(payment_order_id,membership_id,club_id,subject_id,intent_id,ledger_id,entitlement)
 values(new.id,v_membership.id,new.club_id,new.user_id,new.payment_intent_id,v_ledger,
  jsonb_build_object('tier',v_membership.tier,'partner_id',v_membership.partner_id,'expires_at',v_membership.expires_at,
   'renewed_at',v_membership.renewed_at,'payment_status',v_membership.payment_status));
 return new;
end; $$;
create trigger refund_paid_membership_activation after update of activated_at on public.membership_payment_orders
 for each row when(old.activated_at is null and new.activated_at is not null)
 execute function public.payment_refund_record_membership_activation();

-- Internal current-actor check uses the SAME account closure serialization lock.
-- The retained payment subject need not be an active account to receive a refund.
create function public.payment_refund_assert_actor(p_actor uuid,p_club bigint) returns void
language plpgsql security definer set search_path='' as $$
begin
 if p_actor is null or p_club is null then raise exception 'REFUND_GLOBAL_ADMIN_REQUIRED' using errcode='42501'; end if;
 -- Human refund commands take this bounded transaction lock before any actor
 -- account locks, preventing maker/checker lock inversion across requests.
 perform pg_advisory_xact_lock(hashtextextended('refund-human-authority',21025));
 perform pg_advisory_xact_lock(hashtextextended(p_actor::text,21000));
 if exists(select 1 from public.account_erasure_jobs where user_id=p_actor)
  or not exists(select 1 from auth.users where id=p_actor and not is_anonymous
    and (phone_confirmed_at is not null or email_confirmed_at is not null)) then
  raise exception 'ACCOUNT_CLOSED' using errcode='42501'; end if;
 perform 1 from public.admin_role_assignments where user_id=p_actor and is_active and revoked_at is null
  and role in ('admin','super_admin') order by id limit 1 for share;
 if not found or not exists(select 1 from public.african_football_clubs where id=p_club and is_active) then
  raise exception 'REFUND_GLOBAL_ADMIN_REQUIRED' using errcode='42501'; end if;
end; $$;
create function public.payment_refund_assert_caller(p_club bigint) returns uuid
language plpgsql security definer set search_path='' as $$
begin
 if auth.role() is distinct from 'authenticated' then raise exception 'REFUND_GLOBAL_ADMIN_REQUIRED' using errcode='42501'; end if;
 perform public.assert_staff_step_up();
 perform public.payment_refund_assert_actor(auth.uid(),p_club);
 perform public.assert_staff_step_up();
 return auth.uid();
end; $$;

create function public.payment_refund_original_payment(p_event uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare e public.trusted_sms_gateway_events;l public.momo_ledger_entries;r public.momo_reconciliations;
 p public.momo_sms_parsed;v_table text;
begin
 select * into e from public.trusted_sms_gateway_events where id=p_event and completed_at is not null and status in ('confirmed','allocated');
 if e.id is null then raise exception 'REFUND_CONFIRMED_PAYMENT_REQUIRED'; end if;
 select * into p from public.momo_sms_parsed where raw_sms_id=e.raw_sms_id;
 select * into l from public.momo_ledger_entries where parsed_sms_id=p.id;
 select * into r from public.momo_reconciliations where parsed_sms_id=p.id;
 v_table:=case e.target_kind when 'membership' then 'membership_payment_orders' when 'shop' then 'shop_orders' else 'tickets' end;
 if l.id is null or r.id is null or l.ledger_status<>'posted' or l.entry_type<>'debit' or r.match_status<>'matched'
  or l.user_id is distinct from p.user_id or r.user_id is distinct from l.user_id
  or l.club_id is distinct from e.club_id or r.club_id is distinct from e.club_id
  or l.target_table is distinct from v_table or r.target_table is distinct from v_table
  or l.target_record_id is distinct from e.target_ids[1] or r.target_record_id is distinct from e.target_ids[1]
  or l.amount is distinct from (e.projection->>'amount')::integer or l.currency is distinct from e.projection->>'currency'
  or l.external_reference is distinct from e.provider_transaction_id
  or p.structured_data->>'gateway_event_id' is distinct from e.id::text
  or p.structured_data->>'settlement_record_digest' is distinct from e.projection->>'settlementRecordDigest'
  or (e.target_kind='membership' and (l.metadata->>'business_target_fulfilled' is distinct from 'true'
    or l.metadata->>'intent_id' is distinct from e.intent_id::text))
  or (e.target_kind<>'membership' and (l.metadata->>'commerce_persisted' is distinct from 'true'
    or l.metadata->'record_ids' is distinct from to_jsonb(e.target_ids))) then
  raise exception 'REFUND_CONFIRMED_PAYMENT_REQUIRED'; end if;
 return jsonb_build_object('event_id',e.id,'gateway_id',e.gateway_id,'ledger_id',l.id,'reconciliation_id',r.id,
  'subject_id',l.user_id,'club_id',e.club_id,'target_kind',e.target_kind,'target_ids',e.target_ids,
  'receiver_account_id',e.receiver_account_id,'receiver',e.projection->>'receiver','provider',e.provider,
  'country',e.projection->>'country','currency',l.currency,'amount',l.amount,
  'provider_transaction_id',e.provider_transaction_id,'checkout_reference',e.projection->>'checkoutReference',
  'settlement_record_id',e.projection->>'settlementRecordId',
  'settlement_record_digest',e.projection->>'settlementRecordDigest','membership_id',l.metadata->>'membership_id');
end; $$;

create function public.payment_refund_current_approval(p_gateway uuid) returns jsonb
language sql security definer set search_path='' as $$
 select to_jsonb(a) from public.payment_refund_gateway_approvals a where a.gateway_id=p_gateway and a.enabled
  and length(trim(a.policy_version)) between 1 and 80
  and length(trim(a.source_review_reference)) between 12 and 200
  and length(trim(a.provider_acceptance_reference)) between 12 and 200
  and length(trim(a.terms_reference)) between 12 and 200;
$$;
create function public.get_trusted_payment_refund_gateway_key(p_key_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare k jsonb;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'REFUND_SERVICE_REQUIRED' using errcode='42501'; end if;
 k:=public.get_trusted_sms_gateway_key(p_key_id);
 if k is null or public.payment_refund_current_approval((k->>'gateway_id')::uuid) is null then return null; end if;
 return k;
end; $$;

-- Hold the same canonical target -> receiver -> route sequence as payment
-- processing. A stale receiver or club currency cannot authorize a new refund.
create function public.payment_refund_lock_payment_route(p_payment jsonb,p_key uuid) returns void
language plpgsql security definer set search_path='' as $$
declare e public.trusted_sms_gateway_events;a public.payment_receiver_accounts;c public.african_football_clubs;
 g public.trusted_sms_gateways;k public.trusted_sms_gateway_keys;
begin
 select * into e from public.trusted_sms_gateway_events where id=(p_payment->>'event_id')::uuid;
 if p_payment->>'target_kind'='membership' then
  perform 1 from public.payment_intents where id=e.intent_id and user_id=(p_payment->>'subject_id')::uuid for update;
 else
  perform 1 from public.pending_transactions where reference=p_payment->>'checkout_reference'
   and user_id=(p_payment->>'subject_id')::uuid for update;
 end if;
 if not found then raise exception 'REFUND_TARGET_CHANGED'; end if;
 select * into a from public.payment_receiver_accounts where id=(p_payment->>'receiver_account_id')::uuid for share;
 select * into c from public.african_football_clubs where id=(p_payment->>'club_id')::bigint for share;
 perform 1 from public.partner_payment_routes r where r.club_id=c.id and r.partner_id=a.partner_id and r.status='active'
  and upper(r.country)=p_payment->>'country' and r.recipient_code=p_payment->>'receiver'
  and (case lower(trim(r.provider)) when 'mtn' then 'mtn_rwanda' when 'mtn rwanda' then 'mtn_rwanda' else lower(trim(r.provider)) end)=p_payment->>'provider'
  order by r.id limit 1 for share;
 if not found then raise exception 'REFUND_RECEIVER_CHANGED'; end if;
 select * into g from public.trusted_sms_gateways where id=(p_payment->>'gateway_id')::uuid;
 select * into k from public.trusted_sms_gateway_keys where id=p_key;
 if not coalesce((select enabled from public.trusted_sms_ingress_config where id),false)
  or not coalesce(g.enabled,false) or not coalesce(k.enabled,false) or k.gateway_id is distinct from g.id
  or k.not_before>clock_timestamp() or k.expires_at<=clock_timestamp()
  or not coalesce(length(trim(g.source_review_reference)) between 12 and 200 and length(trim(g.provider_acceptance_reference)) between 12 and 200,false)
  or not coalesce(a.is_active,false) or not coalesce(c.is_active,false)
  or a.payee_number_or_code is distinct from p_payment->>'receiver' or g.receiver_account_id is distinct from a.id
  or g.club_id is distinct from c.id or g.provider is distinct from p_payment->>'provider'
  or g.country is distinct from p_payment->>'country' or c.country_iso_code is distinct from g.country
  or g.currency is distinct from p_payment->>'currency' or c.currency_code is distinct from g.currency then
  raise exception 'REFUND_RECEIVER_CHANGED'; end if;
end; $$;

create function public.payment_refund_receipt(p_id uuid) returns jsonb
language sql security definer set search_path='' as $$
 select jsonb_build_object('id',r.id,'instruction_id',r.instruction_id,'payment_event_id',r.payment_event_id,
  'club_id',r.club_id,'maker_id',r.maker_id,'checker_id',r.checker_id,'payment',r.payment,'amount',r.amount,
  'reason',r.reason,'status',r.status,'revision',r.revision,'confirmed_amount',r.confirmed_amount,
  'approval',r.approval,'current_approval',public.payment_refund_current_approval((r.payment->>'gateway_id')::uuid),
  'instruction',i.instruction,'created_at',r.created_at,'updated_at',r.updated_at,
  'payment_confirmed_amount',coalesce((select sum(c.amount) from public.payment_refund_compensations c where c.payment_event_id=r.payment_event_id),0),
  'consequence',(select result from public.payment_refund_consequences c where c.payment_event_id=r.payment_event_id))
 from public.payment_refund_requests r left join public.payment_refund_instructions i on i.refund_id=r.id where r.id=p_id;
$$;

create function public.admin_recover_payment_refund_operation(p_club_id bigint,p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;result jsonb;
begin
 actor:=public.payment_refund_assert_caller(p_club_id);
 perform pg_advisory_xact_lock(hashtextextended('refund-operation:'||p_operation_id::text,0));
 perform public.payment_refund_assert_caller(p_club_id);
 select o.result into result from public.payment_refund_operations o
  where operation_id=p_operation_id and actor_id=actor and club_id=p_club_id;
 return result;
end; $$;

create function public.admin_prepare_payment_refund(p_club_id bigint,p_payment_event_id uuid,p_amount integer,p_reason text,p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;payment jsonb;args jsonb;op public.payment_refund_operations;id uuid;result jsonb;reserved bigint;
begin
 actor:=public.payment_refund_assert_caller(p_club_id);
 if p_operation_id is null or p_amount is null or p_amount<=0 or p_reason is null or p_reason not in
  ('duplicate_payment','cancelled_order','unavailable_item','cancelled_event','membership_adjustment','other_reviewed') then
  raise exception 'REFUND_INVALID_REQUEST'; end if;
 args:=jsonb_build_object('payment_event_id',p_payment_event_id,'amount',p_amount,'reason',p_reason);
 perform pg_advisory_xact_lock(hashtextextended('refund-operation:'||p_operation_id::text,0));
 perform public.payment_refund_assert_caller(p_club_id);
 select * into op from public.payment_refund_operations where operation_id=p_operation_id;
 if op.operation_id is not null then
  if op.actor_id<>actor or op.club_id<>p_club_id or op.action<>'prepare' or op.args is distinct from args then
   raise exception 'REFUND_OPERATION_BINDING_MISMATCH'; end if;
  return op.result;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('refund-payment:'||p_payment_event_id::text,0));
 perform public.payment_refund_assert_caller(p_club_id);
 payment:=public.payment_refund_original_payment(p_payment_event_id);
 if (payment->>'club_id')::bigint<>p_club_id then raise exception 'REFUND_PAYMENT_NOT_FOUND'; end if;
 select coalesce(sum(amount),0) into reserved from public.payment_refund_requests where payment_event_id=p_payment_event_id and status<>'rejected';
 if reserved+p_amount>(payment->>'amount')::integer then raise exception 'REFUND_AMOUNT_RESERVED'; end if;
 insert into public.payment_refund_requests(payment_event_id,club_id,subject_id,maker_id,payment,amount,reason)
 values(p_payment_event_id,p_club_id,(payment->>'subject_id')::uuid,actor,payment,p_amount,p_reason) returning payment_refund_requests.id into id;
 result:=public.payment_refund_receipt(id)||jsonb_build_object('operation_id',p_operation_id);
 insert into public.payment_refund_operations values(p_operation_id,actor,p_club_id,'prepare',args,result,clock_timestamp());
 insert into public.admin_audit_log(actor_id,user_id,action,target_table,target_id,club_id,metadata)
 values(actor,actor,'payment_refund.prepare','payment_refund_requests',id::text,p_club_id,
  jsonb_build_object('operation_id',p_operation_id,'amount',p_amount,'currency',payment->>'currency','payment_event_id',p_payment_event_id));
 return result;
end; $$;

create function public.admin_review_payment_refund(p_refund_id uuid,p_expected_club_id bigint,p_expected_revision integer,p_approve boolean,p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;r public.payment_refund_requests;op public.payment_refund_operations;args jsonb;v_approval jsonb;result jsonb;
begin
 actor:=public.payment_refund_assert_caller(p_expected_club_id);
 if p_operation_id is null or p_approve is null then raise exception 'REFUND_INVALID_REQUEST'; end if;
 args:=jsonb_build_object('refund_id',p_refund_id,'revision',p_expected_revision,'approve',p_approve);
 perform pg_advisory_xact_lock(hashtextextended('refund-operation:'||p_operation_id::text,0));
 perform public.payment_refund_assert_caller(p_expected_club_id);
 select * into op from public.payment_refund_operations where operation_id=p_operation_id;
 if op.operation_id is not null then
  if op.actor_id<>actor or op.club_id<>p_expected_club_id or op.action<>'review' or op.args is distinct from args then raise exception 'REFUND_OPERATION_BINDING_MISMATCH'; end if;
  return op.result;
 end if;
 select * into r from public.payment_refund_requests where id=p_refund_id and club_id=p_expected_club_id;
 if r.id is null then raise exception 'REFUND_NOT_FOUND'; end if;
 if p_approve then
  perform 1 from public.payment_refund_gateway_approvals where gateway_id=(r.payment->>'gateway_id')::uuid for share;
 end if;
 perform pg_advisory_xact_lock(hashtextextended('refund-payment:'||r.payment_event_id::text,0));
 select * into r from public.payment_refund_requests where id=p_refund_id for update;
 perform public.payment_refund_assert_caller(p_expected_club_id);
 perform public.payment_refund_assert_actor(r.maker_id,p_expected_club_id);
 if actor=r.maker_id then raise exception 'REFUND_DISTINCT_CHECKER_REQUIRED'; end if;
 if r.revision is distinct from p_expected_revision then raise exception 'REFUND_REVIEW_CHANGED'; end if;
 if r.status not in ('awaiting_review','approved') then raise exception 'REFUND_REVIEW_CLOSED'; end if;
 if r.payment is distinct from public.payment_refund_original_payment(r.payment_event_id) then raise exception 'REFUND_PAYMENT_CHANGED'; end if;
 if p_approve then
  v_approval:=public.payment_refund_current_approval((r.payment->>'gateway_id')::uuid);
  if v_approval is null then raise exception 'REFUND_CAPABILITY_CLOSED'; end if;
 end if;
 perform public.payment_refund_assert_caller(p_expected_club_id);
 update public.payment_refund_requests set checker_id=actor,approval=v_approval,status=case when p_approve then 'approved' else 'rejected' end,
  revision=revision+1,updated_at=clock_timestamp() where id=r.id;
 result:=public.payment_refund_receipt(r.id)||jsonb_build_object('operation_id',p_operation_id);
 insert into public.payment_refund_operations values(p_operation_id,actor,p_expected_club_id,'review',args,result,clock_timestamp());
 insert into public.admin_audit_log(actor_id,user_id,action,target_table,target_id,club_id,metadata)
 values(actor,actor,'payment_refund.review','payment_refund_requests',r.id::text,p_expected_club_id,
  jsonb_build_object('operation_id',p_operation_id,'approved',p_approve,'maker_id',r.maker_id,'amount',r.amount,'currency',r.payment->>'currency'));
 return result;
end; $$;

create function public.admin_dispatch_payment_refund(p_refund_id uuid,p_expected_club_id bigint,p_operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;r public.payment_refund_requests;op public.payment_refund_operations;args jsonb;result jsonb;instruction jsonb;key_id uuid;
begin
 actor:=public.payment_refund_assert_caller(p_expected_club_id);
 if p_operation_id is null then raise exception 'REFUND_INVALID_REQUEST'; end if;
 args:=jsonb_build_object('refund_id',p_refund_id);
 perform pg_advisory_xact_lock(hashtextextended('refund-operation:'||p_operation_id::text,0));
 perform public.payment_refund_assert_caller(p_expected_club_id);
 select * into op from public.payment_refund_operations where operation_id=p_operation_id;
 if op.operation_id is not null then
  if op.actor_id<>actor or op.club_id<>p_expected_club_id or op.action<>'dispatch' or op.args is distinct from args then raise exception 'REFUND_OPERATION_BINDING_MISMATCH'; end if;
  return op.result;
 end if;
 select * into r from public.payment_refund_requests where id=p_refund_id and club_id=p_expected_club_id;
 if r.id is null then raise exception 'REFUND_NOT_FOUND'; end if;
 -- Provisioning locks precede request/target locks, matching actual trusted ingress.
 perform 1 from public.trusted_sms_ingress_config where id for share;
 select id into key_id from public.trusted_sms_gateway_keys where gateway_id=(r.payment->>'gateway_id')::uuid
  and enabled and not_before<=clock_timestamp() and expires_at>clock_timestamp() order by id limit 1 for share;
 perform 1 from public.trusted_sms_gateways where id=(r.payment->>'gateway_id')::uuid for share;
 perform 1 from public.payment_refund_gateway_approvals where gateway_id=(r.payment->>'gateway_id')::uuid for share;
 perform pg_advisory_xact_lock(hashtextextended('refund-payment:'||r.payment_event_id::text,0));
 select * into r from public.payment_refund_requests where id=p_refund_id for update;
 perform public.payment_refund_assert_caller(p_expected_club_id);
 perform public.payment_refund_assert_actor(r.maker_id,p_expected_club_id);
 perform public.payment_refund_assert_actor(r.checker_id,p_expected_club_id);
 if r.maker_id=r.checker_id or r.status<>'approved' then raise exception 'REFUND_APPROVED_REVIEW_REQUIRED'; end if;
 if r.approval is null or r.approval is distinct from public.payment_refund_current_approval((r.payment->>'gateway_id')::uuid)
  or not coalesce((select enabled from public.trusted_sms_ingress_config where id),false)
  or not coalesce((select enabled from public.trusted_sms_gateways where id=(r.payment->>'gateway_id')::uuid),false)
  or not exists(select 1 from public.trusted_sms_gateway_keys k where k.gateway_id=(r.payment->>'gateway_id')::uuid
   and k.enabled and k.not_before<=clock_timestamp() and k.expires_at>clock_timestamp()) then raise exception 'REFUND_APPROVAL_CHANGED'; end if;
 if r.payment is distinct from public.payment_refund_original_payment(r.payment_event_id) then raise exception 'REFUND_PAYMENT_CHANGED'; end if;
 perform public.payment_refund_lock_payment_route(r.payment,key_id);
 perform public.payment_refund_assert_caller(p_expected_club_id);
 perform public.payment_refund_assert_actor(r.maker_id,p_expected_club_id);
 perform public.payment_refund_assert_actor(r.checker_id,p_expected_club_id);
 instruction:=jsonb_build_object('protocol','africlub.provider-refund-instruction.v1','id',r.instruction_id,
  'refund_id',r.id,'original_payment',r.payment,'amount',r.amount,'currency',r.payment->>'currency',
  'maker_id',r.maker_id,'checker_id',r.checker_id,'approval',r.approval);
 insert into public.payment_refund_instructions(id,refund_id,club_id,subject_id,maker_id,checker_id,instruction)
 values(r.instruction_id,r.id,r.club_id,r.subject_id,r.maker_id,r.checker_id,instruction);
 update public.payment_refund_requests set status='pending',revision=revision+1,updated_at=clock_timestamp() where id=r.id;
 result:=public.payment_refund_receipt(r.id)||jsonb_build_object('operation_id',p_operation_id);
 insert into public.payment_refund_operations values(p_operation_id,actor,p_expected_club_id,'dispatch',args,result,clock_timestamp());
 insert into public.admin_audit_log(actor_id,user_id,action,target_table,target_id,club_id,metadata)
 values(actor,actor,'payment_refund.dispatch','payment_refund_requests',r.id::text,p_expected_club_id,
  jsonb_build_object('operation_id',p_operation_id,'instruction_id',r.instruction_id,'maker_id',r.maker_id,'checker_id',r.checker_id,
   'amount',r.amount,'currency',r.payment->>'currency'));
 return result;
end; $$;

create function public.admin_payment_refund_dashboard(p_club_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;payments jsonb;requests jsonb;
begin
 actor:=public.payment_refund_assert_caller(p_club_id);
 select coalesce(jsonb_agg(item order by created_at desc),'[]') into requests from
  (select public.payment_refund_receipt(id) item,created_at from public.payment_refund_requests where club_id=p_club_id order by created_at desc limit 1000) q;
 select coalesce(jsonb_agg(item order by completed_at desc),'[]') into payments from
  (select public.payment_refund_original_payment(e.id)||jsonb_build_object('capability_enabled',
    public.payment_refund_current_approval(e.gateway_id) is not null,'reserved_amount',
    coalesce((select sum(r.amount) from public.payment_refund_requests r where r.payment_event_id=e.id and r.status<>'rejected'),0)) item,e.completed_at
   from public.trusted_sms_gateway_events e where e.club_id=p_club_id and e.completed_at is not null and e.status in ('confirmed','allocated')
    order by e.completed_at desc limit 1000) q;
 perform public.payment_refund_assert_caller(p_club_id);
 return jsonb_build_object('club_id',p_club_id,'payments',payments,'requests',requests);
end; $$;

-- No direct mutable grants: even the service adapter can only invoke bounded RPCs.
do $$ declare t text;begin
 foreach t in array array['payment_refund_gateway_approvals','payment_refund_requests','payment_refund_operations',
 'payment_refund_instructions','payment_refund_provider_attempts','payment_refund_evidence','payment_refund_nonces',
 'payment_refund_compensations','payment_refund_consequences','payment_refund_membership_activations'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
 end loop;
 foreach t in array array['payment_refund_gateway_approvals','payment_refund_requests','payment_refund_operations',
 'payment_refund_instructions','payment_refund_provider_attempts','payment_refund_evidence','payment_refund_nonces',
 'payment_refund_compensations','payment_refund_consequences','payment_refund_membership_activations'] loop
  execute format('create trigger account_lifecycle_statement_guard before insert or update or delete on public.%I for each statement execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create trigger account_lifecycle_mutation_guard before insert or update or delete on public.%I for each row execute function public.guard_account_lifecycle_mutation()',t);
  execute format('create policy account_lifecycle_access on public.%I as restrictive for all to authenticated using(public.account_access_allowed()) with check(public.account_access_allowed())',t);
 end loop;
end; $$;
insert into public.account_erasure_fk_inventory(constraint_oid,child_table,subject_table,deletion_action,retained)
select c.oid,c.conrelid::regclass::text,c.confrelid::regclass::text,c.confdeltype::text,true from pg_constraint c
 where c.contype='f' and c.conrelid in ('public.payment_refund_requests'::regclass,'public.payment_refund_operations'::regclass,
 'public.payment_refund_instructions'::regclass,'public.payment_refund_compensations'::regclass,'public.payment_refund_consequences'::regclass,
 'public.payment_refund_membership_activations'::regclass)
 and c.confrelid in ('auth.users'::regclass,'public.users'::regclass,'public.profiles'::regclass) on conflict(constraint_oid) do nothing;

create function public.guard_payment_refund_immutable() returns trigger
language plpgsql set search_path='' as $$
begin
 if tg_op='DELETE' then raise exception 'REFUND_RECORD_IMMUTABLE'; end if;
 if tg_table_name='payment_refund_requests' then
  if (to_jsonb(new)-array['checker_id','approval','revision','status','confirmed_amount','updated_at'])
   is distinct from (to_jsonb(old)-array['checker_id','approval','revision','status','confirmed_amount','updated_at'])
   or new.confirmed_amount<old.confirmed_amount or new.revision<=old.revision
   or (old.status not in ('awaiting_review','approved') and
    (new.checker_id is distinct from old.checker_id or new.approval is distinct from old.approval)) then raise exception 'REFUND_RECORD_IMMUTABLE'; end if;
 elsif tg_table_name='payment_refund_evidence' then
  if old.completed_at is not null or new.completed_at is null or new.result is null
   or (to_jsonb(new)-array['status','completed_at','result']) is distinct from (to_jsonb(old)-array['status','completed_at','result']) then raise exception 'REFUND_RECORD_IMMUTABLE'; end if;
 else raise exception 'REFUND_RECORD_IMMUTABLE'; end if;
 return new;
end; $$;
do $$ declare t text;begin
 foreach t in array array['payment_refund_requests','payment_refund_operations','payment_refund_instructions',
 'payment_refund_provider_attempts','payment_refund_evidence','payment_refund_nonces','payment_refund_compensations','payment_refund_consequences','payment_refund_membership_activations'] loop
  execute format('create trigger refund_immutable before update or delete on public.%I for each row execute function public.guard_payment_refund_immutable()',t);
 end loop;
end; $$;

create function public.admit_trusted_payment_refund_evidence(
 p_key_id uuid,p_nonce uuid,p_created_at timestamptz,p_expires_at timestamptz,p_body_digest text,p_projection jsonb) returns jsonb
language plpgsql security definer set search_path='' set statement_timeout='8s' as $$
declare event uuid;refund uuid;r public.payment_refund_requests;e public.payment_refund_evidence;
 n public.payment_refund_nonces;k public.trusted_sms_gateway_keys;g public.trusted_sms_gateways;
 a public.payment_refund_provider_attempts;key jsonb;settled timestamptz;field text;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'REFUND_SERVICE_REQUIRED' using errcode='42501'; end if;
 if p_key_id is null or p_nonce is null or p_body_digest is null or p_body_digest!~'^[A-Za-z0-9+/]{43}=$'
  or jsonb_typeof(p_projection) is distinct from 'object'
  or (select array_agg(t order by t) from jsonb_object_keys(p_projection) t) is distinct from
   array['amount','country','currency','eventId','instructionId','originalPaymentEventId','originalProviderTransactionId',
    'originalSettlementRecordId','protocol','provider','providerRefundTransactionId','receiver','refundId','settledAt',
    'settlementRecordDigest','settlementRecordId','settlementStatus'] then raise exception 'REFUND_INVALID_EVIDENCE'; end if;
 foreach field in array array['country','currency','eventId','instructionId','originalPaymentEventId','originalProviderTransactionId',
  'originalSettlementRecordId','protocol','provider','providerRefundTransactionId','receiver','refundId','settledAt',
  'settlementRecordDigest','settlementRecordId','settlementStatus'] loop
  if jsonb_typeof(p_projection->field) is distinct from 'string' or length(p_projection->>field) not between 1 and 160 then raise exception 'REFUND_INVALID_EVIDENCE'; end if;
 end loop;
 foreach field in array array['eventId','refundId','instructionId','originalPaymentEventId'] loop
  if (p_projection->>field)!~'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then raise exception 'REFUND_INVALID_EVIDENCE'; end if;
 end loop;
 if p_projection->>'protocol'<>'africlub.receiver-refund-settlement.v1'
  or p_projection->>'settlementStatus' not in ('settled','failed','unknown')
  or (p_projection->>'settlementRecordDigest')!~'^[a-f0-9]{64}$'
  or jsonb_typeof(p_projection->'amount') is distinct from 'number'
  or (p_projection->>'amount')!~'^[0-9]{1,10}$'
  or (p_projection->>'amount')::bigint>2147483647
  or (p_projection->>'settlementStatus'='settled' and (p_projection->>'amount')::integer<=0)
  or (p_projection->>'settlementStatus'<>'settled' and (p_projection->>'amount')::integer<>0)
  or (p_projection->>'settledAt')!~'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?Z$' then raise exception 'REFUND_INVALID_EVIDENCE'; end if;
 begin settled:=(p_projection->>'settledAt')::timestamptz;
 exception when invalid_datetime_format or datetime_field_overflow then raise exception 'REFUND_INVALID_EVIDENCE'; end;
 event:=(p_projection->>'eventId')::uuid;refund:=(p_projection->>'refundId')::uuid;
 perform pg_advisory_xact_lock(hashtextextended('refund-evidence:'||event::text,0));
 perform pg_advisory_xact_lock(hashtextextended('refund-nonce:'||p_key_id::text||':'||p_nonce::text,0));
 -- Exact authority order shared with payment ingress; all checks occur again
 -- after every potentially contended authority or financial wait.
 perform 1 from public.trusted_sms_ingress_config where id for share;
 select * into k from public.trusted_sms_gateway_keys where id=p_key_id for share;
 select * into g from public.trusted_sms_gateways where id=k.gateway_id for share;
 perform 1 from public.payment_refund_gateway_approvals where gateway_id=g.id for share;
 select * into r from public.payment_refund_requests where id=refund;
 if r.id is null then raise exception 'REFUND_INSTRUCTION_BINDING_MISMATCH'; end if;
 perform pg_advisory_xact_lock(hashtextextended('refund-payment:'||r.payment_event_id::text,0));
 select * into r from public.payment_refund_requests where id=refund for update;
 if p_created_at is null or p_expires_at is null or p_created_at>clock_timestamp()+interval '30 seconds'
  or p_created_at<clock_timestamp()-interval '5 minutes' or p_expires_at<=clock_timestamp()
  or p_expires_at<=p_created_at or p_expires_at>p_created_at+interval '5 minutes'
  or settled>clock_timestamp()+interval '30 seconds' or settled<clock_timestamp()-interval '14 days' then raise exception 'REFUND_EXPIRED_EVIDENCE'; end if;
 key:=public.get_trusted_payment_refund_gateway_key(p_key_id);
 if key is null then raise exception 'REFUND_CAPABILITY_CLOSED' using errcode='42501'; end if;
 if r.status not in ('pending','unknown','failed','partially_refunded','refunded')
  or not exists(select 1 from public.payment_refund_instructions i where i.id=r.instruction_id and i.refund_id=r.id)
  or r.instruction_id is distinct from (p_projection->>'instructionId')::uuid
  or r.payment_event_id is distinct from (p_projection->>'originalPaymentEventId')::uuid
  or (r.payment->>'gateway_id')::uuid is distinct from g.id or r.club_id is distinct from g.club_id
  or r.approval is distinct from public.payment_refund_current_approval(g.id)
  or r.payment->>'provider_transaction_id' is distinct from p_projection->>'originalProviderTransactionId'
  or r.payment->>'settlement_record_id' is distinct from p_projection->>'originalSettlementRecordId'
  or r.payment->>'receiver' is distinct from p_projection->>'receiver'
  or r.payment->>'provider' is distinct from p_projection->>'provider'
  or r.payment->>'country' is distinct from p_projection->>'country'
  or r.payment->>'currency' is distinct from p_projection->>'currency'
  or (r.payment->>'receiver_account_id')::uuid is distinct from g.receiver_account_id then raise exception 'REFUND_INSTRUCTION_BINDING_MISMATCH'; end if;
 select * into e from public.payment_refund_evidence where id=event;
 select * into n from public.payment_refund_nonces where key_id=p_key_id and nonce=p_nonce;
 if n.event_id is not null and (n.event_id<>event or n.body_digest<>p_body_digest) then raise exception 'REFUND_NONCE_REUSED'; end if;
 if e.id is not null then
  if e.key_id<>p_key_id or e.gateway_id<>g.id or e.refund_id<>refund or e.body_digest<>p_body_digest or e.projection is distinct from p_projection then raise exception 'REFUND_EVENT_CHANGED'; end if;
  return jsonb_build_object('event_id',e.id,'refund_id',e.refund_id,'status',e.status,'completed',e.completed_at is not null,'replay',true);
 end if;
 perform pg_advisory_xact_lock(hashtextextended('refund-provider-attempt:'||g.provider||':'||(p_projection->>'providerRefundTransactionId'),0));
 insert into public.payment_refund_provider_attempts(provider,provider_refund_transaction_id,refund_id,instruction_id)
 values(g.provider,p_projection->>'providerRefundTransactionId',r.id,r.instruction_id) on conflict do nothing;
 select * into a from public.payment_refund_provider_attempts where provider=g.provider and provider_refund_transaction_id=p_projection->>'providerRefundTransactionId';
 if a.refund_id<>r.id or a.instruction_id<>r.instruction_id then raise exception 'REFUND_PROVIDER_TRANSACTION_REUSED'; end if;
 -- A provider-attempt lock may also wait; no expired/revoked request survives it.
 if p_expires_at<=clock_timestamp() or p_created_at<clock_timestamp()-interval '5 minutes' then raise exception 'REFUND_EXPIRED_EVIDENCE'; end if;
 if public.get_trusted_payment_refund_gateway_key(p_key_id) is null then raise exception 'REFUND_CAPABILITY_CLOSED' using errcode='42501'; end if;
 insert into public.payment_refund_evidence(id,refund_id,gateway_id,key_id,body_digest,projection)
 values(event,refund,g.id,p_key_id,p_body_digest,p_projection);
 insert into public.payment_refund_nonces values(p_key_id,p_nonce,event,p_body_digest,p_expires_at) on conflict do nothing;
 return jsonb_build_object('event_id',event,'refund_id',refund,'status','pending','completed',false,'replay',false);
end; $$;

create function public.process_trusted_payment_refund_evidence(p_event_id uuid) returns jsonb
language plpgsql security definer set search_path='' set statement_timeout='8s' as $$
declare e public.payment_refund_evidence;r public.payment_refund_requests;g public.trusted_sms_gateways;
 c public.payment_refund_compensations;order_row public.shop_orders;item jsonb;v_result jsonb;effects jsonb;
 amount integer;total bigint;payment jsonb;new_status text;compensation uuid;policy jsonb;membership public.membership_payment_orders;
 v_entitlement public.fan_memberships;v_activation public.payment_refund_membership_activations;
begin
 if auth.role() is distinct from 'service_role' then raise exception 'REFUND_SERVICE_REQUIRED' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('refund-evidence:'||p_event_id::text,0));
 select * into e from public.payment_refund_evidence where id=p_event_id;
 if e.id is null then raise exception 'REFUND_EVIDENCE_NOT_FOUND'; end if;
 if e.completed_at is not null then return e.result||jsonb_build_object('replay',true); end if;
 perform 1 from public.trusted_sms_ingress_config where id for share;
 perform 1 from public.trusted_sms_gateway_keys where id=e.key_id for share;
 select * into g from public.trusted_sms_gateways where id=e.gateway_id for share;
 perform 1 from public.payment_refund_gateway_approvals where gateway_id=g.id for share;
 select * into r from public.payment_refund_requests where id=e.refund_id;
 perform pg_advisory_xact_lock(hashtextextended('refund-payment:'||r.payment_event_id::text,0));
 select * into r from public.payment_refund_requests where id=e.refund_id for update;
 select * into e from public.payment_refund_evidence where id=p_event_id for update;
 if e.completed_at is not null then return e.result||jsonb_build_object('replay',true); end if;
 if public.get_trusted_payment_refund_gateway_key(e.key_id) is null then raise exception 'REFUND_CAPABILITY_CLOSED' using errcode='42501'; end if;
 payment:=public.payment_refund_original_payment(r.payment_event_id);
 if payment is distinct from r.payment or r.approval is distinct from public.payment_refund_current_approval(g.id)
  or g.id is distinct from (r.payment->>'gateway_id')::uuid
  or not exists(select 1 from public.payment_refund_instructions i where i.refund_id=r.id and i.id=r.instruction_id
   and i.instruction->'original_payment'=r.payment and i.instruction->'approval'=r.approval
   and (i.instruction->>'amount')::integer=r.amount)
  or r.status not in ('pending','unknown','failed','partially_refunded','refunded') then raise exception 'REFUND_INSTRUCTION_BINDING_MISMATCH'; end if;
 perform public.payment_refund_lock_payment_route(r.payment,e.key_id);
 if public.get_trusted_payment_refund_gateway_key(e.key_id) is null then raise exception 'REFUND_CAPABILITY_CLOSED' using errcode='42501'; end if;
 amount:=(e.projection->>'amount')::integer;
 if e.projection->>'settlementStatus'='settled' then
  select * into c from public.payment_refund_compensations where provider=e.projection->>'provider'
   and provider_refund_transaction_id=e.projection->>'providerRefundTransactionId';
  if c.id is not null then
   if c.refund_id<>r.id or c.amount<>amount or c.currency<>r.payment->>'currency'
    or c.settlement_record_id<>e.projection->>'settlementRecordId'
    or c.settlement_record_digest<>e.projection->>'settlementRecordDigest'
    or c.settled_at is distinct from (e.projection->>'settledAt')::timestamptz then raise exception 'REFUND_PROVIDER_TRANSACTION_CHANGED'; end if;
   compensation:=c.id;
  else
   if amount<=0 or r.confirmed_amount+amount>r.amount then raise exception 'REFUND_AMOUNT_EXCEEDED'; end if;
   insert into public.payment_refund_compensations(refund_id,evidence_id,original_ledger_id,payment_event_id,club_id,subject_id,
    amount,currency,provider,provider_refund_transaction_id,settlement_record_id,settlement_record_digest,settled_at)
   values(r.id,e.id,(r.payment->>'ledger_id')::uuid,r.payment_event_id,r.club_id,r.subject_id,amount,
    r.payment->>'currency',e.projection->>'provider',e.projection->>'providerRefundTransactionId',
    e.projection->>'settlementRecordId',e.projection->>'settlementRecordDigest',(e.projection->>'settledAt')::timestamptz)
   returning id into compensation;
   r.confirmed_amount:=r.confirmed_amount+amount;
  end if;
 end if;
 new_status:=case when r.confirmed_amount=r.amount then 'refunded' when r.confirmed_amount>0 then 'partially_refunded'
  when e.projection->>'settlementStatus'='failed' then 'failed' when e.projection->>'settlementStatus'='unknown' then 'unknown' else 'pending' end;
 update public.payment_refund_requests set confirmed_amount=r.confirmed_amount,status=new_status,revision=revision+1,updated_at=clock_timestamp() where id=r.id;
 select coalesce(sum(refund_credit.amount),0) into total from public.payment_refund_compensations refund_credit where refund_credit.payment_event_id=r.payment_event_id;
 if total>(payment->>'amount')::integer then raise exception 'REFUND_AMOUNT_EXCEEDED'; end if;
 if total=(payment->>'amount')::integer and not exists(select 1 from public.payment_refund_consequences where payment_event_id=r.payment_event_id) then
  policy:=r.approval;effects:=jsonb_build_object('stock','retained','tickets','retained','membership','retained');
  if payment->>'target_kind'='shop' and policy->>'shop_stock_policy'='restore_unfulfilled' then
   select * into order_row from public.shop_orders where id=(payment->'target_ids'->>0)::uuid and club_id=r.club_id and user_id=r.subject_id for update;
   if order_row.id is null or order_row.payment_receipt->>'total' is distinct from payment->>'amount' then raise exception 'REFUND_TARGET_CHANGED'; end if;
   if order_row.status in ('paid','confirmed') and not order_row.inventory_reserved then
    -- Paid stock was already fulfilled from the reservation; the existing
    -- cancellation trigger restores only pending reservations, so restore here once.
    for item in select value from jsonb_array_elements(order_row.items) order by value->>'product_id' loop
     update public.shop_products set stock=stock+(item->>'quantity')::integer
      where id=(item->>'product_id')::uuid and club_id=r.club_id;
     if not found then raise exception 'REFUND_TARGET_CHANGED'; end if;
    end loop;
    update public.shop_orders set status='cancelled',updated_at=clock_timestamp() where id=order_row.id;
    effects:=effects||jsonb_build_object('stock','restored_unfulfilled');
   else effects:=effects||jsonb_build_object('stock','retained_fulfillment_history'); end if;
  elsif payment->>'target_kind'='ticket' and policy->>'ticket_policy'='revoke_unused' then
   perform 1 from public.tickets where id in (select value::uuid from jsonb_array_elements_text(payment->'target_ids')) order by id for update;
   if (select count(*) from public.tickets where id in (select value::uuid from jsonb_array_elements_text(payment->'target_ids')) and club_id=r.club_id and user_id=r.subject_id)
    <>jsonb_array_length(payment->'target_ids') then raise exception 'REFUND_TARGET_CHANGED'; end if;
   update public.tickets set status='refunded',updated_at=clock_timestamp()
    where id in (select value::uuid from jsonb_array_elements_text(payment->'target_ids')) and status='valid';
   effects:=effects||jsonb_build_object('tickets','unused_revoked_used_history_retained');
  elsif payment->>'target_kind'='membership' and policy->>'membership_policy'='suspend_current' then
   select * into membership from public.membership_payment_orders where id=(payment->'target_ids'->>0)::uuid for update;
   select * into v_entitlement from public.fan_memberships where id=(payment->>'membership_id')::uuid for update;
   if membership.id is null or membership.user_id<>r.subject_id or membership.club_id<>r.club_id
    or v_entitlement.id is null or v_entitlement.user_id<>r.subject_id or v_entitlement.club_id<>r.club_id then raise exception 'REFUND_TARGET_CHANGED'; end if;
   select a.* into v_activation from public.payment_refund_membership_activations a
    where a.membership_id=(payment->>'membership_id')::uuid and a.subject_id=r.subject_id and a.club_id=r.club_id
    order by a.activation_sequence desc limit 1;
   if v_activation.payment_order_id is null or v_activation.entitlement is distinct from
    jsonb_build_object('tier',v_entitlement.tier,'partner_id',v_entitlement.partner_id,'expires_at',v_entitlement.expires_at,
     'renewed_at',v_entitlement.renewed_at,'payment_status',v_entitlement.payment_status) then
    effects:=effects||jsonb_build_object('membership','retained_unresolved_membership_binding');
   elsif v_activation.payment_order_id=membership.id then
    update public.fan_memberships set status='suspended',updated_at=clock_timestamp()
     where id=(payment->>'membership_id')::uuid and user_id=r.subject_id and club_id=r.club_id and status='active';
    effects:=effects||jsonb_build_object('membership','current_suspended');
   else effects:=effects||jsonb_build_object('membership','later_paid_membership_retained'); end if;
  end if;
  -- All consequences and financial credits share this one transaction. Original
  -- payment evidence, rewards, admission history and receipt remain unchanged.
  insert into public.payment_refund_consequences values(r.payment_event_id,e.id,r.club_id,r.subject_id,policy,effects,clock_timestamp());
 end if;
 -- Full-refund consequences can wait on the original order, products, ticket
 -- or membership rows. Expiry remains wall-clock authority after those waits;
 -- reject and roll back every credit/consequence if the held key expired.
 if public.get_trusted_payment_refund_gateway_key(e.key_id) is null then raise exception 'REFUND_CAPABILITY_CLOSED' using errcode='42501'; end if;
 v_result:=jsonb_build_object('event_id',e.id,'refund_id',r.id,'instruction_id',r.instruction_id,'status',new_status,
  'confirmed_amount',r.confirmed_amount,'currency',r.payment->>'currency','compensation_id',compensation,'replay',false);
 update public.payment_refund_evidence set status=e.projection->>'settlementStatus',result=v_result,completed_at=clock_timestamp() where id=e.id;
 return v_result;
end; $$;

-- All helpers remain private, including projections of arbitrary retained subjects.
do $$ declare f record;begin
 for f in select oid::regprocedure signature from pg_proc where pronamespace='public'::regnamespace
  and (proname like 'payment_refund_%' or proname like 'admin_%payment_refund%' or proname in
   ('get_trusted_payment_refund_gateway_key','guard_payment_refund_immutable','admit_trusted_payment_refund_evidence','process_trusted_payment_refund_evidence')) loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
 end loop;
end; $$;
grant execute on function public.get_trusted_payment_refund_gateway_key(uuid) to service_role;
grant execute on function public.admit_trusted_payment_refund_evidence(uuid,uuid,timestamptz,timestamptz,text,jsonb),
 public.process_trusted_payment_refund_evidence(uuid) to service_role;
grant execute on function public.admin_payment_refund_dashboard(bigint),public.admin_recover_payment_refund_operation(bigint,uuid),
 public.admin_prepare_payment_refund(bigint,uuid,integer,text,uuid),public.admin_review_payment_refund(uuid,bigint,integer,boolean,uuid),
 public.admin_dispatch_payment_refund(uuid,bigint,uuid) to authenticated;
commit;

begin;

-- All existing payment/parse entrypoints serialize the raw source before taking
-- review/interpretation locks. A missing review cannot reverse the lock order.
-- NO KEY UPDATE still excludes every evidence update, while permitting the FK
-- KEY SHARE used by existing parser ledger/reconciliation INSERTs. Those paths
-- keep their separate business-transaction acceptance requirements.
-- CREATE OR REPLACE preserves the existing restricted EXECUTE grants.

create or replace function public.allocate_momo_payment_intent(
  p_parsed_sms_id uuid, p_intent_id uuid
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_lock_raw_id uuid;
  v_lock_parsed_id uuid;
  v_review public.momo_reconciliations;
  v_parsed public.momo_sms_parsed;
  v_raw public.momo_sms_raw;
  v_intent public.payment_intents;
  v_receiver public.payment_receiver_accounts;
  v_ledger public.momo_ledger_entries;
  v_provider text;
  v_reference text;
  v_metadata jsonb;
  v_now timestamptz;
  v_scope text;
begin
  if p_parsed_sms_id is null or p_intent_id is null then
    raise exception 'INTENT_ALLOCATION_IDS_REQUIRED';
  end if;
  -- Same lock order as operator allocation. Existing reviewed decisions win.
  select raw_sms_id into v_lock_raw_id from public.momo_sms_parsed where id=p_parsed_sms_id;
  if v_lock_raw_id is null then raise exception 'INTENT_ALLOCATION_EVIDENCE_REQUIRED'; end if;
  -- Serialize this source even before its interpretation or review exists.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'momo-evidence:'||v_lock_raw_id::text,0));
  select * into v_review from public.momo_reconciliations
    where parsed_sms_id=p_parsed_sms_id for update;
  select * into v_parsed from public.momo_sms_parsed
    where id=p_parsed_sms_id for no key update;
  if v_parsed.raw_sms_id is distinct from v_lock_raw_id then raise exception 'MOMO_EVIDENCE_CHANGED'; end if;
  if not found then raise exception 'INTENT_ALLOCATION_EVIDENCE_REQUIRED'; end if;
  select * into v_raw from public.momo_sms_raw where id=v_parsed.raw_sms_id for update;
  select * into v_intent from public.payment_intents where id=p_intent_id for update;
  if not found then raise exception 'INTENT_ALLOCATION_NOT_FOUND'; end if;
  select * into v_receiver from public.payment_receiver_accounts
    where id=v_intent.receiving_account_id for update;
  if v_raw.id is null or v_parsed.user_id is distinct from v_raw.user_id
    or v_parsed.user_id is distinct from v_intent.user_id then
    raise exception 'INTENT_ALLOCATION_OWNER_MISMATCH';
  end if;
  if v_parsed.club_id is null or v_parsed.club_id is distinct from v_raw.club_id
    or v_parsed.country_code is distinct from v_raw.country_code then
    raise exception 'INTENT_ALLOCATION_TENANT_MISMATCH';
  end if;
  v_provider:=case lower(btrim(v_raw.provider)) when 'mtn' then 'mtn_rwanda'
    when 'mtn rwanda' then 'mtn_rwanda' else nullif(lower(btrim(v_raw.provider)),'') end;
  v_reference:=nullif(btrim(v_parsed.momo_tx_id),'');
  if v_parsed.parse_status<>'parsed' or v_parsed.tx_direction<>'debit'
    or coalesce(v_parsed.amount,0)<=0 or v_provider is null or v_reference is null
    or v_parsed.is_mock or v_raw.is_mock then
    raise exception 'INTENT_ALLOCATION_INVALID_EVIDENCE';
  end if;
  if v_intent.expected_amount is distinct from v_parsed.amount then
    raise exception 'INTENT_ALLOCATION_AMOUNT_MISMATCH';
  end if;
  if upper(btrim(v_intent.currency)) is distinct from upper(btrim(v_parsed.currency)) then
    raise exception 'INTENT_ALLOCATION_CURRENCY_MISMATCH';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'momo-allocation:'||v_provider||':'||v_reference,0));
  select * into v_ledger from public.momo_ledger_entries
    where parsed_sms_id=p_parsed_sms_id for update;
  -- A competing parser may have inserted this review while we waited above.
  select * into v_review from public.momo_reconciliations
    where parsed_sms_id=p_parsed_sms_id for update;
  if v_intent.status='fulfilled' and v_review.match_status='matched'
    and v_review.metadata->>'intent_id'=p_intent_id::text
    and v_review.metadata->>'allocation_persisted'='true'
    and v_review.user_id=v_parsed.user_id and v_review.club_id=v_parsed.club_id
    and v_ledger.ledger_status='posted' and v_ledger.metadata->>'intent_id'=p_intent_id::text
    and v_ledger.user_id=v_parsed.user_id and v_ledger.club_id=v_parsed.club_id
    and v_ledger.amount=v_parsed.amount and v_ledger.currency=v_parsed.currency
    and v_ledger.entry_type='debit' and v_ledger.external_reference=v_reference
    and v_review.target_table=v_intent.target_table and v_review.target_record_id=v_intent.target_record_id
    and v_ledger.target_table=v_intent.target_table and v_ledger.target_record_id=v_intent.target_record_id then
    return jsonb_build_object('status','allocated','intent_id',p_intent_id,
      'parsed_sms_id',p_parsed_sms_id,'newly_allocated',false);
  end if;
  -- A posted receipt describes the original payment. Today's receiving
  -- account controls new allocations only, not recovery of that receipt.
  if v_receiver.id is null or v_receiver.payee_number_or_code is distinct from v_parsed.payee_number_or_code then
    raise exception 'INTENT_ALLOCATION_RECEIVER_MISMATCH';
  end if;
  if v_intent.status<>'pending' or (v_review.id is not null and
    (v_review.match_status not in ('manual_review','pending_review')
      or v_review.user_id is distinct from v_parsed.user_id
      or v_review.club_id is distinct from v_parsed.club_id)) then
    raise exception 'INTENT_ALLOCATION_STATE_CONFLICT';
  end if;
  -- Every value is re-read under its row lock, and expiry is checked after all
  -- row/advisory waits against wall-clock time, not transaction start time.
  if not v_receiver.is_active then raise exception 'INTENT_ALLOCATION_RECEIVER_MISMATCH'; end if;
  v_now:=clock_timestamp();
  if v_intent.expires_at is not null and v_intent.expires_at<=v_now then
    raise exception 'INTENT_ALLOCATION_EXPIRED';
  end if;
  if v_ledger.id is not null and (v_ledger.ledger_status<>'draft'
    or v_ledger.user_id is distinct from v_parsed.user_id
    or v_ledger.club_id is distinct from v_parsed.club_id
    or v_ledger.entry_type<>'debit' or v_ledger.amount is distinct from v_parsed.amount
    or v_ledger.currency is distinct from v_parsed.currency
    or (v_ledger.target_table is not null and v_ledger.target_table<>v_intent.target_table)
    or (v_ledger.target_record_id is not null and v_ledger.target_record_id<>v_intent.target_record_id)) then
    raise exception 'INTENT_ALLOCATION_LEDGER_CONFLICT';
  end if;
  if exists(select 1 from public.momo_ledger_entries l
    join public.momo_sms_parsed p on p.id=l.parsed_sms_id
    join public.momo_sms_raw r on r.id=p.raw_sms_id
    where l.ledger_status='posted' and p.id<>p_parsed_sms_id
      and btrim(p.momo_tx_id)=v_reference
      and (case lower(btrim(r.provider)) when 'mtn' then 'mtn_rwanda'
        when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(r.provider)) end)=v_provider) then
    raise exception 'INTENT_ALLOCATION_TRANSACTION_USED';
  end if;
  v_metadata:=jsonb_build_object('auto_match',true,'intent_id',p_intent_id,
    'provider',v_provider,'source_raw_sms_id',v_raw.id,'matched_reference',v_reference,
    'allocation_persisted',true,'business_target_fulfilled',false);
  v_scope:=case when v_intent.target_table='group_contributions' then 'group'
    when v_intent.target_table in ('tickets','rs_tickets','shop_orders','rs_shop_orders',
      'initiative_contributions','rs_initiative_contributions','partner_payment_routes') then 'partner'
    else 'wallet' end;
  update public.payment_intents set status='fulfilled',updated_at=v_now where id=p_intent_id;
  insert into public.momo_ledger_entries
    (parsed_sms_id,user_id,entry_type,ledger_scope,ledger_status,amount,currency,
     tx_datetime,external_reference,target_table,target_record_id,description,
     metadata,club_id,country_code,updated_at)
  values (v_parsed.id,v_parsed.user_id,'debit',v_scope,'posted',v_parsed.amount,v_parsed.currency,
    coalesce(v_parsed.tx_datetime,v_raw.sms_received_at),v_reference,v_intent.target_table,
    v_intent.target_record_id,'Payment evidence allocated to an intent',v_metadata,
    v_parsed.club_id,v_parsed.country_code,v_now)
  on conflict (parsed_sms_id) do update set ledger_status='posted',ledger_scope=excluded.ledger_scope,
    external_reference=excluded.external_reference,target_table=excluded.target_table,
    target_record_id=excluded.target_record_id,metadata=public.momo_ledger_entries.metadata||excluded.metadata,
    updated_at=v_now;
  insert into public.momo_reconciliations
    (parsed_sms_id,user_id,match_type,match_status,target_table,target_record_id,
     confidence,notes,metadata,reconciled_at,club_id,country_code,updated_at)
  values (v_parsed.id,v_parsed.user_id,'intent_'||v_intent.target_table,'matched',v_intent.target_table,
    v_intent.target_record_id,v_parsed.confidence,'Payment evidence allocated; linked target fulfillment is separate.',
    v_metadata,v_now,v_parsed.club_id,v_parsed.country_code,v_now)
  on conflict (parsed_sms_id) do update set match_type=excluded.match_type,match_status='matched',
    target_table=excluded.target_table,target_record_id=excluded.target_record_id,
    confidence=excluded.confidence,notes=excluded.notes,
    metadata=public.momo_reconciliations.metadata||excluded.metadata,
    reconciled_at=v_now,updated_at=v_now;
  return jsonb_build_object('status','allocated','intent_id',p_intent_id,
    'parsed_sms_id',p_parsed_sms_id,'newly_allocated',true);
end;
$$;

create or replace function public.allocate_momo_manual_review(
  p_review_id uuid, p_intent_id uuid, p_note text default null
) returns table(review_id uuid, intent_id uuid, matched_reference text)
language plpgsql security definer set search_path = '' as $$
declare
  v_lock_raw_id uuid;
  v_lock_parsed_id uuid;
  v_actor uuid := auth.uid();
  v_review public.momo_reconciliations%rowtype;
  v_parsed public.momo_sms_parsed%rowtype;
  v_raw public.momo_sms_raw%rowtype;
  v_intent public.payment_intents%rowtype;
  v_receiver public.payment_receiver_accounts%rowtype;
  v_ledger public.momo_ledger_entries%rowtype;
  v_provider text;
  v_reference text;
  v_note text;
  v_now timestamptz;
  v_metadata jsonb;
  v_scope text;
begin
  if v_actor is null then raise exception 'MANUAL_ALLOCATION_AUTH_REQUIRED'; end if;
  if p_review_id is null or p_intent_id is null then
    raise exception 'MANUAL_ALLOCATION_IDS_REQUIRED';
  end if;
  if length(coalesce(p_note, '')) > 1000 then raise exception 'MANUAL_ALLOCATION_NOTE_TOO_LONG'; end if;

  select p.raw_sms_id,r.parsed_sms_id into v_lock_raw_id,v_lock_parsed_id
    from public.momo_reconciliations r join public.momo_sms_parsed p on p.id=r.parsed_sms_id
    where r.id=p_review_id;
  if v_lock_raw_id is null then raise exception 'MANUAL_ALLOCATION_NOT_FOUND'; end if;
  -- Serialize this source even before its interpretation or review exists.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'momo-evidence:'||v_lock_raw_id::text,0));
  select * into v_review from public.momo_reconciliations
    where id=p_review_id for update;
  if not found then raise exception 'MANUAL_ALLOCATION_NOT_FOUND'; end if;
  if v_review.parsed_sms_id is distinct from v_lock_parsed_id then raise exception 'MOMO_EVIDENCE_CHANGED'; end if;
  select * into v_parsed from public.momo_sms_parsed
    where id=v_review.parsed_sms_id for no key update;
  if v_parsed.raw_sms_id is distinct from v_lock_raw_id then raise exception 'MOMO_EVIDENCE_CHANGED'; end if;
  if not found then raise exception 'MANUAL_ALLOCATION_INVALID_EVIDENCE'; end if;
  select * into v_raw from public.momo_sms_raw where id=v_parsed.raw_sms_id for update;
  if not found then raise exception 'MANUAL_ALLOCATION_INVALID_EVIDENCE'; end if;
  select * into v_intent from public.payment_intents where id=p_intent_id for update;
  if not found then raise exception 'MANUAL_ALLOCATION_NOT_FOUND'; end if;
  select * into v_receiver from public.payment_receiver_accounts
    where id=v_intent.receiving_account_id for update;

  -- Recheck the actor after all row waits. NULL ownership cannot authorize a
  -- caller, and privilege is evaluated against the review's trusted tenant.
  if not coalesce(public.user_has_admin_workspace_access(v_parsed.club_id, v_receiver.partner_id), false)
     and not coalesce(v_receiver.owner_user_id=v_actor, false) then
    raise exception 'MANUAL_ALLOCATION_FORBIDDEN';
  end if;
  if v_raw.user_id is distinct from v_parsed.user_id
     or v_review.user_id is distinct from v_parsed.user_id
     or v_intent.user_id is distinct from v_parsed.user_id then
    raise exception 'MANUAL_ALLOCATION_OWNER_MISMATCH';
  end if;
  if v_parsed.club_id is null or v_raw.club_id is distinct from v_parsed.club_id
     or v_review.club_id is distinct from v_parsed.club_id then
    raise exception 'MANUAL_ALLOCATION_TENANT_MISMATCH';
  end if;
  v_reference := nullif(btrim(v_parsed.momo_tx_id), '');
  v_provider := case lower(btrim(v_raw.provider))
    when 'mtn' then 'mtn_rwanda' when 'mtn rwanda' then 'mtn_rwanda'
    else nullif(lower(btrim(v_raw.provider)), '') end;
  if v_parsed.parse_status not in ('parsed','needs_review')
     or v_parsed.tx_direction <> 'debit' or coalesce(v_parsed.amount,0) <= 0
     or v_reference is null or v_provider is null then
    raise exception 'MANUAL_ALLOCATION_INVALID_EVIDENCE';
  end if;
  if v_intent.expected_amount is distinct from v_parsed.amount then
    raise exception 'MANUAL_ALLOCATION_AMOUNT_MISMATCH';
  end if;
  if upper(btrim(v_intent.currency)) is distinct from upper(btrim(v_parsed.currency)) then
    raise exception 'MANUAL_ALLOCATION_CURRENCY_MISMATCH';
  end if;
  if v_receiver.id is null
     or v_receiver.payee_number_or_code is distinct from v_parsed.payee_number_or_code then
    raise exception 'MANUAL_ALLOCATION_RECEIVER_MISMATCH';
  end if;

  -- Serialize manual decisions for duplicate imported evidence, including the
  -- same transaction imported by different accounts. Provider delivery and
  -- other reconciliation paths retain their separate acceptance requirements.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'momo-allocation:' || v_provider || ':' || v_reference, 0));
  select * into v_ledger from public.momo_ledger_entries
    where parsed_sms_id=v_parsed.id for update;

  if v_review.match_status='matched' and v_intent.status='fulfilled'
     and v_review.metadata->>'intent_id'=p_intent_id::text
     and v_ledger.metadata->>'intent_id'=p_intent_id::text
     and v_ledger.ledger_status='posted'
     and v_ledger.user_id=v_parsed.user_id and v_ledger.club_id=v_parsed.club_id
     and v_ledger.entry_type='debit' and v_ledger.amount=v_parsed.amount
     and v_ledger.currency=v_parsed.currency and v_ledger.external_reference=v_reference
     and v_review.target_table=v_intent.target_table
     and v_review.target_record_id=v_intent.target_record_id
     and v_ledger.target_table=v_intent.target_table
     and v_ledger.target_record_id=v_intent.target_record_id then
    return query select v_review.id,v_intent.id,v_reference;
    return;
  end if;
  if v_review.match_status not in ('pending_review','manual_review') or v_intent.status <> 'pending' then
    raise exception 'MANUAL_ALLOCATION_STATE_CONFLICT';
  end if;
  if not v_receiver.is_active then raise exception 'MANUAL_ALLOCATION_RECEIVER_MISMATCH'; end if;
  v_now := clock_timestamp();
  if v_intent.expires_at is not null and v_intent.expires_at <= v_now then
    raise exception 'MANUAL_ALLOCATION_EXPIRED';
  end if;
  if v_ledger.id is not null and (
    v_ledger.ledger_status <> 'draft' or v_ledger.user_id is distinct from v_parsed.user_id
    or v_ledger.club_id is distinct from v_parsed.club_id
    or v_ledger.entry_type <> 'debit' or v_ledger.amount is distinct from v_parsed.amount
    or v_ledger.currency is distinct from v_parsed.currency
    or (v_ledger.target_table is not null and v_ledger.target_table <> v_intent.target_table)
    or (v_ledger.target_record_id is not null and v_ledger.target_record_id <> v_intent.target_record_id)
  ) then raise exception 'MANUAL_ALLOCATION_LEDGER_CONFLICT'; end if;
  if exists (
    select 1 from public.momo_ledger_entries l
    join public.momo_sms_parsed p on p.id=l.parsed_sms_id
    join public.momo_sms_raw r on r.id=p.raw_sms_id
    where l.ledger_status='posted' and l.parsed_sms_id<>v_parsed.id
      and btrim(p.momo_tx_id)=v_reference
      and (case lower(btrim(r.provider)) when 'mtn' then 'mtn_rwanda'
        when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(r.provider)) end)=v_provider
  ) then raise exception 'MANUAL_ALLOCATION_TRANSACTION_USED'; end if;

  v_note := coalesce(nullif(btrim(p_note),''),'Admin manually allocated this payment.');
  v_metadata := jsonb_build_object('manual_allocation',true,'intent_id',p_intent_id,
    'matched_reference',v_reference,'allocation_actor_id',v_actor,
    'allocation_source','admin_operations','provider',v_provider);
  v_scope := case
    when v_intent.target_table in ('group_contributions','contribution_groups','groups') then 'group'
    when v_intent.target_table in ('subscriptions','membership_applications','membership_tiers') then 'subscription'
    when v_intent.target_table in ('shop_orders','orders','partners') then 'partner'
    when v_intent.target_table in ('tickets','matches') then 'ticket' else 'wallet' end;

  update public.payment_intents set status='fulfilled',updated_at=v_now where id=v_intent.id;
  update public.momo_reconciliations set target_table=v_intent.target_table,
    target_record_id=v_intent.target_record_id,
    match_type='admin_manual_allocation_to_'||v_intent.target_table,
    match_status='matched',notes=v_note,metadata=metadata||v_metadata,
    reconciled_at=v_now,updated_at=v_now where id=v_review.id;
  if v_ledger.id is null then
    insert into public.momo_ledger_entries
      (parsed_sms_id,user_id,entry_type,ledger_scope,ledger_status,amount,currency,
       tx_datetime,external_reference,target_table,target_record_id,description,
       metadata,created_at,updated_at,club_id,country_code)
    values (v_parsed.id,v_parsed.user_id,'debit',v_scope,'posted',v_parsed.amount,
      v_parsed.currency,coalesce(v_parsed.tx_datetime,v_raw.sms_received_at),v_reference,
      v_intent.target_table,v_intent.target_record_id,'Manual allocation via admin review',
      v_metadata,v_now,v_now,v_parsed.club_id,v_parsed.country_code);
  else
    update public.momo_ledger_entries set target_table=v_intent.target_table,
      target_record_id=v_intent.target_record_id,ledger_status='posted',ledger_scope=v_scope,
      external_reference=v_reference,metadata=metadata||v_metadata,updated_at=v_now
      where id=v_ledger.id;
  end if;
  insert into public.admin_audit_log
    (actor_id,user_id,action,target_table,target_id,old_data,new_data,club_id,
     entity_type,entity_id,metadata,notes)
  values (v_actor,v_actor,'momo_manual_allocation','momo_reconciliations',v_review.id::text,
    jsonb_build_object('match_status',v_review.match_status,'intent_status',v_intent.status),
    jsonb_build_object('match_status','matched','intent_status','fulfilled'),v_parsed.club_id,
    'momo_reconciliation',v_review.id::text,v_metadata,v_note);
  return query select v_review.id,v_intent.id,v_reference;
end;
$$;

create or replace function public.admin_reject_momo_sms_manual_review(
  p_review_id uuid,p_note text default null
) returns table(review_id uuid,match_status text)
language plpgsql security definer set search_path='' as $$
declare
  v_lock_raw_id uuid;
  v_lock_parsed_id uuid;
  v_actor uuid:=auth.uid();
  v_review public.momo_reconciliations%rowtype;
  v_parsed public.momo_sms_parsed%rowtype;
  v_receiver public.payment_receiver_accounts%rowtype;
  v_ledger public.momo_ledger_entries%rowtype;
  v_now timestamptz;
  v_metadata jsonb;
begin
  if v_actor is null then raise exception 'MANUAL_REVIEW_AUTH_REQUIRED'; end if;
  if length(coalesce(p_note,''))>1000 then raise exception 'MANUAL_REVIEW_NOTE_TOO_LONG'; end if;
  select p.raw_sms_id,r.parsed_sms_id into v_lock_raw_id,v_lock_parsed_id
    from public.momo_reconciliations r join public.momo_sms_parsed p on p.id=r.parsed_sms_id
    where r.id=p_review_id;
  if v_lock_raw_id is null then raise exception 'MANUAL_REVIEW_NOT_FOUND'; end if;
  -- Serialize this source even before its interpretation or review exists.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'momo-evidence:'||v_lock_raw_id::text,0));
  select * into v_review from public.momo_reconciliations where id=p_review_id for update;
  if not found then raise exception 'MANUAL_REVIEW_NOT_FOUND'; end if;
  if v_review.parsed_sms_id is distinct from v_lock_parsed_id then raise exception 'MOMO_EVIDENCE_CHANGED'; end if;
  select * into v_parsed from public.momo_sms_parsed where id=v_review.parsed_sms_id for no key update;
  if v_parsed.raw_sms_id is distinct from v_lock_raw_id then raise exception 'MOMO_EVIDENCE_CHANGED'; end if;
  select * into v_receiver from public.payment_receiver_accounts
    where payee_number_or_code=v_parsed.payee_number_or_code for update;
  if not coalesce(public.user_has_admin_workspace_access(v_parsed.club_id,v_receiver.partner_id),false)
    and not coalesce(v_receiver.owner_user_id=v_actor,false) then
    raise exception 'MANUAL_REVIEW_FORBIDDEN';
  end if;
  if v_parsed.id is null or v_parsed.user_id is distinct from v_review.user_id
    or v_parsed.club_id is distinct from v_review.club_id then
    raise exception 'MANUAL_REVIEW_EVIDENCE_MISMATCH';
  end if;
  if v_review.match_status='rejected' and v_review.metadata->>'manual_rejection'='true' then
    return query select v_review.id,'rejected'::text;
    return;
  end if;
  if v_review.match_status not in ('pending_review','manual_review') then
    raise exception 'MANUAL_REVIEW_STATE_CONFLICT';
  end if;
  select * into v_ledger from public.momo_ledger_entries where parsed_sms_id=v_parsed.id for update;
  if v_ledger.id is not null and (v_ledger.ledger_status<>'draft'
    or v_ledger.user_id is distinct from v_parsed.user_id
    or v_ledger.club_id is distinct from v_parsed.club_id) then
    raise exception 'MANUAL_REVIEW_LEDGER_CONFLICT';
  end if;
  v_now:=clock_timestamp();
  v_metadata:=jsonb_build_object('manual_rejection',true,'manual_rejection_actor_id',v_actor,
    'manual_rejection_source','custodian_operations','manual_rejection_reason','not_app_linked','rejected_at',v_now);
  update public.momo_reconciliations set target_table=null,target_record_id=null,
    match_type='manual_rejection',match_status='rejected',
    notes=coalesce(nullif(btrim(p_note),''),'Review rejected because it does not map to an app payment target.'),
    metadata=metadata||v_metadata,reconciled_at=null,updated_at=v_now where id=v_review.id;
  update public.momo_ledger_entries set target_table=null,target_record_id=null,
    metadata=metadata||v_metadata,updated_at=v_now where id=v_ledger.id;
  return query select v_review.id,'rejected'::text;
end;
$$;

create or replace function public.confirm_club_commerce_payment(
  p_kind text, p_record_ids uuid[], p_user_id uuid, p_reference text,
  p_amount integer, p_club_id bigint, p_partner_id uuid,
  p_provider text, p_payee text, p_currency text, p_country text, p_parsed_sms_id uuid
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_lock_raw_id uuid;
  v_lock_parsed_id uuid;
  v_checkout public.pending_transactions;
  v_club public.african_football_clubs;
  v_ticket public.tickets;
  v_match public.matches;
  v_order public.shop_orders;
  v_ids uuid[] := '{}';
  v_expected uuid[];
  v_total bigint := 0;
  v_new integer := 0;
  v_points integer := 0;
  v_referral_id uuid;
  v_referral boolean := false;
  v_provider text;
  v_checkout_provider text;
  v_status text;
  v_parsed public.momo_sms_parsed;
  v_raw public.momo_sms_raw;
  v_review public.momo_reconciliations;
  v_ledger public.momo_ledger_entries;
  v_tx text;
  v_table text;
  v_metadata jsonb;
  v_request jsonb;
begin
  if p_kind not in ('ticket','shop') or p_kind is null or p_user_id is null
    or p_amount is null or p_amount<=0 or p_club_id is null or p_parsed_sms_id is null
    or coalesce(cardinality(p_record_ids),0)=0
    or nullif(btrim(p_reference),'') is null
    or nullif(regexp_replace(p_payee,'\D','','g'),'') is null then
    return jsonb_build_object('status','manual_review','reason','invalid_commerce_binding');
  end if;
  select array_agg(id order by id) into v_expected from unnest(p_record_ids) id;
  if array_position(v_expected,null) is not null
    or cardinality(v_expected)<>(select count(distinct id) from unnest(p_record_ids) id)
    or (p_kind='shop' and cardinality(v_expected)<>1) then
    return jsonb_build_object('status','manual_review','reason','invalid_commerce_records');
  end if;

  -- Match the operator/intent allocation lock order. Re-read original evidence
  -- under locks; selection snapshots and caller amounts are never sufficient.
  select raw_sms_id into v_lock_raw_id from public.momo_sms_parsed where id=p_parsed_sms_id;
  if v_lock_raw_id is null then return jsonb_build_object('status','manual_review','reason','persisted_payment_evidence_mismatch'); end if;
  -- Serialize this source even before its interpretation or review exists.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
    'momo-evidence:'||v_lock_raw_id::text,0));
  select * into v_review from public.momo_reconciliations where parsed_sms_id=p_parsed_sms_id for update;
  select * into v_parsed from public.momo_sms_parsed where id=p_parsed_sms_id for no key update;
  if v_parsed.raw_sms_id is distinct from v_lock_raw_id then raise exception 'MOMO_EVIDENCE_CHANGED'; end if;
  select * into v_raw from public.momo_sms_raw where id=v_parsed.raw_sms_id for update;
  v_provider:=case lower(btrim(p_provider)) when 'mtn' then 'mtn_rwanda'
    when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(p_provider)) end;
  v_tx:=nullif(btrim(v_parsed.momo_tx_id),'');
  v_table:=case when p_kind='ticket' then 'tickets' else 'shop_orders' end;
  if v_parsed.id is null or v_raw.id is null or v_tx is null
    or v_parsed.user_id is distinct from p_user_id or v_raw.user_id is distinct from p_user_id
    or v_parsed.club_id is distinct from p_club_id or v_raw.club_id is distinct from p_club_id
    or v_parsed.country_code is distinct from p_country or v_raw.country_code is distinct from p_country
    or v_parsed.currency is distinct from p_currency or v_parsed.amount is distinct from p_amount
    or v_parsed.parse_status<>'parsed' or v_parsed.tx_direction<>'debit'
    or v_parsed.is_mock or v_raw.is_mock
    or regexp_replace(v_parsed.payee_number_or_code,'\D','','g') is distinct from regexp_replace(p_payee,'\D','','g')
    or (case lower(btrim(v_raw.provider)) when 'mtn' then 'mtn_rwanda'
      when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(v_raw.provider)) end) is distinct from v_provider then
    return jsonb_build_object('status','manual_review','reason','persisted_payment_evidence_mismatch');
  end if;
  -- Ticket issuance already requires exact provider-reference attestation.
  -- Do not turn an equal amount into a looser automatic issuance rule.
  if p_kind='ticket' and upper(regexp_replace(v_tx,'[^A-Za-z0-9]','','g'))
    is distinct from upper(regexp_replace(p_reference,'[^A-Za-z0-9]','','g')) then
    return jsonb_build_object('status','manual_review','reason','ticket_provider_reference_mismatch');
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('momo-allocation:'||v_provider||':'||v_tx,0));
  select * into v_ledger from public.momo_ledger_entries where parsed_sms_id=p_parsed_sms_id for update;
  select * into v_review from public.momo_reconciliations where parsed_sms_id=p_parsed_sms_id for update;
  if v_review.metadata->>'commerce_persisted'='true' and v_review.match_status='matched'
    and v_review.target_table=v_table and v_review.target_record_id=p_record_ids[1]
    and v_review.user_id=p_user_id and v_review.club_id=p_club_id
    and v_review.metadata->'record_ids'=to_jsonb(p_record_ids)
    and v_review.metadata->>'checkout_reference'=p_reference
    and v_ledger.ledger_status='posted' and v_ledger.entry_type='debit'
    and v_ledger.target_table=v_table and v_ledger.target_record_id=p_record_ids[1]
    and v_ledger.user_id=p_user_id and v_ledger.club_id=p_club_id
    and v_ledger.amount=p_amount and v_ledger.currency=p_currency
    and v_ledger.external_reference=v_tx and v_ledger.metadata->>'commerce_persisted'='true' then
    return jsonb_build_object('status','confirmed','record_ids',p_record_ids,'parsed_sms_id',p_parsed_sms_id,
      'newly_confirmed',false,'points_awarded',0,'referral_activated',false,
      'applied_status',v_review.metadata->>'applied_status');
  end if;
  if (v_review.id is not null and (v_review.match_status not in ('manual_review','pending_review')
      or v_review.user_id is distinct from p_user_id or v_review.club_id is distinct from p_club_id))
    or (v_ledger.id is not null and (v_ledger.ledger_status<>'draft' or v_ledger.entry_type<>'debit'
      or v_ledger.user_id is distinct from p_user_id or v_ledger.club_id is distinct from p_club_id
      or v_ledger.amount is distinct from p_amount or v_ledger.currency is distinct from p_currency
      or (v_ledger.target_table is not null and v_ledger.target_table<>v_table)
      or (v_ledger.target_record_id is not null and v_ledger.target_record_id<>p_record_ids[1]))) then
    return jsonb_build_object('status','manual_review','reason','commerce_posting_conflict');
  end if;
  if exists(select 1 from public.momo_ledger_entries l
    join public.momo_sms_parsed p on p.id=l.parsed_sms_id join public.momo_sms_raw r on r.id=p.raw_sms_id
    where l.ledger_status='posted' and p.id<>p_parsed_sms_id and btrim(p.momo_tx_id)=v_tx
      and (case lower(btrim(r.provider)) when 'mtn' then 'mtn_rwanda'
        when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(r.provider)) end)=v_provider) then
    return jsonb_build_object('status','manual_review','reason','provider_transaction_already_posted');
  end if;

  -- The checkout is unique by reference. A changed payee/provider/amount must
  -- be revalidated after its lock wait, not trusted from an HTTP snapshot.
  select * into v_checkout from public.pending_transactions
    where reference=p_reference and user_id=p_user_id for update;
  v_provider:=case lower(btrim(p_provider)) when 'mtn' then 'mtn_rwanda'
    when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(p_provider)) end;
  v_checkout_provider:=case lower(btrim(v_checkout.provider)) when 'mtn' then 'mtn_rwanda'
    when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(v_checkout.provider)) end;
  if v_checkout.id is null or v_checkout.status not in ('pending','confirmed')
    or v_checkout.amount is distinct from p_amount or nullif(v_provider,'') is null
    or v_checkout_provider is distinct from v_provider
    or regexp_replace(v_checkout.recipient_momo,'\D','','g') is distinct from regexp_replace(p_payee,'\D','','g') then
    return jsonb_build_object('status','manual_review','reason','checkout_evidence_mismatch');
  end if;
  select * into v_club from public.african_football_clubs where id=p_club_id for share;
  if v_club.id is null or p_currency is null or p_country is null
    or v_club.currency_code is distinct from p_currency
    or v_club.country_iso_code is distinct from p_country then
    return jsonb_build_object('status','manual_review','reason','checkout_tenant_mismatch');
  end if;

  if p_kind='ticket' then
    for v_ticket in select * from public.tickets
      where user_id=p_user_id and momo_reference=p_reference order by id for update
    loop
      v_ids:=array_append(v_ids,v_ticket.id);
      if v_ticket.club_id is distinct from p_club_id or v_ticket.amount_paid<=0
        or v_ticket.status not in ('pending','valid','used') then
        return jsonb_build_object('status','manual_review','reason','ticket_payment_binding_mismatch');
      end if;
      select * into v_match from public.matches where id=v_ticket.match_id for share;
      if v_match.id is null or v_match.club_id is distinct from p_club_id
        or (v_match.partner_id is not null and v_match.partner_id is distinct from p_partner_id) then
        return jsonb_build_object('status','manual_review','reason','ticket_match_binding_mismatch');
      end if;
      v_total:=v_total+v_ticket.amount_paid;
      if v_ticket.status='pending' then v_new:=v_new+1; end if;
      if v_ticket.id=p_record_ids[1] then v_referral_id:=v_ticket.referral_invite_id; end if;
    end loop;
    if v_ids is distinct from v_expected or v_total<>p_amount then
      return jsonb_build_object('status','manual_review','reason','ticket_bundle_changed');
    end if;
    v_status:='valid';
    if p_partner_id is not null then v_points:=v_new*50; end if;
  else
    -- Lock all same-reference rows before deciding uniqueness. A cancellation,
    -- fulfillment or reservation expiry that wins the race is never reopened.
    for v_order in select * from public.shop_orders
      where user_id=p_user_id and momo_reference=p_reference order by id for update
    loop
      v_ids:=array_append(v_ids,v_order.id);
    end loop;
    if v_ids is distinct from v_expected or v_order.club_id is distinct from p_club_id
      or v_order.total is distinct from p_amount
      or v_order.status not in ('pending','paid','confirmed','packed','fulfilled')
      or (v_order.partner_id is not null and v_order.partner_id is distinct from p_partner_id)
      or (v_order.status='pending' and v_order.inventory_reserved
        and v_order.reservation_expires_at<=clock_timestamp()) then
      return jsonb_build_object('status','manual_review','reason','shop_payment_binding_mismatch');
    end if;
    v_status:=v_order.status;
    if v_order.status='pending' then
      v_new:=1; v_status:='paid';
      if p_partner_id is not null then v_points:=p_amount/100; end if;
    end if;
    v_referral_id:=v_order.referral_invite_id;
  end if;
  if v_new=0 then
    return jsonb_build_object('status','manual_review','reason','confirmed_target_without_matching_receipt');
  end if;
  v_request:=jsonb_build_object('p_kind',p_kind,'p_record_ids',p_record_ids,'p_user_id',p_user_id,
    'p_reference',p_reference,'p_amount',p_amount,'p_club_id',p_club_id,'p_partner_id',p_partner_id,
    'p_provider',p_provider,'p_payee',p_payee,'p_currency',p_currency,'p_country',p_country,'p_parsed_sms_id',p_parsed_sms_id);
  v_metadata:=jsonb_build_object('commerce_persisted',true,'business_target_fulfilled',true,
    'record_ids',p_record_ids,'ticket_ids',case when p_kind='ticket' then to_jsonb(p_record_ids) else '[]'::jsonb end,
    'checkout_reference',p_reference,'provider',v_provider,'source_raw_sms_id',v_raw.id,
    'commerce_request',v_request,'partner_id',p_partner_id,'applied_status',v_status,'points_awarded',v_points);
  -- Insert the exact attestation before status changes, within the SAME
  -- transaction. Ticket validation continues to enforce its existing trigger.
  insert into public.momo_ledger_entries(parsed_sms_id,user_id,entry_type,ledger_scope,ledger_status,
    amount,currency,tx_datetime,external_reference,target_table,target_record_id,payee_partner_id,
    description,metadata,club_id,country_code,updated_at)
  values(p_parsed_sms_id,p_user_id,'debit','partner','posted',p_amount,p_currency,
    coalesce(v_parsed.tx_datetime,v_raw.sms_received_at),v_tx,v_table,p_record_ids[1],p_partner_id,
    'Confirmed club commerce payment',v_metadata,p_club_id,p_country,clock_timestamp())
  on conflict(parsed_sms_id) do update set ledger_status='posted',ledger_scope='partner',
    external_reference=excluded.external_reference,target_table=excluded.target_table,target_record_id=excluded.target_record_id,
    payee_partner_id=excluded.payee_partner_id,metadata=public.momo_ledger_entries.metadata||excluded.metadata,updated_at=clock_timestamp();
  insert into public.momo_reconciliations(parsed_sms_id,user_id,match_type,match_status,target_table,
    target_record_id,confidence,notes,metadata,reconciled_at,club_id,country_code,updated_at)
  values(p_parsed_sms_id,p_user_id,case when p_kind='ticket' then 'rayon_ticket' else 'rayon_shop_order' end,
    'matched',v_table,p_record_ids[1],v_parsed.confidence,'Payment, commerce state and rewards committed atomically.',
    v_metadata,clock_timestamp(),p_club_id,p_country,clock_timestamp())
  on conflict(parsed_sms_id) do update set match_type=excluded.match_type,match_status='matched',
    target_table=excluded.target_table,target_record_id=excluded.target_record_id,confidence=excluded.confidence,
    notes=excluded.notes,metadata=public.momo_reconciliations.metadata||excluded.metadata,
    reconciled_at=excluded.reconciled_at,updated_at=clock_timestamp();
  if p_kind='ticket' then
    update public.tickets set status='valid',confirmed_at=coalesce(confirmed_at,clock_timestamp()),
      updated_at=clock_timestamp() where id=any(v_ids) and status='pending';
  else
    update public.shop_orders set status='paid',confirmed_at=coalesce(confirmed_at,clock_timestamp()),
      updated_at=clock_timestamp() where id=v_order.id and status='pending';
  end if;
  -- Do not swallow a late reward/referral failure: the entire transition must
  -- roll back so the same request can safely retry without losing rewards.
  if v_points>0 then perform public.rs_apply_membership_points(p_user_id,p_partner_id,v_points); end if;
  if v_new>0 and v_referral_id is not null then
    v_referral:=public.activate_referral_invite_for_user(v_referral_id,p_user_id,
      case when p_kind='ticket' then 'rayon_ticket_bought' else 'rayon_shop_order_confirmed' end,
      p_record_ids[1]::text,case when p_kind='ticket' then 140 else 120 end,
      case when p_kind='ticket' then 60 else 50 end);
  end if;
  return jsonb_build_object('status','confirmed','record_ids',p_record_ids,'parsed_sms_id',p_parsed_sms_id,
    'newly_confirmed',v_new>0,'points_awarded',v_points,
    'referral_activated',coalesce(v_referral,false),'applied_status',v_status);
end;
$$;

create or replace function public.claim_momo_sms_parse(
  p_raw_sms_id uuid, p_user_id uuid, p_expected_updated_at timestamptz,
  p_force_reparse boolean default false
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_raw public.momo_sms_raw;
  v_lease public.momo_parse_leases;
  v_parsed_id uuid;
  v_token uuid := gen_random_uuid();
begin
  -- A missing raw ID retains the function's existing not-found/lease refusal.
  if p_raw_sms_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      'momo-evidence:'||p_raw_sms_id::text,0));
  end if;
  -- Use the same review -> interpretation -> raw lock order as allocation.
  select id into v_parsed_id from public.momo_sms_parsed where raw_sms_id=p_raw_sms_id;
  perform id from public.momo_reconciliations where parsed_sms_id=v_parsed_id for update;
  perform id from public.momo_sms_parsed where id=v_parsed_id for no key update;
  select * into v_raw from public.momo_sms_raw where id=p_raw_sms_id for update;
  if v_raw.id is null or v_raw.user_id is distinct from p_user_id then
    return jsonb_build_object('status','not_found');
  end if;
  if v_raw.updated_at is distinct from p_expected_updated_at then
    return jsonb_build_object('status','changed');
  end if;
  if v_raw.parse_status='parsed' and not coalesce(p_force_reparse,false) then
    return jsonb_build_object('status','already_parsed');
  end if;
  if v_raw.parse_status='ignored' then
    return jsonb_build_object('status','review_required');
  end if;
  if exists(select 1 from public.momo_sms_parsed p
    left join public.momo_ledger_entries l on l.parsed_sms_id=p.id
    left join public.momo_reconciliations r on r.parsed_sms_id=p.id
    where p.raw_sms_id=p_raw_sms_id and (l.ledger_status='posted' or r.match_status='matched')) then
    return jsonb_build_object('status','receipt_required');
  end if;
  select * into v_lease from public.momo_parse_leases where raw_sms_id=p_raw_sms_id for update;
  -- Raw status is also editable through other workflows. It cannot override
  -- a private worker claim or prove that a saved interpretation has no effects.
  if v_lease.phase='persisted' or (v_raw.parse_status='processing' and v_lease.raw_sms_id is null) then
    return jsonb_build_object('status','review_required');
  end if;
  if v_lease.raw_sms_id is not null and v_lease.expires_at>clock_timestamp() then
    return jsonb_build_object('status','busy');
  end if;
  update public.momo_sms_raw set parse_status='processing',updated_at=clock_timestamp()
    where id=p_raw_sms_id returning * into v_raw;
  insert into public.momo_parse_leases(raw_sms_id,token,raw_version,expires_at,phase)
    values(p_raw_sms_id,v_token,v_raw.updated_at,clock_timestamp()+interval '2 minutes','parsing')
    on conflict(raw_sms_id) do update set token=excluded.token,raw_version=excluded.raw_version,
      expires_at=excluded.expires_at,phase='parsing';
  update public.momo_parse_attempts set status='failed',error_message='Parser claim expired before an interpretation was persisted.'
    where raw_sms_id=p_raw_sms_id and status='pending';
  return jsonb_build_object('status','claimed','token',v_token);
end;
$$;

create or replace function public.persist_momo_sms_parse(
  p_raw_sms_id uuid, p_user_id uuid, p_token uuid, p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_raw public.momo_sms_raw;
  v_lease public.momo_parse_leases;
  v_parsed public.momo_sms_parsed;
  v_id uuid;
begin
  -- A missing raw ID retains the function's existing not-found/lease refusal.
  if p_raw_sms_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      'momo-evidence:'||p_raw_sms_id::text,0));
  end if;
  select id into v_id from public.momo_sms_parsed where raw_sms_id=p_raw_sms_id;
  perform id from public.momo_reconciliations where parsed_sms_id=v_id for update;
  perform id from public.momo_sms_parsed where id=v_id for no key update;
  select * into v_raw from public.momo_sms_raw where id=p_raw_sms_id for update;
  select * into v_lease from public.momo_parse_leases where raw_sms_id=p_raw_sms_id for update;
  if v_raw.user_id is distinct from p_user_id or v_raw.parse_status is distinct from 'processing'
    or v_lease.token is distinct from p_token or p_token is null
    or v_lease.phase is distinct from 'parsing' or v_lease.expires_at<=clock_timestamp()
    or v_raw.updated_at is distinct from v_lease.raw_version then
    raise exception 'MOMO_PARSE_LEASE_LOST';
  end if;
  if exists(select 1 from public.momo_ledger_entries where parsed_sms_id=v_id and ledger_status='posted')
    or exists(select 1 from public.momo_reconciliations where parsed_sms_id=v_id and match_status='matched') then
    raise exception 'MOMO_PARSE_EVIDENCE_COMMITTED';
  end if;
  v_parsed:=jsonb_populate_record(null::public.momo_sms_parsed,p_payload);
  -- Explicit fields prevent the AI payload from changing identity or tenancy.
  insert into public.momo_sms_parsed(raw_sms_id,user_id,country_code,club_id,is_mock,
    parser_provider,parser_model,parse_status,confidence,tx_direction,tx_type,tx_category,cashflow_bucket,
    momo_tx_id,amount,currency,tx_date,tx_time,tx_datetime,payer_name,payer_number_last3,payer_number_full,
    payee_name,payee_number_or_code,merchant_code,fee_amount,balance_after,counterparty_name,ai_summary,
    recurring_pattern_hint,narrative,structured_data,updated_at)
  values(p_raw_sms_id,v_raw.user_id,v_raw.country_code,v_raw.club_id,v_raw.is_mock,
    v_parsed.parser_provider,v_parsed.parser_model,v_parsed.parse_status,v_parsed.confidence,
    v_parsed.tx_direction,v_parsed.tx_type,v_parsed.tx_category,v_parsed.cashflow_bucket,
    v_parsed.momo_tx_id,v_parsed.amount,v_parsed.currency,v_parsed.tx_date,v_parsed.tx_time,v_parsed.tx_datetime,
    v_parsed.payer_name,v_parsed.payer_number_last3,v_parsed.payer_number_full,v_parsed.payee_name,
    v_parsed.payee_number_or_code,v_parsed.merchant_code,v_parsed.fee_amount,v_parsed.balance_after,
    v_parsed.counterparty_name,v_parsed.ai_summary,v_parsed.recurring_pattern_hint,v_parsed.narrative,
    coalesce(v_parsed.structured_data,'{}'::jsonb),clock_timestamp())
  on conflict(raw_sms_id) do update set parser_provider=excluded.parser_provider,parser_model=excluded.parser_model,
    parse_status=excluded.parse_status,confidence=excluded.confidence,tx_direction=excluded.tx_direction,
    tx_type=excluded.tx_type,tx_category=excluded.tx_category,cashflow_bucket=excluded.cashflow_bucket,
    momo_tx_id=excluded.momo_tx_id,amount=excluded.amount,currency=excluded.currency,tx_date=excluded.tx_date,
    tx_time=excluded.tx_time,tx_datetime=excluded.tx_datetime,payer_name=excluded.payer_name,
    payer_number_last3=excluded.payer_number_last3,payer_number_full=excluded.payer_number_full,
    payee_name=excluded.payee_name,payee_number_or_code=excluded.payee_number_or_code,merchant_code=excluded.merchant_code,
    fee_amount=excluded.fee_amount,balance_after=excluded.balance_after,counterparty_name=excluded.counterparty_name,
    ai_summary=excluded.ai_summary,recurring_pattern_hint=excluded.recurring_pattern_hint,narrative=excluded.narrative,
    structured_data=excluded.structured_data,updated_at=excluded.updated_at
  returning id into v_id;
  update public.momo_parse_leases set phase='persisted' where raw_sms_id=p_raw_sms_id;
  return jsonb_build_object('id',v_id);
end;
$$;

create or replace function public.finish_momo_sms_parse(
  p_raw_sms_id uuid, p_user_id uuid, p_token uuid, p_success boolean,
  p_attempt_id uuid default null, p_request_payload jsonb default null,
  p_response_payload jsonb default null, p_error text default null
) returns boolean language plpgsql security invoker set search_path='' as $$
declare
  v_raw public.momo_sms_raw;
  v_lease public.momo_parse_leases;
begin
  -- A missing raw ID retains the function's existing not-found/lease refusal.
  if p_raw_sms_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(
      'momo-evidence:'||p_raw_sms_id::text,0));
  end if;
  select * into v_raw from public.momo_sms_raw where id=p_raw_sms_id for update;
  select * into v_lease from public.momo_parse_leases where raw_sms_id=p_raw_sms_id for update;
  if v_raw.user_id is distinct from p_user_id or v_raw.parse_status is distinct from 'processing'
    or v_lease.token is distinct from p_token or p_token is null
    or v_raw.updated_at is distinct from v_lease.raw_version then return false; end if;
  if coalesce(p_success,false) then
    if v_lease.phase<>'persisted' or p_attempt_id is null then
      raise exception 'MOMO_PARSE_RESULT_REQUIRED';
    end if;
    update public.momo_parse_attempts set status='success',request_payload=p_request_payload,
      response_payload=p_response_payload,error_message=null
      where id=p_attempt_id and raw_sms_id=p_raw_sms_id and user_id=p_user_id;
    if not found then raise exception 'MOMO_PARSE_ATTEMPT_REQUIRED'; end if;
  else
    update public.momo_parse_attempts set status='failed',error_message=left(coalesce(p_error,'AI parse failed'),1000)
      where raw_sms_id=p_raw_sms_id and user_id=p_user_id and status='pending';
  end if;
  update public.momo_sms_raw set parse_status=case when coalesce(p_success,false) then 'parsed' else 'failed' end,
    updated_at=clock_timestamp() where id=p_raw_sms_id;
  delete from public.momo_parse_leases where raw_sms_id=p_raw_sms_id;
  return true;
end;
$$;

notify pgrst,'reload schema';
commit;

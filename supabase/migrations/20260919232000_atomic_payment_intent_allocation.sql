begin;

-- Allocation is a financial posting, not fulfillment of the linked business
-- target. Preserve that boundary while committing all allocation records once.
create or replace function public.allocate_momo_payment_intent(
  p_parsed_sms_id uuid, p_intent_id uuid
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
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
  select * into v_review from public.momo_reconciliations
    where parsed_sms_id=p_parsed_sms_id for update;
  select * into v_parsed from public.momo_sms_parsed
    where id=p_parsed_sms_id for update;
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
  if v_receiver.id is null or v_receiver.payee_number_or_code is distinct from v_parsed.payee_number_or_code then
    raise exception 'INTENT_ALLOCATION_RECEIVER_MISMATCH';
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
revoke all on function public.allocate_momo_payment_intent(uuid,uuid) from public,anon,authenticated;
grant execute on function public.allocate_momo_payment_intent(uuid,uuid) to service_role;

-- A lost HTTP response must not let the parser's fallback overwrite the
-- committed allocation as "manual_review". Corrections use financial reversal.
create or replace function public.protect_committed_intent_reconciliation()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if old.match_status='matched' and old.metadata->>'allocation_persisted'='true' then
    if new.match_status is distinct from old.match_status
      or new.match_type is distinct from old.match_type
      or new.user_id is distinct from old.user_id
      or new.club_id is distinct from old.club_id
      or new.parsed_sms_id is distinct from old.parsed_sms_id
      or new.target_table is distinct from old.target_table
      or new.target_record_id is distinct from old.target_record_id
      or new.reconciled_at is distinct from old.reconciled_at then
      raise exception 'INTENT_ALLOCATION_COMMITTED';
    end if;
    new.metadata:=new.metadata||jsonb_build_object('allocation_persisted',true,
      'intent_id',old.metadata->'intent_id','business_target_fulfilled',false);
  end if;
  return new;
end;
$$;
revoke all on function public.protect_committed_intent_reconciliation() from public,anon,authenticated;
create trigger protect_committed_intent_reconciliation before update on public.momo_reconciliations
  for each row execute function public.protect_committed_intent_reconciliation();

commit;

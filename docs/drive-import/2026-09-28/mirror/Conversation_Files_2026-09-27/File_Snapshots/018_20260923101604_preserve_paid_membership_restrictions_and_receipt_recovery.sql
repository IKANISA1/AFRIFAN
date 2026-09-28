begin;

-- Preserve immutable paid receipt recovery and administrative restrictions.
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
revoke all on function public.allocate_momo_payment_intent(uuid,uuid) from public,anon,authenticated;
grant execute on function public.allocate_momo_payment_intent(uuid,uuid) to service_role;

create or replace function public.activate_matched_membership_payment() returns trigger
language plpgsql security definer set search_path='' as $$
declare
 payment_order public.membership_payment_orders; intent public.payment_intents;
 evidence public.momo_ledger_entries; membership public.fan_memberships;
begin
 select * into intent from public.payment_intents where id=new.id for update;
 if intent.target_table<>'membership_payment_orders' or intent.status<>'fulfilled' then return null; end if;
 select * into payment_order from public.membership_payment_orders
   where id=intent.target_record_id and payment_intent_id=intent.id for update;
 if payment_order.id is null or payment_order.user_id<>intent.user_id
   or payment_order.amount<>intent.expected_amount or payment_order.currency<>intent.currency
   or payment_order.receiving_account_id<>intent.receiving_account_id then raise exception 'Membership payment binding mismatch'; end if;
 if payment_order.activated_at is not null then return null; end if;
 if payment_order.payment_provider is null or payment_order.payment_country is null
   or payment_order.payment_recipient is null then
   raise exception 'Membership payment route evidence is required'; end if;
 select l.* into evidence from public.momo_ledger_entries l
 join public.momo_reconciliations r on r.parsed_sms_id=l.parsed_sms_id
 join public.momo_sms_parsed p on p.id=l.parsed_sms_id
 join public.momo_sms_raw raw on raw.id=p.raw_sms_id
 join public.payment_receiver_accounts a on a.id=payment_order.receiving_account_id
 where l.metadata->>'intent_id'=intent.id::text and r.metadata->>'intent_id'=intent.id::text
   and l.ledger_status='posted' and l.entry_type='debit' and r.match_status='matched'
   and l.user_id=payment_order.user_id and p.user_id=l.user_id and r.user_id=l.user_id
   and l.club_id=payment_order.club_id and p.club_id=l.club_id and r.club_id=l.club_id
   and l.target_table='membership_payment_orders' and l.target_record_id=payment_order.id
   and r.target_table=l.target_table and r.target_record_id=l.target_record_id
   and l.amount=payment_order.amount and p.amount=l.amount
   and l.currency=payment_order.currency and p.currency=l.currency
   and p.tx_direction='debit' and p.momo_tx_id=l.external_reference
   and p.payee_number_or_code=a.payee_number_or_code and a.partner_id=payment_order.partner_id
   and a.is_active and p.payee_number_or_code=payment_order.payment_recipient
   and p.parse_status in ('parsed','needs_review') and not p.is_mock and not raw.is_mock
   and raw.user_id=payment_order.user_id and raw.club_id=payment_order.club_id
   and upper(p.country_code)=payment_order.payment_country
   and upper(raw.country_code)=payment_order.payment_country
   and (case lower(btrim(raw.provider)) when 'mtn' then 'mtn_rwanda'
     when 'mtn rwanda' then 'mtn_rwanda' else nullif(lower(btrim(raw.provider)),'') end)=payment_order.payment_provider
 limit 1;
 if evidence.id is null then raise exception 'Matched membership payment evidence is required'; end if;
 -- The intent/order locks make one payment idempotent. The membership upsert
 -- serializes different paid orders on (user_id,club_id); it must not wait on
 -- checkout's advisory lock while checkout waits on this transaction's intent.
 insert into public.fan_memberships(user_id,partner_id,club_id,tier,points,chapter,membership_number,payment_status,status,renewed_at,expires_at)
 values(payment_order.user_id,payment_order.partner_id,payment_order.club_id,payment_order.tier,0,'Main',
   'MEM-'||replace(gen_random_uuid()::text,'-',''),'verified','active',now(),now()+interval '1 year')
 on conflict(user_id,club_id) do update set tier=excluded.tier,payment_status='verified',
   -- A payment grants an entitlement; it cannot lift an administrator's restriction.
   status=case when public.fan_memberships.status='suspended' then 'suspended' else 'active' end,
   renewed_at=now(),expires_at=case when public.fan_memberships.tier=excluded.tier then greatest(now(),public.fan_memberships.expires_at)+interval '1 year' else now()+interval '1 year' end,
   updated_at=now() returning * into membership;
 update public.membership_payment_orders set activated_at=now() where id=payment_order.id;
 update public.momo_ledger_entries set ledger_scope='subscription',metadata=metadata||jsonb_build_object('business_target_fulfilled',true,'membership_id',membership.id) where id=evidence.id;
 update public.momo_reconciliations set notes='Membership activated automatically after matched payment.',metadata=metadata||jsonb_build_object('business_target_fulfilled',true,'membership_id',membership.id) where parsed_sms_id=evidence.parsed_sms_id;
 return null;
end $$;

revoke all on function public.activate_matched_membership_payment() from public,anon,authenticated,service_role;
notify pgrst,'reload schema';
commit;

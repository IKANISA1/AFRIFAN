begin;

-- Manual allocation consumes a payment intent. Fulfillment of its business
-- target remains the responsibility of that target's confirmation contract.
-- Never report one of those separate operations as completed by this RPC.
create or replace function public.allocate_momo_manual_review(
  p_review_id uuid, p_intent_id uuid, p_note text default null
) returns table(review_id uuid, intent_id uuid, matched_reference text)
language plpgsql security definer set search_path = '' as $$
declare
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

  select * into v_review from public.momo_reconciliations
    where id=p_review_id for update;
  if not found then raise exception 'MANUAL_ALLOCATION_NOT_FOUND'; end if;
  select * into v_parsed from public.momo_sms_parsed
    where id=v_review.parsed_sms_id for update;
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

revoke all on function public.allocate_momo_manual_review(uuid,uuid,text) from public,anon;
grant execute on function public.allocate_momo_manual_review(uuid,uuid,text) to authenticated,service_role;
comment on function public.allocate_momo_manual_review(uuid,uuid,text) is
  'Guarded operator allocation of matching SMS evidence: atomic intent, reconciliation, debit ledger and audit; identical retries return the committed decision. Does not confirm the linked business target.';

-- Restore only the authenticated operations used by the existing admin UI.
-- The old inherited-ACL cleanup had also removed these guarded entry points.
create or replace function public.admin_reject_momo_sms_manual_review(
  p_review_id uuid,p_note text default null
) returns table(review_id uuid,match_status text)
language plpgsql security definer set search_path='' as $$
declare
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
  select * into v_review from public.momo_reconciliations where id=p_review_id for update;
  if not found then raise exception 'MANUAL_REVIEW_NOT_FOUND'; end if;
  select * into v_parsed from public.momo_sms_parsed where id=v_review.parsed_sms_id for update;
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
revoke all on function public.admin_reject_momo_sms_manual_review(uuid,text) from public,anon;
grant execute on function public.admin_reject_momo_sms_manual_review(uuid,text) to authenticated,service_role;
revoke all on function public.get_momo_sms_manual_review_queue(integer,integer) from public,anon;
grant execute on function public.get_momo_sms_manual_review_queue(integer,integer) to authenticated,service_role;
grant select(id,user_id,target_table,target_record_id,expected_amount,currency,status,expires_at,created_at)
  on public.payment_intents to authenticated;
-- Existing users RLS limits these fields to the owner or a platform operator.
-- Do not grant the phone, identity flags, or other private profile fields.
grant select(id,full_name) on public.users to authenticated;
drop policy if exists payment_intents_select_auth on public.payment_intents;
create policy payment_intents_select_auth on public.payment_intents for select to authenticated
  using (auth.uid()=user_id or public.is_admin_user());

commit;

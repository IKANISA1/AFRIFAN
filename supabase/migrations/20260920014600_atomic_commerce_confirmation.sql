begin;

-- Commit persisted SMS evidence, ledger, reconciliation, ticket/shop state and
-- rewards together. External provider truth and notification delivery remain
-- separate; retain the existing ticket attestation trigger without weakening it.
create or replace function public.confirm_club_commerce_payment(
  p_kind text, p_record_ids uuid[], p_user_id uuid, p_reference text,
  p_amount integer, p_club_id bigint, p_partner_id uuid,
  p_provider text, p_payee text, p_currency text, p_country text, p_parsed_sms_id uuid
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
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
  select * into v_review from public.momo_reconciliations where parsed_sms_id=p_parsed_sms_id for update;
  select * into v_parsed from public.momo_sms_parsed where id=p_parsed_sms_id for update;
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
revoke all on function public.confirm_club_commerce_payment(text,uuid[],uuid,text,integer,bigint,uuid,text,text,text,text,uuid) from public,anon,authenticated;
grant execute on function public.confirm_club_commerce_payment(text,uuid[],uuid,text,integer,bigint,uuid,text,text,text,text,uuid) to service_role;
comment on function public.confirm_club_commerce_payment(text,uuid[],uuid,text,integer,bigint,uuid,text,text,text,text,uuid) is
  'Service-only persisted SMS, checkout, ledger, reconciliation, ticket/shop state and reward transaction. Does not attest external provider truth or durable notification delivery.';

create or replace function public.protect_committed_commerce_reconciliation()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
  if old.match_status='matched' and old.metadata->>'commerce_persisted'='true' then
    if new.match_status is distinct from old.match_status or new.match_type is distinct from old.match_type
      or new.user_id is distinct from old.user_id or new.club_id is distinct from old.club_id
      or new.parsed_sms_id is distinct from old.parsed_sms_id or new.target_table is distinct from old.target_table
      or new.target_record_id is distinct from old.target_record_id or new.reconciled_at is distinct from old.reconciled_at then
      raise exception 'COMMERCE_POSTING_COMMITTED';
    end if;
    new.metadata:=new.metadata||old.metadata;
  end if;
  return new;
end;
$$;
revoke all on function public.protect_committed_commerce_reconciliation() from public,anon,authenticated;
create trigger protect_committed_commerce_reconciliation before update on public.momo_reconciliations
  for each row execute function public.protect_committed_commerce_reconciliation();

commit;

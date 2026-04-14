begin;

create or replace function public.get_momo_sms_manual_review_queue(
  p_limit integer default 50,
  p_offset integer default 0
) returns table(
  review_id uuid,
  raw_sms_id uuid,
  parsed_sms_id uuid,
  user_id uuid,
  sender text,
  tx_type text,
  tx_category text,
  cashflow_bucket text,
  amount integer,
  currency text,
  momo_tx_id text,
  payer_name text,
  payee_name text,
  payee_number_or_code text,
  merchant_code text,
  sms_received_at timestamp with time zone,
  review_created_at timestamp with time zone,
  updated_at timestamp with time zone,
  review_kind text,
  reason text,
  notes text,
  sms_preview text,
  total_count bigint
)
language plpgsql
stable
security definer
set search_path to 'public', 'auth'
as $$
begin
  return query
  with queue_rows as (
    select
      mr.id as review_id,
      raw.id as raw_sms_id,
      parsed.id as parsed_sms_id,
      mr.user_id,
      raw.sender,
      coalesce(parsed.tx_type, 'unknown') as tx_type,
      coalesce(parsed.tx_category, 'uncategorized') as tx_category,
      coalesce(parsed.cashflow_bucket, 'unknown') as cashflow_bucket,
      parsed.amount,
      coalesce(parsed.currency, 'RWF') as currency,
      parsed.momo_tx_id,
      parsed.payer_name,
      parsed.payee_name,
      parsed.payee_number_or_code,
      parsed.merchant_code,
      raw.sms_received_at,
      mr.created_at as review_created_at,
      coalesce(mr.updated_at, mr.created_at) as updated_at,
      case
        when coalesce(parsed.tx_type, 'unknown') in (
          'service_announcement',
          'account_status_update'
        )
          or coalesce(parsed.tx_category, 'uncategorized') = 'uncategorized'
          or coalesce(parsed.cashflow_bucket, 'unknown') = 'unknown'
          or coalesce(parsed.amount, 0) <= 0 then
          'non_actionable'
        when coalesce(mr.metadata ->> 'reason', '') = 'no_pending_transaction_match' then
          'unmatched_payment'
        else
          'needs_review'
      end as review_kind,
      coalesce(nullif(mr.metadata ->> 'reason', ''), 'manual_review') as reason,
      coalesce(nullif(btrim(mr.notes), ''), 'Manual review required.') as notes,
      left(coalesce(raw.sms_body, ''), 220) as sms_preview
    from public.momo_reconciliations mr
    join public.momo_sms_parsed parsed
      on parsed.id = mr.parsed_sms_id
    join public.momo_sms_raw raw
      on raw.id = parsed.raw_sms_id
    left join public.payment_receiver_accounts pra
      on pra.payee_number_or_code = parsed.payee_number_or_code
    where mr.match_status = 'manual_review'
      and (
        public.user_has_admin_workspace_access(
          coalesce(parsed.club_id, mr.club_id),
          pra.partner_id
        )
        or pra.owner_user_id = auth.uid()
      )
  )
  select
    qr.review_id,
    qr.raw_sms_id,
    qr.parsed_sms_id,
    qr.user_id,
    qr.sender,
    qr.tx_type,
    qr.tx_category,
    qr.cashflow_bucket,
    qr.amount,
    qr.currency,
    qr.momo_tx_id,
    qr.payer_name,
    qr.payee_name,
    qr.payee_number_or_code,
    qr.merchant_code,
    qr.sms_received_at,
    qr.review_created_at,
    qr.updated_at,
    qr.review_kind,
    qr.reason,
    qr.notes,
    qr.sms_preview,
    count(*) over() as total_count
  from queue_rows qr
  order by qr.updated_at desc, qr.review_id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

create or replace function public.allocate_momo_manual_review(
  p_review_id uuid,
  p_intent_id uuid,
  p_note text default null::text
) returns table(
  review_id uuid,
  intent_id uuid,
  matched_reference text
)
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_review public.momo_reconciliations%rowtype;
  v_intent public.payment_intents%rowtype;
  v_amount numeric;
  v_currency text;
  v_tx_datetime timestamptz;
  v_parsed_reference text;
  v_reference text;
  v_note text;
  v_user_id uuid;
  v_now timestamptz := now();
  v_parsed_club_id bigint;
  v_review_partner_id uuid;
  v_review_owner_user_id uuid;
begin
  if p_review_id is null then
    raise exception 'Review id is required.';
  end if;

  if p_intent_id is null then
    raise exception 'Intent id is required.';
  end if;

  select *
  into v_review
  from public.momo_reconciliations mr
  where mr.id = p_review_id
  for update;

  if not found then
    raise exception 'Manual review allocation was not found.';
  end if;

  if v_review.match_status not in ('pending_review', 'manual_review') then
    raise exception 'Only pending or manual-review allocations can be resolved.';
  end if;

  select
    parsed.amount,
    parsed.currency,
    coalesce(parsed.tx_datetime, parsed.created_at),
    nullif(parsed.momo_tx_id, ''),
    parsed.user_id,
    parsed.club_id,
    pra.partner_id,
    pra.owner_user_id
  into
    v_amount,
    v_currency,
    v_tx_datetime,
    v_parsed_reference,
    v_user_id,
    v_parsed_club_id,
    v_review_partner_id,
    v_review_owner_user_id
  from public.momo_sms_parsed parsed
  left join public.payment_receiver_accounts pra
    on pra.payee_number_or_code = parsed.payee_number_or_code
  where parsed.id = v_review.parsed_sms_id;

  if not (
    public.user_has_admin_workspace_access(
      coalesce(v_parsed_club_id, v_review.club_id),
      v_review_partner_id
    )
    or v_review_owner_user_id = auth.uid()
  ) then
    raise exception 'Admin or account-owner privileges are required to allocate this review.';
  end if;

  if coalesce(v_amount, 0) <= 0 then
    raise exception 'The reviewed payment does not have a usable amount.';
  end if;

  select *
  into v_intent
  from public.payment_intents pi
  where pi.id = p_intent_id
  for update;

  if not found then
    raise exception 'Payment intent was not found.';
  end if;

  if v_intent.status <> 'pending' then
    raise exception 'Only pending payment intents can be allocated to.';
  end if;

  if v_intent.expected_amount <> v_amount then
    raise exception 'Payment intent expected amount (%) does not match SMS amount (%).', v_intent.expected_amount, v_amount;
  end if;

  v_reference := coalesce(v_parsed_reference, format('MR-%s', v_review.id));

  update public.payment_intents
  set
    status = 'completed',
    updated_at = v_now
  where id = v_intent.id;

  v_note := coalesce(
    nullif(btrim(p_note), ''),
    'Admin manually allocated this payment.'
  );

  update public.momo_reconciliations
  set
    target_table = coalesce(v_intent.target_table, 'payment_intents'),
    target_record_id = coalesce(v_intent.target_record_id, v_intent.id),
    match_type = format(
      'admin_manual_allocation_to_%s',
      coalesce(v_intent.intent_type, 'intent')
    ),
    match_status = 'matched',
    notes = v_note,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'manual_allocation', true,
      'intent_id', p_intent_id,
      'matched_reference', v_reference,
      'allocation_actor_id', auth.uid(),
      'allocation_source', 'admin_operations'
    ),
    reconciled_at = v_now,
    updated_at = v_now
  where id = v_review.id;

  insert into public.momo_ledger_entries (
    parsed_sms_id,
    user_id,
    entry_type,
    ledger_scope,
    ledger_status,
    amount,
    currency,
    tx_datetime,
    external_reference,
    target_table,
    target_record_id,
    description,
    metadata,
    created_at,
    updated_at
  ) values (
    v_review.parsed_sms_id,
    v_user_id,
    case when coalesce(v_amount, 0) >= 0 then 'credit' else 'debit' end,
    case
      when v_intent.intent_type = 'group_contribution' then 'group'
      when v_intent.intent_type = 'subscription' then 'subscription'
      when v_intent.intent_type = 'shop_order' then 'partner'
      else 'wallet'
    end,
    'posted',
    v_amount,
    coalesce(v_currency, 'RWF'),
    coalesce(v_tx_datetime, v_now),
    v_reference,
    coalesce(v_intent.target_table, 'payment_intents'),
    coalesce(v_intent.target_record_id, v_intent.id),
    'Manual allocation via admin review',
    jsonb_build_object(
      'manual_allocation', true,
      'intent_id', p_intent_id,
      'matched_reference', v_reference,
      'allocation_actor_id', auth.uid(),
      'allocation_source', 'admin_operations'
    ),
    v_now,
    v_now
  )
  on conflict (parsed_sms_id) do update set
    target_table = excluded.target_table,
    target_record_id = excluded.target_record_id,
    ledger_status = 'posted',
    ledger_scope = excluded.ledger_scope,
    external_reference = coalesce(
      public.momo_ledger_entries.external_reference,
      excluded.external_reference
    ),
    metadata = coalesce(public.momo_ledger_entries.metadata, '{}'::jsonb) ||
      jsonb_build_object(
        'manual_allocation', true,
        'intent_id', p_intent_id,
        'matched_reference', excluded.external_reference,
        'allocation_actor_id', auth.uid(),
        'allocation_source', 'admin_operations'
      ),
    updated_at = v_now;

  return query
  select v_review.id, v_intent.id, v_reference;
end;
$$;

create or replace function public.admin_reject_momo_sms_manual_review(
  p_review_id uuid,
  p_note text default null::text
) returns table(
  review_id uuid,
  match_status text
)
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_review public.momo_reconciliations%rowtype;
  v_parsed public.momo_sms_parsed%rowtype;
  v_pra public.payment_receiver_accounts%rowtype;
  v_note text;
  v_now timestamptz := now();
begin
  if p_review_id is null then
    raise exception 'Review id is required.';
  end if;

  select *
  into v_review
  from public.momo_reconciliations mr
  where mr.id = p_review_id
  for update;

  if not found then
    raise exception 'Manual review allocation was not found.';
  end if;

  if v_review.match_status not in ('pending_review', 'manual_review') then
    raise exception 'Only pending or manual-review reconciliations can be closed.';
  end if;

  select *
  into v_parsed
  from public.momo_sms_parsed
  where id = v_review.parsed_sms_id;

  select *
  into v_pra
  from public.payment_receiver_accounts
  where payee_number_or_code = v_parsed.payee_number_or_code;

  if not (
    public.user_has_admin_workspace_access(
      coalesce(v_parsed.club_id, v_review.club_id),
      v_pra.partner_id
    )
    or v_pra.owner_user_id = auth.uid()
  ) then
    raise exception 'Admin or account owner privileges required.';
  end if;

  v_note := coalesce(
    nullif(btrim(p_note), ''),
    'Review rejected because it does not map to an app payment target.'
  );

  update public.momo_reconciliations
  set
    target_table = null,
    target_record_id = null,
    match_type = 'manual_rejection',
    match_status = 'rejected',
    notes = v_note,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'manual_rejection', true,
      'manual_rejection_actor_id', auth.uid(),
      'manual_rejection_source', 'custodian_operations',
      'manual_rejection_reason', 'not_app_linked',
      'rejected_at', v_now
    ),
    reconciled_at = null,
    updated_at = v_now
  where id = v_review.id;

  update public.momo_ledger_entries
  set
    target_table = null,
    target_record_id = null,
    ledger_status = 'draft',
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'manual_rejection', true,
      'manual_rejection_actor_id', auth.uid(),
      'manual_rejection_source', 'custodian_operations',
      'manual_rejection_reason', 'not_app_linked',
      'rejected_at', v_now
    ),
    updated_at = v_now
  where parsed_sms_id = v_review.parsed_sms_id;

  return query
  select v_review.id, 'rejected'::text;
end;
$$;

create or replace function public.admin_reject_momo_sms_manual_review_batch(
  p_review_ids uuid[],
  p_note text default null::text
) returns table(
  rejected_count integer
)
language plpgsql
security definer
set search_path to 'public', 'auth'
as $$
declare
  v_now timestamptz := now();
  v_note text;
begin
  if coalesce(array_length(p_review_ids, 1), 0) = 0 then
    return query
    select 0::integer;
    return;
  end if;

  v_note := coalesce(
    nullif(btrim(p_note), ''),
    'Review rejected because it does not map to an app payment target.'
  );

  return query
  with input_ids as (
    select distinct rid as review_id
    from unnest(p_review_ids) as rid
    where rid is not null
  ),
  eligible_reviews as (
    select mr.id, mr.parsed_sms_id
    from public.momo_reconciliations mr
    join input_ids ids
      on ids.review_id = mr.id
    join public.momo_sms_parsed parsed
      on parsed.id = mr.parsed_sms_id
    left join public.payment_receiver_accounts pra
      on pra.payee_number_or_code = parsed.payee_number_or_code
    where mr.match_status in ('pending_review', 'manual_review')
      and (
        public.user_has_admin_workspace_access(
          coalesce(parsed.club_id, mr.club_id),
          pra.partner_id
        )
        or pra.owner_user_id = auth.uid()
      )
    for update
  ),
  updated_reviews as (
    update public.momo_reconciliations mr
    set
      target_table = null,
      target_record_id = null,
      match_type = 'manual_rejection',
      match_status = 'rejected',
      notes = v_note,
      metadata = coalesce(mr.metadata, '{}'::jsonb) || jsonb_build_object(
        'manual_rejection', true,
        'manual_rejection_actor_id', auth.uid(),
        'manual_rejection_source', 'custodian_operations',
        'manual_rejection_reason', 'not_app_linked',
        'rejected_at', v_now
      ),
      reconciled_at = null,
      updated_at = v_now
    from eligible_reviews er
    where mr.id = er.id
    returning er.parsed_sms_id
  ),
  updated_ledger as (
    update public.momo_ledger_entries ledger
    set
      target_table = null,
      target_record_id = null,
      ledger_status = 'draft',
      metadata = coalesce(ledger.metadata, '{}'::jsonb) || jsonb_build_object(
        'manual_rejection', true,
        'manual_rejection_actor_id', auth.uid(),
        'manual_rejection_source', 'custodian_operations',
        'manual_rejection_reason', 'not_app_linked',
        'rejected_at', v_now
      ),
      updated_at = v_now
    where ledger.parsed_sms_id in (
      select parsed_sms_id
      from updated_reviews
    )
    returning ledger.id
  )
  select count(*)::integer
  from updated_reviews;
end;
$$;

comment on function public.allocate_momo_manual_review(uuid, uuid, text)
  is 'Scoped admin or receiver-account-owner operation to explicitly route a pending manual review SMS to a specific payment intent and post to the ledger.';

comment on function public.get_momo_sms_manual_review_queue(integer, integer)
  is 'Queue for M-Money SMS manual reviews, filtered by scoped admin workspace access or receiver account ownership.';

commit;

-- Repair live app-facing RPCs after legacy cleanup. These functions are still
-- referenced by the repo, so they are fixed in place instead of deleted.

create or replace function public.purchase_club_tickets(
  p_match_id uuid,
  p_user_id uuid,
  p_seat_type text,
  p_quantity integer,
  p_payment_reference text
) returns table(id uuid)
language plpgsql
set search_path = public
as $$
declare
  v_match record;
  v_ticket_amount integer;
  v_seat_type text;
  v_index integer;
begin
  if auth.uid() is distinct from p_user_id then
    raise exception 'Authenticated user must match the requested ticket owner.';
  end if;

  if p_quantity is null or p_quantity < 1 then
    raise exception 'Ticket quantity must be at least 1.';
  end if;

  v_seat_type := case
    when lower(coalesce(p_seat_type, '')) = 'vip' then 'vip'
    else 'general'
  end;

  select
    m.id,
    m.club_id,
    m.is_on_sale,
    m.ticket_general_price,
    m.ticket_vip_price
  into v_match
  from public.matches as m
  where m.id = p_match_id
  for update;

  if not found then
    raise exception 'Match % was not found.', p_match_id;
  end if;

  if coalesce(v_match.is_on_sale, false) is not true then
    raise exception 'Tickets are not on sale for this match.';
  end if;

  v_ticket_amount := case
    when v_seat_type = 'vip' then coalesce(v_match.ticket_vip_price, 0)
    else coalesce(v_match.ticket_general_price, 0)
  end;

  for v_index in 1..p_quantity loop
    return query
    insert into public.tickets (
      match_id,
      user_id,
      club_id,
      seat_type,
      amount_paid,
      momo_reference,
      status,
      purchased_at,
      confirmed_at
    )
    values (
      p_match_id,
      p_user_id,
      v_match.club_id,
      v_seat_type,
      v_ticket_amount,
      nullif(btrim(coalesce(p_payment_reference, '')), ''),
      'pending',
      timezone('utc', now()),
      null
    )
    returning tickets.id;
  end loop;
end;
$$;

create or replace function public.prediction_admin_settle(
  p_fixture_id uuid,
  p_home_score integer,
  p_away_score integer,
  p_status text default 'finished'
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_status football.fixture_status := coalesce(nullif(p_status, ''), 'finished')::football.fixture_status;
  v_settlements jsonb := '[]'::jsonb;
  v_fm record;
  v_correct_outcome text;
  v_total_goals int;
  v_settle_result jsonb;
  v_acca_result jsonb;
  v_notif_result jsonb;
  v_streak_user record;
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  if not exists (select 1 from football.fixtures where id = p_fixture_id) then
    return jsonb_build_object('status', 'error', 'message', 'Fixture not found.');
  end if;

  update football.fixtures
  set home_score = p_home_score,
      away_score = p_away_score,
      status = v_status,
      updated_at = now()
  where id = p_fixture_id;

  v_total_goals := p_home_score + p_away_score;

  for v_fm in
    select fm.id as fm_id, pm.slug as market_slug
    from football.fixture_markets fm
    join football.prediction_markets pm on pm.id = fm.market_id
    where fm.fixture_id = p_fixture_id
  loop
    v_correct_outcome := null;

    case v_fm.market_slug
      when '1x2' then
        v_correct_outcome := case
          when p_home_score > p_away_score then 'Home'
          when p_home_score = p_away_score then 'Draw'
          else 'Away'
        end;
      when 'btts' then
        v_correct_outcome := case
          when p_home_score > 0 and p_away_score > 0 then 'Yes'
          else 'No'
        end;
      when 'over-under-1-5' then
        v_correct_outcome := case when v_total_goals > 1 then 'Over 1.5' else 'Under 1.5' end;
      when 'over-under-2-5' then
        v_correct_outcome := case when v_total_goals > 2 then 'Over 2.5' else 'Under 2.5' end;
      else
        v_correct_outcome := null;
    end case;

    if v_correct_outcome is not null then
      v_settlements := v_settlements || jsonb_build_object(
        'market_slug', v_fm.market_slug,
        'correct_outcome', v_correct_outcome
      );
    end if;
  end loop;

  v_settle_result := '{"status":"skipped"}'::jsonb;
  if jsonb_array_length(v_settlements) > 0 then
    v_settle_result := public.prediction_settle_fixture(p_fixture_id, v_settlements);
  end if;

  v_acca_result := public.prediction_settle_acca_slips(p_fixture_id);
  v_notif_result := public.prediction_queue_settlement_notifications(p_fixture_id);

  for v_streak_user in
    select distinct p.user_id
    from football.predictions p
    where p.fixture_id = p_fixture_id
      and p.status in ('won', 'lost')
      and p.settled_at >= now() - interval '10 seconds'
  loop
    begin
      perform public.prediction_check_streak_reward(v_streak_user.user_id);
    exception when others then
      raise notice 'Streak check failed for user %: %', v_streak_user.user_id, sqlerrm;
    end;
  end loop;

  return jsonb_build_object(
    'status', 'success',
    'fixture_id', p_fixture_id,
    'score', format('%s - %s', p_home_score, p_away_score),
    'markets_settled', jsonb_array_length(v_settlements),
    'settlement', v_settle_result,
    'acca', v_acca_result,
    'notifications', v_notif_result
  );
end;
$$;

create or replace function public.prediction_admin_settle(
  p_fixture_id uuid,
  p_home_score integer,
  p_away_score integer,
  p_status text default 'finished',
  p_ht_home_score integer default null,
  p_ht_away_score integer default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, football
as $$
declare
  v_status football.fixture_status := coalesce(nullif(p_status, ''), 'finished')::football.fixture_status;
  v_settlements jsonb := '[]'::jsonb;
  v_fm record;
  v_correct_outcome text;
  v_total_goals int;
  v_settle_result jsonb;
  v_acca_result jsonb;
  v_notif_result jsonb;
  v_streak_user record;
begin
  if auth.role() != 'service_role' then
    return jsonb_build_object('status', 'error', 'message', 'Service role required.');
  end if;

  if not exists (select 1 from football.fixtures where id = p_fixture_id) then
    return jsonb_build_object('status', 'error', 'message', 'Fixture not found.');
  end if;

  update football.fixtures
  set home_score = p_home_score,
      away_score = p_away_score,
      status = v_status,
      updated_at = now()
  where id = p_fixture_id;

  v_total_goals := p_home_score + p_away_score;

  for v_fm in
    select fm.id as fm_id, pm.slug as market_slug
    from football.fixture_markets fm
    join football.prediction_markets pm on pm.id = fm.market_id
    where fm.fixture_id = p_fixture_id
  loop
    v_correct_outcome := null;

    case v_fm.market_slug
      when '1x2' then
        v_correct_outcome := case
          when p_home_score > p_away_score then 'home'
          when p_home_score = p_away_score then 'draw'
          else 'away'
        end;
      when 'btts' then
        v_correct_outcome := case when p_home_score > 0 and p_away_score > 0 then 'yes' else 'no' end;
      when 'over-under-1-5' then
        v_correct_outcome := case when v_total_goals > 1 then 'over' else 'under' end;
      when 'over-under-2-5' then
        v_correct_outcome := case when v_total_goals > 2 then 'over' else 'under' end;
      when 'over-under-3-5' then
        v_correct_outcome := case when v_total_goals > 3 then 'over' else 'under' end;
      when 'half-time-result' then
        if p_ht_home_score is not null and p_ht_away_score is not null then
          v_correct_outcome := case
            when p_ht_home_score > p_ht_away_score then 'home'
            when p_ht_home_score = p_ht_away_score then 'draw'
            else 'away'
          end;
        end if;
      when 'correct-score' then
        v_correct_outcome := p_home_score::text || '-' || p_away_score::text;
      else
        v_correct_outcome := null;
    end case;

    if v_correct_outcome is not null then
      v_settlements := v_settlements || jsonb_build_object(
        'market_slug', v_fm.market_slug,
        'correct_outcome', v_correct_outcome
      );
    end if;
  end loop;

  v_settle_result := '{"status":"skipped"}'::jsonb;
  if jsonb_array_length(v_settlements) > 0 then
    v_settle_result := public.prediction_settle_fixture(p_fixture_id, v_settlements);
  end if;

  v_acca_result := public.prediction_settle_acca_slips(p_fixture_id);
  v_notif_result := public.prediction_queue_settlement_notifications(p_fixture_id);

  for v_streak_user in
    select distinct p.user_id
    from football.predictions p
    where p.fixture_id = p_fixture_id
      and p.status in ('won', 'lost')
      and p.settled_at >= now() - interval '10 seconds'
  loop
    begin
      perform public.prediction_check_streak_reward(v_streak_user.user_id);
    exception when others then
      raise notice 'Streak check failed for user %: %', v_streak_user.user_id, sqlerrm;
    end;
  end loop;

  return jsonb_build_object(
    'status', 'success',
    'fixture_id', p_fixture_id,
    'score', format('%s - %s', p_home_score, p_away_score),
    'ht_score', case
      when p_ht_home_score is not null then format('%s - %s', p_ht_home_score, p_ht_away_score)
      else null
    end,
    'markets_settled', jsonb_array_length(v_settlements),
    'settlement', v_settle_result,
    'acca', v_acca_result,
    'notifications', v_notif_result
  );
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
set search_path = public, auth
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
  v_intent_kind text;
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
  v_intent_kind := coalesce(nullif(v_intent.target_table, ''), 'payment_intents');

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
    target_table = v_intent_kind,
    target_record_id = coalesce(v_intent.target_record_id, v_intent.id),
    match_type = format('admin_manual_allocation_to_%s', v_intent_kind),
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
      when v_intent_kind in ('group_contributions', 'contribution_groups', 'groups') then 'group'
      when v_intent_kind in ('subscriptions', 'membership_applications', 'membership_tiers') then 'subscription'
      when v_intent_kind in ('shop_orders', 'orders', 'partners') then 'partner'
      when v_intent_kind in ('tickets', 'matches') then 'ticket'
      else 'wallet'
    end,
    'posted',
    v_amount,
    coalesce(v_currency, 'RWF'),
    coalesce(v_tx_datetime, v_now),
    v_reference,
    v_intent_kind,
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

create or replace function public.admin_reject_momo_sms_manual_review_batch(
  p_review_ids uuid[],
  p_note text default null::text
) returns table(
  rejected_count integer
)
language plpgsql
security definer
set search_path = public, auth
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
    for update of mr
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

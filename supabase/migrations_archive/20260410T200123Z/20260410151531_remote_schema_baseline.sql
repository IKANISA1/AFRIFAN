--
-- PostgreSQL database dump
--

\restrict gr08AxczS7jBqRQf9Z5r642q4loonQFgr3aF0A2Za3fP0e4oAIIjlzFTgTBpffJ

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.9 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: graphql_public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA graphql_public;


--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: ai_content_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ai_content_status AS ENUM (
    'draft',
    'pending_review',
    'approved',
    'rejected'
);


--
-- Name: ai_content_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ai_content_type AS ENUM (
    'recommendation',
    'banner',
    'promo',
    'tip',
    'hero_headline',
    'club_history',
    'privacy_policy',
    'terms',
    'contact_support',
    'biopay_info',
    'section_heading',
    'portal_hero',
    'general'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: fan_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fan_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    partner_id uuid NOT NULL,
    tier text DEFAULT 'blue'::text NOT NULL,
    points integer DEFAULT 0 NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    chapter text,
    membership_number text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    display_name text DEFAULT '000000'::text NOT NULL,
    expires_at timestamp with time zone,
    club_id bigint,
    renewed_at timestamp with time zone,
    CONSTRAINT rs_fan_memberships_tier_check CHECK ((tier = ANY (ARRAY['blue'::text, 'silver'::text, 'gold'::text, 'platinum'::text])))
);


--
-- Name: COLUMN fan_memberships.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fan_memberships.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN fan_memberships.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fan_memberships.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: add_fan_points(uuid, text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_fan_points(p_user_id uuid, p_partner_id text, p_points integer, p_reason text DEFAULT NULL::text) RETURNS public.fan_memberships
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_club_id bigint;
  v_membership public.fan_memberships;
BEGIN
  v_club_id := COALESCE(
    public.compat_parse_partner_id(p_partner_id),
    NULLIF(public.requesting_club_id(), '')::bigint
  );

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Club context required for fan points.';
  END IF;

  INSERT INTO public.fan_memberships (
    user_id,
    club_id,
    partner_id,
    points,
    tier
  )
  VALUES (
    p_user_id,
    v_club_id,
    COALESCE(NULLIF(trim(coalesce(p_partner_id, '')), ''), v_club_id::text),
    GREATEST(coalesce(p_points, 0), 0),
    public.resolve_fan_tier(GREATEST(coalesce(p_points, 0), 0))
  )
  ON CONFLICT (user_id, club_id)
  DO UPDATE SET
    points = public.fan_memberships.points + GREATEST(coalesce(p_points, 0), 0),
    tier = public.resolve_fan_tier(
      public.fan_memberships.points + GREATEST(coalesce(p_points, 0), 0)
    ),
    renewed_at = timezone('utc', now()),
    updated_at = timezone('utc', now())
  RETURNING * INTO v_membership;

  INSERT INTO public.cool_events (
    user_id,
    club_id,
    event_type,
    xp_awarded,
    metadata,
    event_at
  )
  VALUES (
    p_user_id,
    v_club_id,
    COALESCE(NULLIF(trim(coalesce(p_reason, '')), ''), 'manual_adjustment'),
    GREATEST(coalesce(p_points, 0), 0),
    jsonb_build_object('reason', p_reason, 'source', 'add_fan_points'),
    timezone('utc', now())
  );

  RETURN v_membership;
END;
$$;


--
-- Name: admin_acknowledge_momo_sms_sender_inventory(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_acknowledge_momo_sms_sender_inventory(p_sender_token text, p_note text DEFAULT NULL::text) RETURNS TABLE(sender_token text, resolution_status text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_sender_token text;
  v_sender_display text;
  v_note text;
  v_now timestamptz := now();
  v_approved_sender_tokens constant text[] := array[
    'mmoney',
    'mmoneyalerts',
    'mobilemoney',
    'momo',
    'momoalerts',
    'mtnmomo',
    'mtnmomorwanda'
  ];
begin
  if not public.is_admin() then
    raise exception 'Admin privileges required';
  end if;

  v_sender_token := regexp_replace(
    lower(coalesce(p_sender_token, '')),
    '[^a-z0-9]+',
    '',
    'g'
  );

  if v_sender_token = '' then
    raise exception 'Sender token is required.';
  end if;

  if v_sender_token = any(v_approved_sender_tokens) then
    raise exception 'Approved sender tokens cannot be acknowledged as legacy unsupported senders.';
  end if;

  select btrim(raw.sender)
  into v_sender_display
  from public.momo_sms_raw raw
  where regexp_replace(
    lower(coalesce(raw.sender, '')),
    '[^a-z0-9]+',
    '',
    'g'
  ) = v_sender_token
  order by raw.sms_received_at desc, raw.created_at desc, raw.id desc
  limit 1;

  if not found then
    raise exception 'Unsupported sender backlog was not found.';
  end if;

  v_note := coalesce(
    nullif(btrim(p_note), ''),
    'Admin acknowledged this unsupported sender as legacy raw SMS history. The sender remains unapproved and stays excluded from active intake policies.'
  );

  insert into public.momo_sms_sender_inventory_resolutions as resolution (
    sender_token,
    sender_display,
    resolution_status,
    resolution_note,
    resolved_by,
    resolved_at,
    created_at,
    updated_at
  )
  values (
    v_sender_token,
    v_sender_display,
    'acknowledged_legacy',
    v_note,
    auth.uid(),
    v_now,
    v_now,
    v_now
  )
  on conflict on constraint momo_sms_sender_inventory_resolutions_pkey do update
  set
    sender_display = excluded.sender_display,
    resolution_status = excluded.resolution_status,
    resolution_note = excluded.resolution_note,
    resolved_by = excluded.resolved_by,
    resolved_at = excluded.resolved_at,
    updated_at = excluded.updated_at;

  return query
  select v_sender_token, 'acknowledged_legacy'::text;
end;
$$;


--
-- Name: FUNCTION admin_acknowledge_momo_sms_sender_inventory(p_sender_token text, p_note text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_acknowledge_momo_sms_sender_inventory(p_sender_token text, p_note text) IS 'Admin-only operation that marks an unsupported M-Money SMS sender as acknowledged legacy history without altering the raw SMS records.';


--
-- Name: admin_acknowledge_momo_sms_sender_inventory_batch(text[], text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_acknowledge_momo_sms_sender_inventory_batch(p_sender_tokens text[], p_note text DEFAULT NULL::text) RETURNS TABLE(acknowledged_count integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_note text;
  v_now timestamptz := now();
  v_approved_sender_tokens constant text[] := array[
    'mmoney',
    'mmoneyalerts',
    'mobilemoney',
    'momo',
    'momoalerts',
    'mtnmomo',
    'mtnmomorwanda'
  ];
begin
  if not public.is_admin() then
    raise exception 'Admin privileges required';
  end if;

  if coalesce(array_length(p_sender_tokens, 1), 0) = 0 then
    return query
    select 0::integer;
    return;
  end if;

  v_note := coalesce(
    nullif(btrim(p_note), ''),
    'Admin acknowledged this unsupported sender as legacy raw SMS history. The sender remains unapproved and stays excluded from active intake policies.'
  );

  return query
  with normalized_tokens as (
    select distinct regexp_replace(
      lower(coalesce(raw_token, '')),
      '[^a-z0-9]+',
      '',
      'g'
    ) as sender_token
    from unnest(p_sender_tokens) as raw_token
  ),
  eligible_tokens as (
    select nt.sender_token
    from normalized_tokens nt
    where nt.sender_token <> ''
      and not (nt.sender_token = any(v_approved_sender_tokens))
  ),
  source_rows as (
    select
      et.sender_token,
      (
        select btrim(raw.sender)
        from public.momo_sms_raw raw
        where regexp_replace(
          lower(coalesce(raw.sender, '')),
          '[^a-z0-9]+',
          '',
          'g'
        ) = et.sender_token
        order by raw.sms_received_at desc, raw.created_at desc, raw.id desc
        limit 1
      ) as sender_display
    from eligible_tokens et
  ),
  resolved_rows as (
    select
      sr.sender_token,
      sr.sender_display
    from source_rows sr
    where sr.sender_display is not null
  ),
  upserted as (
    insert into public.momo_sms_sender_inventory_resolutions as resolution (
      sender_token,
      sender_display,
      resolution_status,
      resolution_note,
      resolved_by,
      resolved_at,
      created_at,
      updated_at
    )
    select
      rr.sender_token,
      rr.sender_display,
      'acknowledged_legacy',
      v_note,
      auth.uid(),
      v_now,
      v_now,
      v_now
    from resolved_rows rr
    on conflict on constraint momo_sms_sender_inventory_resolutions_pkey do update
    set
      sender_display = excluded.sender_display,
      resolution_status = excluded.resolution_status,
      resolution_note = excluded.resolution_note,
      resolved_by = excluded.resolved_by,
      resolved_at = excluded.resolved_at,
      updated_at = excluded.updated_at
    returning resolution.sender_token
  )
  select count(*)::integer
  from upserted;
end;
$$;


--
-- Name: FUNCTION admin_acknowledge_momo_sms_sender_inventory_batch(p_sender_tokens text[], p_note text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_acknowledge_momo_sms_sender_inventory_batch(p_sender_tokens text[], p_note text) IS 'Admin-only batch operation that marks unsupported M-Money SMS senders as acknowledged legacy history without altering raw SMS records.';


--
-- Name: admin_reject_momo_sms_manual_review(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_reject_momo_sms_manual_review(p_review_id uuid, p_note text DEFAULT NULL::text) RETURNS TABLE(review_id uuid, match_status text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
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

  -- Authorization: must be admin or owner of the receiver account
  if not public.is_admin() then
    if v_pra.id is null then
      raise exception 'Admin privileges required to reject unowned reviews.';
    end if;
    if v_pra.owner_user_id <> auth.uid() then
      raise exception 'Admin or account owner privileges required.';
    end if;
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


--
-- Name: FUNCTION admin_reject_momo_sms_manual_review(p_review_id uuid, p_note text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_reject_momo_sms_manual_review(p_review_id uuid, p_note text) IS 'Admin-only operation that closes a generic M-Money SMS manual review as not app-linked without deleting the underlying wallet history.';


--
-- Name: admin_reject_momo_sms_manual_review_batch(uuid[], text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_reject_momo_sms_manual_review_batch(p_review_ids uuid[], p_note text DEFAULT NULL::text) RETURNS TABLE(rejected_count integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
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
        public.is_admin()
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
    returning mr.id, er.parsed_sms_id
  ),
  updated_ledgers as (
    update public.momo_ledger_entries le
    set
      target_table = null,
      target_record_id = null,
      ledger_status = 'draft',
      metadata = coalesce(le.metadata, '{}'::jsonb) || jsonb_build_object(
        'manual_rejection', true,
        'manual_rejection_actor_id', auth.uid(),
        'manual_rejection_source', 'custodian_operations',
        'manual_rejection_reason', 'not_app_linked',
        'rejected_at', v_now
      ),
      updated_at = v_now
    from updated_reviews ur
    where le.parsed_sms_id = ur.parsed_sms_id
    returning le.id
  )
  select count(*)::integer
  from updated_reviews;
end;
$$;


--
-- Name: FUNCTION admin_reject_momo_sms_manual_review_batch(p_review_ids uuid[], p_note text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_reject_momo_sms_manual_review_batch(p_review_ids uuid[], p_note text) IS 'Admin-only batch operation that closes generic M-Money SMS manual reviews as not app-linked.';


--
-- Name: ai_content_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.ai_content_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;


--
-- Name: allocate_momo_manual_review(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.allocate_momo_manual_review(p_review_id uuid, p_intent_id uuid, p_note text DEFAULT NULL::text) RETURNS TABLE(review_id uuid, intent_id uuid, matched_reference text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
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
begin
  if p_review_id is null then
    raise exception 'Review id is required.';
  end if;

  if p_intent_id is null then
    raise exception 'Intent id is required.';
  end if;

  if not public.is_admin() then
    raise exception 'Admin privileges required to execute generalized manual allocation.';
  end if;

  -- 1. Lock and fetch the manual review
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

  -- 2. Fetch parsed details
  select
    parsed.amount,
    parsed.currency,
    coalesce(parsed.tx_datetime, parsed.created_at),
    nullif(parsed.momo_tx_id, ''),
    parsed.user_id
  into
    v_amount,
    v_currency,
    v_tx_datetime,
    v_parsed_reference,
    v_user_id
  from public.momo_sms_parsed parsed
  where parsed.id = v_review.parsed_sms_id;

  if coalesce(v_amount, 0) <= 0 then
    raise exception 'The reviewed payment does not have a usable amount.';
  end if;

  -- 3. Lock and fetch intent
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

  v_reference := coalesce(
    v_parsed_reference,
    format('MR-%s', v_review.id)
  );

  -- 4. Update the Payment Intent
  update public.payment_intents
  set
    status = 'completed',
    updated_at = v_now
  where id = v_intent.id;

  v_note := coalesce(
    nullif(btrim(p_note), ''),
    'Admin manually allocated this payment.'
  );

  -- 5. Update reconciliation record
  update public.momo_reconciliations
  set
    target_table = coalesce(v_intent.target_table, 'payment_intents'),
    target_record_id = coalesce(v_intent.target_record_id, v_intent.id),
    match_type = format('admin_manual_allocation_to_%s', coalesce(v_intent.intent_type, 'intent')),
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

  -- 6. Upsert the Ledger Entry (because pending review SMSs no longer default create ledger rows)
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
    external_reference = coalesce(public.momo_ledger_entries.external_reference, excluded.external_reference),
    metadata = coalesce(public.momo_ledger_entries.metadata, '{}'::jsonb) || jsonb_build_object(
      'manual_allocation', true,
      'intent_id', p_intent_id,
      'matched_reference', excluded.external_reference,
      'allocation_actor_id', auth.uid(),
      'allocation_source', 'admin_operations'
    ),
    updated_at = v_now;

  return query
  select
    v_review.id,
    v_intent.id,
    v_reference;
end;
$$;


--
-- Name: FUNCTION allocate_momo_manual_review(p_review_id uuid, p_intent_id uuid, p_note text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.allocate_momo_manual_review(p_review_id uuid, p_intent_id uuid, p_note text) IS 'Admin-only operation to explicitly route a pending manual review SMS to a specific Payment Intent and post to the ledger.';


--
-- Name: allocate_transaction_to_member(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.allocate_transaction_to_member(p_ledger_id uuid, p_group_id uuid, p_member_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_ledger public.momo_ledger_entries%rowtype;
  v_caller_id uuid := auth.uid();
  v_is_group_admin boolean;
  v_member_exists boolean;
  v_now timestamptz := now();
begin
  -- Validate input
  if p_ledger_id is null then
    raise exception 'Ledger entry id is required.';
  end if;
  if p_group_id is null then
    raise exception 'Group id is required.';
  end if;
  if p_member_user_id is null then
    raise exception 'Member user id is required.';
  end if;

  -- Check caller is a group admin or app admin
  select exists(
    select 1
    from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = v_caller_id
      and gm.is_admin = true
  ) into v_is_group_admin;

  if not v_is_group_admin and not public.is_admin() then
    raise exception 'You must be a group admin to allocate transactions.';
  end if;

  -- Verify the target member exists in the group
  select exists(
    select 1
    from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = p_member_user_id
  ) into v_member_exists;

  if not v_member_exists then
    raise exception 'The target member is not in this group.';
  end if;

  -- Lock and fetch the ledger entry
  select *
  into v_ledger
  from public.momo_ledger_entries
  where id = p_ledger_id
  for update;

  if not found then
    raise exception 'Ledger entry not found.';
  end if;

  -- Update the ledger entry
  update public.momo_ledger_entries
  set
    target_table = 'group_contributions',
    target_record_id = p_group_id,
    user_id = p_member_user_id,
    ledger_scope = 'group',
    ledger_status = 'posted',
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'group_allocation', true,
      'allocated_group_id', p_group_id,
      'allocated_member_id', p_member_user_id,
      'allocation_actor_id', v_caller_id,
      'allocation_source', 'group_admin',
      'allocated_at', v_now
    ),
    updated_at = v_now
  where id = p_ledger_id;

  return jsonb_build_object(
    'status', 'success',
    'ledger_id', p_ledger_id,
    'group_id', p_group_id,
    'member_user_id', p_member_user_id
  );
end;
$$;


--
-- Name: FUNCTION allocate_transaction_to_member(p_ledger_id uuid, p_group_id uuid, p_member_user_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.allocate_transaction_to_member(p_ledger_id uuid, p_group_id uuid, p_member_user_id uuid) IS 'Group-admin action: allocate a ledger entry to a specific group member.';


--
-- Name: cool_status; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_status (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    total_points integer DEFAULT 0 NOT NULL,
    tier text DEFAULT 'blue'::text NOT NULL,
    current_streak integer DEFAULT 0 NOT NULL,
    longest_streak integer DEFAULT 0 NOT NULL,
    streak_grace_remaining integer DEFAULT 1 NOT NULL,
    season_points integer DEFAULT 0 NOT NULL,
    active_season_id uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    club_id bigint
);


--
-- Name: TABLE cool_status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cool_status IS 'Unified cross-app status: points, tier, streaks.';


--
-- Name: COLUMN cool_status.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_status.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN cool_status.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_status.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: apply_cool_event(uuid, text, integer, text, jsonb, uuid, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_cool_event(p_user_id uuid, p_event_type text, p_points integer DEFAULT 0, p_source_id text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb, p_referrer_id uuid DEFAULT NULL::uuid, p_dedupe_key text DEFAULT NULL::text, p_campaign_id text DEFAULT NULL::text, p_season_id uuid DEFAULT NULL::uuid) RETURNS public.cool_status
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if auth.uid() is null and auth.role() <> 'service_role' then
    raise exception 'Authentication is required.';
  end if;

  if auth.role() <> 'service_role' and auth.uid() <> p_user_id then
    raise exception 'You can only log your own status event.';
  end if;

  return public.apply_cool_event_internal(
    p_user_id,
    p_event_type,
    p_points,
    p_source_id,
    p_metadata,
    p_referrer_id,
    p_dedupe_key,
    p_campaign_id,
    p_season_id
  );
end;
$$;


--
-- Name: apply_cool_event_internal(uuid, text, integer, text, jsonb, uuid, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_cool_event_internal(p_user_id uuid, p_event_type text, p_points integer DEFAULT 0, p_source_id text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb, p_referrer_id uuid DEFAULT NULL::uuid, p_dedupe_key text DEFAULT NULL::text, p_campaign_id text DEFAULT NULL::text, p_season_id uuid DEFAULT NULL::uuid) RETURNS public.cool_status
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_status public.cool_status;
  v_existing_event_id uuid;
  v_effective_season_id uuid;
begin
  insert into public.cool_status (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  if nullif(btrim(coalesce(p_dedupe_key, '')), '') is not null then
    select id
    into v_existing_event_id
    from public.cool_events
    where user_id = p_user_id
      and dedupe_key = p_dedupe_key
    limit 1;

    if v_existing_event_id is not null then
      select *
      into v_status
      from public.cool_status
      where user_id = p_user_id;

      return v_status;
    end if;
  end if;

  select active_season_id
  into v_effective_season_id
  from public.cool_status
  where user_id = p_user_id;

  v_effective_season_id := coalesce(p_season_id, v_effective_season_id);

  insert into public.cool_events (
    user_id,
    event_type,
    source_id,
    points_awarded,
    metadata,
    referrer_id,
    dedupe_key,
    campaign_id,
    season_id
  )
  values (
    p_user_id,
    p_event_type,
    p_source_id,
    coalesce(p_points, 0),
    coalesce(p_metadata, '{}'::jsonb),
    p_referrer_id,
    nullif(btrim(coalesce(p_dedupe_key, '')), ''),
    nullif(btrim(coalesce(p_campaign_id, '')), ''),
    v_effective_season_id
  );

  update public.cool_status
  set
    total_points = greatest(total_points + coalesce(p_points, 0), 0),
    season_points = case
      when v_effective_season_id is null then season_points
      when active_season_id is null or active_season_id = v_effective_season_id
        then greatest(season_points + coalesce(p_points, 0), 0)
      else season_points
    end,
    active_season_id = coalesce(v_effective_season_id, active_season_id),
    updated_at = now()
  where user_id = p_user_id
  returning *
  into v_status;

  if v_effective_season_id is not null then
    insert into public.season_memberships (
      season_id,
      user_id,
      season_points
    )
    values (
      v_effective_season_id,
      p_user_id,
      greatest(coalesce(p_points, 0), 0)
    )
    on conflict (season_id, user_id) do update
      set
        season_points = greatest(
          public.season_memberships.season_points + coalesce(p_points, 0),
          0
        ),
        updated_at = now();
  end if;

  return v_status;
end;
$$;


--
-- Name: assign_admin_role(uuid, text, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assign_admin_role(p_target_user_id uuid, p_role text, p_partner_scope_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_caller_id uuid;
  v_assignment_id uuid;
BEGIN
  v_caller_id := auth.uid();

  -- Only platform admins can assign roles
  IF NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = v_caller_id AND u.is_admin = true
  ) THEN
    RAISE EXCEPTION 'Only platform admins can assign admin roles.';
  END IF;

  -- Validate role
  IF p_role NOT IN ('admin', 'bank', 'rayon_sport') THEN
    RAISE EXCEPTION 'Invalid role: %. Must be admin, bank, or rayon_sport.', p_role;
  END IF;

  -- For admin role, partner_scope_id should be NULL
  -- For bank/rayon_sport, partner_scope_id should be provided
  IF p_role IN ('bank', 'rayon_sport') AND p_partner_scope_id IS NULL THEN
    RAISE EXCEPTION 'Partner scope is required for % role.', p_role;
  END IF;

  -- Upsert (reactivate if previously revoked)
  INSERT INTO public.admin_role_assignments (
    user_id, role, partner_scope_id, granted_by, granted_at, is_active, notes
  ) VALUES (
    p_target_user_id, p_role, p_partner_scope_id, v_caller_id, now(), true, p_notes
  )
  ON CONFLICT (user_id, role, partner_scope_id)
  DO UPDATE SET
    is_active = true,
    granted_by = v_caller_id,
    granted_at = now(),
    revoked_at = NULL,
    notes = COALESCE(p_notes, admin_role_assignments.notes)
  RETURNING id INTO v_assignment_id;

  RETURN jsonb_build_object(
    'status', 'assigned',
    'assignment_id', v_assignment_id,
    'role', p_role,
    'user_id', p_target_user_id,
    'partner_scope_id', p_partner_scope_id
  );
END;
$$;


--
-- Name: assign_public_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assign_public_user_id() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if coalesce(btrim(new.public_user_id), '') = '' then
    new.public_user_id := public.next_public_user_id();
  end if;

  return new;
end;
$$;


--
-- Name: award_cool_achievement(uuid, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.award_cool_achievement(p_user_id uuid, p_achievement_id text, p_points_value integer DEFAULT 0) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
    -- Only service_role or the user themselves can trigger this (usually service role via triggers)
    -- But for simplicity in this proto, we allow the user or admin.
    
    UPDATE public.cool_achievements
    SET 
        is_earned = true,
        earned_at = now(),
        points_value = p_points_value
    WHERE user_id = p_user_id 
      AND achievement_id = p_achievement_id
      AND is_earned = false;

    IF FOUND AND p_points_value > 0 THEN
        PERFORM public.apply_cool_event_internal(
            p_user_id,
            'achievementUnlocked',
            p_points_value,
            p_achievement_id,
            jsonb_build_object('achievement_id', p_achievement_id),
            NULL,
            'achievement:' || p_user_id || ':' || p_achievement_id,
            NULL,
            NULL
        );
    END IF;
END;
$$;


--
-- Name: bank_accept_suggested_allocation(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bank_accept_suggested_allocation(p_partner_id uuid, p_review_id uuid, p_note text DEFAULT NULL::text) RETURNS TABLE(review_id uuid, contribution_id uuid, group_id uuid, user_id uuid, matched_reference text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_metadata jsonb;
  v_suggested_group_id uuid;
  v_suggested_member_user_id uuid;
begin
  -- Get metadata from the reconciliation
  select mr.metadata
  into v_metadata
  from public.momo_reconciliations mr
  where mr.id = p_review_id;

  if not found then
    raise exception 'Review item not found.';
  end if;

  v_suggested_group_id := (v_metadata ->> 'suggested_group_id')::uuid;
  v_suggested_member_user_id := (v_metadata ->> 'suggested_member_user_id')::uuid;

  if v_suggested_group_id is null or v_suggested_member_user_id is null then
    raise exception 'No AI suggestion available for this review item.';
  end if;

  -- Delegate to existing allocation RPC
  return query
  select *
  from public.bank_allocate_manual_review_allocation(
    p_partner_id,
    p_review_id,
    v_suggested_group_id,
    v_suggested_member_user_id,
    coalesce(nullif(btrim(p_note), ''), 'Accepted AI suggestion.')
  );
end;
$$;


--
-- Name: bank_add_member_to_group(uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bank_add_member_to_group(p_partner_id uuid, p_group_id uuid, p_phone text, p_display_name text DEFAULT NULL::text) RETURNS TABLE(member_user_id uuid, display_name text, group_id uuid, is_new_member boolean)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
declare
  v_user_id uuid;
  v_user_name text;
  v_phone text;
  v_already_member boolean;
begin
  -- Validate inputs
  if p_partner_id is null then
    raise exception 'Partner id is required.';
  end if;

  if p_group_id is null then
    raise exception 'Group id is required.';
  end if;

  v_phone := btrim(coalesce(p_phone, ''));
  if v_phone = '' then
    raise exception 'Phone number is required.';
  end if;

  -- Normalize phone: ensure +250 prefix
  if v_phone ~ '^\d{9}$' then
    v_phone := '+250' || v_phone;
  elsif v_phone ~ '^0\d{9}$' then
    v_phone := '+25' || v_phone;
  elsif v_phone ~ '^250\d{9}$' then
    v_phone := '+' || v_phone;
  end if;

  -- Auth check
  if auth.uid() is null or not public.can_read_bank_custody(p_partner_id) then
    raise exception 'Not authorized to manage bank custody members.';
  end if;

  -- Verify group belongs to this partner
  if not public.group_belongs_to_bank_partner(p_group_id, p_partner_id) then
    raise exception 'The selected group does not belong to this bank workspace.';
  end if;

  -- Look up user by phone
  select u.id, coalesce(u.full_name, '')
  into v_user_id, v_user_name
  from public.users u
  where u.phone = v_phone;

  if v_user_id is null then
    raise exception 'No registered user found with phone %. The user must register in the app first.', v_phone;
  end if;

  -- Check if already a member
  select exists(
    select 1 from public.group_members gm
    where gm.group_id = p_group_id and gm.user_id = v_user_id
  ) into v_already_member;

  if v_already_member then
    -- Return existing member info
    return query
    select
      v_user_id,
      coalesce(nullif(btrim(p_display_name), ''), v_user_name, 'Member'),
      p_group_id,
      false;
    return;
  end if;

  -- Insert new member
  insert into public.group_members (
    group_id,
    user_id,
    display_name,
    is_admin,
    is_anonymous,
    contribution_amount,
    joined_at
  )
  values (
    p_group_id,
    v_user_id,
    coalesce(nullif(btrim(p_display_name), ''), v_user_name, 'Member'),
    false,
    false,
    0,
    now()
  );

  -- Update group member count
  update public.groups
  set member_count = member_count + 1, updated_at = now()
  where id = p_group_id;

  return query
  select
    v_user_id,
    coalesce(nullif(btrim(p_display_name), ''), v_user_name, 'Member'),
    p_group_id,
    true;
end;
$_$;


--
-- Name: bank_allocate_manual_review_allocation(uuid, uuid, uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bank_allocate_manual_review_allocation(p_partner_id uuid, p_review_id uuid, p_group_id uuid, p_member_user_id uuid, p_note text DEFAULT NULL::text) RETURNS TABLE(review_id uuid, contribution_id uuid, group_id uuid, user_id uuid, matched_reference text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_review public.momo_reconciliations%rowtype;
  v_amount integer;
  v_tx_datetime timestamptz;
  v_parsed_reference text;
  v_reference text;
  v_contribution_id uuid;
  v_existing_contribution_id uuid;
  v_note text;
  v_now timestamptz := now();
begin
  if p_partner_id is null then
    raise exception 'Partner id is required.';
  end if;

  if p_review_id is null then
    raise exception 'Review id is required.';
  end if;

  if p_group_id is null then
    raise exception 'Group id is required.';
  end if;

  if p_member_user_id is null then
    raise exception 'Member user id is required.';
  end if;

  if auth.uid() is null or not public.can_read_bank_custody(p_partner_id) then
    raise exception 'Not authorized to manage bank custody allocations.';
  end if;

  if not public.bank_manual_review_matches_partner(p_review_id, p_partner_id) then
    raise exception 'This review is not visible in the current bank workspace.';
  end if;

  if not public.group_belongs_to_bank_partner(p_group_id, p_partner_id) then
    raise exception 'The selected group is not linked to this bank workspace.';
  end if;

  if not exists (
    select 1
    from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = p_member_user_id
  ) then
    raise exception 'The selected member does not belong to the target group.';
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
    coalesce(parsed.tx_datetime, parsed.created_at),
    nullif(parsed.momo_tx_id, '')
  into
    v_amount,
    v_tx_datetime,
    v_parsed_reference
  from public.momo_sms_parsed parsed
  where parsed.id = v_review.parsed_sms_id;

  if coalesce(v_amount, 0) <= 0 then
    raise exception 'The reviewed payment does not have a usable amount.';
  end if;

  v_reference := coalesce(
    nullif(v_review.metadata ->> 'matched_reference', ''),
    v_parsed_reference,
    format('MR-%s', v_review.id)
  );

  select gc.id
  into v_existing_contribution_id
  from public.group_contributions gc
  where gc.group_id = p_group_id
    and gc.user_id = p_member_user_id
    and (
      gc.momo_reference = v_reference
      or (
        gc.amount = v_amount
        and gc.status in ('pending', 'confirmed')
      )
    )
  order by
    case when gc.momo_reference = v_reference then 0 else 1 end,
    gc.created_at desc
  limit 1;

  if v_existing_contribution_id is null then
    insert into public.group_contributions (
      group_id,
      user_id,
      amount,
      status,
      momo_reference,
      created_at
    )
    values (
      p_group_id,
      p_member_user_id,
      v_amount,
      'confirmed',
      v_reference,
      coalesce(v_tx_datetime, v_review.created_at, v_now)
    )
    returning id
    into v_contribution_id;
  else
    update public.group_contributions
    set
      amount = v_amount,
      status = 'confirmed',
      momo_reference = coalesce(momo_reference, v_reference)
    where id = v_existing_contribution_id
    returning id
    into v_contribution_id;
  end if;

  v_note := coalesce(
    nullif(btrim(p_note), ''),
    'Bank admin manually allocated this payment.'
  );

  update public.momo_reconciliations
  set
    target_table = 'group_contributions',
    target_record_id = v_contribution_id,
    match_type = 'bank_manual_group_allocation',
    match_status = 'matched',
    notes = v_note,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'manual_allocation', true,
      'group_id', p_group_id,
      'allocated_user_id', p_member_user_id,
      'matched_reference', v_reference,
      'allocation_actor_id', auth.uid(),
      'allocation_source', 'bank_admin'
    ),
    reconciled_at = v_now,
    updated_at = v_now
  where id = v_review.id;

  update public.momo_ledger_entries
  set
    target_table = 'group_contributions',
    target_record_id = v_contribution_id,
    payee_group_id = p_group_id,
    ledger_scope = 'savings',
    ledger_status = 'posted',
    external_reference = coalesce(external_reference, v_reference),
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'manual_allocation', true,
      'group_id', p_group_id,
      'allocated_user_id', p_member_user_id,
      'matched_reference', v_reference,
      'allocation_actor_id', auth.uid(),
      'allocation_source', 'bank_admin'
    ),
    updated_at = v_now
  where parsed_sms_id = v_review.parsed_sms_id;

  return query
  select
    v_review.id,
    v_contribution_id,
    p_group_id,
    p_member_user_id,
    v_reference;
end;
$$;


--
-- Name: bank_is_partner_admin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bank_is_partner_admin(p_partner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select
    coalesce(auth.jwt() -> 'app_metadata' ->> 'is_bank_admin', 'false') = 'true'
    or coalesce(
      (auth.jwt() -> 'app_metadata' -> 'bank_admin_ids') ? p_partner_id::text,
      false
    );
$$;


--
-- Name: bank_manual_review_matches_partner(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bank_manual_review_matches_partner(p_review_id uuid, p_partner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
  with candidate_groups as (
    select distinct scoped.group_id
    from (
      select gc.group_id
      from public.momo_reconciliations mr
      left join public.group_contributions gc
        on mr.target_table = 'group_contributions'
        and mr.target_record_id = gc.id
      where mr.id = p_review_id

      union all

      select nullif(mr.metadata ->> 'group_id', '')::uuid
      from public.momo_reconciliations mr
      where mr.id = p_review_id
        and nullif(mr.metadata ->> 'group_id', '') is not null

      union all

      select candidate_id::uuid
      from public.momo_reconciliations mr,
        jsonb_array_elements_text(
          coalesce(mr.metadata -> 'matching_group_ids', '[]'::jsonb)
        ) candidate(candidate_id)
      where mr.id = p_review_id
        and candidate_id ~* '^[0-9a-f-]{36}$'
    ) scoped
    where scoped.group_id is not null
  )
  select exists (
    select 1
    from candidate_groups cg
    where public.group_belongs_to_bank_partner(cg.group_id, p_partner_id)
  );
$_$;


--
-- Name: bank_reject_manual_review_allocation(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bank_reject_manual_review_allocation(p_partner_id uuid, p_review_id uuid, p_note text DEFAULT NULL::text) RETURNS TABLE(review_id uuid, match_status text)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_review public.momo_reconciliations%rowtype;
  v_note text;
  v_now timestamptz := now();
begin
  if p_partner_id is null then
    raise exception 'Partner id is required.';
  end if;

  if p_review_id is null then
    raise exception 'Review id is required.';
  end if;

  if auth.uid() is null or not public.can_read_bank_custody(p_partner_id) then
    raise exception 'Not authorized to manage bank custody allocations.';
  end if;

  if not public.bank_manual_review_matches_partner(p_review_id, p_partner_id) then
    raise exception 'This review is not visible in the current bank workspace.';
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
    raise exception 'Only pending or manual-review allocations can be rejected.';
  end if;

  v_note := coalesce(
    nullif(btrim(p_note), ''),
    'Bank admin rejected this payment allocation.'
  );

  update public.momo_reconciliations
  set
    target_table = null,
    target_record_id = null,
    match_type = 'bank_manual_rejection',
    match_status = 'rejected',
    notes = v_note,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'manual_rejection', true,
      'allocation_actor_id', auth.uid(),
      'allocation_source', 'bank_admin',
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
      'allocation_actor_id', auth.uid(),
      'allocation_source', 'bank_admin',
      'rejected_at', v_now
    ),
    updated_at = v_now
  where parsed_sms_id = v_review.parsed_sms_id;

  return query
  select v_review.id, 'rejected'::text;
end;
$$;


--
-- Name: biopay_array_to_vector(double precision[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.biopay_array_to_vector(p_embedding double precision[]) RETURNS extensions.vector
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO 'public', 'extensions'
    AS $$
BEGIN
  IF coalesce(array_length(p_embedding, 1), 0) != 192 THEN
    RAISE EXCEPTION 'BioPay embedding must contain exactly 192 values.';
  END IF;
  RETURN ('[' || array_to_string(p_embedding, ',') || ']')::vector(192);
END;
$$;


--
-- Name: biopay_array_to_vector_192(double precision[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.biopay_array_to_vector_192(p_embedding double precision[]) RETURNS extensions.vector
    LANGUAGE plpgsql IMMUTABLE
    SET search_path TO 'public', 'extensions'
    AS $$
begin
  if coalesce(array_length(p_embedding, 1), 0) != 192 then
    raise exception 'BioPay embedding must contain exactly 192 values.';
  end if;

  return ('[' || array_to_string(p_embedding, ',') || ']')::vector(192);
end;
$$;


--
-- Name: biopay_revoke_profile(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.biopay_revoke_profile(p_reason text DEFAULT NULL::text) RETURNS TABLE(profile_id uuid, public_id text, revoked_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile public.biopay_profiles%rowtype;
  v_revoked_at timestamptz := timezone('utc', now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  SELECT * INTO v_profile
  FROM public.biopay_profiles
  WHERE user_id = v_user_id AND active = true AND deleted_at IS NULL
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No active BioPay enrollment was found.';
  END IF;

  UPDATE public.biopay_profiles SET
    active = false, revoked_at = v_revoked_at
  WHERE id = v_profile.id
  RETURNING * INTO v_profile;

  UPDATE public.biopay_embeddings SET
    active = false, retired_at = v_revoked_at
  WHERE profile_id = v_profile.id AND active = true;

  INSERT INTO public.biopay_revocations (profile_id, user_id, reason, metadata)
  VALUES (v_profile.id, v_user_id,
    nullif(trim(coalesce(p_reason, '')), ''),
    jsonb_build_object('public_id', v_profile.public_id));

  INSERT INTO public.biopay_enrollment_audits (profile_id, user_id, event_type, metadata)
  VALUES (v_profile.id, v_user_id, 'revoked', jsonb_build_object(
    'reason', nullif(trim(coalesce(p_reason, '')), ''),
    'public_id', v_profile.public_id
  ));

  RETURN QUERY SELECT v_profile.id, v_profile.public_id, v_revoked_at;
END;
$$;


--
-- Name: biopay_revoke_profile_server(uuid, bigint, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.biopay_revoke_profile_server(p_requester_user_id uuid, p_club_id bigint, p_reason text DEFAULT NULL::text) RETURNS TABLE(profile_id uuid, public_id text, revoked_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_user_id uuid := p_requester_user_id;
  v_profile public.biopay_profiles%rowtype;
  v_revoked_at timestamptz := timezone('utc', now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF p_club_id IS NULL THEN
    RAISE EXCEPTION 'Club context required.';
  END IF;

  SELECT * INTO v_profile
  FROM public.biopay_profiles
  WHERE user_id = v_user_id
    AND club_id = p_club_id
    AND active = true
    AND deleted_at IS NULL
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No active BioPay enrollment was found.';
  END IF;

  UPDATE public.biopay_profiles SET
    active = false, revoked_at = v_revoked_at
  WHERE id = v_profile.id
  RETURNING * INTO v_profile;

  UPDATE public.biopay_embeddings SET
    active = false, retired_at = v_revoked_at
  WHERE profile_id = v_profile.id
    AND club_id = p_club_id
    AND active = true;

  INSERT INTO public.biopay_revocations (profile_id, user_id, club_id, reason, metadata)
  VALUES (
    v_profile.id,
    v_user_id,
    p_club_id,
    nullif(trim(coalesce(p_reason, '')), ''),
    jsonb_build_object('public_id', v_profile.public_id, 'origin', 'edge')
  );

  INSERT INTO public.biopay_enrollment_audits (profile_id, user_id, club_id, event_type, metadata)
  VALUES (v_profile.id, v_user_id, p_club_id, 'revoked', jsonb_build_object(
    'reason', nullif(trim(coalesce(p_reason, '')), ''),
    'public_id', v_profile.public_id,
    'origin', 'edge'
  ));

  RETURN QUERY SELECT v_profile.id, v_profile.public_id, v_revoked_at;
END;
$$;


--
-- Name: biopay_upsert_enrollment(text, text, text, text, text, double precision[], text, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.biopay_upsert_enrollment(p_display_name text DEFAULT NULL::text, p_route_type text DEFAULT NULL::text, p_recipient_value text DEFAULT NULL::text, p_country_code text DEFAULT 'RW'::text, p_consent_version text DEFAULT 'biopay-v1'::text, p_embedding double precision[] DEFAULT NULL::double precision[], p_model_version text DEFAULT 'mobilefacenet_int8_v1'::text, p_quality_score double precision DEFAULT NULL::double precision) RETURNS TABLE(id uuid, public_id text, user_id uuid, club_id bigint, display_name text, route_type text, recipient_value text, country_code text, active boolean, consent_version text, consent_at timestamp with time zone, created_at timestamp with time zone, updated_at timestamp with time zone, revoked_at timestamp with time zone, enrolled_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_club_id bigint;
  v_profile public.biopay_profiles%rowtype;
  v_embedding extensions.vector(192);
  v_display_name text;
  v_route_type text;
  v_recipient_value text;
  v_country_code text;
  v_consent_version text;
  v_enrolled_at timestamptz := timezone('utc', now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Derive club_id from JWT claims
  v_club_id := NULLIF(
    COALESCE(
      current_setting('request.jwt.claims', true)::jsonb ->> 'club_id',
      current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'club_id'
    ), ''
  )::bigint;

  IF v_club_id IS NULL THEN
    RAISE EXCEPTION 'Club context required. Ensure club_id is set in JWT claims.';
  END IF;

  IF p_embedding IS NULL THEN
    RAISE EXCEPTION 'Embedding is required for BioPay enrollment.';
  END IF;

  v_display_name := nullif(trim(coalesce(p_display_name, '')), '');
  IF v_display_name IS NULL THEN
    RAISE EXCEPTION 'Display name is required.';
  END IF;

  v_route_type := lower(trim(coalesce(nullif(p_route_type, ''), '')));
  IF v_route_type NOT IN ('phone_number', 'code') THEN
    RAISE EXCEPTION 'A valid payment route type (phone_number or code) is required.';
  END IF;

  v_recipient_value := trim(coalesce(nullif(p_recipient_value, ''), ''));
  IF v_recipient_value = '' THEN
    RAISE EXCEPTION 'A valid payout recipient is required.';
  END IF;

  v_country_code := upper(trim(coalesce(nullif(p_country_code, ''), 'RW')));
  v_consent_version := coalesce(nullif(trim(p_consent_version), ''), 'biopay-v1');
  v_embedding := public.biopay_array_to_vector(p_embedding);

  -- Upsert profile (scoped to club_id)
  SELECT * INTO v_profile
  FROM public.biopay_profiles
  WHERE biopay_profiles.user_id = v_user_id
    AND biopay_profiles.club_id = v_club_id
    AND deleted_at IS NULL
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.biopay_profiles SET
      display_name = v_display_name,
      route_type = v_route_type,
      recipient_value = v_recipient_value,
      country_code = v_country_code,
      active = true,
      consent_version = v_consent_version,
      consent_at = timezone('utc', now()),
      revoked_at = NULL,
      deleted_at = NULL
    WHERE biopay_profiles.id = v_profile.id
    RETURNING * INTO v_profile;
  ELSE
    INSERT INTO public.biopay_profiles (
      user_id, club_id, display_name, route_type, recipient_value,
      country_code, active, consent_version, consent_at
    ) VALUES (
      v_user_id, v_club_id, v_display_name, v_route_type, v_recipient_value,
      v_country_code, true, v_consent_version, timezone('utc', now())
    ) RETURNING * INTO v_profile;
  END IF;

  -- Retire old embeddings for this club
  UPDATE public.biopay_embeddings SET
    active = false, retired_at = timezone('utc', now())
  WHERE biopay_embeddings.profile_id = v_profile.id
    AND biopay_embeddings.club_id = v_club_id
    AND biopay_embeddings.active = true;

  -- Insert new embedding
  INSERT INTO public.biopay_embeddings (
    profile_id, club_id, embedding, model_version, quality_score, active, enrolled_at
  ) VALUES (
    v_profile.id, v_club_id, v_embedding,
    coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1'),
    p_quality_score, true, v_enrolled_at
  );

  -- Audit trail
  INSERT INTO public.biopay_enrollment_audits (profile_id, user_id, club_id, event_type, metadata)
  VALUES (v_profile.id, v_user_id, v_club_id, 'enrolled', jsonb_build_object(
    'route_type', v_route_type,
    'country_code', v_country_code,
    'model_version', coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1')
  ));

  RETURN QUERY SELECT
    v_profile.id, v_profile.public_id, v_profile.user_id,
    v_profile.club_id,
    v_profile.display_name, v_profile.route_type, v_profile.recipient_value,
    v_profile.country_code, v_profile.active, v_profile.consent_version,
    v_profile.consent_at, v_profile.created_at, v_profile.updated_at,
    v_profile.revoked_at, v_enrolled_at;
END;
$$;


--
-- Name: biopay_upsert_enrollment_server(uuid, bigint, text, text, text, text, text, double precision[], text, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.biopay_upsert_enrollment_server(p_requester_user_id uuid, p_club_id bigint, p_display_name text DEFAULT NULL::text, p_route_type text DEFAULT NULL::text, p_recipient_value text DEFAULT NULL::text, p_country_code text DEFAULT 'RW'::text, p_consent_version text DEFAULT 'biopay-v1'::text, p_embedding double precision[] DEFAULT NULL::double precision[], p_model_version text DEFAULT 'mobilefacenet_int8_v1'::text, p_quality_score double precision DEFAULT NULL::double precision) RETURNS TABLE(id uuid, public_id text, user_id uuid, club_id bigint, display_name text, route_type text, recipient_value text, country_code text, active boolean, consent_version text, consent_at timestamp with time zone, created_at timestamp with time zone, updated_at timestamp with time zone, revoked_at timestamp with time zone, enrolled_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_user_id uuid := p_requester_user_id;
  v_profile public.biopay_profiles%rowtype;
  v_embedding extensions.vector(192);
  v_display_name text;
  v_route_type text;
  v_recipient_value text;
  v_country_code text;
  v_consent_version text;
  v_enrolled_at timestamptz := timezone('utc', now());
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF p_club_id IS NULL THEN
    RAISE EXCEPTION 'Club context required.';
  END IF;

  IF p_embedding IS NULL THEN
    RAISE EXCEPTION 'Embedding is required for BioPay enrollment.';
  END IF;

  v_display_name := nullif(trim(coalesce(p_display_name, '')), '');
  IF v_display_name IS NULL THEN
    RAISE EXCEPTION 'Display name is required.';
  END IF;

  v_route_type := lower(trim(coalesce(nullif(p_route_type, ''), '')));
  IF v_route_type NOT IN ('phone_number', 'code') THEN
    RAISE EXCEPTION 'A valid payment route type (phone_number or code) is required.';
  END IF;

  v_recipient_value := trim(coalesce(nullif(p_recipient_value, ''), ''));
  IF v_recipient_value = '' THEN
    RAISE EXCEPTION 'A valid payout recipient is required.';
  END IF;

  v_country_code := upper(trim(coalesce(nullif(p_country_code, ''), 'RW')));
  v_consent_version := coalesce(nullif(trim(p_consent_version), ''), 'biopay-v1');
  v_embedding := public.biopay_array_to_vector(p_embedding);

  SELECT * INTO v_profile
  FROM public.biopay_profiles
  WHERE biopay_profiles.user_id = v_user_id
    AND biopay_profiles.club_id = p_club_id
    AND deleted_at IS NULL
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.biopay_profiles SET
      display_name = v_display_name,
      route_type = v_route_type,
      recipient_value = v_recipient_value,
      country_code = v_country_code,
      active = true,
      consent_version = v_consent_version,
      consent_at = timezone('utc', now()),
      revoked_at = NULL,
      deleted_at = NULL
    WHERE biopay_profiles.id = v_profile.id
    RETURNING * INTO v_profile;
  ELSE
    INSERT INTO public.biopay_profiles (
      user_id, club_id, display_name, route_type, recipient_value,
      country_code, active, consent_version, consent_at
    ) VALUES (
      v_user_id, p_club_id, v_display_name, v_route_type, v_recipient_value,
      v_country_code, true, v_consent_version, timezone('utc', now())
    ) RETURNING * INTO v_profile;
  END IF;

  UPDATE public.biopay_embeddings SET
    active = false, retired_at = timezone('utc', now())
  WHERE biopay_embeddings.profile_id = v_profile.id
    AND biopay_embeddings.club_id = p_club_id
    AND biopay_embeddings.active = true;

  INSERT INTO public.biopay_embeddings (
    profile_id, club_id, embedding, model_version, quality_score, active, enrolled_at
  ) VALUES (
    v_profile.id, p_club_id, v_embedding,
    coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1'),
    p_quality_score, true, v_enrolled_at
  );

  INSERT INTO public.biopay_enrollment_audits (profile_id, user_id, club_id, event_type, metadata)
  VALUES (v_profile.id, v_user_id, p_club_id, 'enrolled', jsonb_build_object(
    'route_type', v_route_type,
    'country_code', v_country_code,
    'model_version', coalesce(nullif(trim(p_model_version), ''), 'mobilefacenet_int8_v1'),
    'origin', 'edge'
  ));

  RETURN QUERY SELECT
    v_profile.id, v_profile.public_id, v_profile.user_id,
    v_profile.club_id,
    v_profile.display_name, v_profile.route_type, v_profile.recipient_value,
    v_profile.country_code, v_profile.active, v_profile.consent_version,
    v_profile.consent_at, v_profile.created_at, v_profile.updated_at,
    v_profile.revoked_at, v_enrolled_at;
END;
$$;


--
-- Name: biopay_vector_128_to_192(extensions.vector); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.biopay_vector_128_to_192(p_embedding extensions.vector) RETURNS extensions.vector
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public', 'extensions'
    AS $$
  select (
    '[' ||
    trim(both '[]' from p_embedding::text) ||
    repeat(',0', 64) ||
    ']'
  )::vector(192);
$$;


--
-- Name: bulk_refund_rs_tickets(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bulk_refund_rs_tickets(p_ticket_ids uuid[]) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_role_assignments ara
    WHERE ara.user_id = auth.uid()
      AND ara.is_active = true
      AND (ara.role = 'admin' OR ara.role = 'rayon_sport')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Requires admin or rayon_sport role';
  END IF;

  UPDATE public.rs_tickets
  SET status = 'refunded', updated_at = now()
  WHERE id = ANY(p_ticket_ids)
    AND status NOT IN ('voided','refunded');

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


--
-- Name: bulk_void_rs_tickets(uuid[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bulk_void_rs_tickets(p_ticket_ids uuid[]) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_count int;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_role_assignments ara
    WHERE ara.user_id = auth.uid()
      AND ara.is_active = true
      AND (ara.role = 'admin' OR ara.role = 'rayon_sport')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Requires admin or rayon_sport role';
  END IF;

  UPDATE public.rs_tickets
  SET status = 'voided', updated_at = now()
  WHERE id = ANY(p_ticket_ids)
    AND status != 'voided';

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


--
-- Name: can_export_group_payment_ledger(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_export_group_payment_ledger(p_group_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    public.can_manage_group_settings(p_group_id)
    or exists (
      select 1
      from public.partners p
      where public.bank_is_partner_admin(p.id)
        and public.group_belongs_to_bank_partner(p_group_id, p.id)
    );
$$;


--
-- Name: can_manage_group_settings(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_manage_group_settings(p_group_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    public.is_admin_user()
    or exists (
      select 1
      from public.groups g
      where g.id = p_group_id
        and g.creator_id = auth.uid()
    )
    or exists (
      select 1
      from public.group_members gm
      where gm.group_id = p_group_id
        and gm.user_id = auth.uid()
        and gm.is_admin = true
    );
$$;


--
-- Name: can_read_bank_custody(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_read_bank_custody(p_partner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    public.is_admin_user()
    or public.bank_is_partner_admin(p_partner_id);
$$;


--
-- Name: can_read_group_payment_ledger(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_read_group_payment_ledger(p_group_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    public.is_admin_user()
    or exists (
      select 1
      from public.groups g
      where g.id = p_group_id
        and g.creator_id = auth.uid()
    )
    or exists (
      select 1
      from public.group_members gm
      where gm.group_id = p_group_id
        and gm.user_id = auth.uid()
        and gm.is_admin = true
    )
    or exists (
      select 1
      from public.partners p
      where public.bank_is_partner_admin(p.id)
        and public.group_belongs_to_bank_partner(p_group_id, p.id)
    );
$$;


--
-- Name: can_read_partner_payment_ledger(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_read_partner_payment_ledger(p_partner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    public.is_admin_user()
    or public.rs_is_partner_admin(p_partner_id);
$$;


--
-- Name: can_view_group_transaction_feed(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.can_view_group_transaction_feed(p_group_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    public.is_admin_user()
    or exists (
      select 1
      from public.groups g
      where g.id = p_group_id
        and g.creator_id = auth.uid()
    )
    or public.is_group_member(p_group_id)
    or exists (
      select 1
      from public.partners p
      where public.bank_is_partner_admin(p.id)
        and public.group_belongs_to_bank_partner(p_group_id, p.id)
    );
$$;


--
-- Name: cleanup_stale_fcm_tokens(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_stale_fcm_tokens() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.user_fcm_tokens
  WHERE updated_at < now() - INTERVAL '60 days';

  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;


--
-- Name: compat_parse_partner_id(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.compat_parse_partner_id(p_partner_id text) RETURNS bigint
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT NULLIF(regexp_replace(trim(coalesce(p_partner_id, '')), '[^0-9]', '', 'g'), '')::bigint
$$;


--
-- Name: confirm_contribution(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_contribution(p_contribution_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_contribution record;
begin
  select id, group_id, amount, status
    into v_contribution
    from public.group_contributions
   where id = p_contribution_id
   for update;

  if v_contribution is null then
    return jsonb_build_object('status', 'error', 'message', 'Contribution not found.');
  end if;

  if v_contribution.status in ('confirmed', 'completed') then
    return jsonb_build_object('status', 'already_confirmed');
  end if;

  if v_contribution.status <> 'pending' then
    return jsonb_build_object(
      'status', 'error',
      'message', format('Cannot confirm contribution with status: %s', v_contribution.status)
    );
  end if;

  update public.group_contributions
     set status = 'confirmed',
         updated_at = now()
   where id = p_contribution_id;

  update public.groups
     set amount = coalesce(amount, 0) + v_contribution.amount,
         updated_at = now()
   where id = v_contribution.group_id;

  return jsonb_build_object('status', 'success', 'amount', v_contribution.amount);
end;
$$;


--
-- Name: FUNCTION confirm_contribution(p_contribution_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.confirm_contribution(p_contribution_id uuid) IS 'Idempotent: moves a pending contribution to confirmed and updates the group balance.';


--
-- Name: consume_request_rate_limit(text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.consume_request_rate_limit(p_bucket_key text, p_limit integer, p_window_ms integer) RETURNS TABLE(allowed boolean, retry_after_seconds integer, remaining integer, reset_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  now_ts timestamptz := timezone('utc', now());
  window_interval interval := (GREATEST(p_window_ms, 1)::text || ' milliseconds')::interval;
  current_count integer;
  current_reset_at timestamptz;
BEGIN
  IF p_bucket_key IS NULL OR btrim(p_bucket_key) = '' THEN
    RAISE EXCEPTION 'p_bucket_key is required';
  END IF;

  IF p_limit <= 0 THEN
    RAISE EXCEPTION 'p_limit must be positive';
  END IF;

  LOOP
    UPDATE public.request_rate_limits
    SET
      count = CASE
        WHEN request_rate_limits.reset_at <= now_ts THEN 1
        ELSE request_rate_limits.count + 1
      END,
      reset_at = CASE
        WHEN request_rate_limits.reset_at <= now_ts THEN now_ts + window_interval
        ELSE request_rate_limits.reset_at
      END,
      updated_at = now_ts
    WHERE request_rate_limits.bucket_key = p_bucket_key
    RETURNING request_rate_limits.count, request_rate_limits.reset_at
      INTO current_count, current_reset_at;

    EXIT WHEN FOUND;

    BEGIN
      INSERT INTO public.request_rate_limits (
        bucket_key,
        count,
        reset_at,
        created_at,
        updated_at
      )
      VALUES (
        p_bucket_key,
        1,
        now_ts + window_interval,
        now_ts,
        now_ts
      )
      RETURNING request_rate_limits.count, request_rate_limits.reset_at
        INTO current_count, current_reset_at;

      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        NULL;
    END;
  END LOOP;

  RETURN QUERY
  SELECT
    current_count <= p_limit,
    CASE
      WHEN current_count > p_limit THEN GREATEST(1, CEIL(EXTRACT(EPOCH FROM current_reset_at - now_ts))::integer)
      ELSE 0
    END,
    GREATEST(p_limit - LEAST(current_count, p_limit), 0),
    current_reset_at;
END;
$$;


--
-- Name: cool_status_tier_for_points(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cool_status_tier_for_points(p_points integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select case
    when greatest(coalesce(p_points, 0), 0) >= 5000 then 'platinum'
    when greatest(coalesce(p_points, 0), 0) >= 2000 then 'gold'
    when greatest(coalesce(p_points, 0), 0) >= 1000 then 'silver'
    else 'blue'
  end;
$$;


--
-- Name: create_biopay_enrollment(text, text, uuid, timestamp with time zone, extensions.vector); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_biopay_enrollment(p_display_name text, p_ussd_string text, p_supabase_uid uuid, p_consent_ts timestamp with time zone, p_embedding extensions.vector) RETURNS TABLE(biopay_id text, enrolled_at timestamp with time zone)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
declare
  v_payee_id uuid;
  v_biopay_id text;
  v_enrolled_at timestamptz;
begin
  for attempt in 1..10 loop
    v_biopay_id := public.generate_biopay_id();
    begin
      insert into public.biopay_payees (biopay_id, display_name, ussd_string, supabase_uid, consent_ts)
      values (v_biopay_id, p_display_name, p_ussd_string, p_supabase_uid, p_consent_ts)
      returning id, public.biopay_payees.biopay_id, public.biopay_payees.enrolled_at
      into v_payee_id, biopay_id, v_enrolled_at;

      insert into public.biopay_embeddings (payee_id, embedding)
      values (v_payee_id, p_embedding);

      enrolled_at := v_enrolled_at;
      return next;
      return;
    exception
      when unique_violation then
        if sqlerrm like '%biopay_payees_biopay_id_key%' then
          continue;
        end if;
        raise;
    end;
  end loop;

  raise exception 'Unable to allocate a unique BioPay ID after multiple attempts' using errcode = '23505';
end;
$$;


--
-- Name: create_group_atomic(text, text, text, text, text, bigint, bigint, integer, text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_group_atomic(p_name text, p_visibility text DEFAULT 'private'::text, p_type text DEFAULT 'saving'::text, p_description text DEFAULT NULL::text, p_country text DEFAULT 'RW'::text, p_target_amount bigint DEFAULT 0, p_monthly_contribution bigint DEFAULT NULL::bigint, p_cycle_days integer DEFAULT 30, p_momo_number text DEFAULT NULL::text, p_receiving_momo_code text DEFAULT NULL::text, p_receiving_momo_route_type text DEFAULT NULL::text, p_bank_partner_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id     uuid := auth.uid();
  v_group_id    uuid;
  v_invite_code text;
BEGIN
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('status', 'error', 'message', 'Not authenticated.');
  END IF;

  -- Generate a 6-char invite code
  v_invite_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));

  INSERT INTO public.groups (
    creator_id,
    name,
    visibility,
    type,
    description,
    country,
    target_amount,
    monthly_contribution,
    cycle_days,
    momo_number,
    receiving_momo_code,
    receiving_momo_route_type,
    bank_partner_id,
    invite_code,
    amount,
    created_at,
    updated_at
  ) VALUES (
    v_user_id,
    btrim(p_name),
    lower(btrim(coalesce(p_visibility, 'private'))),
    lower(btrim(coalesce(p_type, 'saving'))),
    nullif(btrim(coalesce(p_description, '')), ''),
    upper(btrim(coalesce(p_country, 'RW'))),
    coalesce(p_target_amount, 0),
    p_monthly_contribution,
    coalesce(p_cycle_days, 30),
    nullif(btrim(coalesce(p_momo_number, '')), ''),
    nullif(btrim(coalesce(p_receiving_momo_code, '')), ''),
    nullif(btrim(coalesce(p_receiving_momo_route_type, '')), ''),
    p_bank_partner_id,
    v_invite_code,
    0,
    now(),
    now()
  )
  RETURNING id INTO v_group_id;

  -- Auto-add creator as admin member
  INSERT INTO public.group_members (
    group_id,
    user_id,
    display_name,
    is_admin,
    joined_at
  ) VALUES (
    v_group_id,
    v_user_id,
    (SELECT coalesce(
       nullif(btrim(display_name), ''),
       nullif(btrim(phone), ''),
       v_user_id::text
     ) FROM public.users WHERE id = v_user_id),
    true,
    now()
  );

  RETURN jsonb_build_object('status', 'success', 'group_id', v_group_id);
END;
$$;


--
-- Name: create_group_atomic(text, text, text, text, text, integer, integer, integer, text, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_group_atomic(p_name text, p_visibility text, p_type text, p_description text DEFAULT NULL::text, p_country text DEFAULT NULL::text, p_target_amount integer DEFAULT 0, p_monthly_contribution integer DEFAULT NULL::integer, p_cycle_days integer DEFAULT 30, p_bank_partner text DEFAULT NULL::text, p_institution_id text DEFAULT NULL::text, p_momo_number text DEFAULT NULL::text, p_receiving_momo_code text DEFAULT NULL::text, p_receiving_momo_route_type text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ declare v_user public.users; v_group public.groups; v_invite_code text; begin p_country := nullif(btrim(coalesce(p_country, '')), '' ); if auth.uid() is null then raise exception 'Authentication is required.'; end if; select * into v_user from public.users where id = auth.uid(); if v_user.id is null then raise exception 'Complete profile before creating a group.'; end if; v_invite_code := public.generate_group_invite_code(); insert into public.groups (creator_id, name, description, country, visibility, type, amount, target_amount, monthly_contribution, contribution_amount, cycle_days, frequency, bank_partner, institution_id, momo_number, receiving_momo_code, receiving_momo_route_type, invite_code) values (auth.uid(), nullif(btrim(p_name), '' ), nullif(btrim(coalesce(p_description, '' )), '' ), 'RW', coalesce(nullif(btrim(coalesce(p_visibility, '' )), '' ), 'private'), coalesce(nullif(btrim(coalesce(p_type, '' )), '' ), 'saving'), 0, coalesce(p_target_amount, 0), p_monthly_contribution, coalesce(p_monthly_contribution, p_target_amount, 0), greatest(coalesce(p_cycle_days, 30), 1), coalesce(nullif(btrim(case when p_cycle_days <= 1 then 'daily' when p_cycle_days <= 7 then 'weekly' else 'monthly' end), '' ), 'monthly'), nullif(btrim(coalesce(p_bank_partner, '' )), '' ), nullif(btrim(coalesce(p_institution_id, '' )), '' ), nullif(btrim(coalesce(p_momo_number, '' )), '' ), nullif(btrim(coalesce(p_receiving_momo_code, '' )), '' ), nullif(btrim(coalesce(p_receiving_momo_route_type, '' )), '' ), v_invite_code) returning * into v_group; insert into public.group_members (group_id, user_id, display_name, is_admin, is_anonymous, contribution_amount, joined_at) values (v_group.id, auth.uid(), coalesce(nullif(btrim(v_user.public_user_id), '' ), '000000'), true, false, 0, now()) on conflict (group_id, user_id) do update set is_admin = true, display_name = excluded.display_name; return jsonb_build_object('status', 'success', 'group_id', v_group.id, 'invite_code', v_invite_code); exception when others then return jsonb_build_object('status', 'error', 'message', sqlerrm); end; $$;


--
-- Name: custom_access_token_hook(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.custom_access_token_hook(event jsonb) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
DECLARE
  claims                jsonb;
  app_meta              jsonb;
  user_meta             jsonb;
  v_raw_club_id         text;
  v_normalized_club_id  text;
  v_user_role           text;
BEGIN
  claims := event -> 'claims';
  app_meta := claims -> 'app_metadata';
  user_meta := claims -> 'user_metadata';

  v_raw_club_id := COALESCE(
    app_meta ->> 'club_id',
    user_meta ->> 'club_id',
    ''
  );
  v_normalized_club_id := COALESCE(
    public.normalize_club_id(NULLIF(v_raw_club_id, ''))::text,
    v_raw_club_id
  );
  v_user_role := COALESCE(app_meta ->> 'role', 'fan');

  claims := jsonb_set(claims, '{club_id}', to_jsonb(v_normalized_club_id));
  claims := jsonb_set(claims, '{role}', to_jsonb(v_user_role));
  event := jsonb_set(event, '{claims}', claims);
  RETURN event;
END;
$$;


--
-- Name: derive_momo_cashflow_bucket(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.derive_momo_cashflow_bucket(p_tx_category text, p_tx_direction text) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select case
    when lower(coalesce(p_tx_category, '')) in ('salary', 'cash_in', 'transfer_in', 'loan_disbursement') then 'income'
    when lower(coalesce(p_tx_category, '')) in ('group_contribution', 'savings') then 'savings'
    when lower(coalesce(p_tx_category, '')) in ('loan', 'loan_repayment') then 'loan'
    when lower(coalesce(p_tx_category, '')) in ('fees', 'charge') then 'fees'
    when lower(coalesce(p_tx_category, '')) in ('transfer_in', 'transfer_out', 'transfer', 'bank_transfer') then 'transfer'
    when lower(coalesce(p_tx_category, '')) in ('merchant_payment', 'cash_out', 'airtime', 'subscription') then 'expense'
    when lower(coalesce(p_tx_direction, '')) = 'credit' then 'income'
    when lower(coalesce(p_tx_direction, '')) = 'debit' then 'expense'
    else 'unknown'
  end;
$$;


--
-- Name: derive_momo_tx_category(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.derive_momo_tx_category(p_tx_type text, p_tx_direction text, p_target_table text DEFAULT NULL::text) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select case
    when lower(coalesce(p_target_table, '')) = 'group_contributions' then 'group_contribution'
    when lower(coalesce(p_target_table, '')) = 'driver_subscriptions' then 'subscription'
    when lower(coalesce(p_tx_type, '')) in ('salary', 'payroll') then 'salary'
    when lower(coalesce(p_tx_type, '')) in ('subscription', 'bundle') then 'subscription'
    when lower(coalesce(p_tx_type, '')) in ('cash_in', 'deposit') then 'cash_in'
    when lower(coalesce(p_tx_type, '')) in ('cash_out', 'withdrawal') then 'cash_out'
    when lower(coalesce(p_tx_type, '')) in ('merchant_payment', 'bill_payment', 'payment') then 'merchant_payment'
    when lower(coalesce(p_tx_type, '')) in ('transfer', 'send_money', 'received_money') then
      case
        when lower(coalesce(p_tx_direction, '')) = 'credit' then 'transfer_in'
        when lower(coalesce(p_tx_direction, '')) = 'debit' then 'transfer_out'
        else 'transfer'
      end
    when lower(coalesce(p_tx_type, '')) in ('airtime', 'bundle_purchase') then 'airtime'
    when lower(coalesce(p_tx_type, '')) in ('bank_transfer', 'bank_deposit') then 'bank_transfer'
    when lower(coalesce(p_tx_type, '')) in ('fee', 'charge') then 'fees'
    when lower(coalesce(p_tx_type, '')) in ('loan', 'loan_repayment', 'loan_disbursement') then lower(coalesce(p_tx_type, ''))
    when lower(coalesce(p_tx_direction, '')) = 'credit' then 'transfer_in'
    when lower(coalesce(p_tx_direction, '')) = 'debit' then 'transfer_out'
    else 'uncategorized'
  end;
$$;


--
-- Name: enforce_group_momo_fields(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_group_momo_fields() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  v_route_type text;
  v_recipient text;
begin
  new.country := public.normalize_country_code(
    coalesce(nullif(btrim(coalesce(new.country, '')), ''), 'RW')
  );
  new.type := coalesce(nullif(lower(btrim(coalesce(new.type, ''))), ''), 'saving');
  new.momo_number := nullif(btrim(coalesce(new.momo_number, '')), '');
  new.receiving_momo_code := nullif(
    btrim(coalesce(new.receiving_momo_code, '')),
    ''
  );
  new.receiving_momo_route_type := nullif(
    lower(btrim(coalesce(new.receiving_momo_route_type, ''))),
    ''
  );

  if new.receiving_momo_code is null and new.momo_number is not null then
    new.receiving_momo_code := new.momo_number;
  end if;

  if new.receiving_momo_route_type is null
     and new.receiving_momo_code is not null then
    new.receiving_momo_route_type := public.infer_momo_route_type_for_country(
      new.country,
      new.receiving_momo_code
    );
  end if;

  if new.type = 'community'
     and new.receiving_momo_code is null
     and new.momo_number is null then
    raise exception 'Community groups require a MoMo number or merchant code.';
  end if;

  v_route_type := new.receiving_momo_route_type;
  if v_route_type is null and new.momo_number is not null then
    v_route_type := 'phone_number';
  end if;

  if v_route_type is null then
    return new;
  end if;

  if v_route_type not in ('phone_number', 'code') then
    raise exception 'Unsupported receiving_momo_route_type: %', v_route_type;
  end if;

  v_recipient := coalesce(new.receiving_momo_code, new.momo_number);
  if v_recipient is null then
    raise exception 'A MoMo recipient is required for route type %.', v_route_type;
  end if;

  if v_route_type = 'phone_number' then
    v_recipient := public.normalize_momo_phone_for_country(
      new.country,
      v_recipient
    );
    new.momo_number := v_recipient;
    new.receiving_momo_code := v_recipient;
    new.receiving_momo_route_type := 'phone_number';
  else
    v_recipient := public.normalize_momo_code_for_country(
      new.country,
      v_recipient
    );
    new.momo_number := null;
    new.receiving_momo_code := v_recipient;
    new.receiving_momo_route_type := 'code';
  end if;

  return new;
end;
$$;


--
-- Name: enforce_partner_payment_route_fields(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_partner_payment_route_fields() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  v_country public.supported_countries;
begin
  new.country := 'RW';
  new.provider := public.normalize_partner_payment_provider(new.provider);
  new.status := lower(btrim(coalesce(new.status, 'draft')));
  new.reconciliation_label := regexp_replace(
    lower(btrim(coalesce(new.reconciliation_label, ''))),
    '[^a-z0-9]+',
    '_',
    'g'
  );
  new.reconciliation_label := btrim(new.reconciliation_label, '_');
  new.recipient_code := public.normalize_momo_code_for_country(
    new.country,
    new.recipient_code
  );

  select *
  into v_country
  from public.get_supported_country_momo_config('RW');

  if v_country.iso_code is null then
    raise exception 'Rwanda mobile money configuration is missing.';
  end if;

  if new.provider = '' then
    raise exception 'Payment provider is required.';
  end if;

  if new.reconciliation_label = '' then
    raise exception 'Reconciliation label is required.';
  end if;

  if new.status not in ('draft', 'active', 'inactive') then
    raise exception 'Invalid payment route status: %', new.status;
  end if;

  if coalesce(nullif(v_country.momo_code_ussd_template, ''), '') = '' then
    raise exception 'Merchant-code payments are not configured for Rwanda.';
  end if;

  if new.status = 'active' and new.recipient_code is null then
    raise exception 'Active payment routes require a merchant code.';
  end if;

  return new;
end;
$$;


--
-- Name: enforce_user_momo_fields(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.enforce_user_momo_fields() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  v_country public.supported_countries;
begin
  new.country := 'RW';
  new.language_code := 'en';
  new.momo_number := nullif(btrim(coalesce(new.momo_number, '')), '');
  new.momo_code := nullif(btrim(coalesce(new.momo_code, '')), '');
  new.momo_route_type := nullif(
    lower(btrim(coalesce(new.momo_route_type, ''))),
    ''
  );
  new.momo_provider := coalesce(new.momo_provider, '');

  if new.momo_number is not null then
    new.momo_number := public.normalize_momo_phone_for_country(
      new.country,
      new.momo_number
    );
  end if;

  if new.momo_code is not null then
    new.momo_code := public.normalize_momo_code_for_country(
      new.country,
      new.momo_code
    );
  end if;

  if btrim(new.momo_provider) = '' then
    select *
    into v_country
    from public.get_supported_country_momo_config(new.country);

    if v_country.iso_code is not null then
      new.momo_provider := coalesce(v_country.momo_provider_id, '');
    end if;
  end if;

  if new.momo_route_type = 'phone_number' then
    if new.momo_number is null then
      raise exception using
        errcode = '23514',
        message = 'momo_route_type phone_number requires momo_number';
    end if;
  elsif new.momo_route_type = 'code' then
    if new.momo_code is null then
      raise exception using
        errcode = '23514',
        message = 'momo_route_type code requires momo_code';
    end if;
  elsif new.momo_number is not null then
    new.momo_route_type := 'phone_number';
  elsif new.momo_code is not null then
    new.momo_route_type := 'code';
  else
    new.momo_route_type := null;
  end if;

  return new;
end;
$$;


--
-- Name: find_auth_user_by_phone_or_email(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.find_auth_user_by_phone_or_email(p_phone text, p_email text) RETURNS TABLE(user_id uuid)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
  select au.id as user_id
  from auth.users au
  where au.email = p_email
     or au.phone = p_phone
     or au.phone_change = p_phone
     or coalesce(au.raw_user_meta_data ->> 'phone', '') = p_phone
  order by case
    when au.email = p_email then 0
    when au.phone = p_phone then 1
    when au.phone_change = p_phone then 2
    when coalesce(au.raw_user_meta_data ->> 'phone', '') = p_phone then 3
    else 9
  end,
  au.created_at asc
  limit 1;
$$;


--
-- Name: generate_biopay_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_biopay_id() RETURNS text
    LANGUAGE plpgsql
    AS $$
declare
  candidate text;
begin
  candidate := lpad((floor(random() * 1000000))::int::text, 6, '0');
  return candidate;
end;
$$;


--
-- Name: generate_biopay_public_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_biopay_public_id() RETURNS text
    LANGUAGE plpgsql
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  v_candidate text;
BEGIN
  LOOP
    v_candidate := lpad(floor(random() * 1000000)::int::text, 6, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.biopay_profiles WHERE public_id = v_candidate
    );
  END LOOP;
  RETURN v_candidate;
END;
$$;


--
-- Name: generate_group_invite_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_group_invite_code() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_code text;
begin
  loop
    v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (
      select 1
      from public.groups
      where invite_code = v_code
    );
  end loop;

  return v_code;
end;
$$;


--
-- Name: generate_invite_code(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_invite_code() RETURNS text
    LANGUAGE plpgsql
    AS $$ declare v_code text; v_attempts int := 0; begin loop v_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)); if not exists (select 1 from public.groups where invite_code = v_code) then return v_code; end if; v_attempts := v_attempts + 1; if v_attempts > 100 then raise exception 'Could not generate unique invite code after 100 attempts'; end if; end loop; end; $$;


--
-- Name: generate_public_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_public_user_id() RETURNS text
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
DECLARE
  v_candidate text;
BEGIN
  LOOP
    v_candidate := lpad(floor(random() * 1000000)::int::text, 6, '0');
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE public_user_id = v_candidate
    );
  END LOOP;
  RETURN v_candidate;
END;
$$;


--
-- Name: get_admin_access_for_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_admin_access_for_user(p_user_id uuid DEFAULT NULL::uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
  v_is_platform_admin boolean := false;
  v_result jsonb;
  v_role_rows jsonb;
  v_bank_ids jsonb;
  v_partner_ids jsonb;
  v_has_rayon boolean := false;
BEGIN
  -- Use current user if not specified
  v_user_id := COALESCE(p_user_id, auth.uid());

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object(
      'has_platform_access', false,
      'has_bank_access', false,
      'has_rayon_access', false,
      'bank_partner_ids', '[]'::jsonb,
      'partner_admin_ids', '[]'::jsonb,
      'role_assignments', '[]'::jsonb
    );
  END IF;

  -- Check if the user is a platform admin (from users table)
  SELECT COALESCE(u.is_admin, false)
  INTO v_is_platform_admin
  FROM public.users u
  WHERE u.id = v_user_id;

  -- Get active role assignments
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', ra.id,
      'role', ra.role,
      'partner_scope_id', ra.partner_scope_id,
      'partner_name', p.name,
      'granted_at', ra.granted_at,
      'is_active', ra.is_active
    )
  ), '[]'::jsonb)
  INTO v_role_rows
  FROM public.admin_role_assignments ra
  LEFT JOIN public.partners p ON p.id = ra.partner_scope_id
  WHERE ra.user_id = v_user_id AND ra.is_active = true;

  -- Extract bank partner IDs
  SELECT COALESCE(jsonb_agg(ra.partner_scope_id), '[]'::jsonb)
  INTO v_bank_ids
  FROM public.admin_role_assignments ra
  WHERE ra.user_id = v_user_id
    AND ra.is_active = true
    AND ra.role = 'bank'
    AND ra.partner_scope_id IS NOT NULL;

  -- Extract partner admin IDs (non-rayon partners)
  SELECT COALESCE(jsonb_agg(ra.partner_scope_id), '[]'::jsonb)
  INTO v_partner_ids
  FROM public.admin_role_assignments ra
  WHERE ra.user_id = v_user_id
    AND ra.is_active = true
    AND ra.role = 'rayon_sport'
    AND ra.partner_scope_id IS NOT NULL;

  -- Check rayon_sport role
  SELECT EXISTS(
    SELECT 1 FROM public.admin_role_assignments ra
    WHERE ra.user_id = v_user_id
      AND ra.is_active = true
      AND ra.role = 'rayon_sport'
  ) INTO v_has_rayon;

  -- Also check for 'admin' role assignment (in addition to users.is_admin)
  IF NOT v_is_platform_admin THEN
    SELECT EXISTS(
      SELECT 1 FROM public.admin_role_assignments ra
      WHERE ra.user_id = v_user_id
        AND ra.is_active = true
        AND ra.role = 'admin'
    ) INTO v_is_platform_admin;
  END IF;

  v_result := jsonb_build_object(
    'has_platform_access', v_is_platform_admin,
    'has_bank_access', v_is_platform_admin OR jsonb_array_length(v_bank_ids) > 0,
    'has_rayon_access', v_is_platform_admin OR v_has_rayon,
    'bank_partner_ids', v_bank_ids,
    'partner_admin_ids', v_partner_ids,
    'role_assignments', v_role_rows
  );

  RETURN v_result;
END;
$$;


--
-- Name: get_admin_audit_log(integer, integer, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_admin_audit_log(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_action text DEFAULT NULL::text, p_actor_id uuid DEFAULT NULL::uuid) RETURNS SETOF jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select jsonb_build_object(
    'id', a.id,
    'actor_id', a.actor_id,
    'actor_name', u.full_name,
    'actor_phone', u.phone,
    'action', a.action,
    'target_table', a.target_table,
    'target_id', a.target_id,
    'old_data', a.old_data,
    'new_data', a.new_data,
    'notes', a.notes,
    'created_at', a.created_at
  )
  from public.admin_audit_log a
  left join public.users u on u.id = a.actor_id
  where
    (p_action is null or a.action = p_action)
    and (p_actor_id is null or a.actor_id = p_actor_id)
    and exists (
      select 1 from public.users caller
      where caller.id = auth.uid() and caller.is_admin = true
    )
  order by a.created_at desc
  limit p_limit
  offset p_offset;
$$;


--
-- Name: get_admin_groups_summary(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_admin_groups_summary() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$ declare v_result jsonb; begin if not public.is_admin_user() then raise exception 'Forbidden: platform admin access required.'; end if; select jsonb_build_object( 'total_groups', (select count(*) from public.groups), 'active_groups', (select count(*) from public.groups where is_active = true), 'closed_groups', (select count(*) from public.groups where is_closed = true), 'public_groups', (select count(*) from public.groups where visibility = 'public'), 'private_groups', (select count(*) from public.groups where visibility = 'private'), 'total_members', (select count(*) from public.group_members), 'groups', coalesce(( select jsonb_agg(g_row order by g_row->>'created_at' desc) from ( select jsonb_build_object( 'id', g.id, 'name', g.name, 'type', g.type, 'visibility', g.visibility, 'country', g.country, 'target_amount', g.target_amount, 'monthly_contribution', g.monthly_contribution, 'momo_number', g.momo_number, 'invite_code', g.invite_code, 'creator_id', g.creator_id, 'created_at', g.created_at, 'member_count', coalesce(mc.cnt, 0) ) as g_row from public.groups g left join lateral ( select count(*) as cnt from public.group_members m where m.group_id = g.id ) mc on true ) sub ), '[]'::jsonb) ) into v_result; return v_result; end; $$;


--
-- Name: FUNCTION get_admin_groups_summary(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_admin_groups_summary() IS 'Returns admin overview of all contribution groups with member/wallet counts. Platform admin only.';


--
-- Name: get_bank_analytics_summary(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bank_analytics_summary(p_partner_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  result jsonb;
begin
  select jsonb_build_object(
    'total_groups',
      (
        select count(*)
        from public.groups as group_record
        where group_record.bank_partner_id = p_partner_id
      ),
    'active_groups_count',
      (
        select count(*)
        from public.groups as group_record
        where group_record.bank_partner_id = p_partner_id
      ),
    'total_group_balance',
      (
        select coalesce(sum(coalesce(group_record.amount, 0)), 0)
        from public.groups as group_record
        where group_record.bank_partner_id = p_partner_id
      ),
    'total_collected',
      (
        select coalesce(sum(coalesce(contribution.amount, 0)), 0)
        from public.group_contributions as contribution
        join public.groups as group_record
          on group_record.id = contribution.group_id
        where group_record.bank_partner_id = p_partner_id
          and contribution.status in ('completed', 'confirmed')
      ),
    'total_members',
      (
        select count(*)
        from public.group_members as member
        join public.groups as group_record
          on group_record.id = member.group_id
        where group_record.bank_partner_id = p_partner_id
      )
  ) into result;

  return coalesce(result, '{}'::jsonb);
end;
$$;


--
-- Name: get_bank_custody_contributions(uuid, uuid, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bank_custody_contributions(p_partner_id uuid, p_group_id uuid DEFAULT NULL::uuid, p_status text DEFAULT NULL::text, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS TABLE(contribution_id uuid, group_id uuid, group_name text, user_id uuid, contributor_name text, amount integer, status text, momo_reference text, created_at timestamp with time zone, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if p_partner_id is null then
    raise exception 'Partner id is required.';
  end if;

  if auth.uid() is null or not public.can_read_bank_custody(p_partner_id) then
    raise exception 'Not authorized to view bank custody contributions.';
  end if;

  if p_group_id is not null and not public.group_belongs_to_bank_partner(p_group_id, p_partner_id) then
    raise exception 'This group is not linked to the requested bank workspace.';
  end if;

  return query
  with scoped_contributions as (
    select
      gc.id as contribution_id,
      gc.group_id,
      g.name as group_name,
      gc.user_id,
      coalesce(
        nullif(btrim(gm.display_name), ''),
        nullif(btrim(u.public_user_id), ''),
        nullif(btrim(u.full_name), ''),
        'Member'
      ) as contributor_name,
      gc.amount,
      gc.status,
      gc.momo_reference,
      gc.created_at
    from public.group_contributions gc
    join public.groups g
      on g.id = gc.group_id
    left join public.group_members gm
      on gm.group_id = gc.group_id
      and gm.user_id = gc.user_id
    left join public.users u
      on u.id = gc.user_id
    where public.group_belongs_to_bank_partner(g.id, p_partner_id)
      and (p_group_id is null or gc.group_id = p_group_id)
      and (
        p_status is null
        or btrim(p_status) = ''
        or lower(gc.status) = lower(btrim(p_status))
      )
  )
  select
    sc.contribution_id,
    sc.group_id,
    sc.group_name,
    sc.user_id,
    sc.contributor_name,
    sc.amount,
    sc.status,
    sc.momo_reference,
    sc.created_at,
    count(*) over() as total_count
  from scoped_contributions sc
  order by sc.created_at desc, sc.contribution_id desc
  limit greatest(coalesce(p_limit, 1000), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


--
-- Name: get_bank_custody_group_members(uuid, uuid, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bank_custody_group_members(p_partner_id uuid, p_group_id uuid DEFAULT NULL::uuid, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS TABLE(group_id uuid, group_name text, user_id uuid, display_name text, is_admin boolean, is_anonymous boolean, contribution_amount integer, joined_at timestamp with time zone, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if p_partner_id is null then
    raise exception 'Partner id is required.';
  end if;

  if auth.uid() is null or not public.can_read_bank_custody(p_partner_id) then
    raise exception 'Not authorized to view bank custody members.';
  end if;

  if p_group_id is not null and not public.group_belongs_to_bank_partner(p_group_id, p_partner_id) then
    raise exception 'This group is not linked to the requested bank workspace.';
  end if;

  return query
  with scoped_members as (
    select
      gm.group_id,
      g.name as group_name,
      gm.user_id,
      coalesce(
        nullif(btrim(gm.display_name), ''),
        nullif(btrim(u.public_user_id), ''),
        nullif(btrim(u.full_name), ''),
        'Member'
      ) as display_name,
      gm.is_admin,
      gm.is_anonymous,
      gm.contribution_amount,
      gm.joined_at
    from public.group_members gm
    join public.groups g
      on g.id = gm.group_id
    left join public.users u
      on u.id = gm.user_id
    where public.group_belongs_to_bank_partner(g.id, p_partner_id)
      and (p_group_id is null or gm.group_id = p_group_id)
      and (
        p_search is null
        or btrim(p_search) = ''
        or coalesce(gm.display_name, '') ilike '%' || btrim(p_search) || '%'
        or coalesce(u.public_user_id, '') ilike '%' || btrim(p_search) || '%'
        or coalesce(u.full_name, '') ilike '%' || btrim(p_search) || '%'
        or g.name ilike '%' || btrim(p_search) || '%'
      )
  )
  select
    sm.group_id,
    sm.group_name,
    sm.user_id,
    sm.display_name,
    sm.is_admin,
    sm.is_anonymous,
    sm.contribution_amount,
    sm.joined_at,
    count(*) over() as total_count
  from scoped_members sm
  order by sm.joined_at desc nulls last, sm.group_name asc, sm.display_name asc
  limit greatest(coalesce(p_limit, 1000), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


--
-- Name: get_bank_custody_groups(uuid, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bank_custody_groups(p_partner_id uuid, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, creator_id uuid, name text, type text, visibility text, amount integer, target_amount integer, country text, member_count integer, monthly_contribution integer, description text, bank_partner text, momo_number text, receiving_momo_route_type text, institution_id text, invite_code text, frequency text, created_at timestamp with time zone, updated_at timestamp with time zone, admin_count integer, contribution_count integer, contribution_total integer, last_contribution_at timestamp with time zone, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if p_partner_id is null then
    raise exception 'Partner id is required.';
  end if;

  if auth.uid() is null or not public.can_read_bank_custody(p_partner_id) then
    raise exception 'Not authorized to view this bank custody workspace.';
  end if;

  return query
  with scoped_groups as (
    select g.*
    from public.groups g
    where public.group_belongs_to_bank_partner(g.id, p_partner_id)
      and (
        p_search is null
        or btrim(p_search) = ''
        or g.name ilike '%' || btrim(p_search) || '%'
        or coalesce(g.description, '') ilike '%' || btrim(p_search) || '%'
        or coalesce(g.invite_code, '') ilike '%' || btrim(p_search) || '%'
      )
  ),
  aggregated as (
    select
      g.id,
      g.creator_id,
      g.name,
      g.type,
      g.visibility,
      g.amount,
      g.target_amount,
      g.country,
      g.monthly_contribution,
      g.description,
      g.bank_partner,
      g.momo_number,
      g.receiving_momo_route_type,
      g.institution_id,
      g.invite_code,
      g.frequency,
      g.created_at,
      g.updated_at,
      count(distinct gm.user_id)::int as member_count,
      count(distinct gm.user_id) filter (where gm.is_admin = true)::int as admin_count,
      count(distinct gc.id)::int as contribution_count,
      coalesce(sum(gc.amount), 0)::int as contribution_total,
      max(gc.created_at) as last_contribution_at
    from scoped_groups g
    left join public.group_members gm
      on gm.group_id = g.id
    left join public.group_contributions gc
      on gc.group_id = g.id
    group by
      g.id,
      g.creator_id,
      g.name,
      g.type,
      g.visibility,
      g.amount,
      g.target_amount,
      g.country,
      g.monthly_contribution,
      g.description,
      g.bank_partner,
      g.momo_number,
      g.receiving_momo_route_type,
      g.institution_id,
      g.invite_code,
      g.frequency,
      g.created_at,
      g.updated_at
  )
  select
    a.id,
    a.creator_id,
    a.name,
    a.type,
    a.visibility,
    a.amount,
    a.target_amount,
    a.country,
    a.member_count,
    a.monthly_contribution,
    a.description,
    a.bank_partner,
    a.momo_number,
    a.receiving_momo_route_type,
    a.institution_id,
    a.invite_code,
    a.frequency,
    a.created_at,
    a.updated_at,
    a.admin_count,
    a.contribution_count,
    a.contribution_total,
    a.last_contribution_at,
    count(*) over() as total_count
  from aggregated a
  order by a.updated_at desc nulls last, a.created_at desc nulls last, a.id desc
  limit greatest(coalesce(p_limit, 1000), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


--
-- Name: get_bank_manual_review_allocations(uuid, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_bank_manual_review_allocations(p_partner_id uuid, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS TABLE(review_id uuid, group_id uuid, group_name text, payer_user_id uuid, payer_name text, match_status text, reason text, matched_reference text, amount integer, provider text, payee_digits text, created_at timestamp with time zone, updated_at timestamp with time zone, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $_$
begin
  if p_partner_id is null then
    raise exception 'Partner id is required.';
  end if;

  if auth.uid() is null or not public.can_read_bank_custody(p_partner_id) then
    raise exception 'Not authorized to view bank custody allocations.';
  end if;

  return query
  with candidate_rows as (
    select
      mr.id as review_id,
      coalesce(
        gc.group_id,
        nullif(mr.metadata ->> 'group_id', '')::uuid,
        (
          select candidate_id::uuid
          from jsonb_array_elements_text(coalesce(mr.metadata -> 'matching_group_ids', '[]'::jsonb)) candidate(candidate_id)
          where candidate_id ~* '^[0-9a-f-]{36}$'
          limit 1
        )
      ) as group_id,
      mr.user_id as payer_user_id,
      coalesce(
        nullif(btrim(u.public_user_id), ''),
        nullif(btrim(u.full_name), ''),
        'Member'
      ) as payer_name,
      mr.match_status,
      coalesce(nullif(mr.metadata ->> 'reason', ''), nullif(mr.notes, ''), 'manual_review') as reason,
      nullif(mr.metadata ->> 'matched_reference', '') as matched_reference,
      coalesce((mr.metadata ->> 'amount')::integer, 0) as amount,
      nullif(mr.metadata ->> 'provider', '') as provider,
      coalesce(
        nullif(mr.metadata ->> 'receiver_source_of_truth', ''),
        nullif(mr.metadata ->> 'payee_number_or_code', ''),
        nullif(mr.metadata ->> 'merchant_code', '')
      ) as payee_digits,
      mr.created_at,
      coalesce(mr.updated_at, mr.created_at) as updated_at
    from public.momo_reconciliations mr
    left join public.group_contributions gc
      on mr.target_table = 'group_contributions'
      and mr.target_record_id = gc.id
    left join public.users u
      on u.id = mr.user_id
    where mr.match_status in ('pending_review', 'manual_review')
  ),
  scoped_reviews as (
    select
      cr.review_id,
      cr.group_id,
      g.name as group_name,
      cr.payer_user_id,
      cr.payer_name,
      cr.match_status,
      cr.reason,
      cr.matched_reference,
      cr.amount,
      cr.provider,
      cr.payee_digits,
      cr.created_at,
      cr.updated_at
    from candidate_rows cr
    join public.groups g
      on g.id = cr.group_id
    where public.group_belongs_to_bank_partner(g.id, p_partner_id)
  )
  select
    sr.review_id,
    sr.group_id,
    sr.group_name,
    sr.payer_user_id,
    sr.payer_name,
    sr.match_status,
    sr.reason,
    sr.matched_reference,
    sr.amount,
    sr.provider,
    sr.payee_digits,
    sr.created_at,
    sr.updated_at,
    count(*) over() as total_count
  from scoped_reviews sr
  order by sr.updated_at desc, sr.review_id desc
  limit greatest(coalesce(p_limit, 1000), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$_$;


--
-- Name: get_currency_for_dialing_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_currency_for_dialing_code(p_dialing_code text) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  SELECT currency FROM public.countries
  WHERE dialing_code = p_dialing_code AND is_active = true
  LIMIT 1;
$$;


--
-- Name: get_group_access_snapshot(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_group_access_snapshot(p_group_id uuid) RETURNS TABLE(group_id uuid, is_member boolean, is_creator boolean, is_group_admin boolean, is_bank_custody_admin boolean, can_view_transactions boolean, can_manage_settings boolean, can_export_ledger boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  with viewer_scope as (
    select g.id
    from public.groups g
    where g.id = p_group_id
      and (
        g.visibility = 'public'
        or g.creator_id = auth.uid()
        or public.is_group_member(g.id)
        or public.is_admin_user()
        or exists (
          select 1
          from public.partners p
          where public.bank_is_partner_admin(p.id)
            and public.group_belongs_to_bank_partner(g.id, p.id)
        )
      )
  )
  select
    scope.id as group_id,
    public.is_group_member(scope.id) as is_member,
    exists (
      select 1
      from public.groups g
      where g.id = scope.id
        and g.creator_id = auth.uid()
    ) as is_creator,
    exists (
      select 1
      from public.group_members gm
      where gm.group_id = scope.id
        and gm.user_id = auth.uid()
        and gm.is_admin = true
    ) as is_group_admin,
    exists (
      select 1
      from public.partners p
      where public.bank_is_partner_admin(p.id)
        and public.group_belongs_to_bank_partner(scope.id, p.id)
    ) as is_bank_custody_admin,
    public.can_view_group_transaction_feed(scope.id) as can_view_transactions,
    public.can_manage_group_settings(scope.id) as can_manage_settings,
    public.can_export_group_payment_ledger(scope.id) as can_export_ledger
  from viewer_scope scope;
$$;


--
-- Name: get_group_invite_preview(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_group_invite_preview(p_invite_code text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_group public.groups;
  v_member_count integer := 0;
  v_is_member boolean := false;
begin
  select *
  into v_group
  from public.groups
  where invite_code = upper(btrim(p_invite_code))
  limit 1;

  if v_group.id is null then
    return '{}'::jsonb;
  end if;

  select count(*)
  into v_member_count
  from public.group_members
  where group_id = v_group.id;

  if auth.uid() is not null then
    select exists (
      select 1
      from public.group_members
      where group_id = v_group.id
        and user_id = auth.uid()
    )
    into v_is_member;
  end if;

  return to_jsonb(v_group) || jsonb_build_object(
    'member_count', v_member_count,
    'is_member', v_is_member
  );
end;
$$;


--
-- Name: get_group_payment_ledger_entries(uuid, timestamp with time zone, timestamp with time zone, uuid, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_group_payment_ledger_entries(p_group_id uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_payer_user_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS TABLE(ledger_id uuid, payer_user_id uuid, payer_name text, payer_phone text, amount integer, currency text, tx_datetime timestamp with time zone, external_reference text, tx_category text, cashflow_bucket text, statement_label text, counterparty_name text, target_table text, target_record_id uuid, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if p_group_id is null then
    raise exception 'Group id is required.';
  end if;

  if auth.uid() is null or not public.can_read_group_payment_ledger(p_group_id) then
    raise exception 'Not authorized to view this group payment ledger.';
  end if;

  return query
  with ledger_rows as (
    select
      ledger.id as ledger_id,
      ledger.user_id as payer_user_id,
      coalesce(
        nullif(trim(payer.full_name), ''),
        nullif(trim(payer.official_name), ''),
        'Member'
      ) as payer_name,
      nullif(trim(coalesce(payer.official_phone, payer.phone)), '') as payer_phone,
      ledger.amount,
      ledger.currency,
      coalesce(ledger.tx_datetime, ledger.created_at) as tx_datetime,
      ledger.external_reference,
      ledger.tx_category,
      ledger.cashflow_bucket,
      ledger.statement_label,
      ledger.counterparty_name,
      ledger.target_table,
      ledger.target_record_id
    from public.momo_ledger_entries as ledger
    left join public.users as payer
      on payer.id = ledger.user_id
    where ledger.payee_group_id = p_group_id
      and ledger.ledger_status = 'posted'
      and (p_start_at is null or coalesce(ledger.tx_datetime, ledger.created_at) >= p_start_at)
      and (p_end_before is null or coalesce(ledger.tx_datetime, ledger.created_at) < p_end_before)
      and (p_payer_user_id is null or ledger.user_id = p_payer_user_id)
  )
  select
    row.ledger_id,
    row.payer_user_id,
    row.payer_name,
    row.payer_phone,
    row.amount,
    row.currency,
    row.tx_datetime,
    row.external_reference,
    row.tx_category,
    row.cashflow_bucket,
    row.statement_label,
    row.counterparty_name,
    row.target_table,
    row.target_record_id,
    count(*) over() as total_count
  from ledger_rows as row
  order by row.tx_datetime desc, row.ledger_id desc
  limit greatest(coalesce(p_limit, 1000), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


--
-- Name: get_group_savings_statement_entries(timestamp with time zone, timestamp with time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_group_savings_statement_entries(p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, group_id uuid, group_name text, amount integer, status text, created_at timestamp with time zone, momo_reference text, total_count bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  with statement_rows as (
    select
      contribution.id,
      contribution.group_id,
      coalesce(nullif(trim(group_item.name), ''), 'Savings group') as group_name,
      contribution.amount,
      contribution.status,
      contribution.created_at,
      contribution.momo_reference
    from public.group_contributions as contribution
    left join public.groups as group_item
      on group_item.id = contribution.group_id
    where contribution.user_id = auth.uid()
      and (p_start_at is null or contribution.created_at >= p_start_at)
      and (p_end_before is null or contribution.created_at < p_end_before)
  )
  select
    row.id,
    row.group_id,
    row.group_name,
    row.amount,
    row.status,
    row.created_at,
    row.momo_reference,
    count(*) over() as total_count
  from statement_rows as row
  order by row.created_at desc, row.id desc
  limit greatest(coalesce(p_limit, 1000), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;


--
-- Name: get_group_transaction_feed_entries(uuid, timestamp with time zone, timestamp with time zone, uuid, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_group_transaction_feed_entries(p_group_id uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_payer_user_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS TABLE(ledger_id uuid, payer_user_id uuid, payer_name text, amount integer, currency text, tx_datetime timestamp with time zone, external_reference text, tx_category text, cashflow_bucket text, statement_label text, counterparty_name text, target_table text, target_record_id uuid, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if p_group_id is null then
    raise exception 'Group id is required.';
  end if;

  if auth.uid() is null or not public.can_view_group_transaction_feed(p_group_id) then
    raise exception 'Not authorized to view this group transaction feed.';
  end if;

  return query
  with ledger_rows as (
    select
      ledger.id as ledger_id,
      ledger.user_id as payer_user_id,
      coalesce(
        case
          when coalesce(member.is_anonymous, false) then null
          else nullif(trim(member.display_name), '')
        end,
        case
          when coalesce(member.is_anonymous, false) then null
          else nullif(trim(payer.public_user_id), '')
        end,
        case
          when coalesce(member.is_anonymous, false) then null
          else nullif(trim(payer.full_name), '')
        end,
        'Member'
      ) as payer_name,
      ledger.amount,
      ledger.currency,
      coalesce(ledger.tx_datetime, ledger.created_at) as tx_datetime,
      ledger.external_reference,
      ledger.tx_category,
      ledger.cashflow_bucket,
      ledger.statement_label,
      ledger.counterparty_name,
      ledger.target_table,
      ledger.target_record_id
    from public.momo_ledger_entries as ledger
    left join public.group_members as member
      on member.group_id = p_group_id
      and member.user_id = ledger.user_id
    left join public.users as payer
      on payer.id = ledger.user_id
    where ledger.payee_group_id = p_group_id
      and ledger.ledger_status = 'posted'
      and (p_start_at is null or coalesce(ledger.tx_datetime, ledger.created_at) >= p_start_at)
      and (p_end_before is null or coalesce(ledger.tx_datetime, ledger.created_at) < p_end_before)
      and (p_payer_user_id is null or ledger.user_id = p_payer_user_id)
  )
  select
    row.ledger_id,
    row.payer_user_id,
    row.payer_name,
    row.amount,
    row.currency,
    row.tx_datetime,
    row.external_reference,
    row.tx_category,
    row.cashflow_bucket,
    row.statement_label,
    row.counterparty_name,
    row.target_table,
    row.target_record_id,
    count(*) over() as total_count
  from ledger_rows as row
  order by row.tx_datetime desc, row.ledger_id desc
  limit greatest(coalesce(p_limit, 1000), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


--
-- Name: get_momo_sms_manual_review_queue(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_momo_sms_manual_review_queue(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS TABLE(review_id uuid, raw_sms_id uuid, parsed_sms_id uuid, user_id uuid, sender text, tx_type text, tx_category text, cashflow_bucket text, amount integer, currency text, momo_tx_id text, payer_name text, payee_name text, payee_number_or_code text, merchant_code text, sms_received_at timestamp with time zone, review_created_at timestamp with time zone, updated_at timestamp with time zone, review_kind text, reason text, notes text, sms_preview text, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_is_admin boolean;
begin
  v_is_admin := public.is_admin();

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
      coalesce(
        nullif(btrim(mr.notes), ''),
        'Manual review required.'
      ) as notes,
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
        v_is_admin
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


--
-- Name: FUNCTION get_momo_sms_manual_review_queue(p_limit integer, p_offset integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_momo_sms_manual_review_queue(p_limit integer, p_offset integer) IS 'Queue for M-Money SMS manual reviews, filtered by admin access or receiver account ownership.';


--
-- Name: get_momo_sms_operational_summary(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_momo_sms_operational_summary() RETURNS TABLE(metric_key text, label text, health_status text, summary text, primary_label text, primary_value integer, secondary_label text, secondary_value integer, tertiary_label text, tertiary_value integer, last_signal_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
begin
  if not public.is_admin() then
    raise exception 'Admin privileges required';
  end if;

  return query
  select *
    from (
      with sync_metrics as (
        select
          count(*) filter (
            where status = 'succeeded'
              and created_at >= now() - interval '24 hours'
          )::integer as success_24h,
          count(*) filter (
            where status = 'failed'
              and created_at >= now() - interval '24 hours'
          )::integer as failed_24h,
          coalesce(
            sum(duplicate_messages) filter (
              where created_at >= now() - interval '24 hours'
            ),
            0
          )::integer as duplicates_24h,
          max(created_at) as last_signal_at
        from public.momo_sms_sync_runs
      ),
      raw_summary as (
        select
          count(*) filter (
            where parse_status in ('pending', 'processing')
          )::integer as pending_now,
          count(*) filter (
            where parse_status = 'parsed'
              and created_at >= now() - interval '24 hours'
          )::integer as parsed_24h,
          count(*) filter (
            where parse_status = 'failed'
              and created_at >= now() - interval '24 hours'
          )::integer as failed_24h,
          max(coalesce(updated_at, created_at)) as last_signal_at
        from public.momo_sms_raw
      ),
      parsed_summary as (
        select
          count(*) filter (
            where parse_status = 'needs_review'
              and coalesce(updated_at, created_at) >= now() - interval '24 hours'
          )::integer as needs_review_24h,
          max(coalesce(updated_at, created_at)) as last_signal_at
        from public.momo_sms_parsed
      ),
      parsing_metrics as (
        select
          raw.pending_now,
          raw.parsed_24h,
          raw.failed_24h,
          parsed.needs_review_24h,
          (
            select max(ts)
            from (
              values (raw.last_signal_at), (parsed.last_signal_at)
            ) as timestamps(ts)
          ) as last_signal_at
        from raw_summary raw
        cross join parsed_summary parsed
      ),
      reconciliation_metrics as (
        select
          count(*) filter (
            where match_status = 'matched'
              and coalesce(reconciled_at, updated_at, created_at) >=
                  now() - interval '24 hours'
          )::integer as matched_24h,
          count(*) filter (
            where match_status in ('pending_review', 'manual_review')
          )::integer as open_reviews,
          count(*) filter (
            where match_status = 'rejected'
              and coalesce(updated_at, created_at) >= now() - interval '24 hours'
          )::integer as rejected_24h,
          min(coalesce(updated_at, created_at)) filter (
            where match_status in ('pending_review', 'manual_review')
          ) as oldest_open_at,
          max(coalesce(reconciled_at, updated_at, created_at)) as last_signal_at
        from public.momo_reconciliations
      ),
      sender_inventory_rows as (
        select *
        from public.get_momo_sms_sender_inventory(2147483647, false)
      ),
      sender_inventory_metrics as (
        select
          count(*) filter (
            where resolution_status is null
          )::integer as unresolved_senders,
          count(*) filter (
            where resolution_status is not null
          )::integer as acknowledged_senders,
          coalesce(
            sum(raw_count) filter (
              where resolution_status is null
            ),
            0
          )::integer as unresolved_raw_rows,
          coalesce(sum(raw_count), 0)::integer as total_raw_rows,
          max(
            case
              when resolution_status is null then last_seen_at
              when resolved_at is null then last_seen_at
              when last_seen_at is null then resolved_at
              when resolved_at > last_seen_at then resolved_at
              else last_seen_at
            end
          ) as last_signal_at
        from sender_inventory_rows
      ),
      migration_safety_metrics as (
        select
          count(*) filter (
            where status = 'completed'
          )::integer as legacy_completed_rows,
          count(distinct status)::integer as distinct_statuses,
          max(created_at) filter (
            where status = 'completed'
          ) as last_signal_at
        from public.group_contributions
      ),
      sync_audit_inventory as (
        select count(*)::integer as total_sync_runs
        from public.momo_sms_sync_runs
      ),
      raw_retention_backlog as (
        select count(*)::integer as backlog
        from public.momo_sms_raw raw
        join public.momo_sms_parsed parsed
          on parsed.raw_sms_id = raw.id
         and parsed.parse_status = 'parsed'
        join public.momo_reconciliations reconciliation
          on reconciliation.parsed_sms_id = parsed.id
         and reconciliation.match_status = 'matched'
        where raw.sms_body_redacted_at is null
          and raw.parse_status = 'parsed'
          and raw.created_at <= now() - interval '14 days'
      ),
      attempt_retention_backlog as (
        select count(*)::integer as backlog
        from public.momo_parse_attempts attempt
        join public.momo_sms_raw raw
          on raw.id = attempt.raw_sms_id
        where attempt.payloads_redacted_at is null
          and raw.created_at <= now() - interval '14 days'
          and raw.parse_status in ('parsed', 'failed', 'ignored')
      ),
      raw_redactions as (
        select
          count(*) filter (
            where sms_body_redacted_at >= now() - interval '24 hours'
          )::integer as redacted_24h,
          max(sms_body_redacted_at) as last_signal_at
        from public.momo_sms_raw
      ),
      attempt_redactions as (
        select
          count(*) filter (
            where payloads_redacted_at >= now() - interval '24 hours'
          )::integer as redacted_24h,
          max(payloads_redacted_at) as last_signal_at
        from public.momo_parse_attempts
      ),
      retention_metrics as (
        select
          raw_backlog.backlog as raw_backlog,
          attempt_backlog.backlog as attempt_backlog,
          raw_redactions.redacted_24h as raw_redacted_24h,
          attempt_redactions.redacted_24h as attempt_redacted_24h,
          (
            select max(ts)
            from (
              values (raw_redactions.last_signal_at), (attempt_redactions.last_signal_at)
            ) as timestamps(ts)
          ) as last_signal_at
        from raw_retention_backlog raw_backlog
        cross join attempt_retention_backlog attempt_backlog
        cross join raw_redactions
        cross join attempt_redactions
      ),
      sender_drift_metrics as (
        select
          count(*)::integer as drift_events_24h,
          count(distinct coalesce(
            nullif(metadata ->> 'sender_token', ''),
            nullif(metadata ->> 'sender_display', ''),
            'unknown'
          ))::integer as distinct_senders_24h,
          max(occurred_at) as last_signal_at
        from public.operational_health_events
        where service = 'sms_ingest'
          and component = 'android_sms_autoread'
          and ingest_origin = 'mobile_app'
          and issue_code = 'approved_sender_drift'
          and occurred_at >= now() - interval '24 hours'
      ),
      retry_queue_metrics as (
        select
          count(*) filter (
            where issue_code = 'retry_queue_backlog'
          )::integer as backlog_events_24h,
          count(*) filter (
            where issue_code = 'retry_queue_full'
          )::integer as full_events_24h,
          count(*) filter (
            where issue_code = 'retry_queue_drain_failed'
          )::integer as drain_failures_24h,
          coalesce(
            max(
              greatest(
                coalesce((metadata ->> 'queued_after')::integer, 0),
                coalesce((metadata ->> 'queued_before')::integer, 0)
              )
            ),
            0
          )::integer as max_queue_24h,
          max(occurred_at) as last_signal_at
        from public.operational_health_events
        where service = 'sms_ingest'
          and component = 'android_sms_autoread'
          and ingest_origin = 'mobile_app'
          and issue_code in (
            'retry_queue_backlog',
            'retry_queue_full',
            'retry_queue_drain_failed',
            'retry_queue_drained'
          )
          and occurred_at >= now() - interval '24 hours'
      )
      select
        'device_sync'::text as metric_key,
        'Device Sync'::text as label,
        case
          when sync.last_signal_at is null then 'unknown'
          when sync.failed_24h > 0 and sync.success_24h = 0 then 'failing'
          when sync.failed_24h > 0 then 'degraded'
          when sync.success_24h > 0 then 'healthy'
          else 'unknown'
        end as health_status,
        case
          when sync.last_signal_at is null then
            'No device sync audits have been reported yet.'
          when sync.failed_24h > 0 then
            format(
              '%s successful syncs and %s failed syncs were reported in the last 24 hours.',
              sync.success_24h,
              sync.failed_24h
            )
          else
            format(
              '%s successful syncs were reported in the last 24 hours.',
              sync.success_24h
            )
        end as summary,
        '24h Success'::text as primary_label,
        sync.success_24h as primary_value,
        '24h Fail'::text as secondary_label,
        sync.failed_24h as secondary_value,
        'Duplicates'::text as tertiary_label,
        sync.duplicates_24h as tertiary_value,
        sync.last_signal_at
      from sync_metrics sync

      union all

      select
        'parsing'::text as metric_key,
        'Parsing'::text as label,
        case
          when parsing.pending_now >= 50 or parsing.failed_24h >= 10 then 'failing'
          when parsing.pending_now > 0
            or parsing.failed_24h > 0
            or parsing.needs_review_24h > 0 then 'degraded'
          when parsing.parsed_24h > 0 then 'healthy'
          else 'unknown'
        end as health_status,
        case
          when parsing.last_signal_at is null then
            'No raw SMS parsing activity has been recorded yet.'
          else
            format(
              '%s SMS are waiting for parse, %s parsed successfully, %s failed, and %s required parser review in the last 24 hours.',
              parsing.pending_now,
              parsing.parsed_24h,
              parsing.failed_24h,
              parsing.needs_review_24h
            )
        end as summary,
        'Pending'::text as primary_label,
        parsing.pending_now as primary_value,
        'Parsed 24h'::text as secondary_label,
        parsing.parsed_24h as secondary_value,
        'Failed 24h'::text as tertiary_label,
        parsing.failed_24h as tertiary_value,
        parsing.last_signal_at
      from parsing_metrics parsing

      union all

      select
        'reconciliation'::text as metric_key,
        'Reconciliation'::text as label,
        case
          when reconciliation.open_reviews > 0
            and reconciliation.oldest_open_at <= now() - interval '24 hours' then
            'failing'
          when reconciliation.open_reviews > 0 then 'degraded'
          when reconciliation.matched_24h > 0
            or reconciliation.rejected_24h > 0 then
            'healthy'
          else 'unknown'
        end as health_status,
        case
          when reconciliation.last_signal_at is null then
            'No reconciliation activity has been recorded yet.'
          when reconciliation.open_reviews > 0 then
            format(
              '%s reconciliations still need review, %s matched automatically, and %s were closed in the last 24 hours.',
              reconciliation.open_reviews,
              reconciliation.matched_24h,
              reconciliation.rejected_24h
            )
          when reconciliation.matched_24h > 0
            or reconciliation.rejected_24h > 0 then
            format(
              '%s reconciliations matched automatically and %s were closed in the last 24 hours.',
              reconciliation.matched_24h,
              reconciliation.rejected_24h
            )
          else
            'No open reconciliation work remains in the current 24-hour window.'
        end as summary,
        'Open Review'::text as primary_label,
        reconciliation.open_reviews as primary_value,
        'Matched 24h'::text as secondary_label,
        reconciliation.matched_24h as secondary_value,
        'Closed 24h'::text as tertiary_label,
        reconciliation.rejected_24h as tertiary_value,
        reconciliation.last_signal_at
      from reconciliation_metrics reconciliation

      union all

      select
        'sender_inventory'::text as metric_key,
        'Sender Inventory'::text as label,
        case
          when sender_inventory.unresolved_senders >= 3
            or sender_inventory.unresolved_raw_rows >= 10 then
            'failing'
          when sender_inventory.unresolved_senders > 0 then 'degraded'
          else 'healthy'
        end as health_status,
        case
          when sender_inventory.unresolved_senders > 0 then
            format(
              '%s unsupported senders remain unresolved across %s raw SMS rows. %s sender backlogs were already acknowledged.',
              sender_inventory.unresolved_senders,
              sender_inventory.unresolved_raw_rows,
              sender_inventory.acknowledged_senders
            )
          when sender_inventory.acknowledged_senders > 0 then
            format(
              'All %s unsupported sender backlogs have been acknowledged. %s raw SMS rows remain preserved as historical evidence.',
              sender_inventory.acknowledged_senders,
              sender_inventory.total_raw_rows
            )
          else
            'No unsupported sender backlog is currently stored in raw SMS history.'
        end as summary,
        'Unresolved'::text as primary_label,
        sender_inventory.unresolved_senders as primary_value,
        'Acknowledged'::text as secondary_label,
        sender_inventory.acknowledged_senders as secondary_value,
        'Raw Rows'::text as tertiary_label,
        sender_inventory.total_raw_rows as tertiary_value,
        sender_inventory.last_signal_at
      from sender_inventory_metrics sender_inventory

      union all

      select
        'migration_safety'::text as metric_key,
        'Migration Safety'::text as label,
        case
          when migration_safety.legacy_completed_rows > 0 then 'failing'
          else 'healthy'
        end as health_status,
        case
          when migration_safety.legacy_completed_rows > 0 then
            format(
              '%s legacy group contribution rows still use completed instead of confirmed. Backfill verification failed.',
              migration_safety.legacy_completed_rows
            )
          else
            format(
              'No legacy completed contribution rows remain. %s sync audit runs are currently stored, and canonical statuses stay limited to pending, confirmed, and failed.',
              sync_audit.total_sync_runs
            )
        end as summary,
        'Legacy Rows'::text as primary_label,
        migration_safety.legacy_completed_rows as primary_value,
        'Distinct Statuses'::text as secondary_label,
        migration_safety.distinct_statuses as secondary_value,
        'Sync Audit Rows'::text as tertiary_label,
        sync_audit.total_sync_runs as tertiary_value,
        migration_safety.last_signal_at
      from migration_safety_metrics migration_safety
      cross join sync_audit_inventory sync_audit

      union all

      select
        'retention'::text as metric_key,
        'Retention'::text as label,
        case
          when retention.raw_backlog + retention.attempt_backlog >= 100 then
            'failing'
          when retention.raw_backlog + retention.attempt_backlog > 0 then
            'degraded'
          when retention.last_signal_at is not null then 'healthy'
          else 'unknown'
        end as health_status,
        case
          when retention.last_signal_at is null
            and retention.raw_backlog = 0
            and retention.attempt_backlog = 0 then
            'No eligible retention workload has accumulated yet.'
          else
            format(
              '%s raw SMS rows and %s parse-attempt payload rows are currently eligible for redaction cleanup.',
              retention.raw_backlog,
              retention.attempt_backlog
            )
        end as summary,
        'Raw Backlog'::text as primary_label,
        retention.raw_backlog as primary_value,
        'Attempt Backlog'::text as secondary_label,
        retention.attempt_backlog as secondary_value,
        'Redacted 24h'::text as tertiary_label,
        retention.raw_redacted_24h + retention.attempt_redacted_24h as tertiary_value,
        retention.last_signal_at
      from retention_metrics retention

      union all

      select
        'sender_drift'::text as metric_key,
        'Sender Drift'::text as label,
        case
          when sender_drift.drift_events_24h >= 10
            or sender_drift.distinct_senders_24h >= 3 then 'failing'
          when sender_drift.drift_events_24h > 0 then 'degraded'
          else 'unknown'
        end as health_status,
        case
          when sender_drift.last_signal_at is null then
            'No unapproved sender drift has been reported in the last 24 hours.'
          else
            format(
              '%s possible MoMo messages came from %s unapproved sender IDs in the last 24 hours.',
              sender_drift.drift_events_24h,
              sender_drift.distinct_senders_24h
            )
        end as summary,
        'Drift 24h'::text as primary_label,
        sender_drift.drift_events_24h as primary_value,
        'Distinct Senders'::text as secondary_label,
        sender_drift.distinct_senders_24h as secondary_value,
        'Expected Senders'::text as tertiary_label,
        11::integer as tertiary_value,
        sender_drift.last_signal_at
      from sender_drift_metrics sender_drift

      union all

      select
        'retry_queue'::text as metric_key,
        'Retry Queue'::text as label,
        case
          when retry_queue.full_events_24h > 0
            or retry_queue.drain_failures_24h > 0
            or retry_queue.max_queue_24h >= 50 then 'failing'
          when retry_queue.backlog_events_24h > 0
            or retry_queue.max_queue_24h > 0 then 'degraded'
          when retry_queue.last_signal_at is not null then 'healthy'
          else 'unknown'
        end as health_status,
        case
          when retry_queue.last_signal_at is null then
            'No retry queue pressure has been reported in the last 24 hours.'
          else
            format(
              'Retry queue backlog was reported %s times, the largest observed queue was %s, and full-queue incidents occurred %s times in the last 24 hours.',
              retry_queue.backlog_events_24h,
              retry_queue.max_queue_24h,
              retry_queue.full_events_24h
            )
        end as summary,
        'Backlog Events'::text as primary_label,
        retry_queue.backlog_events_24h as primary_value,
        'Max Queue'::text as secondary_label,
        retry_queue.max_queue_24h as secondary_value,
        'Full Events'::text as tertiary_label,
        retry_queue.full_events_24h as tertiary_value,
        retry_queue.last_signal_at
      from retry_queue_metrics retry_queue
    ) summary_rows
   order by
    case summary_rows.metric_key
      when 'device_sync' then 0
      when 'parsing' then 1
      when 'reconciliation' then 2
      when 'sender_inventory' then 3
      when 'migration_safety' then 4
      when 'retention' then 5
      when 'sender_drift' then 6
      when 'retry_queue' then 7
      else 8
    end;
end;
$$;


--
-- Name: FUNCTION get_momo_sms_operational_summary(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_momo_sms_operational_summary() IS 'Admin-only MoMo SMS operational summary spanning device sync audits, parse pressure, reconciliation backlog, and retention backlog.';


--
-- Name: get_momo_sms_sender_inventory(integer, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_momo_sms_sender_inventory(p_limit integer DEFAULT 20, p_include_approved boolean DEFAULT false) RETURNS TABLE(sender text, sender_token text, sender_kind text, approval_status text, raw_count integer, user_count integer, pending_raw_count integer, parsed_count integer, open_review_count integer, rejected_count integer, matched_count integer, latest_parse_status text, latest_match_status text, last_ingestion_source text, first_seen_at timestamp with time zone, last_seen_at timestamp with time zone, resolution_status text, resolution_note text, resolved_at timestamp with time zone, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $_$
declare
  v_approved_sender_tokens constant text[] := array[
    'mmoney',
    'mmoneyalerts',
    'mobilemoney',
    'momo',
    'momoalerts',
    'mtnmomo',
    'mtnmomorwanda'
  ];
begin
  if not public.is_admin() then
    raise exception 'Admin privileges required';
  end if;

  return query
  with raw_enriched as (
    select
      raw.id,
      raw.user_id,
      btrim(raw.sender) as sender,
      regexp_replace(
        lower(coalesce(raw.sender, '')),
        '[^a-z0-9]+',
        '',
        'g'
      ) as sender_token,
      case
        when btrim(coalesce(raw.sender, '')) ~ '^\+?[0-9]+$' then 'msisdn'
        else 'alias'
      end as sender_kind,
      case
        when regexp_replace(
          lower(coalesce(raw.sender, '')),
          '[^a-z0-9]+',
          '',
          'g'
        ) = any(v_approved_sender_tokens) then 'approved'
        else 'unsupported'
      end as approval_status,
      raw.parse_status as raw_parse_status,
      raw.ingestion_source,
      raw.sms_received_at,
      parsed.parse_status as parsed_parse_status,
      reconciliation.match_status,
      row_number() over (
        partition by btrim(raw.sender)
        order by raw.sms_received_at desc, raw.created_at desc, raw.id desc
      ) as sender_recency_rank
    from public.momo_sms_raw raw
    left join public.momo_sms_parsed parsed
      on parsed.raw_sms_id = raw.id
    left join public.momo_reconciliations reconciliation
      on reconciliation.parsed_sms_id = parsed.id
  ),
  filtered as (
    select *
    from raw_enriched
    where p_include_approved or raw_enriched.approval_status = 'unsupported'
  ),
  grouped as (
    select
      f.sender as sender,
      f.sender_token as sender_token,
      f.sender_kind as sender_kind,
      f.approval_status as approval_status,
      count(*)::integer as raw_count,
      count(distinct f.user_id)::integer as user_count,
      count(*) filter (
        where f.raw_parse_status in ('pending', 'processing')
      )::integer as pending_raw_count,
      count(*) filter (
        where f.parsed_parse_status = 'parsed'
      )::integer as parsed_count,
      count(*) filter (
        where f.match_status in ('pending_review', 'manual_review')
      )::integer as open_review_count,
      count(*) filter (
        where f.match_status = 'rejected'
      )::integer as rejected_count,
      count(*) filter (
        where f.match_status = 'matched'
      )::integer as matched_count,
      max(f.raw_parse_status) filter (
        where f.sender_recency_rank = 1
      ) as latest_parse_status,
      coalesce(
        max(f.match_status) filter (
          where f.sender_recency_rank = 1
        ),
        'not_reconciled'
      ) as latest_match_status,
      max(f.ingestion_source) filter (
        where f.sender_recency_rank = 1
      ) as last_ingestion_source,
      min(f.sms_received_at) as first_seen_at,
      max(f.sms_received_at) as last_seen_at
    from filtered f
    group by f.sender, f.sender_token, f.sender_kind, f.approval_status
  )
  select
    g.sender,
    g.sender_token,
    g.sender_kind,
    g.approval_status,
    g.raw_count,
    g.user_count,
    g.pending_raw_count,
    g.parsed_count,
    g.open_review_count,
    g.rejected_count,
    g.matched_count,
    g.latest_parse_status,
    g.latest_match_status,
    g.last_ingestion_source,
    g.first_seen_at,
    g.last_seen_at,
    resolution.resolution_status,
    resolution.resolution_note,
    resolution.resolved_at,
    count(*) over() as total_count
  from grouped g
  left join public.momo_sms_sender_inventory_resolutions resolution
    on resolution.sender_token = g.sender_token
  order by
    case
      when resolution.resolution_status is null then 0
      else 1
    end,
    case g.approval_status
      when 'unsupported' then 0
      else 1
    end,
    g.raw_count desc,
    g.last_seen_at desc,
    g.sender asc
  limit greatest(coalesce(p_limit, 20), 1);
end;
$_$;


--
-- Name: FUNCTION get_momo_sms_sender_inventory(p_limit integer, p_include_approved boolean); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_momo_sms_sender_inventory(p_limit integer, p_include_approved boolean) IS 'Admin-only sender inventory for M-Money SMS raw history, including unsupported legacy senders, their parse or reconciliation outcomes, and admin acknowledgements.';


--
-- Name: get_momo_validation_issues(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_momo_validation_issues() RETURNS TABLE(record_type text, record_id uuid, country text, country_name text, route_type text, issue_code text, issue_message text, momo_number text, momo_code text, expected_phone_example text, expected_code_example text, phone_ussd_example text, code_ussd_example text, repair_supported boolean)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select
    mvi.record_type,
    mvi.record_id,
    mvi.country,
    mvi.country_name,
    mvi.route_type,
    mvi.issue_code,
    mvi.issue_message,
    mvi.momo_number,
    mvi.momo_code,
    mvi.expected_phone_example,
    mvi.expected_code_example,
    mvi.phone_ussd_example,
    mvi.code_ussd_example,
    mvi.repair_supported
  from public.momo_validation_issues mvi
$$;


--
-- Name: get_my_notification_events(integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_my_notification_events(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
DECLARE
  result jsonb;
BEGIN
  SELECT jsonb_agg(row_to_json(t))
  INTO result
  FROM (
    SELECT
      id,
      title,
      body,
      route,
      image_url,
      data,
      provider,
      send_status,
      sent_count,
      failed_count,
      cleaned_tokens,
      errors,
      created_at,
      sent_at
    FROM public.notification_events
    WHERE target_type = 'user'
      AND user_id = auth.uid()
    ORDER BY COALESCE(sent_at, created_at) DESC, created_at DESC
    LIMIT GREATEST(p_limit, 1)
    OFFSET GREATEST(p_offset, 0)
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$$;


--
-- Name: FUNCTION get_my_notification_events(p_limit integer, p_offset integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_my_notification_events(p_limit integer, p_offset integer) IS 'Returns the authenticated user''s recent server-trusted notification events.';


--
-- Name: get_nearby_drivers(double precision, double precision, text, text, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_nearby_drivers(p_lat double precision, p_lng double precision, p_vehicle_type text DEFAULT NULL::text, p_country text DEFAULT NULL::text, radius_km double precision DEFAULT 10) RETURNS TABLE(driver_id uuid, user_id uuid, vehicle_type text, vehicle_emoji text, distance_km double precision, is_online boolean, rating double precision, trip_count integer, scheduled_route text, has_return_trip boolean, latitude double precision, longitude double precision)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
  select
    dp.user_id as driver_id,
    dp.user_id,
    dp.vehicle_type,
    coalesce(
      dp.vehicle_emoji,
      case lower(dp.vehicle_type)
        when 'moto' then '🛺'
        when 'moto taxi' then '🛺'
        when 'cab' then '🚗'
        when 'truck' then '🚛'
        when 'trike' then '🚐'
        else '🚗'
      end
    ) as vehicle_emoji,
    round(
      (st_distancesphere(
        dp.location::geometry,
        st_setsrid(st_makepoint(p_lng, p_lat), 4326)
      ) / 1000.0)::numeric,
      2
    )::double precision as distance_km,
    dp.is_online,
    dp.rating,
    dp.trips_done as trip_count,
    (
      select mt.from_location || ' -> ' || mt.to_location
      from public.mobility_trips mt
      where mt.driver_id = dp.user_id
        and mt.status = 'open'
        and mt.departure_at >= now()
      order by mt.departure_at asc
      limit 1
    ) as scheduled_route,
    exists (
      select 1
      from public.mobility_trips mt
      where mt.driver_id = dp.user_id
        and mt.status = 'open'
        and mt.is_driver_return_trip = true
        and coalesce(mt.expires_at, mt.departure_at + interval '1 hour') >= now()
    ) as has_return_trip,
    dp.latitude,
    dp.longitude
  from public.driver_profiles dp
  where dp.is_online = true
    and dp.location is not null
    and (
      p_country is null
      or dp.country = public.normalize_country_code(p_country)
    )
    and st_dwithin(
      dp.location,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      radius_km * 1000
    )
    and (p_vehicle_type is null or dp.vehicle_type = p_vehicle_type)
  order by distance_km;
$$;


--
-- Name: get_operational_release_dashboard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_operational_release_dashboard() RETURNS TABLE(service_key text, label text, health_status text, ok_count_24h integer, warn_count_24h integer, error_count_24h integer, issue_count integer, last_signal_at timestamp with time zone, summary text)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
begin
  if not public.is_admin() then
    raise exception 'Admin privileges required';
  end if;

  return query
  select
    ord.service_key,
    ord.label,
    ord.health_status,
    ord.ok_count_24h,
    ord.warn_count_24h,
    ord.error_count_24h,
    ord.issue_count,
    ord.last_signal_at,
    ord.summary
  from public.operational_release_dashboard ord
  order by
    case ord.health_status
      when 'failing' then 0
      when 'degraded' then 1
      when 'unknown' then 2
      else 3
    end,
    ord.label asc;
end;
$$;


--
-- Name: get_operational_triage_issues(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_operational_triage_issues() RETURNS TABLE(issue_id text, issue_type text, severity text, service text, title text, detail text, subject_table text, subject_id text, user_id uuid, reference text, first_seen_at timestamp with time zone, last_seen_at timestamp with time zone, metadata jsonb)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
begin
  if not public.is_admin() then
    raise exception 'Admin privileges required';
  end if;

  return query
  select
    oti.issue_id,
    oti.issue_type,
    oti.severity,
    oti.service,
    oti.title,
    oti.detail,
    oti.subject_table,
    oti.subject_id,
    oti.user_id,
    oti.reference,
    oti.first_seen_at,
    oti.last_seen_at,
    oti.metadata
  from public.operational_triage_issues oti
  order by
    case oti.severity
      when 'critical' then 0
      else 1
    end,
    oti.last_seen_at desc;
end;
$$;


--
-- Name: get_partner_payment_ledger_entries(uuid, timestamp with time zone, timestamp with time zone, uuid, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_partner_payment_ledger_entries(p_partner_id uuid, p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_payer_user_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS TABLE(ledger_id uuid, payer_user_id uuid, payer_name text, payer_phone text, amount integer, currency text, tx_datetime timestamp with time zone, external_reference text, tx_category text, cashflow_bucket text, statement_label text, counterparty_name text, target_table text, target_record_id uuid, total_count bigint)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
begin
  if p_partner_id is null then
    raise exception 'Partner id is required.';
  end if;

  if auth.uid() is null or not public.can_read_partner_payment_ledger(p_partner_id) then
    raise exception 'Not authorized to view this partner payment ledger.';
  end if;

  return query
  with ledger_rows as (
    select
      ledger.id as ledger_id,
      ledger.user_id as payer_user_id,
      coalesce(
        nullif(trim(payer.full_name), ''),
        nullif(trim(payer.official_name), ''),
        'Member'
      ) as payer_name,
      nullif(trim(coalesce(payer.official_phone, payer.phone)), '') as payer_phone,
      ledger.amount,
      ledger.currency,
      coalesce(ledger.tx_datetime, ledger.created_at) as tx_datetime,
      ledger.external_reference,
      ledger.tx_category,
      ledger.cashflow_bucket,
      ledger.statement_label,
      ledger.counterparty_name,
      ledger.target_table,
      ledger.target_record_id
    from public.momo_ledger_entries as ledger
    left join public.users as payer
      on payer.id = ledger.user_id
    where ledger.payee_partner_id = p_partner_id
      and ledger.ledger_status = 'posted'
      and (p_start_at is null or coalesce(ledger.tx_datetime, ledger.created_at) >= p_start_at)
      and (p_end_before is null or coalesce(ledger.tx_datetime, ledger.created_at) < p_end_before)
      and (p_payer_user_id is null or ledger.user_id = p_payer_user_id)
  )
  select
    row.ledger_id,
    row.payer_user_id,
    row.payer_name,
    row.payer_phone,
    row.amount,
    row.currency,
    row.tx_datetime,
    row.external_reference,
    row.tx_category,
    row.cashflow_bucket,
    row.statement_label,
    row.counterparty_name,
    row.target_table,
    row.target_record_id,
    count(*) over() as total_count
  from ledger_rows as row
  order by row.tx_datetime desc, row.ledger_id desc
  limit greatest(coalesce(p_limit, 1000), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


--
-- Name: get_partner_payment_route(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_partner_payment_route(p_partner_id uuid, p_country text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_route record;
begin
  p_country := nullif(btrim(coalesce(p_country, '')), '');

  if p_partner_id is null then
    return null;
  end if;

  select
    ppr.id,
    ppr.partner_id,
    ppr.country,
    ppr.provider,
    ppr.recipient_code,
    ppr.reconciliation_label,
    ppr.status,
    p.name as partner_name,
    p.slug as partner_slug
  into v_route
  from public.partner_payment_routes ppr
  join public.partners p
    on p.id = ppr.partner_id
  where ppr.partner_id = p_partner_id
    and ppr.status = 'active'
    and ppr.recipient_code is not null
    and ppr.country = 'RW'
  order by ppr.updated_at desc
  limit 1;

  if v_route is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_route.id,
    'partner_id', v_route.partner_id,
    'partner_name', v_route.partner_name,
    'partner_slug', v_route.partner_slug,
    'country', 'RW',
    'provider', v_route.provider,
    'recipient_code', v_route.recipient_code,
    'reconciliation_label', v_route.reconciliation_label,
    'status', v_route.status
  );
end;
$$;


--
-- Name: get_platform_analytics_summary(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_platform_analytics_summary() RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  result jsonb;
begin
  -- Only admins can call this
  if not exists (
    select 1 from public.users where id = auth.uid() and is_admin = true
  ) then
    raise exception 'Unauthorized: admin access required';
  end if;

  select jsonb_build_object(
    -- Core counts
    'total_users', (select count(*) from public.users),
    'real_users', (select count(*) from public.users where is_mock = false),
    'mock_users', (select count(*) from public.users where is_mock = true),
    'total_admins', (select count(*) from public.users where is_admin = true),
    'total_drivers', (select count(*) from public.users where is_driver = true),
    'total_partners', (select count(*) from public.partners),
    'total_groups', (select count(*) from public.groups),
    'total_trips', (
      select count(*) from public.trips
      where exists (select 1 from information_schema.tables where table_name = 'trips' and table_schema = 'public')
    ),

    -- Growth (last 7 & 30 days)
    'signups_7d', (select count(*) from public.users where created_at >= now() - interval '7 days'),
    'signups_30d', (select count(*) from public.users where created_at >= now() - interval '30 days'),
    'trips_7d', (
      select count(*) from public.trips
      where created_at >= now() - interval '7 days'
      and exists (select 1 from information_schema.tables where table_name = 'trips' and table_schema = 'public')
    ),
    'active_partners', (select count(*) from public.partners where is_active = true),

    -- Role distribution
    'role_distribution', (
      select coalesce(jsonb_object_agg(role, cnt), '{}'::jsonb)
      from (
        select role, count(*) as cnt
        from public.admin_role_assignments
        where is_active = true
        group by role
      ) sub
    ),

    -- Audit actions last 7 days
    'audit_actions_7d', (
      select count(*) from public.admin_audit_log
      where created_at >= now() - interval '7 days'
    ),

    -- Event distribution last 30 days
    'event_distribution', (
      select coalesce(jsonb_object_agg(action, cnt), '{}'::jsonb)
      from (
        select action, count(*) as cnt
        from public.admin_audit_log
        where created_at >= now() - interval '30 days'
        group by action
      ) sub
    )
  ) into result;

  return result;
end;
$$;


--
-- Name: get_rayon_member_registry(uuid, text, text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_rayon_member_registry(p_partner_id uuid, p_search_query text DEFAULT NULL::text, p_filter_tier text DEFAULT NULL::text, p_region text DEFAULT NULL::text, p_limit integer DEFAULT 20, p_offset integer DEFAULT 0) RETURNS TABLE(user_id uuid, display_name text, membership_number text, points integer, tier text, chapter text, joined_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_search text := nullif(btrim(coalesce(p_search_query, '')), '');
  v_tier text := lower(nullif(btrim(coalesce(p_filter_tier, '')), ''));
  v_region text := nullif(btrim(coalesce(p_region, '')), '');
begin
  if auth.uid() is null then
    raise exception 'Authentication is required.';
  end if;

  return query
  select
    membership.user_id,
    membership.display_name,
    membership.membership_number,
    membership.points,
    membership.tier,
    membership.chapter,
    membership.joined_at
  from public.rs_fan_memberships membership
  where membership.partner_id = p_partner_id
    and (v_tier is null or lower(membership.tier) = v_tier)
    and (v_region is null or coalesce(membership.chapter, '') ilike '%' || v_region || '%')
    and (
      v_search is null
      or membership.display_name ilike '%' || v_search || '%'
      or membership.membership_number ilike '%' || v_search || '%'
    )
  order by membership.points desc, membership.joined_at asc, membership.membership_number asc
  limit greatest(coalesce(p_limit, 20), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


--
-- Name: get_recent_operational_health_events(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_recent_operational_health_events(p_limit integer DEFAULT 40) RETURNS TABLE(id uuid, service text, component text, status text, severity text, issue_code text, message text, function_name text, user_id uuid, subject_type text, subject_id text, metadata jsonb, occurred_at timestamp with time zone)
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_limit integer := least(greatest(coalesce(p_limit, 40), 1), 200);
begin
  if not public.is_admin() then
    raise exception 'Admin privileges required';
  end if;

  return query
  select
    ohe.id,
    ohe.service,
    ohe.component,
    ohe.status,
    ohe.severity,
    ohe.issue_code,
    ohe.message,
    ohe.function_name,
    ohe.user_id,
    ohe.subject_type,
    ohe.subject_id,
    ohe.metadata,
    ohe.occurred_at
  from public.operational_health_events ohe
  order by ohe.occurred_at desc
  limit v_limit;
end;
$$;


--
-- Name: get_rs_fan_analytics(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_rs_fan_analytics() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_role_assignments ara
    WHERE ara.user_id = auth.uid()
      AND ara.is_active = true
      AND (ara.role = 'admin' OR ara.role = 'rayon_sport')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Requires admin or rayon_sport role';
  END IF;

  SELECT jsonb_build_object(
    'total_fans', (SELECT count(*) FROM public.rs_fan_memberships),
    'active_memberships', (SELECT count(*) FROM public.rs_fan_memberships),
    'total_tickets_sold', (
      SELECT count(*) FROM public.rs_tickets
      WHERE status IN ('valid', 'used')
    ),
    'ticket_revenue', (
      SELECT COALESCE(sum(amount_paid), 0)
      FROM public.rs_tickets
      WHERE status IN ('valid', 'used')
    ),
    'total_initiatives', (SELECT count(*) FROM public.rs_initiatives),
    'total_contributions', (
      SELECT COALESCE(sum(amount), 0)
      FROM public.rs_initiative_contributions
      WHERE status = 'confirmed'
    ),
    'total_shop_revenue', (
      SELECT COALESCE(sum(total), 0)
      FROM public.rs_shop_orders
      WHERE status IN ('paid', 'confirmed', 'packed', 'fulfilled', 'delivered')
    ),
    'tier_breakdown', (
      SELECT COALESCE(
        jsonb_object_agg(tier, cnt),
        '{}'::jsonb
      )
      FROM (
        SELECT tier, count(*) AS cnt
        FROM public.rs_fan_memberships
        GROUP BY tier
      ) t
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


--
-- Name: get_rs_notifications(uuid, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_rs_notifications(p_match_id uuid DEFAULT NULL::uuid, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  result jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_role_assignments ara
    WHERE ara.user_id = auth.uid()
      AND ara.is_active = true
      AND (ara.role = 'admin' OR ara.role = 'rayon_sport')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Requires admin or rayon_sport role';
  END IF;

  SELECT jsonb_agg(row_to_json(t))
  INTO result
  FROM (
    SELECT
      n.id, n.match_id, n.title, n.body, n.status,
      n.sent_at, n.created_at,
      m.home_team || ' vs ' || m.away_team AS match_label,
      m.match_date
    FROM public.rs_notifications n
    JOIN public.rs_matches m ON m.id = n.match_id
    WHERE (p_match_id IS NULL OR n.match_id = p_match_id)
    ORDER BY n.created_at DESC
    LIMIT p_limit OFFSET p_offset
  ) t;

  RETURN COALESCE(result, '[]'::jsonb);
END;
$$;


--
-- Name: get_scheduled_trips(double precision, double precision, text, text, text, double precision); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_scheduled_trips(p_lat double precision, p_lng double precision, p_vehicle_type text DEFAULT NULL::text, p_trip_type text DEFAULT NULL::text, p_country text DEFAULT NULL::text, radius_km double precision DEFAULT 10) RETURNS TABLE(id uuid, user_id uuid, role text, vehicle_type text, trip_type text, from_location text, from_lat double precision, from_lng double precision, to_location text, to_lat double precision, to_lng double precision, travel_time timestamp with time zone, repeat_days text[], status text, contact_phone text, contact_name text, whatsapp_number text, created_at timestamp with time zone, distance_km double precision)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
  select
    mt.id,
    mt.user_id,
    mt.role,
    mt.vehicle_type,
    mt.trip_type,
    mt.from_location,
    mt.from_lat,
    mt.from_lng,
    mt.to_location,
    mt.to_lat,
    mt.to_lng,
    mt.travel_time,
    mt.repeat_days,
    mt.status,
    mt.contact_phone,
    mt.contact_name,
    mt.whatsapp_number,
    mt.created_at,
    round(
      (st_distancesphere(
        mt.origin_geo::geometry,
        st_setsrid(st_makepoint(p_lng, p_lat), 4326)
      ) / 1000.0)::numeric,
      2
    )::double precision as distance_km
  from public.mobility_trips mt
  where mt.status in ('open', 'active')
    and mt.origin_geo is not null
    and (
      p_country is null
      or mt.country = public.normalize_country_code(p_country)
    )
    and st_dwithin(
      mt.origin_geo,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      radius_km * 1000
    )
    and (
      p_vehicle_type is null
      or mt.vehicle_type = p_vehicle_type
    )
    and (
      p_trip_type is null
      or mt.trip_type = p_trip_type
    )
  order by mt.travel_time asc, mt.created_at desc;
$$;


--
-- Name: get_wallet_statement_entries(timestamp with time zone, timestamp with time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_wallet_statement_entries(p_start_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_before timestamp with time zone DEFAULT NULL::timestamp with time zone, p_limit integer DEFAULT 1000, p_offset integer DEFAULT 0) RETURNS TABLE(id uuid, entry_type text, ledger_status text, amount integer, currency text, tx_datetime timestamp with time zone, external_reference text, tx_category text, cashflow_bucket text, counterparty_name text, statement_label text, description text, created_at timestamp with time zone, total_count bigint)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  with statement_rows as (
    select
      ledger.id,
      ledger.entry_type,
      ledger.ledger_status,
      ledger.amount,
      ledger.currency,
      coalesce(ledger.tx_datetime, ledger.created_at) as tx_datetime,
      ledger.external_reference,
      coalesce(
        nullif(trim(ledger.tx_category), ''),
        public.derive_momo_tx_category(
          ledger.entry_type,
          ledger.ledger_scope,
          ledger.target_table
        )
      ) as tx_category,
      coalesce(
        nullif(trim(ledger.cashflow_bucket), ''),
        public.derive_momo_cashflow_bucket(
          coalesce(
            nullif(trim(ledger.tx_category), ''),
            public.derive_momo_tx_category(
              ledger.entry_type,
              ledger.ledger_scope,
              ledger.target_table
            )
          ),
          ledger.entry_type
        )
      ) as cashflow_bucket,
      nullif(trim(ledger.counterparty_name), '') as counterparty_name,
      coalesce(
        nullif(trim(ledger.statement_label), ''),
        nullif(trim(ledger.description), ''),
        initcap(replace(coalesce(ledger.tx_category, ledger.entry_type), '_', ' '))
      ) as statement_label,
      ledger.description,
      ledger.created_at
    from public.momo_ledger_entries as ledger
    where ledger.user_id = auth.uid()
      and ledger.ledger_status = 'posted'
      and (p_start_at is null or coalesce(ledger.tx_datetime, ledger.created_at) >= p_start_at)
      and (p_end_before is null or coalesce(ledger.tx_datetime, ledger.created_at) < p_end_before)
  )
  select
    row.id,
    row.entry_type,
    row.ledger_status,
    row.amount,
    row.currency,
    row.tx_datetime,
    row.external_reference,
    row.tx_category,
    row.cashflow_bucket,
    row.counterparty_name,
    row.statement_label,
    row.description,
    row.created_at,
    count(*) over() as total_count
  from statement_rows as row
  order by row.tx_datetime desc, row.created_at desc
  limit greatest(coalesce(p_limit, 1000), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;


--
-- Name: group_belongs_to_bank_partner(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.group_belongs_to_bank_partner(p_group_id uuid, p_partner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.groups g
    left join public.partners p
      on p.id = p_partner_id
    where g.id = p_group_id
      and (
        g.institution_id = p_partner_id::text
        or lower(btrim(coalesce(g.institution_id, ''))) = lower(btrim(coalesce(p.slug, '')))
        or lower(btrim(coalesce(g.bank_partner, ''))) = lower(btrim(coalesce(p.name, '')))
        or lower(btrim(coalesce(g.bank_partner, ''))) = lower(btrim(coalesce(p.slug, '')))
      )
  );
$$;


--
-- Name: handle_new_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.handle_new_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_club_id bigint;
  v_country_code text;
  v_display_name text;
  v_language_code text;
BEGIN
  v_club_id := public.normalize_club_id(
    COALESCE(
      NEW.raw_app_meta_data ->> 'club_id',
      NEW.raw_user_meta_data ->> 'club_id'
    )
  );

  v_country_code := COALESCE(
    NULLIF(upper(NEW.raw_user_meta_data ->> 'country_code'), ''),
    NULLIF(upper(NEW.raw_user_meta_data ->> 'country'), ''),
    'RW'
  );
  v_display_name := COALESCE(
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'display_name'), ''),
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'full_name'), '')
  );
  v_language_code := COALESCE(
    NULLIF(btrim(NEW.raw_user_meta_data ->> 'language_code'), ''),
    'en'
  );

  INSERT INTO public.profiles (
    id,
    club_id,
    display_name,
    full_name,
    country_code,
    country,
    language_code,
    is_active
  )
  VALUES (
    NEW.id,
    v_club_id,
    v_display_name,
    v_display_name,
    v_country_code,
    v_country_code,
    v_language_code,
    true
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.user_privacy_settings (user_id, club_id)
  VALUES (NEW.id, v_club_id)
  ON CONFLICT (user_id) DO NOTHING;

  INSERT INTO public.user_notification_settings (user_id, club_id)
  VALUES (NEW.id, v_club_id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;


--
-- Name: infer_momo_route_type_for_country(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.infer_momo_route_type_for_country(p_country text, p_value text) RETURNS text
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
declare
  v_country public.supported_countries;
  v_trimmed text := btrim(coalesce(p_value, ''));
  v_digits text;
  v_dial_digits text;
begin
  if v_trimmed = '' then
    return null;
  end if;

  if public.is_valid_momo_phone_for_country(p_country, v_trimmed) then
    return 'phone_number';
  end if;

  if public.is_valid_momo_code_for_country(p_country, v_trimmed) then
    return 'code';
  end if;

  select *
  into v_country
  from public.get_supported_country_momo_config(p_country);

  if v_country.iso_code is null then
    return null;
  end if;

  v_digits := regexp_replace(v_trimmed, '[^0-9]', '', 'g');
  v_dial_digits := replace(v_country.dial_code, '+', '');

  if left(v_trimmed, 1) = '+'
     or left(v_trimmed, 1) = '0'
     or left(v_digits, length(v_dial_digits)) = v_dial_digits
     or char_length(v_digits) >= 9 then
    return 'phone_number';
  end if;

  return 'code';
end;
$$;


--
-- Name: is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select coalesce(
    (select is_admin from public.users where id = auth.uid()),
    false
  );
$$;


--
-- Name: is_admin_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_admin_user() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1
    from public.users
    where id = auth.uid()
      and is_admin = true
  );
$$;


--
-- Name: is_club_admin(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_club_admin(p_club_id bigint DEFAULT NULL::bigint) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_user_id uuid;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN RETURN false; END IF;

  RETURN EXISTS (
    SELECT 1 FROM public.admin_role_assignments
    WHERE user_id = v_user_id
      AND (role = 'super_admin'
        OR (role IN ('club_admin', 'club_moderator') AND club_id = COALESCE(p_club_id, public.requesting_club_id())))
  );
END;
$$;


--
-- Name: is_group_member(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_group_member(p_group_id uuid, p_user_id uuid DEFAULT auth.uid()) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select coalesce(
    (
      select exists (
        select 1
        from public.group_members
        where group_id = p_group_id
          and user_id = p_user_id
      )
    ),
    false
  );
$$;


--
-- Name: is_super_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_super_admin() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.admin_role_assignments
    WHERE user_id = auth.uid() AND role = 'super_admin'
  );
END;
$$;


--
-- Name: is_valid_momo_code_for_country(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_valid_momo_code_for_country(p_country text, p_value text) RETURNS boolean
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
begin
  if nullif(btrim(coalesce(p_value, '')), '') is null then
    return false;
  end if;

  perform public.normalize_momo_code_for_country(p_country, p_value);
  return true;
exception
  when others then
    return false;
end;
$$;


--
-- Name: is_valid_momo_phone_for_country(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_valid_momo_phone_for_country(p_country text, p_value text) RETURNS boolean
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
begin
  if nullif(btrim(coalesce(p_value, '')), '') is null then
    return false;
  end if;

  perform public.normalize_momo_phone_for_country(p_country, p_value);
  return true;
exception
  when others then
    return false;
end;
$$;


--
-- Name: join_group_via_invite(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.join_group_via_invite(p_invite_code text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ declare v_user public.users; v_group public.groups; begin if auth.uid() is null then raise exception 'Authentication is required.'; end if; select * into v_user from public.users where id = auth.uid(); if v_user.id is null then raise exception 'Complete your profile first.'; end if; select * into v_group from public.groups where invite_code = btrim(upper(p_invite_code)); if v_group.id is null then return jsonb_build_object('status', 'error', 'message', 'Invalid invite code.'); end if; if exists (select 1 from public.group_members where group_id = v_group.id and user_id = auth.uid()) then return jsonb_build_object('status', 'already_member', 'group_id', v_group.id, 'group_name', v_group.name); end if; insert into public.group_members (group_id, user_id, display_name, is_admin, is_anonymous, contribution_amount, joined_at) values (v_group.id, auth.uid(), coalesce(nullif(btrim(v_user.public_user_id), ''), '000000'), false, false, 0, now()) on conflict (group_id, user_id) do nothing; return jsonb_build_object('status', 'success', 'group_id', v_group.id, 'group_name', v_group.name, 'invite_code', v_group.invite_code); exception when others then return jsonb_build_object('status', 'error', 'message', sqlerrm); end; $$;


--
-- Name: list_admin_role_assignments(text, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.list_admin_role_assignments(p_role text DEFAULT NULL::text, p_active_only boolean DEFAULT true) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_caller_id uuid;
  v_result jsonb;
BEGIN
  v_caller_id := auth.uid();

  -- Only platform admins can list all assignments
  IF NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = v_caller_id AND u.is_admin = true
  ) THEN
    RAISE EXCEPTION 'Only platform admins can list admin role assignments.';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', ra.id,
      'user_id', ra.user_id,
      'user_name', u.full_name,
      'user_phone', u.phone,
      'role', ra.role,
      'partner_scope_id', ra.partner_scope_id,
      'partner_name', p.name,
      'granted_by', ra.granted_by,
      'granted_at', ra.granted_at,
      'revoked_at', ra.revoked_at,
      'is_active', ra.is_active,
      'notes', ra.notes
    ) ORDER BY ra.granted_at DESC
  ), '[]'::jsonb)
  INTO v_result
  FROM public.admin_role_assignments ra
  LEFT JOIN public.users u ON u.id = ra.user_id
  LEFT JOIN public.partners p ON p.id = ra.partner_scope_id
  WHERE (p_role IS NULL OR ra.role = p_role)
    AND (NOT p_active_only OR ra.is_active = true);

  RETURN v_result;
END;
$$;


--
-- Name: log_admin_mutation(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_admin_mutation() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_target_id text;
  v_old_json jsonb;
  v_new_json jsonb;
BEGIN
  IF TG_OP = 'DELETE' or TG_OP = 'UPDATE' THEN
    v_old_json := to_jsonb(OLD);
  END IF;
  
  IF TG_OP = 'INSERT' or TG_OP = 'UPDATE' THEN
    v_new_json := to_jsonb(NEW);
  END IF;

  IF TG_OP = 'DELETE' THEN
    IF TG_TABLE_NAME = 'app_config' THEN
      v_target_id := (v_old_json->>'key')::text;
    ELSE
      v_target_id := (v_old_json->>'id')::text;
    END IF;
  ELSE
    IF TG_TABLE_NAME = 'app_config' THEN
      v_target_id := (v_new_json->>'key')::text;
    ELSE
      v_target_id := (v_new_json->>'id')::text;
    END IF;
  END IF;

  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.admin_audit_log (actor_id, action, target_table, target_id, new_data)
    VALUES (auth.uid(), 'create', TG_TABLE_NAME, v_target_id, v_new_json);
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO public.admin_audit_log (actor_id, action, target_table, target_id, old_data, new_data)
    VALUES (auth.uid(), 'update', TG_TABLE_NAME, v_target_id, v_old_json, v_new_json);
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO public.admin_audit_log (actor_id, action, target_table, target_id, old_data)
    VALUES (auth.uid(), 'delete', TG_TABLE_NAME, v_target_id, v_old_json);
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: match_biopay_face(extensions.vector, double precision, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.match_biopay_face(query_embedding extensions.vector, match_threshold double precision, match_count integer) RETURNS TABLE(display_name text, ussd_string text, score double precision)
    LANGUAGE sql STABLE
    SET search_path TO 'public', 'extensions'
    AS $$
  select
    p.display_name,
    p.ussd_string,
    (1 - (e.embedding <=> query_embedding))::float as score
  from public.biopay_embeddings e
  join public.biopay_payees p on p.id = e.payee_id
  where coalesce(e.is_active, true) = true
    and e.revoked_at is null
    and (1 - (e.embedding <=> query_embedding)) >= match_threshold
  order by e.embedding <=> query_embedding
  limit greatest(match_count, 1);
$$;


--
-- Name: match_biopay_profile(double precision[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.match_biopay_profile(p_embedding double precision[]) RETURNS TABLE(profile_id uuid, public_id text, user_id uuid, club_id bigint, display_name text, route_type text, recipient_value text, country_code text, consent_version text, consent_at timestamp with time zone, created_at timestamp with time zone, updated_at timestamp with time zone, score double precision)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
  WITH query_vector AS (
    SELECT public.biopay_array_to_vector(p_embedding) AS embedding
  ),
  requesting_club AS (
    SELECT NULLIF(
      COALESCE(
        current_setting('request.jwt.claims', true)::jsonb ->> 'club_id',
        current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'club_id'
      ), ''
    )::bigint AS cid
  )
  SELECT
    p.id AS profile_id, p.public_id, p.user_id, p.club_id,
    p.display_name, p.route_type, p.recipient_value, p.country_code,
    p.consent_version, p.consent_at, p.created_at, p.updated_at,
    1 - (e.embedding <=> q.embedding) AS score
  FROM public.biopay_embeddings e
  JOIN public.biopay_profiles p ON p.id = e.profile_id
  CROSS JOIN query_vector q
  CROSS JOIN requesting_club rc
  WHERE e.active = true
    AND p.active = true
    AND p.deleted_at IS NULL
    AND p.club_id = rc.cid -- SCOPED TO REQUESTING CLUB
  ORDER BY e.embedding <=> q.embedding ASC
  LIMIT 1;
$$;


--
-- Name: match_biopay_profile_server(bigint, double precision[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.match_biopay_profile_server(p_club_id bigint, p_embedding double precision[]) RETURNS TABLE(profile_id uuid, public_id text, user_id uuid, club_id bigint, display_name text, route_type text, recipient_value text, country_code text, consent_version text, consent_at timestamp with time zone, created_at timestamp with time zone, updated_at timestamp with time zone, score double precision)
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
  WITH query_vector AS (
    SELECT public.biopay_array_to_vector(p_embedding) AS embedding
  )
  SELECT
    p.id AS profile_id, p.public_id, p.user_id, p.club_id,
    p.display_name, p.route_type, p.recipient_value, p.country_code,
    p.consent_version, p.consent_at, p.created_at, p.updated_at,
    1 - (e.embedding <=> q.embedding) AS score
  FROM public.biopay_embeddings e
  JOIN public.biopay_profiles p ON p.id = e.profile_id
  CROSS JOIN query_vector q
  WHERE e.active = true
    AND p.active = true
    AND p.deleted_at IS NULL
    AND p.club_id = p_club_id
  ORDER BY e.embedding <=> q.embedding ASC
  LIMIT 1;
$$;


--
-- Name: next_public_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_public_user_id() RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_next integer;
begin
  v_next := nextval('public.public_user_id_seq');
  return lpad(v_next::text, 6, '0');
end;
$$;


--
-- Name: normalize_club_id(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_club_id(raw_club_id text) RETURNS bigint
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $_$
BEGIN
  IF raw_club_id IS NULL OR btrim(raw_club_id) = '' THEN
    RETURN NULL;
  END IF;

  IF raw_club_id ~ '^[0-9]+$' THEN
    RETURN raw_club_id::bigint;
  END IF;

  IF raw_club_id = 'rayon_sports_rw' THEN
    RETURN 24;
  END IF;

  RETURN NULL;
END;
$_$;


--
-- Name: normalize_country_code(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_country_code(raw_value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select case lower(trim(coalesce(raw_value, '')))
    when '' then 'RW'
    when 'rw' then 'RW'
    when 'rwanda' then 'RW'
    when 'bj' then 'BJ'
    when 'benin' then 'BJ'
    when 'bw' then 'BW'
    when 'botswana' then 'BW'
    when 'cm' then 'CM'
    when 'cameroon' then 'CM'
    when 'cg' then 'CG'
    when 'congo brazzaville' then 'CG'
    when 'republic of congo' then 'CG'
    when 'republic of the congo' then 'CG'
    when 'congo' then 'CG'
    when 'ci' then 'CI'
    when 'cote d''ivoire' then 'CI'
    when 'côte d''ivoire' then 'CI'
    when 'ivory coast' then 'CI'
    when 'gh' then 'GH'
    when 'ghana' then 'GH'
    when 'gn' then 'GN'
    when 'guinea' then 'GN'
    when 'gw' then 'GW'
    when 'guinea-bissau' then 'GW'
    when 'guinea bissau' then 'GW'
    when 'ke' then 'KE'
    when 'kenya' then 'KE'
    when 'lr' then 'LR'
    when 'liberia' then 'LR'
    when 'mw' then 'MW'
    when 'malawi' then 'MW'
    when 'mz' then 'MZ'
    when 'mozambique' then 'MZ'
    when 'ng' then 'NG'
    when 'nigeria' then 'NG'
    when 'za' then 'ZA'
    when 'south africa' then 'ZA'
    when 'sz' then 'SZ'
    when 'eswatini' then 'SZ'
    when 'swaziland' then 'SZ'
    when 'eswatini (swaziland)' then 'SZ'
    when 'ug' then 'UG'
    when 'uganda' then 'UG'
    when 'zm' then 'ZM'
    when 'zambia' then 'ZM'
    when 'zw' then 'ZW'
    when 'zimbabwe' then 'ZW'
    when 'cd' then 'CD'
    when 'drc' then 'CD'
    when 'democratic republic of congo' then 'CD'
    when 'democratic republic of the congo' then 'CD'
    when 'democratic republic of congo (drc)' then 'CD'
    when 'congo kinshasa' then 'CD'
    when 'et' then 'ET'
    when 'ethiopia' then 'ET'
    when 'ga' then 'GA'
    when 'gabon' then 'GA'
    when 'mg' then 'MG'
    when 'madagascar' then 'MG'
    when 'sn' then 'SN'
    when 'senegal' then 'SN'
    when 'sl' then 'SL'
    when 'sierra leone' then 'SL'
    when 'tz' then 'TZ'
    when 'tanzania' then 'TZ'
    else upper(trim(coalesce(raw_value, 'RW')))
  end
$$;


--
-- Name: normalize_momo_code_for_country(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_momo_code_for_country(p_country text, p_value text) RETURNS text
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
declare
  v_country public.supported_countries;
  v_trimmed text := btrim(coalesce(p_value, ''));
  v_digits text;
begin
  if v_trimmed = '' then
    return null;
  end if;

  select *
  into v_country
  from public.get_supported_country_momo_config(p_country);

  if v_country.iso_code is null then
    raise exception 'Unsupported country code for MoMo validation: %',
      coalesce(nullif(btrim(coalesce(p_country, '')), ''), '(blank)');
  end if;

  if coalesce(nullif(v_country.momo_code_ussd_template, ''), '') = '' then
    raise exception 'Merchant-code payments are not configured for %.',
      v_country.country_name;
  end if;

  v_digits := regexp_replace(v_trimmed, '[^0-9]', '', 'g');
  if v_digits = '' then
    raise exception 'Merchant code is required.';
  end if;

  if coalesce(v_country.momo_code_pattern, '') <> ''
     and not (v_digits ~ v_country.momo_code_pattern) then
    raise exception 'Enter a valid merchant code for %.', v_country.country_name;
  end if;

  if v_country.momo_code_min_length is not null
     and char_length(v_digits) < v_country.momo_code_min_length then
    raise exception 'Merchant code is too short for %.', v_country.country_name;
  end if;

  if v_country.momo_code_max_length is not null
     and char_length(v_digits) > v_country.momo_code_max_length then
    raise exception 'Merchant code is too long for %.', v_country.country_name;
  end if;

  return v_digits;
end;
$$;


--
-- Name: normalize_momo_phone_for_country(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_momo_phone_for_country(p_country text, p_value text) RETURNS text
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public'
    AS $$
declare
  v_country public.supported_countries;
  v_trimmed text := btrim(coalesce(p_value, ''));
  v_digits text;
  v_plus_candidate text;
  v_dial_digits text;
  v_local_pattern text;
  v_keep_nsn_leading_zero boolean := false;
  v_local_digits text;
begin
  if v_trimmed = '' then
    return null;
  end if;

  select *
  into v_country
  from public.get_supported_country_momo_config(p_country);

  if v_country.iso_code is null then
    raise exception 'Unsupported country code for MoMo validation: %',
      coalesce(nullif(btrim(coalesce(p_country, '')), ''), '(blank)');
  end if;

  v_digits := regexp_replace(v_trimmed, '[^0-9]', '', 'g');
  if v_digits = '' then
    raise exception 'Phone number is required.';
  end if;

  v_plus_candidate := '+' || v_digits;
  v_dial_digits := replace(v_country.dial_code, '+', '');
  v_local_pattern := coalesce(
    nullif(v_country.momo_number_local_pattern, ''),
    nullif(v_country.mobile_national_number_pattern, '')
  );
  v_keep_nsn_leading_zero := regexp_replace(
    coalesce(v_country.mobile_example_e164, ''),
    '[^0-9]',
    '',
    'g'
  ) like v_dial_digits || '0%';

  if coalesce(v_country.momo_number_e164_pattern, '') <> ''
     and v_plus_candidate ~ v_country.momo_number_e164_pattern then
    return v_plus_candidate;
  end if;

  if coalesce(v_local_pattern, '') <> ''
     and v_digits ~ v_local_pattern then
    v_local_digits := v_digits;
    if not v_keep_nsn_leading_zero and left(v_local_digits, 1) = '0' then
      v_local_digits := regexp_replace(v_local_digits, '^0', '');
    end if;
    return v_country.dial_code || v_local_digits;
  end if;

  if left(v_digits, length(v_dial_digits)) = v_dial_digits then
    if coalesce(v_country.momo_number_e164_pattern, '') <> ''
       and v_plus_candidate ~ v_country.momo_number_e164_pattern then
      return v_plus_candidate;
    end if;

    v_local_digits := substr(v_digits, length(v_dial_digits) + 1);
    if coalesce(v_local_pattern, '') <> ''
       and v_local_digits ~ v_local_pattern then
      if not v_keep_nsn_leading_zero and left(v_local_digits, 1) = '0' then
        v_local_digits := regexp_replace(v_local_digits, '^0', '');
      end if;
      return v_country.dial_code || v_local_digits;
    end if;
  end if;

  if coalesce(array_length(v_country.mobile_possible_lengths, 1), 0) > 0
     and not (char_length(v_digits) = any(v_country.mobile_possible_lengths)) then
    raise exception 'Enter a valid % mobile money number.', v_country.country_name;
  end if;

  raise exception 'Enter a valid % mobile money number.', v_country.country_name;
end;
$$;


--
-- Name: normalize_partner_payment_provider(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_partner_payment_provider(p_value text) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select lower(btrim(coalesce(p_value, '')))
$$;


--
-- Name: notify_mission_completed(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notify_mission_completed() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'extensions'
    AS $$
DECLARE
  _supabase_url    TEXT;
  _service_key     TEXT;
  _mission_title   TEXT;
  _request_id      BIGINT;
BEGIN
  IF NEW.completed_at IS NULL THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND OLD.completed_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  SELECT title INTO _mission_title
  FROM public.cool_missions
  WHERE id = NEW.mission_id;

  IF _mission_title IS NULL THEN
    _mission_title := 'a mission';
  END IF;

  _supabase_url := current_setting('app.settings.supabase_url', TRUE);
  _service_key  := current_setting('app.settings.service_role_key', TRUE);

  IF _supabase_url IS NULL OR _service_key IS NULL THEN
    RAISE WARNING '[notify_mission_completed] app.settings.supabase_url or service_role_key not configured. Skipping push.';
    RETURN NEW;
  END IF;

  SELECT extensions.http_post(
    url     := _supabase_url || '/functions/v1/send-notification',
    body    := jsonb_build_object(
      'type',    'user',
      'user_id', NEW.user_id::TEXT,
      'title',   'Mission Complete! 🎉',
      'body',    'You completed: ' || _mission_title,
      'data',    jsonb_build_object(
        'route', '/missions',
        'type',  'mission_complete',
        'mission_id', NEW.mission_id::TEXT
      )
    ),
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || _service_key
    )
  ) INTO _request_id;

  RETURN NEW;
END;
$$;


--
-- Name: FUNCTION notify_mission_completed(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.notify_mission_completed() IS 'Sends a push notification via the send-notification Edge Function when a user completes a Cool mission.';


--
-- Name: partners_set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.partners_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.updated_at := now();
  return new;
end;
$$;


--
-- Name: peek_biopay_face_match(extensions.vector, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.peek_biopay_face_match(query_embedding extensions.vector, match_count integer DEFAULT 1) RETURNS TABLE(display_name text, ussd_string text, score double precision)
    LANGUAGE sql STABLE
    SET search_path TO 'public', 'extensions'
    AS $$
  select
    p.display_name,
    p.ussd_string,
    (1 - (e.embedding <=> query_embedding))::float as score
  from public.biopay_embeddings e
  join public.biopay_payees p on p.id = e.payee_id
  where coalesce(e.is_active, true) = true
    and e.revoked_at is null
  order by e.embedding <=> query_embedding
  limit greatest(match_count, 1);
$$;


--
-- Name: populate_event_club_scope(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.populate_event_club_scope() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.club_id IS NULL THEN
    NEW.club_id := NULLIF(public.requesting_club_id(), '')::bigint;
  END IF;

  IF NEW.club_id IS NULL THEN
    SELECT club_id INTO NEW.club_id
      FROM public.profiles
     WHERE id = NEW.user_id;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: populate_group_message_defaults(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.populate_group_message_defaults() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ begin if new.alias is null then new.alias := substr(md5(new.sender_id::text || new.group_id::text), 1, 6); end if; return new; end; $$;


--
-- Name: preview_invite(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.preview_invite(p_invite_code text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$ declare v_group public.groups; v_member_count bigint; begin select * into v_group from public.groups where invite_code = btrim(upper(p_invite_code)); if v_group.id is null then return jsonb_build_object('status', 'not_found', 'message', 'No group found for this invite code.'); end if; select count(*) into v_member_count from public.group_members where group_id = v_group.id; return jsonb_build_object('status', 'success', 'group_id', v_group.id, 'group_name', v_group.name, 'description', v_group.description, 'visibility', v_group.visibility, 'type', v_group.type, 'target_amount', v_group.target_amount, 'country', v_group.country, 'member_count', v_member_count, 'invite_code', v_group.invite_code, 'already_member', exists (select 1 from public.group_members where group_id = v_group.id and user_id = auth.uid())); end; $$;


--
-- Name: protect_users_is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.protect_users_is_admin() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  if auth.role() <> 'service_role' then
    if tg_op = 'INSERT' and coalesce(new.is_admin, false) then
      raise exception 'is_admin can only be assigned by the service role.';
    end if;

    if tg_op = 'UPDATE' and new.is_admin is distinct from old.is_admin then
      raise exception 'is_admin can only be modified by the service role.';
    end if;
  end if;

  return new;
end;
$$;


--
-- Name: purge_mock_batch(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.purge_mock_batch(p_mock_batch text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_batch text := nullif(trim(p_mock_batch), '');
  v_result jsonb := '{}'::jsonb;
  v_count integer := 0;
begin
  if v_batch is null then
    raise exception 'Mock batch is required.';
  end if;

  if not public.is_admin_user() then
    raise exception 'Only admins can purge mock data batches.';
  end if;

  create temporary table tmp_mock_user_ids (
    user_id uuid primary key
  ) on commit drop;

  insert into tmp_mock_user_ids (user_id)
  select distinct id
  from public.users
  where mock_batch = v_batch
  union
  select distinct id
  from auth.users
  where coalesce(raw_user_meta_data ->> 'mock_batch', '') = v_batch
     or coalesce(raw_app_meta_data ->> 'mock_batch', '') = v_batch;

  -- >> NEW BANK TABLES <<
  delete from public.bank_loans
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('bank_loans', v_count);

  delete from public.bank_baskets
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('bank_baskets', v_count);
  -- << END NEW BANK TABLES >>

  delete from public.momo_reconciliations
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('momo_reconciliations', v_count);

  delete from public.momo_ledger_entries
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('momo_ledger_entries', v_count);

  delete from public.momo_sms_parsed
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('momo_sms_parsed', v_count);

  delete from public.momo_sms_raw
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('momo_sms_raw', v_count);

  delete from public.cool_mission_progress
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('cool_mission_progress', v_count);

  delete from public.cool_events
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('cool_events', v_count);

  delete from public.cool_status
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('cool_status', v_count);

  delete from public.season_memberships
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('season_memberships', v_count);

  delete from public.credit_scores
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('credit_scores', v_count);

  delete from public.driver_subscriptions
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('driver_subscriptions', v_count);

  delete from public.mobility_trips
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('mobility_trips', v_count);

  delete from public.driver_profiles
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('driver_profiles', v_count);

  delete from public.group_contributions
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('group_contributions', v_count);

  delete from public.group_members
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('group_members', v_count);

  delete from public.groups
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('groups', v_count);

  delete from public.rs_tickets
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('rs_tickets', v_count);

  delete from public.rs_shop_orders
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('rs_shop_orders', v_count);

  delete from public.rs_initiative_contributions
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('rs_initiative_contributions', v_count);

  delete from public.rs_achievements
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('rs_achievements', v_count);

  delete from public.rs_fan_club_members
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('rs_fan_club_members', v_count);

  delete from public.rs_fan_memberships
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('rs_fan_memberships', v_count);

  delete from public.rs_matches
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('rs_matches', v_count);

  delete from public.rs_shop_products
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('rs_shop_products', v_count);

  delete from public.partner_services
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('partner_services', v_count);

  delete from public.partners
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('partners', v_count);

  delete from public.cool_missions
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('cool_missions', v_count);

  delete from public.season_definitions
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('season_definitions', v_count);

  delete from public.cool_seasons
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('cool_seasons', v_count);

  delete from public.nexus_opportunities
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('nexus_opportunities', v_count);

  delete from public.users
  where mock_batch = v_batch;
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('users', v_count);

  delete from auth.users
  where id in (select user_id from tmp_mock_user_ids);
  get diagnostics v_count = row_count;
  v_result := v_result || jsonb_build_object('auth_users', v_count);

  return jsonb_build_object(
    'success',
    true,
    'mock_batch',
    v_batch,
    'deleted',
    v_result
  );
end;
$$;


--
-- Name: record_admin_action(text, text, text, jsonb, jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_admin_action(p_action text, p_target_table text DEFAULT NULL::text, p_target_id text DEFAULT NULL::text, p_old_data jsonb DEFAULT NULL::jsonb, p_new_data jsonb DEFAULT NULL::jsonb, p_notes text DEFAULT NULL::text) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  insert into public.admin_audit_log (actor_id, action, target_table, target_id, old_data, new_data, notes)
  values (auth.uid(), p_action, p_target_table, p_target_id, p_old_data, p_new_data, p_notes);
$$;


--
-- Name: redact_momo_sms_artifacts_due(interval, interval, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redact_momo_sms_artifacts_due(p_raw_retention interval DEFAULT '14 days'::interval, p_attempt_retention interval DEFAULT '14 days'::interval, p_batch_size integer DEFAULT 500) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_now timestamptz := now();
  v_batch_size integer := greatest(coalesce(p_batch_size, 500), 1);
  v_raw_redacted integer := 0;
  v_attempt_payloads_redacted integer := 0;
begin
  with raw_candidates as (
    select raw.id
    from public.momo_sms_raw raw
    join public.momo_sms_parsed parsed
      on parsed.raw_sms_id = raw.id
     and parsed.parse_status = 'parsed'
    join public.momo_reconciliations reconciliation
      on reconciliation.parsed_sms_id = parsed.id
     and reconciliation.match_status = 'matched'
    where raw.sms_body_redacted_at is null
      and raw.parse_status = 'parsed'
      and raw.created_at <= v_now - p_raw_retention
    order by raw.created_at asc
    limit v_batch_size
  )
  update public.momo_sms_raw raw
     set sms_body = '[REDACTED AFTER PARSE + MATCHED RECONCILIATION]',
         sms_body_redacted_at = v_now,
         updated_at = v_now
    from raw_candidates
   where raw.id = raw_candidates.id;

  get diagnostics v_raw_redacted = row_count;

  with attempt_candidates as (
    select attempt.id
    from public.momo_parse_attempts attempt
    join public.momo_sms_raw raw
      on raw.id = attempt.raw_sms_id
    where attempt.payloads_redacted_at is null
      and raw.created_at <= v_now - p_attempt_retention
      and raw.parse_status in ('parsed', 'failed', 'ignored')
    order by attempt.created_at asc
    limit v_batch_size
  )
  update public.momo_parse_attempts attempt
     set request_payload = '{}'::jsonb,
         response_payload = '{}'::jsonb,
         payloads_redacted_at = v_now
    from attempt_candidates
   where attempt.id = attempt_candidates.id;

  get diagnostics v_attempt_payloads_redacted = row_count;

  return jsonb_build_object(
    'raw_redacted', v_raw_redacted,
    'attempt_payloads_redacted', v_attempt_payloads_redacted,
    'executed_at', v_now,
    'raw_retention_days', extract(day from p_raw_retention),
    'attempt_retention_days', extract(day from p_attempt_retention),
    'batch_size', v_batch_size
  );
end;
$$;


--
-- Name: FUNCTION redact_momo_sms_artifacts_due(p_raw_retention interval, p_attempt_retention interval, p_batch_size integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.redact_momo_sms_artifacts_due(p_raw_retention interval, p_attempt_retention interval, p_batch_size integer) IS 'Redacts retained raw MoMo SMS bodies after successful parse + matched reconciliation, and clears stored AI request/response payloads after the retention window.';


--
-- Name: redeem_cool_reward(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redeem_cool_reward(p_user_id uuid, p_reward_id uuid) RETURNS public.cool_status
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
    v_cost int;
    v_current_points int;
    v_status public.cool_status;
BEGIN
    -- 1. Get reward cost
    SELECT token_cost INTO v_cost
    FROM public.cool_rewards
    WHERE id = p_reward_id AND is_active = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Reward not found or inactive';
    END IF;

    -- 2. Get user points
    SELECT total_points INTO v_current_points
    FROM public.cool_status
    WHERE user_id = p_user_id;

    IF v_current_points < v_cost THEN
        RAISE EXCEPTION 'Insufficient points. Have %, need %', v_current_points, v_cost;
    END IF;

    -- 3. Record redemption
    INSERT INTO public.cool_reward_redemptions (user_id, reward_id, cost_at_redemption)
    VALUES (p_user_id, p_reward_id, v_cost);

    -- 4. Deduct points (as a negative event)
    SELECT * INTO v_status
    FROM public.apply_cool_event_internal(
        p_user_id,
        'rewardRedeemed',
        -v_cost,
        p_reward_id::text,
        jsonb_build_object('reward_id', p_reward_id),
        NULL,
        NULL, -- No dedupe needed for redemptions
        NULL,
        NULL
    );

    RETURN v_status;
END;
$$;


--
-- Name: refresh_admin_phone_access_for_user(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_admin_phone_access_for_user(p_user_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
DECLARE
  v_phone text;
  v_phone_digits text;
  v_club_ids bigint[];
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  SELECT
    COALESCE(NULLIF(u.phone, ''), i.identity_data->>'phone')
  INTO v_phone
  FROM auth.users AS u
  LEFT JOIN auth.identities AS i
    ON i.user_id = u.id
   AND i.provider = 'phone'
  WHERE u.id = p_user_id
  ORDER BY i.updated_at DESC NULLS LAST
  LIMIT 1;

  SELECT ARRAY_REMOVE(ARRAY_AGG(DISTINCT assignments.club_id), NULL)
  INTO v_club_ids
  FROM public.admin_role_assignments AS assignments
  WHERE assignments.user_id = p_user_id
    AND assignments.is_active = true
    AND assignments.role IN (
      'super_admin',
      'admin',
      'club_admin',
      'club_moderator',
      'rayon_sport',
      'bank'
    );

  v_phone_digits := regexp_replace(COALESCE(v_phone, ''), '[^0-9]', '', 'g');

  IF COALESCE(array_length(v_club_ids, 1), 0) = 0 OR v_phone_digits = '' THEN
    DELETE FROM public.admin_phone_access
    WHERE user_id = p_user_id;
    RETURN;
  END IF;

  DELETE FROM public.admin_phone_access
  WHERE normalized_phone = v_phone_digits
    AND user_id <> p_user_id;

  INSERT INTO public.admin_phone_access (
    user_id,
    phone,
    normalized_phone,
    club_ids,
    updated_at
  )
  VALUES (
    p_user_id,
    v_phone,
    v_phone_digits,
    COALESCE(v_club_ids, '{}'),
    timezone('utc', now())
  )
  ON CONFLICT (user_id) DO UPDATE
  SET phone = EXCLUDED.phone,
      normalized_phone = EXCLUDED.normalized_phone,
      club_ids = EXCLUDED.club_ids,
      updated_at = timezone('utc', now());
END;
$$;


--
-- Name: refresh_match_ticket_sales(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.refresh_match_ticket_sales() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_match_id uuid;
BEGIN
  v_match_id := COALESCE(NEW.match_id, OLD.match_id);
  UPDATE public.matches
     SET sold_count = (
           SELECT COUNT(*)
             FROM public.tickets
            WHERE match_id = v_match_id
              AND status = 'active'
         ),
         updated_at = timezone('utc', now())
   WHERE id = v_match_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;


--
-- Name: repair_momo_validation_issue(text, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.repair_momo_validation_issue(p_record_type text, p_record_id uuid, p_issue_code text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select jsonb_build_object(
    'status', 'unavailable',
    'record_type', p_record_type,
    'record_id', p_record_id,
    'issue_code', p_issue_code,
    'message', 'Repair automation is unavailable until the full validation migration set is applied.'
  )
$$;


--
-- Name: requesting_club_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.requesting_club_id() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT COALESCE(
    public.normalize_club_id(
      NULLIF(
        COALESCE(
          current_setting('request.jwt.claims', true)::jsonb ->> 'club_id',
          current_setting('request.jwt.claims', true)::jsonb -> 'app_metadata' ->> 'club_id',
          current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'club_id'
        ),
        ''
      )
    )::text,
    (
      SELECT p.club_id::text
      FROM public.profiles p
      WHERE p.id = auth.uid()
      LIMIT 1
    )
  );
$$;


--
-- Name: resolve_fan_tier(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_fan_tier(p_points integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
    WHEN coalesce(p_points, 0) >= 5000 THEN 'platinum'
    WHEN coalesce(p_points, 0) >= 2000 THEN 'gold'
    WHEN coalesce(p_points, 0) >= 1000 THEN 'bronze'
    ELSE 'fan'
  END
$$;


--
-- Name: revoke_admin_role(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.revoke_admin_role(p_assignment_id uuid, p_notes text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_caller_id uuid;
  v_assignment record;
BEGIN
  v_caller_id := auth.uid();

  -- Only platform admins can revoke roles
  IF NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = v_caller_id AND u.is_admin = true
  ) THEN
    RAISE EXCEPTION 'Only platform admins can revoke admin roles.';
  END IF;

  -- Find and validate assignment
  SELECT * INTO v_assignment
  FROM public.admin_role_assignments
  WHERE id = p_assignment_id AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Role assignment not found or already revoked.';
  END IF;

  -- Soft-delete
  UPDATE public.admin_role_assignments
  SET is_active = false,
      revoked_at = now(),
      notes = COALESCE(p_notes, notes)
  WHERE id = p_assignment_id;

  RETURN jsonb_build_object(
    'status', 'revoked',
    'assignment_id', p_assignment_id,
    'role', v_assignment.role,
    'user_id', v_assignment.user_id
  );
END;
$$;


--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


--
-- Name: rs_apply_membership_points(uuid, uuid, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rs_apply_membership_points(p_user_id uuid, p_partner_id uuid, p_points integer, p_chapter text DEFAULT NULL::text) RETURNS public.fan_memberships
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_membership public.rs_fan_memberships;
  v_chapter text := coalesce(nullif(btrim(coalesce(p_chapter, '')), ''), 'Kigali Central');
begin
  insert into public.rs_fan_memberships (
    user_id,
    partner_id,
    display_name,
    points,
    chapter,
    membership_number,
    joined_at,
    created_at,
    updated_at
  )
  values (
    p_user_id,
    p_partner_id,
    public.rs_resolve_public_identity(p_user_id),
    greatest(coalesce(p_points, 0), 0),
    v_chapter,
    'RS-' || to_char(now(), 'YYYY') || '-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6)),
    now(),
    now(),
    now()
  )
  on conflict (user_id, partner_id) do update
    set
      points = greatest(public.rs_fan_memberships.points + coalesce(p_points, 0), 0),
      display_name = public.rs_resolve_public_identity(excluded.user_id, public.rs_fan_memberships.display_name),
      chapter = coalesce(nullif(btrim(public.rs_fan_memberships.chapter), ''), excluded.chapter),
      updated_at = now()
  returning * into v_membership;

  return v_membership;
end;
$$;


--
-- Name: rs_check_ticket_capacity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rs_check_ticket_capacity() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_capacity integer;
  v_sold integer;
begin
  select capacity
  into v_capacity
  from public.rs_matches
  where id = new.match_id;

  -- If capacity is 0 or null, treat as unlimited
  if coalesce(v_capacity, 0) = 0 then
    return new;
  end if;

  select count(*)
  into v_sold
  from public.rs_tickets
  where match_id = new.match_id
    and status in ('pending', 'valid', 'used');

  if v_sold >= v_capacity then
    raise exception 'Match is sold out. Capacity: %, Sold: %',
      v_capacity, v_sold;
  end if;

  return new;
end;
$$;


--
-- Name: rs_decrement_stock_on_order(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rs_decrement_stock_on_order() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_item jsonb;
  v_product_id uuid;
  v_quantity integer;
begin
  if new.items is null or jsonb_array_length(new.items) = 0 then
    return new;
  end if;

  for v_item in select * from jsonb_array_elements(new.items)
  loop
    v_product_id := (v_item ->> 'product_id')::uuid;
    v_quantity := coalesce((v_item ->> 'quantity')::integer, 1);

    update public.rs_shop_products
    set stock = greatest(stock - v_quantity, 0)
    where id = v_product_id;
  end loop;

  return new;
end;
$$;


--
-- Name: rs_is_partner_admin(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rs_is_partner_admin(p_partner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE
    SET search_path TO 'public'
    AS $$
  select
    coalesce(auth.jwt() -> 'app_metadata' ->> 'is_partner_admin', 'false') = 'true'
    or coalesce(
      (auth.jwt() -> 'app_metadata' -> 'partner_admin_ids') ? p_partner_id::text,
      false
    );
$$;


--
-- Name: rs_membership_tier_for_points(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rs_membership_tier_for_points(p_points integer) RETURNS text
    LANGUAGE sql IMMUTABLE
    SET search_path TO 'public'
    AS $$
  select case
    when greatest(coalesce(p_points, 0), 0) >= 5000 then 'platinum'
    when greatest(coalesce(p_points, 0), 0) >= 2000 then 'gold'
    when greatest(coalesce(p_points, 0), 0) >= 1000 then 'silver'
    else 'blue'
  end;
$$;


--
-- Name: rs_resolve_public_identity(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rs_resolve_public_identity(p_user_id uuid, p_seeded text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $_$
declare
  v_candidate text := nullif(btrim(coalesce(p_seeded, '')), '');
  v_meta_identity text;
  v_hash bigint;
begin
  if v_candidate ~ '^[0-9]{6}$' then
    return v_candidate;
  end if;

  select coalesce(
    nullif(btrim(raw_user_meta_data ->> 'public_user_id'), ''),
    nullif(btrim(raw_app_meta_data ->> 'public_user_id'), '')
  )
  into v_meta_identity
  from auth.users
  where id = p_user_id;

  if coalesce(v_meta_identity, '') ~ '^[0-9]{6}$' then
    return v_meta_identity;
  end if;

  if p_user_id is null then
    return '000000';
  end if;

  v_hash := (('x' || substr(replace(p_user_id::text, '-', ''), 1, 14))::bit(56)::bigint);
  return lpad((100000 + (v_hash % 900000))::text, 6, '0');
end;
$_$;


--
-- Name: rs_sync_membership_fields(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rs_sync_membership_fields() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.points := greatest(coalesce(new.points, 0), 0);
  new.tier := case
    when new.points >= 5000 then 'platinum'
    when new.points >= 2000 then 'gold'
    when new.points >= 1000 then 'silver'
    else 'blue'
  end;
  new.chapter := coalesce(nullif(btrim(coalesce(new.chapter, '')), ''), 'Kigali Central');
  new.display_name := public.rs_resolve_public_identity(new.user_id, new.display_name);

  if coalesce(nullif(btrim(coalesce(new.membership_number, '')), ''), '') = '' then
    new.membership_number := 'RS-' ||
      to_char(coalesce(new.joined_at, now()), 'YYYY') ||
      '-' ||
      upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  end if;

  if tg_op = 'INSERT' then
    new.created_at := coalesce(new.created_at, now());
    new.joined_at := coalesce(new.joined_at, new.created_at, now());
  end if;

  new.updated_at := now();
  return new;
end;
$$;


--
-- Name: run_momo_sms_migration_safety_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.run_momo_sms_migration_safety_check() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_now timestamptz := now();
  v_legacy_completed_rows integer := 0;
  v_distinct_statuses integer := 0;
  v_sync_audit_rows integer := 0;
  v_status text := 'ok';
  v_severity text := 'info';
  v_issue_code text := 'migration_safety_verified';
  v_message text;
begin
  select
    count(*) filter (where status = 'completed')::integer,
    count(distinct status)::integer
    into v_legacy_completed_rows, v_distinct_statuses
  from public.group_contributions;

  select count(*)::integer
    into v_sync_audit_rows
  from public.momo_sms_sync_runs;

  if v_legacy_completed_rows > 0 then
    v_status := 'error';
    v_severity := 'critical';
    v_issue_code := 'legacy_completed_contribution_rows';
    v_message := format(
      '%s legacy group contribution rows still use completed instead of confirmed.',
      v_legacy_completed_rows
    );
  else
    v_message := format(
      'No legacy completed contribution rows remain. %s sync audit runs are currently stored.',
      v_sync_audit_rows
    );
  end if;

  insert into public.operational_health_events (
    service,
    component,
    status,
    severity,
    issue_code,
    message,
    subject_type,
    subject_id,
    metadata,
    occurred_at,
    ingest_origin
  )
  values (
    'sms_ingest',
    'momo_sms_migration_safety',
    v_status,
    v_severity,
    v_issue_code,
    v_message,
    'group_contributions',
    'completed_status_backfill',
    jsonb_build_object(
      'legacy_completed_rows',
      v_legacy_completed_rows,
      'distinct_statuses',
      v_distinct_statuses,
      'sync_audit_rows',
      v_sync_audit_rows
    ),
    v_now,
    'system'
  );

  return jsonb_build_object(
    'status',
    v_status,
    'issue_code',
    v_issue_code,
    'legacy_completed_rows',
    v_legacy_completed_rows,
    'distinct_statuses',
    v_distinct_statuses,
    'sync_audit_rows',
    v_sync_audit_rows,
    'executed_at',
    v_now
  );
end;
$$;


--
-- Name: send_rs_match_notification(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.send_rs_match_notification(p_match_id uuid, p_title text, p_body text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_notif_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.admin_role_assignments ara
    WHERE ara.user_id = auth.uid()
      AND ara.is_active = true
      AND (ara.role = 'admin' OR ara.role = 'rayon_sport')
  ) THEN
    RAISE EXCEPTION 'Unauthorized: Requires admin or rayon_sport role';
  END IF;

  INSERT INTO public.rs_notifications (match_id, title, body, status, sent_at, created_by)
  VALUES (p_match_id, p_title, p_body, 'sent', now(), auth.uid())
  RETURNING id INTO v_notif_id;

  RETURN v_notif_id;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := timezone('utc', now());
  RETURN NEW;
END;
$$;


--
-- Name: sync_admin_phone_access_from_auth_identity(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_admin_phone_access_from_auth_identity() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  IF TG_OP <> 'DELETE' AND NEW.provider = 'phone' THEN
    PERFORM public.refresh_admin_phone_access_for_user(NEW.user_id);
  END IF;

  IF TG_OP <> 'INSERT' AND OLD.provider = 'phone' THEN
    PERFORM public.refresh_admin_phone_access_for_user(OLD.user_id);
  END IF;

  RETURN NULL;
END;
$$;


--
-- Name: sync_admin_phone_access_from_auth_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_admin_phone_access_from_auth_user() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  PERFORM public.refresh_admin_phone_access_for_user(COALESCE(NEW.id, OLD.id));
  RETURN NULL;
END;
$$;


--
-- Name: sync_admin_phone_access_from_role_assignment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_admin_phone_access_from_role_assignment() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
BEGIN
  PERFORM public.refresh_admin_phone_access_for_user(COALESCE(NEW.user_id, OLD.user_id));

  IF TG_OP = 'UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    PERFORM public.refresh_admin_phone_access_for_user(OLD.user_id);
  END IF;

  RETURN NULL;
END;
$$;


--
-- Name: sync_cool_status_fields(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_cool_status_fields() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.total_points := greatest(coalesce(new.total_points, 0), 0);
  new.season_points := greatest(coalesce(new.season_points, 0), 0);
  new.current_streak := greatest(coalesce(new.current_streak, 0), 0);
  new.longest_streak := greatest(coalesce(new.longest_streak, 0), 0);
  new.streak_grace_remaining := greatest(coalesce(new.streak_grace_remaining, 0), 0);
  new.tier := public.cool_status_tier_for_points(new.total_points);

  if tg_op = 'insert' then
    new.created_at := coalesce(new.created_at, now());
  end if;

  new.updated_at := now();
  return new;
end;
$$;


--
-- Name: sync_driver_location(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_driver_location() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  if new.latitude is not null and new.longitude is not null then
    new.location := st_setsrid(st_makepoint(new.longitude, new.latitude), 4326)::geography;
  end if;
  return new;
end;
$$;


--
-- Name: sync_fan_club_member_scope(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_fan_club_member_scope() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.tenant_club_id IS NULL THEN
    SELECT club_id INTO NEW.tenant_club_id
      FROM public.fan_clubs
     WHERE id = NEW.club_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: sync_fan_membership_defaults(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_fan_membership_defaults() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.club_id IS NULL AND NEW.partner_id IS NOT NULL THEN
    NEW.club_id := public.compat_parse_partner_id(NEW.partner_id);
  END IF;

  IF NEW.partner_id IS NULL AND NEW.club_id IS NOT NULL THEN
    NEW.partner_id := NEW.club_id::text;
  END IF;

  IF NEW.display_name IS NULL OR btrim(NEW.display_name) = '' THEN
    SELECT COALESCE(NULLIF(btrim(display_name), ''), 'Fan')
      INTO NEW.display_name
      FROM public.profiles
     WHERE id = NEW.user_id;
    NEW.display_name := COALESCE(NEW.display_name, 'Fan');
  END IF;

  IF NEW.membership_number IS NULL OR btrim(NEW.membership_number) = '' THEN
    NEW.membership_number := 'FAN-' || replace(gen_random_uuid()::text, '-', '');
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: sync_group_financials(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_group_financials() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  target_group_id uuid := coalesce(new.group_id, old.group_id);
  target_user_id uuid := coalesce(new.user_id, old.user_id);
begin
  if target_group_id is null then
    return coalesce(new, old);
  end if;

  update public.groups
  set
    amount = coalesce((
      select sum(gc.amount)
      from public.group_contributions gc
      where gc.group_id = target_group_id
        and gc.status = 'confirmed'
    ), 0),
    updated_at = now()
  where id = target_group_id;

  update public.group_members gm
  set contribution_amount = coalesce((
    select sum(gc.amount)
    from public.group_contributions gc
    where gc.group_id = gm.group_id
      and gc.user_id = gm.user_id
      and gc.status = 'confirmed'
  ), 0)
  where gm.group_id = target_group_id
    and (target_user_id is null or gm.user_id = target_user_id);

  return coalesce(new, old);
end;
$$;


--
-- Name: sync_group_member_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_group_member_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
  target_group_id uuid := coalesce(new.group_id, old.group_id);
begin
  if target_group_id is null then
    return coalesce(new, old);
  end if;

  update public.groups
  set
    member_count = (
      select count(*)
      from public.group_members gm
      where gm.group_id = target_group_id
    ),
    updated_at = now()
  where id = target_group_id;

  return coalesce(new, old);
end;
$$;


--
-- Name: sync_initiative_contribution_scope(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_initiative_contribution_scope() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.club_id IS NULL THEN
    SELECT club_id INTO NEW.club_id
      FROM public.initiatives
     WHERE id = NEW.initiative_id;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: sync_mobility_country_from_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_mobility_country_from_user() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.country := 'RW';
  return new;
end;
$$;


--
-- Name: sync_mobility_trip_compat(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_mobility_trip_compat() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
begin
  new.user_id := coalesce(new.user_id, new.driver_id);
  new.driver_id := coalesce(new.driver_id, new.user_id);
  new.vehicle_type := coalesce(nullif(new.vehicle_type, ''), nullif(new.vehicle_preference, ''), 'any');
  new.vehicle_preference := coalesce(nullif(new.vehicle_preference, ''), nullif(new.vehicle_type, ''), 'any');
  new.seats := coalesce(new.seats, new.seats_needed, 1);
  new.seats_needed := coalesce(new.seats_needed, new.seats, 1);
  new.trip_type := coalesce(
    nullif(new.trip_type, ''),
    case
      when coalesce(new.is_driver_return_trip, false) then 'driver_return'
      else 'passenger'
    end
  );
  new.vehicle_emoji := coalesce(
    nullif(new.vehicle_emoji, ''),
    case lower(coalesce(new.vehicle_type, new.vehicle_preference, ''))
      when 'moto' then '🛺'
      when 'moto taxi' then '🛺'
      when 'cab' then '🚗'
      when 'truck' then '🚛'
      when 'trike' then '🚐'
      else '🚗'
    end
  );
  new.travel_time := coalesce(new.travel_time, new.departure_at);
  new.departure_at := coalesce(new.departure_at, new.travel_time);
  new.from_lat := coalesce(new.from_lat, new.latitude);
  new.from_lng := coalesce(new.from_lng, new.longitude);
  new.latitude := coalesce(new.latitude, new.from_lat);
  new.longitude := coalesce(new.longitude, new.from_lng);
  new.repeat_days := coalesce(new.repeat_days, new.recurring_days, '{}');
  new.recurring_days := coalesce(new.recurring_days, new.repeat_days, '{}');
  new.role := coalesce(
    nullif(new.role, ''),
    case
      when coalesce(new.is_driver_return_trip, false) then 'DRIVER'
      else 'PASSENGER'
    end
  );
  new.whatsapp_number := coalesce(nullif(new.whatsapp_number, ''), nullif(new.contact_phone, ''));
  new.status := lower(coalesce(nullif(new.status, ''), 'open'));
  new.expires_at := coalesce(new.expires_at, new.departure_at + interval '1 hour');
  new.updated_at := now();

  if coalesce(new.latitude, new.from_lat) is not null
     and coalesce(new.longitude, new.from_lng) is not null then
    new.origin_geo := st_setsrid(
      st_makepoint(
        coalesce(new.longitude, new.from_lng),
        coalesce(new.latitude, new.from_lat)
      ),
      4326
    )::extensions.geography;
  end if;

  return new;
end;
$$;


--
-- Name: sync_mobility_trip_contact(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_mobility_trip_contact() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
declare
  profile_phone text;
  profile_name text;
begin
  if new.user_id is null then
    return new;
  end if;

  select u.phone, u.public_user_id
  into profile_phone, profile_name
  from public.users u
  where u.id = new.user_id;

  new.contact_phone := coalesce(nullif(new.contact_phone, ''), profile_phone);
  new.contact_name := coalesce(profile_name, nullif(new.contact_name, ''));
  return new;
end;
$$;


--
-- Name: sync_partner_club_columns(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_partner_club_columns() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.club_id IS NULL AND NEW.partner_id IS NOT NULL THEN
    NEW.club_id := public.compat_parse_partner_id(NEW.partner_id);
  END IF;

  IF NEW.partner_id IS NULL AND NEW.club_id IS NOT NULL THEN
    NEW.partner_id := NEW.club_id::text;
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: sync_profile_compat_columns(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_profile_compat_columns() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  NEW.display_name := COALESCE(
    NULLIF(btrim(NEW.display_name), ''),
    NULLIF(btrim(NEW.full_name), '')
  );
  NEW.full_name := COALESCE(
    NULLIF(btrim(NEW.full_name), ''),
    NEW.display_name
  );

  NEW.country_code := COALESCE(
    NULLIF(upper(btrim(NEW.country_code)), ''),
    NULLIF(upper(btrim(NEW.country)), '')
  );
  NEW.country := COALESCE(
    NULLIF(upper(btrim(NEW.country)), ''),
    NEW.country_code
  );

  -- Private contact details now live in public.user_private_contacts.
  NEW.momo_number := NULL;
  NEW.phone := NULL;

  NEW.language_code := COALESCE(NULLIF(btrim(NEW.language_code), ''), 'en');
  NEW.is_active := COALESCE(NEW.is_active, true);
  RETURN NEW;
END;
$$;


--
-- Name: sync_ticket_scope(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.sync_ticket_scope() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.club_id IS NULL THEN
    SELECT club_id INTO NEW.club_id
      FROM public.matches
     WHERE id = NEW.match_id;
  END IF;

  IF NEW.qr_code IS NULL OR btrim(NEW.qr_code) = '' THEN
    NEW.qr_code := 'AFC-' || replace(gen_random_uuid()::text, '-', '');
  END IF;

  RETURN NEW;
END;
$$;


--
-- Name: unallocate_transaction(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unallocate_transaction(p_ledger_id uuid, p_group_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'auth'
    AS $$
declare
  v_ledger public.momo_ledger_entries%rowtype;
  v_caller_id uuid := auth.uid();
  v_is_group_admin boolean;
  v_now timestamptz := now();
begin
  -- Validate input
  if p_ledger_id is null then
    raise exception 'Ledger entry id is required.';
  end if;
  if p_group_id is null then
    raise exception 'Group id is required.';
  end if;

  -- Check caller is a group admin or app admin
  select exists(
    select 1
    from public.group_members gm
    where gm.group_id = p_group_id
      and gm.user_id = v_caller_id
      and gm.is_admin = true
  ) into v_is_group_admin;

  if not v_is_group_admin and not public.is_admin() then
    raise exception 'You must be a group admin to unallocate transactions.';
  end if;

  -- Lock and fetch the ledger entry
  select *
  into v_ledger
  from public.momo_ledger_entries
  where id = p_ledger_id
  for update;

  if not found then
    raise exception 'Ledger entry not found.';
  end if;

  -- Verify it's actually allocated to this group
  if v_ledger.target_record_id::text <> p_group_id::text then
    raise exception 'This ledger entry is not allocated to the specified group.';
  end if;

  -- Revert to wallet scope
  update public.momo_ledger_entries
  set
    target_table = null,
    target_record_id = null,
    ledger_scope = 'wallet',
    ledger_status = 'draft',
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'unallocated_from_group', p_group_id,
      'unallocation_actor_id', v_caller_id,
      'unallocation_source', 'group_admin',
      'unallocated_at', v_now
    ),
    updated_at = v_now
  where id = p_ledger_id;

  return jsonb_build_object(
    'status', 'success',
    'ledger_id', p_ledger_id,
    'group_id', p_group_id
  );
end;
$$;


--
-- Name: FUNCTION unallocate_transaction(p_ledger_id uuid, p_group_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.unallocate_transaction(p_ledger_id uuid, p_group_id uuid) IS 'Group-admin action: remove group allocation from a ledger entry, reverting to wallet scope.';


--
-- Name: update_fan_club_member_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_fan_club_member_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.fan_clubs
       SET member_count = member_count + 1,
           updated_at = timezone('utc', now())
     WHERE id = NEW.club_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.fan_clubs
       SET member_count = GREATEST(0, member_count - 1),
           updated_at = timezone('utc', now())
     WHERE id = OLD.club_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: update_group_member_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_group_member_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ begin update public.groups set member_count = (select count(*) from public.group_members gm where gm.group_id = coalesce(new.group_id, old.group_id)), updated_at = now() where id = coalesce(new.group_id, old.group_id); return coalesce(new, old); end; $$;


--
-- Name: update_group_savings_settings(uuid, text, text, integer, integer, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_group_savings_settings(p_group_id uuid, p_name text DEFAULT NULL::text, p_description text DEFAULT NULL::text, p_target_amount integer DEFAULT NULL::integer, p_monthly_contribution integer DEFAULT NULL::integer, p_frequency text DEFAULT NULL::text, p_receiving_momo_route_type text DEFAULT NULL::text, p_recipient_value text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_group public.groups%rowtype;
  v_name text;
  v_description text;
  v_frequency text;
  v_route_type text;
  v_recipient text;
begin
  if p_group_id is null then
    return jsonb_build_object(
      'status', 'error',
      'message', 'Group id is required.'
    );
  end if;

  if auth.uid() is null or not public.can_manage_group_settings(p_group_id) then
    return jsonb_build_object(
      'status', 'error',
      'message', 'Not authorized to update this group.'
    );
  end if;

  select *
    into v_group
    from public.groups
   where id = p_group_id
   for update;

  if not found then
    return jsonb_build_object(
      'status', 'error',
      'message', 'Group not found.'
    );
  end if;

  if p_target_amount is not null and p_target_amount < 0 then
    return jsonb_build_object(
      'status', 'error',
      'message', 'Target amount must be zero or greater.'
    );
  end if;

  if p_monthly_contribution is not null and p_monthly_contribution < 0 then
    return jsonb_build_object(
      'status', 'error',
      'message', 'Contribution amount must be zero or greater.'
    );
  end if;

  v_name := nullif(btrim(coalesce(p_name, v_group.name)), '');
  if v_name is null then
    return jsonb_build_object(
      'status', 'error',
      'message', 'Group name is required.'
    );
  end if;

  v_description := case
    when p_description is null then v_group.description
    else nullif(btrim(p_description), '')
  end;

  v_frequency := case
    when p_frequency is null then v_group.frequency
    else nullif(lower(btrim(p_frequency)), '')
  end;

  if v_frequency is not null
     and v_frequency not in ('daily', 'weekly', 'monthly', 'one_off') then
    return jsonb_build_object(
      'status', 'error',
      'message', 'Unsupported frequency.'
    );
  end if;

  v_route_type := case
    when p_receiving_momo_route_type is null then v_group.receiving_momo_route_type
    else nullif(lower(btrim(p_receiving_momo_route_type)), '')
  end;

  if v_route_type is not null and v_route_type not in ('phone_number', 'code') then
    return jsonb_build_object(
      'status', 'error',
      'message', 'Unsupported receiving_momo_route_type.'
    );
  end if;

  v_recipient := case
    when p_recipient_value is null then
      coalesce(
        nullif(btrim(coalesce(v_group.receiving_momo_code, '')), ''),
        nullif(btrim(coalesce(v_group.momo_number, '')), '')
      )
    else
      nullif(btrim(p_recipient_value), '')
  end;

  update public.groups
     set name = v_name,
         description = v_description,
         target_amount = coalesce(p_target_amount, target_amount),
         monthly_contribution = coalesce(p_monthly_contribution, monthly_contribution),
         frequency = coalesce(v_frequency, frequency),
         receiving_momo_route_type = v_route_type,
         receiving_momo_code = case
           when v_route_type = 'code' then v_recipient
           when v_route_type = 'phone_number' then null
           else receiving_momo_code
         end,
         momo_number = case
           when v_route_type = 'phone_number' then v_recipient
           when v_route_type = 'code' then null
           else momo_number
         end,
         updated_at = now()
   where id = p_group_id
   returning * into v_group;

  return jsonb_build_object(
    'status', 'success',
    'group_id', v_group.id::text
  );
end;
$$;


--
-- Name: update_group_totals(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_group_totals() RETURNS trigger
    LANGUAGE plpgsql
    AS $$ begin update public.groups set current_total = coalesce((select sum(gc.amount) from public.group_contributions gc where gc.group_id = coalesce(new.group_id, old.group_id) and gc.status = 'confirmed'), 0), updated_at = now() where id = coalesce(new.group_id, old.group_id); return coalesce(new, old); end; $$;


--
-- Name: user_has_role_for_partner(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_has_role_for_partner(p_partner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.admin_role_assignments
    where user_id = auth.uid()
      and is_active = true
      and (
        -- Platform admins can access everything
        role = 'admin'
        -- Scoped admins can access their partner
        or partner_scope_id = p_partner_id
      )
  )
  or exists (
    -- Legacy fallback: check is_admin flag
    select 1 from public.users
    where id = auth.uid() and is_admin = true
  );
$$;


--
-- Name: user_is_bank_admin_for(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_is_bank_admin_for(p_partner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.admin_role_assignments
    where user_id = auth.uid()
      and is_active = true
      and role in ('admin', 'bank')
      and (role = 'admin' or partner_scope_id = p_partner_id)
  )
  or exists (
    select 1 from public.users
    where id = auth.uid() and is_admin = true
  );
$$;


--
-- Name: user_is_rayon_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_is_rayon_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  select exists (
    select 1 from public.admin_role_assignments
    where user_id = auth.uid()
      and is_active = true
      and role in ('admin', 'rayon_sport')
  )
  or exists (
    select 1 from public.users
    where id = auth.uid() and is_admin = true
  );
$$;


--
-- Name: achievements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.achievements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    partner_id uuid NOT NULL,
    badge_type text NOT NULL,
    earned_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    emoji text DEFAULT '🏆'::text NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    is_earned boolean DEFAULT true NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    club_id bigint
);


--
-- Name: COLUMN achievements.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.achievements.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN achievements.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.achievements.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: admin_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_audit_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    target_table text NOT NULL,
    target_id text,
    old_data jsonb,
    new_data jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    notes text,
    user_id uuid,
    club_id bigint,
    entity_type text,
    entity_id text,
    metadata jsonb DEFAULT '{}'::jsonb
);


--
-- Name: TABLE admin_audit_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.admin_audit_log IS 'Tracks admin actions for accountability and debugging.';


--
-- Name: admin_phone_access; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_phone_access (
    user_id uuid NOT NULL,
    phone text NOT NULL,
    normalized_phone text NOT NULL,
    club_ids bigint[] DEFAULT '{}'::bigint[] NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: TABLE admin_phone_access; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.admin_phone_access IS 'Server-side lookup table of admin-approved WhatsApp numbers for OTP gating.';


--
-- Name: admin_role_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_role_assignments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    role text NOT NULL,
    partner_scope_id uuid,
    granted_by uuid,
    granted_at timestamp with time zone DEFAULT now() NOT NULL,
    revoked_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    notes text,
    club_id bigint,
    CONSTRAINT admin_role_assignments_role_check CHECK ((role = ANY (ARRAY['admin'::text, 'bank'::text, 'rayon_sport'::text])))
);


--
-- Name: african_football_clubs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.african_football_clubs (
    id bigint NOT NULL,
    club_name text NOT NULL,
    country_name text NOT NULL,
    country_flag text DEFAULT ''::text NOT NULL,
    country_iso_code text,
    country_population bigint DEFAULT 0 NOT NULL,
    football_penetration numeric(5,2) DEFAULT 0 NOT NULL,
    club_market_share numeric(5,2) DEFAULT 0 NOT NULL,
    estimated_fan_base bigint DEFAULT 0 NOT NULL,
    market_research_note text,
    is_onboarded boolean DEFAULT false NOT NULL,
    onboarding_priority smallint,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    region text,
    league text,
    primary_brand_colors text,
    nickname_brand_identity text,
    official_contact text,
    facebook_url text,
    x_twitter_url text,
    instagram_url text,
    tiktok_url text,
    official_logo_url text,
    club_slug text,
    momo_prefix text,
    momo_ussd_template text,
    momo_sender_name text,
    currency_code text DEFAULT 'USD'::text NOT NULL,
    currency_symbol text DEFAULT '$'::text NOT NULL,
    default_language text DEFAULT 'en'::text NOT NULL,
    primary_color_hex text,
    secondary_color_hex text,
    accent_color_hex text,
    supported_languages text[] DEFAULT '{en}'::text[] NOT NULL,
    feature_flags jsonb DEFAULT '{"chat": true, "shop": true, "biopay": true, "fan_clubs": true, "ticketing": true, "sms_ledger": true}'::jsonb NOT NULL
);


--
-- Name: TABLE african_football_clubs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.african_football_clubs IS 'Master registry of African football clubs with market research data (fan base estimates, penetration rates, market share).';


--
-- Name: COLUMN african_football_clubs.club_slug; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.african_football_clubs.club_slug IS 'URL-safe tenant slug e.g. rayon_sports_rw — used as ClubConfig.clubId and JWT claim';


--
-- Name: COLUMN african_football_clubs.momo_ussd_template; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.african_football_clubs.momo_ussd_template IS 'USSD template e.g. *182*8*1*{amount}*{momo}# — placeholders: {amount}, {momo}';


--
-- Name: african_football_clubs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.african_football_clubs ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.african_football_clubs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ai_content; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_content (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    content_type public.ai_content_type DEFAULT 'recommendation'::public.ai_content_type NOT NULL,
    title text NOT NULL,
    subtitle text DEFAULT ''::text NOT NULL,
    body text DEFAULT ''::text,
    rationale text DEFAULT ''::text,
    icon_emoji text DEFAULT '✨'::text,
    cta_action text DEFAULT ''::text,
    cta_label text DEFAULT ''::text,
    country text,
    sort_order integer DEFAULT 0 NOT NULL,
    status public.ai_content_status DEFAULT 'draft'::public.ai_content_status NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_by uuid,
    reviewed_by uuid,
    reviewed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE ai_content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.ai_content IS 'AI-generated UI content with admin approval workflow';


--
-- Name: ai_content_generation_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ai_content_generation_config (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    is_enabled boolean DEFAULT false NOT NULL,
    interval_hours integer DEFAULT 12 NOT NULL,
    last_generated_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now(),
    updated_by uuid
);


--
-- Name: app_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_config (
    key text NOT NULL,
    value text NOT NULL,
    description text,
    country text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT app_config_country_local_scope_check CHECK (((country IS NULL) OR (country = 'RW'::text)))
);


--
-- Name: biopay_embeddings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_embeddings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    payee_id uuid NOT NULL,
    embedding extensions.vector(128) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    model_name text DEFAULT 'mobilefacenet'::text NOT NULL,
    model_version text DEFAULT 'int8_v1'::text NOT NULL,
    quality_score double precision,
    capture_device text DEFAULT 'unknown'::text NOT NULL,
    liveness_method text DEFAULT 'none'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    revoked_at timestamp with time zone
);


--
-- Name: biopay_enrollment_audits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_enrollment_audits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid NOT NULL,
    user_id uuid NOT NULL,
    event_type text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    club_id bigint
);


--
-- Name: biopay_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    event_type text NOT NULL,
    status text NOT NULL,
    scan_method text NOT NULL,
    payee_id uuid,
    actor_supabase_uid uuid,
    score double precision,
    message text DEFAULT ''::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT biopay_events_method_chk CHECK ((scan_method = ANY (ARRAY['face'::text, 'qr'::text, 'nfc'::text, 'system'::text]))),
    CONSTRAINT biopay_events_status_chk CHECK ((status = ANY (ARRAY['success'::text, 'no-match'::text, 'error'::text, 'info'::text]))),
    CONSTRAINT biopay_events_type_chk CHECK ((event_type = ANY (ARRAY['enroll'::text, 'match'::text, 'reindex'::text, 'profile-update'::text, 'qr-scan'::text, 'nfc-session'::text, 'data-deletion'::text])))
);


--
-- Name: biopay_liveness_challenges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_liveness_challenges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    club_id bigint NOT NULL,
    mode text NOT NULL,
    nonce text NOT NULL,
    issued_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    consumed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT biopay_liveness_challenges_mode_check CHECK ((mode = ANY (ARRAY['enrollment'::text, 'payment'::text])))
);


--
-- Name: biopay_match_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_match_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    requester_user_id uuid NOT NULL,
    matched_profile_id uuid,
    matched boolean DEFAULT false NOT NULL,
    score double precision DEFAULT 0 NOT NULL,
    threshold_used double precision DEFAULT 0.72 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    club_id bigint NOT NULL
);


--
-- Name: biopay_match_rate_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_match_rate_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    requester_user_id uuid NOT NULL,
    scope text NOT NULL,
    actor_key text NOT NULL,
    outcome text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT biopay_match_rate_events_outcome_check CHECK ((outcome = ANY (ARRAY['match'::text, 'miss'::text, 'blocked_user_rate_limit'::text, 'blocked_ip_rate_limit'::text, 'lockout_started'::text, 'blocked_lockout'::text]))),
    CONSTRAINT biopay_match_rate_events_scope_check CHECK ((scope = ANY (ARRAY['user'::text, 'ip'::text])))
);


--
-- Name: TABLE biopay_match_rate_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.biopay_match_rate_events IS 'Service-role-only BioPay match risk and rate-limit telemetry keyed by hashed user and IP actors.';


--
-- Name: biopay_nfc_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_nfc_tokens (
    token text NOT NULL,
    payee_id uuid NOT NULL,
    actor_supabase_uid uuid,
    expires_at timestamp with time zone NOT NULL,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT biopay_nfc_tokens_token_chk CHECK ((length(token) >= 16))
);


--
-- Name: biopay_payees; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_payees (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    biopay_id text DEFAULT public.generate_biopay_id() NOT NULL,
    display_name text NOT NULL,
    ussd_string text NOT NULL,
    supabase_uid uuid,
    enrolled_at timestamp with time zone DEFAULT now() NOT NULL,
    consent_ts timestamp with time zone NOT NULL,
    CONSTRAINT biopay_payees_biopay_id_format_chk CHECK ((biopay_id ~ '^[0-9]{6}$'::text)),
    CONSTRAINT biopay_payees_display_name_chk CHECK ((length(btrim(display_name)) > 0)),
    CONSTRAINT biopay_payees_ussd_chk CHECK ((ussd_string ~ '^\*[0-9]+(\*[0-9]+)*#$'::text))
);


--
-- Name: biopay_payment_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_payment_intents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    profile_id uuid NOT NULL,
    match_score double precision NOT NULL,
    recipient_value text NOT NULL,
    route_type text NOT NULL,
    payment_code text NOT NULL,
    nonce text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    dialed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    club_id bigint NOT NULL,
    CONSTRAINT biopay_payment_intents_route_type_check CHECK ((route_type = ANY (ARRAY['phone_number'::text, 'code'::text]))),
    CONSTRAINT biopay_payment_intents_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'dialed'::text, 'expired'::text, 'cancelled'::text])))
);


--
-- Name: biopay_profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_profiles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    public_id text DEFAULT public.generate_biopay_public_id() NOT NULL,
    user_id uuid NOT NULL,
    display_name text NOT NULL,
    route_type text NOT NULL,
    recipient_value text NOT NULL,
    country_code text DEFAULT 'RW'::text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    consent_version text DEFAULT 'biopay-v1'::text NOT NULL,
    consent_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    revoked_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    club_id bigint,
    CONSTRAINT biopay_profiles_route_type_check CHECK ((route_type = ANY (ARRAY['phone_number'::text, 'code'::text])))
);


--
-- Name: biopay_revocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_revocations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    profile_id uuid NOT NULL,
    user_id uuid NOT NULL,
    reason text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    club_id bigint
);


--
-- Name: biopay_user_preferences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_user_preferences (
    supabase_uid uuid NOT NULL,
    preferred_momo_value text DEFAULT ''::text NOT NULL,
    preferred_momo_type text DEFAULT 'number'::text NOT NULL,
    preferred_ussd_code text DEFAULT '*182*1*1*'::text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT biopay_user_preferences_type_chk CHECK ((preferred_momo_type = ANY (ARRAY['number'::text, 'code'::text]))),
    CONSTRAINT biopay_user_preferences_ussd_code_chk CHECK ((preferred_ussd_code ~ '^\*[0-9]+(\*[0-9]+)*\*$'::text))
);


--
-- Name: biopay_web_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_web_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_supabase_uid uuid,
    event_type text NOT NULL,
    route text DEFAULT '/app/'::text NOT NULL,
    status text DEFAULT 'info'::text NOT NULL,
    source text DEFAULT 'pwa'::text NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT biopay_web_events_source_chk CHECK ((source = ANY (ARRAY['pwa'::text, 'landing'::text, 'service-worker'::text]))),
    CONSTRAINT biopay_web_events_status_chk CHECK ((status = ANY (ARRAY['success'::text, 'dismissed'::text, 'error'::text, 'info'::text]))),
    CONSTRAINT biopay_web_events_type_chk CHECK ((event_type = ANY (ARRAY['install_prompt_impression'::text, 'install_prompt_result'::text, 'shortcut_saved'::text, 'shortcut_shared'::text, 'support_request'::text, 'notification_opt_in'::text, 'web_vital'::text])))
);


--
-- Name: biopay_web_push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.biopay_web_push_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    actor_supabase_uid uuid,
    endpoint text NOT NULL,
    p256dh text NOT NULL,
    auth text NOT NULL,
    expiration_time timestamp with time zone,
    route text DEFAULT '/app/install/'::text NOT NULL,
    user_agent text DEFAULT ''::text NOT NULL,
    subscription jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contributions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    club_id bigint NOT NULL,
    amount integer NOT NULL,
    currency text DEFAULT 'RWF'::text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    payment_method text DEFAULT 'momo'::text NOT NULL,
    external_ref text,
    ledger_entry_id uuid,
    note text,
    confirmed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contributions_amount_check CHECK ((amount > 0)),
    CONSTRAINT contributions_payment_method_check CHECK ((payment_method = ANY (ARRAY['momo'::text, 'cash'::text, 'bank'::text, 'nfc'::text]))),
    CONSTRAINT contributions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'failed'::text, 'reversed'::text])))
);


--
-- Name: cool_achievements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_achievements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    achievement_id text NOT NULL,
    badge_type text DEFAULT 'blue'::text NOT NULL,
    emoji text DEFAULT '🏆'::text NOT NULL,
    name text NOT NULL,
    description text,
    feature_context text,
    points_value integer DEFAULT 0,
    is_earned boolean DEFAULT false,
    earned_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    club_id bigint
);


--
-- Name: cool_activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_activities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    emoji text DEFAULT '⭐'::text NOT NULL,
    category text DEFAULT 'general'::text NOT NULL,
    tokens_awarded integer DEFAULT 20 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE cool_activities; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cool_activities IS 'Admin-managed catalog of all token-earning activities. Each activity defines what users can do to earn Cool Tokens.';


--
-- Name: cool_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    event_type text NOT NULL,
    source_id text,
    points_awarded integer DEFAULT 0,
    metadata jsonb DEFAULT '{}'::jsonb,
    referrer_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    dedupe_key text,
    campaign_id text,
    season_id uuid,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    club_id bigint,
    xp_awarded integer DEFAULT 0 NOT NULL,
    event_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE cool_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cool_events IS 'Event log for all point-awarding actions.';


--
-- Name: COLUMN cool_events.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_events.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN cool_events.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_events.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: cool_invite_attributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_invite_attributions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    inviter_id uuid NOT NULL,
    invitee_id uuid NOT NULL,
    qualifying_event_type text,
    qualifying_event_id uuid,
    points_awarded_inviter integer DEFAULT 0,
    points_awarded_invitee integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE cool_invite_attributions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cool_invite_attributions IS 'Double-sided invite tracking for qualified referrals.';


--
-- Name: cool_mission_progress; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_mission_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    mission_id uuid NOT NULL,
    user_id uuid NOT NULL,
    contribution_value integer DEFAULT 0 NOT NULL,
    completed_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text
);


--
-- Name: TABLE cool_mission_progress; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cool_mission_progress IS 'Per-user contribution tracking toward mission goals.';


--
-- Name: COLUMN cool_mission_progress.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_mission_progress.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN cool_mission_progress.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_mission_progress.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: cool_missions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_missions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    season_id uuid,
    title text NOT NULL,
    description text,
    mission_type text NOT NULL,
    target_value integer NOT NULL,
    scope_type text DEFAULT 'global'::text NOT NULL,
    scope_id text,
    emoji text DEFAULT '🎯'::text,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    reward_points integer DEFAULT 0,
    reward_description text,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    club_id bigint
);


--
-- Name: TABLE cool_missions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cool_missions IS 'Time-bound cooperative missions (savings sprints, supporter seasons, etc.).';


--
-- Name: COLUMN cool_missions.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_missions.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN cool_missions.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_missions.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: cool_reward_redemptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_reward_redemptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    reward_id uuid NOT NULL,
    cost_at_redemption integer NOT NULL,
    redeemed_at timestamp with time zone DEFAULT now() NOT NULL,
    club_id bigint
);


--
-- Name: cool_rewards; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_rewards (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    token_cost integer NOT NULL,
    emoji text DEFAULT '🎁'::text NOT NULL,
    partner_id uuid,
    is_active boolean DEFAULT true,
    expiry_date timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: cool_seasons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.cool_seasons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    theme text NOT NULL,
    emoji text DEFAULT '🏅'::text,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    is_active boolean DEFAULT false,
    rewards_description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text
);


--
-- Name: TABLE cool_seasons; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.cool_seasons IS 'Time-limited engagement campaigns (2-4 weeks).';


--
-- Name: COLUMN cool_seasons.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_seasons.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN cool_seasons.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.cool_seasons.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.countries (
    id text NOT NULL,
    name text NOT NULL,
    flag text DEFAULT ''::text NOT NULL,
    dialing_code text NOT NULL,
    currency text DEFAULT 'RWF'::text NOT NULL,
    phone_placeholder text DEFAULT '780 000 000'::text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    telecom_provider text DEFAULT ''::text NOT NULL,
    momo_brand text DEFAULT ''::text NOT NULL,
    ussd_number_format text DEFAULT ''::text NOT NULL,
    ussd_code_format text DEFAULT ''::text NOT NULL,
    currency_name text DEFAULT ''::text NOT NULL
);


--
-- Name: driver_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.driver_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    driver_id uuid NOT NULL,
    plan text NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    started_at timestamp with time zone,
    expires_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    plan_id text,
    plan_name text,
    amount_rwf integer,
    momo_reference text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    CONSTRAINT driver_subscriptions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'active'::text, 'expired'::text, 'cancelled'::text])))
);


--
-- Name: COLUMN driver_subscriptions.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.driver_subscriptions.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN driver_subscriptions.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.driver_subscriptions.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: edge_function_rate_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.edge_function_rate_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    function_name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: fan_club_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fan_club_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    club_id uuid NOT NULL,
    user_id uuid NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    tenant_club_id bigint
);


--
-- Name: COLUMN fan_club_members.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fan_club_members.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN fan_club_members.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fan_club_members.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: fan_clubs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fan_clubs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    name text NOT NULL,
    region text DEFAULT 'Kigali'::text NOT NULL,
    description text,
    member_count integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    event_count integer DEFAULT 0 NOT NULL,
    rating numeric(3,2) DEFAULT 0 NOT NULL,
    banner_emoji text DEFAULT '🥁'::text NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    club_id bigint,
    banner_image_url text,
    is_active boolean DEFAULT true NOT NULL,
    CONSTRAINT rs_fan_clubs_check_event_count CHECK ((event_count >= 0)),
    CONSTRAINT rs_fan_clubs_check_rating CHECK (((rating >= (0)::numeric) AND (rating <= (5)::numeric)))
);


--
-- Name: fan_engagement_token_catalog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fan_engagement_token_catalog (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    club_id bigint NOT NULL,
    code text NOT NULL,
    template_scope text DEFAULT 'generic'::text NOT NULL,
    category text DEFAULT 'General'::text NOT NULL,
    item_name text DEFAULT 'Fan engagement reward'::text NOT NULL,
    fet_value integer DEFAULT 0 NOT NULL,
    trigger_condition text DEFAULT 'Defined by club operations.'::text NOT NULL,
    activation_timing text DEFAULT 'Always on'::text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    badge_name text DEFAULT ''::text NOT NULL,
    implementation_notes text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT fan_engagement_token_catalog_fet_value_check CHECK ((fet_value >= 0)),
    CONSTRAINT fan_engagement_token_catalog_sort_order_check CHECK ((sort_order >= 0)),
    CONSTRAINT fan_engagement_token_catalog_template_scope_check CHECK ((template_scope = ANY (ARRAY['generic'::text, 'club_specific'::text])))
);


--
-- Name: group_contributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_contributions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    momo_reference text,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    CONSTRAINT group_contributions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'failed'::text])))
);


--
-- Name: COLUMN group_contributions.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.group_contributions.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN group_contributions.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.group_contributions.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: group_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid NOT NULL,
    user_id uuid NOT NULL,
    display_name text,
    is_admin boolean DEFAULT false,
    is_anonymous boolean DEFAULT false,
    contribution_amount integer DEFAULT 0,
    joined_at timestamp with time zone DEFAULT now(),
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text
);


--
-- Name: COLUMN group_members.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.group_members.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN group_members.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.group_members.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: group_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    group_id uuid,
    sender_id uuid,
    alias character(6),
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    club_id bigint,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    creator_id uuid,
    name text NOT NULL,
    description text,
    group_type text DEFAULT 'community'::text NOT NULL,
    privacy text DEFAULT 'public'::text NOT NULL,
    target_amount numeric(12,2) DEFAULT 0,
    current_total numeric(12,2) DEFAULT 0,
    momo_code text,
    deadline timestamp with time zone,
    is_recurring boolean DEFAULT false,
    is_closed boolean DEFAULT false,
    invite_code text DEFAULT public.generate_invite_code(),
    member_count integer DEFAULT 1,
    created_at timestamp with time zone DEFAULT now(),
    club_id bigint,
    partner_id text,
    currency text DEFAULT 'RWF'::text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    country text DEFAULT 'RW'::text NOT NULL,
    visibility text DEFAULT 'private'::text NOT NULL,
    type text DEFAULT 'saving'::text NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    monthly_contribution integer,
    bank_partner_id text,
    momo_number text,
    frequency text,
    receiving_momo_route_type text,
    receiving_momo_code text,
    cycle_days integer DEFAULT 30 NOT NULL,
    contribution_amount integer DEFAULT 0 NOT NULL
);


--
-- Name: home_banners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.home_banners (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    subtitle text,
    badge_label text,
    cta_label text DEFAULT 'LEARN MORE'::text NOT NULL,
    route text DEFAULT '/'::text NOT NULL,
    image_url text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: initiative_contributions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.initiative_contributions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    initiative_id uuid NOT NULL,
    user_id uuid NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    momo_reference text,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    referral_invite_id uuid,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    supporter_name text,
    confirmed_at timestamp with time zone,
    club_id bigint,
    CONSTRAINT rs_initiative_contributions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'failed'::text, 'cancelled'::text])))
);


--
-- Name: COLUMN initiative_contributions.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.initiative_contributions.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN initiative_contributions.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.initiative_contributions.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: initiatives; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.initiatives (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    title text NOT NULL,
    description text,
    category text NOT NULL,
    target_amount integer DEFAULT 0 NOT NULL,
    raised_amount integer DEFAULT 0 NOT NULL,
    supporter_count integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    ends_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    club_id bigint,
    goal_amount integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'active'::text NOT NULL
);


--
-- Name: matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.matches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    home_team text NOT NULL,
    away_team text NOT NULL,
    competition text NOT NULL,
    venue text NOT NULL,
    match_date date NOT NULL,
    kickoff_time time without time zone NOT NULL,
    is_on_sale boolean DEFAULT true NOT NULL,
    ticket_general_price integer DEFAULT 0 NOT NULL,
    ticket_vip_price integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    sale_starts_at timestamp with time zone DEFAULT now() NOT NULL,
    capacity integer DEFAULT 0 NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    sold_count integer DEFAULT 0 NOT NULL,
    image_url text,
    club_id bigint,
    roster text[] DEFAULT '{}'::text[] NOT NULL,
    match_status text DEFAULT 'scheduled'::text NOT NULL,
    home_score integer DEFAULT 0 NOT NULL,
    away_score integer DEFAULT 0 NOT NULL,
    live_minute integer,
    match_summary text,
    live_stats jsonb DEFAULT '{}'::jsonb NOT NULL,
    live_events jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_featured boolean DEFAULT false NOT NULL,
    CONSTRAINT rs_matches_check_capacity CHECK ((capacity >= 0))
);


--
-- Name: COLUMN matches.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.matches.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN matches.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.matches.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: membership_packages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.membership_packages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    tier text NOT NULL,
    title text NOT NULL,
    subtitle text NOT NULL,
    description text,
    benefits jsonb DEFAULT '[]'::jsonb NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    club_id bigint,
    annual_price numeric(12,2) DEFAULT 0,
    price numeric(12,2) DEFAULT 0,
    CONSTRAINT rs_membership_packages_tier_check CHECK ((tier = ANY (ARRAY['blue'::text, 'silver'::text, 'gold'::text, 'platinum'::text])))
);


--
-- Name: momo_ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_ledger_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parsed_sms_id uuid NOT NULL,
    user_id uuid NOT NULL,
    entry_type text NOT NULL,
    ledger_scope text DEFAULT 'wallet'::text NOT NULL,
    ledger_status text DEFAULT 'draft'::text NOT NULL,
    amount integer NOT NULL,
    currency text DEFAULT 'RWF'::text NOT NULL,
    tx_datetime timestamp with time zone,
    external_reference text,
    target_table text,
    target_record_id uuid,
    description text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    tx_category text DEFAULT 'uncategorized'::text NOT NULL,
    cashflow_bucket text DEFAULT 'unknown'::text NOT NULL,
    counterparty_name text,
    statement_label text,
    payee_group_id uuid,
    payee_partner_id uuid,
    country_code text,
    club_id bigint,
    CONSTRAINT momo_ledger_entries_cashflow_bucket_check CHECK ((cashflow_bucket = ANY (ARRAY['income'::text, 'expense'::text, 'savings'::text, 'transfer'::text, 'loan'::text, 'fees'::text, 'unknown'::text]))),
    CONSTRAINT momo_ledger_entries_status_check CHECK ((ledger_status = ANY (ARRAY['draft'::text, 'posted'::text, 'reversed'::text]))),
    CONSTRAINT momo_ledger_entries_type_check CHECK ((entry_type = ANY (ARRAY['credit'::text, 'debit'::text])))
);


--
-- Name: COLUMN momo_ledger_entries.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_ledger_entries.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN momo_ledger_entries.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_ledger_entries.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: momo_parse_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_parse_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    raw_sms_id uuid NOT NULL,
    user_id uuid NOT NULL,
    provider text NOT NULL,
    model text NOT NULL,
    attempt_number integer DEFAULT 1 NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    prompt_version text DEFAULT 'v1'::text NOT NULL,
    request_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    response_payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    error_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    payloads_redacted_at timestamp with time zone,
    club_id bigint,
    CONSTRAINT momo_parse_attempts_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'success'::text, 'failed'::text])))
);


--
-- Name: COLUMN momo_parse_attempts.payloads_redacted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_parse_attempts.payloads_redacted_at IS 'When stored AI request/response payloads were cleared to minimize long-term retention of sensitive SMS context.';


--
-- Name: momo_reconciliations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_reconciliations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    parsed_sms_id uuid NOT NULL,
    user_id uuid NOT NULL,
    target_table text,
    target_record_id uuid,
    match_type text DEFAULT 'ai_match'::text NOT NULL,
    match_status text DEFAULT 'pending_review'::text NOT NULL,
    confidence numeric(5,4),
    notes text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    reconciled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    country_code text,
    club_id bigint,
    CONSTRAINT momo_reconciliations_status_check CHECK ((match_status = ANY (ARRAY['pending_review'::text, 'matched'::text, 'manual_review'::text, 'rejected'::text])))
);


--
-- Name: COLUMN momo_reconciliations.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_reconciliations.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN momo_reconciliations.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_reconciliations.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: momo_sms_parsed; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_sms_parsed (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    raw_sms_id uuid NOT NULL,
    user_id uuid NOT NULL,
    parser_provider text NOT NULL,
    parser_model text NOT NULL,
    parse_status text DEFAULT 'parsed'::text NOT NULL,
    confidence numeric(5,4),
    tx_direction text DEFAULT 'unknown'::text NOT NULL,
    tx_type text DEFAULT 'unknown'::text NOT NULL,
    momo_tx_id text,
    amount integer,
    currency text DEFAULT 'RWF'::text NOT NULL,
    tx_date date,
    tx_time time without time zone,
    tx_datetime timestamp with time zone,
    payer_name text,
    payer_number_last3 text,
    payer_number_full text,
    payee_name text,
    payee_number_or_code text,
    merchant_code text,
    fee_amount integer,
    balance_after integer,
    narrative text,
    structured_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    tx_category text DEFAULT 'uncategorized'::text NOT NULL,
    cashflow_bucket text DEFAULT 'unknown'::text NOT NULL,
    counterparty_name text,
    ai_summary text,
    recurring_pattern_hint text,
    country_code text,
    club_id bigint,
    CONSTRAINT momo_sms_parsed_cashflow_bucket_check CHECK ((cashflow_bucket = ANY (ARRAY['income'::text, 'expense'::text, 'savings'::text, 'transfer'::text, 'loan'::text, 'fees'::text, 'unknown'::text]))),
    CONSTRAINT momo_sms_parsed_parse_status_check CHECK ((parse_status = ANY (ARRAY['parsed'::text, 'needs_review'::text, 'failed'::text]))),
    CONSTRAINT momo_sms_parsed_tx_direction_check CHECK ((tx_direction = ANY (ARRAY['credit'::text, 'debit'::text, 'unknown'::text])))
);


--
-- Name: COLUMN momo_sms_parsed.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_sms_parsed.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN momo_sms_parsed.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_sms_parsed.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: momo_sms_raw; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_sms_raw (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_message_key text NOT NULL,
    sender text NOT NULL,
    sms_body text NOT NULL,
    provider text,
    country_code text,
    sms_received_at timestamp with time zone NOT NULL,
    detected_tx_type text,
    detected_amount integer,
    detected_tx_id text,
    ingestion_source text DEFAULT 'android_sms_listener'::text NOT NULL,
    parse_status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    otp_whatsapp_number text,
    sms_body_redacted_at timestamp with time zone,
    club_id bigint,
    CONSTRAINT momo_sms_raw_parse_status_check CHECK ((parse_status = ANY (ARRAY['pending'::text, 'processing'::text, 'parsed'::text, 'failed'::text, 'ignored'::text])))
);


--
-- Name: COLUMN momo_sms_raw.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_sms_raw.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN momo_sms_raw.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_sms_raw.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: COLUMN momo_sms_raw.otp_whatsapp_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_sms_raw.otp_whatsapp_number IS 'WhatsApp / OTP phone number attached to the authenticated app user at SMS ingest time.';


--
-- Name: COLUMN momo_sms_raw.sms_body_redacted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_sms_raw.sms_body_redacted_at IS 'When the original raw SMS body was replaced with a redacted placeholder after successful parse + reconciliation retention expiry.';


--
-- Name: momo_sms_sender_allowlist; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_sms_sender_allowlist (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    sender_display text NOT NULL,
    sender_token text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    market text DEFAULT 'RW'::text NOT NULL,
    sort_order integer DEFAULT 100 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: momo_sms_sender_inventory_resolutions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_sms_sender_inventory_resolutions (
    sender_token text NOT NULL,
    sender_display text,
    resolution_status text DEFAULT 'acknowledged_legacy'::text NOT NULL,
    resolution_note text NOT NULL,
    resolved_by uuid,
    resolved_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT momo_sms_sender_inventory_resolutions_status_check CHECK ((resolution_status = 'acknowledged_legacy'::text))
);


--
-- Name: momo_sms_sync_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.momo_sms_sync_runs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    trigger text NOT NULL,
    status text DEFAULT 'succeeded'::text NOT NULL,
    lookback_days integer DEFAULT 365 NOT NULL,
    incremental boolean DEFAULT false NOT NULL,
    scan_started_at timestamp with time zone DEFAULT now() NOT NULL,
    scan_completed_at timestamp with time zone,
    scanned_messages integer DEFAULT 0 NOT NULL,
    uploaded_messages integer DEFAULT 0 NOT NULL,
    duplicate_messages integer DEFAULT 0 NOT NULL,
    oldest_message_at timestamp with time zone,
    newest_message_at timestamp with time zone,
    latest_known_message_at timestamp with time zone,
    error_message text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT momo_sms_sync_runs_status_check CHECK ((status = ANY (ARRAY['running'::text, 'succeeded'::text, 'failed'::text, 'rate_limited'::text]))),
    CONSTRAINT momo_sms_sync_runs_trigger_check CHECK ((trigger = ANY (ARRAY['initial_permission_grant'::text, 'manual'::text])))
);


--
-- Name: TABLE momo_sms_sync_runs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.momo_sms_sync_runs IS 'User-visible audit trail for device-side M-Money SMS historical and manual sync runs.';


--
-- Name: COLUMN momo_sms_sync_runs.incremental; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.momo_sms_sync_runs.incremental IS 'True when the device sync used a narrowed window instead of a full 12-month backfill.';


--
-- Name: momo_validation_issues; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.momo_validation_issues AS
 SELECT NULL::text AS record_type,
    NULL::uuid AS record_id,
    NULL::text AS country,
    NULL::text AS country_name,
    NULL::text AS route_type,
    NULL::text AS issue_code,
    'Compatibility placeholder. Apply the full country-validation migration set to enable real audit rows.'::text AS issue_message,
    NULL::text AS momo_number,
    NULL::text AS momo_code,
    NULL::text AS expected_phone_example,
    NULL::text AS expected_code_example,
    NULL::text AS phone_ussd_example,
    NULL::text AS code_ussd_example,
    false AS repair_supported
  WHERE false;


--
-- Name: VIEW momo_validation_issues; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.momo_validation_issues IS 'Admin/service audit view for users and groups whose MoMo country or recipient data does not satisfy the current validation rules.';


--
-- Name: news_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.news_articles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    club_id bigint,
    title text NOT NULL,
    subtitle text,
    body text,
    category text DEFAULT 'News'::text NOT NULL,
    image_url text,
    image_prompt text,
    is_published boolean DEFAULT false NOT NULL,
    published_at timestamp with time zone,
    is_featured boolean DEFAULT false NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    author_name text DEFAULT 'Club Media'::text
);


--
-- Name: TABLE news_articles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.news_articles IS 'CMS-driven news/intel articles per club. Header images are AI-generated using team brand context.';


--
-- Name: nexus_opportunities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.nexus_opportunities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    subtitle text NOT NULL,
    rationale text NOT NULL,
    type text NOT NULL,
    icon_emoji text DEFAULT '✨'::text NOT NULL,
    cta_action text NOT NULL,
    country text,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: notification_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    target_type text NOT NULL,
    user_id uuid,
    topic text,
    title text NOT NULL,
    body text NOT NULL,
    route text,
    image_url text,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    provider text DEFAULT 'fcm'::text NOT NULL,
    send_status text DEFAULT 'queued'::text NOT NULL,
    sent_count integer DEFAULT 0 NOT NULL,
    failed_count integer DEFAULT 0 NOT NULL,
    cleaned_tokens integer DEFAULT 0 NOT NULL,
    errors jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    sent_at timestamp with time zone,
    CONSTRAINT notification_events_cleaned_tokens_check CHECK ((cleaned_tokens >= 0)),
    CONSTRAINT notification_events_failed_count_check CHECK ((failed_count >= 0)),
    CONSTRAINT notification_events_send_status_check CHECK ((send_status = ANY (ARRAY['queued'::text, 'sent'::text, 'partial'::text, 'failed'::text]))),
    CONSTRAINT notification_events_sent_count_check CHECK ((sent_count >= 0)),
    CONSTRAINT notification_events_target_type_check CHECK ((target_type = ANY (ARRAY['user'::text, 'topic'::text]))),
    CONSTRAINT notification_events_target_user_check CHECK ((((target_type = 'user'::text) AND (user_id IS NOT NULL)) OR ((target_type = 'topic'::text) AND (topic IS NOT NULL))))
);


--
-- Name: TABLE notification_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.notification_events IS 'Durable record of user-targeted and topic-targeted push notification send attempts.';


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    match_id uuid NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    sent_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    club_id bigint,
    image_url text,
    audience_type text DEFAULT 'all_fans'::text,
    audience_tier text,
    audience_group_name text,
    delivery_mode text DEFAULT 'send_now'::text,
    scheduled_at timestamp with time zone,
    requested_recipient_count integer DEFAULT 0,
    successful_user_count integer DEFAULT 0,
    failed_user_count integer DEFAULT 0,
    sent_count integer DEFAULT 0,
    failed_count integer DEFAULT 0,
    cleaned_tokens integer DEFAULT 0,
    last_error text,
    delivery_summary jsonb DEFAULT '{}'::jsonb,
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT rs_notifications_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'sent'::text, 'failed'::text])))
);


--
-- Name: operational_config_issues; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.operational_config_issues WITH (security_invoker='true') AS
 WITH required_configs(config_key, scope_mode, stale_after_days, description) AS (
         VALUES ('support_whatsapp'::text,'shared'::text,45,'Primary support escalation contact.'::text), ('mobility_subscription_momo_code'::text,'any'::text,30,'MoMo code used for mobility subscription checkout.'::text)
        ), matching_configs AS (
         SELECT rc.config_key,
            rc.scope_mode,
            rc.stale_after_days,
            rc.description,
            ac.key,
            ac.country,
            NULLIF(btrim(COALESCE(ac.value, ''::text)), ''::text) AS config_value,
            COALESCE(ac.updated_at, ac.created_at) AS last_updated_at
           FROM (required_configs rc
             LEFT JOIN LATERAL ( SELECT ac_1.key,
                    ac_1.value,
                    ac_1.description,
                    ac_1.country,
                    ac_1.created_at,
                    ac_1.updated_at
                   FROM public.app_config ac_1
                  WHERE ((ac_1.key = rc.config_key) AND ((rc.scope_mode = 'any'::text) OR ((rc.scope_mode = 'shared'::text) AND (ac_1.country IS NULL))))
                  ORDER BY COALESCE(ac_1.updated_at, ac_1.created_at) DESC NULLS LAST
                 LIMIT 1) ac ON (true))
        )
 SELECT format('config:%s'::text, config_key) AS issue_id,
        CASE
            WHEN (config_value IS NULL) THEN 'missing_required_config'::text
            ELSE 'stale_config_review'::text
        END AS issue_type,
        CASE
            WHEN (config_value IS NULL) THEN 'critical'::text
            ELSE 'warning'::text
        END AS severity,
    'config_hygiene'::text AS service,
        CASE
            WHEN (config_value IS NULL) THEN 'Required config is missing'::text
            ELSE 'Config review window expired'::text
        END AS title,
        CASE
            WHEN (config_value IS NULL) THEN format('%s is missing. %s'::text, config_key, description)
            ELSE format('%s has not been reviewed in %s days. %s'::text, config_key, GREATEST(1, (floor((EXTRACT(epoch FROM (now() - last_updated_at)) / (86400)::numeric)))::integer), description)
        END AS detail,
    'app_config'::text AS subject_table,
    config_key AS subject_id,
    NULL::uuid AS user_id,
    config_key AS reference,
    last_updated_at AS first_seen_at,
    last_updated_at AS last_seen_at,
    jsonb_build_object('config_key', config_key, 'scope_mode', scope_mode, 'country', country, 'last_updated_at', last_updated_at, 'stale_after_days', stale_after_days) AS metadata
   FROM matching_configs
  WHERE ((config_value IS NULL) OR (last_updated_at <= (now() - make_interval(days => stale_after_days))));


--
-- Name: operational_health_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.operational_health_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    service text NOT NULL,
    component text DEFAULT 'general'::text NOT NULL,
    status text DEFAULT 'ok'::text NOT NULL,
    severity text DEFAULT 'info'::text NOT NULL,
    issue_code text,
    message text NOT NULL,
    function_name text,
    user_id uuid,
    subject_type text,
    subject_id text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    ingest_origin text DEFAULT 'system'::text NOT NULL,
    CONSTRAINT operational_health_events_ingest_origin_check CHECK ((ingest_origin = ANY (ARRAY['system'::text, 'mobile_app'::text]))),
    CONSTRAINT operational_health_events_severity_check CHECK ((severity = ANY (ARRAY['info'::text, 'warning'::text, 'critical'::text]))),
    CONSTRAINT operational_health_events_status_check CHECK ((status = ANY (ARRAY['ok'::text, 'warn'::text, 'error'::text])))
);


--
-- Name: TABLE operational_health_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.operational_health_events IS 'Append-only operational health feed for SMS ingest, MoMo parsing, wallet sync, partner checkout, and Edge Function failures.';


--
-- Name: COLUMN operational_health_events.ingest_origin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.operational_health_events.ingest_origin IS 'Source class for the event. system = service-role/server instrumentation, mobile_app = authenticated mobile telemetry relayed via Edge Function.';


--
-- Name: operational_triage_issues; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.operational_triage_issues WITH (security_invoker='true') AS
 WITH manual_review_reconciliations AS (
         SELECT format('payment-review:%s'::text, mr.id) AS issue_id,
            'failed_payment_sync'::text AS issue_type,
                CASE
                    WHEN (COALESCE(mr.updated_at, mr.created_at) <= (now() - '02:00:00'::interval)) THEN 'critical'::text
                    ELSE 'warning'::text
                END AS severity,
            'payment_sync'::text AS service,
            'Payment sync requires manual review'::text AS title,
            format('Reconciliation %s is in %s for %s.'::text, mr.id, mr.match_status, COALESCE(NULLIF((mr.metadata ->> 'matched_reference'::text), ''::text), NULLIF((mr.metadata ->> 'source_raw_sms_id'::text), ''::text), 'this SMS'::text)) AS detail,
            COALESCE(mr.target_table, 'momo_reconciliations'::text) AS subject_table,
            COALESCE((mr.target_record_id)::text, (mr.id)::text) AS subject_id,
            mr.user_id,
            COALESCE(NULLIF((mr.metadata ->> 'matched_reference'::text), ''::text), NULLIF((mr.metadata ->> 'source_raw_sms_id'::text), ''::text)) AS reference,
            mr.created_at AS first_seen_at,
            COALESCE(mr.updated_at, mr.created_at) AS last_seen_at,
            (COALESCE(mr.metadata, '{}'::jsonb) || jsonb_build_object('match_status', mr.match_status, 'notes', mr.notes)) AS metadata
           FROM public.momo_reconciliations mr
          WHERE (mr.match_status = ANY (ARRAY['pending_review'::text, 'manual_review'::text]))
        ), latest_sms_migration_safety AS (
         SELECT DISTINCT ON (COALESCE(ohe.subject_id, 'completed_status_backfill'::text)) format('sms-migration-safety:%s'::text, ohe.id) AS issue_id,
            'sms_migration_safety'::text AS issue_type,
            'critical'::text AS severity,
            'sms_ingest'::text AS service,
            'M-Money SMS migration safety regression'::text AS title,
            ohe.message AS detail,
            'operational_health_events'::text AS subject_table,
            (ohe.id)::text AS subject_id,
            ohe.user_id,
            COALESCE(ohe.issue_code, ohe.component) AS reference,
            ohe.occurred_at AS first_seen_at,
            ohe.occurred_at AS last_seen_at,
            (COALESCE(ohe.metadata, '{}'::jsonb) || jsonb_build_object('function_name', ohe.function_name, 'issue_code', ohe.issue_code, 'component', ohe.component)) AS metadata,
            ohe.status
           FROM public.operational_health_events ohe
          WHERE ((ohe.service = 'sms_ingest'::text) AND (ohe.component = 'momo_sms_migration_safety'::text) AND (ohe.ingest_origin = 'system'::text) AND (ohe.occurred_at >= (now() - '30 days'::interval)))
          ORDER BY COALESCE(ohe.subject_id, 'completed_status_backfill'::text), ohe.occurred_at DESC
        ), sms_migration_safety_issues AS (
         SELECT latest_sms_migration_safety.issue_id,
            latest_sms_migration_safety.issue_type,
            latest_sms_migration_safety.severity,
            latest_sms_migration_safety.service,
            latest_sms_migration_safety.title,
            latest_sms_migration_safety.detail,
            latest_sms_migration_safety.subject_table,
            latest_sms_migration_safety.subject_id,
            latest_sms_migration_safety.user_id,
            latest_sms_migration_safety.reference,
            latest_sms_migration_safety.first_seen_at,
            latest_sms_migration_safety.last_seen_at,
            latest_sms_migration_safety.metadata
           FROM latest_sms_migration_safety
          WHERE (latest_sms_migration_safety.status = 'error'::text)
        ), edge_function_failures AS (
         SELECT format('edge-function:%s'::text, ohe.id) AS issue_id,
            'failed_function_invocation'::text AS issue_type,
            'critical'::text AS severity,
            'edge_function'::text AS service,
            format('%s failed'::text, COALESCE(NULLIF(ohe.function_name, ''::text), ohe.component, 'Edge Function'::text)) AS title,
            ohe.message AS detail,
            'operational_health_events'::text AS subject_table,
            (ohe.id)::text AS subject_id,
            ohe.user_id,
            COALESCE(ohe.function_name, ohe.component) AS reference,
            ohe.occurred_at AS first_seen_at,
            ohe.occurred_at AS last_seen_at,
            (COALESCE(ohe.metadata, '{}'::jsonb) || jsonb_build_object('function_name', ohe.function_name, 'issue_code', ohe.issue_code)) AS metadata
           FROM public.operational_health_events ohe
          WHERE ((ohe.service = 'edge_function'::text) AND (ohe.status = 'error'::text) AND (ohe.occurred_at >= (now() - '7 days'::interval)))
        ), config_issues AS (
         SELECT operational_config_issues.issue_id,
            operational_config_issues.issue_type,
            operational_config_issues.severity,
            operational_config_issues.service,
            operational_config_issues.title,
            operational_config_issues.detail,
            operational_config_issues.subject_table,
            operational_config_issues.subject_id,
            operational_config_issues.user_id,
            operational_config_issues.reference,
            operational_config_issues.first_seen_at,
            operational_config_issues.last_seen_at,
            operational_config_issues.metadata
           FROM public.operational_config_issues
        )
 SELECT manual_review_reconciliations.issue_id,
    manual_review_reconciliations.issue_type,
    manual_review_reconciliations.severity,
    manual_review_reconciliations.service,
    manual_review_reconciliations.title,
    manual_review_reconciliations.detail,
    manual_review_reconciliations.subject_table,
    manual_review_reconciliations.subject_id,
    manual_review_reconciliations.user_id,
    manual_review_reconciliations.reference,
    manual_review_reconciliations.first_seen_at,
    manual_review_reconciliations.last_seen_at,
    manual_review_reconciliations.metadata
   FROM manual_review_reconciliations
UNION ALL
 SELECT sms_migration_safety_issues.issue_id,
    sms_migration_safety_issues.issue_type,
    sms_migration_safety_issues.severity,
    sms_migration_safety_issues.service,
    sms_migration_safety_issues.title,
    sms_migration_safety_issues.detail,
    sms_migration_safety_issues.subject_table,
    sms_migration_safety_issues.subject_id,
    sms_migration_safety_issues.user_id,
    sms_migration_safety_issues.reference,
    sms_migration_safety_issues.first_seen_at,
    sms_migration_safety_issues.last_seen_at,
    sms_migration_safety_issues.metadata
   FROM sms_migration_safety_issues
UNION ALL
 SELECT edge_function_failures.issue_id,
    edge_function_failures.issue_type,
    edge_function_failures.severity,
    edge_function_failures.service,
    edge_function_failures.title,
    edge_function_failures.detail,
    edge_function_failures.subject_table,
    edge_function_failures.subject_id,
    edge_function_failures.user_id,
    edge_function_failures.reference,
    edge_function_failures.first_seen_at,
    edge_function_failures.last_seen_at,
    edge_function_failures.metadata
   FROM edge_function_failures
UNION ALL
 SELECT config_issues.issue_id,
    config_issues.issue_type,
    config_issues.severity,
    config_issues.service,
    config_issues.title,
    config_issues.detail,
    config_issues.subject_table,
    config_issues.subject_id,
    config_issues.user_id,
    config_issues.reference,
    config_issues.first_seen_at,
    config_issues.last_seen_at,
    config_issues.metadata
   FROM config_issues;


--
-- Name: operational_release_dashboard; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.operational_release_dashboard WITH (security_invoker='true') AS
 WITH targets(service_key, label) AS (
         VALUES ('sms_ingest'::text,'SMS Ingest'::text), ('momo_parsing'::text,'MoMo Parsing'::text), ('payment_sync'::text,'Payment Sync'::text), ('edge_function'::text,'Edge Functions'::text), ('config_hygiene'::text,'Config Hygiene'::text)
        ), recent_events AS (
         SELECT operational_health_events.service,
            (count(*) FILTER (WHERE (operational_health_events.status = 'ok'::text)))::integer AS ok_count_24h,
            (count(*) FILTER (WHERE (operational_health_events.status = 'warn'::text)))::integer AS warn_count_24h,
            (count(*) FILTER (WHERE (operational_health_events.status = 'error'::text)))::integer AS error_count_24h,
            max(operational_health_events.occurred_at) AS last_event_at
           FROM public.operational_health_events
          WHERE ((operational_health_events.ingest_origin = 'system'::text) AND (operational_health_events.occurred_at >= (now() - '24:00:00'::interval)))
          GROUP BY operational_health_events.service
        ), issue_counts AS (
         SELECT operational_triage_issues.service,
            (count(*))::integer AS issue_count,
            (count(*) FILTER (WHERE (operational_triage_issues.severity = 'critical'::text)))::integer AS critical_issue_count,
            max(operational_triage_issues.last_seen_at) AS last_issue_at
           FROM public.operational_triage_issues
          GROUP BY operational_triage_issues.service
        )
 SELECT t.service_key,
    t.label,
        CASE
            WHEN (t.service_key = ANY (ARRAY['sms_ingest'::text, 'payment_sync'::text, 'config_hygiene'::text, 'edge_function'::text])) THEN
            CASE
                WHEN (COALESCE(ic.critical_issue_count, 0) > 0) THEN 'failing'::text
                WHEN (COALESCE(ic.issue_count, 0) > 0) THEN 'degraded'::text
                WHEN (COALESCE(re.error_count_24h, 0) > 0) THEN 'failing'::text
                WHEN (COALESCE(re.warn_count_24h, 0) > 0) THEN 'degraded'::text
                WHEN (COALESCE(re.ok_count_24h, 0) > 0) THEN 'healthy'::text
                ELSE 'unknown'::text
            END
            WHEN (COALESCE(re.error_count_24h, 0) > 0) THEN 'failing'::text
            WHEN ((COALESCE(re.warn_count_24h, 0) > 0) OR (COALESCE(ic.issue_count, 0) > 0)) THEN 'degraded'::text
            WHEN (COALESCE(re.ok_count_24h, 0) > 0) THEN 'healthy'::text
            ELSE 'unknown'::text
        END AS health_status,
    COALESCE(re.ok_count_24h, 0) AS ok_count_24h,
    COALESCE(re.warn_count_24h, 0) AS warn_count_24h,
    COALESCE(re.error_count_24h, 0) AS error_count_24h,
    COALESCE(ic.issue_count, 0) AS issue_count,
    GREATEST(COALESCE(re.last_event_at, '-infinity'::timestamp with time zone), COALESCE(ic.last_issue_at, '-infinity'::timestamp with time zone)) AS last_signal_at,
        CASE
            WHEN (t.service_key = 'sms_ingest'::text) THEN
            CASE
                WHEN (COALESCE(ic.issue_count, 0) > 0) THEN format('%s trusted M-Money SMS migration safety issues currently need triage.'::text, COALESCE(ic.issue_count, 0))
                WHEN (COALESCE(re.last_event_at, NULL::timestamp with time zone) IS NULL) THEN 'No trusted SMS ingest checks were recorded in the last 24 hours.'::text
                ELSE format('%s ok, %s warn, %s error trusted SMS ingest checks in the last 24 hours.'::text, COALESCE(re.ok_count_24h, 0), COALESCE(re.warn_count_24h, 0), COALESCE(re.error_count_24h, 0))
            END
            WHEN (t.service_key = 'payment_sync'::text) THEN format('%s payment-sync issues currently need triage.'::text, COALESCE(ic.issue_count, 0))
            WHEN (t.service_key = 'config_hygiene'::text) THEN format('%s config issues are blocking or degrading release readiness.'::text, COALESCE(ic.issue_count, 0))
            WHEN (t.service_key = 'edge_function'::text) THEN
            CASE
                WHEN (COALESCE(ic.issue_count, 0) = 0) THEN 'No Edge Function failures were recorded in the last 7 days.'::text
                ELSE format('%s Edge Function failures were recorded in the last 7 days.'::text, COALESCE(ic.issue_count, 0))
            END
            WHEN (COALESCE(re.last_event_at, NULL::timestamp with time zone) IS NULL) THEN format('No trusted %s health events were recorded in the last 24 hours.'::text, lower(t.label))
            ELSE format('%s ok, %s warn, %s error trusted events in the last 24 hours.'::text, COALESCE(re.ok_count_24h, 0), COALESCE(re.warn_count_24h, 0), COALESCE(re.error_count_24h, 0))
        END AS summary
   FROM ((targets t
     LEFT JOIN recent_events re ON ((re.service = t.service_key)))
     LEFT JOIN issue_counts ic ON ((ic.service = t.service_key)));


--
-- Name: otp_codes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_codes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    phone text NOT NULL,
    code text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    attempts integer DEFAULT 0,
    verified boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: otp_rate_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.otp_rate_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    action text NOT NULL,
    actor_key text NOT NULL,
    outcome text NOT NULL,
    phone text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT otp_rate_events_action_check CHECK ((action = ANY (ARRAY['send_ip'::text, 'send_phone'::text, 'verify_ip'::text, 'verify_phone'::text])))
);


--
-- Name: TABLE otp_rate_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.otp_rate_events IS 'Service-role-only OTP abuse telemetry for IP- and phone-scoped send and verify limits.';


--
-- Name: partner_payment_routes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.partner_payment_routes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    country text DEFAULT 'RW'::text NOT NULL,
    provider text NOT NULL,
    recipient_code text,
    reconciliation_label text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    club_id bigint,
    partner_name text DEFAULT 'Club'::text NOT NULL,
    partner_slug text DEFAULT ''::text NOT NULL,
    CONSTRAINT partner_payment_routes_country_rwanda_only_check CHECK ((country = 'RW'::text)),
    CONSTRAINT partner_payment_routes_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'active'::text, 'inactive'::text])))
);


--
-- Name: TABLE partner_payment_routes; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.partner_payment_routes IS 'Admin-managed mobile money routing per partner and country.';


--
-- Name: COLUMN partner_payment_routes.provider; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.partner_payment_routes.provider IS 'Human and app-facing provider identifier such as mtn_rwanda.';


--
-- Name: COLUMN partner_payment_routes.recipient_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.partner_payment_routes.recipient_code IS 'Merchant/payment code used for USSD mobile money checkout.';


--
-- Name: COLUMN partner_payment_routes.reconciliation_label; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.partner_payment_routes.reconciliation_label IS 'Stable label used to explain how receipts are reconciled.';


--
-- Name: partner_services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.partner_services (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid NOT NULL,
    title text NOT NULL,
    subtitle text,
    emoji text DEFAULT '📋'::text,
    category text DEFAULT 'general'::text,
    details jsonb DEFAULT '[]'::jsonb,
    cta_label text,
    cta_action text,
    country text DEFAULT 'RW'::text,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    CONSTRAINT partner_services_country_rwanda_only_check CHECK ((country = 'RW'::text))
);


--
-- Name: TABLE partner_services; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.partner_services IS 'Dynamic partner services managed via admin. GUARDRAIL: Bank partners (category=bank) must expose exactly one custody CTA: internal:group_savings_custodian. Non-bank partners keep their own service schemas.';


--
-- Name: COLUMN partner_services.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.partner_services.is_mock IS 'Internal-only marker for removable seeded/demo partner service rows. Not intended for client display.';


--
-- Name: COLUMN partner_services.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.partner_services.mock_batch IS 'Internal batch key used to bulk remove mock partner service rows from admin or SQL.';


--
-- Name: partners; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.partners (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    category text DEFAULT 'football'::text NOT NULL,
    country text DEFAULT 'RW'::text NOT NULL,
    logo_url text,
    description text,
    fan_count integer DEFAULT 0,
    club_count integer DEFAULT 0,
    game_count integer DEFAULT 0,
    created_at timestamp with time zone DEFAULT now(),
    slug text,
    emoji text DEFAULT '🤝'::text NOT NULL,
    subtitle text,
    whatsapp_number text,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    banner_url text,
    brand_primary_color text,
    brand_secondary_color text,
    website_url text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    momo_code text,
    CONSTRAINT partners_category_check CHECK ((category = ANY (ARRAY['football'::text, 'bank'::text, 'organization'::text]))),
    CONSTRAINT partners_country_rwanda_only_check CHECK ((country = 'RW'::text))
);


--
-- Name: COLUMN partners.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.partners.is_mock IS 'Internal-only marker for removable seeded/demo partner rows. Not intended for client display.';


--
-- Name: COLUMN partners.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.partners.mock_batch IS 'Internal batch key used to bulk remove mock partner rows from admin or SQL.';


--
-- Name: COLUMN partners.momo_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.partners.momo_code IS 'MoMo payment code for the partner (used for USSD payments in Rwanda).';


--
-- Name: payment_identities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_identities (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    normalized_name text NOT NULL,
    number_last_3 text NOT NULL,
    number_full text,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: payment_intents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_intents (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    receiving_account_id uuid NOT NULL,
    target_table text NOT NULL,
    target_record_id uuid NOT NULL,
    expected_amount integer NOT NULL,
    currency text DEFAULT 'RWF'::text NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    expires_at timestamp with time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_intents_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'fulfilled'::text, 'expired'::text, 'cancelled'::text])))
);


--
-- Name: payment_receiver_accounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_receiver_accounts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    payee_number_or_code text NOT NULL,
    purpose text NOT NULL,
    owner_user_id uuid,
    partner_id uuid,
    is_active boolean DEFAULT true NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payment_receiver_accounts_purpose_check CHECK ((purpose = ANY (ARRAY['personal_wallet'::text, 'bank_custody'::text, 'rayon_shop'::text, 'subscription'::text, 'system_pool'::text])))
);


--
-- Name: pending_transactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pending_transactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid,
    group_id uuid,
    group_contribution_id uuid,
    reference text NOT NULL,
    recipient_momo text NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    provider text,
    status text DEFAULT 'pending'::text NOT NULL,
    raw_payload jsonb,
    confirmed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pending_transactions_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'failed'::text])))
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    club_id bigint,
    phone text,
    full_name text,
    public_user_id text DEFAULT public.generate_public_user_id() NOT NULL,
    country text,
    language_code text DEFAULT 'en'::text NOT NULL,
    avatar_url text,
    is_admin boolean DEFAULT false NOT NULL,
    momo_number text,
    momo_provider text,
    theme_preference text,
    date_of_birth date,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    display_name text,
    country_code text,
    is_active boolean DEFAULT true NOT NULL
);


--
-- Name: public_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.public_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 999999
    CACHE 1;


--
-- Name: pwa_engagement_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pwa_engagement_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    club_id text NOT NULL,
    user_id uuid,
    event_type text NOT NULL,
    surface text NOT NULL,
    path text,
    display_mode text,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    user_agent text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--
-- Name: quest_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quest_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    description text,
    event_type text NOT NULL,
    target_count integer DEFAULT 1 NOT NULL,
    reward_points integer DEFAULT 0 NOT NULL,
    campaign_id text,
    start_at timestamp with time zone,
    end_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT quest_definitions_check CHECK (((end_at IS NULL) OR (start_at IS NULL) OR (end_at > start_at))),
    CONSTRAINT quest_definitions_reward_points_check CHECK ((reward_points >= 0)),
    CONSTRAINT quest_definitions_target_count_check CHECK ((target_count > 0))
);


--
-- Name: quest_progress; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quest_progress (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    quest_id uuid NOT NULL,
    user_id uuid NOT NULL,
    progress_count integer DEFAULT 0 NOT NULL,
    completed_at timestamp with time zone,
    reward_dedupe_key text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT quest_progress_progress_count_check CHECK ((progress_count >= 0))
);


--
-- Name: quick_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quick_actions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title text NOT NULL,
    subtitle text,
    emoji text DEFAULT '⚡'::text,
    route text NOT NULL,
    country text,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT quick_actions_country_local_scope_check CHECK (((country IS NULL) OR (country = 'RW'::text)))
);


--
-- Name: request_rate_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.request_rate_limits (
    bucket_key text NOT NULL,
    count integer DEFAULT 0 NOT NULL,
    reset_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT request_rate_limits_count_check CHECK ((count >= 0))
);


--
-- Name: rs_initiative_contributions; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.rs_initiative_contributions AS
 SELECT id,
    initiative_id,
    user_id,
    club_id,
    referral_invite_id,
    amount,
    momo_reference,
    status,
    created_at,
    updated_at
   FROM public.initiative_contributions;


--
-- Name: rs_initiatives; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.rs_initiatives AS
 SELECT id,
    club_id,
    partner_id,
    title,
    description,
    goal_amount,
    raised_amount,
    supporter_count,
    status,
    created_at,
    updated_at
   FROM public.initiatives;


--
-- Name: rs_matches; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.rs_matches AS
 SELECT id,
    club_id,
    partner_id,
    home_team,
    away_team,
    competition,
    venue,
    match_date,
    kickoff_time,
    is_on_sale,
    ticket_general_price,
    ticket_vip_price,
    sale_starts_at,
    capacity,
    sold_count,
    image_url,
    roster,
    created_at,
    updated_at
   FROM public.matches;


--
-- Name: shop_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shop_orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    items jsonb DEFAULT '[]'::jsonb NOT NULL,
    subtotal integer DEFAULT 0 NOT NULL,
    discount integer DEFAULT 0 NOT NULL,
    total integer DEFAULT 0 NOT NULL,
    delivery_address text,
    momo_reference text,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    referral_invite_id uuid,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    discount_amount integer DEFAULT 0 NOT NULL,
    delivery_fee integer DEFAULT 0 NOT NULL,
    confirmed_at timestamp with time zone,
    partner_id uuid,
    club_id bigint,
    CONSTRAINT rs_shop_orders_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'paid'::text, 'confirmed'::text, 'packed'::text, 'shipped'::text, 'fulfilled'::text, 'delivered'::text, 'cancelled'::text])))
);


--
-- Name: COLUMN shop_orders.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.shop_orders.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN shop_orders.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.shop_orders.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: rs_shop_orders; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.rs_shop_orders AS
 SELECT id,
    user_id,
    club_id,
    partner_id,
    referral_invite_id,
    items,
    subtotal,
    discount_amount,
    delivery_fee,
    total,
    delivery_address,
    momo_reference,
    status,
    created_at,
    updated_at
   FROM public.shop_orders;


--
-- Name: tickets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tickets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    match_id uuid NOT NULL,
    user_id uuid NOT NULL,
    seat_type text NOT NULL,
    amount_paid integer DEFAULT 0 NOT NULL,
    qr_code text,
    momo_reference text,
    status text DEFAULT 'pending'::text NOT NULL,
    purchased_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    referral_invite_id uuid,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    confirmed_at timestamp with time zone,
    club_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT rs_tickets_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'valid'::text, 'used'::text, 'cancelled'::text, 'voided'::text, 'refunded'::text])))
);


--
-- Name: COLUMN tickets.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tickets.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN tickets.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tickets.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: rs_tickets; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.rs_tickets AS
 SELECT id,
    match_id,
    user_id,
    club_id,
    referral_invite_id,
    seat_type,
    amount_paid,
    qr_code,
    momo_reference,
    status,
    purchased_at,
    created_at,
    updated_at
   FROM public.tickets;


--
-- Name: season_definitions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.season_definitions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    description text,
    starts_at timestamp with time zone NOT NULL,
    ends_at timestamp with time zone NOT NULL,
    is_active boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    CONSTRAINT season_definitions_check CHECK ((ends_at > starts_at))
);


--
-- Name: COLUMN season_definitions.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.season_definitions.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN season_definitions.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.season_definitions.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: season_memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.season_memberships (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    season_id uuid NOT NULL,
    user_id uuid NOT NULL,
    season_points integer DEFAULT 0 NOT NULL,
    rank_hint integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text
);


--
-- Name: COLUMN season_memberships.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.season_memberships.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN season_memberships.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.season_memberships.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: shop_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shop_products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    partner_id uuid,
    name text NOT NULL,
    category text NOT NULL,
    price numeric(10,2) NOT NULL,
    stock integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_new boolean DEFAULT false NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    image_url text,
    sizes jsonb DEFAULT '[]'::jsonb NOT NULL,
    badge_label text,
    collection text,
    sort_order integer DEFAULT 0 NOT NULL,
    available_sizes text[],
    club_id bigint,
    subtitle text,
    product_id text,
    product_type text DEFAULT 'kit'::text NOT NULL,
    image_prompt text,
    currency text DEFAULT 'USD'::text NOT NULL,
    CONSTRAINT rs_shop_products_price_check CHECK ((price >= (0)::numeric))
);


--
-- Name: TABLE shop_products; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.shop_products IS 'Club merchandise catalog. Images are AI-generated via the generate-product-image Edge Function using team-specific brand prompts.';


--
-- Name: special_products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.special_products (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title text NOT NULL,
    subtitle text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    amount integer DEFAULT 0 NOT NULL,
    currency text DEFAULT 'RWF'::text NOT NULL,
    icon_name text DEFAULT 'star'::text NOT NULL,
    color_hex text DEFAULT '#C9A84C'::text NOT NULL,
    interest_rate text,
    loan_multiplier text,
    momo_recipient text NOT NULL,
    momo_recipient_type text DEFAULT 'code'::text NOT NULL,
    target_audience text DEFAULT 'Everyone'::text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: squad_players; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.squad_players (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    club_id bigint,
    partner_id text,
    name text NOT NULL,
    "position" text DEFAULT 'Player'::text NOT NULL,
    shirt_number integer DEFAULT 0 NOT NULL,
    nationality text DEFAULT 'Rwanda'::text NOT NULL,
    bio text,
    image_url text,
    photo_url text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: standings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.standings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    club_id bigint,
    partner_id text,
    "position" integer DEFAULT 1 NOT NULL,
    club_name text DEFAULT ''::text NOT NULL,
    club_slug text,
    played integer DEFAULT 0 NOT NULL,
    won integer DEFAULT 0 NOT NULL,
    drawn integer DEFAULT 0 NOT NULL,
    lost integer DEFAULT 0 NOT NULL,
    goals_for integer DEFAULT 0 NOT NULL,
    goals_against integer DEFAULT 0 NOT NULL,
    goal_difference integer DEFAULT 0 NOT NULL,
    points integer DEFAULT 0 NOT NULL,
    form text[] DEFAULT '{}'::text[],
    season text,
    league text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_fcm_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_fcm_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token text NOT NULL,
    platform text DEFAULT 'android'::text NOT NULL,
    device_info jsonb DEFAULT '{}'::jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    club_id bigint,
    device_platform text,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_notification_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_notification_settings (
    user_id uuid NOT NULL,
    club_id bigint,
    push_enabled boolean DEFAULT false NOT NULL,
    allow_all boolean DEFAULT false NOT NULL,
    match_alerts boolean DEFAULT true NOT NULL,
    contribution_receipts boolean DEFAULT true NOT NULL,
    xp_milestones boolean DEFAULT true NOT NULL,
    team_news boolean DEFAULT false NOT NULL,
    challenges boolean DEFAULT true NOT NULL,
    group_chat boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_privacy_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_privacy_settings (
    user_id uuid NOT NULL,
    club_id bigint,
    group_visibility text DEFAULT 'members'::text NOT NULL,
    analytics_enabled boolean DEFAULT true NOT NULL,
    biometric_login_enabled boolean DEFAULT true NOT NULL,
    show_activity_status boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_privacy_settings_group_visibility_check CHECK ((group_visibility = ANY (ARRAY['public'::text, 'members'::text, 'private'::text])))
);


--
-- Name: user_private_contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_private_contacts (
    user_id uuid NOT NULL,
    club_id bigint,
    momo_number text,
    momo_provider text,
    whatsapp_number text,
    country_code text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    phone text NOT NULL,
    full_name text DEFAULT ''::text NOT NULL,
    country text DEFAULT 'RW'::text NOT NULL,
    language_code text DEFAULT 'en'::text NOT NULL,
    momo_number text,
    avatar_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    momo_provider text DEFAULT ''::text NOT NULL,
    is_driver boolean DEFAULT false NOT NULL,
    vehicle_type text,
    momo_code text,
    is_admin boolean DEFAULT false NOT NULL,
    is_mock boolean DEFAULT false NOT NULL,
    mock_batch text,
    official_name text,
    official_phone text,
    public_user_id text DEFAULT public.next_public_user_id() NOT NULL,
    momo_route_type text,
    date_of_birth date,
    national_id_number text,
    identity_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    theme_preference text DEFAULT 'system'::text,
    theme_preference_updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT users_country_rwanda_only_check CHECK ((country = 'RW'::text)),
    CONSTRAINT users_language_code_english_only_check CHECK ((language_code = 'en'::text)),
    CONSTRAINT users_momo_route_type_check CHECK ((momo_route_type = ANY (ARRAY['phone_number'::text, 'code'::text]))),
    CONSTRAINT users_public_user_id_format_check CHECK ((public_user_id ~ '^[0-9]{6}$'::text))
);


--
-- Name: COLUMN users.is_mock; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.is_mock IS 'Internal-only marker for removable demo seed rows. Not intended for customer-facing UI.';


--
-- Name: COLUMN users.mock_batch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.users.mock_batch IS 'Internal batch key used to identify and bulk remove demo seed rows.';


--
-- Name: vehicle_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.vehicle_types (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    label text NOT NULL,
    value text NOT NULL,
    emoji text DEFAULT '🚘'::text,
    country text,
    sort_order integer DEFAULT 0,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT vehicle_types_country_local_scope_check CHECK (((country IS NULL) OR (country = 'RW'::text)))
);


--
-- Name: wallet_pass_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet_pass_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wallet_pass_id uuid NOT NULL,
    user_id uuid,
    event_type text NOT NULL,
    status text,
    details jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: wallet_passes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet_passes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    partner_id uuid,
    provider text DEFAULT 'google_wallet'::text NOT NULL,
    pass_type text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    google_class_id text NOT NULL,
    google_object_id text NOT NULL,
    status text DEFAULT 'ready'::text NOT NULL,
    state text DEFAULT 'ACTIVE'::text NOT NULL,
    save_url text,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    last_error text,
    last_issued_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wallet_passes_entity_type_check CHECK ((entity_type = ANY (ARRAY['rs_ticket'::text, 'rs_membership'::text]))),
    CONSTRAINT wallet_passes_pass_type_check CHECK ((pass_type = ANY (ARRAY['event_ticket'::text, 'generic_membership'::text]))),
    CONSTRAINT wallet_passes_status_check CHECK ((status = ANY (ARRAY['ready'::text, 'failed'::text, 'inactive'::text])))
);


--
-- Name: web_push_subscriptions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_push_subscriptions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    club_id text NOT NULL,
    user_id uuid,
    session_id text,
    surface text DEFAULT 'site'::text NOT NULL,
    path text,
    endpoint text NOT NULL,
    p256dh text NOT NULL,
    auth text NOT NULL,
    language_code text,
    user_agent text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_seen_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    last_push_at timestamp with time zone,
    disabled_at timestamp with time zone
);


--
-- Name: xp_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.xp_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    club_id bigint,
    event_type text NOT NULL,
    xp_awarded integer DEFAULT 0 NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    event_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admin_audit_log admin_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_log
    ADD CONSTRAINT admin_audit_log_pkey PRIMARY KEY (id);


--
-- Name: admin_phone_access admin_phone_access_normalized_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_phone_access
    ADD CONSTRAINT admin_phone_access_normalized_phone_key UNIQUE (normalized_phone);


--
-- Name: admin_phone_access admin_phone_access_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_phone_access
    ADD CONSTRAINT admin_phone_access_pkey PRIMARY KEY (user_id);


--
-- Name: admin_role_assignments admin_role_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_role_assignments
    ADD CONSTRAINT admin_role_assignments_pkey PRIMARY KEY (id);


--
-- Name: admin_role_assignments admin_role_assignments_user_id_role_partner_scope_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_role_assignments
    ADD CONSTRAINT admin_role_assignments_user_id_role_partner_scope_id_key UNIQUE (user_id, role, partner_scope_id);


--
-- Name: african_football_clubs african_football_clubs_club_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.african_football_clubs
    ADD CONSTRAINT african_football_clubs_club_slug_key UNIQUE (club_slug);


--
-- Name: african_football_clubs african_football_clubs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.african_football_clubs
    ADD CONSTRAINT african_football_clubs_pkey PRIMARY KEY (id);


--
-- Name: ai_content_generation_config ai_content_generation_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_content_generation_config
    ADD CONSTRAINT ai_content_generation_config_pkey PRIMARY KEY (id);


--
-- Name: ai_content ai_content_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_content
    ADD CONSTRAINT ai_content_pkey PRIMARY KEY (id);


--
-- Name: app_config app_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_config
    ADD CONSTRAINT app_config_pkey PRIMARY KEY (key);


--
-- Name: biopay_embeddings biopay_embeddings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_embeddings
    ADD CONSTRAINT biopay_embeddings_pkey PRIMARY KEY (id);


--
-- Name: biopay_enrollment_audits biopay_enrollment_audits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_enrollment_audits
    ADD CONSTRAINT biopay_enrollment_audits_pkey PRIMARY KEY (id);


--
-- Name: biopay_events biopay_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_events
    ADD CONSTRAINT biopay_events_pkey PRIMARY KEY (id);


--
-- Name: biopay_liveness_challenges biopay_liveness_challenges_nonce_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_liveness_challenges
    ADD CONSTRAINT biopay_liveness_challenges_nonce_key UNIQUE (nonce);


--
-- Name: biopay_liveness_challenges biopay_liveness_challenges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_liveness_challenges
    ADD CONSTRAINT biopay_liveness_challenges_pkey PRIMARY KEY (id);


--
-- Name: biopay_match_events biopay_match_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_match_events
    ADD CONSTRAINT biopay_match_events_pkey PRIMARY KEY (id);


--
-- Name: biopay_match_rate_events biopay_match_rate_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_match_rate_events
    ADD CONSTRAINT biopay_match_rate_events_pkey PRIMARY KEY (id);


--
-- Name: biopay_nfc_tokens biopay_nfc_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_nfc_tokens
    ADD CONSTRAINT biopay_nfc_tokens_pkey PRIMARY KEY (token);


--
-- Name: biopay_payees biopay_payees_biopay_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_payees
    ADD CONSTRAINT biopay_payees_biopay_id_key UNIQUE (biopay_id);


--
-- Name: biopay_payees biopay_payees_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_payees
    ADD CONSTRAINT biopay_payees_pkey PRIMARY KEY (id);


--
-- Name: biopay_payees biopay_payees_supabase_uid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_payees
    ADD CONSTRAINT biopay_payees_supabase_uid_key UNIQUE (supabase_uid);


--
-- Name: biopay_payment_intents biopay_payment_intents_nonce_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_payment_intents
    ADD CONSTRAINT biopay_payment_intents_nonce_key UNIQUE (nonce);


--
-- Name: biopay_payment_intents biopay_payment_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_payment_intents
    ADD CONSTRAINT biopay_payment_intents_pkey PRIMARY KEY (id);


--
-- Name: biopay_profiles biopay_profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_profiles
    ADD CONSTRAINT biopay_profiles_pkey PRIMARY KEY (id);


--
-- Name: biopay_profiles biopay_profiles_public_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_profiles
    ADD CONSTRAINT biopay_profiles_public_id_key UNIQUE (public_id);


--
-- Name: biopay_revocations biopay_revocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_revocations
    ADD CONSTRAINT biopay_revocations_pkey PRIMARY KEY (id);


--
-- Name: biopay_user_preferences biopay_user_preferences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_user_preferences
    ADD CONSTRAINT biopay_user_preferences_pkey PRIMARY KEY (supabase_uid);


--
-- Name: biopay_web_events biopay_web_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_web_events
    ADD CONSTRAINT biopay_web_events_pkey PRIMARY KEY (id);


--
-- Name: biopay_web_push_subscriptions biopay_web_push_subscriptions_endpoint_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_web_push_subscriptions
    ADD CONSTRAINT biopay_web_push_subscriptions_endpoint_key UNIQUE (endpoint);


--
-- Name: biopay_web_push_subscriptions biopay_web_push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_web_push_subscriptions
    ADD CONSTRAINT biopay_web_push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: groups contribution_groups_invite_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT contribution_groups_invite_code_key UNIQUE (invite_code);


--
-- Name: groups contribution_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT contribution_groups_pkey PRIMARY KEY (id);


--
-- Name: contributions contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_pkey PRIMARY KEY (id);


--
-- Name: cool_achievements cool_achievements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_achievements
    ADD CONSTRAINT cool_achievements_pkey PRIMARY KEY (id);


--
-- Name: cool_achievements cool_achievements_user_id_achievement_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_achievements
    ADD CONSTRAINT cool_achievements_user_id_achievement_id_key UNIQUE (user_id, achievement_id);


--
-- Name: cool_activities cool_activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_activities
    ADD CONSTRAINT cool_activities_pkey PRIMARY KEY (id);


--
-- Name: cool_activities cool_activities_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_activities
    ADD CONSTRAINT cool_activities_slug_key UNIQUE (slug);


--
-- Name: cool_events cool_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_events
    ADD CONSTRAINT cool_events_pkey PRIMARY KEY (id);


--
-- Name: cool_invite_attributions cool_invite_attributions_inviter_id_invitee_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_invite_attributions
    ADD CONSTRAINT cool_invite_attributions_inviter_id_invitee_id_key UNIQUE (inviter_id, invitee_id);


--
-- Name: cool_invite_attributions cool_invite_attributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_invite_attributions
    ADD CONSTRAINT cool_invite_attributions_pkey PRIMARY KEY (id);


--
-- Name: cool_mission_progress cool_mission_progress_mission_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_mission_progress
    ADD CONSTRAINT cool_mission_progress_mission_id_user_id_key UNIQUE (mission_id, user_id);


--
-- Name: cool_mission_progress cool_mission_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_mission_progress
    ADD CONSTRAINT cool_mission_progress_pkey PRIMARY KEY (id);


--
-- Name: cool_missions cool_missions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_missions
    ADD CONSTRAINT cool_missions_pkey PRIMARY KEY (id);


--
-- Name: cool_reward_redemptions cool_reward_redemptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_reward_redemptions
    ADD CONSTRAINT cool_reward_redemptions_pkey PRIMARY KEY (id);


--
-- Name: cool_rewards cool_rewards_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_rewards
    ADD CONSTRAINT cool_rewards_pkey PRIMARY KEY (id);


--
-- Name: cool_seasons cool_seasons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_seasons
    ADD CONSTRAINT cool_seasons_pkey PRIMARY KEY (id);


--
-- Name: cool_status cool_status_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_status
    ADD CONSTRAINT cool_status_pkey PRIMARY KEY (id);


--
-- Name: cool_status cool_status_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_status
    ADD CONSTRAINT cool_status_user_id_key UNIQUE (user_id);


--
-- Name: countries countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT countries_pkey PRIMARY KEY (id);


--
-- Name: driver_subscriptions driver_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.driver_subscriptions
    ADD CONSTRAINT driver_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: edge_function_rate_events edge_function_rate_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edge_function_rate_events
    ADD CONSTRAINT edge_function_rate_events_pkey PRIMARY KEY (id);


--
-- Name: fan_engagement_token_catalog fan_engagement_token_catalog_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_engagement_token_catalog
    ADD CONSTRAINT fan_engagement_token_catalog_pkey PRIMARY KEY (id);


--
-- Name: group_contributions group_contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_contributions
    ADD CONSTRAINT group_contributions_pkey PRIMARY KEY (id);


--
-- Name: group_members group_members_group_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_group_id_user_id_key UNIQUE (group_id, user_id);


--
-- Name: group_members group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_pkey PRIMARY KEY (id);


--
-- Name: group_messages group_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_messages
    ADD CONSTRAINT group_messages_pkey PRIMARY KEY (id);


--
-- Name: momo_ledger_entries momo_ledger_entries_parsed_sms_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_ledger_entries
    ADD CONSTRAINT momo_ledger_entries_parsed_sms_id_key UNIQUE (parsed_sms_id);


--
-- Name: momo_ledger_entries momo_ledger_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_ledger_entries
    ADD CONSTRAINT momo_ledger_entries_pkey PRIMARY KEY (id);


--
-- Name: momo_parse_attempts momo_parse_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_parse_attempts
    ADD CONSTRAINT momo_parse_attempts_pkey PRIMARY KEY (id);


--
-- Name: momo_parse_attempts momo_parse_attempts_unique_attempt; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_parse_attempts
    ADD CONSTRAINT momo_parse_attempts_unique_attempt UNIQUE (raw_sms_id, provider, attempt_number);


--
-- Name: momo_reconciliations momo_reconciliations_parsed_sms_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_reconciliations
    ADD CONSTRAINT momo_reconciliations_parsed_sms_id_key UNIQUE (parsed_sms_id);


--
-- Name: momo_reconciliations momo_reconciliations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_reconciliations
    ADD CONSTRAINT momo_reconciliations_pkey PRIMARY KEY (id);


--
-- Name: momo_sms_parsed momo_sms_parsed_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_parsed
    ADD CONSTRAINT momo_sms_parsed_pkey PRIMARY KEY (id);


--
-- Name: momo_sms_parsed momo_sms_parsed_raw_sms_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_parsed
    ADD CONSTRAINT momo_sms_parsed_raw_sms_id_key UNIQUE (raw_sms_id);


--
-- Name: momo_sms_raw momo_sms_raw_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_raw
    ADD CONSTRAINT momo_sms_raw_pkey PRIMARY KEY (id);


--
-- Name: momo_sms_raw momo_sms_raw_user_message_key_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_raw
    ADD CONSTRAINT momo_sms_raw_user_message_key_unique UNIQUE (user_id, device_message_key);


--
-- Name: momo_sms_sender_allowlist momo_sms_sender_allowlist_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_sender_allowlist
    ADD CONSTRAINT momo_sms_sender_allowlist_pkey PRIMARY KEY (id);


--
-- Name: momo_sms_sender_allowlist momo_sms_sender_allowlist_token_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_sender_allowlist
    ADD CONSTRAINT momo_sms_sender_allowlist_token_unique UNIQUE (sender_token);


--
-- Name: momo_sms_sender_inventory_resolutions momo_sms_sender_inventory_resolutions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_sender_inventory_resolutions
    ADD CONSTRAINT momo_sms_sender_inventory_resolutions_pkey PRIMARY KEY (sender_token);


--
-- Name: momo_sms_sync_runs momo_sms_sync_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_sync_runs
    ADD CONSTRAINT momo_sms_sync_runs_pkey PRIMARY KEY (id);


--
-- Name: nexus_opportunities nexus_opportunities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.nexus_opportunities
    ADD CONSTRAINT nexus_opportunities_pkey PRIMARY KEY (id);


--
-- Name: notification_events notification_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_events
    ADD CONSTRAINT notification_events_pkey PRIMARY KEY (id);


--
-- Name: operational_health_events operational_health_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_health_events
    ADD CONSTRAINT operational_health_events_pkey PRIMARY KEY (id);


--
-- Name: otp_codes otp_codes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_codes
    ADD CONSTRAINT otp_codes_pkey PRIMARY KEY (id);


--
-- Name: otp_rate_events otp_rate_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.otp_rate_events
    ADD CONSTRAINT otp_rate_events_pkey PRIMARY KEY (id);


--
-- Name: partner_payment_routes partner_payment_routes_partner_id_country_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_payment_routes
    ADD CONSTRAINT partner_payment_routes_partner_id_country_key UNIQUE (partner_id, country);


--
-- Name: partner_payment_routes partner_payment_routes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_payment_routes
    ADD CONSTRAINT partner_payment_routes_pkey PRIMARY KEY (id);


--
-- Name: partner_services partner_services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_services
    ADD CONSTRAINT partner_services_pkey PRIMARY KEY (id);


--
-- Name: partners partners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_pkey PRIMARY KEY (id);


--
-- Name: partners partners_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_slug_key UNIQUE (slug);


--
-- Name: payment_identities payment_identities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_identities
    ADD CONSTRAINT payment_identities_pkey PRIMARY KEY (id);


--
-- Name: payment_identities payment_identities_unique_identity; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_identities
    ADD CONSTRAINT payment_identities_unique_identity UNIQUE NULLS NOT DISTINCT (user_id, normalized_name, number_last_3);


--
-- Name: payment_intents payment_intents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_intents
    ADD CONSTRAINT payment_intents_pkey PRIMARY KEY (id);


--
-- Name: payment_receiver_accounts payment_receiver_accounts_payee_number_or_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_receiver_accounts
    ADD CONSTRAINT payment_receiver_accounts_payee_number_or_code_key UNIQUE (payee_number_or_code);


--
-- Name: payment_receiver_accounts payment_receiver_accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_receiver_accounts
    ADD CONSTRAINT payment_receiver_accounts_pkey PRIMARY KEY (id);


--
-- Name: pending_transactions pending_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_transactions
    ADD CONSTRAINT pending_transactions_pkey PRIMARY KEY (id);


--
-- Name: pending_transactions pending_transactions_reference_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_transactions
    ADD CONSTRAINT pending_transactions_reference_key UNIQUE (reference);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: pwa_engagement_events pwa_engagement_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pwa_engagement_events
    ADD CONSTRAINT pwa_engagement_events_pkey PRIMARY KEY (id);


--
-- Name: quest_definitions quest_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quest_definitions
    ADD CONSTRAINT quest_definitions_pkey PRIMARY KEY (id);


--
-- Name: quest_definitions quest_definitions_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quest_definitions
    ADD CONSTRAINT quest_definitions_slug_key UNIQUE (slug);


--
-- Name: quest_progress quest_progress_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quest_progress
    ADD CONSTRAINT quest_progress_pkey PRIMARY KEY (id);


--
-- Name: quest_progress quest_progress_quest_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quest_progress
    ADD CONSTRAINT quest_progress_quest_id_user_id_key UNIQUE (quest_id, user_id);


--
-- Name: quest_progress quest_progress_reward_dedupe_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quest_progress
    ADD CONSTRAINT quest_progress_reward_dedupe_key_key UNIQUE (reward_dedupe_key);


--
-- Name: quick_actions quick_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quick_actions
    ADD CONSTRAINT quick_actions_pkey PRIMARY KEY (id);


--
-- Name: request_rate_limits request_rate_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_rate_limits
    ADD CONSTRAINT request_rate_limits_pkey PRIMARY KEY (bucket_key);


--
-- Name: achievements rs_achievements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.achievements
    ADD CONSTRAINT rs_achievements_pkey PRIMARY KEY (id);


--
-- Name: achievements rs_achievements_unique_user_badge; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.achievements
    ADD CONSTRAINT rs_achievements_unique_user_badge UNIQUE (user_id, partner_id, badge_type);


--
-- Name: fan_club_members rs_fan_club_members_club_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_club_members
    ADD CONSTRAINT rs_fan_club_members_club_id_user_id_key UNIQUE (club_id, user_id);


--
-- Name: fan_club_members rs_fan_club_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_club_members
    ADD CONSTRAINT rs_fan_club_members_pkey PRIMARY KEY (id);


--
-- Name: fan_clubs rs_fan_clubs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_clubs
    ADD CONSTRAINT rs_fan_clubs_pkey PRIMARY KEY (id);


--
-- Name: fan_clubs rs_fan_clubs_unique_partner_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_clubs
    ADD CONSTRAINT rs_fan_clubs_unique_partner_name UNIQUE (partner_id, name);


--
-- Name: fan_memberships rs_fan_memberships_membership_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_memberships
    ADD CONSTRAINT rs_fan_memberships_membership_number_key UNIQUE (membership_number);


--
-- Name: fan_memberships rs_fan_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_memberships
    ADD CONSTRAINT rs_fan_memberships_pkey PRIMARY KEY (id);


--
-- Name: fan_memberships rs_fan_memberships_user_id_partner_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_memberships
    ADD CONSTRAINT rs_fan_memberships_user_id_partner_id_key UNIQUE (user_id, partner_id);


--
-- Name: home_banners rs_home_banners_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.home_banners
    ADD CONSTRAINT rs_home_banners_pkey PRIMARY KEY (id);


--
-- Name: initiative_contributions rs_initiative_contributions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.initiative_contributions
    ADD CONSTRAINT rs_initiative_contributions_pkey PRIMARY KEY (id);


--
-- Name: initiatives rs_initiatives_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.initiatives
    ADD CONSTRAINT rs_initiatives_pkey PRIMARY KEY (id);


--
-- Name: initiatives rs_initiatives_unique_partner_title; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.initiatives
    ADD CONSTRAINT rs_initiatives_unique_partner_title UNIQUE (partner_id, title);


--
-- Name: matches rs_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT rs_matches_pkey PRIMARY KEY (id);


--
-- Name: membership_packages rs_membership_packages_partner_id_tier_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_packages
    ADD CONSTRAINT rs_membership_packages_partner_id_tier_key UNIQUE (partner_id, tier);


--
-- Name: membership_packages rs_membership_packages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_packages
    ADD CONSTRAINT rs_membership_packages_pkey PRIMARY KEY (id);


--
-- Name: news_articles rs_news_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_articles
    ADD CONSTRAINT rs_news_articles_pkey PRIMARY KEY (id);


--
-- Name: notifications rs_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT rs_notifications_pkey PRIMARY KEY (id);


--
-- Name: shop_orders rs_shop_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_orders
    ADD CONSTRAINT rs_shop_orders_pkey PRIMARY KEY (id);


--
-- Name: shop_products rs_shop_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_products
    ADD CONSTRAINT rs_shop_products_pkey PRIMARY KEY (id);


--
-- Name: shop_products rs_shop_products_unique_partner_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_products
    ADD CONSTRAINT rs_shop_products_unique_partner_name UNIQUE (partner_id, name);


--
-- Name: tickets rs_tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT rs_tickets_pkey PRIMARY KEY (id);


--
-- Name: season_definitions season_definitions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.season_definitions
    ADD CONSTRAINT season_definitions_pkey PRIMARY KEY (id);


--
-- Name: season_definitions season_definitions_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.season_definitions
    ADD CONSTRAINT season_definitions_slug_key UNIQUE (slug);


--
-- Name: season_memberships season_memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.season_memberships
    ADD CONSTRAINT season_memberships_pkey PRIMARY KEY (id);


--
-- Name: season_memberships season_memberships_season_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.season_memberships
    ADD CONSTRAINT season_memberships_season_id_user_id_key UNIQUE (season_id, user_id);


--
-- Name: special_products special_products_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_products
    ADD CONSTRAINT special_products_pkey PRIMARY KEY (id);


--
-- Name: special_products special_products_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.special_products
    ADD CONSTRAINT special_products_slug_key UNIQUE (slug);


--
-- Name: squad_players squad_players_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.squad_players
    ADD CONSTRAINT squad_players_pkey PRIMARY KEY (id);


--
-- Name: standings standings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standings
    ADD CONSTRAINT standings_pkey PRIMARY KEY (id);


--
-- Name: african_football_clubs uq_african_football_clubs_name; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.african_football_clubs
    ADD CONSTRAINT uq_african_football_clubs_name UNIQUE (club_name);


--
-- Name: user_fcm_tokens uq_user_fcm_token; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_fcm_tokens
    ADD CONSTRAINT uq_user_fcm_token UNIQUE (user_id, token);


--
-- Name: user_fcm_tokens user_fcm_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_fcm_tokens
    ADD CONSTRAINT user_fcm_tokens_pkey PRIMARY KEY (id);


--
-- Name: user_notification_settings user_notification_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_notification_settings
    ADD CONSTRAINT user_notification_settings_pkey PRIMARY KEY (user_id);


--
-- Name: user_privacy_settings user_privacy_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_privacy_settings
    ADD CONSTRAINT user_privacy_settings_pkey PRIMARY KEY (user_id);


--
-- Name: user_private_contacts user_private_contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_private_contacts
    ADD CONSTRAINT user_private_contacts_pkey PRIMARY KEY (user_id);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: vehicle_types vehicle_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_types
    ADD CONSTRAINT vehicle_types_pkey PRIMARY KEY (id);


--
-- Name: vehicle_types vehicle_types_value_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.vehicle_types
    ADD CONSTRAINT vehicle_types_value_key UNIQUE (value);


--
-- Name: wallet_pass_events wallet_pass_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_pass_events
    ADD CONSTRAINT wallet_pass_events_pkey PRIMARY KEY (id);


--
-- Name: wallet_passes wallet_passes_pass_type_entity_type_entity_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_passes
    ADD CONSTRAINT wallet_passes_pass_type_entity_type_entity_id_key UNIQUE (pass_type, entity_type, entity_id);


--
-- Name: wallet_passes wallet_passes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_passes
    ADD CONSTRAINT wallet_passes_pkey PRIMARY KEY (id);


--
-- Name: wallet_passes wallet_passes_provider_google_object_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_passes
    ADD CONSTRAINT wallet_passes_provider_google_object_id_key UNIQUE (provider, google_object_id);


--
-- Name: web_push_subscriptions web_push_subscriptions_endpoint_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_push_subscriptions
    ADD CONSTRAINT web_push_subscriptions_endpoint_key UNIQUE (endpoint);


--
-- Name: web_push_subscriptions web_push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_push_subscriptions
    ADD CONSTRAINT web_push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: xp_events xp_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xp_events
    ADD CONSTRAINT xp_events_pkey PRIMARY KEY (id);


--
-- Name: biopay_embedding_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_embedding_idx ON public.biopay_embeddings USING ivfflat (embedding extensions.vector_cosine_ops) WITH (lists='64');


--
-- Name: biopay_embeddings_active_payee_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_embeddings_active_payee_idx ON public.biopay_embeddings USING btree (payee_id, created_at DESC) WHERE ((is_active = true) AND (revoked_at IS NULL));


--
-- Name: biopay_embeddings_payee_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_embeddings_payee_id_idx ON public.biopay_embeddings USING btree (payee_id);


--
-- Name: biopay_enrollment_audits_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_enrollment_audits_user_idx ON public.biopay_enrollment_audits USING btree (user_id, created_at DESC);


--
-- Name: biopay_events_actor_supabase_uid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_events_actor_supabase_uid_idx ON public.biopay_events USING btree (actor_supabase_uid);


--
-- Name: biopay_events_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_events_occurred_at_idx ON public.biopay_events USING btree (occurred_at DESC);


--
-- Name: biopay_events_payee_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_events_payee_id_idx ON public.biopay_events USING btree (payee_id);


--
-- Name: biopay_match_events_requester_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_match_events_requester_user_idx ON public.biopay_match_events USING btree (requester_user_id, created_at DESC);


--
-- Name: biopay_match_rate_events_requester_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_match_rate_events_requester_created_idx ON public.biopay_match_rate_events USING btree (requester_user_id, created_at DESC);


--
-- Name: biopay_match_rate_events_scope_actor_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_match_rate_events_scope_actor_created_idx ON public.biopay_match_rate_events USING btree (scope, actor_key, created_at DESC);


--
-- Name: biopay_nfc_tokens_expires_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_nfc_tokens_expires_at_idx ON public.biopay_nfc_tokens USING btree (expires_at DESC);


--
-- Name: biopay_nfc_tokens_payee_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_nfc_tokens_payee_id_idx ON public.biopay_nfc_tokens USING btree (payee_id);


--
-- Name: biopay_payees_supabase_uid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_payees_supabase_uid_idx ON public.biopay_payees USING btree (supabase_uid);


--
-- Name: biopay_profiles_public_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_profiles_public_id_idx ON public.biopay_profiles USING btree (public_id);


--
-- Name: biopay_profiles_user_id_club_id_active_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX biopay_profiles_user_id_club_id_active_idx ON public.biopay_profiles USING btree (user_id, club_id) WHERE (deleted_at IS NULL);


--
-- Name: biopay_revocations_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_revocations_user_idx ON public.biopay_revocations USING btree (user_id, created_at DESC);


--
-- Name: biopay_web_events_actor_supabase_uid_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_web_events_actor_supabase_uid_idx ON public.biopay_web_events USING btree (actor_supabase_uid);


--
-- Name: biopay_web_events_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_web_events_occurred_at_idx ON public.biopay_web_events USING btree (occurred_at DESC);


--
-- Name: biopay_web_events_type_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_web_events_type_idx ON public.biopay_web_events USING btree (event_type);


--
-- Name: biopay_web_push_subscriptions_actor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_web_push_subscriptions_actor_idx ON public.biopay_web_push_subscriptions USING btree (actor_supabase_uid);


--
-- Name: biopay_web_push_subscriptions_last_seen_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX biopay_web_push_subscriptions_last_seen_idx ON public.biopay_web_push_subscriptions USING btree (last_seen_at DESC);


--
-- Name: idx_admin_audit_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_audit_club ON public.admin_audit_log USING btree (club_id);


--
-- Name: idx_admin_audit_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_audit_entity ON public.admin_audit_log USING btree (entity_type, entity_id);


--
-- Name: idx_admin_audit_log_actor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_audit_log_actor_id ON public.admin_audit_log USING btree (actor_id);


--
-- Name: idx_admin_audit_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_audit_user ON public.admin_audit_log USING btree (user_id);


--
-- Name: idx_admin_role_assignments_granted_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_role_assignments_granted_by ON public.admin_role_assignments USING btree (granted_by);


--
-- Name: idx_admin_role_assignments_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_role_assignments_role ON public.admin_role_assignments USING btree (role) WHERE (is_active = true);


--
-- Name: idx_admin_role_assignments_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_role_assignments_user_id ON public.admin_role_assignments USING btree (user_id) WHERE (is_active = true);


--
-- Name: idx_admin_roles_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_roles_club ON public.admin_role_assignments USING btree (club_id);


--
-- Name: idx_admin_roles_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_roles_user ON public.admin_role_assignments USING btree (user_id, is_active) WHERE (is_active = true);


--
-- Name: idx_afc_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_afc_active ON public.african_football_clubs USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_afc_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_afc_country ON public.african_football_clubs USING btree (country_iso_code);


--
-- Name: idx_afc_fan_base; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_afc_fan_base ON public.african_football_clubs USING btree (estimated_fan_base DESC);


--
-- Name: idx_afc_league; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_afc_league ON public.african_football_clubs USING btree (league);


--
-- Name: idx_afc_region; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_afc_region ON public.african_football_clubs USING btree (region);


--
-- Name: idx_afc_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_afc_slug ON public.african_football_clubs USING btree (club_slug) WHERE (club_slug IS NOT NULL);


--
-- Name: idx_ai_content_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_content_created_by ON public.ai_content USING btree (created_by);


--
-- Name: idx_ai_content_generation_config_updated_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_content_generation_config_updated_by ON public.ai_content_generation_config USING btree (updated_by);


--
-- Name: idx_ai_content_reviewed_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_content_reviewed_by ON public.ai_content USING btree (reviewed_by);


--
-- Name: idx_ai_content_status_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ai_content_status_active ON public.ai_content USING btree (status, is_active) WHERE ((status = 'approved'::public.ai_content_status) AND (is_active = true));


--
-- Name: idx_biopay_enrollment_audits_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_enrollment_audits_club ON public.biopay_enrollment_audits USING btree (club_id);


--
-- Name: idx_biopay_enrollment_audits_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_enrollment_audits_profile_id ON public.biopay_enrollment_audits USING btree (profile_id);


--
-- Name: idx_biopay_intents_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_intents_club ON public.biopay_payment_intents USING btree (club_id);


--
-- Name: idx_biopay_intents_nonce; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_intents_nonce ON public.biopay_payment_intents USING btree (nonce) WHERE (status = 'pending'::text);


--
-- Name: idx_biopay_intents_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_intents_user ON public.biopay_payment_intents USING btree (user_id, created_at DESC);


--
-- Name: idx_biopay_liveness_challenges_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_liveness_challenges_open ON public.biopay_liveness_challenges USING btree (expires_at) WHERE (consumed_at IS NULL);


--
-- Name: idx_biopay_liveness_challenges_user_club_mode; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_liveness_challenges_user_club_mode ON public.biopay_liveness_challenges USING btree (user_id, club_id, mode, created_at DESC);


--
-- Name: idx_biopay_match_events_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_match_events_club ON public.biopay_match_events USING btree (club_id);


--
-- Name: idx_biopay_match_events_matched_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_match_events_matched_profile_id ON public.biopay_match_events USING btree (matched_profile_id);


--
-- Name: idx_biopay_profiles_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_profiles_club ON public.biopay_profiles USING btree (club_id);


--
-- Name: idx_biopay_revocations_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_revocations_club ON public.biopay_revocations USING btree (club_id);


--
-- Name: idx_biopay_revocations_profile_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_biopay_revocations_profile_id ON public.biopay_revocations USING btree (profile_id);


--
-- Name: idx_contribution_groups_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contribution_groups_club ON public.groups USING btree (club_id, is_closed, created_at DESC);


--
-- Name: idx_contribution_groups_creator; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contribution_groups_creator ON public.groups USING btree (creator_id);


--
-- Name: idx_contribution_groups_invite; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contribution_groups_invite ON public.groups USING btree (invite_code) WHERE (invite_code IS NOT NULL);


--
-- Name: idx_contribution_groups_privacy; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contribution_groups_privacy ON public.groups USING btree (privacy);


--
-- Name: idx_contribution_groups_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contribution_groups_type ON public.groups USING btree (group_type);


--
-- Name: idx_contributions_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contributions_club ON public.contributions USING btree (club_id);


--
-- Name: idx_contributions_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contributions_created ON public.contributions USING btree (group_id, created_at DESC);


--
-- Name: idx_contributions_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contributions_group ON public.group_contributions USING btree (group_id);


--
-- Name: idx_contributions_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contributions_status ON public.group_contributions USING btree (status);


--
-- Name: idx_contributions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_contributions_user ON public.contributions USING btree (user_id);


--
-- Name: idx_cool_events_user_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cool_events_user_date ON public.cool_events USING btree (user_id, event_at DESC);


--
-- Name: idx_cool_events_user_dedupe; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_cool_events_user_dedupe ON public.cool_events USING btree (user_id, dedupe_key) WHERE (dedupe_key IS NOT NULL);


--
-- Name: idx_cool_missions_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cool_missions_active ON public.cool_missions USING btree (is_active, starts_at, ends_at);


--
-- Name: idx_cool_reward_redemptions_reward_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cool_reward_redemptions_reward_id ON public.cool_reward_redemptions USING btree (reward_id);


--
-- Name: idx_cool_reward_redemptions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cool_reward_redemptions_user_id ON public.cool_reward_redemptions USING btree (user_id);


--
-- Name: idx_cool_seasons_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cool_seasons_active ON public.cool_seasons USING btree (is_active, starts_at, ends_at);


--
-- Name: idx_cool_status_active_season_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cool_status_active_season_id ON public.cool_status USING btree (active_season_id);


--
-- Name: idx_cool_status_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cool_status_club ON public.cool_status USING btree (club_id);


--
-- Name: idx_cool_status_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_cool_status_user ON public.cool_status USING btree (user_id);


--
-- Name: idx_driver_subscriptions_driver_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_driver_subscriptions_driver_id ON public.driver_subscriptions USING btree (driver_id);


--
-- Name: idx_driver_subscriptions_momo_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_driver_subscriptions_momo_reference ON public.driver_subscriptions USING btree (momo_reference) WHERE (momo_reference IS NOT NULL);


--
-- Name: idx_ef_rate_events_user_fn_ts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ef_rate_events_user_fn_ts ON public.edge_function_rate_events USING btree (user_id, function_name, created_at DESC);


--
-- Name: idx_fan_club_members_tenant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fan_club_members_tenant ON public.fan_club_members USING btree (tenant_club_id);


--
-- Name: idx_fan_club_members_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fan_club_members_user ON public.fan_club_members USING btree (user_id);


--
-- Name: idx_fan_clubs_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fan_clubs_club ON public.fan_clubs USING btree (club_id);


--
-- Name: idx_fan_clubs_members; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fan_clubs_members ON public.fan_clubs USING btree (club_id, member_count DESC);


--
-- Name: idx_fan_clubs_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fan_clubs_partner ON public.fan_clubs USING btree (partner_id);


--
-- Name: idx_fan_memberships_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fan_memberships_partner ON public.fan_memberships USING btree (partner_id);


--
-- Name: idx_fan_memberships_points; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fan_memberships_points ON public.fan_memberships USING btree (club_id, points DESC);


--
-- Name: idx_fan_memberships_user_club; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_fan_memberships_user_club ON public.fan_memberships USING btree (user_id, club_id);


--
-- Name: idx_fet_catalog_club_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_fet_catalog_club_code ON public.fan_engagement_token_catalog USING btree (club_id, code);


--
-- Name: idx_fet_catalog_club_scope_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_fet_catalog_club_scope_sort ON public.fan_engagement_token_catalog USING btree (club_id, template_scope, is_active, sort_order, code);


--
-- Name: idx_group_contributions_momo_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_group_contributions_momo_reference ON public.group_contributions USING btree (momo_reference) WHERE (momo_reference IS NOT NULL);


--
-- Name: idx_group_contributions_user_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_contributions_user_status_created ON public.group_contributions USING btree (user_id, status, created_at DESC);


--
-- Name: idx_group_members_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_members_group ON public.group_members USING btree (group_id);


--
-- Name: idx_group_members_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_members_user ON public.group_members USING btree (user_id);


--
-- Name: idx_group_messages_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_messages_created ON public.group_messages USING btree (group_id, created_at);


--
-- Name: idx_group_messages_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_messages_group ON public.group_messages USING btree (group_id);


--
-- Name: idx_group_messages_group_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_messages_group_created ON public.group_messages USING btree (group_id, created_at DESC);


--
-- Name: idx_groups_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_groups_country ON public.groups USING btree (country);


--
-- Name: idx_groups_creator_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_groups_creator_id ON public.groups USING btree (creator_id);


--
-- Name: idx_groups_visibility; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_groups_visibility ON public.groups USING btree (visibility);


--
-- Name: idx_initiative_contributions_reference; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_initiative_contributions_reference ON public.initiative_contributions USING btree (momo_reference);


--
-- Name: idx_initiative_contributions_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_initiative_contributions_user_created ON public.initiative_contributions USING btree (user_id, created_at DESC);


--
-- Name: idx_initiatives_club_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_initiatives_club_status ON public.initiatives USING btree (club_id, status, created_at DESC);


--
-- Name: idx_matches_featured; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_featured ON public.matches USING btree (club_id, is_featured, match_date);


--
-- Name: idx_matches_live_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_live_status ON public.matches USING btree (club_id, match_status, match_date);


--
-- Name: idx_matches_on_sale; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_on_sale ON public.matches USING btree (club_id, is_on_sale, match_date);


--
-- Name: idx_matches_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_matches_partner ON public.matches USING btree (partner_id, match_date);


--
-- Name: idx_membership_packages_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_membership_packages_club ON public.membership_packages USING btree (club_id, sort_order);


--
-- Name: idx_momo_ledger_entries_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_ledger_entries_category ON public.momo_ledger_entries USING btree (tx_category, cashflow_bucket);


--
-- Name: idx_momo_ledger_entries_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_ledger_entries_club ON public.momo_ledger_entries USING btree (club_id);


--
-- Name: idx_momo_ledger_entries_country_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_ledger_entries_country_code ON public.momo_ledger_entries USING btree (country_code);


--
-- Name: idx_momo_ledger_entries_payee_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_ledger_entries_payee_group ON public.momo_ledger_entries USING btree (payee_group_id, ledger_status, COALESCE(tx_datetime, created_at) DESC) WHERE (payee_group_id IS NOT NULL);


--
-- Name: idx_momo_ledger_entries_payee_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_ledger_entries_payee_partner ON public.momo_ledger_entries USING btree (payee_partner_id, ledger_status, COALESCE(tx_datetime, created_at) DESC) WHERE (payee_partner_id IS NOT NULL);


--
-- Name: idx_momo_ledger_entries_scope; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_ledger_entries_scope ON public.momo_ledger_entries USING btree (ledger_scope, ledger_status);


--
-- Name: idx_momo_ledger_entries_statement; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_ledger_entries_statement ON public.momo_ledger_entries USING btree (user_id, ledger_status, tx_datetime DESC);


--
-- Name: idx_momo_ledger_entries_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_ledger_entries_user ON public.momo_ledger_entries USING btree (user_id);


--
-- Name: idx_momo_ledger_entries_user_posted_statement_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_ledger_entries_user_posted_statement_at ON public.momo_ledger_entries USING btree (user_id, ledger_status, COALESCE(tx_datetime, created_at) DESC);


--
-- Name: idx_momo_ledger_user_extref; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_momo_ledger_user_extref ON public.momo_ledger_entries USING btree (user_id, external_reference) WHERE ((external_reference IS NOT NULL) AND (external_reference !~~ 'SMS-%'::text));


--
-- Name: idx_momo_parse_attempts_raw_sms; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_parse_attempts_raw_sms ON public.momo_parse_attempts USING btree (raw_sms_id, created_at DESC);


--
-- Name: idx_momo_parse_attempts_unique_attempt; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_momo_parse_attempts_unique_attempt ON public.momo_parse_attempts USING btree (raw_sms_id, provider, attempt_number);


--
-- Name: idx_momo_parse_attempts_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_parse_attempts_user ON public.momo_parse_attempts USING btree (user_id);


--
-- Name: idx_momo_parse_attempts_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_parse_attempts_user_id ON public.momo_parse_attempts USING btree (user_id);


--
-- Name: idx_momo_parsed_user_txid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_momo_parsed_user_txid ON public.momo_sms_parsed USING btree (user_id, momo_tx_id) WHERE (momo_tx_id IS NOT NULL);


--
-- Name: idx_momo_reconciliations_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_reconciliations_club ON public.momo_reconciliations USING btree (club_id);


--
-- Name: idx_momo_reconciliations_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_reconciliations_target ON public.momo_reconciliations USING btree (target_table, target_record_id);


--
-- Name: idx_momo_reconciliations_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_reconciliations_user ON public.momo_reconciliations USING btree (user_id);


--
-- Name: idx_momo_sms_parsed_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_parsed_category ON public.momo_sms_parsed USING btree (tx_category, cashflow_bucket);


--
-- Name: idx_momo_sms_parsed_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_parsed_club ON public.momo_sms_parsed USING btree (club_id);


--
-- Name: idx_momo_sms_parsed_country_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_parsed_country_code ON public.momo_sms_parsed USING btree (country_code);


--
-- Name: idx_momo_sms_parsed_momo_tx_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_parsed_momo_tx_id ON public.momo_sms_parsed USING btree (momo_tx_id);


--
-- Name: idx_momo_sms_parsed_tx_datetime; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_parsed_tx_datetime ON public.momo_sms_parsed USING btree (tx_datetime DESC);


--
-- Name: idx_momo_sms_parsed_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_parsed_user ON public.momo_sms_parsed USING btree (user_id);


--
-- Name: idx_momo_sms_raw_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_raw_club ON public.momo_sms_raw USING btree (club_id);


--
-- Name: idx_momo_sms_raw_country_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_raw_country_code ON public.momo_sms_raw USING btree (country_code);


--
-- Name: idx_momo_sms_raw_parse_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_raw_parse_status ON public.momo_sms_raw USING btree (parse_status);


--
-- Name: idx_momo_sms_raw_received_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_raw_received_at ON public.momo_sms_raw USING btree (sms_received_at DESC);


--
-- Name: idx_momo_sms_raw_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_raw_user ON public.momo_sms_raw USING btree (user_id);


--
-- Name: idx_momo_sms_raw_user_message_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_momo_sms_raw_user_message_key ON public.momo_sms_raw USING btree (user_id, device_message_key);


--
-- Name: idx_momo_sms_sender_allowlist_active_sort; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_sender_allowlist_active_sort ON public.momo_sms_sender_allowlist USING btree (active, sort_order, sender_display);


--
-- Name: idx_momo_sms_sender_inv_res_resolved_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_sender_inv_res_resolved_by ON public.momo_sms_sender_inventory_resolutions USING btree (resolved_by);


--
-- Name: idx_momo_sms_sender_inventory_resolutions_resolved_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_sender_inventory_resolutions_resolved_at ON public.momo_sms_sender_inventory_resolutions USING btree (resolved_at DESC);


--
-- Name: idx_momo_sms_sync_runs_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_sync_runs_user_created ON public.momo_sms_sync_runs USING btree (user_id, created_at DESC);


--
-- Name: idx_momo_sms_sync_runs_user_trigger; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_momo_sms_sync_runs_user_trigger ON public.momo_sms_sync_runs USING btree (user_id, trigger, status, created_at DESC);


--
-- Name: idx_news_articles_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_articles_club ON public.news_articles USING btree (club_id);


--
-- Name: idx_news_articles_published; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_news_articles_published ON public.news_articles USING btree (is_published, published_at DESC) WHERE (is_published = true);


--
-- Name: idx_notification_events_topic_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_events_topic_created_at ON public.notification_events USING btree (topic, created_at DESC) WHERE (topic IS NOT NULL);


--
-- Name: idx_notification_events_user_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notification_events_user_created_at ON public.notification_events USING btree (user_id, created_at DESC);


--
-- Name: idx_notifications_club_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_club_created ON public.notifications USING btree (club_id, created_at DESC);


--
-- Name: idx_notifications_club_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_club_status ON public.notifications USING btree (club_id, status, created_at DESC);


--
-- Name: idx_notifications_dispatch_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_dispatch_queue ON public.notifications USING btree (status, scheduled_at) WHERE (status = 'scheduled'::text);


--
-- Name: idx_operational_health_events_origin_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operational_health_events_origin_time ON public.operational_health_events USING btree (ingest_origin, occurred_at DESC);


--
-- Name: idx_operational_health_events_status_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operational_health_events_status_time ON public.operational_health_events USING btree (status, occurred_at DESC);


--
-- Name: idx_operational_health_events_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operational_health_events_user_id ON public.operational_health_events USING btree (user_id);


--
-- Name: idx_operational_health_service_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operational_health_service_created ON public.operational_health_events USING btree (service, created_at DESC);


--
-- Name: idx_operational_health_status_severity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operational_health_status_severity ON public.operational_health_events USING btree (status, severity, created_at DESC);


--
-- Name: idx_operational_health_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_operational_health_user_created ON public.operational_health_events USING btree (user_id, created_at DESC);


--
-- Name: idx_otp_codes_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_otp_codes_phone ON public.otp_codes USING btree (phone);


--
-- Name: idx_partner_payment_routes_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_partner_payment_routes_partner ON public.partner_payment_routes USING btree (partner_id, status);


--
-- Name: idx_partner_payment_routes_partner_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_partner_payment_routes_partner_status ON public.partner_payment_routes USING btree (partner_id, status, country);


--
-- Name: idx_partner_services_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_partner_services_country ON public.partner_services USING btree (country);


--
-- Name: idx_partner_services_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_partner_services_partner ON public.partner_services USING btree (partner_id);


--
-- Name: idx_partners_slug_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_partners_slug_unique ON public.partners USING btree (slug) WHERE (slug IS NOT NULL);


--
-- Name: idx_payment_identities_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_identities_search ON public.payment_identities USING btree (normalized_name, number_last_3);


--
-- Name: idx_payment_identities_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_identities_user ON public.payment_identities USING btree (user_id);


--
-- Name: idx_payment_intents_receiver; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_intents_receiver ON public.payment_intents USING btree (receiving_account_id, status);


--
-- Name: idx_payment_intents_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_intents_target ON public.payment_intents USING btree (target_table, target_record_id);


--
-- Name: idx_payment_intents_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_intents_user ON public.payment_intents USING btree (user_id);


--
-- Name: idx_payment_receiver_accounts_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_receiver_accounts_owner ON public.payment_receiver_accounts USING btree (owner_user_id);


--
-- Name: idx_payment_receiver_accounts_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_payment_receiver_accounts_partner ON public.payment_receiver_accounts USING btree (partner_id);


--
-- Name: idx_pending_transactions_group_contribution_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pending_transactions_group_contribution_id ON public.pending_transactions USING btree (group_contribution_id);


--
-- Name: idx_pending_transactions_group_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pending_transactions_group_id ON public.pending_transactions USING btree (group_id);


--
-- Name: idx_pending_transactions_reconciliation_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pending_transactions_reconciliation_lookup ON public.pending_transactions USING btree (user_id, status, amount, provider, created_at DESC);


--
-- Name: idx_profiles_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_profiles_club ON public.profiles USING btree (club_id);


--
-- Name: idx_profiles_public_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_profiles_public_user_id ON public.profiles USING btree (public_user_id);


--
-- Name: idx_pwa_engagement_events_club_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pwa_engagement_events_club_created ON public.pwa_engagement_events USING btree (club_id, created_at DESC);


--
-- Name: idx_pwa_engagement_events_type_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_pwa_engagement_events_type_created ON public.pwa_engagement_events USING btree (event_type, created_at DESC);


--
-- Name: idx_request_rate_limits_reset_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_request_rate_limits_reset_at ON public.request_rate_limits USING btree (reset_at);


--
-- Name: idx_rs_achievements_user_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_achievements_user_partner ON public.achievements USING btree (user_id, partner_id, earned_at DESC);


--
-- Name: idx_rs_fan_club_members_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_fan_club_members_club ON public.fan_club_members USING btree (club_id);


--
-- Name: idx_rs_fan_club_members_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_fan_club_members_user ON public.fan_club_members USING btree (user_id);


--
-- Name: idx_rs_fan_memberships_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_fan_memberships_partner ON public.fan_memberships USING btree (partner_id, tier, points DESC);


--
-- Name: idx_rs_fan_memberships_user_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_fan_memberships_user_partner ON public.fan_memberships USING btree (user_id, partner_id);


--
-- Name: idx_rs_initiative_contributions_initiative; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_initiative_contributions_initiative ON public.initiative_contributions USING btree (initiative_id, status);


--
-- Name: idx_rs_initiative_contributions_referral_invite_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_initiative_contributions_referral_invite_id ON public.initiative_contributions USING btree (referral_invite_id);


--
-- Name: idx_rs_initiative_contributions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_initiative_contributions_user_id ON public.initiative_contributions USING btree (user_id);


--
-- Name: idx_rs_initiatives_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_initiatives_partner ON public.initiatives USING btree (partner_id, is_active, ends_at);


--
-- Name: idx_rs_matches_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_matches_partner ON public.matches USING btree (partner_id, match_date);


--
-- Name: idx_rs_matches_partner_fixture; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rs_matches_partner_fixture ON public.matches USING btree (partner_id, home_team, away_team, match_date);


--
-- Name: idx_rs_membership_packages_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_membership_packages_partner ON public.membership_packages USING btree (partner_id, sort_order, tier);


--
-- Name: idx_rs_notifications_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_notifications_created_by ON public.notifications USING btree (created_by);


--
-- Name: idx_rs_notifications_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_notifications_match_id ON public.notifications USING btree (match_id);


--
-- Name: idx_rs_shop_orders_partner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_shop_orders_partner_id ON public.shop_orders USING btree (partner_id);


--
-- Name: idx_rs_shop_orders_referral_invite_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_shop_orders_referral_invite_id ON public.shop_orders USING btree (referral_invite_id);


--
-- Name: idx_rs_shop_orders_user_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_shop_orders_user_status ON public.shop_orders USING btree (user_id, status);


--
-- Name: idx_rs_shop_products_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_shop_products_partner ON public.shop_products USING btree (partner_id, is_active, category);


--
-- Name: idx_rs_tickets_match_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_tickets_match_id ON public.tickets USING btree (match_id);


--
-- Name: idx_rs_tickets_qr_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_rs_tickets_qr_code ON public.tickets USING btree (qr_code) WHERE (qr_code IS NOT NULL);


--
-- Name: idx_rs_tickets_referral_invite_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_tickets_referral_invite_id ON public.tickets USING btree (referral_invite_id);


--
-- Name: idx_rs_tickets_user_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rs_tickets_user_status ON public.tickets USING btree (user_id, status);


--
-- Name: idx_shop_orders_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shop_orders_club ON public.shop_orders USING btree (club_id);


--
-- Name: idx_shop_orders_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shop_orders_user ON public.shop_orders USING btree (user_id, created_at DESC);


--
-- Name: idx_shop_products_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shop_products_active ON public.shop_products USING btree (is_active) WHERE (is_active = true);


--
-- Name: idx_shop_products_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shop_products_category ON public.shop_products USING btree (category);


--
-- Name: idx_shop_products_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_shop_products_club ON public.shop_products USING btree (club_id);


--
-- Name: idx_squad_players_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_squad_players_club ON public.squad_players USING btree (club_id, shirt_number);


--
-- Name: idx_standings_club_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_standings_club_position ON public.standings USING btree (club_id, "position");


--
-- Name: idx_tickets_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_club ON public.tickets USING btree (club_id);


--
-- Name: idx_tickets_match; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_match ON public.tickets USING btree (match_id, status);


--
-- Name: idx_tickets_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_tickets_user_created ON public.tickets USING btree (user_id, purchased_at DESC);


--
-- Name: idx_user_fcm_tokens_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_fcm_tokens_club ON public.user_fcm_tokens USING btree (club_id);


--
-- Name: idx_user_fcm_tokens_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_fcm_tokens_user ON public.user_fcm_tokens USING btree (user_id);


--
-- Name: idx_user_notification_settings_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_notification_settings_club ON public.user_notification_settings USING btree (club_id);


--
-- Name: idx_user_privacy_settings_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_privacy_settings_club ON public.user_privacy_settings USING btree (club_id);


--
-- Name: idx_user_private_contacts_club; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_private_contacts_club ON public.user_private_contacts USING btree (club_id);


--
-- Name: idx_users_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_phone ON public.users USING btree (phone);


--
-- Name: idx_users_public_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_users_public_user_id ON public.users USING btree (public_user_id);


--
-- Name: idx_wallet_pass_events_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_pass_events_user_id ON public.wallet_pass_events USING btree (user_id);


--
-- Name: idx_wallet_pass_events_wallet_pass_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_pass_events_wallet_pass_id ON public.wallet_pass_events USING btree (wallet_pass_id);


--
-- Name: idx_wallet_passes_partner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_passes_partner ON public.wallet_passes USING btree (partner_id, created_at DESC);


--
-- Name: idx_wallet_passes_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_wallet_passes_user_id ON public.wallet_passes USING btree (user_id);


--
-- Name: idx_web_push_subscriptions_club_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_web_push_subscriptions_club_active ON public.web_push_subscriptions USING btree (club_id, disabled_at, last_seen_at DESC);


--
-- Name: idx_web_push_subscriptions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_web_push_subscriptions_user ON public.web_push_subscriptions USING btree (user_id, disabled_at, updated_at DESC);


--
-- Name: idx_xp_events_user_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_xp_events_user_date ON public.xp_events USING btree (user_id, event_at DESC);


--
-- Name: admin_role_assignments admin_phone_access_role_assignment_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admin_phone_access_role_assignment_sync AFTER INSERT OR DELETE OR UPDATE ON public.admin_role_assignments FOR EACH ROW EXECUTE FUNCTION public.sync_admin_phone_access_from_role_assignment();


--
-- Name: admin_role_assignments trg_admin_roles_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_admin_roles_updated BEFORE UPDATE ON public.admin_role_assignments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ai_content_generation_config trg_ai_content_generation_config_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ai_content_generation_config_set_updated_at BEFORE UPDATE ON public.ai_content_generation_config FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: ai_content trg_ai_content_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_ai_content_updated_at BEFORE UPDATE ON public.ai_content FOR EACH ROW EXECUTE FUNCTION public.ai_content_set_updated_at();


--
-- Name: app_config trg_app_config_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_app_config_updated BEFORE UPDATE ON public.app_config FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: users trg_assign_public_user_id; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_assign_public_user_id BEFORE INSERT OR UPDATE OF public_user_id ON public.users FOR EACH ROW EXECUTE FUNCTION public.assign_public_user_id();


--
-- Name: admin_role_assignments trg_audit_admin_role_assignments; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_admin_role_assignments AFTER INSERT OR DELETE OR UPDATE ON public.admin_role_assignments FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();


--
-- Name: app_config trg_audit_app_config; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_app_config AFTER INSERT OR DELETE OR UPDATE ON public.app_config FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();


--
-- Name: partner_services trg_audit_partner_services; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_partner_services AFTER INSERT OR DELETE OR UPDATE ON public.partner_services FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();


--
-- Name: partners trg_audit_partners; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_partners AFTER INSERT OR DELETE OR UPDATE ON public.partners FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();


--
-- Name: quick_actions trg_audit_quick_actions; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_quick_actions AFTER INSERT OR DELETE OR UPDATE ON public.quick_actions FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();


--
-- Name: vehicle_types trg_audit_vehicle_types; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit_vehicle_types AFTER INSERT OR DELETE OR UPDATE ON public.vehicle_types FOR EACH ROW EXECUTE FUNCTION public.log_admin_mutation();


--
-- Name: biopay_profiles trg_biopay_profiles_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_biopay_profiles_updated BEFORE UPDATE ON public.biopay_profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: groups trg_contribution_groups_partner_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_contribution_groups_partner_sync BEFORE INSERT OR UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();


--
-- Name: groups trg_contribution_groups_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_contribution_groups_updated BEFORE UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contributions trg_contribution_update_totals; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_contribution_update_totals AFTER UPDATE ON public.contributions FOR EACH ROW EXECUTE FUNCTION public.update_group_totals();


--
-- Name: contributions trg_contributions_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_contributions_updated BEFORE UPDATE ON public.contributions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: cool_activities trg_cool_activities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cool_activities_set_updated_at BEFORE UPDATE ON public.cool_activities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: cool_events trg_cool_events_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cool_events_scope BEFORE INSERT OR UPDATE ON public.cool_events FOR EACH ROW EXECUTE FUNCTION public.populate_event_club_scope();


--
-- Name: cool_mission_progress trg_cool_mission_progress_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cool_mission_progress_set_updated_at BEFORE UPDATE ON public.cool_mission_progress FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: cool_status trg_cool_status_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cool_status_set_updated_at BEFORE UPDATE ON public.cool_status FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: cool_status trg_cool_status_sync_fields; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_cool_status_sync_fields BEFORE INSERT OR UPDATE ON public.cool_status FOR EACH ROW EXECUTE FUNCTION public.sync_cool_status_fields();


--
-- Name: driver_subscriptions trg_driver_subscriptions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_driver_subscriptions_set_updated_at BEFORE UPDATE ON public.driver_subscriptions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: users trg_enforce_user_momo_fields; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_enforce_user_momo_fields BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.enforce_user_momo_fields();


--
-- Name: fan_club_members trg_fan_club_members_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fan_club_members_count AFTER INSERT OR DELETE ON public.fan_club_members FOR EACH ROW EXECUTE FUNCTION public.update_fan_club_member_count();


--
-- Name: fan_club_members trg_fan_club_members_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fan_club_members_scope BEFORE INSERT OR UPDATE ON public.fan_club_members FOR EACH ROW EXECUTE FUNCTION public.sync_fan_club_member_scope();


--
-- Name: fan_clubs trg_fan_clubs_partner_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fan_clubs_partner_sync BEFORE INSERT OR UPDATE ON public.fan_clubs FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();


--
-- Name: fan_clubs trg_fan_clubs_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fan_clubs_updated BEFORE UPDATE ON public.fan_clubs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: fan_memberships trg_fan_memberships_defaults; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fan_memberships_defaults BEFORE INSERT OR UPDATE ON public.fan_memberships FOR EACH ROW EXECUTE FUNCTION public.sync_fan_membership_defaults();


--
-- Name: fan_memberships trg_fan_memberships_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fan_memberships_updated BEFORE UPDATE ON public.fan_memberships FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: fan_engagement_token_catalog trg_fet_catalog_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fet_catalog_updated BEFORE UPDATE ON public.fan_engagement_token_catalog FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: group_members trg_group_member_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_group_member_count AFTER INSERT OR DELETE ON public.group_members FOR EACH ROW EXECUTE FUNCTION public.update_group_member_count();


--
-- Name: group_messages trg_group_messages_defaults; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_group_messages_defaults BEFORE INSERT OR UPDATE ON public.group_messages FOR EACH ROW EXECUTE FUNCTION public.populate_group_message_defaults();


--
-- Name: group_messages trg_group_messages_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_group_messages_updated BEFORE UPDATE ON public.group_messages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: groups trg_groups_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_groups_set_updated_at BEFORE UPDATE ON public.groups FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: initiative_contributions trg_initiative_contributions_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_initiative_contributions_scope BEFORE INSERT OR UPDATE ON public.initiative_contributions FOR EACH ROW EXECUTE FUNCTION public.sync_initiative_contribution_scope();


--
-- Name: initiative_contributions trg_initiative_contributions_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_initiative_contributions_updated BEFORE UPDATE ON public.initiative_contributions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: initiatives trg_initiatives_partner_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_initiatives_partner_sync BEFORE INSERT OR UPDATE ON public.initiatives FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();


--
-- Name: initiatives trg_initiatives_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_initiatives_updated BEFORE UPDATE ON public.initiatives FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: matches trg_matches_partner_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_matches_partner_sync BEFORE INSERT OR UPDATE ON public.matches FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();


--
-- Name: matches trg_matches_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_matches_updated BEFORE UPDATE ON public.matches FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: membership_packages trg_membership_packages_partner_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_membership_packages_partner_sync BEFORE INSERT OR UPDATE ON public.membership_packages FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();


--
-- Name: membership_packages trg_membership_packages_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_membership_packages_updated BEFORE UPDATE ON public.membership_packages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: momo_ledger_entries trg_momo_ledger_entries_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_momo_ledger_entries_set_updated_at BEFORE UPDATE ON public.momo_ledger_entries FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: momo_reconciliations trg_momo_reconciliations_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_momo_reconciliations_set_updated_at BEFORE UPDATE ON public.momo_reconciliations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: momo_sms_parsed trg_momo_sms_parsed_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_momo_sms_parsed_set_updated_at BEFORE UPDATE ON public.momo_sms_parsed FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: momo_sms_raw trg_momo_sms_raw_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_momo_sms_raw_set_updated_at BEFORE UPDATE ON public.momo_sms_raw FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: momo_sms_sender_allowlist trg_momo_sms_sender_allowlist_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_momo_sms_sender_allowlist_set_updated_at BEFORE UPDATE ON public.momo_sms_sender_allowlist FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: momo_sms_sender_inventory_resolutions trg_momo_sms_sender_inventory_resolutions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_momo_sms_sender_inventory_resolutions_set_updated_at BEFORE UPDATE ON public.momo_sms_sender_inventory_resolutions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: momo_sms_sync_runs trg_momo_sms_sync_runs_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_momo_sms_sync_runs_set_updated_at BEFORE UPDATE ON public.momo_sms_sync_runs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: nexus_opportunities trg_nexus_opportunities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_nexus_opportunities_set_updated_at BEFORE UPDATE ON public.nexus_opportunities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: notifications trg_notifications_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notifications_updated BEFORE UPDATE ON public.notifications FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: cool_mission_progress trg_notify_mission_completed; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify_mission_completed AFTER INSERT OR UPDATE OF completed_at ON public.cool_mission_progress FOR EACH ROW WHEN ((new.completed_at IS NOT NULL)) EXECUTE FUNCTION public.notify_mission_completed();


--
-- Name: partner_payment_routes trg_partner_payment_routes_partner_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_partner_payment_routes_partner_sync BEFORE INSERT OR UPDATE ON public.partner_payment_routes FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();


--
-- Name: partner_payment_routes trg_partner_payment_routes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_partner_payment_routes_set_updated_at BEFORE UPDATE ON public.partner_payment_routes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: partner_payment_routes trg_partner_payment_routes_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_partner_payment_routes_updated BEFORE UPDATE ON public.partner_payment_routes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: partner_payment_routes trg_partner_payment_routes_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_partner_payment_routes_validate BEFORE INSERT OR UPDATE ON public.partner_payment_routes FOR EACH ROW EXECUTE FUNCTION public.enforce_partner_payment_route_fields();


--
-- Name: partner_services trg_partner_services_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_partner_services_updated BEFORE UPDATE ON public.partner_services FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: partners trg_partners_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_partners_set_updated_at BEFORE UPDATE ON public.partners FOR EACH ROW EXECUTE FUNCTION public.partners_set_updated_at();


--
-- Name: payment_identities trg_payment_identities_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_payment_identities_set_updated_at BEFORE UPDATE ON public.payment_identities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: payment_intents trg_payment_intents_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_payment_intents_set_updated_at BEFORE UPDATE ON public.payment_intents FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: payment_receiver_accounts trg_payment_receiver_accounts_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_payment_receiver_accounts_set_updated_at BEFORE UPDATE ON public.payment_receiver_accounts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: pending_transactions trg_pending_transactions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_pending_transactions_set_updated_at BEFORE UPDATE ON public.pending_transactions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: profiles trg_profiles_sync_compat_columns; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_profiles_sync_compat_columns BEFORE INSERT OR UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.sync_profile_compat_columns();


--
-- Name: profiles trg_profiles_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: users trg_protect_users_is_admin; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_users_is_admin BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.protect_users_is_admin();


--
-- Name: quest_definitions trg_quest_definitions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quest_definitions_set_updated_at BEFORE UPDATE ON public.quest_definitions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quest_progress trg_quest_progress_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quest_progress_set_updated_at BEFORE UPDATE ON public.quest_progress FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: quick_actions trg_quick_actions_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_quick_actions_updated BEFORE UPDATE ON public.quick_actions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: fan_clubs trg_rs_fan_clubs_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_fan_clubs_set_updated_at BEFORE UPDATE ON public.fan_clubs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: fan_memberships trg_rs_fan_memberships_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_fan_memberships_set_updated_at BEFORE UPDATE ON public.fan_memberships FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: fan_memberships trg_rs_fan_memberships_sync_fields; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_fan_memberships_sync_fields BEFORE INSERT OR UPDATE ON public.fan_memberships FOR EACH ROW EXECUTE FUNCTION public.rs_sync_membership_fields();


--
-- Name: initiative_contributions trg_rs_initiative_contributions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_initiative_contributions_set_updated_at BEFORE UPDATE ON public.initiative_contributions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: initiatives trg_rs_initiatives_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_initiatives_set_updated_at BEFORE UPDATE ON public.initiatives FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: matches trg_rs_matches_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_matches_set_updated_at BEFORE UPDATE ON public.matches FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: membership_packages trg_rs_membership_packages_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_membership_packages_set_updated_at BEFORE UPDATE ON public.membership_packages FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: shop_orders trg_rs_shop_orders_decrement_stock; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_shop_orders_decrement_stock AFTER INSERT ON public.shop_orders FOR EACH ROW EXECUTE FUNCTION public.rs_decrement_stock_on_order();


--
-- Name: shop_orders trg_rs_shop_orders_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_shop_orders_set_updated_at BEFORE UPDATE ON public.shop_orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: shop_products trg_rs_shop_products_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_shop_products_set_updated_at BEFORE UPDATE ON public.shop_products FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: tickets trg_rs_tickets_check_capacity; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_tickets_check_capacity BEFORE INSERT ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.rs_check_ticket_capacity();


--
-- Name: tickets trg_rs_tickets_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rs_tickets_set_updated_at BEFORE UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: season_definitions trg_season_definitions_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_season_definitions_set_updated_at BEFORE UPDATE ON public.season_definitions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: season_memberships trg_season_memberships_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_season_memberships_set_updated_at BEFORE UPDATE ON public.season_memberships FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: shop_orders trg_shop_orders_partner_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_shop_orders_partner_sync BEFORE INSERT OR UPDATE ON public.shop_orders FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();


--
-- Name: shop_orders trg_shop_orders_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_shop_orders_updated BEFORE UPDATE ON public.shop_orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: shop_products trg_shop_products_partner_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_shop_products_partner_sync BEFORE INSERT OR UPDATE ON public.shop_products FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();


--
-- Name: special_products trg_special_products_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_special_products_set_updated_at BEFORE UPDATE ON public.special_products FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: squad_players trg_squad_players_partner_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_squad_players_partner_sync BEFORE INSERT OR UPDATE ON public.squad_players FOR EACH ROW EXECUTE FUNCTION public.sync_partner_club_columns();


--
-- Name: squad_players trg_squad_players_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_squad_players_updated BEFORE UPDATE ON public.squad_players FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: standings trg_standings_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_standings_updated BEFORE UPDATE ON public.standings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: group_contributions trg_sync_group_financials; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_group_financials AFTER INSERT OR DELETE OR UPDATE ON public.group_contributions FOR EACH ROW EXECUTE FUNCTION public.sync_group_financials();


--
-- Name: group_members trg_sync_group_member_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync_group_member_count AFTER INSERT OR DELETE OR UPDATE ON public.group_members FOR EACH ROW EXECUTE FUNCTION public.sync_group_member_count();


--
-- Name: tickets trg_tickets_sales_refresh; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tickets_sales_refresh AFTER INSERT OR DELETE OR UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.refresh_match_ticket_sales();


--
-- Name: tickets trg_tickets_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tickets_scope BEFORE INSERT OR UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.sync_ticket_scope();


--
-- Name: tickets trg_tickets_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_tickets_updated BEFORE UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: user_fcm_tokens trg_user_fcm_tokens_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_fcm_tokens_set_updated_at BEFORE UPDATE ON public.user_fcm_tokens FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: user_fcm_tokens trg_user_fcm_tokens_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_fcm_tokens_updated BEFORE UPDATE ON public.user_fcm_tokens FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: user_notification_settings trg_user_notification_settings_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_notification_settings_updated BEFORE UPDATE ON public.user_notification_settings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: user_privacy_settings trg_user_privacy_settings_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_privacy_settings_updated BEFORE UPDATE ON public.user_privacy_settings FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: user_private_contacts trg_user_private_contacts_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_user_private_contacts_updated BEFORE UPDATE ON public.user_private_contacts FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: users trg_users_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_set_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: vehicle_types trg_vehicle_types_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_vehicle_types_updated BEFORE UPDATE ON public.vehicle_types FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: wallet_passes trg_wallet_passes_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_wallet_passes_set_updated_at BEFORE UPDATE ON public.wallet_passes FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: web_push_subscriptions trg_web_push_subscriptions_updated; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_web_push_subscriptions_updated BEFORE UPDATE ON public.web_push_subscriptions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: xp_events trg_xp_events_scope; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_xp_events_scope BEFORE INSERT OR UPDATE ON public.xp_events FOR EACH ROW EXECUTE FUNCTION public.populate_event_club_scope();


--
-- Name: achievements achievements_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.achievements
    ADD CONSTRAINT achievements_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: admin_audit_log admin_audit_log_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_audit_log
    ADD CONSTRAINT admin_audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: admin_phone_access admin_phone_access_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_phone_access
    ADD CONSTRAINT admin_phone_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: admin_role_assignments admin_role_assignments_granted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_role_assignments
    ADD CONSTRAINT admin_role_assignments_granted_by_fkey FOREIGN KEY (granted_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: admin_role_assignments admin_role_assignments_partner_scope_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_role_assignments
    ADD CONSTRAINT admin_role_assignments_partner_scope_id_fkey FOREIGN KEY (partner_scope_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: admin_role_assignments admin_role_assignments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_role_assignments
    ADD CONSTRAINT admin_role_assignments_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: african_football_clubs african_football_clubs_country_iso_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.african_football_clubs
    ADD CONSTRAINT african_football_clubs_country_iso_code_fkey FOREIGN KEY (country_iso_code) REFERENCES public.countries(id);


--
-- Name: ai_content ai_content_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_content
    ADD CONSTRAINT ai_content_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id);


--
-- Name: ai_content_generation_config ai_content_generation_config_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_content_generation_config
    ADD CONSTRAINT ai_content_generation_config_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id);


--
-- Name: ai_content ai_content_reviewed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ai_content
    ADD CONSTRAINT ai_content_reviewed_by_fkey FOREIGN KEY (reviewed_by) REFERENCES auth.users(id);


--
-- Name: biopay_embeddings biopay_embeddings_payee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_embeddings
    ADD CONSTRAINT biopay_embeddings_payee_id_fkey FOREIGN KEY (payee_id) REFERENCES public.biopay_payees(id) ON DELETE CASCADE;


--
-- Name: biopay_enrollment_audits biopay_enrollment_audits_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_enrollment_audits
    ADD CONSTRAINT biopay_enrollment_audits_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: biopay_enrollment_audits biopay_enrollment_audits_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_enrollment_audits
    ADD CONSTRAINT biopay_enrollment_audits_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.biopay_profiles(id) ON DELETE CASCADE;


--
-- Name: biopay_enrollment_audits biopay_enrollment_audits_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_enrollment_audits
    ADD CONSTRAINT biopay_enrollment_audits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: biopay_events biopay_events_actor_supabase_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_events
    ADD CONSTRAINT biopay_events_actor_supabase_uid_fkey FOREIGN KEY (actor_supabase_uid) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: biopay_events biopay_events_payee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_events
    ADD CONSTRAINT biopay_events_payee_id_fkey FOREIGN KEY (payee_id) REFERENCES public.biopay_payees(id) ON DELETE SET NULL;


--
-- Name: biopay_liveness_challenges biopay_liveness_challenges_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_liveness_challenges
    ADD CONSTRAINT biopay_liveness_challenges_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id) ON DELETE CASCADE;


--
-- Name: biopay_liveness_challenges biopay_liveness_challenges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_liveness_challenges
    ADD CONSTRAINT biopay_liveness_challenges_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: biopay_match_events biopay_match_events_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_match_events
    ADD CONSTRAINT biopay_match_events_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: biopay_match_events biopay_match_events_matched_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_match_events
    ADD CONSTRAINT biopay_match_events_matched_profile_id_fkey FOREIGN KEY (matched_profile_id) REFERENCES public.biopay_profiles(id) ON DELETE SET NULL;


--
-- Name: biopay_match_events biopay_match_events_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_match_events
    ADD CONSTRAINT biopay_match_events_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: biopay_match_rate_events biopay_match_rate_events_requester_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_match_rate_events
    ADD CONSTRAINT biopay_match_rate_events_requester_user_id_fkey FOREIGN KEY (requester_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: biopay_nfc_tokens biopay_nfc_tokens_actor_supabase_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_nfc_tokens
    ADD CONSTRAINT biopay_nfc_tokens_actor_supabase_uid_fkey FOREIGN KEY (actor_supabase_uid) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: biopay_nfc_tokens biopay_nfc_tokens_payee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_nfc_tokens
    ADD CONSTRAINT biopay_nfc_tokens_payee_id_fkey FOREIGN KEY (payee_id) REFERENCES public.biopay_payees(id) ON DELETE CASCADE;


--
-- Name: biopay_payees biopay_payees_supabase_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_payees
    ADD CONSTRAINT biopay_payees_supabase_uid_fkey FOREIGN KEY (supabase_uid) REFERENCES auth.users(id);


--
-- Name: biopay_payment_intents biopay_payment_intents_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_payment_intents
    ADD CONSTRAINT biopay_payment_intents_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: biopay_payment_intents biopay_payment_intents_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_payment_intents
    ADD CONSTRAINT biopay_payment_intents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: biopay_profiles biopay_profiles_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_profiles
    ADD CONSTRAINT biopay_profiles_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: biopay_profiles biopay_profiles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_profiles
    ADD CONSTRAINT biopay_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: biopay_revocations biopay_revocations_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_revocations
    ADD CONSTRAINT biopay_revocations_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: biopay_revocations biopay_revocations_profile_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_revocations
    ADD CONSTRAINT biopay_revocations_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES public.biopay_profiles(id) ON DELETE CASCADE;


--
-- Name: biopay_revocations biopay_revocations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_revocations
    ADD CONSTRAINT biopay_revocations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: biopay_user_preferences biopay_user_preferences_supabase_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_user_preferences
    ADD CONSTRAINT biopay_user_preferences_supabase_uid_fkey FOREIGN KEY (supabase_uid) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: biopay_web_events biopay_web_events_actor_supabase_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_web_events
    ADD CONSTRAINT biopay_web_events_actor_supabase_uid_fkey FOREIGN KEY (actor_supabase_uid) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: biopay_web_push_subscriptions biopay_web_push_subscriptions_actor_supabase_uid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.biopay_web_push_subscriptions
    ADD CONSTRAINT biopay_web_push_subscriptions_actor_supabase_uid_fkey FOREIGN KEY (actor_supabase_uid) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: groups contribution_groups_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT contribution_groups_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: groups contribution_groups_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT contribution_groups_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: contributions contributions_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: contributions contributions_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: contributions contributions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contributions
    ADD CONSTRAINT contributions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: cool_achievements cool_achievements_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_achievements
    ADD CONSTRAINT cool_achievements_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: cool_achievements cool_achievements_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_achievements
    ADD CONSTRAINT cool_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: cool_events cool_events_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_events
    ADD CONSTRAINT cool_events_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: cool_events cool_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_events
    ADD CONSTRAINT cool_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: cool_invite_attributions cool_invite_attributions_invitee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_invite_attributions
    ADD CONSTRAINT cool_invite_attributions_invitee_id_fkey FOREIGN KEY (invitee_id) REFERENCES auth.users(id);


--
-- Name: cool_invite_attributions cool_invite_attributions_inviter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_invite_attributions
    ADD CONSTRAINT cool_invite_attributions_inviter_id_fkey FOREIGN KEY (inviter_id) REFERENCES auth.users(id);


--
-- Name: cool_mission_progress cool_mission_progress_mission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_mission_progress
    ADD CONSTRAINT cool_mission_progress_mission_id_fkey FOREIGN KEY (mission_id) REFERENCES public.cool_missions(id) ON DELETE CASCADE;


--
-- Name: cool_mission_progress cool_mission_progress_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_mission_progress
    ADD CONSTRAINT cool_mission_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: cool_missions cool_missions_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_missions
    ADD CONSTRAINT cool_missions_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: cool_reward_redemptions cool_reward_redemptions_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_reward_redemptions
    ADD CONSTRAINT cool_reward_redemptions_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: cool_reward_redemptions cool_reward_redemptions_reward_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_reward_redemptions
    ADD CONSTRAINT cool_reward_redemptions_reward_id_fkey FOREIGN KEY (reward_id) REFERENCES public.cool_rewards(id) ON DELETE CASCADE;


--
-- Name: cool_reward_redemptions cool_reward_redemptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_reward_redemptions
    ADD CONSTRAINT cool_reward_redemptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: cool_status cool_status_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_status
    ADD CONSTRAINT cool_status_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: cool_status cool_status_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_status
    ADD CONSTRAINT cool_status_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: driver_subscriptions driver_subscriptions_driver_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.driver_subscriptions
    ADD CONSTRAINT driver_subscriptions_driver_id_fkey FOREIGN KEY (driver_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: edge_function_rate_events edge_function_rate_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.edge_function_rate_events
    ADD CONSTRAINT edge_function_rate_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: fan_club_members fan_club_members_tenant_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_club_members
    ADD CONSTRAINT fan_club_members_tenant_club_id_fkey FOREIGN KEY (tenant_club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: fan_clubs fan_clubs_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_clubs
    ADD CONSTRAINT fan_clubs_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: fan_engagement_token_catalog fan_engagement_token_catalog_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_engagement_token_catalog
    ADD CONSTRAINT fan_engagement_token_catalog_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id) ON DELETE CASCADE;


--
-- Name: fan_memberships fan_memberships_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_memberships
    ADD CONSTRAINT fan_memberships_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: cool_status fk_cool_status_season; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.cool_status
    ADD CONSTRAINT fk_cool_status_season FOREIGN KEY (active_season_id) REFERENCES public.cool_seasons(id) ON DELETE SET NULL;


--
-- Name: momo_sms_raw fk_momo_sms_raw_country; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_raw
    ADD CONSTRAINT fk_momo_sms_raw_country FOREIGN KEY (country_code) REFERENCES public.countries(id) ON DELETE SET NULL;


--
-- Name: group_contributions group_contributions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_contributions
    ADD CONSTRAINT group_contributions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_members group_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_messages group_messages_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_messages
    ADD CONSTRAINT group_messages_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: group_messages group_messages_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_messages
    ADD CONSTRAINT group_messages_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: group_messages group_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_messages
    ADD CONSTRAINT group_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: initiative_contributions initiative_contributions_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.initiative_contributions
    ADD CONSTRAINT initiative_contributions_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: initiatives initiatives_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.initiatives
    ADD CONSTRAINT initiatives_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: matches matches_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT matches_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: membership_packages membership_packages_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_packages
    ADD CONSTRAINT membership_packages_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: momo_ledger_entries momo_ledger_entries_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_ledger_entries
    ADD CONSTRAINT momo_ledger_entries_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: momo_ledger_entries momo_ledger_entries_country_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_ledger_entries
    ADD CONSTRAINT momo_ledger_entries_country_code_fkey FOREIGN KEY (country_code) REFERENCES public.countries(id) ON DELETE SET NULL;


--
-- Name: momo_ledger_entries momo_ledger_entries_parsed_sms_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_ledger_entries
    ADD CONSTRAINT momo_ledger_entries_parsed_sms_id_fkey FOREIGN KEY (parsed_sms_id) REFERENCES public.momo_sms_parsed(id) ON DELETE CASCADE;


--
-- Name: momo_ledger_entries momo_ledger_entries_payee_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_ledger_entries
    ADD CONSTRAINT momo_ledger_entries_payee_partner_id_fkey FOREIGN KEY (payee_partner_id) REFERENCES public.partners(id) ON DELETE SET NULL;


--
-- Name: momo_ledger_entries momo_ledger_entries_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_ledger_entries
    ADD CONSTRAINT momo_ledger_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: momo_parse_attempts momo_parse_attempts_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_parse_attempts
    ADD CONSTRAINT momo_parse_attempts_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: momo_parse_attempts momo_parse_attempts_raw_sms_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_parse_attempts
    ADD CONSTRAINT momo_parse_attempts_raw_sms_id_fkey FOREIGN KEY (raw_sms_id) REFERENCES public.momo_sms_raw(id) ON DELETE CASCADE;


--
-- Name: momo_parse_attempts momo_parse_attempts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_parse_attempts
    ADD CONSTRAINT momo_parse_attempts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: momo_reconciliations momo_reconciliations_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_reconciliations
    ADD CONSTRAINT momo_reconciliations_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: momo_reconciliations momo_reconciliations_country_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_reconciliations
    ADD CONSTRAINT momo_reconciliations_country_code_fkey FOREIGN KEY (country_code) REFERENCES public.countries(id) ON DELETE SET NULL;


--
-- Name: momo_reconciliations momo_reconciliations_parsed_sms_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_reconciliations
    ADD CONSTRAINT momo_reconciliations_parsed_sms_id_fkey FOREIGN KEY (parsed_sms_id) REFERENCES public.momo_sms_parsed(id) ON DELETE CASCADE;


--
-- Name: momo_reconciliations momo_reconciliations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_reconciliations
    ADD CONSTRAINT momo_reconciliations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: momo_sms_parsed momo_sms_parsed_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_parsed
    ADD CONSTRAINT momo_sms_parsed_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: momo_sms_parsed momo_sms_parsed_country_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_parsed
    ADD CONSTRAINT momo_sms_parsed_country_code_fkey FOREIGN KEY (country_code) REFERENCES public.countries(id) ON DELETE SET NULL;


--
-- Name: momo_sms_parsed momo_sms_parsed_raw_sms_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_parsed
    ADD CONSTRAINT momo_sms_parsed_raw_sms_id_fkey FOREIGN KEY (raw_sms_id) REFERENCES public.momo_sms_raw(id) ON DELETE CASCADE;


--
-- Name: momo_sms_parsed momo_sms_parsed_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_parsed
    ADD CONSTRAINT momo_sms_parsed_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: momo_sms_raw momo_sms_raw_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_raw
    ADD CONSTRAINT momo_sms_raw_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: momo_sms_raw momo_sms_raw_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_raw
    ADD CONSTRAINT momo_sms_raw_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: momo_sms_sender_inventory_resolutions momo_sms_sender_inventory_resolutions_resolved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_sender_inventory_resolutions
    ADD CONSTRAINT momo_sms_sender_inventory_resolutions_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: momo_sms_sync_runs momo_sms_sync_runs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.momo_sms_sync_runs
    ADD CONSTRAINT momo_sms_sync_runs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: notification_events notification_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification_events
    ADD CONSTRAINT notification_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id) ON DELETE CASCADE;


--
-- Name: operational_health_events operational_health_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.operational_health_events
    ADD CONSTRAINT operational_health_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: partner_payment_routes partner_payment_routes_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_payment_routes
    ADD CONSTRAINT partner_payment_routes_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: partner_payment_routes partner_payment_routes_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_payment_routes
    ADD CONSTRAINT partner_payment_routes_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: partner_services partner_services_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.partner_services
    ADD CONSTRAINT partner_services_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: payment_identities payment_identities_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_identities
    ADD CONSTRAINT payment_identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: payment_intents payment_intents_receiving_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_intents
    ADD CONSTRAINT payment_intents_receiving_account_id_fkey FOREIGN KEY (receiving_account_id) REFERENCES public.payment_receiver_accounts(id) ON DELETE RESTRICT;


--
-- Name: payment_intents payment_intents_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_intents
    ADD CONSTRAINT payment_intents_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: payment_receiver_accounts payment_receiver_accounts_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_receiver_accounts
    ADD CONSTRAINT payment_receiver_accounts_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: payment_receiver_accounts payment_receiver_accounts_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_receiver_accounts
    ADD CONSTRAINT payment_receiver_accounts_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE SET NULL;


--
-- Name: pending_transactions pending_transactions_group_contribution_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_transactions
    ADD CONSTRAINT pending_transactions_group_contribution_id_fkey FOREIGN KEY (group_contribution_id) REFERENCES public.group_contributions(id) ON DELETE SET NULL;


--
-- Name: pending_transactions pending_transactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pending_transactions
    ADD CONSTRAINT pending_transactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: profiles profiles_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: profiles profiles_country_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_country_code_fkey FOREIGN KEY (country_code) REFERENCES public.countries(id);


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: pwa_engagement_events pwa_engagement_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pwa_engagement_events
    ADD CONSTRAINT pwa_engagement_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: quest_progress quest_progress_quest_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quest_progress
    ADD CONSTRAINT quest_progress_quest_id_fkey FOREIGN KEY (quest_id) REFERENCES public.quest_definitions(id) ON DELETE CASCADE;


--
-- Name: quest_progress quest_progress_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quest_progress
    ADD CONSTRAINT quest_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: achievements rs_achievements_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.achievements
    ADD CONSTRAINT rs_achievements_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: achievements rs_achievements_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.achievements
    ADD CONSTRAINT rs_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: fan_club_members rs_fan_club_members_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_club_members
    ADD CONSTRAINT rs_fan_club_members_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.fan_clubs(id) ON DELETE CASCADE;


--
-- Name: fan_club_members rs_fan_club_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_club_members
    ADD CONSTRAINT rs_fan_club_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: fan_clubs rs_fan_clubs_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_clubs
    ADD CONSTRAINT rs_fan_clubs_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: fan_memberships rs_fan_memberships_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_memberships
    ADD CONSTRAINT rs_fan_memberships_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: fan_memberships rs_fan_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fan_memberships
    ADD CONSTRAINT rs_fan_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: initiative_contributions rs_initiative_contributions_initiative_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.initiative_contributions
    ADD CONSTRAINT rs_initiative_contributions_initiative_id_fkey FOREIGN KEY (initiative_id) REFERENCES public.initiatives(id) ON DELETE CASCADE;


--
-- Name: initiative_contributions rs_initiative_contributions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.initiative_contributions
    ADD CONSTRAINT rs_initiative_contributions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: initiatives rs_initiatives_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.initiatives
    ADD CONSTRAINT rs_initiatives_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: matches rs_matches_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.matches
    ADD CONSTRAINT rs_matches_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: membership_packages rs_membership_packages_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.membership_packages
    ADD CONSTRAINT rs_membership_packages_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: news_articles rs_news_articles_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.news_articles
    ADD CONSTRAINT rs_news_articles_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: notifications rs_notifications_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT rs_notifications_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id) ON DELETE SET NULL;


--
-- Name: notifications rs_notifications_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT rs_notifications_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: shop_orders rs_shop_orders_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_orders
    ADD CONSTRAINT rs_shop_orders_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id);


--
-- Name: shop_orders rs_shop_orders_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_orders
    ADD CONSTRAINT rs_shop_orders_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: shop_products rs_shop_products_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_products
    ADD CONSTRAINT rs_shop_products_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: shop_products rs_shop_products_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_products
    ADD CONSTRAINT rs_shop_products_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE CASCADE;


--
-- Name: tickets rs_tickets_match_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT rs_tickets_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matches(id) ON DELETE CASCADE;


--
-- Name: tickets rs_tickets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT rs_tickets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: season_memberships season_memberships_season_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.season_memberships
    ADD CONSTRAINT season_memberships_season_id_fkey FOREIGN KEY (season_id) REFERENCES public.season_definitions(id) ON DELETE CASCADE;


--
-- Name: season_memberships season_memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.season_memberships
    ADD CONSTRAINT season_memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: shop_orders shop_orders_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shop_orders
    ADD CONSTRAINT shop_orders_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: squad_players squad_players_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.squad_players
    ADD CONSTRAINT squad_players_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: standings standings_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.standings
    ADD CONSTRAINT standings_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: tickets tickets_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: user_fcm_tokens user_fcm_tokens_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_fcm_tokens
    ADD CONSTRAINT user_fcm_tokens_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: user_fcm_tokens user_fcm_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_fcm_tokens
    ADD CONSTRAINT user_fcm_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_notification_settings user_notification_settings_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_notification_settings
    ADD CONSTRAINT user_notification_settings_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: user_notification_settings user_notification_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_notification_settings
    ADD CONSTRAINT user_notification_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_privacy_settings user_privacy_settings_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_privacy_settings
    ADD CONSTRAINT user_privacy_settings_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: user_privacy_settings user_privacy_settings_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_privacy_settings
    ADD CONSTRAINT user_privacy_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: user_private_contacts user_private_contacts_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_private_contacts
    ADD CONSTRAINT user_private_contacts_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: user_private_contacts user_private_contacts_country_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_private_contacts
    ADD CONSTRAINT user_private_contacts_country_code_fkey FOREIGN KEY (country_code) REFERENCES public.countries(id);


--
-- Name: user_private_contacts user_private_contacts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_private_contacts
    ADD CONSTRAINT user_private_contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: wallet_pass_events wallet_pass_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_pass_events
    ADD CONSTRAINT wallet_pass_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: wallet_pass_events wallet_pass_events_wallet_pass_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_pass_events
    ADD CONSTRAINT wallet_pass_events_wallet_pass_id_fkey FOREIGN KEY (wallet_pass_id) REFERENCES public.wallet_passes(id) ON DELETE CASCADE;


--
-- Name: wallet_passes wallet_passes_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_passes
    ADD CONSTRAINT wallet_passes_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id) ON DELETE SET NULL;


--
-- Name: wallet_passes wallet_passes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_passes
    ADD CONSTRAINT wallet_passes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: web_push_subscriptions web_push_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_push_subscriptions
    ADD CONSTRAINT web_push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: xp_events xp_events_club_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xp_events
    ADD CONSTRAINT xp_events_club_id_fkey FOREIGN KEY (club_id) REFERENCES public.african_football_clubs(id);


--
-- Name: xp_events xp_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.xp_events
    ADD CONSTRAINT xp_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: special_products Admin full access to special_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admin full access to special_products" ON public.special_products TO authenticated USING (public.is_admin()) WITH CHECK (public.is_admin());


--
-- Name: admin_audit_log Admins can insert audit log; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can insert audit log" ON public.admin_audit_log FOR INSERT TO authenticated WITH CHECK ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.is_admin = true)))));


--
-- Name: home_banners Admins can manage home banners; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can manage home banners" ON public.home_banners USING ((EXISTS ( SELECT 1
   FROM auth.users
  WHERE ((auth.uid() = users.id) AND ((users.raw_user_meta_data ->> 'role'::text) = ANY (ARRAY['admin'::text, 'super_admin'::text]))))));


--
-- Name: nexus_opportunities Admins can manage nexus opportunities; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can manage nexus opportunities" ON public.nexus_opportunities TO authenticated USING (public.is_admin_user());


--
-- Name: admin_audit_log Admins can read audit log; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins can read audit log" ON public.admin_audit_log FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.is_admin = true)))));


--
-- Name: african_football_clubs Anyone can read active clubs; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can read active clubs" ON public.african_football_clubs FOR SELECT USING ((is_active = true));


--
-- Name: group_messages Authenticated users can send messages; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Authenticated users can send messages" ON public.group_messages FOR INSERT WITH CHECK ((auth.uid() IS NOT NULL));


--
-- Name: group_messages Messages readable by all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Messages readable by all" ON public.group_messages FOR SELECT USING (true);


--
-- Name: nexus_opportunities Nexus opportunities are viewable by everyone; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Nexus opportunities are viewable by everyone" ON public.nexus_opportunities FOR SELECT TO authenticated USING ((is_active = true));


--
-- Name: admin_audit_log No deletes on audit log; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "No deletes on audit log" ON public.admin_audit_log FOR DELETE USING (false);


--
-- Name: admin_audit_log No updates on audit log; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "No updates on audit log" ON public.admin_audit_log FOR UPDATE USING (false);


--
-- Name: home_banners Public can read active home banners; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public can read active home banners" ON public.home_banners FOR SELECT USING ((is_active = true));


--
-- Name: special_products Public read access for special_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read access for special_products" ON public.special_products FOR SELECT USING (true);


--
-- Name: app_config Public read app_config; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read app_config" ON public.app_config FOR SELECT USING (true);


--
-- Name: partner_services Public read partner_services; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read partner_services" ON public.partner_services FOR SELECT USING (true);


--
-- Name: quick_actions Public read quick_actions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read quick_actions" ON public.quick_actions FOR SELECT USING (true);


--
-- Name: vehicle_types Public read vehicle_types; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Public read vehicle_types" ON public.vehicle_types FOR SELECT USING (true);


--
-- Name: admin_audit_log Service role can insert audit log; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role can insert audit log" ON public.admin_audit_log FOR INSERT TO service_role WITH CHECK (true);


--
-- Name: otp_codes Service role full access on otp_codes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on otp_codes" ON public.otp_codes TO service_role USING (true) WITH CHECK (true);


--
-- Name: otp_rate_events Service role full access on otp_rate_events; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role full access on otp_rate_events" ON public.otp_rate_events TO service_role USING (true) WITH CHECK (true);


--
-- Name: notification_events Service role manages notification events; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role manages notification events" ON public.notification_events TO service_role USING (true) WITH CHECK (true);


--
-- Name: user_fcm_tokens Service role reads all FCM tokens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Service role reads all FCM tokens" ON public.user_fcm_tokens FOR SELECT TO service_role USING (true);


--
-- Name: momo_ledger_entries Users can delete own ledger entries; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own ledger entries" ON public.momo_ledger_entries FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: momo_parse_attempts Users can delete own parse attempts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own parse attempts" ON public.momo_parse_attempts FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: momo_sms_parsed Users can delete own parsed SMS; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own parsed SMS" ON public.momo_sms_parsed FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: momo_sms_raw Users can delete own raw SMS; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own raw SMS" ON public.momo_sms_raw FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: momo_reconciliations Users can delete own reconciliations; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own reconciliations" ON public.momo_reconciliations FOR DELETE TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: user_fcm_tokens Users manage own FCM tokens; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users manage own FCM tokens" ON public.user_fcm_tokens USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: notification_events Users read own notification events; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users read own notification events" ON public.notification_events FOR SELECT TO authenticated USING (((target_type = 'user'::text) AND (auth.uid() = user_id)));


--
-- Name: achievements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;

--
-- Name: admin_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: news_articles admin_manage_articles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_manage_articles ON public.news_articles TO authenticated USING (true) WITH CHECK (true);


--
-- Name: shop_products admin_manage_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_manage_products ON public.shop_products TO authenticated USING (true) WITH CHECK (true);


--
-- Name: admin_phone_access; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_phone_access ENABLE ROW LEVEL SECURITY;

--
-- Name: admin_role_assignments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admin_role_assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: admin_role_assignments admin_role_assignments_delete_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_role_assignments_delete_policy ON public.admin_role_assignments FOR DELETE USING (false);


--
-- Name: admin_role_assignments admin_role_assignments_insert_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_role_assignments_insert_policy ON public.admin_role_assignments FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.is_admin = true)))));


--
-- Name: admin_role_assignments admin_role_assignments_select_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_role_assignments_select_policy ON public.admin_role_assignments FOR SELECT USING (((( SELECT auth.uid() AS uid) = user_id) OR (EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.is_admin = true))))));


--
-- Name: admin_role_assignments admin_role_assignments_update_policy; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_role_assignments_update_policy ON public.admin_role_assignments FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.users u
  WHERE ((u.id = ( SELECT auth.uid() AS uid)) AND (u.is_admin = true)))));


--
-- Name: admin_role_assignments admin_roles_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY admin_roles_select ON public.admin_role_assignments FOR SELECT USING (((user_id = auth.uid()) OR public.is_super_admin()));


--
-- Name: african_football_clubs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.african_football_clubs ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_content; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_content ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_content ai_content_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_content_admin_delete ON public.ai_content FOR DELETE USING ((EXISTS ( SELECT 1
   FROM public.admin_role_assignments
  WHERE ((admin_role_assignments.user_id = ( SELECT auth.uid() AS uid)) AND (admin_role_assignments.is_active = true)))));


--
-- Name: ai_content ai_content_admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_content_admin_insert ON public.ai_content FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.admin_role_assignments
  WHERE ((admin_role_assignments.user_id = ( SELECT auth.uid() AS uid)) AND (admin_role_assignments.is_active = true)))));


--
-- Name: ai_content ai_content_admin_read_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_content_admin_read_all ON public.ai_content FOR SELECT TO authenticated USING (((((auth.jwt() -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: ai_content ai_content_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_content_admin_update ON public.ai_content FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.admin_role_assignments
  WHERE ((admin_role_assignments.user_id = ( SELECT auth.uid() AS uid)) AND (admin_role_assignments.is_active = true)))));


--
-- Name: ai_content ai_content_admin_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_content_admin_write ON public.ai_content TO authenticated USING (((((auth.jwt() -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true)) WITH CHECK (((((auth.jwt() -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: ai_content_generation_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.ai_content_generation_config ENABLE ROW LEVEL SECURITY;

--
-- Name: ai_content ai_content_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_content_public_read ON public.ai_content FOR SELECT USING (((status = 'approved'::public.ai_content_status) AND (is_active = true)));


--
-- Name: ai_content ai_content_read_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_content_read_active ON public.ai_content FOR SELECT TO authenticated USING (((status = 'approved'::public.ai_content_status) AND (is_active = true)));


--
-- Name: ai_content_generation_config ai_gen_config_admin_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_gen_config_admin_write ON public.ai_content_generation_config FOR UPDATE TO authenticated USING (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true)) WITH CHECK (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: ai_content_generation_config ai_gen_config_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ai_gen_config_read ON public.ai_content_generation_config FOR SELECT TO authenticated USING (true);


--
-- Name: app_config; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

--
-- Name: app_config app_config_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_config_delete_admin ON public.app_config FOR DELETE TO authenticated USING (public.is_admin_user());


--
-- Name: app_config app_config_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_config_insert_admin ON public.app_config FOR INSERT TO authenticated WITH CHECK (public.is_admin_user());


--
-- Name: app_config app_config_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_config_select_all ON public.app_config FOR SELECT USING (true);


--
-- Name: app_config app_config_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY app_config_update_admin ON public.app_config FOR UPDATE TO authenticated USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());


--
-- Name: biopay_embeddings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_embeddings ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_embeddings biopay_embeddings_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_embeddings_select_own ON public.biopay_embeddings FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.biopay_payees p
  WHERE ((p.id = biopay_embeddings.payee_id) AND (p.supabase_uid = auth.uid())))));


--
-- Name: biopay_enrollment_audits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_enrollment_audits ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_enrollment_audits biopay_enrollment_audits_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_enrollment_audits_select_own ON public.biopay_enrollment_audits FOR SELECT USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: biopay_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_events ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_events biopay_events_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_events_select_own ON public.biopay_events FOR SELECT USING (((actor_supabase_uid = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.biopay_payees p
  WHERE ((p.id = biopay_events.payee_id) AND (p.supabase_uid = auth.uid()))))));


--
-- Name: biopay_payment_intents biopay_intents_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_intents_select_own ON public.biopay_payment_intents FOR SELECT TO authenticated USING (((user_id = auth.uid()) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: biopay_payment_intents biopay_intents_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_intents_update_own ON public.biopay_payment_intents FOR UPDATE TO authenticated USING (((user_id = auth.uid()) AND (status = 'pending'::text) AND ((club_id)::text = public.requesting_club_id()))) WITH CHECK ((user_id = auth.uid()));


--
-- Name: biopay_liveness_challenges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_liveness_challenges ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_match_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_match_events ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_match_events biopay_match_events_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_match_events_select_own ON public.biopay_match_events FOR SELECT USING (((auth.uid() = requester_user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: biopay_match_rate_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_match_rate_events ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_match_rate_events biopay_match_rate_events_deny_anon; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_match_rate_events_deny_anon ON public.biopay_match_rate_events TO anon USING (false);


--
-- Name: biopay_match_rate_events biopay_match_rate_events_deny_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_match_rate_events_deny_authenticated ON public.biopay_match_rate_events TO authenticated USING (false);


--
-- Name: biopay_match_rate_events biopay_match_rate_events_service_role; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_match_rate_events_service_role ON public.biopay_match_rate_events TO service_role USING (true) WITH CHECK (true);


--
-- Name: biopay_nfc_tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_nfc_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_payees; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_payees ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_payees biopay_payees_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_payees_select_own ON public.biopay_payees FOR SELECT USING ((supabase_uid = auth.uid()));


--
-- Name: biopay_payees biopay_payees_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_payees_update_own ON public.biopay_payees FOR UPDATE USING ((supabase_uid = auth.uid())) WITH CHECK ((supabase_uid = auth.uid()));


--
-- Name: biopay_payment_intents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_payment_intents ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_profiles biopay_profiles_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_profiles_insert_own ON public.biopay_profiles FOR INSERT WITH CHECK (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: biopay_profiles biopay_profiles_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_profiles_select_own ON public.biopay_profiles FOR SELECT USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: biopay_profiles biopay_profiles_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_profiles_update_own ON public.biopay_profiles FOR UPDATE USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id()))) WITH CHECK (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: biopay_revocations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_revocations ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_revocations biopay_revocations_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_revocations_select_own ON public.biopay_revocations FOR SELECT USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: biopay_user_preferences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_user_preferences ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_user_preferences biopay_user_preferences_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_user_preferences_insert_own ON public.biopay_user_preferences FOR INSERT WITH CHECK ((supabase_uid = auth.uid()));


--
-- Name: biopay_user_preferences biopay_user_preferences_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_user_preferences_select_own ON public.biopay_user_preferences FOR SELECT USING ((supabase_uid = auth.uid()));


--
-- Name: biopay_user_preferences biopay_user_preferences_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_user_preferences_update_own ON public.biopay_user_preferences FOR UPDATE USING ((supabase_uid = auth.uid())) WITH CHECK ((supabase_uid = auth.uid()));


--
-- Name: biopay_web_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_web_events ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_web_events biopay_web_events_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_web_events_select_own ON public.biopay_web_events FOR SELECT USING ((actor_supabase_uid = auth.uid()));


--
-- Name: biopay_web_push_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.biopay_web_push_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: biopay_web_push_subscriptions biopay_web_push_subscriptions_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY biopay_web_push_subscriptions_select_own ON public.biopay_web_push_subscriptions FOR SELECT USING ((actor_supabase_uid = auth.uid()));


--
-- Name: african_football_clubs clubs_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY clubs_admin_update ON public.african_football_clubs FOR UPDATE USING (((auth.role() = 'authenticated'::text) AND (public.is_super_admin() OR (((id)::text = public.requesting_club_id()) AND public.is_club_admin(id))))) WITH CHECK (((auth.role() = 'authenticated'::text) AND (public.is_super_admin() OR (((id)::text = public.requesting_club_id()) AND public.is_club_admin(id)))));


--
-- Name: groups contribution_groups_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contribution_groups_admin_all ON public.groups USING (((club_id IS NULL) OR (((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)))) WITH CHECK (((club_id IS NULL) OR (((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))));


--
-- Name: groups contribution_groups_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contribution_groups_public_read ON public.groups FOR SELECT TO anon USING (((is_active = true) AND (privacy = 'public'::text)));


--
-- Name: groups contribution_groups_select_club; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contribution_groups_select_club ON public.groups FOR SELECT USING (((club_id IS NULL) OR ((club_id)::text = public.requesting_club_id())));


--
-- Name: contributions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contributions ENABLE ROW LEVEL SECURITY;

--
-- Name: contributions contributions_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contributions_insert ON public.contributions FOR INSERT WITH CHECK (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: group_contributions contributions_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contributions_insert ON public.group_contributions FOR INSERT WITH CHECK (((( SELECT auth.uid() AS uid) = user_id) AND public.is_group_member(group_id)));


--
-- Name: contributions contributions_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contributions_select ON public.contributions FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND (EXISTS ( SELECT 1
   FROM public.group_members gm
  WHERE ((gm.group_id = contributions.group_id) AND (gm.user_id = auth.uid()))))));


--
-- Name: group_contributions contributions_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contributions_select ON public.group_contributions FOR SELECT USING (public.is_group_member(group_id));


--
-- Name: cool_achievements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_achievements ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_achievements cool_achievements_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_achievements_select ON public.cool_achievements FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: cool_activities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_activities ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_activities cool_activities_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_activities_admin_delete ON public.cool_activities FOR DELETE USING (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: cool_activities cool_activities_admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_activities_admin_insert ON public.cool_activities FOR INSERT WITH CHECK (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: cool_activities cool_activities_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_activities_admin_update ON public.cool_activities FOR UPDATE USING (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: cool_activities cool_activities_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_activities_select ON public.cool_activities FOR SELECT USING (true);


--
-- Name: cool_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_events ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_events cool_events_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_events_insert ON public.cool_events FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: cool_events cool_events_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_events_insert_own ON public.cool_events FOR INSERT WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: cool_events cool_events_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_events_select ON public.cool_events FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: cool_events cool_events_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_events_select_own ON public.cool_events FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: cool_invite_attributions cool_invite_attr_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_invite_attr_insert ON public.cool_invite_attributions FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = invitee_id));


--
-- Name: cool_invite_attributions cool_invite_attr_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_invite_attr_select ON public.cool_invite_attributions FOR SELECT USING (((( SELECT auth.uid() AS uid) = inviter_id) OR (( SELECT auth.uid() AS uid) = invitee_id)));


--
-- Name: cool_invite_attributions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_invite_attributions ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_mission_progress; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_mission_progress ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_mission_progress cool_mission_progress_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_mission_progress_insert ON public.cool_mission_progress FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: cool_mission_progress cool_mission_progress_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_mission_progress_select ON public.cool_mission_progress FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: cool_mission_progress cool_mission_progress_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_mission_progress_update ON public.cool_mission_progress FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: cool_missions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_missions ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_missions cool_missions_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_missions_admin_delete ON public.cool_missions FOR DELETE USING (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: cool_missions cool_missions_admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_missions_admin_insert ON public.cool_missions FOR INSERT WITH CHECK (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: cool_missions cool_missions_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_missions_admin_update ON public.cool_missions FOR UPDATE USING (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: cool_missions cool_missions_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_missions_select ON public.cool_missions FOR SELECT USING (true);


--
-- Name: cool_reward_redemptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_reward_redemptions ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_reward_redemptions cool_reward_redemptions_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_reward_redemptions_select ON public.cool_reward_redemptions FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: cool_rewards; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_rewards ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_rewards cool_rewards_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_rewards_select ON public.cool_rewards FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: cool_seasons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_seasons ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_seasons cool_seasons_admin_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_seasons_admin_delete ON public.cool_seasons FOR DELETE USING (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: cool_seasons cool_seasons_admin_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_seasons_admin_insert ON public.cool_seasons FOR INSERT WITH CHECK (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: cool_seasons cool_seasons_admin_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_seasons_admin_update ON public.cool_seasons FOR UPDATE USING (((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean = true));


--
-- Name: cool_seasons cool_seasons_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_seasons_select ON public.cool_seasons FOR SELECT USING (true);


--
-- Name: cool_status; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.cool_status ENABLE ROW LEVEL SECURITY;

--
-- Name: cool_status cool_status_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_status_insert ON public.cool_status FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: cool_status cool_status_multitenant_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_status_multitenant_insert ON public.cool_status FOR INSERT WITH CHECK (((user_id = auth.uid()) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: cool_status cool_status_multitenant_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_status_multitenant_select ON public.cool_status FOR SELECT USING (((user_id = auth.uid()) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: cool_status cool_status_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_status_select ON public.cool_status FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: cool_status cool_status_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY cool_status_update ON public.cool_status FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: countries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.countries ENABLE ROW LEVEL SECURITY;

--
-- Name: countries countries_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY countries_public_read ON public.countries FOR SELECT USING (true);


--
-- Name: countries countries_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY countries_select_all ON public.countries FOR SELECT USING (true);


--
-- Name: driver_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.driver_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: edge_function_rate_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.edge_function_rate_events ENABLE ROW LEVEL SECURITY;

--
-- Name: edge_function_rate_events ef_rate_events_deny_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY ef_rate_events_deny_all ON public.edge_function_rate_events TO authenticated USING (false);


--
-- Name: fan_club_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fan_club_members ENABLE ROW LEVEL SECURITY;

--
-- Name: fan_club_members fan_club_members_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_club_members_delete_own ON public.fan_club_members FOR DELETE USING ((((tenant_club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: fan_club_members fan_club_members_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_club_members_insert_own ON public.fan_club_members FOR INSERT WITH CHECK ((((tenant_club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: fan_club_members fan_club_members_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_club_members_select_own ON public.fan_club_members FOR SELECT USING ((((tenant_club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: fan_clubs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fan_clubs ENABLE ROW LEVEL SECURITY;

--
-- Name: fan_clubs fan_clubs_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_clubs_admin_all ON public.fan_clubs USING ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))) WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: fan_clubs fan_clubs_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_clubs_public_read ON public.fan_clubs FOR SELECT TO authenticated, anon USING (true);


--
-- Name: fan_clubs fan_clubs_select_club; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_clubs_select_club ON public.fan_clubs FOR SELECT USING (((club_id)::text = public.requesting_club_id()));


--
-- Name: fan_engagement_token_catalog; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fan_engagement_token_catalog ENABLE ROW LEVEL SECURITY;

--
-- Name: fan_memberships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.fan_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: fan_memberships fan_memberships_insert_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_memberships_insert_self ON public.fan_memberships FOR INSERT WITH CHECK (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: fan_memberships fan_memberships_select_club; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_memberships_select_club ON public.fan_memberships FOR SELECT USING (((club_id)::text = public.requesting_club_id()));


--
-- Name: fan_memberships fan_memberships_update_self_or_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fan_memberships_update_self_or_admin ON public.fan_memberships FOR UPDATE USING ((((club_id)::text = public.requesting_club_id()) AND ((auth.uid() = user_id) OR public.is_club_admin(club_id))));


--
-- Name: fan_engagement_token_catalog fet_catalog_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fet_catalog_admin_all ON public.fan_engagement_token_catalog USING ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))) WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: fan_engagement_token_catalog fet_catalog_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY fet_catalog_public_read ON public.fan_engagement_token_catalog FOR SELECT USING (((is_active = true) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: group_contributions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.group_contributions ENABLE ROW LEVEL SECURITY;

--
-- Name: group_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;

--
-- Name: group_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.group_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: group_messages group_messages_insert_members; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY group_messages_insert_members ON public.group_messages FOR INSERT WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND (sender_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM public.group_members gm
  WHERE ((gm.group_id = group_messages.group_id) AND (gm.user_id = auth.uid()))))));


--
-- Name: group_messages group_messages_select_members; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY group_messages_select_members ON public.group_messages FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND (EXISTS ( SELECT 1
   FROM public.group_members gm
  WHERE ((gm.group_id = group_messages.group_id) AND (gm.user_id = auth.uid()))))));


--
-- Name: groups; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

--
-- Name: groups groups_admin_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY groups_admin_select_all ON public.groups FOR SELECT USING (public.is_admin_user());


--
-- Name: groups groups_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY groups_insert ON public.groups FOR INSERT WITH CHECK ((auth.uid() = creator_id));


--
-- Name: groups groups_select_public; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY groups_select_public ON public.groups FOR SELECT USING (((visibility = 'public'::text) OR (creator_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.group_members gm
  WHERE ((gm.group_id = gm.id) AND (gm.user_id = auth.uid()))))));


--
-- Name: groups groups_update_creator; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY groups_update_creator ON public.groups FOR UPDATE USING ((auth.uid() = creator_id));


--
-- Name: home_banners; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.home_banners ENABLE ROW LEVEL SECURITY;

--
-- Name: initiative_contributions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.initiative_contributions ENABLE ROW LEVEL SECURITY;

--
-- Name: initiative_contributions initiative_contributions_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY initiative_contributions_insert_own ON public.initiative_contributions FOR INSERT WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: initiative_contributions initiative_contributions_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY initiative_contributions_select_own ON public.initiative_contributions FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: initiative_contributions initiative_contributions_update_own_or_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY initiative_contributions_update_own_or_admin ON public.initiative_contributions FOR UPDATE USING ((((club_id)::text = public.requesting_club_id()) AND ((user_id = auth.uid()) OR public.is_club_admin(club_id))));


--
-- Name: initiatives; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.initiatives ENABLE ROW LEVEL SECURITY;

--
-- Name: initiatives initiatives_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY initiatives_admin_all ON public.initiatives USING ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))) WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: initiatives initiatives_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY initiatives_public_read ON public.initiatives FOR SELECT TO authenticated, anon USING (true);


--
-- Name: initiatives initiatives_select_club; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY initiatives_select_club ON public.initiatives FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND (status = 'active'::text)));


--
-- Name: matches; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.matches ENABLE ROW LEVEL SECURITY;

--
-- Name: matches matches_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY matches_admin_all ON public.matches USING ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))) WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: matches matches_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY matches_public_read ON public.matches FOR SELECT TO authenticated, anon USING (true);


--
-- Name: matches matches_select_club; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY matches_select_club ON public.matches FOR SELECT USING (((club_id)::text = public.requesting_club_id()));


--
-- Name: membership_packages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.membership_packages ENABLE ROW LEVEL SECURITY;

--
-- Name: membership_packages membership_packages_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY membership_packages_admin_all ON public.membership_packages USING (((club_id IS NULL) OR (((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)))) WITH CHECK (((club_id IS NULL) OR (((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))));


--
-- Name: membership_packages membership_packages_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY membership_packages_public_read ON public.membership_packages FOR SELECT TO anon USING ((is_active = true));


--
-- Name: membership_packages membership_packages_select_club; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY membership_packages_select_club ON public.membership_packages FOR SELECT USING (((club_id IS NULL) OR ((club_id)::text = public.requesting_club_id()) OR (is_active = true)));


--
-- Name: momo_ledger_entries; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.momo_ledger_entries ENABLE ROW LEVEL SECURITY;

--
-- Name: momo_ledger_entries momo_ledger_entries_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_ledger_entries_select_own ON public.momo_ledger_entries FOR SELECT USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: momo_parse_attempts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.momo_parse_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: momo_parse_attempts momo_parse_attempts_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_parse_attempts_select_own ON public.momo_parse_attempts FOR SELECT USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: momo_reconciliations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.momo_reconciliations ENABLE ROW LEVEL SECURITY;

--
-- Name: momo_reconciliations momo_reconciliations_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_reconciliations_select_own ON public.momo_reconciliations FOR SELECT USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: momo_sms_parsed; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.momo_sms_parsed ENABLE ROW LEVEL SECURITY;

--
-- Name: momo_sms_parsed momo_sms_parsed_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_sms_parsed_select_own ON public.momo_sms_parsed FOR SELECT USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: momo_sms_raw; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.momo_sms_raw ENABLE ROW LEVEL SECURITY;

--
-- Name: momo_sms_raw momo_sms_raw_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_sms_raw_insert_own ON public.momo_sms_raw FOR INSERT WITH CHECK (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: momo_sms_raw momo_sms_raw_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_sms_raw_select_own ON public.momo_sms_raw FOR SELECT USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: momo_sms_raw momo_sms_raw_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_sms_raw_update_own ON public.momo_sms_raw FOR UPDATE USING (((auth.uid() = user_id) AND ((club_id)::text = public.requesting_club_id()))) WITH CHECK ((auth.uid() = user_id));


--
-- Name: momo_sms_sender_allowlist; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.momo_sms_sender_allowlist ENABLE ROW LEVEL SECURITY;

--
-- Name: momo_sms_sender_allowlist momo_sms_sender_allowlist_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_sms_sender_allowlist_select_authenticated ON public.momo_sms_sender_allowlist FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: momo_sms_sender_inventory_resolutions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.momo_sms_sender_inventory_resolutions ENABLE ROW LEVEL SECURITY;

--
-- Name: momo_sms_sender_inventory_resolutions momo_sms_sender_inventory_resolutions_select_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_sms_sender_inventory_resolutions_select_admin ON public.momo_sms_sender_inventory_resolutions FOR SELECT USING (public.is_admin());


--
-- Name: momo_sms_sync_runs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.momo_sms_sync_runs ENABLE ROW LEVEL SECURITY;

--
-- Name: momo_sms_sync_runs momo_sms_sync_runs_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_sms_sync_runs_delete_own ON public.momo_sms_sync_runs FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: momo_sms_sync_runs momo_sms_sync_runs_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_sms_sync_runs_insert_own ON public.momo_sms_sync_runs FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: momo_sms_sync_runs momo_sms_sync_runs_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY momo_sms_sync_runs_select_own ON public.momo_sms_sync_runs FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: news_articles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.news_articles ENABLE ROW LEVEL SECURITY;

--
-- Name: news_articles news_articles_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY news_articles_admin_all ON public.news_articles USING (((auth.role() = 'authenticated'::text) AND ((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))) WITH CHECK (((auth.role() = 'authenticated'::text) AND ((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: news_articles news_articles_select_published; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY news_articles_select_published ON public.news_articles FOR SELECT USING (((is_published = true) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: nexus_opportunities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.nexus_opportunities ENABLE ROW LEVEL SECURITY;

--
-- Name: notification_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification_events ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications notifications_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_insert_admin ON public.notifications FOR INSERT WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: notifications notifications_select_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_select_admin ON public.notifications FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: notifications notifications_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notifications_update_admin ON public.notifications FOR UPDATE USING ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))) WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: operational_health_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.operational_health_events ENABLE ROW LEVEL SECURITY;

--
-- Name: operational_health_events operational_health_events_select_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY operational_health_events_select_admin ON public.operational_health_events FOR SELECT TO authenticated USING (public.is_admin());


--
-- Name: POLICY operational_health_events_select_admin ON operational_health_events; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON POLICY operational_health_events_select_admin ON public.operational_health_events IS 'Admins can view the full operational health feed for triage and release monitoring.';


--
-- Name: operational_health_events operational_health_events_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY operational_health_events_select_own ON public.operational_health_events FOR SELECT USING ((user_id = auth.uid()));


--
-- Name: otp_codes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

--
-- Name: otp_rate_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.otp_rate_events ENABLE ROW LEVEL SECURITY;

--
-- Name: fan_memberships partner_admin_reads_all_memberships; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_admin_reads_all_memberships ON public.fan_memberships FOR SELECT TO authenticated USING (( SELECT public.rs_is_partner_admin(fan_memberships.partner_id) AS rs_is_partner_admin));


--
-- Name: partner_payment_routes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.partner_payment_routes ENABLE ROW LEVEL SECURITY;

--
-- Name: partner_payment_routes partner_payment_routes_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_payment_routes_admin_all ON public.partner_payment_routes USING ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))) WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: partner_payment_routes partner_payment_routes_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_payment_routes_delete_admin ON public.partner_payment_routes FOR DELETE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: partner_payment_routes partner_payment_routes_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_payment_routes_insert_admin ON public.partner_payment_routes FOR INSERT TO authenticated WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: partner_payment_routes partner_payment_routes_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_payment_routes_select_active ON public.partner_payment_routes FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND (status = 'active'::text)));


--
-- Name: partner_payment_routes partner_payment_routes_select_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_payment_routes_select_admin ON public.partner_payment_routes FOR SELECT TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: partner_payment_routes partner_payment_routes_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_payment_routes_update_admin ON public.partner_payment_routes FOR UPDATE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id))) WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: partner_services; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.partner_services ENABLE ROW LEVEL SECURITY;

--
-- Name: partner_services partner_services_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_services_delete_admin ON public.partner_services FOR DELETE TO authenticated USING (public.is_admin_user());


--
-- Name: partner_services partner_services_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_services_insert_admin ON public.partner_services FOR INSERT TO authenticated WITH CHECK (public.is_admin_user());


--
-- Name: partner_services partner_services_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partner_services_update_admin ON public.partner_services FOR UPDATE TO authenticated USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());


--
-- Name: partners; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;

--
-- Name: partners partners_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partners_delete_admin ON public.partners FOR DELETE TO authenticated USING (public.is_admin_user());


--
-- Name: partners partners_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partners_insert_admin ON public.partners FOR INSERT TO authenticated WITH CHECK (public.is_admin_user());


--
-- Name: partners partners_select_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partners_select_all ON public.partners FOR SELECT USING (true);


--
-- Name: partners partners_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY partners_update_admin ON public.partners FOR UPDATE TO authenticated USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());


--
-- Name: payment_identities; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payment_identities ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_identities payment_identities_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payment_identities_select_own ON public.payment_identities FOR SELECT USING (((auth.uid() = user_id) OR public.is_admin()));


--
-- Name: payment_intents; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payment_intents ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_intents payment_intents_insert_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payment_intents_insert_auth ON public.payment_intents FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: payment_intents payment_intents_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payment_intents_select_auth ON public.payment_intents FOR SELECT USING (((auth.uid() = user_id) OR public.is_admin()));


--
-- Name: payment_intents payment_intents_update_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payment_intents_update_auth ON public.payment_intents FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: payment_receiver_accounts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.payment_receiver_accounts ENABLE ROW LEVEL SECURITY;

--
-- Name: payment_receiver_accounts payment_receiver_accounts_select_auth; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY payment_receiver_accounts_select_auth ON public.payment_receiver_accounts FOR SELECT USING (((is_active = true) OR (auth.uid() = owner_user_id) OR public.is_admin()));


--
-- Name: pending_transactions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pending_transactions ENABLE ROW LEVEL SECURITY;

--
-- Name: pending_transactions pending_transactions_insert_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pending_transactions_insert_authenticated ON public.pending_transactions FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) IS NOT NULL));


--
-- Name: pending_transactions pending_transactions_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pending_transactions_select_own ON public.pending_transactions FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: pending_transactions pending_transactions_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pending_transactions_update_own ON public.pending_transactions FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: shop_products products_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY products_public_read ON public.shop_products FOR SELECT TO authenticated, anon USING (true);


--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles profiles_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_insert_own ON public.profiles FOR INSERT WITH CHECK ((auth.uid() = id));


--
-- Name: profiles profiles_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_own ON public.profiles FOR SELECT USING ((auth.uid() = id));


--
-- Name: profiles profiles_select_same_club; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_select_same_club ON public.profiles FOR SELECT USING (((club_id)::text = public.requesting_club_id()));


--
-- Name: profiles profiles_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY profiles_update_own ON public.profiles FOR UPDATE USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: shop_products public_read_active_products; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_read_active_products ON public.shop_products FOR SELECT USING ((is_active = true));


--
-- Name: news_articles public_read_published_articles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY public_read_published_articles ON public.news_articles FOR SELECT USING ((is_published = true));


--
-- Name: pwa_engagement_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pwa_engagement_events ENABLE ROW LEVEL SECURITY;

--
-- Name: pwa_engagement_events pwa_engagement_events_admin_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY pwa_engagement_events_admin_read ON public.pwa_engagement_events FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.admin_role_assignments ara
  WHERE ((ara.user_id = auth.uid()) AND (ara.is_active = true)))));


--
-- Name: quest_definitions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quest_definitions ENABLE ROW LEVEL SECURITY;

--
-- Name: quest_definitions quest_definitions_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quest_definitions_select_authenticated ON public.quest_definitions FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: quest_progress; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quest_progress ENABLE ROW LEVEL SECURITY;

--
-- Name: quest_progress quest_progress_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quest_progress_insert_own ON public.quest_progress FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: quest_progress quest_progress_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quest_progress_select_own ON public.quest_progress FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: quest_progress quest_progress_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quest_progress_update_own ON public.quest_progress FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: quick_actions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quick_actions ENABLE ROW LEVEL SECURITY;

--
-- Name: quick_actions quick_actions_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quick_actions_delete_admin ON public.quick_actions FOR DELETE TO authenticated USING (public.is_admin_user());


--
-- Name: quick_actions quick_actions_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quick_actions_insert_admin ON public.quick_actions FOR INSERT TO authenticated WITH CHECK (public.is_admin_user());


--
-- Name: quick_actions quick_actions_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY quick_actions_update_admin ON public.quick_actions FOR UPDATE TO authenticated USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());


--
-- Name: request_rate_limits; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.request_rate_limits ENABLE ROW LEVEL SECURITY;

--
-- Name: achievements rs_achievements_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_achievements_delete_admin ON public.achievements FOR DELETE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: achievements rs_achievements_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_achievements_insert_admin ON public.achievements FOR INSERT TO authenticated WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: achievements rs_achievements_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_achievements_select_own ON public.achievements FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: achievements rs_achievements_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_achievements_update_admin ON public.achievements FOR UPDATE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id))) WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: fan_club_members rs_fan_club_members_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_club_members_delete_own ON public.fan_club_members FOR DELETE USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: fan_club_members rs_fan_club_members_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_club_members_insert_own ON public.fan_club_members FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: fan_club_members rs_fan_club_members_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_club_members_select_authenticated ON public.fan_club_members FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: fan_clubs rs_fan_clubs_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_clubs_delete_admin ON public.fan_clubs FOR DELETE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: fan_clubs rs_fan_clubs_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_clubs_insert_admin ON public.fan_clubs FOR INSERT TO authenticated WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: fan_clubs rs_fan_clubs_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_clubs_select_authenticated ON public.fan_clubs FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: fan_clubs rs_fan_clubs_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_clubs_update_admin ON public.fan_clubs FOR UPDATE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id))) WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: fan_memberships rs_fan_memberships_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_memberships_delete_admin ON public.fan_memberships FOR DELETE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: fan_memberships rs_fan_memberships_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_memberships_insert_own ON public.fan_memberships FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: fan_memberships rs_fan_memberships_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_memberships_select_authenticated ON public.fan_memberships FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: fan_memberships rs_fan_memberships_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_memberships_update_admin ON public.fan_memberships FOR UPDATE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id))) WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: fan_memberships rs_fan_memberships_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_fan_memberships_update_own ON public.fan_memberships FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: initiative_contributions rs_initiative_contributions_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_initiative_contributions_insert_own ON public.initiative_contributions FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: initiative_contributions rs_initiative_contributions_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_initiative_contributions_select_authenticated ON public.initiative_contributions FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: initiative_contributions rs_initiative_contributions_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_initiative_contributions_select_own ON public.initiative_contributions FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: initiative_contributions rs_initiative_contributions_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_initiative_contributions_update_own ON public.initiative_contributions FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: initiatives rs_initiatives_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_initiatives_delete_admin ON public.initiatives FOR DELETE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: initiatives rs_initiatives_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_initiatives_insert_admin ON public.initiatives FOR INSERT TO authenticated WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: initiatives rs_initiatives_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_initiatives_select_authenticated ON public.initiatives FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: initiatives rs_initiatives_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_initiatives_update_admin ON public.initiatives FOR UPDATE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id))) WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: matches rs_matches_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_matches_delete_admin ON public.matches FOR DELETE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: matches rs_matches_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_matches_insert_admin ON public.matches FOR INSERT TO authenticated WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: matches rs_matches_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_matches_select_authenticated ON public.matches FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: matches rs_matches_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_matches_update_admin ON public.matches FOR UPDATE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id))) WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: membership_packages rs_membership_packages_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_membership_packages_delete_admin ON public.membership_packages FOR DELETE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: membership_packages rs_membership_packages_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_membership_packages_insert_admin ON public.membership_packages FOR INSERT TO authenticated WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: membership_packages rs_membership_packages_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_membership_packages_select_authenticated ON public.membership_packages FOR SELECT TO authenticated USING ((is_active OR public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: membership_packages rs_membership_packages_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_membership_packages_update_admin ON public.membership_packages FOR UPDATE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id))) WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: notifications rs_notifications_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_notifications_admin ON public.notifications USING ((EXISTS ( SELECT 1
   FROM public.admin_role_assignments ara
  WHERE ((ara.user_id = ( SELECT auth.uid() AS uid)) AND (ara.is_active = true) AND ((ara.role = 'admin'::text) OR (ara.role = 'rayon_sport'::text))))));


--
-- Name: shop_orders rs_shop_orders_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_shop_orders_delete_admin ON public.shop_orders FOR DELETE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: shop_orders rs_shop_orders_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_shop_orders_insert_own ON public.shop_orders FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: shop_orders rs_shop_orders_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_shop_orders_select_own ON public.shop_orders FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: shop_orders rs_shop_orders_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_shop_orders_update_admin ON public.shop_orders FOR UPDATE TO authenticated USING (((( SELECT auth.uid() AS uid) = user_id) OR public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: shop_orders rs_shop_orders_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_shop_orders_update_own ON public.shop_orders FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: shop_products rs_shop_products_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_shop_products_delete_admin ON public.shop_products FOR DELETE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: shop_products rs_shop_products_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_shop_products_insert_admin ON public.shop_products FOR INSERT TO authenticated WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: shop_products rs_shop_products_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_shop_products_select_authenticated ON public.shop_products FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: shop_products rs_shop_products_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_shop_products_update_admin ON public.shop_products FOR UPDATE TO authenticated USING ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id))) WITH CHECK ((public.is_admin_user() OR public.rs_is_partner_admin(partner_id)));


--
-- Name: tickets rs_tickets_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_tickets_delete_admin ON public.tickets FOR DELETE TO authenticated USING ((public.is_admin_user() OR (EXISTS ( SELECT 1
   FROM public.matches m
  WHERE ((m.id = tickets.match_id) AND public.rs_is_partner_admin(m.partner_id))))));


--
-- Name: tickets rs_tickets_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_tickets_insert_own ON public.tickets FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: tickets rs_tickets_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_tickets_select_own ON public.tickets FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: tickets rs_tickets_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_tickets_update_admin ON public.tickets FOR UPDATE TO authenticated USING (((( SELECT auth.uid() AS uid) = user_id) OR public.is_admin_user() OR (EXISTS ( SELECT 1
   FROM public.matches m
  WHERE ((m.id = tickets.match_id) AND public.rs_is_partner_admin(m.partner_id))))));


--
-- Name: tickets rs_tickets_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY rs_tickets_update_own ON public.tickets FOR UPDATE USING ((( SELECT auth.uid() AS uid) = user_id)) WITH CHECK ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: season_definitions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.season_definitions ENABLE ROW LEVEL SECURITY;

--
-- Name: season_definitions season_definitions_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY season_definitions_select_authenticated ON public.season_definitions FOR SELECT USING ((( SELECT auth.role() AS role) = 'authenticated'::text));


--
-- Name: season_memberships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.season_memberships ENABLE ROW LEVEL SECURITY;

--
-- Name: season_memberships season_memberships_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY season_memberships_select_own ON public.season_memberships FOR SELECT USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: shop_orders; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.shop_orders ENABLE ROW LEVEL SECURITY;

--
-- Name: shop_orders shop_orders_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY shop_orders_insert_own ON public.shop_orders FOR INSERT WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: shop_orders shop_orders_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY shop_orders_select_own ON public.shop_orders FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: shop_orders shop_orders_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY shop_orders_update_own ON public.shop_orders FOR UPDATE USING ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: shop_products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.shop_products ENABLE ROW LEVEL SECURITY;

--
-- Name: shop_products shop_products_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY shop_products_admin_all ON public.shop_products USING (((auth.role() = 'authenticated'::text) AND ((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))) WITH CHECK (((auth.role() = 'authenticated'::text) AND ((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: shop_products shop_products_select_active; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY shop_products_select_active ON public.shop_products FOR SELECT USING (((is_active = true) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: special_products; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.special_products ENABLE ROW LEVEL SECURITY;

--
-- Name: squad_players; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.squad_players ENABLE ROW LEVEL SECURITY;

--
-- Name: squad_players squad_players_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY squad_players_admin_all ON public.squad_players USING (((club_id IS NULL) OR (((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)))) WITH CHECK (((club_id IS NULL) OR (((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))));


--
-- Name: squad_players squad_players_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY squad_players_public_read ON public.squad_players FOR SELECT TO anon USING ((is_active = true));


--
-- Name: squad_players squad_players_select_club; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY squad_players_select_club ON public.squad_players FOR SELECT USING (((club_id IS NULL) OR ((club_id)::text = public.requesting_club_id())));


--
-- Name: standings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.standings ENABLE ROW LEVEL SECURITY;

--
-- Name: standings standings_admin_all; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY standings_admin_all ON public.standings USING (((club_id IS NULL) OR (((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)))) WITH CHECK (((club_id IS NULL) OR (((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))));


--
-- Name: standings standings_public_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY standings_public_read ON public.standings FOR SELECT USING (true);


--
-- Name: driver_subscriptions subscriptions_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subscriptions_insert_own ON public.driver_subscriptions FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = driver_id));


--
-- Name: driver_subscriptions subscriptions_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY subscriptions_select_own ON public.driver_subscriptions FOR SELECT USING ((( SELECT auth.uid() AS uid) = driver_id));


--
-- Name: tickets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;

--
-- Name: tickets tickets_admin_manage; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tickets_admin_manage ON public.tickets USING (((auth.role() = 'authenticated'::text) AND ((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id))) WITH CHECK (((auth.role() = 'authenticated'::text) AND ((club_id)::text = public.requesting_club_id()) AND public.is_club_admin(club_id)));


--
-- Name: tickets tickets_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tickets_insert_own ON public.tickets FOR INSERT WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: tickets tickets_multitenant_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tickets_multitenant_select ON public.tickets FOR SELECT USING (((user_id = auth.uid()) AND ((club_id)::text = public.requesting_club_id())));


--
-- Name: tickets tickets_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tickets_select_own ON public.tickets FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: tickets tickets_update_own_or_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY tickets_update_own_or_admin ON public.tickets FOR UPDATE USING ((((club_id)::text = public.requesting_club_id()) AND ((user_id = auth.uid()) OR public.is_club_admin(club_id))));


--
-- Name: user_fcm_tokens; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

--
-- Name: user_fcm_tokens user_fcm_tokens_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_fcm_tokens_delete_own ON public.user_fcm_tokens FOR DELETE USING ((auth.uid() = user_id));


--
-- Name: user_fcm_tokens user_fcm_tokens_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_fcm_tokens_insert_own ON public.user_fcm_tokens FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_fcm_tokens user_fcm_tokens_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_fcm_tokens_select_own ON public.user_fcm_tokens FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: user_fcm_tokens user_fcm_tokens_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_fcm_tokens_update_own ON public.user_fcm_tokens FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_notification_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_notification_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: user_notification_settings user_notification_settings_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_notification_settings_insert_own ON public.user_notification_settings FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_notification_settings user_notification_settings_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_notification_settings_select_own ON public.user_notification_settings FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: user_notification_settings user_notification_settings_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_notification_settings_update_own ON public.user_notification_settings FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_privacy_settings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_privacy_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: user_privacy_settings user_privacy_settings_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_privacy_settings_insert_own ON public.user_privacy_settings FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_privacy_settings user_privacy_settings_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_privacy_settings_select_own ON public.user_privacy_settings FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: user_privacy_settings user_privacy_settings_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_privacy_settings_update_own ON public.user_privacy_settings FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_private_contacts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_private_contacts ENABLE ROW LEVEL SECURITY;

--
-- Name: user_private_contacts user_private_contacts_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_private_contacts_insert_own ON public.user_private_contacts FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: user_private_contacts user_private_contacts_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_private_contacts_select_own ON public.user_private_contacts FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: user_private_contacts user_private_contacts_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_private_contacts_update_own ON public.user_private_contacts FOR UPDATE USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_insert_own ON public.users FOR INSERT WITH CHECK ((( SELECT auth.uid() AS uid) = id));


--
-- Name: users users_select_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_select_admin ON public.users FOR SELECT TO authenticated USING (public.is_admin_user());


--
-- Name: users users_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_select_own ON public.users FOR SELECT USING ((( SELECT auth.uid() AS uid) = id));


--
-- Name: users users_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_update_own ON public.users FOR UPDATE USING ((( SELECT auth.uid() AS uid) = id)) WITH CHECK ((( SELECT auth.uid() AS uid) = id));


--
-- Name: vehicle_types; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.vehicle_types ENABLE ROW LEVEL SECURITY;

--
-- Name: vehicle_types vehicle_types_delete_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vehicle_types_delete_admin ON public.vehicle_types FOR DELETE TO authenticated USING (public.is_admin_user());


--
-- Name: vehicle_types vehicle_types_insert_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vehicle_types_insert_admin ON public.vehicle_types FOR INSERT TO authenticated WITH CHECK (public.is_admin_user());


--
-- Name: vehicle_types vehicle_types_update_admin; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY vehicle_types_update_admin ON public.vehicle_types FOR UPDATE TO authenticated USING (public.is_admin_user()) WITH CHECK (public.is_admin_user());


--
-- Name: wallet_pass_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wallet_pass_events ENABLE ROW LEVEL SECURITY;

--
-- Name: wallet_pass_events wallet_pass_events_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY wallet_pass_events_select_own ON public.wallet_pass_events FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.wallet_passes wp
  WHERE ((wp.id = wallet_pass_events.wallet_pass_id) AND (wp.user_id = ( SELECT auth.uid() AS uid))))));


--
-- Name: wallet_passes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wallet_passes ENABLE ROW LEVEL SECURITY;

--
-- Name: wallet_passes wallet_passes_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY wallet_passes_select_own ON public.wallet_passes FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = user_id));


--
-- Name: web_push_subscriptions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.web_push_subscriptions ENABLE ROW LEVEL SECURITY;

--
-- Name: web_push_subscriptions web_push_subscriptions_delete_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY web_push_subscriptions_delete_own ON public.web_push_subscriptions FOR DELETE TO authenticated USING ((user_id = auth.uid()));


--
-- Name: web_push_subscriptions web_push_subscriptions_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY web_push_subscriptions_insert_own ON public.web_push_subscriptions FOR INSERT TO authenticated WITH CHECK ((user_id = auth.uid()));


--
-- Name: web_push_subscriptions web_push_subscriptions_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY web_push_subscriptions_select_own ON public.web_push_subscriptions FOR SELECT TO authenticated USING ((user_id = auth.uid()));


--
-- Name: web_push_subscriptions web_push_subscriptions_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY web_push_subscriptions_update_own ON public.web_push_subscriptions FOR UPDATE TO authenticated USING ((user_id = auth.uid())) WITH CHECK ((user_id = auth.uid()));


--
-- Name: xp_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.xp_events ENABLE ROW LEVEL SECURITY;

--
-- Name: xp_events xp_events_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY xp_events_insert_own ON public.xp_events FOR INSERT WITH CHECK ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- Name: xp_events xp_events_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY xp_events_select_own ON public.xp_events FOR SELECT USING ((((club_id)::text = public.requesting_club_id()) AND (user_id = auth.uid())));


--
-- PostgreSQL database dump complete
--

\unrestrict gr08AxczS7jBqRQf9Z5r642q4loonQFgr3aF0A2Za3fP0e4oAIIjlzFTgTBpffJ


begin;

-- A dead worker may be replaced only before it persists an interpretation.
-- Persisted/partially reconciled evidence still requires receipt recovery or
-- operator review; an expiring timer is not proof that business writes rolled back.
create table public.momo_parse_leases (
  raw_sms_id uuid primary key references public.momo_sms_raw(id) on delete cascade,
  token uuid not null unique,
  raw_version timestamptz not null,
  expires_at timestamptz not null,
  phase text not null check (phase in ('parsing','persisted'))
);
alter table public.momo_parse_leases enable row level security;
revoke all on public.momo_parse_leases from public, anon, authenticated;
grant select, insert, update, delete on public.momo_parse_leases to service_role;

create function public.claim_momo_sms_parse(
  p_raw_sms_id uuid, p_user_id uuid, p_expected_updated_at timestamptz,
  p_force_reparse boolean default false
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_raw public.momo_sms_raw;
  v_lease public.momo_parse_leases;
  v_parsed_id uuid;
  v_token uuid := gen_random_uuid();
begin
  -- Use the same review -> interpretation -> raw lock order as allocation.
  select id into v_parsed_id from public.momo_sms_parsed where raw_sms_id=p_raw_sms_id;
  perform id from public.momo_reconciliations where parsed_sms_id=v_parsed_id for update;
  perform id from public.momo_sms_parsed where id=v_parsed_id for update;
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

create function public.persist_momo_sms_parse(
  p_raw_sms_id uuid, p_user_id uuid, p_token uuid, p_payload jsonb
) returns jsonb language plpgsql security invoker set search_path='' as $$
declare
  v_raw public.momo_sms_raw;
  v_lease public.momo_parse_leases;
  v_parsed public.momo_sms_parsed;
  v_id uuid;
begin
  select id into v_id from public.momo_sms_parsed where raw_sms_id=p_raw_sms_id;
  perform id from public.momo_reconciliations where parsed_sms_id=v_id for update;
  perform id from public.momo_sms_parsed where id=v_id for update;
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

create function public.finish_momo_sms_parse(
  p_raw_sms_id uuid, p_user_id uuid, p_token uuid, p_success boolean,
  p_attempt_id uuid default null, p_request_payload jsonb default null,
  p_response_payload jsonb default null, p_error text default null
) returns boolean language plpgsql security invoker set search_path='' as $$
declare
  v_raw public.momo_sms_raw;
  v_lease public.momo_parse_leases;
begin
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

revoke all on function public.claim_momo_sms_parse(uuid,uuid,timestamptz,boolean),
  public.persist_momo_sms_parse(uuid,uuid,uuid,jsonb),
  public.finish_momo_sms_parse(uuid,uuid,uuid,boolean,uuid,jsonb,jsonb,text) from public,anon,authenticated;
grant execute on function public.claim_momo_sms_parse(uuid,uuid,timestamptz,boolean),
  public.persist_momo_sms_parse(uuid,uuid,uuid,jsonb),
  public.finish_momo_sms_parse(uuid,uuid,uuid,boolean,uuid,jsonb,jsonb,text) to service_role;

commit;

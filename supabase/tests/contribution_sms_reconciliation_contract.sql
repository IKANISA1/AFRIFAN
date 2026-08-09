-- Supporter contribution and service-only SMS reconciliation contract.
-- Run against a migrated isolated database with `supabase test db`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(21);

select ok(
  has_column_privilege(
    'anon',
    'public.contribution_groups',
    'name',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.contribution_groups',
    'momo_recipient_code',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.group_contributions',
    'INSERT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.group_contributions',
    'UPDATE'
  )
  and not has_table_privilege(
    'authenticated',
    'public.group_contributions',
    'DELETE'
  )
  and not has_table_privilege(
    'authenticated',
    'public.momo_ledger_entries',
    'UPDATE'
  )
  and not has_table_privilege(
    'authenticated',
    'public.momo_reconciliations',
    'INSERT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.momo_reconciliations',
    'DELETE'
  ),
  'supporters read the contribution surfaces but cannot write financial state directly'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.group_contributions',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.group_contributions',
    'client_request_reference',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.group_contributions',
    'payment_status',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.group_contributions',
    'idempotency_key',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.momo_ledger_entries',
    'external_reference',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.momo_ledger_entries',
    'metadata',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.momo_reconciliations',
    'match_status',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.momo_reconciliations',
    'metadata',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.group_members',
    'mock_batch',
    'SELECT'
  ),
  'released reads use explicit privacy-minimized column grants'
);

select ok(
  (
    select count(*) = 2
      from pg_policies
     where schemaname = 'public'
       and tablename = 'groups'
       and cmd = 'SELECT'
  )
  and (
    select count(*) = 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'group_members'
       and cmd = 'SELECT'
       and roles = array['authenticated']::name[]
  )
  and (
    select count(*) = 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'group_contributions'
       and cmd = 'SELECT'
       and roles = array['authenticated']::name[]
  )
  and (
    select count(*) = 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'momo_ledger_entries'
       and cmd = 'SELECT'
       and roles = array['authenticated']::name[]
  )
  and (
    select count(*) = 1
      from pg_policies
     where schemaname = 'public'
       and tablename = 'momo_reconciliations'
       and cmd = 'SELECT'
       and roles = array['authenticated']::name[]
  )
  and not exists (
    select 1
      from pg_policies
     where schemaname = 'public'
       and tablename in (
         'group_members',
         'group_contributions',
         'momo_ledger_entries',
         'momo_reconciliations'
       )
       and cmd <> 'SELECT'
  ),
  'financial tables retain only scoped read policies for authenticated clients'
);

select ok(
  exists (
    select 1
      from pg_proc
     where oid =
       'public.create_pending_group_contribution(uuid,integer,text,text)'::regprocedure
       and prosecdef
       and proconfig = array['search_path=""']::text[]
       and prosrc ~ 'auth.uid'
       and prosrc ~ 'requesting_club_id'
       and prosrc ~ 'pending_verification'
       and prosrc ~ 'idempotency'
  )
  and exists (
    select 1
      from pg_proc
     where oid =
       'public.reconcile_group_contribution_from_sms(uuid,uuid,timestamptz,timestamptz,text,uuid,text)'::regprocedure
       and prosecdef
       and proconfig = array['search_path=""']::text[]
       and prosrc ~ 'for update'
       and prosrc ~ 'updated_at is distinct from'
       and prosrc ~ 'group_contribution_sms_reconciled'
  ),
  'pending creation and exact SMS reconciliation are fixed-path security-definer functions'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.create_pending_group_contribution(uuid,integer,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.create_pending_group_contribution(uuid,integer,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.create_pending_group_contribution(uuid,integer,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.reconcile_group_contribution_from_sms(uuid,uuid,timestamptz,timestamptz,text,uuid,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.reconcile_group_contribution_from_sms(uuid,uuid,timestamptz,timestamptz,text,uuid,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.reconcile_group_contribution_from_sms(uuid,uuid,timestamptz,timestamptz,text,uuid,text)',
    'EXECUTE'
  ),
  'pending creation is supporter-only and reconciliation is service-only'
);

select ok(
  exists (
    select 1
      from pg_constraint
     where conrelid = 'public.group_contributions'::regclass
       and conname = 'group_contributions_group_id_fkey'
       and contype = 'f'
  )
  and exists (
    select 1
      from pg_constraint
     where conrelid = 'public.group_contributions'::regclass
       and conname = 'group_contributions_idempotency_key_key'
       and contype = 'u'
  )
  and exists (
    select 1
      from pg_indexes
     where schemaname = 'public'
       and tablename = 'group_contributions'
       and indexname = 'idx_group_contributions_reconciliation_idempotency'
       and indexdef ~ 'WHERE \(reconciliation_idempotency_key IS NOT NULL\)'
  )
  and exists (
    select 1
      from pg_indexes
     where schemaname = 'public'
       and tablename = 'group_contributions'
       and indexname = 'idx_group_contributions_reconciled_ledger_entry_id'
  )
  and exists (
    select 1
      from pg_indexes
     where schemaname = 'public'
       and tablename = 'group_contributions'
       and indexname = 'idx_group_contributions_reconciliation_id'
  )
  and exists (
    select 1
      from information_schema.triggers
     where event_object_schema = 'public'
       and event_object_table = 'group_contributions'
       and trigger_name = 'trg_group_contributions_immutable_identity'
  )
  and (
    select column_default ~ 'pending_verification'
      from information_schema.columns
     where table_schema = 'public'
       and table_name = 'group_contributions'
       and column_name = 'payment_status'
  ),
  'contribution identity, foreign keys and idempotency have database constraints'
);

insert into public.african_football_clubs (
  id,
  club_name,
  country_name,
  club_slug
) overriding system value values
  (9936001, 'Contribution Contract Club', 'Rwanda', 'contribution-contract-club'),
  (9936002, 'Foreign Contribution Club', 'Rwanda', 'foreign-contribution-club');

insert into public.partners (id, name, slug, is_active)
values
  (
    '99360000-0000-4000-8000-000000000100',
    'Contribution Contract Club',
    'contribution-contract-club',
    true
  ),
  (
    '99360000-0000-4000-8000-000000000101',
    'Foreign Contribution Club',
    'foreign-contribution-club',
    true
  );

insert into auth.users (id, aud, role)
values
  ('99360000-0000-4000-8000-000000000001', 'authenticated', 'authenticated'),
  ('99360000-0000-4000-8000-000000000002', 'authenticated', 'authenticated'),
  ('99360000-0000-4000-8000-000000000003', 'authenticated', 'authenticated'),
  ('99360000-0000-4000-8000-000000000004', 'authenticated', 'authenticated');

insert into public.users (id, phone, full_name)
values
  ('99360000-0000-4000-8000-000000000001', '+250793600001', 'Contribution Member'),
  ('99360000-0000-4000-8000-000000000002', '+250793600002', 'Same Club Outsider'),
  ('99360000-0000-4000-8000-000000000003', '+250793600003', 'Foreign Member'),
  ('99360000-0000-4000-8000-000000000004', '+250793600004', 'Reconciliation Worker');

insert into public.profiles (id, club_id)
values
  ('99360000-0000-4000-8000-000000000001', 9936001),
  ('99360000-0000-4000-8000-000000000002', 9936001),
  ('99360000-0000-4000-8000-000000000003', 9936002),
  ('99360000-0000-4000-8000-000000000004', 9936001);

insert into public.groups (
  id,
  creator_id,
  name,
  group_type,
  target_amount,
  club_id,
  partner_id,
  currency,
  visibility,
  is_active,
  is_closed,
  receiving_momo_route_type,
  receiving_momo_code
) values
  (
    '99360000-0000-4000-8000-000000000110',
    '99360000-0000-4000-8000-000000000001',
    'Own Club Contribution Group',
    'community',
    100000,
    9936001,
    '99360000-0000-4000-8000-000000000100',
    'RWF',
    'public',
    true,
    false,
    'code',
    '123456'
  ),
  (
    '99360000-0000-4000-8000-000000000111',
    '99360000-0000-4000-8000-000000000003',
    'Foreign Club Contribution Group',
    'community',
    100000,
    9936002,
    '99360000-0000-4000-8000-000000000101',
    'RWF',
    'public',
    true,
    false,
    'code',
    '654321'
  );

-- The local reference catalog defaults newly-created synthetic clubs to USD.
-- This contract models the released Rwanda contribution route explicitly.
update public.groups
   set currency = 'RWF'
 where id in (
   '99360000-0000-4000-8000-000000000110',
   '99360000-0000-4000-8000-000000000111'
 );

insert into public.group_members (id, group_id, user_id, display_name)
values
  (
    '99360000-0000-4000-8000-000000000120',
    '99360000-0000-4000-8000-000000000110',
    '99360000-0000-4000-8000-000000000001',
    'Contribution Member'
  ),
  (
    '99360000-0000-4000-8000-000000000121',
    '99360000-0000-4000-8000-000000000111',
    '99360000-0000-4000-8000-000000000003',
    'Foreign Member'
  );

insert into public.momo_sms_raw (
  id,
  user_id,
  device_message_key,
  sender,
  sms_body,
  sms_received_at,
  parse_status,
  club_id
) values
  (
    '99360000-0000-4000-8000-000000000200',
    '99360000-0000-4000-8000-000000000001',
    'contribution-success-raw',
    'MTN MoMo',
    'Payment 5000 RWF. TxId TXSUCCESS0001.',
    '2026-08-09 08:00:00+00',
    'parsed',
    9936001
  ),
  (
    '99360000-0000-4000-8000-000000000201',
    '99360000-0000-4000-8000-000000000001',
    'contribution-mismatch-raw',
    'MTN MoMo',
    'Payment 7001 RWF. TxId TXMISMATCH0002.',
    '2026-08-09 08:10:00+00',
    'parsed',
    9936001
  ),
  (
    '99360000-0000-4000-8000-000000000202',
    '99360000-0000-4000-8000-000000000001',
    'contribution-rollback-raw',
    'MTN MoMo',
    'Payment 9000 RWF. TxId TXROLLBACK0003.',
    '2026-08-09 08:20:00+00',
    'parsed',
    9936001
  );

insert into public.momo_sms_parsed (
  id,
  raw_sms_id,
  user_id,
  parser_provider,
  parser_model,
  parse_status,
  tx_direction,
  tx_type,
  momo_tx_id,
  amount,
  currency,
  tx_datetime,
  club_id
) values
  (
    '99360000-0000-4000-8000-000000000210',
    '99360000-0000-4000-8000-000000000200',
    '99360000-0000-4000-8000-000000000001',
    'contract',
    'contract-v1',
    'parsed',
    'debit',
    'payment',
    'TXSUCCESS0001',
    5000,
    'RWF',
    '2026-08-09 08:00:00+00',
    9936001
  ),
  (
    '99360000-0000-4000-8000-000000000211',
    '99360000-0000-4000-8000-000000000201',
    '99360000-0000-4000-8000-000000000001',
    'contract',
    'contract-v1',
    'parsed',
    'debit',
    'payment',
    'TXMISMATCH0002',
    7001,
    'RWF',
    '2026-08-09 08:10:00+00',
    9936001
  ),
  (
    '99360000-0000-4000-8000-000000000212',
    '99360000-0000-4000-8000-000000000202',
    '99360000-0000-4000-8000-000000000001',
    'contract',
    'contract-v1',
    'parsed',
    'debit',
    'payment',
    'TXROLLBACK0003',
    9000,
    'RWF',
    '2026-08-09 08:20:00+00',
    9936001
  );

insert into public.momo_ledger_entries (
  id,
  parsed_sms_id,
  user_id,
  entry_type,
  ledger_status,
  amount,
  currency,
  tx_datetime,
  external_reference,
  club_id
) values
  (
    '99360000-0000-4000-8000-000000000220',
    '99360000-0000-4000-8000-000000000210',
    '99360000-0000-4000-8000-000000000001',
    'debit',
    'draft',
    5000,
    'RWF',
    '2026-08-09 08:00:00+00',
    'tx-success-0001',
    9936001
  ),
  (
    '99360000-0000-4000-8000-000000000221',
    '99360000-0000-4000-8000-000000000211',
    '99360000-0000-4000-8000-000000000001',
    'debit',
    'draft',
    7001,
    'RWF',
    '2026-08-09 08:10:00+00',
    'TXMISMATCH0002',
    9936001
  ),
  (
    '99360000-0000-4000-8000-000000000222',
    '99360000-0000-4000-8000-000000000212',
    '99360000-0000-4000-8000-000000000001',
    'debit',
    'draft',
    9000,
    'RWF',
    '2026-08-09 08:20:00+00',
    'TXROLLBACK0003',
    9936001
  );

select set_config(
  'request.jwt.claim.sub',
  '99360000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99360000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9936001"}',
  true
);
set local role authenticated;

do $$
declare
  visible_groups integer;
  visible_members integer;
begin
  select count(*) into visible_groups from public.contribution_groups;
  select count(*) into visible_members from public.group_members;
  if visible_groups <> 1 or visible_members <> 1 then
    raise exception 'tenant read boundary failed: groups %, members %',
      visible_groups,
      visible_members;
  end if;
end;
$$;
reset role;
select pass('authenticated contribution and member reads stay in the active club and group');

set local role authenticated;
do $$
declare
  created jsonb;
begin
  created := public.create_pending_group_contribution(
    '99360000-0000-4000-8000-000000000110',
    5000,
    'momo-client-success-0001',
    'pending:success:01'
  );
  if created ->> 'status' <> 'pending'
     or created ->> 'payment_status' <> 'pending_verification'
     or (created ->> 'replayed')::boolean then
    raise exception 'unexpected pending contribution response: %', created;
  end if;

  perform public.create_pending_group_contribution(
    '99360000-0000-4000-8000-000000000110',
    7000,
    'MOMO-CLIENT-MISMATCH-0002',
    'pending:mismatch:02'
  );
  perform public.create_pending_group_contribution(
    '99360000-0000-4000-8000-000000000110',
    9000,
    'MOMO-CLIENT-ROLLBACK-0003',
    'pending:rollback:03'
  );
end;
$$;
reset role;
select pass('supporter RPC creates only pending, unverified contribution requests');

select ok(
  (
    select count(*) = 3
      from public.group_contributions
     where group_id = '99360000-0000-4000-8000-000000000110'
       and user_id = '99360000-0000-4000-8000-000000000001'
       and status = 'pending'
       and payment_status = 'pending_verification'
       and momo_reference is null
  )
  and exists (
    select 1
      from public.group_contributions
     where client_request_reference = 'MOMOCLIENTSUCCESS0001'
       and momo_reference is null
       and idempotency_key = 'pending:success:01'
  ),
  'pending RPC stores an immutable client reference without inventing a provider TxID'
);

set local role authenticated;
do $$
declare
  first_id uuid;
  replayed jsonb;
begin
  select id into first_id
    from public.group_contributions
   where client_request_reference = 'MOMOCLIENTSUCCESS0001';
  replayed := public.create_pending_group_contribution(
    '99360000-0000-4000-8000-000000000110',
    5000,
    'MOMO-CLIENT-SUCCESS-0001',
    'pending:success:01'
  );
  if (replayed ->> 'id')::uuid <> first_id
     or not (replayed ->> 'replayed')::boolean then
    raise exception 'pending idempotency replay failed: %', replayed;
  end if;
end;
$$;
reset role;
select pass('identical pending contribution retries return the original record');

set local role authenticated;
do $$
declare
  conflict_denied boolean := false;
  zero_denied boolean := false;
  cross_club_denied boolean := false;
begin
  begin
    perform public.create_pending_group_contribution(
      '99360000-0000-4000-8000-000000000110',
      5001,
      'MOMOCLIENTSUCCESS0001',
      'pending:success:01'
    );
  exception when others then conflict_denied := true;
  end;

  begin
    perform public.create_pending_group_contribution(
      '99360000-0000-4000-8000-000000000110',
      0,
      'TXZERO000004',
      'pending:zero:04'
    );
  exception when others then zero_denied := true;
  end;

  begin
    perform public.create_pending_group_contribution(
      '99360000-0000-4000-8000-000000000111',
      1000,
      'TXFOREIGN005',
      'pending:foreign:05'
    );
  exception when others then cross_club_denied := true;
  end;

  if not conflict_denied or not zero_denied or not cross_club_denied then
    raise exception 'pending validation failed: conflict %, zero %, cross %',
      conflict_denied,
      zero_denied,
      cross_club_denied;
  end if;
end;
$$;
reset role;
select pass('conflicting replay, non-positive amount and foreign-club group fail closed');

select set_config(
  'request.jwt.claim.sub',
  '99360000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99360000-0000-4000-8000-000000000002","role":"authenticated","club_id":"9936001"}',
  true
);
set local role authenticated;
do $$
declare
  visible_members integer;
  visible_contributions integer;
  create_denied boolean := false;
begin
  select count(*) into visible_members from public.group_members;
  select count(*) into visible_contributions from public.group_contributions;
  begin
    perform public.create_pending_group_contribution(
      '99360000-0000-4000-8000-000000000110',
      1000,
      'TXOUTSIDER006',
      'pending:outsider:06'
    );
  exception when others then create_denied := true;
  end;

  if visible_members <> 0
     or visible_contributions <> 0
     or not create_denied then
    raise exception 'nonmember boundary failed: members %, contributions %, create %',
      visible_members,
      visible_contributions,
      create_denied;
  end if;
end;
$$;
reset role;
select pass('a same-club nonmember cannot inspect membership, contributions, or contribute');

select set_config(
  'request.jwt.claim.sub',
  '99360000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99360000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9936001"}',
  true
);
set local role authenticated;
do $$
declare
  insert_denied boolean := false;
  update_denied boolean := false;
  ledger_delete_denied boolean := false;
  reconciliation_insert_denied boolean := false;
  service_rpc_denied boolean := false;
begin
  begin
    insert into public.group_contributions (
      group_id,
      user_id,
      amount,
      status,
      momo_reference
    ) values (
      '99360000-0000-4000-8000-000000000110',
      '99360000-0000-4000-8000-000000000001',
      1,
      'confirmed',
      'TXDIRECT0007'
    );
  exception when insufficient_privilege then insert_denied := true;
  end;

  begin
    update public.group_contributions
       set status = 'confirmed'
     where client_request_reference = 'MOMOCLIENTSUCCESS0001';
  exception when insufficient_privilege then update_denied := true;
  end;

  begin
    delete from public.momo_ledger_entries
     where id = '99360000-0000-4000-8000-000000000220';
  exception when insufficient_privilege then ledger_delete_denied := true;
  end;

  begin
    insert into public.momo_reconciliations (
      parsed_sms_id,
      user_id,
      match_status,
      club_id
    ) values (
      '99360000-0000-4000-8000-000000000210',
      '99360000-0000-4000-8000-000000000001',
      'matched',
      9936001
    );
  exception when insufficient_privilege then
    reconciliation_insert_denied := true;
  end;

  begin
    perform public.reconcile_group_contribution_from_sms(
      (
        select id
          from public.group_contributions
         where client_request_reference = 'MOMOCLIENTSUCCESS0001'
      ),
      '99360000-0000-4000-8000-000000000220',
      pg_catalog.clock_timestamp(),
      pg_catalog.clock_timestamp(),
      'reconcile:denied:01',
      '99360000-0000-4000-8000-000000000004',
      'contract-worker'
    );
  exception when insufficient_privilege then service_rpc_denied := true;
  end;

  if not insert_denied
     or not update_denied
     or not ledger_delete_denied
     or not reconciliation_insert_denied
     or not service_rpc_denied then
    raise exception 'direct mutation boundary failed: %, %, %, %, %',
      insert_denied,
      update_denied,
      ledger_delete_denied,
      reconciliation_insert_denied,
      service_rpc_denied;
  end if;
end;
$$;
reset role;
select pass('authenticated clients cannot insert, confirm, reconcile, delete, or enter the service RPC');

set local role service_role;
do $$
declare
  contribution_id uuid;
  contribution_version timestamptz;
  ledger_version timestamptz;
  result jsonb;
begin
  select id, updated_at
    into contribution_id, contribution_version
    from public.group_contributions
   where client_request_reference = 'MOMOCLIENTSUCCESS0001';
  select updated_at into ledger_version
    from public.momo_ledger_entries
   where id = '99360000-0000-4000-8000-000000000220';

  result := public.reconcile_group_contribution_from_sms(
    contribution_id,
    '99360000-0000-4000-8000-000000000220',
    contribution_version,
    ledger_version,
    'reconcile:success:01',
    '99360000-0000-4000-8000-000000000004',
    'contract-worker'
  );

  if result ->> 'status' <> 'confirmed' then
    raise exception 'exact reconciliation failed: %', result;
  end if;
end;
$$;
reset role;
select pass('trusted service atomically reconciles an exact SMS payment binding');

select ok(
  exists (
    select 1
      from public.group_contributions as contribution
      join public.momo_ledger_entries as ledger
        on ledger.id = contribution.reconciled_ledger_entry_id
      join public.momo_reconciliations as reconciliation
        on reconciliation.id = contribution.reconciliation_id
     where contribution.momo_reference = 'TXSUCCESS0001'
       and contribution.client_request_reference = 'MOMOCLIENTSUCCESS0001'
       and contribution.status = 'confirmed'
       and contribution.payment_status = 'verified'
       and contribution.confirmed_at is not null
       and contribution.reconciliation_idempotency_key = 'reconcile:success:01'
       and contribution.reconciled_by =
         '99360000-0000-4000-8000-000000000004'
       and ledger.ledger_status = 'posted'
       and ledger.target_table = 'group_contributions'
       and ledger.target_record_id = contribution.id
       and reconciliation.match_status = 'matched'
       and reconciliation.club_id = 9936001
  )
  and exists (
    select 1
      from public.admin_audit_log
     where action = 'group_contribution_sms_reconciled'
       and actor_id = '99360000-0000-4000-8000-000000000004'
       and club_id = 9936001
       and metadata ->> 'idempotency_key' = 'reconcile:success:01'
  ),
  'confirmation, ledger target, reconciliation and immutable actor audit agree'
);

set local role service_role;
do $$
declare
  contribution_id uuid;
  result jsonb;
begin
  select id into contribution_id
    from public.group_contributions
   where momo_reference = 'TXSUCCESS0001';
  result := public.reconcile_group_contribution_from_sms(
    contribution_id,
    '99360000-0000-4000-8000-000000000220',
    '2000-01-01 00:00:00+00',
    '2000-01-01 00:00:00+00',
    'reconcile:success:01',
    '99360000-0000-4000-8000-000000000004',
    'contract-worker'
  );
  if result ->> 'status' <> 'idempotent_replay' then
    raise exception 'reconciliation replay failed: %', result;
  end if;
end;
$$;
reset role;
select pass('identical reconciliation replay is idempotent even with stale original tokens');

set local role service_role;
do $$
declare
  contribution_id uuid;
  contribution_version timestamptz;
  ledger_version timestamptz;
  mismatch_denied boolean := false;
begin
  select id, updated_at
    into contribution_id, contribution_version
    from public.group_contributions
   where client_request_reference = 'MOMOCLIENTMISMATCH0002';
  select updated_at into ledger_version
    from public.momo_ledger_entries
   where id = '99360000-0000-4000-8000-000000000221';

  begin
    perform public.reconcile_group_contribution_from_sms(
      contribution_id,
      '99360000-0000-4000-8000-000000000221',
      contribution_version,
      ledger_version,
      'reconcile:mismatch:02',
      '99360000-0000-4000-8000-000000000004',
      'contract-worker'
    );
  exception when others then mismatch_denied := true;
  end;

  if not mismatch_denied
     or not exists (
       select 1
         from public.group_contributions
        where id = contribution_id
          and status = 'pending'
          and payment_status = 'pending_verification'
          and momo_reference is null
     )
     or not exists (
       select 1
         from public.momo_ledger_entries
        where id = '99360000-0000-4000-8000-000000000221'
          and ledger_status = 'draft'
          and target_record_id is null
     )
     or exists (
       select 1
         from public.momo_reconciliations
        where parsed_sms_id = '99360000-0000-4000-8000-000000000211'
     ) then
    raise exception 'amount mismatch did not fail closed and preserve pending state';
  end if;
end;
$$;
reset role;
select pass('amount mismatch rejects reconciliation without partial state');

create or replace function public.test_force_contribution_audit_rollback()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.action = 'group_contribution_sms_reconciled'
     and new.metadata ->> 'idempotency_key' = 'reconcile:rollback:03' then
    raise exception 'forced audit rollback contract';
  end if;
  return new;
end;
$$;

create trigger trg_test_force_contribution_audit_rollback
before insert on public.admin_audit_log
for each row execute function public.test_force_contribution_audit_rollback();

set local role service_role;
do $$
declare
  contribution_id uuid;
  contribution_version timestamptz;
  ledger_version timestamptz;
  forced_rollback boolean := false;
begin
  select id, updated_at
    into contribution_id, contribution_version
    from public.group_contributions
   where client_request_reference = 'MOMOCLIENTROLLBACK0003';
  select updated_at into ledger_version
    from public.momo_ledger_entries
   where id = '99360000-0000-4000-8000-000000000222';

  begin
    perform public.reconcile_group_contribution_from_sms(
      contribution_id,
      '99360000-0000-4000-8000-000000000222',
      contribution_version,
      ledger_version,
      'reconcile:rollback:03',
      '99360000-0000-4000-8000-000000000004',
      'contract-worker'
    );
  exception when others then forced_rollback := true;
  end;

  if not forced_rollback
     or not exists (
       select 1
         from public.group_contributions
        where id = contribution_id
          and status = 'pending'
          and reconciliation_id is null
          and momo_reference is null
     )
     or not exists (
       select 1
         from public.momo_ledger_entries
        where id = '99360000-0000-4000-8000-000000000222'
          and ledger_status = 'draft'
          and target_record_id is null
     )
     or exists (
       select 1
         from public.momo_reconciliations
        where parsed_sms_id = '99360000-0000-4000-8000-000000000212'
     ) then
    raise exception 'late audit failure left partial reconciliation state';
  end if;
end;
$$;
reset role;
select pass('late audit failure rolls back reconciliation, ledger and contribution atomically');

drop trigger trg_test_force_contribution_audit_rollback
  on public.admin_audit_log;
drop function public.test_force_contribution_audit_rollback();

set local role service_role;
do $$
declare
  immutable_denied boolean := false;
begin
  begin
    update public.group_contributions
       set momo_reference = 'TAMPERED999'
     where momo_reference = 'TXSUCCESS0001';
  exception when others then immutable_denied := true;
  end;

  if not immutable_denied then
    raise exception 'service-side direct mutation changed immutable payment identity';
  end if;
end;
$$;
reset role;
select pass('database trigger prevents rebinding an accepted payment reference');

select ok(
  (
    select current_total = 5000
      from public.groups
     where id = '99360000-0000-4000-8000-000000000110'
  ),
  'only the successful exact reconciliation affects the group total'
);

select ok(
  (
    select count(*) = 1
      from public.admin_audit_log
     where action = 'group_contribution_sms_reconciled'
       and club_id = 9936001
  ),
  'only the successful exact reconciliation remains in audit history'
);

select * from finish();

rollback;

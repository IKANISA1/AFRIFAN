-- Ticket purchase, tenant, lifecycle, and audit boundary regression checks.
-- Run against a migrated isolated database with `supabase test db`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(21);

select ok(
  not has_table_privilege('anon', 'public.tickets', 'SELECT')
  and not has_table_privilege('anon', 'public.tickets', 'INSERT')
  and not has_table_privilege('anon', 'public.tickets', 'UPDATE')
  and not has_table_privilege('anon', 'public.tickets', 'DELETE')
  and not has_table_privilege('authenticated', 'public.tickets', 'INSERT')
  and not has_table_privilege('authenticated', 'public.tickets', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.tickets', 'DELETE')
  and not has_table_privilege('authenticated', 'public.tickets', 'TRUNCATE')
  and has_column_privilege('authenticated', 'public.tickets', 'id', 'SELECT')
  and has_column_privilege('authenticated', 'public.tickets', 'updated_at', 'SELECT')
  and not has_column_privilege(
    'authenticated',
    'public.tickets',
    'mock_batch',
    'SELECT'
  )
  and has_table_privilege('service_role', 'public.tickets', 'SELECT')
  and has_table_privilege('service_role', 'public.tickets', 'INSERT')
  and has_table_privilege('service_role', 'public.tickets', 'UPDATE')
  and has_table_privilege('service_role', 'public.tickets', 'DELETE')
  and has_table_privilege('service_role', 'public.tickets', 'TRUNCATE'),
  'ticket ACL exposes only the supporter projection and RPC mutation boundary'
);

select ok(
  not has_table_privilege('anon', 'public.matches', 'SELECT')
  and not has_table_privilege('anon', 'public.matches', 'INSERT')
  and not has_table_privilege('anon', 'public.matches', 'UPDATE')
  and not has_table_privilege('anon', 'public.matches', 'DELETE')
  and not has_table_privilege('anon', 'public.matches', 'TRUNCATE')
  and has_column_privilege('anon', 'public.matches', 'id', 'SELECT')
  and has_column_privilege(
    'anon',
    'public.matches',
    'match_status',
    'SELECT'
  )
  and not has_column_privilege(
    'anon',
    'public.matches',
    'partner_id',
    'SELECT'
  )
  and not has_column_privilege(
    'anon',
    'public.matches',
    'image_rights_approved_by',
    'SELECT'
  )
  and has_column_privilege('authenticated', 'public.matches', 'id', 'SELECT')
  and has_column_privilege(
    'authenticated',
    'public.matches',
    'home_team',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.matches',
    'image_rights_approved_by',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.matches',
    'partner_id',
    'INSERT'
  )
  and has_column_privilege(
    'authenticated',
    'public.matches',
    'match_summary',
    'UPDATE'
  )
  and not has_column_privilege(
    'authenticated',
    'public.matches',
    'image_rights_approved',
    'UPDATE'
  )
  and has_table_privilege('authenticated', 'public.matches', 'DELETE')
  and not has_table_privilege('authenticated', 'public.matches', 'INSERT,UPDATE')
  and exists(select 1 from pg_policies where schemaname='public' and tablename='matches' and policyname='staff_step_up_delete' and permissive='RESTRICTIVE')
  and not has_table_privilege('authenticated', 'public.matches', 'TRUNCATE')
  and has_table_privilege('service_role', 'public.matches', 'INSERT')
  and has_table_privilege('service_role', 'public.matches', 'UPDATE')
  and has_table_privilege('service_role', 'public.matches', 'DELETE')
  and has_table_privilege('service_role', 'public.matches', 'TRUNCATE'),
  'match ACL preserves public fixtures and scoped editor columns without internal rights fields or broad insert/update; deletes retain staff assurance'
);

select ok(
  (
    select count(*) = 4
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'matches'
  )
  and exists (
    select 1
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'matches'
      and policyname = 'matches_public_read'
      and cmd = 'SELECT'
      and roles = array['anon', 'authenticated']::name[]
  )
  and exists (
    select 1
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'matches'
      and policyname = 'matches_admin_insert'
      and cmd = 'INSERT'
      and with_check ~ 'is_club_admin'
  )
  and exists (
    select 1
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'matches'
      and policyname = 'matches_admin_update'
      and cmd = 'UPDATE'
      and qual ~ 'is_club_admin'
      and with_check ~ 'is_club_admin'
  )
  and exists(select 1 from pg_policies where schemaname='public' and tablename='matches' and policyname='matches_admin_delete' and cmd='DELETE' and qual ~ 'is_club_admin'),
  'matches retain public read plus exact-row assignment insert/update/delete policies'
);

select ok(
  (
    select count(*) = 2
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'tickets'
      and cmd = 'SELECT'
      and roles = array['authenticated']::name[]
  )
  and not exists (
    select 1
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'tickets'
      and cmd <> 'SELECT'
  )
  and exists (
    select 1
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'tickets'
      and policyname = 'tickets_select_own'
      and qual ~ 'requesting_club_id'
      and qual ~ 'auth.uid'
  )
  and exists (
    select 1
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'tickets'
      and policyname = 'tickets_admin_select'
      and qual ~ 'is_club_admin'
  ),
  'tickets retain exactly two read-only authenticated tenant policies'
);

select ok(
  exists (
    select 1
    from pg_proc as procedure
    where procedure.oid =
      'public.purchase_club_tickets(uuid,uuid,text,integer,text)'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'pg_advisory_xact_lock'
      and procedure.prosrc ~ 'requesting_club_id'
      and procedure.prosrc ~ 'v_sold_count \+ p_quantity'
  )
  and exists (
    select 1
    from pg_proc as procedure
    where procedure.oid =
      'public.cancel_ticket_if_unchanged(uuid,timestamptz)'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'v_previous.updated_at is distinct from p_expected_updated_at'
      and procedure.prosrc ~ 'supporter_ticket_cancel'
  ),
  'purchase and cancellation RPCs fix their path, tenant, capacity, audit, and version boundaries'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.purchase_club_tickets(uuid,uuid,text,integer,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.purchase_club_tickets(uuid,uuid,text,integer,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.purchase_club_tickets(uuid,uuid,text,integer,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.cancel_ticket_if_unchanged(uuid,timestamptz)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.cancel_ticket_if_unchanged(uuid,timestamptz)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.cancel_ticket_if_unchanged(uuid,timestamptz)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.admin_bulk_update_ticket_status(uuid[],text,bigint,uuid,text,boolean)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.admin_bulk_update_ticket_status_if_unchanged(uuid[],timestamptz[],text,bigint,uuid,text,boolean)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.admin_bulk_update_ticket_status_if_unchanged(uuid[],timestamptz[],text,bigint,uuid,text,boolean)',
    'EXECUTE'
  ),
  'supporter and service admin mutations expose only their version-checked RPCs'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.rs_check_ticket_capacity()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.refresh_match_ticket_sales()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.refresh_match_ticket_sales()',
    'EXECUTE'
  )
  and exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'tickets'
      and indexname = 'idx_tickets_purchase_reference'
      and indexdef ~ '\(user_id, match_id, momo_reference\)'
  ),
  'capacity and counter triggers are not API-callable and idempotency lookup is indexed'
);

insert into public.african_football_clubs (
  id,
  club_name,
  country_name,
  club_slug
) overriding system value values
  (9932001, 'Ticket Contract Club', 'Rwanda', 'ticket-contract-club'),
  (9932002, 'Foreign Ticket Contract Club', 'Rwanda', 'foreign-ticket-contract-club');

insert into public.partners (id, name, slug)
values (
  '99320000-0000-4000-8000-000000000100',
  'Ticket Contract Partner',
  'ticket-contract-partner'
);

insert into auth.users (id, aud, role)
values
  ('99320000-0000-4000-8000-000000000001', 'authenticated', 'authenticated'),
  ('99320000-0000-4000-8000-000000000002', 'authenticated', 'authenticated'),
  ('99320000-0000-4000-8000-000000000003', 'authenticated', 'authenticated');

insert into public.users (id, phone, full_name)
values
  ('99320000-0000-4000-8000-000000000001', '+250793200001', 'Ticket Contract Owner'),
  ('99320000-0000-4000-8000-000000000002', '+250793200002', 'Ticket Contract Outsider'),
  ('99320000-0000-4000-8000-000000000003', '+250793200003', 'Ticket Contract Admin');

insert into public.profiles (id, club_id)
values
  ('99320000-0000-4000-8000-000000000001', 9932001),
  ('99320000-0000-4000-8000-000000000002', 9932002),
  ('99320000-0000-4000-8000-000000000003', 9932001);

insert into public.admin_role_assignments (user_id, role, club_id)
values (
  '99320000-0000-4000-8000-000000000003',
  'club_admin',
  9932001
);

insert into public.matches (
  id,
  partner_id,
  club_id,
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
  sold_count
)
values
  (
    '99320000-0000-4000-8000-000000000110',
    '99320000-0000-4000-8000-000000000100',
    9932001,
    'Ticket Contract Home',
    'Ticket Contract Away',
    'Ticket Contract League',
    'Ticket Contract Stadium',
    current_date + 7,
    '18:00'::time,
    true,
    3000,
    10000,
    pg_catalog.now() - interval '1 day',
    3,
    0
  ),
  (
    '99320000-0000-4000-8000-000000000111',
    '99320000-0000-4000-8000-000000000100',
    9932002,
    'Foreign Ticket Contract Home',
    'Foreign Ticket Contract Away',
    'Ticket Contract League',
    'Foreign Ticket Contract Stadium',
    current_date + 7,
    '18:00'::time,
    true,
    2500,
    9000,
    pg_catalog.now() - interval '1 day',
    5,
    0
  );

set local role anon;
do $$
declare
  fixture_count integer;
  internal_column_denied boolean := false;
begin
  select pg_catalog.count(*)::integer
    into fixture_count
    from public.unified_matches;

  begin
    perform match.image_rights_approved_by
      from public.matches as match
     limit 1;
  exception
    when insufficient_privilege then internal_column_denied := true;
  end;

  if fixture_count < 0 or not internal_column_denied then
    raise exception 'public match contract failed: fixtures %, internal denied %',
      fixture_count,
      internal_column_denied;
  end if;
end $$;
reset role;
select pass('anonymous fixture view remains readable while internal rights columns stay denied');

select set_config(
  'request.jwt.claim.sub',
  '99320000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub','99320000-0000-4000-8000-000000000003','role','authenticated','club_id','9932001','is_anonymous',false,'aal','aal2','exp',floor(extract(epoch from clock_timestamp()))+3600,'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',floor(extract(epoch from clock_timestamp())))))::text,
  true
);
set local role authenticated;
do $$
declare
  changed_count integer;
begin
  update public.matches as match
     set match_summary = 'Tenant admin reviewed fixture'
   where match.id = '99320000-0000-4000-8000-000000000110';
  get diagnostics changed_count = row_count;

  if changed_count <> 1 then
    raise exception 'tenant admin match update failed: changed %', changed_count;
  end if;
end $$;
reset role;
select pass('current-club admin can use the bounded direct match editor contract');

select set_config(
  'request.jwt.claim.sub',
  '99320000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub','99320000-0000-4000-8000-000000000002','role','authenticated','club_id','9932002','is_anonymous',false,'aal','aal2','exp',floor(extract(epoch from clock_timestamp()))+3600,'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',floor(extract(epoch from clock_timestamp())))))::text,
  true
);
set local role authenticated;
do $$
declare
  denied boolean := false;
begin
  begin
    update public.matches as match
       set match_summary = 'Unauthorized fixture edit'
     where match.id in (
       '99320000-0000-4000-8000-000000000110',
       '99320000-0000-4000-8000-000000000111'
     );
  exception when insufficient_privilege then
    if sqlerrm<>'STAFF_ADMIN_REQUIRED' then raise; end if;
    denied := true;
  end;
  if not denied then
    raise exception 'non-admin match mutation was not denied';
  end if;
end $$;
reset role;
select pass('fresh assurance cannot authorize non-admin or cross-club match mutations');

select set_config(
  'request.jwt.claim.sub',
  '99320000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99320000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9932001","is_anonymous":true}',
  true
);
set local role authenticated;

do $$
declare
  direct_write_denied boolean := false;
  client_purchase_denied boolean := false;
begin
  begin
    insert into public.tickets (
      match_id,
      user_id,
      club_id,
      seat_type,
      amount_paid,
      status
    ) values (
      '99320000-0000-4000-8000-000000000110',
      '99320000-0000-4000-8000-000000000001',
      9932001,
      'general',
      3000,
      'pending'
    );
  exception
    when insufficient_privilege then direct_write_denied := true;
  end;

  begin
    perform public.purchase_club_tickets(
      '99320000-0000-4000-8000-000000000110',
      '99320000-0000-4000-8000-000000000001',
      'general',
      1,
      'ticket-contract-client-denied'
    );
  exception
    when insufficient_privilege then client_purchase_denied := true;
  end;

  if not direct_write_denied or not client_purchase_denied then
    raise exception 'client ticket writes were not denied: direct %, RPC %',
      direct_write_denied,
      client_purchase_denied;
  end if;
end $$;
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"99320000-0000-4000-8000-000000000001","role":"service_role","club_id":"9932001","is_anonymous":true}',
  true
);
set local role service_role;
do $$
declare
  first_ids uuid[];
  retry_ids uuid[];
begin
  select pg_catalog.array_agg(result.id order by result.id)
    into first_ids
    from public.purchase_club_tickets(
      '99320000-0000-4000-8000-000000000110',
      '99320000-0000-4000-8000-000000000001',
      'general',
      2,
      'ticket-contract-reference-1'
    ) as result;

  select pg_catalog.array_agg(result.id order by result.id)
    into retry_ids
    from public.purchase_club_tickets(
      '99320000-0000-4000-8000-000000000110',
      '99320000-0000-4000-8000-000000000001',
      'general',
      2,
      'ticket-contract-reference-1'
    ) as result;

  if pg_catalog.cardinality(first_ids) <> 2
     or retry_ids is distinct from first_ids then
    raise exception
      'server purchase contract failed: first %, retry %',
      first_ids,
      retry_ids;
  end if;
end $$;
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"99320000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9932001","is_anonymous":true}',
  true
);
set local role authenticated;
do $$
declare
  visible_count integer;
begin
  select pg_catalog.count(*)::integer
    into visible_count
    from public.tickets;

  if visible_count <> 2 then
    raise exception 'supporter ticket visibility failed: %', visible_count;
  end if;
end $$;
reset role;
select pass('server purchase is idempotent while authenticated direct and RPC writes are denied');

select is(
  (
    select sold_count
    from public.matches
    where id = '99320000-0000-4000-8000-000000000110'
  ),
  2,
  'pending ticket batches consume and refresh match capacity'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"99320000-0000-4000-8000-000000000001","role":"service_role","club_id":"9932001","is_anonymous":true}',
  true
);
set local role service_role;
do $$
declare
  wrong_owner_denied boolean := false;
  foreign_match_denied boolean := false;
  bad_seat_denied boolean := false;
  reused_reference_denied boolean := false;
begin
  begin
    perform public.purchase_club_tickets(
      '99320000-0000-4000-8000-000000000110',
      '99320000-0000-4000-8000-000000000002',
      'general',
      1,
      'ticket-contract-wrong-owner'
    );
  exception when raise_exception then wrong_owner_denied := true;
  end;

  begin
    perform public.purchase_club_tickets(
      '99320000-0000-4000-8000-000000000111',
      '99320000-0000-4000-8000-000000000001',
      'general',
      1,
      'ticket-contract-foreign-match'
    );
  exception when raise_exception then foreign_match_denied := true;
  end;

  begin
    perform public.purchase_club_tickets(
      '99320000-0000-4000-8000-000000000110',
      '99320000-0000-4000-8000-000000000001',
      'premium-lounge',
      1,
      'ticket-contract-bad-seat'
    );
  exception when raise_exception then bad_seat_denied := true;
  end;

  begin
    perform public.purchase_club_tickets(
      '99320000-0000-4000-8000-000000000110',
      '99320000-0000-4000-8000-000000000001',
      'vip',
      2,
      'ticket-contract-reference-1'
    );
  exception when raise_exception then reused_reference_denied := true;
  end;

  if not wrong_owner_denied
     or not foreign_match_denied
     or not bad_seat_denied
     or not reused_reference_denied then
    raise exception
      'purchase denial contract failed: owner %, club %, seat %, reused %',
      wrong_owner_denied,
      foreign_match_denied,
      bad_seat_denied,
      reused_reference_denied;
  end if;
end $$;
reset role;
select pass('purchase rejects owner spoofing, cross-club matches, invalid seats, and reference reuse');

set local role service_role;
do $$
declare
  oversell_denied boolean := false;
  quantity_denied boolean := false;
begin
  begin
    perform public.purchase_club_tickets(
      '99320000-0000-4000-8000-000000000110',
      '99320000-0000-4000-8000-000000000001',
      'general',
      2,
      'ticket-contract-oversell'
    );
  exception when raise_exception then oversell_denied := true;
  end;

  begin
    perform public.purchase_club_tickets(
      '99320000-0000-4000-8000-000000000110',
      '99320000-0000-4000-8000-000000000001',
      'general',
      11,
      'ticket-contract-quantity'
    );
  exception when raise_exception then quantity_denied := true;
  end;

  if not oversell_denied or not quantity_denied then
    raise exception 'capacity contract failed: oversell %, quantity %',
      oversell_denied,
      quantity_denied;
  end if;
end $$;
reset role;
select pass('server purchase rejects overselling and unbounded ticket batches');

select set_config(
  'request.jwt.claims',
  '{"sub":"99320000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9932001","is_anonymous":true}',
  true
);
set local role authenticated;
do $$
declare
  target_id uuid;
  loaded_version timestamptz;
  cancelled public.tickets;
  stale_denied boolean := false;
begin
  select ticket.id, ticket.updated_at
    into target_id, loaded_version
    from public.tickets as ticket
   where ticket.momo_reference = 'ticket-contract-reference-1'
   order by ticket.id
   limit 1;

  select *
    into cancelled
    from public.cancel_ticket_if_unchanged(target_id, loaded_version);

  begin
    perform public.cancel_ticket_if_unchanged(
      (
        select ticket.id
        from public.tickets as ticket
        where ticket.momo_reference = 'ticket-contract-reference-1'
          and ticket.status = 'pending'
        order by ticket.id
        limit 1
      ),
      '2000-01-01 00:00:00+00'::timestamptz
    );
  exception when raise_exception then stale_denied := true;
  end;

  if cancelled.status <> 'cancelled' or not stale_denied then
    raise exception 'cancellation contract failed: status %, stale %',
      cancelled.status,
      stale_denied;
  end if;
end $$;
reset role;
select pass('supporter cancellation returns the new state and rejects a stale loaded version');

set local role service_role;
do $$
declare
  target_id uuid;
  loaded_version timestamptz;
  changed_count integer;
  provider_denied boolean := false;
  stale_denied boolean := false;
  persisted_status text;
begin
  select ticket.id, ticket.updated_at
    into target_id, loaded_version
    from public.tickets as ticket
   where ticket.momo_reference = 'ticket-contract-reference-1'
     and ticket.status = 'pending'
   order by ticket.id
   limit 1;

  begin
    perform public.admin_bulk_update_ticket_status_if_unchanged(
      array[target_id],
      array[loaded_version],
      'valid',
      9932001,
      '99320000-0000-4000-8000-000000000003',
      'club_admin',
      false
    );
  exception when raise_exception then provider_denied := true;
  end;

  select public.admin_bulk_update_ticket_status_if_unchanged(
    array[target_id],
    array[loaded_version],
    'cancelled',
    9932001,
    '99320000-0000-4000-8000-000000000003',
    'club_admin',
    false
  ) into changed_count;

  select ticket.status
    into persisted_status
    from public.tickets as ticket
   where ticket.id = target_id;

  begin
    perform public.admin_bulk_update_ticket_status_if_unchanged(
      array[target_id],
      array['2000-01-01 00:00:00+00'::timestamptz],
      'used',
      9932001,
      '99320000-0000-4000-8000-000000000003',
      'club_admin',
      false
    );
  exception when raise_exception then stale_denied := true;
  end;

  if not provider_denied
     or changed_count <> 1
     or persisted_status <> 'cancelled'
     or not stale_denied then
    raise exception 'admin attestation/concurrency contract failed: provider %, changed %, status %, stale %',
      provider_denied,
      changed_count,
      persisted_status,
      stale_denied;
  end if;
end $$;
reset role;
select pass('service admin validation fails closed without provider evidence while exact-version cancellation remains safe');

select ok(
  exists (
    select 1
    from public.admin_audit_log
    where action = 'ticket_status_update'
      and club_id = 9932001
      and actor_id = '99320000-0000-4000-8000-000000000003'
      and old_data ->> 'status' = 'pending'
      and new_data ->> 'status' = 'cancelled'
      and old_data ? 'updated_at'
      and new_data ? 'updated_at'
      and metadata ->> 'optimistic_concurrency' = 'true'
      and metadata ->> 'selection_count' = '1'
  ),
  'admin ticket cancellation records exact actor, club, old/new state, versions, and batch size'
);

select set_config(
  'request.jwt.claim.sub',
  '99320000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99320000-0000-4000-8000-000000000002","role":"authenticated","club_id":"9932002","is_anonymous":true}',
  true
);
set local role authenticated;
do $$
declare
  visible_count integer;
  foreign_cancel_denied boolean := false;
begin
  select pg_catalog.count(*)::integer
    into visible_count
    from public.tickets;

  begin
    perform public.cancel_ticket_if_unchanged(
      (
        select ticket.id
        from public.tickets as ticket
        where ticket.momo_reference = 'ticket-contract-reference-1'
        limit 1
      ),
      pg_catalog.now()
    );
  exception when raise_exception then foreign_cancel_denied := true;
  end;

  if visible_count <> 0 or not foreign_cancel_denied then
    raise exception 'outsider isolation failed: visible %, cancellation %',
      visible_count,
      foreign_cancel_denied;
  end if;
end $$;
reset role;
select pass('a cross-club supporter sees no tickets and cannot cancel an owner ticket');

select is(
  (
    select pg_catalog.count(*)::integer
    from public.admin_audit_log
    where action = 'supporter_ticket_purchase'
      and club_id = 9932001
      and actor_id = '99320000-0000-4000-8000-000000000001'
  ),
  2,
  'the idempotent purchase writes exactly one actor-bound audit row per issued ticket'
);

select ok(
  exists (
    select 1
    from public.admin_audit_log
    where action = 'supporter_ticket_cancel'
      and club_id = 9932001
      and actor_id = '99320000-0000-4000-8000-000000000001'
      and old_data ->> 'status' = 'pending'
      and new_data ->> 'status' = 'cancelled'
      and metadata ->> 'scope' = 'active_club'
      and metadata ->> 'optimistic_concurrency' = 'true'
  ),
  'supporter cancellation records actor, club, old/new status, source, and concurrency mode'
);

select is(
  (
    select sold_count
    from public.matches
    where id = '99320000-0000-4000-8000-000000000110'
  ),
  0,
  'supporter and attestation-safe service cancellations release ticket capacity'
);

select * from finish();

rollback;

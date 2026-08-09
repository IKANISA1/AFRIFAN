-- Membership catalog, application, activation, review and tenant contract.

create extension if not exists pgtap with schema extensions;

begin;

select plan(15);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.fan_memberships'::regclass
      and conname = 'fan_memberships_tier_check'
      and pg_get_constraintdef(oid) ~ 'ingenzi-imanzi'
      and pg_get_constraintdef(oid) ~ 'silver'
  )
  and exists (
    select 1
    from pg_constraint
    where conrelid = 'public.membership_packages'::regclass
      and conname = 'membership_packages_tier_check'
      and pg_get_constraintdef(oid) ~ 'ingenzi-imanzi'
      and pg_get_constraintdef(oid) ~ 'silver'
  ),
  'canonical package and membership constraints support every official tier'
);

select ok(
  has_table_privilege('anon', 'public.membership_packages', 'SELECT')
  and has_table_privilege('authenticated', 'public.membership_packages', 'SELECT')
  and not has_table_privilege('authenticated', 'public.membership_packages', 'INSERT')
  and not has_table_privilege('authenticated', 'public.fan_memberships', 'SELECT')
  and has_column_privilege('authenticated', 'public.fan_memberships', 'tier', 'SELECT')
  and not has_column_privilege('authenticated', 'public.fan_memberships', 'mock_batch', 'SELECT')
  and not has_table_privilege('authenticated', 'public.fan_memberships', 'INSERT')
  and not has_table_privilege('authenticated', 'public.fan_memberships', 'UPDATE')
  and has_table_privilege('authenticated', 'public.membership_applications', 'SELECT')
  and not has_table_privilege('authenticated', 'public.membership_applications', 'INSERT')
  and not has_table_privilege('authenticated', 'public.membership_applications', 'UPDATE')
  and has_table_privilege('service_role', 'public.fan_memberships', 'UPDATE')
  and has_table_privilege('service_role', 'public.membership_applications', 'UPDATE'),
  'catalog is readable while supporter membership and application mutations are RPC-only'
);

select ok(
  (
    select count(*) = 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fan_memberships'
      and cmd = 'SELECT'
      and roles = array['authenticated']::name[]
  )
  and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fan_memberships'
      and cmd <> 'SELECT'
  )
  and (
    select count(*) = 2
    from pg_policies
    where schemaname = 'public'
      and tablename = 'membership_applications'
      and cmd = 'SELECT'
  )
  and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'membership_applications'
      and cmd <> 'SELECT'
  ),
  'legacy cross-club and self-escalation write policies are removed'
);

select ok(
  to_regclass('public.membership_tiers') is not null
  and exists (
    select 1
    from pg_class as relation
    where relation.oid = 'public.membership_tiers'::regclass
      and 'security_invoker=true' = any(coalesce(relation.reloptions, '{}'::text[]))
  )
  and has_table_privilege('anon', 'public.membership_tiers', 'SELECT')
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'membership_tiers'
      and column_name = 'category_slug'
  ),
  'the missing membership_tiers route is a security-invoker compatibility view'
);

select ok(
  exists (
    select 1
    from pg_proc
    where oid = 'public.activate_free_fan_membership()'::regprocedure
      and prosecdef
      and proconfig = array['search_path=""']::text[]
  )
  and exists (
    select 1
    from pg_proc
    where oid = 'public.submit_membership_application(text,text,text)'::regprocedure
      and prosecdef
      and proconfig = array['search_path=""']::text[]
      and prosrc ~ 'pg_advisory_xact_lock'
      and prosrc ~ 'physical_membership'
  )
  and exists (
    select 1
    from pg_proc
    where oid = 'public.review_membership_application_if_unchanged(uuid,timestamptz,text,text,uuid,text)'::regprocedure
      and prosecdef
      and proconfig = array['search_path=""']::text[]
      and prosrc ~ 'changed after it was loaded'
  )
  and has_function_privilege(
    'authenticated',
    'public.activate_free_fan_membership()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.submit_membership_application(text,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.submit_membership_application(text,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.review_membership_application_if_unchanged(uuid,timestamptz,text,text,uuid,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.review_membership_application_if_unchanged(uuid,timestamptz,text,text,uuid,text)',
    'EXECUTE'
  ),
  'membership RPCs fix their paths and expose exact supporter and service roles'
);

insert into public.african_football_clubs (
  id,
  club_name,
  country_name,
  club_slug
) overriding system value values
  (9935001, 'Membership Contract Club', 'Rwanda', 'membership-contract-club'),
  (9935002, 'Foreign Membership Contract Club', 'Rwanda', 'foreign-membership-contract-club');

insert into public.partners (id, name, slug, is_active)
values
  (
    '99350000-0000-4000-8000-000000000100',
    'Membership Contract Club',
    'membership-contract-club',
    true
  ),
  (
    '99350000-0000-4000-8000-000000000101',
    'Foreign Membership Contract Club',
    'foreign-membership-contract-club',
    true
  );

insert into auth.users (id, aud, role)
values
  ('99350000-0000-4000-8000-000000000001', 'authenticated', 'authenticated'),
  ('99350000-0000-4000-8000-000000000002', 'authenticated', 'authenticated'),
  ('99350000-0000-4000-8000-000000000003', 'authenticated', 'authenticated'),
  ('99350000-0000-4000-8000-000000000004', 'authenticated', 'authenticated');

insert into public.users (id, phone, full_name)
values
  ('99350000-0000-4000-8000-000000000001', '+250793500001', 'Membership Contract Owner'),
  ('99350000-0000-4000-8000-000000000002', '+250793500002', 'Membership Contract Outsider'),
  ('99350000-0000-4000-8000-000000000003', '+250793500003', 'Membership Contract Admin'),
  ('99350000-0000-4000-8000-000000000004', '+250793500004', 'Membership Contract Unauthorized Reviewer');

insert into public.profiles (id, club_id)
values
  ('99350000-0000-4000-8000-000000000001', 9935001),
  ('99350000-0000-4000-8000-000000000002', 9935002),
  ('99350000-0000-4000-8000-000000000003', 9935001),
  ('99350000-0000-4000-8000-000000000004', 9935001);

insert into public.admin_role_assignments (user_id, role, club_id)
values (
  '99350000-0000-4000-8000-000000000003',
  'club_admin',
  9935001
);

insert into public.membership_packages (
  id,
  partner_id,
  club_id,
  tier,
  title,
  subtitle,
  benefits,
  annual_price,
  price,
  benefit_scope,
  store_billing_required,
  is_active,
  sort_order
) values
  (
    '99350000-0000-4000-8000-000000000110',
    '99350000-0000-4000-8000-000000000100',
    9935001,
    'gold',
    'Gold Physical Membership',
    'Live-event and physical benefits',
    '["Reserved live-event access"]'::jsonb,
    100000,
    100000,
    'physical_membership',
    false,
    true,
    1
  ),
  (
    '99350000-0000-4000-8000-000000000111',
    '99350000-0000-4000-8000-000000000100',
    9935001,
    'silver',
    'Unclassified Silver Membership',
    'Not reviewed',
    '[]'::jsonb,
    40000,
    40000,
    'unclassified',
    false,
    true,
    2
  ),
  (
    '99350000-0000-4000-8000-000000000112',
    '99350000-0000-4000-8000-000000000100',
    9935001,
    'bronze',
    'Digital Bronze Membership',
    'Digital entitlement',
    '["Digital unlock"]'::jsonb,
    20000,
    20000,
    'digital_entitlement',
    true,
    true,
    3
  ),
  (
    '99350000-0000-4000-8000-000000000113',
    '99350000-0000-4000-8000-000000000101',
    9935002,
    'platinum',
    'Foreign Platinum Membership',
    'Foreign live-event membership',
    '[]'::jsonb,
    200000,
    200000,
    'physical_membership',
    false,
    true,
    1
  ),
  (
    '99350000-0000-4000-8000-000000000114',
    '99350000-0000-4000-8000-000000000100',
    9935001,
    'fan',
    'Free Supporter Membership',
    'Free base club membership',
    '[]'::jsonb,
    0,
    0,
    'physical_membership',
    false,
    true,
    4
  );

set local role anon;
select ok(
  (
    select pg_catalog.count(*) = 1
      and pg_catalog.bool_and(
        benefit_scope = 'physical_membership'
        and store_billing_required is false
        and coalesce(annual_price, price, 0) = 0
        and tier = 'fan'
      )
    from public.membership_tiers
    where active
  ),
  'anonymous clients see only the free, physical, non-billing catalog tier'
);
reset role;

select set_config(
  'request.jwt.claim.sub',
  '99350000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99350000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9935001","is_anonymous":true}',
  true
);
set local role authenticated;

do $$
declare
  direct_insert_denied boolean := false;
  direct_update_denied boolean := false;
  membership public.fan_memberships;
begin
  begin
    insert into public.fan_memberships (
      user_id,
      partner_id,
      club_id,
      tier,
      points,
      chapter,
      payment_status,
      status
    ) values (
      '99350000-0000-4000-8000-000000000001',
      '99350000-0000-4000-8000-000000000100',
      9935001,
      'gold',
      999999,
      'Escalated',
      'verified',
      'active'
    );
  exception when insufficient_privilege then direct_insert_denied := true;
  end;

  select * into membership
  from public.activate_free_fan_membership();

  begin
    update public.fan_memberships
       set tier = 'gold', points = 999999
     where id = membership.id;
  exception when insufficient_privilege then direct_update_denied := true;
  end;

  if not direct_insert_denied
     or not direct_update_denied
     or membership.user_id <> '99350000-0000-4000-8000-000000000001'
     or membership.club_id <> 9935001
     or membership.tier <> 'fan'
     or membership.points <> 0
     or membership.status <> 'active' then
    raise exception 'free membership boundary failed: %', membership;
  end if;
end $$;
reset role;
select pass('supporter obtains only a server-bound free base membership and direct escalation fails');

set local role authenticated;
do $$
declare
  first_id uuid;
  retry_id uuid;
begin
  select membership.id into first_id
  from public.activate_free_fan_membership() as membership;
  select membership.id into retry_id
  from public.activate_free_fan_membership() as membership;
  if first_id is distinct from retry_id then
    raise exception 'free membership retry changed id: % vs %', first_id, retry_id;
  end if;
end $$;
reset role;
select pass('free base membership activation is idempotent');

set local role authenticated;
do $$
declare
  paid_application_denied boolean := false;
begin
  begin
    perform public.submit_membership_application(
      'gold',
      'membership-contract-payment-1',
      'Kigali'
    );
  exception when insufficient_privilege then
    paid_application_denied := true;
  end;

  if not paid_application_denied then
    raise exception 'paid membership application did not fail closed';
  end if;
end $$;
reset role;
select pass('paid membership application is unavailable to the submitted client');

select is(
  (select pg_catalog.count(*)::integer from public.membership_applications),
  0,
  'no paid application or payment promise is created before reconciliation exists'
);

select ok(
  not has_function_privilege(
    'service_role',
    'public.submit_membership_application(text,text,text)',
    'EXECUTE'
  ),
  'the unverified paid application entry point is not exposed to service callers'
);

select set_config(
  'request.jwt.claim.sub',
  '99350000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99350000-0000-4000-8000-000000000002","role":"authenticated","club_id":"9935002","is_anonymous":true}',
  true
);
set local role authenticated;
select is(
  (
    select pg_catalog.count(*)::integer
    from public.membership_applications
  ),
  0,
  'another club cannot read the owner membership application'
);
reset role;

insert into public.membership_applications (
  id,
  user_id,
  club_id,
  tier,
  status,
  payment_status,
  metadata
) values (
  '99350000-0000-4000-8000-000000000120',
  '99350000-0000-4000-8000-000000000001',
  9935001,
  'gold',
  'pending',
  'unpaid',
  pg_catalog.jsonb_build_object(
    'package_id', '99350000-0000-4000-8000-000000000110',
    'amount', 100000,
    'source', 'contract_unverified_fixture'
  )
);

set local role service_role;
do $$
declare
  application_id uuid;
  loaded_version timestamptz;
  unauthorized_denied boolean := false;
  unverified_payment_denied boolean := false;
  stale_denied boolean := false;
  reviewed public.membership_applications;
begin
  select application.id, application.updated_at
    into application_id, loaded_version
    from public.membership_applications as application
   where application.user_id = '99350000-0000-4000-8000-000000000001'
     and application.tier = 'gold';

  begin
    perform public.review_membership_application_if_unchanged(
      application_id,
      loaded_version,
      'approved',
      'paid',
      '99350000-0000-4000-8000-000000000004',
      'Unauthorized review'
    );
  exception when raise_exception then unauthorized_denied := true;
  end;

  begin
    perform public.review_membership_application_if_unchanged(
      application_id,
      loaded_version,
      'approved',
      'paid',
      '99350000-0000-4000-8000-000000000003',
      'Reviewer must not manufacture paid status'
    );
  exception when raise_exception then unverified_payment_denied := true;
  end;

  select * into reviewed
  from public.review_membership_application_if_unchanged(
    application_id,
    loaded_version,
    'rejected',
    'failed',
    '99350000-0000-4000-8000-000000000003',
    'Provider payment was not independently verified'
  );

  begin
    perform public.review_membership_application_if_unchanged(
      application_id,
      loaded_version,
      'approved',
      'failed',
      '99350000-0000-4000-8000-000000000003',
      'Stale retry'
    );
  exception when raise_exception then stale_denied := true;
  end;

  if not unauthorized_denied
     or not unverified_payment_denied
     or not stale_denied
     or reviewed.status <> 'rejected'
     or reviewed.payment_status <> 'failed'
     or reviewed.reviewer_id <> '99350000-0000-4000-8000-000000000003' then
    raise exception 'membership review contract failed: %', reviewed;
  end if;
end $$;
reset role;
select pass('review cannot manufacture paid state and rejection remains versioned and scoped');

select ok(
  not exists (
    select 1
    from public.fan_memberships
    where user_id = '99350000-0000-4000-8000-000000000001'
      and club_id = 9935001
      and tier <> 'fan'
  ),
  'an unverified paid application cannot activate or upgrade membership'
);

select ok(
  not exists (
    select 1
    from public.admin_audit_log
    where action = 'supporter_membership_application_created'
      and actor_id = '99350000-0000-4000-8000-000000000001'
  )
  and exists (
    select 1
    from public.admin_audit_log
    where action = 'membership_application_reviewed'
      and actor_id = '99350000-0000-4000-8000-000000000003'
      and club_id = 9935001
      and old_data ->> 'status' = 'pending'
      and new_data ->> 'status' = 'rejected'
      and metadata ->> 'optimistic_concurrency' = 'true'
      and metadata ->> 'membership_activated' = 'false'
  ),
  'rejection retains authoritative actor, scope and state without a false paid audit trail'
);

select * from finish();

rollback;

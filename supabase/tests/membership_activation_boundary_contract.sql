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
  and has_function_privilege(
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
  );

set local role anon;
select is(
  (
    select pg_catalog.count(*)::integer
    from public.membership_tiers
    where active
  ),
  4,
  'anonymous clients can read the active compatibility catalog'
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
  application public.membership_applications;
begin
  select * into application
  from public.submit_membership_application(
    'gold',
    'membership-contract-payment-1',
    'Kigali'
  );

  if application.user_id <> '99350000-0000-4000-8000-000000000001'
     or application.club_id <> 9935001
     or application.status <> 'pending'
     or application.payment_status <> 'unpaid'
     or application.metadata ->> 'amount' <> '100000'
     or application.metadata ->> 'benefit_scope' <> 'physical_membership'
     or application.metadata ->> 'payment_reference' <>
       'membership-contract-payment-1' then
    raise exception 'membership application contract failed: %', application;
  end if;
end $$;
reset role;
select pass('physical membership application binds server offer, price, actor and club');

set local role authenticated;
do $$
declare
  first_id uuid;
  retry_id uuid;
begin
  select application.id into first_id
  from public.membership_applications as application
  where application.user_id = auth.uid()
    and application.tier = 'gold'
    and application.status = 'pending';

  select application.id into retry_id
  from public.submit_membership_application(
    'gold',
    'membership-contract-payment-ignored-on-retry',
    'Kigali'
  ) as application;

  if retry_id is distinct from first_id then
    raise exception 'pending application retry changed id: % vs %', retry_id, first_id;
  end if;
end $$;
reset role;
select pass('one pending application per supporter, club and tier is idempotent');

set local role authenticated;
do $$
declare
  unclassified_denied boolean := false;
  digital_denied boolean := false;
  foreign_denied boolean := false;
begin
  begin
    perform public.submit_membership_application(
      'silver', 'membership-contract-unclassified', 'Kigali'
    );
  exception when raise_exception then unclassified_denied := true;
  end;

  begin
    perform public.submit_membership_application(
      'bronze', 'membership-contract-digital', 'Kigali'
    );
  exception when raise_exception then digital_denied := true;
  end;

  begin
    perform public.submit_membership_application(
      'platinum', 'membership-contract-foreign', 'Kigali'
    );
  exception when raise_exception then foreign_denied := true;
  end;

  if not unclassified_denied or not digital_denied or not foreign_denied then
    raise exception 'unsafe offer denial failed: unclassified %, digital %, foreign %',
      unclassified_denied,
      digital_denied,
      foreign_denied;
  end if;
end $$;
reset role;
select pass('unclassified, digital-billing, and foreign-club offers fail closed');

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

set local role service_role;
do $$
declare
  application_id uuid;
  loaded_version timestamptz;
  unauthorized_denied boolean := false;
  unpaid_denied boolean := false;
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
      'unpaid',
      '99350000-0000-4000-8000-000000000003',
      'Payment not verified'
    );
  exception when raise_exception then unpaid_denied := true;
  end;

  select * into reviewed
  from public.review_membership_application_if_unchanged(
    application_id,
    loaded_version,
    'approved',
    'paid',
    '99350000-0000-4000-8000-000000000003',
    'Verified physical membership payment'
  );

  begin
    perform public.review_membership_application_if_unchanged(
      application_id,
      loaded_version,
      'rejected',
      'failed',
      '99350000-0000-4000-8000-000000000003',
      'Stale retry'
    );
  exception when raise_exception then stale_denied := true;
  end;

  if not unauthorized_denied
     or not unpaid_denied
     or not stale_denied
     or reviewed.status <> 'approved'
     or reviewed.payment_status <> 'paid'
     or reviewed.reviewer_id <> '99350000-0000-4000-8000-000000000003' then
    raise exception 'membership review contract failed: %', reviewed;
  end if;
end $$;
reset role;
select pass('authorized service review requires paid state, exact version and scoped actor');

select ok(
  exists (
    select 1
    from public.fan_memberships
    where user_id = '99350000-0000-4000-8000-000000000001'
      and club_id = 9935001
      and tier = 'gold'
      and points = 0
      and payment_status = 'verified'
      and status = 'active'
      and renewed_at is not null
      and expires_at > renewed_at
  ),
  'approval activates the physical membership without client-controlled points'
);

select ok(
  exists (
    select 1
    from public.admin_audit_log
    where action = 'supporter_membership_application_created'
      and actor_id = '99350000-0000-4000-8000-000000000001'
      and club_id = 9935001
      and metadata ->> 'authoritative_offer' = 'true'
      and metadata ->> 'benefit_scope' = 'physical_membership'
  )
  and exists (
    select 1
    from public.admin_audit_log
    where action = 'membership_application_reviewed'
      and actor_id = '99350000-0000-4000-8000-000000000003'
      and club_id = 9935001
      and old_data ->> 'status' = 'pending'
      and new_data ->> 'status' = 'approved'
      and metadata ->> 'optimistic_concurrency' = 'true'
      and metadata ->> 'membership_activated' = 'true'
  ),
  'membership submission and review retain authoritative actor, scope, state and classification evidence'
);

select * from finish();

rollback;

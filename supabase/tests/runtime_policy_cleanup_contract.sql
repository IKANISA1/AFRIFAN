begin;

select plan(23);

select is(
  (
    select count(*)::integer
    from pg_policies
    where schemaname = 'public'
      and policyname in (
        'rs_fan_club_members_select_authenticated',
        'rs_fan_club_members_insert_own',
        'rs_fan_club_members_delete_own',
        'rs_initiative_contributions_select_authenticated',
        'rs_initiative_contributions_select_own',
        'rs_initiative_contributions_insert_own',
        'rs_initiative_contributions_update_own',
        'momo_sms_sender_allowlist_select_authenticated'
      )
  ),
  0,
  'legacy permissive runtime policies are absent'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'initiative_contributions'
      and policyname = 'initiative_contributions_update_own_or_admin'
      and cmd = 'UPDATE'
      and with_check is not null
      and with_check like '%requesting_club_id%'
      and with_check like '%auth.uid%'
  ),
  'initiative updates enforce the governed club and actor on the new row'
);

select ok(not has_table_privilege('anon', 'public.fan_club_members', 'select'),
  'anonymous cannot read fan club members');
select ok(not has_table_privilege('authenticated', 'public.fan_club_members', 'select'),
  'authenticated clients cannot enumerate fan club members');
select ok(has_table_privilege('service_role', 'public.fan_club_members', 'select'),
  'service role retains fan club member read access');
select ok(has_table_privilege('service_role', 'public.fan_club_members', 'insert,update,delete'),
  'service role retains fan club member mutation access');

select ok(not has_table_privilege('anon', 'public.initiative_contributions', 'select'),
  'anonymous cannot read initiative contributions');
select ok(not has_table_privilege('authenticated', 'public.initiative_contributions', 'select'),
  'authenticated has no all-column contribution read');
select ok(has_column_privilege('authenticated', 'public.initiative_contributions', 'initiative_id', 'select'),
  'authenticated can read initiative identifiers');
select ok(has_column_privilege('authenticated', 'public.initiative_contributions', 'amount', 'select'),
  'authenticated can read contribution amounts');
select ok(has_column_privilege('authenticated', 'public.initiative_contributions', 'status', 'select'),
  'authenticated can read contribution status');
select ok(has_column_privilege('authenticated', 'public.initiative_contributions', 'created_at', 'select'),
  'authenticated can read contribution creation time');
select ok(has_column_privilege('authenticated', 'public.initiative_contributions', 'user_id', 'select'),
  'authenticated can filter its own contribution rows');
select ok(has_column_privilege('authenticated', 'public.initiative_contributions', 'club_id', 'select'),
  'authenticated can filter the governed club');
-- The member-portal migration explicitly added the supporter's own receipt
-- reference. Actual owner/foreign/anonymous reads are exercised by
-- member_contribution_receipt_privacy_contract.sql.
select ok(has_column_privilege('authenticated', 'public.initiative_contributions', 'momo_reference', 'select'),
  'authenticated can read its receipt reference through the own-club row policy');
select ok(not has_table_privilege('authenticated', 'public.initiative_contributions', 'insert,update,delete'),
  'authenticated cannot mutate contribution rows directly');
select ok(has_table_privilege('service_role', 'public.initiative_contributions', 'select,insert,update,delete'),
  'service role retains contribution reconciliation access');

select ok(not has_table_privilege('anon', 'public.momo_sms_sender_allowlist', 'select'),
  'anonymous cannot read MoMo sender controls');
select ok(not has_table_privilege('authenticated', 'public.momo_sms_sender_allowlist', 'select'),
  'authenticated cannot read MoMo sender controls');
select ok(has_table_privilege('service_role', 'public.momo_sms_sender_allowlist', 'select,insert,update,delete'),
  'service role retains MoMo sender administration access');

select ok(
  coalesce((
    select c.reloptions @> array['security_invoker=true']
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'football' and c.relname = 'fixture_features'
  ), false),
  'fixture_features is security invoker'
);
select ok(
  coalesce((
    select c.reloptions @> array['security_invoker=true']
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'football' and c.relname = 'prediction_volume'
  ), false),
  'prediction_volume is security invoker'
);
select ok(
  not has_table_privilege('anon', 'football.fixture_features', 'select')
  and not has_table_privilege('authenticated', 'football.fixture_features', 'select')
  and not has_table_privilege('anon', 'football.prediction_volume', 'select')
  and not has_table_privilege('authenticated', 'football.prediction_volume', 'select'),
  'probability-engine views are not client APIs'
);

select * from finish();
rollback;

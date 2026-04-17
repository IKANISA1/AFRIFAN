\set ON_ERROR_STOP on

-- Platform feature management smoke checks
--
-- Run this after applying:
--   - 20260416140000_platform_feature_management.sql
--   - 20260416180000_harden_platform_feature_management.sql
--
-- The script validates:
--   - schema objects and helper functions
--   - hardened RLS policy contract
--   - public RPC execute grants
--   - feature access semantics
--   - audit-log trigger activity
--
-- Functional checks run inside a transaction and are rolled back.

\echo '== relations =='
select
  rel,
  to_regclass(rel) is not null as exists
from (
  values
    ('public.platform_features'),
    ('public.platform_feature_channels'),
    ('public.platform_feature_rules'),
    ('public.platform_content_blocks'),
    ('public.platform_feature_audit_logs')
) s(rel)
order by rel;

do $$
declare
  expected_rel text;
begin
  foreach expected_rel in array array[
    'public.platform_features',
    'public.platform_feature_channels',
    'public.platform_feature_rules',
    'public.platform_content_blocks',
    'public.platform_feature_audit_logs'
  ]
  loop
    if to_regclass(expected_rel) is null then
      raise exception 'Missing relation: %', expected_rel;
    end if;
  end loop;
end;
$$;

\echo '== functions =='
select
  p.oid::regprocedure as function_signature
from pg_proc p
join pg_namespace n
  on n.oid = p.pronamespace
where p.oid in (
  to_regprocedure('public.canonicalize_platform_feature_key(text)'),
  to_regprocedure('public.get_feature_access_state(text, text, bigint, boolean, text[])'),
  to_regprocedure('public.check_feature_enabled(text, text, bigint)'),
  to_regprocedure('public.get_platform_config(text, bigint)')
)
order by 1;

do $$
declare
  expected_signature text;
begin
  foreach expected_signature in array array[
    'public.canonicalize_platform_feature_key(text)',
    'public.get_feature_access_state(text, text, bigint, boolean, text[])',
    'public.check_feature_enabled(text, text, bigint)',
    'public.get_platform_config(text, bigint)'
  ]
  loop
    if to_regprocedure(expected_signature) is null then
      raise exception 'Missing function: %', expected_signature;
    end if;
  end loop;
end;
$$;

\echo '== policy contract =='
select
  schemaname,
  tablename,
  policyname,
  cmd
from pg_policies
where (schemaname, tablename, policyname) in (
  ('public', 'platform_features', 'platform_features_select_admin'),
  ('public', 'platform_features', 'platform_features_insert_admin'),
  ('public', 'platform_features', 'platform_features_update_admin'),
  ('public', 'platform_features', 'platform_features_delete_admin'),
  ('public', 'platform_feature_channels', 'platform_feature_channels_select_admin'),
  ('public', 'platform_feature_channels', 'platform_feature_channels_insert_admin'),
  ('public', 'platform_feature_channels', 'platform_feature_channels_update_admin'),
  ('public', 'platform_feature_channels', 'platform_feature_channels_delete_admin'),
  ('public', 'platform_feature_rules', 'platform_feature_rules_select_admin'),
  ('public', 'platform_feature_rules', 'platform_feature_rules_insert_admin'),
  ('public', 'platform_feature_rules', 'platform_feature_rules_update_admin'),
  ('public', 'platform_feature_rules', 'platform_feature_rules_delete_admin'),
  ('public', 'platform_content_blocks', 'platform_content_blocks_select_admin'),
  ('public', 'platform_content_blocks', 'platform_content_blocks_insert_admin'),
  ('public', 'platform_content_blocks', 'platform_content_blocks_update_admin'),
  ('public', 'platform_content_blocks', 'platform_content_blocks_delete_admin'),
  ('public', 'platform_feature_audit_logs', 'platform_feature_audit_logs_select_admin')
)
order by schemaname, tablename, policyname;

do $$
declare
  expected record;
begin
  for expected in
    select *
    from (
      values
        ('public', 'platform_features', 'platform_features_select_admin', 'SELECT'),
        ('public', 'platform_features', 'platform_features_insert_admin', 'INSERT'),
        ('public', 'platform_features', 'platform_features_update_admin', 'UPDATE'),
        ('public', 'platform_features', 'platform_features_delete_admin', 'DELETE'),
        ('public', 'platform_feature_channels', 'platform_feature_channels_select_admin', 'SELECT'),
        ('public', 'platform_feature_channels', 'platform_feature_channels_insert_admin', 'INSERT'),
        ('public', 'platform_feature_channels', 'platform_feature_channels_update_admin', 'UPDATE'),
        ('public', 'platform_feature_channels', 'platform_feature_channels_delete_admin', 'DELETE'),
        ('public', 'platform_feature_rules', 'platform_feature_rules_select_admin', 'SELECT'),
        ('public', 'platform_feature_rules', 'platform_feature_rules_insert_admin', 'INSERT'),
        ('public', 'platform_feature_rules', 'platform_feature_rules_update_admin', 'UPDATE'),
        ('public', 'platform_feature_rules', 'platform_feature_rules_delete_admin', 'DELETE'),
        ('public', 'platform_content_blocks', 'platform_content_blocks_select_admin', 'SELECT'),
        ('public', 'platform_content_blocks', 'platform_content_blocks_insert_admin', 'INSERT'),
        ('public', 'platform_content_blocks', 'platform_content_blocks_update_admin', 'UPDATE'),
        ('public', 'platform_content_blocks', 'platform_content_blocks_delete_admin', 'DELETE'),
        ('public', 'platform_feature_audit_logs', 'platform_feature_audit_logs_select_admin', 'SELECT')
    ) as expected(schema_name, table_name, policy_name, command_name)
  loop
    if not exists (
      select 1
      from pg_policies
      where schemaname = expected.schema_name
        and tablename = expected.table_name
        and policyname = expected.policy_name
        and cmd = expected.command_name
    ) then
      raise exception
        'Missing expected policy %.%.% (%).',
        expected.schema_name,
        expected.table_name,
        expected.policy_name,
        expected.command_name;
    end if;
  end loop;

  if exists (
    select 1
    from pg_policies
    where (schemaname, tablename, policyname) in (
      ('public', 'platform_features', 'Public read platform_features'),
      ('public', 'platform_feature_channels', 'Public read platform_feature_channels'),
      ('public', 'platform_feature_rules', 'Public read platform_feature_rules'),
      ('public', 'platform_content_blocks', 'Public read active platform_content_blocks'),
      ('public', 'platform_content_blocks', 'Admin read all platform_content_blocks'),
      ('public', 'platform_feature_audit_logs', 'Admin read platform_feature_audit_logs')
    )
  ) then
    raise exception 'Deprecated public-read policies are still present on platform feature tables.';
  end if;

  if exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_feature_audit_logs'
      and cmd in ('INSERT', 'UPDATE', 'DELETE')
  ) then
    raise exception 'platform_feature_audit_logs should not expose write policies.';
  end if;
end;
$$;

\echo '== privilege contract =='
select
  'anon execute get_platform_config' as check_name,
  has_function_privilege('anon', 'public.get_platform_config(text, bigint)', 'EXECUTE') as ok
union all
select
  'authenticated execute get_platform_config',
  has_function_privilege('authenticated', 'public.get_platform_config(text, bigint)', 'EXECUTE')
union all
select
  'anon execute get_feature_access_state',
  has_function_privilege('anon', 'public.get_feature_access_state(text, text, bigint, boolean, text[])', 'EXECUTE')
union all
select
  'authenticated execute get_feature_access_state',
  has_function_privilege('authenticated', 'public.get_feature_access_state(text, text, bigint, boolean, text[])', 'EXECUTE')
union all
select
  'anon execute check_feature_enabled',
  has_function_privilege('anon', 'public.check_feature_enabled(text, text, bigint)', 'EXECUTE')
union all
select
  'authenticated execute check_feature_enabled',
  has_function_privilege('authenticated', 'public.check_feature_enabled(text, text, bigint)', 'EXECUTE')
union all
select
  'anon raw select platform_features',
  has_table_privilege('anon', 'public.platform_features', 'SELECT')
union all
select
  'anon raw select platform_feature_channels',
  has_table_privilege('anon', 'public.platform_feature_channels', 'SELECT')
union all
select
  'anon raw select platform_feature_rules',
  has_table_privilege('anon', 'public.platform_feature_rules', 'SELECT')
union all
select
  'anon raw select platform_content_blocks',
  has_table_privilege('anon', 'public.platform_content_blocks', 'SELECT')
union all
select
  'anon raw select platform_feature_audit_logs',
  has_table_privilege('anon', 'public.platform_feature_audit_logs', 'SELECT');

do $$
begin
  if not has_function_privilege('anon', 'public.get_platform_config(text, bigint)', 'EXECUTE') then
    raise exception 'anon is missing EXECUTE on get_platform_config(text, bigint)';
  end if;
  if not has_function_privilege('authenticated', 'public.get_platform_config(text, bigint)', 'EXECUTE') then
    raise exception 'authenticated is missing EXECUTE on get_platform_config(text, bigint)';
  end if;
  if not has_function_privilege('anon', 'public.get_feature_access_state(text, text, bigint, boolean, text[])', 'EXECUTE') then
    raise exception 'anon is missing EXECUTE on get_feature_access_state(text, text, bigint, boolean, text[])';
  end if;
  if not has_function_privilege('authenticated', 'public.get_feature_access_state(text, text, bigint, boolean, text[])', 'EXECUTE') then
    raise exception 'authenticated is missing EXECUTE on get_feature_access_state(text, text, bigint, boolean, text[])';
  end if;
  if not has_function_privilege('anon', 'public.check_feature_enabled(text, text, bigint)', 'EXECUTE') then
    raise exception 'anon is missing EXECUTE on check_feature_enabled(text, text, bigint)';
  end if;
  if not has_function_privilege('authenticated', 'public.check_feature_enabled(text, text, bigint)', 'EXECUTE') then
    raise exception 'authenticated is missing EXECUTE on check_feature_enabled(text, text, bigint)';
  end if;

  if has_table_privilege('anon', 'public.platform_feature_audit_logs', 'INSERT, UPDATE, DELETE') then
    raise exception 'anon unexpectedly has write privileges on platform_feature_audit_logs';
  end if;
end;
$$;

\echo '== canonicalization and baseline rpc checks =='
select public.canonicalize_platform_feature_key(' Fan Clubs!! ') as canonical_key;
select public.get_feature_access_state('NEWS', 'web', null, false, array[]::text[]) as news_access_state;
select
  public.get_platform_config('web', null) ->> 'channel' as config_channel,
  jsonb_array_length(public.get_platform_config('web', null) -> 'features') as feature_count,
  jsonb_array_length(public.get_platform_config('web', null) -> 'content_blocks') as content_block_count;

do $$
declare
  v_news_state jsonb;
  v_web_config jsonb;
begin
  if public.canonicalize_platform_feature_key(' Fan Clubs!! ') <> 'fan_clubs' then
    raise exception 'canonicalize_platform_feature_key did not normalize as expected';
  end if;

  v_news_state := public.get_feature_access_state('NEWS', 'web', null, false, array[]::text[]);
  if coalesce((v_news_state ->> 'is_registered')::boolean, false) <> true then
    raise exception 'Expected NEWS to resolve as a registered feature';
  end if;
  if v_news_state ->> 'feature_key' <> 'news' then
    raise exception 'Expected NEWS to canonicalize to feature_key=news, got %', v_news_state ->> 'feature_key';
  end if;

  v_web_config := public.get_platform_config('web', null);
  if jsonb_typeof(v_web_config) <> 'object' then
    raise exception 'get_platform_config(web, null) did not return a JSON object';
  end if;
  if jsonb_typeof(v_web_config -> 'features') <> 'array' then
    raise exception 'get_platform_config(web, null) is missing a features array';
  end if;
  if jsonb_typeof(v_web_config -> 'content_blocks') <> 'array' then
    raise exception 'get_platform_config(web, null) is missing a content_blocks array';
  end if;
  if v_web_config ->> 'channel' <> 'web' then
    raise exception 'get_platform_config(web, null) returned channel %, expected web', v_web_config ->> 'channel';
  end if;
  if not (v_web_config ? 'config_version') then
    raise exception 'get_platform_config(web, null) is missing config_version';
  end if;
end;
$$;

\echo '== functional feature semantics (transactional, rolls back) =='
begin;

do $$
declare
  v_suffix text := substring(md5(clock_timestamp()::text || random()::text) from 1 for 8);
  v_hidden_key text := '__smoke_hidden_' || v_suffix;
  v_channel_key text := '__smoke_channel_' || v_suffix;
  v_schedule_key text := '__smoke_schedule_' || v_suffix;
  v_auth_key text := '__smoke_auth_' || v_suffix;
  v_dep_parent_key text := '__smoke_dep_parent_' || v_suffix;
  v_dep_child_key text := '__smoke_dep_child_' || v_suffix;
  v_block_key text := '__smoke_block_' || v_suffix;
  v_hidden_feature_id uuid;
  v_channel_feature_id uuid;
  v_schedule_feature_id uuid;
  v_auth_feature_id uuid;
  v_dep_parent_feature_id uuid;
  v_dep_child_feature_id uuid;
  v_state jsonb;
  v_config jsonb;
  v_audit_count integer;
begin
  insert into public.platform_features (
    feature_key,
    display_name,
    description,
    category,
    club_id,
    is_enabled,
    visibility_state
  ) values (
    v_hidden_key,
    'Smoke Hidden Feature',
    'Temporary smoke-test hidden feature',
    'smoke',
    null,
    true,
    'hidden'
  )
  returning id into v_hidden_feature_id;

  insert into public.platform_feature_channels (
    feature_id,
    channel,
    is_enabled,
    is_visible,
    show_in_navigation,
    show_on_home,
    sort_order,
    route_key,
    placement_key
  ) values (
    v_hidden_feature_id,
    'web',
    true,
    true,
    true,
    false,
    10,
    '/smoke-hidden-' || v_suffix,
    'main_nav'
  );

  insert into public.platform_features (
    feature_key,
    display_name,
    description,
    category,
    club_id,
    is_enabled,
    visibility_state
  ) values (
    v_channel_key,
    'Smoke Channel Disabled Feature',
    'Temporary smoke-test channel disabled feature',
    'smoke',
    null,
    true,
    'visible'
  )
  returning id into v_channel_feature_id;

  insert into public.platform_feature_channels (
    feature_id,
    channel,
    is_enabled,
    is_visible,
    show_in_navigation,
    show_on_home,
    sort_order,
    route_key,
    placement_key
  ) values
    (
      v_channel_feature_id,
      'web',
      false,
      true,
      true,
      false,
      20,
      '/smoke-channel-' || v_suffix,
      'main_nav'
    ),
    (
      v_channel_feature_id,
      'mobile',
      true,
      true,
      false,
      true,
      30,
      '/smoke-channel-mobile-' || v_suffix,
      'home_top'
    );

  insert into public.platform_features (
    feature_key,
    display_name,
    description,
    category,
    club_id,
    is_enabled,
    visibility_state
  ) values (
    v_schedule_key,
    'Smoke Scheduled Feature',
    'Temporary smoke-test scheduled feature',
    'smoke',
    null,
    true,
    'visible'
  )
  returning id into v_schedule_feature_id;

  insert into public.platform_feature_channels (
    feature_id,
    channel,
    is_enabled,
    is_visible,
    show_in_navigation,
    show_on_home,
    sort_order,
    route_key,
    placement_key
  ) values (
    v_schedule_feature_id,
    'web',
    true,
    true,
    false,
    false,
    40,
    '/smoke-schedule-' || v_suffix,
    'home_top'
  );

  insert into public.platform_feature_rules (
    feature_id,
    schedule_start_at,
    schedule_end_at
  ) values (
    v_schedule_feature_id,
    now() + interval '1 day',
    null
  );

  insert into public.platform_features (
    feature_key,
    display_name,
    description,
    category,
    club_id,
    is_enabled,
    visibility_state
  ) values (
    v_auth_key,
    'Smoke Auth Feature',
    'Temporary smoke-test auth-gated feature',
    'smoke',
    null,
    true,
    'visible'
  )
  returning id into v_auth_feature_id;

  insert into public.platform_feature_channels (
    feature_id,
    channel,
    is_enabled,
    is_visible,
    show_in_navigation,
    show_on_home,
    sort_order,
    route_key,
    placement_key
  ) values (
    v_auth_feature_id,
    'web',
    true,
    true,
    false,
    false,
    50,
    '/smoke-auth-' || v_suffix,
    'home_top'
  );

  insert into public.platform_feature_rules (
    feature_id,
    auth_required
  ) values (
    v_auth_feature_id,
    true
  );

  insert into public.platform_features (
    feature_key,
    display_name,
    description,
    category,
    club_id,
    is_enabled,
    visibility_state
  ) values (
    v_dep_parent_key,
    'Smoke Dependency Parent',
    'Temporary smoke-test dependency parent',
    'smoke',
    null,
    true,
    'visible'
  )
  returning id into v_dep_parent_feature_id;

  insert into public.platform_feature_channels (
    feature_id,
    channel,
    is_enabled,
    is_visible,
    show_in_navigation,
    show_on_home,
    sort_order,
    route_key,
    placement_key
  ) values (
    v_dep_parent_feature_id,
    'web',
    false,
    true,
    false,
    false,
    60,
    '/smoke-dep-parent-' || v_suffix,
    'home_top'
  );

  insert into public.platform_features (
    feature_key,
    display_name,
    description,
    category,
    club_id,
    is_enabled,
    visibility_state
  ) values (
    v_dep_child_key,
    'Smoke Dependency Child',
    'Temporary smoke-test dependency child',
    'smoke',
    null,
    true,
    'visible'
  )
  returning id into v_dep_child_feature_id;

  insert into public.platform_feature_channels (
    feature_id,
    channel,
    is_enabled,
    is_visible,
    show_in_navigation,
    show_on_home,
    sort_order,
    route_key,
    placement_key
  ) values (
    v_dep_child_feature_id,
    'web',
    true,
    true,
    false,
    false,
    70,
    '/smoke-dep-child-' || v_suffix,
    'home_top'
  );

  insert into public.platform_feature_rules (
    feature_id,
    dependency_rules
  ) values (
    v_dep_child_feature_id,
    jsonb_build_object('requires', jsonb_build_array(v_dep_parent_key))
  );

  insert into public.platform_content_blocks (
    block_key,
    block_type,
    title,
    subtitle,
    content,
    target_channel,
    placement_key,
    feature_id,
    club_id,
    is_active,
    sort_order
  ) values (
    v_block_key,
    'banner',
    'Smoke Block',
    null,
    jsonb_build_object('smoke', true),
    'web',
    'home_top',
    v_hidden_feature_id,
    null,
    true,
    5
  );

  v_state := public.get_feature_access_state(v_hidden_key, 'web', null, false, array[]::text[]);
  if coalesce((v_state ->> 'is_visible')::boolean, true) <> false then
    raise exception 'Hidden smoke feature should not be visible: %', v_state;
  end if;
  if coalesce((v_state ->> 'is_operational')::boolean, false) <> true then
    raise exception 'Hidden smoke feature should remain operational: %', v_state;
  end if;
  if coalesce((v_state ->> 'is_available')::boolean, false) <> true then
    raise exception 'Hidden smoke feature should remain available: %', v_state;
  end if;
  if v_state ->> 'reason' <> 'hidden' then
    raise exception 'Hidden smoke feature expected reason=hidden, got %', v_state ->> 'reason';
  end if;
  if public.check_feature_enabled(v_hidden_key, 'web', null) <> true then
    raise exception 'check_feature_enabled should allow hidden smoke feature for backend execution';
  end if;

  v_state := public.get_feature_access_state(v_channel_key, 'web', null, false, array[]::text[]);
  if coalesce((v_state ->> 'is_operational')::boolean, true) <> false then
    raise exception 'Channel-disabled smoke feature should not be operational: %', v_state;
  end if;
  if v_state ->> 'reason' <> 'channel_disabled' then
    raise exception 'Channel-disabled smoke feature expected reason=channel_disabled, got %', v_state ->> 'reason';
  end if;

  v_state := public.get_feature_access_state(v_schedule_key, 'web', null, false, array[]::text[]);
  if coalesce((v_state ->> 'is_within_schedule')::boolean, true) <> false then
    raise exception 'Scheduled smoke feature should be outside schedule: %', v_state;
  end if;
  if v_state ->> 'reason' <> 'outside_schedule' then
    raise exception 'Scheduled smoke feature expected reason=outside_schedule, got %', v_state ->> 'reason';
  end if;

  v_state := public.get_feature_access_state(v_auth_key, 'web', null, false, array[]::text[]);
  if coalesce((v_state ->> 'is_available')::boolean, true) <> false then
    raise exception 'Auth-gated smoke feature should be unavailable to anonymous callers: %', v_state;
  end if;
  if v_state ->> 'reason' <> 'auth_required' then
    raise exception 'Auth-gated smoke feature expected reason=auth_required, got %', v_state ->> 'reason';
  end if;

  v_state := public.get_feature_access_state(v_auth_key, 'web', null, true, array[]::text[]);
  if coalesce((v_state ->> 'is_available')::boolean, false) <> true then
    raise exception 'Auth-gated smoke feature should be available to authenticated callers: %', v_state;
  end if;

  v_state := public.get_feature_access_state(v_dep_child_key, 'web', null, false, array[]::text[]);
  if coalesce((v_state ->> 'dependencies_satisfied')::boolean, true) <> false then
    raise exception 'Dependency-blocked smoke feature should report unsatisfied dependencies: %', v_state;
  end if;
  if v_state ->> 'reason' <> 'dependency_blocked' then
    raise exception 'Dependency-blocked smoke feature expected reason=dependency_blocked, got %', v_state ->> 'reason';
  end if;

  v_config := public.get_platform_config('web', null);
  if not exists (
    select 1
    from jsonb_array_elements(v_config -> 'features') as feature_row
    where feature_row ->> 'feature_key' = v_hidden_key
  ) then
    raise exception 'Temporary hidden smoke feature was not returned in get_platform_config(web, null)';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(v_config -> 'content_blocks') as block_row
    where block_row ->> 'block_key' = v_block_key
  ) then
    raise exception 'Temporary smoke content block was not returned in get_platform_config(web, null)';
  end if;

  select count(*)
  into v_audit_count
  from public.platform_feature_audit_logs
  where feature_id in (
    v_hidden_feature_id,
    v_channel_feature_id,
    v_schedule_feature_id,
    v_auth_feature_id,
    v_dep_parent_feature_id,
    v_dep_child_feature_id
  );

  if v_audit_count < 12 then
    raise exception 'Expected feature audit logs for smoke inserts, found %', v_audit_count;
  end if;
end;
$$;

rollback;

\echo '== notes =='
\echo 'Smoke checks passed if no exception was raised above.'

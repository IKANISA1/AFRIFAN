-- Release runtime read models, public-media boundaries, and store-rule authority.

create extension if not exists pgtap with schema extensions;

begin;

select plan(24);

select ok(
  not has_table_privilege('anon', 'public.news_articles', 'TRUNCATE')
  and not has_table_privilege('anon', 'public.users', 'MAINTAIN')
  and not has_table_privilege(
    'authenticated',
    'public.users',
    'MAINTAIN'
  )
  and not has_table_privilege(
    'authenticated',
    'public.platform_features',
    'REFERENCES'
  )
  and not has_table_privilege(
    'authenticated',
    'public.shop_orders',
    'TRIGGER'
  ),
  'anonymous and authenticated API roles have no dangerous table privileges'
);

select ok(
  has_column_privilege(
    'anon',
    'public.african_football_clubs',
    'nickname_brand_identity',
    'SELECT'
  )
  and not has_column_privilege(
    'anon',
    'public.african_football_clubs',
    'official_contact',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.african_football_clubs',
    'official_logo_url',
    'SELECT'
  ),
  'club identity projection excludes private contacts and ungoverned images'
);

select ok(
  has_column_privilege(
    'anon',
    'public.news_articles',
    'image_rights_approved',
    'SELECT'
  )
  and not has_column_privilege(
    'anon',
    'public.news_articles',
    'image_prompt',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.news_articles',
    'image_rights_approved_by',
    'SELECT'
  )
  and exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'news_articles'
      and policyname = 'news_articles_public_read'
      and qual ~ 'image_rights_approved'
  ),
  'published news exposes governed media without prompt or approver details'
);

select ok(
  has_column_privilege(
    'authenticated',
    'public.news_articles',
    'title',
    'INSERT'
  )
  and has_column_privilege(
    'authenticated',
    'public.news_articles',
    'is_published',
    'UPDATE'
  )
  and not has_column_privilege(
    'authenticated',
    'public.news_articles',
    'image_rights_approved',
    'UPDATE'
  )
  and not has_column_privilege(
    'authenticated',
    'public.news_articles',
    'image_prompt',
    'INSERT'
  ),
  'club admins can author news but cannot self-approve media rights'
);

select ok(
  has_column_privilege(
    'authenticated',
    'public.squad_players',
    'name',
    'SELECT'
  )
  and not has_column_privilege(
    'anon',
    'public.squad_players',
    'image_url',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.squad_players',
    'photo_url',
    'SELECT'
  ),
  'public squad is a text roster until player-image rights are governed'
);

select ok(
  has_column_privilege('anon', 'public.standings', 'points', 'SELECT')
  and has_column_privilege('anon', 'public.ai_content', 'body', 'SELECT')
  and has_table_privilege('anon', 'public.countries', 'SELECT')
  and has_table_privilege('anon', 'public.quick_actions', 'SELECT'),
  'safe public standings, approved copy, geography, and navigation are readable'
);

select ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'quick_actions'
      and policyname = 'quick_actions_public_active_read'
      and qual ~ 'is_active'
  )
  and exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'quick_actions'
      and policyname = 'quick_actions_admin_read'
      and qual ~ 'is_admin_user'
  ),
  'quick actions expose active public rows and retain inactive admin visibility'
);

select ok(
  not has_table_privilege('anon', 'public.app_config', 'SELECT')
  and not has_table_privilege(
    'authenticated',
    'public.club_app_config',
    'SELECT'
  )
  and has_function_privilege(
    'anon',
    'public.get_runtime_app_config(text,bigint)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_runtime_app_config(text,bigint)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.get_runtime_app_config(text,bigint)',
    'EXECUTE'
  ),
  'runtime config is an allowlisted RPC rather than a raw-table surface'
);

select ok(
  exists (
    select 1
    from pg_proc as procedure
    where procedure.oid =
      'public.get_runtime_app_config(text,bigint)'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'feature\\_%'
      and procedure.prosrc ~ 'support_email'
  ),
  'runtime config RPC is fixed-path and carries the explicit key allowlist'
);

insert into public.app_config (key, value, description)
values
  ('feature_release_contract_visible', 'true', 'pgTAP fixture'),
  ('release_contract_secret', 'must-not-escape', 'pgTAP fixture');

select is(
  (
    select pg_catalog.count(*)::integer
    from public.get_runtime_app_config(null, null)
    where key in (
      'feature_release_contract_visible',
      'release_contract_secret'
    )
  ),
  1,
  'runtime config returns the allowed feature key and omits the arbitrary key'
);

select ok(
  has_column_privilege('anon', 'public.partners', 'name', 'SELECT')
  and not has_column_privilege(
    'anon',
    'public.partners',
    'whatsapp_number',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.partners',
    'momo_code',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.partners',
    'metadata',
    'SELECT'
  ),
  'partner cards exclude legacy contact, payment, and free-form metadata'
);

select ok(
  has_column_privilege(
    'anon',
    'public.partner_services',
    'title',
    'SELECT'
  )
  and not has_column_privilege(
    'anon',
    'public.partner_services',
    'is_mock',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.partner_services',
    'title',
    'UPDATE'
  )
  and not has_column_privilege(
    'authenticated',
    'public.partner_services',
    'mock_batch',
    'UPDATE'
  )
  and exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'partner_services'
      and policyname = 'partner_services_public_active_read'
      and qual ~ 'is_active'
  ),
  'active partner services remain public while admin writes stay policy-bound'
);

select ok(
  has_column_privilege('anon', 'public.initiatives', 'title', 'SELECT')
  and not has_table_privilege(
    'authenticated',
    'public.initiatives',
    'INSERT'
  )
  and exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'initiatives'
      and policyname = 'initiatives_public_active_read'
      and qual ~ 'status = ''active'''
  ),
  'initiatives are an active public read model with server-owned mutations'
);

select ok(
  not has_table_privilege('authenticated', 'public.cool_events', 'SELECT')
  and has_column_privilege(
    'authenticated',
    'public.fet_events',
    'fet_awarded',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.fet_events',
    'metadata',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.fet_events',
    'INSERT'
  ),
  'client FET history is owner-readable but awards and metadata are server-owned'
);

select ok(
  not has_table_privilege(
    'authenticated',
    'public.fet_reward_store_items',
    'SELECT'
  )
  and has_table_privilege(
    'service_role',
    'public.fet_reward_store_items',
    'SELECT'
  ),
  'raw rewards catalog remains closed until the complete store-policy gate opens'
);

select ok(
  not has_table_privilege('anon', 'public.partner_payment_routes', 'SELECT')
  and has_column_privilege(
    'authenticated',
    'public.partner_payment_routes',
    'recipient_code',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.partner_payment_routes',
    'UPDATE'
  ),
  'payment instructions are authenticated, tenant-scoped, and read-only'
);


select ok(
  not has_table_privilege('anon', 'public.admin_role_assignments', 'SELECT')
  and has_column_privilege(
    'authenticated',
    'public.admin_role_assignments',
    'role',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.admin_audit_log',
    'metadata',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.admin_audit_log',
    'INSERT'
  ),
  'role and audit projections are read-only and policy scoped'
);

select ok(
  has_column_privilege(
    'authenticated',
    'public.notifications',
    'delivery_mode',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.notifications',
    'INSERT'
  )
  and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'notifications'
      and policyname = 'rs_notifications_admin'
  ),
  'notification history is scoped read-only and the unscoped legacy policy is gone'
);

select ok(
  has_column_privilege('anon', 'public.fan_clubs', 'name', 'SELECT')
  and not has_column_privilege(
    'anon',
    'public.fan_clubs',
    'banner_image_url',
    'SELECT'
  )
  and exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'fan_clubs'
      and policyname = 'fan_clubs_public_active_read'
      and qual ~ 'is_active'
  ),
  'canonical fan clubs expose active text records without ungoverned images'
);

select ok(
  not has_table_privilege('anon', 'public.platform_features', 'SELECT')
  and has_table_privilege(
    'authenticated',
    'public.platform_features',
    'UPDATE'
  )
  and has_table_privilege(
    'authenticated',
    'public.platform_feature_rules',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.platform_feature_audit_logs',
    'INSERT'
  ),
  'platform base tables are admin-policy surfaces, not anonymous runtime APIs'
);

select ok(
  not has_table_privilege('anon', 'public.platform_option_sets', 'SELECT')
  and not has_table_privilege(
    'anon',
    'public.platform_option_values',
    'SELECT'
  )
  and has_table_privilege(
    'authenticated',
    'public.platform_option_values',
    'UPDATE'
  ),
  'admin option registries no longer expose raw metadata anonymously'
);

select ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_option_sets'
      and policyname = 'platform_option_sets_select_runtime'
  )
  and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_option_values'
      and policyname = 'platform_option_values_select_runtime'
  )
  and exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'platform_option_sets'
      and policyname = 'platform_option_sets_write_admin'
  ),
  'option registries are visible only through the authenticated admin policy'
);

select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.platform_feature_rules'::regclass
      and tgname = 'enforce_store_release_rule_authority'
      and not tgisinternal
  )
  and exists (
    select 1
    from pg_proc as procedure
    where procedure.oid =
      'public.enforce_store_release_rule_authority()'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'store_release_authorized'
      and procedure.prosrc ~ 'store_billing_authorized'
  )
  and not has_function_privilege(
    'anon',
    'public.enforce_store_release_rule_authority()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.enforce_store_release_rule_authority()',
    'EXECUTE'
  ),
  'store-review rule assertions are fixed-path, trigger-only, and service controlled'
);

insert into auth.users (id, aud, role, raw_app_meta_data, raw_user_meta_data)
values (
  '99510400-0000-4000-8000-000000000001',
  'authenticated',
  'authenticated',
  '{}'::jsonb,
  '{}'::jsonb
);

insert into public.users (id, phone, full_name, is_admin)
values (
  '99510400-0000-4000-8000-000000000001',
  '+250780995104',
  'Runtime Read Contract Admin',
  true
)
on conflict (id) do update set is_admin = excluded.is_admin;

insert into public.platform_features (
  id,
  feature_key,
  display_name,
  category,
  is_enabled,
  visibility_state
) values (
  '99510400-0000-4000-8000-000000000002',
  'runtime_read_contract',
  'Runtime Read Contract',
  'test',
  false,
  'hidden'
);

insert into public.platform_feature_rules (
  id,
  feature_id,
  rollout_rules
) values (
  '99510400-0000-4000-8000-000000000003',
  '99510400-0000-4000-8000-000000000002',
  '{}'::jsonb
);

select set_config(
  'request.jwt.claim.sub',
  '99510400-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99510400-0000-4000-8000-000000000001","role":"authenticated"}',
  true
);
set local role authenticated;
do $$
declare
  approval_denied boolean := false;
begin
  begin
    update public.platform_feature_rules
    set rollout_rules = '{"store_release_authorized":true}'::jsonb
    where id = '99510400-0000-4000-8000-000000000003';
  exception
    when insufficient_privilege then
      approval_denied := sqlerrm =
        'Store-release approval rules require service-role authority';
  end;

  if not approval_denied then
    raise exception 'authenticated admin was able to assert a store approval';
  end if;
end;
$$;
reset role;
select pass('an authenticated admin cannot self-authorize a store-release rule');

select * from finish();

rollback;

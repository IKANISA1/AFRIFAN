-- Shop-order and catalog tenant-boundary regression checks.
-- Run against a migrated isolated database with `supabase test db`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(16);

select ok(
  not has_table_privilege('anon', 'public.shop_orders', 'SELECT')
  and not has_table_privilege('anon', 'public.shop_orders', 'INSERT')
  and not has_table_privilege('anon', 'public.shop_orders', 'UPDATE')
  and not has_table_privilege('anon', 'public.shop_orders', 'DELETE')
  and has_table_privilege('authenticated', 'public.shop_orders', 'SELECT')
  and not has_table_privilege('authenticated', 'public.shop_orders', 'INSERT')
  and not has_table_privilege('authenticated', 'public.shop_orders', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.shop_orders', 'DELETE')
  and not has_table_privilege('authenticated', 'public.shop_orders', 'TRUNCATE')
  and has_table_privilege('service_role', 'public.shop_orders', 'SELECT')
  and has_table_privilege('service_role', 'public.shop_orders', 'INSERT')
  and has_table_privilege('service_role', 'public.shop_orders', 'UPDATE')
  and has_table_privilege('service_role', 'public.shop_orders', 'DELETE')
  and has_table_privilege('service_role', 'public.shop_orders', 'TRUNCATE'),
  'shop order ACL exposes reads to authenticated and reserves all DML for service or RPC boundaries'
);

select ok(
  not has_table_privilege('anon', 'public.shop_products', 'SELECT')
  and has_column_privilege('anon', 'public.shop_products', 'id', 'SELECT')
  and not has_column_privilege('anon', 'public.shop_products', 'image_prompt', 'SELECT')
  and not has_table_privilege('anon', 'public.shop_products', 'INSERT')
  and not has_table_privilege('anon', 'public.shop_products', 'UPDATE')
  and not has_table_privilege('anon', 'public.shop_products', 'DELETE')
  and not has_table_privilege('authenticated', 'public.shop_products', 'SELECT')
  and has_column_privilege('authenticated', 'public.shop_products', 'name', 'SELECT')
  and not has_column_privilege('authenticated', 'public.shop_products', 'image_rights_approved_by', 'SELECT')
  and not has_table_privilege('authenticated', 'public.shop_products', 'INSERT')
  and not has_table_privilege('authenticated', 'public.shop_products', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.shop_products', 'DELETE')
  and not has_table_privilege('authenticated', 'public.shop_products', 'TRUNCATE')
  and has_table_privilege('service_role', 'public.shop_products', 'SELECT')
  and has_table_privilege('service_role', 'public.shop_products', 'INSERT')
  and has_table_privilege('service_role', 'public.shop_products', 'UPDATE')
  and has_table_privilege('service_role', 'public.shop_products', 'DELETE')
  and has_table_privilege('service_role', 'public.shop_products', 'TRUNCATE'),
  'shop product ACL keeps a safe active catalog projection and server-only administration'
);

select ok(
  (
    select count(*) = 2
    from pg_policies
    where schemaname = 'public'
      and tablename = 'shop_orders'
  )
  and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'shop_orders'
      and policyname like 'rs_shop_orders_%'
  )
  and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'shop_orders'
      and (cmd <> 'SELECT' or not ('authenticated' = any(roles)))
  ),
  'shop orders retain only explicit authenticated owner and scoped-admin read policies'
);

select ok(
  (
    select count(*) = 2
    from pg_policies
    where schemaname = 'public'
      and tablename = 'shop_products'
  )
  and exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'shop_products'
      and policyname = 'shop_products_select_active_anon'
      and 'anon' = any(roles)
      and cmd = 'SELECT'
      and qual ~ 'is_active'
      and qual ~ 'image_rights_approved'
  )
  and exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'shop_products'
      and policyname = 'shop_products_select_active_authenticated'
      and 'authenticated' = any(roles)
      and cmd = 'SELECT'
      and qual ~ 'requesting_club_id'
      and qual ~ 'image_rights_approved'
  )
  and not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'shop_products'
      and policyname in (
        'products_public_read',
        'public_read_active_products',
        'rs_shop_products_select_authenticated'
      )
  ),
  'catalog policies expose only active public rows and scoped authenticated rows'
);

select ok(
  exists (
    select 1
    from pg_proc as procedure
    join pg_namespace as namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'requesting_club_id'
      and procedure.pronargs = 0
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc !~* 'user_metadata'
      and procedure.prosrc ~ 'app_metadata'
      and procedure.prosrc ~ 'public\.profiles'
  )
  and exists (
    select 1
    from pg_proc as procedure
    where procedure.oid = 'public.cancel_shop_order_if_unchanged(uuid,timestamptz)'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'shop_order.club_id = v_actor_club_id'
  )
  and exists (
    select 1
    from pg_proc as procedure
    where procedure.oid = 'public.rs_decrement_stock_on_order()'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'club_id is not distinct from new.club_id'
      and procedure.prosrc ~ 'v_quantity <= 0'
      and procedure.prosrc ~ 'stock >= v_quantity'
  ),
  'tenant helpers, cancellation, and stock mutation have fixed paths and trusted scope predicates'
);

-- Isolated behavioral fixture. Every row is rolled back below.
insert into public.african_football_clubs (
  id,
  club_name,
  country_name,
  club_slug
) overriding system value values
  (9931001, 'Shop Tenant Contract Club', 'Rwanda', 'shop-tenant-contract-club'),
  (9931002, 'Foreign Shop Tenant Contract Club', 'Rwanda', 'foreign-shop-tenant-contract-club');

insert into auth.users (id, aud, role)
values
  ('99310000-0000-4000-8000-000000000001', 'authenticated', 'authenticated'),
  ('99310000-0000-4000-8000-000000000002', 'authenticated', 'authenticated'),
  ('99310000-0000-4000-8000-000000000003', 'authenticated', 'authenticated'),
  ('99310000-0000-4000-8000-000000000004', 'authenticated', 'authenticated');

insert into public.users (id, phone, full_name)
values
  ('99310000-0000-4000-8000-000000000001', '+250793100001', 'Shop Contract Member'),
  ('99310000-0000-4000-8000-000000000002', '+250793100002', 'Shop Contract Outsider'),
  ('99310000-0000-4000-8000-000000000003', '+250793100003', 'Shop Contract Club Admin'),
  ('99310000-0000-4000-8000-000000000004', '+250793100004', 'Shop Contract No Profile');

insert into public.profiles (id, club_id)
values
  ('99310000-0000-4000-8000-000000000001', 9931001),
  ('99310000-0000-4000-8000-000000000002', 9931001),
  ('99310000-0000-4000-8000-000000000003', 9931001);

insert into public.admin_role_assignments (user_id, role, club_id)
values (
  '99310000-0000-4000-8000-000000000003',
  'club_admin',
  9931001
);

insert into public.shop_products (
  id,
  club_id,
  name,
  category,
  price,
  stock,
  is_active
)
values
  (
    '99310000-0000-4000-8000-000000000010',
    9931001,
    'Active Shop Contract Product',
    'shirt',
    10000,
    5,
    true
  ),
  (
    '99310000-0000-4000-8000-000000000011',
    9931001,
    'Inactive Shop Contract Product',
    'shirt',
    12000,
    4,
    false
  ),
  (
    '99310000-0000-4000-8000-000000000012',
    9931002,
    'Foreign Active Shop Contract Product',
    'shirt',
    9000,
    6,
    true
  );

insert into public.shop_orders (
  id,
  user_id,
  club_id,
  items,
  subtotal,
  total,
  updated_at
)
values (
  '99310000-0000-4000-8000-000000000021',
  '99310000-0000-4000-8000-000000000001',
  9931002,
  '[]'::jsonb,
  0,
  0,
  '2026-08-08 00:00:00+00'::timestamptz
);

do $$
declare
  resolved text;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99310000-0000-4000-8000-000000000001',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99310000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9931002","app_metadata":{"club_id":"9931001"},"user_metadata":{"club_id":"9999999"}}',
    true
  );
  select public.requesting_club_id() into resolved;
  if resolved <> '9931002' then
    raise exception 'trusted top-level club claim was not preferred: %', resolved;
  end if;

  perform set_config(
    'request.jwt.claims',
    '{"sub":"99310000-0000-4000-8000-000000000001","role":"authenticated","app_metadata":{"club_id":"9931001"},"user_metadata":{"club_id":"9931002"}}',
    true
  );
  select public.requesting_club_id() into resolved;
  if resolved <> '9931001' then
    raise exception 'trusted app metadata was not preferred: %', resolved;
  end if;

  perform set_config(
    'request.jwt.claims',
    '{"sub":"99310000-0000-4000-8000-000000000001","role":"authenticated","user_metadata":{"club_id":"9931002"}}',
    true
  );
  select public.requesting_club_id() into resolved;
  if resolved <> '9931001' then
    raise exception 'profile fallback did not override editable user metadata: %', resolved;
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    '99310000-0000-4000-8000-000000000004',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99310000-0000-4000-8000-000000000004","role":"authenticated","user_metadata":{"club_id":"9931002"}}',
    true
  );
  select public.requesting_club_id() into resolved;
  if resolved is not null then
    raise exception 'editable metadata selected a club without a trusted source: %', resolved;
  end if;
end $$;
select pass('trusted claims and profile fallback resolve scope without user_metadata trust');

-- The clean replay deliberately has no general profile DML ACL. Temporarily
-- expose the real RLS boundary inside this rolled-back test transaction.
grant select, update on table public.profiles to authenticated;
select set_config(
  'request.jwt.claim.sub',
  '99310000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99310000-0000-4000-8000-000000000001","role":"authenticated","user_metadata":{"club_id":"9931002"}}',
  true
);
set local role authenticated;
do $$
declare
  denied boolean := false;
  persisted_club_id bigint;
begin
  begin
    update public.profiles
    set club_id = 9931002
    where id = '99310000-0000-4000-8000-000000000001';
  exception
    when insufficient_privilege then denied := true;
  end;

  select club_id into persisted_club_id
  from public.profiles
  where id = '99310000-0000-4000-8000-000000000001';

  if not denied or persisted_club_id <> 9931001 then
    raise exception 'supporter profile club reassignment was not denied: denied %, club %',
      denied,
      persisted_club_id;
  end if;
end $$;
reset role;
select pass('a supporter cannot rewrite the persisted profile tenant fallback');

select set_config(
  'request.jwt.claim.sub',
  '99310000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99310000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":true,"user_metadata":{"club_id":"9931002"}}',
  true
);
set local role authenticated;
do $$
declare
  visible_orders bigint;
  remaining_stock integer;
  loaded_version timestamptz;
  created_order public.shop_orders;
  cancelled_order public.shop_orders;
  direct_update_denied boolean := false;
begin
  select * into created_order
  from public.create_shop_order(
    jsonb_build_array(
      jsonb_build_object(
        'product_id', '99310000-0000-4000-8000-000000000010',
        'quantity', 2
      )
    ),
    'Kigali shop tenant contract address',
    'shop-tenant-contract-reference'
  );

  select count(*) into visible_orders
  from public.shop_orders
  where id = created_order.id
     or id = '99310000-0000-4000-8000-000000000021';

  select stock into remaining_stock
  from public.shop_products
  where id = '99310000-0000-4000-8000-000000000010';

  select updated_at into loaded_version
  from public.shop_orders
  where id = created_order.id;

  select * into cancelled_order
  from public.cancel_shop_order_if_unchanged(
    created_order.id,
    loaded_version
  );

  begin
    update public.shop_orders
    set total = 1
    where id = created_order.id;
  exception
    when insufficient_privilege then direct_update_denied := true;
  end;

  if visible_orders <> 1
     or remaining_stock <> 3
     or cancelled_order.status <> 'cancelled'
     or cancelled_order.inventory_reserved
     or not direct_update_denied then
    raise exception 'authoritative own-club order contract failed: visible %, stock %, status %, direct denied %',
      visible_orders,
      remaining_stock,
      cancelled_order.status,
      direct_update_denied;
  end if;
end $$;
reset role;
select pass('profile fallback permits authoritative checkout and scoped RPC cancellation without direct owner updates');

set local role authenticated;
do $$
declare
  denied boolean := false;
  cancellation_denied boolean := false;
  foreign_product_denied boolean := false;
  invalid_quantity_denied boolean := false;
  insufficient_stock_denied boolean := false;
begin
  begin
    insert into public.shop_orders (
      id,
      user_id,
      club_id,
      items,
      subtotal,
      total
    ) values (
      '99310000-0000-4000-8000-000000000022',
      '99310000-0000-4000-8000-000000000001',
      9931002,
      '[]'::jsonb,
      0,
      0
    );
  exception
    when insufficient_privilege then denied := true;
  end;

  begin
    perform public.cancel_shop_order_if_unchanged(
      '99310000-0000-4000-8000-000000000021',
      '2026-08-08 00:00:00+00'::timestamptz
    );
  exception
    when raise_exception then cancellation_denied := true;
  end;

  begin
    perform public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object(
          'product_id',
          '99310000-0000-4000-8000-000000000012',
          'quantity',
          1
        )
      ),
      'Kigali foreign product contract address',
      'shop-tenant-foreign-product'
    );
  exception
    when raise_exception then foreign_product_denied := true;
  end;

  begin
    perform public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object(
          'product_id',
          '99310000-0000-4000-8000-000000000010',
          'quantity',
          -2
        )
      ),
      'Kigali invalid quantity contract address',
      'shop-tenant-invalid-quantity'
    );
  exception
    when raise_exception then invalid_quantity_denied := true;
  end;

  begin
    perform public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object(
          'product_id',
          '99310000-0000-4000-8000-000000000010',
          'quantity',
          99
        )
      ),
      'Kigali insufficient stock contract address',
      'shop-tenant-insufficient-stock'
    );
  exception
    when raise_exception then insufficient_stock_denied := true;
  end;

  if not denied
     or not cancellation_denied
     or not foreign_product_denied
     or not invalid_quantity_denied
     or not insufficient_stock_denied then
    raise exception 'unsafe order actions were not denied: insert %, cancel %, product %, quantity %, stock %',
      denied,
      cancellation_denied,
      foreign_product_denied,
      invalid_quantity_denied,
      insufficient_stock_denied;
  end if;
end $$;
reset role;
select ok(
  (
    select stock = 6
    from public.shop_products
    where id = '99310000-0000-4000-8000-000000000012'
  )
  and (
    select stock = 5
    from public.shop_products
    where id = '99310000-0000-4000-8000-000000000010'
  ),
  'cross-club order, RPC, inventory, and invalid-quantity attacks fail atomically'
);

set local role authenticated;
do $$
declare
  foreign_visible bigint;
begin
  select count(*) into foreign_visible
  from public.shop_orders
  where id = '99310000-0000-4000-8000-000000000021';
  if foreign_visible <> 0 then
    raise exception 'cross-club order was visible to its user';
  end if;
end $$;
reset role;
select pass('an authenticated owner cannot read a same-user order from another club');

select set_config(
  'request.jwt.claim.sub',
  '99310000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99310000-0000-4000-8000-000000000002","role":"authenticated"}',
  true
);
set local role authenticated;
do $$
declare
  other_visible bigint;
begin
  select count(*) into other_visible
  from public.shop_orders
  where momo_reference = 'shop-tenant-contract-reference';
  if other_visible <> 0 then
    raise exception 'another supporter could read the member order';
  end if;
end $$;
reset role;
select pass('a same-club outsider cannot read another supporter order');

select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claims', '{"role":"anon"}', true);
set local role anon;
do $$
declare
  denied boolean := false;
begin
  begin
    perform 1 from public.shop_orders limit 1;
  exception
    when insufficient_privilege then denied := true;
  end;

  if not denied then
    raise exception 'raw anon order access was not denied';
  end if;
end $$;
reset role;
select pass('the raw anon role has no shop order access');

set local role anon;
do $$
declare
  active_visible bigint;
  inactive_visible bigint;
begin
  select count(*) into active_visible
  from public.shop_products
  where id in (
    '99310000-0000-4000-8000-000000000010',
    '99310000-0000-4000-8000-000000000011',
    '99310000-0000-4000-8000-000000000012'
  );
  select count(*) into inactive_visible
  from public.shop_products
  where id = '99310000-0000-4000-8000-000000000011';

  if active_visible <> 2 or inactive_visible <> 0 then
    raise exception 'public active-only catalog contract failed: visible %, inactive %',
      active_visible,
      inactive_visible;
  end if;
end $$;
reset role;
select pass('raw anon catalog reads expose active products but never inactive products');

select set_config(
  'request.jwt.claim.sub',
  '99310000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99310000-0000-4000-8000-000000000001","role":"authenticated","user_metadata":{"club_id":"9931002"}}',
  true
);
set local role authenticated;
do $$
declare
  visible_products bigint;
  mutation_denied boolean := false;
begin
  select count(*) into visible_products
  from public.shop_products
  where id in (
    '99310000-0000-4000-8000-000000000010',
    '99310000-0000-4000-8000-000000000011',
    '99310000-0000-4000-8000-000000000012'
  );

  begin
    update public.shop_products
    set stock = 99
    where id = '99310000-0000-4000-8000-000000000010';
  exception
    when insufficient_privilege then mutation_denied := true;
  end;

  if visible_products <> 1 or not mutation_denied then
    raise exception 'supporter product controls failed: visible %, mutation denied %',
      visible_products,
      mutation_denied;
  end if;
end $$;
reset role;
select pass('an authenticated supporter sees only active own-club products and cannot mutate them');

select set_config(
  'request.jwt.claim.sub',
  '99310000-0000-4000-8000-000000000003',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99310000-0000-4000-8000-000000000003","role":"authenticated"}',
  true
);
set local role authenticated;
do $$
declare
  visible_products bigint;
begin
  select count(*) into visible_products
  from public.admin_get_shop_products(50, 0, true) as product
  where product.id in (
    '99310000-0000-4000-8000-000000000010',
    '99310000-0000-4000-8000-000000000011',
    '99310000-0000-4000-8000-000000000012'
  );

  if visible_products <> 2 then
    raise exception 'club admin product read scope failed: %', visible_products;
  end if;
end $$;
reset role;
select pass('a club admin uses the bounded RPC to read active and inactive assigned-club products');

set local role authenticated;
do $$
declare
  update_denied boolean := false;
  insert_denied boolean := false;
  delete_denied boolean := false;
begin
  begin
    update public.shop_products
    set stock = 7
    where id = '99310000-0000-4000-8000-000000000010';
  exception
    when insufficient_privilege then update_denied := true;
  end;

  begin
    insert into public.shop_products (
      id,
      club_id,
      name,
      category,
      price,
      stock,
      is_active
    ) values (
      '99310000-0000-4000-8000-000000000013',
      9931002,
      'Denied Foreign Admin Product',
      'shirt',
      8000,
      1,
      true
    );
  exception
    when insufficient_privilege then insert_denied := true;
  end;

  begin
    delete from public.shop_products
    where id = '99310000-0000-4000-8000-000000000010';
  exception
    when insufficient_privilege then delete_denied := true;
  end;

  if not update_denied or not insert_denied or not delete_denied then
    raise exception 'direct admin mutation remained reachable: update %, insert %, delete %',
      update_denied,
      insert_denied,
      delete_denied;
  end if;
end $$;
reset role;
select pass('club-admin mobile sessions cannot bypass the server-side catalog mutation boundary');

select * from finish();

rollback;

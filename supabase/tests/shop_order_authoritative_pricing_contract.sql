-- Server-authoritative shop pricing, reservation, tenant and audit contract.
-- Run against a migrated isolated database with `supabase test db`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(16);

select ok(
  not has_table_privilege('anon', 'public.shop_orders', 'SELECT')
  and not has_table_privilege('authenticated', 'public.shop_orders', 'INSERT')
  and not has_table_privilege('authenticated', 'public.shop_orders', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.shop_orders', 'DELETE')
  and not has_table_privilege('authenticated', 'public.shop_orders', 'TRUNCATE')
  and has_table_privilege('authenticated', 'public.shop_orders', 'SELECT')
  and has_table_privilege('service_role', 'public.shop_orders', 'SELECT')
  and has_table_privilege('service_role', 'public.shop_orders', 'INSERT')
  and has_table_privilege('service_role', 'public.shop_orders', 'UPDATE')
  and has_table_privilege('service_role', 'public.shop_orders', 'DELETE'),
  'supporters read orders while creation and mutation stay on explicit server or safe-user RPC boundaries'
);

select ok(
  not has_table_privilege('anon', 'public.shop_products', 'SELECT')
  and has_column_privilege('anon', 'public.shop_products', 'id', 'SELECT')
  and has_column_privilege(
    'authenticated',
    'public.shop_products',
    'image_rights_approved',
    'SELECT'
  )
  and not has_column_privilege(
    'anon',
    'public.shop_products',
    'image_prompt',
    'SELECT'
  )
  and not has_column_privilege(
    'authenticated',
    'public.shop_products',
    'image_rights_approved_by',
    'SELECT'
  )
  and has_column_privilege('authenticated', 'public.shop_products', 'price', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.shop_products', 'image_rights_approved', 'UPDATE')
  and not has_column_privilege('authenticated', 'public.shop_products', 'image_rights_approved_by', 'INSERT')
  and (select count(*)=3 from pg_policy where polrelid='public.shop_products'::regclass
    and polname in ('staff_step_up_insert','staff_step_up_update','staff_step_up_delete')
    and not polpermissive and polroles=array['authenticated'::regrole::oid])
  and has_table_privilege('service_role', 'public.shop_products', 'UPDATE'),
  'public catalog preserves its safe projection and only guarded staff columns can be written'
);

select ok(
  (
    select count(*) = 2
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'shop_orders'
      and cmd = 'SELECT'
      and roles = array['authenticated']::name[]
  )
  and not exists (
    select 1
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'shop_orders'
      and cmd <> 'SELECT'
  )
  and (
    select count(*) = 2
    from (select * from pg_policies where permissive='PERMISSIVE') pg_policies
    where schemaname = 'public'
      and tablename = 'shop_products'
      and cmd = 'SELECT'
  ),
  'shop tables retain only the intended supporter and public read policies'
);

select ok(
  exists (
    select 1
    from pg_proc as procedure
    where procedure.oid =
      'public.create_shop_order(jsonb,text,text)'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'for update'
      and procedure.prosrc ~ 'pg_advisory_xact_lock'
      and procedure.prosrc ~ 'v_product.price'
      and procedure.prosrc ~ 'inventory_reserved'
  )
  and not has_function_privilege(
    'authenticated',
    'public.create_shop_order(jsonb,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.create_shop_order(jsonb,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.create_shop_order(jsonb,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.release_expired_shop_order_reservations(bigint)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.release_expired_shop_order_reservations(bigint)',
    'EXECUTE'
  )
  and exists (
    select 1
    from pg_proc as procedure
    where procedure.oid =
      'public.admin_get_shop_products(integer,integer,boolean)'::regprocedure
      and procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
      and procedure.prosrc ~ 'is_club_admin'
  )
  and has_function_privilege(
    'authenticated',
    'public.admin_get_shop_products(integer,integer,boolean)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.admin_get_shop_products(integer,integer,boolean)',
    'EXECUTE'
  ),
  'shop RPCs fix path, authorization, pricing, locking, idempotency and execution ACLs'
);

insert into public.african_football_clubs (
  id,
  club_name,
  country_name,
  club_slug
) overriding system value values
  (9934001, 'Shop Contract Club', 'Rwanda', 'shop-contract-club'),
  (9934002, 'Foreign Shop Contract Club', 'Rwanda', 'foreign-shop-contract-club');

insert into public.partners (id, name, slug)
values (
  '99340000-0000-4000-8000-000000000100',
  'Shop Contract Partner',
  'shop-contract-partner'
);

insert into auth.users (id, aud, role)
values
  ('99340000-0000-4000-8000-000000000001', 'authenticated', 'authenticated'),
  ('99340000-0000-4000-8000-000000000002', 'authenticated', 'authenticated');

insert into public.users (id, phone, full_name)
values
  ('99340000-0000-4000-8000-000000000001', '+250793400001', 'Shop Contract Owner'),
  ('99340000-0000-4000-8000-000000000002', '+250793400002', 'Shop Contract Outsider');

insert into public.profiles (id, club_id)
values
  ('99340000-0000-4000-8000-000000000001', 9934001),
  ('99340000-0000-4000-8000-000000000002', 9934002);

insert into public.shop_products (
  id,
  partner_id,
  club_id,
  name,
  category,
  price,
  stock,
  is_active,
  description,
  image_url,
  available_sizes,
  currency
) values
  (
    '99340000-0000-4000-8000-000000000110',
    '99340000-0000-4000-8000-000000000100',
    9934001,
    'Shop Contract Jersey',
    'shirt',
    12500,
    8,
    true,
    'Server-priced contract product',
    null,
    array['M', 'L'],
    'RWF'
  ),
  (
    '99340000-0000-4000-8000-000000000111',
    '99340000-0000-4000-8000-000000000100',
    9934002,
    'Foreign Shop Contract Jersey',
    'shirt',
    9000,
    5,
    true,
    'Foreign tenant product',
    null,
    array['M'],
    'RWF'
  );

set local role anon;
do $$
declare
  visible_count integer;
  internal_denied boolean := false;
begin
  select pg_catalog.count(*)::integer
    into visible_count
    from public.shop_products
   where is_active;

  begin
    perform product.image_prompt
      from public.shop_products as product
     limit 1;
  exception
    when insufficient_privilege then internal_denied := true;
  end;

  if visible_count <> 2 or not internal_denied then
    raise exception 'anonymous catalog boundary failed: visible %, internal %',
      visible_count,
      internal_denied;
  end if;
end $$;
reset role;
select pass('anonymous catalog reads approved rows while internal media fields stay denied');

select set_config(
  'request.jwt.claim.sub',
  '99340000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99340000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9934001","is_anonymous":true}',
  true
);
set local role authenticated;

do $$
declare
  direct_insert_denied boolean := false;
  client_create_denied boolean := false;
begin
  begin
    insert into public.shop_orders (
      user_id,
      club_id,
      items,
      subtotal,
      total,
      delivery_address,
      momo_reference
    ) values (
      '99340000-0000-4000-8000-000000000001',
      9934001,
      '[]'::jsonb,
      1,
      1,
      'Untrusted direct insert',
      'shop-contract-direct'
    );
  exception
    when insufficient_privilege then direct_insert_denied := true;
  end;

  begin
    perform public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', '99340000-0000-4000-8000-000000000110',
          'quantity', 1,
          'selected_variant', 'M'
        )
      ),
      'Denied client checkout address',
      'shop-contract-client-denied'
    );
  exception
    when insufficient_privilege then client_create_denied := true;
  end;

  if not direct_insert_denied or not client_create_denied then
    raise exception 'client shop writes were not denied: direct %, RPC %',
      direct_insert_denied,
      client_create_denied;
  end if;
end $$;
reset role;

select set_config(
  'request.jwt.claims',
  '{"sub":"99340000-0000-4000-8000-000000000001","role":"service_role","club_id":"9934001","is_anonymous":true}',
  true
);
set local role service_role;
do $$
declare
  created public.shop_orders;
begin

  select *
    into created
    from public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', '99340000-0000-4000-8000-000000000110',
          'quantity', 2,
          'selected_variant', 'M',
          'price', 1,
          'subtotal', 2,
          'discount_amount', 999999
        )
      ),
      'Kigali contract delivery address',
      'shop-contract-reference-1'
    );

  if created.user_id <> '99340000-0000-4000-8000-000000000001'
     or created.club_id <> 9934001
     or created.status <> 'pending'
     or created.subtotal <> 25000
     or created.total <> 25000
     or created.discount <> 0
     or created.discount_amount <> 0
     or not created.inventory_reserved
     or created.reservation_expires_at is null
     or created.items #>> '{0,product,price}' <> '12500'
     or created.items #>> '{0,product_id}' <>
       '99340000-0000-4000-8000-000000000110' then
    raise exception 'authoritative order creation contract failed: %', created;
  end if;
end $$;
reset role;
select pass('authenticated writes fail and the server RPC persists canonical price and scope');

select is(
  (
    select stock
    from public.shop_products
    where id = '99340000-0000-4000-8000-000000000110'
  ),
  6,
  'accepted reservation decrements stock exactly once'
);

set local role service_role;
do $$
declare
  first_id uuid;
  retry_id uuid;
begin
  select shop_order.id
    into first_id
    from public.shop_orders as shop_order
   where shop_order.momo_reference = 'shop-contract-reference-1';

  select retry.id
    into retry_id
    from public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', '99340000-0000-4000-8000-000000000110',
          'quantity', 2,
          'selected_variant', 'M'
        )
      ),
      'Kigali contract delivery address',
      'shop-contract-reference-1'
    ) as retry;

  if retry_id is distinct from first_id then
    raise exception 'idempotent retry changed order id: % vs %', retry_id, first_id;
  end if;
end $$;
reset role;
select is(
  (
    select stock
    from public.shop_products
    where id = '99340000-0000-4000-8000-000000000110'
  ),
  6,
  'same-reference retry returns the order without reserving stock twice'
);

set local role service_role;
do $$
declare
  duplicate_denied boolean := false;
  variant_denied boolean := false;
  oversell_denied boolean := false;
  foreign_denied boolean := false;
begin
  begin
    perform public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object('product_id', '99340000-0000-4000-8000-000000000110', 'quantity', 1, 'selected_variant', 'M'),
        jsonb_build_object('product_id', '99340000-0000-4000-8000-000000000110', 'quantity', 1, 'selected_variant', 'M')
      ),
      'Kigali contract delivery address',
      'shop-contract-duplicate'
    );
  exception when raise_exception then duplicate_denied := true;
  end;

  begin
    perform public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object('product_id', '99340000-0000-4000-8000-000000000110', 'quantity', 1, 'selected_variant', 'XL')
      ),
      'Kigali contract delivery address',
      'shop-contract-variant'
    );
  exception when raise_exception then variant_denied := true;
  end;

  begin
    perform public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object('product_id', '99340000-0000-4000-8000-000000000110', 'quantity', 7, 'selected_variant', 'M')
      ),
      'Kigali contract delivery address',
      'shop-contract-oversell'
    );
  exception when raise_exception then oversell_denied := true;
  end;

  begin
    perform public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object('product_id', '99340000-0000-4000-8000-000000000111', 'quantity', 1, 'selected_variant', 'M')
      ),
      'Kigali contract delivery address',
      'shop-contract-foreign'
    );
  exception when raise_exception then foreign_denied := true;
  end;

  if not duplicate_denied
     or not variant_denied
     or not oversell_denied
     or not foreign_denied then
    raise exception
      'invalid order denial failed: duplicate %, variant %, oversell %, foreign %',
      duplicate_denied,
      variant_denied,
      oversell_denied,
      foreign_denied;
  end if;
end $$;
reset role;
select pass('order RPC rejects duplicates, invalid variants, overselling, and foreign-club products');

select is(
  (
    select stock
    from public.shop_products
    where id = '99340000-0000-4000-8000-000000000110'
  ),
  6,
  'rejected order attempts roll back every inventory mutation'
);

select set_config(
  'request.jwt.claim.sub',
  '99340000-0000-4000-8000-000000000002',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99340000-0000-4000-8000-000000000002","role":"authenticated","club_id":"9934002","is_anonymous":true}',
  true
);
set local role authenticated;
do $$
declare
  visible_count integer;
begin
  select pg_catalog.count(*)::integer
    into visible_count
    from public.shop_orders;
  if visible_count <> 0 then
    raise exception 'outsider saw owner orders: %', visible_count;
  end if;
end $$;
reset role;
select pass('order history RLS hides owner orders from another club');

select set_config(
  'request.jwt.claim.sub',
  '99340000-0000-4000-8000-000000000001',
  true
);
select set_config(
  'request.jwt.claims',
  '{"sub":"99340000-0000-4000-8000-000000000001","role":"authenticated","club_id":"9934001","is_anonymous":true}',
  true
);
set local role authenticated;
do $$
declare
  target_id uuid;
  loaded_version timestamptz;
  cancelled public.shop_orders;
  retry_denied boolean := false;
begin
  select shop_order.id, shop_order.updated_at
    into target_id, loaded_version
    from public.shop_orders as shop_order
   where shop_order.momo_reference = 'shop-contract-reference-1';

  select *
    into cancelled
    from public.cancel_shop_order_if_unchanged(target_id, loaded_version);

  begin
    perform public.cancel_shop_order_if_unchanged(target_id, loaded_version);
  exception when raise_exception then retry_denied := true;
  end;

  if cancelled.status <> 'cancelled'
     or cancelled.inventory_reserved
     or not retry_denied then
    raise exception 'cancel/retry contract failed: status %, reserved %, retry %',
      cancelled.status,
      cancelled.inventory_reserved,
      retry_denied;
  end if;
end $$;
reset role;
select pass('versioned cancellation releases one reservation and rejects the retry');

select is(
  (
    select stock
    from public.shop_products
    where id = '99340000-0000-4000-8000-000000000110'
  ),
  8,
  'cancellation restocks the exact reserved quantity once'
);

select ok(
  exists (
    select 1
    from public.admin_audit_log
    where action = 'supporter_shop_order_created'
      and actor_id = '99340000-0000-4000-8000-000000000001'
      and club_id = 9934001
      and new_data ->> 'subtotal' = '25000'
      and metadata ->> 'authoritative_pricing' = 'true'
      and metadata ->> 'inventory_reserved' = 'true'
  )
  and exists (
    select 1
    from public.admin_audit_log
    where action = 'supporter_shop_order_cancelled'
      and actor_id = '99340000-0000-4000-8000-000000000001'
      and club_id = 9934001
      and old_data ->> 'status' = 'pending'
      and new_data ->> 'status' = 'cancelled'
      and metadata ->> 'optimistic_concurrency' = 'true'
      and metadata ->> 'inventory_restocked' = 'true'
  ),
  'order creation and cancellation retain actor, club, state, price and stock audit evidence'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"99340000-0000-4000-8000-000000000001","role":"service_role","club_id":"9934001","is_anonymous":true}',
  true
);
set local role service_role;
do $$
declare
  created public.shop_orders;
begin
  select *
    into created
    from public.create_shop_order(
      jsonb_build_array(
        jsonb_build_object(
          'product_id', '99340000-0000-4000-8000-000000000110',
          'quantity', 3,
          'selected_variant', 'L'
        )
      ),
      'Kigali expiring reservation address',
      'shop-contract-expiring'
    );
end $$;
reset role;

update public.shop_orders
   set reservation_expires_at = pg_catalog.now() - interval '1 minute'
 where momo_reference = 'shop-contract-expiring';

set local role service_role;
select is(
  public.release_expired_shop_order_reservations(9934001),
  1,
  'service expiry worker releases one expired reservation'
);
reset role;

select ok(
  (
    select status = 'cancelled' and not inventory_reserved
    from public.shop_orders
    where momo_reference = 'shop-contract-expiring'
  )
  and (
    select stock = 8
    from public.shop_products
    where id = '99340000-0000-4000-8000-000000000110'
  ),
  'expiry cancellation persists terminal state and restores stock'
);

select * from finish();

rollback;

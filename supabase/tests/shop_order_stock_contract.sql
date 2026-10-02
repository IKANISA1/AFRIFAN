-- Shop-order stock trigger regression checks.
-- Run against a migrated database with `supabase test db`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(6);

select ok(
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'rs_decrement_stock_on_order'
      and p.prorettype = 'trigger'::regtype
      and p.prosecdef
      and p.proconfig = array['search_path=""']::text[]
      and p.prosrc ~ 'update public\.shop_products'
      and p.prosrc !~ 'public\.rs_shop_products'
  ),
  'shop stock trigger targets the canonical table with a fixed empty search path'
);

select ok(
  not has_function_privilege(
    'public',
    'public.rs_decrement_stock_on_order()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.rs_decrement_stock_on_order()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.rs_decrement_stock_on_order()',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'public.rs_decrement_stock_on_order()',
    'EXECUTE'
  )
  and exists (
    select 1
    from pg_trigger t
    join pg_class c on c.oid = t.tgrelid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_proc p on p.oid = t.tgfoid
    where n.nspname = 'public'
      and c.relname = 'shop_orders'
      and t.tgname = 'trg_rs_shop_orders_decrement_stock'
      and not t.tgisinternal
      and p.oid = 'public.rs_decrement_stock_on_order()'::regprocedure
  ),
  'shop stock function is trigger-only and not directly executable by API roles'
);

insert into auth.users (id, aud, role)
values (
  '99000000-0000-4000-8000-000000000091',
  'authenticated',
  'authenticated'
);

insert into public.users (id, phone, full_name)
values (
  '99000000-0000-4000-8000-000000000091',
  '+250790000091',
  'Shop Stock Contract Member'
);

insert into public.shop_products (
  id,
  name,
  category,
  price,
  stock
) values (
  '99000000-0000-4000-8000-000000000092',
  'Shop Stock Contract Product',
  'shirt',
  10000,
  10
);

insert into public.shop_orders (
  id,
  user_id,
  items,
  subtotal,
  total,
  inventory_reserved
) values (
  '99000000-0000-4000-8000-000000000093',
  '99000000-0000-4000-8000-000000000091',
  jsonb_build_array(
    jsonb_build_object(
      'product',
      jsonb_build_object(
        'id',
        '99000000-0000-4000-8000-000000000092'
      ),
      'quantity',
      3
    )
  ),
  30000,
  30000,
  true
);

select is(
  (
    select stock
    from public.shop_products
    where id = '99000000-0000-4000-8000-000000000092'
  ),
  7,
  'a non-empty order using the current nested product payload decrements stock'
);

insert into public.shop_orders (
  id,
  user_id,
  items,
  subtotal,
  total,
  inventory_reserved
) values (
  '99000000-0000-4000-8000-000000000094',
  '99000000-0000-4000-8000-000000000091',
  jsonb_build_array(
    jsonb_build_object(
      'product_id',
      '99000000-0000-4000-8000-000000000092',
      'quantity',
      2
    )
  ),
  20000,
  20000,
  true
);

select is(
  (
    select stock
    from public.shop_products
    where id = '99000000-0000-4000-8000-000000000092'
  ),
  5,
  'the legacy top-level product_id order payload remains supported'
);

insert into public.shop_orders (
  id,
  user_id,
  items,
  subtotal,
  total,
  inventory_reserved
) values (
  '99000000-0000-4000-8000-000000000095',
  '99000000-0000-4000-8000-000000000091',
  '[]'::jsonb,
  0,
  0,
  true
);

select is(
  (
    select stock
    from public.shop_products
    where id = '99000000-0000-4000-8000-000000000092'
  ),
  5,
  'an empty order payload leaves stock unchanged'
);

do $contract$
declare
  v_stock_before integer;
begin
  select stock
  into v_stock_before
  from public.shop_products
  where id = '99000000-0000-4000-8000-000000000092';

  begin
    insert into public.shop_orders (
      id,
      user_id,
      items,
      subtotal,
      total,
      inventory_reserved
    ) values (
      '99000000-0000-4000-8000-000000000096',
      '99000000-0000-4000-8000-000000000091',
      jsonb_build_array(
        jsonb_build_object(
          'product_id',
          '99000000-0000-4000-8000-000000000092',
          'quantity',
          4
        )
      ),
      40000,
      40000,
      true
    );

    if (
      select stock
      from public.shop_products
      where id = '99000000-0000-4000-8000-000000000092'
    ) <> v_stock_before - 4 then
      raise exception 'stock did not change inside the rollback subtransaction';
    end if;

    raise sqlstate 'ZX001' using message = 'force contract rollback';
  exception
    when sqlstate 'ZX001' then
      null;
  end;

  if exists (
    select 1
    from public.shop_orders
    where id = '99000000-0000-4000-8000-000000000096'
  ) then
    raise exception 'forced rollback retained the order row';
  end if;

  if (
    select stock
    from public.shop_products
    where id = '99000000-0000-4000-8000-000000000092'
  ) <> v_stock_before then
    raise exception 'forced rollback retained the stock mutation';
  end if;
end
$contract$;

select pass('order insert and stock decrement roll back atomically');

select * from finish();

rollback;

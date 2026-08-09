begin;

alter table public.shop_orders
  add column if not exists inventory_reserved boolean not null default false,
  add column if not exists reservation_expires_at timestamp with time zone;

create index if not exists idx_shop_orders_expiring_reservations
on public.shop_orders (reservation_expires_at)
where status = 'pending' and inventory_reserved;

-- Only an RPC may create a supporter order. The two read policies remain for
-- owners and scoped admins; mutations use trusted service/admin paths.
revoke all privileges on table public.shop_orders
from public, anon, authenticated, service_role;
grant select on table public.shop_orders to authenticated;
grant all privileges on table public.shop_orders to service_role;

drop policy if exists shop_orders_insert_own on public.shop_orders;
drop policy if exists shop_orders_admin_update on public.shop_orders;
drop policy if exists shop_orders_admin_delete on public.shop_orders;

-- Public product reads exclude internal prompt/provenance/approval-actor data.
revoke all privileges on table public.shop_products
from public, anon, authenticated, service_role;
grant select (
  id,
  partner_id,
  club_id,
  name,
  subtitle,
  description,
  category,
  price,
  stock,
  is_active,
  is_new,
  image_url,
  sizes,
  available_sizes,
  badge_label,
  collection,
  sort_order,
  product_id,
  product_type,
  currency,
  image_rights_approved,
  image_provenance_id
) on table public.shop_products to anon, authenticated;
grant all privileges on table public.shop_products to service_role;

drop policy if exists shop_products_select_active_anon on public.shop_products;
drop policy if exists shop_products_select_active_authenticated on public.shop_products;
drop policy if exists shop_products_admin_all on public.shop_products;

create policy shop_products_select_active_anon
on public.shop_products
for select
to anon
using (
  is_active
  and (image_url is null or image_rights_approved)
);

create policy shop_products_select_active_authenticated
on public.shop_products
for select
to authenticated
using (
  is_active
  and club_id::text = public.requesting_club_id()
  and (image_url is null or image_rights_approved)
);

-- Admin writes are server-side with service_role. This removes a dormant
-- direct authenticated catalog mutation path while retaining RLS as defense
-- in depth for any future bounded admin RPC.

create or replace function public.admin_get_shop_products(
  p_limit integer default 50,
  p_offset integer default 0,
  p_include_inactive boolean default true
) returns table (
  id uuid,
  partner_id uuid,
  club_id bigint,
  name text,
  subtitle text,
  description text,
  category text,
  price numeric,
  stock integer,
  is_active boolean,
  is_new boolean,
  image_url text,
  sizes jsonb,
  available_sizes text[],
  badge_label text,
  collection text,
  sort_order integer,
  product_id text,
  product_type text,
  currency text,
  image_rights_approved boolean,
  image_provenance_id text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_club_id bigint;
begin
  if auth.uid() is null then
    raise exception 'An authenticated club administrator is required.';
  end if;

  if p_limit < 1 or p_limit > 100 or p_offset < 0 then
    raise exception 'Product page bounds are invalid.';
  end if;

  begin
    v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A valid trusted club scope is required.';
  end;

  if v_club_id is null or not public.is_club_admin(v_club_id) then
    raise exception 'Club administrator permission is required.';
  end if;

  return query
  select
    product.id,
    product.partner_id,
    product.club_id,
    product.name,
    product.subtitle,
    product.description,
    product.category,
    product.price,
    product.stock,
    product.is_active,
    product.is_new,
    product.image_url,
    product.sizes,
    product.available_sizes,
    product.badge_label,
    product.collection,
    product.sort_order,
    product.product_id,
    product.product_type,
    product.currency,
    product.image_rights_approved,
    product.image_provenance_id,
    product.created_at,
    product.updated_at
  from public.shop_products as product
  where product.club_id = v_club_id
    and (p_include_inactive or product.is_active)
  order by product.sort_order, product.name, product.id
  limit p_limit
  offset p_offset;
end;
$$;

revoke execute on function public.admin_get_shop_products(integer,integer,boolean)
from public, anon, authenticated, service_role;
grant execute on function public.admin_get_shop_products(integer,integer,boolean)
to authenticated;

create or replace function public.manage_shop_order_reservation_state()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.inventory_reserved
     and old.status = 'pending'
     and new.status <> 'pending' then
    new.inventory_reserved := false;
  end if;

  return new;
end;
$$;

revoke execute on function public.manage_shop_order_reservation_state()
from public, anon, authenticated, service_role;

drop trigger if exists manage_shop_order_reservation_state
on public.shop_orders;
create trigger manage_shop_order_reservation_state
before update of status on public.shop_orders
for each row execute function public.manage_shop_order_reservation_state();

create or replace function public.restock_cancelled_shop_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_product_id uuid;
  v_quantity integer;
begin
  if old.inventory_reserved
     and not new.inventory_reserved
     and new.status = 'cancelled' then
    for v_item in
      select value
      from pg_catalog.jsonb_array_elements(old.items)
    loop
      v_product_id := coalesce(
        nullif(v_item ->> 'product_id', ''),
        nullif(v_item -> 'product' ->> 'id', '')
      )::uuid;
      v_quantity := (v_item ->> 'quantity')::integer;

      update public.shop_products as product
         set stock = product.stock + v_quantity
       where product.id = v_product_id
         and product.club_id is not distinct from old.club_id;

      if not found then
        raise exception 'Reserved product is missing from the order club.';
      end if;
    end loop;
  end if;

  return new;
end;
$$;

revoke execute on function public.restock_cancelled_shop_order()
from public, anon, authenticated, service_role;

drop trigger if exists restock_cancelled_shop_order
on public.shop_orders;
create trigger restock_cancelled_shop_order
after update of status on public.shop_orders
for each row execute function public.restock_cancelled_shop_order();

create or replace function public.release_expired_shop_order_reservations(
  p_club_id bigint default null
) returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_released integer;
begin
  update public.shop_orders as shop_order
     set status = 'cancelled'
   where shop_order.status = 'pending'
     and shop_order.inventory_reserved
     and shop_order.reservation_expires_at <= pg_catalog.now()
     and (p_club_id is null or shop_order.club_id = p_club_id);

  get diagnostics v_released = row_count;
  return v_released;
end;
$$;

revoke execute on function public.release_expired_shop_order_reservations(bigint)
from public, anon, authenticated, service_role;
grant execute on function public.release_expired_shop_order_reservations(bigint)
to service_role;

create or replace function public.create_shop_order(
  p_items jsonb,
  p_delivery_address text,
  p_payment_reference text
) returns public.shop_orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_club_id bigint;
  v_item jsonb;
  v_product_id uuid;
  v_product public.shop_products;
  v_partner_id uuid;
  v_quantity integer;
  v_selected_variant text;
  v_subtotal bigint := 0;
  v_canonical_items jsonb := '[]'::jsonb;
  v_seen_product_ids uuid[] := '{}'::uuid[];
  v_delivery_address text := nullif(
    pg_catalog.btrim(coalesce(p_delivery_address, '')),
    ''
  );
  v_payment_reference text := nullif(
    pg_catalog.btrim(coalesce(p_payment_reference, '')),
    ''
  );
  v_order public.shop_orders;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  begin
    v_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A valid trusted club scope is required.';
  end;

  if v_club_id is null then
    raise exception 'A trusted club scope is required.';
  end if;

  if pg_catalog.jsonb_typeof(p_items) <> 'array'
     or pg_catalog.jsonb_array_length(p_items) < 1
     or pg_catalog.jsonb_array_length(p_items) > 20 then
    raise exception 'An order must contain between 1 and 20 products.';
  end if;

  if v_delivery_address is null
     or pg_catalog.length(v_delivery_address) < 5
     or pg_catalog.length(v_delivery_address) > 500 then
    raise exception 'A valid delivery address is required.';
  end if;

  if v_payment_reference is null
     or pg_catalog.length(v_payment_reference) > 120 then
    raise exception 'A valid payment reference is required.';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_actor_id::text || ':' || v_club_id::text || ':' || v_payment_reference,
      0
    )
  );

  perform public.release_expired_shop_order_reservations(v_club_id);

  select shop_order.*
    into v_order
    from public.shop_orders as shop_order
   where shop_order.user_id = v_actor_id
     and shop_order.club_id = v_club_id
     and shop_order.momo_reference = v_payment_reference
   order by shop_order.created_at desc, shop_order.id
   limit 1;

  if v_order.id is not null then
    return v_order;
  end if;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(p_items)
  loop
    begin
      v_product_id := nullif(v_item ->> 'product_id', '')::uuid;
      v_quantity := (v_item ->> 'quantity')::integer;
    exception
      when invalid_text_representation then
        raise exception 'Order item product and quantity must be valid.';
    end;

    if v_product_id is null or v_quantity < 1 or v_quantity > 20 then
      raise exception 'Each product quantity must be between 1 and 20.';
    end if;

    if v_product_id = any(v_seen_product_ids) then
      raise exception 'Duplicate products are not allowed in one order.';
    end if;
    v_seen_product_ids := pg_catalog.array_append(v_seen_product_ids, v_product_id);

    v_selected_variant := nullif(
      pg_catalog.btrim(coalesce(v_item ->> 'selected_variant', '')),
      ''
    );
    if pg_catalog.length(coalesce(v_selected_variant, '')) > 80 then
      raise exception 'Selected product variant is too long.';
    end if;

    select product.*
      into v_product
      from public.shop_products as product
     where product.id = v_product_id
       and product.club_id = v_club_id
       and product.is_active
       and (product.image_url is null or product.image_rights_approved)
     for update;

    if not found then
      raise exception 'Order item is unavailable in the active club catalog.';
    end if;

    if v_product.stock < v_quantity then
      raise exception 'Order item has insufficient stock.';
    end if;

    if v_product.price < 0
       or v_product.price <> pg_catalog.trunc(v_product.price)
       or v_product.price > 2147483647 then
      raise exception 'Order item price is not a valid RWF amount.';
    end if;

    if pg_catalog.cardinality(v_product.available_sizes) > 0
       and (
         v_selected_variant is null
         or not (v_selected_variant = any(v_product.available_sizes))
       ) then
      raise exception 'A valid available product variant is required.';
    end if;

    if v_partner_id is null then
      v_partner_id := v_product.partner_id;
    elsif v_partner_id is distinct from v_product.partner_id then
      raise exception 'All order products must use one fulfillment partner.';
    end if;

    v_subtotal := v_subtotal + (v_product.price::bigint * v_quantity);
    if v_subtotal > 2147483647 then
      raise exception 'Order total exceeds the supported amount.';
    end if;

    v_canonical_items := v_canonical_items || pg_catalog.jsonb_build_array(
      pg_catalog.jsonb_build_object(
        'product_id', v_product.id,
        'product', pg_catalog.jsonb_build_object(
          'id', v_product.id,
          'partner_id', v_product.partner_id,
          'club_id', v_product.club_id,
          'name', v_product.name,
          'description', v_product.description,
          'category', v_product.category,
          'price', v_product.price::integer,
          'is_active', v_product.is_active,
          'is_new', v_product.is_new,
          'image_url', v_product.image_url,
          'available_sizes', v_product.available_sizes,
          'badge_label', v_product.badge_label,
          'collection', v_product.collection,
          'sort_order', v_product.sort_order
        ),
        'quantity', v_quantity,
        'selected_variant', v_selected_variant
      )
    );
  end loop;

  insert into public.shop_orders (
    user_id,
    club_id,
    partner_id,
    items,
    subtotal,
    discount,
    discount_amount,
    delivery_fee,
    total,
    delivery_address,
    momo_reference,
    status,
    inventory_reserved,
    reservation_expires_at
  ) values (
    v_actor_id,
    v_club_id,
    v_partner_id,
    v_canonical_items,
    v_subtotal::integer,
    0,
    0,
    0,
    v_subtotal::integer,
    v_delivery_address,
    v_payment_reference,
    'pending',
    true,
    pg_catalog.now() + interval '15 minutes'
  )
  returning * into v_order;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  ) values (
    v_actor_id,
    v_actor_id,
    'supporter_shop_order_created',
    'shop_orders',
    v_order.id::text,
    null,
    pg_catalog.jsonb_build_object(
      'status', v_order.status,
      'subtotal', v_order.subtotal,
      'total', v_order.total,
      'reservation_expires_at', v_order.reservation_expires_at
    ),
    v_club_id,
    'shop_order',
    v_order.id::text,
    pg_catalog.jsonb_build_object(
      'scope', 'active_club',
      'source', 'mobile_shop_checkout',
      'authoritative_pricing', true,
      'inventory_reserved', true
    )
  );

  return v_order;
end;
$$;

revoke execute on function public.create_shop_order(jsonb,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.create_shop_order(jsonb,text,text)
to authenticated;

create or replace function public.cancel_shop_order_if_unchanged(
  p_order_id uuid,
  p_expected_updated_at timestamp with time zone
) returns public.shop_orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_club_id bigint;
  v_previous public.shop_orders;
  v_order public.shop_orders;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  begin
    v_actor_club_id := nullif(public.requesting_club_id(), '')::bigint;
  exception
    when invalid_text_representation then
      raise exception 'A valid trusted club scope is required.';
  end;

  if v_actor_club_id is null then
    raise exception 'A trusted club scope is required.';
  end if;

  if p_order_id is null or p_expected_updated_at is null then
    raise exception 'Order id and loaded version are required.';
  end if;

  select shop_order.*
    into v_previous
    from public.shop_orders as shop_order
   where shop_order.id = p_order_id
     and shop_order.user_id = v_actor_id
     and shop_order.club_id = v_actor_club_id
   for update;

  if not found then
    raise exception 'Order was not found in the active supporter account.';
  end if;

  if v_previous.status <> 'pending' then
    raise exception 'Order can no longer be cancelled. Refresh order history.';
  end if;

  if v_previous.updated_at is distinct from p_expected_updated_at then
    raise exception
      'Order changed after it was loaded. Refresh order history and review before retrying.';
  end if;

  update public.shop_orders as shop_order
     set status = 'cancelled'
   where shop_order.id = v_previous.id
  returning shop_order.* into v_order;

  insert into public.admin_audit_log (
    actor_id,
    user_id,
    action,
    target_table,
    target_id,
    old_data,
    new_data,
    club_id,
    entity_type,
    entity_id,
    metadata
  ) values (
    v_actor_id,
    v_actor_id,
    'supporter_shop_order_cancelled',
    'shop_orders',
    v_order.id::text,
    pg_catalog.jsonb_build_object(
      'status', v_previous.status,
      'updated_at', v_previous.updated_at,
      'inventory_reserved', v_previous.inventory_reserved
    ),
    pg_catalog.jsonb_build_object(
      'status', v_order.status,
      'updated_at', v_order.updated_at,
      'inventory_reserved', v_order.inventory_reserved
    ),
    v_actor_club_id,
    'shop_order',
    v_order.id::text,
    pg_catalog.jsonb_build_object(
      'scope', 'active_club',
      'source', 'mobile_order_history',
      'optimistic_concurrency', true,
      'inventory_restocked', true
    )
  );

  return v_order;
end;
$$;

revoke execute on function public.cancel_shop_order_if_unchanged(
  uuid,
  timestamp with time zone
) from public, anon, authenticated, service_role;
grant execute on function public.cancel_shop_order_if_unchanged(
  uuid,
  timestamp with time zone
) to authenticated;

commit;

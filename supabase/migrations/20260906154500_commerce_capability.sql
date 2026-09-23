-- Preserve native ordering; explicitly configured enquiry products cannot be charged.
begin;
alter table public.shop_products add column commerce_mode text not null default 'native'
  check(commerce_mode in ('native','enquiry'));
alter table public.shop_products add column enquiry_phone text
  check(enquiry_phone is null or enquiry_phone ~ '^[1-9][0-9]{7,14}$');
grant select(commerce_mode,enquiry_phone) on public.shop_products to anon, authenticated;
CREATE OR REPLACE FUNCTION "public"."create_shop_order"("p_items" "jsonb", "p_delivery_address" "text", "p_payment_reference" "text") RETURNS "public"."shop_orders"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO ''
    AS $$
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

    if v_product.commerce_mode <> 'native' then
      raise exception 'This product supports enquiries only.';
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


commit;

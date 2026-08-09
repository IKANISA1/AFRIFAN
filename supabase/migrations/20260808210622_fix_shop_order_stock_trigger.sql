-- Repair the shop-order stock trigger after the rs_* compatibility view was
-- retired. Keep the trigger privileged so authenticated order inserts can
-- update the RLS-protected catalog, but expose no callable function surface.
create or replace function public.rs_decrement_stock_on_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_item jsonb;
  v_product_id uuid;
  v_quantity integer;
begin
  if new.items is null or pg_catalog.jsonb_array_length(new.items) = 0 then
    return new;
  end if;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(new.items)
  loop
    -- Retain the original top-level product_id contract while accepting the
    -- nested product payload emitted by the current Flutter repository.
    v_product_id := coalesce(
      nullif(v_item ->> 'product_id', ''),
      nullif(v_item -> 'product' ->> 'id', '')
    )::uuid;
    v_quantity := coalesce((v_item ->> 'quantity')::integer, 1);

    update public.shop_products
    set stock = greatest(stock - v_quantity, 0)
    where id = v_product_id;
  end loop;

  return new;
end;
$function$;

revoke all on function public.rs_decrement_stock_on_order()
  from public, anon, authenticated, service_role;

comment on function public.rs_decrement_stock_on_order() is
  'Internal shop_orders trigger that atomically decrements public.shop_products stock; not a callable Data API function.';

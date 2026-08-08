-- Bind supporter venue orders to the caller's current governed check-in and
-- serialize identical idempotency keys before any order rows are written.

create or replace function public.venue_order_create(
  p_club_id bigint,
  p_venue_id uuid,
  p_checkin_id uuid,
  p_items jsonb,
  p_age_gate_confirmed boolean,
  p_idempotency_key text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_checkin public.venue_checkins;
  v_order public.venue_drink_orders;
  v_item jsonb;
  v_drink public.venue_drink_items;
  v_quantity integer;
  v_total integer := 0;
  v_has_alcohol boolean := false;
  v_idempotency_key text := nullif(btrim(coalesce(p_idempotency_key, '')), '');
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'error', 'code', 'auth_required');
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    return jsonb_build_object('status', 'error', 'code', 'items_required');
  end if;

  if jsonb_array_length(p_items) > 10 then
    return jsonb_build_object('status', 'error', 'code', 'item_limit_exceeded');
  end if;

  if v_idempotency_key is not null then
    perform pg_advisory_xact_lock(
      hashtextextended(
        v_user_id::text || ':' || p_club_id::text || ':' || v_idempotency_key,
        0
      )
    );

    select *
      into v_order
      from public.venue_drink_orders
     where club_id = p_club_id
       and user_id = v_user_id
       and idempotency_key = v_idempotency_key
     limit 1;

    if v_order.id is not null then
      return jsonb_build_object(
        'status', v_order.status,
        'code', 'idempotent_replay',
        'order_id', v_order.id,
        'total_amount', v_order.total_amount,
        'currency_code', v_order.currency_code,
        'payment_status', v_order.payment_status
      );
    end if;
  end if;

  select *
    into v_checkin
    from public.venue_checkins
   where id = p_checkin_id
     and club_id = p_club_id
     and venue_id = p_venue_id
     and user_id = v_user_id
     and status in ('confirmed', 'pending_review')
   limit 1;

  if v_checkin.id is null then
    return jsonb_build_object('status', 'error', 'code', 'checkin_required');
  end if;

  insert into public.venue_drink_orders (
    club_id,
    venue_id,
    checkin_id,
    user_id,
    status,
    idempotency_key,
    total_amount,
    age_gate_confirmed
  )
  values (
    p_club_id,
    p_venue_id,
    v_checkin.id,
    v_user_id,
    'created',
    v_idempotency_key,
    0,
    p_age_gate_confirmed
  )
  returning * into v_order;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    begin
      v_quantity := (v_item ->> 'quantity')::integer;
    exception
      when others then
        raise exception 'Drink quantity must be an integer between 1 and 20.';
    end;

    if v_quantity is null or v_quantity < 1 or v_quantity > 20 then
      raise exception 'Drink quantity must be between 1 and 20.';
    end if;

    select *
      into v_drink
      from public.venue_drink_items
     where id = (v_item ->> 'drink_item_id')::uuid
       and club_id = p_club_id
       and venue_id = p_venue_id
       and is_active
     limit 1;

    if v_drink.id is null then
      raise exception 'Drink item is unavailable.';
    end if;

    v_has_alcohol := v_has_alcohol or v_drink.is_alcohol;
    v_total := v_total + (v_drink.price_amount * v_quantity);

    insert into public.venue_drink_order_items (
      club_id,
      venue_id,
      order_id,
      drink_item_id,
      item_name,
      quantity,
      unit_price_amount,
      line_total_amount,
      is_alcohol
    )
    values (
      p_club_id,
      p_venue_id,
      v_order.id,
      v_drink.id,
      v_drink.item_name,
      v_quantity,
      v_drink.price_amount,
      v_drink.price_amount * v_quantity,
      v_drink.is_alcohol
    );
  end loop;

  if v_has_alcohol and not p_age_gate_confirmed then
    raise exception 'Age gate confirmation is required for alcohol items.';
  end if;

  update public.venue_drink_orders
     set total_amount = v_total,
         age_gate_confirmed = p_age_gate_confirmed
   where id = v_order.id
   returning * into v_order;

  insert into public.venue_order_events (
    club_id,
    venue_id,
    order_id,
    event_type,
    to_status,
    actor_id,
    metadata
  )
  values (
    p_club_id,
    p_venue_id,
    v_order.id,
    'order_created',
    'created',
    v_user_id,
    jsonb_build_object('item_count', jsonb_array_length(p_items))
  );

  return jsonb_build_object(
    'status', v_order.status,
    'code', 'ok',
    'order_id', v_order.id,
    'total_amount', v_order.total_amount,
    'currency_code', v_order.currency_code,
    'payment_status', v_order.payment_status
  );
exception
  when others then
    if v_order.id is not null then
      delete from public.venue_drink_orders where id = v_order.id;
    end if;
    raise;
end;
$$;

revoke execute on function public.venue_order_create(
  bigint,
  uuid,
  uuid,
  jsonb,
  boolean,
  text
) from public, anon, authenticated, service_role;
grant execute on function public.venue_order_create(
  bigint,
  uuid,
  uuid,
  jsonb,
  boolean,
  text
) to authenticated;

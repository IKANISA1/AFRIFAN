begin;

-- The client-supplied user_metadata claim is editable by the account holder and
-- must never select a tenant. Keep the server-controlled claims first and the
-- persisted profile as the compatibility fallback used by anonymous Auth users.
create or replace function public.requesting_club_id()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  with request_claims as (
    select coalesce(
      nullif(current_setting('request.jwt.claims', true), ''),
      '{}'
    )::jsonb as claims
  )
  select coalesce(
    public.normalize_club_id(
      nullif(
        coalesce(
          request_claims.claims ->> 'club_id',
          request_claims.claims -> 'app_metadata' ->> 'club_id'
        ),
        ''
      )
    )::text,
    (
      select profile.club_id::text
      from public.profiles as profile
      where profile.id = auth.uid()
      limit 1
    )
  )
  from request_claims;
$$;

-- The profile fallback is authoritative only while a user cannot rewrite its
-- tenant key. Supporter profile edits remain available, but club reassignment
-- requires a trusted claim or a privileged service/admin operation.
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
on public.profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check (
  (select auth.uid()) = id
  and club_id is not distinct from
    nullif(public.requesting_club_id(), '')::bigint
);

-- Reset the production-only broad ACL drift before granting the exact Data API
-- surface. Anonymous Auth sessions use the authenticated database role.
revoke all privileges on table public.shop_orders from public, anon, authenticated, service_role;
grant select, insert, update, delete on table public.shop_orders to authenticated;
grant all privileges on table public.shop_orders to service_role;

revoke all privileges on table public.shop_products from public, anon, authenticated, service_role;
grant select on table public.shop_products to anon;
grant select, insert, update, delete on table public.shop_products to authenticated;
grant all privileges on table public.shop_products to service_role;

-- Remove permissive legacy order policies whose user-only or partner-only
-- predicates could bypass the club tenant boundary.
drop policy if exists rs_shop_orders_insert_own on public.shop_orders;
drop policy if exists rs_shop_orders_select_own on public.shop_orders;
drop policy if exists rs_shop_orders_update_own on public.shop_orders;
drop policy if exists rs_shop_orders_update_admin on public.shop_orders;
drop policy if exists rs_shop_orders_delete_admin on public.shop_orders;

drop policy if exists shop_orders_insert_own on public.shop_orders;
create policy shop_orders_insert_own
on public.shop_orders
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);

drop policy if exists shop_orders_select_own on public.shop_orders;
create policy shop_orders_select_own
on public.shop_orders
for select
to authenticated
using (
  user_id = (select auth.uid())
  and club_id::text = public.requesting_club_id()
);

drop policy if exists shop_orders_update_own on public.shop_orders;

drop policy if exists shop_orders_admin_select on public.shop_orders;
create policy shop_orders_admin_select
on public.shop_orders
for select
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and (
    public.is_club_admin(club_id)
    or (
      partner_id is not null
      and public.rs_is_partner_admin(partner_id)
    )
  )
);

drop policy if exists shop_orders_admin_update on public.shop_orders;
create policy shop_orders_admin_update
on public.shop_orders
for update
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and (
    public.is_club_admin(club_id)
    or (
      partner_id is not null
      and public.rs_is_partner_admin(partner_id)
    )
  )
)
with check (
  club_id::text = public.requesting_club_id()
  and (
    public.is_club_admin(club_id)
    or (
      partner_id is not null
      and public.rs_is_partner_admin(partner_id)
    )
  )
);

drop policy if exists shop_orders_admin_delete on public.shop_orders;
create policy shop_orders_admin_delete
on public.shop_orders
for delete
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and (
    public.is_club_admin(club_id)
    or (
      partner_id is not null
      and public.rs_is_partner_admin(partner_id)
    )
  )
);

-- Supporters cancel through the optimistic-concurrency RPC, not unrestricted
-- direct UPDATE. Its SECURITY DEFINER boundary must enforce the same club scope
-- as the table policies before it bypasses RLS.
create or replace function public.cancel_shop_order_if_unchanged(
  p_order_id uuid,
  p_expected_updated_at timestamp with time zone
)
returns public.shop_orders
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor_id uuid := auth.uid();
  v_actor_club_id text := public.requesting_club_id();
  v_order public.shop_orders;
begin
  if v_actor_id is null then
    raise exception 'An authenticated supporter is required.';
  end if;

  if v_actor_club_id is null then
    raise exception 'A trusted club scope is required.';
  end if;

  if p_order_id is null or p_expected_updated_at is null then
    raise exception 'Order id and loaded version are required.';
  end if;

  update public.shop_orders
     set status = 'cancelled'
   where id = p_order_id
     and user_id = v_actor_id
     and club_id::text = v_actor_club_id
     and status = 'pending'
     and updated_at = p_expected_updated_at
  returning * into v_order;

  if found then
    return v_order;
  end if;

  select *
    into v_order
    from public.shop_orders
   where id = p_order_id
     and user_id = v_actor_id
     and club_id::text = v_actor_club_id;

  if not found then
    raise exception 'Order was not found in the active supporter account.';
  end if;

  if v_order.status <> 'pending' then
    raise exception 'Order can no longer be cancelled. Refresh order history.';
  end if;

  raise exception
    'Order changed after it was loaded. Refresh order history and review before retrying.';
end;
$$;

-- The order items JSON is attacker-controlled at the direct Data API boundary.
-- Keep the trigger privileged, but bind every inventory mutation to the order
-- club and reject invalid quantities, inactive products, and overselling.
create or replace function public.rs_decrement_stock_on_order()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item jsonb;
  v_product_id uuid;
  v_quantity integer;
  v_updated_product_id uuid;
begin
  if new.items is null or pg_catalog.jsonb_array_length(new.items) = 0 then
    return new;
  end if;

  for v_item in
    select value
    from pg_catalog.jsonb_array_elements(new.items)
  loop
    begin
      v_product_id := coalesce(
        nullif(v_item ->> 'product_id', ''),
        nullif(v_item -> 'product' ->> 'id', '')
      )::uuid;
      v_quantity := coalesce((v_item ->> 'quantity')::integer, 1);
    exception
      when invalid_text_representation then
        raise exception 'Order item product and quantity must be valid.';
    end;

    if v_product_id is null or v_quantity <= 0 then
      raise exception 'Order item product and quantity must be valid.';
    end if;

    v_updated_product_id := null;
    update public.shop_products
       set stock = stock - v_quantity
     where id = v_product_id
       and club_id is not distinct from new.club_id
       and is_active = true
       and stock >= v_quantity
    returning id into v_updated_product_id;

    if v_updated_product_id is null then
      raise exception
        'Order item is unavailable in the active club catalog or has insufficient stock.';
    end if;
  end loop;

  return new;
end;
$$;

-- Public catalog access remains intentional but is limited to active rows.
-- Authenticated catalog access is club-scoped; inactive rows and all writes are
-- visible only through an explicitly scoped administrator predicate.
drop policy if exists products_public_read on public.shop_products;
drop policy if exists public_read_active_products on public.shop_products;
drop policy if exists rs_shop_products_select_authenticated on public.shop_products;
drop policy if exists rs_shop_products_insert_admin on public.shop_products;
drop policy if exists rs_shop_products_update_admin on public.shop_products;
drop policy if exists rs_shop_products_delete_admin on public.shop_products;
drop policy if exists shop_products_select_active on public.shop_products;
drop policy if exists shop_products_admin_all on public.shop_products;

create policy shop_products_select_active_anon
on public.shop_products
for select
to anon
using (is_active = true);

create policy shop_products_select_active_authenticated
on public.shop_products
for select
to authenticated
using (
  is_active = true
  and club_id::text = public.requesting_club_id()
);

create policy shop_products_admin_all
on public.shop_products
for all
to authenticated
using (
  club_id::text = public.requesting_club_id()
  and (
    public.is_club_admin(club_id)
    or (
      partner_id is not null
      and public.rs_is_partner_admin(partner_id)
    )
  )
)
with check (
  club_id::text = public.requesting_club_id()
  and (
    public.is_club_admin(club_id)
    or (
      partner_id is not null
      and public.rs_is_partner_admin(partner_id)
    )
  )
);

commit;

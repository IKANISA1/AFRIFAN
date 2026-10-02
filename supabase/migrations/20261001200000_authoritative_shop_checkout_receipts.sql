begin;

-- Historical/service orders remain unchanged. Only the new explicit supporter
-- boundary captures a receipt; never infer a historical receiver from today's route.
alter table public.shop_orders add column payment_receipt jsonb;

create function public.require_shop_checkout_actor(p_expected_club_id bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); club bigint:=nullif(public.requesting_club_id(),'')::bigint;
begin
 if actor is null or club is null or club is distinct from p_expected_club_id
   or not exists(select 1 from auth.users u where u.id=actor and not coalesce(u.is_anonymous,false)
     and (u.phone_confirmed_at is not null or u.email_confirmed_at is not null))
   or not exists(select 1 from public.profiles p where p.id=actor and p.club_id=club) then
   raise exception 'SHOP_AUTH_REQUIRED';
 end if;
 return club;
end $$;
revoke all on function public.require_shop_checkout_actor(bigint) from public,anon,authenticated,service_role;

create function public.shop_checkout_receipt_response(p_order public.shop_orders)
returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('order',to_jsonb(p_order),'receipt',p_order.payment_receipt,
   'can_pay',p_order.payment_receipt is not null and p_order.status='pending'
     and p_order.inventory_reserved and p_order.reservation_expires_at>clock_timestamp()
     and exists(select 1 from public.fan_memberships m where m.user_id=p_order.user_id and m.club_id=p_order.club_id
       and m.payment_status='verified' and m.status='active' and m.expires_at>clock_timestamp())
     and exists(select 1 from public.african_football_clubs c
       join public.partner_payment_routes r on r.club_id=c.id
       join public.payment_receiver_accounts a on a.id=(p_order.payment_receipt->>'receiver_id')::uuid
       where c.id=p_order.club_id and c.is_active
         and c.currency_code=p_order.payment_receipt->>'currency'
         and upper(c.country_iso_code)=p_order.payment_receipt->>'country'
         and r.id=(p_order.payment_receipt->>'route_id')::uuid and r.status='active'
         and r.partner_id=p_order.partner_id and a.partner_id=r.partner_id and a.is_active
         and a.purpose in ('club_shop','rayon_shop')
         and r.recipient_code=p_order.payment_receipt->>'recipient_code'
         and a.payee_number_or_code=r.recipient_code
         and upper(r.country)=p_order.payment_receipt->>'country'
         and (case lower(btrim(r.provider)) when 'mtn' then 'mtn_rwanda'
           when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(r.provider)) end)=p_order.payment_receipt->>'provider'));
$$;
revoke all on function public.shop_checkout_receipt_response(public.shop_orders) from public,anon,authenticated,service_role;

create function public.prepare_shop_checkout_for_club(p_items jsonb,p_delivery_address text,
 p_payment_reference text,p_expected_club_id bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); club bigint; original public.shop_orders; created public.shop_orders;
 c public.african_football_clubs; r public.partner_payment_routes; a public.payment_receiver_accounts;
 provider text; instruction text; receipt jsonb;
begin
 club:=public.require_shop_checkout_actor(p_expected_club_id);
 if p_payment_reference is null or p_payment_reference !~ '^order-[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
   raise exception 'SHOP_OPERATION_INVALID'; end if;
 -- Same lock as the legacy creator. No receiver is locked before an existing
 -- order/pending-transaction row, preserving commerce's established lock order.
 perform pg_advisory_xact_lock(hashtextextended(actor::text||':'||club::text||':'||p_payment_reference,0));
 select * into original from public.shop_orders where user_id=actor and club_id=club
   and momo_reference=p_payment_reference order by created_at,id limit 1;
 if original.id is not null then
   if original.payment_receipt is null then raise exception 'SHOP_RECEIPT_UNAVAILABLE'; end if;
   return public.shop_checkout_receipt_response(original);
 end if;
 -- Newly placing an order requires the current verified paid-member capability.
 -- Recovery remains readable when membership later expires.
 if not exists(select 1 from public.fan_memberships m where m.user_id=actor and m.club_id=club
   and m.payment_status='verified' and m.status='active' and m.expires_at>clock_timestamp()) then
   raise exception 'SHOP_MEMBERSHIP_REQUIRED'; end if;
 select * into created from public.create_shop_order(p_items,p_delivery_address,p_payment_reference);
 -- This order is still invisible outside this transaction. Taking route locks
 -- here cannot wait behind another transaction holding this new order.
 select * into c from public.african_football_clubs where id=club and is_active for share;
 if c.id is null or c.currency_code !~ '^[A-Z]{3}$' or c.country_iso_code !~ '^[A-Z]{2}$'
   or exists(select 1 from jsonb_array_elements(created.items) item
     join public.shop_products p on p.id=(item->>'product_id')::uuid
     where p.currency is distinct from c.currency_code) then raise exception 'SHOP_CURRENCY_INVALID'; end if;
 select route.* into strict r from public.partner_payment_routes route
   join public.payment_receiver_accounts receiver on receiver.partner_id=route.partner_id
     and receiver.payee_number_or_code=route.recipient_code and receiver.is_active
     and receiver.purpose in ('club_shop','rayon_shop')
   where route.club_id=club and route.partner_id=created.partner_id and route.status='active'
     and upper(route.country)=upper(c.country_iso_code) for share of route,receiver;
 select * into strict a from public.payment_receiver_accounts where partner_id=r.partner_id
   and payee_number_or_code=r.recipient_code and is_active and purpose in ('club_shop','rayon_shop') for share;
 provider:=case lower(btrim(r.provider)) when 'mtn' then 'mtn_rwanda'
   when 'mtn rwanda' then 'mtn_rwanda' else nullif(lower(btrim(r.provider)),'') end;
 instruction:=replace(replace(replace(replace(coalesce(c.momo_ussd_template,''),
   '{amount}',created.total::text),'{momo}',r.recipient_code),'{recipient}',r.recipient_code),'{code}',r.recipient_code);
 if created.total<=0 or provider is null or r.recipient_code !~ '^[0-9]{1,40}$'
   or instruction !~ '^[*][0-9*]+#$' then raise exception 'SHOP_ROUTE_UNAVAILABLE'; end if;
 receipt:=jsonb_build_object('version',1,'order_id',created.id,'user_id',actor,'club_id',club,
   'payment_reference',p_payment_reference,'total',created.total,'currency',c.currency_code,
   'recipient_code',r.recipient_code,'country',upper(r.country),'provider',provider,
   'receiver_id',a.id,'route_id',r.id,'ussd_code',instruction,'items',created.items,
   'delivery_address',created.delivery_address,'expires_at',created.reservation_expires_at);
 insert into public.pending_transactions(user_id,reference,recipient_momo,amount,provider,status,raw_payload)
   values(actor,p_payment_reference,r.recipient_code,created.total,provider,'pending',
     jsonb_build_object('kind','shop','club_id',club,'order_id',created.id,'receipt',receipt));
 update public.shop_orders set payment_receipt=receipt where id=created.id returning * into created;
 return public.shop_checkout_receipt_response(created);
end $$;
revoke all on function public.prepare_shop_checkout_for_club(jsonb,text,text,bigint) from public,anon,service_role;
grant execute on function public.prepare_shop_checkout_for_club(jsonb,text,text,bigint) to authenticated;

create function public.recover_shop_checkout_for_club(p_payment_reference text,p_expected_club_id bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare club bigint; original public.shop_orders;
begin
 club:=public.require_shop_checkout_actor(p_expected_club_id);
 select * into original from public.shop_orders where user_id=auth.uid() and club_id=club
   and momo_reference=p_payment_reference order by created_at,id limit 1;
 if original.id is null then return null; end if;
 return public.shop_checkout_receipt_response(original);
end $$;
revoke all on function public.recover_shop_checkout_for_club(text,bigint) from public,anon,service_role;
grant execute on function public.recover_shop_checkout_for_club(text,bigint) to authenticated;

create function public.validate_shop_checkout_for_club(p_order_id uuid,p_expected_club_id bigint,p_receipt jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare club bigint; original public.shop_orders;
begin
 club:=public.require_shop_checkout_actor(p_expected_club_id);
 -- Read-only order snapshot; never lock an existing order before a receiver.
 select * into original from public.shop_orders where id=p_order_id and user_id=auth.uid() and club_id=club;
 if original.id is null then raise exception 'SHOP_ORDER_UNAVAILABLE'; end if;
 if original.payment_receipt is null or original.payment_receipt is distinct from p_receipt then
   raise exception 'SHOP_REVIEW_CHANGED'; end if;
 perform c.id from public.african_football_clubs c where c.id=club for share;
 perform r.id from public.partner_payment_routes r where r.id=(p_receipt->>'route_id')::uuid for share;
 perform a.id from public.payment_receiver_accounts a where a.id=(p_receipt->>'receiver_id')::uuid for share;
 return public.shop_checkout_receipt_response(original);
end $$;
revoke all on function public.validate_shop_checkout_for_club(uuid,bigint,jsonb) from public,anon,service_role;
grant execute on function public.validate_shop_checkout_for_club(uuid,bigint,jsonb) to authenticated;

create function public.guard_shop_checkout_receipt() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.payment_receipt is not null then
   if new.payment_receipt is distinct from old.payment_receipt or new.user_id is distinct from old.user_id
     or new.club_id is distinct from old.club_id or new.partner_id is distinct from old.partner_id
     or new.items is distinct from old.items or new.total is distinct from old.total
     or new.subtotal is distinct from old.subtotal or new.discount_amount is distinct from old.discount_amount
     or new.discount is distinct from old.discount or new.delivery_fee is distinct from old.delivery_fee
     or new.delivery_address is distinct from old.delivery_address or new.momo_reference is distinct from old.momo_reference
     or new.reservation_expires_at is distinct from old.reservation_expires_at then
     raise exception 'SHOP_RECEIPT_IMMUTABLE'; end if;
   if old.status='pending' and new.status in ('paid','confirmed','packed','shipped','fulfilled','delivered')
     and not exists(select 1 from public.momo_ledger_entries l
       join public.momo_reconciliations m on m.parsed_sms_id=l.parsed_sms_id
       where l.user_id=old.user_id and l.club_id=old.club_id and l.target_table='shop_orders' and l.target_record_id=old.id
         and l.amount=old.total and l.currency=old.payment_receipt->>'currency' and l.ledger_status='posted'
         and l.entry_type='debit' and m.match_status='matched' and m.target_table=l.target_table and m.target_record_id=old.id
         and l.metadata->'commerce_request'->>'p_reference'=old.momo_reference
         and l.metadata->'commerce_request'->>'p_payee'=old.payment_receipt->>'recipient_code'
         and (case lower(btrim(l.metadata->'commerce_request'->>'p_provider')) when 'mtn' then 'mtn_rwanda'
           when 'mtn rwanda' then 'mtn_rwanda' else lower(btrim(l.metadata->'commerce_request'->>'p_provider')) end)=old.payment_receipt->>'provider'
         and l.metadata->'commerce_request'->>'p_country'=old.payment_receipt->>'country') then
     raise exception 'SHOP_RECEIPT_EVIDENCE_MISMATCH'; end if;
 end if;
 return new;
end $$;
revoke all on function public.guard_shop_checkout_receipt() from public,anon,authenticated,service_role;
create trigger shop_checkout_receipt_guard before update on public.shop_orders
 for each row execute function public.guard_shop_checkout_receipt();

commit;

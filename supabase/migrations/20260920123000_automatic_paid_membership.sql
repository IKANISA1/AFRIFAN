-- All offered memberships are paid. A supporter selects a tier and pays via
-- MoMo; a posted, matched payment activates it without an application/reviewer.
begin;

create table public.membership_payment_orders (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id),
 club_id bigint not null references public.african_football_clubs(id),
 partner_id uuid not null references public.partners(id),
 package_id uuid not null references public.membership_packages(id),
 tier text not null,
 amount integer not null check(amount>0),
 currency text not null,
 receiving_account_id uuid not null references public.payment_receiver_accounts(id),
 payment_intent_id uuid unique references public.payment_intents(id),
 activated_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.membership_payment_orders enable row level security;
revoke all on public.membership_payment_orders from public,anon,authenticated;
grant select on public.membership_payment_orders to authenticated;
grant select,insert,update on public.membership_payment_orders to service_role;
create policy membership_payment_orders_read_own on public.membership_payment_orders
 for select to authenticated using (user_id=auth.uid() and club_id=nullif(public.requesting_club_id(),'')::bigint);

create or replace function public.prepare_membership_payment(p_tier text) returns jsonb
language plpgsql security definer set search_path='' as $$
<<prepare>>
declare
 actor uuid:=auth.uid(); club bigint:=nullif(public.requesting_club_id(),'')::bigint;
 package public.membership_packages; route public.partner_payment_routes;
 receiver uuid; amount numeric; currency text;
 payment_order public.membership_payment_orders; intent public.payment_intents;
begin
 if actor is null or club is null then raise exception 'An authenticated club account is required'; end if;
 select * into package from public.membership_packages where club_id=club
   and is_active and tier=lower(btrim(p_tier)) order by sort_order,id limit 1 for share;
 if package.id is null then raise exception 'Membership tier is not configured'; end if;
 amount:=coalesce(nullif(package.annual_price,0),package.price,0);
 if amount<=0 or amount<>trunc(amount) or amount>2147483647 then raise exception 'Membership price must be a positive whole amount'; end if;
 currency:=public.resolve_club_currency_code(club);
 select r.* into route from public.partner_payment_routes r
   join public.payment_receiver_accounts a on a.partner_id=r.partner_id
    and a.payee_number_or_code=r.recipient_code and a.is_active
   where r.club_id=club and r.partner_id=package.partner_id and r.status='active'
   order by r.id limit 1 for share of r,a;
 -- Resolve both records explicitly: the response and intent use one receiver.
 if route.id is null then raise exception 'Membership payment route is not configured'; end if;
 select id into strict receiver from public.payment_receiver_accounts
   where partner_id=route.partner_id and payee_number_or_code=route.recipient_code and is_active;
 perform pg_advisory_xact_lock(hashtextextended('membership-payment:'||actor::text||':'||club::text,0));
 select o.* into payment_order from public.membership_payment_orders o
   join public.payment_intents i on i.id=o.payment_intent_id
   where o.user_id=actor and o.club_id=club and o.package_id=package.id
     and o.amount=prepare.amount and o.currency=prepare.currency and o.receiving_account_id=receiver
     and i.status='pending' and i.expires_at>clock_timestamp()
   order by o.created_at desc limit 1;
 if payment_order.id is null then
   update public.payment_intents i set status='cancelled',updated_at=now()
   from public.membership_payment_orders o where o.payment_intent_id=i.id
     and o.user_id=actor and o.club_id=club and i.status='pending';
   insert into public.membership_payment_orders(user_id,club_id,partner_id,package_id,tier,amount,currency,receiving_account_id)
     values(actor,club,package.partner_id,package.id,package.tier,amount,currency,receiver) returning * into payment_order;
   insert into public.payment_intents(user_id,receiving_account_id,target_table,target_record_id,expected_amount,currency,expires_at)
     values(actor,receiver,'membership_payment_orders',payment_order.id,amount,currency,clock_timestamp()+interval '24 hours') returning * into intent;
   update public.membership_payment_orders set payment_intent_id=intent.id where id=payment_order.id;
 end if;
 return jsonb_build_object('id',payment_order.id,'amount',payment_order.amount,'currency',currency,
   'tier',package.tier,'recipient_code',route.recipient_code,'country',route.country);
end $$;
revoke all on function public.prepare_membership_payment(text) from public,anon;
grant execute on function public.prepare_membership_payment(text) to authenticated;

-- Deferred until the allocation transaction has posted both ledger and matching
-- evidence. Retries cannot activate twice or extend a membership a second time.
create or replace function public.activate_matched_membership_payment() returns trigger
language plpgsql security definer set search_path='' as $$
declare
 payment_order public.membership_payment_orders; intent public.payment_intents;
 evidence public.momo_ledger_entries; membership public.fan_memberships;
begin
 select * into intent from public.payment_intents where id=new.id for update;
 if intent.target_table<>'membership_payment_orders' or intent.status<>'fulfilled' then return null; end if;
 select * into payment_order from public.membership_payment_orders
   where id=intent.target_record_id and payment_intent_id=intent.id for update;
 if payment_order.id is null or payment_order.user_id<>intent.user_id
   or payment_order.amount<>intent.expected_amount or payment_order.currency<>intent.currency
   or payment_order.receiving_account_id<>intent.receiving_account_id then raise exception 'Membership payment binding mismatch'; end if;
 if payment_order.activated_at is not null then return null; end if;
 select l.* into evidence from public.momo_ledger_entries l
 join public.momo_reconciliations r on r.parsed_sms_id=l.parsed_sms_id
 join public.momo_sms_parsed p on p.id=l.parsed_sms_id
 join public.payment_receiver_accounts a on a.id=payment_order.receiving_account_id
 where l.metadata->>'intent_id'=intent.id::text and r.metadata->>'intent_id'=intent.id::text
   and l.ledger_status='posted' and l.entry_type='debit' and r.match_status='matched'
   and l.user_id=payment_order.user_id and p.user_id=l.user_id and r.user_id=l.user_id
   and l.club_id=payment_order.club_id and p.club_id=l.club_id and r.club_id=l.club_id
   and l.target_table='membership_payment_orders' and l.target_record_id=payment_order.id
   and r.target_table=l.target_table and r.target_record_id=l.target_record_id
   and l.amount=payment_order.amount and p.amount=l.amount
   and l.currency=payment_order.currency and p.currency=l.currency
   and p.tx_direction='debit' and p.momo_tx_id=l.external_reference
   and p.payee_number_or_code=a.payee_number_or_code and a.partner_id=payment_order.partner_id
 limit 1;
 if evidence.id is null then raise exception 'Matched membership payment evidence is required'; end if;
 perform pg_advisory_xact_lock(hashtextextended('membership-payment:'||payment_order.user_id::text||':'||payment_order.club_id::text,0));
 insert into public.fan_memberships(user_id,partner_id,club_id,tier,points,chapter,membership_number,payment_status,status,renewed_at,expires_at)
 values(payment_order.user_id,payment_order.partner_id,payment_order.club_id,payment_order.tier,0,'Main',
   'MEM-'||replace(gen_random_uuid()::text,'-',''),'verified','active',now(),now()+interval '1 year')
 on conflict(user_id,club_id) do update set tier=excluded.tier,payment_status='verified',status='active',
   renewed_at=now(),expires_at=case when public.fan_memberships.tier=excluded.tier then greatest(now(),public.fan_memberships.expires_at)+interval '1 year' else now()+interval '1 year' end,
   updated_at=now() returning * into membership;
 update public.membership_payment_orders set activated_at=now() where id=payment_order.id;
 update public.momo_ledger_entries set ledger_scope='subscription',metadata=metadata||jsonb_build_object('business_target_fulfilled',true,'membership_id',membership.id) where id=evidence.id;
 update public.momo_reconciliations set notes='Membership activated automatically after matched payment.',metadata=metadata||jsonb_build_object('business_target_fulfilled',true,'membership_id',membership.id) where parsed_sms_id=evidence.parsed_sms_id;
 return null;
end $$;
revoke all on function public.activate_matched_membership_payment() from public,anon,authenticated,service_role;
create constraint trigger activate_matched_membership_payment
 after insert or update on public.payment_intents deferrable initially deferred
 for each row when(new.target_table='membership_payment_orders' and new.status='fulfilled')
 execute function public.activate_matched_membership_payment();

-- Respect every published paid tier; points do not select a customer's tier.
do $$ declare definition text; begin
 definition:=pg_get_functiondef('public.rs_sync_membership_fields()'::regprocedure);
 execute replace(definition, $old$IN ('fan', 'bronze', 'gold', 'platinum')$old$, $new$IN ('fan', 'bronze', 'silver', 'gold', 'platinum', 'imena', 'inyamibwa', 'ingenzi-imanzi')$new$);
end $$;
update public.membership_packages set is_active=false where coalesce(nullif(annual_price,0),price,0)<=0;
alter table public.membership_packages add constraint active_membership_price_positive
 check (not is_active or (coalesce(nullif(annual_price,0),price,0)>0
   and coalesce(nullif(annual_price,0),price,0)=trunc(coalesce(nullif(annual_price,0),price,0))));
revoke all on function public.activate_free_fan_membership() from public,anon,authenticated,service_role;
revoke all on function public.submit_membership_application(text,text,text) from public,anon,authenticated,service_role;
revoke all on function public.activate_free_fan_membership_for_club(bigint) from public,anon,authenticated,service_role;
-- Publish every configured paid tier; there is no free catalog or benefit
-- classification gate in the supporter payment journey.
drop policy if exists membership_packages_active_catalog_anon on public.membership_packages;
drop policy if exists membership_packages_active_catalog_authenticated on public.membership_packages;
create policy membership_packages_active_catalog_anon on public.membership_packages
 for select to anon using (is_active and coalesce(nullif(annual_price,0),price,0)>0);
create policy membership_packages_active_catalog_authenticated on public.membership_packages
 for select to authenticated using (is_active and coalesce(nullif(annual_price,0),price,0)>0
   and club_id::text=public.requesting_club_id());
notify pgrst,'reload schema';
commit;

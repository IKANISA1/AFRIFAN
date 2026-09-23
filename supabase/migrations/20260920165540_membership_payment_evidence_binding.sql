begin;

-- Bind the displayed checkout route alongside the existing amount/currency
-- snapshot. Do not infer a historical provider from today's editable routing.
-- Unactivated older orders without these fields cannot grant membership; a new
-- checkout prepares an authoritative order instead of reusing an unbound one.
alter table public.membership_payment_orders
  add column payment_provider text,
  add column payment_country text,
  add column payment_recipient text;
comment on column public.membership_payment_orders.payment_provider is
  'Canonical payment provider captured from the server-controlled checkout route.';

create or replace function public.prepare_membership_payment(p_tier text) returns jsonb
language plpgsql security definer set search_path='' as $$
<<prepare>>
declare
 actor uuid:=auth.uid(); club bigint:=nullif(public.requesting_club_id(),'')::bigint;
 package public.membership_packages; route public.partner_payment_routes;
 receiver uuid; amount numeric; currency text; provider text;
 club_record public.african_football_clubs; ussd text;
 payment_order public.membership_payment_orders; intent public.payment_intents;
begin
 if actor is null or club is null then raise exception 'An authenticated club account is required'; end if;
 -- Serialize checkouts before taking any rows. Allocation takes intents before
 -- receivers, so checkout must acquire its pending intents in the same order.
 perform pg_advisory_xact_lock(hashtextextended('membership-payment:'||actor::text||':'||club::text,0));
 perform i.id from public.payment_intents i
   join public.membership_payment_orders o on o.payment_intent_id=i.id
   where o.user_id=actor and o.club_id=club and i.status='pending'
   order by i.id for update of i;
 select * into club_record from public.african_football_clubs where id=club and is_active for share;
 if club_record.id is null then raise exception 'Club is not available'; end if;
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
 if route.id is null or upper(route.country) is distinct from upper(club_record.country_iso_code) then
   raise exception 'Membership payment route is not configured for this club country'; end if;
 provider:=case lower(btrim(route.provider)) when 'mtn' then 'mtn_rwanda'
   when 'mtn rwanda' then 'mtn_rwanda' else nullif(lower(btrim(route.provider)),'') end;
 if provider is null then raise exception 'Membership payment provider is not configured'; end if;
 ussd:=replace(replace(replace(replace(coalesce(club_record.momo_ussd_template,''),
   '{amount}',amount::integer::text),'{momo}',route.recipient_code),'{recipient}',route.recipient_code),'{code}',route.recipient_code);
 if ussd !~ '^[*][0-9*]+#$' then raise exception 'Membership dialer route is not configured'; end if;
 select id into strict receiver from public.payment_receiver_accounts
   where partner_id=route.partner_id and payee_number_or_code=route.recipient_code and is_active;
 select o.* into payment_order from public.membership_payment_orders o
   join public.payment_intents i on i.id=o.payment_intent_id
   where o.user_id=actor and o.club_id=club and o.package_id=package.id
     and o.amount=prepare.amount and o.currency=prepare.currency and o.receiving_account_id=receiver
     and o.payment_provider=prepare.provider and o.payment_country=upper(route.country)
     and o.payment_recipient=route.recipient_code
     and i.status='pending' and i.expires_at>clock_timestamp()
   order by o.created_at desc limit 1;
 if payment_order.id is null then
   update public.payment_intents i set status='cancelled',updated_at=now()
   from public.membership_payment_orders o where o.payment_intent_id=i.id
     and o.user_id=actor and o.club_id=club and i.status='pending';
   insert into public.membership_payment_orders(user_id,club_id,partner_id,package_id,tier,amount,currency,receiving_account_id,payment_provider,payment_country,payment_recipient)
     values(actor,club,package.partner_id,package.id,package.tier,amount,currency,receiver,provider,upper(route.country),route.recipient_code) returning * into payment_order;
   insert into public.payment_intents(user_id,receiving_account_id,target_table,target_record_id,expected_amount,currency,expires_at)
     values(actor,receiver,'membership_payment_orders',payment_order.id,amount,currency,clock_timestamp()+interval '24 hours') returning * into intent;
   update public.membership_payment_orders set payment_intent_id=intent.id where id=payment_order.id;
 end if;
 return jsonb_build_object('id',payment_order.id,'amount',payment_order.amount,'currency',currency,
   'club_id',club,'ussd_code',ussd,'tier',package.tier,'recipient_code',route.recipient_code,'country',route.country);
end $$;

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
 if payment_order.payment_provider is null or payment_order.payment_country is null
   or payment_order.payment_recipient is null then
   raise exception 'Membership payment route evidence is required'; end if;
 select l.* into evidence from public.momo_ledger_entries l
 join public.momo_reconciliations r on r.parsed_sms_id=l.parsed_sms_id
 join public.momo_sms_parsed p on p.id=l.parsed_sms_id
 join public.momo_sms_raw raw on raw.id=p.raw_sms_id
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
   and a.is_active and p.payee_number_or_code=payment_order.payment_recipient
   and p.parse_status in ('parsed','needs_review') and not p.is_mock and not raw.is_mock
   and raw.user_id=payment_order.user_id and raw.club_id=payment_order.club_id
   and upper(p.country_code)=payment_order.payment_country
   and upper(raw.country_code)=payment_order.payment_country
   and (case lower(btrim(raw.provider)) when 'mtn' then 'mtn_rwanda'
     when 'mtn rwanda' then 'mtn_rwanda' else nullif(lower(btrim(raw.provider)),'') end)=payment_order.payment_provider
 limit 1;
 if evidence.id is null then raise exception 'Matched membership payment evidence is required'; end if;
 -- The intent/order locks make one payment idempotent. The membership upsert
 -- serializes different paid orders on (user_id,club_id); it must not wait on
 -- checkout's advisory lock while checkout waits on this transaction's intent.
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

notify pgrst,'reload schema';
commit;

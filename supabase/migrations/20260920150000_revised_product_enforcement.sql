-- Enforce the accepted supporter contract at the API and configuration boundary.
begin;
-- Wallet credits, debits and Predict settlement must never overwrite the tier
-- selected by a paid membership order. Preserve their balance/ledger logic.
do $$ declare routine record; definition text; begin
 for routine in select oid from pg_proc where pronamespace='public'::regnamespace and prokind='f'
  and prosrc ~ 'tier\s*=\s*public[.]resolve_fan_tier\([^()]*\),'
 loop
  definition:=pg_get_functiondef(routine.oid);
  execute regexp_replace(definition,'tier\s*=\s*public[.]resolve_fan_tier\([^()]*\),','','g');
 end loop;
end $$;

-- A shared admin must preserve the selected club's country, including Burundi.
alter table public.partner_payment_routes drop constraint partner_payment_routes_country_supported_check;
alter table public.partner_payment_routes add constraint partner_payment_routes_country_supported_check
 check (upper(country) in ('RW','BI','CD','ZM'));
alter table public.partners drop constraint partners_country_supported_check;
alter table public.partners add constraint partners_country_supported_check
 check (upper(country) in ('RW','BI','CD','ZM'));
alter table public.partner_services drop constraint partner_services_country_supported_check;
alter table public.partner_services add constraint partner_services_country_supported_check
 check (country is null or upper(country) in ('RW','BI','CD','ZM'));
alter table public.quick_actions drop constraint quick_actions_country_supported_check;
alter table public.quick_actions add constraint quick_actions_country_supported_check
 check (country is null or upper(country) in ('RW','BI','CD','ZM'));

create or replace function public.enforce_partner_payment_route_fields() returns trigger
language plpgsql set search_path='' as $$
declare club_country text;
begin
 select upper(country_iso_code) into club_country from public.african_football_clubs where id=new.club_id;
 if club_country is null then raise exception 'Payment route requires a configured club country'; end if;
 new.country:=upper(btrim(new.country));
 if new.country is distinct from club_country then raise exception 'Payment route country must match its club'; end if;
 new.provider:=public.normalize_partner_payment_provider(new.provider);
 new.status:=lower(btrim(coalesce(new.status,'draft')));
 new.reconciliation_label:=btrim(regexp_replace(lower(btrim(coalesce(new.reconciliation_label,''))),'[^a-z0-9]+','_','g'),'_');
 new.recipient_code:=public.normalize_momo_code_for_country(new.country,new.recipient_code);
 if new.provider='' then raise exception 'Payment provider is required'; end if;
 if new.reconciliation_label='' then raise exception 'Reconciliation label is required'; end if;
 if new.status not in ('draft','active','inactive') then raise exception 'Invalid payment route status'; end if;
 if new.status='active' and new.recipient_code is null then raise exception 'Active payment routes require a merchant code'; end if;
 return new;
end $$;

create or replace function public.prepare_membership_payment(p_tier text) returns jsonb
language plpgsql security definer set search_path='' as $$
<<prepare>>
declare
 actor uuid:=auth.uid(); club bigint:=nullif(public.requesting_club_id(),'')::bigint;
 package public.membership_packages; route public.partner_payment_routes;
 receiver uuid; amount numeric; currency text;
 club_record public.african_football_clubs; ussd text;
 payment_order public.membership_payment_orders; intent public.payment_intents;
begin
 if actor is null or club is null then raise exception 'An authenticated club account is required'; end if;
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
 ussd:=replace(replace(replace(replace(coalesce(club_record.momo_ussd_template,''),
   '{amount}',amount::integer::text),'{momo}',route.recipient_code),'{recipient}',route.recipient_code),'{code}',route.recipient_code);
 if ussd !~ '^[*][0-9*]+#$' then raise exception 'Membership dialer route is not configured'; end if;
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
   'club_id',club,'ussd_code',ussd,'tier',package.tier,'recipient_code',route.recipient_code,'country',route.country);
end $$;

-- The website binds the visible club to trusted account scope before preparing
-- a payment. The caller cannot select a different tenant with this parameter.
create function public.prepare_membership_payment_for_club(p_tier text,p_expected_club_id bigint) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
 if p_expected_club_id is null or p_expected_club_id is distinct from nullif(public.requesting_club_id(),'')::bigint then
  raise exception 'MEMBER_CLUB_MISMATCH' using errcode='42501';
 end if;
 return public.prepare_membership_payment(p_tier);
end $$;
revoke all on function public.prepare_membership_payment_for_club(text,bigint) from public,anon,service_role;
grant execute on function public.prepare_membership_payment_for_club(text,bigint) to authenticated;

-- Historical application records are auditable, never an active approval path.
do $$ declare fn record; begin
 for fn in select oid::regprocedure as signature from pg_proc
 where pronamespace='public'::regnamespace and prokind='f'
 and (proname like '%review_membership_application%' or proname in ('activate_free_fan_membership','activate_free_fan_membership_for_club','submit_membership_application'))
 loop execute format('revoke all on function %s from public,anon,authenticated,service_role',fn.signature); end loop;
end $$;
revoke all on public.membership_applications from anon,authenticated;
revoke insert,update,delete on public.membership_applications from service_role;
-- Table-level revocation does not remove earlier column-level grants.
do $$ declare col record; begin
 for col in select attname from pg_attribute where attrelid='public.membership_applications'::regclass and attnum>0 and not attisdropped loop
  execute format('revoke select (%I), insert (%I), update (%I), references (%I) on public.membership_applications from anon,authenticated',col.attname,col.attname,col.attname,col.attname);
  execute format('revoke insert (%I), update (%I) on public.membership_applications from service_role',col.attname,col.attname);
 end loop;
end $$;

-- Stored runtime configuration cannot restore removed products through CMS.
alter table public.platform_features add constraint supported_prediction_feature
 check (lower(feature_key) not in ('fanzone','fan_zone','challenge'));
alter table public.platform_route_registry add constraint supported_prediction_route
 check (lower(feature_key) not in ('fanzone','fan_zone','challenge') and lower(path_pattern) !~ '^/(fanzone|challenge)(/|[?]|$)');
alter table public.quick_actions add constraint supported_prediction_quick_action
 check (lower(action_key) not in ('fan_zone','fanzone','challenge') and lower(route) !~ '^/(fanzone|challenge)(/|[?]|$)');
alter table public.site_navigation_items add constraint supported_prediction_navigation
 check (lower(feature_key) not in ('fan_zone','fanzone','challenge') and lower(href) !~ '^/(fanzone|challenge)(/|[?]|$)');
alter table public.site_search_items add constraint supported_prediction_search
 check (lower(feature_key) not in ('fan_zone','fanzone','challenge') and lower(href) !~ '^/(fanzone|challenge)(/|[?]|$)');
alter table public.platform_feature_channels add constraint supported_prediction_channel
 check (lower(route_key) !~ '^/?(fanzone|challenge)(/|[?]|$)');
comment on column public.membership_packages.benefit_scope is 'Benefit classification metadata; it does not restrict supporter selection of an active paid tier.';
notify pgrst,'reload schema';
commit;

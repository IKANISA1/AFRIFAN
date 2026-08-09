-- Venue foundation contract checks.
-- Run against a migrated database with `supabase test db`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(6);

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'venues',
    'venue_staff_memberships',
    'venue_checkin_campaigns',
    'venue_checkin_codes',
    'venue_checkins',
    'venue_drink_items',
    'venue_drink_orders',
    'venue_drink_order_items',
    'venue_order_events',
    'venue_staff_audit_events',
    'venue_promotion_events',
    'venue_fet_wallets',
    'fet_ledger_reservations'
  ] loop
    if to_regclass('public.' || table_name) is null then
      raise exception 'missing public.%', table_name;
    end if;

    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = table_name
        and c.relrowsecurity
    ) then
      raise exception 'RLS is not enabled on public.%', table_name;
    end if;
  end loop;
end $$;

select pass('venue foundation tables exist with RLS enabled');

do $$
begin
  if to_regprocedure('public.venue_staff_can_access(uuid,text[])') is null then
    raise exception 'missing venue_staff_can_access RPC';
  end if;
  if to_regprocedure('public.venue_checkin_validate(bigint,text,text,numeric)') is null then
    raise exception 'missing venue_checkin_validate RPC';
  end if;
  if to_regprocedure('public.venue_order_create(bigint,uuid,uuid,jsonb,boolean,text)') is null then
    raise exception 'missing venue_order_create RPC';
  end if;
  if to_regprocedure('public.venue_order_update_status(bigint,uuid,text,text)') is null then
    raise exception 'missing venue_order_update_status RPC';
  end if;
  if to_regprocedure('public.venue_menu_upsert(uuid,uuid,text,text,integer,text,boolean,boolean,integer)') is null then
    raise exception 'missing venue_menu_upsert RPC';
  end if;
  if to_regprocedure('public.venue_promotion_launch(uuid,uuid,text)') is null then
    raise exception 'missing venue_promotion_launch RPC';
  end if;
end $$;

select pass('venue foundation RPC signatures exist');

do $$
begin
  if not exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and indexname = 'idx_venue_checkin_codes_hash'
  ) then
    raise exception 'missing hashed code lookup index';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'venue_checkin_codes'
      and column_name in ('code', 'raw_code', 'qr_code')
  ) then
    raise exception 'venue_checkin_codes must not persist raw codes';
  end if;
end $$;

select pass('venue check-in code storage keeps hashed lookup only');

do $$
declare
  trigger_source text;
begin
  select p.prosrc
    into trigger_source
    from pg_proc p
   where p.proname = 'venue_enforce_active_drink_limit'
   limit 1;

  if trigger_source !~ '>= 10' then
    raise exception 'active drink limit trigger does not enforce top-10 MVP';
  end if;
end $$;

select pass('venue drinks menu trigger enforces top-10 active MVP');

do $$
declare
  checkin_source text;
  internal_source text;
begin
  select p.prosrc
    into checkin_source
    from pg_proc p
   where p.oid =
     'public.venue_checkin_validate(bigint,text,text,numeric)'::regprocedure;

  select p.prosrc
    into internal_source
    from pg_proc p
   where p.oid =
     'public.venue_checkin_validate_unscoped_internal(bigint,text,text,numeric)'::regprocedure;

  if checkin_source !~ 'fet_require_club_context' or
     internal_source !~ 'idempotent_replay' or
     internal_source !~ 'expired_code' or
     internal_source !~ 'campaign_budget_exhausted' or
     internal_source !~ 'already_checked_in' then
    raise exception 'venue_checkin_validate does not expose required stable states';
  end if;
end $$;

select pass('venue check-in wrapper binds trusted club scope and exposes stable product states');

do $$
declare
  v_club_id bigint;
  v_user_id uuid := '00000000-0000-4000-8000-000000000001';
  v_second_user_id uuid := '00000000-0000-4000-8000-000000000002';
  v_staff_user_id uuid := '00000000-0000-4000-8000-000000000003';
  v_other_user_id uuid := '00000000-0000-4000-8000-000000000004';
  v_manager_user_id uuid := '00000000-0000-4000-8000-000000000005';
  v_venue_id uuid;
  v_other_venue_id uuid;
  v_campaign_id uuid;
  v_launch_campaign_id uuid;
  v_drink_id uuid;
  v_alcohol_drink_id uuid;
  v_checkin_id uuid;
  v_order_id uuid;
  v_result jsonb;
  i integer;
begin
  insert into public.african_football_clubs (club_name, country_name, club_slug)
  values ('Rayon Contract Club', 'Rwanda', 'rayon-contract-club')
  returning id into v_club_id;

  insert into auth.users (id, aud, role)
  values
    (v_user_id, 'authenticated', 'authenticated'),
    (v_second_user_id, 'authenticated', 'authenticated'),
    (v_staff_user_id, 'authenticated', 'authenticated'),
    (v_other_user_id, 'authenticated', 'authenticated'),
    (v_manager_user_id, 'authenticated', 'authenticated');

  insert into public.users (id, phone, full_name)
  values
    (v_user_id, '+250790100001', 'Venue Contract Supporter'),
    (v_second_user_id, '+250790100002', 'Venue Contract Second Supporter'),
    (v_staff_user_id, '+250790100003', 'Venue Contract Staff'),
    (v_other_user_id, '+250790100004', 'Venue Contract Other Supporter'),
    (v_manager_user_id, '+250790100005', 'Venue Contract Manager');

  insert into public.profiles (id, club_id)
  values
    (v_user_id, v_club_id),
    (v_second_user_id, v_club_id),
    (v_staff_user_id, v_club_id),
    (v_other_user_id, v_club_id),
    (v_manager_user_id, v_club_id);

  insert into public.venues (
    club_id,
    slug,
    display_name,
    status,
    approved_public_profile,
    public_summary
  )
  values (
    v_club_id,
    'contract-venue',
    'Contract Venue',
    'approved',
    true,
    'Contract-only venue'
  )
  returning id into v_venue_id;

  insert into public.venues (club_id, slug, display_name, status)
  values (v_club_id, 'other-contract-venue', 'Other Contract Venue', 'approved')
  returning id into v_other_venue_id;

  insert into public.venue_checkin_campaigns (
    club_id,
    venue_id,
    campaign_name,
    status,
    starts_at,
    ends_at,
    fet_award_per_checkin,
    fet_budget,
    max_checkins_per_user,
    require_location,
    min_location_accuracy_meters
  )
  values (
    v_club_id,
    v_venue_id,
    'Contract check-in',
    'approved',
    timezone('utc', now()) - interval '1 hour',
    timezone('utc', now()) + interval '1 hour',
    5,
    10,
    1,
    true,
    50
  )
  returning id into v_campaign_id;

  insert into public.venue_checkin_codes (
    club_id,
    venue_id,
    campaign_id,
    code_hash,
    code_nonce,
    expires_at
  )
  values (
    v_club_id,
    v_venue_id,
    v_campaign_id,
    'contract-code-hash',
    'contract-nonce',
    timezone('utc', now()) + interval '10 minutes'
  );

  perform set_config('request.jwt.claim.sub', v_user_id::text, true);

  v_result := public.venue_checkin_validate(v_club_id, 'contract-code-hash', 'checkin-1', 20);
  if v_result ->> 'code' <> 'ok' or
     v_result ->> 'location_verification_status' <> 'verified' or
     (v_result ->> 'fet_awarded')::integer <> 5 then
    raise exception 'check-in success contract failed: %', v_result;
  end if;
  v_checkin_id := (v_result ->> 'checkin_id')::uuid;

  v_result := public.venue_checkin_validate(v_club_id, 'contract-code-hash', 'checkin-1', 20);
  if v_result ->> 'code' <> 'idempotent_replay' then
    raise exception 'check-in idempotency contract failed: %', v_result;
  end if;

  v_result := public.venue_checkin_validate(v_club_id, 'contract-code-hash', 'checkin-2', 20);
  if v_result ->> 'code' <> 'already_checked_in' then
    raise exception 'check-in per-user limit contract failed: %', v_result;
  end if;

  update public.venue_checkin_campaigns
     set max_checkins_per_user = 20,
         awarded_fet = 10
   where id = v_campaign_id;

  perform set_config('request.jwt.claim.sub', v_second_user_id::text, true);
  v_result := public.venue_checkin_validate(v_club_id, 'contract-code-hash', 'budget-check', 20);
  if v_result ->> 'code' <> 'campaign_budget_exhausted' then
    raise exception 'check-in budget contract failed: %', v_result;
  end if;

  for i in 1..10 loop
    insert into public.venue_drink_items (
      club_id,
      venue_id,
      item_name,
      price_amount,
      is_active,
      is_alcohol,
      sort_order
    )
    values (
      v_club_id,
      v_venue_id,
      'Contract Drink ' || i,
      1000 + i,
      true,
      i = 1,
      i
    )
    returning id into v_drink_id;

    if i = 1 then
      v_alcohol_drink_id := v_drink_id;
    end if;
  end loop;

  begin
    insert into public.venue_drink_items (
      club_id,
      venue_id,
      item_name,
      price_amount,
      is_active,
      is_alcohol,
      sort_order
    )
    values (
      v_club_id,
      v_venue_id,
      'Contract Drink 11',
      1011,
      true,
      false,
      11
    );
    raise exception 'top-10 active drink contract did not reject the 11th active item';
  exception
    when others then
      if sqlerrm !~ 'at most 10 active drinks' then
        raise;
      end if;
  end;

  perform set_config('request.jwt.claim.sub', v_user_id::text, true);

  begin
    perform public.venue_order_create(
      v_club_id,
      v_venue_id,
      v_checkin_id,
      jsonb_build_array(jsonb_build_object('drink_item_id', v_alcohol_drink_id, 'quantity', 1)),
      false,
      'order-age-gate'
    );
    raise exception 'alcohol age-gate contract did not reject unconfirmed alcohol order';
  exception
    when others then
      if sqlerrm !~ 'Age gate confirmation is required' then
        raise;
      end if;
  end;

  v_result := public.venue_order_create(
    v_club_id,
    v_venue_id,
    v_checkin_id,
    jsonb_build_array(jsonb_build_object('drink_item_id', v_alcohol_drink_id, 'quantity', 2)),
    true,
    'order-ok'
  );

  if v_result ->> 'code' <> 'ok' or (v_result ->> 'total_amount')::integer <= 0 then
    raise exception 'order create contract failed: %', v_result;
  end if;

  v_order_id := (v_result ->> 'order_id')::uuid;

  if not exists (
    select 1
    from public.venue_order_events
    where order_id = v_order_id
      and event_type = 'order_created'
      and to_status = 'created'
  ) then
    raise exception 'order create did not write order_created event';
  end if;

  perform set_config('request.jwt.claim.sub', v_other_user_id::text, true);
  v_result := public.venue_order_create(
    v_club_id,
    v_venue_id,
    v_checkin_id,
    jsonb_build_array(jsonb_build_object('drink_item_id', v_alcohol_drink_id, 'quantity', 1)),
    true,
    'cross-user-checkin'
  );
  if v_result ->> 'code' <> 'checkin_required' then
    raise exception 'cross-user check-in order was not denied: %', v_result;
  end if;

  insert into public.venue_staff_memberships (club_id, venue_id, user_id, role)
  values (v_club_id, v_venue_id, v_staff_user_id, 'staff');
  insert into public.venue_staff_memberships (club_id, venue_id, user_id, role)
  values (v_club_id, v_venue_id, v_manager_user_id, 'manager');

  perform set_config('request.jwt.claim.sub', v_other_user_id::text, true);
  v_result := public.venue_order_update_status(v_club_id, v_order_id, 'accepted', null);
  if v_result ->> 'code' <> 'permission_denied' then
    raise exception 'non-staff order status update was not denied: %', v_result;
  end if;

  perform set_config('request.jwt.claim.sub', v_staff_user_id::text, true);
  v_result := public.venue_order_update_status(v_club_id, v_order_id, 'accepted', 'contract accepted');
  if v_result ->> 'code' <> 'ok' or v_result ->> 'status' <> 'accepted' then
    raise exception 'staff order status update contract failed: %', v_result;
  end if;

  if not exists (
    select 1
    from public.venue_order_events
    where order_id = v_order_id
      and event_type = 'order_status_changed'
      and from_status = 'created'
      and to_status = 'accepted'
  ) then
    raise exception 'order status update did not write audit event';
  end if;

  perform set_config('request.jwt.claim.sub', v_manager_user_id::text, true);
  v_result := public.venue_menu_upsert(
    v_venue_id, null, 'Inactive Contract Drink', 'Scoped menu mutation',
    1500, 'RWF', false, false, 50
  );
  if v_result ->> 'code' <> 'ok' then
    raise exception 'manager menu upsert contract failed: %', v_result;
  end if;
  if not exists (
    select 1 from public.venue_staff_audit_events
    where venue_id = v_venue_id and event_type = 'menu_item_created'
  ) then
    raise exception 'menu mutation did not write staff audit event';
  end if;

  v_result := public.venue_menu_upsert(
    v_other_venue_id, null, 'Cross Venue Drink', '', 1500, 'RWF', false, false, 51
  );
  if v_result ->> 'code' <> 'permission_denied' then
    raise exception 'cross-venue menu mutation was not denied: %', v_result;
  end if;

  insert into public.venue_checkin_campaigns (
    club_id, venue_id, campaign_name, status, starts_at, ends_at,
    fet_award_per_checkin, fet_budget, max_checkins_per_user
  ) values (
    v_club_id, v_venue_id, 'Launch Contract Campaign', 'approved',
    timezone('utc', now()) - interval '1 hour',
    timezone('utc', now()) + interval '1 hour', 1, 100, 1
  ) returning id into v_launch_campaign_id;

  v_result := public.venue_promotion_launch(v_venue_id, v_launch_campaign_id, 'launch-contract-key');
  if v_result ->> 'code' <> 'ok' then
    raise exception 'promotion launch contract failed: %', v_result;
  end if;
  v_result := public.venue_promotion_launch(v_venue_id, v_launch_campaign_id, 'launch-contract-key');
  if v_result ->> 'code' <> 'idempotent_replay' then
    raise exception 'promotion launch idempotency failed: %', v_result;
  end if;
  if (select count(*) from public.venue_staff_audit_events
      where entity_id = v_launch_campaign_id::text and event_type = 'promotion_launched') <> 1 then
    raise exception 'promotion idempotency wrote duplicate staff audit events';
  end if;
end $$;

select pass('venue check-in and drinks ordering behavior contracts pass');

select * from finish();

rollback;

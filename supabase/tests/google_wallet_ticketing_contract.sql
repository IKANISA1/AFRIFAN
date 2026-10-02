-- Wallet issuance, ownership, cancellation and retry contracts without partner venues.
create extension if not exists pgtap with schema extensions;
begin;
select plan(9);
select is((select count(*)::integer from pg_class where relnamespace='public'::regnamespace
  and relname = any(array['ticket_organizations','ticket_events','ticket_wallet_credentials','google_wallet_ticket_passes','google_wallet_ticket_outbox'])
  and relkind='r' and relrowsecurity),5,'all five Wallet tables have RLS');
select ok(not exists(select 1 from unnest(array['ticket_wallet_credentials','google_wallet_ticket_passes','google_wallet_ticket_outbox']) t
  where has_table_privilege('anon','public.'||t,'SELECT') or has_table_privilege('authenticated','public.'||t,'SELECT'))
  and has_table_privilege('service_role','public.google_wallet_ticket_passes','INSERT'), 'private Wallet state remains service-only');
select ok(has_function_privilege('authenticated','public.prepare_google_wallet_ticket(uuid)','EXECUTE')
  and not has_function_privilege('anon','public.prepare_google_wallet_ticket(uuid)','EXECUTE')
  and not exists(select 1 from unnest(array['record_google_wallet_ticket_pass(uuid,uuid,text,text,text)','claim_google_wallet_ticket_outbox(uuid,integer)','complete_google_wallet_ticket_outbox(uuid,uuid,boolean,text)']) f
    where not has_function_privilege('service_role','public.'||f,'EXECUTE') or has_function_privilege('authenticated','public.'||f,'EXECUTE')),
  'issuance and synchronization preserve the service boundary');
select ok((select bool_and(prosecdef and proconfig=array['search_path=""']::text[]) from pg_proc
  where pronamespace='public'::regnamespace and proname in ('prepare_google_wallet_ticket','record_google_wallet_ticket_pass','claim_google_wallet_ticket_outbox','complete_google_wallet_ticket_outbox')),
  'Wallet RPCs use a fixed empty search path');
select ok(exists(select 1 from public.platform_features where feature_key='google_wallet_tickets' and club_id is null and not is_enabled and visibility_state='hidden')
  and exists(select 1 from public.platform_feature_channels c join public.platform_features f on f.id=c.feature_id where f.feature_key='google_wallet_tickets' and f.club_id is null and c.channel='mobile' and not c.is_enabled and not c.is_visible),
  'Wallet remains hidden until explicit activation gates pass');
select is((select count(*)::integer from (select * from pg_policies where permissive='PERMISSIVE') pg_policies where schemaname='public' and tablename=any(array['ticket_organizations','ticket_events','ticket_wallet_credentials','google_wallet_ticket_passes','google_wallet_ticket_outbox'])),20,
  'all five Wallet tables have explicit command policies');
select ok(exists(select 1 from pg_trigger where tgrelid='public.tickets'::regclass and tgname='tickets_queue_google_wallet_state' and not tgisinternal),
  'ticket lifecycle synchronizes Wallet state');
select ok(exists(select 1 from pg_indexes where schemaname='public' and indexname='idx_google_wallet_ticket_outbox_processing_pass' and indexdef ilike 'create unique index%')
  and exists(select 1 from cron.job where jobname='sync-google-wallet-ticket-state' and schedule='* * * * *'),
  'Wallet synchronization retains single-processing guard and governed scheduling');

do $$
declare
  v_club_id bigint;
  v_partner_id uuid;
  v_fan_id uuid := '00000000-0000-4000-8000-00000000a101';
  v_admin_id uuid := '00000000-0000-4000-8000-00000000a104';
  v_match_id uuid;
  v_ticket_id uuid;
  v_organization_id uuid;
  v_event_id uuid;
  v_credential_id uuid;
  v_first_claim_token uuid := '00000000-0000-4000-8000-00000000c101';
  v_second_claim_token uuid := '00000000-0000-4000-8000-00000000c102';
  v_outbox_id uuid;
  v_claimed_token uuid;
  v_claimed_attempts integer;
  v_completion_state text;
  v_result jsonb;
begin
  insert into public.african_football_clubs (
    club_name,
    country_name,
    club_slug
  ) values (
    'Wallet Contract Club',
    'Rwanda',
    'wallet-contract-club'
  ) returning id into v_club_id;

  insert into public.partners (name, slug)
  values ('Wallet Contract Partner', 'wallet-contract-partner')
  returning id into v_partner_id;

  insert into auth.users (id, aud, role)
  values
    (v_fan_id, 'authenticated', 'authenticated'),
    (v_admin_id, 'authenticated', 'authenticated');

  insert into public.users (id, phone, full_name)
  values
    (v_fan_id, '+250790200101', 'Wallet Contract Fan'),
    (v_admin_id, '+250790200104', 'Wallet Contract Admin');

  insert into public.profiles (id, club_id, full_name, country)
  values
    (v_fan_id, v_club_id, 'Wallet Contract Fan', 'RW'),
    (v_admin_id, v_club_id, 'Wallet Contract Admin', 'RW');

  insert into public.admin_role_assignments (
    user_id,
    role,
    club_id,
    granted_by
  ) values (
    v_admin_id,
    'club_admin',
    v_club_id,
    v_admin_id
  );


  insert into public.matches (
    partner_id,
    home_team,
    away_team,
    competition,
    venue,
    match_date,
    kickoff_time,
    capacity,
    club_id
  ) values (
    v_partner_id,
    'Wallet Contract Home',
    'Wallet Contract Away',
    'Contract Cup',
    'Wallet Contract Stadium',
    current_date + 1,
    '18:00',
    100,
    v_club_id
  ) returning id into v_match_id;

  insert into public.tickets (
    match_id,
    user_id,
    seat_type,
    amount_paid,
    status,
    confirmed_at,
    club_id
  ) values (
    v_match_id,
    v_fan_id,
    'General admission',
    5000,
    'valid',
    timezone('utc', now()),
    v_club_id
  ) returning id into v_ticket_id;

  insert into public.ticket_organizations (
    club_id,
    slug,
    display_name,
    status,
    google_wallet_issuer_id
  ) values (
    v_club_id,
    'wallet-contract-org',
    'Wallet Contract Organization',
    'active',
    '1234567890123456'
  ) returning id into v_organization_id;

  insert into public.ticket_events (
    club_id,
    organization_id,
    match_id,
    location_name,
    location_address,
    location_country_code,
    location_timezone,
    status,
    entry_opens_at,
    entry_closes_at,
    google_wallet_enabled
  ) values (
    v_club_id,
    v_organization_id,
    v_match_id,
    'Wallet Contract Stadium',
    'Kigali',
    'RW',
    'Africa/Kigali',
    'active',
    timezone('utc', now()) - interval '1 hour',
    timezone('utc', now()) + interval '2 hours',
    true
  ) returning id into v_event_id;

  perform set_config('request.jwt.claim.sub', v_fan_id::text, true);
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', v_fan_id,
      'role', 'authenticated',
      'club_id', v_club_id
    )::text,
    true
  );

  v_result := public.prepare_google_wallet_ticket(v_ticket_id);
  if v_result ->> 'code' <> 'ready'
     or v_result ->> 'ticket_id' <> v_ticket_id::text
     or v_result ? 'totp_secret' then
    raise exception 'safe Wallet preparation failed: %', v_result;
  end if;

  v_credential_id := (v_result ->> 'credential_id')::uuid;
  perform public.record_google_wallet_ticket_pass(
    v_ticket_id,
    v_credential_id,
    '1234567890123456.contract_class',
    '1234567890123456.contract_object',
    'ACTIVE'
  );

  v_result := public.prepare_google_wallet_ticket(v_ticket_id);
  if v_result ->> 'credential_id' <> v_credential_id::text
     or v_result ->> 'venue' <> 'Wallet Contract Stadium'
     or v_result ->> 'venue_address' <> 'Kigali'
     or v_result ->> 'venue_country_code' <> 'RW'
     or v_result ->> 'venue_timezone' <> 'Africa/Kigali' then
    raise exception 'Wallet preparation lost stable identity or independent stadium details: %', v_result;
  end if;

  perform set_config('request.jwt.claim.sub', v_admin_id::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub',v_admin_id,'role','authenticated','club_id',v_club_id,
    'aal','aal2','is_anonymous',false,'exp',floor(extract(epoch from clock_timestamp()))::bigint+3600,
    'amr',jsonb_build_array(jsonb_build_object('method','totp',
      'timestamp',floor(extract(epoch from clock_timestamp()))::bigint-1)))::text, true);
  v_result := public.prepare_google_wallet_ticket(v_ticket_id);
  if v_result ->> 'code' <> 'ticket_not_found' then
    raise exception 'Another account must not prepare the ticket: %', v_result;
  end if;
  perform set_config('request.jwt.claim.sub', v_fan_id::text, true);
  perform set_config('request.jwt.claims', jsonb_build_object('sub',v_fan_id,'role','authenticated','club_id',v_club_id)::text, true);

  update public.tickets set status = 'cancelled' where id = v_ticket_id;
  v_result := public.prepare_google_wallet_ticket(v_ticket_id);
  if v_result ->> 'code' <> 'ticket_not_active'
     or (select wallet_state from public.google_wallet_ticket_passes where ticket_id = v_ticket_id) <> 'INACTIVE' then
    raise exception 'Cancellation must stop issuance and synchronize local Wallet state: %', v_result;
  end if;

  select claimed.id, claimed.claim_token, claimed.attempts
  into v_outbox_id, v_claimed_token, v_claimed_attempts
  from public.claim_google_wallet_ticket_outbox(v_first_claim_token, 25) as claimed
  where claimed.desired_state = 'INACTIVE';

  if v_outbox_id is null
     or v_claimed_token <> v_first_claim_token
     or v_claimed_attempts <> 1 then
    raise exception 'Wallet outbox was not claimed atomically';
  end if;

  v_completion_state := public.complete_google_wallet_ticket_outbox(
    v_outbox_id,
    v_first_claim_token,
    false,
    'google_wallet_state_update_503'
  );
  if v_completion_state <> 'failed'
     or not exists (
       select 1
       from public.google_wallet_ticket_outbox as outbox
       where outbox.id = v_outbox_id
         and outbox.status = 'failed'
         and outbox.available_at > timezone('utc', now())
         and outbox.last_error_code = 'google_wallet_state_update_503'
     ) then
    raise exception 'Wallet outbox retry and backoff were not recorded';
  end if;

  update public.google_wallet_ticket_outbox
  set available_at = timezone('utc', now()) - interval '1 second'
  where id = v_outbox_id;

  select claimed.claim_token, claimed.attempts
  into v_claimed_token, v_claimed_attempts
  from public.claim_google_wallet_ticket_outbox(v_second_claim_token, 25) as claimed
  where claimed.id = v_outbox_id;

  if v_claimed_token <> v_second_claim_token or v_claimed_attempts <> 2 then
    raise exception 'Wallet outbox retry was not reclaimed safely';
  end if;

  v_completion_state := public.complete_google_wallet_ticket_outbox(
    v_outbox_id,
    v_second_claim_token,
    true,
    null
  );
  if v_completion_state <> 'completed'
     or not exists (
       select 1
       from public.google_wallet_ticket_outbox as outbox
       join public.google_wallet_ticket_passes as wallet_pass
         on wallet_pass.id = outbox.pass_id
       where outbox.id = v_outbox_id
         and outbox.status = 'completed'
         and outbox.claim_token is null
         and outbox.completed_at is not null
         and wallet_pass.last_synced_at is not null
         and wallet_pass.last_error_code is null
     ) then
    raise exception 'Wallet outbox completion did not update pass synchronization evidence';
  end if;

end $$;

select pass('Wallet issuance, event location, ownership, cancellation and outbox retries remain consistent');
select * from finish();
rollback;

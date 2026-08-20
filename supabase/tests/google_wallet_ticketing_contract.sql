-- Google Wallet ticket issuance and venue verification contract checks.
-- Run against a migrated isolated database with `supabase test db`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(9);

select ok(
  (
    select count(*) = 7
    from pg_class as relation
    join pg_namespace as namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = any (
        array[
          'ticket_organizations',
          'ticket_events',
          'ticket_verifier_assignments',
          'ticket_wallet_credentials',
          'google_wallet_ticket_passes',
          'google_wallet_ticket_outbox',
          'ticket_redemption_events'
        ]
      )
      and relation.relkind = 'r'
      and relation.relrowsecurity
  ),
  'wallet and verifier tables exist with RLS enabled'
);

select ok(
  not has_table_privilege('anon', 'public.ticket_verifier_assignments', 'SELECT')
  and has_column_privilege(
    'authenticated',
    'public.ticket_verifier_assignments',
    'gate_code',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.ticket_verifier_assignments',
    'INSERT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.ticket_wallet_credentials',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.google_wallet_ticket_passes',
    'SELECT'
  )
  and not has_table_privilege(
    'authenticated',
    'public.google_wallet_ticket_outbox',
    'SELECT'
  )
  and has_column_privilege(
    'authenticated',
    'public.ticket_redemption_events',
    'decision',
    'SELECT'
  )
  and has_table_privilege(
    'service_role',
    'public.google_wallet_ticket_passes',
    'INSERT'
  ),
  'the Data API exposes verifier-safe reads while private Wallet state remains service-only'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.prepare_google_wallet_ticket(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.prepare_google_wallet_ticket(uuid)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.record_google_wallet_ticket_pass(uuid,uuid,text,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.record_google_wallet_ticket_pass(uuid,uuid,text,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.redeem_ticket_for_verifier(uuid,uuid,integer,uuid,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.redeem_ticket_for_verifier(uuid,uuid,integer,uuid,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.claim_google_wallet_ticket_outbox(uuid,integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.claim_google_wallet_ticket_outbox(uuid,integer)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.complete_google_wallet_ticket_outbox(uuid,uuid,boolean,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.complete_google_wallet_ticket_outbox(uuid,uuid,boolean,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.grant_ticket_verifier_assignment(uuid,bigint,uuid,uuid,text,timestamp with time zone,timestamp with time zone)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.grant_ticket_verifier_assignment(uuid,bigint,uuid,uuid,text,timestamp with time zone,timestamp with time zone)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.revoke_ticket_verifier_assignment(uuid,bigint,uuid,timestamp with time zone)',
    'EXECUTE'
  ),
  'issuance, verifier administration, redemption, and synchronization RPC grants preserve the service boundary'
);

select ok(
  (
    select bool_and(
      procedure.prosecdef
      and procedure.proconfig = array['search_path=""']::text[]
    )
    from pg_proc as procedure
    where procedure.oid = any (
      array[
        'public.prepare_google_wallet_ticket(uuid)'::regprocedure,
        'public.record_google_wallet_ticket_pass(uuid,uuid,text,text,text)'::regprocedure,
        'public.redeem_ticket_for_verifier(uuid,uuid,integer,uuid,text)'::regprocedure,
        'public.claim_google_wallet_ticket_outbox(uuid,integer)'::regprocedure,
        'public.complete_google_wallet_ticket_outbox(uuid,uuid,boolean,text)'::regprocedure,
        'public.grant_ticket_verifier_assignment(uuid,bigint,uuid,uuid,text,timestamp with time zone,timestamp with time zone)'::regprocedure,
        'public.revoke_ticket_verifier_assignment(uuid,bigint,uuid,timestamp with time zone)'::regprocedure
      ]
    )
  ),
  'Wallet and verifier RPCs are security-definer functions with a fixed empty path'
);

select ok(
  exists (
    select 1
    from public.platform_features as feature
    where feature.feature_key = 'google_wallet_tickets'
      and feature.club_id is null
      and not feature.is_enabled
      and feature.visibility_state = 'hidden'
  )
  and exists (
    select 1
    from public.platform_feature_channels as channel
    join public.platform_features as feature on feature.id = channel.feature_id
    where feature.feature_key = 'google_wallet_tickets'
      and feature.club_id is null
      and channel.channel = 'mobile'
      and not channel.is_enabled
      and not channel.is_visible
  ),
  'Google Wallet remains hidden and disabled until explicit activation gates pass'
);

select ok(
  (
    select count(*) = 28
    from pg_policies
    where schemaname = 'public'
      and tablename = any (
        array[
          'ticket_organizations',
          'ticket_events',
          'ticket_verifier_assignments',
          'ticket_wallet_credentials',
          'google_wallet_ticket_passes',
          'google_wallet_ticket_outbox',
          'ticket_redemption_events'
        ]
      )
  ),
  'all Wallet and verifier tables have explicit command policies'
);

do $$
declare
  policy_expression text;
begin
  select qual
  into policy_expression
  from pg_policies
  where schemaname = 'public'
    and tablename = 'ticket_redemption_events'
    and policyname = 'ticket_redemption_events_assigned_or_admin_read';

  if policy_expression !~ 'verifier_assignment_id'
     or policy_expression !~ 'ticket_verifier_assignments' then
    raise exception 'redemption history read policy is not bound to an assignment';
  end if;
end $$;

select ok(
  exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.tickets'::regclass
      and tgname = 'tickets_queue_google_wallet_state'
      and not tgisinternal
  )
  and exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.ticket_redemption_events'::regclass
      and tgname = 'ticket_redemption_events_immutable_update'
      and not tgisinternal
  )
  and exists (
    select 1
    from pg_trigger
    where tgrelid = 'public.ticket_redemption_events'::regclass
      and tgname = 'ticket_redemption_events_immutable_delete'
      and not tgisinternal
  ),
  'ticket lifecycle synchronization and immutable redemption audit triggers exist'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'public'
      and tablename = 'google_wallet_ticket_outbox'
      and indexname = 'idx_google_wallet_ticket_outbox_processing_pass'
      and indexdef ilike 'create unique index%'
  )
  and exists (
    select 1
    from cron.job
    where jobname = 'sync-google-wallet-ticket-state'
      and schedule = '* * * * *'
  ),
  'Wallet state synchronization has a single-processing-pass guard and governed cron job'
);

do $$
declare
  v_club_id bigint;
  v_partner_id uuid;
  v_fan_id uuid := '00000000-0000-4000-8000-00000000a101';
  v_verifier_id uuid := '00000000-0000-4000-8000-00000000a102';
  v_unassigned_id uuid := '00000000-0000-4000-8000-00000000a103';
  v_admin_id uuid := '00000000-0000-4000-8000-00000000a104';
  v_venue_id uuid;
  v_match_id uuid;
  v_ticket_id uuid;
  v_organization_id uuid;
  v_event_id uuid;
  v_credential_id uuid;
  v_assignment_id uuid;
  v_assignment_updated_at timestamp with time zone;
  v_operation_id uuid := '00000000-0000-4000-8000-00000000b101';
  v_retry_operation_id uuid := '00000000-0000-4000-8000-00000000b102';
  v_first_claim_token uuid := '00000000-0000-4000-8000-00000000c101';
  v_second_claim_token uuid := '00000000-0000-4000-8000-00000000c102';
  v_outbox_id uuid;
  v_claimed_token uuid;
  v_claimed_attempts integer;
  v_completion_state text;
  v_result jsonb;
  v_mutation_blocked boolean := false;
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
    (v_verifier_id, 'authenticated', 'authenticated'),
    (v_unassigned_id, 'authenticated', 'authenticated'),
    (v_admin_id, 'authenticated', 'authenticated');

  insert into public.users (id, phone, full_name)
  values
    (v_fan_id, '+250790200101', 'Wallet Contract Fan'),
    (v_verifier_id, '+250790200102', 'Wallet Contract Verifier'),
    (v_unassigned_id, '+250790200103', 'Wallet Contract Unassigned'),
    (v_admin_id, '+250790200104', 'Wallet Contract Admin');

  insert into public.profiles (id, club_id, full_name, country)
  values
    (v_fan_id, v_club_id, 'Wallet Contract Fan', 'RW'),
    (v_verifier_id, v_club_id, 'Wallet Contract Verifier', 'RW'),
    (v_unassigned_id, v_club_id, 'Wallet Contract Unassigned', 'RW'),
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

  insert into public.venues (
    club_id,
    slug,
    display_name,
    status,
    approved_public_profile,
    address_line
  ) values (
    v_club_id,
    'wallet-contract-stadium',
    'Wallet Contract Stadium',
    'approved',
    true,
    'Kigali'
  ) returning id into v_venue_id;

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
    venue_id,
    status,
    entry_opens_at,
    entry_closes_at,
    google_wallet_enabled,
    verification_enabled
  ) values (
    v_club_id,
    v_organization_id,
    v_match_id,
    v_venue_id,
    'active',
    timezone('utc', now()) - interval '1 hour',
    timezone('utc', now()) + interval '2 hours',
    true,
    true
  ) returning id into v_event_id;

  v_assignment_id := public.grant_ticket_verifier_assignment(
    v_admin_id,
    v_club_id,
    v_event_id,
    v_verifier_id,
    'GATE_A',
    timezone('utc', now()) - interval '59 minutes',
    timezone('utc', now()) + interval '119 minutes'
  );

  if v_assignment_id is null
     or not exists (
       select 1
       from public.admin_audit_log
       where target_id = v_assignment_id::text
         and action = 'ticket_verifier_assignment_granted'
         and actor_id = v_admin_id
     ) then
    raise exception 'governed verifier grant and audit were not recorded';
  end if;

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

  v_result := public.redeem_ticket_for_verifier(
    v_unassigned_id,
    v_credential_id,
    1,
    '00000000-0000-4000-8000-00000000b100',
    'GATE_A'
  );
  if v_result ->> 'code' <> 'permission_denied'
     or v_result ? 'ticket_id'
     or v_result ? 'seat_type' then
    raise exception 'unassigned verifier response leaked ticket data: %', v_result;
  end if;

  v_result := public.redeem_ticket_for_verifier(
    v_verifier_id,
    v_credential_id,
    1,
    v_operation_id,
    'GATE_A'
  );
  if v_result ->> 'status' <> 'admitted'
     or v_result ->> 'code' <> 'admitted' then
    raise exception 'authorized admission failed: %', v_result;
  end if;

  v_result := public.redeem_ticket_for_verifier(
    v_verifier_id,
    v_credential_id,
    1,
    v_operation_id,
    'GATE_A'
  );
  if v_result ->> 'status' <> 'admitted'
     or (v_result ->> 'replayed')::boolean is not true then
    raise exception 'operation replay was not idempotent: %', v_result;
  end if;

  v_result := public.redeem_ticket_for_verifier(
    v_verifier_id,
    v_credential_id,
    1,
    v_retry_operation_id,
    'GATE_A'
  );
  if v_result ->> 'code' <> 'already_used'
     or v_result ->> 'first_admitted_at' is null then
    raise exception 'second admission was not rejected with first-use evidence: %', v_result;
  end if;

  if (select status from public.tickets where id = v_ticket_id) <> 'used'
     or (
       select wallet_state
       from public.google_wallet_ticket_passes
       where ticket_id = v_ticket_id
     ) <> 'COMPLETED'
     or not exists (
       select 1
       from public.google_wallet_ticket_outbox
       where ticket_id = v_ticket_id
         and desired_state = 'COMPLETED'
         and status = 'pending'
     ) then
    raise exception 'admission did not synchronize authoritative ticket and Wallet state';
  end if;

  select claimed.id, claimed.claim_token, claimed.attempts
  into v_outbox_id, v_claimed_token, v_claimed_attempts
  from public.claim_google_wallet_ticket_outbox(v_first_claim_token, 25) as claimed
  where claimed.desired_state = 'COMPLETED';

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

  begin
    update public.ticket_redemption_events
    set decision = 'permission_denied'
    where verifier_user_id = v_verifier_id
      and operation_id = v_operation_id;
  exception
    when others then
      v_mutation_blocked := sqlerrm = 'Ticket redemption events are immutable.';
  end;

  if not v_mutation_blocked then
    raise exception 'redemption audit mutation was not blocked';
  end if;

  select updated_at
  into v_assignment_updated_at
  from public.ticket_verifier_assignments
  where id = v_assignment_id;

  perform public.revoke_ticket_verifier_assignment(
    v_admin_id,
    v_club_id,
    v_assignment_id,
    v_assignment_updated_at
  );

  if exists (
       select 1
       from public.ticket_verifier_assignments
       where id = v_assignment_id
         and is_active
     )
     or not exists (
       select 1
       from public.admin_audit_log
       where target_id = v_assignment_id::text
         and action = 'ticket_verifier_assignment_revoked'
         and actor_id = v_admin_id
     ) then
    raise exception 'governed verifier revocation and audit were not recorded';
  end if;
end $$;

select pass(
  'governed assignment, issuance, one-time admission, Wallet retries, revocation, and immutable audit hold together'
);

select * from finish();

rollback;

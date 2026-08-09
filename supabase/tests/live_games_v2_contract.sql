-- AFRICLUB Live Games V2 authoritative contract checks.
-- Run against a migrated isolated database with `supabase test db`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(82);

select ok(
  to_regclass('africlub_game.display_assignments') is not null
  and to_regclass('africlub_game.role_grants') is not null
  and to_regclass('africlub_game.session_organizers') is not null
  and to_regclass('africlub_game.session_eligibility') is not null
  and to_regclass('africlub_game.session_invitations') is not null,
  'owner, assigned-organizer, display, and eligibility relations exist'
);

select ok(
  to_regclass('africlub_game.transition_requests') is not null
  and to_regclass('africlub_game.operation_requests') is not null
  and to_regclass('africlub_game.game_events') is not null
  and to_regclass('africlub_game.display_pairing_challenges') is not null
  and to_regclass('africlub_game.display_bootstrap_challenges') is not null,
  'idempotency, event, owner pairing, and TV bootstrap relations exist'
);

select columns_are(
  'africlub_game',
  'tv_devices',
  array[
    'id',
    'club_id',
    'device_label',
    'pairing_code',
    'status',
    'last_seen_at',
    'current_session_id',
    'metadata',
    'created_by',
    'created_at',
    'updated_at',
    'pairing_code_hash',
    'pairing_expires_at',
    'credential_token_hash',
    'credential_issued_at',
    'credential_revoked_at',
    'owner_user_id',
    'scope_type',
    'venue_id',
    'app_version',
    'capabilities',
    'device_auth_user_id'
  ],
  'TV installations include first-class owner, scope, venue, version, capabilities, and Realtime identity'
);

select ok(
  to_regprocedure('public.bind_tv_realtime_identity_v2(text)') is not null
  and to_regprocedure(
    'africlub_game.is_tv_session_subscriber(uuid)'
  ) is not null
  and exists (
    select 1
    from pg_indexes
    where schemaname = 'africlub_game'
      and indexname = 'idx_tv_devices_active_auth_identity'
  )
  and exists (
    select 1
    from pg_trigger trigger_row
    join pg_class table_row on table_row.oid = trigger_row.tgrelid
    join pg_namespace schema_row on schema_row.oid = table_row.relnamespace
    where schema_row.nspname = 'africlub_game'
      and table_row.relname = 'tv_devices'
      and trigger_row.tgname = 'tv_devices_clear_realtime_identity'
      and not trigger_row.tgisinternal
  ),
  'native TV Realtime identity has a bounded binding RPC, RLS predicate, active-identity index, and revocation trigger'
);

select ok(
  exists (
    select 1
    from pg_constraint constraint_row
    join pg_class relation_row on relation_row.oid = constraint_row.conrelid
    join pg_namespace namespace_row on namespace_row.oid = relation_row.relnamespace
    where namespace_row.nspname = 'africlub_game'
      and relation_row.relname = 'tv_devices'
      and constraint_row.conname = 'tv_devices_capabilities_check'
      and pg_get_constraintdef(constraint_row.oid) like '%2048%'
  ),
  'TV capability metadata is bounded by an enforced database constraint'
);

select ok(
  exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'africlub_game'
      and tablename = 'game_events'
  )
  and exists (
    select 1
    from pg_constraint constraint_row
    join pg_class relation_row on relation_row.oid = constraint_row.conrelid
    join pg_namespace namespace_row on namespace_row.oid = relation_row.relnamespace
    where namespace_row.nspname = 'africlub_game'
      and relation_row.relname = 'game_events'
      and constraint_row.conname = 'game_events_payload_check'
      and pg_get_constraintdef(constraint_row.oid)
        like '%requires_projection_refresh%'
  ),
  'game invalidation events are published and require projection reconciliation'
);

select ok(
  exists (
    select 1
    from information_schema.columns
    where table_schema = 'africlub_game'
      and table_name = 'game_sessions'
      and column_name = 'lifecycle_phase'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'africlub_game'
      and table_name = 'game_sessions'
      and column_name = 'session_version'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'africlub_game'
      and table_name = 'game_sessions'
      and column_name = 'event_sequence'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'africlub_game'
      and table_name = 'game_sessions'
      and column_name = 'paused_from_phase'
  ),
  'game sessions carry lifecycle, pause recovery, and monotonic projection versions'
);

select ok(
  to_regprocedure('public.get_eligible_game_sessions_v2(uuid)') is not null
  and to_regprocedure('public.get_participant_game_projection_v2(uuid)') is not null
  and to_regprocedure(
    'public.submit_participant_answer_v2(uuid,uuid,text,bigint,bigint,text)'
  ) is not null,
  'code-free discovery, participant projection, and versioned answer RPCs exist'
);

select ok(
  to_regprocedure(
    'africlub_game.transition_session_v2(uuid,text,bigint,text,uuid,timestamp with time zone,text)'
  ) is not null
  and to_regprocedure('africlub_game.assign_display_v2(uuid,uuid,text)') is not null,
  'versioned transition and many-display assignment RPCs exist'
);

select ok(
  to_regprocedure(
    'public.create_display_pairing_challenge_v2(text,text,jsonb)'
  ) is not null
  and to_regprocedure(
    'public.claim_display_bootstrap_challenge_v2(text,text,text,uuid)'
  ) is not null
  and to_regprocedure(
    'public.exchange_display_pairing_challenge_v2(text,text)'
  ) is not null
  and to_regprocedure('public.get_tv_game_projection_v2(text)') is not null,
  'native-TV bootstrap pairing and credential-scoped projection RPCs exist'
);

select ok(
  to_regprocedure('public.get_owned_displays_v2()') is not null
  and to_regprocedure(
    'public.update_owned_display_v2(uuid,text,text,uuid,text)'
  ) is not null
  and to_regprocedure('public.revoke_owned_display_v2(uuid,text)') is not null
  and to_regprocedure(
    'public.recover_owned_display_from_bootstrap_v2(uuid,text,text)'
  ) is not null,
  'owner-scoped display inventory, update, revocation, and recovery RPCs exist'
);

select ok(
  to_regprocedure('public.get_managed_game_sessions_v2()') is not null
  and to_regprocedure('public.get_game_planner_options_v2()') is not null
  and to_regprocedure('public.get_organizer_game_projection_v2(uuid)') is not null
  and to_regprocedure('public.get_admin_game_projection_v2(uuid)') is not null
  and to_regprocedure(
    'public.skip_managed_game_question_v2(uuid,uuid,bigint,text,text)'
  ) is not null
  and to_regprocedure(
    'public.end_managed_game_session_v2(uuid,bigint,text,text)'
  ) is not null
  and to_regprocedure(
    'public.create_managed_game_session_v2(uuid,timestamp with time zone,text,uuid[],text,uuid[],uuid[])'
  ) is not null,
  'organizer planning and role-safe organizer/admin projection RPCs exist'
);

do $$
declare
  planner_source text;
begin
  select p.prosrc into planner_source
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_game_planner_options_v2';

  if planner_source !~ '''questions'''
     or planner_source !~ '''organizers'''
     or planner_source !~ '''invitees'''
     or planner_source !~ 'question.status = ''approved'''
     or planner_source !~ 'role_key = ''game_organizer'''
     or planner_source !~ 'membership.status = ''active'''
     or planner_source !~ 'limit 200'
     or planner_source !~ 'limit 100' then
    raise exception 'planner does not expose bounded approved content, organizer, and invitee selectors';
  end if;
  if planner_source ~ '''correct_option_key'''
     or planner_source ~ '''explanation'''
     or planner_source ~ '''phone'''
     or planner_source ~ '''email''' then
    raise exception 'planner selector exposes answer-only or private content';
  end if;
end $$;
select pass(
  'planner exposes bounded approved content, organizer, and Fan-ID invitee metadata without answer-only or private content'
);

do $$
declare
  organizer_source text;
begin
  select p.prosrc into organizer_source
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_organizer_game_projection_v2';

  if organizer_source !~ '''question_controls'''
     or organizer_source !~ 'session_question.ordinal' then
    raise exception 'organizer projection omits ordered question controls';
  end if;
  if organizer_source ~ '''correct_option_key''' then
    raise exception 'organizer question controls expose correct-answer material';
  end if;
end $$;
select pass(
  'organizer projection provides ordered question selectors without correct answers'
);

select ok(
  to_regprocedure(
    'public.create_display_pairing_challenge_v2(text,text,jsonb)'
  ) is not null
  and to_regprocedure(
    'public.claim_display_bootstrap_challenge_v2(text,text,text,uuid)'
  ) is not null
  and to_regprocedure(
    'public.exchange_display_pairing_challenge_v2(text,text)'
  ) is not null
  and to_regprocedure(
    'public.recover_owned_display_from_bootstrap_v2(uuid,text,text)'
  ) is not null
  and to_regprocedure(
    'public.transition_managed_game_session_v2(uuid,text,bigint,text,uuid,timestamp with time zone,text)'
  ) is not null
  and to_regprocedure(
    'public.assign_managed_game_display_v2(uuid,uuid,text)'
  ) is not null
  and to_regprocedure(
    'public.unassign_managed_game_display_v2(uuid,uuid,text)'
  ) is not null
  and to_regprocedure(
    'public.issue_owned_display_pairing_challenge_v2(uuid)'
  ) is null
  and to_regprocedure(
    'public.claim_display_pairing_challenge_v2(text,text,text,uuid)'
  ) is null,
  'TV bootstrap and public authorization-preserving operations wrappers exist'
);

do $$
declare
  discovery_source text;
begin
  select p.prosrc into discovery_source
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_eligible_game_sessions_v2';

  if discovery_source ~ '''join_code'''
     or discovery_source ~ '''tv_code'''
     or discovery_source ~ '''pairing_code''' then
    raise exception 'participant discovery exposes join or pairing material';
  end if;
  if discovery_source !~ '''club_membership'''
     or discovery_source !~ '''invitation'''
     or discovery_source !~ '''home_owner'''
     or discovery_source !~ '''venue'''
     or discovery_source !~ '''deep_link''' then
    raise exception 'participant discovery omits a governed discovery source';
  end if;
end $$;
select pass('participant discovery is code-free and source-governed');

do $$
declare
  projection_source text;
begin
  select p.prosrc into projection_source
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_participant_game_projection_v2';

  if position(
       'lifecycle_phase in (''reveal'', ''completed'')'
       in projection_source
     ) = 0
     or position('''correct_option_key''' in projection_source) = 0 then
    raise exception 'participant answer reveal guard is missing';
  end if;
  if projection_source ~ '''phone'''
     or projection_source ~ '''email'''
     or projection_source ~ '''join_code''' then
    raise exception 'participant projection exposes private or join material';
  end if;
end $$;
select pass('participant projection gates answers and omits private/join material');

do $$
declare
  submission_source text;
begin
  select p.prosrc into submission_source
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'submit_participant_answer_v2';

  if submission_source !~ 'current_club_id'
     or submission_source !~ 'get_eligible_game_sessions_v2'
     or submission_source !~ 'club_id = v_club_id' then
    raise exception 'answer submission does not re-authorize current club eligibility';
  end if;
end $$;
select pass('answer submission re-authorizes current club eligibility');

do $$
declare
  transition_source text;
begin
  select p.prosrc into transition_source
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'africlub_game'
    and p.proname = 'transition_session_v2';

  if transition_source !~ 'session_version <> p_expected_session_version'
     or transition_source !~ 'transition_requests'
     or transition_source !~ 'game_events'
     or transition_source !~ 'audit_log' then
    raise exception 'transition is missing version, idempotency, event, or audit enforcement';
  end if;
end $$;
select pass('lifecycle transition is versioned, idempotent, evented, and audited');

select ok(
  (
    select count(*) = 10
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'africlub_game'
      and relation.relname in (
        'role_grants',
        'session_organizers',
        'display_assignments',
        'session_eligibility',
        'session_invitations',
        'transition_requests',
        'operation_requests',
        'game_events',
        'display_pairing_challenges',
        'display_bootstrap_challenges'
      )
      and relation.relrowsecurity
  ),
  'every Live Games V2 relation enforces row-level security'
);

select ok(
  exists (
    select 1
    from pg_indexes
    where schemaname = 'africlub_game'
      and indexname = 'idx_display_assignments_active'
  )
  and exists (
    select 1
    from pg_indexes
    where schemaname = 'africlub_game'
      and indexname = 'idx_game_events_topic_sequence'
  )
  and exists (
    select 1
    from pg_constraint constraint_row
    join pg_class relation on relation.oid = constraint_row.conrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'africlub_game'
      and relation.relname = 'transition_requests'
      and constraint_row.contype = 'u'
  )
  and exists (
    select 1
    from pg_indexes
    where schemaname = 'africlub_game'
      and indexname = 'idx_session_organizers_active'
  )
  and exists (
    select 1
    from pg_indexes
    where schemaname = 'africlub_game'
      and indexname = 'idx_display_bootstrap_installation'
  ),
  'assignment, organizer, bootstrap, ordering, and idempotency indexes are enforced'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.get_eligible_game_sessions_v2(uuid)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_eligible_game_sessions_v2(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'africlub_game.transition_session_v2(uuid,text,bigint,text,uuid,timestamp with time zone,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'anon',
    'public.create_display_pairing_challenge_v2(text,text,jsonb)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.claim_display_bootstrap_challenge_v2(text,text,text,uuid)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.get_owned_displays_v2()',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.recover_owned_display_from_bootstrap_v2(uuid,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.recover_owned_display_from_bootstrap_v2(uuid,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.transition_managed_game_session_v2(uuid,text,bigint,text,uuid,timestamp with time zone,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'africlub_game.transition_session_v2(uuid,text,bigint,text,uuid,timestamp with time zone,text)',
    'EXECUTE'
  ),
  'participant, owner, organizer, wrapper, and TV bootstrap privileges are least-privilege'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.bind_tv_realtime_identity_v2(text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.bind_tv_realtime_identity_v2(text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'africlub_game.is_tv_session_subscriber(uuid)',
    'EXECUTE'
  ),
  'native TV identity binding and event authorization require an authenticated caller'
);

select ok(
  pg_get_functiondef(
    to_regprocedure('public.custom_access_token_hook(jsonb)')
  ) like '%''{user_role}''%'
  and pg_get_functiondef(
    to_regprocedure('public.custom_access_token_hook(jsonb)')
  ) not like '%jsonb_set(claims, ''{role}''%',
  'the access-token hook preserves authenticated and separates the product role'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'africlub_game.get_tv_session_state(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'africlub_game.join_session(uuid,text,bigint,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'africlub_game.submit_answer(uuid,uuid,text,text)',
    'EXECUTE'
  )
  and not has_table_privilege(
    'authenticated',
    'africlub_game.session_players',
    'INSERT'
  )
  and not has_table_privilege(
    'authenticated',
    'africlub_game.answer_attempts',
    'INSERT'
  ),
  'legacy participant RPCs and direct writes are service-mediated after V2'
);

-- Behavioral fixture. These rows are rolled back with the test transaction.
insert into public.african_football_clubs (
  id,
  club_name,
  country_name,
  club_slug
) overriding system value values (
  9900001,
  'Live Games V2 Contract Club',
  'Rwanda',
  'live-games-v2-contract-club'
);

insert into public.african_football_clubs (
  id,
  club_name,
  country_name,
  club_slug
) overriding system value values (
  9900002,
  'Foreign Live Games Contract Club',
  'Rwanda',
  'foreign-live-games-contract-club'
);

insert into public.partners (
  id,
  name,
  slug
) values (
  '99000000-0000-4000-8000-000000000001',
  'Live Games V2 Contract Partner',
  'live-games-v2-contract-partner'
);

insert into auth.users (id, aud, role)
values
  ('99000000-0000-4000-8000-000000000011', 'authenticated', 'authenticated'),
  ('99000000-0000-4000-8000-000000000012', 'authenticated', 'authenticated'),
  ('99000000-0000-4000-8000-000000000013', 'authenticated', 'authenticated'),
  ('99000000-0000-4000-8000-000000000014', 'authenticated', 'authenticated'),
  ('99000000-0000-4000-8000-000000000015', 'authenticated', 'authenticated'),
  ('99000000-0000-4000-8000-000000000016', 'authenticated', 'authenticated'),
  ('99000000-0000-4000-8000-000000000018', 'authenticated', 'authenticated'),
  ('99000000-0000-4000-8000-000000000019', 'authenticated', 'authenticated'),
  ('99000000-0000-4000-8000-000000000020', 'authenticated', 'authenticated');

insert into public.users (id, phone, full_name)
values
  ('99000000-0000-4000-8000-000000000011', '+250790000011', 'Contract Member'),
  ('99000000-0000-4000-8000-000000000012', '+250790000012', 'Contract Suspended Member'),
  ('99000000-0000-4000-8000-000000000013', '+250790000013', 'Contract Organizer'),
  ('99000000-0000-4000-8000-000000000014', '+250790000014', 'Contract Club Admin'),
  ('99000000-0000-4000-8000-000000000015', '+250790000015', 'Contract Display Owner'),
  ('99000000-0000-4000-8000-000000000016', '+250790000016', 'Contract Venue Manager'),
  ('99000000-0000-4000-8000-000000000018', '+250790000018', 'Contract Platform Admin'),
  ('99000000-0000-4000-8000-000000000019', '+250790000019', 'Contract Other Owner'),
  ('99000000-0000-4000-8000-000000000020', '+250790000020', 'Contract Native TV Identity');

insert into public.admin_role_assignments (
  user_id,
  role,
  club_id
) values
  (
    '99000000-0000-4000-8000-000000000014',
    'club_admin',
    9900001
  ),
  (
    '99000000-0000-4000-8000-000000000018',
    'super_admin',
    null
  );

insert into public.venues (
  id,
  club_id,
  slug,
  display_name,
  status,
  approved_public_profile,
  created_by
) values
  (
    '99000000-0000-4000-8000-000000000071',
    9900001,
    'contract-venue',
    'Contract Venue',
    'approved',
    true,
    '99000000-0000-4000-8000-000000000014'
  ),
  (
    '99000000-0000-4000-8000-000000000072',
    9900002,
    'foreign-contract-venue',
    'Foreign Contract Venue',
    'approved',
    true,
    '99000000-0000-4000-8000-000000000014'
  );

insert into public.venue_staff_memberships (
  club_id,
  venue_id,
  user_id,
  role,
  is_active,
  granted_by
) values
  (
    9900001,
    '99000000-0000-4000-8000-000000000071',
    '99000000-0000-4000-8000-000000000016',
    'manager',
    true,
    '99000000-0000-4000-8000-000000000014'
  ),
  (
    9900002,
    '99000000-0000-4000-8000-000000000072',
    '99000000-0000-4000-8000-000000000016',
    'manager',
    true,
    '99000000-0000-4000-8000-000000000014'
  );

insert into public.fan_memberships (
  user_id,
  partner_id,
  club_id,
  membership_number,
  display_name,
  status,
  payment_status,
  expires_at
) values
  (
    '99000000-0000-4000-8000-000000000011',
    '99000000-0000-4000-8000-000000000001',
    9900001,
    'GAME-MEMBER-001',
    'Private Member Name',
    'active',
    'verified',
    timezone('utc', now()) + interval '1 year'
  ),
  (
    '99000000-0000-4000-8000-000000000012',
    '99000000-0000-4000-8000-000000000001',
    9900001,
    'GAME-SUSPENDED-001',
    'Suspended Member Name',
    'suspended',
    'verified',
    timezone('utc', now()) + interval '1 year'
  ),
  (
    '99000000-0000-4000-8000-000000000013',
    '99000000-0000-4000-8000-000000000001',
    9900001,
    'GAME-REVIEWER-001',
    'Synthetic Reviewer Organizer',
    'active',
    'verified',
    timezone('utc', now()) + interval '1 year'
  );

insert into africlub_game.questions (
  id,
  club_id,
  prompt,
  options,
  correct_option_key,
  status
) values (
  '99000000-0000-4000-8000-000000000021',
  9900001,
  'Which city is the capital of Rwanda?',
  '[
    {"key": "a", "label": "Kigali"},
    {"key": "b", "label": "Huye"}
  ]'::jsonb,
  'a',
  'approved'
);

insert into africlub_game.game_sessions (
  id,
  club_id,
  title,
  status,
  lifecycle_phase,
  join_code,
  session_version,
  question_version,
  event_sequence,
  eligibility_scope
) values (
  '99000000-0000-4000-8000-000000000031',
  9900001,
  'Contract Match Quiz',
  'live',
  'question_open',
  'PRIVATE-CONTRACT-CODE',
  7,
  3,
  0,
  'club_membership'
);

insert into africlub_game.game_sessions (
  id,
  club_id,
  title,
  status,
  lifecycle_phase,
  join_code,
  session_version,
  question_version,
  event_sequence,
  eligibility_scope
) values (
  '99000000-0000-4000-8000-000000000032',
  9900001,
  'Conflicting Display Session',
  'scheduled',
  'scheduled',
  'PRIVATE-CONFLICT-CODE',
  1,
  0,
  0,
  'club_membership'
);

insert into africlub_game.session_questions (
  id,
  club_id,
  session_id,
  question_id,
  ordinal,
  state,
  opened_at
) values (
  '99000000-0000-4000-8000-000000000041',
  9900001,
  '99000000-0000-4000-8000-000000000031',
  '99000000-0000-4000-8000-000000000021',
  1,
  'open',
  timezone('utc', now())
);

update africlub_game.game_sessions
set current_session_question_id =
      '99000000-0000-4000-8000-000000000041'
where id = '99000000-0000-4000-8000-000000000031';

insert into africlub_game.session_eligibility (
  club_id,
  session_id,
  scope_type
) values (
  9900001,
  '99000000-0000-4000-8000-000000000031',
  'club_membership'
);

insert into africlub_game.role_grants (
  club_id,
  user_id,
  role_key,
  venue_id
) values
  (
    9900001,
    '99000000-0000-4000-8000-000000000013',
    'game_organizer',
    null
  ),
  (
    9900001,
    '99000000-0000-4000-8000-000000000016',
    'venue_manager',
    '99000000-0000-4000-8000-000000000071'
  );

insert into africlub_game.session_organizers (
  club_id,
  session_id,
  user_id,
  assigned_by
) values (
  9900001,
  '99000000-0000-4000-8000-000000000031',
  '99000000-0000-4000-8000-000000000013',
  '99000000-0000-4000-8000-000000000014'
);

insert into africlub_game.tv_devices (
  id,
  club_id,
  device_label,
  pairing_code,
  status,
  owner_user_id,
  scope_type,
  venue_id,
  app_version,
  capabilities,
  created_by
) values
  (
    '99000000-0000-4000-8000-000000000051',
    9900001,
    'Organizer Home Display',
    'ORGANIZER-DISPLAY-CODE',
    'paired',
    '99000000-0000-4000-8000-000000000013',
    'home',
    null,
    '2.0.0-contract',
    '{"resolution":"1080p","dpad":true}'::jsonb,
    '99000000-0000-4000-8000-000000000013'
  ),
  (
    '99000000-0000-4000-8000-000000000052',
    9900001,
    'Owner Home Display',
    'OWNER-DISPLAY-CODE',
    'paired',
    '99000000-0000-4000-8000-000000000015',
    'home',
    null,
    '2.0.0-contract',
    '{"resolution":"1080p"}'::jsonb,
    '99000000-0000-4000-8000-000000000015'
  ),
  (
    '99000000-0000-4000-8000-000000000053',
    9900001,
    'Managed Venue Display',
    'VENUE-DISPLAY-CODE',
    'paired',
    '99000000-0000-4000-8000-000000000019',
    'venue',
    '99000000-0000-4000-8000-000000000071',
    '2.0.0-contract',
    '{"resolution":"4k"}'::jsonb,
    '99000000-0000-4000-8000-000000000019'
  ),
  (
    '99000000-0000-4000-8000-000000000054',
    9900001,
    'Assigned Organizer Display',
    'ASSIGNED-DISPLAY-CODE',
    'paired',
    '99000000-0000-4000-8000-000000000019',
    'home',
    null,
    '2.0.0-contract',
    '{"resolution":"1080p"}'::jsonb,
    '99000000-0000-4000-8000-000000000019'
  ),
  (
    '99000000-0000-4000-8000-000000000055',
    9900002,
    'Foreign Club Display',
    'FOREIGN-DISPLAY-CODE',
    'paired',
    '99000000-0000-4000-8000-000000000019',
    'home',
    null,
    '2.0.0-contract',
    '{"resolution":"1080p"}'::jsonb,
    '99000000-0000-4000-8000-000000000019'
  );

insert into africlub_game.display_assignments (
  club_id,
  session_id,
  display_id,
  assigned_by
) values (
  9900001,
  '99000000-0000-4000-8000-000000000031',
  '99000000-0000-4000-8000-000000000054',
  '99000000-0000-4000-8000-000000000014'
);

insert into africlub_game.game_templates (
  id,
  club_id,
  template_key,
  title,
  created_by
) values (
  '99000000-0000-4000-8000-000000000061',
  9900001,
  'managed_contract_quiz',
  'Managed Contract Quiz',
  '99000000-0000-4000-8000-000000000014'
);

insert into africlub_game.questions (
  id,
  club_id,
  prompt,
  options,
  correct_option_key,
  status,
  approved_by,
  approved_at
)
select
  (
    '99000000-0000-4000-8000-' ||
    lpad((100 + ordinal)::text, 12, '0')
  )::uuid,
  9900001,
  'Managed contract question ' || ordinal::text,
  '[
    {"key": "a", "label": "Approved answer"},
    {"key": "b", "label": "Alternative answer"}
  ]'::jsonb,
  'a',
  'approved',
  '99000000-0000-4000-8000-000000000014'::uuid,
  timezone('utc', now())
from generate_series(1, 20) ordinal;

insert into africlub_game.question_packs (
  id,
  club_id,
  template_id,
  title,
  status,
  published_by,
  published_at,
  created_by
) values
  (
    '99000000-0000-4000-8000-000000000062',
    9900001,
    '99000000-0000-4000-8000-000000000061',
    'Complete Managed Contract Pack',
    'published',
    '99000000-0000-4000-8000-000000000014',
    timezone('utc', now()),
    '99000000-0000-4000-8000-000000000014'
  ),
  (
    '99000000-0000-4000-8000-000000000063',
    9900001,
    '99000000-0000-4000-8000-000000000061',
    'Incomplete Managed Contract Pack',
    'published',
    '99000000-0000-4000-8000-000000000014',
    timezone('utc', now()),
    '99000000-0000-4000-8000-000000000014'
  );

insert into africlub_game.question_pack_questions (
  pack_id,
  question_id,
  club_id,
  ordinal
)
select
  '99000000-0000-4000-8000-000000000062'::uuid,
  (
    '99000000-0000-4000-8000-' ||
    lpad((100 + ordinal)::text, 12, '0')
  )::uuid,
  9900001,
  ordinal
from generate_series(1, 20) ordinal;

insert into africlub_game.question_pack_questions (
  pack_id,
  question_id,
  club_id,
  ordinal
)
select
  '99000000-0000-4000-8000-000000000063'::uuid,
  (
    '99000000-0000-4000-8000-' ||
    lpad((100 + ordinal)::text, 12, '0')
  )::uuid,
  9900001,
  ordinal
from generate_series(1, 19) ordinal;

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000015',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000015","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;
set local role authenticated;
select ok(
  (select count(*) = 1 from africlub_game.tv_devices)
  and exists (
    select 1 from africlub_game.tv_devices
    where id = '99000000-0000-4000-8000-000000000052'
  )
  and jsonb_array_length(public.get_owned_displays_v2()->'displays') = 1,
  'a display owner can read and inventory only their authorized installation'
);
reset role;

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000016',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000016","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;
set local role authenticated;
select ok(
  (select count(*) = 1 from africlub_game.tv_devices)
  and exists (
    select 1 from africlub_game.tv_devices
    where id = '99000000-0000-4000-8000-000000000053'
  )
  and jsonb_array_length(public.get_owned_displays_v2()->'displays') = 1
  and jsonb_array_length(public.get_owned_displays_v2()->'scope_options') = 1
  and public.get_owned_displays_v2()->'scope_options'->0->>'venue_id'
    = '99000000-0000-4000-8000-000000000071'
  and public.get_owned_displays_v2()->'scope_options'->0->>'label'
    = 'Contract Venue',
  'a venue manager can manage only displays scoped to their authorized venue'
);
do $$
declare
  denied boolean := false;
begin
  begin
    perform public.update_owned_display_v2(
      '99000000-0000-4000-8000-000000000053',
      'Managed Venue Display',
      'venue',
      '99000000-0000-4000-8000-000000000072',
      'cross-club-display-move-contract-0001'
    );
  exception when others then
    denied := true;
  end;
  if not denied then
    raise exception 'cross-club venue move unexpectedly succeeded';
  end if;
end $$;
reset role;

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000013',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000013","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;
set local role authenticated;
select ok(
  (select count(*) = 2 from africlub_game.tv_devices)
  and exists (
    select 1 from africlub_game.tv_devices
    where id = '99000000-0000-4000-8000-000000000051'
  )
  and exists (
    select 1 from africlub_game.tv_devices
    where id = '99000000-0000-4000-8000-000000000054'
  ),
  'an organizer can read only owned or explicitly assigned displays'
);
reset role;

do $$
declare
  visible_count bigint;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000014',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000014","role":"authenticated","club_id":"9900001"}',
    true
  );
  set local role authenticated;
  select count(*) into visible_count from africlub_game.tv_devices;
  reset role;
  if visible_count <> 4 then
    raise exception 'club admin display scope expected 4, received %', visible_count;
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000018',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000018","role":"authenticated","club_id":"9900001"}',
    true
  );
  set local role authenticated;
  select count(*) into visible_count from africlub_game.tv_devices;
  reset role;
  if visible_count <> 5 then
    raise exception 'platform admin display scope expected 5, received %', visible_count;
  end if;
end $$;
select pass(
  'club admins remain club-scoped while platform admins retain governed cross-club access'
);

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000011',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000011","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;

select is(
  jsonb_array_length(
    public.get_eligible_game_sessions_v2(null)->'sessions'
  ),
  1,
  'an active, verified, non-expired club member discovers the eligible session'
);

select ok(
  (
    public.get_eligible_game_sessions_v2(null)
      ->'sessions'->0->>'source'
  ) = 'club_membership'
  and not (
    public.get_eligible_game_sessions_v2(null)
      ->'sessions'->0 ? 'join_code'
  )
  and (
    public.get_eligible_game_sessions_v2(null)->>'public_alias'
  ) ~ '^Supporter [0-9A-F]{6}$',
  'member discovery is code-free and returns only a deterministic public alias'
);

select throws_ok(
  $statement$
    select public.create_managed_game_session_v2(
      '99000000-0000-4000-8000-000000000062',
      timezone('utc', now()) + interval '1 hour',
      'club_membership',
      '{}'::uuid[],
      'member-plan-contract-0001'
    )
  $statement$,
  'P0001',
  'Not authorized to plan games',
  'a club member without a planning role cannot create a managed game'
);

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000012',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000012","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;

select is(
  jsonb_array_length(
    public.get_eligible_game_sessions_v2(null)->'sessions'
  ),
  0,
  'a suspended member cannot discover a club-membership session'
);

set local role authenticated;
select is(
  (
    select count(*)
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000031'
  ),
  0::bigint,
  'a participant club claim cannot bypass role-safe projections through raw tables'
);
reset role;

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000013',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000013","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;

set local role authenticated;
select ok(
  (
    select count(*) = 1
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000031'
  )
  and (
    select count(*) = 0
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000032'
  )
  and (
    select count(*) = 0
    from africlub_game.questions
    where id = '99000000-0000-4000-8000-000000000021'
  ),
  'an organizer can read only an explicitly assigned session and no raw answer content'
);
reset role;

do $$
declare
  projection jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000011',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000011","role":"authenticated","club_id":"9900001"}',
    true
  );
  projection := public.get_participant_game_projection_v2(
    '99000000-0000-4000-8000-000000000031'
  );
  if projection->'question' ? 'correct_option_key'
     or projection->>'public_alias' = 'Private Member Name'
     or projection->>'answer_state' <> 'not_answered' then
    raise exception 'pre-reveal projection disclosed private or answer material';
  end if;
end $$;
select pass('pre-reveal participant projection omits private identity and the correct answer');

select is(
  (
    public.submit_participant_answer_v2(
      '99000000-0000-4000-8000-000000000031',
      '99000000-0000-4000-8000-000000000041',
      'a',
      7,
      3,
      'answer-contract-0001'
    )->>'answer_state'
  ),
  'accepted',
  'an eligible participant answer is accepted into the authoritative projection'
);

select ok(
  (
    select count(*) = 1
    from africlub_game.answer_attempts
    where session_id = '99000000-0000-4000-8000-000000000031'
  )
  and (
    select event_sequence = 1
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000031'
  ),
  'the accepted answer records once and advances the event sequence once'
);

select ok(
  (
    public.submit_participant_answer_v2(
      '99000000-0000-4000-8000-000000000031',
      '99000000-0000-4000-8000-000000000041',
      'a',
      7,
      3,
      'answer-contract-0001'
    )->>'answer_state'
  ) = 'accepted'
  and (
    select count(*) = 1
    from africlub_game.answer_attempts
    where session_id = '99000000-0000-4000-8000-000000000031'
  )
  and (
    select event_sequence = 1
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000031'
  ),
  'an answer retry is idempotent and does not emit a duplicate event'
);

do $$
declare
  first_result jsonb;
  retry_result jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000013',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000013","role":"authenticated","club_id":"9900001"}',
    true
  );
  first_result := public.transition_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000031',
    'reveal',
    7,
    'transition-contract-0001',
    '99000000-0000-4000-8000-000000000041',
    null,
    'pgTAP lifecycle proof'
  );
  retry_result := public.transition_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000031',
    'reveal',
    7,
    'transition-contract-0001',
    '99000000-0000-4000-8000-000000000041',
    null,
    'pgTAP lifecycle proof'
  );
  if first_result <> retry_result then
    raise exception 'idempotent transition returned a different result';
  end if;
end $$;

select ok(
  (
    select session_version = 8 and event_sequence = 2
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000031'
  )
  and (
    select count(*) = 1
    from africlub_game.transition_requests
    where session_id = '99000000-0000-4000-8000-000000000031'
  )
  and (
    select count(*) = 1
    from africlub_game.audit_log
    where entity_id = '99000000-0000-4000-8000-000000000031'
      and action = 'game_session_transitioned'
  ),
  'an organizer transition is versioned, idempotent, evented, and audited once'
);

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000011',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000011","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;

select is(
  (
    public.get_participant_game_projection_v2(
      '99000000-0000-4000-8000-000000000031'
    )->'question'->>'correct_option_key'
  ),
  'a',
  'the correct answer is exposed only after the authoritative reveal transition'
);

do $$
declare
  projection jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000013',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000013","role":"authenticated","club_id":"9900001"}',
    true
  );
  projection := public.get_organizer_game_projection_v2(
    '99000000-0000-4000-8000-000000000031'
  );
  if not (projection->'allowed_actions' ? 'question_open')
     or not (projection->'allowed_actions' ? 'paused')
     or projection ? 'device_credential'
     or projection::text like '%Private Member Name%'
     or projection->>'participant_count' <> '1' then
    raise exception 'organizer projection is incomplete or privacy-unsafe';
  end if;
end $$;
select pass('assigned organizer receives safe phase controls and aggregate state');

do $$
declare
  first_result jsonb;
  retry_result jsonb;
begin
  first_result := public.assign_managed_game_display_v2(
    '99000000-0000-4000-8000-000000000031',
    '99000000-0000-4000-8000-000000000051',
    'display-assignment-contract-0001'
  );
  retry_result := public.assign_managed_game_display_v2(
    '99000000-0000-4000-8000-000000000031',
    '99000000-0000-4000-8000-000000000051',
    'display-assignment-contract-0001'
  );
  if first_result <> retry_result then
    raise exception 'display assignment retry returned a different result';
  end if;
end $$;

select ok(
  (
    select count(*) = 1
    from africlub_game.display_assignments
    where session_id = '99000000-0000-4000-8000-000000000031'
      and display_id = '99000000-0000-4000-8000-000000000051'
      and unassigned_at is null
  )
  and (
    select count(*) = 1
    from africlub_game.audit_log
    where action = 'display_assigned'
      and after_json->>'display_id' =
        '99000000-0000-4000-8000-000000000051'
  ),
  'display assignment is idempotent and audited exactly once'
);

do $$
declare
  first_result jsonb;
  retry_result jsonb;
begin
  first_result := public.unassign_managed_game_display_v2(
    '99000000-0000-4000-8000-000000000031',
    '99000000-0000-4000-8000-000000000051',
    'display-unassignment-contract-0001'
  );
  retry_result := public.unassign_managed_game_display_v2(
    '99000000-0000-4000-8000-000000000031',
    '99000000-0000-4000-8000-000000000051',
    'display-unassignment-contract-0001'
  );
  if first_result->>'status' <> 'unassigned'
     or retry_result->>'status' <> 'unassigned' then
    raise exception 'display unassignment did not converge';
  end if;
  perform public.assign_managed_game_display_v2(
    '99000000-0000-4000-8000-000000000031',
    '99000000-0000-4000-8000-000000000051',
    'display-reassignment-contract-0001'
  );
end $$;
select ok(
  (
    select count(*) = 1
    from africlub_game.audit_log
    where action = 'display_unassigned'
      and after_json->>'display_id' =
        '99000000-0000-4000-8000-000000000051'
  )
  and (
    select count(*) = 1
    from africlub_game.display_assignments
    where session_id = '99000000-0000-4000-8000-000000000031'
      and display_id = '99000000-0000-4000-8000-000000000051'
      and unassigned_at is null
  ),
  'public unassignment converges without duplicate audit and permits a governed reassignment'
);

select is(
  jsonb_array_length(
    public.get_managed_game_sessions_v2()->'sessions'
  ),
  1,
  'organizer inventory includes only explicitly assigned sessions'
);

select ok(
  jsonb_array_length(public.get_game_planner_options_v2()->'packs') = 1
  and (
    public.get_game_planner_options_v2()->'packs'->0->>'pack_id'
  ) = '99000000-0000-4000-8000-000000000062'
  and jsonb_array_length(
    public.get_game_planner_options_v2()->'displays'
  ) = 1
  and not (
    public.get_game_planner_options_v2()->'displays'->0
      ? 'device_credential'
  )
  and not (
    public.get_game_planner_options_v2()->'displays'->0
      ? 'pairing_code'
  )
  and jsonb_array_length(
    public.get_game_planner_options_v2()->'invitees'
  ) = 1
  and (
    public.get_game_planner_options_v2()->'invitees'->0->>'public_user_id'
  ) ~ '^[0-9]{6}$'
  and not (
    public.get_game_planner_options_v2()->'invitees'->0 ? 'phone'
  )
  and not (
    public.get_game_planner_options_v2()->'invitees'->0 ? 'full_name'
  ),
  'planner options expose complete packs, authorized credential-free displays, and one active privacy-safe Fan-ID invitee'
);

select throws_ok(
  $statement$
    select public.create_managed_game_session_v2(
      '99000000-0000-4000-8000-000000000063',
      timezone('utc', now()) + interval '1 hour',
      'club_membership',
      '{}'::uuid[],
      'invalid-pack-contract-0001'
    )
  $statement$,
  'P0001',
  'Published question pack must contain exactly 20 questions',
  'an organizer cannot schedule an incomplete question pack'
);

select throws_ok(
  $statement$
    select public.create_managed_game_session_v2(
      '99000000-0000-4000-8000-000000000062',
      timezone('utc', now()) + interval '1 hour',
      'invitation_only',
      '{}'::uuid[],
      'missing-invitee-contract-0001'
    )
  $statement$,
  'P0001',
  'Invitation-only sessions require at least one supporter',
  'an invitation-only session fails closed without an eligible supporter'
);

select throws_ok(
  $statement$
    select public.create_managed_game_session_v2(
      '99000000-0000-4000-8000-000000000062',
      timezone('utc', now()) + interval '1 hour',
      'invitation_only',
      '{}'::uuid[],
      'suspended-invitee-contract-0001',
      '{}'::uuid[],
      array['99000000-0000-4000-8000-000000000012'::uuid]
    )
  $statement$,
  'P0001',
  'Selected invitee is not an eligible club supporter',
  'a suspended supporter cannot be invited to a managed game'
);

create temp table live_games_v2_invited_session_state (
  session_id uuid not null
) on commit drop;

do $$
declare
  result jsonb;
begin
  result := public.create_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000062',
    timezone('utc', now()) + interval '1 hour',
    'invitation_only',
    '{}'::uuid[],
    'invited-session-contract-0001',
    '{}'::uuid[],
    array['99000000-0000-4000-8000-000000000011'::uuid]
  );
  insert into live_games_v2_invited_session_state (session_id)
  values ((result->>'session_id')::uuid);
end $$;
select ok(
  (
    select eligibility_scope = 'invitation_only'
    from africlub_game.game_sessions
    where id = (
      select session_id from live_games_v2_invited_session_state
    )
  )
  and (
    select count(*) = 1
    from africlub_game.session_invitations
    where session_id = (
      select session_id from live_games_v2_invited_session_state
    )
      and user_id = '99000000-0000-4000-8000-000000000011'
      and revoked_at is null
  )
  and (
    select count(*) = 1
    from africlub_game.session_eligibility
    where session_id = (
      select session_id from live_games_v2_invited_session_state
    )
      and scope_type = 'invitation'
      and scope_id = '99000000-0000-4000-8000-000000000011'
  )
  and (
    select after_json->>'invitee_count' = '1'
    from africlub_game.audit_log
    where action = 'managed_game_session_created'
      and entity_id = (
        select session_id from live_games_v2_invited_session_state
      )
  ),
  'an organizer creates one audited invitation-only session for an active Fan ID'
);

create temp table live_games_v2_managed_session_state (
  session_id uuid not null
) on commit drop;

do $$
declare
  first_result jsonb;
  retry_result jsonb;
begin
  first_result := public.create_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000062',
    timezone('utc', now()) + interval '1 hour',
    'club_membership',
    '{}'::uuid[],
    'managed-session-contract-0001'
  );
  retry_result := public.create_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000062',
    timezone('utc', now()) + interval '2 hours',
    'club_membership',
    '{}'::uuid[],
    'managed-session-contract-0001'
  );
  if first_result <> retry_result then
    raise exception 'managed session retry returned a different result';
  end if;
  insert into live_games_v2_managed_session_state (session_id)
  values ((first_result->>'session_id')::uuid);
end $$;
select pass('managed session creation is idempotent for one organizer operation');

select ok(
  (
    select lifecycle_phase = 'scheduled'
      and eligibility_scope = 'club_membership'
      and pack_id = '99000000-0000-4000-8000-000000000062'
    from africlub_game.game_sessions
    where id = (
      select session_id from live_games_v2_managed_session_state
    )
  )
  and (
    select count(*) = 20
    from africlub_game.session_questions
    where session_id = (
      select session_id from live_games_v2_managed_session_state
    )
  )
  and (
    select count(*) = 1
    from africlub_game.session_organizers
    where session_id = (
      select session_id from live_games_v2_managed_session_state
    )
      and user_id = '99000000-0000-4000-8000-000000000013'
      and revoked_at is null
  )
  and (
    select count(*) = 1
    from africlub_game.session_eligibility
    where session_id = (
      select session_id from live_games_v2_managed_session_state
    )
      and scope_type = 'club_membership'
  )
  and (
    select count(*) = 1
    from africlub_game.audit_log
    where action = 'managed_game_session_created'
      and entity_id = (
        select session_id from live_games_v2_managed_session_state
      )
  ),
  'managed planning creates exactly 20 questions, organizer ownership, eligibility, and audit evidence'
);

select is(
  jsonb_array_length(
    public.get_managed_game_sessions_v2()->'sessions'
  ),
  3,
  'managed inventory includes both newly planned sessions exactly once'
);

do $$
declare
  v_installation_nonce text :=
    'reviewer-installation-nonce-contract-00000001';
  v_display_id uuid;
  v_device_token text;
  v_session_id uuid;
  v_first_question_id uuid;
  v_second_question_id uuid;
  pairing jsonb;
  claimed jsonb;
  exchanged jsonb;
  owned_inventory jsonb;
  planner_options jsonb;
  created jsonb;
  lobby jsonb;
  opened jsonb;
  revealed jsonb;
  advanced jsonb;
  tv_projection jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000013',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000013","role":"authenticated","club_id":"9900001"}',
    true
  );

  pairing := public.create_display_pairing_challenge_v2(
    v_installation_nonce,
    '2.0.0-contract',
    '{"platform":"android_tv","projection_version":2}'::jsonb
  );
  claimed := public.claim_display_bootstrap_challenge_v2(
    pairing->>'challenge',
    'Synthetic Reviewer Home Display',
    'home',
    null
  );
  exchanged := public.exchange_display_pairing_challenge_v2(
    pairing->>'challenge',
    v_installation_nonce
  );
  v_display_id := (claimed->>'display_id')::uuid;
  v_device_token := exchanged->>'device_credential';
  owned_inventory := public.get_owned_displays_v2();
  planner_options := public.get_game_planner_options_v2();

  if pairing->>'status' <> 'pending_owner_claim'
     or claimed->>'status' <> 'claimed'
     or exchanged->>'status' <> 'paired'
     or length(v_device_token) <> 64
     or not exists (
       select 1
       from jsonb_array_elements(owned_inventory->'displays') owned_display
       where owned_display->>'display_id' = v_display_id::text
     )
     or not exists (
       select 1
       from jsonb_array_elements(planner_options->'displays') planner_display
       where planner_display->>'display_id' = v_display_id::text
     )
     or not exists (
       select 1
       from jsonb_array_elements(planner_options->'packs') planner_pack
       where planner_pack->>'pack_id' =
         '99000000-0000-4000-8000-000000000062'
     )
     or not exists (
       select 1
       from africlub_game.tv_devices display
       where display.id = v_display_id
         and display.owner_user_id =
           '99000000-0000-4000-8000-000000000013'::uuid
         and display.scope_type = 'home'
     )
     or not exists (
       select 1
       from public.fan_memberships membership
       where membership.user_id =
           '99000000-0000-4000-8000-000000000013'::uuid
         and membership.club_id = 9900001
         and membership.status = 'active'
         and membership.payment_status = 'verified'::public.payment_status
         and membership.expires_at > timezone('utc', now())
     )
     or not africlub_game.has_role(9900001, 'game_organizer', null)
     or exists (
       select 1
       from public.admin_role_assignments admin_grant
       where admin_grant.user_id =
         '99000000-0000-4000-8000-000000000013'::uuid
     )
     or exists (
       select 1
       from public.venue_staff_memberships venue_membership
       where venue_membership.user_id =
         '99000000-0000-4000-8000-000000000013'::uuid
         and venue_membership.is_active
     )
     or exists (
       select 1
       from africlub_game.role_grants role_grant
       where role_grant.user_id =
         '99000000-0000-4000-8000-000000000013'::uuid
         and role_grant.revoked_at is null
         and role_grant.role_key not in ('game_organizer', 'display_owner')
     ) then
    raise exception 'least-privilege reviewer could not claim its home display';
  end if;

  created := public.create_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000062',
    timezone('utc', now()) + interval '1 hour',
    'home_owner',
    array[v_display_id],
    'reviewer-session-contract-0001'
  );
  v_session_id := (created->>'session_id')::uuid;

  select session_question.id into v_first_question_id
  from africlub_game.session_questions session_question
  where session_question.session_id = v_session_id
  order by session_question.ordinal, session_question.id
  limit 1;
  select session_question.id into v_second_question_id
  from africlub_game.session_questions session_question
  where session_question.session_id = v_session_id
    and session_question.ordinal > 1
  order by session_question.ordinal, session_question.id
  limit 1;

  if created->'current_question_control'->>'id' <> v_first_question_id::text
     or not exists (
       select 1
       from africlub_game.game_sessions session_row
       where session_row.id = v_session_id
         and session_row.current_session_question_id = v_first_question_id
     )
     or not exists (
       select 1
       from africlub_game.display_assignments assignment
       where assignment.session_id = v_session_id
         and assignment.display_id = v_display_id
         and assignment.unassigned_at is null
     ) then
    raise exception 'reviewer session did not initialize and assign atomically';
  end if;

  tv_projection := public.get_tv_game_projection_v2(v_device_token);
  if tv_projection->>'phase' <> 'scheduled'
     or tv_projection->'question' <> 'null'::jsonb then
    raise exception 'scheduled TV projection exposed queued question content: %', tv_projection;
  end if;

  lobby := public.transition_managed_game_session_v2(
    v_session_id,
    'activated_lobby',
    (created->>'session_version')::bigint,
    'reviewer-lobby-contract-0001',
    v_first_question_id,
    null,
    null
  );
  tv_projection := public.get_tv_game_projection_v2(v_device_token);
  if tv_projection->>'phase' <> 'activated_lobby'
     or tv_projection->'question' <> 'null'::jsonb then
    raise exception 'lobby TV projection exposed queued question content: %', tv_projection;
  end if;

  opened := public.transition_managed_game_session_v2(
    v_session_id,
    'question_open',
    (lobby->>'session_version')::bigint,
    'reviewer-open-first-contract-0001',
    v_first_question_id,
    timezone('utc', now()) + interval '30 seconds',
    null
  );
  tv_projection := public.get_tv_game_projection_v2(v_device_token);
  if opened->'current_question_control'->>'id' <> v_first_question_id::text
     or tv_projection->>'phase' <> 'question_open'
     or tv_projection->'question'->>'id' <> v_first_question_id::text then
    raise exception 'first question did not open on the assigned TV: %', tv_projection;
  end if;

  revealed := public.transition_managed_game_session_v2(
    v_session_id,
    'reveal',
    (opened->>'session_version')::bigint,
    'reviewer-reveal-first-contract-0001',
    v_first_question_id,
    null,
    null
  );
  advanced := public.transition_managed_game_session_v2(
    v_session_id,
    'question_open',
    (revealed->>'session_version')::bigint,
    'reviewer-open-next-contract-0001',
    v_first_question_id,
    timezone('utc', now()) + interval '30 seconds',
    null
  );
  tv_projection := public.get_tv_game_projection_v2(v_device_token);
  if advanced->'current_question_control'->>'id' <> v_second_question_id::text
     or tv_projection->>'phase' <> 'question_open'
     or tv_projection->'question'->>'id' <> v_second_question_id::text then
    raise exception 'legacy reveal payload did not advance to question two: %', tv_projection;
  end if;

end $$;
select pass(
  'least-privilege reviewer claims and assigns its display, hides queued content, opens question one, and advances to question two with the frozen mobile payload'
);

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000011',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000011","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;
select throws_ok(
  $statement$
    select public.transition_managed_game_session_v2(
      '99000000-0000-4000-8000-000000000031',
      'question_open',
      8,
      'unauthorized-next-contract-0001',
      '99000000-0000-4000-8000-000000000041',
      timezone('utc', now()) + interval '30 seconds',
      null
    )
  $statement$,
  'P0001',
  'Not authorized to control this game session',
  'legacy next-question normalization does not reveal session state to an unauthorized member'
);
do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000013',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000013","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;

do $$
declare
  paused_result jsonb;
begin
  paused_result := public.transition_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000031',
    'paused',
    8,
    'transition-pause-contract-0001',
    '99000000-0000-4000-8000-000000000041',
    null,
    'pause contract proof'
  );
  if paused_result->>'phase' <> 'paused' then
    raise exception 'pause transition did not return paused state';
  end if;
end $$;
select ok(
  (
    select lifecycle_phase = 'paused'
      and paused_from_phase = 'reveal'
      and session_version = 9
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000031'
  ),
  'pause records the exact authoritative phase required for safe resume'
);

do $$
declare
  resumed_result jsonb;
begin
  resumed_result := public.transition_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000031',
    'reveal',
    9,
    'transition-resume-contract-0001',
    '99000000-0000-4000-8000-000000000041',
    null,
    'resume contract proof'
  );
  if resumed_result->>'phase' <> 'reveal' then
    raise exception 'resume transition did not restore reveal state';
  end if;
end $$;
select ok(
  (
    select lifecycle_phase = 'reveal'
      and paused_from_phase is null
      and session_version = 10
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000031'
  ),
  'resume restores the exact pre-pause phase and clears recovery metadata'
);

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000014',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000014","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;

select throws_ok(
  $statement$
    select public.assign_managed_game_display_v2(
      '99000000-0000-4000-8000-000000000032',
      '99000000-0000-4000-8000-000000000051',
      'display-conflict-contract-0001'
    )
  $statement$,
  'P0001',
  'Display is assigned to another active game session',
  'one display cannot be assigned to two active sessions'
);

do $$
declare
  projection jsonb;
begin
  projection := public.get_admin_game_projection_v2(
    '99000000-0000-4000-8000-000000000031'
  );
  if projection ? 'device_credential'
     or projection::text like '%Private Member Name%'
     or not (projection ? 'audit_summary')
     or not (projection ? 'participant_aggregate')
     or not (projection ? 'projection_previews') then
    raise exception 'admin projection is incomplete or privacy-unsafe';
  end if;
end $$;
select pass('admin projection adds audit and cross-surface aggregates without private identity');

select ok(
  jsonb_array_length(public.get_managed_game_sessions_v2()->'sessions') > 0
  and not exists (
    select 1
    from jsonb_array_elements(
      public.get_managed_game_sessions_v2()->'sessions'
    ) as managed_session
    where not (managed_session ? 'participant_aggregate')
      or not (managed_session ? 'projection_previews')
      or managed_session ? 'device_credential'
      or managed_session::text like '%Private Member Name%'
  ),
  'admin managed inventory includes privacy-safe participant and TV previews'
);

insert into africlub_game.session_questions (
  id,
  club_id,
  session_id,
  question_id,
  ordinal,
  state
) values
  (
    '99000000-0000-4000-8000-000000000042',
    9900001,
    '99000000-0000-4000-8000-000000000031',
    '99000000-0000-4000-8000-000000000101',
    2,
    'queued'
  ),
  (
    '99000000-0000-4000-8000-000000000043',
    9900001,
    '99000000-0000-4000-8000-000000000031',
    '99000000-0000-4000-8000-000000000102',
    3,
    'queued'
  );

do $$
declare
  opened_result jsonb;
  skipped_result jsonb;
  retry_result jsonb;
  action_projection jsonb;
begin
  opened_result := public.transition_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000031',
    'question_open',
    10,
    'transition-next-contract-0001',
    '99000000-0000-4000-8000-000000000042',
    null,
    'normal next-question progression'
  );
  action_projection := public.get_organizer_game_projection_v2(
    '99000000-0000-4000-8000-000000000031'
  );
  if not (action_projection->'allowed_actions' ? 'skip_question')
     or not (action_projection->'allowed_actions' ? 'end_early') then
    raise exception 'question-open projection omitted exception actions';
  end if;
  skipped_result := public.skip_managed_game_question_v2(
    '99000000-0000-4000-8000-000000000031',
    '99000000-0000-4000-8000-000000000043',
    (opened_result->>'session_version')::bigint,
    'transition-skip-contract-0001',
    'question withdrawn by organizer'
  );
  retry_result := public.skip_managed_game_question_v2(
    '99000000-0000-4000-8000-000000000031',
    '99000000-0000-4000-8000-000000000043',
    (opened_result->>'session_version')::bigint,
    'transition-skip-contract-0001',
    'question withdrawn by organizer'
  );
  if skipped_result <> retry_result then
    raise exception 'skip retry returned a different result';
  end if;
end $$;
select ok(
  (
    select lifecycle_phase = 'question_open'
      and current_session_question_id = '99000000-0000-4000-8000-000000000043'
      and session_version = 12
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000031'
  )
  and (
    select state = 'closed' and closed_at is not null
    from africlub_game.session_questions
    where id = '99000000-0000-4000-8000-000000000042'
  )
  and (
    select count(*) = 1
    from africlub_game.transition_requests
    where session_id = '99000000-0000-4000-8000-000000000031'
      and idempotency_key = 'transition-skip-contract-0001'
  ),
  'reasoned skip closes the current question, opens a different question, and is idempotent'
);

do $$
declare
  ended_result jsonb;
  retry_result jsonb;
begin
  ended_result := public.end_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000031',
    12,
    'transition-end-contract-0001',
    'venue evacuation'
  );
  retry_result := public.end_managed_game_session_v2(
    '99000000-0000-4000-8000-000000000031',
    12,
    'transition-end-contract-0001',
    'venue evacuation'
  );
  if ended_result <> retry_result then
    raise exception 'end retry returned a different result';
  end if;
end $$;
select ok(
  (
    select lifecycle_phase = 'completed'
      and session_version = 13
      and ended_at is not null
    from africlub_game.game_sessions
    where id = '99000000-0000-4000-8000-000000000031'
  )
  and (
    select count(*) = 1
    from africlub_game.transition_requests
    where session_id = '99000000-0000-4000-8000-000000000031'
      and idempotency_key = 'transition-end-contract-0001'
  )
  and (
    select count(*) = 1
    from africlub_game.audit_log
    where entity_id = '99000000-0000-4000-8000-000000000031'
      and action = 'game_session_transitioned'
      and reason = 'end: venue evacuation'
  ),
  'reasoned early end completes the session with one attributable audit event'
);

create temp table live_games_v2_pairing_state (
  challenge text not null,
  qr_payload text not null,
  installation_nonce text not null,
  display_id uuid,
  credential text
) on commit drop;
grant select, update on live_games_v2_pairing_state to authenticated;

insert into live_games_v2_pairing_state (
  challenge,
  qr_payload,
  installation_nonce
)
select
  result->>'challenge',
  result->>'qr_payload',
  'installation-nonce-contract-0000000000000001'
from (
  select public.create_display_pairing_challenge_v2(
    'installation-nonce-contract-0000000000000001',
    '2.0.0-contract',
    '{"resolution":"1080p","dpad":true}'::jsonb
  ) result
) created;

select ok(
  (
    select public.exchange_display_pairing_challenge_v2(
      challenge,
      installation_nonce
    )->>'status' = 'pending_owner_claim'
      and qr_payload = 'africlub://my-tvs/pair?challenge=' || challenge
    from live_games_v2_pairing_state
  )
  and exists (
    select 1
    from africlub_game.display_bootstrap_challenges bootstrap
    join live_games_v2_pairing_state state
      on bootstrap.challenge_hash = encode(
        digest(state.challenge, 'sha256'),
        'hex'
      )
    where bootstrap.challenge_hash <> state.challenge
      and bootstrap.consumed_at is null
      and bootstrap.expires_at > timezone('utc', now())
      and bootstrap.expires_at <= timezone('utc', now()) + interval '8 minutes'
  ),
  'unpaired TV challenge is hashed, short-lived, deep-linked, and pending until owner claim'
);

do $$
declare
  claimed jsonb;
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000011',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000011","role":"authenticated","club_id":"9900001"}',
    true
  );
  select public.claim_display_bootstrap_challenge_v2(
    challenge,
    'Member Home Display',
    'home',
    null
  ) into claimed
  from live_games_v2_pairing_state;
  update live_games_v2_pairing_state
  set display_id = (claimed->>'display_id')::uuid;
end $$;

select ok(
  jsonb_array_length(public.get_owned_displays_v2()->'displays') = 1
  and (
    public.get_owned_displays_v2()->'displays'->0->>'display_name'
  ) = 'Member Home Display'
  and (
    public.get_owned_displays_v2()->'displays'->0->>'app_version'
  ) = '2.0.0-contract'
  and (
    public.get_owned_displays_v2()->'displays'->0->'capabilities'
  ) @> '{"resolution":"1080p","dpad":true}'::jsonb
  and public.get_owned_displays_v2()->'displays'->0 ? 'last_seen_at'
  and public.get_owned_displays_v2()->'displays'->0 ? 'assigned_session'
  and not (
    public.get_owned_displays_v2()->'displays'->0 ? 'device_credential'
  )
  and not (
    public.get_owned_displays_v2()->'displays'->0 ? 'pairing_code'
  ),
  'owner claim creates a complete scoped inventory item without pairing or credential material'
);

do $$
declare
  exchanged jsonb;
  replayed jsonb;
begin
  select public.exchange_display_pairing_challenge_v2(
    challenge,
    installation_nonce
  ) into exchanged
  from live_games_v2_pairing_state;
  select public.exchange_display_pairing_challenge_v2(
    challenge,
    installation_nonce
  ) into replayed
  from live_games_v2_pairing_state;
  if exchanged->>'status' <> 'paired'
     or length(exchanged->>'device_credential') <> 64
     or replayed->>'code' <> 'credential_already_issued' then
    raise exception 'TV credential exchange was not one-time and bounded';
  end if;
  update live_games_v2_pairing_state
  set credential = exchanged->>'device_credential';
end $$;
select pass('TV receives one revocable credential exactly once after owner claim');

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000020',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000020","role":"authenticated","club_id":"9900001","is_anonymous":true}',
    true
  );
end $$;
set local role authenticated;
do $$
declare
  bound jsonb;
  invalid jsonb;
begin
  select public.bind_tv_realtime_identity_v2(credential)
  into bound
  from live_games_v2_pairing_state;
  select public.bind_tv_realtime_identity_v2(repeat('f', 64))
  into invalid;
  if bound->>'status' <> 'ready'
     or bound->>'authorization' <> 'assigned_session_events_only'
     or invalid->>'code' <> 'credential_revoked_or_invalid' then
    raise exception 'TV Realtime identity binding did not fail closed';
  end if;
end $$;
reset role;

select ok(
  (
    select device_auth_user_id =
      '99000000-0000-4000-8000-000000000020'::uuid
    from africlub_game.tv_devices
    where id = (
      select display_id from live_games_v2_pairing_state
    )
  )
  and (
    select count(*) = 1
    from africlub_game.audit_log
    where action = 'tv_realtime_identity_bound'
      and entity_id = (
        select display_id from live_games_v2_pairing_state
      )
  ),
  'native TV Realtime identity is bound only through a valid device credential'
);

do $$
declare
  projection jsonb;
begin
  insert into africlub_game.display_assignments (
    club_id,
    session_id,
    display_id,
    assigned_by
  )
  select
    9900001,
    '99000000-0000-4000-8000-000000000031',
    display_id,
    '99000000-0000-4000-8000-000000000014'
  from live_games_v2_pairing_state
  on conflict (session_id, display_id) where unassigned_at is null do nothing;

  update africlub_game.game_sessions
  set lifecycle_phase = 'completed',
      status = 'complete',
      ended_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = '99000000-0000-4000-8000-000000000031';

  select public.get_tv_game_projection_v2(credential)
  into projection
  from live_games_v2_pairing_state;

  if projection->>'status' <> 'ready'
     or projection->>'phase' <> 'completed'
     or projection->'allowed_actions' <> '["retry_projection"]'::jsonb
     or projection->'freshness'->>'state' <> 'current'
     or nullif(projection->'freshness'->>'last_event_at', '') is null
     or projection->'question'->>'correct_option_key' <> 'a'
     or jsonb_array_length(projection->'leaderboard') < 1
     or projection ? 'device_credential'
     or projection::text like '%Private Member Name%' then
    raise exception
      'terminal TV projection is incomplete or privacy-unsafe: %',
      projection;
  end if;
end $$;
select pass(
  'completed TV projection remains visible briefly with reveal-safe answer and public leaderboard'
);

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000020',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000020","role":"authenticated","club_id":"9900001","is_anonymous":true}',
    true
  );
end $$;
set local role authenticated;
select ok(
  (select count(*) > 0 from africlub_game.game_events)
  and (
    select count(distinct session_id) = 1
      and bool_and(
        session_id = '99000000-0000-4000-8000-000000000031'
      )
    from africlub_game.game_events
  ),
  'a bound native TV reads only its actively assigned session events'
);
reset role;

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000019',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000019","role":"authenticated","club_id":"9900001","is_anonymous":true}',
    true
  );
end $$;
set local role authenticated;
select is(
  (
    select public.bind_tv_realtime_identity_v2(credential)->>'code'
    from live_games_v2_pairing_state
  ),
  'identity_already_bound',
  'a different authenticated identity cannot take over a bound TV credential'
);
reset role;

do $$
declare
  projection jsonb;
begin
  update africlub_game.game_sessions
  set ended_at = timezone('utc', now()) - interval '31 minutes',
      updated_at = timezone('utc', now()) - interval '31 minutes'
  where id = '99000000-0000-4000-8000-000000000031';

  select public.get_tv_game_projection_v2(credential)
  into projection
  from live_games_v2_pairing_state;

  if projection->>'status' <> 'empty' then
    raise exception 'expired terminal TV projection did not clear';
  end if;

  update africlub_game.game_sessions
  set lifecycle_phase = 'reveal',
      status = 'live',
      ended_at = null,
      updated_at = timezone('utc', now())
  where id = '99000000-0000-4000-8000-000000000031';
end $$;
select pass('terminal TV projection clears after the bounded thirty-minute window');

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000011',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000011","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;

do $$
declare
  v_display_id uuid;
  first_update jsonb;
  retry_update jsonb;
  first_revoke jsonb;
  retry_revoke jsonb;
  recovery_challenge jsonb;
  first_recovery jsonb;
  retry_recovery jsonb;
  recovered_credential jsonb;
begin
  select display_id into v_display_id
  from live_games_v2_pairing_state;
  first_update := public.update_owned_display_v2(
    v_display_id,
    'Living Room Display',
    'home',
    null,
    'display-update-contract-0001'
  );
  retry_update := public.update_owned_display_v2(
    v_display_id,
    'Living Room Display',
    'home',
    null,
    'display-update-contract-0001'
  );
  first_revoke := public.revoke_owned_display_v2(
    v_display_id,
    'display-revoke-contract-0001'
  );
  retry_revoke := public.revoke_owned_display_v2(
    v_display_id,
    'display-revoke-contract-0001'
  );
  recovery_challenge := public.create_display_pairing_challenge_v2(
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    '2.1.0-recovered',
    '{"resolution":"4k","dpad":true}'::jsonb
  );
  first_recovery := public.recover_owned_display_from_bootstrap_v2(
    v_display_id,
    recovery_challenge->>'challenge',
    'display-recovery-contract-0001'
  );
  retry_recovery := public.recover_owned_display_from_bootstrap_v2(
    v_display_id,
    recovery_challenge->>'challenge',
    'display-recovery-contract-0001'
  );
  recovered_credential := public.exchange_display_pairing_challenge_v2(
    recovery_challenge->>'challenge',
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
  );
  if first_update <> retry_update
     or first_revoke <> retry_revoke
     or first_recovery <> retry_recovery
     or recovered_credential->>'status' <> 'paired' then
    raise exception 'owner display mutation retry returned different results';
  end if;
end $$;

select ok(
  (
    select status = 'paired'
      and credential_revoked_at is null
      and credential_token_hash is not null
      and device_label = 'Living Room Display'
      and app_version = '2.1.0-recovered'
      and capabilities = '{"resolution":"4k","dpad":true}'::jsonb
    from africlub_game.tv_devices
    where id = (
      select display_id from live_games_v2_pairing_state
    )
  )
  and (
    select count(*) = 1
    from africlub_game.audit_log
    where action = 'display_updated'
      and entity_id = (
        select display_id from live_games_v2_pairing_state
      )
  )
  and (
    select count(*) = 1
    from africlub_game.audit_log
    where action = 'display_revoked'
      and entity_id = (
        select display_id from live_games_v2_pairing_state
      )
  )
  and (
    select count(*) = 1
    from africlub_game.audit_log
    where action = 'display_recovery_started'
      and entity_id = (
        select display_id from live_games_v2_pairing_state
      )
  )
  and not exists (
    select 1
    from africlub_game.display_assignments
    where display_id = (
      select display_id from live_games_v2_pairing_state
    )
      and unassigned_at is null
  ),
  'owner rename, revocation, and credential recovery are idempotent and audited once'
);

select ok(
  to_regprocedure(
    'africlub_game.admin_publish_question_pack(bigint,text,uuid[],text,uuid,text)'
  ) is not null,
  'pack publication requires the exact reviewed-preview fingerprint'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'africlub_game.admin_publish_question_pack(bigint,text,uuid[],text,uuid)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'africlub_game.admin_publish_question_pack(bigint,text,uuid[],text,uuid,text)',
    'EXECUTE'
  ),
  'the legacy no-preview publication RPC is revoked and the guarded RPC is service-only'
);

select ok(
  pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_publish_question_pack(bigint,text,uuid[],text,uuid,text)'
    )
  ) like '%all pack questions must retain source evidence%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_publish_question_pack(bigint,text,uuid[],text,uuid,text)'
    )
  ) like '%mobile and TV publication previews must be reviewed%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_publish_question_pack(bigint,text,uuid[],text,uuid,text)'
    )
  ) like '%digest(%',
  'pack publication verifies source completeness and the exact preview fingerprint'
);

select ok(
  pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer)'
    )
  ) like '%generationMode%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer)'
    )
  ) like '%reviewerName%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer)'
    )
  ) like '%qaChecks%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer)'
    )
  ) not like '%correct_option_key%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer)'
    )
  ) not like '%''options''%',
  'draft projection exposes provenance and QA without answer-bearing content'
);

select ok(
  exists (
    select 1
    from pg_trigger trigger_row
    join pg_class table_row on table_row.oid = trigger_row.tgrelid
    join pg_namespace schema_row on schema_row.oid = table_row.relnamespace
    where schema_row.nspname = 'africlub_game'
      and table_row.relname = 'question_drafts'
      and trigger_row.tgname = 'question_drafts_require_human_review'
      and not trigger_row.tgisinternal
  )
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.enforce_question_draft_pending_review()'
    )
  ) like '%new.validation_status := ''pending_review''%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.enforce_question_draft_pending_review()'
    )
  ) like '%new.reviewed_by := null%',
  'draft insertion cannot bypass pending human review'
);

select ok(
  to_regprocedure(
    'africlub_game.evaluate_question_draft_checks(uuid)'
  ) is not null
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.evaluate_question_draft_checks(uuid)'
    )
  ) like '%ambiguitySignalsAbsent%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.evaluate_question_draft_checks(uuid)'
    )
  ) like '%answerConsistent%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.evaluate_question_draft_checks(uuid)'
    )
  ) like '%languageSupported%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.evaluate_question_draft_checks(uuid)'
    )
  ) like '%policyCompliant%',
  'draft QA evaluates deterministic ambiguity, answer, language, and policy checks'
);

select ok(
  pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_review_question_draft(uuid,text,text)'
    )
  ) like '%draft approval blocked by deterministic checks%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_review_question_draft(uuid,text,text)'
    )
  ) like '%last_review_checks%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer)'
    )
  ) like '%citationFragment%'
  and pg_get_functiondef(
    to_regprocedure(
      'africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer)'
    )
  ) like '%schemaVersion%',
  'approval fails closed and preserves attributable checks, citation, and schema provenance'
);

create temp table live_games_v2_tv_revocation_state (
  identity_cleared boolean not null
) on commit drop;
grant select on live_games_v2_tv_revocation_state to authenticated;
insert into live_games_v2_tv_revocation_state (identity_cleared)
select device_auth_user_id is null
from africlub_game.tv_devices
where id = (
  select display_id from live_games_v2_pairing_state
);

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000020',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000020","role":"authenticated","club_id":"9900001","is_anonymous":true}',
    true
  );
end $$;
set local role authenticated;
select ok(
  (select identity_cleared from live_games_v2_tv_revocation_state)
  and (select count(*) = 0 from africlub_game.game_events),
  'revoking a TV credential clears its Realtime identity and event access'
);
reset role;

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000015',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000015","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;
set local role authenticated;
select is(
  (select count(*) from africlub_game.game_events),
  0::bigint,
  'an unrelated display owner cannot subscribe to game-session invalidation events'
);
reset role;

do $$
begin
  perform set_config(
    'request.jwt.claim.sub',
    '99000000-0000-4000-8000-000000000011',
    true
  );
  perform set_config(
    'request.jwt.claims',
    '{"sub":"99000000-0000-4000-8000-000000000011","role":"authenticated","club_id":"9900001"}',
    true
  );
end $$;
set local role authenticated;
select ok(
  (select count(*) > 0 from africlub_game.game_events)
  and (
    select count(distinct session_id) = 1
      and bool_and(
        session_id = '99000000-0000-4000-8000-000000000031'
      )
    from africlub_game.game_events
  ),
  'a participant subscribes only to invalidation events for their joined session'
);
reset role;

select ok(
  (
    select count(*) > 0
      and bool_and(
        topic = club_id::text || ':game_session:' || session_id::text
      )
      and bool_and(event_type = 'projection_invalidated')
      and bool_and(payload->>'requires_projection_refresh' = 'true')
      and bool_and(
        not payload ? 'correct_option_key'
        and not payload ? 'phone'
        and not payload ? 'email'
        and not payload ? 'display_name'
      )
    from africlub_game.game_events
  ),
  'runtime events are club-scoped privacy-safe hints that require snapshot reconciliation'
);

select * from finish();

rollback;

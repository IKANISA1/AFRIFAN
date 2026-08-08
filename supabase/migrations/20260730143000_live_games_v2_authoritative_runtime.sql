-- AFRICLUB Live Games V2 authoritative runtime.
--
-- Product defaults are deliberately narrow and fail closed:
--   * one session may target several explicitly assigned displays;
--   * home displays are owner/invitation scoped, never implicitly club-wide;
--   * venue managers operate assigned displays and require an explicit
--     organizer grant to control a game;
--   * participant identity is the authenticated AFRICLUB account projected
--     through a session-safe public alias;
--   * synchronized trivia state is in scope; no video-programme pipeline is
--     inferred.
--
-- This migration is additive. The legacy join-code RPC remains available as a
-- rollback path until the code-free participant client and release evidence
-- are complete.

begin;

alter table africlub_game.tv_devices
  add column if not exists owner_user_id uuid references auth.users(id) on delete set null,
  add column if not exists scope_type text not null default 'home',
  add column if not exists venue_id uuid references public.venues(id) on delete set null,
  add column if not exists app_version text,
  add column if not exists capabilities jsonb not null default '{}'::jsonb;

update africlub_game.tv_devices
set venue_id = (metadata->>'venue_id')::uuid
where venue_id is null
  and nullif(metadata->>'venue_id', '') ~*
    '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

update africlub_game.tv_devices
set owner_user_id = coalesce(owner_user_id, created_by),
    scope_type = case when venue_id is not null then 'venue' else 'home' end
where owner_user_id is null
   or scope_type not in ('home', 'venue')
   or (venue_id is not null and scope_type <> 'venue');

alter table africlub_game.tv_devices
  drop constraint if exists tv_devices_scope_type_check;
alter table africlub_game.tv_devices
  add constraint tv_devices_scope_type_check
  check (
    scope_type in ('home', 'venue')
    and (scope_type <> 'venue' or venue_id is not null)
  );

alter table africlub_game.tv_devices
  drop constraint if exists tv_devices_app_version_check;
alter table africlub_game.tv_devices
  add constraint tv_devices_app_version_check
  check (
    app_version is null
    or length(btrim(app_version)) between 1 and 80
  );

alter table africlub_game.tv_devices
  drop constraint if exists tv_devices_capabilities_check;
alter table africlub_game.tv_devices
  add constraint tv_devices_capabilities_check
  check (
    jsonb_typeof(capabilities) = 'object'
    and octet_length(capabilities::text) <= 2048
  );

alter table africlub_game.game_sessions
  add column if not exists lifecycle_phase text,
  add column if not exists session_version bigint not null default 0,
  add column if not exists question_version bigint not null default 0,
  add column if not exists event_sequence bigint not null default 0,
  add column if not exists phase_deadline timestamptz,
  add column if not exists paused_from_phase text,
  add column if not exists eligibility_scope text not null default 'club_membership';

update africlub_game.game_sessions
set lifecycle_phase = case status
  when 'draft' then 'draft'
  when 'scheduled' then 'scheduled'
  when 'lobby' then 'activated_lobby'
  when 'live' then case
    when exists (
      select 1
      from africlub_game.session_questions sq
      where sq.id = game_sessions.current_session_question_id
        and sq.state = 'revealed'
    ) then 'reveal'
    else 'question_open'
  end
  when 'paused' then 'paused'
  when 'complete' then 'completed'
  when 'cancelled' then 'cancelled'
  else 'draft'
end
where lifecycle_phase is null;

alter table africlub_game.game_sessions
  alter column lifecycle_phase set default 'draft',
  alter column lifecycle_phase set not null;

alter table africlub_game.game_sessions
  drop constraint if exists game_sessions_lifecycle_phase_check;
alter table africlub_game.game_sessions
  add constraint game_sessions_lifecycle_phase_check check (
    lifecycle_phase in (
      'draft',
      'validated',
      'published',
      'scheduled',
      'activated_lobby',
      'question_open',
      'reveal',
      'paused',
      'completed',
      'cancelled'
    )
  );

alter table africlub_game.game_sessions
  drop constraint if exists game_sessions_eligibility_scope_check;
alter table africlub_game.game_sessions
  add constraint game_sessions_eligibility_scope_check check (
    eligibility_scope in (
      'club_membership',
      'invitation_only',
      'venue',
      'home_owner'
    )
  );

alter table africlub_game.game_sessions
  drop constraint if exists game_sessions_paused_from_phase_check;
alter table africlub_game.game_sessions
  add constraint game_sessions_paused_from_phase_check check (
    paused_from_phase is null
    or paused_from_phase in ('activated_lobby', 'question_open', 'reveal')
  );

alter table africlub_game.session_players
  add column if not exists public_alias text;

update africlub_game.session_players
set public_alias = 'Supporter ' ||
  upper(substr(encode(digest(id::text, 'sha256'), 'hex'), 1, 6))
where nullif(btrim(public_alias), '') is null;

alter table africlub_game.session_players
  alter column public_alias set not null;
alter table africlub_game.session_players
  drop constraint if exists session_players_public_alias_check;
alter table africlub_game.session_players
  add constraint session_players_public_alias_check
  check (length(btrim(public_alias)) between 3 and 32);

create unique index if not exists idx_session_players_public_alias
  on africlub_game.session_players (session_id, lower(public_alias));

create table if not exists africlub_game.role_grants (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role_key text not null,
  venue_id uuid references public.venues(id) on delete cascade,
  granted_by uuid references auth.users(id) on delete set null,
  granted_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint role_grants_role_check check (
    role_key in ('display_owner', 'venue_manager', 'game_organizer')
  )
);

create unique index if not exists idx_game_role_grants_active
  on africlub_game.role_grants (
    club_id,
    user_id,
    role_key,
    coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid)
  )
  where revoked_at is null;

create table if not exists africlub_game.session_organizers (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create unique index if not exists idx_session_organizers_active
  on africlub_game.session_organizers (session_id, user_id)
  where revoked_at is null;

create table if not exists africlub_game.display_assignments (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  display_id uuid not null references africlub_game.tv_devices(id) on delete cascade,
  assigned_by uuid references auth.users(id) on delete set null,
  assigned_at timestamptz not null default timezone('utc', now()),
  unassigned_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

create unique index if not exists idx_display_assignments_active
  on africlub_game.display_assignments (session_id, display_id)
  where unassigned_at is null;
create index if not exists idx_display_assignments_display
  on africlub_game.display_assignments (display_id, unassigned_at, assigned_at desc);

insert into africlub_game.display_assignments (
  club_id,
  session_id,
  display_id,
  assigned_by
)
select s.club_id, s.id, s.tv_device_id, s.created_by
from africlub_game.game_sessions s
where s.tv_device_id is not null
on conflict (session_id, display_id) where unassigned_at is null do nothing;

create table if not exists africlub_game.session_eligibility (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  scope_type text not null,
  scope_id uuid,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint session_eligibility_scope_check check (
    scope_type in ('club_membership', 'invitation', 'venue', 'home_owner')
  ),
  constraint session_eligibility_scope_id_check check (
    (scope_type = 'club_membership' and scope_id is null)
    or (scope_type <> 'club_membership' and scope_id is not null)
  )
);

create unique index if not exists idx_session_eligibility_unique
  on africlub_game.session_eligibility (
    session_id,
    scope_type,
    coalesce(scope_id, '00000000-0000-0000-0000-000000000000'::uuid)
  );

insert into africlub_game.session_eligibility (
  club_id,
  session_id,
  scope_type,
  created_by
)
select club_id, id, 'club_membership', created_by
from africlub_game.game_sessions
where eligibility_scope = 'club_membership'
on conflict do nothing;

create table if not exists africlub_game.session_invitations (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  invited_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz,
  revoked_at timestamptz,
  accepted_at timestamptz
);

create unique index if not exists idx_session_invitations_active
  on africlub_game.session_invitations (session_id, user_id)
  where revoked_at is null;

create table if not exists africlub_game.transition_requests (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete restrict,
  idempotency_key text not null,
  requested_phase text not null,
  expected_session_version bigint not null,
  result_json jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  unique (session_id, actor_id, idempotency_key),
  constraint transition_requests_key_check
    check (length(btrim(idempotency_key)) between 8 and 128)
);

create table if not exists africlub_game.operation_requests (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  actor_id uuid not null references auth.users(id) on delete restrict,
  operation_scope text not null,
  idempotency_key text not null,
  result_json jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  unique (actor_id, operation_scope, idempotency_key),
  constraint operation_requests_scope_check
    check (length(btrim(operation_scope)) between 3 and 80),
  constraint operation_requests_key_check
    check (length(btrim(idempotency_key)) between 8 and 128)
);

create table if not exists africlub_game.game_events (
  id bigint generated always as identity primary key,
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  topic text not null,
  event_type text not null,
  session_version bigint not null,
  question_version bigint not null,
  event_sequence bigint not null,
  actor_id uuid references auth.users(id) on delete set null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint game_events_topic_check
    check (topic ~ '^[0-9]+:game_session:[0-9a-f-]{36}$'),
  constraint game_events_payload_check
    check (
      payload->>'requires_projection_refresh' = 'true'
      and not payload ? 'correct_option_key'
      and not payload ? 'phone'
      and not payload ? 'email'
      and not payload ? 'display_name'
    ),
  unique (session_id, event_sequence)
);

create index if not exists idx_game_events_topic_sequence
  on africlub_game.game_events (topic, event_sequence desc);

create table if not exists africlub_game.display_pairing_challenges (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  display_id uuid not null references africlub_game.tv_devices(id) on delete cascade,
  challenge_hash text not null,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  unique (challenge_hash),
  constraint pairing_challenge_expiry_check
    check (expires_at > created_at and expires_at <= created_at + interval '10 minutes')
);

-- A TV is not club-scoped until its authenticated owner claims it. This
-- global, short-lived bootstrap relation contains no personal or club data and
-- is reachable only through bounded security-definer RPCs.
create table if not exists africlub_game.display_bootstrap_challenges (
  id uuid primary key default gen_random_uuid(),
  challenge_hash text not null unique,
  installation_nonce_hash text not null,
  app_version text,
  capabilities jsonb not null default '{}'::jsonb,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  consumed_by uuid references auth.users(id) on delete set null,
  display_id uuid references africlub_game.tv_devices(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint display_bootstrap_expiry_check
    check (expires_at > created_at and expires_at <= created_at + interval '10 minutes'),
  constraint display_bootstrap_capabilities_check
    check (
      jsonb_typeof(capabilities) = 'object'
      and octet_length(capabilities::text) <= 2048
    )
);

create index if not exists idx_display_bootstrap_installation
  on africlub_game.display_bootstrap_challenges (
    installation_nonce_hash,
    created_at desc
  );

create or replace function africlub_game.has_role(
  p_club_id bigint,
  p_role_key text,
  p_venue_id uuid default null
) returns boolean
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select
    africlub_game.is_game_admin(p_club_id)
    or exists (
      select 1
      from africlub_game.role_grants grant_row
      where grant_row.club_id = p_club_id
        and grant_row.user_id = auth.uid()
        and grant_row.role_key = p_role_key
        and grant_row.revoked_at is null
        and (p_venue_id is null or grant_row.venue_id = p_venue_id)
    )
    or (
      p_role_key = 'venue_manager'
      and p_venue_id is not null
      and public.venue_staff_can_access(p_venue_id, array['owner', 'manager'])
    )
$$;

create or replace function africlub_game.can_manage_display(p_display_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select exists (
    select 1
    from africlub_game.tv_devices display
    where display.id = p_display_id
      and (
        africlub_game.is_game_admin(display.club_id)
        or display.owner_user_id = auth.uid()
        or (
          display.scope_type = 'venue'
          and (
            africlub_game.has_role(
              display.club_id,
              'display_owner',
              display.venue_id
            )
            or africlub_game.has_role(
              display.club_id,
              'venue_manager',
              display.venue_id
            )
          )
        )
      )
  )
$$;

create or replace function africlub_game.can_organize_session(p_session_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select exists (
    select 1
    from africlub_game.game_sessions session_row
    where session_row.id = p_session_id
      and (
        africlub_game.is_game_admin(session_row.club_id)
        or exists (
          select 1
          from africlub_game.session_organizers organizer
          where organizer.session_id = session_row.id
            and organizer.user_id = auth.uid()
            and organizer.revoked_at is null
        )
      )
  )
$$;

create or replace function africlub_game.is_session_participant(
  p_session_id uuid
) returns boolean
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select exists (
    select 1
    from africlub_game.session_players player
    where player.session_id = p_session_id
      and player.user_id = auth.uid()
  )
$$;

create or replace function africlub_game.can_plan_games(p_club_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select
    africlub_game.is_game_admin(p_club_id)
    or africlub_game.has_role(p_club_id, 'game_organizer')
$$;

create or replace function africlub_game.can_assign_display_to_session(
  p_session_id uuid,
  p_display_id uuid
) returns boolean
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select exists (
    select 1
    from africlub_game.game_sessions session_row
    join africlub_game.tv_devices display
      on display.id = p_display_id
     and display.club_id = session_row.club_id
    where session_row.id = p_session_id
      and display.status = 'paired'
      and (
        africlub_game.is_game_admin(session_row.club_id)
        or (
          africlub_game.can_organize_session(session_row.id)
          and (
            display.owner_user_id = auth.uid()
            or (
              display.scope_type = 'venue'
              and africlub_game.has_role(
                session_row.club_id,
                'game_organizer',
                display.venue_id
              )
            )
          )
        )
      )
  )
$$;

create or replace function africlub_game.allowed_session_phases_v2(
  p_session_id uuid
) returns text[]
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select case
    when not africlub_game.can_organize_session(session_row.id)
      then array[]::text[]
    when session_row.lifecycle_phase = 'draft'
      and africlub_game.is_game_admin(session_row.club_id)
      then array['validated']
    when session_row.lifecycle_phase = 'validated'
      and africlub_game.is_game_admin(session_row.club_id)
      then array['published']
    when session_row.lifecycle_phase = 'published'
      then array['scheduled']
    when session_row.lifecycle_phase = 'scheduled'
      then array['activated_lobby', 'cancelled']
    when session_row.lifecycle_phase = 'activated_lobby'
      then array['question_open', 'paused', 'end_early', 'cancelled']
    when session_row.lifecycle_phase = 'question_open'
      then array['reveal', 'skip_question', 'paused', 'end_early', 'cancelled']
    when session_row.lifecycle_phase = 'reveal'
      then array['question_open', 'paused', 'completed', 'cancelled']
    when session_row.lifecycle_phase = 'paused'
      then array[
        coalesce(session_row.paused_from_phase, 'question_open'),
        'completed',
        'cancelled'
      ]
    else array[]::text[]
  end
  from africlub_game.game_sessions session_row
  where session_row.id = p_session_id
$$;

create or replace function africlub_game.participant_public_alias(
  p_club_id bigint,
  p_user_id uuid
) returns text
language sql
immutable
set search_path = public, africlub_game, extensions, pg_temp
as $$
  select 'Supporter ' ||
    upper(substr(encode(digest(p_club_id::text || ':' || p_user_id::text, 'sha256'), 'hex'), 1, 6))
$$;

create or replace function public.get_eligible_game_sessions_v2(
  p_session_id uuid default null
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint := africlub_game.current_club_id();
  v_feed_version bigint := 0;
  v_public_alias text;
  v_sessions jsonb := '[]'::jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  if v_club_id is null then
    raise exception 'Club context required';
  end if;

  v_public_alias := africlub_game.participant_public_alias(v_club_id, v_user_id);

  select
    coalesce(max(session_row.session_version), 0),
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'club_id', session_row.club_id::text,
          'session_id', session_row.id::text,
          'title', left(session_row.title, 120),
          'phase', session_row.lifecycle_phase,
          'source', case
            when p_session_id is not null then 'deep_link'
            when invitation.id is not null then 'invitation'
            when session_row.eligibility_scope = 'home_owner' then 'home_owner'
            when session_row.eligibility_scope = 'venue' then 'venue'
            else 'club_membership'
          end,
          'session_version', session_row.session_version,
          'available_from', case
            when session_row.lifecycle_phase = 'scheduled'
              then session_row.scheduled_start_at
            else null
          end,
          'eligibility', true
        )
        order by
          case when session_row.lifecycle_phase = 'scheduled' then 1 else 0 end,
          session_row.scheduled_start_at nulls first,
          session_row.updated_at desc
      ),
      '[]'::jsonb
    )
  into v_feed_version, v_sessions
  from africlub_game.game_sessions session_row
  left join africlub_game.session_invitations invitation
    on invitation.session_id = session_row.id
   and invitation.user_id = v_user_id
   and invitation.revoked_at is null
   and (invitation.expires_at is null or invitation.expires_at > timezone('utc', now()))
  where session_row.club_id = v_club_id
    and session_row.lifecycle_phase in (
      'scheduled',
      'activated_lobby',
      'question_open',
      'reveal',
      'paused'
    )
    and (p_session_id is null or session_row.id = p_session_id)
    and (
      (
        session_row.eligibility_scope = 'club_membership'
        and exists (
          select 1
          from africlub_game.session_eligibility eligible
          where eligible.session_id = session_row.id
            and eligible.scope_type = 'club_membership'
        )
        and exists (
          select 1
          from public.fan_memberships membership
          where membership.user_id = v_user_id
            and membership.club_id = v_club_id
            and membership.status = 'active'
            and membership.payment_status = 'verified'::public.payment_status
            and (
              membership.expires_at is null
              or membership.expires_at > timezone('utc', now())
            )
        )
      )
      or invitation.id is not null
      or (
        session_row.eligibility_scope = 'home_owner'
        and exists (
          select 1
          from africlub_game.display_assignments assignment
          join africlub_game.tv_devices display on display.id = assignment.display_id
          where assignment.session_id = session_row.id
            and assignment.unassigned_at is null
            and display.scope_type = 'home'
            and display.owner_user_id = v_user_id
        )
      )
      or (
        session_row.eligibility_scope = 'venue'
        and exists (
          select 1
          from africlub_game.display_assignments assignment
          join africlub_game.tv_devices display on display.id = assignment.display_id
          where assignment.session_id = session_row.id
            and assignment.unassigned_at is null
            and display.scope_type = 'venue'
            and public.venue_staff_can_access(display.venue_id)
        )
      )
    );

  return jsonb_build_object(
    'club_id', v_club_id::text,
    'feed_version', v_feed_version,
    'server_time', timezone('utc', now()),
    'public_alias', v_public_alias,
    'sessions', v_sessions
  );
end;
$$;

create or replace function public.get_participant_game_projection_v2(
  p_session_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_club_id bigint := africlub_game.current_club_id();
  v_session africlub_game.game_sessions%rowtype;
  v_question record;
  v_player africlub_game.session_players%rowtype;
  v_attempt africlub_game.answer_attempts%rowtype;
  v_eligible boolean := false;
  v_public_alias text;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;
  if v_club_id is null then
    raise exception 'Club context required';
  end if;

  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id and club_id = v_club_id;
  if v_session.id is null then
    raise exception 'Game session not found';
  end if;

  select exists (
    select 1
    from jsonb_array_elements(
      public.get_eligible_game_sessions_v2(p_session_id)->'sessions'
    ) entry
    where entry->>'session_id' = p_session_id::text
  ) into v_eligible;
  if not v_eligible then
    raise exception 'Not authorized for this game session';
  end if;

  v_public_alias := africlub_game.participant_public_alias(v_club_id, v_user_id);

  insert into africlub_game.session_players (
    club_id,
    session_id,
    user_id,
    display_name,
    public_alias,
    last_seen_at
  ) values (
    v_club_id,
    v_session.id,
    v_user_id,
    v_public_alias,
    v_public_alias,
    timezone('utc', now())
  )
  on conflict (session_id, user_id) do update
    set last_seen_at = excluded.last_seen_at
  returning * into v_player;

  select
    sq.id,
    sq.ordinal,
    sq.state,
    q.prompt,
    q.options,
    q.correct_option_key
  into v_question
  from africlub_game.session_questions sq
  join africlub_game.questions q on q.id = sq.question_id
  where sq.id = v_session.current_session_question_id;

  select * into v_attempt
  from africlub_game.answer_attempts
  where session_question_id = v_session.current_session_question_id
    and session_player_id = v_player.id
  order by accepted_at desc
  limit 1;

  return jsonb_build_object(
    'club_id', v_session.club_id::text,
    'session_id', v_session.id::text,
    'phase', v_session.lifecycle_phase,
    'session_version', v_session.session_version,
    'event_sequence', v_session.event_sequence,
    'server_time', timezone('utc', now()),
    'phase_deadline', v_session.phase_deadline,
    'question_version', v_session.question_version,
    'freshness', jsonb_build_object(
      'state', 'current',
      'last_event_at', coalesce(v_session.updated_at, timezone('utc', now()))
    ),
    'eligibility', true,
    'public_alias', v_player.public_alias,
    'answer_state', case
      when v_session.lifecycle_phase in ('reveal', 'completed') and v_attempt.id is not null
        then 'revealed'
      when v_attempt.id is not null then 'accepted'
      else 'not_answered'
    end,
    'allowed_actions', case
      when v_session.lifecycle_phase = 'question_open'
        and v_attempt.id is null
        and v_question.id is not null
        then jsonb_build_array('submit_answer', 'retry_projection')
      else jsonb_build_array('retry_projection')
    end,
    'question', case
      when v_question.id is null then null
      else jsonb_build_object(
        'id', v_question.id::text,
        'prompt', left(v_question.prompt, 500),
        'options', v_question.options
      ) || case
        when v_session.lifecycle_phase in ('reveal', 'completed')
          then jsonb_build_object('correct_option_key', v_question.correct_option_key)
        else '{}'::jsonb
      end
    end,
    'leader_summary', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'rank', ranked.rank,
          'public_alias', ranked.public_alias,
          'score', ranked.score
        )
        order by ranked.rank
      )
      from (
        select
          row_number() over (order by player.score desc, player.joined_at asc) as rank,
          player.public_alias,
          player.score
        from africlub_game.session_players player
        where player.session_id = v_session.id
        order by player.score desc, player.joined_at asc
        limit 20
      ) ranked
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.submit_participant_answer_v2(
  p_session_id uuid,
  p_question_id uuid,
  p_option_key text,
  p_expected_session_version bigint,
  p_expected_question_version bigint,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_club_id bigint := africlub_game.current_club_id();
  v_session africlub_game.game_sessions%rowtype;
  v_player africlub_game.session_players%rowtype;
  v_answer_result jsonb;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if v_club_id is null then
    raise exception 'Club context required';
  end if;
  if length(btrim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'Invalid idempotency key';
  end if;

  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id
    and club_id = v_club_id
  for update;
  if v_session.id is null then
    raise exception 'Game session not found';
  end if;
  if not exists (
    select 1
    from jsonb_array_elements(
      public.get_eligible_game_sessions_v2(p_session_id)->'sessions'
    ) entry
    where entry->>'session_id' = p_session_id::text
  ) then
    raise exception 'Not authorized for this game session';
  end if;
  if v_session.lifecycle_phase <> 'question_open'
     or v_session.current_session_question_id <> p_question_id then
    raise exception 'Question is not open';
  end if;
  if v_session.session_version <> p_expected_session_version
     or v_session.question_version <> p_expected_question_version then
    raise exception 'Game projection version conflict';
  end if;

  select * into v_player
  from africlub_game.session_players
  where session_id = v_session.id
    and user_id = v_actor;
  if v_player.id is null then
    raise exception 'Participant is not joined to this session';
  end if;

  if exists (
    select 1
    from africlub_game.answer_attempts attempt
    where attempt.session_question_id = p_question_id
      and attempt.session_player_id = v_player.id
  ) then
    return public.get_participant_game_projection_v2(v_session.id);
  end if;

  select africlub_game.submit_answer(
           p_question_id,
           v_player.id,
           btrim(p_option_key),
           btrim(p_idempotency_key)
         )
    into v_answer_result;

  if not coalesce((v_answer_result->>'accepted')::boolean, false) then
    return public.get_participant_game_projection_v2(v_session.id);
  end if;

  update africlub_game.game_sessions
  set event_sequence = event_sequence + 1,
      updated_at = timezone('utc', now())
  where id = v_session.id
  returning * into v_session;

  insert into africlub_game.game_events (
    club_id,
    session_id,
    topic,
    event_type,
    session_version,
    question_version,
    event_sequence,
    actor_id,
    payload
  ) values (
    v_session.club_id,
    v_session.id,
    v_session.club_id::text || ':game_session:' || v_session.id::text,
    'projection_invalidated',
    v_session.session_version,
    v_session.question_version,
    v_session.event_sequence,
    v_actor,
    jsonb_build_object(
      'reason', 'participant_answer_recorded',
      'requires_projection_refresh', true
    )
  );

  return public.get_participant_game_projection_v2(v_session.id);
end;
$$;

create or replace function africlub_game.transition_session_v2(
  p_session_id uuid,
  p_requested_phase text,
  p_expected_session_version bigint,
  p_idempotency_key text,
  p_session_question_id uuid default null,
  p_phase_deadline timestamptz default null,
  p_reason text default null
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_session africlub_game.game_sessions%rowtype;
  v_previous_phase text;
  v_existing jsonb;
  v_result jsonb;
  v_status text;
  v_next_question_version bigint;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if length(btrim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'Invalid idempotency key';
  end if;

  select result_json into v_existing
  from africlub_game.transition_requests
  where session_id = p_session_id
    and actor_id = v_actor
    and idempotency_key = btrim(p_idempotency_key);
  if v_existing is not null then
    return v_existing;
  end if;

  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id
  for update;
  if v_session.id is null then
    raise exception 'Game session not found';
  end if;
  if not africlub_game.can_organize_session(v_session.id) then
    raise exception 'Not authorized to control this game session';
  end if;
  if p_requested_phase in ('validated', 'published')
     and not africlub_game.is_game_admin(v_session.club_id) then
    raise exception 'Only a governed game admin may validate or publish';
  end if;
  if v_session.session_version <> p_expected_session_version then
    raise exception 'Game session version conflict';
  end if;
  v_previous_phase := v_session.lifecycle_phase;

  if not (
    (v_session.lifecycle_phase = 'draft' and p_requested_phase = 'validated')
    or (v_session.lifecycle_phase = 'validated' and p_requested_phase = 'published')
    or (v_session.lifecycle_phase = 'published' and p_requested_phase = 'scheduled')
    or (v_session.lifecycle_phase = 'scheduled' and p_requested_phase in ('activated_lobby', 'cancelled'))
    or (v_session.lifecycle_phase = 'activated_lobby' and p_requested_phase in ('question_open', 'paused', 'completed', 'cancelled'))
    or (v_session.lifecycle_phase = 'question_open' and p_requested_phase in ('reveal', 'paused', 'completed', 'cancelled'))
    or (
      v_session.lifecycle_phase = 'question_open'
      and p_requested_phase = 'question_open'
      and p_session_question_id is not null
      and p_session_question_id <> v_session.current_session_question_id
      and length(btrim(coalesce(p_reason, ''))) between 3 and 240
    )
    or (v_session.lifecycle_phase = 'reveal' and p_requested_phase in ('question_open', 'paused', 'completed', 'cancelled'))
    or (
      v_session.lifecycle_phase = 'paused'
      and p_requested_phase in ('activated_lobby', 'question_open', 'reveal', 'completed', 'cancelled')
      and (
        p_requested_phase in ('completed', 'cancelled')
        or p_requested_phase = v_session.paused_from_phase
      )
    )
  ) then
    raise exception 'Invalid game lifecycle transition';
  end if;

  if p_requested_phase = 'completed'
     and v_session.lifecycle_phase in ('activated_lobby', 'question_open')
     and length(btrim(coalesce(p_reason, ''))) not between 3 and 240 then
    raise exception 'A bounded reason is required to end an active game early';
  end if;

  if p_requested_phase in ('question_open', 'reveal')
     and coalesce(p_session_question_id, v_session.current_session_question_id) is null then
    raise exception 'A session question is required';
  end if;
  if p_session_question_id is not null and not exists (
    select 1 from africlub_game.session_questions
    where id = p_session_question_id and session_id = v_session.id
  ) then
    raise exception 'Session question is outside the game session';
  end if;

  v_status := case p_requested_phase
    when 'draft' then 'draft'
    when 'validated' then 'draft'
    when 'published' then 'draft'
    when 'scheduled' then 'scheduled'
    when 'activated_lobby' then 'lobby'
    when 'question_open' then 'live'
    when 'reveal' then 'live'
    when 'paused' then 'paused'
    when 'completed' then 'complete'
    when 'cancelled' then 'cancelled'
  end;
  v_next_question_version := v_session.question_version +
    case when p_requested_phase = 'question_open' then 1 else 0 end;

  if p_requested_phase = 'question_open' then
    if v_session.current_session_question_id is not null
       and p_session_question_id is not null
       and p_session_question_id <> v_session.current_session_question_id then
      update africlub_game.session_questions
      set state = 'closed',
          closed_at = timezone('utc', now()),
          updated_at = timezone('utc', now())
      where id = v_session.current_session_question_id;
    end if;
    update africlub_game.session_questions
    set state = 'open',
        opened_at = timezone('utc', now()),
        revealed_at = null,
        closed_at = null,
        updated_at = timezone('utc', now())
    where id = coalesce(p_session_question_id, v_session.current_session_question_id);
  elsif p_requested_phase = 'reveal' then
    update africlub_game.session_questions
    set state = 'revealed',
        revealed_at = timezone('utc', now()),
        updated_at = timezone('utc', now())
    where id = v_session.current_session_question_id;
  elsif p_requested_phase in ('completed', 'cancelled')
        and v_session.current_session_question_id is not null then
    update africlub_game.session_questions
    set state = case when state = 'revealed' then state else 'closed' end,
        closed_at = coalesce(closed_at, timezone('utc', now())),
        updated_at = timezone('utc', now())
    where id = v_session.current_session_question_id;
  end if;

  update africlub_game.game_sessions
  set lifecycle_phase = p_requested_phase,
      status = v_status,
      current_session_question_id = coalesce(
        p_session_question_id,
        current_session_question_id
      ),
      session_version = session_version + 1,
      question_version = v_next_question_version,
      event_sequence = event_sequence + 1,
      phase_deadline = p_phase_deadline,
      paused_from_phase = case
        when p_requested_phase = 'paused' then v_previous_phase
        when v_previous_phase = 'paused' then null
        else paused_from_phase
      end,
      started_at = case
        when p_requested_phase = 'activated_lobby' then coalesce(started_at, timezone('utc', now()))
        else started_at
      end,
      ended_at = case
        when p_requested_phase in ('completed', 'cancelled') then timezone('utc', now())
        else ended_at
      end,
      updated_at = timezone('utc', now())
  where id = v_session.id
  returning * into v_session;

  insert into africlub_game.game_events (
    club_id,
    session_id,
    topic,
    event_type,
    session_version,
    question_version,
    event_sequence,
    actor_id,
    payload
  ) values (
    v_session.club_id,
    v_session.id,
    v_session.club_id::text || ':game_session:' || v_session.id::text,
    'projection_invalidated',
    v_session.session_version,
    v_session.question_version,
    v_session.event_sequence,
    v_actor,
    jsonb_build_object(
      'phase', v_session.lifecycle_phase,
      'requires_projection_refresh', true
    )
  );

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    before_json,
    after_json,
    reason
  ) values (
    v_session.club_id,
    v_actor,
    'game_session_transitioned',
    'game_session',
    v_session.id,
    jsonb_build_object(
      'phase', v_previous_phase,
      'session_version', p_expected_session_version
    ),
    jsonb_build_object(
      'phase', p_requested_phase,
      'session_version', v_session.session_version,
      'event_sequence', v_session.event_sequence
    ),
    left(nullif(btrim(coalesce(p_reason, '')), ''), 240)
  );

  v_result := jsonb_build_object(
    'session_id', v_session.id,
    'phase', v_session.lifecycle_phase,
    'session_version', v_session.session_version,
    'question_version', v_session.question_version,
    'event_sequence', v_session.event_sequence,
    'server_time', timezone('utc', now()),
    'phase_deadline', v_session.phase_deadline
  );

  insert into africlub_game.transition_requests (
    club_id,
    session_id,
    actor_id,
    idempotency_key,
    requested_phase,
    expected_session_version,
    result_json
  ) values (
    v_session.club_id,
    v_session.id,
    v_actor,
    btrim(p_idempotency_key),
    p_requested_phase,
    p_expected_session_version,
    v_result
  );

  return v_result;
end;
$$;

create or replace function africlub_game.assign_display_v2(
  p_session_id uuid,
  p_display_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_display africlub_game.tv_devices%rowtype;
  v_assignment africlub_game.display_assignments%rowtype;
  v_existing africlub_game.display_assignments%rowtype;
begin
  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id
  for update;
  select * into v_display
  from africlub_game.tv_devices
  where id = p_display_id
  for update;

  if v_session.id is null or v_display.id is null or v_session.club_id <> v_display.club_id then
    raise exception 'Session and display must exist in the same club';
  end if;
  if not africlub_game.can_assign_display_to_session(
    v_session.id,
    v_display.id
  ) then
    raise exception 'Not authorized to assign this display';
  end if;
  if length(btrim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'Invalid idempotency key';
  end if;

  select * into v_existing
  from africlub_game.display_assignments
  where session_id = v_session.id
    and display_id = v_display.id
    and unassigned_at is null
  limit 1;
  if v_existing.id is not null then
    return jsonb_build_object(
      'assignment_id', v_existing.id,
      'session_id', v_session.id,
      'display_id', v_display.id,
      'status', 'assigned'
    );
  end if;

  if exists (
    select 1
    from africlub_game.display_assignments assignment
    join africlub_game.game_sessions other_session
      on other_session.id = assignment.session_id
    where assignment.display_id = v_display.id
      and assignment.unassigned_at is null
      and assignment.session_id <> v_session.id
      and other_session.lifecycle_phase not in ('completed', 'cancelled')
  ) then
    raise exception 'Display is assigned to another active game session';
  end if;

  insert into africlub_game.display_assignments (
    club_id,
    session_id,
    display_id,
    assigned_by,
    metadata
  ) values (
    v_session.club_id,
    v_session.id,
    v_display.id,
    auth.uid(),
    jsonb_build_object('idempotency_key', btrim(p_idempotency_key))
  )
  returning * into v_assignment;

  update africlub_game.tv_devices
  set current_session_id = v_session.id,
      updated_at = timezone('utc', now())
  where id = v_display.id;

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    v_session.club_id,
    auth.uid(),
    'display_assigned',
    'display_assignment',
    v_assignment.id,
    jsonb_build_object(
      'session_id', v_session.id,
      'display_id', v_display.id
    )
  );

  return jsonb_build_object(
    'assignment_id', v_assignment.id,
    'session_id', v_session.id,
    'display_id', v_display.id,
    'status', 'assigned'
  );
end;
$$;

create or replace function africlub_game.unassign_display_v2(
  p_session_id uuid,
  p_display_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_assignment africlub_game.display_assignments%rowtype;
  v_session africlub_game.game_sessions%rowtype;
begin
  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id
  for update;
  if v_session.id is null then
    raise exception 'Game session not found';
  end if;
  if not africlub_game.can_assign_display_to_session(
    p_session_id,
    p_display_id
  ) then
    raise exception 'Not authorized to unassign this display';
  end if;
  if length(btrim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'Invalid idempotency key';
  end if;

  select * into v_assignment
  from africlub_game.display_assignments
  where session_id = p_session_id
    and display_id = p_display_id
    and unassigned_at is null
  limit 1
  for update;
  if v_assignment.id is null then
    return jsonb_build_object(
      'session_id', p_session_id,
      'display_id', p_display_id,
      'status', 'unassigned'
    );
  end if;

  update africlub_game.display_assignments
  set unassigned_at = timezone('utc', now()),
      metadata = metadata || jsonb_build_object(
        'unassign_idempotency_key',
        btrim(p_idempotency_key)
      )
  where id = v_assignment.id;

  update africlub_game.tv_devices
  set current_session_id = null,
      updated_at = timezone('utc', now())
  where id = p_display_id
    and current_session_id = p_session_id;

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    v_session.club_id,
    auth.uid(),
    'display_unassigned',
    'display_assignment',
    v_assignment.id,
    jsonb_build_object(
      'session_id', p_session_id,
      'display_id', p_display_id
    )
  );

  return jsonb_build_object(
    'assignment_id', v_assignment.id,
    'session_id', p_session_id,
    'display_id', p_display_id,
    'status', 'unassigned'
  );
end;
$$;

create or replace function public.get_owned_displays_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_club_id bigint := africlub_game.current_club_id();
  v_displays jsonb := '[]'::jsonb;
  v_scope_options jsonb := '[]'::jsonb;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if v_club_id is null then
    raise exception 'Club context required';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'display_id', display.id::text,
        'display_name', left(display.device_label, 80),
        'scope_type', display.scope_type,
        'venue_id', display.venue_id,
        'pairing_status', display.status,
        'last_seen_at', display.last_seen_at,
        'app_version', left(coalesce(display.app_version, ''), 80),
        'capabilities', display.capabilities,
        'health', case
          when display.status = 'disabled' then 'revoked'
          when display.last_seen_at is null then 'unknown'
          when display.last_seen_at < timezone('utc', now()) - interval '5 minutes'
            then 'offline'
          else 'online'
        end,
        'assigned_session', case
          when assigned_session.id is null then null
          else jsonb_build_object(
            'session_id', assigned_session.id::text,
            'title', left(assigned_session.title, 120),
            'phase', assigned_session.lifecycle_phase
          )
        end
      )
      order by display.updated_at desc, display.id
    ),
    '[]'::jsonb
  ) into v_displays
  from africlub_game.tv_devices display
  left join lateral (
    select session_row.*
    from africlub_game.display_assignments assignment
    join africlub_game.game_sessions session_row
      on session_row.id = assignment.session_id
    where assignment.display_id = display.id
      and assignment.unassigned_at is null
      and session_row.lifecycle_phase not in ('completed', 'cancelled')
    order by assignment.assigned_at desc
    limit 1
  ) assigned_session on true
  where display.club_id = v_club_id
    and africlub_game.can_manage_display(display.id);

  select coalesce(jsonb_agg(option_row.payload order by option_row.sort_key), '[]'::jsonb)
  into v_scope_options
  from (
    select
      '0-home'::text as sort_key,
      jsonb_build_object(
        'scope_type', 'home',
        'venue_id', null,
        'label', 'Home'
      ) as payload
    where africlub_game.is_game_admin(v_club_id)
       or exists (
         select 1
         from public.fan_memberships membership
         where membership.user_id = v_actor
           and membership.club_id = v_club_id
           and membership.status = 'active'
           and membership.payment_status = 'verified'::public.payment_status
           and (
             membership.expires_at is null
             or membership.expires_at > timezone('utc', now())
           )
       )
    union all
    select
      '1-venue-' || lower(venue.display_name) || '-' || venue.id::text,
      jsonb_build_object(
        'scope_type', 'venue',
        'venue_id', venue.id::text,
        'label', left(venue.display_name, 120)
      )
    from public.venues venue
    where venue.club_id = v_club_id
      and venue.status = 'approved'
      and public.venue_staff_can_access(
        venue.id,
        array['owner', 'manager']
      )
    order by sort_key
    limit 50
  ) option_row;

  return jsonb_build_object(
    'club_id', v_club_id::text,
    'server_time', timezone('utc', now()),
    'displays', v_displays,
    'scope_options', v_scope_options
  );
end;
$$;

create or replace function public.update_owned_display_v2(
  p_display_id uuid,
  p_display_name text,
  p_scope_type text,
  p_venue_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_display africlub_game.tv_devices%rowtype;
  v_result jsonb;
  v_scope text := 'display:update:' || p_display_id::text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if length(btrim(coalesce(p_display_name, ''))) not between 2 and 80 then
    raise exception 'Invalid display name';
  end if;
  if p_scope_type not in ('home', 'venue') then
    raise exception 'Invalid display scope';
  end if;
  if length(btrim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'Invalid idempotency key';
  end if;

  select result_json into v_result
  from africlub_game.operation_requests
  where actor_id = v_actor
    and operation_scope = v_scope
    and idempotency_key = btrim(p_idempotency_key);
  if v_result is not null then
    return v_result;
  end if;

  select * into v_display
  from africlub_game.tv_devices
  where id = p_display_id
  for update;
  if v_display.id is null or not africlub_game.can_manage_display(v_display.id) then
    raise exception 'Display not found or not authorized';
  end if;
  if p_scope_type = 'home'
     and v_display.scope_type <> 'home'
     and not africlub_game.is_game_admin(v_display.club_id)
     and not exists (
       select 1
       from public.fan_memberships membership
       where membership.user_id = v_actor
         and membership.club_id = v_display.club_id
         and membership.status = 'active'
         and membership.payment_status = 'verified'::public.payment_status
         and (
           membership.expires_at is null
           or membership.expires_at > timezone('utc', now())
         )
     ) then
    raise exception 'Active membership is required to move a display home';
  end if;
  if p_scope_type = 'venue'
     and (
       v_display.scope_type <> 'venue'
       or v_display.venue_id is distinct from p_venue_id
     )
     and (
       p_venue_id is null
       or not exists (
         select 1
         from public.venues venue
         where venue.id = p_venue_id
           and venue.club_id = v_display.club_id
           and venue.status = 'approved'
       )
       or not public.venue_staff_can_access(
         p_venue_id,
         array['owner', 'manager']
       )
     ) then
    raise exception 'Not authorized for this venue';
  end if;

  update africlub_game.tv_devices
  set device_label = left(btrim(p_display_name), 80),
      scope_type = p_scope_type,
      venue_id = case when p_scope_type = 'venue' then p_venue_id else null end,
      updated_at = timezone('utc', now())
  where id = v_display.id
  returning * into v_display;

  v_result := jsonb_build_object(
    'display_id', v_display.id::text,
    'display_name', v_display.device_label,
    'scope_type', v_display.scope_type,
    'venue_id', v_display.venue_id,
    'pairing_status', v_display.status
  );

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    v_display.club_id,
    v_actor,
    'display_updated',
    'tv_device',
    v_display.id,
    v_result
  );
  insert into africlub_game.operation_requests (
    club_id, actor_id, operation_scope, idempotency_key, result_json
  ) values (
    v_display.club_id,
    v_actor,
    v_scope,
    btrim(p_idempotency_key),
    v_result
  );
  return v_result;
end;
$$;

create or replace function public.revoke_owned_display_v2(
  p_display_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_display africlub_game.tv_devices%rowtype;
  v_result jsonb;
  v_scope text := 'display:revoke:' || p_display_id::text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if length(btrim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'Invalid idempotency key';
  end if;

  select result_json into v_result
  from africlub_game.operation_requests
  where actor_id = v_actor
    and operation_scope = v_scope
    and idempotency_key = btrim(p_idempotency_key);
  if v_result is not null then
    return v_result;
  end if;

  select * into v_display
  from africlub_game.tv_devices
  where id = p_display_id
  for update;
  if v_display.id is null or not africlub_game.can_manage_display(v_display.id) then
    raise exception 'Display not found or not authorized';
  end if;

  update africlub_game.display_assignments
  set unassigned_at = coalesce(unassigned_at, timezone('utc', now()))
  where display_id = v_display.id
    and unassigned_at is null;
  update africlub_game.tv_devices
  set status = 'disabled',
      credential_revoked_at = coalesce(
        credential_revoked_at,
        timezone('utc', now())
      ),
      current_session_id = null,
      updated_at = timezone('utc', now())
  where id = v_display.id
  returning * into v_display;

  v_result := jsonb_build_object(
    'display_id', v_display.id::text,
    'pairing_status', v_display.status,
    'revoked', true
  );

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    v_display.club_id,
    v_actor,
    'display_revoked',
    'tv_device',
    v_display.id,
    v_result
  );
  insert into africlub_game.operation_requests (
    club_id, actor_id, operation_scope, idempotency_key, result_json
  ) values (
    v_display.club_id,
    v_actor,
    v_scope,
    btrim(p_idempotency_key),
    v_result
  );
  return v_result;
end;
$$;

create or replace function public.get_organizer_game_projection_v2(
  p_session_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_question record;
  v_pack_title text;
begin
  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id;
  if v_session.id is null or not africlub_game.can_organize_session(v_session.id) then
    raise exception 'Game session not found or not authorized';
  end if;

  select left(pack.title, 120) into v_pack_title
  from africlub_game.question_packs pack
  where pack.id = v_session.pack_id;

  select
    session_question.id,
    session_question.ordinal,
    session_question.state,
    question.prompt,
    question.options
  into v_question
  from africlub_game.session_questions session_question
  join africlub_game.questions question
    on question.id = session_question.question_id
  where session_question.id = v_session.current_session_question_id;

  return jsonb_build_object(
    'club_id', v_session.club_id::text,
    'session_id', v_session.id::text,
    'session_title', left(v_session.title, 120),
    'pack_title', v_pack_title,
    'phase', v_session.lifecycle_phase,
    'session_version', v_session.session_version,
    'question_version', v_session.question_version,
    'event_sequence', v_session.event_sequence,
    'server_time', timezone('utc', now()),
    'phase_deadline', v_session.phase_deadline,
    'scheduled_start_at', v_session.scheduled_start_at,
    'eligibility_scope', v_session.eligibility_scope,
    'allowed_actions', to_jsonb(
      africlub_game.allowed_session_phases_v2(v_session.id)
    ),
    'participant_count', (
      select count(*)
      from africlub_game.session_players player
      where player.session_id = v_session.id
    ),
    'assigned_displays', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'display_id', display.id::text,
          'display_name', left(display.device_label, 80),
          'scope_type', display.scope_type,
          'pairing_status', display.status,
          'last_seen_at', display.last_seen_at,
          'health', case
            when display.status = 'disabled' then 'revoked'
            when display.last_seen_at is null then 'unknown'
            when display.last_seen_at < timezone('utc', now()) - interval '5 minutes'
              then 'offline'
            else 'online'
          end
        )
        order by display.device_label, display.id
      )
      from africlub_game.display_assignments assignment
      join africlub_game.tv_devices display
        on display.id = assignment.display_id
      where assignment.session_id = v_session.id
        and assignment.unassigned_at is null
    ), '[]'::jsonb),
    'assigned_organizers', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'display_name', left(
            coalesce(
              nullif(btrim(profile.full_name), ''),
              'Organizer profile incomplete'
            ),
            120
          ),
          'assigned_at', assignment.assigned_at
        )
        order by profile.full_name, assignment.assigned_at, assignment.id
      )
      from africlub_game.session_organizers assignment
      left join public.users profile on profile.id = assignment.user_id
      where assignment.session_id = v_session.id
        and assignment.revoked_at is null
    ), '[]'::jsonb),
    'current_question_control', case
      when v_question.id is null then null
      else jsonb_build_object(
        'id', v_question.id::text,
        'ordinal', v_question.ordinal,
        'state', v_question.state,
        'prompt', left(v_question.prompt, 500),
        'options', v_question.options
      )
    end,
    'question_controls', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', session_question.id::text,
          'ordinal', session_question.ordinal,
          'state', session_question.state,
          'prompt', left(question.prompt, 500)
        )
        order by session_question.ordinal, session_question.id
      )
      from africlub_game.session_questions session_question
      join africlub_game.questions question
        on question.id = session_question.question_id
      where session_question.session_id = v_session.id
    ), '[]'::jsonb),
    'freshness', jsonb_build_object(
      'state', 'current',
      'last_event_at', coalesce((
        select max(event.created_at)
        from africlub_game.game_events event
        where event.session_id = v_session.id
      ), v_session.updated_at)
    )
  );
end;
$$;

create or replace function public.get_admin_game_projection_v2(
  p_session_id uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_projection jsonb;
begin
  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id;
  if v_session.id is null or not africlub_game.is_game_admin(v_session.club_id) then
    raise exception 'Game session not found or not authorized';
  end if;

  v_projection := public.get_organizer_game_projection_v2(v_session.id);
  return v_projection || jsonb_build_object(
    'participant_aggregate', jsonb_build_object(
      'participant_count', (
        select count(*)
        from africlub_game.session_players player
        where player.session_id = v_session.id
      ),
      'answer_count', (
        select count(*)
        from africlub_game.answer_attempts attempt
        where attempt.session_id = v_session.id
      ),
      'average_score', coalesce((
        select round(avg(player.score)::numeric, 2)
        from africlub_game.session_players player
        where player.session_id = v_session.id
      ), 0)
    ),
    'audit_summary', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'action', audit.action,
          'entity_type', audit.entity_type,
          'reason', left(coalesce(audit.reason, ''), 240),
          'created_at', audit.created_at
        )
        order by audit.created_at desc
      )
      from (
        select *
        from africlub_game.audit_log audit_row
        where audit_row.club_id = v_session.club_id
          and (
            audit_row.entity_id = v_session.id
            or audit_row.after_json->>'session_id' = v_session.id::text
          )
        order by audit_row.created_at desc
        limit 20
      ) audit
    ), '[]'::jsonb),
    'projection_previews', jsonb_build_object(
      'participant', jsonb_build_object(
        'phase', v_session.lifecycle_phase,
        'session_version', v_session.session_version,
        'question_version', v_session.question_version
      ),
      'tv', jsonb_build_object(
        'phase', v_session.lifecycle_phase,
        'assigned_display_count', (
          select count(*)
          from africlub_game.display_assignments assignment
          where assignment.session_id = v_session.id
            and assignment.unassigned_at is null
        )
      )
    )
  );
end;
$$;

create or replace function public.assign_game_organizer_v2(
  p_session_id uuid,
  p_user_id uuid,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_session africlub_game.game_sessions%rowtype;
  v_assignment africlub_game.session_organizers%rowtype;
  v_result jsonb;
  v_scope text := 'session:organizer:' || p_session_id::text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if length(btrim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'Invalid idempotency key';
  end if;
  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id
  for update;
  if v_session.id is null or not africlub_game.is_game_admin(v_session.club_id) then
    raise exception 'Game session not found or not authorized';
  end if;
  if not exists (
    select 1
    from africlub_game.role_grants grant_row
    where grant_row.club_id = v_session.club_id
      and grant_row.user_id = p_user_id
      and grant_row.role_key = 'game_organizer'
      and grant_row.revoked_at is null
  ) then
    raise exception 'Selected user is not an active game organizer';
  end if;

  select result_json into v_result
  from africlub_game.operation_requests
  where actor_id = v_actor
    and operation_scope = v_scope
    and idempotency_key = btrim(p_idempotency_key);
  if v_result is not null then
    return v_result;
  end if;

  insert into africlub_game.session_organizers (
    club_id, session_id, user_id, assigned_by
  ) values (
    v_session.club_id, v_session.id, p_user_id, v_actor
  )
  on conflict (session_id, user_id) where revoked_at is null do update
    set assigned_at = africlub_game.session_organizers.assigned_at
  returning * into v_assignment;

  v_result := jsonb_build_object(
    'session_id', v_session.id::text,
    'assignment_id', v_assignment.id::text,
    'status', 'assigned'
  );
  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    v_session.club_id,
    v_actor,
    'game_organizer_assigned',
    'game_session',
    v_session.id,
    jsonb_build_object('organizer_user_id', p_user_id)
  );
  insert into africlub_game.operation_requests (
    club_id, actor_id, operation_scope, idempotency_key, result_json
  ) values (
    v_session.club_id,
    v_actor,
    v_scope,
    btrim(p_idempotency_key),
    v_result
  );
  return v_result;
end;
$$;

create or replace function public.get_managed_game_sessions_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_club_id bigint := africlub_game.current_club_id();
  v_sessions jsonb := '[]'::jsonb;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if v_club_id is null then
    raise exception 'Club context required';
  end if;

  select coalesce(
    jsonb_agg(
      case
        when africlub_game.is_game_admin(v_club_id)
          then public.get_admin_game_projection_v2(session_row.id)
        else public.get_organizer_game_projection_v2(session_row.id)
      end
      order by
        case when session_row.lifecycle_phase in ('completed', 'cancelled')
          then 1 else 0 end,
        session_row.scheduled_start_at nulls first,
        session_row.updated_at desc
    ),
    '[]'::jsonb
  ) into v_sessions
  from africlub_game.game_sessions session_row
  where session_row.club_id = v_club_id
    and africlub_game.can_organize_session(session_row.id);

  return jsonb_build_object(
    'club_id', v_club_id::text,
    'server_time', timezone('utc', now()),
    'can_plan', africlub_game.can_plan_games(v_club_id),
    'sessions', v_sessions
  );
end;
$$;

create or replace function public.get_game_planner_options_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_club_id bigint := africlub_game.current_club_id();
  v_packs jsonb := '[]'::jsonb;
  v_questions jsonb := '[]'::jsonb;
  v_displays jsonb := '[]'::jsonb;
  v_invitees jsonb := '[]'::jsonb;
  v_organizers jsonb := '[]'::jsonb;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if v_club_id is null or not africlub_game.can_plan_games(v_club_id) then
    raise exception 'Not authorized to plan games';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'pack_id', pack.id::text,
        'title', left(pack.title, 120),
        'description', left(pack.description, 240),
        'question_count', 20,
        'published_at', pack.published_at
      )
      order by pack.published_at desc nulls last, pack.title, pack.id
    ),
    '[]'::jsonb
  ) into v_packs
  from africlub_game.question_packs pack
  where pack.club_id = v_club_id
    and pack.status = 'published'
    and (
      select count(*)
      from africlub_game.question_pack_questions item
      where item.pack_id = pack.id
    ) = 20;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'question_id', approved_question.id::text,
        'prompt', left(approved_question.prompt, 500),
        'category', left(approved_question.category, 80),
        'difficulty', approved_question.difficulty,
        'language', approved_question.language,
        'approved_at', approved_question.approved_at,
        'source_title', left(approved_question.source_title, 160),
        'source_url', left(approved_question.source_url, 500),
        'source_trust_tier', approved_question.source_trust_tier
      )
      order by approved_question.approved_at desc nulls last,
        approved_question.prompt,
        approved_question.id
    ),
    '[]'::jsonb
  ) into v_questions
  from (
    select
      question.id,
      question.prompt,
      question.category,
      question.difficulty,
      question.language,
      question.approved_at,
      source.source_title,
      source.source_url,
      source.trust_tier as source_trust_tier
    from africlub_game.questions question
    left join africlub_game.question_sources source
      on source.id = question.source_id
      and source.club_id = question.club_id
    where question.club_id = v_club_id
      and question.status = 'approved'
      and question.retired_at is null
    order by question.approved_at desc nulls last, question.prompt, question.id
    limit 200
  ) approved_question;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'display_id', display.id::text,
        'display_name', left(display.device_label, 80),
        'scope_type', display.scope_type,
        'venue_id', display.venue_id,
        'pairing_status', display.status,
        'health', case
          when display.status = 'disabled' then 'revoked'
          when display.last_seen_at is null then 'unknown'
          when display.last_seen_at < timezone('utc', now()) - interval '5 minutes'
            then 'offline'
          else 'online'
        end,
        'assigned_session_id', active_assignment.session_id::text
      )
      order by display.device_label, display.id
    ),
    '[]'::jsonb
  ) into v_displays
  from africlub_game.tv_devices display
  left join lateral (
    select assignment.session_id
    from africlub_game.display_assignments assignment
    join africlub_game.game_sessions session_row
      on session_row.id = assignment.session_id
    where assignment.display_id = display.id
      and assignment.unassigned_at is null
      and session_row.lifecycle_phase not in ('completed', 'cancelled')
    order by assignment.assigned_at desc
    limit 1
  ) active_assignment on true
  where display.club_id = v_club_id
    and display.status = 'paired'
    and (
      africlub_game.is_game_admin(v_club_id)
      or display.owner_user_id = v_actor
      or (
        display.scope_type = 'venue'
        and africlub_game.has_role(
          v_club_id,
          'game_organizer',
          display.venue_id
        )
      )
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'user_id', invitee.user_id::text,
        'display_name', left(invitee.display_name, 80),
        'public_user_id', invitee.public_user_id
      )
      order by invitee.display_name, invitee.public_user_id, invitee.user_id
    ),
    '[]'::jsonb
  ) into v_invitees
  from (
    select distinct on (membership.user_id)
      membership.user_id,
      coalesce(
        nullif(btrim(membership.display_name), ''),
        'Supporter #' || profile.public_user_id
      ) as display_name,
      profile.public_user_id
    from public.fan_memberships membership
    join public.users profile on profile.id = membership.user_id
    where membership.club_id = v_club_id
      and membership.status = 'active'
      and membership.payment_status = 'verified'::public.payment_status
      and (
        membership.expires_at is null
        or membership.expires_at > timezone('utc', now())
      )
      and membership.user_id <> v_actor
    order by
      membership.user_id,
      membership.updated_at desc,
      membership.id desc
    limit 100
  ) invitee;

  if africlub_game.is_game_admin(v_club_id) then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'user_id', organizer.user_id::text,
          'display_name', left(organizer.display_name, 120),
          'venue_id', organizer.venue_id
        )
        order by organizer.display_name, organizer.user_id, organizer.venue_id
      ),
      '[]'::jsonb
    ) into v_organizers
    from (
      select distinct on (grant_row.user_id)
        grant_row.user_id,
        coalesce(
          nullif(btrim(profile.full_name), ''),
          'Organizer profile incomplete'
        ) as display_name,
        grant_row.venue_id
      from africlub_game.role_grants grant_row
      left join public.users profile on profile.id = grant_row.user_id
      where grant_row.club_id = v_club_id
        and grant_row.role_key = 'game_organizer'
        and grant_row.revoked_at is null
      order by
        grant_row.user_id,
        grant_row.venue_id nulls first,
        grant_row.granted_at desc
    ) organizer;
  end if;

  return jsonb_build_object(
    'club_id', v_club_id::text,
    'server_time', timezone('utc', now()),
    'packs', v_packs,
    'questions', v_questions,
    'displays', v_displays,
    'invitees', v_invitees,
    'organizers', v_organizers,
    'allowed_eligibility_scopes',
    jsonb_build_array(
      'club_membership',
      'invitation_only',
      'home_owner',
      'venue'
    )
  );
end;
$$;

create or replace function public.create_managed_game_session_v2(
  p_pack_id uuid,
  p_scheduled_start_at timestamptz,
  p_eligibility_scope text,
  p_display_ids uuid[] default '{}'::uuid[],
  p_idempotency_key text default null,
  p_organizer_user_ids uuid[] default '{}'::uuid[],
  p_invitee_user_ids uuid[] default '{}'::uuid[]
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_club_id bigint := africlub_game.current_club_id();
  v_pack africlub_game.question_packs%rowtype;
  v_session africlub_game.game_sessions%rowtype;
  v_display_id uuid;
  v_organizer_user_id uuid;
  v_invitee_user_id uuid;
  v_question_count integer;
  v_result jsonb;
  v_scope text := 'session:create';
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if v_club_id is null or not africlub_game.can_plan_games(v_club_id) then
    raise exception 'Not authorized to plan games';
  end if;
  if length(btrim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'Invalid idempotency key';
  end if;

  select result_json into v_result
  from africlub_game.operation_requests
  where actor_id = v_actor
    and operation_scope = v_scope
    and idempotency_key = btrim(p_idempotency_key);
  if v_result is not null then
    return v_result;
  end if;

  if p_scheduled_start_at < timezone('utc', now()) - interval '5 minutes'
     or p_scheduled_start_at > timezone('utc', now()) + interval '1 year' then
    raise exception 'Scheduled start is outside the supported window';
  end if;
  if p_eligibility_scope not in (
    'club_membership',
    'invitation_only',
    'home_owner',
    'venue'
  ) then
    raise exception 'Unsupported eligibility scope';
  end if;
  if cardinality(p_display_ids) <> (
    select count(distinct display_id)
    from unnest(p_display_ids) as display_id
  ) then
    raise exception 'Duplicate display assignment';
  end if;
  if cardinality(p_organizer_user_ids) <> (
    select count(distinct organizer_user_id)
    from unnest(p_organizer_user_ids) as organizer_user_id
  ) then
    raise exception 'Duplicate organizer assignment';
  end if;
  if cardinality(p_invitee_user_ids) <> (
    select count(distinct invitee_user_id)
    from unnest(p_invitee_user_ids) as invitee_user_id
  ) then
    raise exception 'Duplicate supporter invitation';
  end if;
  if cardinality(p_invitee_user_ids) > 100 then
    raise exception 'Too many supporter invitations';
  end if;
  if p_eligibility_scope = 'invitation_only'
     and cardinality(p_invitee_user_ids) = 0 then
    raise exception 'Invitation-only sessions require at least one supporter';
  end if;
  if exists (
    select 1
    from unnest(p_invitee_user_ids) as selected(user_id)
    where not exists (
      select 1
      from public.fan_memberships membership
      where membership.club_id = v_club_id
        and membership.user_id = selected.user_id
        and membership.status = 'active'
        and membership.payment_status = 'verified'::public.payment_status
        and (
          membership.expires_at is null
          or membership.expires_at > timezone('utc', now())
        )
    )
  ) then
    raise exception 'Selected invitee is not an eligible club supporter';
  end if;
  if cardinality(p_organizer_user_ids) > 0
     and not africlub_game.is_game_admin(v_club_id) then
    raise exception 'Only game admins may assign additional organizers';
  end if;
  if exists (
    select 1
    from unnest(p_organizer_user_ids) as selected(user_id)
    where not exists (
      select 1
      from africlub_game.role_grants grant_row
      where grant_row.club_id = v_club_id
        and grant_row.user_id = selected.user_id
        and grant_row.role_key = 'game_organizer'
        and grant_row.revoked_at is null
    )
  ) then
    raise exception 'Selected user is not an active game organizer';
  end if;
  if p_eligibility_scope in ('home_owner', 'venue')
     and cardinality(p_display_ids) = 0 then
    raise exception 'Scoped sessions require at least one display';
  end if;

  select * into v_pack
  from africlub_game.question_packs
  where id = p_pack_id
    and club_id = v_club_id
    and status = 'published';
  if v_pack.id is null then
    raise exception 'Published question pack not found';
  end if;
  select count(*) into v_question_count
  from africlub_game.question_pack_questions
  where pack_id = v_pack.id;
  if v_question_count <> 20 then
    raise exception 'Published question pack must contain exactly 20 questions';
  end if;

  insert into africlub_game.game_sessions (
    club_id,
    template_id,
    pack_id,
    title,
    status,
    lifecycle_phase,
    join_code,
    scheduled_start_at,
    eligibility_scope,
    session_version,
    event_sequence,
    created_by
  ) values (
    v_club_id,
    v_pack.template_id,
    v_pack.id,
    left(v_pack.title, 120),
    'scheduled',
    'scheduled',
    upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 24)),
    p_scheduled_start_at,
    p_eligibility_scope,
    1,
    1,
    v_actor
  ) returning * into v_session;

  insert into africlub_game.session_questions (
    club_id, session_id, question_id, ordinal
  )
  select v_club_id, v_session.id, item.question_id, item.ordinal
  from africlub_game.question_pack_questions item
  where item.pack_id = v_pack.id
  order by item.ordinal;

  insert into africlub_game.session_organizers (
    club_id, session_id, user_id, assigned_by
  ) values (
    v_club_id, v_session.id, v_actor, v_actor
  );

  foreach v_organizer_user_id in array p_organizer_user_ids loop
    insert into africlub_game.session_organizers (
      club_id, session_id, user_id, assigned_by
    ) values (
      v_club_id, v_session.id, v_organizer_user_id, v_actor
    )
    on conflict (session_id, user_id) where revoked_at is null do nothing;
  end loop;

  if p_eligibility_scope = 'club_membership' then
    insert into africlub_game.session_eligibility (
      club_id, session_id, scope_type, created_by
    ) values (
      v_club_id, v_session.id, 'club_membership', v_actor
    );
  end if;

  foreach v_invitee_user_id in array p_invitee_user_ids loop
    insert into africlub_game.session_invitations (
      club_id, session_id, user_id, invited_by
    ) values (
      v_club_id, v_session.id, v_invitee_user_id, v_actor
    ) on conflict (session_id, user_id) where revoked_at is null do nothing;
    insert into africlub_game.session_eligibility (
      club_id, session_id, scope_type, scope_id, created_by
    ) values (
      v_club_id,
      v_session.id,
      'invitation',
      v_invitee_user_id,
      v_actor
    ) on conflict do nothing;
  end loop;

  foreach v_display_id in array p_display_ids loop
    perform africlub_game.assign_display_v2(
      v_session.id,
      v_display_id,
      btrim(p_idempotency_key) || ':' || left(v_display_id::text, 8)
    );
    if p_eligibility_scope in ('home_owner', 'venue') then
      insert into africlub_game.session_eligibility (
        club_id, session_id, scope_type, scope_id, created_by
      ) values (
        v_club_id,
        v_session.id,
        p_eligibility_scope,
        v_display_id,
        v_actor
      ) on conflict do nothing;
    end if;
  end loop;

  insert into africlub_game.game_events (
    club_id,
    session_id,
    topic,
    event_type,
    session_version,
    question_version,
    event_sequence,
    actor_id,
    payload
  ) values (
    v_club_id,
    v_session.id,
    v_club_id::text || ':game_session:' || v_session.id::text,
    'projection_invalidated',
    v_session.session_version,
    v_session.question_version,
    v_session.event_sequence,
    v_actor,
    jsonb_build_object(
      'phase', v_session.lifecycle_phase,
      'requires_projection_refresh', true
    )
  );

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    v_club_id,
    v_actor,
    'managed_game_session_created',
    'game_session',
    v_session.id,
    jsonb_build_object(
      'pack_id', v_pack.id,
      'scheduled_start_at', p_scheduled_start_at,
      'eligibility_scope', p_eligibility_scope,
      'display_count', cardinality(p_display_ids),
      'invitee_count', cardinality(p_invitee_user_ids)
    )
  );

  v_result := public.get_organizer_game_projection_v2(v_session.id);
  insert into africlub_game.operation_requests (
    club_id, actor_id, operation_scope, idempotency_key, result_json
  ) values (
    v_club_id,
    v_actor,
    v_scope,
    btrim(p_idempotency_key),
    v_result
  );
  return v_result;
end;
$$;

create or replace function public.transition_managed_game_session_v2(
  p_session_id uuid,
  p_requested_phase text,
  p_expected_session_version bigint,
  p_idempotency_key text,
  p_session_question_id uuid default null,
  p_phase_deadline timestamptz default null,
  p_reason text default null
) returns jsonb
language sql
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select africlub_game.transition_session_v2(
    p_session_id,
    p_requested_phase,
    p_expected_session_version,
    p_idempotency_key,
    p_session_question_id,
    p_phase_deadline,
    p_reason
  )
$$;

create or replace function public.skip_managed_game_question_v2(
  p_session_id uuid,
  p_next_session_question_id uuid,
  p_expected_session_version bigint,
  p_idempotency_key text,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_existing jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  select result_json into v_existing
  from africlub_game.transition_requests
  where session_id = p_session_id
    and actor_id = auth.uid()
    and idempotency_key = btrim(p_idempotency_key);
  if v_existing is not null then
    return v_existing;
  end if;

  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id;

  if v_session.id is null or not africlub_game.can_organize_session(v_session.id) then
    raise exception 'Game session not found or not authorized';
  end if;
  if v_session.lifecycle_phase <> 'question_open' then
    raise exception 'Only an open question may be skipped';
  end if;
  if p_next_session_question_id is null
     or p_next_session_question_id = v_session.current_session_question_id then
    raise exception 'A different next session question is required';
  end if;
  if length(btrim(coalesce(p_reason, ''))) not between 3 and 234 then
    raise exception 'A bounded skip reason is required';
  end if;

  return africlub_game.transition_session_v2(
    p_session_id,
    'question_open',
    p_expected_session_version,
    p_idempotency_key,
    p_next_session_question_id,
    null,
    'skip: ' || btrim(p_reason)
  );
end;
$$;

create or replace function public.end_managed_game_session_v2(
  p_session_id uuid,
  p_expected_session_version bigint,
  p_idempotency_key text,
  p_reason text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_existing jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;
  select result_json into v_existing
  from africlub_game.transition_requests
  where session_id = p_session_id
    and actor_id = auth.uid()
    and idempotency_key = btrim(p_idempotency_key);
  if v_existing is not null then
    return v_existing;
  end if;

  select * into v_session
  from africlub_game.game_sessions
  where id = p_session_id;

  if v_session.id is null or not africlub_game.can_organize_session(v_session.id) then
    raise exception 'Game session not found or not authorized';
  end if;
  if v_session.lifecycle_phase not in (
    'activated_lobby', 'question_open', 'reveal', 'paused'
  ) then
    raise exception 'Only an active game may be ended';
  end if;
  if length(btrim(coalesce(p_reason, ''))) not between 3 and 235 then
    raise exception 'A bounded end reason is required';
  end if;

  return africlub_game.transition_session_v2(
    p_session_id,
    'completed',
    p_expected_session_version,
    p_idempotency_key,
    null,
    null,
    'end: ' || btrim(p_reason)
  );
end;
$$;

create or replace function public.assign_managed_game_display_v2(
  p_session_id uuid,
  p_display_id uuid,
  p_idempotency_key text
) returns jsonb
language sql
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select africlub_game.assign_display_v2(
    p_session_id,
    p_display_id,
    p_idempotency_key
  )
$$;

create or replace function public.unassign_managed_game_display_v2(
  p_session_id uuid,
  p_display_id uuid,
  p_idempotency_key text
) returns jsonb
language sql
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select africlub_game.unassign_display_v2(
    p_session_id,
    p_display_id,
    p_idempotency_key
  )
$$;

create or replace function public.create_display_pairing_challenge_v2(
  p_installation_nonce text,
  p_app_version text default null,
  p_capabilities jsonb default '{}'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_nonce text := btrim(coalesce(p_installation_nonce, ''));
  v_nonce_hash text;
  v_challenge text;
  v_row africlub_game.display_bootstrap_challenges%rowtype;
begin
  if length(v_nonce) not between 32 and 256 then
    raise exception 'Invalid installation nonce';
  end if;
  if p_app_version is not null and length(btrim(p_app_version)) > 80 then
    raise exception 'Invalid app version';
  end if;
  if jsonb_typeof(coalesce(p_capabilities, '{}'::jsonb)) <> 'object'
     or octet_length(coalesce(p_capabilities, '{}'::jsonb)::text) > 2048 then
    raise exception 'Invalid display capabilities';
  end if;

  v_nonce_hash := encode(digest(v_nonce, 'sha256'), 'hex');
  if (
    select count(*) >= 8
    from africlub_game.display_bootstrap_challenges
    where installation_nonce_hash = v_nonce_hash
      and created_at > timezone('utc', now()) - interval '1 hour'
  ) then
    raise exception 'Pairing challenge rate limit exceeded';
  end if;

  update africlub_game.display_bootstrap_challenges
  set expires_at = least(expires_at, timezone('utc', now()))
  where installation_nonce_hash = v_nonce_hash
    and consumed_at is null
    and expires_at > timezone('utc', now());

  v_challenge := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into africlub_game.display_bootstrap_challenges (
    challenge_hash,
    installation_nonce_hash,
    app_version,
    capabilities,
    expires_at
  ) values (
    encode(digest(v_challenge, 'sha256'), 'hex'),
    v_nonce_hash,
    left(nullif(btrim(coalesce(p_app_version, '')), ''), 80),
    coalesce(p_capabilities, '{}'::jsonb),
    timezone('utc', now()) + interval '8 minutes'
  ) returning * into v_row;

  return jsonb_build_object(
    'status', 'pending_owner_claim',
    'challenge', v_challenge,
    'expires_at', v_row.expires_at,
    'qr_payload', 'africlub://my-tvs/pair?challenge=' || v_challenge
  );
end;
$$;

create or replace function public.claim_display_bootstrap_challenge_v2(
  p_challenge text,
  p_display_name text,
  p_scope_type text default 'home',
  p_venue_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_club_id bigint := africlub_game.current_club_id();
  v_challenge africlub_game.display_bootstrap_challenges%rowtype;
  v_display_id uuid := gen_random_uuid();
  v_display africlub_game.tv_devices%rowtype;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if v_club_id is null then
    raise exception 'Club context required';
  end if;
  if length(btrim(coalesce(p_display_name, ''))) not between 2 and 80 then
    raise exception 'Invalid display name';
  end if;
  if p_scope_type not in ('home', 'venue') then
    raise exception 'Invalid display scope';
  end if;
  if p_scope_type = 'home'
     and not africlub_game.is_game_admin(v_club_id)
     and not exists (
       select 1
       from public.fan_memberships membership
       where membership.user_id = v_actor
         and membership.club_id = v_club_id
         and membership.status = 'active'
         and membership.payment_status = 'verified'::public.payment_status
         and (
           membership.expires_at is null
           or membership.expires_at > timezone('utc', now())
         )
     ) then
    raise exception 'Active membership is required to claim a home display';
  end if;
  if p_scope_type = 'venue'
     and (
       p_venue_id is null
       or not exists (
         select 1
         from public.venues venue
         where venue.id = p_venue_id
           and venue.club_id = v_club_id
           and venue.status = 'approved'
       )
       or not public.venue_staff_can_access(
         p_venue_id,
         array['owner', 'manager']
       )
     ) then
    raise exception 'Not authorized for this venue';
  end if;

  select * into v_challenge
  from africlub_game.display_bootstrap_challenges
  where challenge_hash = encode(
      digest(upper(btrim(coalesce(p_challenge, ''))), 'sha256'),
      'hex'
    )
    and consumed_at is null
    and expires_at > timezone('utc', now())
  limit 1
  for update;
  if v_challenge.id is null then
    raise exception 'Display challenge is invalid or expired';
  end if;

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
  ) values (
    v_display_id,
    v_club_id,
    left(btrim(p_display_name), 80),
    'V2-' || upper(substr(replace(v_display_id::text, '-', ''), 1, 20)),
    'paired',
    v_actor,
    p_scope_type,
    case when p_scope_type = 'venue' then p_venue_id else null end,
    v_challenge.app_version,
    v_challenge.capabilities,
    v_actor
  ) returning * into v_display;

  update africlub_game.display_bootstrap_challenges
  set consumed_at = timezone('utc', now()),
      consumed_by = v_actor,
      display_id = v_display.id
  where id = v_challenge.id;

  insert into africlub_game.role_grants (
    club_id, user_id, role_key, venue_id, granted_by
  ) values (
    v_club_id,
    v_actor,
    'display_owner',
    case when p_scope_type = 'venue' then p_venue_id else null end,
    v_actor
  ) on conflict (
    club_id,
    user_id,
    role_key,
    (coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid))
  ) where revoked_at is null do nothing;

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    v_club_id,
    v_actor,
    'display_owner_bound',
    'tv_device',
    v_display.id,
    jsonb_build_object(
      'scope_type', v_display.scope_type,
      'venue_id', v_display.venue_id
    )
  );

  return jsonb_build_object(
    'status', 'claimed',
    'display_id', v_display.id::text,
    'display_name', v_display.device_label,
    'scope_type', v_display.scope_type,
    'venue_id', v_display.venue_id
  );
end;
$$;

create or replace function public.recover_owned_display_from_bootstrap_v2(
  p_display_id uuid,
  p_challenge text,
  p_idempotency_key text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_display africlub_game.tv_devices%rowtype;
  v_challenge africlub_game.display_bootstrap_challenges%rowtype;
  v_result jsonb;
  v_scope text := 'display:recover:' || p_display_id::text;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if length(btrim(coalesce(p_idempotency_key, ''))) not between 8 and 128 then
    raise exception 'Invalid idempotency key';
  end if;

  select result_json into v_result
  from africlub_game.operation_requests
  where actor_id = v_actor
    and operation_scope = v_scope
    and idempotency_key = btrim(p_idempotency_key);
  if v_result is not null then
    return v_result;
  end if;

  select * into v_display
  from africlub_game.tv_devices
  where id = p_display_id
  for update;
  if v_display.id is null or not africlub_game.can_manage_display(v_display.id) then
    raise exception 'Display not found or not authorized';
  end if;

  select * into v_challenge
  from africlub_game.display_bootstrap_challenges
  where challenge_hash = encode(
      digest(upper(btrim(coalesce(p_challenge, ''))), 'sha256'),
      'hex'
    )
    and consumed_at is null
    and expires_at > timezone('utc', now())
  limit 1
  for update;
  if v_challenge.id is null then
    raise exception 'Display challenge is invalid or expired';
  end if;

  update africlub_game.display_pairing_challenges
  set consumed_at = coalesce(consumed_at, timezone('utc', now()))
  where display_id = v_display.id
    and consumed_at is null;

  update africlub_game.tv_devices
  set status = 'paired',
      app_version = v_challenge.app_version,
      capabilities = v_challenge.capabilities,
      credential_token_hash = null,
      credential_issued_at = null,
      credential_revoked_at = null,
      last_seen_at = null,
      pairing_code = 'V2-' || upper(substr(replace(id::text, '-', ''), 1, 20)),
      updated_at = timezone('utc', now())
  where id = v_display.id
  returning * into v_display;

  update africlub_game.display_bootstrap_challenges
  set consumed_at = timezone('utc', now()),
      consumed_by = v_actor,
      display_id = v_display.id
  where id = v_challenge.id;

  v_result := jsonb_build_object(
    'status', 'recovery_pending_tv_exchange',
    'display_id', v_display.id::text,
    'display_name', v_display.device_label,
    'scope_type', v_display.scope_type,
    'venue_id', v_display.venue_id,
    'expires_at', v_challenge.expires_at
  );

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    v_display.club_id,
    v_actor,
    'display_recovery_started',
    'tv_device',
    v_display.id,
    v_result
  );
  insert into africlub_game.operation_requests (
    club_id, actor_id, operation_scope, idempotency_key, result_json
  ) values (
    v_display.club_id,
    v_actor,
    v_scope,
    btrim(p_idempotency_key),
    v_result
  );
  return v_result;
end;
$$;

create or replace function public.exchange_display_pairing_challenge_v2(
  p_challenge text,
  p_installation_nonce text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_row africlub_game.display_bootstrap_challenges%rowtype;
  v_display africlub_game.tv_devices%rowtype;
  v_token text;
begin
  if length(btrim(coalesce(p_installation_nonce, ''))) not between 32 and 256 then
    return jsonb_build_object('status', 'error', 'code', 'installation_invalid');
  end if;

  select * into v_row
  from africlub_game.display_bootstrap_challenges
  where challenge_hash = encode(
      digest(upper(btrim(coalesce(p_challenge, ''))), 'sha256'),
      'hex'
    )
    and installation_nonce_hash = encode(
      digest(btrim(p_installation_nonce), 'sha256'),
      'hex'
    )
    and expires_at > timezone('utc', now())
  limit 1
  for update;
  if v_row.id is null then
    return jsonb_build_object('status', 'error', 'code', 'challenge_invalid_or_expired');
  end if;
  if v_row.consumed_at is null or v_row.display_id is null then
    return jsonb_build_object(
      'status', 'pending_owner_claim',
      'expires_at', v_row.expires_at
    );
  end if;

  select * into v_display
  from africlub_game.tv_devices
  where id = v_row.display_id
  for update;
  if v_display.id is null or v_display.status <> 'paired'
     or v_display.credential_revoked_at is not null then
    return jsonb_build_object('status', 'error', 'code', 'display_revoked');
  end if;
  if v_display.credential_token_hash is not null then
    return jsonb_build_object('status', 'error', 'code', 'credential_already_issued');
  end if;

  v_token := encode(
    digest(
      gen_random_uuid()::text || ':' || clock_timestamp()::text ||
      ':' || gen_random_uuid()::text,
      'sha256'
    ),
    'hex'
  );
  update africlub_game.tv_devices
  set credential_token_hash = encode(digest(v_token, 'sha256'), 'hex'),
      credential_issued_at = timezone('utc', now()),
      credential_revoked_at = null,
      pairing_code = 'REDEEMED-' || id::text,
      updated_at = timezone('utc', now())
  where id = v_display.id
  returning * into v_display;

  return jsonb_build_object(
    'status', 'paired',
    'display_id', v_display.id::text,
    'club_id', v_display.club_id::text,
    'device_credential', v_token
  );
end;
$$;

create or replace function africlub_game.issue_display_pairing_challenge(
  p_display_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_display africlub_game.tv_devices%rowtype;
  v_challenge text;
  v_row africlub_game.display_pairing_challenges%rowtype;
begin
  select * into v_display
  from africlub_game.tv_devices
  where id = p_display_id
  for update;
  if v_display.id is null then
    raise exception 'Display not found';
  end if;
  if auth.role() <> 'service_role'
     and not africlub_game.can_manage_display(v_display.id) then
    raise exception 'Not authorized to issue a display challenge';
  end if;

  update africlub_game.display_pairing_challenges
  set consumed_at = coalesce(consumed_at, timezone('utc', now()))
  where display_id = v_display.id and consumed_at is null;

  v_challenge := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into africlub_game.display_pairing_challenges (
    club_id,
    display_id,
    challenge_hash,
    expires_at
  ) values (
    v_display.club_id,
    v_display.id,
    encode(digest(v_challenge, 'sha256'), 'hex'),
    timezone('utc', now()) + interval '8 minutes'
  )
  returning * into v_row;

  return jsonb_build_object(
    'display_id', v_display.id,
    'challenge', v_challenge,
    'expires_at', v_row.expires_at,
    'qr_payload', 'africlub://my-tvs/pair?challenge=' || v_challenge
  );
end;
$$;

create or replace function public.issue_owned_display_pairing_challenge_v2(
  p_display_id uuid
) returns jsonb
language sql
security definer
set search_path = public, africlub_game, pg_temp
as $$
  select africlub_game.issue_display_pairing_challenge(p_display_id)
$$;

create or replace function public.claim_display_pairing_challenge_v2(
  p_challenge text,
  p_display_name text,
  p_scope_type text default 'home',
  p_venue_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_actor uuid := auth.uid();
  v_hash text;
  v_challenge africlub_game.display_pairing_challenges%rowtype;
  v_display africlub_game.tv_devices%rowtype;
begin
  if v_actor is null then
    raise exception 'Authentication required';
  end if;
  if p_scope_type not in ('home', 'venue') then
    raise exception 'Invalid display scope';
  end if;
  if p_scope_type = 'venue'
     and (p_venue_id is null or not public.venue_staff_can_access(
       p_venue_id,
       array['owner', 'manager']
     )) then
    raise exception 'Not authorized for this venue';
  end if;
  if length(btrim(coalesce(p_display_name, ''))) not between 2 and 80 then
    raise exception 'Invalid display name';
  end if;

  v_hash := encode(digest(upper(btrim(coalesce(p_challenge, ''))), 'sha256'), 'hex');
  select * into v_challenge
  from africlub_game.display_pairing_challenges
  where challenge_hash = v_hash
    and consumed_at is null
    and expires_at > timezone('utc', now())
  limit 1
  for update;
  if v_challenge.id is null then
    raise exception 'Display challenge is invalid or expired';
  end if;

  update africlub_game.tv_devices
  set owner_user_id = v_actor,
      device_label = left(btrim(p_display_name), 80),
      scope_type = p_scope_type,
      venue_id = p_venue_id,
      status = 'paired',
      updated_at = timezone('utc', now())
  where id = v_challenge.display_id
  returning * into v_display;

  update africlub_game.display_pairing_challenges
  set consumed_at = timezone('utc', now()),
      consumed_by = v_actor
  where id = v_challenge.id;

  insert into africlub_game.role_grants (
    club_id,
    user_id,
    role_key,
    venue_id,
    granted_by
  ) values (
    v_display.club_id,
    v_actor,
    'display_owner',
    p_venue_id,
    v_actor
  )
  on conflict (
    club_id,
    user_id,
    role_key,
    (coalesce(venue_id, '00000000-0000-0000-0000-000000000000'::uuid))
  ) where revoked_at is null do nothing;

  insert into africlub_game.audit_log (
    club_id, actor_id, action, entity_type, entity_id, after_json
  ) values (
    v_display.club_id,
    v_actor,
    'display_owner_bound',
    'tv_device',
    v_display.id,
    jsonb_build_object(
      'scope_type', v_display.scope_type,
      'venue_id', v_display.venue_id
    )
  );

  return jsonb_build_object(
    'display_id', v_display.id,
    'display_name', v_display.device_label,
    'scope_type', v_display.scope_type,
    'venue_id', v_display.venue_id,
    'status', v_display.status
  );
end;
$$;

create or replace function public.get_tv_game_projection_v2(
  p_device_token text
) returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_token text := nullif(btrim(coalesce(p_device_token, '')), '');
  v_display africlub_game.tv_devices%rowtype;
  v_session africlub_game.game_sessions%rowtype;
  v_question record;
begin
  if v_token is null or length(v_token) <> 64 then
    return jsonb_build_object('status', 'error', 'code', 'credential_invalid');
  end if;

  select * into v_display
  from africlub_game.tv_devices
  where credential_token_hash = encode(digest(v_token, 'sha256'), 'hex')
    and status = 'paired'
    and credential_revoked_at is null
  limit 1;
  if v_display.id is null then
    return jsonb_build_object('status', 'error', 'code', 'credential_revoked_or_invalid');
  end if;

  select session_row.* into v_session
  from africlub_game.display_assignments assignment
  join africlub_game.game_sessions session_row on session_row.id = assignment.session_id
  where assignment.display_id = v_display.id
    and assignment.unassigned_at is null
    and (
      session_row.lifecycle_phase not in ('completed', 'cancelled')
      or (
        session_row.lifecycle_phase in ('completed', 'cancelled')
        and coalesce(session_row.ended_at, session_row.updated_at)
          >= timezone('utc', now()) - interval '30 minutes'
      )
    )
  order by
    case
      when session_row.lifecycle_phase in ('completed', 'cancelled') then 1
      else 0
    end,
    assignment.assigned_at desc
  limit 1;

  update africlub_game.tv_devices
  set last_seen_at = timezone('utc', now()),
      updated_at = timezone('utc', now())
  where id = v_display.id;

  if v_session.id is null then
    return jsonb_build_object(
      'status', 'empty',
      'display_id', v_display.id,
      'club_id', v_display.club_id::text,
      'server_time', timezone('utc', now()),
      'allowed_actions', jsonb_build_array('retry_projection'),
      'freshness', jsonb_build_object(
        'state', 'current',
        'last_event_at', timezone('utc', now())
      )
    );
  end if;

  select
    sq.id,
    sq.ordinal,
    q.prompt,
    q.options,
    q.correct_option_key
  into v_question
  from africlub_game.session_questions sq
  join africlub_game.questions q on q.id = sq.question_id
  where sq.id = v_session.current_session_question_id;

  return jsonb_build_object(
    'status', 'ready',
    'display_id', v_display.id,
    'club_id', v_session.club_id::text,
    'session_id', v_session.id::text,
    'session_title', left(v_session.title, 120),
    'phase', v_session.lifecycle_phase,
    'session_version', v_session.session_version,
    'question_version', v_session.question_version,
    'event_sequence', v_session.event_sequence,
    'server_time', timezone('utc', now()),
    'phase_deadline', v_session.phase_deadline,
    'allowed_actions', jsonb_build_array('retry_projection'),
    'freshness', jsonb_build_object(
      'state', 'current',
      'last_event_at', coalesce((
        select max(event.created_at)
        from africlub_game.game_events event
        where event.session_id = v_session.id
      ), v_session.updated_at)
    ),
    'question', case
      when v_question.id is null then null
      else jsonb_build_object(
        'id', v_question.id::text,
        'ordinal', v_question.ordinal,
        'prompt', left(v_question.prompt, 500),
        'options', v_question.options
      ) || case
        when v_session.lifecycle_phase in ('reveal', 'completed')
          then jsonb_build_object('correct_option_key', v_question.correct_option_key)
        else '{}'::jsonb
      end
    end,
    'leaderboard', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'rank', ranked.rank,
          'public_alias', ranked.public_alias,
          'score', ranked.score
        )
        order by ranked.rank
      )
      from (
        select
          row_number() over (order by player.score desc, player.joined_at asc) as rank,
          player.public_alias,
          player.score
        from africlub_game.session_players player
        where player.session_id = v_session.id
        order by player.score desc, player.joined_at asc
        limit 20
      ) ranked
    ), '[]'::jsonb)
  );
end;
$$;

alter table africlub_game.role_grants enable row level security;
alter table africlub_game.session_organizers enable row level security;
alter table africlub_game.display_assignments enable row level security;
alter table africlub_game.session_eligibility enable row level security;
alter table africlub_game.session_invitations enable row level security;
alter table africlub_game.transition_requests enable row level security;
alter table africlub_game.operation_requests enable row level security;
alter table africlub_game.game_events enable row level security;
alter table africlub_game.display_pairing_challenges enable row level security;
alter table africlub_game.display_bootstrap_challenges enable row level security;

-- The foundation's club-claim read policies exposed raw session rows and
-- approved correct answers to any authenticated caller able to supply a club
-- claim. V2 participants and organizers must use role-safe projection RPCs
-- instead. An explicitly assigned organizer may see only their session shell;
-- answer-bearing content, participant identity, ledgers, and audit material
-- remain admin-only at the relation boundary.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'game_templates',
    'question_sources',
    'question_drafts',
    'questions',
    'question_packs',
    'question_pack_questions',
    'game_sessions',
    'session_teams',
    'session_players',
    'session_questions',
    'answer_attempts',
    'answer_claims',
    'points_ledger',
    'audit_log'
  ] loop
    execute format(
      'drop policy if exists %I on africlub_game.%I',
      table_name || '_club_read',
      table_name
    );
    execute format(
      'drop policy if exists %I on africlub_game.%I',
      table_name || '_operator_read',
      table_name
    );
    execute format(
      'drop policy if exists %I on africlub_game.%I',
      table_name || '_admin_read',
      table_name
    );
    execute format(
      'create policy %I on africlub_game.%I for select to authenticated using (
        africlub_game.is_game_admin(club_id)
      )',
      table_name || '_admin_read',
      table_name
    );
  end loop;
end $$;

drop policy if exists game_sessions_admin_read
on africlub_game.game_sessions;
drop policy if exists game_sessions_operator_read
on africlub_game.game_sessions;
create policy game_sessions_assigned_operator_read
on africlub_game.game_sessions for select to authenticated
using (
  africlub_game.is_game_admin(club_id)
  or africlub_game.can_organize_session(id)
);

drop policy if exists tv_devices_club_read on africlub_game.tv_devices;
drop policy if exists session_players_insert_self on africlub_game.session_players;
drop policy if exists answer_attempts_insert_self on africlub_game.answer_attempts;
revoke insert on africlub_game.session_players from authenticated;
revoke insert on africlub_game.answer_attempts from authenticated;
revoke all on africlub_game.display_bootstrap_challenges
from public, anon, authenticated;

drop policy if exists game_role_grants_read on africlub_game.role_grants;
create policy game_role_grants_read
on africlub_game.role_grants for select to authenticated
using (user_id = auth.uid() or africlub_game.is_game_admin(club_id));

drop policy if exists game_role_grants_admin_write on africlub_game.role_grants;
create policy game_role_grants_admin_write
on africlub_game.role_grants for all to authenticated
using (africlub_game.is_game_admin(club_id))
with check (africlub_game.is_game_admin(club_id));

drop policy if exists session_organizers_read
on africlub_game.session_organizers;
create policy session_organizers_read
on africlub_game.session_organizers for select to authenticated
using (
  user_id = auth.uid()
  or africlub_game.is_game_admin(club_id)
);

drop policy if exists session_organizers_admin_write
on africlub_game.session_organizers;
create policy session_organizers_admin_write
on africlub_game.session_organizers for all to authenticated
using (africlub_game.is_game_admin(club_id))
with check (africlub_game.is_game_admin(club_id));

drop policy if exists session_eligibility_operator_read
on africlub_game.session_eligibility;
create policy session_eligibility_operator_read
on africlub_game.session_eligibility for select to authenticated
using (
  africlub_game.is_game_admin(club_id)
  or africlub_game.can_organize_session(session_id)
);

drop policy if exists display_assignments_read on africlub_game.display_assignments;
create policy display_assignments_read
on africlub_game.display_assignments for select to authenticated
using (
  africlub_game.is_game_admin(club_id)
  or africlub_game.can_manage_display(display_id)
  or africlub_game.can_organize_session(session_id)
);

drop policy if exists display_assignments_write on africlub_game.display_assignments;
create policy display_assignments_write
on africlub_game.display_assignments for all to authenticated
using (
  africlub_game.can_assign_display_to_session(session_id, display_id)
)
with check (
  africlub_game.can_assign_display_to_session(session_id, display_id)
);

drop policy if exists session_invitations_self_read on africlub_game.session_invitations;
create policy session_invitations_self_read
on africlub_game.session_invitations for select to authenticated
using (
  user_id = auth.uid()
  or africlub_game.can_organize_session(session_id)
);

drop policy if exists game_events_participant_read on africlub_game.game_events;
create policy game_events_participant_read
on africlub_game.game_events for select to authenticated
using (
  club_id = africlub_game.current_club_id()
  and (
    africlub_game.is_session_participant(session_id)
    or africlub_game.can_organize_session(session_id)
  )
);

drop policy if exists transition_requests_actor_read on africlub_game.transition_requests;
create policy transition_requests_actor_read
on africlub_game.transition_requests for select to authenticated
using (
  actor_id = auth.uid()
  or africlub_game.can_organize_session(session_id)
);

drop policy if exists operation_requests_actor_read
on africlub_game.operation_requests;
create policy operation_requests_actor_read
on africlub_game.operation_requests for select to authenticated
using (
  actor_id = auth.uid()
  or africlub_game.is_game_admin(club_id)
);

drop policy if exists pairing_challenges_owner_read on africlub_game.display_pairing_challenges;
create policy pairing_challenges_owner_read
on africlub_game.display_pairing_challenges for select to authenticated
using (africlub_game.can_manage_display(display_id));

drop policy if exists tv_devices_v2_owner_read on africlub_game.tv_devices;
create policy tv_devices_v2_owner_read
on africlub_game.tv_devices for select to authenticated
using (
  africlub_game.is_game_admin(club_id)
  or owner_user_id = auth.uid()
  or africlub_game.can_manage_display(id)
  or exists (
    select 1
    from africlub_game.display_assignments assignment
    where assignment.display_id = tv_devices.id
      and assignment.unassigned_at is null
      and africlub_game.can_organize_session(assignment.session_id)
  )
);

-- Relation privileges and row policies are both required: the explicit grants
-- let PostgreSQL reach the policies, while the policies keep raw rows scoped.
revoke all on table
  africlub_game.role_grants,
  africlub_game.session_organizers,
  africlub_game.display_assignments,
  africlub_game.session_eligibility,
  africlub_game.session_invitations,
  africlub_game.transition_requests,
  africlub_game.operation_requests,
  africlub_game.game_events,
  africlub_game.display_pairing_challenges,
  africlub_game.display_bootstrap_challenges
from public, anon, authenticated, service_role;

grant select on table
  africlub_game.role_grants,
  africlub_game.session_organizers,
  africlub_game.session_eligibility,
  africlub_game.session_invitations,
  africlub_game.transition_requests,
  africlub_game.operation_requests,
  africlub_game.display_pairing_challenges
to authenticated;

-- Display assignment writes and all bootstrap-challenge access remain RPC-only.
grant select on africlub_game.display_assignments to authenticated;
grant select on africlub_game.game_events to authenticated;

revoke all on function africlub_game.has_role(bigint, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.has_role(bigint, text, uuid)
  to authenticated;
revoke all on function africlub_game.can_manage_display(uuid)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.can_manage_display(uuid)
  to authenticated;
revoke all on function africlub_game.can_organize_session(uuid)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.can_organize_session(uuid)
  to authenticated;
revoke all on function africlub_game.is_session_participant(uuid)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.is_session_participant(uuid)
to authenticated;
revoke all on function africlub_game.can_plan_games(bigint)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.can_plan_games(bigint)
  to authenticated;
revoke all on function africlub_game.can_assign_display_to_session(uuid, uuid)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.can_assign_display_to_session(uuid, uuid)
  to authenticated;
revoke all on function africlub_game.allowed_session_phases_v2(uuid)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.allowed_session_phases_v2(uuid)
  to authenticated;

revoke all on function africlub_game.get_tv_session_state(uuid)
from public, anon, authenticated, service_role;
revoke all on function africlub_game.join_session(uuid,text,bigint,text)
from public, anon, authenticated, service_role;
revoke all on function africlub_game.submit_answer(uuid,uuid,text,text)
from public, anon, authenticated, service_role;
grant execute on function africlub_game.get_tv_session_state(uuid)
to service_role;
grant execute on function africlub_game.join_session(uuid,text,bigint,text)
to service_role;
grant execute on function africlub_game.submit_answer(uuid,uuid,text,text)
to service_role;

revoke all on function public.get_eligible_game_sessions_v2(uuid) from public, anon, authenticated, service_role;
grant execute on function public.get_eligible_game_sessions_v2(uuid) to authenticated;
revoke all on function public.get_participant_game_projection_v2(uuid) from public, anon, authenticated, service_role;
grant execute on function public.get_participant_game_projection_v2(uuid) to authenticated;
revoke all on function public.submit_participant_answer_v2(uuid,uuid,text,bigint,bigint,text) from public, anon, authenticated, service_role;
grant execute on function public.submit_participant_answer_v2(uuid,uuid,text,bigint,bigint,text) to authenticated;
revoke all on function public.claim_display_pairing_challenge_v2(text,text,text,uuid) from public, anon, authenticated, service_role;
grant execute on function public.claim_display_pairing_challenge_v2(text,text,text,uuid) to authenticated;
revoke all on function public.get_tv_game_projection_v2(text) from public, anon, authenticated, service_role;
grant execute on function public.get_tv_game_projection_v2(text) to anon, authenticated;
revoke all on function public.get_owned_displays_v2() from public, anon, authenticated, service_role;
grant execute on function public.get_owned_displays_v2() to authenticated;
revoke all on function public.update_owned_display_v2(uuid,text,text,uuid,text) from public, anon, authenticated, service_role;
grant execute on function public.update_owned_display_v2(uuid,text,text,uuid,text)
to authenticated;
revoke all on function public.revoke_owned_display_v2(uuid,text) from public, anon, authenticated, service_role;
grant execute on function public.revoke_owned_display_v2(uuid,text)
to authenticated;
revoke all on function public.get_managed_game_sessions_v2() from public, anon, authenticated, service_role;
grant execute on function public.get_managed_game_sessions_v2()
to authenticated;
revoke all on function public.get_game_planner_options_v2() from public, anon, authenticated, service_role;
grant execute on function public.get_game_planner_options_v2()
to authenticated;
revoke all on function public.get_organizer_game_projection_v2(uuid) from public, anon, authenticated, service_role;
grant execute on function public.get_organizer_game_projection_v2(uuid)
to authenticated;
revoke all on function public.get_admin_game_projection_v2(uuid) from public, anon, authenticated, service_role;
grant execute on function public.get_admin_game_projection_v2(uuid)
to authenticated;
revoke all on function public.create_managed_game_session_v2(uuid,timestamptz,text,uuid[],text,uuid[],uuid[])
  from public, anon, authenticated, service_role;
grant execute on function public.create_managed_game_session_v2(uuid,timestamptz,text,uuid[],text,uuid[],uuid[])
  to authenticated;
revoke all on function public.transition_managed_game_session_v2(uuid,text,bigint,text,uuid,timestamptz,text)
from public, anon, authenticated, service_role;
grant execute on function public.transition_managed_game_session_v2(uuid,text,bigint,text,uuid,timestamptz,text)
to authenticated;
revoke all on function public.skip_managed_game_question_v2(uuid,uuid,bigint,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.skip_managed_game_question_v2(uuid,uuid,bigint,text,text)
to authenticated;
revoke all on function public.end_managed_game_session_v2(uuid,bigint,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.end_managed_game_session_v2(uuid,bigint,text,text)
to authenticated;
revoke all on function public.assign_managed_game_display_v2(uuid,uuid,text)
from public, anon, authenticated, service_role;
grant execute on function public.assign_managed_game_display_v2(uuid,uuid,text)
to authenticated;
revoke all on function public.unassign_managed_game_display_v2(uuid,uuid,text)
from public, anon, authenticated, service_role;
grant execute on function public.unassign_managed_game_display_v2(uuid,uuid,text)
to authenticated;
revoke all on function public.assign_game_organizer_v2(uuid,uuid,text)
from public, anon, authenticated, service_role;
grant execute on function public.assign_game_organizer_v2(uuid,uuid,text)
to authenticated;
revoke all on function public.create_display_pairing_challenge_v2(text,text,jsonb)
from public, anon, authenticated, service_role;
grant execute on function public.create_display_pairing_challenge_v2(text,text,jsonb)
to anon, authenticated;
revoke all on function public.claim_display_bootstrap_challenge_v2(text,text,text,uuid)
from public, anon, authenticated, service_role;
grant execute on function public.claim_display_bootstrap_challenge_v2(text,text,text,uuid)
to authenticated;
revoke all on function public.recover_owned_display_from_bootstrap_v2(uuid,text,text)
from public, anon, authenticated, service_role;
grant execute on function public.recover_owned_display_from_bootstrap_v2(uuid,text,text)
to authenticated;
revoke all on function public.exchange_display_pairing_challenge_v2(text,text)
from public, anon, authenticated, service_role;
grant execute on function public.exchange_display_pairing_challenge_v2(text,text)
to anon, authenticated;
revoke all on function africlub_game.transition_session_v2(uuid,text,bigint,text,uuid,timestamptz,text) from public, anon, authenticated, service_role;
grant execute on function africlub_game.transition_session_v2(uuid,text,bigint,text,uuid,timestamptz,text) to service_role;
revoke all on function africlub_game.assign_display_v2(uuid,uuid,text) from public, anon, authenticated, service_role;
grant execute on function africlub_game.assign_display_v2(uuid,uuid,text) to service_role;
revoke all on function africlub_game.unassign_display_v2(uuid,uuid,text) from public, anon, authenticated, service_role;
grant execute on function africlub_game.unassign_display_v2(uuid,uuid,text)
to service_role;
revoke all on function africlub_game.issue_display_pairing_challenge(uuid) from public, anon, authenticated, service_role;
grant execute on function africlub_game.issue_display_pairing_challenge(uuid)
to service_role;
revoke all on function public.issue_owned_display_pairing_challenge_v2(uuid)
from public, anon, authenticated, service_role;
grant execute on function public.issue_owned_display_pairing_challenge_v2(uuid)
to authenticated;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1
       from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'africlub_game'
         and tablename = 'game_events'
     ) then
    alter publication supabase_realtime add table africlub_game.game_events;
  end if;
end $$;

comment on table africlub_game.display_assignments is
  'Many-to-many, club-scoped assignment of authorized displays to a game session.';
comment on table africlub_game.game_events is
  'Privacy-safe invalidation hints. Clients must fetch and reconcile a versioned projection.';
comment on function public.get_eligible_game_sessions_v2(uuid) is
  'Code-free participant discovery limited to currently eligible club-scoped sessions.';
comment on function public.get_participant_game_projection_v2(uuid) is
  'Versioned participant projection that withholds correct answers until reveal.';
comment on function public.submit_participant_answer_v2(uuid,uuid,text,bigint,bigint,text) is
  'Version-checked, idempotent participant answer submission returning a new authoritative projection.';
comment on function africlub_game.transition_session_v2(uuid,text,bigint,text,uuid,timestamptz,text) is
  'Server-authoritative, version-checked, idempotent game lifecycle transition.';
comment on function public.skip_managed_game_question_v2(uuid,uuid,bigint,text,text) is
  'Reasoned, version-checked organizer exception that closes the current question and opens a different session question.';
comment on function public.end_managed_game_session_v2(uuid,bigint,text,text) is
  'Reasoned, version-checked organizer exception that ends an active game as completed.';
comment on function public.get_tv_game_projection_v2(text) is
  'Credential-scoped TV projection using explicit display assignment and no participant join material.';

-- Retire the pre-bootstrap owner pairing interfaces. Native TV V2 creates a
-- hashed bootstrap challenge and exchanges it only after an authorized owner
-- claim or recovery; no client may mint a challenge for an existing display.
drop function if exists public.issue_owned_display_pairing_challenge_v2(uuid);
drop function if exists public.claim_display_pairing_challenge_v2(text,text,text,uuid);
drop function if exists africlub_game.issue_display_pairing_challenge(uuid);

commit;

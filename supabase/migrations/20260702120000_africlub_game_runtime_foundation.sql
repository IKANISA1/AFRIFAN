-- AFRICLUB TV-led game runtime foundation.
-- Adds server-authoritative quiz/session primitives without replacing the
-- existing Fan Zone or partner WDW pool runtime.

begin;

create schema if not exists africlub_game;

create or replace function africlub_game.current_club_id()
returns bigint
language sql
stable
as $$
  select nullif(public.requesting_club_id(), '')::bigint
$$;

create or replace function africlub_game.is_game_admin(p_club_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public, africlub_game
as $$
  select public.is_super_admin() or public.is_club_admin(p_club_id);
$$;

create or replace function africlub_game.normalize_question_prompt(p_prompt text)
returns text
language sql
immutable
as $$
  select btrim(
    regexp_replace(
      regexp_replace(lower(coalesce(p_prompt, '')), '[^a-z0-9]+', ' ', 'g'),
      '[[:space:]]+',
      ' ',
      'g'
    )
  )
$$;

create table if not exists africlub_game.game_templates (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  template_key text not null,
  title text not null,
  description text not null default '',
  game_kind text not null default 'first_correct_quiz',
  default_question_count integer not null default 20,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint game_templates_key_check check (template_key ~ '^[a-z0-9_:-]+$'),
  constraint game_templates_kind_check check (game_kind in ('first_correct_quiz', 'wdw_pool_board')),
  constraint game_templates_question_count_check check (default_question_count = 20),
  unique (club_id, template_key)
);

create table if not exists africlub_game.question_sources (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  source_url text,
  source_title text not null,
  source_date date,
  extracted_fact text not null default '',
  extraction_hash text,
  trust_tier text not null default 'review_required',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint question_sources_trust_tier_check check (
    trust_tier in ('official', 'trusted_media', 'academic', 'venue_supplied', 'review_required')
  )
);

create table if not exists africlub_game.question_drafts (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  source_id uuid references africlub_game.question_sources(id) on delete set null,
  prompt text not null,
  options jsonb not null,
  correct_option_key text not null,
  explanation text not null default '',
  category text not null default 'general',
  difficulty text not null default 'medium',
  language text not null default 'en',
  model_name text,
  schema_version text not null default '2026-07-02',
  validation_status text not null default 'pending_review',
  validation_notes text not null default '',
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint question_drafts_options_check check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) between 2 and 6),
  constraint question_drafts_correct_key_check check (length(btrim(correct_option_key)) > 0),
  constraint question_drafts_difficulty_check check (difficulty in ('easy', 'medium', 'hard')),
  constraint question_drafts_validation_status_check check (
    validation_status in ('pending_review', 'approved', 'rejected', 'needs_changes')
  )
);

create table if not exists africlub_game.questions (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  draft_id uuid references africlub_game.question_drafts(id) on delete set null,
  source_id uuid references africlub_game.question_sources(id) on delete set null,
  prompt text not null,
  options jsonb not null,
  correct_option_key text not null,
  explanation text not null default '',
  category text not null default 'general',
  difficulty text not null default 'medium',
  language text not null default 'en',
  status text not null default 'approved',
  approved_by uuid references auth.users(id) on delete set null,
  approved_at timestamptz,
  retired_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint questions_options_check check (jsonb_typeof(options) = 'array' and jsonb_array_length(options) between 2 and 6),
  constraint questions_status_check check (status in ('approved', 'retired', 'flagged'))
);

create table if not exists africlub_game.question_packs (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  template_id uuid references africlub_game.game_templates(id) on delete restrict,
  title text not null,
  description text not null default '',
  status text not null default 'draft',
  question_count integer not null default 20,
  published_by uuid references auth.users(id) on delete set null,
  published_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint question_packs_status_check check (status in ('draft', 'published', 'retired')),
  constraint question_packs_count_check check (question_count = 20)
);

create table if not exists africlub_game.question_pack_questions (
  pack_id uuid not null references africlub_game.question_packs(id) on delete cascade,
  question_id uuid not null references africlub_game.questions(id) on delete restrict,
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  ordinal integer not null,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (pack_id, question_id),
  unique (pack_id, ordinal),
  constraint question_pack_questions_ordinal_check check (ordinal between 1 and 20)
);

create table if not exists africlub_game.tv_devices (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  device_label text not null,
  pairing_code text not null,
  status text not null default 'pending',
  last_seen_at timestamptz,
  current_session_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint tv_devices_status_check check (status in ('pending', 'paired', 'disabled')),
  unique (club_id, pairing_code)
);

create table if not exists africlub_game.game_sessions (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  template_id uuid references africlub_game.game_templates(id) on delete restrict,
  pack_id uuid references africlub_game.question_packs(id) on delete restrict,
  tv_device_id uuid references africlub_game.tv_devices(id) on delete set null,
  title text not null,
  play_mode text not null default 'free_for_all',
  status text not null default 'draft',
  current_session_question_id uuid,
  join_code text not null,
  scheduled_start_at timestamptz,
  started_at timestamptz,
  ended_at timestamptz,
  safety_window_seconds integer not null default 60,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint game_sessions_play_mode_check check (play_mode in ('free_for_all', 'teams', 'family_table_battle')),
  constraint game_sessions_status_check check (status in ('draft', 'scheduled', 'lobby', 'live', 'paused', 'complete', 'cancelled')),
  constraint game_sessions_safety_window_check check (safety_window_seconds between 15 and 600),
  unique (club_id, join_code)
);

alter table africlub_game.tv_devices
  drop constraint if exists tv_devices_current_session_fk;
alter table africlub_game.tv_devices
  add constraint tv_devices_current_session_fk foreign key (current_session_id)
  references africlub_game.game_sessions(id) on delete set null;

create table if not exists africlub_game.session_teams (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  name text not null,
  color_key text,
  score integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (session_id, name)
);

create table if not exists africlub_game.session_players (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  team_id uuid references africlub_game.session_teams(id) on delete set null,
  display_name text not null,
  avatar_key text,
  score integer not null default 0,
  joined_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint session_players_display_name_check check (length(btrim(display_name)) > 0),
  unique (session_id, user_id)
);

create table if not exists africlub_game.session_questions (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  question_id uuid not null references africlub_game.questions(id) on delete restrict,
  ordinal integer not null,
  state text not null default 'queued',
  opened_at timestamptz,
  claimed_at timestamptz,
  revealed_at timestamptz,
  closed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint session_questions_ordinal_check check (ordinal between 1 and 20),
  constraint session_questions_state_check check (state in ('queued', 'open', 'claimed', 'revealed', 'closed', 'skipped')),
  unique (session_id, ordinal)
);

alter table africlub_game.game_sessions
  drop constraint if exists game_sessions_current_question_fk;
alter table africlub_game.game_sessions
  add constraint game_sessions_current_question_fk foreign key (current_session_question_id)
  references africlub_game.session_questions(id) on delete set null;

create table if not exists africlub_game.answer_attempts (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  session_question_id uuid not null references africlub_game.session_questions(id) on delete cascade,
  session_player_id uuid not null references africlub_game.session_players(id) on delete cascade,
  selected_option_key text not null,
  is_correct boolean not null default false,
  accepted_at timestamptz not null default timezone('utc', now()),
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  constraint answer_attempts_option_key_check check (length(btrim(selected_option_key)) > 0)
);

create unique index if not exists unique_player_attempt_per_question
  on africlub_game.answer_attempts (session_question_id, session_player_id);

create unique index if not exists unique_answer_attempt_idempotency
  on africlub_game.answer_attempts (session_question_id, session_player_id, idempotency_key)
  where idempotency_key is not null;

create table if not exists africlub_game.answer_claims (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid not null references africlub_game.game_sessions(id) on delete cascade,
  session_question_id uuid not null references africlub_game.session_questions(id) on delete cascade,
  answer_attempt_id uuid not null references africlub_game.answer_attempts(id) on delete cascade,
  session_player_id uuid not null references africlub_game.session_players(id) on delete cascade,
  team_id uuid references africlub_game.session_teams(id) on delete set null,
  points_awarded integer not null default 100,
  claimed_at timestamptz not null default timezone('utc', now()),
  metadata jsonb not null default '{}'::jsonb,
  constraint answer_claims_points_check check (points_awarded > 0)
);

create unique index if not exists unique_session_question_claim
  on africlub_game.answer_claims (session_question_id);

create table if not exists africlub_game.points_ledger (
  id uuid primary key default gen_random_uuid(),
  club_id bigint not null references public.african_football_clubs(id) on delete cascade,
  session_id uuid references africlub_game.game_sessions(id) on delete set null,
  session_player_id uuid references africlub_game.session_players(id) on delete set null,
  user_id uuid references auth.users(id) on delete set null,
  points_type text not null,
  amount integer not null,
  related_entity_type text,
  related_entity_id uuid,
  idempotency_key text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint points_ledger_amount_check check (amount <> 0),
  constraint points_ledger_type_check check (points_type in ('quiz_claim', 'wdw_correct_pick', 'admin_adjustment', 'void_refund'))
);

create unique index if not exists unique_points_ledger_idempotency
  on africlub_game.points_ledger (club_id, idempotency_key)
  where idempotency_key is not null;

create table if not exists africlub_game.audit_log (
  id uuid primary key default gen_random_uuid(),
  club_id bigint references public.african_football_clubs(id) on delete set null,
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  before_json jsonb,
  after_json jsonb,
  reason text,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists idx_game_sessions_club_status
  on africlub_game.game_sessions (club_id, status, scheduled_start_at desc);
create index if not exists idx_session_questions_session_state
  on africlub_game.session_questions (session_id, state, ordinal);
create index if not exists idx_answer_attempts_question_time
  on africlub_game.answer_attempts (session_question_id, accepted_at);
create index if not exists idx_points_ledger_player_time
  on africlub_game.points_ledger (session_player_id, created_at desc);
create index if not exists idx_game_audit_entity
  on africlub_game.audit_log (entity_type, entity_id, created_at desc);
create unique index if not exists unique_question_per_draft
  on africlub_game.questions (draft_id)
  where draft_id is not null;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'game_templates',
    'question_drafts',
    'questions',
    'question_packs',
    'tv_devices',
    'game_sessions',
    'session_teams',
    'session_questions'
  ] loop
    execute format('drop trigger if exists %I on africlub_game.%I', table_name || '_set_updated_at', table_name);
    execute format(
      'create trigger %I before update on africlub_game.%I for each row execute function public.set_updated_at()',
      table_name || '_set_updated_at',
      table_name
    );
  end loop;
end $$;

alter table africlub_game.game_templates enable row level security;
alter table africlub_game.question_sources enable row level security;
alter table africlub_game.question_drafts enable row level security;
alter table africlub_game.questions enable row level security;
alter table africlub_game.question_packs enable row level security;
alter table africlub_game.question_pack_questions enable row level security;
alter table africlub_game.tv_devices enable row level security;
alter table africlub_game.game_sessions enable row level security;
alter table africlub_game.session_teams enable row level security;
alter table africlub_game.session_players enable row level security;
alter table africlub_game.session_questions enable row level security;
alter table africlub_game.answer_attempts enable row level security;
alter table africlub_game.answer_claims enable row level security;
alter table africlub_game.points_ledger enable row level security;
alter table africlub_game.audit_log enable row level security;

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
    'tv_devices',
    'game_sessions',
    'session_teams',
    'session_players',
    'session_questions',
    'answer_attempts',
    'answer_claims',
    'points_ledger',
    'audit_log'
  ] loop
    execute format('drop policy if exists %I on africlub_game.%I', table_name || '_club_read', table_name);
    execute format(
      'create policy %I on africlub_game.%I for select using (club_id = africlub_game.current_club_id() or africlub_game.is_game_admin(club_id))',
      table_name || '_club_read',
      table_name
    );
    execute format('drop policy if exists %I on africlub_game.%I', table_name || '_admin_write', table_name);
    execute format(
      'create policy %I on africlub_game.%I for all to authenticated using (africlub_game.is_game_admin(club_id)) with check (africlub_game.is_game_admin(club_id))',
      table_name || '_admin_write',
      table_name
    );
  end loop;
end $$;

drop policy if exists session_players_insert_self on africlub_game.session_players;
create policy session_players_insert_self
on africlub_game.session_players
for insert
to authenticated
with check (
  club_id = africlub_game.current_club_id()
  and (user_id is null or user_id = auth.uid())
);

drop policy if exists answer_attempts_insert_self on africlub_game.answer_attempts;
create policy answer_attempts_insert_self
on africlub_game.answer_attempts
for insert
to authenticated
with check (
  club_id = africlub_game.current_club_id()
  and exists (
    select 1
    from africlub_game.session_players sp
    where sp.id = session_player_id
      and sp.user_id = auth.uid()
      and sp.session_id = answer_attempts.session_id
  )
);

create or replace function africlub_game.get_tv_session_state(p_session_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_question record;
  v_claim record;
  v_question_total integer := 0;
  v_current_club_id bigint;
begin
  select *
    into v_session
  from africlub_game.game_sessions
  where id = p_session_id;

  if not found then
    raise exception 'Game session not found';
  end if;

  v_current_club_id := africlub_game.current_club_id();

  if not (
    (v_current_club_id is not null and v_session.club_id = v_current_club_id)
    or africlub_game.is_game_admin(v_session.club_id)
    or exists (
      select 1
      from africlub_game.session_players sp
      where sp.session_id = v_session.id
        and sp.user_id = auth.uid()
    )
  ) then
    raise exception 'Not authorized for this game session';
  end if;

  select sq.id as session_question_id,
         sq.ordinal,
         sq.state,
         sq.opened_at,
         sq.claimed_at,
         sq.revealed_at,
         q.prompt,
         q.options,
         q.category,
         q.difficulty
    into v_question
  from africlub_game.session_questions sq
  join africlub_game.questions q on q.id = sq.question_id
  where sq.id = v_session.current_session_question_id;

  select count(*)
    into v_question_total
  from africlub_game.session_questions
  where session_id = v_session.id;

  select ac.id,
         ac.session_player_id,
         ac.team_id,
         ac.points_awarded,
         ac.claimed_at,
         sp.display_name,
         st.name as team_name
    into v_claim
  from africlub_game.answer_claims ac
  join africlub_game.session_players sp on sp.id = ac.session_player_id
  left join africlub_game.session_teams st on st.id = ac.team_id
  where ac.session_question_id = v_session.current_session_question_id;

  return jsonb_build_object(
    'sessionId', v_session.id,
    'clubId', v_session.club_id,
    'title', v_session.title,
    'phase', case
      when v_question.session_question_id is null then 'lobby'
      when v_question.state = 'skipped' then 'closed'
      else v_question.state
    end,
    'joinCode', v_session.join_code,
    'questionIndex', coalesce(v_question.ordinal, 0),
    'questionTotal', v_question_total,
    'currentQuestion', case when v_question.session_question_id is null
      then null
      else jsonb_build_object(
        'id', v_question.session_question_id,
        'order', v_question.ordinal,
        'phase', case
          when v_question.state = 'skipped' then 'closed'
          else v_question.state
        end,
        'prompt', v_question.prompt,
        'category', v_question.category,
        'difficulty', v_question.difficulty,
        'timeLimitSeconds', null,
        'openedAt', v_question.opened_at,
        'options', v_question.options,
        'claim', case when v_claim.id is null
          then null
          else jsonb_build_object(
            'playerName', v_claim.display_name,
            'teamName', v_claim.team_name,
            'claimedAt', v_claim.claimed_at
          )
        end
      )
    end,
    'leaderboard', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'rank', ranked.rank,
          'teamName', ranked.team_name,
          'score', sp.score
        )
        order by ranked.rank asc
      )
      from (
        select sp.id,
               sp.score,
               coalesce(st.name, sp.display_name) as team_name,
               row_number() over (order by sp.score desc, sp.joined_at asc) as rank
          from africlub_game.session_players sp
          left join africlub_game.session_teams st on st.id = sp.team_id
         where sp.session_id = v_session.id
      ) ranked
      join africlub_game.session_players sp on sp.id = ranked.id
    ), '[]'::jsonb),
    'updatedAt', v_session.updated_at
  );
end;
$$;

create or replace function africlub_game.join_session(
  p_session_id uuid default null,
  p_join_code text default null,
  p_club_id bigint default null,
  p_display_name text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_player africlub_game.session_players%rowtype;
  v_display_name text;
  v_club_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  v_display_name := nullif(btrim(coalesce(p_display_name, '')), '');
  if v_display_name is null then
    v_display_name := 'Supporter';
  end if;
  v_display_name := left(v_display_name, 48);
  v_club_id := coalesce(p_club_id, africlub_game.current_club_id());

  if p_session_id is not null then
    select *
      into v_session
    from africlub_game.game_sessions
    where id = p_session_id;
  elsif nullif(btrim(coalesce(p_join_code, '')), '') is not null then
    if v_club_id is null then
      raise exception 'club_id is required when joining by code';
    end if;

    select *
      into v_session
    from africlub_game.game_sessions
    where club_id = v_club_id
      and upper(join_code) = upper(btrim(p_join_code));
  else
    raise exception 'session_id or join_code is required';
  end if;

  if not found then
    raise exception 'Game session not found';
  end if;

  if v_club_id is not null and v_session.club_id <> v_club_id then
    raise exception 'Game session is not available for this club';
  end if;

  if v_session.status not in ('scheduled', 'lobby', 'live', 'paused') then
    raise exception 'Game session is not joinable';
  end if;

  insert into africlub_game.session_players (
    club_id,
    session_id,
    user_id,
    display_name,
    last_seen_at
  )
  values (
    v_session.club_id,
    v_session.id,
    auth.uid(),
    v_display_name,
    timezone('utc', now())
  )
  on conflict (session_id, user_id) do update
     set display_name = excluded.display_name,
         last_seen_at = timezone('utc', now())
  returning * into v_player;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    v_session.club_id,
    auth.uid(),
    'session_joined',
    'session_player',
    v_player.id,
    jsonb_build_object('session_id', v_session.id)
  );

  return jsonb_build_object(
    'sessionId', v_session.id,
    'sessionPlayerId', v_player.id,
    'displayName', v_player.display_name,
    'joinCode', v_session.join_code,
    'score', v_player.score,
    'teamId', v_player.team_id,
    'teamName', (
      select st.name
      from africlub_game.session_teams st
      where st.id = v_player.team_id
    )
  );
end;
$$;

create or replace function africlub_game.submit_answer(
  p_session_question_id uuid,
  p_session_player_id uuid,
  p_selected_option_key text,
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_sq africlub_game.session_questions%rowtype;
  v_question africlub_game.questions%rowtype;
  v_player africlub_game.session_players%rowtype;
  v_attempt africlub_game.answer_attempts%rowtype;
  v_claim africlub_game.answer_claims%rowtype;
  v_is_correct boolean;
  v_points integer := 100;
begin
  select *
    into v_sq
  from africlub_game.session_questions
  where id = p_session_question_id
  for update;

  if not found then
    raise exception 'Session question not found';
  end if;

  if v_sq.state <> 'open' then
    raise exception 'Question is not open';
  end if;

  select *
    into v_player
  from africlub_game.session_players
  where id = p_session_player_id
    and session_id = v_sq.session_id;

  if not found then
    raise exception 'Session player not found';
  end if;

  if (v_player.user_id is null or v_player.user_id <> auth.uid())
    and not africlub_game.is_game_admin(v_player.club_id) then
    raise exception 'Not authorized for this player';
  end if;

  select *
    into v_question
  from africlub_game.questions
  where id = v_sq.question_id;

  v_is_correct := lower(btrim(p_selected_option_key)) = lower(btrim(v_question.correct_option_key));

  insert into africlub_game.answer_attempts (
    club_id,
    session_id,
    session_question_id,
    session_player_id,
    selected_option_key,
    is_correct,
    idempotency_key
  )
  values (
    v_sq.club_id,
    v_sq.session_id,
    v_sq.id,
    v_player.id,
    btrim(p_selected_option_key),
    v_is_correct,
    nullif(btrim(coalesce(p_idempotency_key, '')), '')
  )
  on conflict (session_question_id, session_player_id) do nothing
  returning * into v_attempt;

  if v_attempt.id is null then
    select *
      into v_attempt
    from africlub_game.answer_attempts
    where session_question_id = v_sq.id
      and session_player_id = v_player.id;

    return jsonb_build_object(
      'accepted', false,
      'duplicate', true,
      'correct', v_attempt.is_correct,
      'claimed', exists (
        select 1 from africlub_game.answer_claims where answer_attempt_id = v_attempt.id
      )
    );
  end if;

  if not v_is_correct then
    return jsonb_build_object(
      'accepted', true,
      'duplicate', false,
      'correct', false,
      'claimed', false
    );
  end if;

  insert into africlub_game.answer_claims (
    club_id,
    session_id,
    session_question_id,
    answer_attempt_id,
    session_player_id,
    team_id,
    points_awarded
  )
  values (
    v_sq.club_id,
    v_sq.session_id,
    v_sq.id,
    v_attempt.id,
    v_player.id,
    v_player.team_id,
    v_points
  )
  on conflict (session_question_id) do nothing
  returning * into v_claim;

  if v_claim.id is null then
    return jsonb_build_object(
      'accepted', true,
      'duplicate', false,
      'correct', true,
      'claimed', false
    );
  end if;

  update africlub_game.session_questions
     set state = 'claimed',
         claimed_at = v_claim.claimed_at,
         updated_at = timezone('utc', now())
   where id = v_sq.id;

  update africlub_game.session_players
     set score = score + v_points
   where id = v_player.id;

  if v_player.team_id is not null then
    update africlub_game.session_teams
       set score = score + v_points
     where id = v_player.team_id;
  end if;

  insert into africlub_game.points_ledger (
    club_id,
    session_id,
    session_player_id,
    user_id,
    points_type,
    amount,
    related_entity_type,
    related_entity_id,
    idempotency_key
  )
  values (
    v_sq.club_id,
    v_sq.session_id,
    v_player.id,
    v_player.user_id,
    'quiz_claim',
    v_points,
    'answer_claim',
    v_claim.id,
    'quiz_claim:' || v_claim.id::text
  )
  on conflict do nothing;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    v_sq.club_id,
    auth.uid(),
    'question_claimed',
    'session_question',
    v_sq.id,
    jsonb_build_object(
      'claim_id', v_claim.id,
      'session_player_id', v_player.id,
      'points_awarded', v_points
    )
  );

  return jsonb_build_object(
    'accepted', true,
    'duplicate', false,
    'correct', true,
    'claimed', true,
    'claim_id', v_claim.id,
    'points_awarded', v_points
  );
end;
$$;

create or replace function africlub_game.admin_pair_tv_device(
  p_club_id bigint,
  p_device_label text,
  p_pairing_code text,
  p_session_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_device africlub_game.tv_devices%rowtype;
  v_session africlub_game.game_sessions%rowtype;
  v_device_label text;
  v_pairing_code text;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to pair TV devices';
  end if;

  v_device_label := nullif(btrim(coalesce(p_device_label, '')), '');
  v_pairing_code := upper(nullif(btrim(coalesce(p_pairing_code, '')), ''));
  if v_device_label is null then
    raise exception 'device_label is required';
  end if;
  if v_pairing_code is null then
    raise exception 'pairing_code is required';
  end if;

  if p_session_id is not null then
    select *
      into v_session
    from africlub_game.game_sessions
    where id = p_session_id
      and club_id = p_club_id;

    if not found then
      raise exception 'Game session not found';
    end if;
  end if;

  insert into africlub_game.tv_devices (
    club_id,
    device_label,
    pairing_code,
    status,
    current_session_id,
    last_seen_at,
    created_by
  )
  values (
    p_club_id,
    left(v_device_label, 80),
    left(v_pairing_code, 32),
    'paired',
    p_session_id,
    timezone('utc', now()),
    auth.uid()
  )
  on conflict (club_id, pairing_code) do update
     set device_label = excluded.device_label,
         status = 'paired',
         current_session_id = excluded.current_session_id,
         last_seen_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
  returning * into v_device;

  if p_session_id is not null then
    update africlub_game.game_sessions
       set tv_device_id = v_device.id,
           updated_at = timezone('utc', now())
     where id = p_session_id;
  end if;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    p_club_id,
    auth.uid(),
    'tv_device_paired',
    'tv_device',
    v_device.id,
    jsonb_build_object(
      'pairing_code', v_device.pairing_code,
      'session_id', p_session_id
    )
  );

  return jsonb_build_object(
    'tvDeviceId', v_device.id,
    'deviceLabel', v_device.device_label,
    'pairingCode', v_device.pairing_code,
    'sessionId', v_device.current_session_id,
    'status', v_device.status
  );
end;
$$;

create or replace function africlub_game.admin_create_session(
  p_club_id bigint,
  p_title text,
  p_pack_id uuid default null,
  p_tv_device_id uuid default null,
  p_join_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_pack africlub_game.question_packs%rowtype;
  v_tv_device africlub_game.tv_devices%rowtype;
  v_title text;
  v_join_code text;
  v_first_session_question_id uuid;
  v_question_total integer := 0;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to create game sessions';
  end if;

  v_title := nullif(btrim(coalesce(p_title, '')), '');
  if v_title is null then
    raise exception 'title is required';
  end if;

  if p_pack_id is not null then
    select *
      into v_pack
    from africlub_game.question_packs
    where id = p_pack_id
      and club_id = p_club_id
      and status = 'published';

    if not found then
      raise exception 'Published question pack not found';
    end if;
  end if;

  if p_tv_device_id is not null then
    select *
      into v_tv_device
    from africlub_game.tv_devices
    where id = p_tv_device_id
      and club_id = p_club_id;

    if not found then
      raise exception 'TV device not found';
    end if;
  end if;

  v_join_code := upper(nullif(btrim(coalesce(p_join_code, '')), ''));
  if v_join_code is null then
    v_join_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 6));
  end if;

  insert into africlub_game.game_sessions (
    club_id,
    pack_id,
    template_id,
    tv_device_id,
    title,
    status,
    join_code,
    created_by
  )
  values (
    p_club_id,
    p_pack_id,
    v_pack.template_id,
    p_tv_device_id,
    left(v_title, 120),
    'lobby',
    left(v_join_code, 32),
    auth.uid()
  )
  returning * into v_session;

  if p_pack_id is not null then
    insert into africlub_game.session_questions (
      club_id,
      session_id,
      question_id,
      ordinal
    )
    select p_club_id,
           v_session.id,
           qpq.question_id,
           qpq.ordinal
      from africlub_game.question_pack_questions qpq
     where qpq.pack_id = p_pack_id
     order by qpq.ordinal;
  end if;

  select count(*)
    into v_question_total
  from africlub_game.session_questions
  where session_id = v_session.id;

  select id
    into v_first_session_question_id
  from africlub_game.session_questions
  where session_id = v_session.id
  order by ordinal asc
  limit 1;

  if p_tv_device_id is not null then
    update africlub_game.tv_devices
       set status = 'paired',
           current_session_id = v_session.id,
           updated_at = timezone('utc', now())
     where id = p_tv_device_id;
  end if;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    p_club_id,
    auth.uid(),
    'game_session_created',
    'game_session',
    v_session.id,
    jsonb_build_object(
      'pack_id', p_pack_id,
      'tv_device_id', p_tv_device_id,
      'question_total', v_question_total
    )
  );

  return jsonb_build_object(
    'sessionId', v_session.id,
    'joinCode', v_session.join_code,
    'title', v_session.title,
    'status', v_session.status,
    'questionTotal', v_question_total,
    'firstSessionQuestionId', v_first_session_question_id,
    'tvDeviceId', p_tv_device_id
  );
end;
$$;

create or replace function africlub_game.admin_review_question_draft(
  p_draft_id uuid,
  p_decision text,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_draft africlub_game.question_drafts%rowtype;
  v_question africlub_game.questions%rowtype;
  v_decision text;
begin
  select *
    into v_draft
  from africlub_game.question_drafts
  where id = p_draft_id
  for update;

  if not found then
    raise exception 'Question draft not found';
  end if;

  if not africlub_game.is_game_admin(v_draft.club_id) then
    raise exception 'Not authorized to review question drafts';
  end if;

  v_decision := lower(btrim(coalesce(p_decision, '')));
  if v_decision not in ('approved', 'rejected', 'needs_changes') then
    raise exception 'review decision is invalid';
  end if;

  update africlub_game.question_drafts
     set validation_status = v_decision,
         validation_notes = coalesce(p_notes, ''),
         reviewed_by = auth.uid(),
         reviewed_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
   where id = v_draft.id
   returning * into v_draft;

  if v_decision = 'approved' then
    select *
      into v_question
    from africlub_game.questions
    where draft_id = v_draft.id;

    if found then
      update africlub_game.questions
         set source_id = v_draft.source_id,
             prompt = v_draft.prompt,
             options = v_draft.options,
             correct_option_key = v_draft.correct_option_key,
             explanation = v_draft.explanation,
             category = v_draft.category,
             difficulty = v_draft.difficulty,
             language = v_draft.language,
             status = 'approved',
             approved_by = auth.uid(),
             approved_at = timezone('utc', now()),
             updated_at = timezone('utc', now())
       where id = v_question.id
       returning * into v_question;
    else
      insert into africlub_game.questions (
        club_id,
        draft_id,
        source_id,
        prompt,
        options,
        correct_option_key,
        explanation,
        category,
        difficulty,
        language,
        status,
        approved_by,
        approved_at
      )
      values (
        v_draft.club_id,
        v_draft.id,
        v_draft.source_id,
        v_draft.prompt,
        v_draft.options,
        v_draft.correct_option_key,
        v_draft.explanation,
        v_draft.category,
        v_draft.difficulty,
        v_draft.language,
        'approved',
        auth.uid(),
        timezone('utc', now())
      )
      returning * into v_question;
    end if;
  end if;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    v_draft.club_id,
    auth.uid(),
    'question_draft_reviewed',
    'question_draft',
    v_draft.id,
    jsonb_build_object(
      'decision', v_decision,
      'question_id', v_question.id
    )
  );

  return jsonb_build_object(
    'draftId', v_draft.id,
    'decision', v_decision,
    'questionId', v_question.id
  );
end;
$$;

create or replace function africlub_game.admin_publish_question_pack(
  p_club_id bigint,
  p_title text,
  p_question_ids uuid[],
  p_description text default '',
  p_template_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_pack africlub_game.question_packs%rowtype;
  v_title text;
  v_description text;
  v_question_count integer;
  v_distinct_count integer;
  v_valid_count integer;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to publish question packs';
  end if;

  v_title := nullif(btrim(coalesce(p_title, '')), '');
  if v_title is null then
    raise exception 'title is required';
  end if;

  v_description := coalesce(p_description, '');
  v_question_count := coalesce(array_length(p_question_ids, 1), 0);
  if v_question_count <> 20 then
    raise exception 'question pack must contain exactly 20 questions';
  end if;

  select count(distinct question_id)
    into v_distinct_count
  from unnest(p_question_ids) as q(question_id);
  if v_distinct_count <> 20 then
    raise exception 'question pack contains duplicate questions';
  end if;

  select count(*)
    into v_valid_count
  from africlub_game.questions q
  where q.club_id = p_club_id
    and q.status = 'approved'
    and q.id = any(p_question_ids);

  if v_valid_count <> 20 then
    raise exception 'all pack questions must be approved for this club';
  end if;

  if p_template_id is not null and not exists (
    select 1
    from africlub_game.game_templates gt
    where gt.id = p_template_id
      and gt.club_id = p_club_id
      and gt.is_active
  ) then
    raise exception 'active game template not found';
  end if;

  insert into africlub_game.question_packs (
    club_id,
    template_id,
    title,
    description,
    status,
    question_count,
    published_by,
    published_at,
    created_by
  )
  values (
    p_club_id,
    p_template_id,
    left(v_title, 120),
    v_description,
    'published',
    20,
    auth.uid(),
    timezone('utc', now()),
    auth.uid()
  )
  returning * into v_pack;

  insert into africlub_game.question_pack_questions (
    pack_id,
    question_id,
    club_id,
    ordinal
  )
  select v_pack.id,
         ordered.question_id,
         p_club_id,
         ordered.ordinal::integer
  from unnest(p_question_ids) with ordinality as ordered(question_id, ordinal);

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    p_club_id,
    auth.uid(),
    'question_pack_published',
    'question_pack',
    v_pack.id,
    jsonb_build_object('question_count', 20)
  );

  return jsonb_build_object(
    'packId', v_pack.id,
    'title', v_pack.title,
    'status', v_pack.status,
    'questionCount', v_pack.question_count
  );
end;
$$;

create or replace function africlub_game.admin_list_audit_log(
  p_club_id bigint,
  p_limit integer default 25,
  p_action text default null,
  p_entity_type text default null,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game
as $$
declare
  v_limit integer;
  v_offset integer;
  v_action text;
  v_entity_type text;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to inspect game audit logs';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 25), 100));
  v_offset := greatest(0, coalesce(p_offset, 0));
  v_action := nullif(btrim(coalesce(p_action, '')), '');
  v_entity_type := nullif(btrim(coalesce(p_entity_type, '')), '');

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', al.id,
        'action', al.action,
        'entityType', al.entity_type,
        'entityId', al.entity_id,
        'actorId', al.actor_id,
        'createdAt', al.created_at,
        'after', al.after_json
      )
      order by al.created_at desc
    )
    from (
      select *
      from africlub_game.audit_log
      where club_id = p_club_id
        and (v_action is null or action = v_action)
        and (v_entity_type is null or entity_type = v_entity_type)
      order by created_at desc
      limit v_limit
      offset v_offset
    ) al
  ), '[]'::jsonb);
end;
$$;

create or replace function africlub_game.admin_list_question_drafts(
  p_club_id bigint,
  p_status text default null,
  p_search text default null,
  p_limit integer default 25,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, africlub_game
as $$
declare
  v_limit integer;
  v_offset integer;
  v_status text;
  v_search text;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to inspect question drafts';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 25), 100));
  v_offset := greatest(0, coalesce(p_offset, 0));
  v_status := nullif(btrim(coalesce(p_status, '')), '');
  v_search := nullif(btrim(coalesce(p_search, '')), '');

  if v_status is not null and v_status not in (
    'pending_review',
    'approved',
    'rejected',
    'needs_changes'
  ) then
    raise exception 'draft status is invalid';
  end if;

  return coalesce((
    select jsonb_agg(
      jsonb_build_object(
        'id', qd.id,
        'sourceId', qd.source_id,
        'prompt', qd.prompt,
        'category', qd.category,
        'difficulty', qd.difficulty,
        'language', qd.language,
        'validationStatus', qd.validation_status,
        'validationNotes', qd.validation_notes,
        'duplicatePromptCount', coalesce(duplicates.prompt_count, 0),
        'hasDuplicatePrompt', coalesce(duplicates.prompt_count, 0) > 0,
        'similarPromptCount', coalesce(similar_prompts.prompt_count, 0),
        'hasSimilarPrompt', coalesce(similar_prompts.prompt_count, 0) > 0,
        'duplicateRiskLevel', case
          when coalesce(duplicates.prompt_count, 0) > 0 then 'exact'
          when coalesce(similar_prompts.prompt_count, 0) > 0 then 'normalized'
          else 'none'
        end,
        'normalizedPromptSignature', africlub_game.normalize_question_prompt(qd.prompt),
        'sourceTitle', qs.source_title,
        'sourceUrl', qs.source_url,
        'sourceTrustTier', qs.trust_tier,
        'createdAt', qd.created_at
      )
      order by qd.created_at desc
    )
    from (
      select *
      from africlub_game.question_drafts
      where club_id = p_club_id
        and (v_status is null or validation_status = v_status)
        and (
          v_search is null or
          prompt ilike '%' || v_search || '%' or
          category ilike '%' || v_search || '%'
        )
      order by created_at desc
      limit v_limit
      offset v_offset
    ) qd
    left join africlub_game.question_sources qs on qs.id = qd.source_id
    left join lateral (
      select count(*)::integer as prompt_count
      from africlub_game.question_drafts duplicate_qd
      where duplicate_qd.club_id = p_club_id
        and duplicate_qd.id <> qd.id
        and lower(btrim(duplicate_qd.prompt)) = lower(btrim(qd.prompt))
    ) duplicates on true
    left join lateral (
      select count(*)::integer as prompt_count
      from africlub_game.question_drafts similar_qd
      where similar_qd.club_id = p_club_id
        and similar_qd.id <> qd.id
        and africlub_game.normalize_question_prompt(similar_qd.prompt) =
            africlub_game.normalize_question_prompt(qd.prompt)
    ) similar_prompts on true
  ), '[]'::jsonb);
end;
$$;

create or replace function africlub_game.admin_open_question(
  p_session_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_sq africlub_game.session_questions%rowtype;
begin
  select *
    into v_sq
  from africlub_game.session_questions
  where id = p_session_question_id
  for update;

  if not found then
    raise exception 'Session question not found';
  end if;

  if not africlub_game.is_game_admin(v_sq.club_id) then
    raise exception 'Not authorized to open this question';
  end if;

  update africlub_game.session_questions
     set state = 'open',
         opened_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
   where id = v_sq.id;

  update africlub_game.game_sessions
     set status = 'live',
         current_session_question_id = v_sq.id,
         started_at = coalesce(started_at, timezone('utc', now())),
         updated_at = timezone('utc', now())
   where id = v_sq.session_id;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    v_sq.club_id,
    auth.uid(),
    'question_opened',
    'session_question',
    v_sq.id,
    jsonb_build_object('session_id', v_sq.session_id, 'ordinal', v_sq.ordinal)
  );

  return jsonb_build_object('opened', true, 'session_question_id', v_sq.id);
end;
$$;

create or replace function africlub_game.admin_reveal_question(
  p_session_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_sq africlub_game.session_questions%rowtype;
begin
  select *
    into v_sq
  from africlub_game.session_questions
  where id = p_session_question_id
  for update;

  if not found then
    raise exception 'Session question not found';
  end if;

  if not africlub_game.is_game_admin(v_sq.club_id) then
    raise exception 'Not authorized to reveal this question';
  end if;

  update africlub_game.session_questions
     set state = 'revealed',
         revealed_at = timezone('utc', now()),
         updated_at = timezone('utc', now())
   where id = v_sq.id;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id
  )
  values (
    v_sq.club_id,
    auth.uid(),
    'question_revealed',
    'session_question',
    v_sq.id
  );

  return jsonb_build_object('revealed', true, 'session_question_id', v_sq.id);
end;
$$;

create or replace function africlub_game.admin_advance_question(
  p_session_question_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_sq africlub_game.session_questions%rowtype;
  v_next_sq africlub_game.session_questions%rowtype;
begin
  select *
    into v_sq
  from africlub_game.session_questions
  where id = p_session_question_id
  for update;

  if not found then
    raise exception 'Session question not found';
  end if;

  if not africlub_game.is_game_admin(v_sq.club_id) then
    raise exception 'Not authorized to advance this question';
  end if;

  update africlub_game.session_questions
     set state = case when state in ('closed', 'skipped') then state else 'closed' end,
         closed_at = coalesce(closed_at, timezone('utc', now())),
         updated_at = timezone('utc', now())
   where id = v_sq.id;

  select *
    into v_next_sq
  from africlub_game.session_questions
  where session_id = v_sq.session_id
    and ordinal > v_sq.ordinal
    and state in ('queued', 'open', 'claimed', 'revealed')
  order by ordinal asc
  limit 1
  for update;

  if found then
    update africlub_game.session_questions
       set state = 'queued',
           updated_at = timezone('utc', now())
     where id = v_next_sq.id;

    update africlub_game.game_sessions
       set status = 'live',
           current_session_question_id = v_next_sq.id,
           updated_at = timezone('utc', now())
     where id = v_sq.session_id;

    insert into africlub_game.audit_log (
      club_id,
      actor_id,
      action,
      entity_type,
      entity_id,
      after_json
    )
    values (
      v_sq.club_id,
      auth.uid(),
      'game_question_advanced',
      'session_question',
      v_sq.id,
      jsonb_build_object(
        'session_id', v_sq.session_id,
        'previous_session_question_id', v_sq.id,
        'next_session_question_id', v_next_sq.id,
        'next_ordinal', v_next_sq.ordinal
      )
    );

    return jsonb_build_object(
      'sessionId', v_sq.session_id,
      'previousSessionQuestionId', v_sq.id,
      'nextSessionQuestionId', v_next_sq.id,
      'status', 'live',
      'isComplete', false
    );
  end if;

  update africlub_game.game_sessions
     set status = 'complete',
         current_session_question_id = null,
         ended_at = coalesce(ended_at, timezone('utc', now())),
         updated_at = timezone('utc', now())
   where id = v_sq.session_id;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    v_sq.club_id,
    auth.uid(),
    'game_session_completed',
    'game_session',
    v_sq.session_id,
    jsonb_build_object(
      'previous_session_question_id', v_sq.id,
      'reason', 'question_sequence_complete'
    )
  );

  return jsonb_build_object(
    'sessionId', v_sq.session_id,
    'previousSessionQuestionId', v_sq.id,
    'nextSessionQuestionId', null,
    'status', 'complete',
    'isComplete', true
  );
end;
$$;

create or replace function africlub_game.admin_close_session(
  p_session_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game
as $$
declare
  v_session africlub_game.game_sessions%rowtype;
  v_closed_count integer := 0;
begin
  select *
    into v_session
  from africlub_game.game_sessions
  where id = p_session_id
  for update;

  if not found then
    raise exception 'Game session not found';
  end if;

  if not africlub_game.is_game_admin(v_session.club_id) then
    raise exception 'Not authorized to close this session';
  end if;

  update africlub_game.session_questions
     set state = case when state = 'skipped' then 'skipped' else 'closed' end,
         closed_at = coalesce(closed_at, timezone('utc', now())),
         updated_at = timezone('utc', now())
   where session_id = v_session.id
     and state in ('queued', 'open', 'claimed', 'revealed');

  get diagnostics v_closed_count = row_count;

  update africlub_game.game_sessions
     set status = 'complete',
         current_session_question_id = null,
         ended_at = coalesce(ended_at, timezone('utc', now())),
         updated_at = timezone('utc', now())
   where id = v_session.id;

  update africlub_game.tv_devices
     set current_session_id = null,
         updated_at = timezone('utc', now())
   where current_session_id = v_session.id;

  insert into africlub_game.audit_log (
    club_id,
    actor_id,
    action,
    entity_type,
    entity_id,
    after_json
  )
  values (
    v_session.club_id,
    auth.uid(),
    'game_session_closed',
    'game_session',
    v_session.id,
    jsonb_build_object('closed_question_count', v_closed_count)
  );

  return jsonb_build_object(
    'sessionId', v_session.id,
    'status', 'complete',
    'closedQuestionCount', v_closed_count
  );
end;
$$;

grant usage on schema africlub_game to anon, authenticated, service_role;
grant select on all tables in schema africlub_game to authenticated, service_role;
grant insert on africlub_game.session_players to authenticated;
grant insert on africlub_game.answer_attempts to authenticated;
grant all on all tables in schema africlub_game to service_role;

grant execute on function africlub_game.get_tv_session_state(uuid) to authenticated, service_role;
grant execute on function africlub_game.join_session(uuid, text, bigint, text) to authenticated, service_role;
grant execute on function africlub_game.submit_answer(uuid, uuid, text, text) to authenticated, service_role;
grant execute on function africlub_game.admin_create_session(bigint, text, uuid, uuid, text) to authenticated, service_role;
grant execute on function africlub_game.admin_pair_tv_device(bigint, text, text, uuid) to authenticated, service_role;
grant execute on function africlub_game.admin_review_question_draft(uuid, text, text) to authenticated, service_role;
grant execute on function africlub_game.admin_publish_question_pack(bigint, text, uuid[], text, uuid) to authenticated, service_role;
grant execute on function africlub_game.admin_list_audit_log(bigint, integer, text, text, integer) to authenticated, service_role;
grant execute on function africlub_game.admin_list_question_drafts(bigint, text, text, integer, integer) to authenticated, service_role;
grant execute on function africlub_game.admin_open_question(uuid) to authenticated, service_role;
grant execute on function africlub_game.admin_reveal_question(uuid) to authenticated, service_role;
grant execute on function africlub_game.admin_advance_question(uuid) to authenticated, service_role;
grant execute on function africlub_game.admin_close_session(uuid) to authenticated, service_role;

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table africlub_game.game_sessions;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table africlub_game.session_questions;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table africlub_game.session_players;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table africlub_game.answer_claims;
    exception when duplicate_object then null;
    end;
    begin
      alter publication supabase_realtime add table africlub_game.tv_devices;
    exception when duplicate_object then null;
    end;
  end if;
end $$;

commit;

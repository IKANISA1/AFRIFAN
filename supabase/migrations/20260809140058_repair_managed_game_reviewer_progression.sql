-- Keep already-uploaded mobile clients compatible with managed-game sessions:
-- initialize a deterministic first question, normalize their transition payload,
-- and keep queued question content off TV displays until the question opens.

begin;

create or replace function africlub_game.initialize_scheduled_session_question_v2()
returns trigger
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_first_question_id uuid;
begin
  select session_question.id into v_first_question_id
  from africlub_game.session_questions session_question
  where session_question.session_id = new.session_id
  order by session_question.ordinal, session_question.id
  limit 1;

  update africlub_game.game_sessions session_row
  set current_session_question_id = v_first_question_id
  where session_row.id = new.session_id
    and session_row.club_id = new.club_id
    and session_row.lifecycle_phase = 'scheduled'
    and v_first_question_id is not null
    and session_row.current_session_question_id is distinct from v_first_question_id;

  return new;
end;
$$;

drop trigger if exists session_questions_initialize_scheduled_question_v2
on africlub_game.session_questions;
create trigger session_questions_initialize_scheduled_question_v2
after insert on africlub_game.session_questions
for each row execute function africlub_game.initialize_scheduled_session_question_v2();

revoke all on function africlub_game.initialize_scheduled_session_question_v2()
from public, anon, authenticated, service_role;

-- Repair scheduled sessions created before this migration without changing
-- active, completed, cancelled, or explicitly positioned sessions.
with first_questions as (
  select distinct on (session_question.session_id)
    session_question.session_id,
    session_question.id
  from africlub_game.session_questions session_question
  order by
    session_question.session_id,
    session_question.ordinal,
    session_question.id
)
update africlub_game.game_sessions session_row
set current_session_question_id = first_question.id
from first_questions first_question
where session_row.id = first_question.session_id
  and session_row.lifecycle_phase = 'scheduled'
  and session_row.current_session_question_id is null;

-- Build 6 sends the current question identifier again when moving from reveal
-- to question_open. Treat that legacy-compatible payload as "open next". A
-- lobby client with no current identifier receives the deterministic first
-- queued question instead.
create or replace function public.transition_managed_game_session_v2(
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
  v_session africlub_game.game_sessions%rowtype;
  v_effective_question_id uuid := p_session_question_id;
begin
  if p_requested_phase = 'question_open' then
    select session_row.* into v_session
    from africlub_game.game_sessions session_row
    where session_row.id = p_session_id
      and africlub_game.can_organize_session(session_row.id)
    for update;

    if v_session.id is not null
       and v_session.lifecycle_phase = 'activated_lobby'
       and v_effective_question_id is null then
      select session_question.id into v_effective_question_id
      from africlub_game.session_questions session_question
      where session_question.session_id = v_session.id
        and session_question.state <> 'closed'
      order by session_question.ordinal, session_question.id
      limit 1;
    elsif v_session.id is not null
       and v_session.lifecycle_phase = 'reveal'
       and (
         v_effective_question_id is null
         or v_effective_question_id = v_session.current_session_question_id
       ) then
      select candidate.id into v_effective_question_id
      from africlub_game.session_questions current_question
      join africlub_game.session_questions candidate
        on candidate.session_id = current_question.session_id
       and candidate.ordinal > current_question.ordinal
       and candidate.state <> 'closed'
      where current_question.id = v_session.current_session_question_id
        and current_question.session_id = v_session.id
      order by candidate.ordinal, candidate.id
      limit 1;

      if v_effective_question_id is null then
        raise exception 'No next session question is available';
      end if;
    end if;
  end if;

  return africlub_game.transition_session_v2(
    p_session_id,
    p_requested_phase,
    p_expected_session_version,
    p_idempotency_key,
    v_effective_question_id,
    p_phase_deadline,
    p_reason
  );
end;
$$;

revoke all on function public.transition_managed_game_session_v2(
  uuid,text,bigint,text,uuid,timestamptz,text
) from public, anon, authenticated, service_role;
grant execute on function public.transition_managed_game_session_v2(
  uuid,text,bigint,text,uuid,timestamptz,text
) to authenticated;

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
      when v_session.lifecycle_phase in ('scheduled', 'activated_lobby')
        then null
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

revoke all on function public.get_tv_game_projection_v2(text)
from public, anon, authenticated, service_role;
grant execute on function public.get_tv_game_projection_v2(text)
to anon, authenticated;

comment on function africlub_game.initialize_scheduled_session_question_v2() is
  'Keeps a scheduled managed session positioned on its deterministic first question.';
comment on function public.transition_managed_game_session_v2(uuid,text,bigint,text,uuid,timestamptz,text) is
  'Normalizes legacy mobile first/next-question payloads before the authoritative versioned transition.';
comment on function public.get_tv_game_projection_v2(text) is
  'Credential-scoped TV projection that withholds queued question content until the session opens it.';

commit;

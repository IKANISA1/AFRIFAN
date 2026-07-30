-- AFRICLUB game runtime contract checks.
-- Run against a migrated database with `supabase test db`.

create extension if not exists pgtap with schema extensions;

begin;

select plan(9);

do $$
begin
  if to_regclass('africlub_game.game_sessions') is null then
    raise exception 'missing africlub_game.game_sessions';
  end if;
  if to_regclass('africlub_game.session_questions') is null then
    raise exception 'missing africlub_game.session_questions';
  end if;
  if to_regclass('africlub_game.answer_attempts') is null then
    raise exception 'missing africlub_game.answer_attempts';
  end if;
  if to_regclass('africlub_game.answer_claims') is null then
    raise exception 'missing africlub_game.answer_claims';
  end if;
end $$;

select pass('game runtime tables exist');

do $$
begin
  if not exists (
    select 1
    from pg_indexes
    where schemaname = 'africlub_game'
      and indexname = 'unique_player_attempt_per_question'
  ) then
    raise exception 'missing one-attempt-per-player index';
  end if;

  if not exists (
    select 1
    from pg_indexes
    where schemaname = 'africlub_game'
      and indexname = 'unique_session_question_claim'
  ) then
    raise exception 'missing first-correct unique claim index';
  end if;
end $$;

select pass('game runtime uniqueness indexes exist');

do $$
begin
  if to_regprocedure('africlub_game.submit_answer(uuid,uuid,text,text)') is null then
    raise exception 'missing submit_answer RPC';
  end if;
  if to_regprocedure('africlub_game.get_tv_session_state(uuid)') is null then
    raise exception 'missing TV-safe state RPC';
  end if;
  if to_regprocedure('africlub_game.join_session(uuid,text,bigint,text)') is null then
    raise exception 'missing join_session RPC';
  end if;
  if to_regprocedure('africlub_game.admin_create_session(bigint,text,uuid,uuid,text)') is null then
    raise exception 'missing admin_create_session RPC';
  end if;
  if to_regprocedure('africlub_game.admin_pair_tv_device(bigint,text,text,uuid)') is null then
    raise exception 'missing admin_pair_tv_device RPC';
  end if;
  if to_regprocedure('africlub_game.admin_review_question_draft(uuid,text,text)') is null then
    raise exception 'missing admin_review_question_draft RPC';
  end if;
  if to_regprocedure('africlub_game.admin_publish_question_pack(bigint,text,uuid[],text,uuid)') is null then
    raise exception 'missing admin_publish_question_pack RPC';
  end if;
  if to_regprocedure('africlub_game.admin_list_audit_log(bigint,integer,text,text,integer)') is null then
    raise exception 'missing admin_list_audit_log RPC';
  end if;
  if to_regprocedure('africlub_game.admin_list_question_drafts(bigint,text,text,integer,integer)') is null then
    raise exception 'missing admin_list_question_drafts RPC';
  end if;
  if to_regprocedure('africlub_game.admin_open_question(uuid)') is null then
    raise exception 'missing admin_open_question RPC';
  end if;
  if to_regprocedure('africlub_game.admin_reveal_question(uuid)') is null then
    raise exception 'missing admin_reveal_question RPC';
  end if;
  if to_regprocedure('africlub_game.admin_advance_question(uuid)') is null then
    raise exception 'missing admin_advance_question RPC';
  end if;
  if to_regprocedure('africlub_game.admin_close_session(uuid)') is null then
    raise exception 'missing admin_close_session RPC';
  end if;
  if to_regprocedure('africlub_game.normalize_question_prompt(text)') is null then
    raise exception 'missing normalize_question_prompt helper';
  end if;
end $$;

select pass('game runtime RPC signatures exist');

do $$
declare
  tv_state_source text;
begin
  select p.prosrc
    into tv_state_source
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'africlub_game'
    and p.proname = 'get_tv_session_state';

  if tv_state_source ~ '''correct_option_key''' or
     tv_state_source ~ '''correct_answer''' or
     tv_state_source ~ '''explanation''' then
    raise exception 'TV session state RPC exposes answer-only fields';
  end if;

  if tv_state_source !~ '''currentQuestion''' or
     tv_state_source !~ '''leaderboard''' or
     tv_state_source !~ '''joinCode''' then
    raise exception 'TV session state RPC does not emit canonical game runtime shape';
  end if;
end $$;

select pass('TV projection is canonical and answer-safe');

do $$
declare
  draft_queue_source text;
begin
  select p.prosrc
    into draft_queue_source
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'africlub_game'
    and p.proname = 'admin_list_question_drafts';

  if draft_queue_source !~ '''duplicatePromptCount''' or
     draft_queue_source !~ '''hasDuplicatePrompt''' or
     draft_queue_source !~ '''similarPromptCount''' or
     draft_queue_source !~ '''hasSimilarPrompt''' or
     draft_queue_source !~ '''duplicateRiskLevel''' or
     draft_queue_source !~ '''sourceTrustTier''' then
    raise exception 'question draft queue does not expose duplicate review metadata';
  end if;

  if draft_queue_source !~ 'offset v_offset' then
    raise exception 'question draft queue does not expose paginated history';
  end if;
end $$;

select pass('question review queue exposes governed QA metadata');

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'game_sessions',
    'session_questions',
    'answer_attempts',
    'answer_claims',
    'points_ledger',
    'tv_devices'
  ] loop
    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'africlub_game'
        and c.relname = table_name
        and c.relrowsecurity
    ) then
      raise exception 'RLS is not enabled on africlub_game.%', table_name;
    end if;
  end loop;
end $$;

select pass('game runtime tables enforce row-level security');

do $$
declare
  table_name text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach table_name in array array[
      'game_sessions',
      'session_questions',
      'session_players',
      'answer_claims',
      'tv_devices'
    ] loop
      if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'africlub_game'
          and tablename = table_name
      ) then
        raise exception 'missing scoped realtime publication table africlub_game.%', table_name;
      end if;
    end loop;
  end if;
end $$;

select pass('game runtime realtime publication is complete when enabled');

do $$
begin
  if to_regprocedure('public.exchange_tv_pairing_code(text,bigint)') is null then
    raise exception 'missing one-time TV pairing exchange';
  end if;
  if to_regprocedure('public.get_tv_display_state_with_credential(text)') is null then
    raise exception 'missing credential-scoped TV display RPC';
  end if;
  if to_regprocedure('africlub_game.admin_revoke_tv_device(bigint,uuid,text)') is null then
    raise exception 'missing audited TV credential revocation RPC';
  end if;
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'africlub_game' and table_name = 'tv_devices'
      and column_name = 'credential_token_hash'
  ) then
    raise exception 'missing hashed TV device credential storage';
  end if;
  if has_function_privilege('anon', 'public.get_tv_display_state(uuid,text,bigint)', 'EXECUTE') then
    raise exception 'legacy TV state RPC remains executable by anon';
  end if;
end $$;

select pass('TV credential RPC and storage contract exists');

do $$
declare
  v_club_id bigint;
  v_device_id uuid;
  v_exchange jsonb;
  v_token text;
  v_state jsonb;
begin
  insert into public.african_football_clubs (club_name, country_name, club_slug)
  values ('TV Credential Contract Club', 'Rwanda', 'tv-credential-contract-club')
  returning id into v_club_id;

  insert into africlub_game.tv_devices (
    club_id, device_label, pairing_code, status, metadata
  ) values (
    v_club_id, 'Contract TV', 'SCREEN24', 'paired',
    jsonb_build_object('venue_name', 'Contract Venue', 'session_code', 'JOIN24')
  ) returning id into v_device_id;

  if exists (
    select 1 from africlub_game.tv_devices
    where id = v_device_id and pairing_code = 'SCREEN24'
  ) then
    raise exception 'raw TV pairing code was persisted';
  end if;

  v_exchange := public.exchange_tv_pairing_code('SCREEN24', v_club_id);
  v_token := v_exchange ->> 'device_token';
  if v_exchange ->> 'code' <> 'paired' or length(v_token) <> 64 then
    raise exception 'TV pairing exchange failed: %', v_exchange;
  end if;
  if exists (
    select 1 from africlub_game.tv_devices
    where id = v_device_id and credential_token_hash = v_token
  ) then
    raise exception 'raw TV credential token was persisted';
  end if;

  v_exchange := public.exchange_tv_pairing_code('SCREEN24', v_club_id);
  if v_exchange ->> 'code' <> 'pairing_code_invalid_or_expired' then
    raise exception 'TV pairing code was reusable: %', v_exchange;
  end if;

  v_state := public.get_tv_display_state_with_credential(v_token);
  if v_state ->> 'status' <> 'ready' or v_state ->> 'credential_status' <> 'valid' then
    raise exception 'credential-scoped TV state failed: %', v_state;
  end if;

  update africlub_game.tv_devices
  set status = 'disabled', credential_revoked_at = timezone('utc', now())
  where id = v_device_id;
  v_state := public.get_tv_display_state_with_credential(v_token);
  if v_state ->> 'code' <> 'credential_revoked_or_invalid' then
    raise exception 'revoked TV credential remained usable: %', v_state;
  end if;
end $$;

select pass('TV pairing exchange is one-time, hashed, scoped, and revocable');

select * from finish();

rollback;

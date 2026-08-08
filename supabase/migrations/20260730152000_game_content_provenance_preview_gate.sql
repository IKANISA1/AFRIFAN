-- Governed question provenance and exact publication-preview acknowledgement.
--
-- Draft rows expose only source, generation, human-review and deterministic
-- QA metadata. Correct answers and option payloads remain outside list
-- projections. Question-pack publication requires a SHA-256 fingerprint of
-- the exact title, description and ordered question IDs reviewed in the
-- Admin mobile/TV previews.

create or replace function africlub_game.enforce_question_draft_pending_review()
returns trigger
language plpgsql
set search_path = public, africlub_game, pg_temp
as $$
begin
  -- Generation and manual import both create drafts. Approval is a separate,
  -- attributable operation and cannot be smuggled through an insert payload.
  new.validation_status := 'pending_review';
  new.validation_notes := 'Awaiting human review.';
  new.reviewed_by := null;
  new.reviewed_at := null;
  return new;
end;
$$;

drop trigger if exists question_drafts_require_human_review
  on africlub_game.question_drafts;
create trigger question_drafts_require_human_review
before insert on africlub_game.question_drafts
for each row execute function
  africlub_game.enforce_question_draft_pending_review();

revoke execute on function africlub_game.enforce_question_draft_pending_review()
  from public, anon, authenticated, service_role;

create or replace function africlub_game.evaluate_question_draft_checks(
  p_draft_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public, africlub_game, pg_temp
as $$
  with draft as (
    select
      qd.*,
      qs.id as joined_source_id,
      qs.source_title,
      qs.extracted_fact,
      qs.trust_tier
    from africlub_game.question_drafts qd
    left join africlub_game.question_sources qs
      on qs.id = qd.source_id
      and qs.club_id = qd.club_id
    where qd.id = p_draft_id
  ), option_stats as (
    select
      draft.id,
      count(*)::integer as option_count,
      count(distinct lower(btrim(option ->> 'key')))::integer
        as distinct_key_count,
      count(*) filter (
        where lower(btrim(option ->> 'key')) =
          lower(btrim(draft.correct_option_key))
      )::integer as matching_answer_count,
      count(distinct regexp_replace(
        lower(btrim(option ->> 'label')),
        '[[:space:][:punct:]]+',
        '',
        'g'
      ))::integer as distinct_label_count,
      coalesce(bool_or(
        lower(btrim(option ->> 'label')) ~
          '^(all|none)[[:space:]]+of[[:space:]]+(the[[:space:]]+)?(above|these)$'
      ), false) as has_ambiguous_option
    from draft
    cross join lateral jsonb_array_elements(draft.options) option
    group by draft.id
  ), duplicate_stats as (
    select
      draft.id,
      count(*) filter (
        where lower(btrim(other.prompt)) = lower(btrim(draft.prompt))
      )::integer as exact_count,
      count(*) filter (
        where africlub_game.normalize_question_prompt(other.prompt) =
          africlub_game.normalize_question_prompt(draft.prompt)
      )::integer as normalized_count
    from draft
    left join africlub_game.question_drafts other
      on other.club_id = draft.club_id
      and other.id <> draft.id
    group by draft.id
  )
  select coalesce((
    select jsonb_build_object(
      'sourcePresent',
        draft.source_id is not null
        and draft.joined_source_id is not null
        and nullif(btrim(draft.source_title), '') is not null,
      'citationPresent',
        nullif(btrim(draft.extracted_fact), '') is not null,
      'sourceTrusted',
        draft.trust_tier in (
          'official',
          'trusted_media',
          'academic',
          'venue_supplied'
        ),
      'schemaVersionPresent',
        nullif(btrim(draft.schema_version), '') is not null,
      'modelMetadataPresent',
        case
          when coalesce(
            nullif(btrim(draft.metadata ->> 'generation_mode'), ''),
            case when nullif(btrim(draft.model_name), '') is null
              then 'manual_import' else 'ai_assisted' end
          ) = 'ai_assisted'
            then nullif(btrim(draft.model_name), '') is not null
          else true
        end,
      'promptLengthValid',
        length(btrim(draft.prompt)) between 10 and 500,
      'exactDuplicateFree', duplicate_stats.exact_count = 0,
      'normalizedDuplicateFree', duplicate_stats.normalized_count = 0,
      'ambiguitySignalsAbsent',
        right(btrim(draft.prompt), 1) = '?'
        and length(draft.prompt) - length(replace(draft.prompt, '?', '')) = 1
        and option_stats.distinct_label_count = option_stats.option_count
        and not option_stats.has_ambiguous_option,
      'answerConsistent',
        option_stats.option_count between 2 and 6
        and option_stats.distinct_key_count = option_stats.option_count
        and option_stats.matching_answer_count = 1,
      'languageSupported', lower(btrim(draft.language)) in ('en', 'fr', 'rw'),
      'policyCompliant',
        lower(concat_ws(
          ' ',
          draft.prompt,
          draft.explanation,
          draft.options::text
        )) !~
          '(betting|gambling|wager|cash[[:space:]-]+prize|real[[:space:]-]+money|mobile[[:space:]]+money)'
    )
    from draft
    join option_stats on option_stats.id = draft.id
    join duplicate_stats on duplicate_stats.id = draft.id
  ), jsonb_build_object(
    'sourcePresent', false,
    'citationPresent', false,
    'sourceTrusted', false,
    'schemaVersionPresent', false,
    'modelMetadataPresent', false,
    'promptLengthValid', false,
    'exactDuplicateFree', false,
    'normalizedDuplicateFree', false,
    'ambiguitySignalsAbsent', false,
    'answerConsistent', false,
    'languageSupported', false,
    'policyCompliant', false
  ));
$$;

revoke all on function africlub_game.evaluate_question_draft_checks(uuid)
  from public, anon, authenticated, service_role;
grant execute on function africlub_game.evaluate_question_draft_checks(uuid)
  to service_role;

comment on function africlub_game.evaluate_question_draft_checks(uuid) is
  'Returns bounded deterministic provenance, duplicate, ambiguity, answer-consistency, language, and entertainment-policy checks for one governed draft.';

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
set search_path = public, africlub_game, pg_temp
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
        'prompt', left(qd.prompt, 500),
        'category', left(qd.category, 80),
        'difficulty', qd.difficulty,
        'language', qd.language,
        'validationStatus', qd.validation_status,
        'validationNotes', left(qd.validation_notes, 1000),
        'duplicatePromptCount', coalesce(duplicates.prompt_count, 0),
        'hasDuplicatePrompt', coalesce(duplicates.prompt_count, 0) > 0,
        'similarPromptCount', coalesce(similar_prompts.prompt_count, 0),
        'hasSimilarPrompt', coalesce(similar_prompts.prompt_count, 0) > 0,
        'duplicateRiskLevel', case
          when coalesce(duplicates.prompt_count, 0) > 0 then 'exact'
          when coalesce(similar_prompts.prompt_count, 0) > 0 then 'normalized'
          else 'none'
        end,
        'normalizedPromptSignature',
          left(africlub_game.normalize_question_prompt(qd.prompt), 500),
        'sourceTitle', left(qs.source_title, 240),
        'sourceUrl', left(qs.source_url, 500),
        'sourceTrustTier', qs.trust_tier,
        'citationFragment', left(nullif(btrim(qs.extracted_fact), ''), 500),
        'schemaVersion', left(nullif(btrim(qd.schema_version), ''), 80),
        'generationMode', case
          when qd.metadata ->> 'generation_mode' = 'ai_assisted'
            or nullif(btrim(qd.model_name), '') is not null
            then 'ai_assisted'
          else 'human_authored'
        end,
        'modelName', left(nullif(btrim(qd.model_name), ''), 160),
        'reviewedAt', qd.reviewed_at,
        'reviewerName', case
          when qd.reviewed_at is null then null
          else left(
            coalesce(
              nullif(btrim(reviewer.full_name), ''),
              'Authorized reviewer'
            ),
            160
          )
        end,
        'qaChecks',
          africlub_game.evaluate_question_draft_checks(qd.id),
        'createdAt', qd.created_at
      )
      order by qd.created_at desc, qd.id
    )
    from (
      select *
      from africlub_game.question_drafts
      where club_id = p_club_id
        and (v_status is null or validation_status = v_status)
        and (
          v_search is null
          or prompt ilike '%' || v_search || '%'
          or category ilike '%' || v_search || '%'
        )
      order by created_at desc, id
      limit v_limit
      offset v_offset
    ) qd
    left join africlub_game.question_sources qs
      on qs.id = qd.source_id
      and qs.club_id = qd.club_id
    left join public.users reviewer on reviewer.id = qd.reviewed_by
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

create or replace function africlub_game.admin_review_question_draft(
  p_draft_id uuid,
  p_decision text,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, pg_temp
as $$
declare
  v_draft africlub_game.question_drafts%rowtype;
  v_question africlub_game.questions%rowtype;
  v_decision text;
  v_checks jsonb;
  v_failed_checks text[];
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

  v_checks := africlub_game.evaluate_question_draft_checks(v_draft.id);
  if v_decision = 'approved' then
    select array_agg(check_name order by check_name)
      into v_failed_checks
    from jsonb_each(v_checks) check_result(check_name, passed)
    where check_name <> 'sourceTrusted'
      and passed <> 'true'::jsonb;

    if coalesce(array_length(v_failed_checks, 1), 0) > 0 then
      raise exception 'draft approval blocked by deterministic checks: %',
        array_to_string(v_failed_checks, ', ');
    end if;
  end if;

  update africlub_game.question_drafts
     set validation_status = v_decision,
         validation_notes = coalesce(p_notes, ''),
         reviewed_by = auth.uid(),
         reviewed_at = timezone('utc', now()),
         metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
           'last_review_checks', v_checks,
           'last_review_decision', v_decision
         ),
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
      'question_id', v_question.id,
      'checks', v_checks
    )
  );

  return jsonb_build_object(
    'draftId', v_draft.id,
    'decision', v_decision,
    'questionId', v_question.id
  );
end;
$$;

comment on function africlub_game.admin_review_question_draft(
  uuid,
  text,
  text
) is
  'Records the attributable human decision and fails approval closed when required provenance or deterministic content checks fail.';

revoke all on function africlub_game.admin_list_question_drafts(
  bigint,
  text,
  text,
  integer,
  integer
) from public, anon, authenticated, service_role;
grant execute on function africlub_game.admin_list_question_drafts(
  bigint,
  text,
  text,
  integer,
  integer
) to authenticated, service_role;

revoke all on function africlub_game.admin_review_question_draft(
  uuid,
  text,
  text
) from public, anon, authenticated, service_role;
grant execute on function africlub_game.admin_review_question_draft(
  uuid,
  text,
  text
) to authenticated, service_role;

-- The superseded overload remains present only so older clients receive a
-- permission failure instead of a changed signature. Harden its stored
-- SECURITY DEFINER configuration before revoking every API role.
alter function africlub_game.admin_publish_question_pack(
  bigint,
  text,
  uuid[],
  text,
  uuid
) set search_path = public, africlub_game, pg_temp;
revoke all on function africlub_game.admin_publish_question_pack(
  bigint,
  text,
  uuid[],
  text,
  uuid
) from public, anon, authenticated, service_role;

create or replace function africlub_game.admin_publish_question_pack(
  p_club_id bigint,
  p_title text,
  p_question_ids uuid[],
  p_description text,
  p_template_id uuid,
  p_preview_fingerprint text
)
returns jsonb
language plpgsql
security definer
set search_path = public, africlub_game, extensions, pg_temp
as $$
declare
  v_pack africlub_game.question_packs%rowtype;
  v_title text;
  v_description text;
  v_question_count integer;
  v_distinct_count integer;
  v_valid_count integer;
  v_source_count integer;
  v_expected_preview_fingerprint text;
begin
  if not africlub_game.is_game_admin(p_club_id) then
    raise exception 'Not authorized to publish question packs';
  end if;

  v_title := nullif(btrim(coalesce(p_title, '')), '');
  if v_title is null then
    raise exception 'title is required';
  end if;
  v_description := btrim(coalesce(p_description, ''));

  v_question_count := coalesce(array_length(p_question_ids, 1), 0);
  if v_question_count <> 20 then
    raise exception 'question pack must contain exactly 20 questions';
  end if;

  select count(distinct question_id)
    into v_distinct_count
  from unnest(p_question_ids) as selected(question_id);
  if v_distinct_count <> 20 then
    raise exception 'question pack contains duplicate questions';
  end if;

  select count(*),
         count(*) filter (
           where question.source_id is not null
             and source.id is not null
             and nullif(btrim(source.source_title), '') is not null
             and nullif(btrim(source.trust_tier), '') is not null
         )
    into v_valid_count, v_source_count
  from africlub_game.questions question
  left join africlub_game.question_sources source
    on source.id = question.source_id
    and source.club_id = question.club_id
  where question.club_id = p_club_id
    and question.status = 'approved'
    and question.approved_at is not null
    and question.id = any(p_question_ids);

  if v_valid_count <> 20 then
    raise exception 'all pack questions must be human-approved for this club';
  end if;
  if v_source_count <> 20 then
    raise exception 'all pack questions must retain source evidence';
  end if;

  v_expected_preview_fingerprint := encode(
    digest(
      v_title || E'\n' || v_description || E'\n' ||
        array_to_string(p_question_ids, ','),
      'sha256'
    ),
    'hex'
  );
  if lower(btrim(coalesce(p_preview_fingerprint, ''))) <>
      v_expected_preview_fingerprint then
    raise exception 'mobile and TV publication previews must be reviewed';
  end if;

  if p_template_id is not null and not exists (
    select 1
    from africlub_game.game_templates template
    where template.id = p_template_id
      and template.club_id = p_club_id
      and template.is_active
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
    left(v_description, 1000),
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
  select
    v_pack.id,
    ordered.question_id,
    p_club_id,
    ordered.ordinal::integer
  from unnest(p_question_ids) with ordinality
    as ordered(question_id, ordinal);

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
    jsonb_build_object(
      'question_count', 20,
      'source_evidence_count', v_source_count,
      'preview_fingerprint', v_expected_preview_fingerprint
    )
  );

  return jsonb_build_object(
    'packId', v_pack.id,
    'title', v_pack.title,
    'status', v_pack.status,
    'questionCount', v_pack.question_count
  );
end;
$$;

revoke all on function africlub_game.admin_publish_question_pack(
  bigint,
  text,
  uuid[],
  text,
  uuid,
  text
) from public, anon, authenticated, service_role;
grant execute on function africlub_game.admin_publish_question_pack(
  bigint,
  text,
  uuid[],
  text,
  uuid,
  text
) to service_role;

comment on function africlub_game.admin_publish_question_pack(
  bigint,
  text,
  uuid[],
  text,
  uuid,
  text
) is
  'Publishes one human-approved, source-backed 20-question pack only after exact mobile and TV preview acknowledgement.';

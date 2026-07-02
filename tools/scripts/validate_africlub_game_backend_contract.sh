#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

migration="supabase/migrations/20260702120000_africlub_game_runtime_foundation.sql"
sql_contract="supabase/tests/game_runtime_contract.sql"
game_action="supabase/functions/game-session-action/index.ts"
draft_action="supabase/functions/generate-question-drafts/index.ts"

for file in "$migration" "$sql_contract" "$game_action" "$draft_action"; do
  if [[ ! -f "$file" ]]; then
    echo "missing backend contract file: $file" >&2
    exit 1
  fi
done

extract_function() {
  local fn="$1"
  awk -v fn="$fn" '
    $0 ~ "create or replace function africlub_game\\." fn "\\(" { in_fn = 1 }
    in_fn { print }
    in_fn && $0 == "$$;" { exit }
  ' "$migration"
}

require_in_file() {
  local pattern="$1"
  local file="$2"
  local label="$3"
  if ! rg -q "$pattern" "$file"; then
    echo "backend contract missing $label: $pattern" >&2
    exit 1
  fi
}

require_in_function() {
  local fn="$1"
  local pattern="$2"
  local label="$3"
  if ! extract_function "$fn" | rg -q "$pattern"; then
    echo "backend contract missing $label in $fn: $pattern" >&2
    exit 1
  fi
}

forbid_in_function() {
  local fn="$1"
  local pattern="$2"
  local label="$3"
  if extract_function "$fn" | rg -q "$pattern"; then
    echo "backend contract forbidden $label in $fn: $pattern" >&2
    exit 1
  fi
}

security_definer_count="$(rg -c "security definer" "$migration")"
search_path_count="$(rg -c "set search_path = public, africlub_game" "$migration")"
if [[ "$security_definer_count" != "$search_path_count" ]]; then
  echo "security-definer functions must all pin search_path ($security_definer_count vs $search_path_count)" >&2
  exit 1
fi

required_tables=(
  game_templates
  question_sources
  question_drafts
  questions
  question_packs
  question_pack_questions
  tv_devices
  game_sessions
  session_teams
  session_players
  session_questions
  answer_attempts
  answer_claims
  points_ledger
  audit_log
)

for table in "${required_tables[@]}"; do
  require_in_file "create table if not exists africlub_game\\.$table" "$migration" "table $table"
  require_in_file "alter table africlub_game\\.$table enable row level security" "$migration" "RLS for $table"
done

required_indexes=(
  "unique_player_attempt_per_question"
  "unique_answer_attempt_idempotency"
  "unique_session_question_claim"
  "unique_points_ledger_idempotency"
)

for index in "${required_indexes[@]}"; do
  require_in_file "$index" "$migration" "idempotency/claim index $index"
done

admin_functions=(
  admin_create_session
  admin_pair_tv_device
  admin_review_question_draft
  admin_publish_question_pack
  admin_list_audit_log
  admin_list_question_drafts
  admin_open_question
  admin_reveal_question
  admin_advance_question
  admin_close_session
)

for fn in "${admin_functions[@]}"; do
  require_in_function "$fn" "is_game_admin" "club-admin authorization"
  require_in_function "$fn" "raise exception 'Not authorized" "authorization error"
done

require_in_function "get_tv_session_state" "'currentQuestion'" "canonical current question payload"
require_in_function "get_tv_session_state" "'leaderboard'" "canonical leaderboard payload"
require_in_function "get_tv_session_state" "'joinCode'" "canonical join-code payload"
forbid_in_function "get_tv_session_state" "correct_option_key|correct_answer|explanation" "answer-only TV payload leakage"

require_in_function "join_session" "auth.uid\\(\\)" "authenticated player ownership"
require_in_function "join_session" "on conflict \\(session_id, user_id\\)" "idempotent join by user"
require_in_function "join_session" "audit_log" "join audit event"

require_in_function "submit_answer" "for update" "question row lock"
require_in_function "submit_answer" "v_player.user_id <> auth.uid\\(\\)" "player ownership check"
require_in_function "submit_answer" "on conflict \\(session_question_id, session_player_id\\) do nothing" "one attempt per player"
require_in_function "submit_answer" "on conflict \\(session_question_id\\) do nothing" "first correct claim"
require_in_function "submit_answer" "points_ledger" "points ledger write"
require_in_function "submit_answer" "idempotency_key" "submission idempotency"
require_in_function "submit_answer" "audit_log" "claim audit event"

require_in_function "admin_publish_question_pack" "question pack must contain exactly 20 questions" "20-question pack rule"
require_in_function "admin_publish_question_pack" "question pack contains duplicate questions" "pack duplicate rejection"
require_in_function "admin_publish_question_pack" "q\\.status = 'approved'" "approved-only publishing"

expected_realtime_tables=(
  game_sessions
  session_questions
  session_players
  answer_claims
  tv_devices
)

for table in "${expected_realtime_tables[@]}"; do
  require_in_file "alter publication supabase_realtime add table africlub_game\\.$table" "$migration" "scoped realtime table $table"
done

for table in answer_attempts points_ledger questions question_drafts question_sources audit_log; do
  if rg -q "alter publication supabase_realtime add table africlub_game\\.$table" "$migration"; then
    echo "sensitive table must not be added to realtime publication: $table" >&2
    exit 1
  fi
done

required_sql_contract_patterns=(
  "RLS is not enabled"
  "TV session state RPC exposes answer-only fields"
  "missing first-correct unique claim index"
  "missing one-attempt-per-player index"
  "question draft queue does not expose duplicate review metadata"
  "missing scoped realtime publication table"
)

for pattern in "${required_sql_contract_patterns[@]}"; do
  require_in_file "$pattern" "$sql_contract" "SQL contract assertion"
done

required_game_action_patterns=(
  "request.method !== \"POST\""
  "requireAuthenticatedCaller\\(request\\)"
  "getAuthorizationHeader\\(request\\)"
  "createUserClient\\(authorization\\)"
  "requireClubAdminCaller\\(request, clubId\\)"
  "const lowerMessage = message.toLowerCase\\(\\)"
  "lowerMessage.includes\\(\"not authorized\"\\)"
  "lowerMessage.includes\\(\"not found\"\\)"
  "lowerMessage.includes\\(\"not open\"\\)"
  "lowerMessage.includes\\(\"already answered\"\\)"
  "requireOptionKey"
  "optionalIdempotencyKey"
  "optionalPositiveInteger\\(body.limit"
  "optionalNonNegativeInteger\\(body.offset"
  "Unsupported game action"
)

for pattern in "${required_game_action_patterns[@]}"; do
  require_in_file "$pattern" "$game_action" "game action validation"
done

required_draft_action_patterns=(
  "request.method !== \"POST\""
  "requireClubAdminCaller\\(request, clubId\\)"
  "additionalProperties: false"
  "strict: true"
  "OPENAI_API_KEY"
  "Manual draft payload supplied by club admin"
  "validation_status: \"pending_review\""
  "correct option key must match one option key exactly"
)

for pattern in "${required_draft_action_patterns[@]}"; do
  require_in_file "$pattern" "$draft_action" "question draft validation"
done

echo "AFRICLUB game backend contract validation passed."

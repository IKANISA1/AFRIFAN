#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

required_files=(
  "docs/africlub_game_architecture_review_and_plan_2026-07-02.md"
  "docs/africlub_game_full_implementation_goal_2026-07-02.md"
  "docs/africlub_game_product_spec.md"
  "docs/africlub_game_implementation_status_2026-07-02.md"
  "tools/scripts/africlub_product_boundary_scan.sh"
  "tools/scripts/scoped_realtime_scan.mjs"
  "tools/scripts/africlub_game_uat_checklist.sh"
  "tools/scripts/africlub_game_validation_evidence.sh"
  "tools/scripts/validate_africlub_mobile_game_controller.sh"
  "tools/scripts/validate_africlub_game_backend_contract.sh"
  "supabase/migrations/20260702120000_africlub_game_runtime_foundation.sql"
  "supabase/tests/game_runtime_contract.sql"
  "supabase/functions/game-session-action/index.ts"
  "supabase/functions/generate-question-drafts/index.ts"
  "apps/rayon_sports/web/src/app/tv-display/page.tsx"
  "apps/rayon_sports/web/src/app/tv-display/tv-display-client.tsx"
  "apps/rayon_sports/web/src/app/tv-display/tv-display-client.test.tsx"
  "apps/rayon_sports/web/src/app/admin/games/page.tsx"
  "apps/rayon_sports/web/src/app/admin/games/games-control-client.tsx"
  "apps/rayon_sports/web/src/app/admin/games/games-control-client.test.tsx"
  "apps/rayon_sports/web/src/app/api/game-session-action/route.ts"
  "apps/rayon_sports/web/src/app/api/game-session-action/route.test.ts"
  "apps/rayon_sports/web/src/app/api/generate-question-drafts/route.ts"
  "apps/rayon_sports/web/src/app/api/generate-question-drafts/route.test.ts"
  "apps/rayon_sports/web/src/lib/game-runtime.ts"
  "apps/rayon_sports/web/src/lib/game-runtime.test.ts"
  "packages/features/feat_gamification/lib/src/screens/game_session_controller_screen.dart"
  "packages/features/feat_gamification/lib/src/screens/game_session_join_screen.dart"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "missing required game implementation file: $file" >&2
    exit 1
  fi
done

required_goal_patterns=(
  "TV/display is the stage"
  "Mobile is the controller"
  "Supabase is the authority"
  "No real-money betting"
  "No correct-answer leakage"
)

for pattern in "${required_goal_patterns[@]}"; do
  if ! rg -q "$pattern" docs/africlub_game_full_implementation_goal_2026-07-02.md; then
    echo "goal missing required pattern: $pattern" >&2
    exit 1
  fi
done

required_migration_patterns=(
  "create schema if not exists africlub_game"
  "game_sessions"
  "session_questions"
  "answer_attempts"
  "answer_claims"
  "join_session"
  "admin_create_session"
  "admin_pair_tv_device"
  "admin_review_question_draft"
  "admin_list_question_drafts"
  "duplicatePromptCount"
  "hasDuplicatePrompt"
  "similarPromptCount"
  "hasSimilarPrompt"
  "duplicateRiskLevel"
  "sourceTrustTier"
  "normalize_question_prompt"
  "admin_publish_question_pack"
  "admin_list_audit_log"
  "admin_advance_question"
  "admin_close_session"
  "submit_answer"
  "get_tv_session_state"
  "p_offset integer default 0"
  "offset v_offset"
  "unique_session_question_claim"
  "unique_player_attempt_per_question"
)

for pattern in "${required_migration_patterns[@]}"; do
  if ! rg -q "$pattern" supabase/migrations/20260702120000_africlub_game_runtime_foundation.sql; then
    echo "game runtime migration missing pattern: $pattern" >&2
    exit 1
  fi
done

required_function_patterns=(
  "get_tv_state"
  "join_session"
  "create_session"
  "pair_tv_device"
  "review_question_draft"
  "list_question_drafts"
  "publish_question_pack"
  "list_audit_log"
  "submit_answer"
  "open_question"
  "reveal_question"
  "advance_question"
  "close_session"
  "requireClubAdminCaller"
)

for pattern in "${required_function_patterns[@]}"; do
  if ! rg -q "$pattern" supabase/functions/game-session-action/index.ts; then
    echo "game session edge function missing pattern: $pattern" >&2
    exit 1
  fi
done

required_draft_generation_patterns=(
  "generate-question-drafts"
  "requireClubAdminCaller"
  "OPENAI_API_KEY"
  "question_sources"
  "question_drafts"
  "pending_review"
  "json_schema"
  "ai_assisted"
  "manual_import"
)

for pattern in "${required_draft_generation_patterns[@]}"; do
  if ! rg -q "$pattern" supabase/functions/generate-question-drafts/index.ts; then
    echo "question draft generation edge function missing pattern: $pattern" >&2
    exit 1
  fi
done

required_web_contract_patterns=(
  "GameTvSessionState"
  "GameJoinSessionResult"
  "GameCreateSessionResult"
  "GamePairTvDeviceResult"
  "GameQuestionDraftReviewResult"
  "GameQuestionDraftQueueRow"
  "duplicatePromptCount"
  "hasDuplicatePrompt"
  "similarPromptCount"
  "hasSimilarPrompt"
  "duplicateRiskLevel"
  "sourceTrustTier"
  "GameQuestionDraftGenerationResult"
  "GamePublishQuestionPackResult"
  "GameAuditLogRow"
  "createGameRuntimeClient"
  "joinSession"
  "createSession"
  "pairTvDevice"
  "generateQuestionDrafts"
  "reviewQuestionDraft"
  "listQuestionDrafts"
  "publishQuestionPack"
  "listAuditLog"
  "advanceQuestion"
  "closeSession"
  "assertTvPayloadIsSafe"
  "buildTvDisplayViewModel"
  "resolveTvSessionId"
)

for pattern in "${required_web_contract_patterns[@]}"; do
  if ! rg -q "$pattern" apps/rayon_sports/web/src/lib/game-runtime.ts; then
    echo "game runtime web contract missing pattern: $pattern" >&2
    exit 1
  fi
done

required_tv_display_patterns=(
  "createGameRuntimeClient"
  "getBrowserSupabase"
  "postgres_changes"
  "session_id=eq."
  "setInterval"
  "sessionId"
  "buildTvDisplayViewModel"
)

for pattern in "${required_tv_display_patterns[@]}"; do
  if ! rg -q "$pattern" apps/rayon_sports/web/src/app/tv-display/tv-display-client.tsx; then
    echo "TV display live client missing pattern: $pattern" >&2
    exit 1
  fi
done

required_admin_control_patterns=(
  "GamesControlClient"
  "createSession"
  "pairTvDevice"
  "reviewQuestionDraft"
  "listQuestionDrafts"
  "publishQuestionPack"
  "listAuditLog"
  "openQuestion"
  "revealQuestion"
  "advanceQuestion"
  "closeSession"
  "Inspect audit"
  "Audit detail"
  "generateQuestionDrafts"
  "createGameRuntimeClient"
)

for pattern in "${required_admin_control_patterns[@]}"; do
  if ! rg -q "$pattern" apps/rayon_sports/web/src/app/admin/games/games-control-client.tsx; then
    echo "admin games control client missing pattern: $pattern" >&2
    exit 1
  fi
done

required_web_route_patterns=(
  "createGameSessionActionRouteHandler"
  "game-session-action"
  "uuidPattern"
  "isUuid\\(body\\.session_id"
  "isUuid\\(body\\.session_question_id\\)"
  "isUuid\\(body\\.session_player_id\\)"
  "optionKeyPattern"
  "joinCodePattern"
  "join_session"
  "create_session"
  "pair_tv_device"
  "review_question_draft"
  "list_question_drafts"
  "publish_question_pack"
  "list_audit_log"
  "advance_question"
  "close_session"
  "rejectInsecureMutation"
  "rejectRateLimitedRequest"
)

for pattern in "${required_web_route_patterns[@]}"; do
  if ! rg -q "$pattern" apps/rayon_sports/web/src/app/api/game-session-action/route.ts; then
    echo "game session web route missing pattern: $pattern" >&2
    exit 1
  fi
done

required_draft_route_patterns=(
  "createGenerateQuestionDraftsRouteHandler"
  "generate-question-drafts"
  "rejectInsecureMutation"
  "rejectRateLimitedRequest"
)

for pattern in "${required_draft_route_patterns[@]}"; do
  if ! rg -q "$pattern" apps/rayon_sports/web/src/app/api/generate-question-drafts/route.ts; then
    echo "question draft generation web route missing pattern: $pattern" >&2
    exit 1
  fi
done

bash -n tools/scripts/africlub_product_boundary_scan.sh
bash -n tools/scripts/validate_africlub_game_goal.sh
bash -n tools/scripts/africlub_game_validation_evidence.sh
bash -n tools/scripts/validate_africlub_mobile_game_controller.sh
bash -n tools/scripts/validate_africlub_game_backend_contract.sh
node --check tools/scripts/scoped_realtime_scan.mjs
bash tools/scripts/africlub_product_boundary_scan.sh --fail-on-findings
node tools/scripts/scoped_realtime_scan.mjs
bash tools/scripts/validate_africlub_mobile_game_controller.sh
bash tools/scripts/validate_africlub_game_backend_contract.sh

echo "AFRICLUB game implementation goal validation passed."

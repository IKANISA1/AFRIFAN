#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

controller="packages/features/feat_gamification/lib/src/screens/game_session_controller_screen.dart"
join_screen="packages/features/feat_gamification/lib/src/screens/game_session_join_screen.dart"
module="packages/features/feat_gamification/lib/src/fanzone_module.dart"
models="packages/features/feat_gamification/lib/src/models/game_session_models.dart"
repository="packages/features/feat_gamification/lib/src/repositories/game_session_repository.dart"
providers="packages/features/feat_gamification/lib/src/game_session_providers.dart"
hub_screen="packages/features/feat_gamification/lib/src/screens/fanzone_hub_screen.dart"
hub_widgets="packages/features/feat_gamification/lib/src/widgets/fanzone_hub_widgets.dart"
activity_screen="packages/features/feat_gamification/lib/src/screens/my_predictions_screen.dart"
activity_detail_screen="packages/features/feat_gamification/lib/src/screens/prediction_detail_screen.dart"
points_screen="packages/features/feat_gamification/lib/src/screens/fet_wallet_screen.dart"
market_selector="packages/features/feat_gamification/lib/src/widgets/market_selector_sheet.dart"
settings_section="packages/features/feat_gamification/lib/src/widgets/fanzone_settings_section.dart"
points_widgets="packages/features/feat_gamification/lib/src/widgets/fet_wallet_widgets.dart"
points_models="packages/features/feat_gamification/lib/src/models/fet_models.dart"

required_files=(
  "$controller"
  "$join_screen"
  "$module"
  "$models"
  "$repository"
  "$providers"
  "$hub_screen"
  "$hub_widgets"
  "$activity_screen"
  "$activity_detail_screen"
  "$points_screen"
  "$market_selector"
  "$settings_section"
  "$points_widgets"
  "$points_models"
)

for file in "${required_files[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "missing mobile game controller file: $file" >&2
    exit 1
  fi
done

required_hub_patterns=(
  "play('play', 'Play'"
  "activity('activity', 'My Activity'"
  "points('points', 'Points'"
  "Enter TV code"
  "Join a live session and use this phone as the controller"
  "Points balance"
  "section=play"
  "section=activity"
  "section=points"
)

for pattern in "${required_hub_patterns[@]}"; do
  if ! rg -Fq "$pattern" "$hub_screen"; then
    echo "mobile Fan Zone hub missing recomposition pattern: $pattern" >&2
    exit 1
  fi
done

for forbidden in "title: 'Wallet'" "label: 'Wallet'" "FET wallet" "Predictions" "prediction days" "FET pool"; do
  if rg -Fq "$forbidden" "$hub_screen" "$hub_widgets"; then
    echo "mobile Fan Zone hub still exposes legacy launch copy: $forbidden" >&2
    exit 1
  fi
done

required_deeper_mobile_patterns=(
  "MY ACTIVITY"
  "Activity unavailable"
  "ACTIVITY DETAIL"
  "CANCEL PICK"
  "title: 'Points'"
  "Points unavailable"
  "Earn points from partner initiatives and promotions."
  "Partner points earned"
  "Add picks to unlock round"
  "Open Round"
  "Round Results"
  "fanzone-my-activity"
  "fanzone-activity-detail"
  "fanzone-points"
  "fanzone-points-history"
)

deeper_mobile_surfaces=(
  "$activity_screen"
  "$activity_detail_screen"
  "$points_screen"
  "$market_selector"
  "$settings_section"
  "$points_widgets"
  "$points_models"
  "$module"
)

for pattern in "${required_deeper_mobile_patterns[@]}"; do
  if ! rg -Fq "$pattern" "${deeper_mobile_surfaces[@]}"; then
    echo "mobile Fan Zone deeper recomposition missing pattern: $pattern" >&2
    exit 1
  fi
done

for forbidden in \
  "MY PREDICTIONS" \
  "Prediction unavailable" \
  "Prediction not found" \
  "PREDICTION DETAIL" \
  "CANCEL PREDICTION" \
  "Prediction Settlement" \
  "FET Wallet" \
  "title: 'Wallet'" \
  "Wallet unavailable" \
  "Wallet activity appears" \
  "Earn FET from partner initiatives" \
  "Partner FET earned" \
  "FET earned" \
  "Add predictions to unlock slip" \
  "Open Slip" \
  "Search markets" \
  "fanzone-my-predictions" \
  "fanzone-prediction-detail" \
  "fanzone-prediction-settlement" \
  "fanzone-wallet" \
  "fanzone-token-history"; do
  if rg -Fq "$forbidden" "${deeper_mobile_surfaces[@]}"; then
    echo "mobile Fan Zone deeper surfaces still expose legacy launch copy: $forbidden" >&2
    exit 1
  fi
done

required_controller_patterns=(
  "GameSessionControllerScreen"
  "GameSessionControllerPhase"
  "ConsumerStatefulWidget"
  "gameSessionControllerStateProvider"
  "gameSessionRepositoryProvider"
  "joinSession"
  "submitAnswer"
  "server confirmation"
  "Local state never decides the winner"
  "idempotencyKey"
  "_submittedAnswersByQuestionId"
  "_withLocalSubmittedAnswerLock"
  "Answer submitted. Waiting for server claim or host reveal."
  "AfriIcons.profile"
  "AfriIcons.clubZone"
  "AfriIcons.live"
)

for pattern in "${required_controller_patterns[@]}"; do
  if ! rg -q "$pattern" "$controller"; then
    echo "mobile controller missing pattern: $pattern" >&2
    exit 1
  fi
done

if rg -q "DateTime\\.now\\(\\).*idempotency|microsecondsSinceEpoch" "$controller"; then
  echo "mobile controller idempotency key must be deterministic for retry semantics" >&2
  exit 1
fi

for pattern in "'answer'," "state.sessionId," "state.sessionQuestionId," "state.sessionPlayerId," "option.key," ".join(':')"; do
  if ! rg -Fq "$pattern" "$controller"; then
    echo "mobile controller missing deterministic answer idempotency tuple: $pattern" >&2
    exit 1
  fi
done

required_route_patterns=(
  "fanzone-game-session-entry"
  "game/:sessionId"
  "fanzone-game-session-controller"
  "GameSessionJoinScreen"
  "GameSessionControllerScreen"
  "/fanzone/game/:sessionId"
  "session_player_id"
  "sessionPlayerId"
  "playerId"
)

for pattern in "${required_route_patterns[@]}"; do
  if ! rg -q "$pattern" "$module"; then
    echo "mobile game route missing pattern: $pattern" >&2
    exit 1
  fi
done

required_model_patterns=(
  "GameSessionControllerState"
  "GameSessionJoinResult"
  "GameAnswerOption"
  "GameLeaderboardRow"
  "fromTvState"
  "canSubmitAnswer"
  "sessionQuestionId"
  "sessionPlayerId"
  "join"
  "waiting"
  "answering"
  "locked"
  "reveal"
  "leaderboard"
  "reconnecting"
)

for pattern in "${required_model_patterns[@]}"; do
  if ! rg -q "$pattern" "$models"; then
    echo "mobile game model missing pattern: $pattern" >&2
    exit 1
  fi
done

required_repository_patterns=(
  "GameSessionRepository"
  "functions.invoke"
  "game-session-action"
  "get_tv_state"
  "join_session"
  "submit_answer"
  "session_question_id"
  "session_player_id"
  "selected_option_key"
  "idempotency_key"
  "joinSessionByCode"
  "findTvPayloadLeakKeys"
  "assertTvPayloadIsSafe"
  "correct_option_key"
  "correct_answer"
)

for pattern in "${required_repository_patterns[@]}"; do
  if ! rg -q "$pattern" "$repository"; then
    echo "mobile game repository missing pattern: $pattern" >&2
    exit 1
  fi
done

required_provider_patterns=(
  "gameSessionRepositoryProvider"
  "gameSessionControllerStateProvider"
  "FutureProvider.family"
  "supabaseClientProvider"
)

for pattern in "${required_provider_patterns[@]}"; do
  if ! rg -q "$pattern" "$providers"; then
    echo "mobile game provider missing pattern: $pattern" >&2
    exit 1
  fi
done

required_join_screen_patterns=(
  "GameSessionJoinScreen"
  "joinSessionByCode"
  "session_player_id"
  "AfriButton"
  "Display name"
  "SESSION CODE"
)

for pattern in "${required_join_screen_patterns[@]}"; do
  if ! rg -q "$pattern" "$join_screen"; then
    echo "mobile game join screen missing pattern: $pattern" >&2
    exit 1
  fi
done

echo "AFRICLUB mobile game controller validation passed."

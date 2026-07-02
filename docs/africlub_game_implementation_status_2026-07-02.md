# AFRICLUB Game Implementation Status

Date: 2026-07-02

Source plan:
`docs/africlub_game_architecture_review_and_plan_2026-07-02.md`

## Implemented In This Slice

- Created a robust implementation goal:
  `docs/africlub_game_full_implementation_goal_2026-07-02.md`
- Created the canonical game product spec:
  `docs/africlub_game_product_spec.md`
- Added product-boundary scan:
  `tools/scripts/africlub_product_boundary_scan.sh`
- Added scoped realtime scan:
  `tools/scripts/scoped_realtime_scan.mjs`
- Added implementation validation gate:
  `tools/scripts/validate_africlub_game_goal.sh`
- Added pilot UAT checklist:
  `tools/scripts/africlub_game_uat_checklist.sh`
- Added repeatable validation evidence runner:
  `tools/scripts/africlub_game_validation_evidence.sh`
- Added additive Supabase game runtime migration:
  `supabase/migrations/20260702120000_africlub_game_runtime_foundation.sql`
- Added SQL contract test:
  `supabase/tests/game_runtime_contract.sql`
- Aligned the `get_tv_session_state` RPC to the canonical TV-safe runtime
  payload used by web and mobile clients.
- Added the `join_session` RPC for idempotent player membership from a session
  deep link or TV join code.
- Added admin `admin_create_session` and `admin_pair_tv_device` RPCs for lobby
  setup and display pairing without manual database writes.
- Added admin `admin_review_question_draft`,
  `admin_publish_question_pack`, and `admin_list_audit_log` RPCs for
  human-reviewed content publishing and operational audit inspection.
- Added admin `admin_list_question_drafts` RPC and audit-log filters for
  searchable content moderation queues and scoped audit review.
- Added exact-prompt duplicate metadata to `admin_list_question_drafts` so
  admins can identify likely repeated AI/manual draft questions before review.
- Added normalized prompt similarity metadata, duplicate risk levels, and source
  trust-tier display to the admin question-draft queue.
- Added offset pagination for admin question-draft queues and audit logs,
  surfaced through the Edge Function, same-origin route, typed web runtime, and
  admin controls.
- Added admin audit row drill-down with actor/entity metadata and formatted
  `after` payload inspection.
- Added authoritative host lifecycle RPCs, Edge actions, web runtime methods,
  and admin controls for `advance_question` and `close_session`.
- Added game action Edge Function facade:
  `supabase/functions/game-session-action/index.ts`
- Added club-admin AI/manual question draft generation Edge Function:
  `supabase/functions/generate-question-drafts/index.ts`
- Added typed web game runtime contract/client:
  `apps/rayon_sports/web/src/lib/game-runtime.ts`
- Added web game runtime contract tests:
  `apps/rayon_sports/web/src/lib/game-runtime.test.ts`
- Added same-origin game action API route:
  `apps/rayon_sports/web/src/app/api/game-session-action/route.ts`
- Added game action API route tests:
  `apps/rayon_sports/web/src/app/api/game-session-action/route.test.ts`
- Added same-origin question draft generation API route:
  `apps/rayon_sports/web/src/app/api/generate-question-drafts/route.ts`
- Added question draft generation API route tests:
  `apps/rayon_sports/web/src/app/api/generate-question-drafts/route.test.ts`
- Added admin game control-room entry page:
  `apps/rayon_sports/web/src/app/admin/games/page.tsx`
- Added admin game controls:
  `apps/rayon_sports/web/src/app/admin/games/games-control-client.tsx`
- Added admin game control tests:
  `apps/rayon_sports/web/src/app/admin/games/games-control-client.test.tsx`
- Added TV display route:
  `apps/rayon_sports/web/src/app/tv-display/page.tsx`
- Added realtime TV display client with polling fallback:
  `apps/rayon_sports/web/src/app/tv-display/tv-display-client.tsx`
- Added TV display realtime subscription tests:
  `apps/rayon_sports/web/src/app/tv-display/tv-display-client.test.tsx`
- Added mobile game controller route:
  `packages/features/feat_gamification/lib/src/fanzone_module.dart`
- Added mobile TV-code join screen:
  `packages/features/feat_gamification/lib/src/screens/game_session_join_screen.dart`
- Added mobile game session state models:
  `packages/features/feat_gamification/lib/src/models/game_session_models.dart`
- Added mobile game session Edge Function repository:
  `packages/features/feat_gamification/lib/src/repositories/game_session_repository.dart`
- Added mobile game session Riverpod providers:
  `packages/features/feat_gamification/lib/src/game_session_providers.dart`
- Added mobile game controller screen:
  `packages/features/feat_gamification/lib/src/screens/game_session_controller_screen.dart`
- Added mobile game controller static validator:
  `tools/scripts/validate_africlub_mobile_game_controller.sh`
- Added backend game contract static validator:
  `tools/scripts/validate_africlub_game_backend_contract.sh`
- Reworked the Fan Zone hub first-level mobile sections into `Play`,
  `My Activity`, and `Points`, with TV-code entry surfaced under Play and
  legacy route/query aliases redirected into the new product sections.
- Added static validation that blocks the Fan Zone hub from regressing to
  launch-facing `Wallet`, `FET wallet`, `Predictions`, or `FET pool` copy.
- Reworked deeper mobile Fan Zone compatibility surfaces below the hub:
  `/fanzone/my`, `/fanzone/my/:predictionId`, `/fanzone/wallet`,
  market selection, point transaction headlines, and Fan Zone notification
  settings now use activity, picks, rounds, and points vocabulary instead of
  launch-facing prediction/wallet/FET vocabulary.
- Renamed the mobile compatibility route names for the same surfaces to
  `fanzone-my-activity`, `fanzone-activity-detail`,
  `fanzone-activity-settlement`, `fanzone-points`, and
  `fanzone-points-history` while preserving existing paths for deep-link
  compatibility.
- Expanded the mobile static validator so it now guards the deeper activity,
  detail, points, market-selection, settings, point-row, and point-model
  surfaces, not only the Fan Zone hub.
- Reworked wider mobile Fan Zone compatibility copy across challenge detail,
  challenge creation, challenge cards, old pick-round/slip widgets, inline
  match cards, match detail pick cards, leaderboards, jackpot/challenge reward
  displays, social/friend/team point labels, token-history semantics,
  notifications, offers, auth gate messaging, and related widget tests so
  active surfaces use picks, points, rounds, and result credits rather than
  launch-facing `FET`, `stake`, `payout`, `wallet`, or `slip` language.
- Expanded the product-boundary scan with explicit Fan Zone legacy-copy
  patterns for token, FET, wallet, prediction-slip, and old challenge wording
  in active screens/widgets.
- Added local backend contract validation for RLS coverage, security-definer
  search paths, admin RPC authorization guards, TV-safe payload shape, answer
  idempotency/first-correct constraints, restricted realtime publication,
  Edge Function request validation, AI draft strict schema, and SQL contract
  assertions.
- Strengthened the mobile controller retry/lockout behavior so successful
  answer submissions use a deterministic idempotency key and keep the local
  answer pad locked for that session question while waiting for server claim or
  host reveal state.
- Fixed the TV realtime publication contract so `session_players` is published
  alongside the TV client subscription, and extended the SQL/backend contract
  checks to require every TV runtime realtime table.
- Strengthened the scoped realtime scanner so AFRICLUB subscriptions to
  `africlub_game` tables must be both visibly scoped and backed by a matching
  `supabase_realtime` publication entry in the game migration.
- Hardened the same-origin game action API route so browser-origin calls must
  use UUID-shaped IDs, valid option keys, valid join codes, and bounded
  idempotency keys before the request is forwarded to the Supabase Edge
  Function.
- Hardened the game action Edge Function error taxonomy so capitalized RPC
  messages such as `Not authorized...`, `Question is not open`, and
  `...not found` are classified into recoverable 4xx responses instead of
  falling through to generic 500 errors.
- Repaired current Fan Zone hub drift back to the product contract: visible
  hub navigation now uses `Play`, `My Activity`, and `Points`, while legacy
  `predictions`, `supporters`, and `wallet` query aliases still resolve to the
  new sections for deep-link compatibility.

## Validation Run

Passed:

- `bash tools/scripts/validate_africlub_game_goal.sh`
- `node tools/scripts/scoped_realtime_scan.mjs`
- `bash tools/scripts/africlub_product_boundary_scan.sh --fail-on-findings`
- `bash tools/scripts/validate_africlub_mobile_game_controller.sh`
- `bash tools/scripts/validate_africlub_game_backend_contract.sh`
- `bash tools/scripts/africlub_game_validation_evidence.sh`
- `npx vitest run src/app/tv-display/tv-display-client.test.tsx src/app/admin/games/games-control-client.test.tsx src/lib/game-runtime.test.ts src/app/api/game-session-action/route.test.ts src/app/api/generate-question-drafts/route.test.ts`
  in `apps/rayon_sports/web`
- `npm run typecheck` in `apps/rayon_sports/web`
- `npm run lint` in `apps/rayon_sports/web` (passes with existing warnings
  outside the new game files)
- `npm run build` in `apps/rayon_sports/web` (passes; Next canary emits
  existing Edge-runtime and middleware deprecation warnings)
- Re-ran `npm run typecheck`, `npm run lint`, and `npm run build` after the
  widened product-boundary cleanup across web engagement/admin/public surfaces;
  all passed, with the same existing lint and Next canary warnings noted above.
- `git diff --check` for the files added in this slice
- Focused source check that `MarketOptionPill` no longer accepts or displays
  odds/multiplier copy
- Focused source check that the mobile controller no longer builds
  timestamp-based answer idempotency keys and keeps a local submitted-answer
  lock keyed by session question until server state advances.
- Evidence runner now records required local gate pass/fail state and explicitly
  reports host-toolchain skips for Deno, Supabase CLI, Postgres, and Flutter
  validation instead of leaving those proof gaps implicit.
- Latest evidence runner result: `failures=0 skips=6`. Skips were the expected
  host-toolchain gates for `deno`, `supabase`, `psql`, and `flutter`.
- Focused API route tests now prove invalid lifecycle and answer UUIDs are
  rejected by `/api/game-session-action` before any upstream Edge Function call.
- Focused source check that Edge RPC error mapping lowercases messages before
  classifying authorization, not-found, not-open, and duplicate-answer cases.
- Focused source check that current Fan Zone hub, quick routes, module route
  names, and redirects no longer expose launch-facing `Predictions`, `Wallet`,
  old prediction route names, or old wallet/history route names.
- Focused source check that the strengthened product-boundary scanner no longer
  finds launch-facing `FET`, token, wallet, prediction-slip, stake, payout, or
  old challenge wording in active Flutter screens/widgets, active web app
  surfaces, or the bundled reward catalog.

Could not run in this host environment:

- `deno check supabase/functions/game-session-action/index.ts`
- `deno check supabase/functions/generate-question-drafts/index.ts`
- SQL contract execution through `supabase test` or `psql`
- Flutter analyzer or widget tests

Reason: `deno`, `supabase`, `psql`, `flutter`, and `dart` were not available
on the command path.

## Known Remaining Gaps Against The Full Plan

The full roadmap is not complete yet. Remaining high-risk items:

- Existing mobile Fan Zone still needs full product recomposition beyond the
  hub and the primary activity/detail/points compatibility surfaces. Legacy
  internal Dart class/file/model/database names remain intentionally preserved
  until Flutter analyzer/widget-test proof is available, and wider
  challenge/social/reward modules still need a backend-safe rename or
  compatibility decision.
- Mobile controller analyzer, widget-test, and device proof still need a
  Flutter-enabled environment. The current static gate covers route wiring,
  TV-safe payload enforcement, deterministic answer idempotency, and local
  submitted-answer lockout, but it is not a replacement for Flutter widget
  tests or device traversal.
- The TV display is a first realtime route/surface with a scoped Supabase
  subscription and polling fallback. Live Supabase runtime proof is still
  pending because the local host lacks Supabase/Deno tooling.
- The admin game page can create sessions, pair displays, generate draft
  candidates, browse/search draft queues, review drafts, publish packs, inspect
  filtered/paginated audit rows, and open/reveal/advance/close sessions. It
  now surfaces exact and normalized prompt duplicate risk plus audit row
  drill-down. It still needs live moderation execution proof before pilot use.
- AI draft generation is wired through a review-gated Edge Function, but it
  still needs live OpenAI/Supabase execution proof in a deployed or local
  Supabase runtime.
- SQL/RLS behavior must be executed against a disposable Supabase database.

## Current Product-Boundary Result

`bash tools/scripts/africlub_product_boundary_scan.sh --fail-on-findings`
passes after launch-facing Fan Zone and admin copy cleanup. The scan now targets
user-facing screens, widgets, admin pages, and selected operational strings
instead of failing on internal database field names alone.

Visible cleanup included:

- Removed odds/multiplier display from pick option pills.
- Removed the Fan Zone odds-format preference.
- Replaced visible stake/payout/jackpot copy with neutral entry, points, and
  bonus-round language.
- Reframed admin wallet operations as supporter points operations.
- Reframed the Fan Zone first-level mobile hub around Play, My Activity, and
  Points, including TV-code entry as the first Play action.
- Reframed deeper mobile activity/detail/points surfaces around picks, rounds,
  points, and audited activity while preserving existing deep-link paths.
- Reframed wider Fan Zone challenge, social, leaderboard, offers, notification,
  token-history, and compatibility pick-round surfaces away from old token and
  prediction-slip copy.
- Reframed web public/supporter engagement widgets and relevant admin rows away
  from old `FET` copy toward points/result-credit copy, and updated the bundled
  reward catalog costs to use points.

## Web Runtime Contract Result

The web app now has a typed game runtime boundary used by both the TV display
route and the admin games entry page. The contract includes:

- TV-safe session state shape.
- Game action request bodies matching the Edge Function facade.
- A client for `get_tv_state`, `submit_answer`, `open_question`,
  `reveal_question`, `advance_question`, and `close_session`.
- A `joinSession` client for authenticated player membership.
- `createSession` and `pairTvDevice` clients for admin control-room setup.
- `reviewQuestionDraft`, `publishQuestionPack`, and `listAuditLog` clients for
  human moderation, 20-question pack publishing, and audit inspection.
- `listQuestionDrafts` client for status/search-filtered draft queue browsing,
  including exact-prompt duplicate review metadata, normalized prompt similarity
  risk, source trust tier, and offset pagination.
- `generateQuestionDrafts` client for source-backed draft creation that remains
  pending until human review.
- Session id resolution for `session_id`, `sessionId`, and `session` query
  parameters.
- A recursive TV payload leak detector for correct-answer and explanation
  fields.
- A display view model shared by TV/admin surfaces.

The backing `africlub_game.get_tv_session_state` RPC now emits the same
canonical shape (`sessionId`, `clubId`, `joinCode`, `currentQuestion`,
`leaderboard`, and `updatedAt`) instead of the earlier nested SQL shape, and the
SQL contract file checks that the RPC source does not expose answer-only fields
to TV/mobile clients.

## Same-Origin Game Action Route Result

The web app now exposes `/api/game-session-action` as the browser-safe route to
the Supabase `game-session-action` Edge Function. The route:

- Blocks cross-site mutations.
- Applies request rate limiting.
- Validates action payload shape before calling Supabase.
- Forwards the caller authorization header and anon key to the Edge Function.
- Preserves upstream success/error payloads and status codes.
- Accepts the `join_session` action for both session-id and join-code flows.
- Accepts `create_session` and `pair_tv_device` actions for club-admin lobby
  setup and TV display pairing.
- Accepts `review_question_draft`, `publish_question_pack`, and
  `list_audit_log` actions for club-admin content governance and audit review.
- Accepts `list_question_drafts` and filtered `list_audit_log` actions for
  draft queue browsing and scoped audit inspection, including positive limits
  and non-negative offsets.
- Accepts `advance_question` and `close_session` actions for club-admin host
  lifecycle control.

## Question Draft Generation Result

The repo now has a separate `/api/generate-question-drafts` route and
`generate-question-drafts` Supabase Edge Function. The route blocks cross-site
mutations, applies rate limiting, validates source payloads, forwards caller
authorization, and preserves upstream responses. The Edge Function requires a
club-admin caller, persists a `question_sources` provenance row, creates
`question_drafts` rows with `validation_status = 'pending_review'`, supports
manual draft import when drafts are supplied, and uses the OpenAI Responses API
with structured JSON output when `OPENAI_API_KEY` is configured.

## Admin Control Room Result

The admin games page now includes a client-side control surface for lobby setup,
TV display pairing, draft generation, human content moderation, pack publishing,
audit inspection, and host question actions. It accepts a club id, session
title, optional published pack id, optional TV device id, TV pairing details,
source provenance fields, draft queue filters, question-draft review details,
exactly 20 approved question ids for pack publishing, audit filters, and
session-question id, then sends `create_session`, `pair_tv_device`,
`generateQuestionDrafts`, `listQuestionDrafts`, `review_question_draft`,
`publish_question_pack`, `list_audit_log`, `open_question`, and
`reveal_question`, `advance_question`, and `close_session` through the shared
game runtime client and same-origin API
routes. Draft rows display exact-prompt duplicate counts when present.
Draft rows also display normalized prompt similarity, duplicate risk level, and
source trust tier when present.
Draft and audit lists now include previous/next controls backed by offset
pagination. Audit rows can be selected for actor/entity metadata and formatted
`after` payload inspection. Component tests cover success and recoverable error
states.

## Mobile Fan Zone Hub Result

The Fan Zone hub now resolves legacy `predictions`, `league`, `wallet`,
`rewards`, and `supporters` query sections into three launch-facing product
sections: `Play`, `My Activity`, and `Points`. The Play tab surfaces TV-code
entry, matchday rounds, and match context. My Activity carries fan identity and
supporter activity. Points carries points balance, rewards, achievements, and
share actions. Existing legacy route names remain in place for compatibility,
but route redirects and presentation decisions now target the new sections.

`tools/scripts/validate_africlub_mobile_game_controller.sh` now checks for the
new hub sections and rejects old launch-facing hub copy such as `Wallet`,
`FET wallet`, `Predictions`, and `FET pool`.

## Mobile Controller Result

The Fan Zone module now exposes `/fanzone/game` as a TV-code entry route and
`/fanzone/game/:sessionId` as a deep-link mobile controller route. The controller
accepts `session_player_id`, `sessionPlayerId`, or `playerId` query parameters
for paired-player contexts, and can also create/recover membership through the
server `join_session` action. The controller now has a typed mobile
model/repository/provider boundary:

- `GameSessionControllerState`, answer option, leaderboard row, and phase models.
- `GameSessionRepository` calls the `game-session-action` Edge Function for
  `get_tv_state`, `join_session`, and `submit_answer`.
- Mobile-side TV payload leak detection rejects answer-only fields such as
  `correct_answer` and `correct_option_key`.
- `gameSessionControllerStateProvider` loads server state through Riverpod.
- The screen supports pull-to-refresh, reconnecting fallback state, and
  idempotent answer submission when a paired `sessionPlayerId` is available.
- `GameSessionJoinScreen` lets a supporter enter the TV code, calls
  `joinSessionByCode`, and navigates into the controller with the returned
  `session_player_id`.

The first controller screen covers the required MVP states: join, waiting,
answering, locked, reveal, leaderboard, and reconnecting. It renders a
server-authority message in the answer pad so the mobile app does not present
local winner decisions as authoritative. Because Flutter/Dart tooling is not
available on this host, validation is currently static through
`tools/scripts/validate_africlub_mobile_game_controller.sh`; full analyzer and
widget-test proof still needs a Flutter-enabled environment.

## TV Display Runtime Result

The TV display route now server-renders an initial safe state and passes the
resolved session id into a client component. When `session_id`, `sessionId`, or
`session` is present, the client subscribes to scoped Supabase Realtime changes
for `game_sessions`, `session_questions`, `answer_claims`, and
`session_players`, then refreshes TV-safe state through `/api/game-session-action`.
It keeps polling as a fallback and keeps rendering the last known safe state if
the connection is temporarily unavailable. Without a session id it remains in
demo mode for local visual review. The Supabase migration now publishes all
four client-subscribed runtime tables plus `tv_devices`, and
`supabase/tests/game_runtime_contract.sql` verifies the publication contract
when the SQL suite runs against a database.

## Next Required Implementation Slice

1. Continue deeper mobile Fan Zone recomposition below the hub: legacy points
   route/file names, activity history, reward detail screens, and compatibility
   redirects.
2. Run the mobile join/player-membership flow through analyzer, widget tests,
   and device UAT in a Flutter-enabled environment.
3. Expand admin games into live moderation execution proof.
4. Run Supabase migration and SQL contract tests in an environment with the
   Supabase CLI or `psql`.

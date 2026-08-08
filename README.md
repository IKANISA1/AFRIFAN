# AFRICLUB PLATFORM

White-label football-club platform with five product surfaces:

1. Flutter native mobile app for authenticated supporters.
2. Flutter native TV app for owner-paired, screen-safe public game projections
   and approved matchday venue experiences.
3. Venue app/portal for venue-scoped operators.
4. Centralized admin PWA for club operators.
5. White-label public website for each club.

Rayon Sports is the reference club profile and seeded default. The platform is not a browser fan portal. Authenticated fan journeys belong in Flutter.

## Product Identity And Priority

AFRICLUB is a football club app first. Product decisions follow this order:

1. Club identity, team, news, fixtures, results, standings, and history.
2. Membership, fan clubs, contributions, projects, tickets, and shop.
3. Selected-match predictions, competitions, and reviewed football or
   approved music trivia.
4. Secondary matchday utilities: venue discovery, check-in, bounded drinks
   ordering, venue game events, promotions, and TV display.

The target supporter navigation is `Home · Club · Fan Zone · Membership`.
Settings belongs behind profile. Venue utilities must not displace club or
football destinations in primary navigation.

The governed implementation sequence and evidence gates are in
[`docs/FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md`](docs/FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md).
It is an active plan, not a completion or release claim.

## Current Architecture

- One Melos monorepo for mobile, web, shared packages, and Supabase migrations.
- Melos 8 configuration lives in the root `pubspec.yaml`; workspace dependency
  resolution starts with `flutter pub get`, and repository commands run through
  `dart run melos`.
- One shared Supabase backend with club-scoped tenancy.
- One canonical tenant model:
  - `club_id` for database scoping.
  - `club_slug` for routing, host mapping, and branding resolution.
  - `partner_id` retained only for archived migration compatibility.

### Controlled implementation checkpoint — 1 August 2026

- The Flutter shell implements `Home · Club · Fan Zone · Membership`; Settings
  is reached through Profile, and a shell contract test protects that hierarchy.
- The canonical Club family covers overview, team, news, fixtures, results,
  standings, history, projects, tickets, and shop. All club-owned client
  operations require `club_id`; legacy partner metadata cannot create scope.
- Strict analysis passes across 64 packages. The deterministic test command
  passes 2,621 tests across 44 test-bearing packages. The web workspace passes
  916 tests across 110 files, typecheck, zero-warning lint, and production
  build.
- The signed-out Admin authentication gate has accepted exact-current local
  production renders at 1280 × 720, 834 × 1194, and 390 × 844 plus one combined
  same-state reference/current/difference review. This closes GAME-ADM-05 only
  for local source/visual scope; authenticated game operations remain open.
- Consumer-web TV now locally completes GAME-WEB-01 with exact positive-club
  channel naming, zero-club rejection, cleanup, authoritative reconnect
  refresh, fail-closed authorization presentation, and pre-reveal answer-leak
  rejection. Live RLS/Realtime, cross-client, device, approval and release
  proof remain open under separate gates.
- The authoritative game backend locally completes GAME-BE-01..06:
  display capabilities are database-bounded, many-display assignment is
  explicit and audited, participant/organizer/admin/TV projections share the
  required version and reconnect contract, and pause/resume plus reasoned
  idempotent skip/early-end controls are enforced. Owner, venue-manager,
  organizer, club-admin, and platform-admin display scope plus club/session
  event authorization and privacy are proven against an isolated database.
  Native TV now binds a dedicated anonymous Auth identity to one active device
  credential and may read only events for explicitly assigned club/session
  pairs. Every event is a refresh hint; stale hints are ignored, channel
  failure triggers authoritative recovery, revocation clears identity, and
  five-second polling is recovery-only. The native-TV suite passes 58 tests
  with zero analyzer issues; the Android TV debug APK builds; the full
  migration chain and all 80 V2 pgTAP checks pass. GAME-TV-02 now also passes
  a fresh isolated Realtime v2.120.3 network execution with Auth-issued access
  tokens: five assigned-TV events arrive in exact order, an unbound identity
  receives zero rows through per-event RLS, the local five-event p95 is 542 ms,
  and revocation stops the next delivery. Shared/live WAN, packet-loss/soak,
  cross-client, physical-device, approval and release proof are not claimed.
- GAME-QA-01 is locally complete: the controlled contract and 80-check
  isolated pgTAP suite cover projection safety, role/action matrices, RLS and
  grants, lifecycle preconditions, idempotency, ordering/version rejection,
  deadlines, audit events, and no answer exposure before reveal. Cross-client,
  physical-device, shared/live, approval and release criteria remain open.
- GAME-QA-02 is locally complete: one six-state fixture drives participant
  mobile, organizer mobile, native TV, and Admin through lobby, open, reveal,
  next, completion, and cancellation with the same authoritative
  phase/version/sequence and surface-appropriate privacy. Forty focused
  Flutter tests and 22 focused Admin tests pass. A real synchronized session,
  network/device timing, accessibility, approval, and release remain open.
- GAME-QA-03 now has a governed eight-clause physical synchronized-session
  matrix and an exact device preflight. The current inventory has no available
  physical phone or native-TV target; one paired iPhone 12 Pro is unavailable,
  while two iOS simulators and the Android TV emulator cannot substitute for
  two physical phones plus one physical TV. Authorized shared-backend use,
  correlated exact-build logs/video, measured network loss/recovery, and named
  privacy/accessibility/QA/operations/release approvals remain open.
- GAME-QA-04 is locally complete for deterministic resilience: one controlled
  matrix binds interruption, late join, app resume, TV restart, duplicate tap,
  stale/out-of-order events, clock skew, role revocation, device revocation,
  partial failure, and recovery to exact executable tests. All 86 focused
  Flutter tests and strict workspace analysis pass. GAME-QA-03 real
  synchronized devices, GAME-QA-05 physical accessibility, GAME-QA-06 exact
  candidate/release, and actual network-timing proof remain open.
- GAME-QA-05 now passes ten of thirteen controlled clauses: 55 native-TV tests
  cover 720p/1080p/4K widget layout, simulated overscan, EN/FR/RW long copy,
  exact 200-percent text, light/dark rendering, D-pad focus/back, reduced
  motion, privacy-safe semantics, and automated private-field rejection. The
  governed golden contract includes the inspected exact-200-percent capture,
  and the current Android TV API 36 APK now has inspected native 1920 x 1080
  and 3840 x 2160 emulator captures of the real isolated-backend pairing
  journey. GAME-QA-05 remains open for physical-TV overscan/remote/
  screen-reader execution, four-hour burn-in soak, accountable privacy
  approval, shared/live execution, and release.
- GAME-QA-06 now has a governed nine-clause matrix and a passing exact-current
  dirty local build subset: unsigned iOS release, ephemeral-signed Android AAB,
  ephemeral-signed native-TV release APK, and web typecheck/zero-warning lint/
  111-file/933-test/production build. The development-signed current iOS app
  also installs and launches on the exact paired iPhone 12 Pro. GAME-QA-06
  remains open for a sealed clean candidate, pinned CI, complete physical UAT/
  assistive technology, production signing/stores, authorized target migration/
  rollback, named approvals, and release.
- GAME-MOB-05 is locally complete under an eleven-clause participant-layout
  contract: 37 focused tests and four exact current-source goldens prove the
  standalone safe-area route, compact/keyboard reachability, EN/FR/RW exact
  200-percent reflow, dark/light, reduced motion, denial, offline retention,
  reconnect with localized last-update time, and retryable timeout. Shared/live
  synchronization, physical-device/assistive-technology, real-network timing,
  accountable approval, signing, stores, deployment, and release remain open.
- GAME-MOB-04 is locally complete under a seven-clause deterministic recovery
  contract: 67 focused tests and the governed offline golden prove network
  loss/restoration, missed-event refresh, foreground resume, uncertain
  session-version recovery, retained safe state, localized last-update, and
  privacy-safe failure recovery. Shared/live, physical-device, real-network
  timing/loss, accountable approval, signing, stores, deployment, and release
  remain open.
- GAME-MOB-03 is locally complete under a seven-clause authoritative
  participant-synchronization contract: 68 focused tests plus the existing
  80-check isolated database contract prove validated club/session scope,
  exact topic-filtered privacy-safe hints, versioned projection refresh,
  monotonic stale/out-of-order rejection, server-time deadlines, prohibited
  client scoring/lifecycle authority, and unexpected-close recovery/cleanup.
  Shared/live delivery, physical-device, real-network ordering/timing,
  accountable approval, signing, stores, deployment, and release remain open.
- GAME-MOB-01 is locally complete under a seven-clause code-free discovery
  contract: 69 focused Flutter tests and 77/77 full-chain isolated pgTAP checks
  prove five governed eligibility sources, live/scheduled grouping, targeted
  deep-link reauthorization, locked live-game notification routing, and
  fail-closed code/private/stale/ineligible data. Shared/live discovery,
  physical-device platform delivery, approval, and release remain open.
- GAME-MOB-02 is locally complete under a seven-clause participant-code
  retirement contract: 98 Flutter tests and 42 Admin web tests prove the Fan
  Zone `Live games` identity, eleven removed legacy source/test files,
  session-ID-only Flutter/Edge/Admin joins, retired EN/FR/RW join-code copy,
  preserved owner `My TVs` one-time challenge pairing, and four reviewed Fan
  Zone golden changes. Shared/live, physical-device, network-timing, approval,
  signing, stores, deployment, and release remain open.
- GAME-ORG-01 is locally complete under an eight-clause organizer contract:
  36 focused Flutter tests, 8 localization tests, and 80/80 isolated pgTAP
  checks prove role-gated approved-pack planning, bounded schedules,
  privacy-safe Fan-ID invitations, authorized display assignment,
  server-advertised activation/start/supervision/completion, and one inspected
  exact 390 x 844 planner golden. Shared/live role/RLS/RPC/audit,
  real-network timing, physical-device/AT, accountable approval, signing,
  stores, deployment, and release remain open.
- GAME-ORG-02 is locally complete under a seven-clause guarded-operations
  contract: 45 focused Flutter tests, 8 localization tests, the unchanged
  80/80 isolated pgTAP evidence, and one corrected and inspected exact
  390 x 844 control golden prove one normal next action separated from
  confirmed exceptions, dedicated bounded-reason skip/early-end RPCs,
  authoritative pause/resume, and conflict/timeout refresh lockout.
  Shared/live role/RLS/RPC/audit, real-network timing, physical-device/AT,
  accountable approval, signing, stores, deployment, and release remain open.
- The current Game Operations package now passes 172 tests with strict
  analysis clean. Planner and live-control refreshes retain only the last
  confirmed safe context while disabling every create or transition action;
  permission loss clears protected organizer data; ambiguous timeout/conflict
  outcomes require explicit authoritative refresh; and definite retryable
  mutation failures preserve one idempotent operation intent. The
  managed-games inventory, session-planner, and live-control matrices are
  now locally closed. The live-control route proves fourteen applicable states
  with empty and selected explicitly N/A, imperative normal-transition copy,
  and primary/exception lockout during authority or mutation uncertainty.
  These local checks do not close shared/live organizer authorization or
  release gates.
- GAME-OWN-01 is locally complete under a seven-clause owner-inventory
  contract: 49 focused Flutter tests, 8 localization tests, a fresh 80/80
  full-chain isolated pgTAP run, and one inspected exact 390 x 844 My TVs
  golden prove club/role-scoped displays, connection and last-seen state, app
  version, bounded capabilities, assigned-session context, safe empty/denied/
  offline recovery, and credential-free projections. Shared/live role/RLS/RPC/
  audit, real displays and network timing, physical-device/AT, accountable
  approval, signing, stores, deployment, and release remain open.
- GAME-OWN-02 is locally complete under a seven-clause owner pairing and
  management contract: 57 focused Flutter tests, 8 localization tests, a
  fresh 80/80 full-chain isolated pgTAP run, and one inspected exact
  390 x 844 TV-detail golden prove native-TV bootstrap entry, server-authorized
  named locations, confirmed audited rename/move/revoke, credential-rotating
  recovery, stable retry lockout, and retirement of obsolete pairing RPCs.
  Shared/live role/RLS/RPC/audit, real displays and network timing,
  physical-device/AT, accountable approval, signing, stores, deployment, and
  release remain open.
- GAME-TV-03 is locally complete under a seven-clause native-TV pairing-only
  contract: 56 native-TV Flutter tests, a fresh 80/80 full-chain isolated
  pgTAP run, zero-issue analysis, and one side-by-side reviewed 1280 x 720
  pairing golden prove hashed short-lived challenge creation, the exact My TVs
  owner QR deep link, pending authenticated claim, one-time secure credential
  exchange, pairing-material removal, revocation, and recovery. Shared/live,
  physical-TV/remote/AT, network timing, accountable approval, production
  signing, stores, deployment, and release remain open.
- GAME-TV-01 is locally complete under a nine-clause native-TV full-projection
  contract: 58 native-TV Flutter tests, the fresh unchanged-backend 80/80
  full-chain isolated pgTAP run, zero-issue analysis, and five exact current-
  source 1280 x 720 goldens prove paired-empty, scheduled, lobby, question/
  choices/countdown, reveal/public result, contiguous privacy-safe standings,
  completion, pause/cancellation, retained-offline, reconnect, and strict
  lifecycle payload validation. Authorized real-network Realtime, shared/live
  cross-client execution, physical-TV/remote/AT, 1080p/4K and soak,
  accountable approval, signing, stores, deployment, and release remain open.
- The fail-closed Flutter copy inventory scans 292 production Dart files and
  has zero pending candidates. EN/FR/RW catalogs have exact 3,183-message
  parity; named linguistic approval and dynamic/API/CMS review remain open.
- Existing executed local database contracts pass 15 pgTAP tests and 74
  Edge/Deno tests; the separate Live Games V2 suite now passes all 80 pgTAP
  checks against an isolated full-migration database. Unsigned
  iOS, ephemeral-key Android, and debug native-TV artifacts build successfully.
- The eleven-route Club family now has 153/153 applicable cells evidenced and
  zero open: bounded loading; truthful empty/fallback behavior; explicit
  refresh and retained-data synchronization; sanitized error, offline,
  permission, conflict, and timeout recovery; focus/press; 200-percent text;
  reduced motion; and dark/light exact-current local captures. Disabled and
  selected are explicitly non-applicable for these read-only information
  surfaces. The Club package passes 194 tests with strict analysis clean.
- The static role-gated `/game-operations` hub closes its six applicable
  focus, held-press, 200-percent text, reduced-motion, dark, and light cells;
  ten non-data states are explicitly not applicable. The authenticated
  `/my-tvs` inventory also closes all fourteen applicable cells with typed
  offline recovery, retained-authority lockout, exact interaction/theme
  evidence, and two explicit N/A decisions. `/my-tvs/pair` closes all sixteen
  applicable cells with valid-field/current-authority gating, named-scope
  privacy, and mutation lockout during synchronization or uncertainty.
  `/my-tvs/:displayId` closes all sixteen management cells with permission
  clearing, valid-change gating, and confirmed recovery/revocation. The
  `/game-operations/sessions` organizer inventory closes all fourteen
  applicable cells with permission clearing and stale-authority lockout; the
  `/game-operations/sessions/new` planner closes all sixteen applicable cells
  with complete-plan gating, organizer-specific offline recovery, selected
  invitee evidence, and all-control lockout during refresh or mutation
  uncertainty. The live-control route closes all fourteen applicable cells,
  with empty and selected explicitly N/A; its normal transition is imperative
  and remains separate from confirmed exception controls.
  Participant discovery at `/fanzone/game` closes 15/15 applicable cells with
  persistent selected explicitly N/A, while `/fanzone/game/:sessionId` closes
  all 16 live-play cells with explicit retained sync, conflict, timeout,
  permission, disabled-answer, focus, held-press, selected-answer, theme,
  motion, and 200-percent-text evidence.
- These are local implementation results, not release approval. The governed
  route ledger contains 176 routes and 2,816 cells: 1,881 cells have admitted
  current evidence, 256 remain open, and 679 are explicitly not applicable.
  Corrected specs exist for the final nine Admin PWA and seven Venue portal
  routes, but all sixteen bundles remain pending until an explicitly authorized
  exact-current browser rerun passes visual review and admission.
  Physical-device, authenticated live operator/backend, production TV signing,
  pinned CI/distribution, store, named linguistic/design/content, and release
  approvals remain external gates; `design_complete=false` remains truthful.

## Product Surfaces

### Flutter Native Fan App

- White-label fan app per club.
- Target mobile hierarchy: Home, Club, Fan Zone, and Membership.
- Club owns official team, news, fixtures, results, standings, history,
  projects, ticket, and shop discovery.
- Fan Zone owns selected-match predictions, competitions, and governed trivia.
- Shared features live in `packages/features/*`.
- Per-club identity lives in `packages/clubs/*`.
- Club apps under `apps/*` are thin shells around shared modules and configuration data.

### Admin PWA

- Centralized multi-club operator workspace.
- Lives in `apps/rayon_sports/web/src/app/admin`.
- Club access is resolved server-side and all admin data operations are scoped by `club_id`.
- Game operations use separate Content Studio, Session Planner, and Live
  Control workspaces. Routine pack, question, session, organizer, and display
  selection is name-led and authorization-bounded; UUID, version, deadline,
  and idempotency details are internal rather than operator entry fields.
- Content Studio shows answer-safe source/citation fragments, schema/model,
  AI/human generation, human-review, and deterministic-QA provenance. New
  drafts are forced to `pending_review`; approval fails closed on missing
  provenance or failed duplicate, ambiguity, answer-consistency, supported-
  language, and entertainment-policy checks. Publishing then requires 20
  unique approved source-backed questions plus acknowledgement of the exact
  mobile/TV preview.

### Flutter Native TV App

- Native Flutter TV app lives in `apps/rayon_sports_tv`.
- Web `/tv-display` remains a browser compatibility/admin pairing surface only.
- Shows the assigned public game projection and screen-safe venue state; it is
  not a participant join-code or private reward-claim surface.
- Uses a dedicated anonymous Auth identity bound to one active revocable device
  credential; event RLS is limited to explicitly assigned sessions, and event
  payloads only trigger authoritative projection refresh.
- Must not expose personal, wallet, check-in identity, or order data.

### Venue App / Portal

- Venue operator surface lives in `apps/rayon_sports/web/src/app/venue`.
- Venue capability is a secondary matchday extension of the football-club
  product, not the app's primary identity.
- Access is scoped by `venue_staff_memberships`.
- Handles assigned-venue dashboard, check-ins, drinks-only top-10 order queue, promotions, TV code, and staff role visibility.

### Public Website

- White-label public club website.
- Lives in `apps/rayon_sports/web/src/app/(site)`.
- Club branding and content resolve from hostname, slug, and club configuration.
- Website hands users off to the supporter app instead of hosting a fan portal.
- Approved venues can be discovered publicly, but check-in and ordering stay in the supporter app.

## Repo Structure

```text
apps/
  rayon_sports/
    web/                  Next.js website + admin PWA
  <club apps>/            Flutter fan apps

packages/
  core/                   shared app shell, routing, auth, network, theme
  features/               shared product features
  clubs/                  per-club config packages

supabase/
  migrations/             schema and tenancy migrations
```

## Platform Rules

- No unscoped club queries on app data.
- No fan web portal surface.
- No public browser check-in or live venue order queues.
- No broad admin or venue-staff console in the supporter app. Only the narrow,
  non-tab, role-gated `My TVs` owner and `Games I manage` organizer journeys
  are permitted; the `/admin` route family remains excluded from consumer
  builds.
- LiveScore data remains source-of-record controlled by admin/server sync.
- FET is a closed-loop monetary-equivalent reward ledger until legal/payment review approves otherwise.
- Predictions are free-to-enter and limited to selected approved matches; no
  odds, staking, payout, or betting copy is permitted.
- AI-assisted trivia is draft-only until reviewed and published through the
  governed content workflow.
- Live games synchronize structured prediction/trivia state only. No live or
  prerecorded video programme, ingest, transcoding, CDN, streaming telemetry,
  or video-rights pipeline is authorized by the current product scope.
- No frontend hardcoding that assumes Rayon outside reference defaults.
- UI changes must follow `DESIGN.md`, the only design authority for this repo.
- Architecture and runbook documents are operational references only. They must
  not redefine product visuals, screen inventories, token values, or interface
  rules outside `DESIGN.md`.

## Common Commands

```bash
flutter pub get
dart run melos run analyze --no-select
dart run melos run test_all --no-select
(cd apps/rayon_sports/web && npm run typecheck && npm test && npm run lint && npm run build)
npx --yes supabase test db
```

## Key Docs

- [docs/FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md](/Volumes/PRO-G40/AFRICLUB/docs/FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md)
- [docs/blueprint.md](/Volumes/PRO-G40/AFRICLUB/docs/blueprint.md)
- [docs/venue_app_architecture.md](/Volumes/PRO-G40/AFRICLUB/docs/venue_app_architecture.md)
- [docs/fet_ledger_and_rewards_policy.md](/Volumes/PRO-G40/AFRICLUB/docs/fet_ledger_and_rewards_policy.md)
- [docs/release/rayon_fullstack_uat_matrix.md](/Volumes/PRO-G40/AFRICLUB/docs/release/rayon_fullstack_uat_matrix.md)
- [DESIGN.md](/Volumes/PRO-G40/AFRICLUB/DESIGN.md)
- [apps/rayon_sports/web/README.md](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/README.md)
- [1supabase.md](/Volumes/PRO-G40/AFRICLUB/1supabase.md)

Confidential & Proprietary — IKANISA Ltd.

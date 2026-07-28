# AFRICLUB Three-Surface Production Readiness Review

Date: 2026-07-18  
Scope: Rayon Sports supporter mobile app, native TV app, and venue operator portal  
Method: current-source review plus fresh static analysis, tests, release validators, native build attempts, dependency audit, and runtime-tool availability checks.

## Executive verdict

None of the three reviewed surfaces is production-ready today.

| Surface | Completion status | Production readiness | Verdict |
|---|---|---|---|
| Supporter mobile app | Broad feature implementation; automated shell and startup contracts exist | Blocked by iOS build configuration, unverified current device flows, release-signing inputs, and incomplete end-to-end release evidence | **Late beta / release-candidate engineering, not releasable** |
| Native TV app | One read-only display surface and one RPC loader are implemented | Blocked by debug release signing, lack of refresh/reconnect behavior, no secure device provisioning lifecycle, and no fresh TV-device test | **Functional prototype / early beta** |
| Venue portal | Dashboard scaffold exists; six advertised routes are aliases of that dashboard | Core operational workflows, staff session enforcement, venue scoping, mutations, error handling, and workflow tests are absent | **Scaffold / pre-alpha** |

The repository contains strong architectural intent, useful backend foundations, and meaningful automated checks. However, existing readiness documents overstate completion because they count successful HTTP rendering and shallow widget tests as end-to-end product readiness.

## Fresh verification summary

### Passed

- Mobile `flutter analyze --no-pub`: no issues.
- Mobile tests from repository root: 19 passed.
- TV `flutter analyze --no-pub`: no issues.
- TV tests: 3 passed (screen-safe render, 1080p overflow, Android TV manifest contract).
- Venue/web TypeScript typecheck: passed.
- Venue/web ESLint: passed with 60 warnings.
- Venue/web Vitest: 24 files and 127 tests passed.
- Venue/web production build: passed, with middleware/Edge Runtime deprecation and compatibility warnings.
- npm audit after clean install: 0 known vulnerabilities.
- `validate_club_release.sh rayon_sports`: passed the repository's static release contract.

### Failed or blocked

- Mobile tests fail when run from `apps/rayon_sports`, because four tests use repository-root-relative file paths. They pass only from repository root. This is a harness/CI contract defect.
- iOS simulator build failed before launch. `apps/rayon_sports/ios/Flutter/Generated.xcconfig` contains an invalid fourth `DART_DEFINES` Base64 item (`HOME_TEAM_NAME=Rayon...` is truncated/missing padding). No current iOS screenshot or runtime flow was accepted.
- No Android emulator is connected, so current Android navigation, permissions, offline, accessibility, and performance flows were not traversed.
- TV Android release signing is explicitly set to the debug signing configuration.
- Venue/web initially could not test because the installed optional native Rolldown binding was missing. A clean `npm ci --legacy-peer-deps` repaired the local dependency tree; plain `npm ci` fails a Next/OpenNext peer-resolution conflict and Node 24 does not match the declared Node 22 engine.
- Android release/debug builds and the iOS unsigned release build were slow/stalled on the external volume during this review and did not produce accepted final artifacts before report cutoff. They must not be counted as passes.
- No authenticated venue staff test account/session was available, and the implemented pages do not provide the promised workflows in any case.

## Critical findings

### P0-1 — Venue portal is a dashboard facade, not an operator application

The routes `/venue/orders`, `/venue/menu`, `/venue/checkins`, `/venue/promotions`, `/venue/tv-code`, and `/venue/staff` all export the same `/venue` dashboard page. There are no route-specific lists, forms, status transitions, menu controls, check-in review tools, campaign actions, TV-code controls, or staff views.

Impact: venue staff cannot perform the operations described in README, architecture, release checklist, or page copy. This alone makes the venue surface pre-alpha.

Required action: implement each bounded workflow with real venue-scoped data, empty/loading/error states, mutation confirmation, audit-event creation, permissions, and focused unit/integration/E2E tests.

### P0-2 — Venue staff authentication and assigned-venue authorization are not enforced in the portal layer

The portal page calls `getVenuePortalSnapshot()` directly. It does not resolve a user session or staff membership. The snapshot uses a server-created anonymous Supabase client and issues aggregate queries without a user JWT. `staffCanOperate` remains the hard-coded `false` from the empty snapshot and is never used to gate the UI.

Impact: depending on RLS, the page either exposes anonymous aggregate counts, silently shows misleading zeroes, or fails to provide any authenticated venue functionality. The UI claim “Staff-only” is not enforced by the route.

Required action: add a force-dynamic venue layout/auth boundary, resolve the authenticated user server-side, select a permitted `venue_staff_memberships` record, scope every query/mutation to its `club_id` and `venue_id`, deny by default, and add cross-venue authorization tests.

### P0-3 — TV release artifact is signed with the Android debug key

`apps/rayon_sports_tv/android/app/build.gradle.kts` assigns the debug signing config to `release`.

Impact: the artifact is not suitable for managed production distribution and has no defensible signing/certificate rotation process.

Required action: mirror the supporter app's external keystore contract, fail release builds when signing inputs are absent, generate an AAB, validate signature/certificate fingerprints, and document Play Console or managed private-channel distribution.

### P0-4 — Supporter iOS build cannot currently launch

The fresh Xcode build fails in “Prepare Flutter Framework” because `DART_DEFINES` contains malformed Base64. The current generated configuration's fourth item is truncated.

Impact: no fresh iOS binary, simulator traversal, screenshot audit, archive, or TestFlight confidence is available.

Required action: regenerate iOS Flutter configuration from the canonical production JSON, validate every `DART_DEFINES` item before Xcode, remove stale generated state from the external volume, and rerun build/run/archive through the repo-local iOS loop.

## High findings

### P1-1 — TV state loads once and never refreshes

The TV app creates one future in `initState`; there is no timer, realtime subscription, reconnect loop, lifecycle refresh, code-expiry countdown, manual retry, or stale-state indicator. All RPC exceptions silently become the same unpaired state.

Impact: rotating codes, expiry, challenge phase, and reward changes can remain stale for the entire process lifetime. Operations cannot distinguish “not paired” from network/backend failure.

Recommendation: add a bounded refresh/realtime strategy, visible connection state and last-updated time, exponential backoff, expiry countdown, remote-safe retry action, and structured telemetry without personal data.

### P1-2 — TV provisioning uses compile-time secrets/identifiers

`TV_DEVICE_ID` and `TV_PAIRING_CODE` are compile-time environment values. There is no first-run pairing flow, token exchange, secure local credential storage, revocation, rotation, or device inventory UI in the native TV app.

Impact: provisioning does not scale operationally and a pairing value can be embedded in/recovered from an artifact.

Recommendation: ship only public backend configuration, perform one-time pairing, exchange the code for a revocable device credential, store it securely, and expose last-seen/revoke/rotate controls in admin.

### P1-3 — Venue errors are concealed as valid zero data

The page catches all snapshot errors and returns an empty snapshot. Individual count errors also return zero. The same visual state therefore represents no activity, missing environment, RLS denial, backend failure, and network failure.

Impact: operators can make incorrect matchday decisions while the system appears healthy.

Recommendation: differentiate loading, permission denied, configuration missing, service unavailable, and genuinely empty states; log a correlation ID; provide retry and operational escalation copy.

### P1-4 — Venue test coverage does not cover the venue product

The web suite passes, but overall line coverage is only 15.75%; `lib/data/venue.ts` is about 15% line-covered, and there are no dedicated tests under the venue routes. Prior UAT proved HTTP 200 at viewports, not staff workflows or authorization.

Recommendation: require route-level component tests, auth/membership tests, RPC contract tests, and authenticated browser flows for all seven venue routes before UAT can be marked passed.

### P1-5 — Current mobile runtime evidence is incomplete

Static analysis and root-invoked tests pass, including a 200% text-scale shell test, but there was no current Android emulator and iOS could not launch. Critical real-world journeys—onboarding/auth restore, deep links, push consent, check-in, drinks ordering, payments/contributions, offline recovery, and account deletion—were not freshly traversed.

Recommendation: create a release-candidate matrix on at least one physical Android, one Android emulator, one iPhone, and one iOS simulator, with backend-backed test accounts and evidence for success, denial, empty, slow, offline, and retry states.

### P1-6 — Web dependency installation is not reproducible under the declared contract

The package declares Node 22, the machine is on Node 24, plain `npm ci` fails a Next/OpenNext peer conflict, and tests initially lacked a native optional binding. `npm ci --legacy-peer-deps` succeeds but bypasses peer resolution.

Recommendation: pin Node via `.nvmrc`/toolchain CI, align supported Next and OpenNext versions, regenerate the lockfile under Node 22, and require plain `npm ci` in CI.

## Medium findings

- Web lint has 60 warnings. Most are unused code, but they signal dead/incomplete surfaces and make real regressions easier to miss. Set a warning budget and reduce it to zero for release-critical directories.
- The TV app hard-codes “Kigali Pele Stadium,” which conflicts with the white-label/no-Rayon-hardcoding architecture and prevents venue-bound runtime branding.
- The TV UI claims “Remote-control friendly focus,” but there is no interactive focus target or remote-navigation flow to verify. The statement is currently marketing copy rather than tested behavior.
- The TV app has only three widget/static tests and no RPC parsing matrix for malformed/expired payloads, reconnect behavior, lifecycle changes, or logging privacy.
- The mobile app's four filesystem contract tests are dependent on current working directory; local developer commands and CI can disagree.
- Flutter dependency resolution reports 78 packages with newer versions incompatible with current constraints. This is not automatically a defect, but requires a scheduled upgrade/security review before a long-lived production launch.
- The web app's current production toolchain emits multiple deprecated-package warnings. Review transitive ownership and remove unsupported packages where practical.
- Store metadata exists for the supporter app, but current public URL resolution, monitored support ownership, current privacy/data-safety accuracy, TestFlight/closed-track sign-off, and store-console configuration were not verified.
- No TV store metadata, TV screenshots, remote-control acceptance checklist, crash/ANR dashboard, or device-fleet operating runbook was found.
- No venue-specific privacy notice, staff onboarding/revocation runbook, audit retention policy, incident workflow, or matchday support SLA was demonstrated.

## Product and UX assessment

### Supporter mobile app

Strengths:

- Shared architecture and route registry cover a broad fan-product surface.
- The shell has current widget tests, navigation tests, startup privacy contracts, and a 200% text-scale check.
- Release metadata and privacy documentation are substantially more mature than the other two surfaces.

UX risks and evidence limits:

- No current screenshots were accepted because iOS did not launch and Android was unavailable.
- Code breadth is not proof that the main journeys are coherent or production-complete.
- Permission timing, form validation, payment trust, slow/offline behavior, screen-reader semantics, focus order, contrast, large-text reflow beyond the shell, and destructive-action recovery remain unverified.

### Native TV app

Strengths:

- The screen intentionally excludes identity, balances, and orders.
- A 1080p no-overflow widget test and Android TV manifest contract exist.
- The information hierarchy is simple and suitable for glance viewing in principle.

UX risks and evidence limits:

- No current TV/emulator screenshot or remote traversal was available.
- One landscape layout is assumed; 720p, 4K, overscan, long venue names, localization, burn-in, low-connectivity, and stale-code behavior are unverified.
- Offline/unpaired/backend-error states are visually indistinguishable.

### Venue portal

Strengths:

- The dashboard uses the repository UI kit, clear operational grouping, non-indexable metadata, and explicit separation from supporter/admin responsibilities.

UX risks and evidence limits:

- The task cards are dead ends functionally: each opens the same dashboard.
- There are no actionable queues, filters, detail views, status histories, confirmations, undo/correction, error recovery, or staff scope cues.
- No authenticated current flow exists to screenshot and audit. A screenshot of the dashboard would overstate the product's usability.

## Recommended delivery plan

### Gate 1 — Stop-release blockers

1. Implement venue authentication, assigned-venue scoping, and the six real workflows.
2. Replace TV debug release signing with controlled production signing.
3. Repair/regenerate mobile iOS `DART_DEFINES` and produce a successful simulator build plus unsigned archive dry run.
4. Make web dependency installation reproducible with Node 22 and plain `npm ci`.
5. Make all mobile tests independent of current working directory.

### Gate 2 — Runtime and safety proof

1. Add TV secure pairing, refresh/reconnect, expiry, telemetry, and device revocation.
2. Add venue route/component tests and authenticated cross-venue isolation tests.
3. Run Supabase database/RLS contract tests freshly against the exact release migrations.
4. Run mobile release-candidate journeys on Android and iOS with production-like feature flags.
5. Verify observability is consent/configuration-gated and produces useful release telemetry.

### Gate 3 — Product/UX and operations sign-off

1. Capture current screenshots for every critical flow and complete combined UX/accessibility review.
2. Test screen reader, keyboard/remote focus, 200% text/reflow, contrast, touch target size, localization, and error recovery.
3. Complete store/privacy/data-safety validation for mobile and distribution metadata for TV.
4. Complete venue staff onboarding/revocation, incident response, audit retention, and matchday support runbooks.
5. Obtain named product, security/privacy, backend, operations, and store-release owners' sign-off.

## Release decision

- **Supporter mobile app:** NO-GO for production; continue as late beta/release-candidate work.
- **Native TV app:** NO-GO for production; suitable only for controlled internal demos/pilots after using a non-production backend.
- **Venue portal:** NO-GO for pilot operations; the promised operational product is not implemented.

The next honest milestone is not “production launch.” It is a controlled, backend-backed UAT candidate after the P0 items are closed and fresh cross-device evidence exists.

## Implementation disposition — 2026-07-18

This section records work completed after the original review. The original
findings above remain unchanged as the audit baseline; this disposition is the
current evidence-backed status.

### Finding-by-finding status

| Finding | Disposition | Current evidence |
|---|---|---|
| P0-1 venue facade | **Implemented / automated PASS** | `/venue`, orders, menu, check-ins, promotions, TV code, and staff are distinct force-dynamic workflows. They use scoped data, forms/actions, explicit empty/error/access states, and focused component/data tests. |
| P0-2 venue authentication and authorization | **PASS, including authenticated browser exercise** | `src/lib/data/venue-access.ts` resolves the cookie-bound user and active staff membership; all reads and actions use the exact assigned club/venue and fail closed. Cross-club/cross-venue unit and database contracts pass. A temporary manager session traversed all seven routes and live membership revocation immediately produced the forbidden wall; screenshots are under `output/release_readiness_20260718/venue_authenticated_e2e/`. Temporary user, membership, and venue records were deleted by the test. |
| P0-3 TV debug signing | **Closed in code; signed TV artifact externally blocked** | TV release no longer accepts debug signing, reads only external keystore inputs, enables shrinking, and fails closed when credentials are absent. A TV production keystore/private managed-track credential has not been supplied, so the signed TV AAB and fleet certificate fingerprint remain open. |
| P0-4 supporter iOS launch | **PASS; distribution binary complete** | Generated iOS defines are decoded and checked against the canonical JSON. Current simulator build/launch and accessible onboarding-to-guest-home traversal pass. A signed Release build was installed and launched on the physical iPhone. The 1.0.3 (5) App Store archive and 26,433,650-byte IPA export successfully with an Apple Distribution signature, production APNs, `get-task-allow=false`, and strict signature verification. Only account-bound upload/TestFlight processing remains. |
| P1-1 TV stale state | **Implemented / automated PASS** | 20-second refresh, lifecycle-resume refresh, bounded exponential backoff, revoked/error/unpaired distinctions, last-updated time, expiry countdown, and focused retry are implemented and covered by the eight-test TV suite. Representative Android TV soak/overscan/network traversal remains external device evidence. |
| P1-2 TV compile-time provisioning | **Implemented / database and widget PASS** | One-time pairing exchanges a short-lived code for a 256-bit credential; only hashes are stored server-side and the token is stored in encrypted device storage. Admin revocation clears assignments and is audited. Fresh runtime SQL proves one-time exchange, no raw persistence, and revocation. |
| P1-3 venue errors shown as zeroes | **Closed** | Access, configuration, permission, service error, and genuinely empty states are separate, with correlation identifiers and operational retry/escalation copy. Tests assert fail-closed walls and error/empty distinction. |
| P1-4 venue coverage | **Closed with enforced coverage** | Web passes 154 unit/component tests plus an authenticated mobile-Chromium E2E that traverses all venue routes and proves revocation. Venue authorization/operations enforce 100% statements, lines, and functions plus at least 70% branches (currently 74.76%); dedicated shell, route/action, cross-scope tests, and six venue pgTAP contracts also pass. |
| P1-5 mobile runtime evidence | **PARTIAL (iOS binary complete)** | Current iOS simulator real-photo onboarding and guest-home traversal pass; the exact signed Release artifact installs and launches on the physical iPhone. Swipe, 200% text, compact layout, static analysis, App Store archive/IPA, and signed supporter AAB pass. Current Android emulator/physical-Android critical journeys and backend-backed success/denial/offline/retry/deletion flows remain required; TestFlight processing remains account-bound. |
| P1-6 web reproducibility | **PASS** | `.nvmrc` pins Node 22; stable Next 16.2.10 aligns with OpenNext; Node 22/npm 11 plain `npm ci`, typecheck, 154 tests, full-tree zero-warning lint, production build, and moderate-level audit all pass. The deprecated `middleware.ts` convention was migrated to Next 16 `proxy.ts`. |

### Medium finding status

| Original concern | Disposition |
|---|---|
| 60 web lint warnings | **Closed.** All 60 warnings were removed, the full web tree passes ESLint with `--max-warnings=0`, and CI enforces the full-tree gate. |
| Venue unit coverage | **Closed with an enforced focused gate.** Venue authorization and operations modules have 100% statements, lines, and functions plus 74.76% branches; CI requires 100/100/100 and at least 70% branches in addition to pgTAP and authenticated browser coverage. |
| Hard-coded TV venue branding | Removed. Venue/campaign copy is supplied by credential-bound runtime state. |
| TV focus claim without a focus target | Retry/pairing actions are focusable and widget-tested. Representative remote/D-pad traversal remains open. |
| Thin TV tests | Expanded from three to eight for pairing, parsing/state distinctions, refresh/lifecycle behavior, expiry, focus, privacy, and 1080p safety. Physical 720p/4K/overscan/soak evidence remains open. |
| CWD-dependent mobile tests | Closed. The Firebase startup contract resolves the workspace safely and passes from repository and app directories. |
| 78 newer Flutter packages | Reviewed as upgrade availability rather than an active vulnerability finding. Current analysis/tests/builds pass, and weekly root-level Pub Dependabot updates now make the upgrade/security review an owned repository workflow alongside npm and GitHub Actions updates. |
| Deprecated web toolchain packages | Direct Next/PostCSS incompatibilities were removed and `npm audit --audit-level=moderate` is clean. Remaining transitive deprecation notices require normal upstream maintenance. |
| Mobile store/privacy evidence | Privacy/data-safety artifacts and public URLs are updated; public privacy/terms resolve. Store-console owner confirmation, closed-track/TestFlight evidence, support ownership, and legal approval remain external blockers. |
| Missing TV distribution/operations material | TV listing metadata, fleet signing/revocation/recovery runbook, and release checklist now exist. TV store-console/device screenshots and crash/ANR dashboard remain external evidence. |
| Missing venue privacy/operations material | Venue privacy notice, staff onboarding/revocation, incident response, audit handling, and matchday operations runbooks now exist. Named owners, retention approval, support SLA acceptance, and live rehearsal remain external approvals. |

### Fresh final automated evidence

- A clean `npx supabase@latest db reset` applies every migration through
  `20260718170000_tv_device_credentials.sql` without error.
- Venue pgTAP: 1 file, 6 tests, PASS on the clean schema.
- TV/game runtime SQL: all assertions complete inside a transaction and roll back
  without error, covering hashed pairing/credentials, one-time exchange, runtime
  state, revocation, and anonymous legacy-RPC removal.
- Supporter: onboarding/auth suite 24/24, full app suite 19/19, core-network suite
  57/57, static analysis clean, iOS simulator onboarding-to-guest-home evidence,
  signed physical-iPhone Release launch, verified App Store archive/IPA, and
  signed Android release bundle.
- TV: static analysis clean and 8/8 widget/contract tests.
- Web: reproducible clean install, typecheck, 154/154 tests, full-tree lint at
  zero warnings, stable production build, and zero moderate-or-higher npm
  advisories.
- Venue browser: assignment-backed manager session traverses today, orders, menu,
  check-ins, promotions, TV code, and staff on mobile Chromium; revoking the live
  membership produces the forbidden access wall. Eight accepted screenshots are
  stored under `output/release_readiness_20260718/venue_authenticated_e2e/`.

### Current release decision

| Surface | Current engineering state | Decision |
|---|---|---|
| Supporter mobile | Repository-controlled P0 items are closed; the Android AAB and verified iOS App Store IPA are available. Current Android journey/store evidence is incomplete. | **NO-GO pending Android RC traversal, TestFlight/closed-track processing, accessibility, legal/privacy, monitoring, and named sign-off.** |
| Native TV | Secure runtime and fail-closed signing are implemented; no TV production signing input or representative TV-device evidence exists. | **NO-GO pending signed TV AAB, managed distribution, D-pad/device matrix, soak/performance, and monitoring evidence.** |
| Venue portal | Promised workflows, authorization, auditing, automated isolation contracts, assignment-backed browser traversal, and access revocation are verified. | **NO-GO for live operations pending named operations ownership, representative staff acceptance, support/SLA rehearsal, and privacy/legal sign-off.** |

The repository is now a credible controlled-UAT candidate, but it is **not yet
production-ready**. Account-bound store actions, legal/privacy decisions, named
operational ownership, authenticated live-user exercises, current Android/TV
devices, assistive-technology testing, and dashboard evidence cannot be inferred
from source code and remain explicit release blockers.

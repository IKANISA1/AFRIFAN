# Rayon Sports Findings Implementation Plan

Date: 2026-04-10

Scope:
- audit follow-up for `docs/rayon_sports_full_repo_audit_2026-04-10.md`
- reference app `apps/rayon_sports`
- shared packages under `packages/*`
- web/admin app under `apps/rayon_sports/web`
- Supabase schema and edge functions under `supabase/`

Primary input findings:

- F-001 Stored XSS risk in public JSON-LD script tags
- F-002 FCM token sync can fail on upgraded databases
- F-003 Android release manifest widens permissions and makes camera hardware mandatory
- F-004 Public BioPay legal copy conflicts with actual biometric flow
- F-005 Startup blocks first frame on backend/bootstrap work
- F-006 Reference Flutter host tests are red
- F-007 White-label club defaults conflict with numeric club ID contract
- F-008 Web admin ships with a vulnerable `xlsx` dependency

## Target Outcome

Deliver a repo state that is:

- safe to continue toward Play submission without policy or security blockers
- reproducible in release builds for both mobile and web
- green on the reference app regression surface
- explicit about performance, privacy, manifest, and backend contract assumptions
- suitable to use as the white-label baseline for the other club apps

## Program Strategy

This should not be executed as a flat backlog. The findings have a hard dependency chain.

The correct order is:

1. Stop introducing additional release drift.
2. Remove security and compliance blockers.
3. Restore deterministic builds and tests.
4. Fix startup/runtime quality issues.
5. Normalize white-label defaults and package hygiene.
6. Re-run the full readiness pass and prepare submission artifacts.

Trying to do the performance and package cleanup work before closing the security/compliance blockers is wasted effort.

## Release Policy For This Program

Until Workstreams 1 through 3 are complete:

- no Play submission attempt
- no new feature work in `apps/rayon_sports`
- no content-schema changes without migration review
- no dependency upgrades except those directly required by this plan

## Workstream 1: Security And Compliance Blockers

### Objective

Close the issues that can directly create exploitable behavior, policy rejection, or materially false disclosures.

### Findings addressed

- F-001
- F-002
- F-003
- F-004

### Primary file targets

- `apps/rayon_sports/web/src/app/layout.tsx`
- `apps/rayon_sports/web/src/app/(site)/news/[articleId]/page.tsx`
- `apps/rayon_sports/web/src/app/(site)/fixtures/[matchId]/page.tsx`
- `apps/rayon_sports/web/src/app/(site)/shop/[productId]/page.tsx`
- `apps/rayon_sports/web/src/lib/metadata.ts`
- `apps/rayon_sports/web/src/lib/data/admin/cms.ts`
- `packages/core/core_network/lib/src/push_notification_service.dart`
- `supabase/migrations/`
- `apps/rayon_sports/android/app/src/main/AndroidManifest.xml`
- `apps/rayon_sports/android/app/build.gradle.kts`
- `apps/rayon_sports/assets/flavors/production.json`
- `apps/rayon_sports/landing/terms/index.html`
- `apps/rayon_sports/landing/privacy/index.html`
- `apps/rayon_sports/store_metadata/play_store/*`

### Implementation tasks

#### 1.1 JSON-LD hardening

- Add a single shared helper in the web app for rendering JSON-LD safely.
- The helper must escape:
  - `<`
  - `>`
  - `&`
  - U+2028
  - U+2029
- Replace every direct `JSON.stringify(...)` use inside `dangerouslySetInnerHTML` with this helper.
- Keep JSON-LD generation centralized in `metadata.ts`; do not duplicate escape logic at each page.
- Add a regression test proving that a title/body containing `</script><script>alert(1)</script>` is serialized as inert text and not executable markup.

#### 1.2 FCM token schema repair

- Create a new migration that:
  - checks for duplicate `token` rows
  - resolves duplicates deterministically
  - adds a unique index or unique constraint on `public.user_fcm_tokens(token)` if missing
- Decide whether `token` alone is the right uniqueness boundary or whether `(token, club_id)` is the actual intended model.
- If `token` remains the unique key, document that assumption in the migration and in the client code.
- Add an integration test or migration test that simulates an upgraded database where the table exists without the uniqueness constraint.
- Add logging/telemetry around token upsert failure so this class of defect is visible immediately after rollout.

#### 1.3 Android manifest minimization

- Audit why each dangerous permission exists in the merged release manifest.
- Split this into three outcomes:
  - required and justified for current production behavior
  - optional and should only ship when a feature flag is enabled
  - not needed and should be removed from release builds
- Force `android.hardware.camera.any` back to optional if the app must install on non-camera devices.
- Remove telephony/location/storage permissions from the production build if the underlying feature is disabled in `production.json`.
- If a plugin cannot be made conditional, replace it or move it behind a separate build variant rather than shipping unused dangerous permissions.
- Add a manifest verification step to CI that fails when the merged release manifest contains unapproved dangerous permissions or required hardware features.

#### 1.4 Privacy and disclosure alignment

- Decide the canonical product truth for BioPay:
  - embeddings are processed on-device and sent server-side for enrollment/match, or
  - architecture will change to stay fully on-device
- Update all public/legal/store surfaces to match that single truth:
  - landing privacy
  - landing terms
  - in-app privacy links
  - Play Data Safety answers
  - Play listing copy where relevant
- Add a compliance checklist to release review so legal/store copy is rechecked whenever biometric data flow changes.

### Acceptance criteria

- No raw JSON-LD injection path remains without script-safe escaping.
- Push token upsert succeeds on both fresh and upgraded databases.
- Production merged manifest contains only approved dangerous permissions and preserves optional hardware correctly.
- Privacy/terms/store metadata all describe the same biometric flow.

### Validation

- `npm run lint && npm run typecheck && npm test`
- Targeted web test for JSON-LD escaping
- Supabase migration dry-run on a copy of production schema
- `flutter build appbundle --dart-define-from-file=assets/flavors/production.json`
- Merged manifest diff check against approved permission list

## Workstream 2: Build Reproducibility And Release Engineering

### Objective

Make mobile and web release builds deterministic enough to serve as real gates.

### Findings addressed

- audit build failures from the 2026-04-10 pass
- release engineering debt adjacent to F-003 and F-008

### Primary file targets

- `apps/rayon_sports/android/gradle.properties`
- `apps/rayon_sports/android/app/build.gradle.kts`
- `apps/rayon_sports/web/package.json`
- `apps/rayon_sports/web/next.config.ts`
- CI/build scripts once chosen

### Implementation tasks

#### 2.1 Android bundle stability

- Reproduce the Gradle daemon crash with:
  - `--stacktrace`
  - `--info`
  - `--no-daemon`
- Reduce JVM pressure in `gradle.properties` if the current sizing is destabilizing shared or CI builders.
- Capture whether the crash is memory, plugin, or native toolchain related before changing random settings.
- Add one documented, supported release build command and use that command everywhere.

#### 2.2 Next.js production build stability

- Reproduce the `SIGKILL` with memory/process telemetry.
- Confirm whether the failure is:
  - memory pressure
  - OpenNext/Cloudflare build interaction
  - webpack worker exhaustion
  - `xlsx` packaging overhead
- If memory bound, tune build worker limits or split heavy code paths.
- Do not accept “build passes only on one workstation” as good enough; it must pass in a representative clean environment.

#### 2.3 Artifact-based release checks

- Add build outputs as first-class gates:
  - AAB builds successfully
  - Next production build completes successfully
  - manifest inspection passes
  - dependency audit passes or has approved exceptions
- Produce one release-readiness script or CI workflow that runs the agreed set of commands in sequence.

### Acceptance criteria

- Mobile release bundle builds without daemon crashes in a clean environment.
- Web production build completes without worker `SIGKILL`.
- Release commands are documented once and match actual project behavior.

### Validation

- `flutter build appbundle --dart-define-from-file=assets/flavors/production.json`
- `npm run build`
- clean-environment rerun on a second machine or CI

## Workstream 3: Runtime Quality, Startup, And UX Performance

### Objective

Remove the blocking startup path and turn runtime quality from anecdotal to measured.

### Findings addressed

- F-005

### Primary file targets

- `packages/core/core_app/lib/src/bootstrap.dart`
- `packages/core/core_app/lib/src/startup_coordinator.dart`
- `packages/core/core_network/lib/src/country_repository.dart`
- `packages/core/core_network/lib/src/push_notification_service.dart`
- any home-shell widgets affected by deferred init

### Implementation tasks

#### 3.1 Startup split

- Separate startup work into:
  - mandatory-before-render
  - safe-to-defer
  - lazy-on-first-use
- The only pre-render work should be the minimum needed to paint shell UI and route safely.
- Defer push registration, country refresh, and any non-blocking backend sync until after first frame.

#### 3.2 Country data loading redesign

- Ship a bundled country catalog or embedded fallback as the initial source of truth.
- Refresh from Supabase asynchronously and update the cache in the background.
- Ensure a slow or failing country fetch cannot block app launch.

#### 3.3 Performance measurement

- Capture cold-start traces on representative Android hardware.
- Define numeric budgets:
  - cold start to first frame
  - cold start to interactive shell
  - maximum skipped frames during launch
- Re-run the same measurement after the startup split to prove the improvement.

### Acceptance criteria

- `runApp()` no longer waits on the full backend initialization chain.
- Country fetch does not block first paint.
- Startup traces show a measurable reduction in skipped frames on representative hardware.

### Validation

- targeted Flutter widget/integration tests for deferred init behavior
- Android runtime profiling with documented before/after results

## Workstream 4: QA Surface Restoration And Regression Hardening

### Objective

Get the reference app back to a credible green state and add tests for the newly fixed risks.

### Findings addressed

- F-006
- parts of F-001, F-002, F-003, F-005

### Primary file targets

- `apps/rayon_sports/test/`
- `packages/features/feat_biopay/`
- `packages/features/feat_settings/`
- `apps/rayon_sports/web/src/**/*.test.*`
- any new manifest/migration verification tests

### Implementation tasks

#### 4.1 Fix stale app-level expectations

- Update the failing Rayon Sports host tests to match intended product copy.
- If the mixed-case copy was accidental, revert the UI instead of weakening the test.
- The point is consistency, not merely making the test green.

#### 4.2 Add tests for the new fixes

- Web regression for JSON-LD escaping.
- Schema/migration verification for push token uniqueness.
- Manifest verification test or script for dangerous permissions and `uses-feature`.
- Startup test proving the shell can render before deferred work completes.

#### 4.3 Broaden UAT coverage

- Add a focused UAT matrix for:
  - install/launch
  - anonymous sign-in or onboarding path
  - navigation across home, BioPay, settings
  - offline/degraded start
  - notification permission path
  - privacy/legal link navigation
- Use the reference app as the baseline and then sample at least one non-Rayon club build after the club ID cleanup.

### Acceptance criteria

- Reference app Flutter test surface is green.
- Every high-severity fix is protected by at least one automated regression check.
- UAT matrix exists and is executable without tribal knowledge.

### Validation

- `flutter test`
- targeted `flutter test test/rayon_sports_biopay_host_test.dart -r expanded`
- `npm test`
- documented manual UAT pass sheet

## Workstream 5: White-Label Contract Cleanup

### Objective

Eliminate configuration drift that can silently break non-Rayon apps.

### Findings addressed

- F-007

### Primary file targets

- `packages/clubs/*/lib/src/*_config.dart`
- `packages/core/core_auth/lib/src/auth_repository.dart`
- `packages/core/core_auth/lib/src/models/user_profile.dart`
- flavor config files under `apps/*/assets/flavors/`

### Implementation tasks

- Normalize all club defaults to numeric club IDs.
- Add a startup assertion or validation helper that fails fast if a club config violates the numeric contract.
- Add a simple verification script that compares:
  - club package default
  - app flavor `CLUB_ID`
  - known backend club table mapping
- Document the contract once in the platform docs so new club packages cannot drift back to slug defaults.

### Acceptance criteria

- Every club package and production flavor file agrees on numeric club ID semantics.
- Invalid club ID values fail fast during bootstrap rather than degrading silently.

### Validation

- targeted unit tests for numeric ID validation
- consistency check script across all club packages and app flavors

## Workstream 6: Dependency And Supply-Chain Cleanup

### Objective

Reduce avoidable security and maintenance drag without destabilizing the release branch.

### Findings addressed

- F-008
- outdated dependency backlog observed during the audit

### Primary file targets

- `apps/rayon_sports/web/package.json`
- `apps/rayon_sports/web/package-lock.json`
- selected Flutter `pubspec.yaml` files

### Implementation tasks

#### 6.1 Immediate production dependency fixes

- Replace or upgrade `xlsx` first because it already triggers a production advisory.
- Re-run admin export behavior after the change; do not treat a package upgrade as safe without exercising the export flow.

#### 6.2 Controlled Flutter dependency refresh

- Triage outdated Flutter packages into:
  - security/compliance relevant
  - build stability relevant
  - low-priority feature/runtime upgrades
- Upgrade only the dependencies needed for the current readiness goal before starting a broader modernization pass.
- Pay special attention to packages involved in:
  - camera
  - local auth
  - Firebase messaging
  - route/navigation

### Acceptance criteria

- `npm audit --omit=dev` is clean or has documented accepted exceptions.
- No dependency change lands without targeted functional retesting of the affected flow.

### Validation

- `npm audit --omit=dev --json`
- affected flow tests and manual checks after each package change

## Workstream 7: Final Submission Readiness Pass

### Objective

Convert the fixed codebase into a credible Play submission candidate.

### Dependencies

This workstream starts only after Workstreams 1 through 6 are complete.

### Implementation tasks

- Re-run the full repo audit commands used in the 2026-04-10 pass.
- Rebuild the AAB and archive:
  - merged manifest
  - version info
  - signing verification output
- Re-run web production build and archive the output summary.
- Execute the UAT matrix on:
  - one representative Android physical device
  - one fresh install state
  - one upgrade/install-over-existing-data state
- Validate:
  - privacy links resolve
  - Data Safety answers match implementation
  - notification behavior is either complete or removed from store claims
  - BioPay behavior and disclosures match
- Prepare the final submission checklist and go/no-go call.

### Acceptance criteria

- No unresolved High findings remain.
- Release builds are reproducible.
- Test surface is green.
- UAT signoff is documented.
- Play-facing content matches actual implemented behavior.

## Suggested Execution Order And Duration

This is the practical sequence, assuming one primary engineer and one reviewer:

### Phase 0: 0.5 to 1 day

- branch cut
- freeze Rayon feature work
- align on the canonical BioPay privacy truth
- define approved production permission list

### Phase 1: 2 to 3 days

- Workstream 1.1 JSON-LD hardening
- Workstream 1.2 FCM migration repair
- Workstream 1.4 disclosure alignment

### Phase 2: 2 to 4 days

- Workstream 1.3 manifest minimization
- Workstream 2 build reproducibility investigation and fixes

### Phase 3: 1.5 to 3 days

- Workstream 3 startup split and performance verification
- Workstream 4 regression restoration

### Phase 4: 1 to 2 days

- Workstream 5 white-label cleanup
- Workstream 6 dependency cleanup

### Phase 5: 1 to 2 days

- Workstream 7 final readiness pass
- updated go/no-go report

Total realistic effort:

- approximately 8 to 15 working days, depending on how much build-system instability and manifest/plugin cleanup is uncovered

## Risk Register

### Risk 1: Manifest cleanup may require package replacement

- Some permissions may be introduced by plugins that do not support clean conditional inclusion.
- Mitigation:
  - verify plugin-level manifest behavior early
  - replace problem plugins if needed rather than forcing policy exceptions

### Risk 2: Push token migration may surface dirty historical data

- Duplicate tokens may already exist.
- Mitigation:
  - script duplicate detection before applying the unique constraint
  - decide deterministic dedupe rules before migration rollout

### Risk 3: Startup split may reveal hidden coupling

- Some code may assume services are initialized before first render.
- Mitigation:
  - introduce explicit readiness states rather than relying on implicit global initialization

### Risk 4: Web build and mobile build failures may be environment-specific

- The failure mode may not reproduce identically across machines.
- Mitigation:
  - capture stacktraces and system metrics in a clean environment
  - do not mark the issue fixed based on a single local pass

## Definition Of Done

This plan is complete only when all of the following are true:

- all High findings from the 2026-04-10 audit are closed
- the reference app test suite is green
- mobile and web production builds complete successfully
- merged release manifest matches the approved permission and hardware contract
- privacy, terms, store metadata, and implemented biometric flow all agree
- a final UAT and Play-readiness pass produces a go decision

## Immediate Next Step

Start with Workstream 1.1 and 1.2 in the same branch:

- JSON-LD hardening is isolated and low-risk
- the FCM schema repair fixes a known production runtime defect
- both changes are high leverage and easy to validate quickly

After that, move directly to manifest minimization before touching performance or broader dependency upgrades.

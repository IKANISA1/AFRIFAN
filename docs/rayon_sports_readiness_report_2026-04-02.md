# Rayon Sports Readiness Report

Date: 2026-04-02

Scope: `apps/rayon_sports` as the reference implementation for the AFRICLUB white-label platform.

Objective: assess whether Rayon Sports is ready to serve as the production-grade baseline for future club apps and whether it is currently ready for Google Play submission as a flagship app.

## Executive Verdict

`rayon_sports` has a strong platform direction, but it is not yet a release-candidate baseline for a world-class club app.

The strongest parts are the monorepo structure, shared-package architecture, Supabase multi-tenant model, RLS-first backend design, and the amount of product surface already scaffolded.

The weakest parts are release engineering, policy/compliance alignment, secrets handling, Firebase/App Check provisioning, and the gap between what the Play listing promises and what the mobile client currently proves in code.

Current go/no-go call:

| Area | Status |
|---|---|
| Core architecture | Strong |
| Backend/data foundation | Strong but incomplete operationally |
| UI/UX visual direction | Strong |
| End-to-end production readiness | Partial |
| Play submission readiness | Blocked |
| White-label gold-master suitability | Not ready yet |

## Method

This review combined:

- Direct code inspection across `apps/`, `packages/`, `supabase/`, and `docs/`
- Static analysis via Dart tooling: no analyzer errors were found
- Test verification across package test suites that exist in the repo
- Android release build validation
- Review of Play metadata, privacy policy, and release artifacts
- External standards review using current official sources from Android/Google Play, Flutter, Firebase, Supabase, and OWASP MASVS

## Verification Summary

Validated directly during this assessment:

- Static analysis:
  - Dart analyzer reported no errors for the workspace
- Tests passed for the available suites in:
  - `packages/core/core_app`
  - `packages/core/core_theme`
  - `packages/core/core_utils`
  - `packages/features/feat_BioPay`
  - `packages/features/feat_club`
  - `packages/features/feat_home`
  - `packages/features/feat_onboarding`
  - `packages/features/feat_settings`
  - `packages/features/feat_shop`
  - `apps/rayon_sports`
- Android build behavior:
  - `flutter build appbundle --dart-define-from-file=assets/flavors/production.json` succeeded
  - `flutter build appbundle --flavor production --dart-define-from-file=assets/flavors/production.json` failed because the Android project does not expose a `production` flavor task
- Release artifact size:
  - generated AAB was about `160M`
- Repo/release governance visibility:
  - no `.github/`
  - no `.git/`
  - no `fastlane/`
- Firebase provisioning:
  - no `google-services.json`
  - no `GoogleService-Info.plist`
  - no `firebase_options.dart`
- Integration testing:
  - no `integration_test/` directory was found

## What Is Already Good

### 1. Platform architecture is directionally correct

- The repo is structured as a real Flutter monorepo with shared core packages, feature packages, and club-specific config packages.
- The documented architecture in `docs/blueprint.md` is coherent and ambitious even where implementation still lags.
- The app bootstraps through a shared startup coordinator and a module registry rather than club-specific one-off logic.

### 2. Multi-tenant backend design is a real asset

- The Supabase migration set shows a serious multi-tenant foundation with `club_id` isolation, JWT metadata use, and RLS-oriented design.
- There is real backend work for BioPay, notification token tables, liveness, operational health events, and account deletion.
- The `delete-account` edge function is present and actually deletes the authenticated account.

### 3. Release build capability exists

- A release AAB can be produced with:
  - `flutter build appbundle --dart-define-from-file=assets/flavors/production.json`
- The generated bundle exists at `apps/rayon_sports/build/app/outputs/bundle/release/app-release.aab`.

### 4. Shared UI system exists

- The app has a distinctive visual direction and is not generic boilerplate.
- Shared branding, theme tokens, and module-based routing are in place.
- The screen inventory and package structure indicate the team is building a scalable white-label system, not a single app hack.

## Critical Blockers

These issues must be resolved before Rayon Sports should be treated as Play-ready or as the gold master for other clubs.

### 1. Release pipeline and documentation do not match the Android project

Evidence:

- `melos.yaml` defines `build_club` using `--flavor production`.
- `docs/blueprint.md` repeatedly describes a flavor-driven CI/CD strategy.
- `apps/rayon_sports/android/app/build.gradle.kts` does not define `flavorDimensions` or `productFlavors`.

Observed result:

- `flutter build appbundle --flavor production --dart-define-from-file=assets/flavors/production.json` fails because Gradle does not contain `bundleProductionRelease`.

Why this matters:

- The documented white-label build model is not actually implemented in the Android build.
- The current release process is not the same process the platform claims to rely on.

Required fix:

- Either implement true Android/iOS flavoring for Rayon and future clubs, or remove flavor language from docs/scripts and standardize on a single explicit build path.

### 2. Release signing secrets and keystores are committed in the repo

Evidence:

- `apps/rayon_sports/android/key.properties` contains live-looking signing values.
- `apps/rayon_sports/android/upload-keystore.jks` exists.
- `apps/rayon_sports/android/app/upload-keystore.jks` exists.

Why this matters:

- This is a major supply-chain and release-security failure.
- Anyone with repo access can sign or impersonate releases if the keystore is active.
- Rayon cannot be the white-label reference app while secret material is stored this way.

Required fix:

- Revoke and rotate the Android signing material immediately.
- Remove keystores and signing passwords from source control.
- Move release signing to secure secret storage and CI-injected signing only.

### 3. BioPay depends on Firebase/App Check, but Firebase is not provisioned for Rayon Sports

Evidence:

- `packages/core/core_network/lib/src/firebase_bootstrap_service.dart` initializes Firebase on a best-effort basis and silently skips on failure.
- `packages/core/core_network/lib/src/app_check_service.dart` skips activation if Firebase is not initialized.
- `packages/features/feat_BioPay/lib/src/repositories/BioPay_repository.dart` requires an App Check limited-use token for BioPay calls.
- `tools/scripts/validate_BioPay_firebase.sh` explicitly says BioPay-enabled flavors must include `google-services.json` and `GoogleService-Info.plist`.
- No Firebase config files were found under `apps/rayon_sports`.

Why this matters:

- Rayon has `hasBioPay => true`, but the security/provisioning path needed for BioPay is incomplete.
- In production, this creates a late-failing security dependency instead of a guaranteed-attested path.

Required fix:

- Provision Firebase for Android and iOS for Rayon Sports.
- Enforce App Check instead of silently degrading.
- Add CI validation so a BioPay-enabled flavor cannot ship without Firebase config and attestation readiness.

### 4. Play Data Safety and privacy policy claims do not match actual biometric behavior

Evidence:

- `apps/rayon_sports/store_metadata/play_store/data_safety.md` says biometric data is processed locally and never transmitted.
- `apps/rayon_sports/store_metadata/privacy_policy.html` says biometric data is never transmitted and stored only locally.
- `supabase/functions/BioPay-enroll/index.ts` sends `p_embedding` to a server RPC.
- `supabase/functions/BioPay-match/index.ts` sends `p_embedding` to a server RPC for matching.

Why this matters:

- This is not a wording issue. It is a material mismatch between legal/store declarations and system behavior.
- If submitted this way, the app risks rejection or later enforcement under Play's User Data and Data Safety rules.

Required fix:

- Rewrite the privacy policy and Play Data Safety responses to reflect the real biometric flow.
- Make a clear product decision:
  - either keep server-side biometric matching and disclose it correctly
  - or redesign BioPay so no biometric embeddings leave the device

### 5. Store listing overstates current capability

Evidence:

- `apps/rayon_sports/store_metadata/play_store/listing.md` promises real-time live match updates, push notifications, and offline-capable behavior.
- `packages/features/feat_live/lib/src/screens/live_match_screen.dart` is static demo content.
- `packages/features/feat_settings/lib/src/screens/notification_preferences_screen.dart` only toggles settings state and shows a modal.
- `packages/features/feat_settings/lib/src/widgets/settings_overlays.dart` does not request OS permission; it only returns `true` or `false` from a custom dialog.
- Repo search found backend support for `user_fcm_tokens`, but no client `firebase_messaging` integration or token registration flow.
- Home/news surfaces fall back to mock content when data is empty or failing.

Why this matters:

- The listing currently reads like a finished production app while the client still contains demo or placeholder behavior in important user-facing flows.

Required fix:

- Align the Play listing to the proven current implementation, or finish the missing client flows before submission.

### 6. Public support, privacy, and terms URLs are not reachable from this environment

Evidence:

- The URLs in `apps/rayon_sports/assets/flavors/production.json` were checked and failed DNS resolution:
  - `https://www.rayonsportsfc.net`
  - `https://www.rayonsportsfc.net/privacy`
  - `https://www.rayonsportsfc.net/terms`

Why this matters:

- Play requires an active public privacy policy URL for apps handling user data.
- The settings app links also depend on these URLs.

Required fix:

- Make these URLs live before submission.
- Verify them from an external network, not only locally.

## High-Priority Gaps

### 1. White-label runtime branding is incomplete

Evidence:

- `packages/core/core_theme/lib/src/runtime_branding.dart` expects `CREST_ASSET`, `HOME_TEAM_NAME`, `HOME_VENUE_NAME`, `RIVAL_TEAM_NAME`, and `PRIMARY_COMPETITION_NAME`.
- `apps/rayon_sports/assets/flavors/production.json` provides only a small subset of runtime branding values.

Impact:

- User-facing fallback strings like `Home Stadium`, `Rivals`, and generic initials can appear.
- Rayon is not yet the right canonical white-label baseline.

Required fix:

- Define a complete brand contract for every club app.
- Fail builds when required white-label values are missing.

### 2. Crest asset path is wrong in the club config

Evidence:

- `packages/clubs/club_rayon_sports/lib/src/rayon_sports_config.dart` points to `assets/crest/rayon_crest.png`.
- The actual asset present is `apps/rayon_sports/assets/crest/rayon_sports_crest.png`.

Impact:

- A broken brand asset in the reference club undermines all downstream club onboarding confidence.

Required fix:

- Fix the asset path and add an automated existence check in CI.

### 3. Notification UX exists without the delivery stack

Evidence:

- Notification preferences UI is present.
- No `firebase_messaging` or equivalent client push implementation was found.
- No `POST_NOTIFICATIONS` permission was found in the Android manifest.
- No token registration flow to `user_fcm_tokens` exists on the client side.

Impact:

- The user can enable alerts in-app without any evidence that the device will actually receive them.

Required fix:

- Add FCM/APNs setup, token lifecycle management, foreground/background handling, and OS permission requests.
- Wire the settings screen to actual delivery state rather than optimistic UI state.

### 4. SMS ledger is not in a production-ready state for Play

Evidence:

- `ENABLE_ANDROID_MOMO_SMS_AUTOREAD` is `false` in Rayon production config.
- No SMS permissions are declared in the Android manifest.
- `packages/features/feat_sms_ledger/lib/src/services/momo_sms_deps.dart` still contains placeholders such as `mock_url`, `mock_key`, and stub services.

Impact:

- The feature is present in product language but disabled or stubbed in the production build path.
- If SMS auto-read is re-enabled later, Play policy risk becomes very high because SMS access is heavily restricted.

Required fix:

- Treat SMS ledger as one of two paths:
  - keep it disabled and market the app without SMS auto-read
  - or redesign toward a Play-compliant ingestion strategy and add proper disclosure, permission, and policy review

### 5. No staging or environment separation is visible for Rayon

Evidence:

- Only `apps/rayon_sports/assets/flavors/production.json` exists.
- No staging config file was found for this app.

Impact:

- A flagship app needs at least dev, staging, and production release paths.
- Without environment separation, release verification becomes risky and white-label rollout discipline breaks down.

Required fix:

- Introduce environment separation for app config, Supabase projects, Firebase projects, and signing/release channels.

### 6. CI/CD is described but not present in the workspace

Evidence:

- `docs/blueprint.md` describes GitHub Actions, matrix builds, and deploy workflows.
- No `.github/` directory exists in the current workspace.
- No `fastlane/` automation was found.
- No `.git/` directory exists in the current workspace either, so Git-backed release governance is not observable here.

Impact:

- The stated release maturity is not visible in the implementation delivered for review.

Required fix:

- Add real CI:
  - lint
  - unit/widget tests
  - integration tests
  - Firebase/App Check validation
  - brand asset validation
  - release signing validation
  - Play bundle build
- Add release automation for internal, closed, and production tracks.

## Medium-Priority Gaps

### 1. Offline behavior is not mature enough to market as offline-capable

Observed evidence:

- Hive is initialized and some caching helpers exist.
- The home screen and latest intel use mock fallbacks when data is unavailable.

Why this is not enough:

- A world-class offline-capable app needs explicit offline data strategy:
  - cached source-of-truth policy
  - sync queue and retry behavior
  - conflict handling
  - stale-state messaging
  - offline ticket/member card behavior

Recommendation:

- Remove "offline-capable" from public claims until an offline-first design is implemented and verified.

### 2. No integration test suite was found

Observed evidence:

- Package-level test suites exist and passed where present.
- No `integration_test/` directory was found.

Recommendation:

- Add critical end-to-end coverage for:
  - auth and onboarding
  - membership activation
  - ticket purchase flow
  - contribution flow
  - notification permission and token registration
  - BioPay enrollment/match happy-path and fail-path

### 3. Client observability is not production-grade yet

Observed evidence:

- Backend operational health events exist.
- `CrashlyticsService` in SMS ledger is a debug-print stub.
- The privacy policy claims Firebase crash reporting, but the client implementation does not prove this.

Recommendation:

- Add real crash reporting, non-fatal event logging, release version correlation, and alerting.

### 4. Package/update hygiene needs a managed upgrade pass

Observed evidence:

- `flutter pub outdated` reported many packages constrained below resolvable versions, including major framework dependencies.

Recommendation:

- Plan a dependency modernization pass before scaling the white-label fleet.
- Do not upgrade blindly; validate router, Riverpod, auth, ML, and platform plugins carefully.

### 5. Bundle size is large for this product class

Observed evidence:

- The release AAB is about `160M`.
- The stored release APK artifact is about `125M`.

Recommendation:

- Audit assets, native libraries, TensorFlow/ML packaging, and split delivery strategy.
- Set app-size budgets per feature area.

## Product and UX Scorecard

| Domain | World-class bar | Current Rayon state | Status |
|---|---|---|---|
| Brand fidelity | No generic placeholders, every club fully branded | Runtime branding contract is incomplete; crest path mismatch exists | Partial |
| Home experience | Real club data, resilient empty/error states, real-time cues | Strong visuals, but uses mock fallback for leaderboard/FET/news | Partial |
| Live match | Real-time event stream, stateful match context, sharing, notifications | Current live screen is static mock content | Blocked |
| Membership | Identity, benefits, lifecycle, support, recovery | Structure exists, but full operational audit not completed in this pass | Partial |
| Ticketing | Purchase, wallet, scan, support, refund states | Feature presence exists; production readiness not fully proven here | Partial |
| Contributions | Transparency, receipts, recovery, reconciliation | Backend direction is good; SMS auto-read path is not production-ready | Partial |
| Shop | Catalog, cart, checkout, post-purchase support | Surface exists; operational commerce path not fully proven here | Partial |
| Notifications | OS permission, token registration, reliable delivery | Preferences UI exists without proven delivery pipeline | Blocked |
| Accessibility | Contrast, scalable text, semantics, keyboard/reader support | Not fully audited; no formal evidence of accessibility QA | Unknown |
| Localization | Production-ready localized copy and fallback rules | Language support is declared, but full localization quality was not verified | Partial |
| Adaptive design | Large-screen/tablet/foldable behavior | No formal adaptive QA evidence; iOS orientation config and app lock differ | Partial |

## Backend and Data Scorecard

| Domain | World-class bar | Current Rayon state | Status |
|---|---|---|---|
| Multi-tenancy | Club isolation enforced in DB and auth context | Strong design with `club_id` and RLS | Strong |
| Account deletion | In-app and web deletion path, backend deletion works | Backend function exists; web deletion URL is not live | Partial |
| Security attestation | Device attestation enforced for sensitive flows | App Check design exists, but Firebase provisioning is missing | Blocked |
| Notification backend | Token table, send pipeline, lifecycle cleanup | Backend token table/functions exist | Partial |
| Client-backend parity | Mobile client fully uses available backend features | Notification and some live capabilities lag behind backend | Partial |
| Operational monitoring | Production telemetry and alerting | Some backend health events exist; client monitoring incomplete | Partial |

## Google Play Submission Checklist

This is the minimum list that should be complete before submitting Rayon Sports as a serious production release.

### Submission blockers

- Fix signing-secret exposure and rotate the keystore.
- Make privacy policy and legal URLs publicly reachable.
- Correct Play Data Safety answers to match actual biometric and device-data behavior.
- Correct the privacy policy to match actual data collection and transmission behavior.
- Either implement actual push notifications or remove push claims from the store listing.
- Either implement true live data or remove "real-time live match" claims from the store listing.
- Resolve the build/process mismatch around `--flavor production`.
- Provision Firebase/App Check for every BioPay-enabled platform.

### Strongly recommended before submission

- Add closed/internal testing tracks and pre-submit QA gates.
- Add integration tests for the core monetization and identity flows.
- Add crash reporting and release health dashboards.
- Verify 16 KB page-size compatibility for native dependencies.
- Validate tablet/large-screen behavior and accessibility basics.
- Reduce app size where possible.

### If SMS auto-read is ever enabled

- Re-run Play policy review specifically for SMS/Call Log access.
- Add prominent disclosure and explicit consent UX before any access occurs.
- Expect high review scrutiny because this is not a default SMS app category.

## White-Label Gold-Master Checklist

Rayon Sports should become the template all future clubs inherit. To reach that level, the following must be true:

### Branding

- Required brand contract for every club:
  - app name
  - legal entity
  - crest asset
  - primary/secondary/accent colors
  - stadium/venue name
  - rival/default opponent name
  - competition naming
  - support email
  - public website
  - privacy URL
  - terms URL

### Product

- No demo-only or static placeholder behavior in core fan journeys.
- Every enabled feature flag must correspond to an operational production flow.
- Store metadata must be generated from the same feature matrix used by the app.

### Platform

- A build must fail if:
  - required brand assets are missing
  - Firebase/App Check is missing for a BioPay-enabled club
  - legal URLs are empty or unreachable
  - feature flags and store claims diverge

### Release

- One canonical release path for Android and iOS.
- Internal, staging, and production environments.
- CI artifacts for every club build.
- Secure signing only through secret-managed release infrastructure.

## Recommended Execution Plan

### Phase 1: Release and compliance hardening

Target: make Rayon safe to release.

- Remove committed keystores and rotate all signing credentials.
- Make privacy/terms/support URLs live.
- Rewrite privacy policy and data-safety answers.
- Align the Play listing with actual current features.
- Decide whether SMS auto-read stays off permanently for Play builds.

### Phase 2: Sensitive-feature hardening

Target: make BioPay and notifications operationally real.

- Provision Firebase for Android and iOS.
- Enforce App Check for sensitive calls.
- Add client push messaging stack and token registration.
- Add crash reporting and sensitive-flow telemetry.

### Phase 3: White-label baseline completion

Target: make Rayon the template club.

- Complete runtime brand contract.
- Fix asset mismatches and build-time validation.
- Add staging config and release channels.
- Add integration tests and CI/CD.

### Phase 4: Experience maturity

Target: make the app world-class, not just compliant.

- Replace static live match content with a real event feed.
- Replace mock home/news fallbacks with controlled empty-state design and cached real data.
- Add explicit offline strategy for critical flows.
- Add accessibility and large-screen QA.

## Evidence Pointers

Key files reviewed:

- `melos.yaml`
- `docs/blueprint.md`
- `apps/rayon_sports/android/app/build.gradle.kts`
- `apps/rayon_sports/android/app/src/main/AndroidManifest.xml`
- `apps/rayon_sports/android/key.properties`
- `apps/rayon_sports/assets/flavors/production.json`
- `apps/rayon_sports/store_metadata/play_store/listing.md`
- `apps/rayon_sports/store_metadata/play_store/data_safety.md`
- `apps/rayon_sports/store_metadata/privacy_policy.html`
- `apps/rayon_sports/ios/Runner/Info.plist`
- `packages/clubs/club_rayon_sports/lib/src/rayon_sports_config.dart`
- `packages/core/core_app/lib/src/startup_coordinator.dart`
- `packages/core/core_network/lib/src/firebase_bootstrap_service.dart`
- `packages/core/core_network/lib/src/app_check_service.dart`
- `packages/core/core_theme/lib/src/runtime_branding.dart`
- `packages/features/feat_home/lib/src/screens/home_screen.dart`
- `packages/features/feat_home/lib/src/widgets/latest_intel_section.dart`
- `packages/features/feat_live/lib/src/screens/live_match_screen.dart`
- `packages/features/feat_settings/lib/src/screens/notification_preferences_screen.dart`
- `packages/features/feat_settings/lib/src/widgets/settings_overlays.dart`
- `packages/features/feat_settings/lib/src/settings_actions.dart`
- `packages/features/feat_sms_ledger/lib/src/services/momo_sms_deps.dart`
- `packages/features/feat_BioPay/lib/src/repositories/BioPay_repository.dart`
- `supabase/functions/BioPay-enroll/index.ts`
- `supabase/functions/BioPay-match/index.ts`
- `supabase/functions/delete-account/index.ts`
- `tools/scripts/validate_BioPay_firebase.sh`

## External Standards Used

Official sources reviewed during this assessment:

- Android target API requirements:
  - https://developer.android.com/google/play/requirements/target-sdk
- Android 16 KB page size guidance:
  - https://developer.android.com/guide/practices/page-sizes
- Android publishing guidance:
  - https://developer.android.com/studio/publish/
- Google Play User Data and account deletion requirements:
  - https://support.google.com/googleplay/android-developer/answer/10144311?hl=en
- Google Play SMS and Call Log permissions policy:
  - https://support.google.com/googleplay/android-developer/answer/10208820?hl=en
- Firebase App Check for Flutter:
  - https://firebase.google.com/docs/app-check/flutter/default-providers
- Supabase Row Level Security:
  - https://supabase.com/docs/guides/database/postgres/row-level-security
- Flutter testing:
  - https://docs.flutter.dev/testing
- Flutter performance best practices:
  - https://docs.flutter.dev/perf/best-practices
- Flutter adaptive and responsive design:
  - https://docs.flutter.dev/ui/adaptive-responsive
- OWASP MASVS:
  - https://mas.owasp.org/MASVS/

## Final Assessment

Rayon Sports is a promising platform pilot, not yet a fully operational flagship release.

If the goal is "good enough to demo", it is already beyond that.

If the goal is "reference implementation for every future club app and safe for Play production release", the current blockers are too significant to ignore. The next work should focus less on adding new features and more on bringing the existing product into alignment across code, security, policy, store declarations, and release operations.

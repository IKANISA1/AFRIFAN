# Rayon Sports Full Repo Audit

Date: 2026-04-10

Scope:
- Flutter mobile app under `apps/rayon_sports`
- Shared Flutter packages under `packages/*`
- Next.js web/admin app under `apps/rayon_sports/web`
- Supabase functions and migrations under `supabase/`
- Android runtime verification on physical device `Pixel_4a`

## Executive Summary

The repo is not release-ready in its current state. The highest-risk issues are:

1. Public web pages inject JSON-LD with `dangerouslySetInnerHTML` from admin-editable content without escaping script-breakout sequences.
2. FCM token registration is broken against some existing databases because the client upserts on `token` but the migration only guarantees `UNIQUE` on fresh table creation.
3. The Android release manifest currently widens the permission and hardware surface beyond the app manifest and beyond production feature flags, which creates Google Play review and device-compatibility risk.
4. Public legal copy still claims BioPay processing is on-device only, while the backend sends embeddings server-side.

Secondary issues include startup jank from blocking backend bootstrap before `runApp()`, a red reference test suite, a supply-chain advisory in the web admin Excel export dependency, inconsistent white-label club defaults, and non-reproducible production builds in this environment.

## Findings

### F-001 High: Stored XSS risk in public JSON-LD script tags

- Rule ID: REACT-XSS-001
- Location:
  - `apps/rayon_sports/web/src/app/(site)/news/[articleId]/page.tsx:63`
  - `apps/rayon_sports/web/src/app/(site)/fixtures/[matchId]/page.tsx:64`
  - `apps/rayon_sports/web/src/app/(site)/shop/[productId]/page.tsx:49`
  - `apps/rayon_sports/web/src/lib/metadata.ts:61`
  - `apps/rayon_sports/web/src/lib/metadata.ts:86`
  - `apps/rayon_sports/web/src/lib/metadata.ts:123`
  - `apps/rayon_sports/web/src/app/admin/cms/page.tsx:71`
  - `apps/rayon_sports/web/src/lib/data/admin/cms.ts:89`
- Evidence:
  - Public pages inject JSON-LD with `dangerouslySetInnerHTML={{ __html: JSON.stringify(...) }}`.
  - The JSON-LD builders include admin-managed fields such as `article.title`, `article.excerpt`, `article.author`, `match.homeTeam`, `match.awayTeam`, `product.name`, and `product.description`.
  - Admin CMS writes raw form strings straight into persisted article fields.
- Impact:
  - Any content value containing `</script>` can break out of the JSON-LD `<script>` tag and execute attacker-controlled script in visitors’ browsers.
  - Because the affected content comes from admin-editable records, a compromised or malicious content editor can create stored XSS on public pages.
- Fix:
  - Stop using raw `JSON.stringify(...)` output inside `<script>` tags.
  - Escape `<`, `>`, `&`, U+2028, and U+2029 before injection, or use a serializer designed for script-safe JSON output.
  - Prefer a shared `renderJsonLd()` helper and route every JSON-LD payload through it.

### F-002 High: FCM token sync can fail on upgraded databases

- Rule ID: BACKEND-DATA-001
- Location:
  - `packages/core/core_network/lib/src/push_notification_service.dart:211`
  - `supabase/migrations/20260330203000_profile_settings_foundation.sql:93`
  - `supabase/migrations/20260330203000_profile_settings_foundation.sql:104`
- Evidence:
  - Client code performs `.upsert(..., onConflict: 'token')`.
  - The migration declares `token text NOT NULL UNIQUE` only inside `CREATE TABLE IF NOT EXISTS`.
  - The follow-up `ALTER TABLE` statements add columns only; they do not backfill a unique constraint for pre-existing `user_fcm_tokens` tables.
  - Runtime verification on device previously logged `PostgrestException ... no unique or exclusion constraint matching the ON CONFLICT specification`.
- Impact:
  - Push token registration can silently fail in production on upgraded databases, breaking notification delivery and token freshness.
- Fix:
  - Add a dedicated migration that creates a unique index/constraint on `public.user_fcm_tokens(token)` if it is missing.
  - Add an integration test that verifies token upsert works against an upgraded schema path, not just fresh bootstrap.

### F-003 High: Android release manifest widens permissions and makes camera hardware mandatory

- Rule ID: PLAY-PERMS-001
- Location:
  - `apps/rayon_sports/android/app/src/main/AndroidManifest.xml:3`
  - `apps/rayon_sports/android/app/src/main/AndroidManifest.xml:9`
  - `apps/rayon_sports/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml:17`
  - `apps/rayon_sports/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml:55`
  - `apps/rayon_sports/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml:65`
  - `apps/rayon_sports/build/app/intermediates/merged_manifest/release/processReleaseMainManifest/AndroidManifest.xml:77`
  - `apps/rayon_sports/assets/flavors/production.json:11`
- Evidence:
  - Source manifest declares `android.hardware.camera.any` as optional.
  - Merged release manifest resolves `android.hardware.camera.any` to `android:required="true"`.
  - Merged release manifest also includes `RECORD_AUDIO`, `READ_EXTERNAL_STORAGE`, `ACCESS_COARSE_LOCATION`, and `READ_PHONE_STATE`.
  - Production flavor disables Android MoMo SMS autoread with `ENABLE_ANDROID_MOMO_SMS_AUTOREAD: false`.
  - Manifest-merge blame attributes extra permissions/features to transitive packages such as `camera_android_camerax` and `another_telephony`.
- Impact:
  - Devices without camera hardware can be filtered out of Play distribution even though the source manifest says camera is optional.
  - The app requests a broader dangerous-permission surface than current production behavior appears to need, increasing Play review friction and Data Safety disclosure burden.
- Fix:
  - Override merged manifest behavior explicitly with `tools:node="replace"` or `tools:replace` where appropriate so optional hardware stays optional.
  - Remove or gate telephony/location/storage-related plugins from production if the feature flag is off.
  - Re-run merged-manifest review as part of release CI and treat unexpected dangerous permissions as a failed check.

### F-004 High: Public BioPay legal copy conflicts with actual server-side biometric flow

- Rule ID: PLAY-DISCLOSURE-001
- Location:
  - `apps/rayon_sports/landing/terms/index.html:102`
  - `apps/rayon_sports/landing/privacy/index.html:134`
  - `supabase/functions/BioPay-enroll/index.ts:100`
  - `supabase/functions/BioPay-match/index.ts:152`
- Evidence:
  - Public terms state biometric data is processed on-device only.
  - Public privacy copy refers to storage of biometric templates.
  - The enrollment and match functions send `p_embedding` server-side to Supabase RPCs.
- Impact:
  - Play review, privacy-policy review, and user disclosures can fail because public-facing legal copy does not match implemented biometric handling.
  - This is also a trust issue for users opting into BioPay.
- Fix:
  - Align all public privacy/terms pages with the actual data flow and retention model.
  - Ensure Data Safety, in-app disclosures, consent copy, website privacy copy, and store metadata all describe the same server-side biometric flow.

### F-005 Medium: First frame is blocked on backend/bootstrap work

- Rule ID: UX-PERF-001
- Location:
  - `packages/core/core_app/lib/src/bootstrap.dart:54`
  - `packages/core/core_app/lib/src/startup_coordinator.dart:76`
  - `packages/core/core_network/lib/src/country_repository.dart:29`
- Evidence:
  - `runApp()` does not execute until `AppStartupCoordinator.initialize(config)` completes.
  - Backend initialization performs Firebase bootstrap, App Check, Supabase initialization, push setup, and a live country-table fetch before first paint.
  - Android runtime verification previously showed startup frame skips (`Skipped 92 frames`, `Skipped 88 frames`).
- Impact:
  - Cold start and resume feel slow, especially on mid-range Android devices and poor networks.
  - If any backend dependency is slow, the entire app blocks before rendering shell UI.
- Fix:
  - Render a minimal shell immediately and move non-critical initialization to post-frame/background work.
  - Pre-seed country data from bundled assets and refresh async.
  - Treat push setup and optional services as deferred initialization.

### F-006 Medium: Reference Flutter host tests are red due to stale copy expectations

- Rule ID: QA-TEST-001
- Location:
  - `apps/rayon_sports/test/rayon_sports_BioPay_host_test.dart:28`
  - `apps/rayon_sports/test/rayon_sports_BioPay_host_test.dart:69`
  - `packages/features/feat_BioPay/lib/src/BioPay_module.dart:33`
  - `packages/features/feat_settings/lib/src/screens/settings_screen.dart:120`
- Evidence:
  - The test expects `BioPay` and `BioPay & PRIVACY`.
  - Current UI renders `BioPay` and `BioPay & Privacy`.
  - Re-running `flutter test test/rayon_sports_BioPay_host_test.dart -r expanded` fails on both assertions.
- Impact:
  - The reference app’s own regression suite is red, which weakens release confidence and makes it easier for genuine regressions to get normalized away.
- Fix:
  - Update the test expectations to match intended product copy, or restore the original copy if the mixed-case change was unintentional.
  - Keep this host-level suite in CI because it validates app wiring rather than isolated package behavior.

### F-007 Medium: White-label club defaults conflict with numeric club ID contract

- Rule ID: MULTITENANCY-CONFIG-001
- Location:
  - `packages/core/core_auth/lib/src/auth_repository.dart:8`
  - `packages/core/core_auth/lib/src/auth_repository.dart:14`
  - `packages/core/core_auth/lib/src/models/user_profile.dart:75`
  - `packages/clubs/club_rayon_sports/lib/src/rayon_sports_config.dart:16`
  - `packages/clubs/club_yanga/lib/src/yanga_config.dart:10`
  - `packages/clubs/club_simba/lib/src/simba_config.dart:10`
- Evidence:
  - Auth layer documents `clubId` as a numeric string matching DB `id`.
  - `UserProfile.toProfileRow()` only writes `club_id` when `int.tryParse(clubId)` succeeds.
  - Rayon Sports defaults to numeric `24`, while other club configs still default to slugs such as `yanga` and `simba`.
- Impact:
  - Any run that omits the flavor define file can silently lose correct tenancy metadata/profile writes for non-Rayon club apps.
  - This is a latent white-label regression vector.
- Fix:
  - Normalize all club defaults to numeric IDs.
  - Add an assertion during bootstrap that fails fast if `clubId` is non-numeric where numeric IDs are required.

### F-008 Low: Web admin ships with a vulnerable `xlsx` dependency

- Rule ID: SUPPLY-CHAIN-001
- Location:
  - `apps/rayon_sports/web/package.json:32`
  - `apps/rayon_sports/web/next.config.ts:11`
  - `apps/rayon_sports/web/src/lib/data/admin/contributions.ts:110`
- Evidence:
  - `npm audit --omit=dev --json` reports a high-severity advisory set for `xlsx`.
  - The app dynamically imports `xlsx` in the admin contribution export path.
- Impact:
  - Even if the current code path mainly writes files instead of parsing them, the dependency remains in the production surface and will continue to fail security audits.
- Fix:
  - Upgrade to a patched `xlsx` release or replace it with a maintained alternative.
  - Re-run `npm audit --omit=dev` after the upgrade and add a production dependency audit gate.

## Verification Performed

### Static analysis and tests

- `mcp__dart_mcp_server__analyze_files` on repo root: no analyzer errors reported.
- Shared Flutter package tests: passed.
- `apps/rayon_sports/test/rayon_sports_BioPay_host_test.dart`: failed as documented in F-006.
- `apps/rayon_sports/web`: `npm run lint`, `npm run typecheck`, and `npm test` passed.
- `flutter pub outdated --no-dev-dependencies`: 29 packages outdated, 18 constrained below resolvable versions.

### Runtime and device checks

- Installed Android app launched on physical Pixel 4a.
- Prior runtime session surfaced startup frame skips and push token sync failures.
- Home screen rendered expected production content and navigation tiles.

### Build verification

- `npm run build` in `apps/rayon_sports/web` did not complete successfully in this environment. The build worker exited with `SIGKILL`.
- `flutter build appbundle --dart-define-from-file=assets/flavors/production.json` did not complete successfully in this environment. Gradle daemon disappeared during `bundleRelease`.
- `apps/rayon_sports/android/gradle.properties:1` sets aggressive JVM sizing (`-Xmx8G`, `MaxMetaspaceSize=4G`), which is a likely contributing factor for constrained builders, but the daemon crash itself still needs direct root-cause confirmation.

## Recommended Order of Operations

1. Fix F-001, F-002, F-003, and F-004 before any Play submission attempt.
2. Make release builds reproducible for both the app bundle and Next production build.
3. Fix F-006 so the reference app’s host-level regression suite is green again.
4. Normalize white-label club IDs and clear the dependency backlog with production-impacting packages first.

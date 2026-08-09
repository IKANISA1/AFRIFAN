# Rayon Sports Release Checklist

This is the canonical release checklist for the `rayon_sports` product suite.

The ordered execution goal and its machine-readable completion predicate are:

- `docs/release/AFRICLUB_STORE_AND_CLOUDFLARE_EXECUTION_GOAL_2026-08-09.md`
- `docs/release/AFRICLUB_STORE_AND_CLOUDFLARE_EXECUTION_GOAL_2026-08-09.json`
- generated checkpoint:
  `output/implementation_goal_20260724/release-submission-execution-goal.json`

This checklist cannot override those fail-closed controls or the original
87-task denominator.

Companion evidence and operating controls:

- `docs/release/rayon_fullstack_uat_matrix.md`
- `docs/release/three_surface_release_signoff.md`
- `docs/venue_operations_runbook.md`
- `docs/venue_staff_privacy_notice.md`
- `docs/tv_fleet_release_and_operations_runbook.md`

It assumes the product UI is already approved and frozen for release. This checklist covers engineering, platform, security, compliance, and store operations only.

## 1. Automated repo gates

- `flutter analyze apps/rayon_sports`
- `flutter test apps/rayon_sports/test`
- `flutter test apps/rayon_sports/integration_test`
- `bash tools/scripts/validate_club_release.sh rayon_sports`
- `bash tools/scripts/validate_store_privacy_contract.sh`
- `node --test tools/scripts/reconcile_implementation_goal_checkpoint.test.mjs`
- `node tools/scripts/reconcile_implementation_goal_checkpoint.mjs`
- Android dry run: `bash tools/scripts/dry_run_android_release.sh rayon_sports`
- iOS dry run on macOS: `bash tools/scripts/dry_run_ios_release.sh rayon_sports`

Expected result:

- all commands exit `0`
- no committed signing material is detected
- no committed Play/App Store credentials are detected
- release artifacts are generated successfully
- the release goal validates all 12 workstreams and exactly covers its 33-task
  creation baseline
- the reconciler derives candidate identity from the live checkout and marks a
  stale preflight or prior-commit artifact as historical evidence only
- the validation manifest still reports every unproved CI, device, backend,
  Cloudflare, store, and approval gate as open

## 2. Production secrets and credentials

These must exist outside git:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH` for fastlane uploads
- Cloudflare access with Workers Scripts Edit, Pages Edit, Zone Read, and DNS
  Edit for only the governed account and `gikundiro.com` zone

iOS external signing inputs must exist in Apple Developer / App Store Connect:

- production signing certificate
- provisioning profile with push notifications enabled
- Apple Team ID configured in Xcode signing
- APNs auth key uploaded to Firebase Cloud Messaging
- an authorized App Store Connect API key/JWT, Xcode account, or Transporter
  session with upload rights and an App Manager/Admin/Account Holder path for
  submission fields

Credentials must remain outside git and outside evidence records. A successful
authentication check records only the account/role/path and timestamp, never a
secret, password, verification code, or private key value.

## 3. Firebase and push readiness

- Android and iOS Firebase configs point to the same Firebase project
- Supabase runtime has `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON`
- Firebase App Check is registered for:
  - Android `rw.gikundiro.app` with Play Integrity
  - iOS `rw.ikanisa.rayonSports` with App Attest
- iOS entitlements include:
  - `aps-environment=production`
  - `com.apple.developer.devicecheck.appattest-environment=production`
- Physical-device push delivery is verified on Android and iOS

References:

- [FIREBASE.md](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/FIREBASE.md)
- [FIREBASE_ROLLOUT.md](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/FIREBASE_ROLLOUT.md)

## 4. Android release steps

1. Increment `apps/rayon_sports/pubspec.yaml` so `versionCode` is higher than the last Play production release.
2. Verify the Play record for `rw.gikundiro.app`, Play App Signing enrollment,
   upload-certificate match, and that the version code is unused.
3. Build the signed production AAB from the clean frozen exact candidate in CI
   or a controlled release machine.
4. Verify artifact path:
   `apps/rayon_sports/build/app/outputs/bundle/release/app-release.aab`
5. Record source SHA, package/version, SHA-256, bytes, signer fingerprint,
   toolchain, bundletool/merged-manifest result, 16 KB result, mappings, and
   native symbols.
6. Upload to Play internal testing first.
7. Verify:
   - install succeeds
   - onboarding works
   - home shell loads
   - contributions hub loads
   - notifications register
8. Complete App Bundle Explorer, pre-launch report, integrity, automated
   policy, and device-catalog review.
9. Complete the store listing and all privacy, Data Safety, deletion, ads,
   audience, content-rating, access, financial, restricted-permission, UGC,
   payment, contest/prediction, and child-safety declarations.
10. Complete any required closed-test/production-access programme.
11. Promote to production only after monitoring internal/closed results and
    named approval.
12. Retain a production submission receipt showing the change is under review
    or later. Upload alone is not submission completion.

Fastlane upload prerequisite:

- export `PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH=/absolute/path/to/google-play-service-account.json`

## 5. iOS release steps

Supported deployment floor: **iOS 15.5**. Firebase Apple SDK 12 requires iOS
15 or later, and the additional minor-version floor keeps the Runner, Flutter
framework, CocoaPods fallback, and generated Flutter Swift package aligned.

1. Regenerate the Flutter iOS configuration from the app directory before an
   Xcode-only build:
   `cd apps/rayon_sports && flutter build ios --config-only`
2. Validate the deployment floor and SwiftPM prepare hook:
   `bash tools/scripts/validate_ios_release_contract.sh rayon_sports`
3. Run unsigned dry run on macOS:
   `bash tools/scripts/dry_run_ios_release.sh rayon_sports`
4. In Xcode or the release runner, archive a signed production build.
5. Confirm:
   - bundle id is `rw.ikanisa.rayonSports`
   - the Runner, Flutter framework, Pods fallback, and
     `FlutterGeneratedPluginSwiftPackage` all target iOS 15.5 or later
   - push capability is enabled in the provisioning profile
   - App Attest entitlement is present
   - `PrivacyInfo.xcprivacy` is bundled in the Runner resources
   - the Xcode-generated privacy report is reconciled to the exact signed
     archive and its embedded SDK privacy manifests
6. Upload archive to App Store Connect / TestFlight.
7. Record source SHA, bundle/version/build, SHA-256, bytes, signer/profile,
   Xcode/SDK version, symbols, validation, and processing build identifier.
8. Verify on physical devices through TestFlight:
   - first launch
   - auth restore
   - contributions launch
   - push token registration
   - push delivery
9. Complete metadata, screenshots, URLs, categories, availability, pricing,
   App Privacy, age rating, content rights, encryption, DSA trader, payment,
   UGC, contest/prediction, tracking, and account-deletion answers.
10. Attach the exact processed build to the version and submission.
11. Select **Submit for Review** and retain a receipt showing `Waiting for
    Review`, `In Review`, or a later status. TestFlight processing alone is not
    App Store submission completion.

Platform references:

- Flutter Swift Package Manager guidance:
  `https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers`
- Firebase Apple SDK release notes:
  `https://firebase.google.com/support/release-notes/ios`

## 6. Store and compliance checks

- privacy policy URL resolves publicly
- terms URL resolves publicly
- support email is monitored
- Play/App Store descriptions match actual functionality
- data safety / privacy answers match the implemented app behavior
- the public account-deletion route is deployed and verified
- the signed archive privacy report is reconciled with the Apple working
  declaration before App Store Connect answers are entered
- Play Console Data safety and account-deletion answers are recorded from the
  exact release candidate
- reusable reviewer access does not depend on OTP/MFA and exposes every
  restricted review journey
- physical goods/services and digital content are mapped to the correct
  external-payment, Play Billing, or Apple IAP path
- predictions, contests, prizes, UGC, age groups, and territories match the
  approved product/legal decision

## 7. Android TV release steps

Android TV remains in scope under the R67 goal and is a separate package and
artifact. The signed mobile AAB cannot satisfy this gate.

1. Verify/create the Play record for `rw.ikanisa.rayonSports.tv`, Play App
   Signing, upload certificate, and approved public/closed/managed track.
2. Build and provenance-bind a production-signed TV AAB to the same exact
   release candidate.
3. Complete TV Data Safety, rating, support, reviewer access, banner, and
   screenshots.
4. Install from Play and pass physical 720p/1080p/4K D-pad, Menu, focus,
   pairing, overscan, screen-reader, reconnect, network, thermal, burn-in,
   crash/ANR, and four-hour soak tests.
5. Retain the approved-track submission, processing, review, or approval
   receipt.

## 8. Cloudflare cutover and public contract

Cloudflare must be complete before store review because the stores and OS
association checks depend on public policy, deletion, App Link, and Universal
Link responses.

1. Snapshot DNS, Pages associations, Worker domains/versions, TLS, and rollback
   identifiers without changing unrelated mail or verification records.
2. Deploy the exact candidate to `gikundiro-web` and validate `workers.dev`.
3. Canary `fans`, then migrate `admin`, `www`, and the apex from Pages to
   Worker Custom Domains with per-host validation and rollback.
4. Require all four hosts to serve the exact Worker build; retain the Pages
   project only as controlled rollback infrastructure.
5. Validate `/privacy`, `/terms`, support, account deletion,
   `/.well-known/assetlinks.json`,
   `/.well-known/apple-app-site-association`, TLS, redirects, APIs, callbacks,
   CORS, cache, security headers, robots, sitemap, logs, alerts, and a monitored
   observation window.
6. Retain the deployment version, custom-domain state, test results, hashes,
   timestamps, and rollback receipt.

## 9. Localization limitation

- Rayon Sports defaults to `rw` for club language and can localize app-owned copy.
- Flutter framework strings do not ship Kinyarwanda Material/Cupertino translations, so system labels, date pickers, and some dialog controls intentionally fall back to English for launch.
- Treat English framework copy as an approved launch limitation, not a regression, unless a custom Kinyarwanda framework-localization delegate is added.

## 10. Rollout decision

Release only when all of the following are true:

- automated repo gates are green
- the checkout is clean, its exact HEAD is verified on `origin/main`, and a
  non-empty exact-HEAD pinned CI run succeeds with logs and artifacts
- Android dry run is green
- iOS dry run is green
- exact-candidate mobile AAB, iOS archive/IPA, and TV AAB are signed and
  provenance-complete
- production secrets are provisioned outside git
- physical-device smoke tests are green
- internal testers sign off on release candidate quality
- venue/TV/admin/public UAT evidence is recorded in `docs/release/rayon_fullstack_uat_matrix.md`
- Supabase venue/FET/order SQL contract tests pass for touched schema
- legal/payment review is recorded before FET redemption, transfer, or spend
- privacy review is recorded before location verification launch
- alcohol/age review is recorded before drinks ordering launch
- public website remains discovery and handoff only; no browser check-in or live order queue
- TV display shows no personal, wallet, check-in identity, or order data
- all four Cloudflare hosts serve the exact candidate and the public contract
  passes
- Google Play mobile shows the production submission under review or later
- App Store Connect shows the attached build submitted for review or later
- Android TV has an approved-track submission receipt
- named product, design, privacy, security, accessibility, legal/policy,
  operations, QA, rights, language, and final release approvals are retained

If any item above is red, do not ship.

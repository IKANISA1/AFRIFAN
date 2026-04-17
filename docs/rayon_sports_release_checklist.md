# Rayon Sports Release Checklist

This is the canonical release checklist for the `rayon_sports` Flutter fan app.

It assumes the product UI is already approved and frozen for release. This checklist covers engineering, platform, security, and store operations only.

## 1. Automated repo gates

- `flutter analyze apps/rayon_sports`
- `flutter test apps/rayon_sports/test`
- `flutter test apps/rayon_sports/integration_test`
- `bash tools/scripts/validate_club_release.sh rayon_sports`
- Android dry run: `bash tools/scripts/dry_run_android_release.sh rayon_sports`
- iOS dry run on macOS: `bash tools/scripts/dry_run_ios_release.sh rayon_sports`

Expected result:

- all commands exit `0`
- no committed signing material is detected
- no committed Play/App Store credentials are detected
- release artifacts are generated successfully

## 2. Production secrets and credentials

These must exist outside git:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH` for fastlane uploads

iOS external signing inputs must exist in Apple Developer / App Store Connect:

- production signing certificate
- provisioning profile with push notifications enabled
- Apple Team ID configured in Xcode signing
- APNs auth key uploaded to Firebase Cloud Messaging

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
2. Build signed production AAB in CI or a controlled release machine.
3. Verify artifact path:
   `apps/rayon_sports/build/app/outputs/bundle/release/app-release.aab`
4. Upload to Play internal testing first.
5. Verify:
   - install succeeds
   - onboarding works
   - home shell loads
   - contributions hub loads
   - notifications register
6. Promote to closed track only after smoke checks pass.
7. Promote to production only after monitoring internal/closed results.

Fastlane upload prerequisite:

- export `PLAY_STORE_SERVICE_ACCOUNT_JSON_PATH=/absolute/path/to/google-play-service-account.json`

## 5. iOS release steps

1. Run unsigned dry run on macOS:
   `bash tools/scripts/dry_run_ios_release.sh rayon_sports`
2. In Xcode or the release runner, archive a signed production build.
3. Confirm:
   - bundle id is `rw.ikanisa.rayonSports`
   - push capability is enabled in the provisioning profile
   - App Attest entitlement is present
4. Upload archive to App Store Connect / TestFlight.
5. Verify on physical devices:
   - first launch
   - auth restore
   - contributions launch
   - push token registration
   - push delivery

## 6. Store and compliance checks

- privacy policy URL resolves publicly
- terms URL resolves publicly
- support email is monitored
- Play/App Store screenshots and descriptions match actual functionality
- data safety / privacy answers match the implemented app behavior

## 7. Rollout decision

Release only when all of the following are true:

- automated repo gates are green
- Android dry run is green
- iOS dry run is green
- production secrets are provisioned outside git
- physical-device smoke tests are green
- internal testers sign off on release candidate quality

If any item above is red, do not ship.

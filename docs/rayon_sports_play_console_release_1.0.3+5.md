# Gikundiro Play Console Release Handoff

This is the exact Android production release handoff for the Gikundiro app.

## Release Identity

- App name: `Gikundiro`
- Package name: `rw.gikundiro.app`
- Version name: `1.0.3`
- Version code: `5`
- Environment: `production`

## Canonical Public Links

- Website: `https://gikundiro.com`
- Privacy policy: `https://gikundiro.com/privacy`
- Terms: `https://gikundiro.com/terms`
- Support email: `support@ikanisa.com`

## Play Console Release Name

Use:

```text
Gikundiro 1.0.3 (5)
```

## Play Console “What’s new”

Use this exact text:

```text
• Improved upgrade safety for returning supporters by preserving existing sessions during transient restore failures
• Updated privacy, support, and legal links to the live Gikundiro public domain
• Production release hardening for package identity, Firebase validation, and rollout readiness
```

This matches:

- [5.txt](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/android/fastlane/metadata/android/en-US/changelogs/5.txt)

## Production Artifact

Current repo-side dry-run artifact:

- [app-release.aab](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/build/app/outputs/bundle/release/app-release.aab)

Important:

- This dry-run artifact proves the repo builds for release.
- Final Play upload must use the real Android signing lineage for `rw.gikundiro.app`.
- Do not upload an ephemeral dry-run signed bundle.

## Store Metadata To Confirm In Play Console

Before pressing release, confirm these fields in Play Console match the repo:

1. App name is `Gikundiro`.
2. Package name is `rw.gikundiro.app`.
3. Version code shown for the upload is `5`.
4. Contact email is `support@ikanisa.com`.
5. Website is `https://gikundiro.com`.
6. Privacy policy URL is `https://gikundiro.com/privacy`.
7. Data Safety answers match:
   - anonymous authentication is the default auth model
   - email is not collected in the shipped mobile auth flow
   - phone number is optional for MoMo-linked flows
   - Firebase is used for App Check and push messaging where enabled
   - BioPay face data is optional and tied to enrollment

## 100% Production Rollout Checklist

Use this only after the signed `1.0.3+5` AAB is uploaded.

1. Confirm the uploaded AAB is signed with the existing Play signing lineage for `rw.gikundiro.app`.
2. Confirm Play Console reads version code `5`.
3. Confirm `What’s new` uses the `1.0.3` release text above.
4. Confirm the store URLs and support email match the canonical public links above.
5. Install the release candidate over the currently installed production build on a physical Android device.
6. Verify existing-user upgrade behavior:
   - app opens without crashing
   - existing session lands in the app normally
   - user is not silently reset to a new anonymous identity
   - home shell loads
7. Verify supported production flows:
   - ticketing opens
   - membership screen loads
   - settings links open the new live website/privacy/terms URLs
   - BioPay hub loads if enabled for the release
8. Verify push registration on a physical device after upgrade.
9. Confirm there are no Play Console warnings about package mismatch, signing mismatch, or blocked permissions.
10. Only then press `Review release` and proceed to full production rollout.

## Recommended Final Manual Checks

Do these immediately before rollout:

1. Open `https://gikundiro.com/privacy`.
2. Open `https://gikundiro.com/terms`.
3. Send a test email to `support@ikanisa.com`.
4. Confirm the uploaded screenshots and listing still match the real app.
5. Confirm there is no stale `Rayon Sports` package identity in the release form; the package must stay `rw.gikundiro.app`.

## Repo Validation Already Passed

The following repo-side checks were green for this release candidate:

- `bash tools/scripts/validate_club_release.sh rayon_sports`
- `flutter test apps/rayon_sports/integration_test/release_readiness_smoke_test.dart`
- `bash tools/scripts/dry_run_android_release.sh rayon_sports`

## Remaining External Steps

These are still outside the repo and must be done in your release environment:

1. Build the signed production AAB with the real Android signing secrets.
2. Upload the signed AAB to Play Console.
3. Update Play Console listing and Data Safety fields if the console still contains older values.
4. Complete one install-over-upgrade check on a physical production-like device.

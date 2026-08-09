# Android TV Play Console entry checklist

Status: not submitted. Complete in the authenticated console using the exact
approved AAB and preserve dated evidence.

## Before upload

- [ ] Confirm package `rw.ikanisa.rayonSports.tv`, version `1.0.0`, version code
      `1`, signing certificate, Play App Signing, and version-code availability.
- [ ] Confirm managed/private distribution and the permitted organizations, or
      complete and approve a separate public-distribution assessment.
- [ ] Verify the merged release manifest requires Leanback, does not require a
      touchscreen, has a valid launcher icon and 320x180 xhdpi launcher banner,
      and requests only intended permissions.
- [ ] Verify AAB 32-bit/64-bit ABI coverage and 16 KB page-size compatibility on
      current TV devices.
- [ ] Pass physical-TV remote navigation, focus, Back, text scaling, resume,
      offline, pairing expiry, assignment, and revocation testing.

## Store listing

- [ ] Enter the approved English and French title, short description, and full
      description from Fastlane metadata.
- [ ] Upload approved 512x512 icon, 1280x720 TV banner, and at least one actual
      TV screenshot; use the capture plan in `artwork_manifest.json`.
- [ ] Verify support and privacy URLs are publicly reachable and consistent with
      the TV data practices.
- [ ] Record brand/content-rights approval and native-language review.

## Policy forms and access

- [ ] Reconcile and submit Data safety from `data_safety.md`.
- [ ] Complete App access with tested private reviewer steps.
- [ ] Complete target audience, IARC rating, ads, financial features, news,
      health, government, UGC, and all other currently required declarations.
- [ ] Keep a synthetic review session and authorized owner path available for the
      entire review window.

## Submission evidence

- [ ] Record uploaded AAB SHA-256, version code, processing result, device
      catalog, pre-launch/TV quality results, track, rollout status, submission
      time, reviewer status, and final decision.
- [ ] A portal upload is not approval; a processed build is not publication.

# Android TV Play Console entry checklist

Status: internal testing pre-production. Complete the remaining authenticated
console steps using the exact approved AAB; internal testing is not public
submission, review approval, or publication.

## Before public-track promotion

- [x] Production upload AAB SHA-256 `37bfdbd7a7206c7002c4ba6fad55bfc43247e3df133a6d656b72828ff7f1ae77` and upload certificate SHA-256 `FA:4C:70:17:85:D5:19:E4:AF:05:D9:B7:48:B3:F4:82:64:C3:28:63:09:0F:71:DC:A8:C8:04:6B:EA:CB:B7:7D` recorded.
- [x] Play app ID `4972182995232608852`, package `rw.ikanisa.rayonSports.tv`, version `1.0.0`, and version code `1` are confirmed.
- [x] Internal release **Gikundiro TV 1.0.0 (1) – Internal** is available to testers.
- [ ] Record the distinct Play App Signing identity; the recorded `FA:4C:...:B7:7D` fingerprint is the upload certificate.
- [ ] Approve public Google Play TV distribution, countries, audience/content model, and promotion from internal testing.
- [ ] Verify the merged release manifest requires Leanback, does not require a
      touchscreen, has a valid launcher icon, and requests only intended permissions.
- [x] Verify the 320x180 xhdpi launcher-banner source and production-AAB embedded entry have byte-identical SHA-256 `272c3d57586d779f21ac17bf36acde3848ca1f5814ac49b4317b6e77014164b5`.
- [ ] Verify AAB 32-bit/64-bit ABI coverage and 16 KB page-size compatibility on
      current TV devices.
- [ ] Pass physical-TV remote navigation, focus, Back, text scaling, resume,
      offline, pairing expiry, assignment, and revocation testing.

## Store listing

- [ ] Enter the approved English and French title, short description, and full
      description from Fastlane metadata.
- [ ] Upload the prepared approved 512x512 icon, 1024x500 feature graphic,
      1280x720 TV banner, and both actual 1920x1080 TV screenshots; use the
      capture and rights provenance in `artwork_manifest.json`.
- [ ] Order `02_synthetic_reveal.jpg` first because it demonstrates the core
      read-only experience; keep `01_service_unavailable.jpg` second as an
      honest recovery/configuration state.
- [ ] Verify support and privacy URLs are publicly reachable and consistent with
      the TV data practices.
- [ ] Record brand/content-rights approval and native-language review.

## Policy forms and access

- [ ] Reconcile and submit Data safety from `data_safety.md`.
- [ ] Complete App access with tested private reviewer steps.
- [ ] Complete target audience, IARC rating, ads, financial features, news,
      health, government, UGC, and all other currently required declarations.
- [x] Record the authenticated dashboard progress observed on `2026-08-09`: 6 of 11 setup tasks complete (privacy policy, ads, government-app, financial-features, health-app, and category/contact setup).
- [ ] Complete the five remaining setup tasks: content rating, target audience, Data safety, sign-in details, and store listing.
- [ ] Keep a synthetic review session and authorized owner path available for the
      entire review window.

## Submission evidence

- [x] Record local production upload AAB SHA-256 and upload-certificate evidence.
- [x] Record internal-testing release name, version code, and availability to testers.
- [ ] Record Play app-signing identity, device catalog, pre-launch/TV quality results, public track/rollout status, submission time, reviewer status, and final decision.
- [ ] A portal upload is not approval; a processed build is not publication.

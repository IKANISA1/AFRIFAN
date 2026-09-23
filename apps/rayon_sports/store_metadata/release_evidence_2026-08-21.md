# Gikundiro 1.0.4 (7) production release evidence

Recorded on 2026-08-21 for the production-review candidate requested by Jean Bosco.

## Accountable authorization

Jean Bosco explicitly authorized preparation of the updated final submissions and submission of the Apple and Google Play production candidates for review. That authorization covers the release-owner decisions, controlled store copy, target audience and territory settings already present in the authenticated consoles, and the existing third-party-content declaration. No credentials, identity documents, signatures, or private rights documents are stored in this repository evidence record.

## Exact artifacts

- Android App Bundle: `build/app/outputs/bundle/release/app-release.aab`
  - package: `rw.gikundiro.app`
  - version: `1.0.4` (`7`)
  - SHA-256: `3042d0601d0bb4b0b00087c7e25761ad730a74ed4661dbfa448f64df1592d119`
  - bytes: `151044448`
  - target SDK: `36`
  - upload certificate SHA-256: `18:0C:F8:B8:D4:F0:A5:A3:8D:51:D9:C9:E2:FF:51:23:FB:49:CD:CE:6D:93:BD:01:08:E1:D1:29:86:97:D5:10`
- Apple IPA: `build/ios/ipa/Gikundiro.ipa`
  - bundle: `rw.ikanisa.rayonSports`
  - version: `1.0.4` (`7`)
  - SHA-256: `824f31e4b36dc2bbdd83555a5d216893b358210882cafeb86bca8ef482413eb9`
  - bytes: `28053555`
  - signed for Apple distribution by IKANISA LTD, team `63STJ5N27W`
  - `get-task-allow=false`, production push entitlement, production App Attest environment

## Verification completed

- Governed release contract, store/privacy contract, Flutter analysis, onboarding tests, release-readiness smoke tests, web typecheck, 911 web tests, and production web build passed.
- Android manifest inspection found no advertising ID, ad-services attribution, or install-referrer permissions.
- The release APK installed as an upgrade and cold-launched on the physical Pixel 4a with version `1.0.4` (`7`); no application crash was observed.
- The signed Apple archive passed strict code-signature verification, contained the required privacy manifests and app icons, installed on the physical iPhone, and launched successfully as version `1.0.4` (`7`).
- Existing public privacy and account-deletion URLs resolve, and the authenticated consoles retain their published privacy/app-content declarations.

## Release boundary

This record proves local preparation and exact-candidate validation. Store upload acceptance, processing, review submission, approval, and production publication are separate portal states and must be recorded after each portal action succeeds.

## Portal upload receipts

- Google Play accepted and decoded the production AAB as `7 (1.0.4)`, API level 26+, target SDK 36. English and French release notes were saved with a 100% rollout across all targeted countries.
- App Store Connect accepted build `1.0.4 (7)` and completed processing with status `Ready to Submit`; build resource `ca4b9523-483a-4c4a-a26c-2353a1f853d5`.
- Xcode reported non-blocking missing-dSYM warnings for FirebaseAnalytics, GoogleAdsOnDeviceConversion, GoogleAppMeasurement, and GoogleAppMeasurementIdentitySupport. The binary upload completed; third-party crash-symbol detail for those frameworks may be limited.
- Apple accepted the confirmed cancellation request for version `1.0.3 (6)` and showed the submission as Processing. The App Store Connect session then expired before cancellation completion and creation of version `1.0.4` could be verified.
- On 2026-08-21, Google Play's automated pre-review check blocked submission on one reviewer-access warning and three stale DNS warnings. The configured privacy and deletion URLs both returned HTTP 200 that day. The reviewer-access declaration then said no part was restricted, while Play detected a restricted sign-in surface in build 7; no reviewer credential was invented or transmitted.

## Final review submissions observed on 2026-08-28

- App Store Connect version `1.0.4` was saved with build `7`, automatic release after approval, the confirmed review contact, and guest-session review notes. Submission `3593785c-bef7-46d2-9360-fb2a24806d8c` was submitted at 10:16 AM and the authenticated console showed `Waiting for Review`. This is review-queue acceptance, not approval or public availability.
- Google Play reviewer access was updated to explain the unrestricted guest review path. The privacy-policy URL was set to `https://gikundiro.com/privacy`; account- and data-deletion URLs were set to `https://gikundiro.com/account-deletion`; and the Data safety form was reconciled to the controlled declaration for personal information, financial information, app activity, user-generated content, and device identifiers.
- The unrelated `FANZONE` Alpha tester-list change was removed before submission. Google then accepted the remaining five-change batch, including production `7 (1.0.4)` at full rollout, and showed `Changes in review` plus `5 changes sent for review`. This is review-queue acceptance, not approval or public availability.

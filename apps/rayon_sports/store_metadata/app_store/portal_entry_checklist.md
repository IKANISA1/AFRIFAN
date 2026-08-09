# App Store Connect portal-entry checklist

## Account and app record

- [x] IKANISA LTD membership, the Free Apps Agreement through 21 June 2027, and DSA status `Active` are verified for this free no-IAP candidate.
- [x] App record Apple ID `6799646107` uses bundle ID `rw.ikanisa.rayonSports`.
- [ ] Confirm the intended legal entity for the app record.
- [x] Apple ID is captured in the portal-values record.
- [x] Immutable SKU `GIKUNDIRO-IOS-2026` is verified through the App Store Connect API.
- [x] Version/build `1.0.3 (6)` is available and selected in App Store Connect.
- [ ] Distribution certificate/profile/capabilities match the final archive.
- [x] Rwanda-only availability and free price are configured.
- [x] Primary category `SPORTS` is configured.
- [x] Release method `AFTER_APPROVAL` is configured.
- [x] Paid Apps/tax/banking setup is not required for this free candidate with IAP disabled; re-open this gate before enabling paid digital content.

## Metadata and compliance

- [ ] English, French, and Kinyarwanda metadata approvals recorded.
- [ ] iPhone and iPad screenshot sets pass the artwork manifest.
- [x] App icon presence is verified in exact IPA SHA-256 `606739bff02260103ac0ad55eb1b2d1c223f8aea60e9de1c4099ca7572c477bc`; brand/content-rights approval remains separate.
- [ ] Privacy/support/marketing URLs verified live.
- [ ] App Privacy answers match exact archive and SDK privacy report.
- [ ] Age-rating questionnaire and regional results approved.
- [ ] App-level declaration `USES_THIRD_PARTY_CONTENT` is verified; retain the separate accountable content-rights authority gate.
- [ ] Export-compliance answer approved.
- [x] Paid-digital, reward/contest, and cross-user UGC capabilities are classified disabled/not applicable for this candidate by production policy and migration `20260809111441`.
- [ ] Physical/off-app payment, fulfillment, refund/dispute, audience, rights, privacy, and portal declarations approved.
- [ ] Accessibility Nutrition Labels contain only physically verified claims.

## Review and artifact

- [ ] App Review contact and non-expiring demo access entered only in the portal.
- [ ] Review notes list exact enabled features and payment/reward boundaries.
- [x] Exact build-6 IPA SHA-256 and bundle/version evidence recorded in `artwork_manifest.json`.
- [ ] Distribution signing identity/profile/capabilities evidence recorded.
- [x] App Store Connect build resource `2e7356c9-a12a-46d3-be35-c0bd6621b3a0` is `VALID` and `APP_STORE_ELIGIBLE`.
- [ ] Xcode validation and privacy report complete.
- [x] Exact build 6 upload processed successfully; App Privacy remains a separate unresolved submission gate.
- [ ] Store-installed TestFlight UAT on iPhone and iPad complete.
- [x] Build 6 is attached to App Store version resource `9e1e6c87-be1d-4736-82f6-48d397087f62`.
- [x] Review submission `ff812c5c-8f5a-489b-89cd-6ea87bde9908` exists in `READY_FOR_REVIEW` state.
- [ ] Publish App Privacy, then attach the version item to the review submission. The 9 August API attempt returned `409 STATE_ERROR.APP_DATA_USAGES_REQUIRED` with no other associated submission error.
- [ ] Explicitly complete **Submit for Review**; `READY_FOR_REVIEW` is not submission.
- [ ] Capture the exact submission timestamp after submission; the current receipt records only observation date `2026-08-09`.

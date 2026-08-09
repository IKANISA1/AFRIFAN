# Google Play portal-entry checklist

## App record and account

- [ ] Developer identity and contact are verified.
- [x] App record ID `4975567299527059359` exists for package `rw.gikundiro.app`.
- [ ] Confirm the intended legal entity for the app record.
- [x] Package-name registration is confirmed by the authenticated Play record.
- [x] Play App Signing is enrolled and the app-signing fingerprint is recorded.
- [x] The upload-certificate panel now shows `18:0C:...:D5:10`; the previous `3B:26:...:EA:36` certificate and still-visible pending-reset state are recorded separately.
- [ ] Version code `6` is available and selected in Play Console.
- [ ] Finish the remaining production-access/setup tasks; the authenticated dashboard currently shows `3/5` complete and `Not yet sent for review`.
- [ ] Approve the production countries, free/paid status, category, tags, and contact details; the portal currently shows `176` countries/regions.

## Listing

- [ ] English copy approved.
- [ ] French copy approved by a named reviewer.
- [ ] Kinyarwanda copy approved by a named reviewer.
- [ ] Icon, feature graphic, screenshots, and alt text pass the artwork manifest.
- [ ] Accept the recorded build-5/build-6 UI-equivalence basis or recapture from the exact build-6 candidate; current screenshots contain no real supporter data but are not claimed as exact build-6 captures.
- [ ] Brand/content rights approval is recorded.

## App content

- [ ] Cut over the exact release Worker at `https://gikundiro.com/privacy`, then revalidate the privacy-policy URL in Play Console; the portal reports `DNS not found`, while the latest direct probe resolves but returns only the 1,356-byte legacy Pages shell (`9363ebe…` SHA-256 prefix).
- [ ] Cut over the exact release Worker at `https://gikundiro.com/account-deletion`, then revalidate both account-deletion and data-deletion fields in Play Console; both currently report `DNS not found`.
- [ ] Ads declaration reconciled to exact AAB.
- [ ] App access instructions tested from a fresh install.
- [ ] Target audience and IARC complete.
- [ ] Data Safety and deletion answers approved.
- [ ] Financial-features declaration approved.
- [x] Paid-digital, reward/contest, and cross-user UGC capabilities are classified disabled/not applicable for this candidate by production policy and migration `20260809111441`.
- [ ] Physical/off-app payment, audience, rights, privacy, financial-feature, and restricted-permission portal decisions approved.

## Artifact and review

- [x] Exact local candidate AAB SHA-256 `0a47de88b60c74e5988f92d7e4e800dd096c5ffcbc7d5d3b51957cad66b32fa8` (151,205,832 bytes), package `rw.gikundiro.app`, version `1.0.3`, version code `6`, and upload-certificate SHA-256 `18:0C:F8:B8:D4:F0:A5:A3:8D:51:D9:C9:E2:FF:51:23:FB:49:CD:CE:6D:93:BD:01:08:E1:D1:29:86:97:D5:10` are verified and recorded.
- [ ] Re-upload after `2026-08-11T11:24:08Z`, when Play says the registered replacement `18:0C:...:D5:10` certificate becomes valid. The exact code-6 AAB transfer completed on 9 August, but Play rejected processing during the reset activation delay and the rejected artifact was removed from the internal-testing draft.
- [ ] Upload and process version code `6`; no accepted artifact or release exists yet for this candidate.
- [ ] Resolve the four unsent publishing changes and three URL-validation issues; `Submit` is currently disabled.
- [ ] Decide and execute the existing version `1.0.2` (code `4`) production action currently shown as `Start full rollout`; do not conflate it with candidate code `6`.
- [ ] App Bundle Explorer confirms package/version/signing/native compatibility.
- [ ] Pre-launch report reviewed and issues closed.
- [ ] Internal/closed-test store-installed UAT complete.
- [ ] Release notes match the artifact.
- [ ] Production release created with an approved staged rollout.
- [ ] Submission status and timestamp captured from Play Console.

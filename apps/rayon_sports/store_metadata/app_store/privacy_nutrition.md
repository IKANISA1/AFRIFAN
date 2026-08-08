# Gikundiro — App Store Privacy Working Declaration

Status: controlled working declaration; App Store Connect entry and accountable
privacy/legal approval remain pending.

This file mirrors the app-level `ios/Runner/PrivacyInfo.xcprivacy` contract and
must be reconciled with the privacy manifests bundled by every third-party SDK
when the signed archive privacy report is generated.

## Tracking

- Tracking: No.
- Tracking domains: None.
- Advertising or data-broker sharing: None implemented.

## Data linked to the supporter

| Apple category | Purpose | Current use |
| --- | --- | --- |
| Name | App functionality | Optional profile and membership display name |
| Phone number | App functionality | Optional MoMo/contact and supported authentication flows |
| User ID | App functionality | Supabase account, authorization, membership, and account deletion |
| Device ID | App functionality | App attestation, push registration, fraud prevention, and device revocation |
| Purchase history | App functionality | Confirmed tickets, shop orders, and contribution records |
| Other financial information | App functionality | MoMo transaction references, contribution ledgers, and reconciliation data; no payment-card collection |
| Gameplay content | App functionality | Predictions, trivia/game answers, score, and reward state |
| Product interaction | App functionality; Analytics | Feature actions required for the selected journey; optional closed-taxonomy analytics only after consent and release enablement |

## Data not linked to the supporter

| Apple category | Purpose | Current use |
| --- | --- | --- |
| Crash data | App functionality | Conditional Firebase Crashlytics stability diagnostics; account identifiers and raw exception messages are excluded |
| Performance data | App functionality | Conditional Firebase Performance startup/network/runtime measurements |

## Explicit exclusions

- No advertising identifier, cross-app tracking, third-party advertising, or
  sale of supporter data.
- No precise or coarse location is collected by the current build.
- No contacts, microphone audio, camera capture, or photo-library reads are
  requested. iOS photo-library add access is used only when the supporter
  explicitly exports a QR image.
- Optional SMS auto-read is disabled in the production configuration and is
  not available on iOS.
- Crash reporting never receives the Supabase account/profile identifier.

## Submission evidence still required

- Signed archive and Xcode-generated privacy report.
- Reconciliation against the exact SDK set embedded in that archive.
- App Store Connect screenshots/answers and public privacy URL verification.
- Account Holder/Admin/App Manager submission and privacy/legal approval.

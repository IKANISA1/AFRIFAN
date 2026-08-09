# Three-Surface Release Sign-off

Release candidate: ____________________
Commit: ____________________
Target date: ____________________
Goal revision: `2026-08-09-R67`
Goal checkpoint SHA-256: ____________________

No signer may approve from repository intent alone. Attach current device, backend, store-console, and monitoring evidence.
The sign-off is invalid if the candidate commit differs from any signed
artifact, store build, Cloudflare deployment, or retained CI run.

| Gate | Named owner | Evidence link / artifact | Decision and date |
|---|---|---|---|
| Clean exact candidate / `origin/main` / non-empty passing CI |  |  |  |
| Supporter product journeys and UX |  |  |  |
| Android signed artifact / physical UAT / Play internal |  |  |  |
| Google Play mobile listing, declarations, production-access gate, and submission receipt |  |  |  |
| iOS signed artifact / physical TestFlight UAT |  |  |  |
| App Store metadata, declarations, attached build, and App Review submission receipt |  |  |  |
| Native TV signed artifact / physical fleet UAT |  |  |  |
| Google Play Android TV listing and approved-track submission receipt |  |  |  |
| Cloudflare Worker deployment / four custom domains / public contract / rollback |  |  |  |
| Venue operations and staff onboarding |  |  |  |
| Backend migrations, RLS, recovery |  |  |  |
| Analytics consent, minimum-cohort suppression, monitoring, and incident rehearsal |  |  |  |
| Security and privacy |  |  |  |
| Media/content rights and EN/FR/RW language approval |  |  |  |
| UGC, age/territory, payment/IAP, prediction/contest policy |  |  |  |
| Payments/FET legal review |  |  |  |
| Alcohol/age procedure |  |  |  |
| Accessibility |  |  |  |
| Incident response and monitoring |  |  |  |
| Final release owner |  |  |  |

## Required attachments

- Signed Android supporter AAB and TV AAB certificate fingerprints; signed iOS archive/TestFlight build identifiers.
- Source commit, package/bundle ID, version/build, SHA-256, bytes, signer,
  toolchain, mapping/symbol/privacy report, and validation receipt for all three
  artifacts.
- Exact-HEAD GitHub Actions run with executed jobs, logs, artifacts, and pinned
  runtime results.
- Physical Android, Android emulator, physical iPhone, iOS simulator, and representative Android TV results for success, denied, empty, slow, offline, retry, and destructive recovery states.
- Current screenshots at normal and 200% text/reflow plus TalkBack, VoiceOver, keyboard, and D-pad results.
- Supabase migration reset and contract-test output; rollback/recovery rehearsal.
- Store privacy/data-safety screenshots, verified support ownership, public privacy/terms URLs, crash/ANR and incident dashboard links.
- Play mobile and TV and App Store Connect metadata/declaration exports,
  reviewer-access instructions, processing results, and submission receipts.
- Cloudflare Worker version/deployment receipt, four Custom Domain states,
  exact public-contract results, observation window, and per-host rollback
  evidence.
- Venue staff access/revocation exercise and TV credential revoke/rotate exercise.

## Decision

- [ ] GO — every required gate is approved with current exact-candidate
  evidence; Play mobile is submitted for review, Apple is `Waiting for Review`
  or later, Android TV has its approved-track receipt, and the four Cloudflare
  hosts serve the exact candidate.
- [ ] NO-GO — one or more required gates is missing or failed.

An upload, internal build, TestFlight processing result, local deployment, or
console draft does not satisfy the GO definition.

Open exceptions (owner, risk, expiry):

1. ________________________________________________
2. ________________________________________________

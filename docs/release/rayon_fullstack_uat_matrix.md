# Rayon Fullstack UAT Matrix

Updated: 2026-07-18

Status vocabulary: `PASS` means freshly verified against the current tree; `PARTIAL` means implementation is present but required representative-device or external-console evidence remains; `BLOCKED` means a named external approval/input is missing. Historical HTTP-200 screenshots are not workflow proof.

## Required Evidence

| Surface | UAT evidence | Status |
| --- | --- | --- |
| Mobile supporter app | Fan Zone, auth restore, deep links, push consent, check-in/order/payment, offline/retry, deletion | PARTIAL, with iOS distribution binary complete: fresh analysis and 19 app tests pass; the current iPhone 17 simulator traverses the accessible real-photo onboarding into the guest home, and the exact signed Release artifact installs and launches on the physical iPhone. App Store archive and IPA 1.0.3 (5) pass strict signature/profile/entitlement inspection; the signed Android supporter AAB also passes. Generated iOS defines are validated in CI. The carousel passes swipe, compact-height, and 200% text tests; capture: `output/release_readiness_20260718/ios_onboarding_real_club_carousel.png`. TestFlight processing is account-bound. Android emulator/physical Android and full authenticated/offline/retry journey matrices remain required. Historical Pixel evidence is retained but is not current RC proof. |
| Flutter native TV app | Secure pairing, refresh/reconnect, expiry, remote focus, screen-safe data, managed signing | PARTIAL: 8 tests and analysis pass; one-time pairing, hashed/revocable credential, encrypted device storage, 20-second refresh, lifecycle refresh, bounded backoff, countdown, last-updated state, and focused retry are implemented. Release build correctly fails closed without external signing credentials. A TV production keystore has not been supplied, so the signed TV AAB/fingerprint, Android TV device traversal, 720p/4K/overscan/soak, and crash/ANR dashboard evidence remain required. |
| Venue portal | Auth boundary plus today, orders, menu, check-ins, campaigns, TV code, and staff workflows | PASS implementation, automated contracts, and authenticated E2E: all routes are distinct, force-dynamic, session/membership scoped, fail closed, and differentiate empty/error/access states. Venue authorization/operations enforce 100% statements, lines, and functions with 74.76% branch coverage; web typecheck, full-tree zero-warning lint, and stable Next production build pass. Database tests cover cross-venue denial, audited menu/promotion mutations, idempotency, and order/check-in behavior. A temporary manager session traverses all seven routes on mobile Chromium; live membership revocation immediately produces the forbidden wall. Accepted captures: `output/release_readiness_20260718/venue_authenticated_e2e/`. Representative staff acceptance and named operations approval remain external sign-off items. |
| Admin PWA | Protected admin auth wall plus implemented venue governance sections for onboarding approval, staff assignment, campaign controls, FET export/reversal readiness, audit detail, and compliance flags | PASS automated: `output/rayon_product_uat/20260703T072252Z/report.md` captured unauthenticated `/admin/venues` at desktop and mobile, HTTP 200 with the secure sign-in wall. Protected governance internals are covered by `npx vitest run src/app/admin/venues/venue-governance-panel.test.tsx` and `npm run typecheck`; `src/app/admin/layout.tsx` is force-dynamic so admin auth state is evaluated per request. |
| Public website | Approved venue discovery and app handoff only | PASS automated: `output/rayon_product_uat/20260703T072252Z/report.md` captured `/venues` at desktop and mobile, HTTP 200. No authenticated check-in or live order queue is approved for the public website. |
| Supabase | Venue/FET/order and TV credential schema, RLS, idempotency, hashes, audit behavior | PASS: fresh 2026-07-18 `supabase db reset` applies the exact migration chain through `20260718170000_tv_device_credentials.sql`. Venue pgTAP passes 6 tests. Game runtime SQL assertions pass, including one-time TV pairing, no raw pairing/credential persistence, credential state, revocation, legacy anonymous-RPC removal, and audited admin revoke. |
| Edge/RPC | Check-in validate, order create, order update, venue code/security, campaign budget exhaustion, staff permission boundary | PASS automated: `supabase/tests/venue_foundation_contract.sql` covers RPC signatures and behavior for check-in validation, idempotent replay, already-checked-in state, campaign budget exhaustion, drink limit enforcement, alcohol age-gate rejection, order event write, non-staff denial, staff status update, and audit event write. |
| Web quality gates | Reproducible install, typecheck, tests, warning budget, build, dependency audit | PASS: Node 22 + npm 11 plain `npm ci`, typecheck, 154 tests, full-tree lint with zero warnings, stable Next 16.2.10 production build, and `npm audit --audit-level=moderate` all pass with zero known vulnerabilities. |
| Audit artifact integrity | Root `DESIGN.md`, fullstack UAT matrix, and generated compliance report are present without secondary design authority docs | PASS automated: `cmp -s DESIGN.md /Volumes/PRO-G40/DESIGN/DESIGN.md`, `test -s docs/release/rayon_fullstack_uat_matrix.md`, `flutter test --no-pub test/ui_source_guardrails_test.dart`, and `bash tools/scripts/design_compliance_report.sh` with 0 violations and 0 warnings. |

## Operational Runbooks

| Incident | Owner | Required action |
| --- | --- | --- |
| Wrong LiveScore result | Admin/data | Hold settlement, inspect sync logs, record override reason, release only approved result state. |
| TV outage | Venue/admin | Reconnect display, rotate code, confirm no personal data was shown. |
| Venue check-in abuse | Venue/admin/risk | Pause campaign, review duplicate/location/code events, reverse rewards if policy allows. |
| FET ledger dispute | Finance/admin | Export ledger, check idempotency key and reference, apply reasoned reversal if approved. |
| Wrong order status | Venue staff | Write correction event, notify supporter from venue queue, keep audit row. |
| Alcohol/age incident | Venue/compliance | Pause alcohol items, record review, confirm staff age-check copy and procedure. |
| Privacy/location request | Privacy/admin | Export retained check-in/location fields, confirm no background tracking. |

## Release Blockers

- Legal/payment review for FET redemption/spend is missing.
- Privacy review for location retention is missing.
- Alcohol/age-gate review is missing.
- Manual legal/payment review for FET redemption/spend, privacy review for location retention, and alcohol/age-gate procedure approval remain non-code release approvals.
- Any RLS policy allows cross-club or cross-venue access.
- Public website performs authenticated check-in or shows live order queues.
- TV display exposes user, wallet, order, or personal check-in data.
- Mobile app exposes venue staff/admin operations.

# Rayon Fullstack UAT Matrix

Updated: 2026-07-03

## Required Evidence

| Surface | UAT evidence | Status |
| --- | --- | --- |
| Mobile supporter app | Fan Zone venue entry, code entry, check-in states, receipt, drinks order/status, supporter-only boundary, Rayon-first onboarding, and physical Pixel traversal | PASS automated: `flutter test --no-pub test/venue_checkin_screen_test.dart test/venue_order_screen_test.dart test/fanzone_module_test.dart`, `flutter analyze --no-pub` in `packages/features/feat_gamification`, `flutter test --no-pub test/onboarding_flow_test.dart`, `flutter analyze --no-pub` in `packages/features/feat_onboarding`, `flutter test --no-pub test/service_test.dart`, and `flutter analyze --no-pub` in `packages/core/core_feature_config`. Physical Pixel 4a smoke passed with `flutter test --no-pub -d 13111JEC215558 integration_test/release_readiness_smoke_test.dart`. Profile APK evidence: `output/rayon_product_device/20260703T_profile_rayon_onboarding.png` and `output/rayon_product_device/20260703T_profile_route_cycles_manifest.json` (`performance_signoff_ready=true`, 141 frames, 1.42% jank, 1.388s cold start). |
| Flutter native TV app | Android TV Leanback manifest, native Flutter render test, code expiry copy, FET incentive, no personal/order/wallet data | PASS automated, freshly rerun on 2026-07-03: `flutter test --no-pub` in `apps/rayon_sports_tv` passed 3 tests covering screen-safe render, 1080p no-overflow surface, and Android TV launch manifest. Web `/tv-display` remains browser compatibility evidence only. |
| Venue portal | Today dashboard, orders, menu, check-ins, campaigns, TV code, staff view | PASS automated: `output/rayon_product_uat/20260703T072252Z/report.md` captured `/venue`, `/venue/orders`, `/venue/menu`, `/venue/checkins`, `/venue/promotions`, `/venue/tv-code`, and `/venue/staff` at desktop and mobile, all HTTP 200. |
| Admin PWA | Protected admin auth wall plus implemented venue governance sections for onboarding approval, staff assignment, campaign controls, FET export/reversal readiness, audit detail, and compliance flags | PASS automated: `output/rayon_product_uat/20260703T072252Z/report.md` captured unauthenticated `/admin/venues` at desktop and mobile, HTTP 200 with the secure sign-in wall. Protected governance internals are covered by `npx vitest run src/app/admin/venues/venue-governance-panel.test.tsx` and `npm run typecheck`; `src/app/admin/layout.tsx` is force-dynamic so admin auth state is evaluated per request. |
| Public website | Approved venue discovery and app handoff only | PASS automated: `output/rayon_product_uat/20260703T072252Z/report.md` captured `/venues` at desktop and mobile, HTTP 200. No authenticated check-in or live order queue is approved for the public website. |
| Supabase | Venue/FET/order schema, RLS, idempotency, hashed code storage, no negative campaign budget, audit behavior, rollback notes | PASS automated: database-only local Supabase stack reached `20260702143000_venue_checkin_fet_ordering_foundation.sql`, seed completed, and `supabase test db supabase/tests/venue_foundation_contract.sql --workdir /tmp/africlub_supabase_contract` returned `All tests successful`, 6 pgTAP tests. The full stack initially failed on `supabase_storage_AFRICLUB_CONTRACT` health, so the rerun excluded non-database services for pgTAP. |
| Edge/RPC | Check-in validate, order create, order update, venue code/security, campaign budget exhaustion, staff permission boundary | PASS automated: `supabase/tests/venue_foundation_contract.sql` covers RPC signatures and behavior for check-in validation, idempotent replay, already-checked-in state, campaign budget exhaustion, drink limit enforcement, alcohol age-gate rejection, order event write, non-staff denial, staff status update, and audit event write. |
| Web quality gates | Typecheck, focused tests, lint, design compliance | PASS automated: `npm run typecheck`, `npx vitest run src/lib/feature-config.test.ts src/app/tv-display/tv-display-client.test.tsx src/app/admin/venues/venue-governance-panel.test.tsx`, `npm run lint` with 0 errors and existing warnings only, and fresh design compliance `output/design_compliance/20260703T074611Z/VALIDATION.json` (`status=pass`, 0 violations, 0 warnings). |

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

# Rayon Fullstack UAT Matrix

Updated: 2026-08-02

Status vocabulary: `PASS` means freshly verified against the current tree; `PARTIAL` means implementation is present but required representative-device or external-console evidence remains; `BLOCKED` means a named external approval/input is missing. Historical HTTP-200 screenshots are not workflow proof.

## Product Identity Acceptance

Status: `PARTIAL`.

The football-club-first implementation contract is
[`../FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md`](../FOOTBALL_CLUB_FIRST_IMPLEMENTATION_PLAN_2026-07-30.md).
Release UAT must prove:

- primary navigation is Home, Club, Fan Zone, and Membership, with Settings
  behind profile;
- Club exposes official team, news, fixtures, results, standings, history,
  projects, tickets, and shop journeys;
- Home prioritizes current club/football state;
- predictions are free, limited to selected approved matches, and contain no
  betting language;
- AI-assisted football trivia and any approved music trivia use review/publish
  controls and authoritative scoring;
- venue discovery/order/promotion is a secondary matchday experience;
- mobile, TV, web, admin, and venue surfaces project the same club-scoped
  records without role or personal-data leakage.

This acceptance is open at the evidence and release layers. The current source
now implements the required primary hierarchy, canonical Club family, free
selected-match prediction boundary, secondary venue placement, and mandatory
club scope. Existing route, build, or surface-specific PASS records remain
evidence only for their stated scope. The local route ledger remains open at
1,881 admitted cells, 256 open cells, and 679 explicit N/A decisions;
external and accountable release gates also remain open.

## Current Controlled Checkpoint

- Flutter strict analysis: 65 packages pass.
- Flutter deterministic regression: all 45 test-bearing packages pass through
  the root-primary Melos harness.
- Application integration smoke: 3 journeys pass.
- Web: 113 files and 957 tests pass, plus typecheck, zero-warning lint, and
  production build.
- Backend: 15 pgTAP and 74 Deno Edge tests pass.
- Live Games V2 organizer planning: GAME-ORG-01 passes 36 focused Flutter
  tests, 8 localization tests, one inspected deterministic 390 x 844 golden,
  and 80/80 pgTAP checks after a separate full-chain isolated migration.
  Shared/live role/RLS/RPC/audit, real-network multi-display timing,
  physical-device/AT, accountable approval, signing, stores, deployment, and
  release remain open.
- Live Games V2 guarded organizer control: GAME-ORG-02 passes 45 focused
  Flutter tests, 8 localization tests, one corrected and inspected
  deterministic 390 x 844 golden, and the unchanged 80/80 isolated pgTAP
  evidence. One normal next action is separated from confirmed exceptions;
  skip and early-end use bounded-reason dedicated RPCs; conflict/timeout locks
  actions until authoritative refresh. Shared/live role/RLS/RPC/audit,
  real-network timing, physical-device/AT, accountable approval, signing,
  stores, deployment, and release remain open.
- Live Games V2 owner inventory: GAME-OWN-01 passes 49 focused Flutter tests,
  8 localization tests, one inspected deterministic 390 x 844 My TVs golden,
  and a fresh 80/80 full-chain isolated pgTAP run. Complete safe operational
  metadata, assigned-session context, stale-state lockout, and credential-free
  projection pass locally. Shared/live owner/manager authorization, real
  display operations, network timing, physical-device/AT, accountable
  approval, signing, stores, deployment, and release remain open.
- Live Games V2 owner pairing and management: GAME-OWN-02 passes 57 focused
  Flutter tests, 8 localization tests, one inspected deterministic 390 x 844
  TV-detail golden, and a fresh 80/80 full-chain isolated pgTAP run. Named
  authorized locations, confirmed audited rename/move/revoke, native-TV
  bootstrap credential recovery, and obsolete-interface retirement pass
  locally. Shared/live authorization/audit, real displays and network timing,
  physical-device/AT, accountable approval, signing, stores, deployment, and
  release remain open.
- Live Games V2 native-TV pairing: GAME-TV-03 passes 56 native-TV Flutter
  tests, zero-issue analysis, fresh 80/80 full-chain isolated pgTAP, and one
  corrected side-by-side reviewed 1280 x 720 pairing golden. Hashed short-lived
  challenge, exact My TVs owner link, pending authenticated claim, one-time
  secure credential, pairing-material removal, revocation, and recovery pass
  locally. Shared/live, physical-TV/remote/AT, real-network timing,
  accountable approval, production signing, stores, deployment, and release
  remain open.
- Live Games V2 native-TV full projection: GAME-TV-01 passes 58 native-TV
  Flutter tests, zero-issue analysis, the fresh unchanged-backend 80/80
  full-chain isolated pgTAP run, and five exact current-source 1280 x 720
  projection goldens. Paired-empty, scheduled, lobby, question/choices/
  countdown, reveal/public result, contiguous privacy-safe standings,
  completion, pause/cancellation, offline retention, reconnect, and strict
  phase/shape validation pass locally. Shared/live cross-client timing,
  physical-TV/remote/AT and four-hour soak,
  accountable approval, production signing, stores, deployment, and release
  remain open.
- Live Games V2 native-TV Realtime: GAME-TV-02 passes the 58 native-TV tests,
  zero-issue analysis, a fresh 80/80 full-chain isolated pgTAP run, and an
  executable Realtime v2.120.3 network check with five ordered assigned-TV
  events, zero unbound rows through per-event RLS, 542 ms local p95, and zero
  post-revocation delivery. Shared/live WAN loss/soak, cross-client,
  physical-TV/AT, accountable approval, signing, stores, deployment, and
  release remain open.
- Live Games V2 synchronized-session preflight: GAME-QA-03 has a governed
  eight-clause matrix. The exact 2026-08-01 inventory found zero available
  physical phones, one paired but unavailable iPhone 12 Pro, zero physical
  native-TV targets, two iOS simulators, and no attached Android device.
  Simulators/emulators are not accepted as substitutes. The authorized shared
  backend, two-phone-plus-TV execution, correlated exact-build logs/video,
  measured loss/reconnect recovery, physical accessibility, approvals, and
  release remain open.
- Route ledger: 176 routes; 1,881 cells are admitted, 256 are open across the
  final Admin PWA/Venue tranche, and 679 are explicitly not applicable.
- Component ledger: 71 components; all 316 applicable cells evidenced and zero
  open.
- Local artifacts: exact-current unsigned iOS release ZIP, ephemeral-signed
  Android release AAB, ephemeral-signed native-TV release APK, and current web
  production build. The development-signed iOS build also installs and launches
  on the exact paired iPhone 12 Pro. These are not a sealed clean candidate,
  pinned CI, complete physical UAT/AT, production signing, distribution, store,
  target-backend, or production approval.

## Required Evidence

| Surface | UAT evidence | Status |
| --- | --- | --- |
| Mobile supporter app | Football-primary navigation, auth restore, deep links, Club family, offline/retry, Profile/Settings, membership, tickets, shop, narrow role-gated owner/organizer projections, and secondary matchday utilities | PARTIAL: the eleven-route Club family closes 153/153 applicable local route-state cells with 194 passing Club tests and exact visual evidence. All seven local owner/organizer operations routes are evidence-complete: the static hub closes 6/6 applicable cells; `/my-tvs`, `/game-operations/sessions`, and live control close 14/14 applicable cells each with explicit N/A decisions; Pair TV, TV management, and planner close 16/16. Exact focus, held press, 200-percent text, reduced motion, themes, recovery, retained synchronization, conflict/timeout behavior, imperative live actions, and all-control lockout are governed. Strict source analysis, 172 Game Operations tests, package regressions, three integration smoke journeys, GAME-ORG-01/02 and GAME-OWN-01/02 local/isolated-database/visual contracts, exact-current unsigned iOS release, ephemeral-signed Android release AAB, and exact paired iPhone 12 Pro install/launch pass. Approved live Club content, shared/live authorization, real display operations, complete physical-device journeys/AT, production distribution signing, and store evidence remain open. |
| Flutter native TV app | Secure pairing, authoritative game projection, reconnect/resume, remote focus, screen-safe data, and managed signing | PARTIAL: GAME-TV-01/02/03 projection, isolated-Realtime reconciliation and pairing contracts pass locally with 58 tests, zero-issue analysis, 80/80 full-chain pgTAP, five ordered assigned-TV events, zero unbound or post-revocation events, seven governed 720p states, a debug APK build, and inspected exact current native Android TV API 36 emulator pairing captures at 1920 x 1080 and 3840 x 2160. Shared/live WAN loss/soak, production signing, physical-TV overscan/remote/screen-reader traversal, four-hour crash/ANR soak, accountable approval, store and release evidence remain open. |
| Venue portal | Auth boundary plus today, orders, menu, check-ins, campaigns, TV code, and staff workflows | PARTIAL: 112 cells across seven Venue routes remain pending corrected exact-current desktop/tablet/compact browser execution, visual review, and admission. Live authenticated staff/RLS/data/mutation UAT and named staff approval also remain external. |
| Admin PWA | Protected admin governance for clubs, content, matches, games, membership, commerce, venues, audit, and runtime controls | PARTIAL: most Admin routes retain admitted evidence, while 144 cells across nine routes remain pending corrected exact-current production-build browser matrices and admission. Live authenticated operator/RLS/mutation UAT and named operator approval also remain external. |
| Public website | Club information, news, fixtures/results/standings, tickets/shop handoff, and approved venue discovery | PARTIAL: source regression and production build pass; exact-current route-state and release-candidate evidence remain scoped by the route ledger. Authenticated venue operations remain prohibited on the public surface. |
| Supabase and Edge/RPC | Club-scoped schemas, RLS, idempotency, hashes, audit behavior, authoritative game state, venue/order boundaries | PARTIAL: 15 pgTAP and 74 Deno Edge tests pass locally. Production migration, rollback, monitoring, incident rehearsal, and accountable approval remain open; this audit made no production mutation. |
| Web quality gates | Reproducible install, typecheck, tests, warning budget, and build | PASS locally: 113 files and 957 tests, typecheck, zero-warning lint, and the Next production build pass. Release/deployment approval is separate. |
| Audit artifact integrity | Synchronized `DESIGN.md`, current UAT matrix, governed inventories, compliance report, privacy validation, and provenance | PARTIAL: automated source compliance has zero hard violations and two warnings, `route_evidence_complete=false`, and `design_complete=false`. Provenance for the admitted set and all external gates remain separate. |

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

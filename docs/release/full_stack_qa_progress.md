# AFRICLUB full-stack QA progress

## Fifth-club scope amendment — 23 September 2026

CD Costa do Sol / Os Canarinhos is now in the source portfolio as tenant 1001.
The existing four-club approval, test counts and release evidence below do not
certify its Android/iOS builds, website, backend tenant, providers or artwork.
Its release identifiers, approved crest and palette, backend credentials, Mozambique payment
configuration, hosted migration and owner review remain open. The QA plan now
includes the fifth club and ten native platform targets.

## Frontend approval and implementation resumed — 20 September 2026

The owner approved all presented screens and instructed continued implementation. The reviewed gallery and image hashes are bound by `output/qa/full-stack-20260914/frontend-owner-approval-20260920.json`; the existing native reference map records this decision. The corresponding UI is implemented in the shared production modules. Work now continues on actual backend/API outcomes, automatic paid memberships, integration and native build/device checks. Technical, provider, hosted-CI, signing and release acceptance remain separate. No production deployment or provider messages are authorized by this approval.

The current frontend checks are 2,347 Flutter tests, 26 shell tests, 953 web unit tests and 288 browser passes with three explicit skips. The detailed records are `frontend-consolidation-native-verification-20260920.json` and `frontend-consolidation-web-verification-20260920.json`. Older results below retain their original scope and are not renewed by frontend approval.

## Post-approval implementation — paid membership

Three reproduced defects are repaired in forward migrations: reconciliation incorrectly retained an unfulfilled flag after activation (QA-MONEY-013); concurrent checkout/allocation could deadlock (QA-MONEY-014); and membership activation did not bind the selected payment provider/country (QA-MONEY-015). The existing CI-registered PostgreSQL harness now exercises real allocation and activation together, wrong-evidence refusal, late-write rollback, lock-observed contention, four concurrent checkouts, four concurrent allocation retries, receipt repair and exact-once renewal. All pass on a fresh task-owned native PostgreSQL 17 fixture. The 20 scoped cases and source hashes are in `post-approval-membership-implementation-20260920.json`.

Current Edge typechecks and 289 tests also pass. Docker is unresponsive, so the full pinned Supabase/vendor replay and actual Auth/REST/Edge membership journey remain unverified for these migrations. Older pending orders without provider snapshots require a fresh bound checkout; mixed-version rollout and pre-existing paid-but-unprocessed evidence need separate validation. No migration has been applied to a hosted environment. The 37-task goal remains incomplete.

## Earlier full-stack checkpoint

Updated 2026-09-20T09:13:24.407225+00:00. **The 37-task goal is incomplete; release readiness is NO-GO.** Tasks 5, 11 and 16 have scoped local closure. Thirty-four task buckets remain open or partial. Visual review uses `revolut-design` as the sole design authority; full visual fidelity remains unverified.

The 20 September cleanup removed repository-owned scoring/approval artifacts. The 30 September instruction supersedes earlier visual-scope exemptions: the selected skill's MOBILE-DESIGN-100 and corresponding web/admin evidence rules apply directly. The selected skill is the sole design authority across all included surfaces. Local verification passes 58 governance/release-control tests, two route-generation tests (160 routes across four clubs), authority binding and source compliance (zero violations; two existing evidence warnings). The first broader test attempt lacked the pinned bundletool path and is retained with its failure; the configured rerun passes. Historical local records edited to remove retired metadata are explicitly qualified and hashed in `goal-update-design-scope-cleanup.json`; they cannot be treated as unchanged capture originals. Visual review and the remaining QA work stay open.

The current execution authority is [the 37-task plan](full_stack_qa_plan.md). Its scope is Vital'O (Burundi), Rayon Sports (Rwanda), Nkana (Zambia) and AS Vita (DR Congo): eight native targets, 28 packages (24 shared plus four club configurations), public/member websites, admin PWA, 18 Edge functions and shared backend/release infrastructure. The other dedicated products are removed; shared football opponents, stadiums, tickets and Wallet remain. Applied migrations are preserved and new migrations have run only in isolated synthetic databases.

| Verification | Result | Boundary |
| --- | --- | --- |
| Flutter | 28 packages / 2,569 tests pass; strict analysis passes; 55.45% measured line coverage | Full package suite includes the live-match repair; whole native journeys and visual acceptance remain open. |
| Web | 111 unit files / 940 tests pass; lint/typecheck pass; production-mode build `aQF1v-pe2Mh6ZL-A1-R07` | Pinned Node 22.23.2 full checks include the CSS/font extraction. No hosted deployment. |
| Browser baseline | Current build: 581 passed, one harness failure, 12 skipped of 594 | Corrected header check passes 18 repeats across six profiles. All original failures/skips remain recorded. |
| Member recovery | 63 functional + 12 fixture-cleanup checks across Chromium/Firefox/WebKit | Actual isolated Auth/REST/RPC on build `Cmc0QxLAzr6rgw3Gi4lUU`; provider and installed-PWA acceptance separate. |
| PWA | Six profiles: origin loss/reconnect, private membership cache, preference denial, update cancellation, older-tab drafts and light/dark contrast pass | Actual workers with a controlled same-schema revision. Installed mode, durable drafts and arbitrary version migrations remain open. |
| Edge | 288 tests pass across 18 functions | Actual isolated intent handler: 14 checks; commerce handler: 15 checks. AI output/response loss controlled; external providers separate. |
| Parser recovery | 37 SQL checks, five races and 12 actual process-termination/retry outcomes plus cleanup pass | Expired pre-parse work recovers; a saved interpretation or partial business effect requires receipt recovery/review. |
| Database | Fresh pinned vendor replay: 35 contracts / 622 assertions / 37 races pass | Intent allocation and ticket/shop posting, state and rewards are atomic in scope; generic-intent/group/initiative boundaries remain open. |
| Storage | 13 vendor API checks and nine actual handler/Auth/Storage outcomes pass; four cleanup assertions pass | Includes role removal, tenant denial, exact bytes, MIME/size and RLS. First harness-limit failure remains recorded; hosted acceptance separate. |
| Realtime | Actual public WebSocket/controller recovery passes, including reconnect and foreground catch-up | Private cross-account subscriptions and installed devices remain open. |
| Android | Four current debug builds, physical installation/readback, four emulator launches/readbacks and 16 guest checks pass | Physical foreground/hardware/performance and full authenticated workflows remain open. |
| iOS | Four current simulator builds/installations/launches/readbacks; five Rayon native integration journeys pass | Controlled repositories for those journeys; no physical iPhone, provider or signing acceptance. |
| Performance | Bundle budgets and admin-volume benchmark pass; every Lighthouse iteration retained | Current cold-cache Lighthouse: eight of nine passes; Home 0.89 misses 0.90. Native/database performance remains open. |

Current inventory: 244 Dart test files, four integration-test files, 111 web unit files, 52 Playwright specs, 25 migrations and 35 SQL contracts. Counts are not case-acceptance denominators. The regenerated register has 160 routes, 2,560 route/state cells and 1,796 applicable cells still open; twelve archetypes are mapped. The isolated catalog has 136 application base tables, 298 routines, 312 policies, two storage buckets, two public realtime tables and seven scheduled jobs.

Implemented repairs include authorized/idempotent manual and automatic intent allocation; strict fallback receiver/currency/provider binding; conditional group confirmation; 30-second AI deadlines; committed allocation/final-status recovery; bounded member requests, durable sign-out and stale-account protection; club-bound activation; truthful public content and retained-club identity; guest Home public reads; joined live-match refresh/reconnect; preference-storage tolerance; private membership-cache exclusion; quarantined legacy mutation queues; usable offline fallback; and explicit PWA updates that preserve unfinished work when cancelled. Current PWA light/dark text uses semantic roles with 48px controls. The web performance follow-up removes unused font preloads and loads operator CSS only with admin routes. Upload input validation rejects malformed club identities and JSON. Public support, deletion, share content, page metadata and site JSON-LD preserve all four club identities. Parser claims now expire before interpretation persistence; stale workers cannot publish results or overwrite completion. Actual killed-worker recovery passes, with post-interpretation recovery kept separate. Direct raw-status resets cannot bypass a saved worker claim. Commerce confirmation commits persisted evidence, ledger, reconciliation, ticket/shop state and rewards together; cancelled/expired/changed targets and reused provider transactions cannot be silently confirmed.

Thirty-six changed native golden baselines remain pending independent/owner review. Current web review packets (300 packets / 5006 screenshots) are bound to the current build and remain unreviewed; older sets retain their separate bindings. Design fidelity, usability, accessibility, performance, resilience, security/data correctness and release operations are tracked separately.

Continue the open tasks, prioritizing linked financial target/reward consistency, post-interpretation process-death recovery and durable delivery, remaining identity/membership/Predict/ticket/Wallet/shop and real operator journeys, private storage/realtime/jobs, native/device coverage, reference reconciliation, human accessibility and final candidate checks. Firebase configurations and approved iOS icon assets remain absent for three clubs. Local substitutes do not satisfy provider validation.

The execution directory `output/qa/full-stack-20260914/` contains current logs, retained failures, coverage, findings, source/configuration hashes and artifact evidence. `readiness-report.md`, `execution.json` and `remaining-tasks.md` hold the detailed checkpoint. Disk-pressure attempts and provenance failures remain recorded. The desktop app goal retains its older paused object because available controls cannot edit/resume it; implementation follows the user's current repository objective.

The prepared parser change requires its new schema before the corresponding Edge handler. Existing workers without claims require draining or manual review; mixed-version deployment and rollback acceptance remain open.

Hosted CI reports startup failure without a newly established cause. Independent review, owner acceptance, physical devices, providers, signing/distribution, authorized deployment and public/store availability remain separate gates. No production mutation, deployment, store submission or third-party message has been performed.

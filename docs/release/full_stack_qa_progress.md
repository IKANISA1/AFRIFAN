# AFRICLUB full-stack QA progress

Recorded 19 September 2026. The [full-stack QA plan](full_stack_qa_plan.md) remains incomplete: QA-00–QA-08 are in progress and QA-09 final acceptance is pending.

## Current product scope

The supported products are Vital'O (Burundi), Rayon Sports (Rwanda), Nkana (Zambia) and AS Vita (DR Congo), their public/member websites and the admin PWA. There are four Flutter app shells and 28 packages: 24 shared packages and four club configurations. MOBILE-DESIGN-100 acceptance remains **0/8** Android/iOS targets.

The other sixteen dedicated club apps/configurations were removed in `0d56badcaffdf9ff6167485b8ed3eadd431cec5a`. Shared football opponents and fixtures remain.

The partner venue product is removed: public listings, staff portal, mobile check-in/drinks ordering, admin controls and ticket verifier, corresponding APIs/Edge function, runtime registrations, copy, styles, tests and golden baselines. Existing match stadium details, supporter ticket purchases and Wallet issuance remain. Applied migrations are unchanged; a new forward migration retires 16 operational tables and 13 functions, transfers stadium details into ticket events and narrows the affected read policies. It has been applied only to isolated synthetic databases.

## Current local verification

Commands, failures, corrected reruns, source hashes and per-surface qualifications are in `output/qa/full-stack-20260914/`. Current retirement evidence is indexed by `venue-product-removal.json` and `venue-removal-source-manifest.json`; the per-surface result is `readiness-report.md`.

| Check | Result | Boundary |
| --- | --- | --- |
| Flutter | Strict analysis; 654 tests across six affected packages | Includes routes, configuration, localization, Home, Predict/FET Wallet and ticketing; no new mobile release acceptance |
| Web unit suite | 107 files / 893 tests pass | Local component/API contracts; complete system coverage is not established |
| Web build and quality | Production-mode build, typecheck, lint and bundle budgets pass | Loopback-only unavailable backend; no deployment or provider traffic |
| Browser routing | Chromium, Firefox and WebKit pass | Six retired pages and the verifier API return 404; Home, Tickets, Membership and admin sign-in still render |
| Edge | All 18 entrypoints typecheck; 182 tests pass | Provider responses are controlled; live integrations remain unverified |
| Database | Fresh replay of 19 migrations and both seeds; 29 SQL files / 422 assertions pass | Isolated vendor Auth/Storage schema; four supported clubs; zero orphan rows across 276 foreign keys |
| Existing-data upgrade | Existing ticket and Wallet credential preserved; stadium fields transferred; Wallet preparation still succeeds | Synthetic pre-retirement fixture, verified before/after migration |
| Concurrency | Maintained disposable replay and eight Predict/contribution race scenarios pass | Retry identity, wallet balance, kickoff boundary and atomic contribution confirmation remain covered |
| Governance | Route generation, architecture, Edge contract, golden manifest and both copy inventories pass | 160 discovered routes across current surfaces; 88 native/internal-native entries; zero visual acceptance inferred |

Obsolete product evidence no longer contributes to current readiness. Earlier runs remain available in dated ignored artifacts and Git history with their original source bindings. Corrected test expectations, command setup errors and failed intermediate attempts remain distinguishable from successful reruns. No golden image was regenerated to conceal a visual change.

## Retained repairs from the broader QA review

Earlier work repaired currency precision, admin tenant/role boundaries and club selection, dialog focus, responsive layout clearance, service-worker mutation/cache behavior and Auth-to-supporter identity synchronization. The current local suites cover these maintained contracts; earlier live-browser and native evidence retains its original candidate scope.

Member access now retains confirmed history after failed refreshes, discards stale responses after logout/account changes and requires deliberate membership activation. Complete contribution totals use an owner/club-scoped invoker RPC, exact decimal strings and stable pagination. Earlier three-browser journeys verified those bounded outcomes against an isolated backend; they are not complete current-candidate member acceptance.

Payment reference checks bind payer, amount and allowed status. Initiative confirmation, totals and rewards commit atomically with retry and lock-wait revalidation. Posted SMS evidence is protected against forced reinterpretation, and overlapping parser calls use an owner/version-bound claim. Generic intent selection uses actual schema fields and conditional fulfillment. These are scoped repairs, not complete provider settlement verification.

The earlier Rayon Android Club pilot used a synthetic gateway. Five inspected frames and repaired capture timing do not establish four-club production startup, exact reference fidelity, reader usability or physical-device coverage.

## Remaining full-system work

Manual SMS allocation still uses an invalid `completed` status. Complete ledger/reconciliation atomicity, receiver/expiry changes during lock waits, stalled parse recovery, transaction reuse, fallback currency/payee evidence, ticket/shop transitions and notification delivery need further execution and repair.

Complete member account switching, request deadlines, offline restored sessions and failed sign-out; cover remaining admin roles/mutations and installed-PWA update/recovery. Review remaining storage/realtime behavior and performance findings against current query plans.

Complete all four club builds/boots, route/state/source comparisons, reader/enlarged-text checks, performance and recovery evidence. Visual fidelity, usability, accessibility, performance, resilience and security/data correctness remain separate assessments. Independent review, owner acceptance, physical devices, providers, hosted CI, signing, deployment and store/public availability are separate unresolved gates. No production database change, deployment, store submission or third-party message is part of this increment.

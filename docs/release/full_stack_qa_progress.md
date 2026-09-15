# AFRICLUB full-stack QA progress

Recorded 15 September 2026. The [full-stack QA plan](full_stack_qa_plan.md) remains active; this engineering checkpoint does not declare release readiness.

## Implemented and locally verified

- Bound the selected Revolut design authority, retained club identity, strengthened source/artifact provenance, and added MOBILE-DESIGN-100 release enforcement. Independent reviews and owner acceptance remain separate requirements.
- Added isolated Android/iOS QA configurations across twenty club shells, strengthened artifact/signing checks, and corrected native screenshot setup. Sixty Xcode configuration checks passed.
- Repaired currency precision, admin role ordering and club selection, cross-club content mutation boundaries, dialog keyboard focus, responsive navigation/footer clearance, and admin clock hydration.
- Repaired service-worker activation and unsafe mutation retry/queue behavior. Chromium worker checks cover private cache exclusion and bounded offline recovery; installed and other-browser lifecycle acceptance remains open.
- Added database migrations for replayed client/service privileges, verified Auth-to-supporter identity synchronization, and concurrent ticket retry serialization. Restored the seeded twenty-club identity catalog without importing operational admin assignments.

## Verification evidence

| Scope | Latest local result | Qualification |
| --- | --- | --- |
| Web units | 119 files / 971 tests passed | Current production web source |
| Web build, lint and types | Passed | Build `pxPDJGsYbiqYaQDG6U4LB`; production source and artifact seal revalidated before commit |
| Bundle budgets | CSS 44.92 / 45 KiB; JavaScript 166.67 / 170 KiB | Existing thresholds retained; CSS has only 86 bytes of headroom |
| Real admin/browser checks | Chromium 54/54; Firefox 50/50; WebKit 50/50 | Common cases repeat across engines; real isolated Auth/REST with synthetic accounts |
| Home and Settings state matrices | 6/6 matrices; 102 hash-verified PNGs | Three engines; controlled states; captures are unreviewed engineering evidence |
| Database contracts | 26 files / 365 assertions passed | Pinned vendor database with current migration changes; 324 foreign keys checked with zero orphans |
| Database concurrency | Fresh eleven-migration replay and four concurrent-operation scenarios passed | Disposable network-disabled database; includes duplicate ticket admission retries |
| Ticket HTTP handlers | 17/17 checks passed | Production handler dependencies with real local Auth/REST; two identical requests return one admission and one replay |
| Earlier shared/native checks | Strict Flutter analysis; 44 package runs / 2,624 reported successes; 19 Edge entries / 97 tests | Earlier evidence is retained with its original source and execution scope |
| Native artifact | One isolated ARM64 Android pilot APK compiled | Not installed or launched; this does not cover the forty app/platform combinations |

The ticket HTTP test exercises admission fixtures, not provider payment confirmation or Google issuance. Direct member purchase and unsupported payment confirmation remain denied. Temporary test users and ticket fixtures were removed with persisted readback. Synthetic audit evidence was archived before scoped administrative teardown in the isolated database; production audit immutability was not changed.

Detailed command logs, reproduction failures, source/artifact hashes and residual findings remain in ignored `output/qa/full-stack-20260914/`. See its `checkpoint.md`, `execution.json`, `findings.json`, `database-sql-ticket-retry.json`, `ticket-edge-http-admission-after.json`, and current browser reports. Older captures are not relabelled as current acceptance.

## Remaining work

Complete all-club Android/iOS builds and boots, real member/venue/commerce/storage/realtime journeys, installed PWA updates and legacy queue reconciliation, current remaining route/state captures, reader tasks, performance measurements, and independent visual/owner reviews. Native execution is constrained by local disk capacity; nineteen club shells still lack provider registrations and bundled iOS icons.

Actual MOBILE-DESIGN-100 product acceptance is **0/40**. Hosted CI, physical devices, providers, signing, deployment, store review and public availability have separate unresolved gates. This commit records QA implementation and local results; it does not authorize or assert those outcomes.

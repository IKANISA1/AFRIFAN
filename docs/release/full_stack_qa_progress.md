# AFRICLUB full-stack QA progress

Recorded 15 September 2026. The [full-stack QA plan](full_stack_qa_plan.md) remains active; this engineering checkpoint does not declare release readiness.

## Implemented and locally verified

- Bound the selected Revolut design authority, retained club identity, strengthened source/artifact provenance, and added MOBILE-DESIGN-100 release enforcement. Independent reviews and owner acceptance remain separate requirements.
- Added isolated Android/iOS QA configurations across twenty club shells, strengthened artifact/signing checks, and corrected native screenshot setup. Sixty Xcode configuration checks passed.
- Repaired currency precision, admin role ordering and club selection, cross-club content mutation boundaries, dialog keyboard focus, responsive navigation/footer clearance, and admin clock hydration.
- Repaired service-worker activation and unsafe mutation retry/queue behavior. Chromium worker checks cover private cache exclusion and bounded offline recovery; installed and other-browser lifecycle acceptance remains open.
- Added database migrations for replayed client/service privileges, verified Auth-to-supporter identity synchronization, concurrent ticket retry serialization, and admission deadline checks after lock waits. Restored the seeded twenty-club identity catalog without importing operational admin assignments.

## Verification evidence

| Scope | Latest local result | Qualification |
| --- | --- | --- |
| Web units | 119 files / 971 tests passed | Current production web source |
| Web build, lint and types | Passed | Build `pxPDJGsYbiqYaQDG6U4LB`; production source and artifact seal revalidated before commit |
| Bundle budgets | CSS 44.92 / 45 KiB; JavaScript 166.67 / 170 KiB | Existing thresholds retained; CSS has only 86 bytes of headroom |
| Real admin/browser checks | Chromium 54/54; Firefox 50/50; WebKit 50/50 | Common cases repeat across engines; real isolated Auth/REST with synthetic accounts |
| Home and Settings state matrices | 6/6 matrices; 102 hash-verified PNGs | Three engines; controlled states; captures are unreviewed engineering evidence |
| Database contracts | 26 files / 365 assertions passed | Pinned vendor database with current migration changes; 324 foreign keys checked with zero orphans |
| Database advisors | 0 errors; 240 warnings; 266 informational findings | Isolated database only; warnings concern performance; no finding names the changed admission function |
| Database concurrency | Fresh twelve-migration replay, 110 SQL assertions and seven concurrent-operation scenarios passed | Disposable network-disabled database; includes duplicate ticket retries and three deadline expiry cases |
| Ticket HTTP handlers | 20/20 checks passed | Production handler dependencies with real local Auth/REST; duplicate admission remains idempotent and three delayed scans now reject after expiry |
| Earlier shared/native checks | Strict Flutter analysis; 44 package runs / 2,624 reported successes; 19 Edge entries / 97 tests | Earlier evidence is retained with its original source and execution scope |
| Native artifact | One isolated ARM64 Android pilot APK compiled | Not installed or launched; this does not cover the forty app/platform combinations |

The ticket HTTP test exercises admission fixtures, not provider payment confirmation or Google issuance. Direct member purchase and unsupported payment confirmation remain denied. Temporary test users and ticket fixtures were removed with persisted readback. Synthetic audit evidence was archived before scoped administrative teardown in the isolated database; production audit immutability was not changed.

Before the deadline fix, all three held-lock cases admitted a ticket after its event or verifier shift expired. Admission now reads current database time after lock acquisition, including a wait for the verifier assignment, and searches again if that assignment expired. SQL and HTTP regressions verify rejection, an unchanged valid ticket, zero admission events and the recorded decision time. Existing immutable operation retries and service-only execution grants are preserved.

Detailed command logs, reproduction failures, source/artifact hashes and residual findings remain in ignored `output/qa/full-stack-20260914/`. See its `checkpoint.md`, `execution.json`, `findings.json`, `database-sql-ticket-deadline.json`, `database-ticket-deadline-after.json`, `ticket-edge-http-deadline-before-ready.json`, `ticket-edge-http-deadline-after.json`, and current browser reports. Older captures are not relabelled as current acceptance.

After the first QA commit reached `main`, GitHub closed all eight previously reported Dependabot alerts as fixed; a fresh query returned zero open alerts. Hosted CI started no jobs because the account payment or spending-limit condition requires owner action. See [dependency remediation](../governance/dependency-remediation.md) for the separate remote evidence.

## Remaining work

Complete all-club Android/iOS builds and boots, real member/venue/commerce/storage/realtime journeys, installed PWA updates and legacy queue reconciliation, current remaining route/state captures, reader tasks, performance measurements, and independent visual/owner reviews. Native execution is constrained by local disk capacity; nineteen club shells still lack provider registrations and bundled iOS icons.

Triage the advisor performance findings against real query plans and policies before changing indexes or access rules. Unused-index observations from the synthetic QA database do not establish production usage.

Actual MOBILE-DESIGN-100 product acceptance is **0/40**. Hosted CI, physical devices, providers, signing, deployment, store review and public availability have separate unresolved gates. This commit records QA implementation and local results; it does not authorize or assert those outcomes.

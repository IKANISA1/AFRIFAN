# AFRICLUB full-stack QA progress

Recorded 16 September 2026. The [full-stack QA plan](full_stack_qa_plan.md) remains active; this engineering checkpoint does not declare release readiness.

## Implemented and locally verified

- Bound the selected Revolut design authority, retained club identity, strengthened source/artifact provenance, and added MOBILE-DESIGN-100 release enforcement. Independent reviews and owner acceptance remain separate requirements.
- Added isolated Android/iOS QA configurations across twenty club shells, strengthened artifact/signing checks, and corrected native screenshot setup. Sixty Xcode configuration checks passed.
- Repaired currency precision, admin role ordering and club selection, cross-club content mutation boundaries, dialog keyboard focus, responsive navigation/footer clearance, and admin clock hydration.
- Repaired service-worker activation and unsafe mutation retry/queue behavior. Chromium worker checks cover private cache exclusion and bounded offline recovery; installed and other-browser lifecycle acceptance remains open.
- Added database migrations for replayed client/service privileges, verified Auth-to-supporter identity synchronization, concurrent ticket retry serialization, request-bound admission replay, and deadline/event-access checks after lock waits. Restored the seeded twenty-club identity catalog without importing operational admin assignments.
- Added the maintained disposable database replay and race checks to normal CI and the existing self-hosted Supabase gate. Docker is resolved from the runner's PATH; the pinned database image supports Linux AMD64 and ARM64. Hosted execution remains unverified.
- Restored the authenticated venue membership reads required by the real portal, with column grants and existing row policies preserving private notes and mutation restrictions. Added a client-role SQL regression to the maintained database harness.
- Repaired venue admission recovery after a lost response: unresolved requests retain their operation ID across rotating codes, overlapping submissions are suppressed, stalled requests time out, and confirmed retries display the original decision. Corrected unreadable light-mode warning text and result borders.
- Repaired a reproduced database deadlock between wallet preparation and gate admission by locking the ticket before its credential in both paths. Revalidate the credential association after waits; preserve request-bound retries, event/shift checks and service-only admission access.

- Repaired member campaign reads, failed-history handling and stale private data after sign-out. Added authenticated campaign column contracts and eleven member lifecycle regressions; membership activation remains an explicit action.

## Verification evidence

| Scope | Latest local result | Qualification |
| --- | --- | --- |
| Web units | 121 files / 992 tests passed | Current source; aggregate measured line coverage is 61.07%, not complete coverage |
| Web build, lint and types | Passed | Build `vkuIa4EiOca6h-qmQuzqk`; production source and artifact seal verified |
| Bundle budgets | CSS 44.81 / 45 KiB; JavaScript 166.67 / 170 KiB | Existing thresholds retained; CSS has 194 bytes of headroom |
| Real member portal | 33/33 checks, including six fixture teardown checks; 15 hash-verified PNGs | Chromium, Firefox and WebKit; desktop/phone member-panel axe has zero violations; real isolated Auth/REST, controlled 503 and delayed-response cases |
| Earlier real venue recovery | 60/60 checks; 48 hash-verified PNGs | Repeated flow in Chromium, Firefox and WebKit, light/dark, desktop/phone layouts; actual Next API, local Auth/REST and production Edge handler dependencies |
| Earlier venue recovery after the lock-order fix | 10/10 checks | Chromium light-mode desktop/phone confirmation on the new database function and unchanged web build; repeats the recovery flow above |
| Earlier real admin/browser checks | Chromium 54/54; Firefox 50/50; WebKit 50/50 | Original build-bound evidence retained; not rerun on the current member candidate |
| Earlier Home and Settings state matrices | 6/6 matrices; 102 hash-verified PNGs | Original build-bound controlled captures; unreviewed engineering evidence |
| Database contracts | 28 files / 388 assertions passed | Pinned vendor database with current migration changes; 324 foreign keys checked with zero orphans |
| Database advisors | 0 errors; 240 warnings; 313 informational findings | Isolated database only; warnings concern performance; no security warning/error; unused-index observations vary with local statistics |
| Database concurrency | Fresh sixteen-migration replay, 133 SQL assertions and twenty-two operation/concurrency scenarios passed | Disposable network-disabled database; includes preparation/admission overlap, both cancellation orders, and changed/deleted credentials during ticket waits |
| Earlier ticket HTTP handlers | 34/34 checks passed | Production handler dependencies with real local Auth/REST; request binding, revocation, wallet preparation overlap, cancellation and credential maintenance are checked with persisted outcomes |
| Earlier shared/native checks | Strict Flutter analysis; 44 package runs / 2,624 reported successes; 19 Edge entries / 97 tests | Earlier evidence is retained with its original source and execution scope |
| Native artifact | One isolated ARM64 Android pilot APK compiled | Not installed or launched; this does not cover the forty app/platform combinations |

The ticket HTTP test exercises admission fixtures, not provider payment confirmation or Google issuance. Direct member purchase and unsupported payment confirmation remain denied. Temporary test users and ticket fixtures were removed with persisted readback. Synthetic audit evidence was archived before scoped administrative teardown in the isolated database; production audit immutability was not changed.

Before the deadline fix, all three held-lock cases admitted a ticket after its event or verifier shift expired. Admission now reads current database time after lock acquisition, including a wait for the verifier assignment, and searches again if that assignment expired. SQL and HTTP regressions verify rejection, an unchanged valid ticket, zero admission events and the recorded decision time. Existing immutable operation retries and service-only execution grants are preserved.

The next review reproduced incorrect admission responses when an operation ID was reused with a different credential, version or gate, including two concurrent different-ticket requests. Each new audit records the request version and binds replay to its credential and normalized gate. Changed requests return a redacted `operation_conflict`; identical retries retain their original result. Historical audit rows keep an unknown version and require a fresh scan instead of guessing the original request. No audit history is rewritten.

Disabling an event during an assignment lock wait also previously admitted the ticket. Admission now re-reads and locks the current event through the decision, rechecks scope and time, and rejects that scan. Ten added scenarios repeat through SQL and real HTTP; the original checks still pass. Fixture capacities were increased only to accommodate the additional independent tickets; capacity enforcement remains enabled.

The actual venue page initially could not load a staff membership because its required client read grants were missing. Seventeen SQL checks now exercise the exact queries as `authenticated`, including other-user/venue isolation, revoked membership, hidden notes and denied self-promotion. The browser then reproduced a lost-response defect: a committed admission was retried with a new operation and displayed as already used. Recovery now returns the original admission with one audit row; a subsequent deliberate scan gets a new operation and correctly reports already used. Ten maintained component regressions also cover rotating codes, changed gates/versions, overlapping submissions, malformed responses, timeout and optional device feedback.

All six real venue browser runs pass, with zero automated result-panel accessibility violations and no unexpected page errors. Light-mode warning contrast failed before the styling repair. Two representative final captures received an engineering visual inspection; full reference-fidelity, reader and independent acceptance remain open. Recovery IDs currently live in the mounted verifier component: reload, navigation, session change and device restart recovery are not completed by this fix. Camera hardware and provider issuance were not exercised.

The subsequent race review reproduced a database deadlock: wallet preparation held the ticket while waiting for its credential, and admission held the credential while waiting for the ticket. The SQL regression failed with `deadlock detected`; the real HTTP handler returned 500. Admission now locks the ticket first, then re-reads and locks its credential. A deleted or reassigned credential returns a redacted invalid result without consuming either ticket. All prior deadline, revocation and replay cases still pass.

Cancellation tests cover both lock orders. If cancellation commits first, the waiting scan rejects, the ticket is cancelled, and one pending outbox item requests an inactive wallet pass. If admission commits first, the stale cancellation is rejected, the ticket remains used, and one pending outbox item requests completion. These assertions cover local state and audit consistency; delivery to Google remains unrun. See `database-wallet-lock-before.json`, `database-wallet-lock-after.json`, `ticket-edge-http-wallet-lock-before-verified.json`, and `ticket-edge-http-wallet-lock-after.json`.

The authenticated member review reproduced three failures through the actual browser and local backend. Campaigns returned HTTP 403 because ordering used an ungranted column; failed contribution reads replaced verified history with an empty array and zero total; and an in-flight response restored private data after logout. A column-only grant restores campaign ordering without extending private fields or write privileges. The portal now scopes campaigns to the verified membership club, accepts complete successful snapshots, retains confirmed information after failed refreshes, and offers an initial-load retry. Stale reads and identity-bound responses are discarded after logout/account changes; real cross-tab sign-out also clears the private view.

Nine initial component regressions failed before repair; the final eleven pass, including account switching, overlapping refreshes, late contribution responses and unsubscription. OTP verification no longer activates membership implicitly; its success path is component-tested without contacting a provider. Restored-session browser checks independently verify that activation requires a deliberate click. All three browsers pass the same member journey, including other-club campaign exclusion, confirmed-versus-pending totals, 503 recovery, cross-tab sign-out and delayed-response logout. Two current captures received engineering visual review. Full-height element screenshots contain fixed-navigation overlays and do not prove complete viewport clearance or source fidelity.

The latest-twenty history query still requires a larger-history total review (QA-MONEY-002). This increment did not initiate a payment, open a dialer, send an OTP or validate provider/SMS reconciliation. Full browser account-switch, data-request deadlines, offline restored sessions, failed sign-out and installed-PWA acceptance remain open. See `member-portal-evidence.json`, `member-browser-matrix.json`, `member-lifecycle-unit-before-results.json`, `member-unit-suite-results.json`, and `database-sql-member.json`. Current database cleanup confirms zero operational users or member fixtures, twenty clubs, zero orphans across 324 foreign keys, cron disabled and both immutable ticket audit triggers enabled. Docker was restarted during this run; changed unused-index statistics are synthetic observations only.

Detailed command logs, reproduction failures, source/artifact hashes and residual findings remain in ignored `output/qa/full-stack-20260914/`. See its `checkpoint.md`, `execution.json`, `findings.json`, `venue-retry-evidence.json`, `venue-retry-browser-matrix.json`, `database-sql-venue-access.json`, and `database-venue-access.json`. Older captures are not relabelled as current acceptance.

After the first QA commit reached `main`, GitHub closed all eight previously reported Dependabot alerts as fixed; a fresh query returned zero open alerts. Hosted CI started no jobs because the account payment or spending-limit condition requires owner action. See [dependency remediation](../governance/dependency-remediation.md) for the separate remote evidence.

## Remaining work

Complete all-club Android/iOS builds and boots, remaining member/venue/commerce/storage/realtime journeys, installed PWA updates and legacy queue reconciliation, current remaining route/state captures, reader tasks, performance measurements, and independent visual/owner reviews. Native execution is constrained by local disk capacity; nineteen club shells still lack provider registrations and bundled iOS icons.

Triage the advisor performance findings against real query plans and policies before changing indexes or access rules. Unused-index observations from the synthetic QA database do not establish production usage.

Actual MOBILE-DESIGN-100 product acceptance is **0/40**. Hosted CI, physical devices, providers, signing, deployment, store review and public availability have separate unresolved gates. This commit records QA implementation and local results; it does not authorize or assert those outcomes.

# AFRICLUB: remaining production-readiness tasks

**Compiled:** 29 September 2026. **Decision:** NO-GO for production release.

Implementation is now tracked in the [living task register](production-readiness-task-register.json)
and [current progress checkpoint](production-readiness-progress-2026-09-29.md).
The recorded Drive statuses below remain historical. Current local results,
remaining acceptance and observed external blockers are recorded separately.

This is a consolidated execution list, not a claim that the dated Drive task statuses were independently re-tested today. The 130 numbered tasks below come from the 28 September Implementation 08 `TASK_REGISTER.json`, preserved inside the [Drive package](../drive-import/2026-09-28/mirror/AFRICLUB_Implementation_08_2026-09-28.zip). Its acceptance criteria are reproduced below. All 130 lack a release-accepted closure in that register: 93 Open, 37 In progress (37 P0, 91 P1, two P2). The [current repository QA plan](full_stack_qa_plan.md) contributes 34 still-open execution checks. Those checks overlap the 130 tasks and must not be added to them as 34 distinct product features.

## Reconciliation required before release claims

1. **Set one exact candidate and scope.** The active checkout has five club app shells: Vital’O, Rayon Sports, Nkana, AS Vita and Costa do Sol. The QA plan explicitly adds Costa do Sol and ten Android/iOS targets, while its older checklist entries and the 23 September readiness checkpoint still cite four clubs or eight artifacts. Reconcile every inventory, approval and test result to the five-club candidate. The four-club owner approval applies only to its recorded artifacts.
2. **Reconcile the Drive implementation lineage with active source.** Implementation 08 is a 416-file scoped candidate based on exact Implementation 07. It was initially preserved for review. The current goal has selectively integrated 81 payment/allocation/delivery paths, with reviewed corrections and further integration tracked in the living register. The [Drive comparison](../drive-import/2026-09-28/REVIEW.md) found 94 archive paths with multiple versions and 26 divergent active paths at the initial comparison. Remaining auth/native/web/operator/public modules and existing divergent paths require explicit disposition, followed by a protected candidate with a source-to-artifact manifest.
3. **Restore hosted verification.** On 29 September, `origin/main` resolved to `6fa4588eec0903ea76a3d2f148c4942381dd40d0`. Its [28 September push run](https://github.com/IKANISA1/AFRIFAN/actions/runs/36472373062) ended `startup_failure` with zero jobs. Local Drive-review commits are not a hosted QA pass. Diagnose the actual startup failure, then run required workflows for the exact release candidate.
4. **Treat source evidence and release evidence separately.** The Drive review verified file coverage and hashes, not product behavior. The 23 September [readiness checkpoint](../../output/qa/full-stack-20260914/readiness-report.md) is four-club and historical for the new scope. The [release sign-off](football_platform_release_signoff.md) has blank gate, owner and decision fields. Refresh each against the exact candidate before any release decision.

## Recommended gate order

| Gate | Required result | Main task IDs |
| --- | --- | --- |
| G0: containment and source trust | Confirm/restrict Drive and privileged access; classify actual exposed credentials; protect and reconcile one candidate. | SEC-01–10; REP-01–10 |
| G1: architecture, data and identity | Approve authority boundaries, restore/reconcile data, test tenant and revocation controls. | ARC-01–10; DAT-01–10; AUT-01–10 |
| G2: financial and product behavior | Prove authenticated provider evidence, monetary conservation, fulfillment, refunds, club flows, content rights and agreed Predict rules. | PAY-01–10; PRD-01–10; MOB-01–10; WEB-01–10 |
| G3: candidate assurance | Complete five-club, ten-target QA, hosted CI, isolated target contracts, independent security, accessibility, performance and recovery. | QAT-01–10; QA checklist 1–37 |
| G4: operational and legal approval | Prove alerting, backup/restore, on-call, retention, territory/store position and club approval. | OPS-01–10; REG-01–10 |
| G5: controlled release | Rehearse cutover and rollback, secure named go/no-go signatures, then stage, observe and reconcile deployment and stores. | REL-01–10 |

## All 130 recorded release tasks

**Status column:** the 28 September Drive register status. “In progress” means partial work, not release acceptance. The acceptance evidence column states what must be produced to close the task.

### Security containment

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| SEC-01 | P0 | Open | Restrict public-link write/read permissions | Security lead | Fresh metadata for root, children and archives shows approved named principals only; owner signs the access review. |
| SEC-02 | P0 | Open | Preserve and review Drive/Git/provider audit history | Security lead | Time-bounded access/revision evidence preserved; unexplained edits and downloads investigated with a documented incident decision. |
| SEC-03 | P0 | Open | Inventory sensitive artifact exposure without broadcasting values | Security lead | Classify .env, keystores, service credentials, exports and caches; distinguish public client keys from secrets and map validity/use. |
| SEC-04 | P0 | Open | Rotate exposed live backend/provider secrets where confirmed | Security lead | Validated replacement, revoked old secret, service smoke and rollback plan; do not rotate unclassified values blindly. |
| SEC-05 | P0 | Open | Review Android upload/signing credentials and reset affected key | Security lead | Determine Play App Signing arrangement; approved reset/rotation plus clean-build signature verification and release continuity. |
| SEC-06 | P0 | Open | Restrict production backups and personal-data exports | Security lead | Private encrypted backup store, least-privilege ACLs and access audit; no unrestricted conversation/archive copies of sensitive exports. |
| SEC-07 | P1 | In progress | Scan candidate, Git history, bundles and archives for secrets | Security lead | Independent scan reports zero unapproved live secrets; false positives reviewed and historical exposure addressed. |
| SEC-08 | P1 | In progress | Define redaction and evidence-publication policy | Security lead | Automated tests prevent token/phone/payment-body leakage; approved synthetic data and masking rules for screenshots/logs. |
| SEC-09 | P1 | Open | Require phishing-resistant MFA and privileged access review | Security lead | Named staff access, step-up for critical actions, break-glass logging and tested removal of a departing operator. |
| SEC-10 | P1 | Open | Harden build and deployment credentials | Security lead | Minimal token scopes, environment-separated secrets, immutable action pins, protected runners and approved artifact access. |

### Source convergence

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| REP-01 | P0 | In progress | Establish one protected canonical candidate commit | Repository maintainer | Repository URL, commit SHA, branch protections, ownership and accepted source manifest recorded; Drive archive classified separately. |
| REP-02 | P0 | In progress | Reconcile every batch payload with current paths and hashes | Repository maintainer | Path-by-path accepted/rejected/superseded mapping includes original files, revised siblings and Batch 12 additions. |
| REP-03 | P0 | In progress | Promote approved fixes without downgrading newer code | Repository maintainer | Reviewed merge commits preserve current auth/payment interfaces; no blind application of cumulative v1–v4 archives. |
| REP-04 | P0 | In progress | Repair boundary validator and real-source exception handling | Repository maintainer | Minimal valid fixture and actual migration inventory pass; prohibited runtime schema/routes and expired/wrong-hash exceptions fail. |
| REP-05 | P1 | Open | Separate source, generated output and archival evidence | Repository maintainer | Clean fresh clone excludes caches, build outputs, signing files and archive copies; recoverable evidence retained outside tracked source. |
| REP-06 | P1 | In progress | Create source-to-build-to-deployment manifest | Repository maintainer | Every artifact maps to source SHA, dependencies, toolchain, config fingerprint, migrations and intended environment. |
| REP-07 | P1 | In progress | Register all current backend/native verification commands | Repository maintainer | Main CI invokes relevant current module suites; missing SDK/platform jobs report blocked rather than success. |
| REP-08 | P1 | In progress | Install/reconcile iOS recovery source into the candidate | Repository maintainer | Thirteen Batch 12 source paths accepted or replaced explicitly; imports and build registration tracked, not archive-only. |
| REP-09 | P1 | In progress | Pin and reproduce supported toolchains and dependency locks | Repository maintainer | Fresh install with repository-required Dart/Flutter/Node/npm and pinned Android/Apple tools succeeds without lock mutation. |
| REP-10 | P1 | In progress | Normalize governance hierarchy and task identifiers | Repository maintainer | One design authority/adapter hierarchy, unique task IDs, authoritative object disposition register and dated evidence semantics. |

### Architecture and boundaries

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| ARC-01 | P0 | Open | Approve data-store boundaries and single-writer topology | Technical architect | ADR identifies command authorities, transaction boundaries, backups, residency and rollback; no unsupported cross-DB atomicity claim. |
| ARC-02 | P0 | Open | Benchmark actual D1 transaction and trigger behavior | Technical architect | Real isolated D1 tests cover every financial statement/trigger, limits, foreign keys, retries, concurrency and rollback. |
| ARC-03 | P0 | Open | Define revocation semantics by operation | Technical architect | Checkout, read, allocation, refund and admin decisions have documented acceptance points and tested revocation races. |
| ARC-04 | P1 | Open | Reassess custom authentication operational burden | Technical architect | Threat model and cost/risk ADR compares maintaining custom identity to approved alternatives; no identity rewrite without migration plan. |
| ARC-05 | P1 | In progress | Version all service and public client contracts | Technical architect | Generated schemas, compatibility matrix and tests cover old clients, unknown fields, error envelopes and enum evolution. |
| ARC-06 | P1 | Open | Centralize immutable club/slug/partner mapping | Technical architect | Missing, conflicting and wrong-host tenant inputs fail; IDs preserved and all five release mappings signed off. |
| ARC-07 | P0 | Open | Preserve one global consumed-payment-reference authority | Technical architect | Cross-club/provider race tests and historic claims prevent reuse; any partition proposal includes a proven replacement uniqueness mechanism. |
| ARC-08 | P1 | Open | Approve currency units, rounding, timezone and period rules | Technical architect | Tests cover RWF/BIF/ZMW/CDF/MZN conventions, leap dates and cutoff boundaries using signed business rules. |
| ARC-09 | P1 | In progress | Minimize service capabilities and external attack surface | Technical architect | Each binding has an explicit principal and allowed methods; public HTTP cannot invoke financial or admin private capabilities. |
| ARC-10 | P1 | Open | Measure game-day capacity and choose scaling boundaries | Technical architect | Load model includes read/write mix, OTP bursts and shared databases; p95/p99, overload behavior and cost satisfy approved budgets. |

### Data migration and integrity

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| DAT-01 | P0 | Open | Refresh complete source-object and runtime-caller inventory | Data migration lead | Every table/view/function/trigger/policy/job/provider call has source identity, disposition, owner and evidence; dynamic calls traced. |
| DAT-02 | P0 | Open | Reconcile local versus deployed function behavior | Data migration lead | All 18 deployed entrypoints and local-only Wallet functions mapped; bundle differences compared behaviorally and retired scope approved. |
| DAT-03 | P0 | Open | Create isolated migration environments with approved locality | Data migration lead | Account, resource IDs, bindings and dummy data checked; no existing project resources reused by accident. |
| DAT-04 | P0 | Open | Produce a transactionally consistent final export strategy | Data migration lead | Rehearsal includes write freeze/delta capture, Auth/app data, privileges, operational dependencies and exact cutoff proof. |
| DAT-05 | P0 | Open | Reconcile complete historical payment reference claims | Data migration lead | Counts, uniqueness, provenance and source coverage across every affected club/target reconcile before candidate allocation is enabled. |
| DAT-06 | P0 | In progress | Map data types and financial balances with exception reports | Data migration lead | IDs, amounts, timestamps, JSON, nulls and enums transformed deterministically; counts/sums/member terms/stock/tickets reconcile. |
| DAT-07 | P0 | Open | Recover and verify the eight unresolved AFRICLUB media originals | Data migration lead | Read source access status afresh; all originals or formally approved remediation evidenced by bytes, hashes and rights. |
| DAT-08 | P1 | Open | Keep the separate Gikundiro public dataset provenance distinct | Data migration lead | Source season, owner, rights, IDs and 11-object mapping documented; do not substitute these for missing AFRICLUB originals. |
| DAT-09 | P0 | Open | Restore complete database and object backups in isolation | Data migration lead | Fresh restore proves row/key/financial parity and executable app dependencies, with all restored jobs disabled until approved. |
| DAT-10 | P1 | In progress | Implement repeatable migration reconciliation and delta checks | Data migration lead | Machine-readable pre/post evidence reports no unexplained drift; rejected rows and policy differences receive approved disposition. |

### Identity and authorization

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| AUT-01 | P0 | Open | Threat-model identity and tenant trust boundaries | Identity lead | Document access/refresh/OTP flows, trusted issuer, key lifecycle, abuse paths and user/staff separation; review independently. |
| AUT-02 | P1 | In progress | Replace pilot OTP limits with fair measured controls | Identity lead | Per-club, per-subject/phone, IP and global cost budgets tested; one club cannot silently exhaust unrelated sign-ins. |
| AUT-03 | P1 | Open | Complete lost-phone, phone-change and account-linking flows | Identity lead | Proof-of-control, recovery escalation, reassignment risks and identity continuity tested; no name/suffix-based account merging. |
| AUT-04 | P1 | Open | Complete protected native credential storage and refresh coordination | Identity lead | Keystore/Keychain-backed credentials, single-flight rotation and original retry keys survive crash; no plain-preference fallback. |
| AUT-05 | P1 | In progress | Implement browser authentication and CSRF contract | Identity lead | HttpOnly/Secure cookies, session rotation, logout, CSRF and origin checks validated against the intended browser portal. |
| AUT-06 | P0 | Open | Enforce tested revocation/fencing for sensitive domain commands | Identity lead | Revoked/stale epochs cannot authorize new protected mutations beyond the approved boundary; response loss remains recoverable. |
| AUT-07 | P1 | Open | Implement complete account erasure orchestration | Identity lead | Processor acknowledgements, retained legal records, deletion status, backups policy and failed-job recovery recorded without false completion. |
| AUT-08 | P1 | Open | Reconcile existing identity and profile bootstrap | Identity lead | Original UUIDs, phone binding, club mappings and profiles preserved; signup does not grant paid or staff entitlements. |
| AUT-09 | P1 | Open | Implement custom-auth key rotation and incident recovery | Identity lead | Old/new versions coexist for controlled window; revocation, ciphertext recovery and key-loss runbooks proven with test keys. |
| AUT-10 | P1 | Open | Run live isolated identity/provider acceptance | Identity lead | Real approved test phone/WhatsApp template, code expiry, duplicate status, blocked user and session restore succeed without production imports. |

### Payments and fulfillment

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| PAY-01 | P0 | Open | Integrate authenticated payment evidence and account reconciliation | Payments lead | Verified ingress identifies exact receiver/provider/transaction; three-way evidence/order/receiving-account match with no manual fabricated attestation. |
| PAY-02 | P0 | In progress | Implement late, partial, duplicate and ambiguous payment exceptions | Payments lead | Expired/cancelled/overpaid/wrong-amount payments enter governed queues; resolution preserves original references and audit, not forced reuse. |
| PAY-03 | P0 | Open | Implement refunds, reversals and administrative corrections | Payments lead | Compensating records preserve original financial history; duplicate refunds prevented; approvals and external status reconciled. |
| PAY-04 | P1 | In progress | Complete current membership entitlement and receipt separation | Payments lead | Current status/expiry/suspension read distinct from historical receipt; renewal preserves member ID and does not lift suspension. |
| PAY-05 | P1 | Open | Complete initiative contributions including totals/rewards/referrals | Payments lead | All approved effects commit or recover together; allocation-only records never shown as confirmed contributions. |
| PAY-06 | P1 | Open | Complete supporter-group contributions and statements | Payments lead | Group/member ownership, allocation, balances, exports and correction rules reconcile with preserved source behavior. |
| PAY-07 | P1 | Open | Complete ticket inventory, issuance, transfer and redemption | Payments lead | Concurrent last-seat purchase, duplicate scans, cancellations and refunds tested; offline validation policy prevents silent double entry. |
| PAY-08 | P1 | Open | Complete shop inventory, ordering and fulfillment | Payments lead | Stock reservations, shipping/service terms, cancellation/refund, receipts and idempotent fulfillment reconcile end to end. |
| PAY-09 | P1 | In progress | Implement idempotent outbox consumers and dead-letter handling | Payments lead | Effect deduplication is atomic with downstream state; retry, acknowledgement loss, poison events and manual re-drive tested. |
| PAY-10 | P0 | Open | Prove end-to-end financial conservation and cutover parity | Payments lead | Duplicate callbacks and concurrency cannot duplicate membership/stock/debits; aggregate balances/claims and source cutoffs reconcile. |

### Native app completion

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| MOB-01 | P1 | Open | Compile and test actual Android recovery host | Mobile lead | Repository-pinned Kotlin/AGP/SDK compile host and bridge; emulator/device tests prove Keystore, locked-device and engine-disposal behavior. |
| MOB-02 | P1 | Open | Compile and test actual iOS recovery host | Mobile lead | Supported Xcode/iOS SDK compiles Keychain/Flutter host; accessibility classes, entitlements and foreground checks verified on devices. |
| MOB-03 | P1 | Open | Run pure Dart and Flutter analysis and authored harnesses | Mobile lead | All previously blocked Dart contracts and channel cases execute with no findings; no JVM/TS result counted as a Dart pass. |
| MOB-04 | P1 | Open | Register shared adapters in all five governed app compositions | Mobile lead | No duplicated business logic; dependency/layer validators pass; feature remains disabled in unapproved clubs/platforms. |
| MOB-05 | P1 | Open | Build accessible review, confirm and recovery screens | Mobile lead | All payment fields and consequences displayed; separate foreground confirmation, assistive-technology and large-text tests pass. |
| MOB-06 | P0 | In progress | Implement server-authoritative lost-state and unresolved-attempt recovery | Mobile lead | Reinstall/clear-data/device-loss cannot silently authorize a second unresolved payment attempt; governed resolution has durable audit. |
| MOB-07 | P1 | In progress | Wire lifecycle, logout, account-switch and route guards | Mobile lead | Backgrounding/session/club change invalidates review; restoration performs reads only and preserves unknown outcomes. |
| MOB-08 | P1 | Open | Validate USSD handoff on approved carriers and SIM scenarios | Mobile lead | Each supported Android/iOS-carrier path proves exact code display and explicit confirmation; unsupported paths fail clearly; no automatic payment. |
| MOB-09 | P1 | Open | Verify merged native privacy/link/notification configuration | Mobile lead | Final manifests, associated domains, permission requests, push token scoping and app links checked for every release flavor. |
| MOB-10 | P1 | Open | Execute ten signed club/platform release journeys | Mobile lead | Five clubs times Android/iOS cover install, upgrade, weak network, restore, payment recovery and logout on representative physical devices. |

### Public web and administration

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| WEB-01 | P0 | In progress | Install active-snapshot publication/read integration | Web/admin lead | The executed public entrypoint reads one sealed approved snapshot; partial imports and stale mixed records fail covered tests. |
| WEB-02 | P1 | In progress | Implement media digest, rights revocation and cache policy | Web/admin lead | Same-size wrong bytes denied; expired/revoked rights unavailable through CDN/object URLs; content-addressed caching tested. |
| WEB-03 | P1 | In progress | Define browser member portal boundaries and session contract | Web/admin lead | Approved route/product matrix covers current web membership and contribution initiation without reusing native-only headers as security. |
| WEB-04 | P1 | In progress | Connect browser membership/contribution flows to approved APIs | Web/admin lead | Cookie session, CSRF, owned reads, unknown writes and no automatic financial retry pass integrated browser tests. |
| WEB-05 | P1 | In progress | Reconcile and wire operator console configuration and wrapper | Web/admin lead | Documented console entrypoint/config/assets exist and build; current API implements all UI-used methods with real Access identity. |
| WEB-06 | P1 | In progress | Complete role-scoped admin actions and maker/checker where required | Web/admin lead | Finance/content/support roles have explicit per-club authority, separation-of-duties rules and immutable audit trails. |
| WEB-07 | P1 | In progress | Harden PWA caches, offline states and logout cleanup | Web/admin lead | Private pages/responses not cached across accounts; offline status does not show success for unconfirmed writes; stale assets update safely. |
| WEB-08 | P1 | In progress | Replace permissive CSP and broad origins with reviewed policy | Web/admin lead | Nonce/hash policy or documented safe alternative; no unexpected script/storage origins, unsafe redirects or cross-tenant cache keys. |
| WEB-09 | P1 | Open | Validate domains, SEO and link metadata per club | Web/admin lead | Hostname/slug mapping, canonical URLs, sitemap, robots, legal routes, previews, universal/app links and TLS checked for five sites. |
| WEB-10 | P1 | Open | Complete real desktop/mobile-browser and operator UAT | Web/admin lead | Current candidate tested in Chromium/WebKit/Firefox where supported with real isolated Access and private roles; screenshots not surrogate network proof. |

### Product, content and design

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| PRD-01 | P0 | Open | Approve one Predict/FET economic contract | Product/design lead | Versioned free-entry or separately approved alternative; ledger/API/UI/terms/tests and historical treatment agree before transactional enablement. |
| PRD-02 | P1 | Open | Complete authoritative fixture/result lifecycle | Product/design lead | Feed IDs, kickoff, postponement, void, official-result correction and settlement finality controlled server-side; duplicate feeds tested. |
| PRD-03 | P1 | Open | Approve source/media/brand rights with expiry and scope | Product/design lead | Club crests, players, ticket/shop images, feeds and generated assets have owner, permission, territory and renewal evidence. |
| PRD-04 | P1 | Open | Reconcile design authority and reusable semantic tokens | Product/design lead | One accessible shared token/component system and documented club identity overrides; private skill provisioned to authorized reviewers/CI. |
| PRD-05 | P1 | Open | Define complete state and accessibility matrix | Product/design lead | Loading/empty/error/offline/permission/unknown/disabled/destructive states mapped to real routes; WCAG 2.2 AA and native checks specified. |
| PRD-06 | P1 | Open | Populate current route/state and artifact-evidence registries | Product/design lead | Each required cell links exact candidate/config/build/screenshot/test and accountable reviewer; empty registry is no longer treated as closure. |
| PRD-07 | P1 | Open | Resolve market-language and translation policy explicitly | Product/design lead | Current English-only/source policy preserved until an approved change; test comprehension and terminology with each club market. |
| PRD-08 | P1 | Open | Complete onboarding, consent, help and support journeys | Product/design lead | New supporter, returning member, denied staff, missing record and recoverable payment flows have clear human support escalation. |
| PRD-09 | P1 | Open | Verify runtime flags and deep-link authorization everywhere | Product/design lead | Build capability, club policy, runtime enablement and user authority agree; direct links/cached sessions cannot re-enable blocked operations. |
| PRD-10 | P2 | Open | Validate product analytics and club success measures | Product/design lead | Privacy-approved events distinguish prepared checkout, dialer opened, evidence allocated and active member; no inflated conversion success. |

### Verification and assurance

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| QAT-01 | P0 | In progress | Bind release checks to immutable candidate artifacts | QA/security verification lead | Required job results, config hashes, signing provenance and source SHAs agree; deployments consume the checked artifact only. |
| QAT-02 | P1 | Open | Run complete pinned-toolchain workspace and web checks | QA/security verification lead | Fresh checkout resolves locked dependencies; Flutter/Dart analysis/tests, Next typecheck/lint/build and asset checks all pass. |
| QAT-03 | P1 | Open | Run local replay plus real isolated D1/Workers contract tests | QA/security verification lead | Migrations, triggers, RPC envelopes, Access context and service bindings validated in actual target runtime in addition to Node/SQLite. |
| QAT-04 | P1 | In progress | Create positive and negative multi-tenant acceptance suite | QA/security verification lead | Cross-club reads/writes/storage/realtime/cache/exports/deep links denied; legitimate five-club journeys preserved. |
| QAT-05 | P1 | Open | Commission independent API/web/mobile security verification | QA/security verification lead | Versioned ASVS/MASVS scope, threat model and findings register; no unresolved critical/high exploitable issues in enabled release scope. |
| QAT-06 | P1 | Open | Test financial concurrency and failure recovery on actual target | QA/security verification lead | Callback duplication, competing stock, cutoff waits, crashes, retries and reversals preserve approved invariants and immutable history. |
| QAT-07 | P1 | Open | Run dependency, SBOM, license and supply-chain review | QA/security verification lead | Current advisories checked on exact lockfiles and artifacts; reachable vulnerabilities and licenses have approved disposition. |
| QAT-08 | P1 | Open | Execute native/browser accessibility and visual acceptance | QA/security verification lead | TalkBack/VoiceOver/keyboard/large text/reduced motion/contrast pass; exact current screenshots and design sign-off recorded. |
| QAT-09 | P1 | Open | Run game-day load, degraded-provider and recovery drills | QA/security verification lead | Measured latency, saturation, queue delay, failover and restoration meet approved SLOs; no financial duplicate effects. |
| QAT-10 | P1 | Open | Publish per-surface and per-club go/no-go dossier | QA/security verification lead | Evidence matrix states passed/failed/blocked/not-applicable with owners; no cumulative test-count or archive-presence substitute. |

### Operations and resilience

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| OPS-01 | P1 | Open | Approve traffic, latency, availability and cost budgets | SRE/operations lead | Game-day assumptions and business thresholds signed off; latency percentiles and financial-integrity targets defined per journey. |
| OPS-02 | P1 | In progress | Implement privacy-safe structured metrics and tracing | SRE/operations lead | Correlation IDs link requests/operations without secrets; OTP failures, allocation lag, unknown outcomes and tenant fairness visible. |
| OPS-03 | P1 | Open | Configure actionable alerts and human escalation | SRE/operations lead | Test alerts for overdue reconciliation, stale snapshots, auth/provider failures, high error rate, duplicate anomalies and storage limits. |
| OPS-04 | P1 | In progress | Implement queue retry, poison-event and DLQ operating policy | SRE/operations lead | Idempotent consumers, bounded retry/backoff, retention and approved re-drive paths tested with traceable owners. |
| OPS-05 | P1 | In progress | Create incident and financial exception runbooks | SRE/operations lead | Named responders can contain, diagnose and recover without deleting ledgers or guessing payment failure. |
| OPS-06 | P1 | Open | Approve RPO/RTO and prove restore procedures | SRE/operations lead | Database/object/config/key dependencies restored within measured targets; no reliance on Time Travel as complete object backup. |
| OPS-07 | P1 | In progress | Establish approved retention, export and erasure jobs | SRE/operations lead | Legal schedules applied to operational data, encrypted secrets, logs, exports and backups; deletion failures observable. |
| OPS-08 | P1 | In progress | Implement authoritative scheduling and notification routing | SRE/operations lead | One active owner per cron; timezone, missed-run catch-up, duplicates, tenant push tokens and provider receipts tested. |
| OPS-09 | P1 | Open | Budget and monitor cloud/provider/support unit costs | SRE/operations lead | Cost model includes D1 reads/writes, R2, Workers, messages, logs and human exception handling; alerts tested at agreed limits. |
| OPS-10 | P1 | Open | Complete operator training and support rehearsal | SRE/operations lead | Named club staff resolve login, renewal, refunds, ticket scans and uncertain payments using approved controls and escalation. |

### Legal, privacy and club approvals

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| REG-01 | P0 | Open | Map Rwanda storage/transfer obligations to actual architecture | Privacy/legal lead | Controller/processor roles, applicable registrations and valid foreign-storage authorization evidenced for DB/replicas/logs/backups/processors. |
| REG-02 | P1 | Open | Approve data map, notices, lawful grounds and retention | Privacy/legal lead | Personal-data processing inventory and processor contracts cover consent, rights, children, access requests, erasure and breach response. |
| REG-03 | P1 | Open | Complete Burundi legal and payment launch assessment | Privacy/legal lead | Qualified local assessment documents privacy/transfers, consumer terms, payment model and contest/age requirements or scope restrictions. |
| REG-04 | P1 | Open | Complete DR Congo legal and payment launch assessment | Privacy/legal lead | Qualified local assessment documents privacy/transfers, consumer terms, payment model and contest/age requirements or scope restrictions. |
| REG-05 | P1 | Open | Complete Zambia legal and payment launch assessment | Privacy/legal lead | Qualified local assessment documents privacy/transfers, consumer terms, payment model and contest/age requirements or scope restrictions. |
| REG-06 | P1 | Open | Approve all club commercial, price, currency and receiver records | Privacy/legal lead | Each country/club has authorized merchant identity, settlement ownership, unit rules, refund terms and carrier/payment routes. |
| REG-07 | P1 | Open | Complete Mozambique legal and payment launch assessment | Privacy/legal lead | Qualified local assessment plus Costa do Sol native IDs, crest/palette, receiver routes and tenant-1001 collision check completed. |
| REG-08 | P0 | Open | Resolve contest/reward and store-billing classification | Privacy/legal lead | Counsel/product record free versus paid entry, redemption, age and territories; each membership benefit classified physical/digital under current store rules. |
| REG-09 | P1 | Open | Approve white-label submission and brand ownership | Privacy/legal lead | Content-provider/developer-account responsibilities and per-club authorization documented; Apple 4.2.6 template and 4.3 duplicate sports-team variant risks assessed. |
| REG-10 | P1 | Open | Complete current store and public-policy submission package | Privacy/legal lead | Reviewer access, support, privacy/Data Safety, in-app/web deletion paths, age ratings, required SDK/target levels and regional billing rules verified at submission. |

### Controlled launch and retirement

| ID | Priority | Recorded status | Task | Owner role | Acceptance evidence |
| --- | --- | --- | --- | --- | --- |
| REL-01 | P0 | Open | Approve narrowly scoped staged rollout instead of big-bang release | Release manager | Public read-only, authenticated membership, financial products and club/platform expansions have separate acceptance gates and kill switches. |
| REL-02 | P1 | Open | Verify infrastructure-as-code and environmental isolation | Release manager | Approved accounts, regions, resource IDs, secrets, routes and principals read back; no placeholders or production test overrides. |
| REL-03 | P1 | Open | Release a read-only pilot only after its own gates pass | Release manager | Approved fresh source, rights, public read behavior, domain/security/operational checks and owner acceptance tied to exact artifact. |
| REL-04 | P1 | Open | Run supervised authenticated membership pilot | Release manager | Real isolated end-to-end sign-in/checkout/provider evidence/renewal/recovery and support checks succeed before real-money expansion. |
| REL-05 | P0 | Open | Rehearse single-writer cutover with versioned client admission | Release manager | Final consistent export/deltas, drained jobs, old-client policy, source freeze, reconciliation and target writer enablement executed in rehearsal. |
| REL-06 | P0 | Open | Rehearse rollback after target financial writes | Release manager | Document restore/forward-reconcile strategy; no traffic flip to stale source; customer obligations and original references preserved. |
| REL-07 | P1 | Open | Obtain named go/no-go approvals and staged store rollout | Release manager | Security, privacy, finance, product, QA, ops and club owners approve exact scope; percentages/observation windows chosen from evidence. |
| REL-08 | P1 | Open | Observe and reconcile the launch before expanding clubs | Release manager | Per-club errors, support demand, provider settlement and duplicate-prevention checks meet budgets; pause criteria enforced. |
| REL-09 | P1 | Open | Retire source services only after dependency and restore closure | Release manager | No remaining client/function/job/storage dependency; archives restorable; keys revoked; paid obligations and retention approvals complete. |
| REL-10 | P2 | Open | Maintain continuous post-launch assurance and policy watch | Release manager | Periodic access, dependency, privacy, store-policy, rights, disaster-recovery and cost reviews have accountable owners. |

## Current QA execution checks

The [maintained full-stack QA plan](full_stack_qa_plan.md) has 37 checklist items. Items 5, 11 and 16 have scoped local closure; the 34 items below remain unchecked. This checklist contains dated details, including older four-club/eight-artifact wording in items 22 and 23. Their current target is **five clubs and ten Android/iOS artifacts**. Apply the five-club scope amendment before deciding coverage. These checks expand or verify the 130 tasks above.

1. **QA-00 — Execution prerequisites:** Confirm stable disk capacity, pinned tools, isolated service health and required per-club build inputs before each resource-heavy run. Retain current source/configuration hashes. Official Flutter 3.44.9 now passes standard iOS builds; default recovered external simulator paths remain open with an owned internal-set workaround (QA-ENV-011). Current Home checkpoint recorded transient Docker timeouts, then resumed the exact owned services and verified four tenant configuration responses plus Auth health. No global reset or data loss; root cause remains unconfirmed.

2. **QA-01 — Complete case mapping:** Reconcile the consolidated 47 native rendered entries plus 15 compatibility redirects, 51 web destinations plus one compatibility redirect, with all components, overlays, states, roles, clubs, platforms and actual feature availability. Complete the coverage audit; resolve gaps in API/RPC/table/policy/storage/job coverage without inventing a final case count.

3. **QA-01/06 — Reference coverage:** Bind every applicable screen/state to a current Revolut comparator or justified adaptation; resolve missing platform/theme/state references and preserve club identity and workflows.

4. **QA-02 — Full current baseline:** Run the remaining complete Flutter/package/integration and supported Playwright project suites on the revised scope, measure coverage, refresh dependency/security checks and retain all failure/skip distinctions. Passing affected suites is not a full candidate pass. Earlier source-bound backend and web results are retained in the readiness report; no fresh full browser/SQL/Edge replay is claimed by this Home checkpoint. The subsequent Home layout checkpoint passes 2,332 tests (2,306 shared-package and 26 app tests), zero skips, and strict analysis on final shared UI source; 16 meaningful UI regression cases were added. Coverage is not remeasured.

6. **QA-03/08 — Payment evidence binding:** Complete receiver/payee, currency and provider-evidence checks in fallback matching; revalidate receiver changes and expiry after lock waits (QA-MONEY-007/008). Locked automatic/manual intent allocation and ticket/shop checkout revalidation pass, including receiver changes after waits. Paid membership binds provider, country and recipient to the checkout snapshot. Candidate matching now filters merchant, currency and expiry before ambiguity/limit checks (QA-MONEY-016). The previously probed server receipt handler stores null club/provider metadata and trusts client-submitted message text (QA-MONEY-019/020). These are backend/future management-gateway contract gaps, not supporter-app features. Define authenticated management-device/operator submission, server-bound club/merchant scope and replay-resistant receipt validation without restoring any mobile collector. Group/initiative/other fallback receiver changes and the trusted server receipt boundary remain open.

7. **QA-03/08 — Atomic financial posting:** Prove intent, ledger, reconciliation, target fulfillment and reward changes remain consistent under partial failure, concurrency and retry; prevent duplicate/out-of-order evidence and transaction reuse from allocating value twice. Generic allocation and commerce SQL contracts pass in the current full vendor replay. Paid membership activation, fulfillment reconciliation and exact-once renewal pass through real Auth/PostgREST and the actual parser with synthetic scoped receipts. Seven payment/parser routines now acquire the same raw-evidence mutex before row locks; eight added races cover a newly inserted review, allocation/rejection, parser claim/persistence, commerce and direct parser foreign-key inserts (QA-MONEY-021). Current complete database total is 45 races. Other generic-intent linked fulfillment and group/initiative posting atomicity remain open.

8. **QA-03/07/08 — Interrupted processing:** Exercise crash/response-loss/stalled-parser recovery and durable notification outcomes after a committed transaction. Recovery must neither lose a valid posting nor duplicate it. Historical current-source-bound intent/commerce handler and process-termination checks remain recorded. Current vendor replay reruns parser claim and takeover races; actual membership handler recovery now passes after a committed response is lost and the merchant is rotated/inactivated, with no extra AI interpretation, debit or renewal (QA-MONEY-017). Recovery after saved interpretations/partial business writes outside verified receipts and durable notification delivery remain open.

9. **QA-03/04/05 — Identity lifecycle:** Complete guest/club entry, OTP invalid/expired/resend/rate-limit behavior, restore/refresh/expiry, logout/account switch, role removal, private data access/export/deletion and concurrent profile/phone edits through actual clients.

10. **QA-04/05 — Member lifecycle:** Complete paid-tier selection, authoritative MoMo payment preparation, automatic matched-payment activation/renewal and fan-club/community permissions. The retired application/manual-review/free-tier workflow must remain inaccessible. Current full-schema SQL and actual Auth/REST/parser checks cover paid checkout, server amount and route, provider/recipient binding, automatic activation, exact-once renewal, retained tier/points, receiver-rotation recovery and preserved administrative suspension (QA-MONEY-018). Payment-success cases use directly seeded scoped synthetic receipts. Complete client journeys using server-confirmed payments, contribution intents, statements and totals for all retained clubs. Any message capture is owned by the separate management gateway.

12. **QA-03/04/05 — Predict/FET:** Complete eligible/ineligible entry, balances/history, result correction, settlement retry, void and no-winner outcomes. Preserve the existing passing duplicate-entry, overspend and kickoff races.

13. **QA-03/04/05 — Tickets/Wallet:** Complete price/capacity and pending/failed/unknown/confirmed purchase outcomes, issue/cancel/refund where implemented, ownership and expiry, Wallet availability/save flow and outbox recovery. Preserve the passing migration/issuance contracts.

14. **QA-03/04/05 — Shop:** Complete stock/price authority, stale cart review, last-item races, payment uncertainty, reservation expiry, fulfillment/cancellation/refund and concurrent transition correctness.

15. **QA-05 — Public websites:** Exercise all 23 public page templates and configured retained-club hosts/identities, content discovery, search, SEO, privacy/support and app/deep links across supported responsive browsers. Current scope includes four-club support/deletion/share identity and tenant-specific root/page metadata/JSON-LD, verified by 48 browser cases. Unconfigured club domains do not inherit Rayon canonicals.

17. **QA-05 — Admin operations:** Complete every retained module and role, actual cross-club API writes/readback, search/filter/sort/pagination, detail-return state, save conflicts, destructive review, bulk partial failure and audit actor/reason/time checks.

18. **QA-05/06 — Admin responsive controls:** Finish current-candidate checks for identity/brand/palette/flag controls, text enlargement, keyboard/focus, table density and existing dialog/hydration regressions across supported browsers.

19. **QA-03 — API/backend integration:** Extend real application transport coverage for endpoint methods, authorization/tenant boundaries, invalid input, 401/403/404/409/429/5xx, timeout and retry outcomes. Assert UI and persisted state together. Fifteen current real Auth/PostgREST/Edge membership checks pass, including anonymous/foreign-club rejection, denied supporter snapshot writes and committed-response recovery. The historical server SMS-handler probe exposes an open gateway/server receipt boundary; it neither represents a supporter-app feature nor proves an end-to-end live payment.

20. **QA-03/07 — Storage/realtime/jobs:** Complete upload type/size/path access, private storage boundaries, cross-account realtime subscriptions and reconnect catch-up, scheduled-job overlap/retries and stale-data behavior. Current scope: actual isolated WebSocket/Flutter-controller recovery passes for both published public match sources. Thirteen real Storage API checks and nine upload-handler/Auth/Storage outcomes verify type/size/path/RLS/tenant/role-removal behavior. Private subscriptions and remaining job behavior remain open; no private bucket is configured.

21. **QA-03/07 — Integration failure handling:** Exercise all applicable auth-hook, server receipt, notification, football-feed, image-generation and Wallet integration boundaries using approved substitutes/sinks. Verify signatures, authorization, invalid tokens, deduplication, failure/retry and review-before-publication behavior. The earlier server-handler probe confirms missing trusted tenant/provider context and an undefined receipt trust boundary. Specify the separate management-gateway/server contract and local negative regressions; supporter-app collection is excluded. No external provider was contacted in the isolated payment runs.

22. **QA-04 — Native prerequisites:** Resolve actual release inputs for the four clubs. Current local checks find Firebase configuration files and bundled iOS app-icon PNGs absent for Vital'O, Nkana and AS Vita. Verify intended integrations, registered identities and real build inputs; absence does not by itself prove a boot crash.

23. **QA-04 — Eight native builds/boots:** Build, install and launch each retained club on both Android and iOS. Verify icons, IDs, tenant/currency, feature flags, capabilities, deep links, bootstrap/backend behavior and actual iOS SwiftPM/CocoaPods resolution. After the Home fixes, all eight main-entrypoint debug artifacts are rebuilt, installed, launched and read back again; current evidence is home-layout-20260923/report.json. This is not signing, full-journey or store acceptance.

24. **QA-04 — Remaining native journeys:** Execute the remaining repaired screenshot/integration journeys, capture iOS separately and expand beyond the earlier synthetic Rayon Club pilot to the complete supporter workflow. Current Home checkpoint passes five Home/auth/settings/deep-link/recovery cases and one Club/squad/player/history case on each platform (12 native case executions), with 20 system captures. These use synthetic repositories/auth; all-club authenticated and provider journeys remain open.

25. **QA-05/07 — PWA lifecycle:** Verify tab versus installed mode, offline launch/reconnect, session expiry/logout, storage denial/quota, draft preservation during update, old tabs and supported version recovery. Confirm safe treatment of legacy queued mutations and obtain supported Safari/Firefox worker evidence. Current scope: six browser profiles pass real worker origin-loss/reconnect, private membership-cache exclusion, preference storage denial, explicit update cancellation and older-tab draft preservation. Workers retain legacy mutations without replay. Installed mode, durable saved drafts, account expiry across all lifecycle states and arbitrary mixed-version compatibility remain open.

26. **QA-06 — Visual acceptance:** Complete matched source/target comparisons for geometry, type, full color roles, density, imagery, copy, controls and overlays on all applicable surfaces. Update evidence without treating widget golden equality as source-fidelity approval. Owner approval from 20 September remains bound to the original gallery/image hashes; exact source fidelity and independent technical acceptance remain separate. Home checkpoint closes QA-UI-004/005/006 locally. Eight new Home images and nine reviewed Membership heading changes bring the register to 1,062 (766 route images and 296 shared variants). Current images do not inherit prior owner approval.

27. **QA-06 — Accessibility/usability:** Complete keyboard and human screen-reader tasks, contrast/focus/touch targets, compact reflow, article/header control clearance, 200% text/applicable 400% zoom, large native text, reduced motion, themes, permissions and supported orientations. Record actual task outcomes. New checks cover compact control geometry, News reflow at 200/300 percent, and a protected native status inset while scrolling. Android/iOS Home fixtures pass at 200 percent. Human reader, physical-device and remaining screen/state checks remain open.

28. **QA-07 — Performance:** Measure native cold/warm start, frames, memory and representative operations; web Lighthouse/admin-volume/route behavior; and current database plans/policies/index warnings. Keep existing bundle budgets; old advisor counts need regeneration after schema changes. Current scope: bundle and admin-volume budgets pass. Current cold-cache Lighthouse audit passes eight of nine runs; first Home performance is 0.89 against 0.90. All failures are retained. Native performance, representative database plans and all-route performance remain open.

29. **QA-07 — Resilience/operations:** Exercise process death, background/foreground interruption, network loss, timeout before submission/after commit, provider failure and unchanged-input retry. Verify bounded logs/alerts, queue/dead-letter handling, operational recovery and release rollback compatibility.

30. **QA-08 — Findings closure:** Repair remaining reproduced defects, retest affected shared code and all materially different club variants, and link each closure to reproduction, fix, regression and current evidence. Preserve scoped historical closures and excluded-product findings as such. Earlier source-bound payment, mobile-collector-removal and toolchain closures remain recorded; gateway/server trust findings QA-MONEY-019/020 and other actionable QA remain open. Home findings QA-UI-004/005/006 now have retained reproductions, shared-code fixes, final unit tests and Android/iOS capture evidence. This does not close the findings task as a whole.

31. **QA-09 — Final candidate verification:** Run required final checks, regenerate source/configuration/artifact hashes and current screenshots/traces, reconcile every applicable case and publish the final per-surface readiness decision with separate quality results. Home checkpoint records final source/component/artifact hashes, eight rebuilt main artifacts and separate native fixture evidence; final whole-system candidate acceptance remains open.

32. **Hosted CI:** Recheck the previously recorded GitHub account billing/spending blocker, resolve it through the account owner if still present, and obtain actual hosted QA results without accidentally triggering deployment. The retirement commit intentionally skipped CI. Read-only GitHub refresh on 20 September confirms the latest recorded run remains startup_failure with zero check runs; the earlier billing explanation is not re-proven.

33. **Physical devices:** Complete real Android/iPhone installation, package readback, native permission/hardware behavior, accessibility, performance and interruption/recovery evidence for the release matrix.

34. **Providers:** Validate approved WhatsApp OTP, server payment evidence, push delivery, feeds and Google Wallet issuer/account/cron behavior against real authorized provider environments. Current payment tests substitute AI and directly seed trusted scope. The separate future management gateway needs an agreed authenticated sender/device and server receipt contract; the five supporter apps do not read or upload messages. Existing server-handler probes do not prove provider authenticity. Validate applicable real-provider boundaries separately after the contract is implemented. Local substitutes do not close this gate.

35. **Revolut design review:** Inspect rendered routes and states across all five clubs on Android/iOS, public and member websites, and admin/PWA against the selected skill. Fix observed visual differences, retain current comparison evidence, and record actual implementer, independent reviewer and owner decisions separately. Visual fidelity remains unverified. A bounded same-author read-only code review and selected native/golden inspection are recorded in home-layout-20260923/implementation-review.json. Independent reviewer and current artifact owner acceptance remain unverified.

36. **Signing and distribution:** Verify final Android/iOS signing identities, release configuration, store metadata/privacy inputs, signed artifacts and install behavior; store review/public availability remain separate.

37. **Production operations:** When explicitly authorized, apply the prepared migrations and release/decommissioning changes, validate hosted Cloudflare/Supabase/domains and confirm public availability and recovery. No production operation is authorized by this checklist.

## Final release evidence

The exact candidate must pass the [Rayon Sports release checklist](../rayon_sports_release_checklist.md), receive current per-club and per-surface QA decisions, pass signed physical Android/iOS and hosted web/provider checks, and fill every required gate and named approval in the [sign-off form](football_platform_release_signoff.md). A staged rollout requires tested backup/restore and financial rollback, monitoring/alerts, store submission receipts and post-launch reconciliation. No earlier package report, checksum pass or four-club screenshot set substitutes for those results.

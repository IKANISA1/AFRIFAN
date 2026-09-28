# AFRICLUB — all remaining release tasks

28 September 2026 · Implementation06 ·130 tasks ·36 In progress ·94 Open ·0 release-accepted/Closed.

Statuses reflect scoped implementation, not production completion. Acceptance criteria, dependencies and owner roles remain unchanged. Named owners/approval evidence are still required.

## Security containment

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| SEC-01 | P0 | Open | Restrict public-link write/read permissions | Security lead |
| SEC-02 | P0 | Open | Preserve and review Drive/Git/provider audit history | Security lead |
| SEC-03 | P0 | Open | Inventory sensitive artifact exposure without broadcasting values | Security lead |
| SEC-04 | P0 | Open | Rotate exposed live backend/provider secrets where confirmed | Security lead |
| SEC-05 | P0 | Open | Review Android upload/signing credentials and reset affected key | Security lead |
| SEC-06 | P0 | Open | Restrict production backups and personal-data exports | Security lead |
| SEC-07 | P1 | In progress | Scan candidate, Git history, bundles and archives for secrets | Security lead |
| SEC-08 | P1 | In progress | Define redaction and evidence-publication policy | Security lead |
| SEC-09 | P1 | Open | Require phishing-resistant MFA and privileged access review | Security lead |
| SEC-10 | P1 | Open | Harden build and deployment credentials | Security lead |

## Source convergence

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| REP-01 | P0 | In progress | Establish one protected canonical candidate commit | Repository maintainer |
| REP-02 | P0 | In progress | Reconcile every batch payload with current paths and hashes | Repository maintainer |
| REP-03 | P0 | In progress | Promote approved fixes without downgrading newer code | Repository maintainer |
| REP-04 | P0 | In progress | Repair boundary validator and real-source exception handling | Repository maintainer |
| REP-05 | P1 | Open | Separate source, generated output and archival evidence | Repository maintainer |
| REP-06 | P1 | In progress | Create source-to-build-to-deployment manifest | Repository maintainer |
| REP-07 | P1 | In progress | Register all current backend/native verification commands | Repository maintainer |
| REP-08 | P1 | In progress | Install/reconcile iOS recovery source into the candidate | Repository maintainer |
| REP-09 | P1 | In progress | Pin and reproduce supported toolchains and dependency locks | Repository maintainer |
| REP-10 | P1 | In progress | Normalize governance hierarchy and task identifiers | Repository maintainer |

## Architecture and boundaries

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| ARC-01 | P0 | Open | Approve data-store boundaries and single-writer topology | Technical architect |
| ARC-02 | P0 | Open | Benchmark actual D1 transaction and trigger behavior | Technical architect |
| ARC-03 | P0 | Open | Define revocation semantics by operation | Technical architect |
| ARC-04 | P1 | Open | Reassess custom authentication operational burden | Technical architect |
| ARC-05 | P1 | In progress | Version all service and public client contracts | Technical architect |
| ARC-06 | P1 | Open | Centralize immutable club/slug/partner mapping | Technical architect |
| ARC-07 | P0 | Open | Preserve one global consumed-payment-reference authority | Technical architect |
| ARC-08 | P1 | Open | Approve currency units, rounding, timezone and period rules | Technical architect |
| ARC-09 | P1 | In progress | Minimize service capabilities and external attack surface | Technical architect |
| ARC-10 | P1 | Open | Measure game-day capacity and choose scaling boundaries | Technical architect |

## Data migration and integrity

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| DAT-01 | P0 | Open | Refresh complete source-object and runtime-caller inventory | Data migration lead |
| DAT-02 | P0 | Open | Reconcile local versus deployed function behavior | Data migration lead |
| DAT-03 | P0 | Open | Create isolated migration environments with approved locality | Data migration lead |
| DAT-04 | P0 | Open | Produce a transactionally consistent final export strategy | Data migration lead |
| DAT-05 | P0 | Open | Reconcile complete historical payment reference claims | Data migration lead |
| DAT-06 | P0 | In progress | Map data types and financial balances with exception reports | Data migration lead |
| DAT-07 | P0 | Open | Recover and verify the eight unresolved AFRICLUB media originals | Data migration lead |
| DAT-08 | P1 | Open | Keep the separate Gikundiro public dataset provenance distinct | Data migration lead |
| DAT-09 | P0 | Open | Restore complete database and object backups in isolation | Data migration lead |
| DAT-10 | P1 | In progress | Implement repeatable migration reconciliation and delta checks | Data migration lead |

## Identity and authorization

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| AUT-01 | P0 | Open | Threat-model identity and tenant trust boundaries | Identity lead |
| AUT-02 | P1 | In progress | Replace pilot OTP limits with fair measured controls | Identity lead |
| AUT-03 | P1 | Open | Complete lost-phone, phone-change and account-linking flows | Identity lead |
| AUT-04 | P1 | Open | Complete protected native credential storage and refresh coordination | Identity lead |
| AUT-05 | P1 | In progress | Implement browser authentication and CSRF contract | Identity lead |
| AUT-06 | P0 | Open | Enforce tested revocation/fencing for sensitive domain commands | Identity lead |
| AUT-07 | P1 | Open | Implement complete account erasure orchestration | Identity lead |
| AUT-08 | P1 | Open | Reconcile existing identity and profile bootstrap | Identity lead |
| AUT-09 | P1 | Open | Implement custom-auth key rotation and incident recovery | Identity lead |
| AUT-10 | P1 | Open | Run live isolated identity/provider acceptance | Identity lead |

## Payments and fulfillment

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| PAY-01 | P0 | Open | Integrate authenticated payment evidence and account reconciliation | Payments lead |
| PAY-02 | P0 | In progress | Implement late, partial, duplicate and ambiguous payment exceptions | Payments lead |
| PAY-03 | P0 | Open | Implement refunds, reversals and administrative corrections | Payments lead |
| PAY-04 | P1 | In progress | Complete current membership entitlement and receipt separation | Payments lead |
| PAY-05 | P1 | Open | Complete initiative contributions including totals/rewards/referrals | Payments lead |
| PAY-06 | P1 | Open | Complete supporter-group contributions and statements | Payments lead |
| PAY-07 | P1 | Open | Complete ticket inventory, issuance, transfer and redemption | Payments lead |
| PAY-08 | P1 | Open | Complete shop inventory, ordering and fulfillment | Payments lead |
| PAY-09 | P1 | Open | Implement idempotent outbox consumers and dead-letter handling | Payments lead |
| PAY-10 | P0 | Open | Prove end-to-end financial conservation and cutover parity | Payments lead |

## Native app completion

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| MOB-01 | P1 | Open | Compile and test actual Android recovery host | Mobile lead |
| MOB-02 | P1 | Open | Compile and test actual iOS recovery host | Mobile lead |
| MOB-03 | P1 | Open | Run pure Dart and Flutter analysis and authored harnesses | Mobile lead |
| MOB-04 | P1 | Open | Register shared adapters in all five governed app compositions | Mobile lead |
| MOB-05 | P1 | Open | Build accessible review, confirm and recovery screens | Mobile lead |
| MOB-06 | P0 | In progress | Implement server-authoritative lost-state and unresolved-attempt recovery | Mobile lead |
| MOB-07 | P1 | In progress | Wire lifecycle, logout, account-switch and route guards | Mobile lead |
| MOB-08 | P1 | Open | Validate USSD handoff on approved carriers and SIM scenarios | Mobile lead |
| MOB-09 | P1 | Open | Verify merged native privacy/link/notification configuration | Mobile lead |
| MOB-10 | P1 | Open | Execute ten signed club/platform release journeys | Mobile lead |

## Public web and administration

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| WEB-01 | P0 | In progress | Install active-snapshot publication/read integration | Web/admin lead |
| WEB-02 | P1 | In progress | Implement media digest, rights revocation and cache policy | Web/admin lead |
| WEB-03 | P1 | In progress | Define browser member portal boundaries and session contract | Web/admin lead |
| WEB-04 | P1 | In progress | Connect browser membership/contribution flows to approved APIs | Web/admin lead |
| WEB-05 | P1 | In progress | Reconcile and wire operator console configuration and wrapper | Web/admin lead |
| WEB-06 | P1 | In progress | Complete role-scoped admin actions and maker/checker where required | Web/admin lead |
| WEB-07 | P1 | In progress | Harden PWA caches, offline states and logout cleanup | Web/admin lead |
| WEB-08 | P1 | In progress | Replace permissive CSP and broad origins with reviewed policy | Web/admin lead |
| WEB-09 | P1 | Open | Validate domains, SEO and link metadata per club | Web/admin lead |
| WEB-10 | P1 | Open | Complete real desktop/mobile-browser and operator UAT | Web/admin lead |

## Product, content and design

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| PRD-01 | P0 | Open | Approve one Predict/FET economic contract | Product/design lead |
| PRD-02 | P1 | Open | Complete authoritative fixture/result lifecycle | Product/design lead |
| PRD-03 | P1 | Open | Approve source/media/brand rights with expiry and scope | Product/design lead |
| PRD-04 | P1 | Open | Reconcile design authority and reusable semantic tokens | Product/design lead |
| PRD-05 | P1 | Open | Define complete state and accessibility matrix | Product/design lead |
| PRD-06 | P1 | Open | Populate current route/state and artifact-evidence registries | Product/design lead |
| PRD-07 | P1 | Open | Resolve market-language and translation policy explicitly | Product/design lead |
| PRD-08 | P1 | Open | Complete onboarding, consent, help and support journeys | Product/design lead |
| PRD-09 | P1 | Open | Verify runtime flags and deep-link authorization everywhere | Product/design lead |
| PRD-10 | P2 | Open | Validate product analytics and club success measures | Product/design lead |

## Verification and assurance

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| QAT-01 | P0 | In progress | Bind release checks to immutable candidate artifacts | QA/security verification lead |
| QAT-02 | P1 | Open | Run complete pinned-toolchain workspace and web checks | QA/security verification lead |
| QAT-03 | P1 | Open | Run local replay plus real isolated D1/Workers contract tests | QA/security verification lead |
| QAT-04 | P1 | In progress | Create positive and negative multi-tenant acceptance suite | QA/security verification lead |
| QAT-05 | P1 | Open | Commission independent API/web/mobile security verification | QA/security verification lead |
| QAT-06 | P1 | Open | Test financial concurrency and failure recovery on actual target | QA/security verification lead |
| QAT-07 | P1 | Open | Run dependency, SBOM, license and supply-chain review | QA/security verification lead |
| QAT-08 | P1 | Open | Execute native/browser accessibility and visual acceptance | QA/security verification lead |
| QAT-09 | P1 | Open | Run game-day load, degraded-provider and recovery drills | QA/security verification lead |
| QAT-10 | P1 | Open | Publish per-surface and per-club go/no-go dossier | QA/security verification lead |

## Operations and resilience

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| OPS-01 | P1 | Open | Approve traffic, latency, availability and cost budgets | SRE/operations lead |
| OPS-02 | P1 | In progress | Implement privacy-safe structured metrics and tracing | SRE/operations lead |
| OPS-03 | P1 | Open | Configure actionable alerts and human escalation | SRE/operations lead |
| OPS-04 | P1 | In progress | Implement queue retry, poison-event and DLQ operating policy | SRE/operations lead |
| OPS-05 | P1 | In progress | Create incident and financial exception runbooks | SRE/operations lead |
| OPS-06 | P1 | Open | Approve RPO/RTO and prove restore procedures | SRE/operations lead |
| OPS-07 | P1 | In progress | Establish approved retention, export and erasure jobs | SRE/operations lead |
| OPS-08 | P1 | In progress | Implement authoritative scheduling and notification routing | SRE/operations lead |
| OPS-09 | P1 | Open | Budget and monitor cloud/provider/support unit costs | SRE/operations lead |
| OPS-10 | P1 | Open | Complete operator training and support rehearsal | SRE/operations lead |

## Legal, privacy and club approvals

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| REG-01 | P0 | Open | Map Rwanda storage/transfer obligations to actual architecture | Privacy/legal lead |
| REG-02 | P1 | Open | Approve data map, notices, lawful grounds and retention | Privacy/legal lead |
| REG-03 | P1 | Open | Complete Burundi legal and payment launch assessment | Privacy/legal lead |
| REG-04 | P1 | Open | Complete DR Congo legal and payment launch assessment | Privacy/legal lead |
| REG-05 | P1 | Open | Complete Zambia legal and payment launch assessment | Privacy/legal lead |
| REG-06 | P1 | Open | Approve all club commercial, price, currency and receiver records | Privacy/legal lead |
| REG-07 | P1 | Open | Complete Mozambique legal and payment launch assessment | Privacy/legal lead |
| REG-08 | P0 | Open | Resolve contest/reward and store-billing classification | Privacy/legal lead |
| REG-09 | P1 | Open | Approve white-label submission and brand ownership | Privacy/legal lead |
| REG-10 | P1 | Open | Complete current store and public-policy submission package | Privacy/legal lead |

## Controlled launch and retirement

| ID | Priority | Status | Task | Owner role |
|---|---|---|---|---|
| REL-01 | P0 | Open | Approve narrowly scoped staged rollout instead of big-bang release | Release manager |
| REL-02 | P1 | Open | Verify infrastructure-as-code and environmental isolation | Release manager |
| REL-03 | P1 | Open | Release a read-only pilot only after its own gates pass | Release manager |
| REL-04 | P1 | Open | Run supervised authenticated membership pilot | Release manager |
| REL-05 | P0 | Open | Rehearse single-writer cutover with versioned client admission | Release manager |
| REL-06 | P0 | Open | Rehearse rollback after target financial writes | Release manager |
| REL-07 | P1 | Open | Obtain named go/no-go approvals and staged store rollout | Release manager |
| REL-08 | P1 | Open | Observe and reconcile the launch before expanding clubs | Release manager |
| REL-09 | P1 | Open | Retire source services only after dependency and restore closure | Release manager |
| REL-10 | P2 | Open | Maintain continuous post-launch assurance and policy watch | Release manager |

## Implementation06 contribution

**SEC-01** — Fresh Drive folder metadata still shows anyone/writer. Available sharing action grants access, not revocation; no ACL/credential change performed. Canonical-source trust remains open.

**SEC-07** — Limited path/pattern scan covers all 384 scoped source files with no flagged findings. Full Drive/Git/archive and independent secret review remain outstanding.

**SEC-08** — Portal state excludes phone/OTP/CSRF/cookies, private pages use cache isolation and operational local records remain explicitly private. Approved retention/redaction and shared-device policy are not complete.

**REP-02** — Matched Implementation05 archive and all451 checksums, retrieved four exact Next/SW source prerequisites.32 authored changes preserve unknown edits; not a full source convergence.

**REP-03** — Guarded delta installer retains exact before hashes, unchanged prerequisites and rollback. Original Drive source is not overwritten or canonically merged.

**REP-07** — Registered web router and service-worker suites plus disabled-router config in the main pinned verifier. Full pinned application build remains blocked.

**ARC-05** — Browser-v1 contract has13 routes, including the authenticated bounded offers projection. Existing hyphenated tier identifiers remain supported; real target-runtime compatibility is unverified.

**ARC-09** — Outer router uses original-request HTTP service binding to the browser API and separate Next binding without database/payment-provider capability. Live binding/context and origin isolation need acceptance.

**AUT-05** — Actual Next membership route uses cookie-v1 client/controller when explicitly enabled; session loss/expiry/rotation/logout handled without native bearer exposure. Rendered browser and real cookie acceptance remain pending.

**PAY-04** — New portal shows current observed entitlement separately from owned historical receipts, and locally downgrades expiry. Full financial acceptance and native composition remain open.

**WEB-03** — Preserved old membership surface under explicit legacy/default mode; enabled cookie-v1 misconfiguration fails closed. Authenticated membership route is source-integrated; contribution API/flow still outstanding.

**WEB-04** — Wired Next membership page, real browser client, offers, preparation review, last-order persistence and original-result recovery. Pure TS/gateway integration tests pass; pinned Next/rendered E2E acceptance absent.

**WEB-07** — Fixed actual periodic service-worker membership caching path; private requests network-only, owned page/API cache handshake/purge, offline/BFCache/cross-tab concealment and no mutation replay. VM tests pass; real SW lifecycle/retention/shared-device acceptance pending.

**WEB-08** — Added private Next response headers and exact-origin outer router with sanitized forwarded host. API private headers preserved; whole-site CSP, live network policy and legacy paths are not certified.

**QAT-04** — 96 new Node cases cover actual controller/client/gateway, offer validation, same-origin routing, malformed scope and cache isolation; real multi-tenant browser/Workers/device acceptance remains open.

**QAT-02** — Manual Node bank passes on22.16.0 but required22.23.2 is preserved; Dart/Flutter and full Next dependencies absent. Main verifier reports blocked; no claim of complete pinned workspace validation.


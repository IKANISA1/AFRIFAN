# AFRICLUB — Batch 8 membership checkout and frozen orders

Date: 26 September 2026. Source authority: the current AFRICLUB Drive workspace and
the source membership-checkout migration, with the checked Batch 7 allocation core.
This is a narrow incremental extension, not an older cumulative-source downgrade.

## 1. Actual completion and Drive state

**All 22 source changes are installed in their correct Google Drive paths:**
21 additions and one in-place README update. The README retains Drive ID
`11c2iijJkMgVqUIhC9JivYi8vxb5prAsr`. Its original bytes were checked again immediately
before replacement and a pre-change source archive was uploaded and hash-verified.
No original allocation runtime, applied migration, existing client or economic
policy file was changed. All 22 source downloads matched the exact tested SHA-256
values. A reconstructed checkout using those downloaded files reports zero changes
and all 22 entries already matching.

The complete incremental package passed **465 targeted tests: 202 preserved payment
module tests, 230 new checkout/client/contract tests and 33 installer regressions**.
The downloaded source independently passed all 432 code tests. Repeated executions
are not added to the count. Seventeen syntax/JSON checks, strict TypeScript client
compilation and both disabled-configuration checks also passed.

No remote SQL migration, resource provision, catalog or real identity import, grant
enrollment, provider call, message, payment, membership activation, client release,
financial-writer switch or Supabase retirement occurred. The new runtime and database
controls remain disabled. Uploading SQL source does not apply its migration.

## 2. Implemented workflow

| Component | Implemented behavior |
| --- | --- |
| Private checkout preparation | Fixed service principal and securely caller-derived club/user; exact request grammar accepts only request ID, club, user and tier. No client-selected amount, route, package, recipient, currency or provider. |
| Server-owned catalog selection | First active package by sort/ID, annual-price preference, valid whole amount, current country/currency, first active route with a strict unique matching receiver. Unsafe/ambiguous routing fails rather than guessing another price. |
| Frozen order and USSD instructions | Captures order/intent/package/owner/club, amount/currency/provider/recipient and exact dialer string with a 24-hour deadline. The code does not invoke a handset or transfer money. |
| Atomic reuse or replacement | Reuses a matching unexpired pending generated snapshot. Otherwise cancels only the same owner/club's pending membership orders and inserts the new order/details/result/audit in one triggered database statement inside a batch. All changes roll back together. |
| Original-result recovery | Exact-key retries return the original result under current authority, even after configuration change or expiry. Different arguments under the same key conflict. Lost responses cannot cause a second checkout under that key. |
| Current-status reader | Distinguishes pending_current, expired, cancelled, allocated and configuration_changed. Historical checkout instructions are separate from current presentation/payment-allocation flags. |
| Mutation-time controls | Rechecks service/grant/user/club/catalog revisions, expiry and source-history gates at commit. Revocation/re-enable and concurrent catalog changes cannot silently authorize a stale pending operation in the covered cases. |
| Catalog planning | Hash-checked, bounded, duplicate-aware, parameterized INSERT-only private plans; all imported catalog rows disabled and no grants enabled. No SQL or network execution by the planner. |
| Typed integration and contract | Strictly compiled trusted-server TypeScript adapter, exact-field private RPC contract, bounded waits and no automatic write retry. Unknown prepare outcomes retain the original operation key. |
| Deployment source | Separate named prepare/read entrypoints, hidden HTTP, disabled config and validation requiring the same isolated allocation database/account and distinct principals. |

Checkout alone produces **no membership, allocated-debit ledger, payment receipt,
external-reference claim or payment outbox event**. The unchanged allocator handles
the later trusted evidence and membership fulfillment. Integration tests exercise
checkout -> evidence ingestion -> allocation and preserve administrative suspension,
existing membership identity and one renewal per allocated payment.

## 3. Source preservation and explicit adaptations

The retrieved `prepare_membership_payment` implementation in
`20260920165540_membership_payment_evidence_binding.sql` is the source for package
ordering, price preference, country/receiver/USSD selection, reuse and same-owner
replacement with 24-hour expiry. The companion source map separates these rules
from new controls; the PostgreSQL file remains untouched.

The new private primitive does not reproduce PostgreSQL auth.uid(). Its caller must
independently authenticate the human and derive userId/clubId. Service-role access
and the local enabled-subject table do not complete supporter-session revocation
across databases. Binding this service directly to untrusted request fields is not
an acceptable client integration.

Stricter adaptations include exact receiver club/provider/currency matching,
required amount and recipient placeholders, safe bounded USSD grammar, explicit
route/dialer snapshot identity and durable operation keys. Historic pending orders
without the new reconciled detail/package binding are not guessed as reusable.
A valid new preparation cancels such pending membership orders under the source
replacement rule. Existing inconsistent historical duplicates still require source
reconciliation: a reused matching order does not repair unrelated old pending rows.

Cancellation preserves the order and its original evidence; it is not a refund or
permission to reuse a provider transaction. Payments arriving for a cancelled or
expired checkout require a separate governed exception workflow. Contribution
orders, totals, rewards/referrals, prediction economics and ticket/shop behavior
are not changed by this batch.

Twenty new requests per club/user over a rolling fifteen-minute window is a pilot
abuse-control choice, not a source commercial rule or approved production quota.
Exact stored retries do not create another request record. Safe production
capacity, mobile-network fairness, upstream throttling and retention still need
measurement and approval.

## 4. Historical response versus current state

The frozen checkout carries `paymentVerified: false` and
`membershipActivated: false` as statements about checkout preparation. A later
allocation does not rewrite that historical snapshot. The separate read response
reports `paymentEvidenceAllocated: true` only when the order is allocated, and
`mayPresentPaymentInstruction: true` only for pending_current. Reads are point-in-time
observations, not irrevocable reservations; allocation independently checks current
evidence, receiver, state and expiry.

A caller must persist its operation key before prepare and explicitly retry the
same request after an unknown outcome. The reference adapter does not store keys,
credentials or tokens; does not dial USSD; does not retry writes automatically;
and is not installed into Flutter, Next.js or an admin PWA. A selected tier or an
existing checkout does not attest external payment settlement.

## 5. Executed verification

| Test group | Passing tests |
| --- | ---: |
| Preserved current payment allocation, evidence, authorization, import and outbox tests | 202 |
| New checkout core, catalog, authority, concurrency, tooling, client and contract tests | 230 |
| Reused source installer and rollback regressions | 33 |
| **Total in the assembled package** | **465** |

Final failures and skips were zero. The 432 code tests ran again against all
22 downloaded source replacements and passed. Strict client compilation is real
TypeScript compilation; bounded field-contract checks are not represented as a
complete general JSON Schema/OpenAPI certification.

Coverage includes price preference and rejection, unsafe templates, ambiguous
receivers, wrong-club/wrong-owner access, separate capabilities, expired/revoked
controls, catalog races, same/different request IDs, exact original-result recovery,
stale-current-state detection, immutable history, retry budgets, later allocation,
suspension preservation and faults during every preparation effect. Injected
failures restore previously cancelled pending orders and roll back new details,
results and audit records.

**Four new scenarios use separate Node threads and independent SQLite connections**
against one disposable database: duplicate key; distinct keys for the same offer;
competing tiers; and checkout replacement competing with old-order allocation.
The final states are coherent: one shared pending order for matching preparations;
one pending generated order after competing tiers; an old order is either allocated
with one membership effect or cancelled without that effect, never both. The prior
three allocation concurrency cases also ran as part of the preserved suite.

An earlier expanded test expected a specific offer-change error for an injected
mid-trigger catalog mutation. The database correctly rolled back with an incomplete-
result guard mapped to checkout_unavailable; the test expectation was corrected.
Initial evidence is kept separate from the final passing logs. No retention or
security rule was relaxed to make that assertion pass.

Environment: Node 22.16.0, Python 3.13.5, TypeScript 5.8.3, SQLite 3.49.1 and genuine
local cryptography. Database time and identities are synthetic; most tests emulate
the D1 binding/batch while executing real SQL/triggers. The inherited raw SQL
capability probe runs without clock substitution. WorkerEntrypoint wrappers were
syntax-checked, not run under workerd. No real D1/provider/handset, full Flutter/
Next.js/pgTAP, browser, signed-app or production performance test occurred. Higher
repository SDK requirements are unchanged. No browser policy was changed.

## 6. Incremental installation and rollback

The exact package passed preflight, application, after-hash checks, idempotent
reapplication and starting-byte restoration in three disposable reconstructions:

| Starting state | Files changed | Rollback result |
| --- | ---: | --- |
| Current scoped baseline, no Batch 8 changes | 22 | Original README and every starting byte restored. |
| Half of Batch 8 already matching | 11 | Existing matching additions/README version retained. |
| All Batch 8 changes already matching | 0 | No source mutation. |

The source reconstruction populated with actual Drive downloads reports **zero
outstanding changes, 22 already matching**. These trials do not execute migrations,
change roles, send messages, pay anyone or deploy. Unknown source edits stop the
installer. Individual writes are atomic; stop builds and editors during a multi-file
operation because the whole directory operation is not one atomic transaction.

The pre-change archive contains 30 scoped files: the prior 22-file module plus
seven reference migrations and the workspace manifest. Critical current runtime/
schema/README and the checkout source migration were freshly read and compared;
other unchanged context is preserved from the checksum-verified Batch 7 package.
This is not a fresh complete monorepo export or production backup. The package
excludes real identity/payment data, database files, secrets, original media, fonts
and dependency caches. Synthetic fixture identifiers are test-only.

## 7. Remaining work and release boundary

This closes the isolated order-preparation gap between a catalog and the earlier
allocation core, **not the complete membership/payment migration**. Real catalog/
receiver import and parity, human-authenticated caller integration, native secure
storage/dialer confirmation, browser sessions, cross-database revocation, current
staff roles, actual payment evidence, stale-payment exceptions, refunds/reversals,
contribution rewards/referrals, ticket/shop/group commands, broker consumers,
observability, retention/erasure and full device/application acceptance remain.

Existing global historic payment-reference completeness, final consistent backup,
missing-media recovery, prediction-economics approval and controlled single-writer
cutover remain gating requirements. Supabase is not retired. No new economic,
source-disposition or production release approval is implied by passing tests.

## 8. Saved destinations and use

Source: `AFRICLUB/cloudflare/payment-allocation/`, including its source, tests,
migration, scripts, contracts, docs, reference client and unchanged-ID README.
Deliverables: `AFRICLUB/output/refactor-2026-09-26/batch8-membership-checkout/`.
The source register records every installed path, Drive ID, checksum and readback.

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-batch8-verification"
```

A matching Drive checkout should need no source changes from this package. It is
an incremental current-source patch, not cumulative v1-v4. Historical packages
remain preservation artifacts and must not overwrite newer source.

## Implementation references

Repository behavior: the exact membership-payment-evidence-binding migration and
current payment-allocation sources, recorded in baseline_provenance.json.
Primary platform guidance checked during implementation (not runtime evidence):
- https://developers.cloudflare.com/d1/worker-api/d1-database/
- https://www.sqlite.org/lang_createtrigger.html

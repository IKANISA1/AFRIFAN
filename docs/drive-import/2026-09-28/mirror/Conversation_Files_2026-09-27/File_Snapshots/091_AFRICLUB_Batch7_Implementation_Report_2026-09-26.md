# AFRICLUB — Batch 7 payment allocation and paid-membership core

Date: 26 September 2026. Authority: the current AFRICLUB Drive repository and seven
retrieved payment/membership/contribution migrations. This is an additive current-
source candidate, not a historical cumulative v4 overwrite.

## 1. Actual completion and Drive status

**Twenty-two new source files are saved individually at their correct paths under
`AFRICLUB/cloudflare/payment-allocation/`. All 22 were downloaded again, matched the
tested source bytes by SHA-256, and passed a fresh 202-test code run.** No existing
source file was overwritten, renamed or deleted. The eight-file reference snapshot
(seven SQL migrations and the workspace manifest) is backed up with original IDs
and hashes. It is not a complete repository or production database backup.

The complete incremental package passed **235 targeted tests: 202 new module tests
and 33 reused installer/rollback regressions**. Eighteen additional JavaScript/JSON
syntax/parse checks and the disabled-configuration check passed. Historical test
counts from the other modules are not added; those whole suites were not rerun.

**Nothing was deployed or enabled.** No source database was modified; no real payment
was sent, matched or allocated; no real member was imported, activated, charged or
renewed. Supabase remains the current authoritative writer. The new candidate is
hard-fenced to an explicitly enabled isolated staging environment and separately
gated by disabled database controls. It cannot be configured as a production writer
through the supplied policy.

## 2. Implemented scope

| Component | Concrete behavior |
| --- | --- |
| Private evidence ingestion | Exact raw/parsed identity, club, provider, country, amount, currency and recipient fields; non-mock parsed debit requirement; one immutable interpretation per raw source ID; provenance digest and external attestation reference. No raw SMS, phone or provider body is stored. |
| Payment allocation | Matches immutable pending order/intent snapshots and current receiver controls. At commit it checks owner, club, amount, currency, country, provider, recipient, receiver/partner, pending state and expiry. |
| Global duplicate protection | A unique canonical provider + provider transaction reference across all participating clubs, plus one allocation per order and evidence record. Historical claims can be inserted only through reviewed staging import; their completeness is not assumed. |
| Paid membership | Membership renewal, allocated-debit ledger, reference claim, receipt, intent-allocation state and outbound event share one transaction. Existing member ID/number/code/points and suspended status remain intact. Same-tier renewal extends the later of existing expiry and confirmation; a tier change resets from confirmation. UTC calendar-year arithmetic clamps leap-day ambiguity and rejects unsupported overflow. |
| Contribution evidence | Records allocated payment evidence but explicitly returns `businessTargetFulfilled: false` and no membership. Campaign totals, point rewards, referral effects and final contribution confirmation are not performed. |
| Idempotent recovery | Same request and order/evidence retries return the original immutable receipt. A changed request under the same key conflicts. Lost replies after commit cannot cause a second renewal. Recovery still needs current service authorization. |
| Service authorization | Four private entrypoints use fixed deployment principals and separate current club capabilities. SQL guards repeat revision/expiry/enablement checks at mutation time. No request-body actor or public HTTP financial command exists. |
| Transactional outbox | One immutable `payment.evidence_allocated` event per allocation, with a private bounded 20-event claim, 60-second leases and same-lease acknowledgement. No broker/provider dispatcher or external effect is implemented. |
| Offline staging import | Exact input hash, duplicate and cross-reference checks; original identity preservation; parameterized INSERT-only plan written exclusively with private file mode. Imported control records stay disabled, no service principals/grants are enabled, and no SQL is executed by the planner. |
| Configuration/SQL checks | Disabled private Worker template, isolated placeholder database, fixed principal variables, strict config checks and a read-only SQL capability probe. Passing the checker explicitly does not establish source reconciliation, D1 compatibility, service binding approval or release authority. |

The membership fulfillment is an implemented isolated transaction core, **not the
complete membership product migration**. Checkout preparation, order creation,
price selection, actual provider evidence attestation, existing client adapters and
production data/import parity remain outside this batch.

## 3. Source rules preserved and intentional limits

The newest retrieved `allocate_momo_payment_intent` definition serializes raw
interpretation and global provider/reference use; validates exact payer/order
bindings; distinguishes allocation from business fulfillment; and permits receipt
recovery without applying today's receiver changes to an old payment. These rules
are represented in the new private core rather than copied as PostgreSQL SQL.

The latest paid-membership migration says a payment must not lift an administrative
suspension. It also preserves existing membership identity and extends the term
according to tier. Those rules are covered by executable tests. Target date handling
is explicitly UTC; live-source timezone/data parity still requires reconciliation.

The source final initiative-contribution routine updates contribution state,
campaign totals, points and referrals together. The candidate does not discard
those obligations. Its local order state `fulfilled` describes **allocated payment
intent evidence only** when `kind='contribution'`; the receipt's business flag stays
false and no contribution-confirmed event is emitted. Finalization remains a
separate unfinished port, including the applicable FET governance decision.

**Payment authenticity is still the trusted ingress service's responsibility.** An
attestation reference and a source hash are provenance, not a provider signature or
proof of actual external settlement. The private RPC must not be exposed to an
untrusted client or generic webhook. The database ledger is allocated debit evidence,
not an accounting general ledger, a cash wallet or proof that money was transferred.

Service-role permissions are not supporter authentication. The new local subject
enablement gate does not complete cross-database identity revocation. Consumer
services must authorize the human actor, resource ownership and live entitlements
before showing receipts or performing downstream commands. No staff migration or
operator maker/checker workflow was silently introduced.

## 4. Executed verification

| New module group | Tests |
| --- | ---: |
| Allocation, renewal, exact evidence binding and immutable records | 35 |
| Concurrency and raw SQL capability probe | 4 |
| Private request/receipt/entrypoint contracts | 7 |
| Evidence validation, canonicalization and deduplication | 43 |
| Import and disabled/ready configuration checks | 46 |
| Outbox leasing, acknowledgement and recovery | 25 |
| Authorization, injected failures and mutation-time races | 42 |
| **New module tests** | **202** |
| Repeated installer/rollback regressions | 33 |
| **Targeted total** | **235** |

Final failures and skips were zero. The source downloaded from Drive independently
repeated all 202 module tests; that repetition is not double-counted. Tests include
same-key/different-key retries, conflicting global references, mismatched
owner/club/provider/amount/currency/recipient, expired or disabled controls,
revoked-and-reenabled service authority, suspension preservation, leap-day renewal,
post-commit response loss and failure at every ingestion/allocation batch position.
Injected trigger failures cover the reference claim, membership, ledger, receipt,
outbox and outbox-delivery records, plus the order update. All preceding effects
roll back. Tests also prevent correlated SQL authorization from accidentally
borrowing another club's grant when the target club is revoked mid-transaction.

Three tests use **independent SQLite connections in separate Node worker threads**
against the same disposable database file: same request key, different keys for the
same order, and two orders competing for the same provider transaction. They produce
one allocation, membership effect, global claim, receipt and outbox event. These are
real local SQLite concurrency cases, not D1 production-capacity evidence.

Environment: Node **22.16.0**, Python **3.13.5**, SQLite **3.49.1**, real Web Crypto.
Most tests control database time and emulate the D1 binding/batch API while running
genuine SQL and triggers. The raw SQL probe separately executes without clock
substitution. WorkerEntrypoint wrappers were syntax checked, not run under workerd.
No real D1/provider/handset, full Flutter/Next.js/pgTAP, signed app, browser or
production load testing was performed. Higher repository toolchains remain intact.

## 5. Incremental source installer and recovery

The package passed preflight, source application, exact after-hash verification,
repeat application and restoration checks in three disposable reconstructions:

| Starting source state | Files changed | Result |
| --- | ---: | --- |
| None of the new module preinstalled | 22 | Rollback restores every starting byte. |
| Half of the new module preinstalled | 11 | Rollback retains those original additions. |
| Entire new module already matching | 0 | Application/reapplication changes nothing. |

The reference migrations and workspace manifest are exact-hash preconditions, not
files to be modified. Unknown edits or conflicting pre-existing new files stop the
installer. It does not deploy, import data, send messages, run SQL, change billing or
alter roles. Stop source editors/builds during multi-file application; individual
writes are atomic but the whole directory update is not one filesystem transaction.

Historical cumulative v1-v4 packages remain preservation artifacts and must not
downgrade newer Drive code. This Batch 7 package adds only the new payment module.

## 6. Remaining implementation and activation requirements

R08 advances to **private allocation and paid-membership core implemented locally,
saved, not deployed**. It is not closed. Still required: approved source-order and
global historical-reference reconciliation; actual provider/reconciler integration;
checkout/native/web/admin adapters; current identity/role/revocation integration;
complete contribution points/referrals; group contributions; refunds/reversals;
stock/ticket/shop commands; operational audit, retention/erasure, metrics, abuse and
capacity controls; real D1 transactional/runtime acceptance; consistent final backup
and controlled single-writer cutover.

Outbox acknowledgement is not proof of an external side effect. Consumers need an
idempotent effect transaction and retry/dead-letter policy. No notification or
membership-card dispatcher is included. Immutable stored IDs/hashes remain linkable
personal/financial information; this module does not invent retention approval.

The schema/import projection is intentionally disabled and staging-only. One shared
allocation database preserves global uniqueness across clubs; splitting it would
require a separately proven global authority. Do not enable a candidate with an
empty or partial historic claim set against real payments. No source-disposition,
financial-policy, production release or Supabase retirement approval is granted.

## 7. Saved destinations and use

Source: `AFRICLUB/cloudflare/payment-allocation/`, including code, SQL, tests,
contracts, source maps and runbook. Deliverables:
`AFRICLUB/output/refactor-2026-09-26/batch7-payment-allocation/`.

From the extracted incremental package directory:

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-batch7-verification"
```

A checkout matching the saved Drive source should report all 22 paths already
matching. The source archive excludes real user exports, payment data, database
files, provider secrets, fonts and dependency caches. Test fixtures are synthetic.

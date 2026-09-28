# Payment evidence allocation — isolated staging candidate

This module implements the first transactional membership/payment core in the
AFRICLUB Cloudflare migration. It is a **private, disabled, isolated-staging
candidate**, not the production payment writer. It makes no payment-provider call,
accepts no public HTTP command, and changes no existing Supabase, authentication,
Flutter, website, operator, or delivery module.

## Membership checkout companion (26 September 2026)

`MEMBERSHIP_CHECKOUT.md` documents the new private prepare/read service and forward
migration `0002_membership_checkout.sql`. It creates/reuses frozen pending membership
orders in this same isolated allocation database; checkout itself does not pay or
activate membership. Catalog/grants and runtime remain disabled. It is not installed
in the supporter/admin clients. The original allocation contract below is preserved.

## Implemented scope

A reviewed service can record a raw-evidence digest plus its exact parsed fields,
then allocate that evidence to one frozen pending order. The database transaction
checks service authority, owner, club, amount, currency, provider, country,
recipient, receiver, pending state and deadline. The provider transaction key is
unique across all clubs in this database; a club cannot consume another club's
previously used payment.

For a membership order, one transaction records the global reference claim,
allocation, posted-evidence ledger, membership renewal, immutable receipt and
outbound event. One payment cannot renew the membership twice. Existing membership
ID, member code, number, points and administrative suspension survive renewal.
A same-tier renewal extends from the later of current expiry and confirmation time;
a different tier begins one year from confirmation. The calendar adapter is UTC,
uses an explicit leap-day clamp, and rolls back unsupported date arithmetic.

For an initiative contribution, the transaction records **payment allocation only**.
Its receipt says `allocationPersisted: true`, `businessTargetFulfilled: false`, and
`membership: null`. It does not confirm the initiative contribution, increase
campaign totals, award points or process referrals. The source contribution routine
performs those effects together; pretending to complete it without those ports
would lose behavior. The local order's `state='fulfilled'` means its **payment
intent has been allocated**, not that a campaign, ticket, shop order or contribution
business process has completed. There is no contribution-confirmed event.

The ledger is immutable evidence of an allocated debit. It is **not a cash wallet,
financial-statement general ledger, deposit account, transfer or external settlement**.
No FET economic-policy decision, refund, reversal or store release is implemented.

## Source authority and intentional adaptations

`docs/source-map.md` and `docs/source-provenance.json` bind this implementation to
seven source migrations retrieved from the authoritative AFRICLUB Drive folder.
The 23 September evidence-allocation and paid-membership restriction migrations
supersede older behavior in their respective functions. Existing historical
migration files are preserved, not rewritten or copied into D1 as equivalent SQL.

The current source project UUIDs, intent/order references, club IDs and provider
references must be preserved by the eventual migration. The supplied importer is
for a **reviewed minimal staging projection**, not an automatic conversion of a
raw Supabase dump. There is no live import or cross-database transaction here.

## Private service boundary

All four named Worker entrypoints, and the default HTTP handler, return 404 to
HTTP. Only specifically reviewed service bindings may call their RPC methods:

| Named entrypoint | Fixed deployment variable | Database capability |
| --- | --- | --- |
| `PaymentEvidenceIngestor` | `INGEST_PRINCIPAL_ID` | `ingest` |
| `PaymentAllocator` | `ALLOCATE_PRINCIPAL_ID` | `allocate` |
| `PaymentReceiptReader` | `READ_PRINCIPAL_ID` | `read` |
| `PaymentAllocationOutbox` | `OUTBOX_PRINCIPAL_ID` | `outbox` |

The principal is configured on the trusted Worker, never accepted from the request.
Every call verifies current service and club grants; SQL guards recheck grants,
revisions and expiry during the mutation. Separate capabilities do not automatically
imply two-person approval: no human maker/checker workflow is implemented.

**The ingestion caller remains responsible for payment authenticity and matching.**
The raw SHA-256 and `attestationRef` identify evidence and external review; merely
supplying them does not attest actual bank/mobile-money settlement. The service
must never be bound directly to an untrusted supporter app, generic SQL proxy or
unauthenticated webhook. Raw and parsed records must agree, be non-mock and have
`parseStatus='parsed'`, `direction='debit'`. Reviewed/manual allocations are not
part of this automatic path. No raw SMS body, payer phone or provider response is
stored in these tables.

The reader and outbox return personal IDs and financial metadata. Their consumers
must implement human authentication, ownership and role checks before displaying
anything. A service-role read permission is not an end-user permission. The subject
enablement table is a local staging gate, **not a completed synchronization with
supporter-auth revocation**. No check here closes an identity-revocation race across
another database; that guarantee must be designed and tested before client cutover.

## Request, receipt and retry contracts

`contracts/private-rpc.json` defines exact fields and response shapes. Requests use
lowercase UUID identifiers, positive integer currency units, canonical provider and
country/currency codes, and UTC epoch milliseconds. The request ID is a durable
operation key. Persist it before calling; repeat the same request after an unknown
response. Reusing the key with different arguments conflicts.

An already committed order/evidence pair returns the original receipt, even if a
receiver or membership has changed since the payment. Current service authorization
is still required. A receipt is a historical statement, **not a current entitlement**.
A fresh evidence ID or provider reference must never be invented to recover a lost
response. Conflicting raw interpretations and reused global transaction references
fail rather than being overwritten.

The receipt and event use `businessTargetFulfilled` to distinguish membership
activation from contribution evidence awaiting its separate business fulfillment.
Authentication/delivery receipts from the existing code-delivery modules are not
valid payment evidence and are not connected to this financial core.

## Transactional outbox

The financial transaction creates one immutable `payment.evidence_allocated` event.
`claim({clubId,limit})` leases at most 20 events for 60 seconds. `acknowledge` requires
the matching unexpired lease and its principal, and is idempotent for that lease.
Leases can expire and be delivered again. A lost claim response strands only the
lease until expiry, not the financial record. A consumer must deduplicate `eventId`
**in the same transaction as its own effects** before acknowledging.

This module has no external dispatcher, broker, notification, automatic membership
card issuance, campaign consumer, dead-letter policy or spending action. Its
`delivered` outbox state denotes a consumer acknowledgement, not proof of remote
handset/provider delivery. No exactly-once external-effect guarantee is claimed.
The result and claim bounds do not prove bounded storage scans under production
load; measure indexes, latency and retention before release.

## Disabled staging preparation

`wrangler.staging.jsonc` has no public route, schedule, other service binding,
real account/principal/database ID or enabled flag. Runtime also refuses any
`ALLOCATION_ENVIRONMENT` other than `isolated-staging`. The database starts with
`writer_mode='disabled'`, `source_reconciled=0`, `historical_claims_verified=0`, no
service principals, and disabled club/subject/receiver records on import.

This database must be new and dedicated, **not the public-content, authentication
or delivery-receipt database**. It is one shared allocation/deduplication authority
for all covered clubs. Partitioning by club would break the implemented global
provider-reference constraint; do not do so without a replacement global authority.

The offline plan command is:

```sh
node cloudflare/payment-allocation/scripts/prepare-staging-import.mjs \
  /private/reviewed-staging-projection.json /private/new-import-plan.json EXPECTED_SHA256
```

It accepts exactly `schemaVersion`, `clubs`, `subjects`, `receivers`, `memberships`,
`orders`, and `historicalClaims`; field names are defined by the script and tests.
It outputs parameterized INSERT-only statements to an exclusive 0600 file, never
executes them and never enables a writer. Orders must be pending frozen snapshots.
This tool does not export source data, verify source signatures, prove historical
claim completeness, migrate reversals, or administer service grants.

Staging activation requires independently verified source/control data, preservation
of **all previously used provider references across every affected target and club**,
reconciliation and a restore drill, reviewed service-principal grants/bindings,
actual D1 SQL-feature tests and explicit approval. A hash verifies the supplied file,
not that someone exported the complete correct source. Never silently start this
writer with an empty historical-claim set against real payments.

```sh
node cloudflare/payment-allocation/scripts/check-deployment.mjs
node --test cloudflare/payment-allocation/tests/*.test.mjs
```

The optional ready-config check accepts a private configured file and `--ready`, but
still reports live database, source reconciliation, global deduplication, caller
bindings and production release as **unverified**. It does not provision resources.
`check-sql-runtime.sql` is a read-only capability probe to run in the target staging
database; its result must be examined before applying production assumptions.

## Evidence, recovery and unfinished work

Local tests use genuine SQLite SQL/triggers and Web Crypto, controlled database time
and simulated D1 bindings. They exercise mutation-time revocation, cross-club
conflicts, concurrent JS callers, every batch position, internal trigger failures,
post-commit response loss, immutable receipts, suspension and calendar renewals.
The WorkerEntrypoint wrappers are syntax checked, not executed under workerd. No
real payment, member import, D1 load/concurrency benchmark or existing-app release
is performed by those tests. Full Flutter/Next.js/pgTAP and device checks remain.

Stop staging with the runtime and database gates. Retain receipts, claims, ledgers
and events; do not delete a claim to force payment reuse. The module deliberately
blocks destructive edits but does not define an approved retention/erasure or
reversal policy. UUIDs and evidence hashes remain linkable information. Import,
operator-grant audit, privacy reconciliation, key lifecycle, monitoring and disaster
recovery still need an accountable operational implementation.

Full checkout/client integration, payment-provider evidence ingestion, full contribution
fulfillment/rewards/referrals, refunds/reversals, group contributions, ticket/shop
commands, native/web/admin adapters and cross-database authorization guarantees
remain unfinished. Supabase is still the current authoritative writer. This source
addition must not enable dual writes or authorize its retirement.

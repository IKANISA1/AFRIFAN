# Membership checkout — private isolated-staging candidate

Date: 26 September 2026. This companion implements membership checkout preparation
and current-state reads on the existing payment-allocation database. It does not
perform payments, activate membership at checkout, dial a handset, expose a public
HTTP API, connect existing Flutter/Next.js clients, or authorize production cutover.

## Source contract and scope

The source `prepare_membership_payment` in
`20260920165540_membership_payment_evidence_binding.sql` selects the first active
package by sort order and ID; chooses annual price unless null/zero, then price;
resolves a country-correct active route and unique receiver; builds a USSD string;
reuses a matching unexpired pending order; otherwise cancels the same user's pending
membership intents and creates one with a 24-hour deadline. The new code translates
that behavior into the existing isolated SQLite/D1 candidate. Original PostgreSQL
migrations and original payment allocation code remain unchanged.

Differences are explicit: this primitive uses a trusted service-derived userId
rather than PostgreSQL auth.uid(); its local subject gate is not human/session
authentication. It also requires exact receiver club/provider/currency consistency,
a template containing amount and recipient placeholders, and a bounded safe dialer
string. Unknown legacy orders without a reconciled package/dialer detail record
cannot be reused. The supplied catalog planner is a minimal projection, not a raw
Supabase dump converter. These differences need source-data and real-client parity
acceptance before any cutover.

## Private service boundary

The default HTTP handler and both named WorkerEntrypoints always return 404.
`MembershipCheckout.prepare` uses fixed `CHECKOUT_PRINCIPAL_ID` and the separate
`pa_checkout_grants` capability `prepare`. `MembershipCheckoutReader.read` uses
fixed `CHECKOUT_READ_PRINCIPAL_ID` and capability `read`. Both identities must be
distinct from the existing ingest/allocate/read/outbox principals. The trusted
caller must authenticate the human and securely derive the userId and clubId. It
must not forward user-chosen actor fields or offer this binding to arbitrary apps.

Checks include current service expiry/revisions, club enablement/revision, local
subject enablement/revision, original allocation source/history gates and the new
catalog enablement/reconciliation/revision. SQL repeats those checks at the actual
mutation; revoke-and-reenable cycles invalidate a stale operation in flight. The
cross-database supporter-session revocation problem is not solved by this local
gate. No arbitrary staff or supporter permissions are introduced.

## Versioned request contract

The exact wire fields are in `contracts/membership-checkout.json`.

```text
prepare({requestId, clubId, userId, tier})
read({clubId, userId, orderId})
```

IDs are lower-case UUIDs, clubId a positive safe integer, tier a normalized bounded
identifier. Price, currency, package, recipient, receiver, provider and principal
cannot be chosen in the request. The service normalizes surrounding whitespace and
tier case; the reference TypeScript client intentionally requires canonical input.

The response contains a frozen checkout snapshot: order/intent/user/club/package,
tier, amount, currency, country, provider, recipient, USSD string, creation and
expiry times. Its `paymentVerified: false` and `membershipActivated: false` describe
the checkout-time event, not a later payment. This snapshot is immutable.

## Atomic prepare, reuse and cancellation

The preparation runs as one INSERT with database triggers inside a D1 batch. It
rechecks the offer and all authorization revisions, selects a compatible pending
snapshot or cancels only this owner/club's pending membership orders, creates the
new frozen order and detail, and inserts an original result and audit record. All
of these effects roll back together. Allocation and checkout share the same
database writer and existing order state machine; no two-database transaction is
claimed. Checkout never inserts a ledger, allocation, external reference claim,
membership or payment-evidence outbox event.

A reusable snapshot must match the selected package, route, receiver, tier, current
amount, currency, country, provider, recipient and exact dialer string, and still
be pending/unexpired. A route priority or dialer change can therefore require a new
snapshot even when the amount is unchanged. Historical pending records lacking the
new binding are not guessed. Cancellation preserves history; it is not deletion,
a refund or a cancellation of an already committed allocation. A later payment
against a cancelled or expired order requires governed exception handling, which
is not implemented by this checkout module.

From a reconciled starting state, concurrent matching checkouts reuse one order;
competing tiers leave only the newest created order pending. Existing inconsistent
historical duplicates are not repaired merely by installing this source: source
reconciliation remains required. Reuse deliberately follows source behavior and
does not cancel other pending records while a compatible order already exists.

## Original-response recovery versus current status

Persist the requestId before calling. Repeating the same principal/club/user/request
and normalized tier returns its original checkout/result, including its original
`reused` value, even after expiry or catalog change. Reusing that key with different
arguments fails. The service still requires current authorization. A lost response
after commit cannot silently cancel that checkout and create another under the
same key. Unknown outcomes must retain the original operation key.

Always use the read method before presenting payment instructions. It reports
`pending_current`, `expired`, `cancelled`, `allocated` or `configuration_changed`.
`mayPresentPaymentInstruction` is true only for pending_current.
`paymentEvidenceAllocated` is true only for allocated. Reads are point-in-time
observations: later changes remain possible and allocation independently enforces
its exact evidence, receiver, state and expiry checks. A read is not a reservation
or guarantee of payment success. The allocation receipt remains a separate object.

Twenty new request records per club/user in a rolling fifteen-minute window is a
pilot abuse control. Exact stored retries are not counted again. This is not a
reviewed global production capacity or mobile-network fairness policy. Upstream
rate/spend controls and bounded historical storage management are still needed.

## Allocation compatibility

Prepared orders are consumed by the unchanged PaymentAllocationService. Only the
separate trusted ingestion plus exact allocation command can post evidence and
activate/renew membership. Existing suspension/identity/points preservation and
provider-reference uniqueness still apply. Tests run checkout -> ingestion ->
allocation and confirm one membership effect, while a checkout alone has none.
This does not establish real provider authenticity, receipt settlement or source
migration parity. The contribution path and its unfinished rewards/referrals are
unchanged; membership checkout creates no contribution orders.

## Catalog import and disabled configuration

Apply `0002_membership_checkout.sql` after the existing `0001_payment_allocation.sql`
using the reviewed staging migration process. It adds companion controls, catalog,
requests/details/results/audit, views and indexes. It neither rebuilds nor deletes
existing allocation tables/triggers and creates no users, roles or active catalog.
Both workers must target the same dedicated allocation database and account.

The catalog planner takes a reviewed JSON file with exactly:

```text
{schemaVersion:1, sourceProject, clubs:[{clubId,ussdTemplate}],
 packages:[{id,clubId,partnerId,tier,annualPrice,price,sortOrder,isActive}],
 routes:[{id,clubId,partnerId,provider,country,recipient,isActive}]}
```

Maximum input size is 1 MiB, up to five clubs and 500 package/route entries each.
The byte checksum must match an independently verified value. Duplicate IDs, unsafe
routing and invalid prices fail. The plan preserves original identifiers and
source-active IDs as metadata, but inserts all catalog rows disabled, grants no
permissions and does not execute SQL. It uses exclusive creation and private file
mode; a conflicting output is not overwritten. Keep the reviewed source and plan
private. A checksum does not establish completeness, ownership or approval.

```sh
node cloudflare/payment-allocation/scripts/prepare-checkout-catalog.mjs \
  /private/catalog.json /private/new-disabled-plan.json EXPECTED_SHA256
node cloudflare/payment-allocation/scripts/check-checkout-deployment.mjs
node cloudflare/payment-allocation/scripts/compile-checkout-client.mjs
node --test cloudflare/payment-allocation/tests/*.test.mjs
```

The optional ready checker takes checkout and allocation private config files plus
`--ready`. It rejects another database/account, reused authority principals, public
routes, outgoing service/asset bindings and environment overrides. It reports live
database, source catalog, human authentication, caller-binding and production
release verification as false even when configuration passes. It does not provision
resources or enable anything. There is no schedule or automatic catalog refresh.

The shipped `wrangler.checkout.staging.jsonc` has blank principal IDs, placeholder
shared DB ID and both flags false. The runtime rejects non-isolated-staging
settings. Apply neither an older cumulative archive nor a new empty database over
the current allocation history to make configuration pass.

## Reference client and required integration

`checkout-client.ts` is a strict trusted-server RPC adapter, not an installed native
client or browser cookie/BFF session. It validates request/response correlation,
coherent state flags and the fixed snapshot shape, bounds waits, and never retries
writes automatically. Timeout or malformed result after a prepare call becomes an
unknown outcome. The caller retains the original key and decides when explicitly
to retry. The client performs no storage, credential handling, network payment,
USSD launch or UI navigation. Configure secure native/browser authentication and
explicit confirmation separately before exposing checkout to supporters.

## Verification and limitations

Node tests execute actual SQL/triggers and cryptography with a D1-shaped local
SQLite adapter. Database time and fixture identities are synthetic. Four tests use
independent SQLite connections in separate Node threads for same-key, different-key,
competing-tier and allocation-versus-replacement races. These are local concurrency
proofs for covered cases, not real D1 replication, workerd, provider, load/cost or
production timing evidence. Wrappers are syntax checked; real Cloudflare staging,
full pinned Flutter/Next.js tests and physical-device journeys remain necessary.

Stored identifiers, route values and source/request hashes remain linkable data.
Append-only evidence protects retries but does not define approved retention,
erasure, refunds, audit export or disaster recovery. Full catalog administration,
source import parity, inactive/deleted-account synchronization, stale payments,
client integration, observability and global historical-payment reconciliation
remain unfinished. Supabase is not retired and no production writer is switched.

## References

Source semantics: repository migration
`supabase/migrations/20260920165540_membership_payment_evidence_binding.sql`.
Implementation guidance (not deployment/approval evidence):
- https://developers.cloudflare.com/d1/worker-api/d1-database/
- https://www.sqlite.org/lang_createtrigger.html

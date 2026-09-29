# Supporter membership gateway — disabled isolated-staging candidate

## Current local integration — 30 September 2026

All 34 candidate source files were imported after exact comparison with the frozen
inventory and the original implementation ZIP members. The per-file hashes, review
rationale, local corrections and execution evidence are recorded in
`docs/release/membership-gateway-integration-2026-09-30.json` at repository root.
The provenance documents below retain their earlier source-read and execution
claims; they are historical context, not current live-resource acceptance.

The journal and unclaimed-release flags both remain explicitly disabled. Enabling
release requires an enabled journal, the matching private checkout release flag,
and its runtime method; missing optional capabilities fail before any write RPC.
The deployment checker leaves required-secret verification and runtime readiness
false even when a local staging configuration is structurally valid.

Current checkout instructions are revalidated after final identity introspection.
The native reference client rejects non-string enum values, including arrays, and
rejects malformed recovery phases before a replacement request key can be saved.
OpenAPI 1.4.1 documents all eleven operations, the owned history response schemas
and sanitized handoff errors. Local fixture execution and a Wrangler dry run do
not establish real bindings, carrier/payment results, protected device storage,
five-app integration, atomic revocation or production approval.

This module connects the existing supporter identity verifier to the existing private
membership checkout and payment-receipt services. It is a native-bearer HTTP adapter,
not a browser-cookie session, new financial writer, installed Flutter screen, or
permission to retire Supabase. No existing source schema or service is replaced.

## Trust and service boundaries

The gateway uses four reviewed private bindings; their source methods now also include the opt-in handoff journal described below. The original capabilities remain: identity lookup,
checkout preparation, owner-scoped checkout reads, and historical payment receipt
reads. It has no SQL, payment allocator, payment evidence ingestor, message sender,
account-erasure, staff-role or membership-entitlement authority. Private bindings
must name exactly the entrypoints in the disabled Wrangler template.

Identity comes from `SupporterIdentityVerifier.current({clubId, accessToken})`.
The gateway checks the response shape, verified phone, supporter role, club, session
and timestamp. User IDs are derived from that verified result, never request fields.
It rechecks the same token after upstream work and immediately before invoking a
checkout write. It checks an owned checkout before calling the broader private
payment receipt reader, then correlates owner, club, order, intent, amount and tier.

**These checks do not make two databases one transaction.** A session can be revoked
between the last identity read and an allocation-database checkout commit. A covered
regression intentionally demonstrates that the checkout can exist while the gateway
withholds its response. The result is an unknown outcome, not a promise that nothing
changed. Checkout grants no paid membership; nevertheless real cross-database
revocation semantics remain an explicit release requirement. Revocation occurring
after the final read remains possible as with any point-in-time authorization check.

The configured origin is an exact HTTPS origin. Only directly reviewed Cloudflare
ingress is permitted; Runtime `request.cf` metadata is required; `CF-Connecting-IP` supplies an abuse-control input, not identity.
Do not route requests through an unreviewed proxy or accept arbitrary private callers
that can impersonate edge metadata. The native marker is not an authentication secret.

## Versioned native HTTP contract

All routes begin `/v1/supporter/clubs/{clubId}` and require
`Authorization: Bearer <native access token>` and `X-AFRICLUB-Client: native-v1`.

| Method and suffix | Behavior |
| --- | --- |
| `GET /session` | Returns the verified user, club and current session ID. |
| `POST /membership/checkouts` | Accepts only canonical `{"tier":"gold"}` and an original UUID `Idempotency-Key`. Returns the checkout descriptor, not payment instructions. |
| `GET /membership/checkouts/{orderId}` | Returns the owned checkout's current state; instructions are present only while pending/current. |
| `GET /membership/checkouts/{orderId}/receipt` | Returns a minimized historical membership-allocation receipt, after ownership and allocation checks. |
| `GET /membership/handoffs/current` | Reads the owner-scoped server journal; never regrants platform permission. |
| `POST /membership/handoffs/reservations` | Explicitly reserves an owned order; accepts only orderId and an original UUID request key. |
| `POST /membership/handoffs/claims` | Explicitly claims the one first-response opportunity; all replays return no grant. |
| `POST /membership/handoffs/releases` | Explicitly releases a never-claimed reservation; separately disabled and never a cancellation, refund or payment confirmation. |
| `GET /membership/status` | Returns the owned current membership observation; historical receipts cannot restore suspended or expired entitlement. |
| `GET /membership/history` | Returns an owned history page of up to 20 immutable membership allocations; the optional cursor is carried in a header. |
| `GET /membership/history/{orderId}` | Returns an owned historical receipt without requiring a locally prepared checkout. |

All non-session routes require `X-AFRICLUB-Session` matching the verified access
session. This guards against a credential supplier switching sessions between the
caller's scope selection and the request. Reauthentication of the same user/club
can explicitly resume an original pending operation using the new session ID.

Request-body actor, amount, currency, package, provider, recipient and role fields
are rejected. Browser `Origin`, `Cookie`, `Sec-Fetch-*` and known identity-override
headers are rejected. No wildcard CORS, cookie fallback, public SQL or service-role
fallback exists. GET does not prepare, allocate, refresh credentials or launch USSD;
rate counters still change on reads. Error responses are no-store and contain no
raw database/provider messages. There are no logs or external analytics in this code.

Bodies are bounded to 2 KiB and 1.5 seconds. The single-field JSON grammar deliberately
rejects duplicate keys and escaped alternate names. Each private call has a five-
second deadline; this does not cancel a remote mutation already executing. The
reference client's overall network timeout defaults to fifteen seconds.

OpenAPI 3.1 lives in `contracts/openapi.json`. It documents exact public shapes,
security headers and error outcomes. Example-shape tests are bounded contract tests,
not a general OpenAPI compliance certification.

## Original request and current instructions are different

Preparation and exact-key recovery return only IDs, tier, reuse and the historical
facts `paymentVerified:false` and `membershipActivated:false`. Even if the original
checkout is now expired or cancelled, replay never exposes its old dialer string.
Call the current-state read immediately before presenting payment instructions.
`paymentInstruction` is null for expired, cancelled, allocated or changed offers.
No response is an irrevocable reservation; state may change after a read.

If a checkout RPC was invoked but timed out, failed, returned an invalid shape, or
failed the subsequent identity check, the gateway returns HTTP 503 with
`error:"checkout_outcome_unknown"`, `outcome:"unknown"`, and the original request ID.
It does not automatically retry, cancel, create a replacement key, or claim rollback.
An explicit retry by the same authenticated user/club must retain the same key/tier.

Payment receipt responses deliberately exclude source evidence IDs, payer identity,
provider reference and credentials. `membershipAtAllocation` and `historical:true`
are historical facts, not the current membership entitlement. Administrative
suspension remains visible. The unchanged allocator still owns actual evidence
matching and the membership renewal transaction; this gateway cannot invoke it.

## Reference client and recovery coordination

`client.ts` compiles without runtime dependencies. `MembershipApiClient` needs an
OS-protected access-token supplier and a native fetch transport. It sends once,
validates strict response shapes and correlations, bounds replies, refuses redirects,
and never refreshes or stores tokens. Browser fetch is not a supported deployment.

`CheckoutCoordinator` additionally needs a `RecoveryStore` with durable load,
compare-and-set, and a process/isolate-safe exclusive lock. No Android/iOS secure
store or lock implementation is supplied here. Do not substitute plain preferences,
localStorage, or an in-memory store in a shipped app. Test stores are synthetic.

`begin(tier)` is an explicit action: it resolves the current user, refuses to replace
an unresolved operation, writes and verifies the original key before POST, and saves
the returned order ID. `restore()` reads only; it never POSTs. `resume()` is another
explicit action retaining the original key and tier. Failed response or storage
writes leave the pending operation recoverable. There is no automatic discard or
background retry. State is scoped by user and club and contains no token, phone,
code or dialer instruction. OS backups, keychain availability, account switching,
secure deletion, process crashes and actual handset USSD confirmation still need
native implementation and device acceptance.

## Configuration and disabled deployment

The template is disabled: blank account/origin/club mappings, no routes, no public
preview, no logging, and unassigned rate namespaces. It uses the already named
identity verifier, private checkout, checkout reader and payment receipt reader.
No production default, credential, sender or real resource ID is shipped.

Required secret: `GATEWAY_RATE_KEY`, a separately generated random 32-byte hex
key used only for purpose-separated, daily-scoped rate keys. Raw bearer tokens are
never used as limiter keys. The required local edge and user limits are 120/minute
and 60/minute respectively. These pilot choices are not globally exact quotas or
measured production capacity. Upstream WAF, shared-network fairness, request costs,
privacy and abuse monitoring still require approval and measured evidence.

```sh
node cloudflare/supporter-membership-api/scripts/check-deployment.mjs
node cloudflare/supporter-membership-api/scripts/compile-client.mjs
node --test cloudflare/supporter-membership-api/tests/*.test.mjs
```

The ready-configuration checker takes gateway, identity-verifier, checkout and
allocation private JSON paths followed by `--ready`. It checks account, named
bindings, ingress, rate namespaces, isolated databases and distinct service principals.
It explicitly leaves live-resource, native-storage, atomic-revocation and production
approval unverified. It performs no network call, provisioning, migration or enablement.
The checker does not establish source import completeness or real permissions.

This gateway requires the existing identity schema and the existing allocation plus
checkout migrations to have been applied through a separately approved staging
process. No new migration is included here. Use the same allocation database for
checkout and receipts; never reuse an identity database as financial storage.
Do not make the upstream private Workers public or expose additional bindings.

## Local verification and remaining work

Tests execute the actual current IdentityService, MembershipCheckoutService and
PaymentAllocationService with two independent local SQLite databases, genuine SQL
and Web Crypto. Runtime service bindings, rate limits, provider data, identities
and native transport are test fixtures. WorkerEntrypoint wrappers, real Cloudflare
identity/database behavior, real payments, physical phones and full Flutter/Next.js
builds are not established by these tests. No browser UI or screenshot is produced.

The gateway, journal-enabled TypeScript coordinator and authored Dart adapter are not installed in any of the five Flutter
app shells. Dart ≥3.10 and Flutter ≥3.38 requirements remain unchanged. Production
requires approved native transport/secure storage, explicit USSD confirmation,
complete auth flows, cross-database revocation, full pricing/evidence/source-history
reconciliation, cancelled/expired-payment exceptions, refund and retention policies,
observability, restore proof and controlled single-writer cutover. Existing economic
policy decisions are not resolved by this source addition.

This continuation completes the partially saved gateway handoff: it adds the missing
tests, contracts and verification tools and tightens the membership-tier type check.
The source and delivery artifacts are saved to the authoritative AFRICLUB Drive workspace. Exact paths, file IDs and downloaded checksums are recorded
in the delivery receipt; an upload is not a deployment. Older cumulative v1–v4 source
archives are preservation artifacts and must not downgrade newer files.

## Implementation references

Repository source identities and hashes are recorded in `docs/source-provenance.json`.
External platform guidance is distinct from local execution evidence:
- https://developers.cloudflare.com/workers/runtime-apis/rpc/
- https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/
- https://developers.cloudflare.com/d1/worker-api/d1-database/

## Journaled native handoff — 28 September 2026

The journal uses the existing private checkout/read bindings and the allocation
transaction boundary; no allocator capability is exposed to the gateway. Both
`MEMBERSHIP_HANDOFF_JOURNAL_ENABLED` and the private `HANDOFF_JOURNAL_ENABLED` flag
are false in the templates. Its new SQL control also starts disabled.

`NATIVE_PAYMENT_HANDOFF.md` supersedes the earlier local-only handoff description.
Review/recovery remain read-only; explicit confirmation now reserves and claims on
the server before one platform invocation. The server marker survives loss of local
app data but unallocated/uncertain operations are not automatically reset. The
explicit support/recovery workflow and legacy-client cutoff remain release blockers.
TypeScript/local integration tests run; Dart/Flutter, real Workers, physical devices,
protected credential storage and the complete existing-app journey do not.


## Continuation — reliable delivery and unclaimed recovery, 28 September 2026

The candidate now has eight versioned native paths, including explicit `POST membership/handoffs/releases`. See `../payment-allocation/UNCLAIMED_HANDOFF_RELEASE.md`. It is separately disabled and does not introduce a browser cookie flow or a payment/refund endpoint.


## Current membership (additive v1.3 contract)

`GET /v1/supporter/clubs/{clubId}/membership/status` reads the currently authenticated
supporter's membership through the existing private `CHECKOUT_READER.membershipStatus`
capability. It accepts no body, order ID or caller-supplied user ID and preserves the
native-only origin/header contract. A reader without the new method fails closed.

The response includes `observedAt`, `currentStatus`, `isActive`, `historical:false` and
minimal term details. Statuses are `not_member`, `active`, `suspended`, `expired`,
`pending` and `incomplete`. A historical receipt is never used as current entitlement.
Suspension wins over payment verification; elapsed terms are expired; missing/future
term boundaries never become active. The gateway rechecks identity and projects again
at the response boundary, including active-to-expired downgrading. Returned state is a
point-in-time observation, not authorization for a future command or proof of an atomic
cross-database identity/financial transaction.

The typed TypeScript client exposes `membershipStatus(actor)`. Existing receipts stay
historical and unchanged. No SQL migration, membership activation, suspension removal,
Dart screen or five-app composition was performed by this additive read implementation.


## Implementation 07 — membership history

Adds read-only owned history and imported-receipt lookup. See `cloudflare/payment-allocation/MEMBERSHIP_HISTORY.md` at repository root for the wire paths, cursor contract, index migration, tests and retained acceptance limits. No live financial operation is executed.

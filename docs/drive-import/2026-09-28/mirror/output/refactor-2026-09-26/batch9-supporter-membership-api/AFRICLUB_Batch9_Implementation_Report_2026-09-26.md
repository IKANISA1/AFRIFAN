# AFRICLUB — Batch 9 authenticated supporter checkout: completed source handoff

Batch source date: 26 September 2026. Workspace: AFRICLUB, Google Drive folder
`1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH`. This is an incremental current-source
continuation, not a cumulative replacement of the repository.

## 1. What was actually completed

The continuation found ten Batch 9 source files already saved in Drive, including
its gateway runtime, reference client, configuration, OpenAPI contract and source
maps. Its tests/scripts and delivery handoff were incomplete. Existing source was
read and downloaded before continuing; it was not replaced with an older draft.

**The completed module contains twenty source paths: ten additions in this
continuation, two in-place corrections, and eight existing files preserved.**
The two corrections retain their original Drive IDs:

- `src/projection.mjs`: `1NZQdnOEZbqv9NjXptcsOKq8XFdpXAzCF`.
- `README.md`: `1ZMOX3aVmWujKCYV_YahrkQ5NPbFXuY7h`.

The new files are two verification scripts, seven test/support files, and a
continuation-provenance record. The original OpenAPI and source-map terminology
were retained rather than silently replacing them with a regenerated alternative.

All twenty source files are now in their correct Drive source locations. Every
one was downloaded after saving and matched the tested bytes by SHA-256. The
before-source backup was uploaded and checksum-verified before the two updates.
No file was deleted, renamed, or replaced with a same-name duplicate.

**No runtime was deployed or enabled.** No real identity, catalog, database or
permission was imported; no message, payment, membership renewal, financial-writer
switch or Supabase retirement occurred. Existing Flutter/Next.js callers are unchanged.

## 2. Authenticated workflow now verified

The native-bearer gateway connects the current private supporter identity verifier
to the current membership checkout and historical receipt services. The verified
user is derived from the access token, never from a request-body identity field.

| Endpoint suffix under `/v1/supporter/clubs/{clubId}` | Behavior |
| --- | --- |
| `GET /session` | Reads the verified supporter, club and session identifier. |
| `POST /membership/checkouts` | Accepts only a canonical tier and original UUID idempotency key; returns a checkout descriptor, not payment instructions. |
| `GET /membership/checkouts/{orderId}` | Checks ownership and returns current state; payment instructions appear only for a current pending order. |
| `GET /membership/checkouts/{orderId}/receipt` | Checks owned, allocated checkout first, then returns an exactly correlated, minimized historical membership-allocation receipt. |

All non-session requests require the expected session identifier. The gateway
checks the same token again before checkout preparation and after upstream work.
It checks club/user/order ownership before accessing the broader private receipt
reader and verifies intent, amount, currency and tier correlation in the response.

It rejects caller-selected user, role, amount, package, provider or recipient fields;
Cookie/Origin/browser fetch markers and known identity-override headers; malformed,
ambiguous or oversized bodies; unverified ingress; invalid credentials; and missing
abuse-control bindings. The native marker is not itself an authentication secret.

The gateway has no database, allocator, payment-evidence ingestor, OTP sender or
staff-role capability. Code delivery receipts are not payment evidence. The source
remains isolated-staging only, with a blank origin/account, no public routes,
disabled runtime flag, and placeholder rate namespaces.

## 3. Concrete validation correction

The expanded projection tests found that calling a regular-expression test directly
on a membership tier coerced non-string values. Numeric and null tiers could therefore
pass the pattern check in a malformed upstream checkout snapshot. The correction
requires `typeof c.tier === 'string'` before the pattern check. The two reproductions
failed before the correction and pass afterward; preliminary logs remain separate
from final evidence. Invalid upstream prepare responses are treated as unknown
outcomes, not valid checkout instructions.

The README correction distinguishes completing this partial handoff from creating
all of its existing runtime anew. No financial schema, economic policy, migration,
original authentication runtime, payment allocator or native app source was changed.

## 4. Recovery and current-state boundaries

A prepare call or retry returns identifiers, tier, reuse and the historical facts
`paymentVerified: false` and `membershipActivated: false`. It does not expose an old
recipient or USSD string from a replayed checkout. The caller must read current state
before presenting instructions. Expired, cancelled, allocated or changed offers
have `paymentInstruction: null`. A current-state read is not an irrevocable reservation.

Once the private prepare RPC is invoked, a timeout, invalid response, subsequent
permission failure or lost result can follow a committed checkout. The gateway
therefore returns `checkout_outcome_unknown` with the original request key. It never
retries automatically, invents a new key, cancels the order, or claims that nothing
changed. Same-user/club reauthentication can explicitly retry the original operation.

The strictly compiled TypeScript reference client and recovery coordinator require
an external OS-protected credential supplier and durable recovery store with atomic
compare-and-set and a process/isolate-safe lock. `begin` verifies saved operation
state before POST; `restore` never POSTs; `resume` retains the original key and tier.
Response loss or a post-response storage failure leaves the pending operation
recoverable. Pending operations cannot be silently replaced by another checkout.

**No Android/iOS secure-store implementation, platform lock, Flutter repository
integration or handset dialer action is supplied by this batch.** In-memory stores
in the tests are synthetic fixtures, not approved production storage. The API is not
a browser-cookie authentication interface.

## 5. Cross-database revocation remains a release gap

The gateway's identity reads and checkout commit occur in different databases.
A regression intentionally revokes the session between the final pre-write identity
check and the checkout commit. The checkout can exist while the gateway withholds
its result as unknown. This is an observed limitation, not a passing claim that
pre/post checks create a distributed transaction. A session may also change after
the last read. Checkout itself grants no paid membership, but approved cross-database
revocation semantics are still required before real-client release.

Payment receipts are explicitly historical: `membershipAtAllocation` and
`historical: true` do not attest current membership access. Administrative suspension
is preserved by the unchanged allocation core. Payment authenticity remains the
separate trusted ingestion/reconciliation service's responsibility.

## 6. Executed verification

| Test group | Passing tests |
| --- | ---: |
| Gateway, projections, HTTP, client, recovery, configuration and contract | 160 |
| Preserved payment allocation and membership checkout regressions | 432 |
| Preserved current authentication, delivery and HTTP regressions | 77 |
| Reused installer and rollback regressions | 33 |
| **Total targeted tests** | **702** |

All final groups had zero failures, cancellations or skipped tests. Seventeen
JavaScript/JSON syntax or parse checks, strict TypeScript compilation and the
applicable disabled-configuration checks also passed. Contract tests use the existing
OpenAPI security inheritance and supported response shapes; this is not a general
OpenAPI compliance certification.

After saving to Drive, the twenty downloaded source files were substituted into a
separate scoped checkout. All **669 code tests** passed again: 160 gateway, 432 payment,
and 77 authentication tests. Repeated executions are not double-counted in 702.

The integration tests use the actual current IdentityService, MembershipCheckoutService
and PaymentAllocationService with two separate local SQLite databases and genuine
cryptography. They cover successful login-to-checkout-to-evidence-to-allocation-to-
receipt flow, incorrect ownership, revoked/rotated credentials, safe historical
replay, configuration change, unknown writes, and lack of financial effects at checkout.

The verifier was executed in groups: long combined invocations exceeded the tool's
execution window. Source trials and every test group were completed separately with
unchanged assertions, and the final group logs and summary are included. An interrupted
runner invocation is not represented as a successful full run.

Environment: Node 22.16.0, Python 3.13.5, TypeScript 5.8.3, SQLite 3.49.1.
Service bindings, edge metadata, rate limits, identities, phones and payment evidence
are synthetic. No live Cloudflare D1/workerd, real provider, signed mobile app,
physical device, complete Flutter/Next.js/pgTAP run or production capacity test was
performed. Dart >=3.10 and Flutter >=3.38 requirements remain unchanged.

## 7. Source application, preservation and rollback

| Local starting state | Changes | Already matching | Result |
| --- | ---: | ---: | --- |
| Partial Drive source at continuation | 12 | 8 | Apply, repeat and rollback pass; starting bytes restored. |
| Some continuation files already saved | 6 | 14 | Apply, repeat and rollback pass; existing additions preserved. |
| Completed module already matching | 0 | 20 | No source mutation. |

The source reconstruction populated with actual Drive downloads reports zero
outstanding changes and twenty already matching. Unknown edits still stop the
installer. It performs no network, SQL, payment, account or deployment operations.
Source writes are individually atomic, not a multi-file filesystem transaction;
stop source editors/builds during local application.

The pre-change archive contains seventy scoped files: sixty upstream reference
files recovered from the existing same-day Batch9 reference archive, plus ten
original gateway files downloaded from Drive. This is not a complete fresh monorepo
export, financial backup, identity export or object-storage recovery. Original
source IDs/hashes and the distinction between fresh downloads and preserved archive
context are retained. No real identity/payment data, font, dependency cache, token
or production database file is distributed.

## 8. Saved destinations and reproducibility

Source: `AFRICLUB/cloudflare/supporter-membership-api/`.
Delivery: `AFRICLUB/output/refactor-2026-09-26/batch9-supporter-membership-api/`.
The source registry lists every path, actual Drive ID, size and matching downloaded
checksum. The final delivery receipt separately records uploaded artifact IDs and
checksums. An upload is not a deployment.

```sh
# From the extracted incremental package; source preflight is read-only.
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-batch9-verification"
```

A checkout matching Drive should need no source changes. Use the existing project
toolchains and allow the verification runner to complete its source trials and tests.
Historical cumulative v1-v4 packages remain preservation artifacts and must not
overwrite newer source.

Remaining work includes native credential/recovery storage and app integration,
explicit handset payment confirmation, browser/staff flows, cross-database revocation,
real catalog/evidence/historical-claim reconciliation, financial exceptions/refunds,
contribution rewards/referrals, ticket/shop/group commands, monitoring/retention,
complete device/application acceptance, final backup and missing-media recovery,
and controlled one-writer cutover. No production or economic approval is implied.

## Source and external guidance

Repository authority is recorded in the preserved source maps and the continuation
provenance register. External guidance is distinct from the execution evidence:
- https://developers.cloudflare.com/workers/runtime-apis/rpc/
- https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/
- https://developers.cloudflare.com/d1/worker-api/d1-database/

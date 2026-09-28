# Operator public-source publication — staging candidate

This source package implements the missing **operator authentication and approval
boundary** around the immutable Rayon public-source publisher. It is not supporter
OTP, a new financial backend, a live deployment, or approval to retire Supabase.
The five-club inventory is unchanged; the supplied database binding serves only
club 24, `rayon_sports_rw`. Other clubs require separate verified mappings and
isolated deployments, not a caller-controlled database selection.

## Components and trust boundary

`src/index.mjs` is a standalone API Worker with no Static Assets and no direct
D1/R2 bindings. It accepts only runtime-authenticated human identities from
`ctx.access`, checks the exact Access audience and account, and passes the stable
`user_uuid` through a private service binding. Email addresses, raw JWT headers,
caller-supplied actor IDs and service-token identities never grant approval.
Missing runtime authentication fails closed; there is no fallback bypass.

The sole binding is `AuthorizedPublicSourcePublisher`, implemented in
`../rayon-public/src/authorized-publication-worker.mjs`. Its HTTP interface is
always 404. The gateway must be its only approved caller. RPC arguments alone are
not cryptographic identity proofs: the capability is the private service binding
from the authenticated gateway. Do not expose it to arbitrary Workers and do not
bind to the earlier `PublicSourcePublisher` adapter. Keep that older publisher
disabled. Access context is not propagated over service bindings, so the gateway
must be directly invoked by the Access-protected request, not proxied behind a
framework's assets router.

The database authorization joins a principal, a club-specific grant, and a tenant
mapping. All start disabled. Review and publication permissions are separate;
publication requires both. The same authorized person reviews and confirms: this
is **not a two-person approval system**. A grant, principal, or mapping change
invalidates pending reviews, including revoke-and-reenable cycles.

## API and confirmation sequence

The complete versioned API is `contracts/openapi.json`; the strict TypeScript
browser adapter is `client.ts`. Supported operations:

1. `GET /v1/admin/clubs/24/public-source/head` returns the current snapshot ID.
2. `POST .../reviews` accepts exactly `snapshotId`, `expectedPreviousId` (or null)
   and an external review-evidence reference `reviewRef`. It seals and verifies
   the complete candidate and media, rechecks authority, and returns a review ID,
   counts and expiry. This does **not** publish. The evidence reference must point
   to the operator's actual content/rights review; a valid string is not proof
   that editorial review occurred.
3. After an explicit human confirmation, `POST .../publications` accepts only
   `reviewId` and a durable `Idempotency-Key` header. The snapshot, prior head,
   actor, club, permission revisions and five-minute review expiry are fixed by
   the server-side review. It checks authority again during the commit, rejects
   older capture time, and commits the new head, consumed review, immutable
   receipt and audit event in one D1 batch.
4. `GET .../publications/{operationId}` returns an authorized actor's receipt.

All POSTs require an exact configured HTTPS `Origin`, the
`X-AFRICLUB-Action: publish-review` header, JSON, and at most 4096 body bytes.
No cross-origin allowance is emitted. Per-principal/club controls allow 30 calls
per minute; configure upstream WAF/Access abuse controls separately.

The client does not automatically confirm or retry writes. Persist its generated
idempotency key before sending. After a timeout or uncertain response, keep the
same review and same key: the API returns the durable receipt of an already
committed publication. Do not create a fresh review/key to retry an unknown
outcome. Expired or revoked authority blocks further action, including receipt
replay. Status is a receipt, not a claim that its snapshot is still current.

`client.ts` is available for the existing admin PWA, but the admin UI was not
rewired in this batch. Do not turn this API on merely because the adapter compiles.
The operator UI must show the exact reviewed source/hash and prior head, preserve
request state on network loss, and require explicit confirmation.

## Source and deployment prerequisites

Apply the cumulative source patch with its hash-checked installer. In the target
public-source database, replay migrations `0001`, `0002`, `0003`, then the new
`0004_operator_publication.sql` using the governed migration runner. Preserve
existing applied migrations. No new migration was executed remotely in this
batch. The private publisher imports the earlier `snapshot-publication.mjs`;
deploying only this batch without that module and schema is incomplete.

Both shipped Wrangler templates have `workers_dev: false`, preview URLs disabled,
no public routes, blank account/audience/origin, and both runtime switches false.
No operator or grant is automatically installed. They point to the already named
Rayon staging D1/R2 resources; existence and access must be reverified remotely.

`node cloudflare/operator-api/scripts/prepare-enrollment.mjs enrollment.private.json`
produces INSERT-only, **disabled** enrollment SQL. It never executes SQL or grants
permissions. Its exact private input fields are `principalId`, `accessAccountId`,
`accessSubject`, `clubId`, `clubSlug`, `sourceClubId`, `expiresAt`, `enrollmentRef`.
Use the verified Access account and user UUID, the exact imported source tenant,
an independently allocated internal principal UUID, and an expiry within seven
days. Keep private plans outside tracked source. Existing keys deliberately fail;
never use replace/upsert to overwrite another enrollment. Grant enabling and any
extension of access remain separately authorized, auditable operations by a
privileged operator. No enrollment/role-administration HTTP API is provided.

Run the offline template check:

```sh
node cloudflare/operator-api/scripts/check-deployment.mjs
```

To prepare staging, configure a standalone HTTPS custom domain for the gateway,
protect all its ingress with Access, populate exact audience/account values in
both Workers, and independently enroll the permitted operator and source mapping.
Confirm private binding exclusivity, actual authenticated identity shape,
D1/R2 permissions and schema readback before enabling either switch. The Access
user UUID is returned by `ctx.access.getIdentity()`, not a property on the outer
context. Configure a short staff session and the appropriate authentication
policy. Do not log tokens, raw identity responses, private content or credentials.

`check-deployment.mjs gateway.private.json publisher.private.json --ready` checks
resolved configuration only; it rejects wrong entrypoints, storage resources,
ambiguous overrides, assets routers, simulated Access identity and mismatched
account/audience/origin. It always reports live Access/runtime and release
verification as false. A real authenticated/unauthenticated staging smoke test,
revocation test, D1 concurrency/failure test and binding audit are still mandatory.
The private publisher must have no HTTP domain; enable only the gateway's reviewed
same-origin custom domain. Do not set `access.dev` in deployment configuration.

## Local verification

From repository root, with Node supporting Web Crypto and `node:sqlite` and a
TypeScript compiler available:

```sh
node --test cloudflare/operator-api/tests/*.test.mjs
node cloudflare/operator-api/scripts/compile-client.mjs
node cloudflare/operator-api/scripts/check-deployment.mjs
```

These tests execute the actual gateway/service code with genuine local SQLite
statements, simulated runtime Access/RPC and an R2 test double. They cover spoofed
identity, wrong club/roles, CSRF, malformed requests, immutable records, revocation
races, competing heads, duplicate requests, rollback at every batch statement,
post-commit response loss, media/hash mismatch, SDK and deployment checks. They
are **not workerd, real Cloudflare D1/R2, live Access or complete admin PWA tests**.

No automatic deployment or runtime download is performed. In a separately
prepared pinned Wrangler environment, verify the WorkerEntrypoint wrapper and
multi-Worker service binding. Cloudflare documents `access.dev` for simulating
identity locally; local simulated identity does not establish real authentication.
Record actual installed versions and separate runtime evidence before release.

## Operational recovery and retention

Disable the gateway or publisher switch to stop new publication requests. Revoke
the database grant to stop the operator and invalidate their reviews. Neither
action automatically withdraws already published content; existing active content
expires under the reader's snapshot freshness policy. Emergency withdrawal needs
a separately authorized content response, not an undocumented financial rollback.

Historical receipts/reviews/audit rows are retained by database triggers. No
retention purge is provided: define retention, privacy and archival requirements
before production. External audit export, operator enrollment auditing, alerting,
and administrative UI integration still need operational completion. Do not drop
the old database or change any money/entitlement writer during this work.

## Official implementation references checked 26 September 2026

- Runtime Access identity and its Static Assets/RPC limitations:
  https://developers.cloudflare.com/workers/configuration/cloudflare-access/
- Access user identity fields:
  https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/application-token/
- D1 batch transaction behavior:
  https://developers.cloudflare.com/d1/worker-api/d1-database/
- Private Worker RPC:
  https://developers.cloudflare.com/workers/runtime-apis/rpc/

These references describe platform behavior, not verification of this deployment.

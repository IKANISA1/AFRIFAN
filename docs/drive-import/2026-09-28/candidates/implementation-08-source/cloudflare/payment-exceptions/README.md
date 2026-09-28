# AFRICLUB payment-exception review service

**28 September 2026. Source implementation and local tests; disabled, not deployed.**

This adds a club-scoped operator case workflow to the existing Cloudflare operator
API. It tracks late, partial, duplicate, ambiguous, missing-reference,
cancelled-order and refund-request cases. It does **not** confirm a payment,
allocate funds, execute a refund, post FET, change an order, activate membership,
send a provider instruction or establish that money did not move.

## Integration boundary

`cloudflare/operator-api/src/index.mjs` dispatches the four new API routes to
`payment-exceptions.mjs`. The gateway derives the operator from its existing
Cloudflare Access context. Its private `PAYMENT_EXCEPTION_CASES` binding calls
`PaymentExceptionCases` in `src/worker.mjs`. The browser cannot submit an identity.
`client.ts` is the strictly compiled client; a production admin screen is not
included or claimed. Existing publication routes retain their prior intent header.

Use a **new isolated case D1 database**. The migration creates only `px_*` case
metadata, operator grants and event tables. It does not resolve or run either
conflicting payment-allocation `0003` migration. Never point this binding at the
allocation, identity or public-content database.

Only the reviewed gateway should have the private RPC binding. Service bindings
do not carry Access identity automatically: this service trusts the configured
gateway as an identity issuer, then verifies account, audience, active/expiry
state and club-specific grants against its own database. A compromised gateway or
additional privileged bound worker is outside that trust boundary. Database ACL
changes take effect at the mutation boundary; external identity-provider
revocation is not claimed to be synchronous with a case-database transaction.

## State, concurrency and authority

| Action | From | To | Authority |
|---|---|---|---|
| open | absent | open | maker |
| triage | open | investigating | maker |
| propose | open / investigating | awaiting_review | maker |
| approve | awaiting_review | reviewed | checker, not proposer |
| reject | awaiting_review | investigating | checker, not proposer |
| close | reviewed | closed | maker |
| reopen | closed | investigating | maker |

A proposal records one disposition: `no_financial_change`,
`refer_reconciliation` or `refer_refund_review`. Even an approved refund referral
is not authorization or evidence of a refund. A case being closed means only that
its review workflow is closed. Reopen and rejection clear the prior review state.

Every command supplies an explicit `expectedRevision` and a UUID
`Idempotency-Key`. The SQL INSERT trigger checks the current revision, transition,
actor, role, tenant and settings immediately before creating an immutable event.
Projection changes happen in that same SQL statement. A stale review receives
409; it cannot approve a replacement proposal. Two roles on one account do not
permit self-review.

The uniqueness scope is club + actor + operation ID. An exact-key, exact-body
retry returns the original event and the current head separately; a changed body
conflicts. Lost responses do not cause automatic retries or replacement keys.
The client marks uncertain write outcomes explicitly. Retry an uncertain command
only with its original key and exact payload. A later 401/403 cannot prove a prior
write did not commit. The event journal can retain a committed event after access
is revoked and the response is withheld.

Every service query starts a new `first-primary` session. This does not make a
multi-query read an atomic snapshot, nor establish Cloudflare performance or
capacity. List results are bounded to 50, keyset-paginated, and explicitly
`snapshot:false`. History is bounded and ordered by revision.

## API

Base path: `/v1/admin/clubs/{clubId}/payment-exceptions`.

- `GET /` lists cases; optional `after` UUID, `state`, `limit` 1–50.
- `GET /{caseId}` returns the current case.
- `GET /{caseId}/history` takes `after` revision (default 0) and `limit` 1–50.
- `POST /{caseId}/commands` writes a command.

The base route has **no trailing slash**; `/` above denotes the base itself.
All writes require a same-origin browser request, `Content-Type: application/json`,
`X-Africlub-Action: payment-case-review`, `Idempotency-Key: <UUID>`, and an
Access-authenticated human operator. The gateway accepts only the exact body
shape below, with a 4 KiB body limit. Unknown keys, raw SMS, phone numbers,
free-form notes and body-supplied identity fields are rejected.

```json
{
  "expectedRevision": 0,
  "action": "open",
  "detail": {
    "reasonCode": "support_request",
    "evidenceDigest": null,
    "category": "ambiguous",
    "orderId": "00000000-0000-4000-8000-000000000001",
    "evidenceId": null
  }
}
```

The example is synthetic. Every detail requires `reasonCode` and
`evidenceDigest` (null or lower-case SHA-256). `open` additionally requires
`category`, `orderId` and `evidenceId`, with at least one non-null UUID reference.
`propose` additionally requires `disposition` and a non-null digest. `close`
requires a non-null digest. Other actions accept only the two base detail fields.
See `contracts/api.json` and `src/policy.mjs` for exact enums.

Order/evidence references are **not verified against the financial database**.
Responses state `referencesVerified:false`, `financialEffect:'none'`. A hash does
not prove a source is authentic. Evidence retrieval, provenance checks, financial
reconciliation and approved refunds remain separately controlled work.

## Local verification

From the repository root, with Node supporting `node:sqlite` and TypeScript's
`tsc` available:

```sh
node --test cloudflare/payment-exceptions/tests/*.test.mjs
node cloudflare/payment-exceptions/scripts/check-deployment.mjs
node cloudflare/operator-api/scripts/check-deployment.mjs
python3 tools/scripts/check_migration_lineage.py --root .
(cd tools/scripts && python3 -m unittest -v test_migration_lineage)
```

The tests execute the SQL and triggers with real local SQLite, the actual
operator gateway using synthetic Access context/private bindings, the compiled
TypeScript client, commit-response-loss injection, and separate worker-thread
SQLite connections. They are **not** a workerd/D1, real Access, browser, mobile,
provider or financial acceptance run. Inspect the delivery verification file for
actual runtime versions and current results rather than historical test totals.

## Controlled staging setup — not performed by this delivery

Keep the templates disabled until security and platform owners approve setup.
Restrict the Drive source folder and use a protected canonical repository.
Review and create a distinct case database; apply only this module's migration to
that database. Configure the reviewed database ID, Access account/audience,
operator subjects, expiry timestamps, club rows and explicit reader/maker/checker
grants. Do not enroll the synthetic test identities. Keep `px_settings.enabled=0`
until the readback of those ACL records is approved. Then independently review
the service/gateway bindings, runtime environment, same-origin Access policy and
both runtime switches before enabling the SQL control. Templates are not a
production deployment manifest; the deployment check only validates their
disabled state, not remote Access policy, database isolation or release approval.

No production SQL grant script is provided with invented identities. Grant and
revocation audit, retention/erasure, backup/restore, rate limits, monitoring,
operator UI integration, evidence verification, independent security testing and
live D1 acceptance must be completed before release. Append-only SQL is not
protection against a privileged database administrator changing the schema.

## Primary platform references

- https://developers.cloudflare.com/workers/configuration/cloudflare-access/
- https://developers.cloudflare.com/workers/runtime-apis/bindings/service-bindings/rpc/
- https://developers.cloudflare.com/d1/worker-api/d1-database/
- https://developers.cloudflare.com/d1/best-practices/read-replication/

These references guide API use; they are not evidence of this app's deployment.


## Implementation 04: operator case workspace and read-only recovery

The existing Access gateway now serves `/operator/clubs/{clubId}/payment-exceptions`
when all three `OPERATOR_API_ENABLED`, `OPERATOR_UI_ENABLED` and
`OPERATOR_CASES_ENABLED` switches are explicitly enabled in a reviewed environment.
The shipped template remains disabled. The page is returned directly by the Worker;
there is no Static Assets routing hop and no supporter-token substitute for staff Access.

The same-origin case client uses two additive read endpoints:

- `GET /v1/admin/clubs/{clubId}/payment-exceptions/session`: current read/maker/checker hints.
- `GET /v1/admin/clubs/{clubId}/payment-exceptions/operations/{operationId}`: the current
  operator's original immutable event and latest case head, with different revisions kept distinct.

Hints never authorize a command. Existing SQL mutation-time authorization and expected
revision checks remain authoritative. A missing operation is not evidence that an in-flight
command cannot later commit. The UI can check the original result without POSTing and can
retry only after explicit acknowledgement, with the same original key and payload.
There is no automatic retry on reload, app resume, polling, or network recovery.

The page provides bounded case/history pagination, seven case commands, a separate
confirmation step, maker/checker separation, stale-review rejection, fixed error messages,
revoked-view cleanup and a pending-operation view. After a recorded command it clears the
old loaded history; the operator can explicitly refresh current case/history using reads.

Pending metadata is stored under an operator-and-club-scoped localStorage key. It contains
opaque IDs, operation/revision, enumerated reason/category/disposition and optional evidence
digest, not credentials, phones, raw SMS or free text. This is still private operational
metadata, not anonymous data. Approved retention, account erasure and shared-device policy
remain required. Storage corruption/quota failures block new commands. There is no claim
of cross-tab localStorage atomicity: server revision/idempotency checks remain necessary.

Build the checked-in UI assets with `node cloudflare/operator-api/scripts/build-ui.mjs`.
Use `--check` to detect stale bundles. The existing token/style source is reused. Source
labels, focus handling and responsive styles do not constitute rendered accessibility or
visual approval. The browser harness in `tests/browser/` is loopback-only and synthetic;
its current execution was blocked by administrator navigation policy before rendering.

This workspace is integrated into the **Cloudflare operator gateway**, not into every
Next.js/admin launcher or the five Flutter apps. It never confirms payments, executes
refunds, changes paid membership, resolves financial references or proves settlement.

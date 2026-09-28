# Authentication-code delivery — opt-in source candidate

Date: 26 September 2026. This is an optional, private WhatsApp authentication-code
transport for AFRICLUB. It adds provider template checks, bounded responses and a
durable dispatch claim. It does not provision a sender, approve a template, enroll
users, grant consent, apply SQL, send a real message, or deploy a service.

## Source authority and integration

The latest inspected Drive `cloudflare/supporter-auth` already implements leased
WhatsApp delivery and account-erasure request handling. That implementation differs
from the historical cumulative v4 archive. This batch preserves it and changes only
`src/delivery.mjs` to select this transport explicitly. Unset `AUTH_DELIVERY_MODE`
continues the existing `legacy` path. `private-deduplicated` requires the private
`OTP_DELIVERY` binding; an unknown mode or missing binding stops before acquiring a
lease. No private-mode failure falls back to the legacy provider.

The existing public API, ten-minute code lifetime, identity/session schema, erasure
outbox, native client and production flags are unchanged. The six-field `deliver`
method also supports the historical v4 candidate's private contract; it is NOT a
reason to overwrite newer Drive authentication code with that archive.

## Private contract

Bind `OTP_DELIVERY` on the trusted identity worker to the named
`AuthenticationCodeDelivery` entrypoint. No public HTTP endpoint is exposed: the
ordinary and named HTTP handlers return 404. Worker-to-Worker RPC possession is the
trust boundary; request fields alone are not proof of identity. Bind no unrelated
worker. Keep direct provider credentials only on the private delivery worker.

`deliverWithReceipt` accepts exactly `challengeId`, `clubId`, `phone`, `code`,
`expiresAt`, `channel`, `template`. The queue supplies the challenge/club/expiry and
server-selected template from its current row, not from client authority. Channel
must be `whatsapp`; the code is six ASCII digits, the number E.164, and expiry at
most ten minutes away. First submission requires at least 15 seconds remaining.
The route's approved template name must match the queue's template. Its receipt is
`{accepted:true, challengeId, messageId}` only after the acceptance is stored.
An unconfirmed attempt returns false or a sanitized error; never a forged receipt.

## One durable claim, no automatic second provider attempt

An isolated D1 table stores a unique challenge claim before contacting Meta. A
purpose-separated HMAC commits the request and selected provider route. The table
contains no raw phone, code, token or request body. These HMACs and identifiers are
still linkable data and need a reviewed retention policy; they are not anonymous.

A successful response is accepted only when its recipient matches the exact
intended number, there is exactly one message ID, and no contradictory error or
held status is present. Provider acceptance is NOT handset delivery, receipt by
the intended human, authentication success or account authorization.

The whole metadata lookup/send has a six-second deadline. Redirects are refused,
JSON is limited to 16 KiB, errors are sanitized and the provider origin is fixed.
A timeout, lost response, malformed reply or failed durable receipt write never
permits a new external POST for the same challenge. The existing auth queue may
retry its internal drain, but this adapter only replays a known immutable receipt
or returns unconfirmed. A configuration change invalidates receipt replay.

There is an intentional availability trade-off: a crash after reserving but before
sending can strand an unsent code. The claim must not be deleted to retry it.
Fresh verification requires an explicitly requested new challenge under the
existing rate limits. This is not end-to-end exactly-once delivery. No transaction
can atomically span the external provider and the two databases.

## Reviewed configuration and secrets

The shipped Wrangler file has no public routes, no schedule, no outgoing service
bindings, disabled invocation logging, a placeholder isolated dispatch database,
an empty Graph API version and no enabled club routes. It is disabled by default.

Required secrets: `WA_ACCESS_TOKEN`, `DISPATCH_HMAC_KEY` (a separately generated
32-byte lower-case hexadecimal HMAC key). Do not store secrets in Wrangler vars,
source, reports, UI or logs. Key rotation needs a reviewed migration: changing the
commitment key invalidates old matching receipts. There is no automatic rotation.

Set `DELIVERY_ROUTES_JSON` to reviewed entries with exactly:
`clubId`, `phoneNumberId`, `templateId`, `templateName`, `language`, `reviewRef`,
`reviewExpiresAt` (UTC epoch milliseconds, within seven days). Supported languages
are the explicit English editions `en`, `en_US`, `en_GB`. There are no hardcoded
live account IDs, default provider version, default sender or fallback templates.

Before each attempted send, GET template metadata and require the configured ID,
name, language, AUTHENTICATION category and APPROVED status. This check does not
prove template button anatomy, code expiry wording, sender ownership, consent,
provider billing/capacity or current permission scope. Validate those separately
against the real approved provider account before enabling. The body plus index-0
copy-code URL button payload follows the inspected repository `whatsapp.mjs`.

## Verification commands

From a matching checkout, with Node supporting `node:sqlite` and Web Crypto:

```sh
node --test cloudflare/auth-code-delivery/tests/*.test.mjs \
  cloudflare/supporter-auth/tests/identity.test.mjs \
  cloudflare/supporter-auth/tests/delivery.test.mjs \
  cloudflare/supporter-auth/tests/security-http.test.mjs
node cloudflare/auth-code-delivery/scripts/check-deployment.mjs
```

The tests use genuine local SQLite/cryptography and synthetic network responses.
They do not run workerd, real D1/R2, a live Meta sender, physical phones or the full
Flutter/Next.js applications. Test counts are in the delivery report, not approval.
The legacy direct provider's prior behavior is intentionally not changed by this
optional transport. Browser and full application release gates remain required.

`inspect-provider.mjs` is read-only and defaults to no network. An explicit
`--execute`, with actual private environment configuration, performs only metadata
GETs, never message POSTs, template creation or billing changes. This command was
NOT run with a live account during this batch.

## Staging activation and recovery

Preserve the existing identity database. Provision a new isolated dispatch D1 and
apply this module's own `0001_dispatch_claims.sql` through the approved staging
process. Verify migration, binding exclusivity, secret isolation, configured API
version and approved templates. Enabling is a separately reviewed action, not an
installer effect. See `../supporter-auth/PRIVATE_DELIVERY_INTEGRATION.md`.

Run live staging tests for accepted/rejected/ambiguous outcomes, concurrent drains,
DB interruption, provider account restrictions and downstream code verification.
The private service kill switch stops new provider work; do not downgrade to legacy
while unresolved private challenges are still queued, because legacy transport
would bypass their private deduplication claims. Freeze/drain or expire those
challenges under a governed recovery procedure. Preserve claims/receipts and audit
history. Retention deletion, webhook delivery-status processing, SMS fallback,
provider-spend alerts and online key rotation are not implemented here.

## References and limitations

Repository payload authority: current
`cloudflare/supporter-auth/src/whatsapp.mjs` and queued `delivery.mjs`, read on
26 September 2026. The bundle retains their exact hashes.

Platform behavior references checked during implementation:
- https://developers.cloudflare.com/d1/worker-api/d1-database/
- https://developers.cloudflare.com/workers/runtime-apis/rpc/
- https://www.postman.com/meta/whatsapp-business-platform/folder/huymv7d/templates

These sources are not evidence of a successful deployment, real code delivery,
legal compliance, complete migration or release approval.

## Batch 6 — signed status companion (26 September 2026)

The optional source implementation in [DELIVERY_RECEIPTS.md](DELIVERY_RECEIPTS.md)
now supplies signed provider-status intake, exact recipient/dispatch correlation,
private status reads and bounded reconciliation. It remains disabled and has not
been deployed or tested with a live provider. The earlier statement that status
processing is unimplemented describes the original transport-only batch; alerts,
retention/erasure, subscription approval and real staging acceptance remain pending.
The original acceptance ledger and all no-resend rules above are preserved.

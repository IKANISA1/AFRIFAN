# Signed authentication-delivery receipts — disabled source candidate

Date: 26 September 2026. This increment extends the current AFRICLUB private
WhatsApp code transport. It does not replace the supporter identity service,
change prediction economics, approve a provider subscription, send a message,
apply a remote migration or deploy a Worker.

## Existing authority and new scope

The existing `service.mjs` remains the sole owner of provider submission and its
immutable acceptance receipt. The optional `StatusAwareDeliveryService` adds an
immutable recipient/account/sender binding before that service attempts a send.
It does not create another provider sender, silently resend an unknown outcome,
or retroactively attribute an old unbound dispatch.

The Batch 5 `supporter-auth/src/delivery.mjs` integration is now installed in Drive
with its original file ID preserved. Unset `AUTH_DELIVERY_MODE` still selects
`legacy`; `private-deduplicated` remains an explicit server choice. This new receipt
work does not enable either path or alter the current auth schema/client protocol.

## Three separate service boundaries

| Surface | Responsibility | Deployment template |
| --- | --- | --- |
| Private tracked sender | Pre-send receipt binding, then delegation to the existing deduplicated sender | `wrangler.status-aware.staging.jsonc` |
| Public signed callback | Provider verification handshake, HMAC-authenticated status intake, optional bounded pending reconciliation | `wrangler.receipts-webhook.staging.jsonc` |
| Private reader | Information-only status for an exact club/challenge | `wrangler.receipt-reader.staging.jsonc` |

All templates are disabled, have no live account/database IDs or credentials,
and refer to the same placeholder **dispatch D1**, not identity, public-content,
member, ticket or financial storage. Private entrypoints return 404 for HTTP.
The webhook is a new, independently configured public ingress only after approval.
The existing private sender's normal HTTP endpoint stays closed.

The private reader trusts possession of the reviewed service binding. Its caller
must authenticate and authorize the user/operator, club and challenge ownership.
The request's club ID is not an identity proof. Do not expose it through a generic
public RPC proxy or let unreviewed Workers hold the binding. No operator UI or
supporter API currently consumes the reader; that integration remains unfinished.

## Exact status intake

`GET /webhooks/whatsapp/auth-delivery` handles only the three standard verification
query fields. A matching independently provisioned verify token returns the numeric
challenge. This handshake is not authentication for POST notifications.

`POST` requires `X-Hub-Signature-256`. Verification uses HMAC-SHA-256 over the original
request bytes with the Meta **app secret**, before JSON parsing. A messaging access
token or URL verification token cannot substitute for the app secret. Web Crypto
performs signature comparison. The configured origin and path are exact, cookies
and browser Origin headers are rejected, and no CORS allowance is emitted.

Input limits are deliberate pilot constants: 64 KiB, a three-second body read,
five account entries, twenty changes and twenty known-route status objects per
request. A mandatory edge limiter protects intake. Error responses are sanitized.
Unmatched account/sender routes, unknown status types and inbound message content
are ignored rather than becoming application commands. Malformed supported-envelope
payloads fail. Oversized provider batches need review or a bounded queue design;
this implementation does not split an oversized signed body automatically.

Known observations are sent, delivered, read, failed and deleted. The parser retains
provider/message identifiers, a purpose-separated keyed recipient commitment,
status/times and numeric error codes only. Raw phone numbers, OTPs, inbound message
content, free-text errors, webhook bodies and credentials are not persisted or
logged by this code. Signature verification necessarily handles the raw body
transiently in memory. Upstream request/query logging requires separate review,
including the GET verification token in the provider handshake.

## Correlation, order and interrupted operations

Semantic event hashes deduplicate repeated notifications. Event inserts and any
available exact links use one D1 batch; success is acknowledged only after that
batch returns. A response lost after commit can be retried without a second event.

A callback can arrive before the sender commits its provider message ID. It remains
unlinked until an immutable **accepted** dispatch exists. Linking requires that
exact provider message ID plus the pre-send club/account/sender/recipient/key-version
binding and a bounded timestamp relationship. A database trigger repeats those
conditions. There is no matching on phone suffix, display name, guessed challenge,
or callback-supplied club. Unknown/rejected dispatches cannot be converted into
accepted ones by a callback, even when the provider signature is valid.

The optional reconciler inserts at most 100 eligible links per invocation. It
selects eligible rows before applying the limit so earlier unrelated pending rows
do not starve a later exact match. The row limit does not establish a bounded total
scan cost, real D1 capacity or production latency. All scans need workload evidence.

Out-of-order observations are retained. The information-only projection does not
regress read/delivered to sent. A failed event combined with delivered/read produces
`conflicting`, retaining both facts instead of deleting evidence. A deleted event
is a separate provider observation, not an account-erasure command. Private reads
fail closed above 200 observations rather than silently truncating history.

A callback timestamp is provider-reported data, not a trusted replay nonce. The
eight-day intake horizon and five-minute future tolerance are local policy choices;
deduplication is the replay control. Events outside that horizon are acknowledged
but ignored. Resending an old signed payload does not establish recent identity.

## Limits and privacy boundaries

Provider acceptance, handset status and successful code verification are distinct.
No receipt handler creates/revokes a session, activates membership, moves funds,
issues a ticket, adjusts FET or overwrites the dispatch acceptance record. A reported
read does not prove that the intended person authenticated.

Known sender routes may also carry unrelated provider traffic. Unlinked, minimized
status metadata is retained to cover callback-before-acceptance races. It may never
match an authentication dispatch. Do not configure a shared sender indiscriminately:
review its traffic, tenancy, retention and storage growth. Incoming message content
is ignored, but sender/message IDs and keyed recipient values are still linkable
personal data, not anonymous information. No automatic purge or complete erasure
workflow is provided; immutable-evidence retention requires accountable review and
a later governed archival/deletion design before release. Online key rotation,
alerts, dashboard/export and provider-spend monitoring remain unfinished.

## Keys and configuration

The sender, webhook and reader use the same independently generated
`RECEIPT_HMAC_KEY` (32 random bytes, lowercase hexadecimal) and
`RECEIPT_KEY_VERSION=1`. The sender rejects reuse of its `DISPATCH_HMAC_KEY` for this
purpose. Key values are not included in source or configuration templates. The
webhook separately receives `WA_WEBHOOK_APP_SECRET` and a distinct random
`WA_WEBHOOK_VERIFY_TOKEN`. The webhook/reader do not need `WA_ACCESS_TOKEN` or the
dispatch commitment key. Changing receipt keys without a mapping/reconciliation
plan breaks correlation; hot key rotation is not implemented.

`RECEIPT_ROUTES_JSON` contains one to five exact objects:
`clubId`, `businessAccountId`, `phoneNumberId`. A sender can be shared across clubs
only under the same account; the accepted dispatch and binding resolve actual club
ownership. These routes must agree across all three configurations and with the
existing sender's phone-number routing.

The template checker permits only the named Workers, isolated database and explicit
variables, rejects plaintext credentials/router overrides, and checks exact webhook
custom-domain ingress in ready mode. It requires the optional one-minute bounded
reconciliation schedule for the complete ready configuration. The 600/minute edge
limit is a pilot local ingress setting, not a globally exact or approved capacity.
The source checker cannot verify deployed bindings, subscription ownership, secrets,
retention, sender grants, genuine signatures or release approval.

## Forward migration and staging order

1. Preserve a restorable dispatch database snapshot. Keep all new runtime flags off.
2. Apply existing `0001_dispatch_claims.sql`, then the new forward-only
   `0002_delivery_status_receipts.sql` using the governed staging migration runner.
   Never replay a CREATE migration blindly against existing tables; use the recorded
   migration ledger. This turn adds SQL source but applies no remote SQL.
3. Provision the shared receipt key and approved route mapping in isolated staging.
   Bind the auth queue only to the reviewed private tracked-sender entrypoint.
   Existing unbound challenges retain the old path until drained/reconciled; they
   cannot be retrospectively stamped with a newly supplied recipient.
4. Configure a dedicated callback origin. Determine the provider application's
   existing webhook ownership before subscribing. Do not overwrite another product's
   callback or disable a current subscription. A reviewed fanout integration may be
   required if the account already routes other message/webhook types elsewhere.
5. Verify real provider handshake and signed callback bytes, wrong-signature denial,
   shared-sender isolation, early callbacks, duplicate/reordered events, DB failures,
   revocation, message acceptance correlation and the private reader's authenticated
   caller. All such live tests are still pending.
6. Enable intake/reconciliation and tracked sending only after independent approval.
   Check retention/storage growth and operational alarms. Enabling sending and
   receiving are separate choices: turning off new sends must not discard remaining
   delivery receipts. No source upload is authorization to enable production.

Changing a tracked sender back to legacy can bypass its dispatch claim protections.
Freeze and reconcile/expire pending challenges before any mode change. Do not delete
claims to retry. New code requests remain explicit under the existing auth limits.

## Verification commands and actual evidence

```sh
node --test cloudflare/auth-code-delivery/tests/*.test.mjs \
  cloudflare/supporter-auth/tests/identity.test.mjs \
  cloudflare/supporter-auth/tests/delivery.test.mjs \
  cloudflare/supporter-auth/tests/security-http.test.mjs
node cloudflare/auth-code-delivery/scripts/check-deployment.mjs
node cloudflare/auth-code-delivery/scripts/check-receipts-deployment.mjs
```

Tests use genuine local SQLite and Web Crypto with synthetic sender/identity data,
signed local payloads, private binding doubles and provider doubles. The queue-to-
receipt-to-code-verification test proves the separate mutation boundaries locally.
No real provider message, subscription or callback was used. WorkerEntrypoint
wrappers are syntax checked, not run in workerd. Real D1 performance, cryptographic
secret configuration, production receipts, full web/mobile builds and device
acceptance remain required. Prior browser policy blocks were not bypassed.

## Primary implementation references

Checked 26 September 2026; these describe platform behavior, not this deployment:
- Meta-authored message status examples and out-of-order delivery notes:
  https://www.postman.com/meta/whatsapp-business-platform/request/rgtfq23/message-status-update-notifications
- Meta public signature-validation example:
  https://github.com/fbsamples/whatsapp-api-examples/blob/main/signature-validation-with-webhooks-payloads/app.py
- Cloudflare Web Crypto:
  https://developers.cloudflare.com/workers/runtime-apis/web-crypto/
- Cloudflare D1 batch/sessions:
  https://developers.cloudflare.com/d1/worker-api/d1-database/

The primary sources do not establish the correctness of every local decision,
compatibility with a real account, legal compliance or release authorization.

# Supporter identity and sessions — isolated migration candidate

This module implements verified-phone sign-in, opaque session credentials, rotation,
revocation, a leased WhatsApp code-delivery drain, and an account-erasure request
outbox. It is **not selected by the existing released Flutter/Next.js clients, not deployed,
and not a replacement for the financial backend**. A separately scoped cookie
portal is now integrated as disabled source in this repository. The existing
Supabase authentication and paid-membership flows remain authoritative. All new
runtime templates are disabled; governed import, bindings and release acceptance
are still required.

## Scope and source contract

The source review covered `packages/core/core_auth/lib/src/auth_repository.dart`,
`user_session.dart`, `rbac_resolver.dart`, and `supabase/functions/send-sms/` plus
`_shared/whatsapp.ts`. Existing authenticated identities use their original UUIDs;
club selection must never come from editable user metadata. WhatsApp remains the
intended phone-code delivery provider. The template payload was ported from the
inspected repository, not independently verified against a live Meta account.

The candidate currently covers verified-phone sign-in and sessions only. The
existing anonymous bootstrap/upgrade, authenticated phone changes, profile CRUD,
notification-device unlinking, account-contact recovery and complete admin-role
migration are **not implemented here**. Do not point released clients at this
candidate or rename this module as a finished Supabase replacement. A verified
supporter identity is not paid membership, permission to operate another club,
Predict authorization, or a financial entitlement.

## Storage and service boundaries

`AUTH_DB` must be a new isolated identity D1 database, never the public-content
snapshot database. Migrate only with both public and private identity workers
disabled. The schema starts with `import_ready=0`, no enabled clubs, no users,
no role grants and no schedules. The API checks the approved import gate and
key version as well as the enabled server-side club mapping. Source identifiers
are immutable. Status/contact changes advance the account epoch; club changes
advance their revision. Disable-and-reenable cycles do not restore old sessions.

Access and refresh credentials contain a session UUID plus 32 random bytes.
The database stores SHA-256 token hashes, not bearer credentials. The code hash
and phone lookup use purpose-separated HMAC-SHA-256. Contact, pending delivery and
short-lived retry credentials use AES-256-GCM with random nonces and associated
data. Configure distinct random 32-byte encryption and HMAC keys as Worker secrets
`AUTH_ENCRYPTION_KEY` and `AUTH_HMAC_KEY`, lower-case hexadecimal. Never put them
in Wrangler vars, app bundles, logs, private plans shared publicly, or this repo.
Both workers must receive the same securely provisioned key version. Version 1
is the only implemented key format. Online multi-key rotation and re-encryption
are still required operational work; replacing the lookup key without a governed
migration will break identity mapping and may create duplicate users.

Every live session check uses the direct D1 binding, not a replica or cached JWT
claim. Queries verify account state/epoch, club state/revision, session revocation
and expiry. `SupporterIdentityVerifier` exposes a private token-introspection RPC;
its HTTP interface is 404. Bind only reviewed command workers. The caller must
still authorize resource ownership, operation, current entitlement and any role.
An introspection result is point-in-time evidence, not an irrevocable capability:
this module does not solve cross-database authorization/commit atomicity for future
financial commands. Design those revocation guarantees before transactional cutover.

## API and native transport

The six native route families are implemented by `src/index.mjs` and exercised by
`tests/identity.test.mjs` and `tests/security-http.test.mjs`:

| Method and suffix after `/v1/auth/clubs/{clubId}/` | Effect |
| --- | --- |
| `POST otp/challenges` | Accepts an exact E.164 phone and a 32-byte client secret; creates one queued code under a durable request key. |
| `POST otp/verifications` | Verifies the bound challenge, six-digit code and original client secret; issues one session and preserves an existing UUID. |
| `GET session` | Checks the actual access token and returns verified supporter identity only. |
| `POST sessions/refresh` | Atomically replaces both tokens under the original rotation key. |
| `POST sessions/revoke` | Revokes current, other, or all sessions of the authenticated account. |
| `POST deletion-requests` | Requires recent verification and explicit acknowledgement; disables the account, revokes sessions and writes one retained erasure task. |

All requests use the configured HTTPS origin, `X-AFRICLUB-Client: native-v1`, direct
Cloudflare ingress, and the mandatory edge rate limiter. The marker is **not**
a credential. The edge IP is only an abuse-control input; neither it nor the club
path grants identity. Cookie, Origin and Sec-Fetch-Site requests are refused:
The separate private browser session capability is documented in
`BROWSER_SESSIONS.md`; the native routes accept no browser cookie transport.
The browser gateway, operator authorization and live cookie/CSRF acceptance require
their own integration checks. Use no browser token storage, wildcard CORS, direct
client SQL or raw identity-header fallback.

Challenge issuance, verification, refresh and deletion require an
`Idempotency-Key` (16–128 safe characters; UUID recommended). JSON bodies are
limited to 4 KiB and a two-second complete body-read deadline, have exact allowed fields, and cannot include a chosen user or
staff role. Responses are no-store and sanitized; raw SQL/provider bodies, phone
numbers and codes are not returned. The code must be entered only on the client
that retained the original random `clientSecret` for that challenge.

## Lifetimes, retries and concurrency

Codes expire after ten minutes, matching the inspected template description.
Verify the actual approved template copy before delivery enablement. Access tokens
expire after five minutes, refresh tokens after one day of inactivity, and all
sessions after seven days regardless of refresh. Five failed guesses lock a code.
A shared phone budget permits 15 verification attempts per 15-minute window; a new
challenge does not reset it. Issuance requires the explicit bounded
`AUTH_ISSUANCE_POLICY_JSON` with per-club reservations, global/IP budgets and at most
three codes per phone per 15 minutes. See `ISSUANCE_LIMITS.md`. Queue throughput is
configured independently and retries/provider outages can reduce it. The D1
counters are guarded atomically. The edge limiter is an additional local
100/minute ceiling, not a globally exact quota. Tune shared-mobile-network fairness,
WAF rules, attestation and provider spend limits using genuine staging evidence.

Verification and refresh each retain an encrypted exact response for 60 seconds.
The identical operation key can recover that response only while the resulting
session and credential pair are still current and valid. Different-key reuse of
an already-used refresh token revokes that session family. A replay from a wrong
club cannot revoke the legitimate club's session. A newer rotation cannot be
rolled back to older credentials through a retained receipt. No request sends or
rotates automatically on page load, restart, timeout or unknown response.

This module supplies no native TypeScript client or client compiler. Native
integration must provide OS-protected secure storage, atomic compare-and-set and
a process-safe exclusive refresh lock. Persist the original refresh token and
operation key before sending; explicitly resume that same operation after an
unknown response. A failed storage write must prevent sending or retain recovery
state after a committed response. Save OTP request/client secrets and verification
keys durably before each request. Android/iOS adapter, storage and lifecycle
acceptance remain separate work; the existing Supabase app auth stays authoritative.

The 60-second recovery window is deliberate and bounded. Recovery after it, token
reuse, stale authority or lost recovery state requires fresh phone verification.
Logout-other/all and erasure requests require a phone verification within five
minutes; refreshing a token does not refresh that proof. SQL guards recheck time
and authority at the mutation, not only before it.

## Delivery and privacy

The scheduled handler uses the explicit private queue policy described in
`RELIABLE_DELIVERY.md`: bounded batch/per-club budgets, leases, backoff and at most
three attempts. It requires `OTP_DELIVERY` and never falls back to the historical
direct sender. Expired or consumed codes cannot be sent. Provider acceptance clears
the encrypted delivery secret. A timeout preserves an unknown provider outcome;
retries retain the same challenge identity and dispatch claim. The private sender
never creates another external POST for that claimed challenge. A WhatsApp accepted
message ID does not prove handset delivery.

The private provider adapter uses the repository's English authentication template format:
body code plus copy-code URL button at index 0. Per-club approved template names,
phone-number ID, explicit Graph API version and a secret Cloud API token are
required. There is no default account, template, paid plan or automatic provider
version change. Provider responses are bounded and raw errors are not logged.
No real provider request was sent by the tests; test numbers and receipts are
synthetic. Do not enable real delivery without verifying account/template status,
recipient consent, applicable provider restrictions and the delivery monitoring.

Bounded maintenance clears expired encrypted verification/refresh responses and
expired delivery payloads, and removes old abuse-window counters. Identity,
challenge metadata, encrypted contact copies, audit events, deletion tasks and
refresh-reuse fingerprints remain retained. This is **not** a complete retention
or GDPR/other-law erasure implementation. Define approved retention periods,
privacy-minimized monitoring, archival and deletion reconciliation before release.

Account erasure currently returns `pending_external_erasure`,
`sessionsRevoked: true`, `erasureCompleted: false`. The account and old sessions
cannot be used to regain access. For 60 seconds the exact deletion token/key can
recover only the deletion receipt, not authenticate or create a new task. No worker
here erases profile/media/financial records, revokes legacy Supabase sessions, or
marks downstream erasure complete. The existing backend remains authoritative.

## Offline identity import

An identity import planner is not supplied by this module. Before enabling the
import gate, implement and review a deterministic, private planner for an approved
minimal verified-phone export such as:

```json
{"schemaVersion":1,"sourceProject":"original-project-ref","users":[
  {"id":"original-user-uuid","phone":"+country-and-number",
   "phoneConfirmedAt":"source ISO timestamp","createdAt":"source ISO timestamp",
   "status":"active"}
]}
```

The planner must validate independent source byte hashes and record counts,
preserve original UUIDs, reject duplicate UUIDs/phones and unverified or inconsistent
contacts, encrypt contact data with the approved key version, and write exclusive
private files without executing SQL or making network calls. It must cover every
required source identity and produce sanitized reconciliation evidence. Anonymous
and unverified identity upgrade needs an explicitly reviewed migration contract.
The preserved source candidate contained no executable import utility; no real
user import has occurred.

Use only an empty isolated database with both workers disabled and import_ready=0.
Plans are INSERT-only: any conflict stops rather than upserting/merging identity.
A partial remote file import can leave rows but remains gated; reconcile or rebuild
that disposable staging database instead of force-overwriting. The reviewed plan
must leave import_ready and clubs disabled. Independently compare UUID/contact hashes,
status counts, source provenance and a restored export before authorizing the gate.
Never link users on name, last phone digits, client-supplied IDs or an unverified
phone. Existing contact-reassignment and anonymous-upgrade flows still need design.

## Verification and deployment order

```sh
node --test cloudflare/supporter-auth/tests/*.test.mjs cloudflare/auth-code-delivery/tests/*.test.mjs
node cloudflare/supporter-auth/scripts/check-deployment.mjs
node cloudflare/supporter-auth/scripts/check-reliable-delivery.mjs
node cloudflare/auth-code-delivery/scripts/check-deployment.mjs
node cloudflare/auth-code-delivery/scripts/check-receipts-deployment.mjs
```

Tests execute genuine local SQLite and Web Crypto, with simulated CF context,
edge rate binding and provider responses. SQL time is controlled only by the test
adapter; production uses SQLite's own current time for commit guards. The private
WorkerEntrypoint wrapper is syntax-checked only. These are not workerd, real D1,
real Cloudflare abuse controls, actual phone receipt, device secure-storage tests,
full Flutter/Next builds or production authorization evidence.

`wrangler.native-identity.staging.jsonc` targets the actual `src/index.mjs` gateway;
`wrangler.identity-verifier.staging.jsonc` targets the named private verifier.
The native worker has only AUTH_DB, the placeholder ingress limiter and the private
OTP_DELIVERY capability. The verifier has only AUTH_DB and exposes HTTP 404.
Both templates have disabled switches, zero placeholder database IDs, no routes,
no schedule, and disabled invocation logging. The local checker accepts these
disabled shapes only; it refuses `--ready` and never approves an enabled candidate.

For separately approved isolated staging, provision a **new** identity D1,
apply all four ordered identity migrations, configure the direct native gateway domain and exclusive
private verifier bindings, supply distinct secret keys, verify/import the identity
mapping, approve club/template mappings, configure a namespace-isolated rate binding
and the one-minute drain schedule, then run real runtime/concurrency/provider tests.
Keep the separate dispatch database and its two migrations distinct from identity
and public-content storage. The existing Supabase app auth remains authoritative
until governed migration and cutover acceptance.

## Remaining release conditions

Required before migration: preserved anonymous identities and safe linking,
authenticated phone-change/recovery, profile compatibility, native secure storage
and loss-recovery journeys, browser cookie/BFF transport, staff and resource-role
migration, production key lifecycle, attestation/abuse/spend tests, retention and
complete erasure workflow, real D1 capacity/latency/failure tests, original-source
integration, old-client handling, final backup reconciliation and an approved
single-writer cutover. This batch grants no deployment or retirement approval.

## Implementation references

Official documentation checked during implementation, not deployment evidence:
- https://developers.cloudflare.com/d1/worker-api/d1-database/
- https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/
- https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
- https://www.sqlite.org/lang_datefunc.html

The provider wire payload is specifically derived from the inspected AFRICLUB
`supabase/functions/_shared/whatsapp.ts`; real Meta template/version compatibility
remains unverified. No authentication assurance certification is asserted.


## Continuation — reliable delivery and unclaimed recovery, 28 September 2026

Reliable delivery continuation: see `RELIABLE_DELIVERY.md`. New queue selection is explicitly private-only, fair across configured clubs and guarded by a disabled SQL control. The old legacy default described in historical sections no longer applies to this candidate.

# Reliable OTP dispatch and private queue health

**Disabled isolated-staging source candidate. No provider job or migration has been run remotely.**

## Behavior and integration

`src/delivery.mjs` now delegates to the journalled private dispatch path. It does not
select the legacy network sender when a mode is absent or invalid. Historical
`whatsapp.mjs` remains for source preservation and its tests, not as a runtime retry
fallback. This intentionally supersedes the older integration note's legacy default.

Apply migrations `0001`, the existing `0002_club_delivery_index.sql`, and the new
`0003_reliable_delivery_control.sql` in order in the SAME isolated identity database.
The last migration starts `auth_delivery_control.enabled=0`. It adds no user, changes
no challenge, sends nothing and changes no deployment permission. The private provider
sender's separate dispatch database remains separate from identity storage.

Required reviewed writer settings:

```json
{
  "AUTH_DELIVERY_MODE": "private-deduplicated",
  "AUTH_DELIVERY_POLICY_JSON": "{\"version\":1,\"clubIds\":[24,26],\"batchLimit\":10,\"perClubLimit\":2,\"rpcTimeoutMs\":8000,\"leaseMs\":30000,\"retryDelayMs\":30000,\"runBudgetMs\":25000}"
}
```

These values illustrate the schema, not production throughput approval. Include only
reviewed clubs. Runtime AUTH_SERVICE_ENABLED/AUTH_DELIVERY_ENABLED, source import gates,
reviewed club configuration and the new SQL control must all be enabled explicitly.
The `OTP_DELIVERY` service binding must target the existing private
`AuthenticationCodeDelivery.deliverWithReceipt` entrypoint. No provider credential,
phone, code, key or account ID is supplied in these examples.

The scheduler chooses the least-served eligible club and its oldest due challenge.
A persisted sequence records committed leases across drains; batch/per-club budgets
bound one invocation. OTP issuance anti-abuse/cost limits remain independently in
force. This is not a proven proportional-fairness or game-day capacity guarantee.

## Failure semantics

An attempt journal, challenge lease and scheduler advancement commit atomically before
any provider-capable RPC. The caller rechecks current source, account, tenant and lease
state in a newly started `first-primary` session immediately before sending. A race
between that check and the external call is still possible; no cross-provider atomicity
is claimed. The final local acceptance commit repeats mutation-time checks.

A provider acceptance increments `accepted` only if it is durably recorded or recovered
from an already committed local outcome. A zero-row/stale-lease acknowledgement is not
success. A timeout does not cancel a remote call. Later attempts reuse the SAME original
challenge identifier; the existing private sender's immutable dispatch claim prevents a
second external submission. Its previously stored receipt can satisfy a later local retry.

Old challenges with a recorded delivery attempt but no new attempt journal are
quarantined without resending. This is deliberate adoption behavior, not evidence that
the original send failed. Never delete claims/quarantine/history to force a resend.
A new user-requested challenge remains subject to issuance limits. Deployments must first
freeze and drain old workers; this code cannot stop an older executable still sending.
Rollback must not reactivate the legacy sender over unresolved private dispatches.

The drain returns precise counts for locally accepted, unconfirmed, quarantined and
lost-lease outcomes. The compatibility `dispatchOtp.failed` sum does NOT mean “provider
did not send.” No delivery creates a session, proves handset receipt or grants money,
membership, points or another entitlement. Verification remains a separate command.

## Maintenance and operations

`runIdentityMaintenance` independently attempts both bounded transient-secret expiry
and dispatch. Pausing/failing delivery does not suppress expiry. Expiry needs no decryption key or sender credential, so lost sender/key availability does not itself suppress safe expiry. It rejects with a fixed
sanitized code if either task fails, so a scheduled job is not falsely reported successful.
Platform interruption can still prevent completion; the next separately configured run
must revisit remaining rows. No cron was created by this implementation.

`OtpQueueHealthReader.read({})` is PRIVATE and accepts no caller-selected club or SQL.
It returns configured club IDs, capped state counts (1,000), oldest-pending timestamps,
control revision and observation time. No sender binding or cryptographic credential is
needed in this reader. It cannot send, create a session or mutate through its exposed API.
The D1 binding itself is not an independently read-only database credential.

A trusted operator gateway must authenticate/authorize viewers before displaying these
aggregates. The supplied reader config has no HTTP ingress, sender binding, schedule or
telemetry, and starts disabled. No dashboard or alert subscription has been connected.
Health reads are sequentially consistent observations, not one atomic database snapshot.
Bounded result counts are not a substitute for target-runtime query/read/cost benchmarks.

Immutable local outcomes do not themselves implement retention, deletion, DLQ adjudication,
provider-message redaction, human incident response or approved data location. Those gates
remain open. The outcome journal contains linkable challenge IDs and requires appropriate
access/retention controls even though it does not store codes or phone numbers.

## Verification commands

```sh
node --test cloudflare/supporter-auth/tests/*.test.mjs cloudflare/auth-code-delivery/tests/*.test.mjs
node cloudflare/supporter-auth/scripts/check-reliable-delivery.mjs
```

Tests use real local SQLite, cryptography and simulated sender/bindings. The WorkerEntrypoint
wrapper is source/syntax checked, not real workerd acceptance. The source does not install
SDKs, configure WAF/alerts, change provider templates or authorize production.

Official runtime references checked 28 September 2026:
- https://developers.cloudflare.com/d1/worker-api/d1-database/
- https://developers.cloudflare.com/workers/runtime-apis/handlers/scheduled/
- https://developers.cloudflare.com/workers/configuration/cron-triggers/
- https://developers.cloudflare.com/workers/platform/limits/

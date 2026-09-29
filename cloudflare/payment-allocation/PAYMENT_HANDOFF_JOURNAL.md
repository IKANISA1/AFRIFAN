# Server-authoritative payment handoff journal

28 September 2026. **Disabled isolated-staging source; not a carrier/payment service.**
This forward addition uses the existing allocation/checkout database and trusted
checkout principals. It does not introduce a second financial ledger or change a
previous migration. Apply `0003_payment_handoff_journal.sql` only after separately
approved staging preparation. The new database control starts disabled.

## Authority and flow

The authenticated gateway derives user and club. The private service rechecks its
current capability, subject, club and control revisions inside the same transaction
as the journal mutation. It uses documented opaque D1 prepared statements, not test
fixture properties. Caller-supplied amount, receiver, principal or dialer permission
is rejected.

`review owned order (GET) -> explicit confirmation -> durable local marker ->
reserve server marker -> claim one first-response opportunity -> external dialer`

`reserveHandoff` binds a UUID request to the owned order and its immutable instruction
snapshot digest. It returns `mayOpenDialer:false`. Only one unresolved head exists
for a user/club. Repeating the same reservation request returns that record.

`claimHandoff` records an immutable claim and audit event atomically. Exactly one
successful first claim response can report `mayOpenDialer:true`. **Every retry,
including the original key, returns status only and never regrants permission.**
Losing the database/RPC/HTTP response may therefore strand a claim without a dialer
invocation. This is a deliberate safety/availability trade-off, not payment finality.

`currentHandoff` reads the current server marker after local storage loss. It returns
no token, provider reference, phone, PIN or payment instruction and never permits a
platform call. The gateway still verifies the current identity, ownership and club.

Existing checkout cancellation and claims serialize in this same database: a
claimed order cannot be cancelled to make a replacement checkout. Exact payment
allocation by the existing allocator resolves the journal's phase to `allocated`;
the journal never allocates evidence or activates membership itself.

## Recovery and limits

The current reference clients read the server marker before starting another
handoff, including after reinstall/local-state loss. They fail closed while an
unallocated marker exists. **Even a local `not_opened` response cannot clear a
server claim.** Expiry, cancellation, missing response and configuration changes
are not proof that no payment occurred. They do not delete or reset history.

Read-only recovery is implemented; operator resolution of stranded/unallocated
markers is NOT implemented or authorized. An unclaimed reservation can be replaced
by the private service after its old order is cancelled/expired, but the conservative
reference-client recovery does not automatically perform that replacement. A
reviewed explicit resumption/exception workflow remains a release requirement.

The permission is coordination for a trusted app, not a bank-side spending limit.
Manual payments, malicious clients ignoring the protocol, older clients that never
consult the journal and legacy live Supabase writers remain outside this protection.
Do not enable this flow before a minimum-client-version policy, legacy-client cutoff
and historical in-flight payment reconciliation are accepted. Restore procedures
must preserve all reservations/claims, not merely current head pointers.

The identity and allocation databases remain separate. Pre/post identity checks can
withhold a response but cannot undo a committed journal operation or make revocation
atomic across databases. A grant is not an authenticated human acknowledgement,
proof of handset opening, provider acceptance, settlement or paid entitlement.

## Configuration

The checkout template adds `HANDOFF_JOURNAL_ENABLED=false`. The native gateway adds
`MEMBERSHIP_HANDOFF_JOURNAL_ENABLED=false`. Both flags, the new database control and
existing checkout/allocation/reconciliation/authorization gates must be configured
through a reviewed staging change. The ready checker verifies matching opt-in flags
but reports `serverRecoveryAccepted:false`; it does not supply real resources or
approve a financial rollout. Production writer modes remain rejected.

Private methods are documented in `contracts/payment-handoff.json`; public routes
and minimized shapes in `../supporter-membership-api/contracts/openapi.json`.

## Executed evidence and remaining acceptance

Tests cover duplicate/lost responses, cross-club/owner denial, mutation-time
revocation, every statement failure, opaque statement objects, immutable history,
claim versus checkout cancellation and exact allocation. Three race scenarios use
independent SQLite connections in worker threads. These are actual local SQL tests,
not Cloudflare D1 capacity/runtime or carrier certification.

Before rollout require real Workers bindings and D1 migration tests, native secure
credentials, Dart/Flutter/platform builds, physical devices, accessible confirmation,
provider matching, late/refund support, retention/erasure, backup and single-writer
cutover evidence. No migration, provider request or production action is executed by
this source package or installer.

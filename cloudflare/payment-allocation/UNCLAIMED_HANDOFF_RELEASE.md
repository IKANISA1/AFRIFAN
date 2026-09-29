# Explicit release of a never-claimed handoff

**Source candidate, separately disabled in the database and runtime. This is not a refund or payment-resolution authority.**

An application can crash after reserving a payment handoff but before claiming its single
opportunity to open a dialer. The new release command permits an explicit, authenticated
owner action to release that reservation only while the authoritative journal has NO claim.

Apply the forward-only `0004_release_unclaimed_handoff.sql` after existing migrations.
It adds disabled `pa_handoff_release_settings` and immutable `pa_handoff_releases` in the
SAME allocation database. Leave `HANDOFF_RELEASE_ENABLED` and the gateway's
`MEMBERSHIP_HANDOFF_RELEASE_ENABLED` absent/false until independently approved and tested.
Existing main handoff, subject, principal, club and source controls remain required.

## Contract

Private call: `MembershipCheckout.releaseHandoff({clubId,userId,handoffId,requestId})`.
The private worker derives its principal from deployment settings. The native gateway
derives user/club from the current identity, rejects actor overrides, and exposes only:

`POST /v1/supporter/clubs/{clubId}/membership/handoffs/releases`

with canonical JSON `{"handoffId":"<original UUID>"}`, native bearer/session headers and
an original UUID Idempotency-Key. No price, provider, paid flag or caller reason is accepted.
The response uses the journal schema with additional phase `released`; it NEVER grants
`mayOpenDialer`. Unsupported old clients reject the new phase rather than gain authority.

The command checks ownership, current head, no claim, no allocation, current permissions
and the separate release control inside the database transaction. Bidirectional triggers
make release-vs-claim races mutually exclusive. A stale device cannot subsequently claim
a released reservation. The retained release row is the immutable principal/key/time/reason
audit record; original reservation, head, order, claims and financial records are not deleted.

Replaying the same release key returns retained state. A different key cannot reinterpret
that completed operation. If source permissions change after commit, the response may be
withheld; the persisted release is not rolled back by that transport/authentication failure.
Identity and financial databases are still separate; this does not close their revocation interval.

## Client recovery

The TypeScript and authored Dart handoff coordinators add `releaseUnclaimed(handoffId,
acknowledgement=true)`. Only a separate explicit foreground UI action should call it after
displaying the exact reservation and its limited meaning. This batch does not render or
wire that dialog into the apps.

The coordinator uses the handoff ID itself as the namespaced release request key. A lost
reply can therefore be retried explicitly without inventing another key, even if local
state is missing. It rereads current server state, checks session and lifecycle generation,
and rejects claimed/allocated/changed heads or a local opened/unknown attempt. After a
verified release it changes only a matching local `reserved` marker to `not_opened`.
Storage failure preserves the original marker for explicit same-operation recovery.

`recover()` is still read-only. Neither restore, timers, navigation nor app resume calls
release, creates a new checkout or opens a dialer. A later actual handoff requires a fresh
review and independent confirmation. A new server reservation may replace a released head;
old reservation replay remains released, never becomes newly claimable.

## Boundaries that must remain visible

- An unclaimed reservation is evidence only about this journal protocol. Manual payments,
  old clients, alternative devices bypassing the protocol and fraudulent provider evidence
  are not excluded by it. Release does NOT attest that no money moved.
- Original pending orders remain payable according to their existing rules. A genuinely
  reconciled later payment can still allocate/fulfill the original order.
- Claimed but unsent, uncertain, late, cancelled-order, duplicate or partial payments still
  require a separate governed reconciliation/exception workflow. Expiry is never a substitute.
- No refund, reversal, order cancellation, ticket, contribution, membership or points effect
  is caused by release itself. No real provider or financial record has been acted on here.

Executed validation covers genuine local SQLite transactions, independent connections,
HTTP gateway and strictly compiled TypeScript adapter/coordinator with synthetic identities
and simulated service bindings/dialer. Dart source is supplied but uncompiled without its SDK;
actual D1/workerd, physical devices and an accessible integrated UI remain release gates.

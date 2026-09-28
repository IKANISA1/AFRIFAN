# Server-backed handoff recovery — disabled staging extension

27 September 2026. This module adds an authoritative handoff reservation to the existing allocation database. It does not transfer money, invoke a phone, verify settlement, cancel a provider transaction, or deploy anything. Existing `0001` and `0002` migrations are unchanged; the new `0003_server_handoff_recovery.sql` is forward-only source to be applied through an approved staging process.

## Why the server record is needed

The earlier local encrypted recovery store can be lost with a complete app-data reset or uninstall. An enabled, compliant server-backed client must reserve before invoking its dialer. A new installation or another device recovers the same user/club blocker from the server; it cannot treat an empty local file as permission to launch again. This covers attempts recorded by this protocol only. It cannot discover historic local-only handoffs, manual USSD transfers, identities merged outside the protocol, or a malicious client ignoring the server. Reconcile legacy attempts before enabling the new database gate; a review-reference string is not proof that reconciliation occurred.

## Workflow and non-replayable launch decision

1. The foreground controller reviews the exact owned checkout, including price, recipient and dialer string, and checks server and local unresolved records.
2. Explicit confirmation consumes the review, rereads the current offer and identity, and writes the existing encrypted local reservation. No automatic timer/resume confirmation is added.
3. The gateway derives the user and session from the actual identity verifier. Its private call carries the original local attempt UUID and a canonical SHA-256 commitment to all reviewed instruction fields. This digest is a comparison, not authentication or payment evidence.
4. One database batch inserts the immutable server reservation, current slot and audit event. Current service/club/subject/catalog/history gates are checked by SQL. The reservation must refer to the exact current generated checkout. No allocation, membership or ledger is created.
5. Only a successfully acknowledged first insert may return a launch decision, for at most five seconds. Server, gateway and client subtract elapsed time conservatively. The gateway reauthenticates after the private call and the controller again checks session, review lifecycle and remaining time before invoking the dialer once.
6. Every exact request replay returns the original reservation with no launch decision. A lost database/RPC/HTTP response can strand an unsent attempt, but cannot automatically authorize another launch. Read-only recovery never returns reusable launch authority.

The server stores no bearer token, OTP, phone PIN or provider body. It retains user/session/order IDs, commitments and a checkout snapshot including payment-routing details. These remain personal/financial data requiring a retention policy; immutable records do not by themselves establish privacy compliance.

## Resolution and operational limitation

An unresolved slot prevents another reservation and prevents new membership checkout creation/replacement for that user/club. The old original checkout key can still recover its stored result without a new write. The checkout guard remains effective even when the handoff service is disabled, so disabling the service is not a bypass.

Only an actual existing membership allocation with matching order, ledger and immutable receipt resolves the slot. Administrative membership suspension is preserved by the unchanged allocator. A client saying `not_opened`, a cancelled/expired order, changed configuration, reauthentication, elapsed grant or app reinstall is NOT settlement evidence and does not release the blocker. All old reservations remain immutable when a later allocated slot is replaced.

**There is deliberately no manual-clear/refund/late-payment adjudication API.** An unsent or cancelled unresolved reservation therefore needs the still-unimplemented governed exception workflow; it must not be deleted from the database to proceed. This safety-biased availability limitation makes broad production activation inappropriate until that workflow and actual client integration are accepted. The local result `opened` is never payment success.

## Existing boundaries preserved

The public composition is `cloudflare/supporter-membership-api/src/handoff-index.mjs`. It reuses the existing membership routes, authenticated identity, native-ingress restrictions and keyed abuse controls. The original `src/index.mjs` is unchanged. Private `MembershipHandoffReserve` and `MembershipHandoffRecovery` entrypoints expose no HTTP handler beyond 404, no SQL proxy, no payment allocator and no provider binding to the gateway.

The same allocation D1 must hold checkout, reservations and payment resolution; do not split it by device or club without a replacement transactional authority. Identity remains in its existing separate database. The repeated identity reads do NOT create an atomic transaction with session revocation. A covered post-commit revocation returns an unknown outcome and withholds the response, while the stored reservation remains. Final-read revocation races and carrier actions after a grant remain release risks requiring explicit design/acceptance.

## Integration

Use the new TypeScript `serverBackedHandoff(...)` factory with an OS-protected credential supplier, durable recovery store and native dialer adapter, with explicit `enabled:true` only in reviewed staging. This mandatory-server composition has no fallback when server recovery is unavailable. The old optional local-only TypeScript constructor remains for source compatibility, **not as an approved workaround**.

The existing Dart controller has NOT been switched to this server protocol. No app routes, platform storage registrations, Android/iOS projects, dependency manifests or production flags are changed. Dart/Flutter/Keystore/carrier acceptance and all five club journeys remain blocked/unverified. Do not ship the earlier Dart path as though it had this new server protection.

## Configuration and migration

Both `wrangler.handoff.staging.jsonc` files are disabled, with no public preview, no provisioned accounts and no real database/principal IDs. The private service must use the allocation database already used by checkout and receipts. Configure two new least-privilege principals separate from all earlier principals. New table controls and grants start disabled. The gateway should replace its existing ingress only through controlled staging routing; do not create two conflicting custom domains or an unreviewed proxy.

Run offline checks:

```sh
node cloudflare/supporter-membership-api/scripts/check-handoff-deployment.mjs
node cloudflare/supporter-membership-api/scripts/compile-server-handoff.mjs
node --test cloudflare/payment-allocation/tests/handoff-*.test.mjs \
  cloudflare/supporter-membership-api/tests/server-handoff-*.test.mjs
```

The optional ready-config check requires gateway, private handoff, identity-verifier, checkout and allocation JSON files, followed by `--ready`. It validates source configuration only. It does not verify live grants, DNS/routing, deployed SQL, source-history completeness or production approval, and performs no network or deployment call.

## Verification limits

Tests run real local SQLite/triggers and cryptography with current identity, checkout and allocation source. Independent connections exercise conflicting reservations, checkout replacement and allocation. Network transport, identity fixtures, D1 bindings and dialers are synthetic. No real provider, carrier, Cloudflare runtime, full Flutter/Next.js build or production capacity/retention test is implied. Five-second grants, twenty-second order margin and retained-history scan costs require measured staging evaluation; they are implementation pilot choices, not approved commercial rules.

Primary technical guidance checked during implementation: Cloudflare D1 database batch/session documentation, Workers RPC documentation and SQLite trigger documentation. These references support API choices, not successful deployment evidence.

# Native checkout and journaled payment handoff

28 September 2026. Disabled, opt-in integration candidate. This source reconciles the
existing native gateway, TypeScript controller and authored Dart adapter with the
same-database server journal. It is not installed into any of the five app routes.
The original membership exports and Supabase consumer flows are unchanged.

## Separate deliberate actions

`review(orderId)` authenticates the same user/club/session, checks prior local and
server state and reads the owned current checkout. It displays exact tier, amount,
currency, country, provider, recipient and USSD code. **Review makes no POST and
never opens a dialer.**

After displaying all those fields, a separate foreground action calls
`confirm(reviewId,true)` in TypeScript or `confirm(reviewId,acknowledgement:true)` in
Dart. It consumes the private review, rereads and compares instructions/expiry,
rechecks the session and lifecycle, saves/verifies the local attempt, and performs
two explicitly authorized journal POSTs: reservation and claim. The platform is
invoked once only when the first claim response permits it. No handoff invokes
payment allocation or grants paid membership.

The boolean acknowledgement and review ID do not independently prove human review.
A production screen must use the shared approved design system, display all fields
accessibly and bind confirmation only to the intended explicit user interaction.
No such native confirmation screen was rendered/registered by this patch.

The review window is 30 monotonic seconds, and the owned checkout needs 15 seconds
of validity after elapsed read/storage time. These pilot limits are not settlement
windows or a promise of an atomic carrier operation. Call `invalidateReview()` on
backgrounding, route exit, logout and account changes. Invalidation can prevent a
platform call while leaving an already committed server marker for reconciliation.

## Recovery without duplicate authorization

Local phases remain `reserved`, `opened`, `not_opened`, `unknown`. OS-protected
compare-and-set plus an installation/process/isolate lock must cover the operation.
A saved marker contains no credential, phone, PIN or dialer code, but its IDs remain
linkable personal data. The server marker is separately retained by user/club.

`recover()` reads the current server marker and owned status, with or without local
state. It never creates/reserves/claims/cancels, refreshes a token or opens a dialer.
Server-reserved/claimed unallocated heads block another handoff. **A local failure
to open does not override a server claim.** All claim retries return
`mayOpenDialer:false`. No timeout or process restart can silently restore that grant.

This conservative behavior can strand an unsent attempt. The private journal can
replace an unclaimed head after valid order cancellation/expiry, but these clients
do not automatically do so. Human-reviewed explicit recovery/late-payment workflows,
minimum-client-version enforcement, historical pending-operation reconciliation and
preservation across server restores are still required. Manual external payments or
legacy clients ignoring this protocol are not prevented by a local or server marker.

The two backend databases do not form a distributed transaction. A revoked identity
can cause an unknown/withheld result after a committed journal operation. Old source
clients must not be treated as compatible merely because they use `native-v1`.

## Native source and platform boundaries

`native_membership.dart` remains a separate opt-in entrypoint. Its client/ports,
response models and handoff coordinator now include current/reserve/claim journal
methods. Existing `feat_membership.dart`, app routes and package dependencies remain
unchanged. No raw credentials are persisted by the HTTP client.

The native transport uses normal TLS, bounded responses, no redirects and no cookie
fallback. The optional Flutter adapter uses the existing `url_launcher` dependency
to request an external tel URI, disabled by default. Opening it is never proof of
payment. Real iOS/carrier/SIM restrictions require representative device acceptance.

Portable Android/iOS recovery cores and optional host sources are included in the
reconciled candidate under `native/android` and `native/ios`. Portable JVM/Swift
tests are not Keystore, Keychain, Android/iOS host or Flutter acceptance. Protected
credential storage and all five app compositions remain incomplete. Never replace
required ports with in-memory/plain preferences test stores.

## Verification

```sh
node cloudflare/supporter-membership-api/scripts/compile-client.mjs
node cloudflare/supporter-membership-api/scripts/compile-handoff.mjs
node --test cloudflare/supporter-membership-api/tests/*.test.mjs
python3 tools/scripts/verify_native_membership.py --results /tmp/native-check
```

TypeScript and local real-service/SQLite integration tests run here; external
bindings, delivery and dialer ports use synthetic doubles. The Dart/Flutter SDK is
not available, so the authored Dart journal changes and harness remain uncompiled.
The verifier returns BLOCKED, not PASS. Keep Dart >=3.10 and Flutter >=3.38 and the
repository's selected runtime pins. Do not infer actual app readiness from Node
contract vectors. Browser-cookie clients are a different, unfinished integration.

See `../payment-allocation/PAYMENT_HANDOFF_JOURNAL.md` for private transaction semantics
and `contracts/openapi.json` for the seven native operations. These docs describe
source behavior; no resource, database migration, app flag, carrier action or
production release was performed by preparing them.

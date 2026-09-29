# Native membership recovery integration

## Local integration status — 30 September 2026

The candidate08 source is imported into active source, with its original ZIP and
frozen comparison hashes recorded in
`docs/release/native-membership-integration-2026-09-30.json`. Local verification
covers 95 Flutter membership tests, zero analyzer issues, 72 pure Dart contract
checks, 12 protected-channel adapter checks, 11 history checks, 69 portable Kotlin
checks and 68 portable Swift checks. Portable checks are not device acceptance.

All five Android apps compile the shared recovery source and register one plugin
per Flutter engine. Their manifests disable backups; recovery files live only in
`noBackupFilesDir`. All five iOS targets reference the same Swift source and retain
`IOSNativeRecoveryRegistration`, which waits for foreground/protected data before
installing the channel. Actual Apple SDK/Flutter framework typechecks cover all
five AppDelegates and the shared host, with Swift 6 warnings treated as errors.
No Keychain or Android Keystore device operation, carrier call or signed release
is established by these checks.

`package:feat_membership/native_membership_composition_flutter.dart` provides
`NativeMembershipComposition(api: ..., clubId: ..., enabled: ...)`. It requires an
explicit `NativeMembershipApi` backend choice and defaults to disabled. Call
`invalidateIdentity()` on logout, account/club change, route exit or credential
rotation, then `dispose()` when leaving that scope. Background transitions fence
in-flight replies and invalidate confirmation; foreground transitions never submit
or retry a checkout or open a dialer. Uncertain markers and their original keys
are retained. A failed identity recheck after a sent write is an unknown outcome.

The Cloudflare `NativeMembershipClient` accepts its dedicated native token format;
never pass a Supabase JWT into that credential port. Existing Supabase membership
routes and mutation gateway remain available. Frontend/account/backend selection,
protected credential supply, real Keychain/Keystore tests, accessible confirmation
acceptance, provider reconciliation and store acceptance remain separate gates.
The recovery channel does not collect SMS or execute a payment.

The native client/ports and handoff coordinator require the server journal. Explicit
confirmation reserves and claims before a platform call; recovery reads the current
server record even when local storage is empty. Repeated claims return no grant,
and a local `not_opened` cannot clear a server claim. No plaintext or in-memory
production recovery fallback is installed.

The call sequence is explicit checkout `begin(tier)` or same-key `resume()` after an
unknown outcome, then handoff `review(orderId)`, display **all** reviewed payment
fields, and `confirm(reviewId, acknowledgement: true)` from a separate foreground
action. Opening the external dialer is not payment success. `restore()`/`recover()`
read only. Call `invalidateReview()` when backgrounding, leaving the page or changing
accounts. Expired or cancelled orders do not clear an uncertain past handoff.

Run `python3 tools/scripts/verify_native_membership.py --results /tmp/native-check`
from a full checkout after installing the required SDK in an authorized environment.
The checker never downloads/install tools and never treats an absent SDK as passed.
It verifies only the pure Dart library/harness. The Flutter bridge, URL/USSD carrier
behavior, signed builds, device security and all five app journeys need separate
acceptance. See `cloudflare/supporter-membership-api/NATIVE_PAYMENT_HANDOFF.md` for
full semantics, limits and source provenance.


## Continuation — reliable delivery and unclaimed recovery, 28 September 2026

The authored Dart API/coordinator includes explicit `releaseUnclaimed` for never-claimed server reservations. It is not a reset for claimed/unknown payments. This was the candidate source-authoring status. The 30 September local verification and protected composition described above supersede its execution status; frontend confirmation and real platform acceptance remain required.

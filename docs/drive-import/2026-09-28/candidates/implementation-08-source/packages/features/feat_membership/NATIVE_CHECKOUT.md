# Opt-in native membership adapter

This library is **disabled by default, not installed in the existing app flow, and
not yet Dart/Flutter-verified**. It targets the current
`cloudflare/supporter-membership-api` contract; it does not replace Supabase auth,
membership repositories, provider allocation or existing routes.

Use `package:feat_membership/native_membership.dart` for the pure Dart client and
recovery/controller ports; import `native_membership_flutter.dart` only in reviewed
Android/iOS composition that needs the optional external dialer bridge. Existing
`feat_membership.dart` remains unchanged. No new dependency is added; the bridge
uses the already-declared `url_launcher`. The required toolchain remains
Dart >=3.10.0 <4.0.0 and Flutter >=3.38.0.

Android and iOS recovery cores and optional native host source are supplied under
`native/android/` and `native/ios/`. The portable Kotlin/JVM and Swift cores are
executed locally; Keystore/Keychain, native hosts and Dart/Flutter/device behavior
remain unverified and are not registered in any app. Still missing are a protected
credential supplier, app/account lifecycle and accessible native confirmation UI.
No in-memory or plaintext production fallback is provided.

The native client/ports and handoff coordinator now require the opt-in server journal.
Explicit confirmation reserves and claims before a platform call; restore/recovery
read the current server record even when local storage is empty. All repeated claims
return no grant, and a local `not_opened` cannot clear a server claim. Unknown/late
payment support, historical in-flight reconciliation and legacy-client cutoff remain
required. These new Dart additions and tests are authored but not SDK-executed.

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

The authored Dart API/coordinator includes explicit `releaseUnclaimed` for never-claimed server reservations. It is not a reset for claimed/unknown payments. No Dart/Flutter execution or app-route composition is claimed; a separate reviewed confirmation dialog and real platform tests remain required.

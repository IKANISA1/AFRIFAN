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

An Android encrypted recovery-store candidate and process-safe lock are now supplied
under `native/android/`, with the Dart adapter in `platform_recovery_store.dart`. Its
portable Kotlin engine is JVM-tested; AndroidKeyStore, the Android host, Dart and
Flutter/device behavior remain unverified. It is not registered in any app. Read
`native/android/README.md` before integration. Still missing are an OS-protected
credential supplier, iOS counterpart, server-side lost-state recovery, account/logout/
backup lifecycle and accessible confirmation UI. No memory or plaintext production
fallback is provided. Test doubles are not production storage.

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

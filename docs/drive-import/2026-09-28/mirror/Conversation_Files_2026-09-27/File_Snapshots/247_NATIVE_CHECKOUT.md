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

Mandatory platform integration is still missing: an OS-protected credential
supplier, durable atomic recovery store, a process/isolate-safe exclusive lock,
account/logout/backup lifecycle, and a reviewed accessible confirmation UI. The test
store and fake dialer are NOT production implementations. No default memory or
plain-preferences fallback is provided.

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

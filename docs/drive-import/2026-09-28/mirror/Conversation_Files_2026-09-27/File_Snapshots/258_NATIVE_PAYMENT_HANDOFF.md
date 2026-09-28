# Native checkout and explicit payment handoff — disabled source candidate

27 September 2026. This continuation preserves the existing authenticated membership
gateway, payment allocator, checkout catalog, identity database and all five apps.
It adds a reference handoff controller and a separate opt-in Dart library. No route,
provider, runtime flag, SDK requirement, source migration or app default is changed.

## What belongs to the existing gateway

The current source already authenticates native bearer credentials, derives the
supporter and club, reads owned checkouts, prepares an idempotent order and returns
minimized historical receipts. The gateway and `client.ts` are **not new work in
this continuation**. The new files use that precise contract, not an invented
endpoint or a direct connection to payment allocation. No handoff calls an allocator.

## Two distinct actions

1. `review(orderId)` checks the current account/session and owned checkout, then
   returns exact tier, amount, currency, country, provider, recipient and USSD code
   for display. It performs reads only. No dialer or checkout POST is sent.
2. After those fields are displayed, an explicit user action calls
   `confirm(reviewId, true)` (TypeScript) or
   `confirm(reviewId, acknowledgement: true)` (Dart). The controller consumes its
   in-memory review, rereads the checkout, compares every payment field and expiry,
   rechecks the same session, persists a reservation, and invokes the platform once.

The boolean and review ID are interaction guards, not proof that a human actually
reviewed the screen. The integrating UI must display the exact values accessibly
and bind the method only to the intended foreground user action. There is no newly
rendered screen, app navigation entry or automatic app integration in this batch.

Reviews expire after 30 seconds on a monotonic clock. A checkout requires at least
15 seconds of remaining server-observed validity, reduced by elapsed read/storage
time. These are conservative pilot choices, not a provider settlement guarantee.
The controller invalidates its review on explicit `invalidateReview()`: the UI must
call it on backgrounding, route exit, logout and account changes. `recover()` also
invalidates review state. A result can still change after the last read: neither a
carrier dialer nor two independent backend databases participate in one transaction.

## Recovery that does not cause another payment attempt

A process/isolate-safe exclusive lock and durable compare-and-set protect the
`africlub-payment-handoff-v1:<club>:<user>` record. The marker is written and read
back **before** calling the dialer. It contains only schema version, user/club,
order ID, attempt ID and phase; it contains no token, OTP, amount or dialer code.
IDs are still personal/linkable data and need an approved retention/erasure design.

Phases are `reserved`, `opened`, `not_opened` and `unknown`. `opened` means only that
the platform reported opening an external application. `paymentVerified` remains
false. Platform failure, an exception, an interrupted response and provider
settlement are different things. A timeout does not cancel a platform action that
may already have started. A failed final storage write retains the earlier reserved
marker and reports an unknown handoff outcome.

A restart or `recover()` reads the marker and server status only. It never launches,
retries, prepares, refreshes, cancels, clears an unresolved marker or generates a
replacement payment operation. A prior `reserved`, `opened` or `unknown` attempt
blocks another handoff in the same user/club scope until the server reports that
its order has been allocated. **Expired, cancelled or changed configuration is not
proof that no payment occurred**. The absent operator/late-payment exception flow
must resolve such cases before shipping. This can intentionally strand an unsent
reservation after a crash; it is an availability trade-off, not exactly-once payment.

`not_opened` permits a new explicit review because the platform reported failure
to open. It never triggers automatic retry. Native adapters must make one invocation
only and must not report `false` for an uncertain already-started invocation.
No online/local record can protect against a user manually making a separate
payment outside the app, or clearing/restoring OS state. Server evidence remains
authoritative and duplicate-provider-reference protection must remain intact.

## Native Dart source

`packages/features/feat_membership/lib/native_membership.dart` is a separate
opt-in entrypoint. It contains strict response models, a native bearer client,
a `dart:io` transport, original-key checkout recovery and the handoff controller.
It does not accept Supabase credentials or alter the existing membership exports.

The transport creates a dedicated HttpClient for one operation, uses normal TLS
trust, disables redirects and transparent decompression, bounds response bytes and
closes the client on timeout. It does not install a certificate exception, proxy
bypass, cookie session or automatic retry. The response supplier and platform proxy
configuration must be reviewed in actual devices. Browser/Flutter Web usage is not
supported by this native IO library.

The separate `native_membership_flutter.dart` bridge uses the package's existing
`url_launcher` dependency with an external `tel:` URI. The hash is encoded as path
data, not a fragment. It is disabled by default, supports only the Android/iOS
platform selection and neither requests SMS/call permissions nor directly sends
USSD. Actual carrier, SIM selection, installed dialer and iOS restrictions vary;
**no successful handset USSD behavior is established here**. Unsupported platforms
must remain unavailable rather than report payment success.

The `NativeRecoveryStore` and credential supplier are required integration ports.
No real Keychain/Keystore store, process lock, account-backup policy or credential
lifecycle implementation is shipped. Never replace them with preferences,
localStorage or the in-memory test store in a released app. The TypeScript
`RecoveryStore` and the Dart store must not be used independently with incompatible
locking over the same underlying record. App composition must designate one owner.

## Verification commands and boundaries

```sh
node cloudflare/supporter-membership-api/scripts/compile-handoff.mjs
node --test cloudflare/supporter-membership-api/tests/*.test.mjs
python3 tools/scripts/verify_native_membership.py --results /tmp/africlub-native-check
```

The TypeScript controller is strictly compiled and exercised with the actual
existing gateway/identity/checkout/allocation implementations and synthetic data.
`wire-vectors.json` contains synthetic valid responses generated from those actual
services plus malformed variants. Node tests verify these fixtures against the
current reference client. This is not Dart execution or cross-language proof.

The Python verifier is offline and requires Dart >=3.10 <4. It copies only the pure
Dart files into a temporary dependency-free package, runs the actual analyzer and
standalone contract harness, and reports missing tools as `blocked` (exit 2).
It deliberately excludes the Flutter bridge. **At delivery the SDK is unavailable,
so the Dart analyzer and harness have NOT executed.** The files are source candidates,
not a claim of compiled native code. Flutter >=3.38, full workspace analysis,
platform secure-storage tests, physical-device journeys and app review still apply.

The harness is test-only. Its in-memory store and simulated dialer must never be
used as the application implementation. Node integration tests do not send a real
message, pay, grant a real membership, call a carrier or deploy a Worker.

## Remaining release gates

Wire the opt-in library into reviewed app composition only after Dart/Flutter
checks pass and the platform ports exist. Required acceptance includes duplicate
taps, slow networks/storage, same-user reauthentication, account changes, kill and
restart before/after platform invocation, multiple isolates/processes, locked or
invalidated Keychain/Keystore, restored backups, SIM/carrier behavior, accessibility,
late payments and pending exceptional outcomes. Backend cross-database revocation,
source import parity, provider evidence, historical reference completeness and
single-writer cutover remain outstanding. No live flag or release approval is set.

## Sources and external implementation guidance

Repository basis: current gateway `README.md`, `client.ts`, OpenAPI, existing
service fixtures and feature `pubspec.yaml`; hashes are recorded in the delivery.
The 27 September native source is distinct from the pre-existing 26 September
server source. No historical cumulative v1-v4 archive overrides current Drive.

Official technical guidance, not verification of this app or an endorsement:
- https://api.dart.dev/dart-io/HttpClient-class.html
- https://api.dart.dev/dart-io/HttpClientRequest/followRedirects.html
- https://api.dart.dev/dart-io/HttpClient/autoUncompress.html
- https://api.dart.dev/dart-core/Uri/Uri.html
- https://pub.dev/packages/url_launcher

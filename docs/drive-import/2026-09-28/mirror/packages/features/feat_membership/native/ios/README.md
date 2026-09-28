# iOS native checkout recovery — opt-in source candidate

Date: 27 September 2026. This is the iOS counterpart to the existing Android recovery
channel and the Dart `PlatformNativeRecoveryStore`. It does not replace any existing
source, register an app engine, change entitlements, add a dependency, run a payment,
or deploy a backend. The public native channel remains
`africlub/native-checkout-recovery/v1` with the same four operations.

## Implemented and tested versus authored

The portable Swift codec, installation anchor, advisory file lock, lease registry,
compare-and-set coordinator and strict method dispatcher compile with Swift 6 and
warnings treated as errors. Tests execute real files, POSIX locks, threads and child
processes. They use **explicitly unprotected test backends**. Those results are not
cryptography, Apple Keychain, UIKit, Flutter or device-security tests.

`KeychainRecoveryBlob.swift`, `IOSNativeRecoveryHost.swift`, the iOS Dart channel,
and seven real-Keychain XCTest cases are authored but not Apple/Dart compiled or
executed in this environment. They must be built in the actual signed target with
its real entitlements and tested on iOS before registration. Passing the portable
verifier never marks the whole native release as ready.

## One recovery contract, separate OS storage

The existing Android host writes an app-encrypted file using a Keystore key. This
iOS host instead places the bounded recovery snapshot directly in an app-scoped
Keychain generic-password item. It requests `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
and explicitly disables synchronization. It validates the returned item policy and
never migrates a weaker existing item silently. No key material crosses Dart.

The only app-private files are `recovery.lock` and `installation.anchor`. A matching
installation identifier is included inside the Keychain snapshot. One global
installation lock spans the entire Dart critical section, across every account and
club scope. An NSLock-protected registry serializes in-process engines; `flock`
coordinates cooperating processes. A lease never expires while its operation runs.
The lock inode is checked; the host never deletes or replaces the lock file.

The direct Keychain snapshot is a deliberate iOS adaptation, not a portable file
format or an Android-state migration. Both platforms retain the same maximum 64
scopes and 2,048 UTF-8 bytes per value. The iOS binary envelope is capped at 160,000
bytes. Keychain latency and maximum-size acceptance require actual device tests;
these limits are pilot bounds, not proven capacity. Keychain's durability behavior
is owned by the OS. This source does not claim to fsync the Keychain database.

## Strict recovery and error behavior

A new installation initializes only when both the Keychain item and anchor are
absent. A surviving item with a missing anchor, or anchor with a missing item, blocks
recovery. Corrupt/unknown formats, application/installation mismatches, lock loss,
unsafe files and inaccessible protected data are errors, not an empty store.
An interruption after anchor creation can require governed recovery; no reset or
key deletion is provided.

A successful CAS acknowledgement follows the item update and exact byte readback.
False means an expected-value conflict only. A write error is conservative and may
mean the update committed. In particular, Swift's canonically equivalent String
comparison is **not** used for CAS: UTF-8 bytes must match the Dart contract exactly.
Never use an uncertain response as permission to erase a marker or retry a payment.

`tryAcquire` with the same engine, scope and acquisition ID recovers its existing
lease after a lost reply. Release is keyed by the original acquisition ID; a stale
release cannot unlock a newer lease. Release and disposal do not erase markers.
Wrong owners/scopes/tokens and extra request fields are rejected. No caller supplies
a path, Keychain service/access group, bundle identity or protection policy.

This storage does **not** supply credentials, financial authority, account-erasure,
key rotation, manual override or late-payment resolution. The generic value port is
intended only for the existing checkout/handoff markers; it cannot intrinsically
prevent trusted app code from passing arbitrary text. Do not put tokens or PINs here.

## Lifecycle and app registration

The host is deliberately not an automatically registered plugin. Add its `Sources`
files once to a reviewed shared native module or the appropriate app target. Do not
copy five diverging implementations. No project/build modification is included in
this batch. Verify each club's bundle ID and default Keychain access group; no new
sharing entitlement or explicit access group is requested by this implementation.

On the main actor, after the actual engine is available and the app is active with
protected data available, explicit composition can call:

```swift
let recoveryHost = try IOSNativeRecoveryHost.install(
    messenger: actualEngine.binaryMessenger,
    enabled: approvedNativeRecoveryFlag
)
// Retain recoveryHost with this engine. Call recoveryHost?.dispose() on disposal.
```

The example is a composition contract, not an installed call site. The host defaults
to disabled, caps queued calls at 32, runs blocking Keychain/file work off-main and
returns channel replies on main. Protected-data/background notifications gate new
work; Keychain policy independently restricts access. A lock/background race is not
represented as an atomic carrier/payment cancellation. Dispose removes the handler,
stops new calls and queues owner-lock cleanup after existing work; no timer releases
a still-running handoff. The app must still invalidate reviewed payment instructions
on logout, route exit, account change and background transitions.

Dart composition uses the new separate
`package:feat_membership/native_membership_storage_ios.dart` entrypoint and
`IOSCheckoutRecoveryChannel(enabled: approvedNativeRecoveryFlag)` as the existing
platform store's channel. Android exports and current app routes remain unchanged.
The root SDK requirements remain Dart >=3.10 and Flutter >=3.38. The Swift core is
verified with the installed Swift 6 compiler; actual Xcode/app build settings are
unchanged and must be verified independently.

## Validation

```sh
python3 tools/scripts/verify_ios_recovery.py --results /tmp/africlub-ios-recovery
```

This compiles a fresh portable executable before each run and executes the bounded
harness. It makes no network or provider calls, installs no SDK and never executes
an older binary after a compile failure. Its success means `passed_portable_only`.
The Apple files are explicitly excluded from the portable compile target.

For Apple acceptance, add `Tests/KeychainRecoveryIntegrationTests.swift` and the
actual Apple/core sources to an isolated XCTest target. The seven cases use unique
synthetic Keychain namespaces and clean up only their exact test items. Run them on
unlocked test devices. No Keychain cleanup exists in the production adapter. Separately
validate device lock/unlock, foreground transitions, engine disposal during a call,
reinstall/restore and real plugin/channel behavior. Full Flutter and five-club builds
and accessibility/payment-handoff tests remain required.

## Unresolved release boundaries

If the entire app data and Keychain item are lost, local state cannot distinguish
that from a genuinely new installation. A privileged rollback of a valid prior
snapshot is also outside this component's protection. Server-authoritative recovery
for uncertain payments remains mandatory. A migrated/restored device may lack
ThisDeviceOnly items. Do not reset either half of a mismatched installation.

Advisory locks require all trusted participants to use the same compiled registry,
root and Keychain namespace. They do not defend against arbitrary trusted code or a
compromised device bypassing the protocol. No Secure Enclave/hardware-backing claim
is made. Backup exclusion, protection classes, Keychain access group, item size,
error/retry semantics and device behavior require real acceptance.

Source upload and verification do not approve release, retention, payments or the
Supabase cutover. This batch has not been uploaded when write actions are absent;
the delivery manifest records the actual state, not an intended successful upload.

## Primary guidance checked

- https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly
- https://developer.apple.com/documentation/security/ksecattrsynchronizable
- https://developer.apple.com/documentation/security/secitemupdate(_:_:)
- https://docs.flutter.dev/platform-integration/platform-channels

These references describe platform APIs; they are not evidence that this app has
been built, its Keychain tested, or its shipping entitlements approved.

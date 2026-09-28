# Android recovery storage — opt-in source, portable core verified

27 September 2026. This component supplies the durable `NativeRecoveryStore` storage
boundary for the existing native checkout and payment-handoff controllers. It is
**not registered in a Flutter application, not Android/Flutter compiled, and not
approved for production use**. The portable Kotlin engine has been compiled and
executed on a desktop JVM. That does not validate AndroidKeyStore or a device.

## Implemented boundary

`PlatformNativeRecoveryStore` adapts the existing Dart recovery port to the fixed
`africlub/native-checkout-recovery/v1` channel. The optional Android host gives each
Flutter engine a fresh dispatcher owner. Caller arguments cannot choose a filename,
key alias, host directory or dispatcher owner. The interface exposes acquire, load,
compare-and-set and release only. There is no delete/reset, payment, dialer, token
refresh, key export, signup or entitlement operation.

The intended values are the existing checkout-request and handoff markers. Do not
use this string store as a bearer-token supplier: the schema does not intrinsically
prevent application code from passing other text, and token storage/account recovery
is a separate unfinished integration. Marker user/club/order IDs remain personal
information even when encrypted. No raw SMS, payment PIN or code is needed here.

## Encrypted durable replacement

One installation-wide snapshot is encrypted using AES-256-GCM and an application-ID
bound associated-data string. The Android host obtains its AES key from
AndroidKeyStore; it never exports it or places it in Dart, configuration or source.
The provider generates each encryption IV. Test keys are ordinary JVM test keys,
not evidence of Android hardware-backed storage or StrongBox availability.

The production host selects only `Context.noBackupFilesDir`, a fixed private child
directory and fixed state/lock filenames. Each replacement writes a new same-directory
temporary file, forces it to disk, atomically replaces the snapshot, syncs the directory
and verifies a fresh read. There is no non-atomic copy fallback. If any required step
fails, the operation is not reported as a successful write. Failures after a rename
may mean that the new value exists; they are deliberately classified as uncertain.
Do not retry a financial operation with a fresh key on that basis.

Existing ciphertext without a key, or a key without the state file, blocks recovery.
Corrupt, modified, unsupported-version, truncated or oversized snapshots block
recovery. The store never regenerates a key to silently discard old state. Initial
creation is allowed only when both state and key are absent, under the global lock.
The snapshot is bounded to 64 scopes and 2,048 UTF-8 bytes per value. Capacity fails
closed; no old pending marker is evicted. Limits are pilot choices, not retention
approval. No erasure, compaction, key rotation or lost-state resolution is implemented.

**Uninstall, clearing all app data, or restoring an old complete app state remains an
unsolved release requirement.** If both key and file disappear, local code cannot
prove whether the app is new or has lost an unresolved payment attempt. This module
also cannot stop a privileged attacker from rolling back a valid old encrypted
snapshot. A server-authoritative unresolved-operation recovery protocol and tested
installation lifecycle are required before real payments use this component.

## One global lock, no expiring permission to retry

The implementation combines a process-wide lease registry with an operating-system
file lock. All recovery scopes in this installation serialize through it, including
multiple engines and adapter instances. This intentionally sacrifices parallelism
for straightforward snapshot consistency. The OS lock is held across the caller's
whole asynchronous critical section. It has no lease timer that could permit another
process to start a competing handoff while the original work is still in progress.

Acquisition IDs are original operation IDs. Repeating one acquisition by the same
engine/scope returns its token. Release uses that acquisition ID so a caller can
release a lock even after losing the successful acquisition reply. A stale release
cannot release a newer lock. Process termination releases the OS lock but does not
delete the persisted reservation. Same-process registry access is synchronized.
All processes accessing the recovery files must use this implementation; arbitrary
app code, a different classloader, privileged/root access and raw-file manipulation
are not made safe by advisory locking.

The Flutter wrapper queues at most 32 calls on one I/O executor per engine. Crypto and
file I/O are not performed on the main UI thread. Detaching an engine removes pending
work and closes that engine's lease after running work finishes. An isolate that dies
without destroying its engine can leave a live lease until that engine is disposed or
the process restarts. This is an availability block, not permission to clear state or
expire the lock. Diagnose and restore read-only before any explicit new handoff.

The Dart adapter maintains an asynchronous zone-bound lease, refuses nested locks
(even through another adapter), and refuses storage operations outside the matching
active scope. Once work completes, asynchronously escaped tasks cannot reuse the
released lease. A release error remains uncertain and must not be treated as proof
that no earlier work happened. Different devices are not coordinated by this lock.

## Android host and unlocked-device limits

The optional host requires Android API 26+ and an unlocked user/device before data
access. It uses a fixed AndroidKeyStore alias and an application-owned no-backup path.
No SMS, call, storage or network permission is added. The current application minSDK,
Gradle dependencies, Kotlin plugin version and Flutter manifests are not changed.

`setUnlockedDeviceRequired(true)` is selected only on API 35+. Android documents
key deletion and unlock-related bugs on API 31–34; this candidate does not opt those
versions into that behavior. Earlier supported versions use explicit application-level
locked-device checks, not a claimed hardware-enforced unlock policy. Locking can race
with application-level checks. Real device tests, screen-lock removal/change,
credential reset and key invalidation must be reviewed before supporting those OS
versions. No biometric assurance or universally hardware-backed key is asserted.

## Integration after native acceptance—not performed here

Keep all registration flags false while testing the source. The pure Dart adapter is
exported by `native_membership.dart`; the Flutter channel has a separate
`native_membership_storage_flutter.dart` entrypoint. Configure both the channel and
store explicitly. A disabled or missing channel fails; there is no preferences,
in-memory or plaintext production fallback.

After compiling the native source against the project's actual Android and Flutter
embedding versions, register one fresh `NativeCheckoutRecoveryPlugin` per engine in
a reviewed staging-only composition. Make the source directory available once in the
shared host build; do not duplicate the implementation into five independent copies.
Use the existing workspace Kotlin/AGP/Flutter configuration rather than copying the
portable test compiler version into the app. This delivery does not modify Gradle,
register a plugin, add a package, replace the old membership module or switch any club.

Supply `PlatformNativeRecoveryStore` to the existing checkout/handoff controllers.
Use the separately protected credential supplier and accessible confirmation/lifecycle
integration; those are still missing. The marker persists before a platform attempt,
and the existing controller requires explicit review and confirmation. Application
background/logout/route changes must invalidate the in-memory review. Do not delete
recovery markers merely because an order is expired, cancelled, configuration-changed
or the platform response is uncertain. Those do not prove that no payment occurred.
The iOS Keychain/locking counterpart is not implemented by this Android source.

## Verification

From a matching checkout:

```sh
python3 tools/scripts/verify_android_recovery.py --results /tmp/android-recovery-core
python3 tools/scripts/verify_native_membership.py --results /tmp/native-dart
```

The first command compiles exactly the four portable Kotlin engine/dispatcher sources
and a standalone harness, with warnings treated as errors, into a **fresh temporary
JAR**. It only runs that JAR after compilation succeeds. The harness uses real local
files, AES-GCM, process locks, multiple threads and child processes, including a killed
process holding a persisted reservation. It records the hashes of source inputs and
keeps Android host, Keystore and Flutter/device fields unverified. No JAR/SDK is shipped.

The second command still requires a real Dart >=3.10 SDK and exits 2 when absent.
Its additional platform-channel harness uses a channel double, not Android storage.
No Dart tests, Flutter analyzer, Android host compile, real Keystore invocation,
backup/reinstall test, carrier call or signed application test was executed here.
The previous handoff tests are not relabeled as native tests.

## Required release evidence

Compile the host against the existing project toolchain; analyze/run the Dart harness
and full feature tests; integrate and test engine/isolate lifecycle; verify actual
KeyStore policies and filesystem persistence; test screen lock, reboot, process kill,
power interruption, low disk space, key invalidation and app update/reinstall; inspect
backup and restore behavior; implement server-side lost-state recovery; and verify all
five club compositions and iOS behavior separately. Preserve the original operation
keys and review all uncertain outcomes. No automatic payment retry is introduced.

## Primary implementation references

- https://developer.android.com/privacy-and-security/keystore
- https://developer.android.com/reference/android/content/Context#getNoBackupFilesDir()
- https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec.Builder#setUnlockedDeviceRequired(boolean)
- https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/FileLock.html
- https://api.dart.dev/dart-io/RandomAccessFile/lock.html
- https://docs.flutter.dev/platform-integration/platform-channels

These references explain platform interfaces; they are not evidence of a deployed,
secure-against-all-threats, privacy-compliant or production-approved implementation.

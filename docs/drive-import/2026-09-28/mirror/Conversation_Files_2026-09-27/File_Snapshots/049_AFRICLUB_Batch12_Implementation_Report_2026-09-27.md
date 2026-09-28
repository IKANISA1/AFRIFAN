# AFRICLUB — Batch 12 iOS recovery-store counterpart

27 September 2026. Authoritative repository: AFRICLUB, Google Drive folder
`1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH`.

## Delivery state

**13 new source files are implemented locally. Zero Batch 12 files were uploaded to
Google Drive.** Current Google Drive discovery returned read actions only; the
explicit upload-action query returned no action. Files exposed list/search/read/find/
materialize, not its prior write action. Plugin discovery confirmed that Google Drive
is installed, but supplied no missing write capability. This is an unavailable action
in this turn, not evidence that the user's Drive sharing permissions are wrong.
There was no successful upload, no in-place source write and no remote upload
receipt. The accompanying pending-upload register states the intended exact paths.

All local code, tests, reports, source backup and evidence are included in the source
package or as separate delivery files. No existing app, dependency manifest, build
project, entitlement, backend, database or production flag was changed. There was
no payment, provider request, Keychain provisioning, deployment, app registration,
source deletion or Supabase retirement.

## Implemented scope

The new iOS component follows the existing four-operation native recovery channel:
`tryAcquire`, `load`, `compareAndSet` and `release`. It preserves the existing scope
format, exact-field grammar, original acquisition identifiers, 64-scope capacity and
2,048-byte value bound. Android source and its existing Flutter bridge are unchanged.

| Component | Implemented behavior and verification boundary |
| --- | --- |
| Portable Swift protocol/codec | Strict, bounded binary envelope containing application and installation identity, revision and recovery markers. Rejects duplicate scopes, malformed UTF-8, trailing bytes, unsupported versions and oversized content. Compiled/executed on Linux. |
| File/lease coordination | Fixed private anchor and lock, in-process synchronized registry, POSIX file lock, owner/scope/token binding and lock-inode checks. Original acquisition recovers a lost reply; stale releases cannot unlock another lease. Compiled/executed on Linux. |
| Snapshot CAS | Reads and validates the existing snapshot, checks the expected value byte-for-byte, updates it and verifies exact readback. No silent eviction or reset. Errors after a write are uncertain, never proof of rollback. Compiled/executed against test-only blob storage. |
| Strict method dispatcher | No client-selected owner, path, Keychain namespace, group or policy. No clear/delete/reset/rotate/pay/dial capability. Device/foreground gate can block access while still permitting release. Portable tests inject this gate; they do not test a locked iPhone. |
| Apple Keychain adapter | Authored source uses one app-scoped generic-password item, WhenUnlockedThisDeviceOnly accessibility and no synchronization. Validates existing policy; no missing-item-to-add fallback on replacement. Not Apple-compiled or executed. |
| iOS Flutter host | Authored opt-in main-actor installation, bounded off-main queue, main-thread replies, foreground/protected-data gating and engine disposal. Not installed or compiled in an app. |
| Dart bridge | Separate iOS-only channel export over the existing platform recovery adapter, disabled by default. Not Dart/Flutter-compiled. |
| Verification | Fresh Swift executable built with warnings as errors; 68 portable tests. Seven real-Keychain XCTest cases are supplied separately and were not executed. |

An important cross-language detail is handled explicitly: Swift String equality can
consider canonically equivalent Unicode spellings equal. CAS uses exact UTF-8 bytes
so an expected value with a different byte representation cannot replace the stored
marker. This behavior is covered by a regression test.

## Storage and lifecycle design

The existing Android implementation uses an encrypted file and a Keystore key. This
counterpart instead stores the snapshot directly in Keychain; the private filesystem
contains only the fixed lock and installation anchor. It does not claim to fsync
Apple's Keychain database or to implement a cross-platform ciphertext migration.

The anchor is bound into the Keychain snapshot. Initialization is permitted only
when both are missing. A missing item with an existing anchor, a missing anchor with
an existing item, inaccessible protected data, corruption or mismatched identities
blocks recovery. No automatic reinitialization, reset or deletion is exposed.

The same native lock must cover the entire asynchronous Dart critical section.
It is not forcibly expired by a timer. Different engines/processes must cooperate
through the same fixed application root and Keychain namespace. Arbitrary trusted
code or a compromised device can bypass advisory locks; this is not a defense
against those actors.

The host remains opt-in and requires explicit installation after the actual Flutter
engine is available and the app is active. It must be retained with that engine and
disposed when the engine is destroyed. The app must still invalidate reviewed
payment instructions on background, logout, account changes and route exits.
No call site was inserted into any of the five club applications.

## Executed verification

| Completed suite | Passed |
| --- | ---: |
| Existing gateway, handoff and wire contracts | 283 |
| Existing payment allocation and membership checkout | 432 |
| Existing authentication/delivery/HTTP subset | 77 |
| Existing portable Kotlin/JVM recovery | 69 |
| New portable Swift recovery | 68 |
| Installer/rollback regressions | 33 |
| **Total targeted passes** | **962** |

Every counted suite completed without failed/skipped tests. The Node suites also
reported zero cancelled/todo cases. The combined runner reached the host command
limit after the portable checks; missing installer slices were then executed
independently. All six complete installer outputs were checked before aggregation.
Incomplete runs are not counted. The initial manifest preflight rejected a missing
root-manifest precondition; that condition was added without weakening the installer.
Initial Swift warning/concurrency-capture errors in the harness were corrected before
the final warning-as-error build. Initial evidence remains separate.

The Swift tests use real host files, POSIX locks, threads and child processes but
**unprotected test blob stores**, not Apple Keychain. They exercise independent
process contention and process termination after saving a reservation. These tests
prove the portable coordination behavior only. They are not cryptographic or iPhone
storage acceptance. The inherited Kotlin tests execute their own genuine local
AES-GCM code; that does not validate the new Apple implementation.

The new Apple adapter/host/XCTest files received only syntax parsing with their
platform guards; that is not Apple SDK typechecking. Seven Apple XCTest cases remain
unrun. The existing pure-Dart verifier returned `blocked` because the required SDK is
absent. The Flutter bridge, Android host, Android Keystore, iOS Keychain, handset,
full application, real D1/provider and production capacity gates remain unverified.
The root Dart >=3.10 / Flutter >=3.38 requirements were preserved.

## Source grounding and installation tests

Five source inputs were freshly read/downloaded from Drive: the existing recovery
channel contract, Dart platform store, Android Flutter channel, shared port interfaces
and root pubspec. Their exact bytes matched the preserved Batch 11 source subset.
The remaining 114-file context comes from that prior archive, whose 184 checksummed
entries were validated; it is not a fresh whole-monorepo export.

The exact additive patch passed local preflight, application, after-hash checks,
repeat application and rollback in three disposable states: none of this batch
installed (13 changes), alternating entries present (6 changes), and everything
already matching (0 changes). Rollback restored starting bytes and preserved
pre-existing matching additions. No trial changed Drive or a real application.

Unknown source changes, symlinks, conflicting additions or invalid checksums stop
the installer. Source writes are individually atomic, not one global filesystem
transaction. Stop editors/builds during local application. The `context/` directory
is test/reference material, not authority to overwrite a newer checkout.

## Pending uploads and commands

Intended source destinations are below:

- `AFRICLUB/packages/features/feat_membership/native/ios/`
- `AFRICLUB/packages/features/feat_membership/lib/native_membership_storage_ios.dart`
- `AFRICLUB/tools/scripts/verify_ios_recovery.py`

Intended delivery directory, **not created in this turn**:
`AFRICLUB/output/refactor-2026-09-27/batch12-ios-recovery/`.
The pending-upload register contains all source destinations and checksums. It is
not a Google Drive receipt. Earlier verified batches are not rewritten as pending.

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"          # read-only preflight
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-batch12"
```

The full verifier intentionally exits 2 for unresolved real native acceptance even
when all portable suites pass. The source-level `verify_ios_recovery.py` command
reports only `passed_portable_only`. Neither script uploads, provisions, executes
remote SQL, registers plugins, contacts providers or deploys.

## Remaining release requirements

Actual Apple/Dart/Flutter compilation, Keychain tests with real entitlements, maximum
item-size/latency tests, lock/unlock/foreground behavior, reinstall/restore, protected
credential storage, accessible confirmation screens and all-five-app registration
remain incomplete. All flags stay disabled by default.

Complete loss of both local anchor and Keychain state is indistinguishable locally
from a fresh installation. A privileged rollback to an older valid snapshot is also
not prevented. Server-authoritative recovery for uncertain payments remains a
mandatory release dependency. Expiry/cancellation still does not prove no payment
occurred. Native storage does not resolve late-payment operations, cross-database
revocation, actual payment reconciliation, refunds, contribution rewards/referrals,
shop/ticket migration, economic approvals, retention, backup/media recovery or the
single-writer cutover. The full implementation is not complete.

## Primary platform references

- Apple: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
  https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly
- Apple: `kSecAttrSynchronizable`.
  https://developer.apple.com/documentation/security/ksecattrsynchronizable
- Apple: `SecItemUpdate`.
  https://developer.apple.com/documentation/security/secitemupdate(_:_:)
- Flutter: platform channels and platform threading.
  https://docs.flutter.dev/platform-integration/platform-channels

These were used as API guidance, not as evidence of a successful device build.

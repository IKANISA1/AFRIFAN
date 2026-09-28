# AFRICLUB — Batch 11 native recovery storage

27 September 2026 (Africa/Kigali). Authority: current AFRICLUB Google Drive source,
folder `1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH`, and the preserved Batch 10 source subset.

## 1. Delivered source and actual validation boundary

**All 16 source changes are saved individually at their intended Drive paths:**
13 additions and three in-place updates. The existing native library export, native
checkout documentation and Dart verifier retain their original Drive file IDs.
A checked pre-change source archive was uploaded before replacement. All sixteen
saved source files were downloaded and matched the exact tested SHA-256 values.
The checkout reconstructed from those downloads reports zero outstanding changes.

**894 targeted tests passed:** 792 preserved Node tests, 69 new portable Kotlin/JVM
recovery tests, and 33 inherited installer/rollback tests. The new Kotlin engine and
dispatcher compile with warnings treated as errors. The 69 recovery tests also passed
when compiled afresh from the downloaded Drive sources; repeated executions are not
added to the count.

**Android host, AndroidKeyStore, Dart, Flutter and physical-device acceptance did not
run.** The optional Android/Flutter host and Dart bridge are authored source, not
compiled application proof. The pure Kotlin engine is real compiled/executed code on
Linux/JVM, not a simulated Android build. The overall native gate remains blocked.
No platform class stubs were used to manufacture an Android compilation result.

No club application, runtime route, dependency manifest, Gradle configuration,
production service, database migration or membership/payment writer was changed.
No real key was provisioned, no payment or message was sent, and no app was switched.
The new adapters are disabled by default and are not registered with any app engine.
No existing Supabase flow was replaced or retired.

## 2. Implemented components

| Component | Implemented behavior |
| --- | --- |
| Portable encrypted engine | Application-bound AES-GCM snapshot, strict version/UTF-8/size decoding, private fixed filenames and compare-and-set replacement. One installation snapshot contains bounded recovery markers. |
| Durable write | Temporary-file sync, atomic same-directory replacement, directory sync and readback before a successful write acknowledgement. No non-atomic copy fallback. An error after replacement is uncertain, not proof of rollback. |
| Process and thread coordination | A process-wide lease registry plus an OS file lock serializes every recovery scope in the installation. Active locks do not expire on a timer. Killing a process releases its OS lock without deleting its saved reservation. |
| Engine-bound dispatcher | Strict acquire/load/CAS/release arguments with a fixed host owner. Wrong tokens/scopes/owners and extra fields fail. No caller-selected paths, key aliases, reset, clear, dial or payment operations. |
| Optional Android host | Fixed app-private no-backup directory, AndroidKeyStore AES key source, unlocked-device checks, bounded off-main-thread queue and per-engine cleanup. This host source was not Android-compiled or device-tested. |
| Dart recovery adapter | Implements the existing NativeRecoveryStore port, normalizes platform-codec maps, binds access to an active asynchronous scope, refuses nested/escaped lock use, and releases by the original acquisition ID even after a lost reply. Not executed without the Dart SDK. |
| Offline verification | A fresh temporary JAR is compiled before each portable run; failed compilation cannot execute a previous JAR. The Dart verifier includes the new authored channel harness and still reports missing native tools as blocked. |

The intended stored values are the existing pending checkout and payment-handoff
markers, not bearer credentials or payment PINs. The string API does not intrinsically
prevent a caller from supplying other text; token storage is not implemented here.
The Android host is separate from the current authentication and financial services.
It does not grant identity, membership, entitlement or payment authority.

## 3. Failure and recovery semantics

A missing key with existing ciphertext, missing ciphertext with an existing key,
corruption, unsupported version, truncation and oversized state block recovery.
The engine does not silently create a new key or empty store after those errors.
CAS returns false for a conflicting expected value; write failures do not become
false/no-op acknowledgements. A failed final write may already exist on disk.

The same engine/scope/acquisition ID can recover the lock token after a lost
acknowledgement. A stale release cannot release a later acquisition. Lease ownership
covers the caller's entire asynchronous critical section. No timer forcibly releases
a still-running payment handoff. Another process remains blocked until release or
process termination. An isolate that dies while its engine remains alive may leave
a lease until engine disposal/restart; it is not permission to discard uncertainty.

The store refuses to evict old pending markers when its 64-scope/2,048-byte-per-value
limits are reached. Those are pilot bounds, not a retention policy. No reset, erasure,
key-rotation or operator-override operation is supplied. Expired or cancelled checkout
orders still do not establish that no payment happened; existing handoff protections
remain unchanged.

**Whole-installation data loss is not solved by local encryption.** Clearing all app
data/uninstalling can remove both key and file, making a lost installation locally
indistinguishable from a new one. A valid old encrypted snapshot can also be rolled
back by sufficiently privileged access. A server-authoritative recovery protocol,
installation lifecycle and late/unknown-payment workflow remain required before
production. The component makes no claim of protection against root compromise or
arbitrary trusted application code bypassing its advisory locks.

## 4. Android-specific limits

The optional adapter requires API 26+ without changing any app's current minSDK.
AndroidKeyStore keys are requested only by the native host; no key bytes are exported
to Dart. Actual hardware backing/StrongBox and device key policy are not verified.
On API 35+ the host requests an unlocked-device-required key. For earlier supported
versions it uses application-level unlocked-device checks instead; it does not claim
hardware-enforced unlock behavior there. This avoids opting API 31–34 into Android's
documented unlocked-device key deletion/unlock bugs, but still needs real device
acceptance and a support-policy decision. Locking can race with software checks.

The Flutter host is not in any app's native build or registered engine. Its source is
provided once under the shared membership feature for later governed integration,
not duplicated across five shells. The installed JVM test compiler is not substituted
for the repository's Android Kotlin/AGP versions. Dart >=3.10 and Flutter >=3.38 remain
unchanged. The iOS Keychain/locking counterpart is not provided by this Android work.

## 5. Executed tests and honest aggregation

| Executed group | Passed |
| --- | ---: |
| Existing gateway, native-handoff reference and wire-contract Node tests | 283 |
| Existing payment allocation and membership checkout Node tests | 432 |
| Existing supporter identity/delivery/HTTP Node subset | 77 |
| New portable encrypted storage, locking and dispatcher JVM tests | 69 |
| Reused source installer and rollback regressions | 33 |
| **Total targeted passes** | **894** |

Every counted suite finished with zero failures/skips. Node suites also reported zero
cancelled/todo cases. The combined runner reached the host command limit during
installer slices; the missing slices were run independently, and all six complete
slice outputs were checked before aggregation. Partial runner executions are not
counted as passes. Initial Kotlin warning failures and a manifest-overlap rejection
were fixed; the final compile and manifest passed. No test or security rule was
removed to produce the final result.

The new harness uses real local AES-GCM, files, fsync/atomic replace, OS locks,
threads and child processes. Cases cover expected-value conflicts, Unicode bounds,
corrupt/truncated/versioned state, missing/wrong keys, application binding, scope
limits, wrong engine/lease, stale release, interrupted writes, simultaneous engines,
thread/process contention, and killing a process after persisting a reservation.
Android locked-device checks in dispatcher tests are injected test controls, not
proof of the actual Android host or AndroidKeyStore enforcing those policies.

The authored Dart channel harness contains twelve new behavioral cases, but **none
were executed** and they are not in the 894 total. Earlier Dart contract cases also
remain blocked. Three JSON/Python syntax checks passed; strict TypeScript and the
existing disabled service configuration checks passed. No full Flutter/Next.js,
pgTAP, real D1, Android build, emulator, handset, browser or provider test ran.

Environment: Node 22.16.0, Python 3.13.5, Kotlin/JVM 1.9.0, OpenJDK 21 and TypeScript
5.8.3. Actual captured tool-version logs are included. The Kotlin portable version
does not change the application build toolchain. Native SDK access remained unavailable;
no policy restriction was bypassed and no SDK/font/JAR binaries are distributed.

## 6. Source preservation and reversible installation

Six critical native files were freshly read from Drive and matched against the
prior package before implementation. The three original files to be replaced were
read and checked again immediately before the in-place updates. Unchanged context
comes from the 147-checksum-verified Batch 10 package, not a fresh full repository
export. A separately read Android build reference was preserved without changes.

The exact patch passed source preflight, application, hash checks, repeat application
and rollback in three disposable reconstructions:

| Starting state | Changed files | Result |
| --- | ---: | --- |
| Scoped current baseline | 16 | Starting source bytes restored by rollback. |
| Alternating changes already installed | 8 | Previously present versions retained. |
| All files already matching | 0 | No source writes. |

All sixteen downloaded Drive files matched the source manifest. A readback-built
checkout reports zero outstanding changes. Its portable core was compiled again and
all 69 tests passed. The native verifier still returned blocked. No readback repetition
is counted twice. The source installer retains exact before hashes, preserves existing
permissions and stops on unknown edits rather than forcing a downgrade.

The pre-change archive contains the 101-file scoped baseline, one Android build
reference and provenance. It is not a complete monorepo, device backup, real user
export or production database backup. Source-only bundles exclude dependency caches,
SDK/JAR binaries, original media, secrets and fonts. Synthetic test keys/IDs are not
real credentials. Stop editors/builds during multi-file application: individual writes
are atomic, but the entire directory operation is not a global filesystem transaction.

## 7. Saved destinations and usage

New engine/host source, contract, tests and runbook:
`AFRICLUB/packages/features/feat_membership/native/android/`.
Dart adapter/channel/harness: the existing membership feature's lib/test paths.
Native verifiers: `AFRICLUB/tools/scripts/`.

All source paths, exact Drive IDs, hashes and readback results are in the source
verification register. Deliverables are saved below:
`AFRICLUB/output/refactor-2026-09-27/batch11-native-recovery-storage/`.
The final delivery receipt records actual archive/report uploads and readback hashes.

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-batch11-checks"
```

The matching Drive source already contains the patch. This incremental package is
not a historical cumulative v1–v4 replacement. The native gate remains blocked even
when the portable tests pass. No script deploys, registers an app plugin, applies
remote SQL, sends a payment/message or provisions a production key.

## 8. Remaining work

Compile/test the actual Android host and Dart/Flutter adapter, implement iOS storage,
protect credential storage, integrate all five app compositions, add accessible
review/confirmation and lifecycle handling, implement server-side lost-state recovery,
resolve unknown/late payments and cross-database revocation, complete real provider
reconciliation, refunds/contributions/rewards/ticket/shop workflows, measure capacity,
finish retention/erasure and backup/media recovery, and satisfy the controlled
single-writer cutover gates. Prediction/FET approval and Supabase retirement remain
unresolved/unperformed. Inherited action-register items are preserved rather than
presented as fresh production findings.

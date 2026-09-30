# Dedicated native identity credential store

This new implementation derives reviewed storage/locking primitives from the local
checkout store. It has a separate channel, namespace, policy, key/service and files;
checkout sources and their protocol remain unchanged. No payments or network run here.

Configuration is disabled with no approved scopes by default. Native hosts verify
actual application identity and exact host-approved origin/club bindings. Dart also
requires independent device policy acceptance, false by default. Tests use synthetic
keys/backends only and cannot establish real OS protection or release acceptance.

Each journal is at most 8192 UTF-8 bytes. Stable installation-wide process/OS locks
serialize cooperating engines/processes. CAS compares exact bytes; false writes nothing.
Unknown acknowledgement never authorizes a new command key or reset. A FIFO drain
barrier remains behind issued operations before release, including after observed
timeouts. Engine abort fences future calls and drains/aborts queued work before close.

Android uses a separate AES256-GCM AndroidKeyStore key and noBackupFilesDir, plus a
resumed Activity gate and secure/unlocked-device eligibility. API35+ applies unlocked
key policy; earlier APIs have application checks, not claimed hardware enforcement.
iOS uses nonsynchronized WhenPasscodeSetThisDeviceOnly Keychain, foreground/protected
data gates, and backup-excluded complete-protection anchor/lock files. No biometrics
are prompted by this port. Wrong/missing halves, weak policy and corruption fail closed.

Physical device storage, passcode change, backup/restore, reinstall, power interruption,
late engine destruction and signed app acceptance remain open. Revisions are not a
hardware monotonic rollback counter. No silent reset/migration or journal eviction exists.

Primary policy references:
- https://support.apple.com/guide/security/keychain-data-protection-secb0694df1a/web
- https://developer.android.com/identity/data/autobackup
- https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec.Builder

The FIFO admits at most 32 user calls and two reserved cleanup calls. Queue
pressure cannot bypass pending storage work. Engine disposal fences new calls and
settles or rejects queued calls before closing its original owner. Journal CAS
acknowledges only after durable readback; lost acknowledgements remain unknown.

iOS validates every matching metadata record before fetching one unique persistent
reference. It never combines secret-data return with an all-match password query.
All Security calls use an authentication context that disallows interaction.
Android rejects existing alias keys with a wrong algorithm, size, purpose, mode,
padding, origin, expiry or exportability. API 35+ adds the unlocked-device policy
when a new key is generated; application foreground/unlock checks apply to every
use. An older key surviving an OS upgrade is not a hardware-policy attestation.

The synthetic query harness uses injected Security responses on macOS and never
invokes Keychain. Actual SDK compilation proves API compatibility only.

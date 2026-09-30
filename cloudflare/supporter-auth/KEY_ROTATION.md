# Identity key rotation and local recovery

This source implements a forward key lifecycle and its local SQLite/Web Crypto
rehearsals. Runtime templates remain disabled. It does not provision secrets,
authorize a deployment, register a real identity, or establish live D1 acceptance.

## Key and policy contract

`publicKeyPolicy(env)` in `src/crypto.mjs` validates only `AUTH_KEY_VERSION` and
optional public `AUTH_KEY_POLICY_JSON`. It requires no secret material.
`keyPolicy(env)` and `Vault` separately require the matching secret shape.

A version is a canonical string from `1` to `999`. With no policy/keyring variables,
only version `1` accepts the original distinct `AUTH_HMAC_KEY` and
`AUTH_ENCRYPTION_KEY` Worker secrets. Rotated configurations use:

- `AUTH_KEY_VERSION`: the one current write version.
- `AUTH_KEY_POLICY_JSON`: `schemaVersion`, `currentVersion`, `activatedAt` and
  `versions`. Each version contains exactly `version`, `notBefore` and `readUntil`.
- `AUTH_KEYRING_JSON`: a **Worker secret**, containing `schemaVersion: 1` and
  `keys`, whose version entries have distinct `hmac` and `encryption` fields.
  Each key is a random 32-byte value encoded as 64 lowercase hexadecimal characters.
  The legacy secret variables must be absent when a keyring is selected.

One current version has `notBefore = activatedAt` and `readUntil = null`.
Up to three older read versions have a finite deadline between 15 minutes and
seven days after policy activation. Old versions must be numerically smaller.
All HMAC and encryption material is distinct across purposes and versions. No
keyring belongs in Wrangler vars, source control, an app bundle, evidence, or logs.

Every encryption write uses the current version. New ciphertext associated data
binds both that version and the existing record/operation scope. Version-one
ciphertexts retain their original associated data so they can be read and
rewrapped. Reads, HMAC verification and crypto completion recheck the configured
key deadline. Missing live keys, unknown versions, noncanonical ciphertexts and
version/associated-data tampering fail closed.

## Database commitments and phone identity

Apply the five ordered identity migrations to the isolated identity database with
import, browser login and delivery disabled. Migration `0005` adds no keys or
approval and does not enable any gate.

`auth_key_versions` stores immutable SHA-256 fingerprints of registered keys,
not their material. A secret substituted under an existing version is refused.
`auth_key_rotations` immutably records the activation evidence identifier and
original retention bounds. Runtime checks refuse early old-key removal,
retention extension, an unregistered read version, or an obsolete writer. A
subsequent rotation waits until the preceding old read versions have retired;
it cannot extend their old deadlines by introducing another current version.
The settings version advances only forward and must have a registered fingerprint.

`auth_phone_aliases` maps version-specific HMAC lookup values to the original
user UUID. Canonical phone hashes, source IDs, account status, auth epochs and
verification timestamps stay unchanged. Aliases cannot be rewritten or deleted.
A current alias must cover every account before a rotated service can run.
An alias conflict or a decrypted contact that disagrees with the requested phone
stops authentication; the service never heuristically merges identities.

## Explicit local/admin library procedure

The functions below are private library operations. They have no Worker HTTP/RPC
route, schedule, provider call or automatic application launch hook. Their evidence
identifiers are bounded reference strings; accepting one is not proof of human
approval. Live execution still requires separately established authority.

1. For the first **empty** isolated database, call `registerInitialIdentityKeys`
   with version-one secrets, a reference identifier, `import_ready = 0`, SQL
   delivery control disabled, and `AUTH_DELIVERY_ENABLED = false`. Registration
   records fingerprints and creates no identity. An existing database without a
   registry cannot silently adopt replacement secrets through this initializer.
2. Pause import and delivery before a key change. Keep the current settings
   version as `expectedCurrentVersion`; configure a higher current version and
   its retained old read keys in the explicit public policy and secret keyring.
3. Call `prepareIdentityKeyRotation` explicitly with `expectedCurrentVersion`,
   `evidence`, and `batchLimit` from 1 to 100. Repeat explicit bounded batches
   until `complete` is true. It registers the new fingerprint, adds phone aliases,
   and rewraps account/challenge contact copies, pending delivery payloads, native
   verification/refresh responses and browser login/rotation responses. It
   preserves response payloads, operation hashes, row IDs, generations and times.
   Compare-and-set and transaction guards reject concurrent gate changes.
4. Call `activateIdentityKeyRotation` with the same evidence and expected version.
   The transaction rechecks complete alias/cipher coverage, commits the forward
   settings version and immutable lifecycle record, and leaves import/delivery
   disabled. The retention interval must still have at least 15 minutes remaining.
5. Validate the candidate and separately enable only approved service gates.
   An obsolete worker remains unable to serve after the settings version advances.
   An application rollback must preserve the current key contract; changing the
   database version backwards is forbidden.
6. Inspect `identityKeyRetirementReadiness`. Remaining old ciphertexts, live old
   OTPs, missing current aliases or live old-HMAC browser cookies block retirement.
   Browser users may explicitly rotate their credentials while the key remains
   readable. Alternatively, an authorized paused rehearsal can call
   `revokeRetiringBrowserCredentials` with the exact confirmation
   `REVOKE OLD BROWSER CREDENTIALS`; it revokes those browser/auth sessions,
   clears their response secrets and appends audit events. It never recreates
   credentials or identities. Repeated inspection/revocation is idempotent.
7. At the registered deadline, after dependencies reach zero, the preflight can
   report `retirementAllowed`. Secret deletion and policy changes are separate
   authorized operations; no library function performs them. Removing an expired
   read version from the policy is accepted only after its immutable deadline.

Preparation and activation can lose an acknowledgement after committing. Do not
infer rollback from a timeout. Inspect state and explicitly retry the same bounded
operation/evidence. Already rewrapped bytes are not encrypted again merely to
recover an acknowledgement. Activation replay checks the registered material
and the immutable evidence; a changed secret cannot produce a false success.

## Credential and receipt recovery

Original verification, refresh, deletion, browser issuance/login/rotation/logout
operation hashes remain immutable across retained HMAC versions. Receipt
associated data uses each original stored hash. Crypto rewrapping does not generate
a replacement request key, token pair, cookie, challenge or generation.
Native bearer hashes remain SHA-256 and do not rely on an old Vault key.

Recovery is still limited to the existing 60-second response window and latest
valid credential generation. An older receipt cannot restore a superseded
credential or bypass account/club/session revocation. Refresh does not renew the
original phone-authentication timestamp. Different-key refresh reuse revokes only
that session family; submitting the token to another club cannot revoke its owner.
All retry decisions remain explicit. This change adds no automatic client POST,
refresh, provider send or replay on restart/timeout.

## Missing or irrecoverable keys

A lost live key makes the declared keyring unavailable. Replacing it with random
material under the same version fails the fingerprint check. Neither a new OTP
nor a new random identity is a recovery substitute.

Restore the exact original secret from an independently controlled backup if it
exists. If it is irrecoverable, keep affected services gated. Unrewrapped ciphertext
cannot be decrypted by these tools, and an identity lacking a usable current phone
alias cannot safely be recreated from a claimed contact. The retained encrypted
bytes, source UUIDs, aliases and audit history remain evidence; they are not proof
of recoverable plaintext. An approved independent identity recovery/import
procedure is required for that situation and is not fabricated by this module.

Fresh phone verification can restore a **session** after its short response window,
old cookie key or transient OTP expires, provided the existing canonical identity
and current protected contact mapping remain usable. It does not recover destroyed
contact encryption keys. A successful old-key retirement preserves current aliases
and rewrapped contact copies; it does not regenerate the historical identity.

## Local verification scope

The test bank executes real local SQLite transactions and Web Crypto using only
synthetic keys, contacts and provider receipts. Five-club tests use repository club
IDs with synthetic origins and clear abuse counters only while constructing
independent authorization fixtures. Separate tests prove actual service budgets
cannot be reset by a key change. Browser race tests use independent SQLite
connections and worker threads with the original cookie under current keys.

These checks cover key coexistence/tampering/loss, fixed retirement boundaries,
secret substitution, alias coverage/conflicts, paused bounded migration, unknown
commit recovery, original response receipts, token-family/user/club isolation,
CSRF, revocation epochs and original authentication times. They do not establish
live D1 behavior, device storage, provider/template acceptance, named release
approval, real backup custody, or deployment. No runtime template was enabled.

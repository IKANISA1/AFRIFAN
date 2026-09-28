# Browser identity extension

`src/browser-session-service.mjs` implements bootstrap-bound OTP, independent HttpOnly
browser credentials, same-database revocation checks, rotation and original-operation
recovery. `src/browser-identity-worker.mjs` exposes named PRIVATE methods only, with
HTTP 404 wrappers. It contains no provider or financial bindings.

## Storage

Migration `0004_browser_sessions.sql` is additive. Do not edit, rename or renumber previous
migrations. Existing identity tables remain canonical. Browser policy and origin rows are
explicitly disabled/unassigned until reviewed. No seed creates an enabled origin.

`auth_browser_challenges` pins original issuance key, hashed phone and encrypted bootstrap
identity. `auth_browser_sessions` stores a cookie hash, identity-session linkage, origin,
policy epochs, deadlines and temporary encrypted response. `auth_browser_rotations` retains
immutable original/new hashes, generation and operation key plus a temporary encrypted
response. These hashes/IDs remain private data. They are not financial or legal evidence.

Current reads and rotation SQL join the original account/session/club rows. Suspension,
deletion-pending status, epoch changes, origin reassignment and session revocation deny the
cookie. Rotations never extend the original absolute deadline and cannot revive revoked
sessions. Logging out retires the linked identity session as well as the browser row.

The native access token's five-minute deadline is not the lifetime of this separate browser
credential. Browser lifetime is governed by reviewed browser policy, capped initial identity
refresh deadline and original absolute session deadline; all native bearer endpoints retain
their original access-token expiration checks. Existing custom-key rotation remains separate.

## Temporary secret cleanup

`expireBrowserSecrets(db)` nulls at most 100 expired login-response ciphertexts and 100
expired rotation-response ciphertexts per call. It requires only AUTH_DB, not encryption
keys, code delivery, provider configuration or enabled sign-in. It does not delete retained
operation/audit rows and is not a complete retention/erasure implementation. The private
worker scheduled handler invokes it, but its distributed template contains NO live cron.
Approve a single schedule owner and monitor failures before enabling it.

## Limitation that must stay explicit

OTP verification and browser-row creation are two recoverable steps in the same database,
not one combined transaction. Exact verification retry uses the existing bounded receipt.
An unexposed identity session can remain after a failed browser-row insertion until recovery
or expiry. No bearer is returned by the browser capability. Financial operations remain in
a separate authority/database and still require their own revocation/fencing acceptance.

See `../supporter-browser-api/README.md` for routes, client recovery, deployment and tests.

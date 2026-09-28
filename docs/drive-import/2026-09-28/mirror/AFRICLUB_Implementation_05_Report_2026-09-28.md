# AFRICLUB — Implementation 05
## 28 September 2026

**Implemented and locally tested: separate browser cookie sessions, same-origin membership APIs,
a strict TypeScript client, and explicit recovery of uncertain checkout preparation. All produced
application source is included. This is not a deployed or complete AFRICLUB production release.**

## 1. Source and scope

This delivery continues from the exact **342-file Implementation 04 scoped candidate**, not the
older root-folder snapshot. It adds **20 files** and modifies **five files**, for **25 changed
source/document paths** and a resulting **362-file scoped candidate**. The other **337 source
paths are unchanged exact-hash prerequisites**. The input archive and all **479 internal input
checksums** were verified before implementation. No original SQL migration was changed; one
additive browser-identity migration is provided but was not applied to any hosted database.

This is not a fresh full monorepo export, a protected canonical Git merge, an installed website
or a cloud deployment. The local baseline Git commit is recorded in `SOURCE_PROVENANCE.json`
only to identify the scoped input. Existing Drive source is not replaced by this versioned package.
The source installer defaults to read-only inspection and requires the exact reviewed baseline.

## 2. Implemented browser sign-in and session lifecycle

A new private `BrowserIdentity` Worker entrypoint uses the **same AUTH_DB** as the existing
canonical accounts and identity sessions. It adds browser-specific challenge, session, origin,
control and immutable rotation records through:

`cloudflare/supporter-auth/migrations/0004_browser_sessions.sql`

The browser cookie is independent of native access/refresh tokens. It is not a JavaScript-stored
bearer token and does not convert the native-only API into a cookie endpoint. The public gateway
never returns native credentials or cookie secrets in JSON. Cookies are `__Host-` prefixed,
Secure, HttpOnly, SameSite=Strict, Path=/, without Domain.

The implementation covers bootstrap, OTP challenge, OTP verification, current session,
explicit cookie rotation and logout. Bootstrap is encrypted and short-lived, and binds one
original challenge operation and phone hash. The existing OTP identity service remains the
verification authority; no alternate identity registry or permissive authentication fallback
is introduced.

Browser current-session reads check account, native-session and club revocation along with
browser-origin and policy epochs. Disable/re-enable or a policy revision does not revive an
old cookie. Candidate SQL defaults are 30-minute idle and eight-hour absolute lifetime; they
are configuration proposals requiring owner review, not approved business policy. Session
reads do not prolong the idle lifetime. Rotation is explicit, cannot extend the absolute
lifetime, and commits its credential change, receipt and audit together in the identity database.

Rotation replay retains the original operation UUID. It handles both an old cookie whose
response was lost and a new cookie already set before a response body was lost. Earlier
generations cannot overwrite a newer head. A wrong-key replay cannot revoke the legitimate
current session. Logout revokes the browser session and linked native identity session before
cookies are cleared; only the original logout can replay an already-revoked result.

**Important transaction limit:** underlying OTP verification can commit before browser-session
persistence. An exact retry can recover within the existing short replay window. Otherwise a
fresh verification is required, and an unreachable native session may remain until expiry.
This is not represented as a single transaction spanning both steps. Browser cookie processing
also cannot perform a compare-and-swap against arbitrary simultaneous HTTP responses; a late
cookie response may require reauthentication rather than silently accepting a stale credential.

Replay ciphertext expiry is bounded, independent of enabled login or provider credentials,
and does not delete audit history. The optional scheduled handler has no shipped Cron schedule.
Retention approval, account-erasure orchestration and operational alerting remain separate work.

## 3. Separate same-origin browser member API

The new `cloudflare/supporter-browser-api` module contains twelve versioned endpoints:

| Method | Endpoint |
|---|---|
| POST | `/v1/browser/session/start` |
| GET | `/v1/browser/session/bootstrap` |
| POST | `/v1/browser/session/challenge` |
| POST | `/v1/browser/session/verify` |
| GET | `/v1/browser/session` |
| POST | `/v1/browser/session/rotate` |
| POST | `/v1/browser/session/logout` |
| GET | `/v1/browser/membership/status` |
| POST | `/v1/browser/membership/checkouts` |
| GET | `/v1/browser/membership/operations/{requestId}` |
| GET | `/v1/browser/membership/checkouts/{orderId}` |
| GET | `/v1/browser/membership/checkouts/{orderId}/receipt` |

It requires an exact configured HTTPS origin and club, matched against enabled database
configuration. Body, route and hostname inputs cannot override the configured club. One
approved same-origin deployment/binding is required for each host/club; a generic cross-origin
API host is not an equivalent integration.

State-changing requests require exact Origin, an explicit browser-intent header, a
session/bootstrap-bound CSRF token and the applicable original operation UUID. Fetch Metadata
adds cross-site protection with an explicit fallback when absent. Native Authorization/client
headers and unrecognized fields/queries are rejected. No permissive CORS headers are emitted.
Private responses carry no-store and restrictive API security headers. A real application
service worker must still respect these boundaries; this module does not rewrite its caches.

The gateway is deliberately separated from database, payment-provider and administrative
capabilities. Narrow private bindings derive the user identity server-side. Current membership,
owned order and historical receipt reads reuse the existing domain services. An expired or
suspended membership is not reactivated by displaying an old receipt.

Checkout preparation creates an owned order through the existing authority; it does not
confirm money movement. A new read-only `lookupPreparedOperation` method uses the exact
original writer-principal/user/club/request namespace. A not-observed lookup is explicitly not
proof that an in-flight request cannot commit, and never authorizes a replacement operation key.

**The identity and financial databases remain separate.** Pre/post identity checks are used,
but no atomic cross-database revocation or settlement guarantee is claimed. Authentic provider
evidence, receiving-account reconciliation, refunds, reversals and contribution fulfillment
remain outside this delivery. No dialer/USSD call is made by this browser code.

## 4. Strict TypeScript client and durable checkout recovery

`client.ts` provides strictly validated browser sign-in/session/member/checkout operations.
It uses same-origin credentials without reading HttpOnly cookies. Constructors, session
restoration and recovery lookup do not send a write. An abort/timeout does not imply remote
cancellation, and the client does not automatically repeat a financial command.

Checkout requires an injected durable recovery store and cross-tab exclusive lock. The
provided Storage/Web Locks adapter is selected explicitly by the integrating application;
it does not access browser globals at import. Missing, corrupt or unavailable storage stops
new checkout requests. A record is written and read back before dispatch.

Persisted metadata is limited to origin, club, user UUID, original operation UUID, tier and
time. It contains no phone, OTP, CSRF, cookie or native bearer credentials. These identifiers
are nevertheless private operational metadata requiring retention and shared-device review.
Unresolved metadata is not silently erased on logout.

After a lost response, a new client instance can recover the original checkout through a
read. A found, validated result clears the pending record; not-observed leaves it unresolved.
Only an explicit retry sends the same tier and operation key. Tabs must use the same approved
store/lock; this cannot control arbitrary clients outside the protocol.

**No new browser page, Next.js route integration, mobile screen or five-club composition was
installed.** This delivery supplies the backend and client foundation for the existing browser
membership product, not an accepted rendered customer journey. Browser contribution initiation
and its product rules remain unimplemented here.

## 5. Verification actually completed

| Executed group | Passing tests |
|---|---:|
| Full scoped Node backend/gateway/client regression bank | 1,897 |
| Python source/security/migration/dependency suites | 229 |
| Installer safety and current-bundle scenarios | 39 |
| Freshly compiled portable Kotlin recovery tests | 69 |
| Freshly compiled portable Swift recovery tests | 68 |
| **Unique passing tests, counted once** | **2,302** |

**138 test cases are newly authored:** 136 Node and two Python registration checks. The 136
browser cases comprise 54 session cases, 41 HTTP cases, 24 compiled-client cases, 14 configuration
cases and three independent-connection concurrency cases. Installer and native tests are reruns
of existing cases, not newly implemented features. Repeated Python runs inside the strict
verifier and intermediate Node reruns are not counted twice.

Tests use genuine local SQLite statements/triggers and actual identity, checkout and allocation
service implementations with synthetic fixtures and local bindings. Three new race tests use
separate SQLite connections in worker threads. They cover competing rotation, same-key replay
and rotation/logout competition. Other tests cover wrong-club requests, CSRF, code replay,
policy disable/re-enable, storage failure, old/new-cookie recovery, expired/suspended membership,
owned receipts and uncertain checkout outcomes. They are not real D1/provider/browser tests.

Additional completed checks: **235 syntax/parse operations**, strict client compilation,
operator asset/source parity, disabled deployment templates, source-only migration lineage,
and a limited pattern/path scan of **362 source files with zero flagged findings**. The scan
is not proof of absence of all secrets and does not cover the full Git/Drive history.

Installer tests completed in separate **17, 16 and six-case runs**. The six current-bundle
scenarios verify dry-run/no writes; apply/repeat/exact rollback; unknown modified-file
preservation; unknown added-file preservation; duplicate migration rejection; and tampered
payload rejection. All passed. Local per-file replacement is atomic, not a transaction for
concurrent readers; stop editors/builds during application.

## 6. Gates not passed

The repository still requires Node **22.23.2**, while this runtime is **22.16.0**. Python is
3.13.5 and TypeScript 5.8.3. The main source verifier correctly returns **exit 2 / blocked**
for the Node mismatch and absent Dart/Flutter. Required versions were not lowered. Portable
Kotlin/Swift tests do not prove Android Keystore, Apple Keychain, Flutter hosts, signing or
physical-device behavior.

A package-registry query for a local Cloudflare test runtime failed with `EAI_AGAIN`. No
runtime dependency was installed, and no lockfile was changed. Workerd/real D1, binding and
origin policies have not been accepted. No browser navigation or rendering was attempted
this turn; the earlier administrator block was not bypassed. There are no new screenshots,
keyboard/screen-reader results or visual approvals.

Full monorepo/Next.js/Flutter builds, actual provider journeys, independent security and load
tests, financial reconciliation, hosted migration history, backup/cutover and country/store
approvals remain outstanding. Deployment configurations and SQL browser controls remain disabled.

## 7. Backlog and external actions

The updated register has **130 tasks: 35 In progress, 95 Open, zero accepted/Closed**. Four
previously Open tasks now have scoped source progress: **AUT-05, WEB-03, WEB-04 and WEB-08**.
Fourteen records receive explicit Implementation 05 notes. Every original ID, priority,
dependency, owner role and acceptance requirement is preserved. The dependency plan still
contains 19 levels and 130 missing named-owner assignments; it does not grant approvals.

The Drive folder was checked again and still has **anyone/writer** permission with link
search discovery disabled. Permission revocation is not exposed by the available Drive actions;
no ACL or credential was changed. No misuse is inferred from the permission metadata.
Cloudflare management plugin discovery returned no matching connector. Prior GitHub searches
remain historical; no new repository/branch/protection or Actions run is claimed here.

The existing two version-0003 financial handoff sources remain distinct. The guard detects
conflicting source combinations; it does not reconcile a hosted migration history or authorize
a financial backfill. The browser migration is in the separate existing identity lineage.

No real phone message, payment, live migration, deployment, store submission, permission change,
secret rotation or replacement of the original Drive source was performed. Upload is tracked in
a separate receipt and is not deployment evidence.

## 8. Using the delivery

Start with `CODEX_HANDOFF.md`, then inspect the module README, versioned contract and
`manifest.json`. Use the guarded installer only against the exact reviewed Implementation 04
prerequisites. Do not flatten the paths or replace the full repository with `source/`.

`files/` contains all 25 changed paths. `source/` contains the 362-file scoped verification
candidate. `before/` preserves the five modified originals. `source-diff.patch` includes staged
new and modified source. `reference_only/` preserves the competing migration outside installable
source. `evidence/` contains only this turn's test results; earlier results are not represented
as fresh verification. `PRIMARY_REFERENCES.json` identifies the primary security/runtime guidance.

# AFRICLUB browser member API

Implementation 05 introduced the separate, same-origin cookie ingress. Implementation 06
connects it to the existing Next.js membership route through an explicit per-host mode and a
same-origin outer Worker. The backend continues to serve the existing member product. It does **not** convert the native bearer gateway into a cookie endpoint.
The route/field contract is `contracts/browser-v1.json`; the strictly checked client is
`client.ts`. All shipped runtime switches, SQL browser control, routes and schedules
are disabled. No actual origin, club assignment or principal is approved by these files.

## Implemented surface

| Method / route suffix under `/v1/browser` | Effect |
| --- | --- |
| POST `session/start` | Encrypted, short-lived pre-auth bootstrap; no account or session grant. |
| GET `session/bootstrap` | Existing bootstrap/CSRF restoration only. |
| POST `session/challenge` | One phone and original issuance key bound to this browser bootstrap. |
| POST `session/verify` | Existing OTP verification; a new independent browser cookie after success. |
| GET `session` | Current identity/CSRF/expiry; never extends idle lifetime. |
| POST `session/rotate` | Explicit cookie rotation with an immutable original-operation receipt. |
| POST `session/logout` | Revoke this browser session and its linked identity session. |
| GET `membership/status` | Current entitlement, not a historical active receipt. |
| GET `membership/offers` | Bounded approved, authenticated tier catalog; no recipient/route identifiers. |
| POST `membership/checkouts` | Prepare an owned membership order; no confirmation of money movement. |
| GET `membership/operations/{requestId}` | Read-only original prepare result; absence does not prove failure. |
| GET `membership/checkouts/{orderId}` | Owned current order; eligible payment instructions for review only. |
| GET `membership/checkouts/{orderId}/receipt` | Owned historical fulfilled allocation receipt. |

Browser contribution initiation, refunds and account deletion/recovery screens remain outside
this module. The Next.js `/membership` integration is documented in `PORTAL_INTEGRATION.md`;
its rendered/pinned full-application acceptance has not been executed here. There is no automatic
USSD/dialer call or payment confirmation endpoint. Display of instructions does not prove
payment, a handed-off native attempt or a completed contribution.

## Identity and trust boundaries

The gateway has no database, provider, secret-expiry or arbitrary operator capability.
`BrowserIdentity` is a private named Worker entrypoint. It uses the SAME `AUTH_DB` as the
existing accounts, clubs and sessions, with additive migration
`supporter-auth/migrations/0004_browser_sessions.sql`. It must not be pointed at a new,
unrelated identity database with duplicated account records.

The configured HTTPS origin and club must exactly match an enabled database origin row.
One separately configured deployment/binding is required per approved host/club. No host,
club, user or authority supplied in a request body overrides that configuration. Native
Authorization/client/session headers are rejected. No permissive CORS headers are returned.

Cookies use `__Host-`, Secure, HttpOnly, SameSite=Strict, Path=/, no Domain. JavaScript never
receives cookie secrets or native access/refresh tokens. An explicit same-origin custom
intent header is required; state-changing requests additionally require exact Origin and a
session/bootstrap-bound HMAC CSRF token. Fetch Metadata is defense in depth, with exact
Origin fallback when it is absent. Private GET requires same-origin context as well.
Browser/PWA caches must not store these no-store responses. This is not a complete
service-worker migration or an XSS defense: code executing on the same origin remains
privileged. The original native endpoint protections are unchanged.

A successful native OTP verification establishes the account and an identity-session
record. The browser credential is independent of the five-minute native access token;
its own idle/absolute lifetimes and shared identity/account/club revocation epochs are
checked in SQL. The initial browser absolute deadline is capped by the underlying initial
refresh deadline. Database defaults of 30-minute idle and eight-hour absolute lifetime
are candidate parameters, not approved measured policy. They require explicit review.
Changing browser control/origin policy increments an epoch, so disable/re-enable does
not revive old cookies. Financial reads/prepares still span a DIFFERENT financial database;
pre/post identity reads do not claim cross-database atomic revocation.

## Replay, failure and lifecycle rules

* A bootstrap binds one challenge issuance key and phone; a new phone/key requires an
  explicit new bootstrap. OTPs, client secrets and tokens are not stored in the browser.
* Verification can commit its underlying identity session before browser persistence.
  Exact retry recovers during the existing 60-second identity replay window. If it cannot
  recover, fresh verification is necessary; an unreachable identity session may remain
  until expiry. This is not described as one atomic transaction spanning both steps.
* Rotation updates the cookie hash, idle deadline, generation, receipt and audit in one
  local identity database batch. The retired cookie grants no reads/new writes. Only the
  exact original rotation can recover its latest retained result within 60 seconds.
* A response may set the new cookie before its body is lost. Restore current CSRF with a
  read, then explicitly retry the original rotation ID. An older generation can never
  overwrite a newer one. A wrong-key replay does not revoke the legitimate current head.
* Logout commits revocation before clearing cookies. An expired but exact cookie may
  revoke itself; a retired credential can replay only its original logout. Late HTTP
  cookie responses can still cause a fail-closed reauthentication requirement; this is
  not a browser-level compare-and-swap mechanism across arbitrary clients.
* A timeout does not cancel remote work. Unknown checkout writes retain the original UUID.
  A negative lookup is an observation, not authorization to use another key. Lookup is
  constrained to the configured writer principal, authenticated user and club.

## Client integration

Create `BrowserMemberClient(origin, clubId, { recoveryStore })` only for the same origin
that serves the actual web member application. A standalone cross-origin API host is not
an equivalent deployment. Constructing/restoring the client never sends a write.

For checkout, inject an approved durable operational-metadata store with a cross-tab
exclusive lock. `createBrowserRecoveryStore(localStorage, navigator.locks)` is an adapter
for browsers where that combination is approved and supported; the client does not select
or access those globals on its own. Unsupported/corrupt/unavailable storage blocks new
checkouts. The persisted record contains origin, club, user UUID, original operation UUID,
tier and timestamp; those are private operational metadata, not anonymous data. No phone,
OTP, CSRF token, cookie or bearer token is persisted. The app must approve retention and
shared-device treatment before use. Unresolved metadata is not silently erased on logout.

Call `restore()` for a current session, `pendingCheckout()` to inspect the scoped original
operation, and `recoverCheckout()` for a read-only lookup. A found validated result can
clear the pending record. A not-observed result leaves it locked. Only explicit
`retryPendingCheckout()` resends the SAME tier/key. No retry loop, timer, app resume or
constructor initiates a checkout. Independent tabs must use the same approved store/lock;
other clients outside this protocol are not controlled by the JavaScript lock.

## Delivery / deployment sequence

1. Reconcile the protected canonical source and existing identity migration history.
2. Review and apply the additive identity migration to an isolated approved AUTH_DB only.
3. Review origin/club mapping and lifetime/rate values. Add a disabled origin record;
   verify account/club imports and set reviewed SQL policy only in that isolated environment.
4. Deploy the private BrowserIdentity with existing approved identity key handling. Do not
   copy credentials into JSONC. Review the existing OTP delivery service separately.
5. Bind the public gateway narrowly to BrowserIdentity and the existing checkout/read/receipt
   capabilities. Assign distinct reviewed rate namespaces. Verify its exact origin.
6. Integrate the member site and its no-store/offline/logout behavior, run real browser,
   Access/Workers/D1 and security acceptance, then enable only explicitly approved routes.

The templates deliberately fail production provisioning until real reviewed values and
approvals exist. `check-deployment.mjs` checks DISABLED templates, not enabled deployment
readiness. The gateway's master gate remains false; membership and checkout are separate
switches. No script in this delivery provisions, migrates or enables hosted resources.

## Local verification

```
node --test cloudflare/supporter-browser-api/tests/*.test.mjs
node cloudflare/supporter-browser-api/scripts/check-deployment.mjs
```

Tests use real local SQLite, synthetic identities and locally invoked gateway/service
bindings, including independent worker-thread database connections. The client is compiled
strictly before its integration tests. These are not rendered browsers or Cloudflare D1.
The full release verifier preserves the repository Node pin and blocks missing SDKs.

## Implementation 06 portal

`portal-controller.ts` coordinates read-only restoration and deliberate sign-in, session and
checkout actions. `browser-platform.ts` checks the controlling service worker before private
requests. `client.ts` optionally preserves the last prepared order before clearing its pending
record; this option defaults off for existing client consumers. These records contain private
operational identifiers and are not erased by logout. See `PORTAL_INTEGRATION.md` for the
explicit cache, lifecycle, deployment and retained-metadata boundaries.

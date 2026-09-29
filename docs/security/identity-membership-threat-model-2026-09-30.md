# Identity and membership trust model — local candidate, 30 September 2026

Status: reviewed local source and synthetic contracts; **NO-GO for production**.
This model covers the newly integrated native identity gateway, private verifier,
OTP dispatch, native membership gateway, cookie portal, outer web router and
protected checkout recovery. Existing Supabase clients retain their current
identity authority. No migration, resource enablement or independent security
acceptance is implied. Scope remains all five clubs and ten native targets.

## Assets and authorities

| Asset or operation | Source authority | Required boundary |
| --- | --- | --- |
| Verified supporter UUID, contact state and revocation epoch | Dedicated identity AUTH_DB | Enabled import gate and club, verified phone, current account/session/club epochs |
| Native access/refresh credentials | Identity service; hashes in AUTH_DB | Opaque random credentials; no editable actor/role field; exact native transport |
| Browser cookie session | Private BrowserIdentity against the same identity authority | HTTPS exact approved origin/club, HttpOnly Secure host cookies, browser intent and CSRF |
| OTP delivery and receipt | Separate leased dispatch database and reviewed private delivery services | Per-phone/IP/global/club policy, immutable delivery identity, bounded unknown outcomes |
| Checkout preparation and handoff journal | Existing private financial checkout writer | Verified owner and club; same original request key; claim grants at most one first-response handoff |
| Current membership | Current financial membership observation | Historical receipts cannot reactivate suspended or expired membership |
| Historical receipts | Owner-scoped financial checkout/receipt readers | Correlate actor, order, allocation, amount, currency and tier before returning minimized data |
| Android/iOS checkout recovery metadata | Shared protected host in each engine/target | Keystore/no-backup or WhenUnlockedThisDeviceOnly/non-sync Keychain; explicit scoped composition |
| Provider/payment results | Approved external evidence plus authoritative allocation | OTP queued, prepared order, launched handoff and historical allocation are distinct observations |

A user-supplied club, session marker, request UUID, edge IP or native transport
marker grants no role, payment entitlement or authority over another account.
The native membership adapter has four private bindings and no SQL, allocator,
provider sender, account-erasure or staff authority. The browser adapter is a
separate cookie ingress; native bearer headers cannot be translated into cookies.

## Entry points and trust transitions

1. Native identity accepts exact HTTPS origin and direct Workers ingress with
   bounded JSON, an edge limiter and explicit native marker. Cookie/origin/browser
   transports are rejected. Challenge verification binds the original client secret.
2. Native supporter membership derives the actor through the private verifier;
   actor, price, recipient, provider and role body overrides are rejected. Owned
   financial results are correlated and identity is rechecked before and after work.
3. Browser ingress requires exact origin/approved club, browser intent and
   same-origin metadata. State-changing routes require a CSRF token and original
   request key. Cookies are managed by the browser; JS never stores credentials.
4. The outer router forwards the original Workers Request to the private browser
   binding. It strips untrusted forwarded-host and controlled-evidence headers
   before Next. Encoded API namespaces cannot fall through; encoded application
   pages lose public/CDN cache permission. Binding calls have an eight-second bound.
5. The portal requires acknowledgement from a controlling worker that owned dynamic
   caches have been purged. Hidden/offline/BFCache/cross-tab/worker-change events
   conceal private state. A club change replaces its controller before presentation.
6. Checkout confirmation persists opaque owner-scoped operation metadata before a
   write under an exclusive Web Lock. Lock acquisition and HTTP/body reads are
   bounded; a cancelled late callback cannot dispatch. An acquired lock is retained
   until its action completes. Only explicit same-key retry is allowed after loss.
7. Native recovery installs a shared protected host in all ten target sources. The
   lifecycle-aware Dart composition is disabled by default and requires an explicit
   compatible NativeMembershipApi. It does not consume a Supabase bearer as a
   custom identity token or switch the existing paid-membership flow.

## Concrete abuse paths and current local controls

| Abuse or failure | Current local control / evidence | Remaining acceptance |
| --- | --- | --- |
| Forged user, role, tenant or price | Exact body grammar, verified actor, typed projections, owner correlation; combined service suite | Actual bindings, club mapping/import and independent negative tenant testing |
| Cross-origin cookie write / duplicate cookie selection | Exact origin, intent, CSRF, host-only Secure Strict cookies, duplicate-cookie rejection | Real deployed HTTPS/Workers cookie behavior across intended browsers |
| Session revoked while a financial write is running | Pre/post introspection; changed/unknown result withheld; original operation retained | Two databases are not atomic; approve operation-specific revocation semantics |
| Lost challenge response followed by read refresh | Read 401 preserves unresolved sign-in retry; explicit retry uses the same key | Crash/reload identity-retry storage and governed expiry/abandonment are incomplete |
| Hidden lifecycle then same-key retry | Current presentation epoch with immutable original identity; no unsent post-invalidation challenge | Physical/native and complete browser lifecycle acceptance |
| Slow request, stalled stream or held cross-tab lock | Independent bounded deadlines; nonblocking stream cancellation; late callback fence | Actual target/load/degraded-device measurements and approved latency budgets |
| Malformed array coerced into enum/UUID | String type guards for native/browser wire and recovery phases | Full versioned schema validation and independent fuzzing |
| Previous club shown under new branding | Keyed portal scope replaces state before render; real-client rendered regression | Intended multi-club hosted portal acceptance |
| Private data retained in stale PWA cache | Private/encoded/authorized/RSC routes bypass cache; Vary Cookie rejected; owned-cache protocol | Actual CDN/Workers rules, old-client upgrade and cross-account browser matrix |
| Push payload carries credentials/payment instructions | Generic lock-screen text and exact safe same-origin landing-page allowlist | Provider payloads, user consent and native push routing acceptance |
| Forgotten device generates second payment handoff | Financial server journal and one first-response claim; explicit unknown recovery | Reinstall/device-loss and carrier/SIM journeys on all ten targets |
| Weaker or ambiguous legacy Keychain item appears empty | Inspect all synchronization variants; reject weak/ambiguous item policy | Real Keychain XCTest execution, locked device, backup/restore and disposal |
| Candidate templates acquire unreviewed power | Exact disabled var/resource/entrypoint checks; no public routes or schedules | Infrastructure-as-code, least privilege caller authorization and governed enablement |
| Evidence broadcasts test contact data or credentials | Path-only rejection diagnostics; synthetic phone fixtures redacted; hash manifests | Human evidence review, complete archive/history/artifact inventory and publication approval |

## Explicit unresolved production risks

- No supported native identity adapter, protected OTP/refresh credential journal,
  single-flight process-safe rotation, profile/anonymous upgrade/import planner,
  lost-phone/phone-change/account-linking or complete erasure orchestration exists
  in this integrated custom identity candidate.
- Key version one is implemented. Online multi-key rotation, re-encryption and
  identity lookup-key migration require a reviewed operational design; replacing
  lookup keys without migration can break identity mapping.
- Browser retries for identity are memory-only. The portal's protected durable
  metadata stores checkout operation IDs, not phone/code/cookies/CSRF credentials.
- User/staff separation in this supporter candidate does not implement the complete
  operator role/maker-checker workflow. The separate operator lineage is still pending.
- D1 transaction/trigger behavior, provider delivery status, session policy, tenant
  admission, currency units, cutover/rollback and deletion retention need actual
  governed target acceptance. Local SQLite, portable tests and dry runs do not prove them.
- Native host typecheck/portable execution does not prove OS Keychain/Keystore,
  entitlements, screen composition, dialer behavior, signed bundles or device release.
- Source-only checks, a passing build and synthetic rendered UI do not constitute
  an independent commissioned security assessment or named release approval.

## Source and verification links

- `cloudflare/supporter-auth/{README.md,BROWSER_SESSIONS.md,ISSUANCE_LIMITS.md}`
- `cloudflare/supporter-membership-api/{README.md,contracts/openapi.json}`
- `cloudflare/supporter-browser-api/{README.md,PORTAL.md,client.ts,portal-controller.ts}`
- `cloudflare/supporter-web-router/{README.md,src/index.mjs}`
- `packages/features/feat_membership/NATIVE_CHECKOUT.md`
- `docs/release/{identity-delivery,membership-gateway,browser-membership,native-membership}-integration-2026-09-30.json`

The named goal task ledger records partial local coverage and keeps all original
acceptance criteria and release flags open until exact-candidate evidence and
required owner decisions exist.

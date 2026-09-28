# AFRICLUB — Implementation 06
## 28 September 2026

**Implemented and locally tested: the existing Next.js membership route is connected in source
to the browser API, with approved-offer reads, deliberate checkout review/recovery, a same-origin
edge router and private service-worker cache controls. Not deployed; rendered browser and full
pinned application acceptance remain unverified.**

## 1. Source and delivered scope

This delivery continues the exact 362-file Implementation 05 candidate and adds four freshly
retrieved original Next/service-worker prerequisites. Against that 366-file baseline it adds
**18 authored files and modifies 14 files: 32 changed source/document paths**. The resulting
scoped candidate contains **384 files and 352 unchanged exact-hash prerequisites**. The fresh
membership surface and proxy are preserved unchanged; the fresh membership page and service
worker are modified. Source IDs and SHA-256 hashes are in `SOURCE_PROVENANCE.json`.

All 451 input-bundle checksums passed. All 17 existing SQL files remain byte-identical; no new
migration was authored or applied. The competing version 0003 financial handoff histories stay
separate and the migration guard remains in place. This is not a fresh full monorepo export,
protected Git merge, automatic reconciliation of deployed databases or full platform release.
No existing Drive source was overwritten. Upload is verified separately from implementation.

## 2. Membership journey now connected in source

The actual `/membership` Next page selects the new React component when the OpenNext runtime
explicitly enables `cookie-v1` with the exact approved host and club. It continues using the
existing feature guard and club profile. An invalid enabled configuration displays unavailable,
not an insecure legacy-authentication fallback. The absent/default or explicit legacy mode
retains the original page surface and its existing source; it is not newly certified by this
increment. No production runtime variable or route was enabled.

The new portal connects the real BrowserMemberClient to sign-in, current membership, approved
tier selection, preparation review, owned order status, original-result recovery, historical
receipts, explicit browser-session renewal and logout. The shared TypeScript controller handles
those transitions separately from React and is exercised against the actual local gateway and
identity/payment service implementations. It has no browser payment confirmation or refund API.

Selecting or cancelling a tier makes no checkout request. Confirming rereads the session and
selected offer and rejects a changed review. The actual prepared order is shown afterwards.
A catalog can still change between the last read and preparation; the returned order's actual
price is displayed and **no payment is automatically made**. Existing service units, prices and
commercial rules are preserved, not independently approved or converted. No dialer, USSD call,
provider payment or PIN entry is performed by this portal.

The new `GET /v1/browser/membership/offers` makes 13 browser endpoints. It reads the same approved
checkout view as preparation, checks authority before/after, bounds the catalog to 32 rows and
rejects excess, duplicate or malformed results. Its projection contains tier, amount, currency
and country, not receiver/provider-route identifiers. Existing hyphenated tier codes remain
valid; an overly narrow browser tier pattern was aligned with the existing checkout contract.

## 3. Original-operation recovery and current-state presentation

With the explicit portal option enabled, the client stores and verifies the last prepared order
BEFORE deleting its pending recovery marker. Reload can therefore retrieve an acknowledged order
through reads. A storage failure or lost response leaves the original pending request recoverable.
A lookup returning not-observed does not establish failure or allow a replacement key. Only an
explicit retry uses the original operation identity. Existing client consumers retain the old
default until they opt into last-order retention.

Session rotation/logout also retain their original retry identities in the current coordinator.
Uncertain rotation blocks new checkout review. Logout hides private presentation immediately;
a retry never invents a replacement request. These session-retry closures are not persistent
across arbitrary process loss; the backend's existing cookie/session replay and reauthentication
bounds still apply. No distributed transaction between identity and financial stores is claimed.

The UI keeps current entitlement separate from historical receipt status. A suspended membership
is not activated by an old receipt. A local expiry tick removes expired payment instructions and
can downgrade an expired membership without making HTTP requests. Hidden/offline pages, pagehide,
BFCache restore, controller changes and cross-tab session signals invalidate private presentation
and review; returning to the page requires a deliberate refresh. Browser behavior is authored,
not yet rendered/accepted on real browsers or devices.

Local recovery records hold opaque user/order/request IDs, club and tier metadata, not phone,
OTP, cookie, CSRF or native bearer secrets. These remain **private operational metadata**, not
anonymous data. Logout does not erase unresolved records. Full retention, erasure, shared-device
privacy and all legacy cache behavior remain separate acceptance work.

## 4. Actual cache bug and same-origin routing

Fresh `public/sw.js` included `/membership` in the periodic public-page refresh list. That path
could call the public caching helper without the private-navigation guard. The modified worker
removes it, guards private requests inside the helper itself and makes protected paths/API/RSC/
prefetch/action requests network-only. Encoded paths and requests carrying credentials do not
enter the public cache. Dynamic responses require explicit public permission; redirected,
Vary:Cookie, private and no-store responses are not stored. Known Next static assets retain
their normal public-asset path. Old queued mutations are neither replayed nor deleted.

Before a controlled portal sends private requests, it requires the active worker to acknowledge
its cache protocol after purging the app-owned page/API cache namespaces. An old or failed worker
blocks the portal and requests a site update. No controller means no current worker intercepts
that page; it does not prove all storage has been erased. The protocol does not purge unrelated
caches, IndexedDB, local recovery records or financial data. Actual browser upgrade races and
shared-device acceptance remain unverified.

A new disabled outer Worker forwards the ORIGINAL `/v1/browser/...` Request to its `BROWSER_API`
HTTP service binding and other routes to `NEXT_APP`, removing untrusted forwarded-host overrides
before Next routing. It preserves separate Set-Cookie headers, adds private browser/CDN headers
and never retries the binding automatically. Unknown/encoded v1 paths do not fall through to
Next. There is no fabricated Cloudflare request context inside a Next API proxy. Real binding
metadata/cookie propagation still needs Cloudflare-runtime acceptance.

The existing production Next Wrangler file is unchanged. The new outer template has no public
routes and remains disabled, with no database or payment-provider capability. The page needs the
three documented reviewed runtime values; placeholders are not deployable approvals.

## 5. Current verification

| Completed group | Passing tests |
| --- | ---: |
| Scoped Node controller/client/backend/gateway/cache/config regression bank | 1,993 |
| Python source/security/migration/dependency suites | 231 |
| Installer safety and current-bundle scenarios | 39 |
| Freshly compiled portable Kotlin recovery harness | 69 |
| Freshly compiled portable Swift recovery harness | 68 |
| **Unique passing tests, counted once** | **2,400** |

**98 cases are newly authored: 96 Node and two Python inventory checks.** The Node bank comprises
76 test files and finishes with zero failures, skipped, cancelled or todo cases. New cases cover
sign-in and request recovery, changed catalog prices before/after the last read, persisted-order
recovery, storage failure, suspension versus receipt, lifecycle/expiry handling, original-key
session retries, exact-origin routing, forwarded-host sanitization and private-cache exclusions.

Controller/client tests use genuine local SQLite statements and the actual service classes with
synthetic identities and local transport/service bindings. Service-worker tests execute the actual
script in a VM with cache/events supplied by the test harness. These are not browser clicks,
Cloudflare workerd/D1, real Access/cookies, provider payments or physical-device acceptance.

Another **275 syntax/parse checks** passed, plus strict pure-TypeScript client/controller/config
compilation, disabled-template checks, operator asset parity and source migration-lineage checks.
TSX parsing is NOT semantic React/Next typechecking or a build. A limited path/pattern scan reads
all 384 source files with zero flagged findings; it does not cover full Git/Drive history or prove
absence of all secrets. All 17 SQL files are unchanged.

The first targeted run found two test-fixture column-name errors, corrected to the actual schema
without weakening behavioral checks. The first combined installer invocation timed out while
current-bundle scenarios were incomplete; its partial log is retained, not counted. Completed
17-,16- and six-case replacement/independent runs provide the 39 installer results. Python and
Node reruns are not double-counted, and earlier deliverables' test totals are not added.

## 6. Browser, toolchain and release limits

The required Node pin remains 22.23.2; the executed Node runtime is 22.16.0. Python is 3.13.5 and
TypeScript 5.8.3. Dart/Flutter are absent. The complete source verifier correctly returns
**exit 2 / blocked**. Portable Kotlin/Swift success does not prove Android Keystore, Apple
Keychain, Flutter hosts, app signing or device behavior.

React, Next and OpenNext dependencies cannot be resolved in this scoped runtime. A current
package-registry read fails `EAI_AGAIN`; no dependency was installed and no lockfile changed.
No browser navigation was attempted in this increment, and the earlier administrator browser
block was not bypassed. The flow intended for acceptance is `/membership` → sign-in → current
status → tier review → preparation → owned order/original-result recovery.

| Rendered/browser check | Result |
| --- | --- |
| Page identity / meaningful rendered content | Not verified: full app cannot be built here. |
| Framework overlay / browser console health | Not verified. |
| Desktop/mobile screenshots and visual fidelity | Not verified; zero screenshots. |
| Click/keyboard/screen-reader interaction | Not verified; controller integration is not browser acceptance. |
| Service-worker update, BFCache and multi-tab lifecycle | VM/controller cases only; actual browser acceptance pending. |
| Real Workers bindings, D1 and provider journeys | Not executed. |

Further release work includes the full pinned Next/Flutter builds, actual infrastructure identity
and scope, authenticated payment evidence/reconciliation/refunds, native composition/devices,
independent security/load checks, retention/erasure, backup/cutover and club/country/store approval.
The old conflicting financial migration histories are not resolved by this browser increment.

## 7. Backlog and external actions

All 130 task IDs, priorities, dependencies, owner roles and acceptance requirements are preserved.
The register now has **36 In progress and 94 Open; zero release-accepted/Closed**. WEB-07 is the
only previously Open task moved to In progress. Sixteen records carry explicit Implementation 06
notes. The dependency plan retains 19 levels and 130 missing named-owner assignments; a source
plan cannot grant those human approvals.

Fresh destination metadata still shows anyone/writer with link discovery disabled. The available
Drive sharing action grants access but does not expose revocation. No permission, credential,
provider account, live data, deployed resource or original Drive source was changed. No actual
misuse is inferred from sharing metadata. GitHub/Cloudflare resource operations and app-store
submissions were not performed.

## 8. Use and package structure

Start with `CODEX_HANDOFF.md`. The guarded installer requires the exact Implementation 05 source
and four fresh before-source prerequisites. Run the dry run before applying; do not flatten the
paths or replace the full repository with `source/`. It checks original/after hashes, refuses
unknown edits, records backups, supports repeated no-op application and exact rollback. It
never applies SQL, provisions infrastructure or enables a feature. Individual file replacement
is atomic; the whole multi-file patch is not atomic for concurrent editors/readers.

`files/` contains all 32 changed paths. `source/` is the 384-file scoped test candidate. `before/`
retains 14 modified originals. `reference_only/` preserves the competing migration outside the
installable source. `source-diff.patch`, `manifest.json`, provenance and raw evidence make the
source delta inspectable. Checksums establish consistency against the supplied manifest, not
independent reviewer approval or authenticity of a publicly writable source folder.

The final ZIP and reports are uploaded as versioned files to the same AFRICLUB folder, with a
separate upload receipt after readback. Upload does not mean installation, deployment or release.

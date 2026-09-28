# AFRICLUB — Implementation 07
## 28 September 2026

**Implemented and locally verified: owned membership allocation history and historical receipts,
browser/native API and TypeScript clients, membership portal integration, additive Dart source,
and notification receiving safety. Local delivery complete; Drive upload blocked. Not deployed.**

## 1. Delivered scope and source authority

This delivery continues the exact **384-file Implementation 06 scoped candidate**, adding
**10 files and modifying 25: 35 changed source/document paths**. The resulting candidate has
**394 files, with 359 unchanged exact-hash prerequisites**. Input ZIP SHA-256 and all
**493 internal input checksums** were checked before work. The current Drive report was read,
but the source is the provided archive, not a fresh recursive export or protected Git merge.

`files/` contains the entire 35-path delta; `source/` contains the scoped runnable verification
candidate; `before/` retains the 25 modified originals. All **17 original SQL files are
byte-identical**. One new SQL file creates only a history-read index. No hosted migration,
financial record, existing Drive source, credential or permission was changed.

## 2. Owned membership history and older receipts

The existing private `MembershipCheckoutReader` now provides `history` and `historicalReceipt`.
History reads the existing subscription ledger, orders, allocations and receipts; it does not
create another ledger, copy balances, allocate evidence, confirm external settlement, renew
membership, prepare orders, execute refunds or send notifications.

The list returns at most 20 records, sorted by timestamp and allocation ID using indexed seek
pagination. The new partial index is in `0005_membership_history_read_index.sql`. The query
requires that index rather than silently reverting to an unbounded scan. The list performs
one bounded ledger query rather than one receipt query per item; a selected receipt is read
separately. Tests check use of the index and absence of a temporary sort in local SQLite.

Only owned membership allocations are included. Unallocated, pending, cancelled and contribution
orders are not represented as completed membership payments. Older imported membership orders
with retained ledger/receipt evidence can be read **without newer checkout snapshots or local
browser order records**. A receipt is compared with its immutable order/allocation fields; a
mismatch is rejected, never silently repaired or fabricated.

Both gateways derive user and club through their existing authentication boundaries. The private
service checks current service/subject grants before and after reads, and the gateways validate
the minimized result and recheck identity. This does not establish atomic authorization across
the separate identity and financial databases. It is an observed, owned read—not authority for
a later financial command.

The `X-Africlub-History-Cursor` header keeps pagination metadata out of URLs. It is strictly
bound to the authenticated user/club but is an unsigned selector, not authentication. It remains
private operational metadata and must not be logged or persisted. Pages are marked
`historical:true`, `snapshot:false`, `scope:membership_allocations`. They are live observations,
not a consistent full export; new or backfilled records need appropriate rereads.

## 3. Actual API, client and portal integration

Two GET-only endpoints were added to each transport:

| Surface | List | Selected receipt |
|---|---|---|
| Browser | `/v1/browser/membership/history` | `/v1/browser/membership/history/{orderId}` |
| Native | `/v1/supporter/clubs/{clubId}/membership/history` | the same path plus `/{orderId}` |

The browser contract now contains 15 routes and native OpenAPI 11 paths. Existing authentication,
rate limits, exact-origin policy, native/browser transport separation, no-store responses and
read-body/idempotency-key rejection are retained. History is independent of the browser's
checkout-creation flag but still requires membership access. A disabled membership service is
not treated as a read-only fallback.

Both TypeScript clients are strictly compiled and tested against the actual gateways with local
service bindings. They reject wrong owners/clubs, malformed fields, duplicates, out-of-order
pages, wrong cursors and mismatched receipts. These are not real network/Cloudflare acceptance
runs. The additive Dart history model/API, native GET transport and 11-check harness are authored
and registered in the existing verifier. **No Dart check ran**, because the SDK is absent.
Existing Dart interfaces remain compatible; no five-app registration or signed native release
is claimed.

The actual browser-membership React component connects to the controller/client and provides
Latest/Older history actions and selected receipt reads. One page replaces the previous page,
bounding private presentation to 20 rows. Actions do not run automatically on construction.
Current membership remains separate: an active historical receipt cannot override today's
suspension or expiry. Lifecycle invalidation, logout and authorization denial clear history
presentation; a late response cannot restore a concealed view.

Corrupt or unavailable local checkout recovery storage **continues to block new checkout
preparation**, while server-backed read-only membership/history remains available. No corrupt
record is deleted or overwritten. Explicitly disabled checkout creation also leaves the portal
read-only. Missing authentication or membership access still blocks the journey. This change
is not complete account erasure, retention approval or shared-device acceptance.

## 4. Notification receiving safety

The existing worker accepted notification-supplied title/body, image URLs and click destinations.
It could navigate a matching window to an arbitrary supplied URL. The revised receiving handler
shows generic text, fixed local branding, controlled actions and a safe landing-page destination.
Raw bodies, private IDs, amounts, external images and credentials are not retained in new
notification data. Invalid/oversized payloads are not displayed.

The only accepted destinations are the exact same-origin HTTPS landing pages `/admin`,
`/membership`, `/news`, `/fixtures`, `/results`, `/support`. Other values use `/admin`.
External URLs, credentials, queries, hashes, whitespace, backslashes, encoded and dot-path forms
are rejected. Click handling validates again, including clicks on previously displayed legacy
notifications; it focuses only an exact-target existing window or opens the safe target.
Dismiss/unknown actions make no navigation. Cosmetic badge failure cannot resend a notification.

This deliberately narrows legacy deep links and notification copy. All destination routes must
still enforce their own authorization. Push sender authentication, subscription ownership/tenant
lifecycle, dispatch receipts, notification policy approval and real-browser acceptance remain
outstanding. No notification was sent to a real device. The private cache protections from
Implementation 06 remain in place; financial queues and unresolved recovery records are untouched.

## 5. Verification actually completed

| Executed group | Passing tests |
|---|---:|
| Scoped Node backend/gateway/client/controller/cache/notification regression bank | 2,120 |
| Python source/security/migration/dependency suites | 234 |
| Installer safety and exact current-bundle scenarios | 39 |
| Freshly compiled portable Kotlin recovery harness | 69 |
| Freshly compiled portable Swift recovery harness | 68 |
| **Unique passing total, counted once** | **2,530** |

**130 executed cases are newly authored: 127 Node and 3 Python.** The authored 11-check Dart
harness is excluded from passing totals. The 80-file final Node run has zero failed, skipped,
cancelled or todo cases. Repeated targeted runs, earlier delivery totals and intermediate failing
runs are not added. All 39 installer tests completed as 17, 16 and 6-case runs with no timeout.

Another **282 syntax/parse checks** passed. Framework-independent TypeScript client/controller
compilation,11 configuration/asset checks, source migration-lineage validation and a limited
394-file sensitive-source scan passed. The pattern/path scan is not independent security review
or proof that full Drive/Git/archive history contains no secrets. TypeScript/TSX syntax parsing is
not a full React/Next build or semantic framework typecheck.

Tests execute real local SQLite statements and existing service implementations with synthetic
identities/local bindings. Notification cases execute the actual service worker in a VM with
supplied events/cache/client objects. They are not rendered browser clicks, OS push delivery,
Cloudflare workerd/D1/Access, authentic payment-provider or physical-device acceptance.

Intermediate evidence is retained: an unsupported test-fixture order-kind was corrected to the
actual contribution enum; a read-denial test exposed a generic 503 mapping, now 403 with private
presentation clearing; two stale endpoint-count assertions were updated with explicit GET-only
authentication checks. The syntax harness's initial JSONC parser/compiler-path mistakes were
fixed without changing valid source to accommodate an incorrect parser. Only completed corrected
runs contribute to the stated passing totals.

## 6. Browser and release limits

Required Node remains 22.23.2; executed Node is 22.16.0. Python is 3.13.5 and TypeScript 5.8.3.
The strict full source verifier returns **exit 2 / blocked**, correctly reporting the Node mismatch
and missing Dart/Flutter. Portable Kotlin/Swift success does not prove Keystore/Keychain,
Flutter hosts, signed apps, device storage or device payment journeys.

The flow awaiting browser acceptance is `/membership` -> sign in -> current status -> Latest
history -> Older page -> selected historical receipt -> logout/restore. No Browser runtime is
available in this tool set. No new browser navigation or alternate-policy bypass was attempted;
the earlier administrator block was not circumvented. React/Next dependencies are unresolved,
and a current package-registry read failed `EAI_AGAIN`; no dependency or lockfile was changed.

| Rendered or production check | Result |
|---|---|
| Page identity, nonblank render, framework overlay and console | Not verified; full app not built. |
| Desktop/mobile screenshots and visual fidelity | Not verified; zero new screenshots. |
| Mouse, keyboard and screen-reader interaction | Not verified; controller tests only. |
| Real push/notification permissions, click and SW upgrade behavior | VM checks only; browser/device acceptance pending. |
| Actual Workers/D1/Access/cookie/private bindings | Not executed. |
| Financial authenticity, reconciliation, refunds, load and restore/cutover | Not executed. |

Human commercial/privacy/brand/country/store approvals remain outstanding. The financial
version 0003 conflict is not solved by adding a later index. Confirm actual deployed history,
approve forward-only reconciliation and apply the index only in an approved environment before
enabling the history implementation. The source installer itself never applies SQL.

## 7. Task position and delivery limitation

All 130 task IDs, priorities, dependencies, owner roles and acceptance requirements are preserved.
The register remains **36 In progress and 94 Open; zero release-accepted/Closed**. Sixteen records
receive precise Implementation 07 progress notes. The dependency plan remains 19 levels with 130
missing named-owner assignments; code and local tests do not grant human approvals.

Fresh root metadata still reports anyone/writer with link discovery disabled. No permission or
secret was changed and no misuse is inferred. This session's Google Drive discovery exposes
**29 read actions and no upload/create/update action**. Plugin-directory search returns the
already installed connection, not another write capability. **Implementation 07 has not been
uploaded to Drive.** This differs from the previous delivered packages and is recorded in
`DELIVERY_STATUS.json` and the external upload-pending manifest. It is not a claim that the
folder owner lacks edit rights. No upload receipt or remote file ID is invented.

## 8. Use

Start with `CODEX_HANDOFF.md`. The guarded installer requires the exact reviewed Implementation 06
before-source; default execution is read-only. It checks every payload/prerequisite hash, refuses
unknown edits or conflicting migration histories, backs up modified files and supports repeated
no-op application and exact rollback. It never deploys, applies SQL, sends messages or changes
permissions. Stop other editors/builds while applying: individual file replacement is atomic,
not the entire multi-file operation. Do not flatten paths or replace the full monorepo with the
scoped `source/` directory.

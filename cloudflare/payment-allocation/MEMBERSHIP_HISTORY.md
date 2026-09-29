# Membership allocation history — read-only source implementation

The optional history reader uses the existing `pa_ledger`, `pa_orders`, `pa_allocations`
and `pa_receipts` authority. It does not copy the ledger, change balances, grant membership,
reconcile external settlements, prepare another checkout, or send notifications.

`MembershipCheckoutReader.history({clubId,userId,cursor,limit})` returns at most 20
membership allocations. `historicalReceipt({clubId,userId,orderId})` reads an owned
historical receipt independently of newer `pa_checkout_order_details`. An imported
order with a real retained allocation/receipt can therefore be found after client storage loss.
This is **not** recovery of an unresolved unallocated payment or authorization to pay again.

Authorization uses current private service, club and subject grants before and after reads.
Browser/native gateways independently derive user and club from their existing authentication
boundaries, repeat the identity check and validate the private projection before responding.
These separate stores do not give cross-database atomic revocation guarantees.

## Pagination

The additive migration `0005_membership_history_read_index.sql` creates only a partial
owner/time index; apply it only after resolving actual hosted migration history.
The existing conflicting version-0003 histories are not repaired or renamed by this migration.
The history query deliberately fails without its index rather than silently doing a large scan.

Items sort by `(recorded_at_ms DESC, allocation_id DESC)`. The next page uses the strict
compound `<` boundary, no OFFSET. A private `X-Africlub-History-Cursor` request header keeps
cursor metadata out of URLs. It is strictly bound to the already authenticated user/club;
it is an unsigned selector, **never** an authorization token or authenticity proof.
It must not be logged or persisted. Invalid, duplicate, out-of-order and cross-scope
responses are rejected. Pages are live observations, not a consistent full export. Later
inserts ahead of a cursor require a latest-page refresh; backfilled older rows can appear later.

## Surfaces

Browser: GET `/v1/browser/membership/history` and `/v1/browser/membership/history/{orderId}`.
Native: GET `/v1/supporter/clubs/{clubId}/membership/history` and the same path plus `/{orderId}`.
Only GET is allowed; queries, bodies and Idempotency-Key are rejected. Existing origin,
CSRF/session separation, rate limits, no-store responses and disabled deployment controls remain.
History is available independently of the browser's checkout-creation switch.

The portal offers explicit latest/older-page reads and selected receipts, holds one page in
memory, and clears private presentation on logout/lifecycle invalidation/authorization denial.
Corrupt checkout recovery storage still blocks all new checkout preparation, but does not
prevent server-backed read-only history. It is not erased or silently replaced.
The native TypeScript client is compiled and exercised. The additive Dart history API and
harness are authored and registered; SDK execution, Flutter composition and devices remain open.

## Notification changes

The existing service worker now shows generic notification text and local branding only.
It accepts `/admin`, `/membership`, `/news`, `/fixtures`, `/results`, `/support` on its exact
origin; all other URLs resolve to the admin landing page. It validates again on click,
including legacy notifications, and follows no arbitrary action. No raw push message,
external image URL, private identifier, amount or credentials are persisted in notification data.
This narrows legacy deep links intentionally; routes still enforce their own authentication.
Push subscription tenant/owner lifecycle, sender authentication, dispatch receipts and full
retention/shared-device handling are not implemented by this receiving-side hardening.

## Verification limits

Local SQLite/service/client/VM tests are not hosted D1, real cookie/Access, rendered browser,
provider or signed-app acceptance. No new deployment or public route is enabled by this source.

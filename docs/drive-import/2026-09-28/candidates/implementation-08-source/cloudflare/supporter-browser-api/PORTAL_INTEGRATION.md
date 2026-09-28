# Membership portal integration — Implementation 06

## Source route and rollout

The existing `apps/rayon_sports/web/src/app/(site)/membership/page.tsx` selects the new
`BrowserMembershipPortal` only when the OpenNext Worker environment explicitly declares:

```text
AFRICLUB_BROWSER_PORTAL_MODE=cookie-v1
AFRICLUB_BROWSER_PORTAL_ORIGIN=<approved exact https origin without trailing slash>
AFRICLUB_BROWSER_PORTAL_CLUB_ID=<approved canonical decimal club ID>
```

No real values are approved or enabled in this package. Origin, incoming host and the existing
resolved club must match exactly. An invalid enabled mode displays an unavailable message;
it does not silently fall back to the older authentication flow. An absent mode or `legacy`
retains the original membership surface. The original surface is not newly accepted and its
contribution functions are not replaced by an invented Cloudflare implementation.

The new component uses the existing semantic CSS tokens, not a new brand or an asserted
Revolut-fidelity approval. It provides sign-in, current membership, approved checkout tiers,
explicit preparation review, original-operation recovery, owned order and historical receipt
reads, explicit browser-session renewal and sign-out. It never opens a dialer, executes a
payment, grants paid membership, runs a refund or provides a browser payment-confirmation API.

## Edge topology

Use `cloudflare/supporter-web-router` as the outer same-origin Worker for the approved host.
Its `BROWSER_API` HTTP service binding receives the ORIGINAL Cloudflare Request for
`/v1/browser/...`, preserving the runtime request context for existing ingress controls.
Its `NEXT_APP` binding serves the existing OpenNext application for other routes, after
removing untrusted forwarded-host overrides. There is no Next.js proxy that manufactures CF
IP context or passes a native token obtained in the browser. The new portal cannot work on
a separate cross-origin API host.

The outer router and the Next app do not receive financial database/provider bindings from
this change. The existing browser gateway retains its narrowly scoped private capabilities.
Disable public alternate origins/preview routes for the inner Next and API Workers in the
approved deployment. Test this topology on actual Cloudflare before enabling the route;
local service-binding stubs do not prove Cloudflare request metadata propagation.

## Prepared checkout versus payment

The offers endpoint reads at most 32 unique, valid rows from the same approved checkout view
used by `prepare`. A larger or inconsistent catalog is rejected, not truncated silently.
Only tier, amount, currency and country are returned; receiver and route identifiers are not
part of this catalog. Existing hyphenated tier codes remain supported.

Confirmation rereads the current session and catalog. A changed selected offer requires fresh
review. The catalog can still change after that read: the canonical prepared order determines
its actual price. That order is displayed for separate review, never paid automatically. No
cross-query/cross-database transactional price or revocation guarantee is claimed. Amounts
remain the existing service's configured units; this code does not approve currency scaling,
rounding, exchange rates or commercial prices.

With `rememberLastCheckout: true`, the client stores and verifies the last prepared order
before clearing the pending marker. A lost response or persistence failure retains the
original pending request. A subsequent read recovers that original result. `found:false`
does not prove failure and cannot authorize a replacement key. Only the deliberately labelled
retry uses the original request key and tier. Tabs share the same approved Web Locks adapter
and recovery store; software outside that protocol is not controlled by these locks.

## Browser cache and lifecycle

The actual `public/sw.js` no longer periodically fetches membership into the public-page
cache. Private paths, credentials and React server-component/action/prefetch requests are
network-only, including direct calls to the helper previously used by periodic refresh.
A dynamic response must explicitly permit public caching; redirects, Vary:Cookie, private
and no-store responses are excluded. Encoded paths fail closed for caching. Known immutable
Next static assets retain their ordinary public-asset caching path.

A controlling worker must acknowledge `AFRICLUB_PRIVATE_CACHE_CHECK` by purging its owned
page/API cache namespaces before the portal sends private requests. Old or failed workers
without the acknowledgement block the portal and require the user to apply the site update.
No current controller means this handshake has no controlling worker to consult; it is not
a declaration that all browser or historical storage is empty. The handshake does not erase
IndexedDB, pending checkout metadata, unrelated caches or financial records.

Hidden pages, offline transitions, pagehide, BFCache restoration, a controller change and a
cross-tab session-change signal hide private presentation and invalidate a loaded review.
A local expiry tick does not call HTTP and cannot extend a session, prepare a checkout or
retry a write. Returning to the page requires an explicit session check. These are authored
browser integrations; real navigation, multiple tabs and assistive technology remain untested.

Pending/last-checkout localStorage records contain opaque operational user/order/request IDs,
club, tier and time. They contain no OTP, phone, cookie, CSRF or native bearer. They are private
metadata, not anonymous data. Logout retains them for owner-bound recovery. Retention,
shared-device handling and erasure policy require a separate approved solution; do not clear
site data as a casual fix for an uncertain financial operation.

## Required integration acceptance

Run the pinned complete Next.js build and actual Workers bindings, then exercise sign-in,
expiry, changed offers, dropped responses before and after commit, shared-tab rotation,
logout recovery, blocked/old service workers, offline/BFCache restoration, suspension versus
historical receipts, keyboard navigation, large text and screen readers. Review private
response/CDN headers in actual network traffic. Complete all five club host configurations
without inferring deployment from a source configuration file.

The local tests execute the real controller/client/gateway and service implementations against
synthetic identities and genuine local SQLite, plus a VM service-worker cache/event harness.
They are not a rendered browser, Cloudflare workerd/D1, provider, carrier or store test.


## Implementation 07 — membership history

Adds read-only owned history and imported-receipt lookup. See `cloudflare/payment-allocation/MEMBERSHIP_HISTORY.md` at repository root for the wire paths, cursor contract, index migration, tests and retained acceptance limits. No live financial operation is executed.

# Same-origin supporter web router

A thin outer HTTP Worker composes the existing OpenNext app and browser API on one approved
HTTPS origin. It does not implement another authentication system or accept direct database,
provider or operator capabilities. Backend authority remains in the browser API and its
private bindings. This is source, not a deployed route.

| Input | Destination and behavior |
| --- | --- |
| Exact-origin GET/POST `/v1/browser/...` | Original Request forwarded once to `BROWSER_API`; private response headers retained/strengthened. |
| Unknown or encoded v1 API prefix | Rejected; never falls through to the Next application. |
| Other exact-origin paths | `NEXT_APP` after removing untrusted forwarded-host/evidence overrides. |
| Wrong origin, malformed configuration or disabled router | Rejected; no permissive fallback. |

Private responses preserve separate Set-Cookie values and set no-store on browser/CDN layers.
A thrown POST API binding response is an unknown outcome, not cancellation or an invitation
to invent a new operation key. No binding is automatically called twice.

## Staged configuration

Copy `wrangler.staging.jsonc` to a separately reviewed environment configuration. Its empty
account/origin, textual binding placeholders, disabled switch and absent public routes are
intentional. Do not deploy or turn the template on without the actual account, names, origin,
club mapping and source/runtime acceptance. Use the same origin in the browser gateway,
identity database origin record and Next portal variables documented in
`../supporter-browser-api/PORTAL_INTEGRATION.md`. The Next application's existing production
Wrangler file is not modified by this package.

Only the outer Worker should be publicly routed for this approved site. Keep inner Workers'
alternate development/preview origins closed. Bind the existing OpenNext application as
`NEXT_APP` and the configured browser gateway as `BROWSER_API`. Verify request CF context,
set-cookie forwarding, origins, routing and cache behavior on actual Cloudflare. This package
contains no provisioning, SQL application, switch enablement or origin ownership approval.

```sh
node cloudflare/supporter-web-router/scripts/validate-config.mjs
node --test cloudflare/supporter-web-router/tests/*.test.mjs
```

The validator proves only that the checked-in template remains disabled and capability-limited.
The tests invoke the actual router and service-worker script with synthetic bindings/cache
objects, not a public browser or the Cloudflare runtime. An enabled production configuration
needs its own review rather than bypassing this disabled-template check.

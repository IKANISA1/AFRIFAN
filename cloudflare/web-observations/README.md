# Private web observations

The browser projects five web-vitals names into bounded, rounded values and a
finite rating. PWA observations contain only an allowed event, surface and
display mode. Neither contract accepts a user ID, metric ID, location, raw
payload, navigation entry, cookie, bearer credential, user agent or trace input.

The client is disabled unless `NEXT_PUBLIC_WEB_OBSERVATIONS_ENABLED=true`. It
uses fixed same-origin endpoints, omits credentials and referrers, rejects
redirects, requests no caching, and makes one attempt. A document has a bounded
attempt count; each vital name has at most one submission. Observational failure
cannot retry a product mutation or delay the interaction that called it.

## Server and private binding

`/api/pwa/events` and `/api/telemetry/vitals` use `handleWebObservation`.
The server requires an exact selected HTTPS origin, a declared club ID, finite
policy reference, configured retention, and a `WEB_OBSERVATIONS` service binding
whose entrypoint is `PrivateWebObservations`. Incoming cookies and bearer
credentials are rejected; transport context is never forwarded. Bodies are
bounded to 1,024 bytes with a finite read deadline. Duplicate JSON keys and
unknown fields fail. Acknowledgement follows one verified binding result.

The web worker's private environment must explicitly select:

- `WEB_OBSERVATIONS_ENABLED=true`;
- `WEB_OBSERVATIONS_ENVIRONMENT=isolated-staging`;
- `WEB_OBSERVATIONS_ORIGIN`, the exact HTTPS origin;
- `WEB_OBSERVATIONS_CLUB_ID`, one of 6, 24, 26, 44 or 1001;
- `WEB_OBSERVATIONS_RETENTION_MS`, from one hour through 366 days;
- `WEB_OBSERVATIONS_POLICY_REF`, a finite reviewed non-personal reference;
- the private `WEB_OBSERVATIONS` binding.

The sink independently selects matching configuration and requires
`WEB_OBSERVATIONS_STORE_ENABLED=true`. It uses a separate D1 database, an atomic
per-club quota, server-generated times and an immutable observation table. The
private `PrivateWebObservationsRetention` entrypoint offers explicit bounded
expiry. All HTTP entrypoints on the sink return 404. The checked template is
disabled, has no route, and disables automatic invocation logs and traces.

Node tests execute the ingress and sink against actual SQLite, including all
five club IDs, finite events, privacy rejection, quota, expiry and lost binding
acknowledgements. Browser tests exercise the transport and the two Next route
wrappers. These local tests do not activate a binding or select a production
retention policy. Historical rows in the former Supabase PWA table are not
modified by this source change.

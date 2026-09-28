# Operator publication console — reconciled entrypoint

Use the canonical `wrangler.staging.jsonc`, `src/index.mjs` and generated
`src/ui-assets.mjs` from this reconciled source together. The protected page is
`/operator/clubs/24/public-source`; assets are `/operator/assets/*`. The runtime
requires both OPERATOR_API_ENABLED and OPERATOR_UI_ENABLED to be explicitly true.
Both remain false by default. No separate console Worker or Static Assets router
is required. The old `console-handler.mjs` is not part of this deployment graph.

`node cloudflare/operator-api/scripts/build-ui.mjs --check` proves generated assets
match UI sources and the strict TypeScript client. The index handles page/session,
candidate/preview, expiring review, explicit publication and receipt recovery.
Missing Access identity, wrong origin, wrong club or grants fail closed. The page
uses safe text rendering and no image embedding for unpublished content.

Nothing is integrated into the existing Next.js admin navigation by this source
reconciliation. A launch route, full browser membership session and real operator
Access journey remain separate tasks; neither this document nor an archived report
establishes they are already installed. See ui/README.md for supported controller
states, protected local recovery and known cross-tab/storage limitations.

Human review and publication remain separate explicit actions, but may be performed
by the same authorized person. This is not a completed dual-human approval system.
Source/reference fields are evidence pointers, not automatic editorial approval.


## Payment case workspace (Implementation 04)

`/operator/clubs/{clubId}/payment-exceptions` is a second directly served, Access-protected
operator view. It uses the existing token system and the six-path case API. The private
`PAYMENT_CASES` binding must expose `access`, `operation`, `list`, `get`, `history` and
`command`. The gateway, UI and case switches remain disabled in source templates.

`OPERATOR_METRICS_ENABLED` is an explicit string boolean, default `false`. When enabled,
HTTP metrics contain only schema/event, generated request ID, an allowlisted route class,
GET/POST/HEAD/OTHER, response status and bounded duration. Raw URLs/queries, errors,
request/response bodies, cookies, access tokens, IPs, club/case/user IDs are excluded.
Sink failure never causes a retried business command. This is HTTP instrumentation, not
cross-service tracing, an alert dashboard, approved logging retention or live monitoring.
The injectable sink is synchronous; production uses the default console sink only.

The pending operation contains private opaque metadata in actor/club-scoped localStorage;
it is not a credential store or a complete logout/account-erasure implementation. Do not
add service-worker caching of private responses. Existing no-store/CSP headers are retained.
Follow `cloudflare/payment-exceptions/README.md` for recovery and testing boundaries.

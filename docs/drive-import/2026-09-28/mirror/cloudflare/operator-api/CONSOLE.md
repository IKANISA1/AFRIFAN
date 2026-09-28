# Operator console — batch 3 source candidate

The operator console is implemented at `/operator/clubs/24` on the standalone
Access-authenticated operator gateway. The existing admin PWA gains a navigation
entry and a launch page at `/admin/publishing`. The launch page opens the configured
operator origin in a separate tab; it does not proxy credentials or authorize a
publication. The gateway independently checks identity and current club grants.

This delivery targets only the existing Rayon public-source **staging** service.
It does not replace supporter sessions, authorize production, migrate payments,
activate memberships, issue tickets or resolve the Predict/FET economic decision.
All deployment switches remain disabled. Adding source files or SQL migrations
in Drive does not apply a migration or deploy a Worker.

## Journey and deliberate safeguards

1. Read the current operator capabilities, active head and tenant-scoped candidate
   list. Public source discovery is paginated, with 25 records per page.
2. Select a candidate. Integrity verification seals an import and checks its row
   and media hashes. This step does not create an editorial review or publish.
3. Inspect the exact candidate hash, previous head, capture time, record counts,
   restricted-media count and field-allowlisted editorial records. Each record
   includes its source ID and original row hash. The explorer is **not a complete
   raw-source dump**. Private contacts and arbitrary payload keys are not exposed;
   long fields are marked as truncated. Images are not visually embedded.
4. Complete editorial/rights review using the existing external evidence process.
   Enter its reference and explicitly acknowledge that review. The server creates
   an expiring review tied to the exact snapshot, actor, permissions and head.
5. Separately acknowledge and confirm publication. The server remains the final
   authority. Local capability displays cannot grant access or bypass revocation.
6. On a verified response, show the durable receipt. The receipt describes the
   completed operation, not proof that it is still the latest active snapshot.

The same authorized person may review and publish. This is not maker/checker
approval. An acknowledgement and evidence-reference string do not independently
prove that a human completed editorial or rights review.

## Uncertain outcomes

Before sending confirmation, the console saves the exact review, candidate,
previous head and idempotency key in **tab-scoped sessionStorage**, scoped by
principal and club. Failure to save stops the request. A lost or malformed response
is shown as uncertain, not success or failure. A reload restores that exact pending
request. `POST publication-status` reads the matching receipt without resubmitting.
`not_observed` is not proof that an in-flight request failed. Explicit retry sends
only the original key and review, with no automatic mutation retry.

Closing the tab, clearing browser storage, or device loss can remove this local
recovery record. Operator support must then reconcile the retained server reviews,
publication receipts and audit records; do not invent a new confirmation to infer
what happened. Storage is not a secret/session-token store. Nothing is queued for
offline publication. Reconnection does not submit anything.

## Entrypoints and build

Use `wrangler.console.staging.jsonc` **instead of** the API-only gateway configuration
when testing the console. Both configurations refer to the same gateway service.
The console config selects `src/console-worker.mjs`; the private publisher remains
`AuthorizedPublicSourcePublisher` with no public ingress.

The wrapper uses fixed Wrangler Text modules for HTML/CSS/JavaScript. It imports the
existing web `tokens.css` directly. It deliberately does not use a Static Assets
router: current Cloudflare documentation says that router does not pass `ctx.access`
to the user Worker. The generated client is compiled from the canonical `client.ts`
by `node scripts/build-console.mjs` and is ignored source output. Do not hand-edit it.
No package installation or dependency-lock update is performed by the build script.

From `cloudflare/operator-api`, with the installed repository-approved TypeScript compiler:

```sh
node scripts/build-console.mjs
node scripts/check-deployment.mjs wrangler.console.staging.jsonc ../rayon-public/wrangler.authorized-publisher.staging.jsonc
node --test tests/*.test.mjs
```

`check-deployment` validates disabled templates by default. The `--ready` mode
checks configuration only; it does not authenticate people, certify an Access
policy or authorize release. Real staging runtime tests are still required.

## Admin PWA configuration

Server environment values, disabled when missing:

```text
PUBLIC_SOURCE_CONSOLE_ENABLED=false
PUBLIC_SOURCE_CONSOLE_ORIGIN=
```

Enable only after the corresponding exact HTTPS origin is provisioned and tested.
The origin must have no path, trailing slash, query, fragment or credentials. No
caller-supplied redirect is accepted. Only selected club 24 receives a launcher.
The source launch route uses existing `AdminPortalProvider`, `AdminPageHeader` and
`AdminSurface`. It does not transfer the existing Supabase admin session.
The full Next.js build and integrated PWA journey remain separate verification.

## Verification performed and outstanding

Node tests execute the controller, strictly compiled client, gateway and genuine
SQLite SQL. A loopback HTTPS fixture exercises the full request pipeline and a
response lost after commit. The fixture simulates Access identity and R2; it is
not workerd, actual Cloudflare D1, or provider authentication. Its TLS key and QA
control token are generated locally and never belong in deployment config.

System Chromium URL navigation was blocked by managed policy. The policy was
left unchanged. Separate Playwright **offline DOM-state** tests injected synthetic
API responses into the exact renderer/controller source and checked visible
interactions at 1440, 390 and 320 pixels, including 200% text. Those screenshots and
checks are not browser-network end-to-end, an integrated Next.js build, a real
Access login, or visual approval against the owner's private reference captures.

To reproduce offline DOM QA with an already installed browser:

```sh
python3 tests/console-dom-qa.py --output /tmp/africlub-console-dom --chromium /path/to/chromium
```

Do not change managed browser policies to run the tests. Browser, screen-reader,
mobile Safari, live Access, workerd bundling, real D1/R2, deployment and production
acceptance must be verified in an authorized environment before enabling staging.

Official references checked 26 September 2026:
- https://developers.cloudflare.com/workers/configuration/cloudflare-access/
- https://developers.cloudflare.com/workers/wrangler/configuration/#bundling
- https://developers.cloudflare.com/d1/worker-api/d1-database/

# Operator interface: implementation and acceptance boundary

This is the same-origin protected public-content interface, not a new supporter
app, financial authority, public website or replacement for the complete admin PWA.
All data and release actions are confined to the explicitly configured club 24.

## Flow

Open the Access-protected `/operator/clubs/24/public-source` page, inspect a listed
import or an exact snapshot ID, and enter the reference for actual external
editorial and image-rights review. “Verify and create review” verifies/seals the
import and creates a time-limited server review; it does not publish. Load the
fixed public text/data preview, inspect the hash and previous version, select the
acknowledgement, and type `PUBLISH <last eight snapshot characters>` to enable the
explicit publication action. The server rechecks the entire review and authority.
The phrase is a human confirmation aid, not a security credential or full hash.

A single operator can review and publish when granted both permissions. This is
not two-person approval. Selecting the acknowledgement or entering a review
reference does not itself establish editorial approval, rights clearance, or
legal authorization.

## Security and recovery

No tokens or raw identities are stored in the browser. The persisted recovery
record contains opaque scope, club, snapshot/review/operation IDs and the original
idempotency key. It has a bounded shape and is verified before reuse. No content,
editorial reference, profile, or credentials enter that record. Server receipts
and audit records remain the authoritative history.

A local-storage record is written and read back before sending confirmation.
Unknown outcomes retain that exact key and review, including after reload and
network loss. No event handler, page-open handler or timer automatically confirms
or retries publication. An explicit retry reuses the key after server review/head
checks. Web Locks coordinate tabs; lack of storage or locking disables mutations.
Clearing storage externally can remove recovery identifiers and requires a
separate authorized audit reconciliation, not a fresh speculative publication.

Review/candidate/receipt data is cleared before reauthentication resolves. New
identities cannot pick up another operator's recovery record. Expiry uses a
server-reported deadline mapped onto the monotonic browser clock; server checks
remain authoritative despite timer suspension or manipulated local clocks.

Strict CSP forbids inline code, external media, framing and form submission.
All source values render through textContent, never HTML insertion. Self-hosted
scripts and CSS are served from a fixed in-Worker map; do not add Static Assets
because this ingress needs runtime Access context. Every page/asset/API response
is no-store. No service worker or offline cache is installed by this module.

## Build and source checks

From the repository root, use the project-installed TypeScript compiler on PATH
(or the explicitly recorded compiler in a targeted isolated test environment):

```sh
export PATH="$PWD/apps/rayon_sports/web/node_modules/.bin:$PATH"
node cloudflare/operator-api/scripts/build-ui.mjs
node cloudflare/operator-api/scripts/build-ui.mjs --check
node --test cloudflare/operator-api/tests/*.test.mjs
node cloudflare/operator-api/scripts/check-deployment.mjs
```

The deterministic generated `src/ui-assets.mjs` is intentional deployable source;
edit `ui/*` or `client.ts`, never only the generated text. Source checks bind the
bundle to every source hash and to the existing token file. No dependency, asset,
font or tool download is performed. No deployment occurs in these commands.

## Browser acceptance

The runnable isolated test harness requires preinstalled Python Playwright,
Chromium and openssl. It binds loopback only and uses explicitly synthetic Access,
RPC and media with real local SQLite. Its TLS key and control token are temporary
and must not be committed or used for deployment.

```sh
python3 cloudflare/operator-api/tests/browser/run_browser.py \
  --results /tmp/africlub-operator-ui-browser
```

The intended flow under test is page load → inspect → verify/review → public
preview → explicit confirmation → receipt and GET-only recovery. Cases include
1280px desktop, 390px and 320px layouts, 200% page zoom (not a substitute for large
text testing), expired and revoked reviews, empty imports, source markup, storage
failure, keyboard focus and competing tabs. No browser dependencies are installed.

In the current execution environment Chromium denied local navigation with
`ERR_BLOCKED_BY_ADMINISTRATOR`. None of the 13 browser cases passed; the failure
is recorded as an environment blocker, not hidden or treated as success. Browser
policies were not changed or worked around. Source, state-machine and local SQL
checks do not replace rendered/accessibility testing.

## Rollout still required

Install all cumulative source changes, resolve the repository's pinned toolchains,
run rendered and full build checks, and configure a directly Access-protected
same-origin custom domain. Verify actual Access identity, private binding
exclusivity, D1/R2 resources, schemas, operator grants, browser cookies, CSRF,
revocation, retries and audit readback before enabling the API/UI/publisher flags.
The shipped templates keep them false. Add a reviewed navigation link from the
existing admin PWA only after the domain and access policy are established.

No live enrollment, grant change, publication, production client cutover, payment,
financial migration or Supabase retirement is authorized by these tests or files.

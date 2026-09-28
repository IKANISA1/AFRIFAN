# AFRICLUB — batch 2 implementation and delivery

Date: 26 September 2026.
Authoritative workspace: AFRICLUB Google Drive folder `1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH`.

## Delivered state

The missing operator authentication/authorization boundary around public-source
publication has been implemented as a local source candidate. The batch adds
**22 new source files**. A cumulative v2 bundle contains **69 source changes:
24 modifications and 45 additions**, including every first-batch change.

**Twenty-four source files were created at their correct Drive paths during this
batch:** the 22 new files plus two previously delivered, unchanged prerequisites
(`0003_immutable_public_snapshots.sql` and `snapshot-publication.mjs`). All 24 were
downloaded again and their SHA-256 hashes matched the tested local source.

Existing original source replacement remains blocked. The original repository
validator was fetched again and matched its original before-hash. Its attempted
in-place update again returned HTTP 403 `appNotAuthorizedToFile`. No original was
overwritten, renamed, deleted, or replaced by a same-name copy. Consequently the
new files are saved in the workspace, but the original reader and other first-
batch modifications still require authorized integration through the patch.

No Cloudflare deployment, remote database migration, operator enrollment, Access
policy change, production writer switch, payment action, billing change, or
Supabase retirement was performed. Both new deployment configurations are disabled.

## New implementation

| Component | Implemented behavior |
| --- | --- |
| Standalone operator gateway | Uses only Cloudflare's runtime-authenticated `ctx.access`; verifies the configured audience/account and stable human user UUID. No trust in raw identity headers, email mapping, service-token identity, or request-body actor fields. |
| Private authorized publisher | A separate `AuthorizedPublicSourcePublisher` WorkerEntrypoint. HTTP returns 404; only the authenticated gateway's reviewed service binding should call it. |
| Forward control-plane migration | Adds disabled-by-default principals, tenant mappings and expiring club grants; immutable reviews, durable receipts, retained audit events, atomic guards, and rate windows. No existing financial records are rewritten. |
| Review and confirmation | Seals/verifies the exact source snapshot and media; binds review to actor, club, hash, previous head, evidence reference and current authorization revisions. Review alone does not publish. Confirmation is a separate command within a five-minute review lifetime. |
| Transaction and retry behavior | Authorization recheck, active-head compare-and-swap, review consumption, publication receipt and audit record share one local-tested D1 batch design. Retrying the same completed request/key returns the same receipt; changed requests conflict. |
| Revocation | Disabled/expired principals or grants deny access. Permission or tenant changes invalidate pending reviews. Reenabling permissions does not revive those reviews. Authority is rechecked during commit. |
| HTTP boundary | Exact HTTPS origin and custom mutation header, bounded JSON body, strict allowed fields, safe errors, no cross-origin allowance, no-store responses and per-principal/club rate control. |
| TypeScript client and OpenAPI | Versioned head/review/confirm/status contracts, response-shape checks, explicit confirmation, stable idempotency key handling, timeout/unknown-outcome reporting and no automatic write retry. |
| Deployment and enrollment tooling | Detects unsafe configuration, wrong private entrypoint, storage bindings, mismatched identity settings, simulated deployment identities and assets-router mistakes. Enrollment generates only disabled INSERT statements and makes no network/database calls. |
| Saved-source replay | Runs the actual saved public export through the new gateway/service in disposable local storage, with synthetic Access and operator identities, then checks the existing public reader and media. |

The approved scope is public content for the configured Rayon staging database
(club 24). This is not supporter authentication, WhatsApp/SMS OTP, a full generic
multi-club authorization migration, financial command implementation, or completed
admin PWA integration. The other four supported club shells remain untouched.

The same authorized operator can review and confirm: this is not a two-person
approval system. A review-reference string identifies external editorial evidence;
its presence does not prove that a human completed editorial/rights review. The
admin PWA still needs a reviewed UI that displays the exact candidate and requires
an explicit action before calling the provided confirmation adapter.

## Executed verification

The final cumulative bundle repeated **234 targeted passing tests**:

| Test group | Passed |
| --- | ---: |
| Prior repository-boundary, economics and public-snapshot Node regressions | 52 |
| New operator identity, HTTP, SQL, retry, client, contract and deployment regressions | 98 |
| Prior Python source regressions | 60 |
| Source installer and rollback regressions | 24 |
| Total | 234 |

There were zero final failures or skipped tests. An initial concurrent duplicate-
confirmation test failed: one duplicate could report a conflict after its peer
committed. The implementation now checks the matching durable receipt after that
race, subject to current authorization. The final parallel-duplicate regression
passes. The initial failure log is retained separately from the passing final run.

The actual TypeScript client passed strict compilation. New JavaScript sources
passed `node --check`; the OpenAPI and deployment documents parsed as strict JSON.
Contract tests compare actual HTTP responses with the declared field shapes;
this bounded checker is not claimed as a complete general OpenAPI validator.

Environment: Node 22.16.0, Python 3.13.5, TypeScript 5.8.3, local Node SQLite.
The gateway and core publisher were executed directly, with simulated `ctx.access`,
private RPC and R2 storage. Genuine SQLite statements and triggers were exercised,
including injected failures at every review/publication batch position and a
simulated response lost after commit.

**These are not real Cloudflare D1, workerd, R2, live Access, browser login, or
production concurrency tests.** Wrangler/workerd, Dart and Flutter were absent;
network dependency installation was unavailable. The Cloudflare WorkerEntrypoint
wrapper was syntax checked, not executed in the actual Workers runtime. No claim
of provider authentication, successful remote deployment or complete app build
is made. The repository's full pinned web and mobile toolchains remain required.

## Actual saved-source replay

The earlier saved public JSON and original media were reused, not fabricated as
replacement production data. The source checksum and media hashes were validated.
Its immutable snapshot ID was:
`6d128c532f92b95131c32e5c26f6e74164d4df265d2e8d5e8cea3d36bbc3ad92`.

The replay imported **2,628 source rows and 11 media records** into disposable
local SQLite. Synthetic test identity and grants were installed only in that
isolated database. Review left the active head unchanged. Explicit confirmation
created one receipt and one publication audit event; the duplicate confirmation
returned the same operation without creating a second effect.

All nine public reader routes passed: 15 fixtures, 30 news items, 39 squad members,
42 fanclubs, three partners, two shop products, 15 ticket listings, six membership
tiers and 15 prediction-pool previews. Eight media originals were served with
exact matching hashes; three remained withheld by the existing rights filter.
Transaction-enabling flags stayed false. Original source bytes were unchanged.
These are dated saved-snapshot observations, not claims about current club data.

The eleven replayed originals are not the eight separate AFRICLUB originals whose
recovery remains unresolved in the prior migration records. No new media recovery
or source access restoration is claimed here.

## Reversible installation trials

The complete v2 package was preflighted, applied, after-hash checked, reapplied
without changes, and rolled back with every before-hash restored in three
independent disposable reconstructions:

| Starting state | Files changed | Already matching |
| --- | ---: | ---: |
| Original downloaded source baseline | 69 | 0 |
| Current Drive additions represented locally | 44 | 25 |
| Entire first patch already applied | 22 | 47 |

The source installer performs no network, account, database, provider or
deployment operations. It preserves recognized existing additions on rollback,
refuses conflicting source edits, and retains exact scoped backups. Multi-file
application still requires builds/editors to stop; it is not one globally atomic
filesystem transaction. These trials are not modification of the original Drive
files or a complete production backup/restore drill.

## Exact source destinations

- `AFRICLUB/cloudflare/operator-api/`: gateway, TypeScript client, OpenAPI,
  disabled configuration, enrollment/configuration checks, replay and tests.
- `AFRICLUB/cloudflare/rayon-public/src/`: new authorized publisher, authorization
  service, and earlier immutable-snapshot prerequisite.
- `AFRICLUB/cloudflare/rayon-public/migrations/`: preserved existing migrations
  followed by source additions 0003 and 0004. Adding SQL files does not apply them.
- `AFRICLUB/cloudflare/rayon-public/wrangler.authorized-publisher.staging.jsonc`:
  new disabled private-publisher configuration.

The cumulative package and reports are delivered separately in
`AFRICLUB/output/refactor-2026-09-26/batch2-operator-publication/`.
A create-only source-write/readback register retains each new Drive ID and hash.

## Remaining work and deployment boundary

R05 is now **operator service implemented locally, not deployed**. Before enabling
staging: integrate the operator UI, install the missing first-batch source edits,
verify the exact staging resource bindings, apply governed forward migrations,
protect standalone gateway ingress with real Access, enroll actual authorized
operators and source mappings, and run runtime authentication, revocation,
concurrency, failure and public-reader compatibility tests. Keep the older
unauthenticated private adapter disabled and unbound.

The new deployment checker cannot authenticate approval labels or remotely prove
Access protection. It explicitly reports runtime, live Access and release approval
as unverified even when configuration checks pass. No application secrets,
real operator identities or role grants are shipped as enabled defaults.

The remaining-actions register preserves the still unfinished supporter identity
and session service, complete native/web/admin API replacement, money/entitlement/
stock/ticket commands, function and scheduled-job ports, provider integrations,
whole-repository cleanup, full mobile/web acceptance, final consistent backup and
media recovery. Predict/FET economic policy approval remains unresolved.
Production cutover and Supabase retirement remain blocked and unperformed.

## Apply the cumulative package

Extract the v2 archive outside an authorized checkout. From its package directory:

```sh
python3 apply_patch.py --root "/path/to/AFRICLUB"
python3 apply_patch.py --root "/path/to/AFRICLUB" --apply
python3 verify_bundle.py --results "/tmp/africlub-v2-verification"
```

Use v2 instead of reapplying v1 afterward. Preserve the printed rollback journal.
Run the repository's pinned full checks separately. The source package contains
no raw exported content, original media, secret values, dependency caches, SQLite
databases or font files.

## Platform references

Official Cloudflare documentation checked 26 September 2026:
- https://developers.cloudflare.com/workers/configuration/cloudflare-access/
- https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/application-token/
- https://developers.cloudflare.com/d1/worker-api/d1-database/
- https://developers.cloudflare.com/workers/runtime-apis/rpc/

Runtime Access context is used only on the directly authenticated gateway;
Cloudflare documents that it is not forwarded to downstream service bindings and
is unavailable behind a Static Assets router. These documented constraints are
reflected in the separate gateway and deployment checks, not asserted as tested
remote behavior.

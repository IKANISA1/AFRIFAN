# AFRICLUB implementation and delivery report

Date: 26 September 2026  
Authoritative source: AFRICLUB Google Drive folder `1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH`  
Delivery: 47-file source patch, verification evidence, reversible installer and remaining-work register.

## 1. Actual completion state

**The source changes described below have been implemented and tested in a targeted
local copy. They have not been installed into the original Drive source files or
deployed. The requested complete backend migration is not finished.**

The attempted in-place update of `tools/scripts/validate_repository_boundary.mjs`
returned HTTP 403, reason `appNotAuthorizedToFile`: the connected Drive application
was not authorized to replace that existing file. No original source file was
subsequently overwritten, deleted, renamed or replaced by a same-name copy. The
package retains original Drive IDs and before-hashes so a later authorized merge
can preserve source identity and concurrent edits.

A new `docs/governance/legacy-reference-exceptions.json` was successfully added to
Drive before that failure. It is not consumed by the unchanged original validator.
A scoped pre-change source archive and a delivery folder were also created. These
are source-delivery operations, not evidence of a running application update.

The delivered patch contains **24 modified source files and 23 new source files**.
Seven other downloaded source files are unchanged prerequisites. The baseline
manifest covers **31 original files**, not the entire repository. Existing unrelated
revised copies, generated caches, recovery exports and production resources were
left intact.

## 2. Implemented source changes

| Workstream | Concrete source implementation | Verification and boundary |
| --- | --- | --- |
| Repository boundary | Exact-path, SHA-256-bound, expiring exceptions for identified migration evidence; runtime paths, schemas, generated output and required football capabilities remain checked. | 17 Node regressions passed, including existing migration documents and negative exception cases. The original Drive validator remains unchanged until installation. |
| Public snapshot storage | Forward migration `0003_immutable_public_snapshots.sql` adds versioned records/media, immutable sealed imports, active-head selection and publication guards. Existing migrations and legacy records are preserved. | Real local SQLite schema and failure tests passed. No remote migration was executed. |
| Public Worker | All nine existing read routes use one approved fresh snapshot; JSON and media share freshness; media uses content-addressed keys and SHA-256 verification. Transaction-disabled responses are preserved. | 26 Node snapshot tests passed using a D1-shaped SQLite adapter and R2 test doubles. This is not real Cloudflare runtime validation. |
| Snapshot import and approval | Bounded manifest-fragment SQL, exact source/table/tenant/hash/media validation, seal-before-verification, compare-and-swap publication and private RPC adapter. | 20 Python import/parity tests passed. Private publication defaults disabled and still requires authenticated operator-service integration. |
| Media staging | Existing tool now defaults to dry run, validates local originals, uses content-hash keys, and requires explicit execution for the fixed staging bucket and readback. | Source implementation and validation tests; no R2 upload was performed during this turn. |
| Five-club supporter SMS controls | New XML-aware validator scans registered production packages and all five app roots; source removal directives are distinguished from active permissions; optional merged-manifest checks fail if any club is absent. Existing Rayon-specific store-copy checks remain additional. | 16 Python regressions passed. Five genuine main source manifests passed permission checks; full compiled artifacts were not inspected. |
| Feature composition | Club-disabled features cannot be remotely re-enabled; malformed supplied feature configuration fails closed; empty module registration uses the built-in unavailable route. | Dart policy checks and a Flutter empty-router test were added but not executed because the SDKs were unavailable. |
| Design governance | Corrected five-club scope, clarified the design skill/adapter hierarchy, and updated the adapter hash record without asserting private-reference or visual approval. | Source/hash consistency checked. No design-reference screenshots or physical-device visual acceptance performed. |
| CSS cleanup | Merged only adjacent identical leaf rules in existing admin and shared theme stylesheets. | Nine redundant rules removed, saving 394 source bytes; ordered per-selector declaration ASTs were equivalent before/after. Token values were unchanged. No web build or visual approval claimed. |
| Predict/FET decision control | Added an explicit unresolved economic-contract record and release validation; historical ledger and implementation evidence are preserved. | Nine Node regressions passed. No new economic policy approval or production balance change was invented. |
| Migration catalog | Generator creates stable project/object identities, preserves overloaded function signatures and resets decisions when source metadata changes. Unmapped or missing entries never authorize retirement. | Saved source inventories were checksum-verified; 1,960 catalog entries were generated, all still requiring approved dispositions. |
| Cutover/retirement | Candidate-bound evidence validator checks required gates, freshness, reviewer labels, artifact hashes and single-writer state; templates start unproven. | 24 Python catalog/release tests passed. The 18 cutover and 22 retirement gates do not perform deployment or authenticate reviewer identities. |
| Local check integration | Added `melos run verify_refactor` and its source-check script without weakening existing toolchain requirements. | Shell syntax checked. Complete-checkout Melos/CI execution was not performed. |

The public service remains a limited Rayon public-source migration candidate. It is
not a replacement for supporter authentication, payment authority, member
entitlements, ticket admission, FET settlement, or the complete white-label backend.

## 3. Executed test evidence

| Executed group | Passing tests |
| --- | ---: |
| Repository-boundary Node regressions | 17 |
| Immutable snapshot and public Worker Node regressions | 26 |
| Predict/FET decision-record Node regressions | 9 |
| Supporter SMS boundary Python regressions | 16 |
| Snapshot import and parity Python regressions | 20 |
| Migration-disposition and release-evidence Python regressions | 24 |
| Source installer and rollback regressions | 24 |
| **Total targeted passing tests** | **136** |

The assembled delivery bundle independently repeated the three test groups:
52 Node tests, 60 source Python tests and 24 installer tests, all passing.
Twenty-five changed/new Python, JavaScript and shell source files also passed the
applicable syntax checks. None of these results is a complete application build.

The environment was Python **3.13.5**, Node **22.16.0**, Linux, local SQLite and
file-backed R2 test doubles. CSS AST checks used PostCSS **8.5.6**. The repository's
web requirement remains Node **>=22.22.2 <23**, npm **12.0.2**, and its own lockfile.
The targeted environment does not satisfy or replace that full pinned toolchain.

Dart, Flutter and Wrangler were unavailable. The 20-check pure-Dart policy test and
new Flutter router test were **not executed**. No full Flutter analysis, Next.js
production build, pgTAP suite, real D1 performance/concurrency run, live provider
integration, signed native build, device accessibility journey or production UAT
was performed.

## 4. Real saved-source replay

The actual saved public source export and its original media were obtained from
the repository's migration-output folder, not synthesized as replacement data.
The source JSON checksum and media hashes were checked. The new importer produced
an unpublished local snapshot with **2,628 source rows and 11 media records**.

Snapshot identity:
`6d128c532f92b95131c32e5c26f6e74164d4df265d2e8d5e8cea3d36bbc3ad92`

The exact Worker was exercised against a disposable SQLite backup and a file-backed
R2 test double. Approval used an explicitly synthetic local-test identity. The
original local import database remained unchanged. No Cloudflare account was
contacted or modified.

All nine routes passed. The replay returned 15 fixtures, 30 news items, 39 squad
members, 42 fanclubs, three partners, two shop products, 15 ticket listings, six
membership tiers and 15 prediction-pool previews. **Eight media originals were
served with exact matching hashes; three were withheld by the existing rights
filter.** Purchase, paid-ticket issuance and prediction-entry flags remained false.
These are saved-snapshot replay results, not current live club-content claims.

The separate five-club check read the original main Android manifests for Rayon
Sports, Vital'O, AS Vita, Nkana and Costa do Sol. No prohibited active message
permission was found in those five files. This does not establish the permissions
of a merged, signed or installed release.

## 5. Migration inventory and unresolved work

The inspected machine-readable inventory was captured on
**25 September 2026 at 19:37:42.693302 UTC**. Its saved checksum matched and its query
failure list was empty. The disposition generator accounted for:

| Saved catalog section | Entries |
| --- | ---: |
| Relations: 197 tables and 37 views | 234 |
| Functions, preserving overload identity | 342 |
| Policies | 354 |
| Non-internal triggers | 198 |
| Indexes | 769 |
| Deployed Edge Functions | 18 |
| Local-only Edge Functions | 2 |
| Active scheduled jobs | 6 |
| Storage buckets | 2 |
| Secret names, not values | 25 |
| Extensions | 10 |
| **Total** | **1,960** |

**All 1,960 entries remain unresolved for approved migration/retirement disposition.**
The register accounts for the available catalog sections; it is not a full export
of every auth identity, media object, grant or caller. No function is described as
ported merely because its name appears in this register.

The complete remaining-work register is `remaining_actions.json`. In particular,
replacement supporter identity/session services, complete server authorization,
versioned domain APIs and client adapters, financial/ticket transaction ports,
recovered-function behavior comparisons, scheduled-job/provider ports, real
Cloudflare staging approval integration and full-club release acceptance still
need implementation and verification.

The repository's dated records report an archive restore drill but not a final
transactionally consistent snapshot, and eight inaccessible **AFRICLUB** media
originals. That source access condition was not rechecked live. The eleven public
source originals replayed here are a separate subset, not recovery of those eight.
No spend cap, billing plan, source key, live job or storage object was changed.

Predict/FET's historical debit-based behavior and free-entry policy remain an
accountable business/legal/payment decision. The patch records and gates this
conflict; it does not invent approval or silently change existing financial history.

Production cutover and Supabase retirement are **blocked and unperformed**. The
single-writer rule remains. After authoritative target financial writes start,
recovery requires forward reconciliation, not an unreconciled traffic reversal.

## 6. Application and rollback proof

The complete 47-file bundle was dry-run, applied, checksum-checked, reapplied and
rolled back against a disposable reconstruction of the downloaded source baseline.
All after-hashes and restored before-hashes matched. A second trial preinstalled the
new exception registry to match the current Drive situation: 46 files changed, the
pre-existing registry was preserved, reapplication was idempotent, and rollback
restored the other sources without removing that registry.

The installer refuses modified originals, unexpected pre-existing new files,
corrupted payloads/backups, path traversal, symlinks, foreign journals and concurrent
writers. It preserves concurrent edits on rollback. It makes no network, database,
provider, key, billing or deployment calls. Source writes are individually atomic;
stop source readers/builds during the multi-file operation. Scoped source backups
must not be mistaken for production database backups.

## 7. Delivery contents and required next execution

The bundle contains exact relative source paths, before/after SHA-256 values,
original Drive IDs, a unified diff, the reversible installer, the remaining-work
register and executed evidence logs. Raw exported content, original media,
credentials, SQLite databases, dependency caches and font files are excluded.

Use the read-only installer preflight first, then explicit source application on an
authorized local checkout. Resolve the repository's pinned dependencies and run the
new Melos refactor check plus all existing Flutter/web/database/native release
gates. Review the public service's migration order before any deployment; deploying
only the changed Worker without its schema, module and approved snapshot will
correctly return an unavailable response.

This delivery is a substantial implemented and locally verified source patch.
It is **not a claim that every requested action, integration, migration or release
step has been completed**.

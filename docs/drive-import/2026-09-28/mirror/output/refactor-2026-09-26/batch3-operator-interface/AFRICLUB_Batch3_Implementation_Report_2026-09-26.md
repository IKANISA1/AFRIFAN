# AFRICLUB — batch 3 operator interface implementation

Date: 26 September 2026. Source authority: the supplied AFRICLUB workspace and the
previously delivered cumulative v2 source package. This is implementation of the
next unfinished public-content operator workstream, not a new architecture rewrite.

## 1. Actual delivery state

Batch 3 implements **28 source changes: 14 modifications to v2 files and 14 new
files**. The cumulative v3 package contains **83 source changes relative to the
original scoped baseline: 24 original-file modifications and 59 additions**.
It includes all earlier v1 and v2 changes.

**No files were written to Google Drive in this turn.** Current Google Drive and
Files tool discovery exposes read operations but no upload, update or library-write
action. The installed-provider search did not expose another authorized write
route. The current operator folder and README were read successfully. Earlier
403 replacement failures were not retried, and no original file was overwritten,
renamed, deleted, or replaced by a same-name copy. Delivery is the local cumulative
archive, exact source paths, checksums and reversible installer.

No production deployment, remote SQL migration, Access configuration, enrollment,
role grant, real public-content publication, billing change, payment, client
cutover or Supabase retirement occurred. API, UI and publisher templates remain
disabled. The work was performed in a targeted source subset, not the full monorepo.

## 2. Implemented workflow

The directly Access-authenticated operator Worker now serves
`/operator/clubs/24/public-source` and four fixed same-origin UI assets. It uses
no Static Assets binding, service-worker cache, third-party script, downloaded
font or media embedding. HTML and assets require current runtime Access identity;
the HTML page additionally checks the club grant. Server-side identity and tenant
checks, rather than hidden controls, remain the authorization boundary.

An operator can inspect a listed import or exact snapshot ID, see its full hash,
capture time, import state, source-table counts and currently published predecessor,
then enter the reference for actual external editorial and image-rights review.
Verification creates a time-limited review but does not publish. The interface
previews the public reader's fixed data/eligibility projection, without fetching
unpublished images. An acknowledgement and the displayed confirmation phrase are
required before the explicit publication command. No page-open event, timer or
reload automatically publishes.

The UI distinguishes a historical publication receipt from the currently active
version. It retains the same review and idempotency key after an interrupted
confirmation, reloads status by GET only, and allows only an explicit same-operation
retry. Unknown outcomes cannot be discarded to begin a new publication. Storage
or Web Lock failure disables mutation; a missing recovery mechanism is not silently
accepted. The phrase is a confirmation aid, not a security credential.

A server-derived opaque operator/club key isolates local recovery. The browser
record contains IDs and the original request key, not tokens, raw identity,
editorial evidence or source content. In-memory private display state is cleared
before reauthentication resolves. Other operators cannot adopt an old pending
operation through the application. Web Locks coordinate cooperating tabs; the
backend independently enforces current authority, review binding and idempotency.
The server remains authoritative when storage is cleared outside the app.

This is a **standalone protected operator interface**, not yet a navigation entry
or embedded screen inside the existing Next.js admin PWA. Only the configured
Rayon staging club is supplied. The other four supported club shells are unchanged.
It is not two-person approval: an appropriately granted operator may review and
confirm. An entered reference or checkbox does not establish actual editorial,
image-rights, legal or release approval.

## 3. Server, contract and source changes

| Component | Implemented behavior |
| --- | --- |
| Inspection API | Current operator/club scope, newest 20 candidate imports and exact candidate metadata. All reads are tenant-authorized. Opening a candidate does not seal it or create a review; rate counters still update. |
| Public preview API | Nine fixed projections, fresh verified/active snapshots only, up to 25 returned records per page; no raw source JSON endpoint and no private media fetch. |
| Review recovery API | The current operator's own review, expiry/revision state and durable publication receipt, under current authorization. |
| Source reader reuse | Extracted/exported the existing public projection rather than introducing a competing set of eligibility rules. Public responses and disabled transaction flags are preserved. |
| Query index | Forward-only migration `0005_operator_candidate_index.sql` adds a tenant-scoped partial index for the bounded candidate list. Local SQLite EXPLAIN uses it without a temporary sort. It grants no permission and activates nothing. |
| Typed API | TypeScript client validates IDs, club, response shapes, review/receipt correlation and paging; OpenAPI 1.1.0 covers all nine route patterns. Wire schemaVersion remains 1. |
| UI delivery | Deterministic direct-Worker text bundle from authored HTML/CSS/modules and compiled client. Exact existing token bytes are retained. CSP forbids inline execution, framing, external assets and form navigation. |
| Source gates | Generated-asset/source parity, HTML pattern/label/ID bindings, safe text rendering patterns and unchanged semantic tokens; new operator checks join the full-checkout refactor command without reducing its toolchain requirements. |
| Upgrade installer | Only enumerated exact prior v1/v2 hashes are accepted in addition to the original baseline. Backups journal the actually installed version, so rollback restores that version rather than deleting a previously added file. No force-overwrite option. |

The candidate-list index is a local query-plan result, not a real D1 performance
benchmark. Public preview still reads the relevant snapshot projection before
slicing its response; returned-row bounds do not prove bounded storage reads or
production latency for large imports.

## 4. Executed verification

The final delivered bundle independently repeated **308 passing targeted tests**:

| Test group | Passed |
| --- | ---: |
| Existing repository-boundary, economic-decision and public-snapshot Node tests | 52 |
| Operator/API/client/deployment plus new inspection, controller and static-UI tests | 163 |
| Existing Python source/import/migration-control tests | 60 |
| Installer and rollback tests, including 9 new version-upgrade tests | 33 |
| **Total** | **308** |

Of these, **74 are new this batch**: 65 operator/interface/source checks and 9
installer regressions. The installer tests use six independent parallel fixture
slices to stay within the tool host's execution window; all 33 test names are
accounted for. No test was omitted or counted as passing because it was skipped.
Generated UI parity and disabled configuration checks also pass. The actual
TypeScript client compiles strictly. Applicable changed JavaScript, Python,
shell and JSON sources pass syntax checks recorded in evidence.

The tests cover exact hashes, cross-tenant denial, own-review access, no GET-driven
verification/publication, expiry/revocation, source markup as data, lost responses,
receipt mismatch, duplicate confirmation, storage failures, identity changes,
cooperating-tab locks, immutable history, source conflicts and rollback recovery.
Controller and static-source tests do not establish rendered browser behavior.

Environment: Node 22.16.0, Python 3.13.5, TypeScript 5.8.3 and genuine local Node
SQLite. Access identity, private RPC and R2 are explicitly simulated. The repository's
higher pinned web toolchain is unchanged. No full Next.js build, Flutter analysis,
pgTAP, signed native build, workerd, real Cloudflare D1/R2 or live Access journey
was executed. Existing Dart/Flutter requirements remain in force.

## 5. Browser validation — blocked, not passed

The intended flow is protected page → inspect → verify/review → public preview →
explicit confirmation → receipt → GET-only recovery. A runnable Python Playwright
harness was added for desktop, 390px/320px mobile, 200% page zoom, expiry, revoked
permissions, empty imports, markup safety, storage failure, keyboard focus and
real multi-tab locking. It uses a temporary loopback HTTPS server and synthetic
Access, with real local SQLite; no account credentials or remote services.

Chromium 144.0.7559.96 returned **ERR_BLOCKED_BY_ADMINISTRATOR** on navigation to the
local preview. **Zero of 13 browser cases passed.** No application page rendered,
so interaction, layout, focus, accessibility, CSS fidelity and console-health
acceptance remain unverified. The administrator policy was not modified or worked
around. Browser error-page screenshots are not presented as application evidence.
The Browser plugin was not available; regular Python Playwright was attempted.

An earlier empty-state fixture incorrectly tried to delete retained snapshots;
the immutable trigger rejected it. The corrected harness creates an empty database
without importing a snapshot instead. No retention rule was relaxed. The source
HTML pattern was also corrected to compile under Unicode-set regex syntax; static
regression tests verify this independently of the blocked browser.

## 6. Actual saved-source replay

The existing saved public export was re-imported into disposable local storage:
**2,628 source records and 11 media records**, with the original byte/hash checks.
The snapshot ID remains:
`6d128c532f92b95131c32e5c26f6e74164d4df265d2e8d5e8cea3d36bbc3ad92`.

New session, candidate-list, candidate-detail and review-status reads passed.
All nine operator previews matched the public reader's selected fields and counts
(after the deliberate removal of image URLs). The replay observed 15 fixtures,
30 news items, 39 squad members, 42 supporter groups, 3 partners, 2 shop products,
15 ticket listings, 6 membership tiers and 15 prediction-pool previews. These are
**dated saved-source observations**, not a fresh scrape or current-club-data claim.

Explicit synthetic confirmation created one publication receipt and one publication
audit event; duplicate confirmation returned the original receipt. Eight original
media files passed served-byte hash checks and three remained withheld by the
existing rights filter. Transaction-enabling flags stayed false and source bytes
were unchanged. This is not recovery of the eight separate AFRICLUB originals that
remain unresolved in the earlier migration records.

## 7. Cumulative installation and rollback trials

The exact 83-file package passed dry-run, apply, after-hash verification,
reapplication and rollback in four disposable reconstructions:

| Starting source state | Changed | Already matching |
| --- | ---: | ---: |
| Original scoped baseline | 83 | 0 |
| Entire v1 patch applied | 38 | 45 |
| Entire v2 patch applied | 28 | 55 |
| Prior documented Drive additions represented locally | 70 | 13 |

Every rollback restored the bytes present at the start of that trial. These are
local source trials, not edits to the real Drive workspace or a complete production
backup drill. Unknown concurrent edits still stop preflight and rollback. The
original 31-file source archive is only a scoped baseline, not a full repository.

Use the cumulative v3 bundle instead of applying v1/v2 afterward. Stop source
editors/builds during multi-file application. Individual writes are atomic; the
whole multi-file operation is not one atomic filesystem transaction.

## 8. Remaining work

R05 now has local source for its operator interface and service, but enabling it
still requires authorized source integration, a permitted real browser test,
verified staging resources/migrations, actual Access ingress and staff enrollment,
private binding review, full build/visual/accessibility checks, operational audit
controls and a reviewed admin-PWA navigation entry. The authored interface and
source tests are not publication or release approval.

Supporter OTP/session migration, complete platform authorization, financial and
ticket transaction ports, full typed native/web adapters, provider/function/job
ports, whole-repository cleanup, final consistent backup and media recovery remain
unfinished. Predict/FET economic approval is unresolved. Production cutover and
Supabase retirement remain blocked and unperformed. The remaining-actions register
preserves each prior workstream rather than describing inventory as completed ports.

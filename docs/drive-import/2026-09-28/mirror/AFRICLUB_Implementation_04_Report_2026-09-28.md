# AFRICLUB — Implementation 04
## 28 September 2026

**Implemented source, locally tested and packaged: operator payment-case UI and recovery,
current membership reads, privacy-safe HTTP metrics, migration comparison and dependency
planning. Not deployed; not a complete AFRICLUB production release.**

## What changed

This delivery builds on the exact 322-file Implementation 03 scoped source candidate.
It adds **20 paths** and modifies **26 paths**: **46 changed source/document paths**.
The resulting scoped candidate contains **342 files**, with **296 unchanged exact-hash
prerequisites**. The package is not a fresh full monorepo export or a canonical Git merge.
All SQL migrations are unchanged. Your existing Drive source is not replaced.

| Work area | Actual implementation | Boundary still open |
|---|---|---|
| Operator case UI | Direct Access-protected route, role-aware case lists, seven commands, explicit confirmation, separate checker, pagination and loaded history refresh | Real browser/Access and Next.js/admin launcher acceptance |
| Uncertain case writes | Actor/club-scoped original-operation lookup, durable metadata, explicit same-key retry, stale-review and response-loss handling | Complete organizational retention/shared-device policy and all admin workflows |
| Current membership | Private reader, native gateway and strict TypeScript client distinguish current suspension/expiry/pending/incomplete status from historical receipts | Five-app/browser integration and real authorization/financial acceptance |
| HTTP metrics | Explicit opt-in allowlisted request-ID/route-class/status/duration metrics, with no request or private-record values | Production dashboards, alerts, cross-service tracing, retention and privacy approval |
| Migration checks | Read-only bounded typed snapshot comparator: duplicate keys, missing/extra/changed rows and exact monetary group comparison | Actual extraction, approved normalizers, complete coverage, cross-table integrity and hosted cutover |
| Task dependencies | Immutable input-bound plan for all 130 IDs, 19 prerequisite layers, missing/cycle/closure checks | Named ownership and actual acceptance evidence |
| Main verifier | Adds omitted payment-case suites and checks, preserves required runtime pin and honest blocked status | Full repository CI, supported SDKs and target-runtime verification |

### 1. Integrated operator case workflow

The route is `/operator/clubs/{clubId}/payment-exceptions`, served by the existing
Cloudflare operator gateway. All gateway, UI and case switches remain **disabled** in
shipped templates. The page is returned directly by the Worker and uses the established
human Access boundary; there is no browser-supplied user identity, supporter-token shortcut
or Static Assets authentication hop.

Operators can open, triage, propose, approve, reject, close and reopen cases, subject to
server roles and current revision. A proposer cannot approve their own proposal even with
both roles. The UI rechecks the authoritative head before confirmation and does not present
an old loaded history as newly refreshed after a command. An explicit read-only history
refresh is provided. Existing publication functionality retains its regression coverage.

Two additive read endpoints expose current case capabilities and the original operator's
immutable operation outcome. Capabilities are UI hints, not durable permission. A lost
response retains the original operation key and exact request metadata; a reload or
recovery read never sends another command. Explicit retry reuses the original identity.
A 404 lookup does not prove an in-flight request cannot commit. Corrupt/unavailable local
storage stops new writes rather than discarding uncertainty.

Pending localStorage records contain opaque case/order/evidence/operation IDs, actor/club,
revision and controlled enums/digests. They contain no credentials, phone numbers, raw SMS
or free-text narratives. These IDs remain private operational metadata, not anonymous data.
The work is not a complete account-erasure, PWA logout or shared-device privacy solution.

**This case workflow does not verify financial evidence, transfer/allocate funds, execute
refunds, activate paid membership or prove payment settlement.** Referral to reconciliation
or refund review is not execution of either financial process.

### 2. Current membership, not a historical receipt

The additive `GET /v1/supporter/clubs/{clubId}/membership/status` endpoint uses the existing
native-only gateway and read capability. It derives the user from authentication and does
not accept an order or user override. It returns a point-in-time `observedAt`, `currentStatus`,
`isActive`, `historical:false` and minimal membership-term data.

An old receipt showing active membership cannot override a later suspension or expiry.
Missing/unverified/future term fields do not activate a member. The gateway validates the
private projection, rechecks identity and can downgrade an expiring active term before
response. It does not claim atomic identity/financial cross-database revocation or
permission for a later mutation. The TypeScript client is strictly compiled and exercised
through the actual gateway in local tests; no Dart screen or native app composition was
installed by this change.

### 3. Data-minimized metrics and migration tooling

Operator metrics require explicit enablement. Their fields are schema/event, generated
request ID, coarse route category, method, response code and bounded duration. Bodies,
errors, query strings, IPs, user/club/case IDs and credentials are excluded. Logging failure
cannot retry a business command. The shipped opt-in remains false.

The snapshot comparator validates declared fields, non-null keys, exact decimal/integer
strings, UTC timestamps, completeness declarations and equal scope/normalization/cutoff
context. It compares keys/rows and exact monetary groups without emitting individual
record values, keys or balances. It never rounds, picks FX rates or chooses business
currency conventions. Matching two supplied subsets is **not** full extraction proof:
`coverageVerified` and `releaseAuthorized` always remain false. Inputs are not changed.

The dependency planner reads the existing register, preserves IDs and acceptance text,
and distinguishes implementation progress from closure prerequisites. The baseline forms
19 acyclic layers, and all 130 tasks still need assigned named owners. It never executes
commands found in task text or treats a closure declaration as verified approval.

## Verification completed this turn

| Completed test group | Passing tests |
|---|---:|
| Full Node backend/gateway/client/queue/handoff/source-boundary regression run | 1,761 |
| Python source/security/migration/dependency tests | 227 |
| Installer safety and current-bundle dry-run/apply/repeat/rollback/conflict tests | 39 |
| Freshly compiled portable Kotlin recovery tests | 69 |
| Freshly compiled portable Swift recovery tests | 68 |
| **Unique passing tests, counted once** | **2,164** |

There are **150 newly authored cases**: 91 Node and 59 Python. Existing regression and
portable-native tests are rerun, not described as new code. The final Node run has zero
failed, skipped, cancelled or todo cases. Another **225 syntax/parse checks** passed,
along with strict client compilation, checked-in asset parity, disabled deployment
configuration checks, source-only migration lineage checks and the limited 342-file
sensitive-source scan. These additional checks are not added to the test total.

The first combined installer run hit the tool timeout and is not counted. Complete
replacement runs of 17, 16 and six tests are the counted evidence. Intermediate logs are
preserved. The post-read identity-revocation regression was corrected to invoke the actual
revoke API and assert a successful revocation before the final completed test run.

Node is **22.16.0**, not the repository pin **22.23.2**. The required pin was not lowered.
Python is 3.13.5 and TypeScript is 5.8.3. The complete source verifier correctly exits
**2 / blocked** for the Node mismatch and absent Dart/Flutter. Portable Kotlin/Swift
success is not Android Keystore, Apple Keychain, Flutter-host, signed-app or device proof.

### Browser QA boundary

The intended flow is: Access case route → select/open case → review exact command →
confirm → verify immutable result, including read-only recovery after a lost response.
Controller and compiled-client tests exercise the real gateway and real local SQLite
with synthetic identities. They are not rendered-browser tests.

| Rendered check | Current result |
|---|---|
| Navigate to the case page | Blocked before rendering: `ERR_BLOCKED_BY_ADMINISTRATOR` |
| Page identity and nonblank rendered content | Not verified |
| Framework-overlay and browser-console health | Not verified |
| Desktop/mobile visual layout and screenshots | Not verified; zero screenshots |
| Click/keyboard/screen-reader interaction | Not verified |
| Alternative transport or policy bypass | Not attempted |

The available Browser plugin was absent; the documented fallback used installed Chromium
through Playwright. It encountered the administrator block on the first HTTPS loopback
navigation and stopped. The harness is included for a legitimately permitted development
environment. No screenshot, rendering or accessibility approval is fabricated.

## External actions and source authority

The connected Drive root was reread and still has **anyone/writer** permission with
link discovery disabled. Permission revocation was not exposed by the available Drive
actions; the share action only grants access. No sharing state or credential was changed.
The metadata result does not imply that the owner lacks permission or prove actual misuse.

Connected GitHub searches for AFRICLUB and Rayon returned no repositories. No unrelated
repository was selected. The local Git commit records the exact scoped baseline only;
no remote branch, pull request, branch protection or Actions execution was performed.
Relevant plugin discovery did not supply hosted Cloudflare management. No live resources,
provider calls, real payments, migrations, store submissions or production deployments
were performed.

The original conflicting version-0003 financial handoff sources remain distinct. The
existing guard blocks duplicate or unrecognized histories. No automatic migration rewrite,
renaming or backfill was attempted. A protected canonical source, actual hosted history
readback and reviewed forward-only reconciliation remain requirements.

## Updated task status and immediate work remaining

**130 tasks remain unaccepted: 31 In progress, 99 Open, zero Closed.** Source progress was
added to 19 task records. Four previously Open tasks are now In progress: SEC-08, DAT-06,
DAT-10 and PAY-04. All priorities, dependencies, owner roles and acceptance requirements
are preserved. No task is closed solely because local tests pass.

The full scope remains in `TASK_REGISTER.json`, readable `REMAINING_TASKS.md` and generated
`EXECUTION_PLAN.json`. The immediate prerequisites are restricted source sharing and
credential assessment; a resolved canonical repository and migration lineage; exact
runtime/SDK builds; permitted browser and real Access/D1 tests; authoritative financial
evidence/reconciliation/refunds; native/browser integration; and named operational,
privacy, club and release approvals. Wider contributions, tickets/shop, account recovery,
retention, monitoring, backup/cutover and store work is not silently claimed complete.

## Package use

Start with `CODEX_HANDOFF.md`. The installer defaults to a dry run, verifies exact hashes,
refuses independent changes, records rollback data and never applies SQL. Use the exact
Implementation 03 prerequisites. Do not replace the full repository with `source/`, flatten
paths, bypass a migration conflict or force the patch onto an older root snapshot.

`files/` is the complete 46-path delta; `source/` is the 342-file scoped verification
candidate; `before/` preserves originals for modified files; `reference_only/` holds the
competing Drive migration outside installable source. `tracked-source-diff.patch` covers
modified tracked paths only; new paths are fully included in `files/` and the manifest.
`evidence/` contains actual machine results. Upload is verified separately and does not
mean deployment or release acceptance.

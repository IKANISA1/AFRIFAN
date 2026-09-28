# AFRICLUB — Investigation and implementation 03
## 28 September 2026

**Implemented and locally verified: payment-exception case review, operator API integration, typed client and guarded source delivery. Not deployed; not a complete platform release.**

## 1. What was investigated

The supplied AFRICLUB folder contains the football-club Flutter monorepo, its web/admin surfaces, older Supabase source, newer Cloudflare modules, and later remediation archives. The root README identifies five club apps: Vital'O, Rayon Sports, Nkana, AS Vita and Costa do Sol. This review inspected the root inventory, the September 28 delivery folder, its latest cumulative source/report, the interrupted exception continuation report, the Cloudflare/payment-allocation folder and current handoff migration, plus fresh root permissions.

The latest cumulative package was used rather than overwriting it with older root files. Its 301 selected source files were assembled from the archive's overlay and unchanged context. This is **not a fresh recursive export or full audit of every mobile screen, repository object, generated build, or hosted resource**. The existing 130-task register supplies the wider backlog; each acceptance requirement has been preserved rather than presumed revalidated.

Source identities, exact input hashes, scope and primary platform references are in `SOURCE_PROVENANCE.json`. The original Drive files were not replaced.

## 2. Gaps confirmed

| Finding | Evidence and consequence | This delivery |
|---|---|---|
| Exception continuation lacked captured implementation | Its report records zero captured source files and zero completed test runs; an older claimed result was not current verification. | Implemented a new case workflow and fresh tests. |
| Stale review could not be treated as resolved | The continuation report explicitly retained stale-revision review as outstanding. | SQL mutation-time expected revision checks and competing-review regressions now cover the new workflow. |
| Conflicting handoff migration histories | Current Drive has `0003_server_handoff_recovery.sql`; the later archive has a different `0003_payment_handoff_journal.sql`. | Preserved both as distinct evidence, isolated case tables, added duplicate/version/hash guard. No financial migration history was automatically rewritten. |
| Source and delivery states were mixed | Older reports say upload pending even though their archives are now in Drive. | Current manifest, report and separate upload receipt distinguish code, upload and release status. |
| Anyone-with-link editing remains enabled | Fresh root metadata shows `type:anyone`, `role:writer`, discovery false. | Reported as a P0 trust issue. No permission change or credential rotation performed. |
| Release acceptance is not demonstrated | Original 130-task backlog has no accepted/closed tasks. | All IDs and acceptance requirements retained; no artificial closure from local tests. |

The two handoff files have different names, schemas and SHA-256 values. They must not simply be renamed, combined or replayed into a deployed database. The new guard checks source files, not remote migration history. Restricted canonical source, a hosted history readback and a reviewed forward-only reconciliation remain release conditions.

## 3. Implemented code

**25 source/document paths changed: 21 added and 4 modified.** The package provides a 322-file scoped source candidate with 297 unchanged exact-hash prerequisites. `manifest.json` contains the exact changes. The installer and its delivery tests are included separately.

### Payment-exception case service

The new `cloudflare/payment-exceptions` module supports late, partial, duplicate, ambiguous, missing-reference, cancelled-order and refund-request cases. It supplies open, triage, propose, approve, reject, close and reopen commands; bounded case lists; paginated immutable history; and a typed TypeScript client.

Every command is club-scoped, carries an expected revision and original operation UUID, and records an immutable event. Mutation-time SQL triggers check active settings, environment, operator expiry, account/audience, tenant and role. Reviewers cannot review their own proposal even if assigned both roles. A stale approval cannot approve a newly replaced proposal. Rejection and reopening invalidate the previous review state.

An exact retry returns the original event outcome plus the latest case head, with their revisions kept separate. A conflicting payload using an existing key is rejected. Commit-response loss is recovered only through the original operation identity; neither the service nor the client invents a replacement payment or automatic retry. Concurrent database-connection tests verify that competing proposals/reviews cannot both update the same revision.

### Actual operator API integration

The existing gateway now routes four case endpoints through its established human Access identity boundary. It rejects body-supplied identity, wrong origins, unsupported queries, missing intent/idempotency headers, oversized JSON and extra body fields. Private-service errors stay redacted and responses are not cacheable. Existing publication endpoints retain their original intent header and pass their regression tests.

The gateway's private case binding and explicit case feature switch are included. Both the gateway and case worker templates remain disabled. The private worker exposes no public HTTP business API. Deployment validators reject unreviewed or missing case bindings and enabled template switches.

### Explicit non-financial boundary

**This service records case review, not financial settlement.** It has no payment-provider capability or financial database binding and does not confirm payments, allocate funds, execute refunds, alter membership or post rewards. The three dispositions are no financial change, referral to reconciliation, and referral to refund review. A closed case does not mean a refund was made or no money moved.

Only opaque references, controlled reason codes and optional evidence digests are accepted. Raw SMS, phone numbers and free-text narratives are excluded. References are explicitly `referencesVerified:false`: they are not validated against the financial database, and a digest alone is not evidence authenticity. These intentionally retained gaps must be closed by separately governed reconciliation work, not by pretending a review case is a ledger.

### Safe source handover

`install.py` checks migration lineage before invoking the reused hash-precondition installer. It defaults to a read-only dry run, refuses unknown edits and tampered payloads, takes backups before changing source, supports repeat/no-op installation, and supports exact rollback. Unknown rollback edits are preserved rather than overwritten. No script applies SQL, sends payments, provisions cloud resources or changes Drive permissions.

The root folder is not automatically assumed to contain this exact candidate. The installer requires the reviewed Remediation 02 prerequisites. Do not force installation on the older root snapshot, flatten file paths, or replace the entire repository with the scoped `source/` directory. Local file replacement is atomic per file, not a transaction across concurrent editors; stop other editors/build processes before applying.

## 4. Verification actually completed

| Completed group | Passing tests |
|---|---:|
| Combined Node backend, gateway, client, queue, handoff and source-boundary suites | 1,670 |
| Python source, import, release, security and migration-lineage suites | 168 |
| Installer safety and current-bundle apply/rollback scenarios | 39 |
| **Unique passing tests counted once** | **1,877** |

This includes **132 newly authored cases**: 114 Node, 12 Python lineage and six bundle scenarios. Every counted run completed successfully, with no failed/skipped/cancelled/todo cases in the Node result. Separate checks passed for 217 syntax/parse operations, strict TypeScript client compilation, disabled deployment configurations and a limited sensitive-source scan of all 322 scoped files. These additional checks are not added to the test total.

Tests use real local SQLite SQL/triggers; three use separate database connections in worker threads. The HTTP tests invoke the actual operator gateway with synthetic Access identity and local service bindings. The typed client is compiled before its integration tests. This is stronger than matching source strings, but **not a Cloudflare workerd/D1, real Access, browser, mobile or provider acceptance run**.

Current runtime: Node 22.16.0, Python 3.13.5 and TypeScript 5.8.3. The repository Node pin is 22.23.2, so the Node evidence is explicitly non-pinned. Dart/Flutter and full Next.js builds, Android/iOS acceptance, real providers, independent security/load tests, hosted migration checks and production restore/cutover were not executed. Older Kotlin/Swift and other historical totals are not counted as current passes.

The first combined installer run reached the tool time limit. It is not counted. Its complete replacement runs of 17, 16 and six tests are the evidence used above. Raw logs, machine results and source hashes are included.

## 5. Remaining tasks and priorities

The updated task register contains **130 tasks: 27 In progress, 103 Open, zero release-accepted or Closed**. Only WEB-06 changes from Open to In progress because of the new case-specific role controls; the broad task is not complete. The old register had inconsistent nested status totals; this version recomputes them from the actual task rows and preserves the prior values as history.

The main remaining priorities are:

1. Restrict link-based editing, review exposure/credentials, and converge on a protected canonical repository.
2. Reconcile both handoff migration histories against actual deployed databases; preserve single-writer and forward-only cutover controls.
3. Integrate and accept the new case screen in the admin application; configure real grants, Access policies and an isolated D1 database; test its live boundary before enabling anything.
4. Implement authoritative financial evidence verification, exception allocation/reconciliation, controlled refunds and corrections. Case review alone does not satisfy PAY-02 or PAY-03.
5. Complete native app composition, secure-storage and credentials, account recovery, browser sessions, device/carrier journeys, five-club/two-platform acceptance and production SDK-pinned tests.
6. Finish remaining product surfaces, data/media reconciliation, retention/erasure, monitoring/on-call, backup/restore, independent security and country/store/brand release approvals.

`TASK_REGISTER.json` preserves every task's dependency, priority, owner role and acceptance evidence. `REMAINING_TASKS.md` provides the full readable task list, not just the priorities above. Individual progress notes explicitly separate this delivery's contribution from unresolved wider acceptance.

## 6. Using the package

Start with `CODEX_HANDOFF.md`. Inspect `manifest.json`, `SOURCE_PROVENANCE.json`, the module README and verification logs. Use `install.py --root /path/to/reviewed/AFRICLUB` for a dry run; add `--apply` only for the exact known source state after review. The package never executes its SQL automatically.

`files/` contains only this delivery's changed paths. `source/` contains the scoped runnable test candidate. `before/` retains originals for modified paths. `reference_only/` contains the freshly read competing handoff migration, outside installable source. `evidence/` contains actual local results. The archive upload is verified separately; upload is not deployment or production approval.

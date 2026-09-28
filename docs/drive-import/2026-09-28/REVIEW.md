# AFRICLUB Google Drive import and comparison

> **Full-tree follow-up:** [FULL-TREE-REVIEW.md](FULL-TREE-REVIEW.md) now covers the previously excluded `.git`, generated build, dependency, and QA folders. The counts and coverage limits below describe the earlier source-and-delivery pass only.

**Review date:** 28 September 2026
**Drive folder:** [AFRICLUB](https://drive.google.com/drive/folders/1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH)
**Checkout:** `/Volumes/PRO-G40/Projects/Recovered-G-PRO/AFRICLUB`
**Git branch at intake:** `codex/add-cd-costa-do-sol`, commit `d1dd6916af807c4414dfd26c9475981eb23146b5`

## Result

The Drive folder contains an older repository mirror, dated implementation packages, conversation deliverables, source snapshots, and generated QA output. I recursively listed the source, documentation, conversation, recovery, and delivery areas described below. **7,098 Drive files** were enumerated. **6,233 relative paths already existed** in this checkout; their contents were not all downloaded or hashed. The other **865 files, 75,676,807 bytes**, were downloaded from their exact Drive IDs, checked against Drive metadata sizes, SHA-256 hashed, and copied without overwriting local files to [`mirror/`](mirror/). All 865 copies passed local SHA-256 readback. Every imported file, Drive ID, hash, category, and reason is in [`direct-files.tsv`](direct-files.tsv).

The latest numbered source package, Implementation 08, was also extracted byte-for-byte as a **416-file review candidate** in [`candidates/implementation-08-source/`](candidates/implementation-08-source/). This is a *scoped subset*, not a full monorepo export. Its per-file SHA-256 comparison and reason for preservation are in [`candidate-08-vs-checkout.tsv`](candidate-08-vs-checkout.tsv). No existing application, SQL migration, Cloudflare configuration, or other active source file was overwritten.

These 1,290 additions were committed locally as `345c9309` under `docs/drive-import/2026-09-28/`. They were not deployed or applied to a database.

## What was added and why

| File group | Direct files | Why it was retained |
| --- | ---: | --- |
| Historical conversation file snapshots | 378 | Preserve dated original names and variants for provenance and comparison. |
| Cloudflare service source | 201 | Keep payment, auth, operator, publication, and membership service files available for a guarded integration review. |
| QA and delivery evidence | 118 | Preserve reports and evidence without replacing generated local output. |
| Conversation deliverables | 52 | Retain source bundles, receipts, registers, and verification records. |
| Root deliverables and documents | 42 | Retain dated reports, plans, verification, and upload records. |
| Shared and native package source | 35 | Retain membership, iOS, Android, and package files for source comparison. |
| Tooling source | 20 | Retain validation, release, and security scripts. |
| Documentation and governance | 11 | Retain design, architecture, policy, and reporting variants. |
| Root implementation ZIPs | 6 | Preserve the complete numbered packages and their internal manifests. |
| App source | 2 | Retain the Drive-only publishing route and helper. |
| **Direct Drive files** | **865** | Exact bytes and individual reasons are recorded in `direct-files.tsv`. |
| **Extracted Implementation 08 candidate** | **416** | Make the latest scoped candidate reviewable without bypassing its baseline checks. |

The mirror deliberately retains duplicate-named historical copies. Among its 865 files, **356 paths repeat another imported file's SHA-256** across **270 duplicate groups**. [`duplicate-direct-files.tsv`](duplicate-direct-files.tsv) identifies them. A duplicate byte stream does not make a dated Drive path or delivery receipt interchangeable with another, so no historical path was discarded.

## ZIP and file-level analysis

**95 ZIP files** were among the missing direct files. Each opened successfully and passed Python `zipfile` CRC verification. Recursive inspection found **47 nested ZIPs** and **20,149 entries including nested contents**, with no unsafe traversal paths or ZIP symlink entries. The ZIPs with package checksum manifests supplied **7,280 checksummed entries in 31 archives**; all matched. This verifies the downloaded package bytes and internal checksums, not the truth of the packages' implementation, test, upload, or release claims.

[`archive-summary.tsv`](archive-summary.tsv) records every ZIP's Drive ID, SHA-256, byte size, entry count, and nested ZIP count. [`archive-entries.tsv`](archive-entries.tsv) records each of the 20,149 entries by archive path, nesting depth, internal path, byte size, SHA-256, role, and active checkout comparison wherever a repository path is unambiguous. It includes `source/`, `files/`, baseline, evidence, and expanded-package content, including nested packages. A basic scan of downloaded plain text and bounded text-like ZIP entries found no private-key block, long API-key assignment, or JWT pattern; this is a limited pattern check.

### Numbered implementation lineage

| Package | Scoped `source/` files | New / modified manifest paths | Main declared scope |
| --- | ---: | ---: | --- |
| Implementation 03 | 322 | 21 / 4 | Delta from remediation 02; source-only. |
| Implementation 04 | 342 | 20 / 26 | Delta from 03. |
| Implementation 05 | 362 | 20 / 5 | Browser sessions and member API. |
| Implementation 06 | 384 | 18 / 14 | Browser membership and private cache isolation. |
| Implementation 07 | 394 | 10 / 25 | Read-only allocation history and receiving safety. |
| Implementation 08 | 416 | 22 / 3 | Private allocation-event delivery and operational inbox. |

Each numbered package's `manifest.json` describes a delta against the **exact preceding scoped candidate**. The archive itself says `source/` is not a complete repository. The conversation folders also contain production-readiness reports; production-remediation source, baseline, and evidence bundles; remediation continuation 02; payment-exception continuation; and earlier Batch 10–12/native recovery packages. Their source, before-state, evidence, and reference files have different roles. The individual archives and reports are all retained under their original Drive paths in `mirror/`.

Across all ZIPs, **5,046 entries** map unambiguously to candidate repository paths, covering **438 unique paths**. **94 paths have more than one SHA-256 version** across the archives; [`candidate-path-conflicts.tsv`](candidate-path-conflicts.tsv) lists every version and source archive. This is why selecting one file by name or mixing every ZIP's `files/` directory would not produce a coherent implementation.

## Checkout comparison and integration decision

The working checkout had **1,375 pre-existing Git status entries** at intake. Its Cloudflare area included untracked local work. Against the latest Implementation 08 `source/` candidate, **14 files are byte-identical, 26 existing files differ, and 376 candidate paths are absent**. The 26 divergent paths include CI, Next.js configuration, membership UI, Cloudflare public worker, router, governance, and validation scripts. The latest package requires the exact Implementation 07 scoped baseline and a guarded install. The active checkout is not that baseline.

The direct Drive mirror and the latest candidate differ as well: of 269 Drive-only source-area paths, 210 occur in the 08 candidate; 147 match it byte-for-byte, 63 differ, and 59 are outside it. Those 59 include older or separate handoff, supporter-auth, publishing, and governance variants. Importing them as live code merely because their paths are missing would combine incompatible stages. They are preserved in `mirror/` and visible in the per-file analysis.

Accordingly, this import **adds all 865 missing paths from the enumerated Drive scope to the local repository as versioned source material**, plus an extracted latest candidate for review. It does not claim a functioning merge of those packages into the app. The exact guarded baseline, the 94 archive version conflicts, and the 26 active-file differences need reconciliation before any of the candidate code is promoted into live paths. No release or financial migration was inferred from package reports.

## Coverage limits

[`drive-path-inventory.tsv`](drive-path-inventory.tsv) lists every enumerated Drive path and whether it was imported or merely found locally. The recursive listing visited **1,712 folders**. It intentionally did not descend into **60 generated or repository-internal folders** named `.git`, `build`, `.dart_tool`, `.gradle`, `Pods`, `.wrangler`, `.xcodebuildmcp`, `.idea`, `node_modules`, or `.next`, nor into **492 descendants** of the large `output/qa/full-stack-20260914` tree. That QA folder's direct list reached Drive's 1,000-item page limit, so even its direct child inventory is incomplete. The corresponding local QA tree alone contains more than 47,000 files and occupies about 36 GB. [`inventory-coverage.json`](inventory-coverage.json) records every skipped folder and the truncated list.

Therefore, **7,098 is an enumerated-scope count, not the total file count of the entire Drive folder**. The 6,233 paths already present were compared by relative path only, not asserted byte-identical. The import does not establish whole-repository parity or completeness for the excluded generated trees. It does, however, fully materialize and hash-verify every missing file found in the enumerated source and delivery scope, including Drive-only generated or ignored code in the folders that were inspected.

## Verification performed here

- 865 direct downloads: size matched Drive metadata; local mirror readback SHA-256 matched each staged source.
- 416 extracted candidate files: local readback SHA-256 matched their ZIP entries.
- 95 outer ZIPs and 47 nested ZIPs: readable, CRC checked, no traversal paths or symlink entries.
- 31 package checksum manifests: 7,280 entries verified, zero mismatches.
- Active checkout files were preserved; the import occupies its own `docs/drive-import/2026-09-28/` directory.

These are source and package-integrity checks. They do not execute the packaged tests, prove provider or deployed behaviour, or authorize production use.

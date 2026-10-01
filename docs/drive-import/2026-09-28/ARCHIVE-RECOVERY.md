# Dated Drive archive recovery

The 2026-10-01 AR-13 consolidation removed 132 identical regular copies from this
dated archive, totaling **17,406,955 logical bytes**. It retained 2,144 original
files and all 1,765 distinct SHA-256 contents in the 2,276-file pre-cleanup tracked
inventory. Git history and the original intake manifests were preserved.

[`archive-recovery-index.json`](archive-recovery-index.json) is the single recovery
index. Its `inventory` gives every original path, retained `canonical_path`, byte
length, SHA-256 and original Git blob. Removed occurrences also carry their Drive
retrieval IDs and manifest hashes where the intake supplied them. The exact 132
removed paths are in `removed_regular_paths`; an alias always points directly to
an existing canonical file with the same bytes. No alternate archive tree or
symlink layer was introduced.

From the repository root, verify the frozen index and all retained bytes:

```sh
python3 docs/drive-import/2026-09-28/archive_recovery.py --verify
```

Resolve an original intake path to its retained, hash-checked copy:

```sh
python3 docs/drive-import/2026-09-28/archive_recovery.py --resolve 'mirror/Conversation_Files_2026-09-28/AFRICLUB_Production_Remediation_Source_2026-09-28.zip'
```

For example, that 3,146,553-byte occurrence now resolves to
[`mirror/output/production-remediation-2026-09-28/AFRICLUB_Production_Remediation_Source_2026-09-28.zip`](mirror/output/production-remediation-2026-09-28/AFRICLUB_Production_Remediation_Source_2026-09-28.zip),
SHA-256 `3fb8c5e47767582234c46bb80423894ec18da62daf52e4208d9a0ebde5e13e41`.
Both numbered cumulative-v4 snapshots resolve to the retained
[`mirror/output/refactor-2026-09-26/batch4-supporter-auth/AFRICLUB_Cumulative_Source_Patch_v4_2026-09-26.zip`](mirror/output/refactor-2026-09-26/batch4-supporter-auth/AFRICLUB_Cumulative_Source_Patch_v4_2026-09-26.zip),
609,779 bytes, SHA-256
`e660191cad670983811c83f668f54edc849e3aed6b5e8de862b56b3fcb6249fe`.

The helper verifies every retained canonical byte length/hash, every original
alias, all 29 frozen top-level intake files, 47 retained ZIP containers including
member CRCs, and the seven pre-existing historical revisions described below.
With an existing index, its default command also verifies; it does not create a
new plan. `--resume` completes only an interrupted saved plan, rechecking the same
index, current consumers and both copies before any removal. `--apply` refuses to
replace an existing index. Tests run with:

```sh
python3 -m unittest discover -s docs/drive-import/2026-09-28 -p test_archive_recovery.py
```

## Records retained for their paths or provenance

The exact **246 remaining duplicate groups**, containing 2,609,426 redundant
logical bytes, are recorded in `blocked_groups`. Each entry gives retained paths,
SHA-256, bytes per copy, the specific protection reason and any identified
consumer paths. These copies remain because they form coherent candidate/source
or Git recovery trees; contain structured metadata; preserve historical
documentation, licenses, grants, approvals, receipts, manifests, tests or signing
records; or have an actual documentation/module consumer. Every unique revision
was retained. The implementation-08 candidate, source trees, variants and
`git-metadata` tree remain intact.

The deletion boundary included only hash-identical payloads in flat conversation
snapshots or mirrored output. It excluded historical Markdown, generated
localizations, applied migrations, tests/goldens, source grants, approval/license
records, signing material and Git metadata. The removed extensions were ZIP
(48), JavaScript (64), Python (6), TypeScript (4), PDF (3), XLSX (3), MJS (3) and
CSS (1). These counts describe archived copies, not active product files.

## Original retrieval records and earlier revisions

[`REVIEW.md`](REVIEW.md), [`FULL-TREE-REVIEW.md`](FULL-TREE-REVIEW.md), the original
TSV/JSON inventories, and their original hashes/Drive IDs remain unchanged. A
historical manifest can therefore still name a removed occurrence: use its
original path with `--resolve` or the index's `inventory` to obtain the identical
retained bytes. Historical inventory rows are retrieval records, not a current
filesystem listing.

Before this cleanup, seven intake revisions had already been removed or changed
by the repository's exclusive design-authority work. Their exact original bytes
were independently verified in existing import commit
`345c930934a683d4605524e3b2081862716c5fde`. They are listed under
`preexisting_intake_revision_recovery` with the original path, intake SHA-256,
Drive ID where supplied, state before consolidation, retained Git commit and
original byte length. Recover a required historical record using:

```sh
git show '345c930934a683d4605524e3b2081862716c5fde:docs/drive-import/2026-09-28/ORIGINAL_PATH'
```

This records recoverability without restoring retired competing design rules.
All seven revisions remain in existing Git history; this cleanup did not remove
or amend them.

## Verification scope

After removal, an independent check matched the 132 deleted filesystem paths to
the Git diff, rehashed each retained counterpart, checked all 29 frozen intake
files and recalculated the 246 remaining groups. The helper also scanned tracked
and nonignored untracked UTF-8 source/documentation files up to 8 MiB for literal
archive paths and resolved Markdown/module references before deletion. Every
identified actual consumer keeps its original required path. No active
web/native/SQL source was changed by this cleanup.

This is a bounded local archival result. Binary/large-file embedded links,
dynamically constructed paths, remote Drive access/ACLs and retention acceptance
were not verified. No Git history was rewritten or garbage-collected, so removed
working-tree bytes are not a claim of equivalent Git-object or physical disk
reclamation. Local archival recovery does not establish production release or
external approval.

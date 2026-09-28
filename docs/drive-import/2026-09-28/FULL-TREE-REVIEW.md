# AFRICLUB Drive full-tree review

**Drive folder:** [AFRICLUB](https://drive.google.com/drive/folders/1izZgoOKfEONHZTyHkE0MzBW9Eeo4-VeH)

**Review date:** 28 September 2026

**Local checkout:** `/Volumes/PRO-G40/Projects/Recovered-G-PRO/AFRICLUB`

This report extends the earlier [source and delivery import](REVIEW.md) to every reachable folder, including `.git`, `.dart_tool`, `build`, `node_modules`, and the large QA output tree. It records an individual Drive ID for every file occurrence. The full inventory found **67,157 folders, 260,835 unique relative file paths, and 30 additional file IDs hidden by duplicate names**: **260,865 file occurrences** in total. All folder listings completed without an error. The 7,098 file IDs in the earlier connector inventory matched this full pass exactly. Twenty sampled folders from `.git`, QA, app builds, dependencies, and packages also matched the connector's direct child IDs and counts exactly.

The full pass used the public view of the shared Drive folder to enumerate large directories, including one QA log folder with more than 2,000 direct children. The Google Drive connector supplied metadata and raw downloads for material retained from Drive. The complete [folder inventory](full-tree-folder-inventory.tsv.gz), [file-level analysis](full-tree-file-analysis.tsv.gz), and [duplicate-name register](full-tree-duplicate-names.tsv) make the coverage reviewable. [Coverage totals](full-tree-coverage.json) are machine-readable.

## What was added to the local repository

Every copied Drive file is individually identified by Drive path, ID, local destination, byte count, SHA-256, and reason in [full-tree-additions.tsv](full-tree-additions.tsv). **1,836 Drive file copies or variants** were added without replacing active checkout files. All local copies passed size and SHA-256 readback against that manifest.

| Group | Files | Why it was added |
| --- | ---: | --- |
| Earlier missing source, document, delivery, and archive files | 865 | Their relative paths were absent from the checkout. Exact raw files were retained under `mirror/`, including 95 numbered and historical ZIP packages. [Per-file reasons](direct-files.tsv). |
| Drive loose Git objects | 947 | Their loose-object paths were absent because the corresponding logical objects are available in the local Git object database. Their exact Drive compressed bytes were retained under `git-metadata/objects/loose/` for provenance, outside the active `.git` directory. Every retained object decompresses to the SHA-1 ID in its path. [Object manifest](git-metadata/loose-objects.tsv). |
| Old Git pack index sidecars | 2 | The Drive `.idx` and `.rev` files for `pack-633e7e3c...` have no same-path local copy. They were retained under `git-metadata/objects/pack/`. Drive contains no corresponding `.pack`, so these sidecars were not installed into the active Git store. |
| Differing Git metadata | 16 | The Drive versions of refs, reflogs, index, HEAD, and related metadata differ from this live checkout. They were retained under `variants/git-internal/` without changing Git state. |
| Differing `.gitignore` | 1 | The checkout adds `/.wrangler/` to the 2,113-byte Drive version. The Drive variant is under `variants/root-.gitignore`; the active ignore rule was preserved. |
| Differing generated tooling files | 5 | Four Drive files have different sizes: two lock records reflect different process/time information, one dependency record differs in one environment hash, and one command log reflects a different toolchain run. A fifth, same-size `output.json`, differs only in its timestamp field. All five Drive versions were retained under `variants/generated/` without replacing current generated output. |

The earlier review also extracted **416 files** from Implementation 08 to [a separate candidate directory](candidates/implementation-08-source/) for baseline-aware integration review. Those 416 extracted files are derived from a ZIP already counted among the 865 direct Drive files, so they are not counted again as distinct Drive files here. The package's per-file comparison is in [candidate-08-vs-checkout.tsv](candidate-08-vs-checkout.tsv).

All 30 duplicate-name Drive IDs were preserved in the file inventory. Their fetched bytes match the same-name local files, so no redundant copy was added for them.

## File-by-file analysis

The [file-level register](full-tree-file-analysis.tsv.gz) has one row for each of the 260,865 Drive occurrences. It records role, local basis, byte size, SHA-256 for each available local file, format result, and Drive comparison status. The format checks read **160,250 UTF-8 text files**, parsed **16,154 strict JSON files**, decoded **38,224 images**, and read **40,445 other binary files**. Another **3,045 extensionless or `.lock` files** contain readable binary data rather than UTF-8 text. **108 configuration files** use JSON with comments or related nonstandard syntax, so strict JSON parsing is not a valid test for them.

| File role | Unique Drive paths | Review basis |
| --- | ---: | --- |
| Project source and documentation | 4,549 | Individual local format/hash analysis and Drive byte comparison. |
| Dated delivery packages | 430 | Individual local format/hash analysis and Drive byte comparison; archive entries reviewed where applicable. |
| Recovery evidence | 640 | Individual local format/hash analysis and Drive byte comparison. |
| Other output evidence | 342 | Individual local format/hash analysis and Drive byte comparison. |
| Git internals | 1,010 | Same-path byte comparison or validated, separately preserved Drive object/sidecar. |
| Generated build output | 145,649 | Individual local format/hash analysis and Drive size comparison. |
| Installed dependencies | 65,861 | Individual local format/hash analysis and Drive size comparison. |
| QA output | 41,724 | Individual local format/hash analysis and Drive size comparison. |
| Generated tooling | 630 | Individual local format/hash analysis and Drive size comparison. |

A second [type-specific register](full-tree-structured-code-analysis.tsv.gz) checked **25,638** files that the first pass had only read as generic binary or unclassified content. All **13,621 source maps parsed as JSON**, **3,177 plist/privacy/entitlement files parsed**, **2,653 SVG/interface/workspace files parsed as XML**, and **6,187 class, DEX, Android resource, or QCOW2 files had the expected binary signature**. This is structural validation of the local counterparts; the separate Drive comparison statuses show which bytes were actually compared with Drive.

The following QA artifacts need attention:

The [zero-byte register](full-tree-zero-byte-files.tsv) lists all **627** empty local counterparts individually. Most are generated/build/dependency placeholders or empty text files. The two PNGs below are the empty files that affect visual evidence.

| Finding | Evidence |
| --- | --- |
| Two PNG evidence files are empty. | `output/qa/full-stack-20260914/consolidated-browser-v8-20260920/admin-squad-state-evidence-6c5a8-nticated-squad-state-matrix-mobile-webkit/capture-attempt-XLe7IB/admin_squad_state_focused_dark_desktop_1440x1000.png` and `output/qa/full-stack-20260914/goal-update-playwright-baseline-results/recovery-state-evidence--o-ba4cd--applicable-recovery-states-mobile-chromium/capture-attempt-TaekaP/offline_state_large_text_dark_viewport.png`. Both are zero bytes locally and in Drive metadata, so they do not prove the intended screenshots. |
| Two `.json` QA files fail strict JSON parsing. | `output/qa/full-stack-20260914/goal-update-hosted-ci-runs-current.json` contains extra data after a JSON value; `output/qa/full-stack-20260914/ios-toolchain-20260923/flutter-version.json` contains curl progress text rather than JSON. They were preserved as evidence, not repaired in place. |

All **45 CSV**, **16 PDF**, and **5 XLSX** files opened for type-specific analysis. [The structured-document register](structured-document-analysis.tsv) records CSV dimensions, PDF page/text counts, and workbook sheets, dimensions, and formula counts.
The four local SQLite files also passed read-only `PRAGMA integrity_check`; each is an empty Miniflare metadata database. Their [individual results](full-tree-sqlite-analysis.tsv) are recorded separately.

### Archive contents

The full tree contains **1,887 readable archive containers**: **1,686 ZIP-compatible files** (including ZIP, JAR, APK, AAR, and XLSX) and **201 TAR containers** (177 `.tar.xz` and 24 `.tar.gz`). [Archive summary](full-tree-archive-analysis.tsv.gz) and [171,210 individual archive entries](full-tree-archive-entries.tsv.gz) record every examined entry. This includes **130 nested ZIP containers**. Every entry read and ZIP CRC check completed without error; the scan found **zero unsafe traversal paths, zero ZIP/TAR symlink entries, and zero nested archives skipped for depth or size**. One additional standalone `.gz` stream passed decompression and CRC checks, and **16 `.gz` members inside JAR/APK files** also decompressed with valid CRCs; their hashes are in the [standalone](full-tree-compressed-stream-analysis.tsv) and [nested](full-tree-nested-gzip-analysis.tsv) registers. All **32 `NOTICES.Z` files** are gzip streams despite their extension; each [decompressed and passed CRC validation](full-tree-notices-z-analysis.tsv). All 95 ZIPs in the earlier import are included in this full archive pass. The earlier [package checksum analysis](REVIEW.md#zip-and-file-level-analysis) separately verified 7,280 manifest checksums across 31 package archives.

## Drive-to-checkout comparison

Of the **260,835 unique Drive paths**, **259,021** exist at the same relative path in the checkout, **865** are in the previously imported mirror, and **949** `.git` storage paths were absent at the same path and have now been preserved outside the live Git directory. The 30 extra duplicate-name IDs match local bytes.

Every **5,961 substantive project source, documentation, dated delivery, recovery, and non-QA output files** was fetched from Drive and SHA-256 compared with its checkout or mirror counterpart. **5,960 were byte-identical; `.gitignore` was the one differing file.** Of the 61 Git-internal files with same-path local copies, 45 matched and 16 differed; the Drive variants are retained. The 947 loose Git objects passed object-ID validation and remain available logically through local Git as well.

Another **38 generated files** were fetched as initial spot checks and matched the local bytes. They include the two empty PNGs and two malformed JSON QA artifacts described above. An expanded raw byte pass then downloaded and SHA-256 compared **862 generated files**: **857 matched** and **five `.dart_tool` files differed**. The five Drive versions are retained as variants.

Every generated file was inventoried and had its local content hashed and format checked. A separate [per-file Drive size comparison](full-tree-generated-size-comparison.tsv.gz) completed for all **253,864** QA, build, dependency, and tooling files: **253,860 matched in size** and **four differed**. Size was obtained either from the Drive download response or the corresponding Drive folder metadata; both routes use the same Drive file ID. The expanded byte pass found a fifth difference with an equal size. Its [per-file byte-comparison register](full-tree-generated-byte-comparison.tsv.gz) records completed, failed, and pending raw comparisons.

Google Drive then returned **“Quota exceeded”** HTML for public downloads across multiple file IDs. The byte pass stopped after 862 successful comparisons and 1,174 download failures during the quota period; the remaining generated files have not been downloaded for content hashing. The authenticated Drive connector still fetches individual files, and it was used to preserve the fifth variant, but a complete local Drive export or renewed download access is needed to finish byte parity for the entire generated tree. Matching size and successful local format checks do not prove byte identity. [Coverage totals](full-tree-coverage.json) give the exact count in each state.

## Integration decision

The Drive packages contain multiple incompatible staged source versions. [Candidate conflicts](candidate-path-conflicts.tsv) and the [earlier review](REVIEW.md#checkout-comparison-and-integration-decision) show 94 source paths with multiple archive versions, 26 divergent active files against Implementation 08, and a required exact preceding package baseline. The Drive-only source was retained as review material; this pass did not install incompatible versions into active app, SQL, or Cloudflare paths. No deployment, store release, database migration, or production acceptance is inferred from these files.

The [Implementation 08 report](mirror/AFRICLUB_Implementation_08_Report_2026-09-28.md) describes a 416-file scoped candidate with 22 added and three modified paths, two additive migrations, and local test results. It explicitly says the migrations were not applied and the package was not deployed. The accompanying [remaining-tasks register](mirror/AFRICLUB_All_Remaining_Tasks_08_2026-09-28.md) still lists hosted D1/Workers verification, multi-club acceptance, operational recovery, and release controls as open. These are source-document claims, not tests rerun against the active checkout in this review.

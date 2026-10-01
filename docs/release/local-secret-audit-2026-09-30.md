# Repeatable local source, history and archive secret audit

`tools/scripts/local_secret_audit.py` performs a read-only inventory and content
scan. Its report contains paths, categories, object identifiers, byte counts and
SHA-256 hashes. It does not include matched values, excerpts, request bodies or
exception details. Known credential-shaped filenames are redacted too.

## Scope and interpretation

- Source includes every tracked and untracked nonignored Git path. Retained
  `docs/drive-import` and `.recovery` material is scanned and labeled separately;
  its namespace does not exempt a credential.
- History includes every reachable blob under all available local Git refs.
  Representative `rev-list` names are recorded; this is not a complete mapping
  of every filename in every commit. Dangling objects, reflog-only objects and
  unavailable remote refs are outside this scope.
- Explicit sealed archives require the expected SHA-256. ZIP, TAR and gzip
  contents recurse without extracting files. Member edges and source/history
  occurrences retain provenance when identical content is scanned once.
- Binary embedded UTF-8/ASCII and UTF-16 text is scanned. Private-key material,
  privileged JWTs, recognizable provider credentials and secret assignments
  require review. Public anonymous JWTs and Google client-key configurations are
  separate classifications; classification does not prove provider restrictions.
- A test filename or `testOnly` JWT claim never exempts a credential. Parser
  markers and source that generates synthetic test values are distinguished
  from actual embedded material. Findings in historical evidence stay findings.
- An optional reviewed-content policy can classify only a generic assignment,
  by exact whole-file SHA-256, as a reviewed synthetic placeholder. The finding
  remains in the report with its evidence reference and `blocksAcceptance: false`.
  Any changed byte requires review again. Private keys, privileged JWTs,
  service-account private keys and recognizable credentials always block.
- Unsupported, encrypted, corrupt, duplicate, traversing or linked archive
  members, oversized inputs, exhausted budgets, missing blobs and concurrent
  source/ref changes prevent a complete coverage result. A finding prevents a
  passing result even when coverage is complete.

This pattern scan cannot establish credential validity, source authenticity,
Google Drive permissions, deployment acceptance, rotation or production safety.
It does not decrypt arbitrary encrypted or obfuscated data or perform OCR.

## Local commands

Run the adversarial and actual temporary-Git tests:

```sh
python3 -m unittest discover -s tools/scripts -p 'test_local_secret_audit.py'
```

Run against the repository and all reachable local Git history:

```sh
python3 tools/scripts/local_secret_audit.py \
  --root . --progress \
  --review-policy docs/release/local-secret-audit-review-policy-2026-09-30.json \
  --report output/qa/full-stack-20260914/production-goal-20260929/local-secret-audit-final-20260930.json \
  --max-member-bytes 268435456 --max-expanded-bytes 4294967296 \
  --max-total-bytes 8589934592 --max-seconds 600
```

For a current sealed candidate, append `--sealed PATH SHA256` using the verified
hash in that candidate's artifact report. Freeze source and refs before the full
scan and keep them unchanged until the scanner writes its result. Exit 0 means
complete declared coverage with no blocking findings; exit 1 means blocking
findings or incomplete coverage; exit 2 means invalid arguments or an unavailable
audit/report. The report's `coverageComplete` and `passed` fields are distinct.
Count-only progress checkpoints contain no source names or values.

Reports inside the repository must use an ignored output location and cannot
overwrite tracked source, the scanner, Git metadata or a supplied candidate.
Reports are written atomically. Input/member/total-byte, entry-count, depth and
elapsed-time limits are positive and capped. Time is checked between bounded
read/scan operations; it is not an operating-system deadline for filesystem I/O.

The initial actual scan was stopped before completion because the inherited
matching strategy incurred excessive CPU on large historical evidence. Its
failed control record is preserved. The optimized strategy uses bounded lexical
JWT parsing, targeted secret-assignment candidates and indicated UTF-16 views;
the adversarial checks include repeated JWT prefixes and oversized encodings.
TAR detection checks the numeric checksum, byte sum and parseable header fields;
an embedded JavaScript `ustar` marker at offset 257 is scanned as source text.

The accompanying JSON evidence report records the actual executed snapshot,
source/test hashes, coverage counts, findings, coverage gaps and local limits.
Source changes after that snapshot require a new scan. Keep original evidence;
do not delete credentials, rewrite Git history or rotate keys as part of scanning.

## Reviewed synthetic assignments

`local-secret-audit-review-policy-2026-09-30.json` records eight exact content
hashes and a reason for each: three active schema/test files, two older retained
schema-check versions, and three archived source patches. The active files are
`cloudflare/auth-code-delivery/scripts/check-deployment.mjs` (line 20),
`scripts/check-receipts-deployment.mjs` (line 50), and `tests/fixture.mjs` (line 19).
Their matches are fixed WA inputs for local configuration validation or mocked
tests. Each older version was reviewed separately; each patch match was checked
against the reviewed synthetic values in those source files. Neither source
locations nor filenames create a general exemption.

The targeted three-file check is recorded in
`output/qa/full-stack-20260914/production-goal-20260929/local-secret-audit-active-reviewed-20260930.json`.
It completed with three retained generic-assignment classifications, zero
blocking findings and no coverage gaps. This result covers only those three
files. The scanner's adversarial and temporary-Git suite passed 47 tests in
`local-secret-audit-tests-finish-20260930.log` in the same output directory.

## Historical findings and rejected old build

The earlier resumed scan reported reachable historical material in
Supabase start-secret blobs, a Play Store service-account file, `1supabase.md`,
and `keystore.properties`. Those findings remain blocking; no validity check,
rotation, history rewrite or deletion was performed. Archived inventory TSV
contents with recognizable credential-shaped strings also remain blocking.
The report retains hashes and provenance without matched values.

The old local build
`output/qa/full-stack-20260914/production-goal-20260930-phase4/local-opennext-9f2a658c-1790774375474.zip`,
SHA-256 `77e460ea4d21fcca11d9735d082a56dafa5dbd0cadaadeb4ec2045af7510eaa5`,
contains a privileged backend JWT and a generic secret assignment in
`.open-next/cloudflare/next-env.mjs`. It is rejected and preserved as restricted
local evidence. Its audit is
`output/qa/full-stack-20260914/production-goal-20260929/local-secret-audit-rejected-archive-20260930.json`.
Its contents cannot serve as an accepted candidate. A later isolated build
requires its own verified archive hash and scan.

The first resumed full pass has `coverageComplete: false`: 58 source metadata
changes, one source-inventory change and one TAR false-detection gap were
recorded. Its failure report remains preserved. Only a new frozen full pass can
establish current source/history/candidate coverage.

## Current source and reachable Git checkpoint

The later current checkpoint is recorded in
`docs/release/local-secret-audit-current-checkpoint-2026-09-30.json`, with the
complete scanner output and count-only log under
`output/qa/full-stack-20260914/production-goal-20260930-phase4/secret-current-checkpoint-20260930/`.
The actual process exited 1 after scanning 6,170 source locations, all 20,834
reachable local Git blobs, 21,723 unique contents and 10,124 archive member edges.
No new sealed candidate was included.

There were zero blocking `active_source` locations. Thirteen blocking content
category rows across ten unique contents, plus the historical signing-file path,
remain finite findings. Five of those contents occur inside retained compressed
inventory evidence: three current containers and two older reachable variants.
The eight exact reviewed synthetic contents remain visible classifications;
they create no exemption for private keys, privileged JWTs or recognizable
credentials.

Coverage is incomplete because `core_app` app and routing-test source and the
local route-state assertion fixture changed during scanning. A separate targeted
recheck of only those three paths passed with no findings or gaps. It does not
replace the frozen full source/history/candidate audit. Acceptance remains false.

For the next exact sealed candidate, the full command adds its verified path and
SHA-256 and permits a bounded 256 MiB archive input. Set the three task-specific
variables to the actual supplied path, verified hash and new ignored report path:

```sh
python3 tools/scripts/local_secret_audit.py --root . --progress \
  --review-policy docs/release/local-secret-audit-review-policy-2026-09-30.json \
  --sealed "$AFRICLUB_AUDIT_ARCHIVE" "$AFRICLUB_AUDIT_ARCHIVE_SHA256" \
  --report "$AFRICLUB_AUDIT_REPORT" \
  --max-blob-bytes 268435456 --max-member-bytes 268435456 \
  --max-expanded-bytes 4294967296 --max-total-bytes 8589934592 \
  --max-seconds 600
```

Running this while source changes continue creates another diagnostic checkpoint.
Final acceptance requires the frozen current source, reachable Git and final
candidate result. Preserve the rejected old archive and all prior failure proof.

## Diagnostic web-only bundle privacy checkpoint

`docs/release/local-diagnostic-web-bundle-privacy-2026-09-30.json` binds build
`tsdiZFDh6EmtM85O7Vzgn` to a separately sealed diagnostic ZIP, SHA-256
`d03340c672d32d48e71c918d8650ab357e72331311cf6464a416c1ddb17191ee`.
The exclusive output directory is
`output/qa/full-stack-20260914/production-goal-20260930-phase4/diagnostic-web-bundle-privacy/tsdiZFDh6EmtM85O7Vzgn-20260930T204216000200Z/`.

All 2,557 regular `.open-next` files were included, together with the exact Next
provenance and isolated-build records under a separate evidence prefix and an
embedded manifest: 2,560 archive members. There were no links, special files or
excluded regular output files. Source hashes were rechecked after sealing;
every archive member and exclusive extracted readback matched its manifest
hash. The archive remained mode `0600` with its exact hash after scanning.

The actual source/reachable-Git/diagnostic-archive scan exited 1. All 2,560
diagnostic member hashes matched the independent sealing/readback receipt; the
archive had zero content findings, path findings or coverage gaps. The complete
checkpoint retained the same thirteen historical content-category findings and
signing-file path. Seven concurrent test-source changes prevented complete
whole-source coverage. This diagnostic bundle is not the final all-source
candidate; `diagnosticOnly: true`, `finalCandidate: false` and acceptance false
remain explicit in its evidence report.

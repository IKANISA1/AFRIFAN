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

Run against the repository and the hash-bound phase 3 local candidate:

```sh
python3 tools/scripts/local_secret_audit.py \
  --root . --progress \
  --report output/qa/full-stack-20260914/production-goal-20260929/local-secret-audit-full-optimized-20260930.json \
  --sealed output/qa/full-stack-20260914/production-goal-20260930-phase4/local-opennext-9f2a658c-1790774375474.zip \
  77e460ea4d21fcca11d9735d082a56dafa5dbd0cadaadeb4ec2045af7510eaa5 \
  --max-member-bytes 268435456 --max-expanded-bytes 4294967296 \
  --max-total-bytes 8589934592 --max-seconds 600
```

Choose the archive and its verified hash from the current candidate's artifact
report for later runs. Exit 0 means complete declared coverage with no findings;
exit 1 means findings or incomplete coverage; exit 2 means invalid arguments or
an unavailable audit/report. The report's `coverageComplete` and `passed` fields
are distinct. Count-only progress checkpoints contain no source names or values.

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

The accompanying JSON evidence report records the actual executed snapshot,
source/test hashes, coverage counts, findings, coverage gaps and local limits.
Source changes after that snapshot require a new scan. Keep original evidence;
do not delete credentials, rewrite Git history or rotate keys as part of scanning.

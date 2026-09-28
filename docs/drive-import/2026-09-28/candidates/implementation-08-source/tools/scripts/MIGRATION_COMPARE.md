# Normalized migration snapshot comparison

`migration_compare.py` is a read-only comparison tool, not an exporter, live database
probe, financial provider verifier or migration runner. Its intended use is comparison
of two independently extracted, explicitly normalized snapshots at the same agreed
cutoff and grain. Local unit tests use synthetic rows only.

## Input contract

Each JSON snapshot has exactly `schemaVersion:1`, `dataset`, `normalizationVersion`,
`cutoff`, `scopeSha256`, `completeDeclared`, `expectedRows`, `fields`, `keyFields`,
`money` and `rows`. Dataset/version are lower-case identifiers. `scopeSha256` binds an
independently maintained coverage manifest; it does not prove that coverage is complete.
The UTC cutoff uses `YYYY-MM-DDTHH:MM:SS[.sss]Z`. Ingestion is capped at 32 MiB and
100,000 rows per supplied snapshot. Larger datasets need a separately reviewed
streaming/partition strategy; do not bypass the bound or infer global uniqueness from
independent partition passes.

`fields` maps field names to `{type, nullable}` with type `string`, `integer`, `boolean`,
`timestamp`, `json` or `decimal`. Decimal fields additionally require `scale` (0–12).
Integer and decimal values are canonical **strings**, never JSON floating-point numbers.
Decimals must have exactly the declared fractional digits; no rounding, exponent notation,
leading zeros or negative zero is silently accepted. JSON fields reject floating-point
numbers and cap nesting. Every row must have exactly the declared fields.

`keyFields` defines the complete non-null primary/composite key at the chosen grain.
For global consumed-payment-reference comparisons, preserve the actual provider/reference
namespace across clubs: including a club in a supposedly global key could conceal reuse.
The tool does not decide which source namespace is authoritative.

`money` is an array of `{field,currencyField}` for non-null integer/decimal amounts and
three-letter uppercase currency values. Comparison uses exact integer arithmetic at the
explicit scale; it does not select country rules, convert currencies or approve negative
amounts. Field definitions, key definition, money definition, dataset/version, cutoff and
coverage digest must match before row comparisons are meaningful.

## Run

```sh
python3 tools/scripts/migration_compare.py --source /private/source-normalized.json \
  --target /private/target-normalized.json --output /private/new-comparison.json
```

The output must not already exist and cannot overwrite either input. It is created with
owner-only mode. Outputs provide normalized-input hashes and counts of duplicate keys,
missing/extra/changed/matching rows and unequal monetary groups. Record identifiers,
values, totals and filesystem paths are not emitted. Input/export files remain private;
keep the hash-bound report under appropriate access controls too.

Exit **0** means matching supplied snapshots with internally consistent completeness
**declarations**; it is never release authorization. Exit **1** means drift/invalid input
or unsafe output. Exit **2** means incompatible context or unproven completeness.
Every report says `coverageVerified:false`, `releaseAuthorized:false`, `databaseWrites:0`.
Matching subsets cannot prove full extraction, consistency of the original export,
external payment authenticity, cross-table foreign keys or live cutover parity. Those
checks remain DAT-04/DAT-05/DAT-06/DAT-09/DAT-10/PAY-10 acceptance work.

The executable synthetic contract is in `test_migration_compare.py`.

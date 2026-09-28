# Refactor integration and release boundaries

The patch preserves the five club shells, existing Melos dependency boundaries,
Next.js location, historical migrations, protected financial records, and the
separate server SMS gateway. No application directory is retired merely because
it is not currently active in the hosted registry.

## Implemented source changes

- Hash-bound, expiring exceptions allow identified migration evidence in the
  boundary scanner without allowing retired runtime ownership or arbitrary scripts.
- The Rayon public-source candidate uses immutable imports, sealed verification,
  approved compare-and-swap publication, matching media freshness and byte hashes.
- Supporter privacy validation covers the five registered app roots, all registered
  production Dart packages, source manifests, platform collectors and optional
  per-club merged build manifests. The existing Rayon-specific store-copy checks
  remain additional checks, not evidence of other clubs' store declarations.
- Runtime feature enablement cannot expand a club-disabled feature. Malformed
  supplied flags fail closed. An empty module set uses a built-in recovery route.
- Design authority wording and the five-club scope are reconciled. CSS consolidation
  is limited to adjacent identical leaf rules; this does not grant visual approval.
- The economics record preserves the unresolved decision and blocks promotion;
  it does not silently rewrite existing balances or claim an approved new economy.
- Catalog disposition tooling preserves overloaded function identities and flags
  changed source metadata for re-review. Missing mapping never authorizes deletion.
- Candidate-bound cutover/retirement evidence checks require complete, fresh,
  inspectable artifacts. They never deploy or authenticate reviewer identities.

## Required full-checkout validation

Resolve the existing pinned Flutter and web dependencies. Run:

```sh
dart run melos run verify_refactor --no-select
dart run melos run analyze --no-select
dart run melos run test_all --no-select
```

Then run the existing pinned web typecheck, tests, lint and production build,
local database contracts, signed Android/iOS artifact checks, physical-device
journeys and accountable UAT. The targeted patch test environment is not the
full repository toolchain or a production Cloudflare account.

Before store release, run the supporter boundary validator with
`--merged-manifests <directory>` containing `<club-app>/AndroidManifest.xml` for
all five actual release builds. Source-only checks are not binary certification.

## Migration gates

Generate the catalog review ledger from the saved successful read-only inventories:

```sh
python3 tools/scripts/build_migration_dispositions.py \
  --remote output/migration/cloudflare-stage0/remote-inventory.json \
  --local output/migration/cloudflare-stage0/local-inventory.json \
  --output output/migration/cloudflare-stage0/dispositions.json
```

Use `--previous` to retain decisions whose project, object identity and metadata
fingerprint still match. `--require-resolved` fails on unreviewed or disappeared
objects. Operator-approved source, destination, contract and retention evidence
must be supplied; this generator does not invent them.

`docs/release-cutover-evidence.template.json` and
`docs/release-retirement-evidence.template.json` deliberately begin with every
required gate unproven. Validate candidate-bound evidence with
`tools/scripts/validate_migration_release.py`. After target financial writes have
started, forward recovery and reconciliation replace a simple traffic rollback.

## Work not replaced by this patch

Supporter authentication/session migration, complete domain API and client ports,
transaction throughput/failure proofs on real D1, deployed function behavior
comparison, scheduled-job ports, production provider integration, approved
content-authoring integration and all production cutover/retirement steps remain
outstanding. No source-only result should be used to check off those tasks.

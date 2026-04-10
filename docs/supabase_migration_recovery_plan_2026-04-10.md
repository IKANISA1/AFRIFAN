# Supabase Migration Recovery Plan

## Status

- Production migration history is not compatible with `supabase db push` or `supabase db pull`.
- Local migrations begin at `20260330100000`.
- Production contains an earlier migration lineage starting at `20260310120000`.
- Git history in this repository does not contain the missing `20260310` to `20260404` migration files.
- Migration `20260410230000_create_request_rate_limit_function.sql` has been applied to production and recorded in the remote migration ledger.

## Verified facts

- `supabase migration list --db-url ...` reports:
  - many remote-only versions from `20260310120000` through `20260404103000`
  - many local-only versions from `20260330100000` through `20260410123000`
- `supabase db push --dry-run --db-url ...` fails because remote history references versions missing locally.
- `supabase db pull ... --db-url ...` fails for the same reason.
- Searching `git log --all -- supabase/migrations` did not recover any of the remote-only versions.

## Clean recovery path

1. Treat production as the current source of truth.
2. Export a schema-only snapshot and remote migration ledger.
3. Recover the missing migration SQL files from an external source if available:
   - older repository snapshot
   - teammate clone
   - CI artifact
   - backup branch
4. If the original missing SQL files cannot be recovered, establish a new baseline from production instead of guessing old migrations.
5. Only resume `supabase db push` after local and remote lineage are made consistent.

## Tooling added

- `tools/scripts/audit_supabase_migration_lineage.sh`
  - compares local migration versions with remote production history
  - writes remote-only and local-only lists
- `tools/scripts/export_remote_supabase_schema.sh`
  - exports a production schema-only snapshot and migration ledger
  - defaults to the application schema baseline scope: `public,graphql_public`
  - can be widened with `INCLUDE_ALL_SCHEMAS=1`
- `tools/scripts/repair_supabase_migration_history.sh`
  - records an already-applied migration in the remote migration ledger without replaying SQL
- `tools/scripts/restore_supabase_migration_history.sh`
  - restores the remote migration ledger from a CSV backup
- `tools/scripts/reset_supabase_to_remote_baseline.sh`
  - dry-runs or executes a full baseline reset:
  - backup remote migration history
  - export the live application schema
  - archive the existing local migration chain
  - install a single baseline migration locally
  - rewrite the remote migration ledger to that baseline
  - verify `supabase db push --dry-run`

## Recommended next step

Run:

```bash
export DATABASE_URL='...'
bash tools/scripts/audit_supabase_migration_lineage.sh
bash tools/scripts/export_remote_supabase_schema.sh
```

Then use the exported recovery bundle to either:

- reconstruct the missing migration chain, or
- create a deliberate production baseline reset.

## Supported baseline reset workflow

This matches the current Supabase CLI guidance for repairing divergent history:

1. Remove the incompatible local migration chain.
2. Revert the incompatible remote migration history.
3. Pull or install a single baseline migration from the live schema.
4. Record that baseline as applied.

For this repository, the clean automated path is:

```bash
export DATABASE_URL='...'
bash tools/scripts/reset_supabase_to_remote_baseline.sh
bash tools/scripts/reset_supabase_to_remote_baseline.sh --execute
```

Dry-run generates the recovery bundle and planned baseline version only.

`--execute` will:

- archive the current local `supabase/migrations/*.sql` files into `supabase/migrations_archive/<timestamp>/`
- create one new baseline migration under `supabase/migrations/`
- replace the remote `supabase_migrations.schema_migrations` contents with that single baseline version
- verify that `supabase db push --dry-run` no longer fails on migration history mismatch

If execution fails after rewriting the remote ledger, the script restores the old remote history from the CSV bundle and restores the archived local migration files automatically.

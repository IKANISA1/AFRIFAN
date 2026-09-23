# Football-Only Database Reconciliation And Rollback

Status: production change-control input. This document does not authorize a
live database change.

## Baseline Meaning

`supabase/migrations/20260820080202_football_only_baseline.sql` is the complete
schema baseline for a fresh environment. Subsequent committed migrations apply
in filename order. Validate the complete chain with `supabase db reset --local`
and the database contract suite.

Do not push or replay this baseline over an existing production database.
Existing environments already contain their own applied migration ledger, user
data, storage objects, scheduled work, and operational audit records.

## Required Owners

- database change owner;
- application release owner;
- data-retention and privacy owner;
- security reviewer;
- backup and recovery owner;
- monitoring and incident owner;
- final accountable approver.

No owner may approve solely from a local reset result.

## Discovery And Classification

Perform these read-only steps against an authorized production snapshot or
restored backup, never against live production first:

1. Export the applied migration ledger with version and name.
2. Export object inventories for schemas, relations, columns, routines,
   policies, triggers, publications, grants, default privileges, storage
   buckets, scheduled jobs, and extensions.
3. Generate an equivalent inventory from a fresh baseline environment.
4. Diff production against the baseline using stable identifiers and
   normalized definitions.
5. Classify every production-only object as:
   - required operational drift to incorporate into a new migration;
   - unsupported application ownership to remove;
   - platform-managed object to leave untouched;
   - unknown, which blocks the change until resolved.
6. For every unsupported relation, record row count, data classification,
   retention basis, export destination, deletion approval, and verification
   owner without copying row contents into the change ticket.

Stop if the snapshot is stale, the migration ledger is incomplete, an object
owner is unknown, or the baseline is missing a current production capability.

## Forward-Only Reconciliation

Create a new migration with `supabase migration new` after discovery and
approval. The migration must move the existing environment forward from its
actual state; it must not rewrite old migration records or assume the baseline
was executed there.

The migration must:

- preserve the supported `public` and `football` contracts;
- remove unsupported routes, configuration rows, grants, publications,
  policies, routines, relations, and schemas in dependency-safe order;
- keep platform-managed schemas and extensions untouched unless an official
  Supabase procedure explicitly requires a change;
- preserve production-only changes that were classified as valid and first
  captured in reviewed source;
- use deterministic, idempotent preconditions where safe;
- fail closed when an expected object, dependency, row count, or classification
  differs from the approved discovery snapshot;
- avoid embedding credentials, personal data, or exported records.

Migration-ledger repair is permitted only after the physical schema, policy,
grant, storage, and schedule state has been independently reconciled and the
exact repair command is approved. Ledger repair is not a substitute for schema
change execution.

## Rehearsal

1. Restore the latest approved production backup into an isolated project.
2. Record restore identifier, timestamp, size, and checksum evidence.
3. Apply the forward-only reconciliation migration.
4. Run the full pgTAP suite, schema lint, security advisors, and schema diff.
5. Run application smoke tests for auth, club context, fixtures, predictions,
   membership, contributions, tickets, shop, and notification
   operations.
6. Confirm no unsupported object or persisted configuration remains.
7. Confirm supported row counts, foreign keys, policies, grants, storage
   buckets, schedules, and prediction contracts match the approved target.
8. Measure lock duration, query latency, storage impact, and total change time.
9. Rehearse abort and rollback using the same restore and tooling path.

Any rehearsal variance blocks live execution until the migration and evidence
are updated and reapproved.

## Live Execution

- Freeze conflicting schema and application changes.
- Verify the exact candidate commit, migration checksum, target project, backup
  status, point-in-time recovery window, change window, and named operators.
- Put write-heavy workflows into the approved maintenance posture if required.
- Execute the new forward-only migration once.
- Run immediate object, ACL, RLS, publication, storage, schedule, and
  application smoke checks.
- Observe error rate, authentication, database load, queue health, scheduled
  work, prediction placement, and core transaction workflows for the approved
  window.
- Retain command output with secrets redacted and independent sign-off.

Never run `supabase db reset --linked` against production.

## Rollback

The primary rollback is application rollback plus a reviewed forward
compensating migration. Do not edit an already-applied migration.

Before execution, define:

- the exact application artifact to restore;
- compatibility of that artifact with the reconciled schema;
- compensating SQL for reversible grants, policies, routines, and
  configuration;
- the point at which destructive data removal makes compensation insufficient;
- the restore/PITR decision owner and maximum acceptable data loss;
- reconciliation steps for writes received during the change window.

If data restoration is required, stop writes, invoke the approved recovery
procedure, verify the restored migration and object inventory, reconcile
accepted writes, and repeat the full security and application checks.

## Completion Evidence

Completion requires:

- approved discovery and data-classification inventory;
- verified backup and successful restore rehearsal;
- reviewed forward migration and checksum;
- green database and application tests on the restored snapshot;
- live execution receipt and post-change inventory;
- completed observation window with no unresolved high-severity finding;
- accountable database, privacy, security, application, operations, and final
  release sign-off.

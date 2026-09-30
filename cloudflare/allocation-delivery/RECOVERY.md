# Explicit operations inbox recovery

The existing event delivery protocol remains the owner of original allocation
event IDs. Its effects are operations inbox records; re-drive does not settle a
payment, refund money, post a second allocation or award rewards.

## Optional forward source migration

Apply `migrations_source/0007_approved_recovery.sql` only after the existing
payment-allocation `0006_reliable_event_delivery.sql` in the reviewed source
database. The new recovery control starts disabled. Applying this migration blocks
the older direct `redrive` command path, even if an old binding remains. Prepare
the maker/checker host and preserve the old source before explicitly enabling this
new protocol. Do not downgrade the schema, delete evidence or remove the guard to
recover availability.

The shipped recovery template is disabled, has no public route or schedule, no
provider/sink/dispatcher binding, no credential, and two unresolved principal
identities. Its database is the existing allocation source, not a new empty source
or the consumer inbox.

## Prepare, review, confirm

1. A trusted maker binding inspects the exact dead event and current revision.
2. The maker explicitly submits a new `decisionId` and retained `operationId`,
   selected permitted repair reason, SHA-256 repair evidence and non-personal
   evidence reference. This stores an immutable prepared decision and performs no
   dispatch or financial change.
3. A separately authorized checker reads that decision and the current event,
   then explicitly confirms its original operation ID, revision and evidence hash.
4. The SQLite transaction rechecks both live principals, current grants, club and
   source reconciliation, control, dead state and event revision. The checker must
   differ from the maker and the principal of the failed dispatch. A new decision
   expires after the configured technical decision window (1–300 seconds).
5. Decision confirmation and the original retained re-drive command commit in one
   transaction. Any failure rolls them both back. The job becomes pending; this
   step does not run a consumer or provider. A later explicitly enabled dispatcher
   reuses the same original event, which the real inbox deduplicates.

Same-operation confirmation returns the retained receipt, including after later
dispatch. A different payload/key/reviewer or stale revision cannot replace it.
Lost transport acknowledgments are uncertain. Never delete a decision or create a
new key to make an uncertain command look successful. SQL decision history is
retained; no policy-driven evidence deletion is invented here.

## Durable private host client

`DeliveryRecoveryClient` is a strict server-side/private-binding TypeScript client.
Its constructor, `pending`, and `reconcileReadOnly` never issue a remote write.
`stage` durably records a command with atomic CAS and checks readback before
`sendOriginal` can send. The attempt is journalled before the RPC. Unknown outcomes
retain the complete original tuple across reconstruction; the operator chooses
GET-only reconciliation or an explicit retry of that exact original operation.
Scope invalidation fences late completion, and concurrent clients cannot overwrite
an unresolved command.

For confirmation, the client command additionally contains `eventId` as local
binding context. It strips that field from the five-field wire request and checks
the returned event ID against the retained context. Do not omit this check.

The host supplies a durable authenticated-operator/club/role-scoped journal with
retained history. `tools/scripts/local_ops_rehearsal_journal.mjs` is a concrete
Node/SQLite private host adapter used in the tests. It requires a private directory
and file, rejects symlinks and changed scope, and retains immutable journal history.
It is not browser storage and cannot grant staff authority.

## Local rehearsal

```sh
node tools/scripts/local_ops_rehearsal.mjs --output output/local-ops-rehearsal.json
```

This executes real disposable SQLite with five synthetic club IDs, declared local
budgets, concurrent drains, source/sink response loss, ignored sink deadline and
late commit, financial hash conservation, private snapshot export/hash/readback,
quarantined stale restoration, forward-checkpoint restoration, single-writer
cutover, actual previous-dispatcher execution and kill-switch rollback. Independent
SQLite financial and checker races also execute. Reports include original receipt
pairs, measured durations and retained artifact hashes. Fixture source snapshots
are synthetic, not production backup provenance or release approval.

The module has not enabled any production flag, applied D1 SQL, deployed a service,
provisioned an operator identity or called a real provider.

# Reliable allocation-event delivery

This module consumes the existing `payment.evidence_allocated` outbox into a **private operational inbox**. It does not send SMS/push/email, confirm settlement, post financial entries, activate membership, fulfill contributions, or execute refunds. The inbox is a concrete durable downstream effect, not a placeholder acknowledgement. A consumer record and its deduplication identity are the same atomic SQLite insert.

## Boundaries and integration

`AllocationEventSource` uses the **existing allocation database**, with the additive `../payment-allocation/migrations/0006_reliable_event_delivery.sql`. It requires the reviewed existing migration lineage, existing `outbox` grant and a new club-scoped `dispatch` grant. `AllocationDeliveryReview` requires a separate `review` principal. The same principal that last claimed the event cannot redrive it, even when it has both roles. This is service-principal separation, **not evidence of named human maker/checker approval**.

`AllocationEventInbox` uses a **separate new operational database** with `migrations/0001_operations_inbox.sql`. Its one allowed consumer identity and approved club list are checked before inserts and reads and again at mutation time. Its private reader is exposed separately. Binding possession is privileged: a caller of the reader can read the configured clubs. A real operator adapter must independently enforce human Access and club authorization; Cloudflare Access context does not automatically propagate between Workers. No public operations page or Access adapter is installed by this module.

`AllocationDeliveryRunner` has only the source and inbox service bindings; it has no database, provider or review binding. The runner validates the exact source envelope and destination receipt before asking the source to acknowledge. The source trusts this narrowly bound, reviewed coordinator; a stored acknowledgement is not an independent provider attestation or a cryptographic third-party settlement proof.

## Cutover and legacy ownership

All shipped runtime switches are false, routes/previews are disabled and there is **no shipped Cron schedule**. SQL creates no enabled controls or grants. Stop and review the old outbox executable before enabling the new pipeline.

Only original delivery rows that are `pending` with zero attempts can be enrolled. A source-side SQL guard makes legacy claiming and new enrollment mutually exclusive, including their race. Previously leased, expired-but-attempted and acknowledged rows are never replayed automatically. Those require separate historical reconciliation; `health.unmanagedLegacyAttempted` counts them without asserting uncertainty or non-delivery.

Managed events retain their original outbox and receipt bytes. Their delivery state is in `pa_delivery_jobs`; the old `pa_outbox_delivery` row intentionally does not become a false remote-delivery receipt. Attempts to run the legacy claim/update path over managed rows fail. Do not combine the old and new consumers as active writers. Consumer identity and maximum attempt budget cannot be changed in place after adoption. A different subscription requires reviewed migration, not a configuration shortcut.

## Recovery

Each source command is immutable. Its insertion checks current principal/club/settings/grant, expected revision, lease and allowed transition **inside SQL**, then advances the job in the same transaction. The event ID never changes. Retry backoff doubles from the explicitly configured base, capped at one hour and ten attempts. An expired lease is journaled before another attempt; repeated process crashes cannot create unbounded attempts. Dead letters are retained, not deleted or reset by a timer.

A sink timeout or transport error is an **unknown remote outcome**, not cancellation. A sink may have committed. The next delivery uses the same event ID, consumer ID and immutable envelope; the sink returns the original receipt or rejects conflicting contents. The source acknowledges only a validated durable inbox receipt. Source acknowledgement failure leaves the remote effect recoverable and cannot create a second inbox row.

A reviewer may explicitly redrive a dead event with an original operation UUID, exact revision and controlled reason. Retry that same request after a lost response. Exact-key replay returns the original command outcome; it is not a claim about the current job head. New review reads show the current head separately. The TypeScript client never generates a new operation key or automatically retries a write.

The driver returns command counters: `stored`, `retryRecorded`, `deadRecorded`, `unknown`, and `unavailableClubs`. `retryRecorded` may include an attempt that exhausted its budget and became dead; inspect the current job for state. These counters are not handset delivery, financial settlement, or a monitoring SLA.

## Operational data

The envelope contains only schema/consumer/event/club/order/user IDs, kind, allocation-recorded and business-target flags, and recorded time. It contains no phone, raw SMS, amounts, payment route, provider reference, credential, or free-text narrative. These IDs still constitute private operational data. The contribution flag stays `businessTargetFulfilled:false`; delivery does not create totals, rewards or referrals.

`inspect` and inbox `list` have 50-row maximums and exclusive event-ID cursors. Pagination is not a cross-call snapshot; later arrivals with earlier UUID ordering may require a refresh. Health caps individual counts at 1,000 with a `capped` signal, does not expose record IDs and is not an atomic multi-query snapshot. Returned page sizes and iteration counts are bounded; these controls do **not** prove bounded scanned rows, game-day throughput or D1 cost. Measure execution plans and production-shaped load before acceptance.

Identity and allocation/inbox stores are separate. Revocation can occur after the source pre-send check and before the external effect; no cross-database atomicity or universal revocation fence is claimed. Real retention/erasure, processor review, on-call ownership, alerts and provider acceptance remain open. No audit or ledger is automatically erased.

## Test and deployment use

Run from the repository root:

```sh
node --test cloudflare/allocation-delivery/tests/*.test.mjs
node cloudflare/allocation-delivery/scripts/check-deployment.mjs
tsc cloudflare/allocation-delivery/review-client.ts --strict --target ES2022 --module NodeNext --moduleResolution NodeNext --outDir /tmp/africlub-delivery-client
```

The tests use actual local SQLite, the actual allocation classes and an independently persisted inbox. Five races use independent SQLite connections in worker threads. Local tests are not Workers RPC, Cloudflare D1, real Access, provider or physical-device acceptance. Templates are disabled reference configurations, not deployable approvals. Review account/resource IDs, source and sink DB separation, grants, retention, routes and one scheduler owner before enabling an isolated test environment.

See `contracts/delivery-v1.json` for the private method inventory and limits, and `review-client.ts` for explicit inspection, health and redrive commands. The main pinned source verifier includes all new tests and template checks.

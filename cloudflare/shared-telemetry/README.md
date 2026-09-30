# Private service telemetry

This is a disabled-by-default, local-tested source candidate. It does not approve a
retention policy, enable logging, deploy a sink or establish production SLOs.

## Producer boundary

`traceOperation(env, {service, operation, clubId}, work, options)` executes `work`
once and preserves its result or original error. It generates a random trace
locally. It does not accept an inbound trace header, person, challenge, order,
payment, event or provider identifier as trace authority.

`operationMetric`, `queueMetric`, and `normalizeMetric` accept only their exact
finite schemas. Unknown fields and unknown enum values are rejected. There is no
request/response body, phone, OTP, token, cookie, IP, raw URL, stack, provider body
or exception message in the projection. Duration, time, queue counts and queue age
are bounded. Queue counts mark their 1,000-row cap and retain `dead`, `unknown` and
`reserved` states; per-club drain outcomes make lack of progress visible.

The services are `supporter_auth`, `supporter_browser`, `supporter_membership`,
`auth_code_delivery`, `allocation_delivery`, `payment_allocation`,
`payment_exceptions`, `operator_api`, `rayon_public`, `frontend_router`, and
`receipt_delivery`. The operation labels are defined by the finite `OPERATIONS`
set in `telemetry.mjs`. Route code chooses one of these labels; raw routes are not
labels. `completed` describes the observed service operation, not settlement,
handset delivery, authentication success, business acceptance or release approval.

## Explicit configuration

Each producer requires all of:

- `PRIVATE_METRICS_ENABLED=true`;
- `PRIVATE_METRICS_RETENTION_MS`, an explicit integer from one hour through 366
  days (technical range only; no default or legal recommendation);
- `PRIVATE_METRICS_POLICY_REF`, a reviewed non-personal reference;
- a narrow private `PRIVATE_METRICS` service binding to `PrivateServiceMetrics`.

`emitMetric` makes one private sink call with a maximum 100 ms technical deadline
(25 ms default). It catches rejection, invalid input and configuration errors. It
does not retry the sink, the service operation, a committed command or a provider
submission. A timeout does not cancel a remote sink call. Passing a Worker context
keeps the bounded observation in `waitUntil`; there is no console fallback.

## Concrete sink and retention

`PrivateMetricsStore` uses a separate `METRICS_DB`. It validates the exact metric
again and requires the producer's retention/reference to match the server's
configured values. It accepts only recent bounded observations. Persisted JSON is
an immutable sanitized projection, not a domain receipt. Neither sink nor reader
has a provider, queue, identity or financial database binding in its template.

The private trace reader excludes expired observations. The separate private
retention entrypoint explicitly removes at most 1,000 expired rows per call. It
does not expose raw SQL or unbounded deletion. There is no shipped schedule or
approved retention value. Configure and run the retention operation through the
approved host's maintenance process; source defaults alone do not cause deletion.
An outage may leave expired bytes retained until maintenance recovers; they remain
unreadable through the supplied trace reader. Protect and age backups separately.

These aggregate club records and random trace records remain private operational
data. Binding exclusivity, staff authorization, storage access, actual retention
approval and hosted behavior require separate acceptance.

## Entrypoint integration

`entrypoints.mjs` provides a private RPC wrapper and an HTTP wrapper. They read
only a bounded club scalar, a fixed operation label and response status. The work
runs once. A failed mutating operation is recorded as `unknown`, including a
permission failure which can occur after commit; read permission failures are
`denied`. Neither outcome grants a retry or establishes financial finality.

The wrappers cover the financial ingest/allocation/receipt/outbox capabilities,
all checkout and handoff capabilities, payment case capabilities, both private
publication entrypoints, public snapshot HTTP reads, the same-origin supporter
web router, and credential delivery receipts/reconciliation. The operator gateway
reuses its existing single emission and generated response request ID. Private
telemetry suppresses any second legacy event. The legacy injected sink remains
available to deterministic tests; the default gateway has no console sink.

Distributed service templates remain disabled and omit private telemetry
bindings/retention. Their existing restrictive deployment guards continue to
reject unapproved capabilities. The local fixtures explicitly configure a
separate private observation sink; enabling hosted bindings and selecting policy
requires an approved deployment configuration. The named sink writer has no
financial, identity, provider or queue capabilities.

The expanded service and operation inventory, source hashes and executed checks
are recorded separately in `docs/release/backend-telemetry-integration-2026-09-30.json`.
The earlier delivery recovery checkpoint is retained unchanged.

## Local verification

```sh
node --test cloudflare/shared-telemetry/tests/*.test.mjs
```

The tests execute real local SQLite, configured expiry and read exclusion, negative
schema/secret-injection cases, and source/sink failure isolation. They do not run a
deployed D1 database or Cloudflare runtime.

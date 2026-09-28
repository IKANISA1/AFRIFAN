# Production candidate, promotion and source-control gates

Status: implemented local controls; **not production release approval**.

## Canonical source

Apply changes only to the original relative paths. Dated patches and conversation
archives are preservation artifacts, not an automatic merge order. The
`docs/governance/production-source-lock.json` records selected reconciled source
bytes; it is not a full repository signature. Update its paths through reviewed
source changes whenever a covered file changes. A complete Git checkout, protected
branch, signed/attested candidate and pinned CI remain prerequisites.

The connected GitHub lookup of the remote recorded in this Drive export did not
resolve an accessible repository. No branch, rule, commit, approval identity or
hosted CI completion was fabricated. The current Drive tree is not automatically
made a protected Git candidate by saving a manifest.

## Security containment

The fresh root-folder metadata still has an anyone/writer permission. The available
connector cannot revoke that external permission. An authorized owner must restrict
it, preserve relevant revision evidence, classify exposed signing/config artifacts
and remediate actual credentials through provider procedures. Never upload private
keys or copy real environment values into reports. The source safety scanner
reports paths/rule names only and does not claim comprehensive secret detection.

## CI and builds

Main CI includes the offline backend/identity/payment/operator contracts, source
lock checking and real Dart-native verification after Flutter installation.
Next.js no longer ignores TypeScript build errors. Existing release jobs also
require the backend job. The former automatic web deployment workflow now prepares
an exact commit only; it has no deployment token and performs no remote write.
A successful build does not authorize production.

`candidate-integrity.mjs seal` inventories the built artifact. `verify` checks its
bytes against an externally trusted expected commit and digest. `approve` verifies
four distinct Ed25519 approver keys for security, operations, product and privacy,
for the same candidate, artifact and environment. Approval expires within 24 hours.
Trusted public keys and their revocation state MUST come from a protected external
source, not the uploaded artifact or a caller-selected replacement. No production
private key or approved signature is supplied.

```sh
node tools/release/candidate-integrity.mjs verify ARTIFACT MANIFEST EXPECTED_COMMIT EXPECTED_DIGEST
node tools/release/candidate-integrity.mjs approve APPROVALS TRUSTED_KEYS EXPECTED_COMMIT EXPECTED_DIGEST
```

This is not a deployed promotion service. Protected-environment provisioning,
binding/configuration digests, provider credential injection, provenance/attestation
and remote readback remain required before adding an automated promotion action.
There is intentionally no `wrangler deploy` fallback after a failed check.

## Runtime and financial gates

All new runtimes remain disabled. Approve exact Access policies and tenant grants,
real D1 transaction/trigger behavior, five-club identity and browser/native journeys,
provider evidence authenticity, historical reference reconciliation, late and
unknown payment handling, refunds/full business fulfillment, observability and
privacy/storage/rights decisions before activating any financial writer.

The public reader requires a complete approved immutable snapshot and verified
media. Applying only its new reader without snapshot migrations and approved
publication fails closed; coordinate the source, schema and snapshot transition.
Preserve legacy data; do not edit applied historical SQL migrations.

OTP policy preserves a three-per-phone/15-minute ceiling, adds 10/minute per club,
and uses a 50/minute aggregate default for the five configured clubs. Limits are
pilot bounds, not load-tested capacity or provider-cost approval. Shared-IP limits
still apply across clubs. A fair dispatch drain can inspect up to 10 candidates per
configured club; review scheduling, latency and spend before enabling it.

No local encryption solves complete installation data loss or a restored old
snapshot. Server-authoritative unresolved-operation recovery remains mandatory.

## Cutover

A final consistent database export, all object originals, tested restore, approved
retention and historical ledger/reference reconciliation are required. Keep exactly
one authoritative financial writer. After target writes begin, rollback must
reconcile them before any source writer resumes. No source/CI change in this batch
retires Supabase, approves FET economics, sends a payment or modifies billing.

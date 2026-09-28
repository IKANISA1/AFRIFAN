# Source-to-candidate behavior map

Source files were retrieved from AFRICLUB/supabase/migrations on 26 September 2026.
`source-provenance.json` records their original Drive IDs and exact downloaded hashes.
Those files are evidence, not a new authorization to change economics or deploy.

| Source contract | Candidate treatment |
| --- | --- |
| `20260923102734_serialize_momo_evidence_before_row_locks.sql`: `allocate_momo_payment_intent` | Preserve exact owner/raw/parsed/intent amount/currency binding, non-mock parsed debit requirement, canonical MTN provider, original receiver, deadline at mutation, one global provider/reference claim, original receipt recovery before current receiver revalidation. PostgreSQL locks are replaced by a single SQLite allocation trigger inside the D1 batch candidate; real D1 parity is unverified. |
| `20260923101604_preserve_paid_membership_restrictions_and_receipt_recovery.sql`: `activate_matched_membership_payment` | Preserve suspended membership, existing member identity/number/code/points, verified payment state, same-tier calendar-year extension and different-tier reset. The target uses explicit UTC arithmetic with leap-day clamping. Membership plus allocation, receipt and outbox commit together. |
| `20260920165540_membership_payment_evidence_binding.sql` | Keep immutable server-selected provider/country/payee/partner/receiver/amount snapshot. New checkout/preparation is NOT ported: only reviewed, frozen pending source orders are accepted into staging. |
| `20260920123000_automatic_paid_membership.sql` | Earlier membership behavior is interpreted subject to the later restriction and receipt migrations. No old restriction-lifting logic is reintroduced. |
| `20260823061851_member_portal_and_contribution_intents.sql` | Preserve existing six-digit member code in imported membership records. The staging candidate assigns a new unique code only for an actually new membership; collision fails the transaction. Anonymous/member bootstrap and browser endpoints are NOT ported. |
| `20260916185609_member_contribution_history_and_route_validation.sql` | Contribution projection is limited to positive whole RWF 100–5,000,000 and a server-selected route. History UI/keyset API, pending-order reuse and creation quotas are NOT ported. |
| `20260919164057_atomic_initiative_confirmation.sql` | Source finalization atomically changes contribution state, campaign totals, points and referrals. This candidate deliberately stops at allocated evidence and sets `businessTargetFulfilled=false`; it does not silently omit reward/referral effects and still call the contribution confirmed. |

## New explicit implementation choices

The private service-principal/grant schema, forward-only staging import format,
immutable evidence receipt, transactional outbox and 60-second/20-item leases are
new target-platform choices. They are not represented as already present in the
source SQL. The import planner produces a disabled minimal projection and is not a
full export/import conversion. Trusted service binding and an evidence reference
are not proof of actual external settlement. Human authorization and revocation
across the existing identity database are unfinished integration requirements.

One allocation database covers all participating clubs so deduplication is not
accidentally tenant-local. A future sharded design must replace that guarantee
explicitly. Current receiving-account controls apply to new allocations; historical
receipts remain recoverable with current service authorization.

The original code and records are not edited, deleted or marked as migrated by this
module's presence. No source object disposition or production release is approved
by a test result. Historical cumulative v1–v4 packages must not downgrade newer Drive
code. This is an additive incremental candidate against the current workspace.

## Primary implementation references

These describe APIs and SQL semantics, not evidence that the candidate was deployed:
- https://developers.cloudflare.com/d1/worker-api/d1-database/
- https://developers.cloudflare.com/d1/best-practices/read-replication/
- https://developers.cloudflare.com/d1/sql-api/sql-statements/
- https://sqlite.org/lang_datefunc.html

The precise target D1 SQLite behavior remains a staging prerequisite. Run the
read-only `scripts/check-sql-runtime.sql` probe and actual transactional tests.

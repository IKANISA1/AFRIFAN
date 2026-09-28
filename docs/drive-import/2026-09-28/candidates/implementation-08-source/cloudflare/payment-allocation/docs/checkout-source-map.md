# Membership checkout source map

26 September 2026. Batch 8 is a narrow current-source extension; this document
separates source-derived requirements from new implementation controls.

| Source | Preserved requirement | Implementation |
| --- | --- | --- |
| `20260920165540_membership_payment_evidence_binding.sql`, prepare routine | Source-selected package sorted by sort order and ID; annual-price preference and positive whole amount | `pa_checkout_offers` and catalog/amount validation |
| Same routine, receiver resolution | Active route, matching country and strict unique receiver for partner/recipient | Selected route and receiver predicates, with additional exact tenant/provider/currency consistency |
| Same routine, dialer | Server template substitution only | Bounded USSD builder; stricter required amount/recipient placeholders documented |
| Same routine, pending order reuse | Same owner/club/package/payment route and unexpired pending intent | Reuse view includes exact immutable route/dialer binding; historical imports without detail cannot be guessed |
| Same routine, replacement | Cancel same owner/club pending membership intents then create a 24-hour order | Single-statement triggered transaction, retaining original history |
| Existing `0001_payment_allocation.sql` and `src/service.mjs` | Immutable order/evidence binding; allocation before membership; suspension preservation; global external-reference uniqueness | Unchanged allocator consumes newly prepared orders; no competing ledger or payment writer |

New controls/adaptations, not attributed to the PostgreSQL routine: separate private
prepare/read principals, disabled catalog gate, revision-bound commits, strict
request UUID/field grammar, 20-request pilot budget, durable exact-key original
response recovery, current-status read, private disabled import plans and strict
TypeScript reference adapter. Runtime and integration evidence remain local only.

The retrieved PostgreSQL migration is preserved in the delivery's reference
backup with its original Drive ID `17gFdlbgAmrwpsRmChUCJR6iux1d6LdE4` and hash.
The original allocation code/schema were freshly compared with their saved Batch 7
bytes before extending them. Historical cumulative v1-v4 packages do not authorize
downgrading newer source.

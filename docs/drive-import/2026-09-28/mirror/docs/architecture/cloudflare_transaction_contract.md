# Cloudflare transactional API contract

This contract governs AFRICLUB transactional migration from Supabase. Public-content staging does not satisfy it.

For every consequential command the Worker must resolve authenticated identity, canonical `club_id`, role/entitlement, resource ownership and operation server-side. Client-provided tenant identifiers are untrusted. Each command carries a stable idempotency key. The business mutation, ledger/evidence change, entitlement/inventory state and outbox event are committed atomically in the same club transactional database. Queue delivery and provider callbacks may retry; retries must not duplicate money, FET, membership, stock, tickets or notifications.

One authoritative writer is allowed for financial and entitlement state at a time. Before Cloudflare becomes writer, Supabase remains authoritative. After first Cloudflare authoritative write, recovery is forward reconciliation rather than an unqualified traffic flip.

Mandatory negative tests: missing/expired/revoked identity; missing/conflicting/wrong club; wrong role; cross-club resource; duplicate callback; duplicate command; insufficient balance; exhausted inventory/capacity; concurrent reservation; crash after commit before delivery; queue redelivery; provider replay; settlement replay; reversal replay.

Predict follows `docs/governance/predict_economics_decision.md`: no FET debit for entry unless a later approved version explicitly replaces that contract.

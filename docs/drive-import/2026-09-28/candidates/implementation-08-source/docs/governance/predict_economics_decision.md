# Predict economics decision gate

Status: **unresolved; transactional migration and release approval blocked**.

This file records a conflict, not an accountable product/legal/payment decision.
The blueprint and FET policy describe free selected-match predictions and prohibit
unapproved paid-entry or stake-like mechanics. Historical Predict implementation
and design material describe a 100 FET entry debit and pool distribution.

The executable decision record is `predict-economics.json`. Until a reviewed,
versioned decision resolves the conflict:

- Do not enable or port FET-debit or money-debit prediction entry as a released Cloudflare capability.
- Preserve historical balances, entries, receipts and ledger reversals unchanged.
- Preserve existing server authorization and store-release gates; client feature flags are not permission to change economics.
- Keep public-source pool previews read-only and entry disabled.
- Do not present repository wording, source tests, this patch, or a tool result as legal or payment approval.

The conservative migration restriction is **no newly enabled entry debit**. It
does not claim that the existing Supabase implementation has been rewritten or
that historical liabilities have been reconciled. A future decision must specify
entry cost, earning/redemption rules, reward calculation, supported countries,
required reviewers, policy versions, migrations and negative/concurrency tests.

Run `node tools/scripts/validate_predict_economics_contract.mjs` to check the
record. Add `--release` to require actual approvals; the unresolved record must
fail that release gate. No odds or cash-payout product is introduced by this patch.

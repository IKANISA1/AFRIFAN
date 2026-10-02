# Predict economics implementation and external decision

Status: **free implementation in progress; external economics and release decisions unresolved**.

## Technical free entry v1

The current product blueprint selects free predictions for selected, approved
football fixtures. The local implementation uses `free_v1`: entry debits are zero
FET and zero money, and no welcome or prize FET or money credits are created.
A correct prediction records one accuracy point. Incorrect and void predictions
record zero points. Accuracy points are a separate result field, never a wallet
balance, entitlement or monetary reward. Correctness follows the selected result,
independently of a financial payout.

The forward migration labels all existing pools and entries `legacy_paid_v1`.
It preserves historical amounts, balances, ledger rows and reversals. It creates
new pools explicitly as `free_v1`, blocks new paid entries and retains settlement
and reconciliation of historical liabilities through the guarded service path.
It does not convert a historical paid pool into a free pool or refund history as
a side effect of deployment.

`predict-economics.json` distinguishes this technical implementation from external
approval and verified deployment. Its migration flag permits the scoped local
free implementation and replay; it supplies no deployment or release authority.
Tenant, membership, registered-fixture, kickoff, account revocation and idempotency
checks remain authoritative server checks for every entry.

## External decisions

Historical design and architecture sources describe a 100 FET debit and pool
distribution. Those historical mechanics remain relevant to historical liabilities,
but do not authorize new paid entry. The broader earning, redemption, supported
country, payment and store policy decisions remain unresolved. No reviewers,
approval evidence or release authorization have been invented by implementation.

Run `node tools/scripts/validate_predict_economics_contract.mjs` for consistency.
`--release` remains fail closed while these external decisions are unresolved.
Local source tests, concurrency tests and golden maintenance demonstrate their
specified inputs only; they do not establish deployment, legal or store approval.

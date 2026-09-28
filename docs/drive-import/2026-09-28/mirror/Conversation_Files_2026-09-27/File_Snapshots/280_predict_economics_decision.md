# Predict economics decision gate

Status: release-blocking governance decision for transactional Predict entry and settlement.

The repository currently contains two incompatible descriptions: the authoritative football blueprint and FET policy describe free selected-match predictions and block paid-entry/stake mechanics, while the historical Predict implementation/design material describes a 100 FET entry debit and pool distribution. Until an accountable product/legal/payment decision explicitly replaces the free-entry contract, the conservative contract is authoritative:

- supporter prediction entry does not debit FET or money;
- no odds, custom stake, cash purchase, cash-out, payout or withdrawable balance;
- FET may be awarded only as a pre-disclosed closed-loop reward after authoritative settlement;
- clients cannot enable a debit-based entry through runtime configuration;
- any future FET-entry mechanic requires a versioned decision, policy update, API/ledger migration, negative tests and release approval before enablement.

Migration work may preserve historical ledger records and code evidence, but must not silently promote the historical 100 FET debit behavior into the Cloudflare transactional API.

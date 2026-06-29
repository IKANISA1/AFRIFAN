# AFRICLUB Gamification Product Rules

Date: 2026-06-29
Status: launch contract for partner-centered gamification alignment

## Product Position

AFRICLUB gamification is a closed-loop supporter rewards system. It is not betting, gambling, cash-out, odds, e-money, or a public money-transfer wallet.

FET is an internal club reward balance. Fans earn, reserve, spend, refund, and receive FET only through approved AFRICLUB reward mechanics. Public customer-to-customer transfers and manual amount redemption are not launch behavior.

## Partner-Centered Eligibility

AFRICLUB replaces FANZONE venue/order eligibility with partner-centered eligibility.

Fans earn FET from partner initiatives and promotions, including:

- Partner campaign participation.
- Promotion verification.
- Partner referral conversion.
- Receipt or confirmation review.
- Event QR or matchday activation.
- Admin-approved partner reward adjustment.

Each partner initiative must define:

- Partner.
- Club scope.
- Campaign or promotion title.
- FET earning rule.
- Verification mode.
- Active window.
- Audit metadata.

Partner eligibility is proven by an approved partner FET earn event. A prediction pool may be open to all fans, or it may require an approved earn event for the same partner or the same partner initiative.

## Football Prediction Scope

Launch prediction games are football-only and limited to WDW match-result predictions:

- Home win.
- Draw.
- Away win.

Exact-score, goals, scorer, acca, jackpot, music, trivia, bingo, and non-football games are outside the launch scope unless explicitly reapproved in a later product contract.

## Partner WDW Pools

Partners create pools on football fixtures.

Rules:

- A pool is linked to one partner and one fixture.
- Many partners may create pools for the same fixture at the same time.
- A partner sets the total partner-funded FET stake for the pool.
- A partner sets the fixed fan entry FET required to participate.
- Fans submit one WDW pick per pool.
- Pools lock at fixture kickoff.
- Settlement uses the official fixture result only.
- No dynamic odds, multipliers, overround, house edge, vig, juice, or bookmaker-style liability adjustment is used.

Settlement:

- If there are no active entries, the pool is void.
- If the match is invalid, postponed, cancelled, abandoned, or lacks a final score, active fan entry FET is refunded.
- If no fan picks the correct WDW result, active fan entry FET is refunded and the partner-funded FET remains unawarded.
- If eligible winners exist, the distributable reward is partner-funded FET plus active fan entry FET, divided across eligible winners.
- Logical winners who fail partner eligibility remain visible as ineligible winners and receive zero reward.
- Settlement must be idempotent and audited.

## Wallet Rules

The FET wallet must behave as an audited rewards ledger:

- Available balance is stored in `fan_memberships.points`.
- Every balance mutation requires a ledger row.
- Public fan transfer is disabled for launch.
- Public manual amount redemption is disabled for launch.
- Catalog redemption, partner earn events, pool entry debit, pool payout, pool refund, and admin adjustment must be distinct ledger operations.
- Negative balances are never allowed.
- Retry-safe mutations require idempotency keys.

## Required Launch Evidence

Implementation is not complete until current-state evidence proves:

- Partner initiatives can record approved FET earn events.
- Partner admins or club admins can create partner-funded WDW pools.
- Multiple partners can create concurrent pools on the same fixture.
- Fans can join a pool with one WDW pick and fixed FET entry.
- Pool entry debits, payouts, and refunds write ledger rows.
- Settlement is idempotent.
- Ineligible logical winners are visible and unpaid.
- Legacy multiplier and house-edge generation is not active in the launch path.
- Mobile and admin surfaces use partner pool/rewards ledger language, not betting or fintech wallet language.

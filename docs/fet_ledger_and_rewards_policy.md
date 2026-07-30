# FET Ledger And Rewards Policy

Updated: 2026-07-30

## Policy

FET is a closed-loop supporter reward point. Until legal/payment review approves otherwise, the product must treat `1 FET = 1 FRW` as a monetary-equivalent accounting policy for risk control, limits, audit, reversals, and user copy.

FET must not be described as cash, odds, betting winnings, payout, stake, deposit, stored value, or withdrawable balance.

## Allowed MVP Uses

- Earning FET for approved supporter actions.
- Earning an approved, pre-disclosed reward from a free selected-match
  prediction or reviewed trivia game after authoritative settlement.
- Venue check-in rewards inside approved campaigns.
- Admin-reviewed adjustments with a reason and idempotency key.
- Reservations and reversals for future closed-loop redemption flows.
- Exportable audit views for finance/compliance review.

## Blocked Until Explicit Review

- Cash-out or mobile-money withdrawal.
- External merchant settlement.
- User-to-user transfer outside an approved product policy.
- Open-loop spend.
- Betting, odds, stake, or payout mechanics.
- Alcohol-linked rewards without compliance review.
- Any game mechanic that uses odds, a stake, a paid entry, a cash payout, or
  unreviewed AI-generated content.

## Ledger Rules

- Every write has `club_id`.
- Venue-owned writes also carry `venue_id`.
- Mutation retries use `idempotency_key`.
- Balances and reservations can never go negative.
- Reversals require a reason and actor.
- Admin exports must avoid personal data leakage.
- Client code never receives service-role keys or private feed credentials.
- A game reward references one authoritative game/session/result and is not
  calculated independently by mobile, TV, venue, or web clients.
- AI-assisted trivia cannot create a ledger event until its question set is
  reviewed, published, played, and settled by the governed backend flow.

## Venue Wallet And Reservation Model

Venue campaigns may have a `fet_budget` and `fet_award_per_checkin`. Campaign events write to `venue_promotion_events`. Future redemption/spend flows reserve FET in `fet_ledger_reservations` before final debit so interrupted order/reward flows can be reconciled.

## Release Gates

- Legal/payment review records whether redemption/spend is allowed.
- Privacy review records location and retention handling.
- Alcohol/age review records drinks-ordering constraints.
- SQL contract tests verify idempotency, non-negative balances, RLS, and scoped access.
- Game/reward contract tests verify free entry, selected-match eligibility,
  authoritative settlement, duplicate prevention, and reversal behavior.

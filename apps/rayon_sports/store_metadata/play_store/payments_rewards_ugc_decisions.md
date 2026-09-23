# Payments, rewards, contests, and UGC decision sheet

Candidate classification: reconciled for mobile `1.0.3 (6)`. “Disabled” below
is backed by production-default `StoreReleasePolicy`, its tests, and migration
`20260809111441_enforce_store_release_security_boundary.sql`; it is not an
operational intention. Store-console answers, rights, privacy, audience,
territories, physical fulfillment, and provider/refund approvals remain open.

| Surface | Current implementation evidence | Working classification | Required release decision/evidence |
| --- | --- | --- | --- |
| Merchandise shop | Product catalog, cart, delivery address, pending order, authorized MoMo USSD handoff | Physical goods | Confirm every SKU is physical, fulfillment/refund/support terms, accurate prices/inventory, and no digital entitlement |
| Match tickets | Match/seat flow, pending record, confirmed QR ticket | Access to a real-world event | Confirm venue/event fulfillment, cancellation/refund route, authoritative confirmation, and no misleading “instant purchase” claim |
| Contributions | Contribution records and controlled MoMo handoff | Physical/off-app support payment with no enabled digital entitlement | Approve recipient, purpose, receipts, reversal/dispute, provider terms, and store declaration |
| Membership fees | Policy requires explicit paid-digital authorization plus compiled store billing; candidate migration revokes paid application and exposes only free physical packages | Paid membership/digital entitlement disabled for candidate | Keep free physical membership only; any future paid/digital enablement requires a new artifact, policy assessment, billing implementation, and approval |
| FET points | Earned-points history is allowed; transfer, manual redemption, reward redemption, and partner-offer RPCs are blocked | Non-purchasable read-only/earned history; value transfer and redemption disabled | Ensure store copy does not promise cash, transfer, purchase, withdrawal, or rewards |
| Predictions | General sports prediction context may remain; staked challenge, jackpot, friend challenge, pool join, and related feeds are blocked | Free non-staked engagement only; no prize/value path enabled | Complete age/territory and IARC answers for the visible candidate; separately authorize any future contest |
| Challenges/stakes | Production policy requires complete no-real-value and contest-rule authorization; candidate client RPCs are revoked | Disabled/not applicable | No challenge, stake, jackpot, friend-challenge, or partner-pool claim in listing/review notes |
| Rewards store/offers | Production policy requires approved no-real-value catalog; redemption/offer/transfer RPCs are revoked | Disabled/not applicable | Do not market rewards or offers; future enablement requires new rules, artifact, portal answers, and approval |
| Display names/rankings | Production policy substitutes stable system aliases; friend/search/leaderboard client RPCs are revoked | No cross-user editable text; UGC controls not applicable to this candidate | Keep system aliases and disabled social RPC boundary; reassess before any user-text enablement |
| Challenge notes | Challenge/social capabilities and corresponding client RPCs are blocked | Disabled/not applicable | Reassess UGC only if a future candidate enables cross-user text |
| Fan clubs | Official registers/details; configuration can expose supporter information | Primarily club-published content; privacy/UGC depends on actual fields | Confirm only approved club content/public aliases are exposed and private member data is not shown |

## Required approval statement

The remaining accountable release record must identify:

- exact build and production-config hash;
- the disabled feature keys and matching migration/application evidence;
- each remaining physical/off-app money flow and store policy basis;
- confirmation that public labels remain system-controlled and no cross-user
  editable text is enabled;
- ages and territories;
- contest/loyalty rules URL where applicable;
- approver, date, and evidence reference.

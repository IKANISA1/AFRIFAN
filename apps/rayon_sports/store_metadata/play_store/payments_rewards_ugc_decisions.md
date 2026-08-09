# Payments, rewards, contests, and UGC decision sheet

Every row must be resolved for the exact store candidate. “Disabled” means
enforced in the compiled/runtime configuration and verified on a fresh install;
an unwritten operational intention is not a control.

| Surface | Current implementation evidence | Working classification | Required release decision/evidence |
| --- | --- | --- | --- |
| Merchandise shop | Product catalog, cart, delivery address, pending order, authorized MoMo USSD handoff | Physical goods | Confirm every SKU is physical, fulfillment/refund/support terms, accurate prices/inventory, and no digital entitlement |
| Match tickets | Match/seat flow, pending record, confirmed QR ticket | Access to a real-world event | Confirm venue/event fulfillment, cancellation/refund route, authoritative confirmation, and no misleading “instant purchase” claim |
| Contributions | Contribution records and MoMo route | Donation/support payment; not automatically a store-billing exemption for tied digital benefits | Approve recipient, purpose, receipts, reversal/dispute, and prove no paid digital entitlement |
| Membership fees | Paid application/tier and benefits | Unresolved mixed physical/digital service | Inventory every benefit. Use store billing for paid digital access or remove the digital benefit from the paid bundle/candidate |
| FET points | Earn/history/wallet/rewards code | Loyalty/game points, not yet policy-cleared | Prove no purchase, sale, cash value, withdrawal, transfer for value, or unapproved real-world redemption |
| Predictions | Structured predictions and leaderboard | Free sports engagement only if no consideration/prize | Prove free entry and no cash/real-world prize; approve age/territory and rules |
| Challenges/stakes | Feature-opt-in routes and stake-FET code | Release-blocking contest/gambling risk | Disable for store release unless separately authorized and correctly declared |
| Rewards store/offers | Reward catalog surfaces | Unresolved loyalty redemption | List every reward and fixed/variable method; approve rules, ratios, value, inventory, ages, territories, and accounting |
| Display names/rankings | Editable nickname shown in public/friend/ranking surfaces | UGC risk | Use system aliases only, or provide reporting, blocking, filtering, moderation, terms, contact, and response evidence |
| Challenge notes | User-entered note models on feature-gated challenges | UGC | Disable with challenge feature or provide full UGC controls |
| Fan clubs | Official registers/details; configuration can expose supporter information | Primarily club-published content; privacy/UGC depends on actual fields | Confirm only approved club content/public aliases are exposed and private member data is not shown |

## Required approval statement

The final accountable decision must identify:

- exact build and production-config hash;
- enabled/disabled feature keys;
- each money/reward flow and store policy basis;
- each UGC field and moderation basis;
- ages and territories;
- contest/loyalty rules URL where applicable;
- approver, date, and evidence reference.


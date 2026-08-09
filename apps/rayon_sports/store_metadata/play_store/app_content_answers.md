# Google Play App content working answers

Status: draft pending exact-AAB reconciliation and accountable approval. Enter
these answers in Play Console only after every `BLOCKING` row is closed.

## Privacy policy

- Working URL: `https://gikundiro.com/privacy`
- In-app access: Settings/Profile privacy and legal links.
- `BLOCKING`: verify the public URL returns the approved policy without login,
  is non-editable by users, names the same developer/app, and accurately covers
  the exact AAB, SDKs, retention, deletion, UGC, payments, and support process.

## Ads

- Proposed answer: **No, the app does not contain ads.**
- Evidence: no ads SDK or ad placement was found in the current package graph.
- `BLOCKING`: the inspected generated manifest contains advertising-ID-related
  permissions introduced by dependencies. Reconcile the exact merged manifest
  and SDK configuration; remove unneeded permissions where possible and confirm
  no SDK independently uses the identifier.
- Commercial merchandise, tickets, memberships, or club offers are not by
  themselves the Play “Contains ads” label, but any paid placement or ad SDK
  changes this answer.

## App access / sign-in details

- Proposed answer: **All or some functionality is restricted.**
- Restriction types: guest/anonymous session, phone OTP, membership state,
  role, active backend configuration, and transaction state.
- Portal instructions: use `reviewer_access.md`; add any actual reviewer access
  only in Play Console. Never commit it.
- `BLOCKING`: prove reviewers can reach every submitted feature without a
  personal phone, expiring OTP, Rwanda-only MoMo completion, production payment,
  or unavailable club/admin action.

## Target audience and content

- Current product statement: not directed to children under 13.
- Portal selections: **pending accountable product/legal decision**.
- Recommended conservative gate: do not select child age groups while the
  release exposes payments, predictions, points/rewards, visible supporter
  names, or unclassified contests without the required child-safety design and
  Families compliance.
- `BLOCKING`: approve intended ages and territories and verify the app's actual
  content and marketing are consistent with the selection.

## Content rating (IARC)

Do not copy the former unsupported “Everyone” assertion. Answer the current
questionnaire for the exact release. Review at minimum:

- user-to-user display names and any feature-gated user text;
- predictions, structured games, contests, points, leaderboards, and rewards;
- whether any outcome uses chance;
- whether FET or any reward is purchasable, transferable, redeemable, or has
  real-world value;
- news, supporter content, and remotely configurable content;
- shopping, ticketing, membership, and payment references.

`BLOCKING`: retain the completed questionnaire/export and accountable approval.

## News declaration

- Proposed answer: **Not a News or Magazine app.**
- Rationale: the primary category and function are Sports/supporter services;
  club news is one feature.
- Reassess if editorial news becomes the primary purpose.

## Financial features declaration

The app must complete this declaration even if the final answer were “none.”
The following selections are the conservative working position:

- **Rewards, points, frequent-flyer miles and other incentives** — likely Yes,
  because FET/points/reward surfaces exist.
- **Mobile payments and digital wallets** — policy-owner decision required.
  The app initiates an external MoMo USSD payment route and stores transaction
  references but does not implement a custodial wallet or card account.
- Banking, loans, earned-wage access, credit, crypto/NFT, stock trading,
  insurance, financial advice, and buy-now-pay-later — no implementation found.

`BLOCKING`: a legal/policy owner must map the exact functionality to the current
Console choices; do not select “My app doesn't provide financial features”
without resolving the payment and points rows.

## Data Safety and data deletion

- Use `data_safety.md` as the working category matrix.
- Account creation: Yes (anonymous and phone-auth identities).
- In-app deletion: Profile > Delete account, typed confirmation.
- Web deletion resource: `https://gikundiro.com/account-deletion` is preferred;
  `https://gikundiro.com/privacy#account-deletion` remains a fallback only if it
  presents a real, direct request path.
- Partial retention: possible only for approved transaction,
  fraud-prevention, security, or legal records; disclose categories and periods
  rather than a blanket exception.
- `BLOCKING`: execute deletion for guest and phone accounts, verify the public
  request path, response ownership, identity-safe verification, completion
  timing, retained-data restrictions, and Data Safety consistency.

## User-generated content

- Conservative answer: **UGC/social functionality is present or potentially
  present** because editable nicknames and feature-gated notes can be visible
  to other supporters in rankings/friend/challenge surfaces.
- Current evidence did not identify clear report-content, report-user, and
  block-user flows.
- `BLOCKING`: either ship only system-generated aliases with all user text and
  social/challenge surfaces disabled, or prove terms acceptance, filtering,
  separate reporting and blocking, timely moderation, published contact, and
  abuse-response operations.

## Real-money games, contests, and gambling

- Intended working classification: **not a gambling app**.
- Evidence supports predictions, FET points, leaderboards, rewards, and
  feature-gated stake/challenge code. Absence of a cash-withdrawal method alone
  is not enough to close the policy question.
- `BLOCKING`: prove for the store candidate that FET cannot be bought, sold,
  withdrawn, staked after purchase, or redeemed for cash/real-world prizes;
  disable challenge/stake routes unless separately approved; document any
  contest rules, entry method, prize, dates, selection/odds, ages, and
  territories.

## Payments

- Physical merchandise and match tickets: external MoMo handoff can be
  appropriate when the underlying item and fulfillment are physical/off-app.
- Donations/contributions: document recipient, refund/dispute, and whether any
  digital entitlement is exchanged.
- Membership: **unresolved**. Map every paid benefit. Any digital feature,
  content, subscription, or app functionality must use the applicable Play
  Billing model or be removed from the paid bundle.
- The package contains no Play Billing SDK.
- `BLOCKING`: complete the SKU-by-SKU classification in
  `payments_rewards_ugc_decisions.md`.

## Permissions and APIs

- Source permissions: Internet and optional notifications.
- Source explicitly removes audio recording, external storage, location, and
  phone-state permissions.
- Production define disables Android SMS auto-read; the inspected release
  output has no SMS/Call Log permission.
- Deep links and tel/HTTPS queries are declared.
- `BLOCKING`: inspect the final merged manifest and App Bundle Explorer; submit
  restricted-permission declarations only if the final AAB actually includes a
  restricted permission.

## Other declarations to complete in the authenticated console

- app category and tags;
- government affiliation: No unless an accountable owner documents otherwise;
- health features/content: none found;
- COVID/contact tracing: none found;
- teacher-approved/Families: not proposed;
- Play App Signing and integrity configuration;
- exact countries and pricing (working intent: free download);
- developer contact, support email, and website ownership;
- package-name registration and account verification;
- any required closed-test/production-access answers for the developer account.


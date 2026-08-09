# Google Play App content working answers

Status: build-6 candidate classification reconciled; exact Android AAB, portal
wording, rights, privacy, audience, and release-owner approval remain open.

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
- Recommended conservative gate: do not select child age groups without the
  required child-safety/Families assessment. The candidate disables staked
  contests, reward redemption, social discovery, and cross-user editable text,
  but sports predictions, earned-points history, commerce references, and
  remote club content still require exact questionnaire answers.
- `BLOCKING`: approve intended ages and territories and verify the app's actual
  content and marketing are consistent with the selection.

## Content rating (IARC)

Do not copy the former unsupported “Everyone” assertion. Answer the current
questionnaire for the exact release. Review at minimum:

- system-controlled public aliases and the disabled cross-user text boundary;
- predictions and earned-points history, with contests, staked challenges,
  leaderboards/social discovery, and rewards disabled for public clients;
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
The following is the candidate-specific working position:

- **Rewards, points, frequent-flyer miles and other incentives** — earned-points
  history may be visible, but transfer, redemption, partner offers, and reward
  catalog access are disabled. Select the current Console answer based on the
  exact visible build; do not describe a reward or cash-value program.
- **Mobile payments and digital wallets** — policy-owner decision required.
  The app initiates an external MoMo USSD payment route and stores transaction
  references but does not implement a custodial wallet or card account.
- Banking, loans, earned-wage access, credit, crypto/NFT, stock trading,
  insurance, financial advice, and buy-now-pay-later — no implementation found.

`BLOCKING`: a legal/policy owner must map the exact visible physical/off-app
payment and read-only points context to the current Console choices. The
code-owned paid-digital/reward enablement question is closed as disabled, but
the portal declaration itself remains external.

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

- Candidate answer: **No cross-user editable text or social UGC is enabled.**
- `StoreReleasePolicy` replaces unapproved display names with stable
  system-controlled aliases. Migration `20260809111441` revokes friend,
  supporter-search, leaderboard, challenge-note, and related social RPCs from
  public release clients.
- UGC moderation controls are not applicable to this disabled candidate. Any
  future cross-user text or social enablement requires a new artifact, full
  terms/filtering/reporting/blocking/moderation evidence, and updated portal
  answers.

## Real-money games, contests, and gambling

- Intended working classification: **not a gambling app**.
- Production policy defaults fail closed and the candidate migration revokes
  staked challenge, jackpot, partner-pool, reward, transfer, and related feed
  RPCs from public release clients. FET is not purchasable, transferable,
  manually redeemable, withdrawable, or enabled for a real-world prize in this
  candidate.
- Code-owned contest/reward enablement is therefore disabled/not applicable.
  Current IARC, age, and territory answers remain an accountable portal gate;
  any future contest must carry separately approved rules and controls.

## Payments

- Physical merchandise and match tickets: external MoMo handoff can be
  appropriate when the underlying item and fulfillment are physical/off-app.
- Donations/contributions: document recipient, refund/dispute, and whether any
  digital entitlement is exchanged.
- Membership: paid digital membership is disabled. Production requires explicit
  server authorization plus compiled store-billing availability, which defaults
  false; the candidate migration exposes only free physical membership and
  revokes client submission of paid applications.
- The package contains no Play Billing SDK.
- Physical/off-app provider, fulfillment, refund/dispute, and portal answers
  remain open. Any future paid/digital SKU requires a new billing-enabled
  candidate and assessment.

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

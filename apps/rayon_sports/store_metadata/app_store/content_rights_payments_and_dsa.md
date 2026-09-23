# App Store rights, business-model, and compliance decisions

## Content rights

- The app uses Rayon Sports names, marks, club content, fixtures, and
  photography.
- Onboarding `SOURCES.md` records public source URLs but explicitly states that
  reuse approval remains pending.
- Proposed App Store content-rights answer cannot be finalized until written
  authority is recorded.
- If requested, attach partnership/trademark authorization in App Review and
  explain it in Review Notes.

## Payments and In-App Purchase

- Physical merchandise and real-world match tickets may use external payment
  methods when their fulfillment is genuinely outside the app.
- Contributions require recipient, donation/payment, refund, dispute, and
  entitlement review.
- Paid digital membership is disabled in this candidate. Production policy
  requires explicit server authorization plus compiled store-billing
  availability, which defaults false; candidate migration `20260809111441`
  exposes only free physical membership and revokes paid application submission.
- The package contains no StoreKit/in-app-purchase SDK.
- Do not claim a purchase is complete until the authoritative backend confirms
  it.

## Predictions, rewards, and gaming

- No real-money gambling classification is proposed.
- FET purchase, transfer, manual redemption, reward redemption, partner offers,
  staked challenges, jackpots, and related public-client RPCs are disabled by
  production policy plus migration `20260809111441`.
- The candidate is not presented as gambling and exposes no enabled cash or
  real-world-prize path. Any future contest, promotion, or reward requires a new
  artifact, approved rules, age/geo controls, and updated store answers.

## User-generated content

- Cross-user editable text and social discovery are disabled for this
  candidate. Production policy substitutes system-controlled aliases and the
  candidate migration revokes friend/search/leaderboard/challenge RPCs from
  public clients.
- UGC moderation approval is not applicable to this disabled build. Any future
  enablement requires terms, filtering, reporting, blocking, moderation, and a
  new App Review assessment.

## Digital Services Act

- App Store Connect requires a DSA trader-status declaration for EU
  distribution.
- Trader/non-trader status, legal name, address, phone, email, verification,
  and display choices are portal/legal-entity facts and remain pending.
- If the entity cannot complete the required DSA verification, remove EU
  territories from the initial approved availability rather than guessing.

## Agreements, tax, and banking

- Confirm Apple Developer Program membership and all required agreements.
- Free distribution without IAP may not require banking, but portal status is
  authoritative.
- Complete tax/banking agreements before offering any paid app or IAP.

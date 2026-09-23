# App Review information template

Status: template only. Actual contact details and demo access must be entered in
App Store Connect. Never commit passwords, OTPs, private phone numbers, API
keys, identity documents, payment credentials, or production tokens.

## Required portal fields

- Contact first name: `[portal-only]`
- Contact last name: `[portal-only]`
- Contact phone: `[portal-only]`
- Contact email: `[portal-only]`
- Sign-in required: Yes for some journeys
- Demo account name: `[portal-only]`
- Demo password/access secret: `[portal-only]`

## Suggested review notes

Gikundiro is a supporter-services app for Rayon Sports FC. It supports a guest
session and optional phone authentication. On first launch, complete onboarding
and select **Continue without signing in** for guest-safe content.

Use the dedicated non-expiring review access entered above for restricted
membership, transaction-history, and account-deletion journeys. The review
identity contains fictitious seeded records and may be deleted during review.

Account deletion is available at **Profile > Edit profile > Delete account**.
The destructive action requires entering the localized confirmation phrase.

Notifications are optional. The app must continue to work if permission is
denied. Photo-library add access is requested only after the reviewer explicitly
chooses to export a QR image; the app does not request photo-library read access.

The shop contains physical merchandise and ticketing concerns real-world event
access. Where enabled, the app hands an authorized mobile-money payment to the
system dialer. Review does not require or authorize a real payment. Seeded
pending and confirmed records are available through the review access.

In build `1.0.3 (6)`, production store policy disables staked challenges,
jackpots, reward redemption, partner offers, FET transfer/manual redemption,
social discovery, and cross-user editable text. The candidate migration revokes
the corresponding public-client RPCs. Earned-points history and ordinary free
sports-prediction context may remain, but no purchase, withdrawal, stake,
cash/real-world prize, or reward claim is enabled.

Public supporter labels use system-controlled aliases. User-chosen display names
and challenge notes are not exposed to other users in this candidate. Any future
enablement requires a new binary and updated moderation/review evidence.

## Review-path acceptance gate

- [ ] Guest flow works on a clean App Store/TestFlight install.
- [ ] Non-expiring review access reaches every marketed feature.
- [ ] No personal device, expiring OTP, or employee intervention is required.
- [ ] No real MoMo payment or production admin action is required.
- [ ] Backend and public URLs remain available throughout review.
- [ ] Seed data contains no real supporter information.
- [ ] Reviewer can execute account deletion on a disposable review identity.
- [ ] Exact disabled feature-policy and migration boundary is included in the portal notes.
- [ ] Partnership/trademark authorization is attached if Apple requests it.

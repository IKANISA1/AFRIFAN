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

Predictions, points, rankings, rewards, and any challenge surface are controlled
by production feature configuration. In the submitted store candidate, list the
exact enabled states here. The app is not presented as real-money gambling; any
enabled FET points must not be purchasable, withdrawable, or redeemable for cash
or an unapproved real-world prize.

If user-chosen display names or notes are enabled, describe the exact reporting,
blocking, filtering, moderation, and support controls here. Otherwise confirm
that the candidate exposes only system-controlled aliases and that social/user
text features are disabled.

## Review-path acceptance gate

- [ ] Guest flow works on a clean App Store/TestFlight install.
- [ ] Non-expiring review access reaches every marketed feature.
- [ ] No personal device, expiring OTP, or employee intervention is required.
- [ ] No real MoMo payment or production admin action is required.
- [ ] Backend and public URLs remain available throughout review.
- [ ] Seed data contains no real supporter information.
- [ ] Reviewer can execute account deletion on a disposable review identity.
- [ ] Exact enabled feature flags are included in the portal notes.
- [ ] Partnership/trademark authorization is attached if Apple requests it.


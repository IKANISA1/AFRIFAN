# Google Play reviewer-access template

Status: template only. Do not add passwords, OTPs, API keys, private phone
numbers, identity documents, payment credentials, or live pairing tokens to the
repository. Actual access belongs only in the authenticated Play Console.

## Access declaration

Select: **All or some functionality is restricted**.

## Suggested reviewer instructions

1. Launch Gikundiro.
2. Complete the short onboarding sequence.
3. Choose **Continue without signing in** to create the review guest session.
4. Public and guest-safe journeys include the home feed, published fixtures,
   results, club information, and any feature currently enabled for guests.
5. For membership, saved tickets/orders, account deletion, phone-auth, or other
   restricted journeys, use the dedicated review access supplied in Play
   Console under these instructions.
6. Account deletion is under **Profile > Edit profile > Delete account** and
   requires typing the localized confirmation phrase.
7. Notification permission is optional; denying it must not block the app.
8. Do not make a real MoMo payment. The review environment must provide seeded
   confirmed records or a review-safe route that exercises the UI without a
   financial transaction.

## Portal-only values

- Review access label: `Gikundiro store review`
- Login method: `[choose the actual non-expiring review method]`
- Username/phone/account: **enter only in Play Console**
- Password/PIN/OTP: **enter only in Play Console**
- MFA/OTP bypass or reusable review flow: **document only in Play Console**
- Required location, device, or network setup: `[portal-only]`
- Seeded states available: `[portal-only list]`

## Required seeded review states

- guest/public content;
- phone-authenticated supporter profile;
- pending and confirmed membership state;
- published ticket plus pending and confirmed ticket examples;
- merchandise cart plus pending and confirmed order examples;
- contribution history with privacy-safe fictitious data;
- football prediction state only if enabled in the submitted release;
- account deletion on a disposable review identity.

## Acceptance gate

- Access remains valid for the full review period.
- It does not depend on an employee's personal device or one-time code.
- Every feature mentioned in metadata is reachable.
- Seed data contains no real supporter information.
- Review does not require a real payment, cash-value reward, production admin
  action, or out-of-band human intervention.
- Instructions were tested from a fresh store-installed build.

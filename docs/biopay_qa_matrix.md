# BioPay QA Matrix

## Scope

This matrix covers the current shipped BioPay flows:

- Hub routing
- Face enrollment
- Face pay review
- QR receive
- QR pay scan
- NFC receive
- NFC pay scan
- Recovery and result states

## Automated coverage

| Area | Verification |
|---|---|
| Hub routing | `flutter test packages/features/feat_BioPay/test/BioPay_routing_test.dart` |
| Review privacy | `flutter test packages/features/feat_BioPay/test/BioPay_review_and_privacy_test.dart` |
| Payment intent contract | `flutter test packages/features/feat_BioPay/test/BioPay_repository_test.dart` |
| Edge function amount binding | `deno test --allow-env --allow-net --allow-read supabase/functions/BioPay-create-payment-intent/payment_intent_test.ts` |

## Manual scenarios

### 1. Hub and Settings

- Open BioPay from Settings and confirm `BioPay Home`, `Face ID & Enrollment`, `QR Receive & Pay`, and `NFC Receive & Pay` all route correctly.
- Sign in with no linked MOMO route and confirm the hub blocks BioPay actions behind `Link Mobile Money`.
- Sign in with linked MOMO but no BioPay profile and confirm the hub offers `Enroll Face ID`.

### 2. Face enrollment

- Enter a valid phone number and confirm registration proceeds to camera capture.
- Enter an invalid phone number and confirm inline validation blocks progress.
- Switch to merchant code mode and confirm invalid code formatting is blocked locally.
- Decline consent and confirm enrollment cannot continue.
- Complete five stable captures and confirm enrollment returns to BioPay with a success message.

### 3. Face pay

- Start face pay and confirm the scanner does not open the dialer directly on match.
- Complete a successful match and confirm the review screen shows alias, masked route, match confidence, and amount entry.
- Leave amount empty and confirm review blocks submission.
- Enter a valid amount and confirm the result screen reports that the payment dialer opened.
- Force device-auth unavailable/locked-out and confirm the recovery screen appears instead of a snackbar-only failure.

### 4. QR receive and pay

- Open QR receive and confirm only alias and masked route are shown.
- Set an amount and confirm the QR refreshes with the new requested amount.
- Share the QR and confirm the resolver URL is populated.
- Scan a valid BioPay QR and confirm the flow goes to review before payment handoff.
- Scan an invalid QR and confirm the scanner stays in-place with a retry path.

### 5. NFC receive and pay

- On an Android device with HCE support, activate receive mode and confirm a signed request is exposed.
- On a device without HCE, confirm the screen explains the limitation and offers recovery guidance.
- Scan a valid NFC request and confirm the flow goes to review before payment handoff.
- Scan an invalid NFC target and confirm a clear inline error is shown.

### 6. Recovery and result states

- Force camera denial and confirm the camera recovery screen appears.
- Force NFC disabled and confirm the NFC recovery screen appears.
- Trigger a payment handoff failure and confirm the result screen offers retry and back actions.
- Revoke BioPay enrollment and confirm success routes to the result screen, then the hub reflects the unenrolled state.

## Release gate

BioPay is release-ready only when:

- Dart analysis passes for `feat_BioPay` and `feat_settings`
- BioPay Flutter tests pass
- `BioPay-create-payment-intent` Deno tests pass
- All manual scenarios above are signed off on a device set that includes:
  - Android with NFC/HCE
  - Android without NFC/HCE
  - iOS or simulator path for camera/device-auth messaging

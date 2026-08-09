# Google Play reviewer-access instructions — Gikundiro TV

Status: template. Put the final instructions and any time-limited access data in
Play Console, not in Git.

## Reviewer journey

1. Install the submitted Android TV build on a compatible Leanback device.
2. Launch **Gikundiro TV**. The first screen creates a temporary pairing
   challenge and QR code.
3. Using the publisher-controlled reviewer owner account supplied privately in
   Play Console, open the mobile/owner pairing flow and approve the displayed
   challenge.
4. Assign the reviewer display to the synthetic review session named in the
   console instructions.
5. On the TV, verify lobby, question, reveal, public-alias standings, completed,
   offline/retry, and revoked/expired recovery behavior.
6. The TV must not request a supporter login, payment, participant entry code,
   private balance, reward claim, purchase, ticket, or order.
7. The exact production display content is Kinyarwanda with English fallback for
   platform-provided Material text. English/French golden previews are test
   evidence, not proof of an in-app language selector.

## Portal-only values

- Reviewer contact name, email, and phone
- Time window and timezone for the synthetic session
- Owner-review account credentials or access mechanism
- Temporary pairing/assignment instructions
- Support contact for access failure

Never commit passwords, one-time codes, device credentials, real pairing codes,
production session identifiers, identity evidence, or private contact details.
The release owner must test the exact instructions from a clean device and keep
the synthetic session available through the review window.

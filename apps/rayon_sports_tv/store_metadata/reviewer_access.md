# Google Play reviewer-access instructions — Gikundiro TV

Status: template. Put the final access mechanism and support details in Play
Console, not in Git. The TV build requires the companion Gikundiro mobile app;
the TV build alone cannot claim a display or organize a session.

Backend status: production migration `20260809140058` is applied and the full
local database contract passes 277/277. This proves shipping-build protocol
compatibility only; the synthetic reviewer identity, fixed OTP, entitlements,
published pack, companion-store distribution, and clean-device journey remain
portal/runtime prerequisites below.

## Release-owner prerequisites

- Supply the reviewer with the companion mobile build and a private, reusable
  sign-in method that remains valid throughout review. Do not depend on an
  employee relaying a one-time phone or WhatsApp code.
- Use a dedicated synthetic account that is an active, verified, unexpired club
  member with only the active club-level `game_organizer` role. Do not grant
  club-admin, venue, or service roles.
- Preseed one published synthetic question pack containing exactly 20 reviewed,
  non-sensitive questions.
- Keep both apps pointed at the same production backend. Test the instructions
  from clean TV and mobile installations before entering them in Play Console.

## Reviewer journey

1. Install the submitted Android TV build on a compatible Leanback device and
   install/open the supplied companion Gikundiro mobile build.
2. Launch **Gikundiro TV**. The first screen creates a temporary pairing
   challenge and QR code. The eight-character challenge expires quickly and is
   single-use; select **New code** if it expires.
3. Sign in to the companion mobile app with the synthetic reviewer access
   supplied privately in Play Console. In **Settings**, under **Games and TVs**,
   open **Game operations > My TVs > Pair a TV**. Enter the eight-character
   challenge, name the display **Play Review TV**, choose **Home**, and pair it.
4. Return to **Game operations**, open **Games I manage > Plan a game**, select
   the supplied 20-question synthetic pack, choose **Owners of assigned home
   TVs**, select **Play Review TV**, choose a start time, and select **Create
   scheduled game**. Creation atomically assigns the claimed display and opens
   **Live game control**; no pre-existing-session assignment screen is required
   or available in this journey.
5. From **Live game control**, open the lobby, open question 1, reveal its
   answer, and advance. Confirm the TV first shows question 1 only after it is
   opened, then shows question 2 after the advance. Continue as needed to verify
   public-alias standings, completion, offline/retry, and expired/revoked-device
   recovery behavior.
6. The TV must not request a supporter login, payment, participant entry code,
   private balance, reward claim, purchase, ticket, or order.
7. The exact production display content is Kinyarwanda with English fallback for
   platform-provided Material text. English/French golden previews are test
   evidence, not proof of an in-app language selector.

## Portal-only values

- Reviewer contact name, email, and phone
- Reviewer access credentials or reusable sign-in mechanism
- Synthetic club and question-pack names
- Support contact for access failure

Never commit passwords, one-time codes, device credentials, real pairing codes,
production session identifiers, identity evidence, or private contact details.
The release owner must keep the synthetic account, role, membership, pack, and
companion mobile build available throughout the complete review window.

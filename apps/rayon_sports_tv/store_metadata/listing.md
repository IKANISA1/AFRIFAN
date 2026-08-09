# Gikundiro TV

## Google Play title

Gikundiro TV

## Short description

Read-only Rayon Sports venue display for approved live fan activities.

## Full description

Gikundiro TV is a read-only display for approved Rayon Sports venue and matchday activities.

An authorized owner pairs and assigns the display from the supported owner workflow. The TV then shows the approved session lobby, current question and choices, answer reveal, public-alias standings, final result, completion, and privacy-safe recovery states.

The public display does not accept participant entry codes. It does not show supporter identity, account credentials, private balances, reward claims, purchases, tickets, merchandise orders, or payment controls.

Internet access and a valid approved display assignment are required. Session availability depends on club operations and the configured service.

The current Rayon Sports display content is presented in Kinyarwanda, with English fallback for platform-provided interface text. The app does not currently offer a user-selectable TV language.

## Classification

- Category: Sports
- Audience: managed venue devices; not designed for children
- Preferred distribution: managed/private; a public Android TV listing requires separate product, rights, audience, and policy approval
- Advertising: none found in the current TV source
- Purchases: none in the TV app
- Account creation: none in the TV app; the display uses a temporary owner pairing flow and a device credential

Support, privacy, and account-deletion URLs must be verified in Play Console before release. The mobile account-deletion path is relevant only to supporter accounts; the TV app stores a revocable device credential, not a supporter account.

## Artwork plan

Capture the pairing, live question, reveal/standings, offline/retry, and revoked/expired states from the exact signed candidate at 1280x720 or higher. Use only synthetic sessions and public aliases; never expose real pairing codes, device credentials, supporter information, balances, payments, or production session data. See `artwork_manifest.json`.

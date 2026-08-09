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
- Intended use: authorized venue displays; not designed for children
- Distribution intent: public Google Play TV listing; internal testing is the current pre-production stage and public promotion remains approval-gated
- Advertising: none found in the current TV source
- Purchases: none in the TV app
- Account creation: none in the TV app; the display uses a temporary owner pairing flow and a device credential

Support, privacy, and account-deletion URLs must be verified in Play Console before release. The mobile account-deletion path is relevant only to supporter accounts; the TV app stores a revocable device credential, not a supporter account.

## Artwork plan

The current store set contains two genuine 1920x1080 API 36 AVD renders: the service-unavailable state from a same-TV-source validation release APK, and a Kinyarwanda synthetic reveal/public-alias standings state rendered by the current Flutter TV interface through its existing preview-state boundary. Neither is claimed as a Play-delivered production-AAB capture. The required 1024x500 feature graphic is checksum locked and uses only the project-owned Gikundiro visual language. Add pairing, live-question, offline/retry, and revoked/expired states only from an authorized synthetic internal-test session at 1280x720 or higher; never expose real pairing codes, device credentials, supporter information, balances, payments, or production session data. See `artwork_manifest.json`.

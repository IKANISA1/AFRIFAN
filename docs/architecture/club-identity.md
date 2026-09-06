# Club identity and history

The Club overview now presents the registered crest, full name, roots, current
base, colours and supporter identity before the existing club destinations.
History and membership have direct actions. The page retains the selected
LIVE-021 petrol header and LIVE-007 grouped surfaces, with localized controls,
200% text reflow and an inset scroll viewport below the native status bar.

## Source and scope

On 6 September 2026, Gikundiro's `PublicClubModel.js`, `PublicClubPage.jsx`,
`src/data/content.js`, club-content migration and live approved/public records
were reviewed. The imported facts for `rayon_sports_rw` are:

| Field | Published value |
| --- | --- |
| Full name | Rayon Sports Football Club |
| Roots | Nyanza, Southern Province, Rwanda |
| Current base | Kigali, Rwanda |
| Colours | Blue and white |
| Supporter identity | Gikundiro |

The three published history/identity records are “Roots in Nyanza”, “Based in
Kigali” and “Gikundiro”. Their record identifiers, source labels and source URLs
are retained in the database. Disputed founding dates and unverified honours
are omitted. Gikundiro's own fan platform is not represented as an official
club website. Published dynamic content remains in its source language (English);
the new interface labels are translated into English, French and Kinyarwanda.

The prior crest URL pointed to an HTML page. It is replaced by Gikundiro's
registered blue-and-white competition crest. Its exact public bytes are also
bundled for offline display, scoped to the Rayon slug. Other clubs receive
their own published image or initials. See the
[asset source record](../../packages/features/feat_club/assets/crests/SOURCES.md)
for checksum and retained rights-review status.

## Data contract

Migration `20260906090100_gikundiro_club_identity.sql` adds an object-valued
`club_profile`, history source fields and two narrow public projections:

- `club_public_overview(bigint)` exposes only the active club's public identity.
- `club_public_history(bigint)` exposes only its approved, active app history.

Both functions use a fixed empty search path, explicit club filtering and
restricted execution grants. Public clients gain no broad access to the master
club registry, contact details or market research. The mobile gateway uses these
RPCs instead of relying on direct registry access.

Only the row matching ID 24 and slug `rayon_sports_rw` receives source data.
Six duplicated marketing-history rows are deactivated and retained for
traceability. Three source records are upserted through unique source keys.
Source upserts use stable identifiers and do not replace other clubs' content.

## Verification and delivery

The migration was applied to AFRICLUB and independently found in the remote
migration ledger. A transaction using the anonymous database role returned the
corrected crest, source facts and exactly three published history records.
The clean local migration replay passed 92 pgTAP assertions across Club, Predict,
RPC security and repository boundaries, plus three concurrency scenarios.

Club widget, model, localization and route-golden tests pass. The iPhone 13 /
iOS 26.5 integration journey checks overview content and navigation into history
using an injected public-data fixture; its system screenshots are local review
evidence. They do not establish live API or physical-device behavior.

Supabase's public API remains blocked by storage quota (HTTP 402), so production
API verification and supporter access remain blocked. The broader current
workspace UI guardrail suite also reports shared-control violations in Predict
and its admin screen; those files are outside this Club change. The Club media
and deleted-asset checks are covered by the narrowly registered crest exception.
Full reference pixel equivalence and public mobile release are not claimed.

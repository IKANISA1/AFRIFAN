# Rayon Sports / Gikundiro content parity checkpoint

Observed on 23 September 2026. This is a read-only comparison of the standalone Gikundiro Supabase project and the separately configured AFRICLUB database. It is a working inventory, not a release approval or a claim that the two projects share identifiers, media rights, or payment state.

| Surface | Standalone Gikundiro public records | Configured AFRICLUB Rayon rows | Gap to close |
| --- | ---: | ---: | --- |
| News | 43 approved, active, public; 28 published within three calendar months | 3 `news_articles` rows, without publication filtering in this count | Reconcile exact story URLs, publication dates, attribution and approved media before native publication. |
| Squad | 39 approved, active, public players; six linked approved portraits | 0 `squad_players` rows | Confirm the current roster and exact player media, then publish mapped native profiles. The standalone directory currently displays the six portrait-complete players. |
| Shop | 15 approved, active, public rows; two have exact current-season registered media without generated or review-required rights | 5 `shop_products` rows, without publication filtering in this count | Replace supplier-photo-pending and generated catalogue media, confirm prices and variants, then classify enquiry versus checkout per product. |
| Partners | 3 approved, active, public rows with logo references | `club_partner_publications` table absent from this configured database | Replay the candidate schema, check logo rights, and publish explicitly mapped partner records. |
| Fanclubs | 42 approved, active, public rows | 65 `fan_clubs` rows, without mock/public filtering in this count | Reconcile chapter identity, location, joining behavior and public counts. Names alone are insufficient to merge records. |
| Tickets | 18 approved, active, public sales; 15 with future kickoff dates, all in reservation-only mode | No ticket comparison made | Verify each future sale, category, MoMo instruction and fulfillment path with current club operations. Reservation is not paid ticket issuance. |
| Fixtures and Predict | 99 future, approved, active, public, confirmed `prediction_fixtures` among 1,770 approved active rows; 99 pools currently open | 0 `unified_matches` rows | Map only current confirmed fixtures through the football feed; do not import historical or unconfirmed prediction rows as live matches. Verify FET settlement against confirmed results separately. |
| Membership | 6 approved, active, public tiers | No tier comparison made | Confirm programme and payment rules in each product before cross-project publication. |

The standalone remote verification passed its table, RPC, RLS, media-bucket and scheduled-job checks; its revised Shop check reports the two media-ready products. The public Shop, product metadata and sitemap in the local candidate now apply the same current-season media gate. The live website still shows all 15 products until a deployment, and the other 13 rows remain marked public in Supabase; the client-side gate is not a database publication change. Its local validation and 249 unit tests passed, and Vite built. The AFRICLUB web club-profile query previously omitted its contact, social and crest fields; the current change reads those fields and retains the configured short club label. AFRICLUB web passed 960 tests, lint on changed files, TypeScript checks and a Next production build. None of these checks proves provider payment, installed-device behavior, or deployment of the local AFRICLUB migrations.

## Publication sequence

1. Capture a versioned snapshot of approved public source rows with source URLs, effective dates, media asset IDs and usage rights. Treat missing exact rights or a stale season as an unpublished candidate.
2. Replay and validate the AFRICLUB candidate schema against an isolated database. The configured remote database lacks the local partner-publication and public-link tables, so live imports cannot safely start there.
3. Build explicit source-path-to-native-ID mappings for player, story, product, partner and fanclub records. Verify current publication on both sides; never assume equal UUIDs across projects.
4. Exercise the public site and native app with that approved snapshot, including empty states, deep links, ticket payment return, member verification and low-connectivity recovery.
5. Verify staging deployment, actual WhatsApp/MoMo outcomes, physical devices and owner review before production publication.

The standalone Gikundiro repository remains the source for `gikundiro.com`; AFRICLUB has its own database and native product. This checkpoint does not authorize a cross-project database write or a website deployment.

## Fixture, Predict and news runtime check

Read-only database and code check on 23 September 2026:

- Standalone Gikundiro reads approved public `prediction_fixtures` and open `prediction_pools` from its configured Supabase project. There are 99 future confirmed fixtures with open pools. The public Predict client now requires `schedule_status = 'confirmed'` before it shows or enables a prediction. Member submissions go through `member-portal-api` and the `place_gikundiro_prediction` database RPC; no authenticated payment or settlement transaction was exercised in this check.
- The standalone fixture directory reads its own approved `fixtures` rows and confirmed Rayon fixtures from `prediction_fixtures`. The `fixtures` table currently has zero approved public rows; the confirmed Rayon prediction source has 15 future fixtures. There are 15 `fixture_source_publications` records. The official Rwanda Premier League import parser and publication tables exist, but this check did not confirm a fresh official source import or result settlement.
- Standalone news reads approved, active, public, published `news_posts` from Supabase, bounded to the preceding three calendar months and no later than the current time. The database contains 28 such recent posts. Its newsroom maps source links, editorial/feed type, imagery, categories and article routes. Feed ingestion and publication code exists; this check did not run a fresh ingestion cycle or authorize an article.
- AFRICLUB is connected to a separate database. Its configured Rayon `unified_matches` view currently returns zero rows and `news_articles` has three rows before public filtering. The standalone records have not been imported into AFRICLUB, so its fixture, Predict and news surfaces do not yet have the standalone site's complete real catalogue.

## App-only Gikundiro public data integration — 24 September 2026

The current task is the Rayon Sports AFRICLUB app. No standalone website deployment is required for this app read path. The native app and Rayon web server read approved public records directly from the existing Gikundiro Supabase project with its public anonymous key. Source credentials are never used for member authentication or writes; generated app builds carry only the public key. Other AFRICLUB clubs keep their own data source.

| App surface | Source and publication rule | App behavior |
| --- | --- | --- |
| Club fixtures and Home hero | Approved, active, public, future, confirmed `prediction_fixtures`; exact Rayon participant, registered source publication and HTTPS source URL | Live source reads map to 15 eligible future Rayon fixtures as checked on 23 September; no ticket-sale claim or score is synthesized. |
| Predict schedule preview | The same approved Rayon fixtures used by Club and Home | When AFRICLUB Predict is unavailable, show real upcoming matches as read-only cards without picks, stakes, FET balances or a submission path. |
| Club News and Home latest stories | Approved, active, public, published `news_feed` posts within three calendar months; complete title, excerpt, date and HTTPS original URL | 28 recent stories at the source check; cards open app details with a link to the original publisher and no unapproved generic image. |
| Squad | Approved, active, public players and separately approved squad-scoped media | 39 public players, six with approved portrait references at the source check. |
| Fanclubs | Approved, active, public fanclub register | 42 public chapters; unapproved member counts stay hidden. |
| Partners | Approved, active, public partners with approved partner-scoped logo media | Three source-backed partner records are eligible for the Club directory and Home preview. |
| Shop | Approved, active, public marketplace products with exact current-season status and registered shop-scoped media | Two of 15 public source products currently qualify; the app uses WhatsApp enquiry mode and never routes those records to its cart or payment path. |

The web source adapter now reads Supabase directly instead of relying on the undeployed `/api/public/rayon-content` Pages Function. The native Club, Home, Fanclubs, Partners and Shop adapters use the same public project. The live web adapter smoke test passed, the native mapping tests passed, and the source REST queries returned the counts above. The native client was not exercised on a physical device in this check.

Prediction entries, FET wallets, ticket purchases, paid membership and order settlement remain separate AFRICLUB transactions. They cannot be made functional by copying Gikundiro public IDs: the projects have different authentication and ledger authority. Native Predict now has a source-backed read-only fixture preview, while actual picks remain subject to its store-release policy and the AFRICLUB `predict_dashboard` / `predict_place` RPCs. Ticket sales in the Gikundiro public source are reservation-only and must not be represented as paid app tickets.

The configured AFRICLUB Supabase project still reports `exceed_storage_size_quota` on its platform configuration RPC during the 24 September Next production build. The build compiled, but that provider restriction prevents target-project journeys from being accepted as live. After the project service is restored, verify actual club scope, route flags, authorized member prediction, ticket and membership transactions, and physical-device behavior before app release. The large recovered working tree also requires a scoped release diff so unrelated changes are not shipped.

The updated Android debug APK compiled with the production-local app configuration on 24 September. Focused native source-mapping and read-only Predict preview tests passed, and Dart analysis of the changed integration files found no issues. One existing large-text Predict golden failed with a 0.10% pixel difference in the broad screen suite; its fixture-preview branch is disabled under that test configuration. Review the image baseline before accepting the full visual suite. No physical-device or store release check was performed.

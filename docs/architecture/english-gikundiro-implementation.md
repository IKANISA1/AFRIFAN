# Rayon Sports: English-only implementation and Gikundiro improvements

6 September 2026 · Local implementation handover · AFRICLUB

The maintained app and web code now use English only. The implementation addresses the main navigation, content, membership-truth, merchandise and Predict issues identified in the Gikundiro comparison, while retaining the selected Revolut screen patterns and Rayon Sports identity. The candidate is local: three database migrations are prepared, and their SQL/PLpgSQL syntax is checked, but they have not been executed against PostgreSQL or deployed. Several findings still require published content, cross-project agreement or device/provider evidence.

The original [critical comparison](/Volumes/PRO-G40/AFRICLUB/output/reviews/gikundiro-rayon-2026-09-06/comparative-review.md) remains the dated baseline. This document records the changed candidate and the remaining work for every finding. The owner's English-only instruction supersedes the baseline's multilingual recommendation.

## What changed

| Area | Current implementation |
| --- | --- |
| English-only | One English ARB and generated catalogue; fixed app/framework locale; English profile normalization and runtime copy; all 20 club configurations; English public/admin web; removed translation dictionaries, language selectors, French store listings and the retired Kinyarwanda listing source; CI policy guard. |
| Football discovery | Earlier Club tasks, portrait squad and player details, team/position filters, one news reader, approved media/source links, Partners and explicit public URL mapping. |
| Data truth | Current-match windows; membership qualification independent from FET; published membership prices; no runtime sample product; enquiry/native order capability; stale/denied data recovery. |
| Predict | Clear unavailable state inside the primary tab, selection review, explicit cost/balance/confirmation, safe cancel and retained reconciliation controls. |
| Fanclubs and search | Truthful joining-options label, refresh on return, explicit/deduplicated featuring, partial search results and filtering before limits. |

Proper names such as Gikundiro and Amahoro, club/player names, ISO RW/RWF codes, stable identifiers and historical migration records remain. These are not additional supported languages. The change does not rewrite the separate Gikundiro repository, old installed binaries, external app-store listings or unreviewed remote editorial content.

## Visual contract

| Surface | Retained source pattern | Rayon Sports adaptation |
| --- | --- | --- |
| Home | Blue-to-navy command layout; compact top controls; four actions; floating tabs | Relevant match and one rights-approved editorial object in the early scroll. |
| Club | Cyan/petrol proposition and grouped discovery | Compact identity followed by football destinations; long history stays secondary. |
| Predict | Violet/blue rewards discovery and grouped task surfaces | Fixtures, picks and FET activity, with a neutral confirmation sheet. |
| Membership | Purple membership card followed by neutral information | Verified contribution qualification and separate published offers. |
| Shop | Owner-selected purple/indigo editorial-card pattern | Actual product imagery, prices, variants and capability-specific actions. |
| Child tasks | Neutral grouped lists, details, errors and forms | Player, news, Partner and website-resolution tasks with consistent recovery. |

The [reference map](/Volumes/PRO-G40/AFRICLUB/docs/governance/native-reference-map.json) now identifies 90 mobile/system route entries and the Predict review sheet. Private source assets remain outside runtime assets and this handover. Target screenshots establish regression behavior; they do not certify exact source equivalence. Source font/build/viewport information and several source state/device comparators are missing, so **100% visual fidelity is not certified**. The selected visual direction remains the implementation target.

## Verification

| Check | Result and scope |
| --- | --- |
| Flutter regression | 2601 tests passed in core, data, features, registry, club configurations and Rayon app tests. A final focused Predict capability rerun also passed 29 tests; these overlap with the combined count. See [final log](/Volumes/PRO-G40/AFRICLUB/output/implementation/english-gikundiro-2026-09-06/complete-flutter-verification.log). |
| Static analysis | passed; [analysis log](/Volumes/PRO-G40/AFRICLUB/output/implementation/english-gikundiro-2026-09-06/analysis-final.log). |
| Web | 258 tests / 31 files passed using Node 22.23.2; TypeScript and ESLint completed without errors. |
| English copy controls | One catalogue, 20 club configurations, web/store policy; 77 static and 323 dynamic copy candidates reviewed, zero pending. The dynamic review classifies names/editorial fields; it does not translate or certify remote content automatically. |
| New screens | 56 player/Partner/public-link golden state cases passed. A further behavior test verifies that permission revocation hides retained Club content. |
| iOS | Club and Predict journeys passed with five system captures each. Full application smoke: passed; five application tests, seven harness results including setup/teardown. No production payment or message was sent. |
| Metadata and governance | 12 store-metadata tests passed. Repository/copy/migration/evidence validator tests passed. See control-results.json and governance-tests.log for exact scope. |
| Database | SQL and PL/pgSQL syntax checked; pgTAP contract prepared. PostgreSQL replay was not run because Docker remained unresponsive and no local PostgreSQL runtime was installed. |

These counts identify different suites; focused rerun counts must not be added to the combined Flutter count. Golden regeneration was followed by comparison runs without --update-goldens. The gallery distinguishes Flutter test images from actual iOS Simulator captures. All gallery data is synthetic or app-owned; it is not evidence of current published club inventory or membership.

## Database and content sequence

The candidate reads new columns and RPCs. Apply and verify the schema before distributing the binary; otherwise the affected screens will correctly show unavailable content rather than the intended populated state.

1. Execute the isolated migration replay and pgTAP harness (`python3 tools/scripts/test_predict_database.py`) when Docker is healthy. Its new contract covers English normalization, own-club access, contribution eligibility/windows, mapping revocation and cross-club rejection. Syntax parsing alone cannot establish those outcomes.
2. Review and apply the three forward migrations in timestamp order. The English migration normalizes profile/club preferences and removes non-English runtime-copy rows. The public-content migration adds squad groups, featuring, source links, approved Partners, entity mappings and a separate membership programme. The commerce migration adds enquiry/native capability and enforces it in the order function.
3. Publish the actual English content contract: approved player media/groups, original story URLs/provenance, current Partners, featured chapters, catalogue capability and contacts, explicit entity mappings, qualification initiatives/thresholds and published membership offers. The programme defaults to unpublished, and no categories or rights approvals are invented.
4. Verify the same current entities across web and app, then run a read-only approved-content iOS/Android parity pass. Verify authentication, payment reconciliation, fulfilment and ticket admission separately with their actual providers/operators.
5. Record the shipped binary, applied migrations, content revision and public/store state. No deployment, store submission or remote content publication was performed in this task.

## English vocabulary

- **Membership status:** the canonical club programme response; never inferred from FET.
- **Confirmed contributions:** qualifying, confirmed RWF contributions within the published rolling window.
- **FET balance:** engagement points; distinct from money, membership qualification and purchased benefits.
- **Membership offer:** a published club package with its real price, classification and benefits; separate from calculated qualification.
- **Enquiry:** a draft about a product; opening it is not sending it, ordering it or paying for it.
- **Confirmed ticket:** a server-issued credential after the supported payment/issuance process; a payment intent is not admission.

## Status of the 28 review findings

“Implemented locally” means the app-side change has local evidence. “Publication pending” adds a schema/content dependency. “Partial” identifies a remaining product or integration decision. “Validation pending” and “integration pending” remain open acceptance work. None of these labels means deployed or store-approved.

| ID | Priority | Finding | Status |
| --- | --- | --- | --- |
| F01 | P1 | Define one cross-channel content authority | Partial |
| F02 | P1 | Select the relevant match before limiting history | Implemented locally |
| F03 | P1 | Stop deriving membership identity from FET | Implemented; publication pending |
| F04 | P1 | Reconcile membership packages with contribution-based categories | Partial |
| F05 | P1 | Remove the synthetic product from public runtime behavior | Implemented locally |
| F06 | P1 | Choose and label the merchandise order model | Implemented; publication pending |
| F07 | P2 | Make public browsing resilient to sign-in failure | Implemented locally |
| F08 | P1 | Make Club a football hub before a club biography | Implemented locally |
| F09 | P1 | Add player portraits and a real squad-to-profile flow | Implemented; publication pending |
| F10 | P1 | Unify the two mobile news experiences | Implemented; publication pending |
| F11 | P2 | Restore club emotion without losing native speed | Implemented locally |
| F12 | P1 | Show the real fanclub relationship and next action | Partial |
| F13 | P2 | Reduce fanclub repetition and improve chapter discovery | Implemented; publication pending |
| F14 | P2 | Add a governed partner directory | Implemented; publication pending |
| F15 | P1 | Map Gikundiro URLs to native entities explicitly | Implemented; publication pending |
| F16 | P2 | Make search partial failures and relevance deliberate | Implemented locally |
| F17 | P1 | Explain unavailable Predict capability without weakening its controls | Implemented locally |
| F18 | P2 | Make the 100 FET commitment intentional | Implemented locally |
| F19 | P2 | Explain what supporters can earn and use | Implemented locally |
| F20 | P1 | Prove ticket status continuity through payment and admission | Retained; integration pending |
| F21 | P1 | Update release checks to the current Predict navigation | Implemented locally |
| F22 | P2 | Preserve native accessibility and complete device-level proof | Partial |
| F23 | P2 | Validate merchandise with approved imagery and compact fallbacks | Implemented locally |
| F24 | P2 | Give missing and stale content a consistent meaning | Implemented locally |
| F25 | P2 | Use one clear vocabulary for membership, contributions and FET | Implemented locally |
| F26 | P2 | Add an approved-content native parity run | Validation pending |
| F27 | P3 | Measure content load and reduce avoidable serialization | Partial |
| F28 | P3 | Validate task success instead of judging parity by screenshots alone | Partial |

### F01 · Define one cross-channel content authority

**Partial.** Added a versioned club public-content manifest and explicit, publication-checked web-to-native entity mappings. Each resolution rechecks the club and current publication.

**Remaining acceptance:** Populate approved mappings and agree the authoritative identifier for each entity across both projects. Automatic cross-project content synchronization is not implemented.

**Code:** [supabase/migrations/20260906153000_public_content_and_membership_contract.sql](/Volumes/PRO-G40/AFRICLUB/supabase/migrations/20260906153000_public_content_and_membership_contract.sql)


### F02 · Select the relevant match before limiting history

**Implemented locally.** Home and Club use independently bounded live, upcoming and recent match queries. Upcoming ordering is explicitly ascending; cancelled and expired scheduled fixtures cannot consume the future window.

**Remaining acceptance:** Replay the database and verify the selectors against the actual club calendar. Failure of one calendar query currently fails that match window; other Home sections remain available.

**Code:** [packages/data/club_data/lib/src/repositories/public_match_window.dart](/Volumes/PRO-G40/AFRICLUB/packages/data/club_data/lib/src/repositories/public_match_window.dart)


### F03 · Stop deriving membership identity from FET

**Implemented; publication pending.** Removed FET-derived membership tiers and invented validity dates. Home and Membership use the canonical contribution-qualification response; missing truth produces an unavailable state. Revoked membership data is cleared.

**Remaining acceptance:** Apply and exercise the qualification RPC, then publish the real programme. No live member entitlement has been changed or certified.

**Code:** [packages/features/feat_membership/lib/src/providers/membership_provider.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_membership/lib/src/providers/membership_provider.dart)


### F04 · Reconcile membership packages with contribution-based categories

**Partial.** Prepared separate programme, qualifying-initiative and qualification-tier tables. Only confirmed, positive, non-mock contributions within the rolling year qualify. Purchase offers require current published club prices and benefits; hard-coded fallback packages no longer enter the runtime catalogue.

**Remaining acceptance:** Approve the programme thresholds, qualifying initiatives, effective rules and benefit classification. Confirm how contribution categories and purchased physical packages relate; the migration intentionally publishes no invented programme.

**Code:** [supabase/migrations/20260906153000_public_content_and_membership_contract.sql](/Volumes/PRO-G40/AFRICLUB/supabase/migrations/20260906153000_public_content_and_membership_contract.sql)


### F05 · Remove the synthetic product from public runtime behavior

**Implemented locally.** Removed the runtime sample-product recovery path and official sample overlay. Missing products stay missing; stale or unavailable product data cannot create a purchase.

**Remaining acceptance:** Read a current approved catalogue after deployment. Fixtures remain confined to tests.

**Code:** [packages/features/feat_shop/lib/src/screens/product_detail_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_shop/lib/src/screens/product_detail_screen.dart)


### F06 · Choose and label the merchandise order model

**Implemented; publication pending.** Added server-owned native/enquiry commerce modes. Enquiries preserve product, quantity and size in a WhatsApp draft. Product cards open enquiry details, and both the cart and prepared order RPC reject enquiry-only items.

**Remaining acceptance:** Classify the actual catalogue and verify supported fulfilment and payment recovery. Opening the draft does not send it or create an order.

**Code:** [supabase/migrations/20260906154500_commerce_capability.sql](/Volumes/PRO-G40/AFRICLUB/supabase/migrations/20260906154500_commerce_capability.sql)


### F07 · Make public browsing resilient to sign-in failure

**Implemented locally.** Public Club, news, squad, fixture and catalogue routes remain browsable when sign-in fails. Personal membership, credentials and transactions still require authentication. Returning from verification retains the requested destination.

**Remaining acceptance:** Complete physical-device testing with the actual authentication provider and low-connectivity conditions.

**Code:** [packages/core/core_router/lib/src/public_read_routes.dart](/Volumes/PRO-G40/AFRICLUB/packages/core/core_router/lib/src/public_read_routes.dart)


### F08 · Make Club a football hub before a club biography

**Implemented locally.** Club now has a compact identity header and early Team, News, Fixtures, Results, Standings and Partners entry points. Extended club history follows the football tasks.

**Remaining acceptance:** Populate current club identity and match content; retain the compact hierarchy when editorial content changes.

**Code:** [packages/features/feat_club/lib/src/screens/club_hub_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_club/lib/src/screens/club_hub_screen.dart)


### F09 · Add player portraits and a real squad-to-profile flow

**Implemented; publication pending.** Added portrait squad cards, position and team-group filtering, and a real player route with record-level loading. Player facts come from published records; missing portraits use a shirt-number fallback.

**Remaining acceptance:** Publish approved portraits and correctly classify first team, women, academy and staff. Complete the shared-ID mappings for website player URLs.

**Code:** [packages/features/feat_club/lib/src/screens/club_collection_screens.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_club/lib/src/screens/club_collection_screens.dart)


### F10 · Unify the two mobile news experiences

**Implemented; publication pending.** Home, Club, search and legacy news routes converge on the canonical reader. Approved media requires rights and provenance. Original article URLs are sanitized, tracking is removed, and canonical source URLs are deduplicated.

**Remaining acceptance:** Publish complete source URLs and media metadata. The link validator rejects obvious publisher/social profile links, but editorial review must still verify that each URL supports the story.

**Code:** [packages/features/feat_club/lib/src/repositories/club_content_gateway.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_club/lib/src/repositories/club_content_gateway.dart)


### F11 · Restore club emotion without losing native speed

**Implemented locally.** Home preserves its blue command layout and four clear actions, with a single approved editorial image in the early scroll. Club emotion is carried by actual identity and content rather than fabricated hero media.

**Remaining acceptance:** Review current approved photographs on the target devices. The source comparison remains a component-pattern adaptation, not exact all-state equivalence.

**Code:** [packages/features/feat_home/lib/src/screens/home_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/screens/home_screen.dart)


### F12 · Show the real fanclub relationship and next action

**Partial.** Removed the misleading request-status implication from the fanclub navigation action. It now says View joining options, opens the detail and refreshes on return.

**Remaining acceptance:** A new persisted joining-request backend was not invented. Confirm whether each chapter uses contact-based joining or an app-managed request before exposing pending/member/declined states.

**Code:** [packages/features/feat_fan_clubs/lib/src/screens/fan_clubs_list_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_fan_clubs/lib/src/screens/fan_clubs_list_screen.dart)


### F13 · Reduce fanclub repetition and improve chapter discovery

**Implemented; publication pending.** Featuring now requires an explicit published flag. The featured chapter is removed from the main list, and editorial featuring is hidden during filtering/search. Saved-list failures have recovery feedback.

**Remaining acceptance:** Assign featured chapters from the directory authority and verify current descriptions, locations and aggregate counts.

**Code:** [packages/features/feat_fan_clubs/lib/src/screens/fan_clubs_list_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_fan_clubs/lib/src/screens/fan_clubs_list_screen.dart)


### F14 · Add a governed partner directory

**Implemented; publication pending.** Added Partner list/detail routes, approved-logo rules, official website actions, club-scoped publications and publication/expiry controls. Recognition does not imply FET redemption.

**Remaining acceptance:** Publish approved partner records, dates, categories and logo provenance. No current sponsorship or reward entitlement is inferred from a fixture.

**Code:** [packages/features/feat_club/lib/src/screens/club_partners_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_club/lib/src/screens/club_partners_screen.dart)


### F15 · Map Gikundiro URLs to native entities explicitly

**Implemented; publication pending.** Static Gikundiro paths map explicitly to native destinations. Entity URLs use a scoped resolver with exact allowlists, publication checks, retry and an explicit website fallback. Traversal and unrelated destinations are rejected.

**Remaining acceptance:** Publish the approved entity mappings and test a cross-channel sample of actual URLs. Unmapped records deliberately remain on the website fallback.

**Code:** [packages/features/feat_club/lib/src/screens/club_public_link_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_club/lib/src/screens/club_public_link_screen.dart)


### F16 · Make search partial failures and relevance deliberate

**Implemented locally.** Search keeps successful collections when another fails, labels partial results, filters on the server before row limits, and sends player hits to the canonical profile route.

**Remaining acceptance:** Validate relevance and indexing with the live dataset. Bounded querying does not establish an empirically optimal search ranking.

**Code:** [packages/features/feat_home/lib/src/search/federated_discovery_search_repository.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/search/federated_discovery_search_repository.dart)


### F17 · Explain unavailable Predict capability without weakening its controls

**Implemented locally.** Unavailable Predict capability has its own state. The primary tab keeps its shell when unavailable; a denied capability gateway prevents reads and writes. Store and server controls remain enforced.

**Remaining acceptance:** Verify production feature configuration and backend version separately. A synthetic native success does not authorize or enable a live competition.

**Code:** [packages/features/feat_gamification/lib/src/predict/predict_controller.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_gamification/lib/src/predict/predict_controller.dart)


### F18 · Make the 100 FET commitment intentional

**Implemented locally.** Selecting a result opens a review showing fixture, selection, entry cost and balance after entry. Confirm is explicit; cancellation writes nothing. Pending and reconciliation locks remain.

**Remaining acceptance:** Complete VoiceOver/TalkBack and real network-interruption checks on a controlled release candidate.

**Code:** [packages/features/feat_gamification/lib/src/predict/predict_review_sheet.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_gamification/lib/src/predict/predict_review_sheet.dart)


### F19 · Explain what supporters can earn and use

**Implemented locally.** Added concise earning/usage explanations that separate FET from membership qualification and cash. Unavailable rewards make no redemption promise.

**Remaining acceptance:** Publish any real eligible reward catalogue only through its approved capability and operational process.

**Code:** [packages/features/feat_gamification/lib/src/predict/predict_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_gamification/lib/src/predict/predict_screen.dart)


### F20 · Prove ticket status continuity through payment and admission

**Retained; integration pending.** Retained server-issued ticket states and recovery controls and reran ticketing regressions covering pending/recovery behavior. The review did not justify replacing the existing payment state machine.

**Remaining acceptance:** Run the controlled payment-to-ticket-to-scanner scenario with the actual approved rail and venue operator. No payment, ticket issuance or admission was performed in this implementation.

**Code:** [packages/features/feat_ticketing/test/ticketing_state_test.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_ticketing/test/ticketing_state_test.dart)


### F21 · Update release checks to the current Predict navigation

**Implemented locally.** Updated navigation and smoke expectations to Home, Club, Predict and Membership. Route registries include the new public destinations. Native smoke also checks public browsing before a private-action sign-in.

**Remaining acceptance:** Keep production integration, store acceptance and source-fidelity evidence separate from the local smoke result.

**Code:** [apps/rayon_sports/integration_test/release_readiness_smoke_test.dart](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/integration_test/release_readiness_smoke_test.dart)


### F22 · Preserve native accessibility and complete device-level proof

**Partial.** Retained the shared touch, focus, semantics and reduced-motion components. Added all 14 state cases for each new player, Partner and public-link surface, including 320-point width at 200% text. English replaces the previous multilingual acceptance requirement.

**Remaining acceptance:** Complete device-level VoiceOver/TalkBack, keyboard, authentication focus and payment-return checks. Screenshot and widget checks do not establish screen-reader completion.

**Code:** [packages/features/feat_club/test/club_route_state_goldens_test.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_club/test/club_route_state_goldens_test.dart)


### F23 · Validate merchandise with approved imagery and compact fallbacks

**Implemented locally.** Product imagery and variants remain authoritative. Failed images use a compact fallback that expands safely for large text. Quick add opens details when a variant is required; invalid/stale choices do not advance to checkout.

**Remaining acceptance:** Review approved full-length catalogue content on Android and physical iOS devices, including out-of-stock and fulfilment cases.

**Code:** [packages/features/feat_shop/lib/src/screens/product_detail_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_shop/lib/src/screens/product_detail_screen.dart)


### F24 · Give missing and stale content a consistent meaning

**Implemented locally.** Home and search retain healthy sources. Club uses shared loading, empty, offline, refresh, permission and conflict states. Permission revocation removes retained content; Partner and public-link pages now use the same recovery language.

**Remaining acceptance:** Complete low-bandwidth and live-permission UAT. Match-window queries are still an all-or-fail calendar group, and no claim is made that every collection has a timestamped disk cache.

**Code:** [packages/features/feat_club/lib/src/screens/club_collection_screens.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_club/lib/src/screens/club_collection_screens.dart)


### F25 · Use one clear vocabulary for membership, contributions and FET

**Implemented locally.** English vocabulary separates membership status, confirmed contributions, FET balance, purchase offers and enquiries. Removed language selectors and translation catalogues throughout the maintained app and web code.

**Remaining acceptance:** Review new English editorial publications and run a supporter comprehension check. Proper names, country codes and migration history remain intact.

**Code:** [docs/governance/localization/README.md](/Volumes/PRO-G40/AFRICLUB/docs/governance/localization/README.md)


### F26 · Add an approved-content native parity run

**Validation pending.** Captured actual iOS Simulator Club and Predict journeys with synthetic data, plus the full application smoke. Current Flutter regression images cover the changed screen states.

**Remaining acceptance:** Run read-only iOS and Android parity against the approved content snapshot and deployed candidate schema. Physical devices and a live approved snapshot were not available in this run.

**Code:** [apps/rayon_sports/integration_test/club_identity_journey_test.dart](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/integration_test/club_identity_journey_test.dart)


### F27 · Measure content load and reduce avoidable serialization

**Partial.** Parallelized independent Home reads and bounded current-match queries. Preserved partial Home/search results and avoided invented content on failure.

**Remaining acceptance:** Measure first useful content, image bytes, median/tail network timing and native frame performance against the same-device baseline. No measured speedup is claimed.

**Code:** [packages/features/feat_home/lib/src/repositories/home_content_repository.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_home/lib/src/repositories/home_content_repository.dart)


### F28 · Validate task success instead of judging parity by screenshots alone

**Partial.** Extended existing consent-controlled analytics with confirmed prediction and review-abandonment events. Existing route/search/ticket privacy tests remain in the regression suite.

**Remaining acceptance:** Run the six supporter tasks with an identified sample, baseline and task wording. No participant research or universal UX score was fabricated.

**Code:** [packages/features/feat_gamification/lib/src/predict/predict_screen.dart](/Volumes/PRO-G40/AFRICLUB/packages/features/feat_gamification/lib/src/predict/predict_screen.dart)

## Provenance and limits

AFRICLUB implementation started from commit 3f13a12db5f9e866b1f538bac53afb5ae5a25582 with substantial existing uncommitted work. That work was recorded in pre-existing.patch and pre-existing-status.txt and preserved. Gikundiro was reviewed at c915c9c2c42cd899fafefa8a120a551c92544486; it was not edited. The source manifest and final tracked diff identify the local candidate more accurately than HEAD alone.

The evidence directory contains the updated backlog CSV/JSON, validation results, test logs, gallery and source hashes. Older failed attempts are retained as work evidence; only the explicitly named final logs support the results above. Source-fidelity certification, Android/physical-device accessibility, real-provider settlement/admission, cross-project publication and supporter research remain separate open work.

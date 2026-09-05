# Native mobile implementation review

The shared mobile presentation is reimplemented for all 20 club shells. The
selected reference is Revolut native iOS **Dark · Glow**, captured 5 September
2026, with the historical onboarding cohort used only for phone and code entry.
This report describes local implementation and inspection, not a release or
certification of exact pixel equivalence.

## Scope and implementation

- 57 rendered route entries, including five tab entries and the router error and
  unavailable states; 28 existing redirects keep their registered targets.
- Shared typography, neutral surfaces, rounded groups, inverse primary buttons,
  circular quick actions, compact search and navigation, sheets, selection,
  native switches, and six-cell code entry replace the former visual rules.
- Home uses blue, Club petrol, Fan Zone violet, Membership card-wallet violet,
  and authentication blue-indigo. These are independently selected UI colour
  roles. The 20 club identities and their approved artwork remain their own.
- Home fixture hero, Club directory, Fan Zone overview, membership card, Settings
  profile and Appearance preview have new compositions. Remaining football,
  contribution, venue, ticket and commerce forms use the shared controls and
  the product's existing task order.
- Phone/code entry retains server verification, masking, keyboard, autofill and
  recovery. Appearance keeps a local draft: Cancel/Back discard; Apply persists.
- The 11 internal admin routes also use sentence-case headings, the shared type
  scale and neutral UI roles. Their operational workflows are product adaptations
  without a banking-app analogue.
- Role gates, backend providers, payment verification, dialer handoff,
  cancellation, idempotency, feature flags and image-rights checks remain in
  their existing application contracts.

## Visual review method

The route table names a target regression capture and a source comparator or
explicit product adaptation for every rendered route. Inspection covered
hierarchy, colour roles, type, insets, groups, actions and content preservation.
It found and corrected extra bottom-bar clearance, flush-edge club lists,
shrinking membership labels, obsolete all-capital copy and wide tracking,
layered contribution sheet frames, decorative product fallback artwork,
admin page insets, coloured non-interactive metrics and separate action cards,
icon-button accessibility labels and a card animation restart surviving disposal.

Dark native iPhone 13 simulator captures are 1170 × 2532 pixels at DPR 3,
390 × 844 logical pixels, iOS 26.5. Integration screenshots rasterize the
Flutter layer; they do not include the operating system status-bar artwork.
The fixture is synthetic and backend startup is disabled. Unavailable live-data
states in that journey are expected, not evidence of production availability.
Populated states are additionally rendered by the governed route tests.

There are 866 associated route-state regression images (including the populated
Home fixture). They cover applicable loading, empty, error, offline, permission,
disabled, focus, held press, selection, 200% text, reduced motion, light, dark,
sync, conflict and timeout variants. Passing them means the implementation
matches its reviewed local baseline; it does not mean a source pixel comparison.
The route JSON lists exact files and tests, without treating missing states as
passes.

## Deliberate adaptations and unresolved source evidence

- Football fixtures, picks, supporter identifiers, standings, QR tickets,
  contribution amounts and venue tasks keep their own data and workflow.
- A share/ticket/membership artifact may retain its product-specific composition;
  it is not a banking instrument. Machine-readable QR contrast stays binary.
- Long club names, translated copy, 200% text and disabled/focus states reflow or
  use accessible contrast instead of shrinking text or copying an illegible
  source treatment. Membership progress scrolls horizontally at readable size.
- Source app build, region, exact font and logical viewport are unknown. Its
  current light and all accessibility/state variants have not been captured.
  Target system typography and light/accessibility adaptations are explicit;
  exact fidelity for these dimensions remains unverified.
- Private reference captures and source logos are not included in the repository,
  app assets or review gallery. The reference map uses identifiers only.

**100% pixel-equivalence claim: unverified.** No checklist score or passing test
count is converted to an equivalence percentage. The implementation scope is
57 rendered entries plus 28 redirects, including 11 role-gated internal admin
routes. Web/PWA and venue-operator web surfaces are outside this native scope.

## Verification

The full workspace counts below describe the initial mobile reimplementation.
The subsequent semantic-colour and launch-screen follow-up is verified by the
additional affected-package run recorded after that list.

- Workspace regression: **2,689 tests across 44 packages passed** without
  updating baselines. All 20 club shell route graphs passed.
- Affected admin, gamification and localization rerun: **741 tests passed**.
  After the final admin presentation edits, all **266 admin tests passed again**
  without updating baselines. These reruns overlap the workspace test count.
- Strict workspace analysis: **no issues**. Architecture, iOS QA bundle isolation
  and mobile QA contracts passed.
- Native iOS: **five application journeys passed** on iOS 26.5 (seven harness
  results including setup and teardown), with eight synthetic Flutter-layer
  captures covering tab navigation, phone restoration, Settings and Appearance.
- All **1,187 baseline hashes** were reconciled and the golden contract passed.
  The automated privacy scan passed; it does not replace human release review.
- Localized-copy inventory: **64 literal and 312 dynamic candidates reviewed,
  zero pending**. English, French and Kinyarwanda catalogs are generated.
- Formatting and whitespace checks passed. No deployment or store release is
  represented by this local implementation evidence.

### Semantic-colour and native launch follow-up

- Generated club initials now use the shared tonal surface and theme-aware text.
  The membership card's default accent uses the UI primary role. A production
  source sweep found no remaining callers of club-palette colour getters in UI
  widgets. Actual club artwork and metadata remain unchanged.
- All 20 iOS launch screens use the system background. The primary Android shell
  now uses neutral day/night launch resources, including Android 12. The other
  Android shells already used neutral platform launch backgrounds. XML parsing
  passed for all 20 storyboards and the eight primary Android resources; the
  Rayon Sports QA iOS build compiled successfully. Other club binaries and the
  Android launch transition were not separately built in this follow-up.
- **931 affected tests passed without updating baselines** across theme, app,
  Home, Club, Membership and onboarding. These overlap the earlier workspace
  count. Strict analysis, architecture and both QA isolation contracts passed.
- **67 changed regression images** retain their dimensions; visual review covered
  generated initials in Home, Club, Membership, onboarding and the shared chrome,
  including light and enlarged-text cases. All **1,187 manifest hashes** were
  reconciled and the golden contract passed.
- The five native iOS journeys passed again, producing eight fresh synthetic
  captures at 390 × 844 logical pixels, DPR 3. Source-font, source-build,
  current-native-Light and other unobserved source-state gaps remain as stated
  above; this follow-up does not convert them into verified fidelity.

## Route comparison register

| Target route | Source reference | Mapping | Representative target |
| --- | --- | --- | --- |
| `/auth/otp` | MOBBIN-ONBOARDING-010 | component pattern | [auth_otp_state_dark_dark_390x844.png](../../packages/features/feat_onboarding/test/goldens/auth_otp_state_dark_dark_390x844.png) |
| `/auth/phone` | MOBBIN-ONBOARDING-004 | component pattern | [auth_phone_state_dark_dark_390x844.png](../../packages/features/feat_onboarding/test/goldens/auth_phone_state_dark_dark_390x844.png) |
| `/challenge` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [challenge_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/challenge_state_dark_dark_390x844.png) |
| `/challenge/:id` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [challenge_detail_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/challenge_detail_state_dark_dark_390x844.png) |
| `/challenge/create` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [challenge_create_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/challenge_create_state_dark_dark_390x844.png) |
| `/challenge/my` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [challenge_my_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/challenge_my_state_dark_dark_390x844.png) |
| `/club` | LIVE-021, LIVE-007 | component pattern | [club_hub_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_hub_state_dark_dark_390x844.png) |
| `/club/fixtures` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_fixtures_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_fixtures_state_dark_dark_390x844.png) |
| `/club/fixtures/:matchId` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_fixture_detail_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_fixture_detail_state_dark_dark_390x844.png) |
| `/club/history` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_history_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_history_state_dark_dark_390x844.png) |
| `/club/news` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_news_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_news_state_dark_dark_390x844.png) |
| `/club/news/:articleId` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_news_detail_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_news_detail_state_dark_dark_390x844.png) |
| `/club/projects` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_projects_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_projects_state_dark_dark_390x844.png) |
| `/club/projects/:projectId` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_project_detail_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_project_detail_state_dark_dark_390x844.png) |
| `/club/results` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_results_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_results_state_dark_dark_390x844.png) |
| `/club/standings` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_standings_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_standings_state_dark_dark_390x844.png) |
| `/club/team` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [club_team_state_dark_dark_390x844.png](../../packages/features/feat_club/test/goldens/club_team_state_dark_dark_390x844.png) |
| `/contribute/group/:groupId` | LIVE-053, LIVE-060 | component pattern | [group_detail_state_dark_dark_390x844.png](../../packages/features/feat_contributions/test/goldens/group_detail_state_dark_dark_390x844.png) |
| `/contribute/group/:groupId/statement` | LIVE-053, LIVE-060 | component pattern | [statement_state_dark_dark_390x844.png](../../packages/features/feat_contributions/test/goldens/statement_state_dark_dark_390x844.png) |
| `/e-ticket/:id` | LIVE-048 | component pattern | [e_ticket_state_dark_dark_390x844.png](../../packages/features/feat_ticketing/test/goldens/e_ticket_state_dark_dark_390x844.png) |
| `/fan-clubs/:clubId` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [fan_club_detail_state_dark_dark_390x844.png](../../packages/features/feat_fan_clubs/test/goldens/fan_club_detail_state_dark_dark_390x844.png) |
| `/fanzone` | LIVE-026 | component pattern | [fanzone_state_selected_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/fanzone_state_selected_dark_390x844.png) |
| `/fanzone/match/:fixtureId` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [match_detail_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/match_detail_state_dark_dark_390x844.png) |
| `/fanzone/my/:predictionId` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [prediction_detail_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/prediction_detail_state_dark_dark_390x844.png) |
| `/fanzone/share` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [share_card_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/share_card_state_dark_dark_390x844.png) |
| `/fanzone/venue` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [venue_checkin_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/venue_checkin_state_dark_dark_390x844.png) |
| `/fanzone/venue/order` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [venue_order_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/venue_order_state_dark_dark_390x844.png) |
| `/fanzone/wallet` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [fet_wallet_state_dark_dark_390x844.png](../../packages/features/feat_gamification/test/goldens/fet_wallet_state_dark_dark_390x844.png) |
| `/feature-unavailable` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [feature_unavailable_state_dark_dark_390x844.png](../../packages/core/core_router/test/goldens/feature_unavailable_state_dark_dark_390x844.png) |
| `/home` | LIVE-020 | component pattern | [home_state_populated_dark_390x844.png](../../packages/features/feat_home/test/goldens/home_state_populated_dark_390x844.png) |
| `/live/news/:articleId` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [news_article_state_dark_dark_390x844.png](../../packages/features/feat_live/test/goldens/news_article_state_dark_dark_390x844.png) |
| `/membership` | LIVE-048, LIVE-047 | component pattern | [membership_state_selected_dark_390x844.png](../../packages/features/feat_membership/test/goldens/membership_state_selected_dark_390x844.png) |
| `/membership/tier/:tierId` | LIVE-053, LIVE-060 | component pattern | [tier_detail_state_dark_dark_390x844.png](../../packages/features/feat_membership/test/goldens/tier_detail_state_dark_dark_390x844.png) |
| `/onboarding` |  | unevidenced adaptation | [onboarding_state_selected_dark_390x844.png](../../packages/features/feat_onboarding/test/goldens/onboarding_state_selected_dark_390x844.png) |
| `/search` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [search_state_selected_dark_390x844.png](../../packages/features/feat_home/test/goldens/search_state_selected_dark_390x844.png) |
| `/settings` | LIVE-005, LIVE-007, LIVE-013 | component pattern | [settings_state_selected_dark_390x844.png](../../packages/features/feat_settings/test/goldens/settings_state_selected_dark_390x844.png) |
| `/settings/edit-profile` | LIVE-005, LIVE-007, LIVE-013 | component pattern | [profile_state_dark_dark_390x844.png](../../packages/features/feat_settings/test/goldens/profile_state_dark_dark_390x844.png) |
| `/settings/notifications` | LIVE-005, LIVE-007, LIVE-013 | component pattern | [notifications_state_dark_dark_390x844.png](../../packages/features/feat_settings/test/goldens/notifications_state_dark_dark_390x844.png) |
| `/settings/privacy` | LIVE-005, LIVE-007, LIVE-013 | component pattern | [privacy_state_dark_dark_390x844.png](../../packages/features/feat_settings/test/goldens/privacy_state_dark_dark_390x844.png) |
| `/shop` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [shop_state_selected_dark_390x844.png](../../packages/features/feat_shop/test/goldens/shop_state_selected_dark_390x844.png) |
| `/shop/cart` | LIVE-053, LIVE-060 | component pattern | [cart_state_selected_dark_390x844.png](../../packages/features/feat_shop/test/goldens/cart_state_selected_dark_390x844.png) |
| `/shop/product/:productId` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [product_detail_state_selected_dark_390x844.png](../../packages/features/feat_shop/test/goldens/product_detail_state_selected_dark_390x844.png) |
| `/tickets` | LIVE-007, LIVE-033, LIVE-051, LIVE-053 | component pattern | [tickets_state_selected_dark_390x844.png](../../packages/features/feat_ticketing/test/goldens/tickets_state_selected_dark_390x844.png) |
| `/tickets/detail/:id` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [ticket_detail_state_dark_dark_390x844.png](../../packages/features/feat_ticketing/test/goldens/ticket_detail_state_dark_dark_390x844.png) |
| `/tickets/map/:id` | LIVE-048 | component pattern | [seat_map_state_dark_dark_390x844.png](../../packages/features/feat_ticketing/test/goldens/seat_map_state_dark_dark_390x844.png) |
| `<router-error>` | LIVE-007, LIVE-026, LIVE-053 | component pattern | [router_error_state_dark_dark_390x844.png](../../packages/core/core_router/test/goldens/router_error_state_dark_dark_390x844.png) |

| `/admin` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_dashboard_state_dark_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_dashboard_state_dark_dark_390x844.png) |
| `/admin/challenges` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_challenges_state_dark_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_challenges_state_dark_dark_390x844.png) |
| `/admin/cms` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_cms_state_dark_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_cms_state_dark_dark_390x844.png) |
| `/admin/competitions` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_competitions_state_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_competitions_state_dark_390x844.png) |
| `/admin/contributions` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_contributions_state_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_contributions_state_dark_390x844.png) |
| `/admin/features` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_features_state_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_features_state_dark_390x844.png) |
| `/admin/features/:featureKey` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_feature_detail_state_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_feature_detail_state_dark_390x844.png) |
| `/admin/matches` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_matches_state_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_matches_state_dark_390x844.png) |
| `/admin/notifications` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_notifications_state_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_notifications_state_dark_390x844.png) |
| `/admin/settle` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_settlement_state_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_settlement_state_dark_390x844.png) |
| `/admin/sms-monitor` | LIVE-007, LIVE-053, LIVE-060 | component pattern; operational adaptation | [admin_sms_state_dark_390x844.png](../../packages/features/feat_admin/test/goldens/admin_sms_state_dark_390x844.png) |

## Reproducing the native capture

From `apps/rayon_sports`, target an isolated simulator and use the QA bundle:

```sh
AFRICLUB_REFERENCE_OUTPUT_DIR=/tmp/africlub-native-review \
flutter drive --no-pub --flavor qa -d <isolated-simulator-id> \
  --target=integration_test/release_readiness_smoke_test.dart \
  --driver=test_driver/reference_capture_driver.dart \
  --dart-define=AFRICLUB_CAPTURE_REFERENCE=true \
  --dart-define-from-file=assets/flavors/production.json
```

The integration-test startup options disable the backend and supply synthetic
state. The driver saves captures and the journey result; saved files alone do
not certify fidelity. Normal app builds omit the capture define and driver.

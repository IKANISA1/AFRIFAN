# Golden baseline review

The Flutter golden suite is a controlled visual-regression gate, not a command
to accept changed pixels automatically.

## 2026-08-01 owner TV management route-state review

- Scope: all sixteen governed states for `/my-tvs/:displayId`: loading,
  missing display, unavailable, offline, permission-denied, unchanged-form
  disabled, focused, held destructive press, selected authorized location,
  200-percent text, reduced motion, dark, light, retained syncing, conflict,
  and bounded timeout.
- Review method: source-resolution loading, disabled, selected, focus, held
  press, syncing, conflict, and 320 by 720 large-text captures were inspected
  against the established owner-TV management and shared form grammar. The
  first large-text capture truncated the destructive label and the first focus
  capture horizontally hid most of the current name; two-line action labels
  and explicit leading-caret focus corrected both defects before admission.
  The legacy owner-management baseline was regenerated for the truthful
  unchanged-form disabled state.
- Result: accepted for controlled local synthetic evidence. Permission denial
  clears retained protected inventory, loading and retained refresh block all
  mutations, Save changes is enabled only for a valid actual change, scope is
  presented by authorized name without raw identifiers, the real destructive
  action is visibly held without execution, and every action remains
  scroll-reachable at 200-percent text.
- Boundary: this does not prove authenticated shared/live owner scope, live
  RLS/RPC/audit behavior, real display recovery/revocation, physical-device
  accessibility, named review, signing, stores, deployment, or release.

## 2026-08-01 owner TV pairing route-state review

- Scope: all sixteen governed states for `/my-tvs/pair`: loading, no authorized
  scope, unavailable, offline, permission-denied, incomplete-form disabled,
  focused, pressed, selected authorized location, 200-percent text, reduced
  motion, dark, light, retained syncing, conflict, and bounded timeout.
- Review method: source-resolution loading, empty, dark, light, focus, held
  press, selected, syncing, conflict, timeout, and 320 by 720 large-text
  captures were inspected against the established owner-TV and shared form
  grammar. Partial route frames and a focus capture that lost route identity
  were rejected; bounded settlement and explicit scroll restoration now retain
  the app-bar title and full form context.
- Result: accepted for controlled local synthetic evidence. Initial data and
  authorization failures expose no premature form, the primary action remains
  disabled until challenge, display name, and named scope are valid, retained
  uncertain state blocks mutation, raw venue identifiers remain hidden, and
  real focus/press/selection states have distinct pixels.
- Boundary: this does not prove authenticated shared/live owner scope, live
  RLS/RPC/audit behavior, a real TV challenge exchange, physical-device
  accessibility, named review, signing, stores, deployment, or release.

## 2026-08-01 owner TV inventory route-state review

- Scope: fourteen exact-current local captures for `/my-tvs`: loading, empty,
  unavailable, offline, permission-denied, retained-disabled, focus, press,
  200-percent text, reduced motion, dark, light, retained-syncing, and bounded
  timeout.
- Review method: source-resolution dark, light, loading, offline, retained,
  syncing, large-text, focus, and held-pointer captures were inspected against
  the established owner-TV and shared mobile component grammar. Intermediate
  harness captures with partially entered route chrome or completed pointer
  navigation were rejected; the accepted loading capture seeds the exact state
  and the accepted pressed capture holds the real button gesture without
  leaving the inventory route.
- Result: accepted for controlled local synthetic evidence. Offline is distinct
  from generic unavailability, retained data is labelled stale, refresh and
  pairing are paused while authority is uncertain, keyboard focus is visible,
  and the 320 by 720 large-text inventory remains scroll-reachable without a
  layout exception.
- Boundary: this does not prove authenticated shared/live owner scope, live
  RLS/RPC/audit behavior, physical-device accessibility, named review,
  signing, stores, deployment, or release.

## 2026-08-01 game-operations hub route-state review

- Scope: six exact-current local captures for the static role-gated
  `/game-operations` hub: focused, pressed, 200-percent text, reduced motion,
  dark, and light.
- Review method: source-resolution dark, light, large-text, focus, and held
  pointer captures were inspected against the existing list-row, scaffold,
  spacing, typography, theme, and interaction grammar. The first pressed
  attempt advanced navigation and was rejected; the accepted capture holds the
  pointer without leaving the hub and has a digest distinct from the dark
  baseline.
- Result: accepted for controlled local synthetic evidence. The two role-safe
  choices remain clear, both are scroll-reachable at 320 by 720 and
  200-percent text, focus is visible, and no data, authorization, selection,
  disabled, synchronization, conflict, or timeout state is fabricated for this
  static navigation surface.
- Boundary: this does not prove authorized live owner/organizer roles, the six
  downstream operational routes, physical-device accessibility, named review,
  signing, stores, deployment, or release.

## 2026-08-01 football-club-first route-state review

- Scope: 153 new exact-current local captures across the eleven canonical Club
  routes. The matrix covers every applicable loading, empty, error, offline,
  permission-denied, focus, press, 200-percent text, reduced-motion, dark,
  light, syncing, conflict, and security-timeout state.
- Review method: source-resolution hub, list, detail, recovery, refresh,
  large-text, dark, and light samples were inspected against the existing
  AFRICLUB semantic token, shared scaffold, state-view, list-row, card, button,
  and icon grammar. An initial nested-route capture exposed partially entered
  route chrome; the harness now advances a bounded post-settlement frame and
  all 153 baselines reproduce exactly.
- Result: accepted for controlled local synthetic evidence. Football-club
  identity remains first, recovery copy is concise and privacy-safe, retained
  content remains visible during refresh/offline states, and large text stays
  scroll-reachable without a layout exception.
- Boundary: this is not approved live club content, authenticated production
  behavior, physical-device accessibility, named linguistic/design/privacy
  approval, signing, store, deployment, or release proof.

## 2026-08-01 native-TV owner-pairing QR correction

- Scope: the governed Rwandan 1280 x 720 unpaired-TV state whose QR fixture
  still encoded the obsolete `africlub://tv-pair/...` path.
- Review method: the old and corrected source-resolution images were placed
  side by side. The corrected QR encodes exactly
  `africlub://my-tvs/pair?challenge=TV4K8M2Q`, matching backend emission and
  runtime validation.
- Result: accepted. Only the intentional QR modules changed; club identity,
  localized copy, displayed challenge, expiry, D-pad focus, action hierarchy,
  spacing, and overscan geometry are unchanged.
- Boundary: this is deterministic synthetic exact-pixel proof. Shared/live
  pairing, physical-TV/remote/AT, real-network timing, accountable approval,
  production signing, stores, deployment, and release remain open.

## 2026-08-01 owner TV management review

- Scope: one new dark 390 x 844 TV-detail state covering complete safe
  operational context, current named location, save, credential recovery, and
  destructive access revocation.
- Review method: the source-resolution image was inspected against the existing
  My TVs inventory and shared mobile token/component grammar. The card,
  typography, spacing, field, action, icon, and destructive hierarchy remain
  consistent; the screen contains no raw venue ID or pairing credential.
- Result: accepted for the local source checkpoint. All labels and values are
  readable without clipping or overlap; save and recovery remain distinct from
  the destructive revoke action.
- Boundary: the image uses deterministic synthetic data. Shared/live role and
  audit execution, real-display/network behavior, physical-device/AT,
  accountable approval, signing, stores, deployment, and release remain open.

## 2026-07-30 native-TV V2 projection review

- Scope: six new 1280 × 720 native-TV states covering owner-claim pairing with
  an actual QR payload, current question, reveal, retained-offline recovery,
  paired-without-assignment, and completed gameplay at 170-percent text.
- Review method: the six current images were inspected together with the
  governed native-TV session reference. The V2 surfaces preserve the existing
  overscan frame, club identity, dark palette, status/action placement,
  typography, surface cards, public-alias privacy, and remote-focus treatment.
  The pairing revision was also compared directly against its pre-QR image and
  isolated pixel diff before admission.
- Result: accepted for the local source checkpoint. The pairing QR is generated
  from the validated `africlub://my-tvs/pair` payload, the one-time code remains
  legible at ten-foot distance, reveal uses text/semantics plus border and
  color, retained-offline state stays explicit, and large text reflows to a
  vertical scroll surface without overflow.
- Boundary: GAME-TV-02 now passes its separate local isolated-network contract;
  these images do not prove Realtime behavior. Shared/live WAN,
  physical remote/device, 1080p/4K overscan, assistive technology, soak,
  signing, stores, accountable approval, and release remain open.

## 2026-07-30 owner and organizer Settings entry review

- Scope: the twenty-six governed Settings responsive and state baselines whose
  pixels changed when the role-scoped `Games and TVs` section and `Game
  operations` route entry were added.
- Review method: paired current images against the exact `HEAD` references at
  the same viewport and state, including compact dark, standard light,
  security-timeout, 200-percent text, and tablet examples. The new section
  follows the existing Settings cards, spacing, typography, icon, focus, and
  theme system. No unrelated visual replacement was accepted.
- Result: accepted for the local source checkpoint. Compact and large-text
  captures remain vertically scrollable by design; tablet preserves the full
  account, game, preferences, support, and sign-out sequence without overflow.
  The fourteen-test Settings golden suite passes.
- Boundary: the baseline admission proves deterministic synthetic source
  rendering only. Authorized owner/organizer roles, live data, physical-device
  accessibility, accountable design/privacy approval, signing, deployment,
  stores, and release remain open.

## 2026-07-30 route-wide localization closure review

- Scope: the final Share Card, Prediction Detail, Game Session Join, Match
  Detail, and Venue Check-in static task-copy surfaces in English, French, and
  Kinyarwanda, including compact/200-percent text, privacy semantics, offline,
  conflict, timeout, permission, selected, focused, pressed, loading, empty,
  syncing, dark, light, and reduced-motion states.
- Result: accepted for local engineering evidence. Existing English goldens
  remain exact. The Match Detail empty-state action was restored to its
  title-case English contract with a dedicated localized key; no changed pixels
  or new baseline digest were admitted.
- Validation: the EN/FR/RW catalog has exact 3,183-message parity; `core_l10n`
  passes 8 tests; the complete Gamification package passes 586 tests; strict
  Gamification analysis is clean; and the fail-closed 292-file inventory
  reports 63 controlled dispositions and zero pending candidates.
- Failure artifacts generated during intermediate localization comparisons
  were retained outside the repository at
  `/tmp/africlub-gamification-localization-failures-20260730-02`; they are not
  governed baselines.
- Boundary: French and Kinyarwanda remain draft pending named accountable
  linguistic and approved localized visual review. Static source closure does
  not prove dynamic/API/CMS content, physical devices, assistive technology,
  authenticated production behavior, CI, signing, store, deployment, or
  release approval.

## 2026-07-30 Challenge Detail localization and large-text review

- Scope: Challenge Detail state, card, action, status, feedback, and semantic
  copy across English, French, and Kinyarwanda, plus the shared state view and
  compact Challenge Card at 320 by 760 and 200-percent platform text.
- Result: accepted for local engineering evidence. The large-text execution
  initially exposed real vertical state-content and card-header/match overflows.
  `AfriStateView` now scrolls centered state content only when text scaling
  requires it, and Challenge Card stacks its header and match layout only at
  large text. Normal-scale Challenge Detail images remain byte-identical to the
  approved baselines.
- Regression review: the localized notification CTA exposed a duplicate
  `gameOpen` message ID whose later challenge meaning silently changed the
  approved uppercase notification action. The contexts now use separate
  message IDs. All seven responsive notification goldens again match their
  approved pixels, and the Fan Zone provider test now asserts the locale-neutral
  recovery message key rather than presentation copy.
- Validation: 34 Challenge Detail feature/state/controller tests, 11 focused
  notification and offline-recovery tests, 7 core-l10n tests, 433 core-theme
  tests, and the complete deterministic 575-test Gamification package pass.
  Strict analysis, the 1,084-baseline golden contract, and evidence-privacy
  validation pass. No new Challenge Detail golden digest was admitted.
- Boundary: local source and deterministic synthetic evidence do not constitute
  named French/Kinyarwanda linguistic approval, physical-device or assistive-
  technology proof, authenticated production behavior, CI, signing, store,
  deployment, or release approval.

## Controlled contract

- Baselines use fixed logical viewports, device pixel ratio 1, deterministic
  fixture data, locally loaded Material icons, and disabled decorative motion.
- The comparison threshold is exact: `0.0` differing pixels.
- The universal component catalogs are governed as paired dark and light
  captures so component parity cannot be inferred from route evidence alone.
- Component hover, focus, and pressed evidence is driven by real pointer and
  keyboard events, must produce a measurable pixel delta from the default
  state, and is captured in both themes.
- The ten priority route groups are governed at compact 320/374 dp and
  standard/large-phone 390/430/599 dp plus foldable-half/tablet 674/834 dp
  profiles. Adaptive-shell tablet-rail and separating-hinge captures are also
  governed.
- Home dark and Settings light each have a same-viewport standard versus
  operating-system high-contrast comparison at 390 × 844. The Settings pair
  must not be byte-identical, preventing a route that bypasses shared
  high-contrast semantics from passing unnoticed.
- Dark and light 430 × 900 contrast-evidence sheets cover overlay hierarchy,
  inactive controls, metrics, and chart communication without color alone.
- The current manifest contains 950 exact-pixel baselines, including exact
  Search, Home, Fan Zone, Onboarding, Settings, Membership, Tickets, Shop,
  product-detail, cart, phone-auth, OTP-auth, contribution, challenge,
  prediction, match, article, E-ticket, Ticket detail, Seat Map, Fan Club
  detail, TV Game Join, live Game Controller, Share Card, Venue Check-in,
  Venue Order, FET Wallet, and native TV session/pairing task-state
  captures.
- Tests must not contact Firebase, Supabase, production storage, or live media.
- `docs/governance/golden-baselines.json` identifies every governed baseline,
  its viewport, purpose, and SHA-256 digest.

## Review workflow

1. Run the governed route and component golden files:
   - `packages/core/core_theme/test/universal_component_catalog_golden_test.dart`
   - `packages/core/core_theme/test/universal_interaction_state_golden_test.dart`
   - `packages/core/core_theme/test/contrast_evidence_golden_test.dart`
   - `packages/core/core_router/test/route_transitions_golden_test.dart`
   - `packages/features/feat_home/test/home_screen_states_test.dart`
   - `packages/features/feat_home/test/discovery_search_test.dart`
   - `packages/features/feat_gamification/test/fanzone_hub_screen_test.dart`
   - `packages/features/feat_gamification/test/prediction_notifications_list_test.dart`
   - `packages/features/feat_settings/test/settings_goldens_test.dart`
   - `packages/features/feat_settings/test/settings_screen_states_test.dart`
   - `packages/features/feat_onboarding/test/onboarding_flow_test.dart`
   - `packages/features/feat_onboarding/test/supporter_phone_auth_states_test.dart`
   - `packages/features/feat_membership/test/membership_screen_ui_test.dart`
   - `packages/features/feat_contributions/test/groups_screen_empty_state_test.dart`
   - `packages/features/feat_fan_clubs/test/fan_club_detail_screen_states_test.dart`
   - `packages/features/feat_ticketing/test/ticketing_state_test.dart`
   - `packages/features/feat_shop/test/cart_screen_states_test.dart`
   - `packages/features/feat_shop/test/shop_screen_states_test.dart`
   - `packages/features/feat_shop/test/product_detail_screen_states_test.dart`
   - `packages/features/feat_shop/test/cart_screen_responsive_test.dart`
   - `apps/rayon_sports_tv/test/tv_route_states_test.dart`
2. Inspect each `failures/*_masterImage.png`, `*_testImage.png`, and
   `*_isolatedDiff.png`; never approve a changed baseline from the exit code
   alone.
3. If the implementation change is approved by the design/accessibility owner,
   regenerate only the named test file with `flutter test --update-goldens`.
4. Recalculate and update only the corresponding SHA-256 values in
   `docs/governance/golden-baselines.json`.
5. Run `bash tools/scripts/validate_golden_contract.sh` and the normal Flutter
   validation matrix.
6. Run `bash tools/scripts/validate_evidence_privacy.sh`. The automated scan
   must pass, and human privacy review remains `pending` until an accountable
   reviewer approves the images.
7. Review the generated dark/light interaction contact sheets locally and
   record the reviewer class. For high-contrast changes, also inspect
   `output/implementation_goal_20260724/high_contrast_matrix/high-contrast-comparison.png`
   with the standard and high-contrast captures in the same comparison input.
   For contrast changes, inspect
   `output/implementation_goal_20260724/contrast_matrix/contrast-evidence-comparison.png`
   with the dark and light source captures in the same comparison input.
   Codex visual inspection is useful engineering evidence but does not satisfy
   accountable human design/privacy approval.
8. Commit baseline, manifest, source, and test changes together. CI retains
   golden baselines and any failure diffs for review.

Screenshots containing live personal data, tokens, credentials, phone numbers,
OTPs, or private identifiers are prohibited. Golden fixtures must remain
synthetic and stable.

## 2026-07-30 Home localization review

- Scope: ten changed Home baselines: seven compact-to-tablet profiles, dark
  high contrast, empty, and error.
- Inspection: Codex inspected the generated compact, standard, wide, tablet,
  empty, error, and high-contrast test images at source resolution before
  regenerating only `home_screen_states_test.dart`.
- Result: accepted for local engineering evidence. Typed status notices and
  built-in shortcuts now resolve through the EN/FR/RW catalog; configured CMS
  titles remain authoritative. The new recovery wording fits every governed
  viewport with no clipping, overlap, lost action, or broken hierarchy.
- Regression: the focused Home widget and FR/RW journey tests pass, and all
  changed Home digests are registered in
  `docs/governance/golden-baselines.json`.
- Approval boundary: dynamic CMS copy review, named French/Kinyarwanda
  linguistic approval, localized route-state captures, physical
  assistive-technology/device execution, accountable human design/privacy
  approval, pinned CI, signing, store processing, and release approval remain
  pending.

## 2026-07-30 Onboarding and WhatsApp-auth localization review

- Scope: ten changed dark-theme baselines at 390 × 844: Onboarding offline
  and disabled; phone-auth error, permission-denied, conflict, and
  security-timeout; and the corresponding four OTP-auth states.
- Inspection: Codex inspected every generated test image at source resolution
  before updating only the two named state test files.
- Result: accepted for local engineering evidence. EN framing now comes from
  the same EN/FR/RW catalog used by the localized task surfaces; failure copy
  is privacy-safe and no raw provider diagnostic is rendered. No clipping,
  overflow, broken action hierarchy, or hidden recovery control was observed.
- Regression: all 98 Onboarding tests, all four localization contract tests,
  and both package analyses pass. The ten changed baseline digests are
  registered in `docs/governance/golden-baselines.json`.
- Approval boundary: named French/Kinyarwanda linguistic approval, localized
  route-state captures, physical assistive-technology/device execution,
  accountable human design/privacy approval, pinned CI, signing, store
  processing, and release approval remain pending.

## 2026-07-30 Mobile internal-admin dashboard engineering review

- Scope: all sixteen governed states for the Flutter internal-admin `/admin`
  dashboard at 390 × 844, including 200-percent text and dark/light themes.
- Inspection: Codex inspected the dark, light, selected, permission-denied,
  focused, pressed, and large-text captures at source resolution and compared
  the interaction-state digests.
- Rejection and remediation: the first light capture reused the raw club gold
  for critical text on a light surface, the first 200-percent heading split
  `COMMAND` mid-word beside the close control, and the first held-press capture
  was pixel-identical to focus. The route now resolves accessible metric and
  chart colors per theme, moves the close control into a dedicated large-text
  header row, and captures the real held pointer after focus is cleared.
- Result: accepted for local engineering evidence. Permission loss clears all
  private dashboard data and actions; recoverable failures retain only the
  last confirmed snapshot; focused, pressed, and selected states are visibly
  distinct; the 200-percent heading reflows by complete words; and no clipping,
  overlap, broken padding, or raw diagnostics were observed.
- Regression: the sixteen-state file and the complete 30-test Admin package
  pass, package analysis reports no issues, and the 934-digest governed
  manifest is registered.
- Approval boundary: authenticated production role and RLS behavior, physical
  assistive-technology/device execution, accountable human design/privacy
  approval, pinned CI, signing, store processing, and release approval remain
  pending.

## 2026-07-30 Mobile internal-admin challenges engineering review

- Scope: all sixteen governed states for the Flutter internal-admin
  `/admin/challenges` settlement route at 390 × 844, including 200-percent
  text, dark/light themes, filter selection, keyboard focus, and held press.
- Inspection: Codex inspected the dark, light, selected, focused, pressed, and
  large-text captures at source resolution and compared the interaction-state
  digests.
- Rejection and remediation: the initial selected capture was incomplete after
  a bulk regeneration and the initial held-press assertion sampled before the
  scrolling gesture arena resolved. The named selected baseline was regenerated
  from the deterministic fixture, and the press test now holds a real pointer
  through arena resolution before capturing a visibly scaled control.
- Result: accepted for local engineering evidence. The route exposes bounded
  loading, empty, error, offline, permission-denied, disabled, syncing,
  conflict, and security-timeout behavior; preserves only confirmed data on
  recoverable refresh failures; clears private data on permission loss; blocks
  duplicate settlement while an outcome is uncertain; and does not expose raw
  diagnostics or private admin metadata.
- Regression: the sixteen-state route file, seven controller cases, and the
  complete Admin package pass; package analysis reports no issues; and all
  sixteen exact digests are registered in the 934-baseline governed manifest.
- Approval boundary: authenticated production role and RLS behavior, physical
  assistive-technology/device execution, accountable human design/privacy
  approval, pinned CI, signing, store processing, and release approval remain
  pending.

## 2026-07-30 Mobile internal-admin CMS engineering review

- Scope: all sixteen governed states for the Flutter internal-admin
  `/admin/cms` publishing workspace at 390 × 844, including 200-percent text,
  dark/light themes, section selection, keyboard focus, and held press.
- Inspection: Codex inspected the dark, light, selected, focused, pressed, and
  large-text captures at source resolution and compared the interaction-state
  digests.
- Rejection and remediation: the first light capture rendered publishing
  actions with white chrome text on pale content surfaces, and the first press
  capture sampled before the scrolling gesture arena resolved. CMS actions now
  resolve their foreground from the active surface theme, the shared text-icon
  button correctly gives explicit caller styles precedence, and the press test
  holds a real pointer through arena resolution.
- Result: accepted for local engineering evidence. The route strictly projects
  and caps nine private resource collections, omits arbitrary metadata and
  audit actors, preserves only confirmed data on recoverable failure, clears
  all private collections on permission loss, serializes and bounds mutations,
  blocks actions after an uncertain result, exposes safe recovery copy, and
  preserves all existing create, edit, publish, enable, and disable workflows.
- Regression: eight controller cases and sixteen exact state cases pass;
  package analysis reports no issues; and all sixteen distinct state digests
  are registered in the 950-baseline governed manifest.
- Approval boundary: authenticated production role/RLS behavior, cross-role
  publishing and mutation UAT, content and partner authority, physical
  assistive-technology/device execution, accountable human design/privacy
  approval, pinned CI, signing, store processing, and release approval remain
  pending.

## 2026-07-24 Fan Zone task-copy engineering review

- Scope: seven Fan Zone route baselines at 320, 374, 390, 430, 599, 674, and
  834 logical-pixel widths.
- Trigger: the TV-session and venue-code instructions moved to the shared
  EN/FR/RW catalog and were shortened.
- Inspection: Codex inspected the generated master/test pairs at the smallest
  320 × 760 profile and the largest 834 × 1194 profile before regenerating the
  named Fan Zone test only.
- Result: accepted for local engineering evidence. The shorter copy reduces
  wrapping on the compact surface and retains the existing hierarchy and
  spacing on tablet; no overlap, clipping, broken padding, or missing control
  was observed.
- Regression: the complete 171-test gamification suite passes after the seven
  exact digests were refreshed.
- Approval boundary: accountable human design, privacy, French linguistic, and
  Kinyarwanda linguistic review remains pending.

## 2026-07-25 Membership route-state engineering review

- Scope: deterministic loading, empty, error, offline, large-text, and selected
  Membership route states, plus the refreshed responsive Membership family.
- Inspection: Codex inspected every generated Membership screenshot at source
  resolution before evidence credit.
- Rejection and remediation: the first large-text image stacked price digits
  and hid content, while the first selected image did not show the selected
  package. The package tile now reflows vertically at large text and Gold
  exposes a visible and semantic `Current` state.
- Result: accepted for local engineering evidence. The final large-text and
  selected captures show complete content, clear hierarchy, and usable actions
  without overlap, clipping, or horizontal overflow.
- Regression: the complete 40-test Membership package and package strict
  analysis pass after the six state captures and responsive baseline refresh.
- Approval boundary: physical assistive-technology/device execution and
  accountable human design/privacy approval remain pending.

## 2026-07-25 Complete Cart route-state engineering review

- Scope: deterministic loading, empty, error, offline, disabled, focused,
  pressed, selected-quantity, large-text, permission-denied, syncing, conflict,
  and security-timeout states on `/shop/cart`, together with the governed
  reduced-motion and exact dark/light captures.
- Inspection: Codex inspected every generated cart screenshot at source
  resolution before evidence credit.
- Rejection and remediation: the initial route allowed a payment-availability
  failure to escape without recovery, collided address guidance with entered
  text after focus, rendered the destructive Remove action at insufficient
  contrast in light mode, and truncated both address guidance and checkout
  copy at 200-percent text. The cart now exposes bounded
  loading/error/retry/offline/disabled states, preserves its draft, refreshes
  on reconnect, separates hint from two-line helper guidance, gives Remove an
  explicit error-token style, and uses complete adaptive large-text chrome and
  checkout copy.
- Final-state remediation: checkout exceptions no longer appear in supporter
  copy. Policy rejection, order conflict, and a bounded secure-checkout timeout
  map to stable retained-draft states. Processing disables duplicate
  submission; permission rejection and uncertain order status fail closed.
- Result: accepted for local engineering evidence. Final images retain item,
  delivery, total, payment consequence, and action context; quantity selection
  updates the dependent values. A real held pointer drives pressed treatment.
- Regression: the complete 70-test Shop package and 432-test Core Theme package
  pass after all 16 cart states and semantic input/geometry token changes.
- Approval boundary: physical assistive-technology/device execution,
  authenticated live payment/order behavior, and accountable human
  design/privacy approval remain pending.

## 2026-07-25 Complete Search route-state engineering review

- Scope: all 16 governed states on `/search`, with the new disabled, pressed,
  permission-denied, syncing, conflict, and security-timeout captures added to
  the prior loading, empty, error, offline, focused, selected, large-text,
  reduced-motion, dark, and light evidence.
- Inspection: Codex inspected all six new 390 × 844 screenshots at source
  resolution before evidence credit.
- Behavior and privacy: one-character input explains the two-character
  threshold; a real held pointer drives result-row pressed treatment; changing
  a settled query produces distinct Updating results feedback; typed safe
  failures preserve the query and category without rendering account, policy,
  revision, transport, or backend diagnostics.
- Result: accepted for local engineering evidence. Permission, conflict, and
  timeout consequences are visibly distinct, query and recovery context remain
  reachable, and no clipping, overlap, broken padding, or exposed diagnostics
  were observed.
- Regression: the exact Search file passes 35 tests, the complete Home package
  passes 82 tests, package and workspace strict analysis report no issues, and
  the 410-digest golden contract plus automated privacy validation pass.
- Approval boundary: authenticated live federated-source behavior, physical
  assistive-technology/device execution, and accountable human design/privacy
  approval remain pending.

## 2026-07-25 Complete Membership route-state engineering review

- Scope: all 16 governed states on `/membership`, with disabled, focused,
  pressed, permission-denied, syncing, conflict, and security-timeout captures
  added to the prior loading, empty, error, offline, selected, large-text,
  reduced-motion, dark, and light evidence.
- Inspection: Codex inspected all seven new 390 × 844 screenshots and the
  refreshed generic-error capture at source resolution before evidence credit.
- Rejection and remediation: the first synchronization capture ellipsized the
  in-flight action and reduced its progress icon to an ambiguous dot. The
  route now uses a complete disabled `Submitting` action beneath an explicit
  synchronization state card.
- Behavior and privacy: pending review is disabled; real platform focus and a
  held pointer drive interaction states; bounded read/write operations map raw
  account, RLS, revision, transport, and backend failures to stable categories;
  permission rejection and uncertain timeout block further changes until
  membership status is refreshed.
- Result: accepted for local engineering evidence. Tier, price, current-state,
  failure consequence, and recovery remain visible without clipping, overlap,
  exposed diagnostics, or broken padding.
- Regression: the exact Membership state file passes 30 tests, the complete
  Membership package passes 47 tests, package and workspace strict analysis
  report no issues, and the 417-digest golden contract plus automated privacy
  validation pass.
- Approval boundary: authenticated live payment/application reconciliation,
  physical assistive-technology/device execution, and accountable human
  design/privacy approval remain pending.

## 2026-07-25 Complete Tickets route-state engineering review

- Scope: all 16 governed states on `/tickets`, with disabled, focused, pressed,
  permission-denied, syncing, conflict, and security-timeout captures added to
  the prior loading, empty, error, offline, selected, large-text,
  reduced-motion, dark, and light evidence.
- Inspection: Codex inspected all seven new 390 × 844 screenshots and the
  refreshed offline and selected captures at source resolution before evidence
  credit.
- Behavior and privacy: sold-out and not-yet-open fixtures now retain match and
  price context with explicit disabled actions; real platform focus and a held
  pointer drive interaction states; refresh retains settled inventory beneath
  complete synchronization guidance; bounded reads map permission, revision,
  timeout, and unknown failures to stable supporter-facing categories.
- Result: accepted for local engineering evidence. Failure consequences and
  recovery are distinct, the synchronization state retains current fixture
  context, and no clipping, overlap, broken padding, or exposed backend
  diagnostic was observed.
- Regression: the exact Tickets state file passes 19 tests, the complete
  Ticketing package passes 49 tests, package and workspace strict analysis
  report no issues, and the 424-digest golden contract plus automated privacy
  validation pass.
- Approval boundary: authenticated live inventory and purchase behavior,
  physical assistive-technology/device execution, and accountable human
  design/privacy approval remain pending.

## 2026-07-25 Complete Shop route-state engineering review

- Scope: all 16 governed states on `/shop`, with disabled, focused, pressed,
  permission-denied, syncing, conflict, security-timeout, reduced-motion,
  explicit dark, and explicit light captures added to the prior loading, empty,
  error, offline, selected, and large-text evidence.
- Inspection: Codex inspected all ten added or corrected 390 × 844 captures at
  source resolution before evidence credit.
- Behavior and privacy: unavailable products retain name and price context with
  an explicit `OUT OF STOCK` label and disabled add action; real platform focus
  and a held pointer drive interaction states; reconnect retains settled
  catalog content beneath complete synchronization guidance; bounded reads map
  permission, revision, timeout, and unknown failures to stable copy without
  raw diagnostics.
- Rejection and remediation: generated-ledger review caught three omitted
  theme/motion cells, and pixel comparison caught an autofocus capture that did
  not visibly render keyboard focus. Dedicated reduced-motion, dark, and light
  executions were added, while the focused execution now uses the platform
  traditional-focus highlight mode and shows a measurable blue non-colour ring.
- Result: accepted for local engineering evidence. All 16 Shop cells are linked
  to current tests and screenshots; the light and dark catalogs retain complete
  hierarchy and actions without clipping, overlap, or broken padding.
- Regression: the exact Shop state file passes 17 tests, the complete Shop
  package passes 81 tests, Core Theme passes 432 tests, package and workspace
  strict analysis report no issues, and the 434-digest golden contract plus
  automated privacy validation pass.
- Approval boundary: authenticated live catalog/cart behavior, physical
  assistive-technology/device execution, and accountable human design/privacy
  approval remain pending.

## 2026-07-25 Complete Product-detail route-state engineering review

- Scope: all 16 governed states on `/shop/product/:productId`, with
  permission-denied, disabled, focused, pressed, reduced-motion, explicit dark,
  explicit light, syncing, conflict, and security-timeout captures added to the
  prior loading, not-found, error, offline, selected-size, and large-text
  evidence.
- Inspection: Codex inspected all ten added or corrected 390 × 844 captures at
  source resolution before evidence credit.
- Behavior and privacy: unavailable inventory retains product and price context
  while disabling Add to cart and Buy now; real platform focus and a held
  pointer drive size interactions; reconnect retains settled product,
  selected-size, quantity, total, and purchase context beneath complete
  synchronization guidance; bounded reads map permission, revision, timeout,
  and unknown failures to stable copy without raw diagnostics.
- Rejection and remediation: the initial focus execution was not visibly
  distinct. The production size control now renders a measurable three-pixel
  blue non-colour ring during traditional keyboard focus; a real focused
  capture verifies the corrected behavior.
- Result: accepted for local engineering evidence. All 16 product-detail cells
  are linked to current tests and screenshots; light and dark executions retain
  complete product hierarchy and purchase consequences without clipping,
  overlap, or broken padding.
- Regression: the exact product-detail state file passes 18 tests, the complete
  Shop package passes 92 tests, Core Theme passes 432 tests, package and
  workspace strict analysis report no issues, and the 444-digest golden
  contract plus automated privacy validation pass.
- Approval boundary: authenticated live catalog/cart behavior, physical
  assistive-technology/device execution, and accountable human design/privacy
  approval remain pending.

## 2026-07-25 Complete Fan Zone route-state engineering review

- Scope: all 16 governed states on `/fanzone`, with permission-denied,
  disabled, focused, pressed, syncing, conflict, and security-timeout captures
  added to the prior loading, empty, error, offline, selected, large-text,
  reduced-motion, dark, and light evidence.
- Inspection: Codex inspected all seven new 390 × 844 screenshots at source
  resolution before evidence credit.
- Behavior and privacy: visible but unavailable venue tasks retain labels and
  consequences with disabled semantics and `Unavailable` badges; real platform
  focus and a held pointer drive section interactions; refresh retains current
  points, rounds, selection, and actions; all nine concurrent reads are bounded
  and map policy, revision, timeout, and unknown failures to stable copy without
  raw diagnostics.
- Rejection and remediation: the first disabled capture scrolled the first
  unavailable row under the app bar and clipped its opening context. It was
  rejected and regenerated at the route origin with both unavailable tasks,
  their consequences, and surrounding Fan Zone context visible.
- Result: accepted for local engineering evidence. All 16 Fan Zone cells are
  linked to current tests and screenshots; the focused League segment shows a
  measurable blue non-colour ring, held press produces a real pixel delta, and
  synchronization retains the supporter task without clipping, overlap, or
  broken padding.
- Regression: the exact Fan Zone state file passes 36 tests, the complete
  Gamification package passes 184 tests, Core Theme passes 432 tests, package
  and workspace strict analysis report no issues, and the 451-digest golden
  contract plus automated privacy validation pass.
- Approval boundary: authenticated live repositories and mutations, physical
  assistive-technology/device execution, and accountable human design/privacy
  approval remain pending.

## 2026-07-25 Complete Home route-state engineering review

- Scope: all 16 governed states on `/home`, with offline, permission-denied,
  disabled, focused, pressed, selected, syncing, conflict, and security-timeout
  captures added to the prior loading, empty, error, large-text, reduced-motion,
  dark, and light evidence.
- Inspection: Codex inspected all nine new 390 × 844 screenshots at source
  resolution before evidence credit.
- Behavior and privacy: visible but unavailable Matchday and Fan Zone commands
  retain labels and consequences with disabled semantics; real platform focus,
  a held pointer, and a PageView swipe drive the interaction states; refresh
  retains settled Home content; the initial feed read is bounded by a
  provider-owned cancellable timer; policy, revision, timeout, and unknown
  failures map to stable copy without raw diagnostics.
- Rejection and remediation: the first bounded-load implementation used a
  detached future timeout that left fake timers pending after the provider was
  disposed. It was rejected and replaced with a notifier-owned timer that is
  cancelled on disposal while preserving the production 12-second fail-safe.
- Result: accepted for local engineering evidence. All 16 Home cells are linked
  to current tests and screenshots; focus, held press, selected hero, disabled
  commands, retained synchronization, and typed recovery remain complete
  without clipping, overlap, exposed diagnostics, or broken padding.
- Regression: the exact Home state file passes 35 tests, the complete Home
  package passes 91 tests, Core Theme passes 432 tests, Core Feature Config
  service passes 68 tests, package and workspace strict analysis report no
  issues, and the 460-digest golden contract plus automated privacy validation
  pass.
- Approval boundary: authenticated live repositories/navigation outcomes,
  physical assistive-technology/device execution, and accountable human
  design/privacy approval remain pending.

## 2026-07-25 Tickets route-state engineering review

- Scope: deterministic loading, empty, error, offline, large-text, and selected
  states on the production Tickets route.
- Inspection: Codex inspected every generated Tickets screenshot at source
  resolution before evidence credit.
- Rejection and remediation: the first 200-percent-text capture clipped the
  Upcoming tab, availability status, date, and venue. The route now uses a
  semantic `NEXT` label at large text and stacks availability and metadata.
- Result: accepted for local engineering evidence. The final capture retains
  complete tab meaning, status, teams, competition, full date, venue, price,
  and the full-width Buy ticket action without clipping or overflow.
- Regression: the complete 41-test Ticketing package and package strict
  analysis pass after the six new exact state captures.
- Approval boundary: physical assistive-technology/device execution and
  accountable human design/privacy approval remain pending.

## 2026-07-25 Shop route-state engineering review

- Scope: deterministic loading, empty, error, offline, large-text, and selected
  states on the production Shop route.
- Inspection: Codex inspected every generated Shop screenshot at source
  resolution before evidence credit.
- Rejection and remediation: initial review found a blank offline surface, an
  online error using offline warning treatment, and 99-pixel and 55-pixel
  product-card overflows at 200-percent text. Offline and online error are now
  distinct, and large-text products use a natural-height single-column layout.
- Result: accepted for local engineering evidence. The final captures retain
  complete state consequences, product name, description, full price, category
  selection, and add action without clipping or overflow.
- Regression: the complete 48-test Shop package and package strict analysis
  pass after the six exact state captures.
- Approval boundary: physical assistive-technology/device execution and
  accountable human design/privacy approval remain pending.

## 2026-07-25 Product-detail route-state engineering review

- Scope: deterministic loading, not-found, error, offline, large-text, and
  selected-size states on `/shop/product/:productId`.
- Inspection: Codex inspected every generated product-detail screenshot at
  source resolution before evidence credit.
- Rejection and remediation: initial execution trapped loading users without a
  close action, failed because the quantity header expanded inside unbounded
  width, and overflowed the 200-percent-text media fallback by 120 pixels.
  Navigation, state consequences, quantity structure, hero fallback, price,
  total, and purchase actions now adapt to the current constraints.
- Result: accepted for local engineering evidence. The final images retain
  recovery, readable current-data consequences, complete purchase actions, and
  a visibly and semantically selected XL size without rendering overflow.
- Regression: the complete 55-test Shop package and package strict analysis
  pass after the six product-detail captures.
- Approval boundary: physical assistive-technology/device execution and
  accountable human design/privacy approval remain pending.

## 2026-07-25 Phone and OTP authentication engineering review

- Scope: all 16 governed states on `/auth/phone` and `/auth/otp`: loading,
  empty, error, offline, permission-denied, disabled, focused, pressed,
  selected, 200-percent text, reduced motion, dark, light, syncing, conflict,
  and security timeout.
- Inspection: Codex inspected all 32 final production-screen screenshots at
  source resolution or through byte-identical current state captures before
  evidence credit.
- Rejection and remediation: initial captures exposed action timing that did
  not enter the intended state, raw phone display, duplicated error feedback,
  keyboard displacement, truncated OTP recovery guidance, and clipped
  large-text labels/actions. The routes now use typed and sanitized failures,
  mask phone and code values, preserve drafts, distinguish offline and
  permission outcomes, prevent duplicate submission, and keep the essential
  task sequence reachable at 200-percent text. The completion tranche then
  exposed inherited white recovery actions in light mode and a pressed fixture
  that resembled a complete phone number; semantic light/dark action colors and
  an unmistakably synthetic all-zero fixture replaced them.
- Result: accepted for local engineering evidence. The final images contain
  synthetic non-production data, no raw backend error, no visible OTP, and no
  complete phone number. Every state retains a clear consequence and recovery
  path without overlap, clipping, or horizontal overflow.
- Regression: the exact state file passes 32 tests, the complete Core Auth
  package passes 97 tests, the complete Onboarding package passes 78 tests, the
  complete Core Theme package passes 432 tests, and strict package/root
  analysis reports no issues.
- Approval boundary: live WhatsApp delivery, physical-device and
  assistive-technology execution, pinned CI, and accountable human
  design/privacy approval remain pending.

## 2026-07-25 Complete Onboarding route-state engineering review

- Scope: all 16 governed states on `/onboarding`, with loading, empty, error,
  offline, permission-denied, disabled, focused, pressed, selected,
  large-text, syncing, conflict, and security-timeout captures added to the
  prior reduced-motion, dark, and light evidence.
- Inspection: Codex inspected all 13 new production-screen screenshots at
  source resolution before evidence credit.
- Behavior and privacy: production welcome content now uses a typed
  repository/notifier contract; offline and disabled states retain a safe
  guest path; real platform focus, a held pointer, and a PageView fling drive
  interaction states; refresh retains settled welcome content; reads are
  bounded by a provider-owned cancellable timer; policy, revision, timeout,
  and unknown failures map to stable copy without raw diagnostics.
- Rejection and remediation: the initial state scaffold failed under
  unbounded scroll constraints; a generic capture reset returned the selected
  PageView to its first slide; single-line actions clipped at 200-percent text;
  and fallback stadium media overlapped the large-text title. The final route
  uses bounded state layout, vertical-only capture reset, adaptive multi-line
  action labels, compact large-text typography, and decorative-media omission
  at 320 by 720.
- Result: accepted for local engineering evidence. All 16 Onboarding cells are
  linked to current tests and screenshots; focus, held press, selected slide,
  disabled/offline consequences, retained synchronization, and typed recovery
  remain complete without clipping, overlap, exposed diagnostics, or broken
  padding.
- Regression: the exact Onboarding state file passes 13 tests, the existing
  flow file passes 26 tests, the complete Onboarding package passes 91 tests,
  Core Theme passes 432 tests, package and workspace strict analysis report no
  issues, and the 473-digest golden contract plus automated privacy and
  design-compliance checks pass.
- Approval boundary: live WhatsApp authentication and remote content,
  physical assistive-technology/device execution, pinned CI, and accountable
  human design/privacy approval remain pending.

## 2026-07-28 Complete Settings route-state engineering review

- Scope: all 16 governed states on `/settings`, with loading, empty, error,
  offline, permission-denied, disabled, focused, pressed, selected,
  large-text, syncing, conflict, and security-timeout captures added to the
  prior reduced-motion, dark, and light evidence.
- Inspection: Codex inspected all 13 new production-route screenshots at
  source resolution before evidence credit.
- Behavior and privacy: the production support lookup now uses a typed
  repository/notifier contract; offline and disabled states keep unrelated
  account and appearance tasks usable while disabling unavailable support;
  real platform focus, a held pointer, and the production Appearance sheet
  drive interaction states; refresh retains settled Settings content; reads
  are bounded by a provider-owned cancellable timer; policy, revision,
  timeout, and unknown failures map to stable copy without raw diagnostics.
- Rejection and remediation: source-resolution review rejected a permission
  consequence truncated by the state banner and a single-line Membership
  details action that ellipsized at 320 by 720 with 200-percent text. The
  permission copy is now complete, the primary action adapts to two lines,
  and shared-source guardrails replaced direct Material progress indicators
  with the governed loading primitive.
- Result: accepted for local engineering evidence. All 16 Settings cells are
  linked to current tests and screenshots; focus, held press, selected theme,
  unavailable-support consequences, retained synchronization, and typed
  recovery remain complete without overlap, exposed diagnostics, or broken
  padding.
- Regression: the exact Settings state file passes 13 tests, the complete
  Settings package passes 68 tests, Core Theme passes 432 tests, package and
  workspace strict analysis report no issues, and the 486-digest golden
  contract plus automated privacy and design-compliance checks pass.
- Approval boundary: live support configuration and session behavior,
  physical assistive-technology/device execution, pinned CI, and accountable
  human design/privacy approval remain pending.

## 2026-07-28 Complete Edit profile route-state engineering review

- Scope: all 16 governed states on `/settings/edit-profile`: loading, empty,
  error, offline, permission-denied, disabled, focused, pressed, selected,
  large-text, reduced motion, dark, light, syncing, conflict, and security
  timeout.
- Inspection: Codex inspected every final production-route screenshot at
  source resolution before evidence credit.
- Behavior and privacy: the production route now uses a typed
  repository/notifier contract, retains a local authenticated profile offline,
  blocks mutation when offline or feature-disabled, bounds profile reads,
  saves, and conflict refreshes, preserves drafts while confirmation is
  pending, refreshes the latest profile after conflict, and maps permission,
  conflict, timeout, and unknown failures to stable copy without exposing raw
  backend diagnostics. Account-deletion failure copy is also sanitized.
- Rejection and remediation: the first pressed capture was byte-identical to
  the default state and was rejected. The test now dispatches and holds a real
  pointer through the production Save changes action, asserts a measurable
  scale value below one, and captures a visibly distinct pressed state.
- Result: accepted for local engineering evidence. The 320 by 720,
  200-percent-text capture keeps alias, language, nickname, save, and
  destructive-account actions complete and scroll-reachable. Focus and text
  selection are driven by the real platform controls, and light/dark parity
  retains the same hierarchy without overlap, clipping, or exposed
  diagnostics.
- Regression: the exact profile state file passes 16 tests, the complete
  Settings package passes 84 tests, Core Theme passes 432 tests, package and
  workspace strict analysis report no issues, and the 502-digest golden
  contract plus automated privacy and design-compliance checks pass.
- Approval boundary: authenticated live profile/update/delete behavior,
  physical assistive-technology/device execution, pinned CI, and accountable
  human design/privacy approval remain pending.

## 2026-07-28 Complete Notifications route-state engineering review

- Scope: all 16 governed states on `/settings/notifications`: loading, empty,
  error, offline, permission-denied, disabled, focused, pressed, selected,
  large-text, reduced motion, dark, light, syncing, conflict, and security
  timeout.
- Inspection: Codex inspected every final production-route screenshot at
  source resolution before evidence credit.
- Behavior and privacy: typed reader/writer boundaries now bound repository
  loads and saves; platform permission, token synchronization, and device
  unregister calls are also time-bounded. Offline and platform-unavailable
  states retain confirmed preferences while blocking unsafe actions; pending
  saves prevent duplicates; conflicts invalidate and refresh; uncertain
  timeouts fail closed; raw policy, repository, and account identifiers never
  enter supporter-facing copy.
- Rejection and remediation: visual review rejected an ellipsized
  200-percent delivery action, state captures with inherited scroll offsets,
  and route-title contrast outside shared chrome ownership. The accepted suite
  uses a governed two-line action, deterministic route-origin capture, and a
  title whose foreground is owned by the shared app bar. The press test holds the production
  press handler at a measured scale below one and produces a distinct digest.
- Result: accepted for local engineering evidence. The all-or-nothing delivery
  model remains truthful; focus and toggled semantics are explicit; the 320 by
  720 large-text route keeps controls complete and scroll-reachable; light,
  dark, and reduced-motion executions retain the same hierarchy.
- Regression: the exact Notifications state file passes 16 tests, complete
  Settings passes 100 tests, Core Theme passes 432 tests, package and workspace
  analysis report no issues, and the 518-digest golden contract passes.
- Approval boundary: live FCM/APNs permission and token behavior,
  authenticated cross-device conflict reconciliation, physical
  assistive-technology/device execution, pinned CI, and accountable human
  design/privacy approval remain pending.

## 2026-07-28 Complete Privacy route-state engineering review

- Scope: all 16 governed states on `/settings/privacy`: loading, empty, error,
  offline, permission-denied, disabled, focused, pressed, selected, large-text,
  reduced motion, dark, light, syncing, conflict, and security timeout.
- Inspection: Codex inspected the representative and interaction-critical
  final production-route screenshots at source resolution before evidence
  credit, including both themes, 200-percent text, recovery, focus, press,
  toggled, synchronization, conflict, and timeout states.
- Behavior and privacy: typed reader/writer boundaries now bound privacy loads
  and saves, analytics-consent and MoMo SMS synchronization, and other-session
  sign-out. Offline and feature-disabled states retain confirmed choices and
  drafts while blocking unsafe actions; pending mutations prevent duplicates;
  conflicts invalidate and require review; uncertain timeouts fail closed; raw
  policy, repository, session, and account identifiers never enter
  supporter-facing copy.
- Rejection and remediation: visual review rejected state captures with
  inherited scroll offsets and missing or low-contrast route chrome. The
  accepted suite resets the route origin deterministically and delegates title
  foreground to the governed shared app bar.
- Result: accepted for local engineering evidence. Focus, pressed scale, and
  toggled semantics are explicit; the 320 by 720 large-text route keeps the
  session action reachable; light, dark, and reduced-motion executions retain
  the same hierarchy; export, policy, and session availability stay truthful.
- Regression: the exact Privacy state file passes 16 tests, complete Settings
  passes 116 tests, Core Theme passes 432 tests, package and workspace analysis
  report no issues, and the 534-digest golden contract passes.
- Approval boundary: authenticated live consent/export/policy/session and MoMo
  SMS behavior, physical assistive-technology/device execution, pinned CI, and
  accountable human design/privacy approval remain pending.

## 2026-07-28 Complete Challenge feed route-state engineering review

- Scope: all 16 governed states on `/challenge`: loading, empty, error,
  offline, permission-denied, disabled, focused, pressed, selected, large-text,
  reduced motion, dark, light, syncing, conflict, and security timeout.
- Inspection: Codex inspected the representative and interaction-critical
  final production-route screenshots at source resolution before evidence
  credit, including both themes, 200-percent text, offline and disabled
  retained-content states, focus, press, permission, synchronization, conflict,
  and timeout recovery.
- Route authority, behavior, and privacy: the root route now resolves to the
  implemented exact-score pool feed described by `ChallengeModule`, not the
  legacy tutorial/catalog surface. All four concurrent reads are bounded,
  offline startup fails before repository access, refreshes coalesce and retain
  settled pools, and raw supporter, row, policy, repository, and transport
  diagnostics map to typed safe failures. Unsafe create, join, and remote
  navigation actions disable while offline, denied, disabled, degraded, or
  uncertain.
- Rejection and remediation: the first pressed capture was byte-identical to
  the settled dark state and was rejected; a real held pointer now reaches and
  asserts the production scale transition before capture. The first light-mode
  visual review also rejected insufficient route-title, section-action, score,
  countdown, stake, status, and prediction-pill contrast. The accepted suite
  uses governed semantic chrome, text, surface, and status roles.
- Result: accepted for local engineering evidence. The pressed digest is
  distinct from dark; focus and selected-filter semantics are explicit; the
  320 by 720 large-text route keeps guidance, filters, the create action,
  scores, status, and stake context reachable; light, dark, and reduced-motion
  executions preserve the hierarchy.
- Regression: the exact Challenge state file passes 16 tests, the controller
  contract passes 4 tests, complete Gamification passes 204 tests, package and
  workspace analysis report no issues, and the 550-digest golden contract,
  automated privacy scan, route inventory, and design-compliance checks pass.
- Approval boundary: authenticated live pool creation, joining, settlement,
  and reconciliation; the related Challenge detail/create/my routes; physical
  assistive-technology/device execution; pinned CI; and accountable human
  design/privacy approval remain pending.

## 2026-07-28 Complete Challenge detail route-state engineering review

- Scope: all 16 governed states on `/challenge/:id`: loading, empty, error,
  offline, permission-denied, disabled, focused, pressed, selected, large-text,
  reduced motion, dark, light, syncing, conflict, and security timeout.
- Inspection: Codex inspected representative and interaction-critical final
  production-route screenshots at source resolution, including both themes,
  200-percent text, offline and degraded retained-detail states, focus, press,
  score selection, synchronization, conflict, and timeout recovery.
- Behavior and privacy: typed detail state now bounds reads, joins, and
  cancellations; offline startup fails before repository access; overlapping
  refreshes coalesce; settled detail survives refresh failure; reconnect
  triggers refresh; successful join adopts the returned challenge without a
  stale reload; and uncertain mutation blocks repeated submission. Raw
  supporter, row, policy, repository, revision, and transport diagnostics map
  to typed supporter-safe failures.
- Rejection and remediation: the first 200-percent capture was rejected
  because it clipped the beginning of the join task and did not prove the full
  score-and-action journey. The accepted deterministic capture advances the
  production detail list through a bounded exact scroll, preserves the
  complete task heading and guidance, shows vertically adapted score controls
  and the complete two-line join action, and keeps the following Entries
  section visible. Focus, pressed scale, and score selection are driven by the
  real production controls.
- Result: accepted for local engineering evidence. Unsafe score, join, and
  cancellation actions fail closed while offline, disabled, syncing,
  conflicted, permission-denied, or uncertain; light/dark and reduced-motion
  executions preserve the same hierarchy; the pressed digest is distinct from
  dark; and selected-score semantics are explicit.
- Regression: the exact Challenge detail state file passes 17 tests, its
  controller contract passes 7 tests, focused feature and module suites pass 7
  and 6 tests, the Challenge feed exact suite passes 16 tests, the complete
  Gamification package passes 228 tests, package and workspace analysis report
  no issues, and the 566-digest golden contract, automated privacy scan, route
  inventory, and design-compliance checks pass.
- Approval boundary: authenticated live join, cancellation, settlement, and
  multi-client reconciliation; the related Challenge create/my routes;
  physical assistive-technology/device execution; pinned CI; and accountable
  human design/privacy approval remain pending.

## 2026-07-28 Complete Challenge creation route-state engineering review

- Scope: all 16 governed states on `/challenge/create`: loading, empty, error,
  offline, permission-denied, disabled, focused, pressed, selected, large-text,
  reduced motion, dark, light, syncing, conflict, and security timeout.
- Inspection: Codex inspected representative and interaction-critical final
  production-route screenshots at source resolution, including both themes,
  200-percent text, offline and degraded retained-form states, focus, press,
  score selection, synchronization, conflict, and timeout recovery.
- Behavior and privacy: typed creation state now bounds fixture reads and
  challenge creation; offline startup fails before gateway access; overlapping
  refreshes coalesce; settled fixtures survive refresh failure; reconnect
  triggers refresh; successful creation adopts the returned challenge without
  a stale reload; and uncertain mutation blocks repeated submission. Raw
  supporter, row, policy, repository, revision, and transport diagnostics map
  to typed supporter-safe failures.
- Rejection and remediation: the first 200-percent capture was rejected
  because the normal compact match card collapsed club and kickoff copy into
  unreadable vertical fragments. The accepted production route switches to a
  dedicated semantic summary at large text, preserving complete club names,
  competition, exact score, entry points, balance, lock timing, and the
  two-line create action. A transient light capture whose action label had not
  painted was also rejected and regenerated before the exact full-file pass.
- Result: accepted for local engineering evidence. Unsafe fixture, score,
  entry, confirmation, and create actions fail closed while offline, disabled,
  syncing, conflicted, permission-denied, or uncertain; light/dark and
  reduced-motion executions preserve the hierarchy; the pressed digest is
  distinct from dark; and selected-score semantics are explicit.
- Regression: the exact Challenge creation state file passes 17 tests, its
  controller contract passes 7 tests, focused feature and module suites pass 7
  and 6 tests, the Challenge feed and detail exact suites pass 16 and 17 tests,
  the complete Gamification package passes 252 tests, package and workspace
  analysis report no issues, and the 582-digest golden contract, automated
  privacy scan, route inventory, and design-compliance checks pass.
- Approval boundary: authenticated live pool creation, points debit, and
  multi-client reconciliation; the related Challenge my route; physical
  assistive-technology/device execution; pinned CI; and accountable human
  design/privacy approval remain pending.

## 2026-07-28 Complete My Challenges route-state engineering review

- Scope: all 16 governed states on `/challenge/my`: loading, empty, error,
  offline, permission-denied, disabled, focused, pressed, selected, large-text,
  reduced motion, dark, light, syncing, conflict, and security timeout.
- Inspection: Codex inspected interaction-critical final production-route
  screenshots at source resolution, including both themes, 200-percent text,
  task-specific empty history, offline and degraded retained-history states,
  keyboard focus, held press, settled-tab selection, synchronization,
  conflict, and timeout recovery.
- Behavior and privacy: typed history state now bounds repository reads; fails
  offline before repository access; serializes rapid tab changes; suppresses
  stale responses; retains per-filter confirmed history during refresh and
  failure; reconnect triggers refresh; and raw account, policy, row, revision,
  repository, and transport diagnostics map to typed supporter-safe failures.
- Rejection and remediation: the legacy route rendered an invisible empty
  state, exposed raw errors, discarded data during refresh, allowed overlapping
  tab loads and stale replacement, and used a compact card that could not
  preserve full club names at 200-percent text. The accepted production route
  exposes explicit consequences, blocks unsafe detail navigation while state is
  unavailable or uncertain, makes the tabs horizontally reachable, and uses a
  dedicated large-text semantic history card. Golden capture was also made
  state-keyed and repaint-explicit after consecutive degraded captures exposed
  retained-layer omissions; final baselines preserve full route chrome.
- Result: accepted for local engineering evidence. The route has truthful
  status-specific empty copy, real focus and held-pointer feedback, real
  settled-tab selected semantics, readable light/dark roles, reduced-motion
  execution, retained synchronization and degraded states, and complete
  320-by-720 200-percent club, status, stake, prediction, and outcome copy.
- Regression: the exact My Challenges state file passes 17 tests, its
  controller contract passes 7 tests, the focused feature suite passes 7 tests,
  the complete Gamification package passes 276 tests, Core Theme passes 432
  tests sequentially, workspace analysis reports no issues, and the
  598-digest governed manifest and route inventory close My Challenges at 304
  evidenced plus 1,676 open applicable cells overall.
- Approval boundary: authenticated live history and multi-client settlement
  reconciliation; physical assistive-technology/device execution; pinned CI;
  accountable human design/privacy approval; signing; and release evidence
  remain pending.

## 2026-07-28 Complete contribution initiative detail route-state engineering review

- Scope: all 16 governed states on `/contribute/group/:groupId`: loading,
  empty, error, offline, permission-denied, disabled, focused, pressed,
  selected, large-text, reduced motion, dark, light, syncing, conflict, and
  security timeout.
- Inspection: Codex inspected interaction-critical final production-route
  screenshots at source resolution, including both themes, 200-percent text,
  the real MoMo amount sheet, offline and degraded retained-content states,
  keyboard focus, held press, synchronization, conflict, and timeout recovery.
- Behavior and privacy: the route no longer queries Supabase directly from
  widget state. A typed gateway/controller bounds reads to 12 seconds, fails
  offline before gateway access, coalesces overlapping refreshes, retains the
  last confirmed total and ledger during uncertainty, refreshes after
  reconnect, and maps account, RLS, row, revision, repository, and transport
  failures to supporter-safe consequences. The public ledger exposes bounded
  aliases, amounts, canonical status, and dates while omitting internal user
  IDs, payment references, phone numbers, and account details.
- Payment integrity: the production action remains disabled while offline,
  read-only, syncing, conflicted, timed out, closed, expired, or missing a
  verified payment recipient. Selected-state evidence exercises the real
  amount sheet and exact selected semantics without launching a dialer or
  recording a payment.
- Rejection and remediation: the first selected capture excluded the modal
  overlay and was rejected; final evidence captures the root overlay and the
  selected RWF 10,000 chip plus visible launch action. The first light capture
  used raw club gold as text/chart foreground and was rejected in favor of the
  design system's accessible metric/chart roles. The first 200-percent ledger
  row fragmented the amount into three narrow lines and was rejected; the
  accepted layout adapts alias and amount vertically. Recursive repaint
  invalidation also corrected a transient retained app-bar layer in the
  conflict capture.
- Result: accepted for local engineering evidence. The route has explicit
  not-found, permission, offline, disabled, syncing, conflict, timeout, and
  unknown-error consequences; real focus, press, and selected feedback;
  readable light/dark roles; reduced-motion execution; complete payment safety;
  and a 320-by-720 200-percent path with reachable action and readable ledger.
- Regression: the exact route-state file passes 17 tests, the controller
  contract passes 7 tests, the payment accessibility suite passes 6 tests, the
  complete Contributions package passes 65 tests sequentially, package and
  workspace analysis report no issues, and the 614-digest governed manifest
  plus route inventory close this route at 320 evidenced and 1,660 open
  applicable cells overall.
- Approval boundary: authenticated live initiative reads, MoMo dialer launch,
  payment recording/status reconciliation, and club/RLS validation; physical
  assistive-technology/device execution; pinned CI; accountable human
  design/privacy approval; signing; and release evidence remain pending.

## 2026-07-28 Complete contribution statement route-state engineering review

- Scope: all 16 governed states on
  `/contribute/group/:groupId/statement`: loading, empty, error, offline,
  permission-denied, disabled, focused, pressed, selected, large-text, reduced
  motion, dark, light, syncing, conflict, and security timeout.
- Inspection: Codex inspected the final dark, light, selected, conflict, and
  320-by-720 200-percent production-route captures at source resolution, along
  with exact assertions for the remaining states. The screen uses the existing
  AFRICLUB chrome, cards, semantic roles, chips, status components, spacing,
  typography, and action patterns.
- Behavior and privacy: a typed gateway/controller now resolves club scope,
  bounds the contribution range to 200 rows and every load to 12 seconds,
  coalesces refreshes, fails offline before gateway access, retains confirmed
  entries through degraded refreshes, refreshes after reconnect, and maps raw
  policy, account, row, revision, and transport diagnostics to safe failures.
  Preview and CSV output contain only bounded public aliases, amounts,
  canonical statuses, and dates; internal IDs, names, phone numbers, MoMo
  references, and account details are excluded.
- Interaction integrity: the CSV action is placed before secondary filters,
  stays blocked while offline, read-only, syncing, conflicted, timed out, or
  permission-denied, and uses real focus and held-pointer feedback. Date
  filters and sort chips are functional, amount selection exposes real
  selected semantics, and PDF is explicitly labelled unavailable rather than
  presented as working.
- Rejection and remediation: the legacy implementation had blank sort chips,
  retained internal contribution IDs and MoMo references for export, performed
  direct unbounded queries in widget state, discarded content during refresh,
  conflated failures, and placed the primary action after secondary controls.
  The accepted production route replaces each defect with the typed,
  fail-closed contract above. The first 200-percent test could not build the
  lazily positioned action from the initial viewport; the final deterministic
  test scrolls the real production list until that action is built and proves
  it remains reachable without clipping or shortcut fixtures.
- Result: accepted for local engineering evidence. The route has explicit
  empty, permission, offline, disabled, syncing, conflict, timeout, and unknown
  consequences; real focus, press, and sort-selection feedback; readable
  light/dark semantic roles; reduced-motion execution; privacy-safe preview and
  CSV generation; and a complete 320-by-720 200-percent path.
- Regression: the exact state file passes 17 tests, the controller/privacy
  contract passes 7 tests, the complete Contributions package passes 89 tests,
  package and workspace analysis report no issues, and the 630-digest governed
  manifest plus regenerated route inventory close this route at 336 evidenced
  and 1,644 open applicable cells overall.
- Approval boundary: authenticated live club/RLS/date-range validation,
  user-accepted clipboard behavior, file and PDF delivery, physical
  assistive-technology/device execution, pinned CI, accountable human
  design/privacy approval, signing, and release evidence remain pending.

## 2026-07-28 Contribution redirect-contract engineering review

- Scope: the three shipping redirect paths `/contribute`,
  `/contribute/projects`, and `/contribute/groups`, including their applicable
  error, permission-denied, and security-timeout consequences.
- Authority correction: current module registration and presentation decisions
  prove that all three paths intentionally consolidate into
  `/fanzone?section=supporters`. The legacy `GroupsScreen` is dormant and is not
  a shipping surface, so duplicate-route resurrection was rejected.
- Executable navigation: four widget tests execute every exact source path
  through GoRouter, assert the final URI including the Supporters query
  parameter, and verify all three presentation decisions declare that same
  registered target.
- Visual consequence review: the redirect sources render no independent
  surface. Their three applicable consequences therefore link only to the
  already governed production Fan Zone error, permission-denied, and
  security-timeout executions. No placeholder or duplicate redirect goldens
  were introduced; the other 13 states per redirect remain explicitly not
  applicable.
- Result: accepted for local engineering evidence. The golden registry remains
  at 630 SHA-256 baselines, while the regenerated route ledger advances to 345
  evidenced, 1,635 open applicable, and 564 not-applicable cells. All three
  contribution redirects report `evidence_complete`; global closure remains
  false.
- Regression: the redirect contract passes 4 tests, the complete Contributions
  package passes 93 tests, and package plus workspace analysis report no
  issues.
- Approval boundary: authenticated live target behavior, pinned CI, physical
  device execution, accountable human design/privacy approval, signing, and
  release evidence remain pending.

## 2026-07-28 Target-governed compatibility redirect review

- Scope: 22 compatibility routes whose registered destinations already have
  complete production-route consequences: 18 Fan Zone paths, `/fan-clubs`,
  `/membership/fans`, `/my-tickets`, and `/splash`.
- Authority corrections: the Fixtures presentation decision now matches its
  runtime League-section destination. Splash metadata now matches its
  implemented Onboarding gateway; executable cases prove that safe internal
  return intent is retained while Splash loops and external URLs are rejected.
- Executable navigation: 30 focused tests start from every exact source path,
  including concrete league, standings, and team parameters, and assert the
  final path and query. Presentation decisions are checked against the same
  destination contract.
- Visual consequence review: the redirect sources render no independent
  surface. Their applicable error, permission-denied, and security-timeout
  cells link only to the governed production Fan Zone, Privacy, Tickets, or
  Onboarding consequences. No placeholder or duplicate goldens were added;
  the other 13 states per redirect remain explicitly not applicable.
- Scope boundary: `/live`, `/live-match`, and
  `/fanzone/my/:predictionId/settlement` remain open because their destination
  routes are not yet evidence-complete.
- Result: accepted for local engineering evidence. The golden registry remains
  at 630 SHA-256 baselines, while the regenerated route ledger advances to 411
  evidenced, 1,569 open applicable, and 564 not-applicable cells. Forty-six
  routes now report `evidence_complete`; global closure remains false.
- Regression: full Gamification, Fan Clubs, Membership, Ticketing, and
  Onboarding packages pass 295, 16, 49, 51, and 96 tests. All five package
  analyses and workspace analysis report no issues.
- Approval boundary: authenticated live destinations, pinned CI, physical
  device execution, accountable human design/privacy approval, signing, and
  release evidence remain pending.

## 2026-07-28 Complete Match Detail and Live-alias route-state engineering review

- Scope: all 16 governed states on `/fanzone/match/:fixtureId`, plus the
  applicable error, permission-denied, and security-timeout consequences of
  `/live` and `/live-match`.
- Inspection: Codex reviewed the final dark, light, modal-focus, selected,
  conflict, and 320-by-720 200-percent production-route captures at source
  resolution. The route retains existing AFRICLUB chrome, semantic surfaces,
  match summary, tabs, team/league links, partner-pool cards, spacing,
  typography, icons, bottom sheet, and action hierarchy.
- Behavior and privacy: a typed gateway/controller bounds reads to 12 seconds
  and pool joining to 15 seconds, fails offline before gateway access,
  coalesces overlapping refreshes, retains the last confirmed match during
  degraded refresh, refreshes after reconnect, and blocks repeat joining after
  conflict or uncertain timeout. Raw account, RLS, row, repository, revision,
  transport, and policy diagnostics map to stable supporter-safe consequences.
- Interaction integrity: the selected WDW outcome exposes explicit selected
  semantics; the real Join round confirmation receives traditional keyboard
  focus and a held-pointer press; joining is unavailable while offline,
  feature-disabled, syncing, conflicted, permission-denied, already joined,
  locked, or uncertain; and every state retains a deterministic exit or
  recovery path.
- Rejection and remediation: source-resolution review found that the existing
  fixed app-bar title, trailing action, and equal-width tabs clipped at 320 by
  720 with 200-percent text. The accepted production layout shortens the
  accessible title, removes the redundant trailing action at that scale, makes
  the tabs horizontally scrollable, and preserves vertically adaptive fixture
  metadata and partner-pool content without overflow. The evidence harness also
  removes the debug banner and activates governed theme tokens.
- Redirect integrity: executable GoRouter navigation starts independently at
  `/live` and `/live-match` and lands on `/fanzone/match/live`. Neither alias
  creates a placeholder surface; their other 13 states remain structurally not
  applicable and the target supplies the three governed failure consequences.
- Result: accepted for local engineering evidence. Sixteen deterministic route
  captures are governed; Match Detail, `/live`, and `/live-match` all report
  complete local evidence.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, the complete Gamification package passes 344 tests, the Live
  package passes 14 tests, both package analyses report no issues, and the
  662-digest golden contract passes.
- Governance: the regenerated 159-route ledger contains 452 evidenced, 1,528
  open applicable, and 564 not-applicable cells. Fifty-one routes are locally
  evidence-complete; global closure and `design_complete` remain false.
- Approval boundary: authenticated live fixture, match-center, partner-pool
  read/join/settlement and multi-client reconciliation, pinned CI, physical
  assistive-technology/device execution, accountable human design/privacy
  approval, signing, and release evidence remain pending.

## 2026-07-28 Complete Prediction Detail route-state engineering review

- Scope: all 16 governed states on `/fanzone/my/:predictionId`, plus the
  applicable error, permission-denied, and security-timeout consequences of
  `/fanzone/my/:predictionId/settlement`.
- Inspection: Codex reviewed the final dark, light, selected, conflict, and
  320-by-720 200-percent production-route captures at source resolution. The
  route uses the existing AFRICLUB chrome, semantic surfaces, status roles,
  metric cards, settlement pattern, share card, spacing, typography, and
  actions.
- Behavior and privacy: a typed gateway/controller bounds reads to 12 seconds
  and cancellation to 15 seconds, fails offline before gateway access,
  coalesces overlapping refreshes, retains the last confirmed activity during
  degraded refresh, refreshes after reconnect, and blocks repeat cancellation
  after conflict or uncertain timeout. Raw account, RLS, row, repository,
  revision, transport, and internal slip identifiers map to stable
  supporter-safe consequences; the internal slip ID is not rendered, copied,
  shared, or captured.
- Interaction integrity: the selected pick exposes explicit selected
  semantics, the real Browse fixtures action receives traditional keyboard
  focus and a held-pointer press, cancellation is disabled while offline,
  feature-disabled, syncing, conflicted, or uncertain, and every state retains
  a deterministic back or recovery path.
- Rejection and remediation: the initial harness double-disposed Riverpod
  controllers, waited indefinitely on the syncing animation, and did not apply
  the light token bridge. The first accepted-state execution then exposed a
  horizontally overflowing share-card header, broken three-column detail copy,
  and severely fragmented share metrics at 200-percent text. The final harness
  has single ownership and bounded capture, activates governed theme tokens,
  and the production metrics adapt into readable rows or vertical groups.
- Redirect integrity: executable GoRouter navigation starts at a concrete
  settlement URI, preserves the dynamic prediction ID, and lands on the
  governed detail route. The redirect introduces no duplicate or placeholder
  surface; its other 13 states remain structurally not applicable.
- Result: accepted for local engineering evidence. Sixteen deterministic
  route captures are governed, all visual review defects above are remediated,
  and both the route and settlement redirect report complete local evidence.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, the Fan Zone redirect contract passes 20 tests, the complete
  Gamification package passes 320 tests, package and workspace analysis report
  no issues, and the 646-digest golden contract passes.
- Governance: the regenerated 159-route ledger contains 430 evidenced, 1,550
  open applicable, and 564 not-applicable cells. Forty-eight routes are locally
  evidence-complete; global closure and `design_complete` remain false.
- Approval boundary: authenticated live activity/cancellation/settlement and
  multi-client reconciliation, pinned CI, physical assistive-technology/device
  execution, accountable human design/privacy approval, signing, and release
  evidence remain pending.

## 2026-07-28 Complete News Article route-state engineering review

- Scope: all 16 governed states on `/live/news/:articleId`.
- Inspection: Codex reviewed the final dark, light, focused, pressed, selected,
  and 320-by-720 200-percent production-route captures at source resolution.
  The route uses the existing AFRICLUB sliver chrome, semantic surfaces, status
  chip, section header, governed-media boundary, spacing, typography, and
  interactive surface card.
- Behavior and privacy: a typed gateway/controller performs a club-scoped read
  bounded to 12 seconds, fails offline before gateway access, coalesces
  overlapping refreshes, retains the last confirmed article during degraded
  refresh, and refreshes after reconnect. Raw Supabase, RLS, row, query,
  repository, transport, and policy details map to stable supporter-safe
  consequences; media requires explicit rights and provenance inputs.
- Interaction integrity: related-story navigation is blocked while offline,
  build-disabled, conflicted, or uncertain. The current article exposes
  selected semantics, while a related story receives traditional keyboard
  focus and a held-pointer pressed state.
- Rejection and remediation: the first focus capture was pixel-identical to the
  default because it sampled before the focus animation settled. The first
  pressed capture sampled before tap recognition, while a later sample
  overscrolled past the target. The final harness settles focus and samples
  after recognition plus one animation frame, asserts the pressed shadow
  target, and produces measurable focus and press deltas.
- Accessibility and theme: the article remains scrollable at 200-percent text
  on 320 by 720 without overflow, honors reduced motion, and activates the
  governed light and dark token bridge.
- Result: accepted for local engineering evidence. Sixteen deterministic route
  captures are governed and News Article reports complete local evidence.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, the complete Live package passes 38 tests, package and
  workspace analysis report no issues, and the 678-digest golden contract
  passes.
- Governance: the regenerated 159-route ledger contains 468 evidenced, 1,512
  open applicable, and 564 not-applicable cells. Fifty-two routes are locally
  evidence-complete; global closure and `design_complete` remain false.
- Approval boundary: authenticated production article and related-story reads,
  accountable media rights/provenance and privacy/design approval, pinned CI,
  physical assistive-technology/device execution, signing, and release
  evidence remain pending.

## 2026-07-28 Complete E-ticket route-state engineering review

- Scope: all 16 governed states on `/e-ticket/:id`.
- Inspection: Codex reviewed the final dark, light, focused, pressed, selected,
  and 320-by-720 200-percent production-route captures at source resolution.
  The route preserves the AFRICLUB full-body shell, glass close control,
  perforated ticket surface, QR credential hierarchy, semantic state banners,
  typography, spacing, and tokenized wallet consequence.
- Behavior and privacy: a typed gateway/controller performs a current-user and
  resolved-club scoped read bounded to 12 seconds, fails offline before gateway
  access, coalesces overlapping refreshes, retains the last confirmed ticket
  during degraded refresh, and refreshes after reconnect. Raw Supabase, RLS,
  row, query, repository, transport, and policy details map to stable
  supporter-safe consequences.
- Credential integrity: access-disabled and authorization-denied states expose
  no QR code. Offline, conflict, and uncertain refresh states retain only the
  last confirmed credential with explicit saved/stale guidance and controlled
  recovery; the close fallback returns to the owned Tickets tab.
- Rejection and remediation: the first 200-percent capture overflowed because
  the QR, date/time row, and wallet actions were fixed horizontally. The
  production layout now shrinks the QR and stacks metadata/actions. The first
  pressed attempt held the close control long enough to show its tooltip; the
  final harness holds the actual refresh action during the retained-conflict
  state and records a distinct pressed capture.
- Accessibility and theme: the current ticket exposes selected semantics, the
  close action receives traditional focus, the route remains usable at
  200-percent text on 320 by 720, light mode activates governed light tokens,
  and reduced motion removes the scanner overlay.
- Result: accepted for local engineering evidence. Sixteen deterministic route
  captures are governed and E-ticket reports complete local evidence.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, the complete Ticketing package passes 75 tests, and package
  plus workspace analysis report no issues. The governed manifest contains
  694 exact SHA-256 baselines.
- Governance: the regenerated 159-route ledger contains 484 evidenced, 1,496
  open applicable, and 564 not-applicable cells. Fifty-three routes are locally
  evidence-complete; global closure and `design_complete` remain false.
- Approval boundary: authenticated production ticket/RLS reads, real gate
  scanning and wallet export, accountable privacy/design approval, pinned CI,
  physical assistive-technology/device execution, signing, and release
  evidence remain pending.

## 2026-07-28 Complete Ticket detail route-state engineering review

- Scope: all 16 governed states on `/tickets/detail/:id`.
- Inspection: Codex reviewed the final dark, light, focused, pressed, selected,
  conflict, and 320-by-720 200-percent production-route captures at source
  resolution. The route preserves the AFRICLUB full-height sheet hierarchy,
  tokenized fixture/access/category cards, selection border, quantity controls,
  seat action, and review flow.
- Behavior and privacy: a typed controller bounds the club-scoped fixture read
  to 12 seconds, fails offline before gateway access, coalesces refreshes,
  retains the last confirmed fixture during degraded refresh, and refreshes
  after reconnect. Payment-route verification and purchase waits are also
  bounded; raw Supabase, RLS, payment, repository, transport, and policy
  details map to stable supporter-safe consequences.
- Transaction integrity: offline review/payment remains connection-gated,
  authorization and configuration failures expose no sale controls, and an
  uncertain purchase timeout returns the supporter to My Tickets before any
  retry. Selection remains locally retained when a safe retry is possible.
- Rejection and remediation: the first 200-percent execution overflowed a
  horizontal control row by 50 pixels and truncated the primary review label.
  Access cards, official category prices, and quantity controls now stack, and
  the compact action reads `Review`. The first held-seat capture was
  incoherent; the final harness holds the authoritative conflict-refresh
  action and produces a distinct, coherent pressed state.
- Accessibility and theme: the selected access tier exposes explicit selected
  semantics, the back action receives traditional focus, reduced-motion
  execution retains task hierarchy, and dark/light variants resolve through
  the governed token bridge.
- Result: accepted for local engineering evidence. Sixteen deterministic route
  captures are governed and Ticket detail reports complete local evidence.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, the complete Ticketing package passes 99 tests, and package
  plus workspace analysis report no issues. The governed manifest contains
  710 exact SHA-256 baselines.
- Governance: the regenerated 159-route ledger contains 500 evidenced, 1,480
  open applicable, and 564 not-applicable cells. Fifty-four routes are locally
  evidence-complete; global closure and `design_complete` remain false.
- Approval boundary: authenticated production fixture/payment/RLS and
  purchase-reconciliation behavior, real MOMO and seat-map execution,
  accountable privacy/design approval, pinned CI, physical
  assistive-technology/device execution, signing, and release evidence remain
  pending.

## 2026-07-28 Complete Seat Map route-state engineering review

- Scope: all 16 governed states on `/tickets/map/:id`.
- Inspection: Codex reviewed the final dark, light, focused, pressed, selected,
  conflict, and 320-by-720 200-percent production-route captures at source
  resolution. The route preserves the AFRICLUB stadium hierarchy, pitch and
  stand colors, tokenized legend, accessible stand actions, selection summary,
  and confirmation consequence.
- Behavior and privacy: the route reuses the typed Ticket-detail controller,
  whose club-scoped fixture read is bounded to 12 seconds, fails offline before
  gateway access, coalesces refreshes, retains the last confirmed fixture
  during degraded refresh, and refreshes after reconnect. Raw query,
  repository, RLS, transport, and policy details map to stable
  supporter-safe consequences.
- Transaction integrity: disabled and authorization-denied states expose no
  selectable map; stale conflict/timeout states retain the last confirmed
  stands with an authoritative refresh. The direct-deep-link back fallback
  returns to the matching Ticket-detail route. Real-time seat inventory, holds,
  and confirmation are not inferred from the current fixture-backed map.
- Rejection and remediation: the first 200-percent selected capture left almost
  no meaningful stadium view because four large stand controls and the legend
  wrapped into multiple vertical rows. The production large-text layout now
  makes stand and legend controls horizontally scrollable, preserves a usable
  stadium view, and keeps the selected-seat summary and full-width Confirm
  action on-screen.
- Accessibility and theme: stand actions exist beyond canvas hit testing, the
  selected stand exposes explicit selected semantics, the back action receives
  traditional focus, a held authoritative refresh produces a distinct pressed
  digest, reduced-motion execution retains hierarchy, and dark/light variants
  resolve through the governed token bridge.
- Result: accepted for local engineering evidence. Sixteen deterministic route
  captures are governed and Seat Map reports complete local evidence.
- Regression: the exact state file passes 17 tests, the shared controller
  contract passes 7 tests, the complete Ticketing package passes 116 tests,
  and package plus workspace analysis report no issues. The governed manifest
  contains 726 exact SHA-256 baselines.
- Governance: the regenerated 159-route ledger contains 516 evidenced, 1,464
  open applicable, and 564 not-applicable cells. Fifty-five routes are locally
  evidence-complete; global closure and `design_complete` remain false.
- Approval boundary: authenticated production fixture/RLS and real-time seat
  availability/hold/confirmation behavior, accountable privacy/design
  approval, pinned CI, physical assistive-technology/device execution, signing,
  and release evidence remain pending.

## 2026-07-28 Complete Fan Club detail route-state engineering review

- Scope: all 16 governed states on `/fan-clubs/:clubId`.
- Inspection: Codex reviewed the final dark, light, focused, pressed, selected,
  conflict, and 320-by-720 200-percent production-route captures at source
  resolution. The route preserves the AFRICLUB club header, public status and
  region hierarchy, snapshot cards, matchday agenda, and canonical Supporters
  handoff.
- Behavior and privacy: a typed controller bounds the approved-public-club
  read to 12 seconds, fails offline before gateway access, coalesces refreshes,
  retains the last confirmed club during degraded refresh, and refreshes after
  reconnect. Raw Supabase, RLS, query, transport, and policy diagnostics map to
  stable supporter-safe consequences. Permission/query failures are not
  disguised as official-register misses.
- Workflow integrity: disabled and authorization-denied states expose no club
  projection. Stale conflict/timeout states retain confirmed public details
  with authoritative refresh guidance. The direct-deep-link fallback returns
  to `/fanzone?section=supporters`, and the previous false “Request sent”
  action is replaced by a truthful handoff to the canonical membership
  workflow.
- Rejection and remediation: initial normal-width evidence broke `ACTIVE` and
  `Kigali` across narrow three-column stat cards, while the first 200-percent
  capture truncated `OPEN SUPPORTERS`. The production stats now use a
  two-plus-one adaptive layout, large text stacks the route content, and the
  concise `SUPPORTERS` action remains fully visible with an expanded semantic
  label.
- Accessibility and theme: the current club exposes selected semantics, the
  back action receives traditional focus, a held authoritative refresh
  produces a digest-distinct pressed capture, reduced-motion execution retains
  hierarchy, and dark/light variants resolve through the governed token
  bridge.
- Result: accepted for local engineering evidence. Sixteen deterministic route
  captures are governed and Fan Club detail reports complete local evidence.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, the complete Fan Clubs package passes 40 tests, and package
  plus workspace analysis report no issues. The governed manifest contains
  742 exact SHA-256 baselines.
- Governance: the regenerated 159-route ledger contains 532 evidenced, 1,448
  open applicable, and 564 not-applicable cells. Fifty-six routes are locally
  evidence-complete; global closure and `design_complete` remain false.
- Approval boundary: authenticated production `fanclubs`/RLS reads, official
  public-register authority/freshness, real Supporters membership behavior,
  accountable privacy/design approval, pinned CI, physical
  assistive-technology/device execution, signing, and release evidence remain
  pending.

## 2026-08-01 GAME-MOB-02 participant-code retirement review

- The 2026-07-28 TV Game Join and Game Controller sections below are retained
  as historical evidence only. They no longer describe the production
  `/fanzone/game` or `/fanzone/game/:sessionId` routes.
- Both routes now render the code-free `ParticipantLiveGamesScreen`; the Fan
  Zone action says “Live games,” and its supporting copy no longer frames TV
  code entry as a participant journey.
- The obsolete participant join form, local TV-code validator, session
  controller, repository surface, providers, public exports, and their tests
  were removed. The `game-session-action` participant join now requires a
  validated session UUID and does not accept a join code.
- Four affected Fan Zone baselines were compared against their former exact
  captures before admission. The differences are limited to the intended
  “Live games” label and shorter code-free supporting copy; layout, hierarchy,
  target sizing, theme, and reachability remain intact.
- Owner `My TVs` pairing remains separate: its validated one-time challenge,
  `/my-tvs/pair` route, and `pairing_code` exchange are intentionally retained.
- Shared/live session execution, physical-device notification entry,
  accountable review, signing, stores, deployment, and release remain open.

## 2026-07-28 Complete TV Game Join route-state engineering review (historical)

- Scope: production mobile route `/fanzone/game`, its typed join controller,
  the complete local form/recovery contract, and sixteen deterministic
  route-state captures.
- Product truth: the selected TV Code method explains that the TV leads and
  the phone stays a private controller. The route explicitly states that
  joins and answers need a live connection, are server-confirmed, and are
  never queued offline.
- Mutation safety: code format is validated locally; offline requests fail
  before gateway access; concurrent joins coalesce; the 12-second mutation
  bound requires a server response before navigation; reconnect never
  replays a join; and an uncertain timeout blocks repeat submission until the
  supporter deliberately edits the attempt.
- Consequences and navigation: disabled, permission, conflict, timeout, and
  unknown failures are explicit and sanitized. Conflict keeps the code field
  editable while submission remains blocked. A direct deep link returns to
  `/fanzone` when there is no route to pop.
- Visual review: dark and light hierarchy, real code-field focus, held action
  press, selected semantics, conflict recovery, syncing, and all fail-closed
  consequences are readable. The first conflict state contradicted its edit
  guidance by disabling the code field, and both initial 200-percent helper
  lines truncated. Production behavior and concise complete helper copy were
  corrected, the goldens regenerated, and the final source-resolution
  captures re-reviewed.
- Accessibility and theme: the code field receives traditional focus, the
  held Join Game pointer produces a measured scale below one, TV Code exposes
  selected semantics, reduced-motion execution retains the hierarchy, and
  the 320 by 720 200-percent form keeps essential guidance and the action
  reachable without essential ellipsis.
- Result: accepted for local engineering evidence. Sixteen deterministic
  route captures are governed and TV Game Join reports complete local
  evidence.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, the complete Gamification package passes 368 tests, and
  package plus workspace analysis report no issues. The governed manifest
  contains 758 exact SHA-256 baselines.
- Governance: the regenerated 159-route ledger contains 548 evidenced, 1,432
  open applicable, and 564 not-applicable cells. Fifty-seven routes are
  locally evidence-complete; global closure and `design_complete` remain
  false.
- Approval boundary: authenticated production join/RLS execution, audit-row
  idempotency under retry and multi-client races, real TV handoff,
  accountable privacy/design approval, pinned CI, physical
  assistive-technology/device execution, signing, and release evidence remain
  pending.

## 2026-07-28 Complete live Game Controller route-state engineering review (historical)

- Scope: production mobile route `/fanzone/game/:sessionId`, its typed
  controller/gateway boundary, bounded live read/join/answer contract, and
  sixteen deterministic route-state captures.
- State authority and privacy: the former error fallback fabricated a live
  question, answer pad, and leaderboard. Failed and missing reads now show
  only fail-closed consequences; retained content is always a prior confirmed
  server projection, and the TV answer-payload leak guard remains active.
- Read and recovery safety: reads are bounded to 12 seconds, offline preflight
  prevents gateway access, concurrent reads coalesce, confirmed state remains
  visible during degraded refresh, and reconnect requests one refresh without
  replaying a mutation.
- Mutation safety: display names are validated; joins and answers are bounded
  and blocked offline/stale; one answer intent uses a stable
  session/question/player idempotency key independent of option choice; local
  lock follows server success only; and uncertain joins or answers remain
  blocked until authoritative state proves the outcome.
- Visual review: dark hierarchy, form focus, held answer press, locked answer
  selection, offline/conflict/timeout consequences, syncing, and 200-percent
  controls are coherent. The first light capture exposed weak gold accent
  contrast, so session codes, question labels, chips, borders, icons, ranks,
  and scores now resolve through the theme-aware semantic accent.
- Accessibility and adaptation: current-session and locked-answer semantics
  are explicit, held press produces a measured scale below one, reduced-motion
  execution retains hierarchy, and 320 by 720 at 200-percent text replaces
  the two-column grid with full-width 64-pixel answer controls.
- Result: accepted for local engineering evidence. Sixteen deterministic
  captures are governed and live Game Controller reports complete local
  evidence.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, the complete Gamification package passes 392 tests, and
  package plus workspace analysis report no issues. The governed manifest
  contains 774 exact SHA-256 baselines.
- Governance: the regenerated 159-route ledger contains 564 evidenced, 1,416
  open applicable, and 564 not-applicable cells. Fifty-eight routes are
  locally evidence-complete; global closure and `design_complete` remain
  false.
- Approval boundary: authenticated production session/RLS behavior, live
  TV-to-controller synchronization, join audit and answer first-claim/
  idempotency races, realtime reconnect/soak, accountable privacy/design
  approval, pinned CI, physical assistive-technology/device execution,
  signing, and release evidence remain pending.

## 2026-07-28 Complete Share Card route-state engineering review

- Scope: production mobile sheet `/fanzone/share`, its typed history and
  platform-action boundary, and sixteen deterministic route-state captures.
- Data authority and privacy: the sheet renders only confirmed prediction
  history. Share payload construction omits prediction, fixture, slip, user,
  and account identifiers; authorization rejection fails closed without
  rendering retained private activity, and raw repository/platform diagnostics
  are sanitized.
- Read and recovery safety: history reads are bounded to 12 seconds, offline
  preflight prevents repository access, concurrent reads coalesce, selection
  survives authoritative refresh when still valid, retained content stays
  visible during degraded refresh, and reconnect requests one refresh without
  replaying a platform action.
- Platform-action truth: share and clipboard operations use the public card
  payload, are bounded to 12 seconds, block overlap and offline execution, and
  return only local platform completion. An uncertain timeout blocks repetition
  until the supporter checks the share sheet or clipboard and deliberately
  acknowledges the warning; no claim is made that a destination published,
  received, or retained the content.
- Visual review and remediation: dark, light, focus, held selector press,
  selected-card change, offline/conflict/timeout consequences, syncing, and
  200-percent text were inspected at source resolution. The first light capture
  exposed weak accent foreground contrast and the first large-text capture hid
  the action relationship; foreground accent roles now use the shared
  4.5-to-1 metric normalization and the reviewed capture shows stacked
  full-width Share and Copy actions.
- Shared regression: the contrast remediation also affects the Share Card
  embedded in Prediction Detail. Its sixteen exact baselines were regenerated
  and reviewed, without adding route-state credit or changing the baseline
  count beyond the sixteen new Share Card images.
- Accessibility and adaptation: Share has a real focus boundary, a held pointer
  produces a measured scale below one, the chosen prediction exposes selected
  semantics, reduced motion is honored, and 320 by 720 at 200-percent text
  stacks full-width actions and reflows selector labels and badges.
- Result: accepted for local engineering evidence. Sixteen deterministic
  captures are governed and Share Card reports complete local evidence.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, the complete Gamification package passes 416 tests serially,
  and package plus workspace analysis report no issues. The governed manifest
  contains 790 exact SHA-256 baselines.
- Governance: the regenerated 159-route ledger contains 580 evidenced, 1,400
  open applicable, and 564 not-applicable cells. Fifty-nine routes are locally
  evidence-complete; global closure and `design_complete` remain false.
- Approval boundary: authenticated production history/RLS behavior, physical
  share-sheet and clipboard execution on supported targets, destination
  application behavior, assistive-technology/device execution, accountable
  privacy/design approval, pinned CI, signing, and release evidence remain
  pending.

## Complete Venue Check-in route-state engineering review

- Route: `/fanzone/venue`.
- Evidence: sixteen exact captures cover loading, empty/ready, error, offline,
  permission denial, disabled access, real focus, held press, selected consent,
  200-percent text, reduced motion, dark, light, syncing, conflict, and
  security timeout.
- Mutation safety: the production gateway resolves club scope, normalizes and
  SHA-256 hashes the rotating code before RPC transport, uses a one-attempt
  idempotency key, and never queues or replays an offline or uncertain attempt.
- Privacy: raw rotating codes and precise coordinates are absent from governed
  evidence. The screen explicitly says local consent is not location
  verification and this build sends no coordinates.
- Visual review: light, dark, focused, pressed, selected, timeout, and
  200-percent states were inspected at source resolution. The initial
  large-text capture exposed clipped navigation chrome; the route now caps its
  single-line app-bar title while preserving full-scale task content.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 7 tests, and package analysis reports no issues.
- Governance: the manifest contains 806 exact SHA-256 baselines. The regenerated
  ledger contains 596 evidenced, 1,384 open applicable, and 564 not-applicable
  cells; 60 routes are locally evidence-complete and global closure remains
  false.
- Approval boundary: authenticated RPC/RLS behavior, live rotating-code and
  campaign data, multi-client idempotency/audit proof, approved foreground
  location, physical assistive-technology/device execution, accountable
  privacy/design approval, pinned CI, signing, and release evidence remain
  pending.

## Complete Venue Order route-state engineering review

- Route: `/fanzone/venue/order`.
- Evidence: sixteen exact captures cover loading, empty menu, error, offline,
  permission denial, disabled access, real focus, held press, selected drinks,
  200-percent text, reduced motion, dark, light, syncing, conflict, and
  security timeout.
- Product truth and safety: the production screen loads an approved venue menu
  for the supporter’s current eligible check-in. It creates only an order
  intent, requires legal-age confirmation for alcohol, never claims payment
  completion, and exposes no staff queue or fulfillment controls.
- Mutation safety: reads and order creation are bounded to 12 seconds, one
  idempotency key is retained per attempt, requests are not queued or replayed
  offline, overlaps coalesce, and an uncertain timeout blocks repetition until
  explicit acknowledgement. The source migration validates authenticated
  caller/check-in/club/venue scope and serializes idempotent creation.
- Visual review: dark, light, focused, selected, syncing, timeout, and
  200-percent states were inspected at source resolution. The first timeout
  capture clipped its recovery copy; the message was tightened and the
  regenerated capture keeps the full consequence visible.
- Accessibility and adaptation: quantity controls expose selected semantics,
  the primary action has a visible focus ring and held-press feedback, reduced
  motion is honored, and the 320 by 720 200-percent layout reflows menu content
  without clipping essential actions or guidance.
- Regression: the exact state file passes 17 tests, the controller contract
  passes 8 tests, the complete Gamification package passes 466 tests serially,
  and package analysis reports no issues.
- Governance: the manifest contains 822 exact SHA-256 baselines and the golden
  contract plus evidence-privacy scan pass. The regenerated ledger contains
  612 evidenced, 1,368 open applicable, and 564 not-applicable cells; 61 routes
  are locally evidence-complete and global closure remains false.
- Approval boundary: the source migration and pgTAP were not executed because
  an authorized Supabase target/CLI was unavailable. Authenticated RPC/RLS,
  cross-user denial, concurrent idempotency/audit, live menu/order data,
  physical assistive-technology/device execution, accountable privacy/design
  approval, pinned CI, signing, and release evidence remain pending.

## Complete FET Wallet route-state engineering review

- Route: `/fanzone/wallet`.
- Evidence: sixteen exact captures cover loading, empty history, error, offline,
  permission denial, disabled access, real focus, held press, selected Activity
  section, 200-percent text, reduced motion, dark, light, syncing, conflict,
  and security timeout.
- Product truth and privacy: the production route is a read-only projection of
  the authenticated supporter’s points balance and bounded private activity.
  It exposes neither public transfer controls nor manual-redemption controls,
  and permission revocation removes retained private ledger content.
- Recovery: route reads are bounded to 12 seconds and coalesced. Confirmed data
  survives degraded refresh, initial and retained offline states refresh once
  after reconnect, permission failures fail closed, strict repository reads do
  not misrepresent RPC failures as an empty wallet, and raw diagnostics map to
  typed user-safe consequences.
- Visual review: dark, light, focus, conflict, timeout, and 200-percent captures
  were inspected at source resolution. Balance metrics and the split-model
  header now wrap instead of overflowing, while section controls and the
  primary content remain scroll-reachable at 320 by 720.
- Accessibility and interaction: back-control focus, held overflow-button
  press, selected-section semantics, reduced motion, semantic theme colors,
  and large-text reflow are exercised by the real route.
- Regression: the state file passes 17 tests, the controller contract passes 9
  tests, the legacy route contract passes 3 tests, the complete Gamification
  package passes 492 tests serially, and package analysis reports no issues.
- Governance: the manifest contains 838 exact SHA-256 baselines. The regenerated
  ledger contains 628 evidenced, 1,352 open applicable, and 564 not-applicable
  cells; 62 routes are locally evidence-complete and global closure remains
  false.
- Approval boundary: authenticated wallet/RLS execution, production ledger
  reconciliation, physical assistive-technology/device execution, accountable
  privacy/design approval, pinned CI, signing, and release evidence remain
  pending.

## Complete Core Router recovery review

- Routes: `/feature-unavailable` and `<router-error>`.
- Evidence: thirty-two exact captures cover all 16 states for both routes,
  including real focus, held press, selected semantics, 200-percent text,
  reduced motion, dark/light, syncing, conflict, and security timeout.
- Privacy and navigation: raw router errors, requested paths, and parameters
  are not rendered. Safe labels, typed consequences, and a valid direct-entry
  fallback replace the prior diagnostic echo and history assumption.
- Review: dark, light, focused, pressed, offline, permission, timeout, and
  large-text captures were inspected at source resolution. The focused and
  pressed images have distinct hashes from default.
- Regression: 34 focused state/navigation tests and all 42 Core Router tests
  pass serially; package analysis reports no issues.

## Complete Membership Tier review

- Route: `/membership/tier/:tierId`.
- Evidence: sixteen exact captures cover loading, empty, error, offline,
  permission denial, disabled access, real focus, held press, selected tier,
  200-percent text, reduced motion, dark, light, syncing, conflict, and
  security timeout.
- Source truth: governed official category content is visibly retained through
  recoverable failures without being misrepresented as a confirmed remote
  read. Unknown identifiers are not rendered and do not resolve to another
  tier.
- Review: dark, light, focused, pressed, offline, timeout, and large-text
  captures were inspected at source resolution. Pricing now uses grouped
  digits, and the 320 by 720 200-percent layout remains scroll-reachable
  without clipped navigation or essential content.
- Regression: 9 controller tests, 19 state/navigation tests, and all 77
  Membership-package tests pass serially; package analysis reports no issues.
- Governance: the manifest contains 886 exact SHA-256 baselines. The
  regenerated ledger contains 676 evidenced, 1,304 open applicable, and 564
  not-applicable cells; all 65 mobile routes are locally evidence-complete.
  Global admin/web/API closure and `design_complete` remain false.

## Complete mobile internal-admin Competition Manager review

- Route: `/admin/competitions`.
- Evidence: sixteen exact 390 by 844 captures cover loading, empty, error,
  offline, permission denial, disabled access, real focus, held press, selected
  region, 200-percent text, reduced motion, dark, light, syncing, conflict, and
  security timeout.
- Authorization and privacy: every competition or season read and mutation
  requires a server-controlled app-metadata admin role. The workspace accepts
  only strict capped projections of 200 competitions and 300 seasons, ignores
  arbitrary private extras, clears both collections on permission loss, and
  never renders raw provider diagnostics.
- Recovery and mutation integrity: reads and mutations are bounded to twelve
  seconds, offline work fails before repository access, filters operate on the
  last confirmed snapshot without overlapping network reads, mutations
  serialize, and a timeout or conflict blocks duplicate action until an
  authoritative refresh.
- Product behavior: competition create/edit/activation and season
  create/activation remain available through controlled forms and explicit
  deactivation confirmations. Empty, unavailable, and degraded states explain
  their consequences and pause unsafe actions.
- Visual review: dark, light, large-text, focused, and pressed captures were
  inspected at source resolution. The first light capture exposed white action
  labels on a pale card; the shared semantic `onSurface` action color was
  applied and the corrected capture is readable. The 200-percent layout stacks
  metrics, wraps filters, and leaves the record and actions scroll-reachable.
- Regression: nine controller tests, fifteen state tests producing sixteen
  exact captures, the complete 101-test Admin package, and clean Core
  Theme/Admin analysis pass locally.
- Governance: the manifest contains 966 exact SHA-256 baselines. Authenticated
  live RLS and mutation behavior, multi-role competition authority, physical
  assistive-technology/device execution, accountable design/privacy approval,
  pinned CI, signing, store processing, deployment, and release approval remain
  open.

## Complete mobile internal-admin Contribution Monitor review

- Route: `/admin/contributions`.
- Evidence: sixteen exact 390 by 844 captures cover loading, empty, error,
  offline, permission denial, disabled access, real focus, held press, selected
  group type, 200-percent text, reduced motion, dark, light, syncing, conflict,
  and security timeout.
- Authorization and privacy: every private read requires a server-controlled
  app-metadata admin role. The monitor accepts only strict capped projections
  of 200 club-scoped groups and 500 contribution records; supporter IDs,
  payment references, creator IDs, and arbitrary private extras are neither
  selected nor rendered. Permission loss clears both collections.
- Recovery and integrity: reads are bounded to twelve seconds, offline work
  fails before repository access, filters and sorting operate on the retained
  confirmed snapshot, recoverable failures preserve totals, and denial clears
  records and pauses export.
- Product behavior: the route provides truthful monthly totals, group status,
  member and bounded-record counts, last activity, local group filtering and
  sorting, and a CSV-safe export without supporter or payment identifiers.
- Visual review: dark, light, large-text, focused, and pressed captures were
  inspected at source resolution. Review corrected low-contrast gold metrics
  and a white export action in the light theme, converted the status badge
  from a full-width bar to an intrinsic label, and confirmed scroll-reachable
  200-percent content.
- Regression: eight controller tests and fifteen state tests producing sixteen
  exact captures pass; the complete Admin regression, golden/privacy contract,
  and route-ledger validation are required before ledger admission.
- Governance: the manifest contains 982 exact SHA-256 baselines. Authenticated
  live RLS behavior, physical assistive-technology/device execution,
  accountable design/privacy approval, pinned CI, signing, store processing,
  deployment, and release approval remain open.

## Complete mobile internal-admin Feature Manager review

- Routes: `/admin/features` and `/admin/features/:featureKey`.
- Evidence: thirty-two exact 390 by 844 captures cover loading, empty, error,
  offline, permission denial, disabled access, real focus, held press, selected
  filter or visibility, 200-percent text, reduced motion, dark, light, syncing,
  conflict, and security timeout for both routes.
- Authorization and privacy: every private read and mutation requires a
  server-controlled app-metadata administrator role. The shared typed model
  accepts at most 100 features, four unique channels per feature, and one
  bounded rule set; it allow-lists rendered fields, rejects malformed keys,
  booleans, visibility, dates, schedules, and sort order, and ignores arbitrary
  private extras. Permission loss clears the registry or detail feature.
- Recovery and mutation integrity: reads and writes are bounded to twelve
  seconds, offline work fails before gateway access, confirmed settings survive
  recoverable refresh failures, mutations serialize, and conflict or timeout
  blocks another change until an authoritative refresh.
- Product behavior: registry status filtering, feature navigation, global
  enablement, visibility, mobile/web channel configuration, schedule selection,
  and authentication requirements remain functional through guarded controls.
- Visual review: registry and detail dark, light, large-text, focused, and
  pressed captures were inspected at source resolution. Semantic surface colors
  preserve light-theme contrast, compact badges remain intrinsic, controls
  reflow without horizontal overflow, and the full detail remains vertically
  reachable at 200-percent text.
- Regression: ten controller tests, fifteen registry-state tests, and fifteen
  detail-state tests pass, producing thirty-two exact captures. Full Admin,
  golden/privacy contracts, and regenerated route-ledger validation are
  required before final admission.
- Governance: the manifest contains 1,014 exact SHA-256 baselines.
  Authenticated live RLS and mutation behavior, cross-role and scheduling
  authority, physical assistive-technology/device execution, accountable
  design/privacy approval, pinned CI, signing, store processing, deployment,
  and release approval remain open.

## Complete mobile internal-admin Match Manager review

- Route: `/admin/matches`.
- Evidence: sixteen exact 390 by 844 captures cover loading, empty, error,
  offline, permission denial, disabled access, real focus, held press, selected
  status, 200-percent text, reduced motion, dark, light, syncing, conflict, and
  security timeout.
- Authorization and privacy: every private read and mutation requires a
  server-controlled app-metadata administrator role. The typed model accepts at
  most 200 fixtures through a strict field allow-list, rejects malformed IDs,
  dates, times, statuses, booleans, scores, prices, counts, and summaries, and
  ignores arbitrary private extras. Permission loss clears all fixture data.
- Recovery and mutation integrity: reads and writes are bounded to twelve
  seconds, offline work fails before gateway access, confirmed fixtures survive
  recoverable refresh failures, mutations serialize, and conflict or timeout
  blocks another change until an authoritative refresh.
- Product behavior: status filters remain local, while guarded create and edit
  flows support sale state, ticket prices and capacity, match status, score,
  live minute, and summary. Creation remains disabled when an empty workspace
  cannot establish a confirmed partner scope.
- Visual review: dark, light, large-text, focused, pressed, and degraded
  captures were inspected at source resolution. The first light capture exposed
  a low-contrast white edit action; the action now uses semantic surface text
  and icon colors. Filters wrap, metrics remain legible, cards retain hierarchy,
  and the complete 200-percent layout is vertically reachable.
- Regression: ten controller tests and fifteen state tests producing sixteen
  exact captures pass. Full Admin, golden/privacy contracts, and regenerated
  route-ledger validation are required before final admission.
- Governance: the manifest contains 1,030 exact SHA-256 baselines.
  Authenticated live RLS and mutation behavior, multi-role match authority,
  physical assistive-technology/device execution, accountable design/privacy
  approval, pinned CI, signing, store processing, deployment, and release
  approval remain open.

## Complete mobile internal-admin Notification workspace review

- Route: `/admin/notifications`.
- Evidence: sixteen exact 390 by 844 captures cover loading, empty history,
  private failure, offline, permission denial, disabled access, real focus,
  held press, selected audience and tier, 200-percent text, reduced motion,
  dark, light, syncing, conflict, and security timeout.
- Authorization and privacy: every private read and send requires a
  server-controlled app-metadata administrator role. The typed model accepts at
  most 50 groups and 100 notification records through strict field allow-lists,
  rejects malformed or duplicate records, validates safe HTTP(S) image
  destinations, and ignores arbitrary private extras. Permission loss clears
  all notification history and group scope.
- Recovery and delivery integrity: reads and sends are bounded to twelve
  seconds, offline work fails before gateway access, confirmed history survives
  recoverable refresh failures, sends serialize, and conflict or timeout blocks
  another delivery request until an authoritative refresh.
- Product behavior: all-supporter, tier, and group targeting; immediate or
  scheduled delivery; payload preview; bounded history metrics; and safe
  clipboard export remain functional through guarded controls without rendering
  raw provider diagnostics.
- Visual review: dark, light, large-text, empty-history, and degraded captures
  were inspected at source resolution. Audience controls wrap, the form and
  history remain vertically reachable, 200-percent content reflows without
  horizontal overflow, and status consequences remain the strongest element
  while controls are paused.
- Regression: nine controller tests and fifteen state tests producing sixteen
  exact captures pass, along with the 213-test Admin regression.
- Governance: the manifest contains 1,046 exact SHA-256 baselines.
  Authenticated live role/RLS and Edge Function behavior, real supporter
  delivery, cross-role targeting authority, physical assistive-technology and
  device execution, accountable design/privacy approval, pinned CI, signing,
  store processing, deployment, and release approval remain open.

## Complete mobile internal-admin Fixture settlement review

- Route: `/admin/settle`.
- Evidence: sixteen exact 390 by 844 captures cover loading, empty fixtures,
  private failure, offline, permission denial, disabled access, real focus,
  held press, selected status filter, 200-percent text, reduced motion, dark,
  light, syncing, conflict, and security timeout.
- Authorization and privacy: every private read and settlement requires a
  server-controlled app-metadata administrator role in the client gateway. The
  typed model accepts at most 100 fixtures through strict field allow-lists,
  rejects malformed or duplicate fixtures, score mismatches, invalid dates,
  statuses, UUIDs, and receipts, and ignores arbitrary private extras.
  Permission loss clears all fixture information.
- Settlement integrity: reads and writes are bounded to twelve seconds, offline
  work fails before gateway access, confirmed fixtures survive recoverable
  refresh failures, writes serialize, and conflict or timeout blocks another
  settlement until an authoritative refresh. The JWT-protected Edge Function
  is the client service boundary for the service-role-only settlement RPC,
  validates full-time and paired half-time scores, exposes only sanitized
  receipt fields, and cannot grade cancelled or postponed fixtures.
- Product behavior: scheduled and live fixtures alone can open the official
  result flow; finished fixtures are visibly settled, while cancelled and
  postponed fixtures are not settleable. Final and optional half-time score
  validation precedes a destructive confirmation that explains prediction
  grading and supporter-reward consequences.
- Visual review: dark, light, 200-percent text, selected, and degraded captures
  were inspected at source resolution. Filters wrap without overflow, the
  200-percent card remains vertically reachable, score and team hierarchy stay
  readable, and the paused mutation consequence remains visually dominant
  while controls are disabled.
- Regression: eleven controller tests and fifteen state tests producing sixteen
  exact captures pass. Four Deno Edge-function contract tests also pass.
- Governance: the manifest contains 1,062 exact SHA-256 baselines.
  Authenticated live role/RLS and RPC behavior, official-result authority,
  cross-role settlement UAT, physical assistive-technology/device execution,
  accountable design/privacy approval, pinned CI, signing, store processing,
  deployment, and release approval remain open.

## Complete mobile internal-admin SMS operations review

- Route: `/admin/sms-monitor`.
- Evidence: sixteen exact 390 by 844 captures cover loading, empty operations,
  private failure, offline, permission denial, disabled access, real focus,
  held press, selected health detail, 200-percent text, reduced motion, dark,
  light, syncing, conflict, and security timeout.
- Authorization and privacy: every private read requires a server-controlled
  app-metadata platform-administrator role. The typed model accepts at most
  eight known operational health metrics and 50 synchronization runs through
  strict field allow-lists, rejects malformed or duplicate records, and omits
  message bodies, supporter/user identifiers, provider diagnostics, errors,
  and arbitrary metadata. Permission loss clears all operational information.
- Recovery integrity: reads are bounded to twelve seconds, offline work fails
  before gateway access, confirmed operational information survives
  recoverable refresh failures, permission denial fails closed, and all
  interactive detail controls pause while the state is unsettled or degraded.
- Product behavior: the workspace summarizes device synchronization, message
  checks, contribution matching, sender drift, retries, and privacy cleanup,
  while recent runs expose only status, trigger, bounded counts, and timestamps.
  Selectable metric cards reveal controlled summaries without implementation
  table names or raw diagnostics.
- Visual review: dark, light, 200-percent text, selected, and degraded captures
  were inspected at source resolution. Operational hierarchy remains clear,
  metric values reflow, the complete large-text page stays vertically
  reachable, selected detail is visually distinct, and degraded consequences
  remain dominant while controls are paused.
- Regression: eight controller tests and fifteen state tests producing sixteen
  exact captures pass, along with the 266-test Admin regression and clean
  focused analysis.
- Governance: the manifest contains 1,084 exact SHA-256 baselines.
  Authenticated live role/RLS/RPC behavior, operational metric ownership,
  real-device sync audit reconciliation, physical assistive-technology/device
  execution, accountable design/privacy approval, pinned CI, signing, store
  processing, deployment, and release approval remain open.

## 2026-07-30 Revolut-reference mobile hierarchy tranche 1

- Scope: Home empty/degraded hero density, light-mode glass-shadow restraint,
  Club primary-route title treatment, and Fan Zone football-first action
  ordering. The frozen match-score hero, routes, providers, APIs, Supabase,
  dependencies, and assets were not changed.
- Golden evidence: ten Home and thirteen Fan Zone baselines changed across
  compact, standard, large-phone, wide, foldable-half, tablet, high-contrast,
  and affected route states. Codex inspected representative dark, light,
  compact, and tablet test images at source resolution before regenerating
  only `home_screen_states_test.dart` and `fanzone_hub_screen_test.dart`.
- Runtime evidence: the current source built, installed, and launched on the
  connected physical Pixel 4a. Home, Club, the Fan Zone first viewport, and
  the scrolled TV-game actions were captured locally. This is Android device
  evidence only and does not establish iPhone execution.
- Result: Home exposes Matchday and all four shortcuts within the first
  viewport when no fixture is published; Club uses the shared compact command
  title without italic or forced uppercase treatment; Fan Zone leads with
  Matchday rounds and places Supporters before TV-code and venue actions; the
  floating bottom navigation remains clear of task content.
- Regression: the complete Home and Fan Zone state files pass after the
  controlled baseline update; Club, token, scaffold, and navigation widget
  tests pass; all four affected packages analyze with zero issues; all 23
  changed digests match `docs/governance/golden-baselines.json`; and the
  automated evidence privacy scan passes.
- Open boundaries: the repository-wide golden validator is blocked by a
  pre-existing digest mismatch for
  `packages/core/core_app/test/goldens/adaptive_shell_hinge_dark_850x900.png`.
  The iOS Simulator build is blocked because Firebase Swift packages require
  iOS 15 while the generated plugin target supports iOS 13. Accountable human
  visual/privacy approval, physical iPhone and assistive-technology execution,
  pinned CI, signing, store processing, deployment, and release approval
  remain pending.

## 2026-08-01 Live Games V2 native-TV accessibility checkpoint

- Scope: the current native-TV live-game surface at deterministic 720p,
  1080p, and 4K widget dimensions; simulated overscan; EN/FR/RW long copy;
  exact 200-percent text; light/dark rendering; D-pad focus and back actions;
  reduced-motion propagation; screen-reader semantics; and automated privacy
  boundaries.
- Inspection: Codex inspected the new synthetic 1280 x 720 long-copy capture
  at source resolution. The 200-percent layout preserves readable hierarchy,
  does not overlap the status or game panels, and intentionally becomes
  vertically scrollable where the first viewport cannot contain all content.
- Rejection and remediation: the first Kinyarwanda-scope 200-percent render
  overflowed because the status pill could collapse the title column. The TV
  header now constrains the large-text status width and permits a two-line,
  ellipsized title without changing the accepted 1.7x baseline.
- Regression: the combined native-TV files pass 55 tests, the unchanged 1.7x
  baseline still matches, the new exact-200-percent digest is governed, and
  `GAME-QA-05` is enforced by the static Live Games V2 contract validator.
- Open boundaries: current native 1080p and 4K captures, physical-TV overscan,
  remote and screen-reader execution, four-hour burn-in/thermal/crash/ANR
  soak, accountable human design/privacy approval, shared/live execution,
  signing, store processing, deployment, and release approval remain open.

## 2026-08-01 Live Games V2 participant-layout checkpoint

- Scope: the exact current participant V2 route in dark, light, retained
  offline, and compact exact-200-percent states.
- Inspection: Codex compared all four source-resolution captures in one local
  contact sheet. The full-screen route has no competing bottom navigation;
  safe-area spacing, action hierarchy, answer controls, and leaderboard remain
  clear in both themes. Offline state leads with the reconnect consequence and
  privacy-safe last-confirmed time. Exact-200-percent content scrolls without
  overlap or text shrinkage.
- Regression: 23 current participant tests pass for safe area, full-screen
  isolation, compact layout, keyboard inset, EN/FR/RW exact-200-percent text,
  both themes, reduced motion, denial, offline/reconnect, timeout, lifecycle
  resume, and authoritative cross-client phases.
- Boundary: deterministic widget/golden evidence is not physical-device,
  assistive-technology, shared/live synchronization, accountable approval,
  signing, store, deployment, or release evidence.

## 2026-08-01 Live Games V2 organizer invitation-planning checkpoint

- Scope: the exact current 390 x 844 dark organizer planner after selecting
  invitation-only eligibility and one privacy-safe six-digit supporter Fan ID.
- Inspection: Codex inspected the source-resolution capture. The football-game
  planning hierarchy remains clear: approved question pack and eligibility lead,
  schedule and optional TV assignment remain distinct, the supporter invitation
  requirement is explicit, and the selected Fan ID remains readable above the
  primary create action without overlap, clipping, or hidden controls.
- Determinism: the widget route injects a fixed test clock, loads the governed app
  fonts, uses synthetic non-production data, and matches the registered SHA-256
  baseline exactly.
- Boundary: this local widget comparison does not establish shared/live role or
  RLS behavior, physical-device or assistive-technology execution, accountable
  design/privacy approval, signing, store processing, deployment, or release.

## 2026-08-01 Live Games V2 guarded organizer-control checkpoint

- Scope: the exact current 390 x 844 dark organizer control route during an
  open question, with one normal progression action and the available skip,
  pause, early-end, and cancellation exceptions.
- Inspection: Codex inspected the source-resolution capture, rejected the first
  render because three narrow metric tiles broke words, changed the metrics to
  a readable two-column wrap, regenerated the controlled baseline, and
  reinspected it. The accepted capture keeps the current question, one primary
  reveal action, and the separately styled exception controls readable without
  overlap or clipping.
- Determinism: the widget uses governed fonts and synthetic non-production
  participant, question, display, and event data at a fixed viewport. The exact
  capture matches its registered SHA-256 baseline.
- Boundary: this local widget comparison does not establish shared/live role or
  RLS behavior, real-network timing, physical-device or assistive-technology
  execution, accountable design/privacy approval, signing, store processing,
  deployment, or release.

## 2026-08-01 Live Games V2 owner-inventory checkpoint

- Scope: the exact current 390 x 844 dark My TVs route for an owner-managed
  home display with authoritative health, last seen, app version, bounded
  capabilities, and assigned-session context.
- Inspection: Codex inspected the source-resolution capture. The display name,
  home scope, online state, operational metadata, assigned game, and pairing
  action remain readable without overlap, clipping, or hidden fields.
- Determinism: the widget uses governed fonts, fixed synthetic non-production
  data, and the current localization/catalog implementation. The exact capture
  matches its registered SHA-256 baseline.
- Boundary: this local widget comparison and isolated database proof do not
  establish shared/live authorization, real-network timing, physical-device or
  assistive-technology execution, accountable design/privacy approval, signing,
  store processing, deployment, or release.

## 2026-08-01 Live Games V2 native-TV full-projection checkpoint

- Scope: five unchanged exact current-source 1280 x 720 goldens governing the
  paired-empty, question plus standings, reveal/public result, completed
  large-text, and retained-offline native-TV projections.
- Inspection: the previously admitted source-resolution states remain the
  controlling visual evidence because this closure changes projection parsing,
  tests, contracts, and metadata without changing rendered layout or assets.
  The suite matches every digest exactly. The five states keep the public game
  hierarchy, choices, correct-answer treatment, public aliases, final
  standings, offline consequence, and retry affordance readable without
  overlap, clipping, private claim information, or participant entry codes.
- Determinism: the widget routes use governed fonts, fixed synthetic
  non-production data, deterministic 1280 x 720 surfaces, and EN/FR/RW locale
  scopes. All five captures remain registered within the 1,099-baseline
  contract.
- Boundary: deterministic widget/golden and isolated-database evidence does
  not establish authorized real-network Realtime delivery, shared/live cross-
  client timing, physical-TV/remote/assistive-technology behavior, native
  1080p/4K capture, four-hour soak, accountable approval, signing, store,
  deployment, or release readiness.

## 2026-08-01 Live Games V2 current native-resolution checkpoint

- Scope: the current Android TV API 36 ARM64 APK rendered its real isolated-
  backend owner-pairing journey at exact native 1920 x 1080/320 dpi and
  3840 x 2160/640 dpi emulator profiles.
- Inspection: both source-resolution PNGs preserve the Gikundiro TV hierarchy,
  QR challenge, visible one-time code, expiry, renewal action and guidance.
  No cropping, framework overflow, configuration failure or missing primary
  action was observed. The 4K profile is an actual 3840 x 2160 framebuffer,
  not an enlarged 1080p artifact.
- Privacy: the challenge belongs to a synthetic isolated club and expired when
  the local Supabase stack stopped without backup.
- Boundary: these captures pass GAME-QA-05 native-current-resolution evidence
  only. They do not establish physical-TV overscan, physical remote or screen-
  reader use, four-hour target-hardware soak, accountable privacy approval,
  shared/live execution, signing, store, deployment or release readiness.

## 2026-08-02 organizer live-control route-state checkpoint

- Scope: fourteen exact current route-state captures for
  `/game-operations/sessions/:sessionId`; empty and selected are explicitly not
  applicable to the canonical live-session control route.
- Inspection: Codex inspected complete source-resolution loading, failure,
  offline, denial, disabled, focus, held-press, 200-percent text, reduced-motion,
  dark/light, retained-syncing, conflict, and timeout frames. The first review
  rejected passive `Lobby open` copy as a next action; the admitted UI uses the
  imperative `OPEN LOBBY`, keeps normal progression visually separate from
  exception controls, and retains complete `OPEN LOBBY` and `CANCEL SESSION`
  labels at 320 x 720 with 200-percent text.
- Determinism: the production screen uses governed fonts, fixed synthetic
  non-production session data, actual keyboard focus and held-pointer state,
  and exact 390 x 844 or 320 x 720 surfaces. All fourteen current hashes and
  the independently changed guarded-controls baseline pass the 1,348-baseline
  golden contract.
- Boundary: this local widget evidence does not establish shared/live role or
  RLS/RPC/audit behavior, real sessions/displays, physical-device assistive
  technology, accountable linguistic/design/privacy approval, clean-candidate
  CI, signing, stores, deployment, or release.

## 2026-08-02 participant discovery and live-play route-state checkpoint

- Scope: fifteen exact current captures for `/fanzone/game` and sixteen for
  `/fanzone/game/:sessionId`. Persistent selected is structurally not
  applicable to discovery because choosing a game immediately enters the
  canonical session route; confirmed answer selection is applicable to live
  play.
- Inspection: Codex inspected all thirty-one source-resolution frames
  individually. Discovery loading, empty, failure, offline, denial, disabled,
  focus, held press, 200-percent text, reduced motion, dark/light, retained
  synchronization, identity/contract conflict, and timeout remain readable and
  truthful. Live play additionally proves semantic selected answer state. No
  critical copy, action, card, or identity is cropped or exposed incorrectly.
- Determinism: the production screens use governed fonts, fixed synthetic
  non-production eligible-session and participant projections, actual keyboard
  focus, held-pointer state and semantic selection, and exact 390 x 844 or
  320 x 720 surfaces. A repeated non-updating run matches every digest and the
  complete manifest passes the 1,379-baseline golden contract.
- Boundary: this local widget evidence does not establish authenticated
  shared/live participant RLS/RPC/audit behavior, a real synchronized event,
  physical-device assistive technology, accountable linguistic/design/privacy
  approval, a clean sealed candidate, signing, stores, deployment, or release.

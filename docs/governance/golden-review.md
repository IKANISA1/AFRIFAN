# Golden baseline review

The Flutter golden suite is a controlled visual-regression gate, not a command
to accept changed pixels automatically.

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
- The current manifest contains 502 exact-pixel baselines, including exact
  Search, Home, Fan Zone, Onboarding, Settings, Membership, Tickets, Shop,
  product-detail, cart, phone-auth, and OTP-auth task-state captures.
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
   - `packages/features/feat_ticketing/test/ticketing_state_test.dart`
   - `packages/features/feat_shop/test/cart_screen_states_test.dart`
   - `packages/features/feat_shop/test/shop_screen_states_test.dart`
   - `packages/features/feat_shop/test/product_detail_screen_states_test.dart`
   - `packages/features/feat_shop/test/cart_screen_responsive_test.dart`
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

# AFRICLUB mobile design contract

The owner selected `$revolut-design` for the **whole native supporter app** on
5 September 2026. This instruction replaces the former mixed benchmark,
8 dp card, 58 dp command control, all-route gradient, heavy italic heading,
and immediate theme-selection treatments. This file is the repository design
authority; the selected skill and local source images provide its evidence.

## Scope and reference

The implementation covers the shared Flutter supporter application and all
20 configured club shells. Public web, Admin PWA and venue web retain their
existing role-specific interfaces; this mobile task does not establish their
visual parity. Internal mobile admin remains role guarded and inherits shared
accessible controls without borrowing a consumer account layout.

The primary comparator is the **5 September 2026 live native iOS Dark · Glow**
cohort in the owner's Revolut collection. Region, installed build, exact font,
device model and DPR were not read. Saved frames are 406 × 890 pixels; their
approximately 390 × 844 phone-content area is the comparison coordinate model,
not a proven device viewport. Mac frame, pointer and capture banners are excluded.
Never assign a store version to these captures. Light, Android and tablet
layouts are product/platform adapters unless independently compared.

Reference source directory (local/private):
`/Users/jeanbosco/Documents/ChatGPT/Revolut/private/native-current-20260905/`.
Selected skill: `/Users/jeanbosco/.codex/skills/revolut-design/SKILL.md`.

Use LIVE-020 for Home anatomy, LIVE-021 for a centred club proposition,
LIVE-026 for Fan Zone discovery, LIVE-047/048 for membership/card anatomy,
LIVE-005/007 for profile/settings, LIVE-010/011 for theme preview,
LIVE-033–041/051/052 for discovery lists, LIVE-053–058 for forms and
LIVE-060/062/063 for amount entry. Open each actual source before applying it.
A static frame establishes its depicted state only. Football matches, free
predictions, ticket seats, QR admission and contributions require explicit
product adaptations; no source frame proves their entire journeys.

`docs/governance/native-reference-map.json` records route mapping and evidence
status. It implements this contract and must not create separate design rules.
Redirects inherit the target's rendered evidence and retain navigation tests.
Missing comparators, states or implementation captures remain unverified.

## Identity and product truth

Keep every app's actual name, crest, icon, approved imagery, feature terminology,
club configuration, domain and legal identity. Preserve the mark's proportions,
clear space and approved variants. Source logos, financial account screenshots,
source-branded illustrations and source product names are reference-only and
must never enter runtime assets, screenshots or copy. Reference names may remain
in internal citations. Use synthetic data in implementation evidence.

## AFRICLUB Football-Club-First Product Contract

For AFRICLUB, football club identity is the governing product and visual
hierarchy. Fintech-grade polish is an interaction-quality benchmark, not the
product identity. The interface must first feel like the official digital home
of a football club.

The mandatory product priority is:

1. Club identity, team, news, fixtures, results, standings, and history.
2. Membership, fan clubs, contributions, projects, tickets, and shop.
3. Selected-match football predictions and competitions.
4. Secondary matchday utilities such as venues, check-in, drinks ordering,
   promotions, and venue-hosted football events.

The target mobile primary navigation is `Home · Club · Fan Zone · Membership`.
Settings, privacy, notifications, support, language, theme, and account
controls belong behind profile. A venue, wallet, generic entertainment, or
settings surface must not displace Club or Membership in the primary shell.

AFRICLUB screen hierarchy must follow these rules:

- Home leads with club identity and current football context: next fixture,
  live/current result, latest official news, membership state, or one relevant
  matchday action.
- Club is a first-class hub for overview, team/squad, news, fixtures, results,
  standings, history, projects, tickets, and shop.
- Membership makes belonging visible through the digital card, plan/status,
  fan clubs, contribution history/statements, and relevant club projects.
- Fan Zone contains free selected-match football predictions, approved
  competitions, points/reward context, and supporter communities.
- Matchday experiences or Places to watch contains secondary venue discovery,
  explicit check-in, a bounded drinks menu/order, and approved promotions.
- Search must discover club, team, news, fixtures, results, standings,
  projects, tickets, products, supporter communities, and approved
  venues according to permissions and availability.

Prediction presentation is safety-critical:

- predictions are free-to-enter and available only for selected approved
  matches from configured main leagues, the local league, or approved club
  competitions;
- no odds, staking, betting, cash-payout, or fantasy-squad implication is
  permitted;
- prediction eligibility, score, settlement state, and rewards display one
  authoritative cross-surface truth.

All supported club apps use the same semantic system and shared domain
contracts. Branding and configuration may vary, but shared layouts must reserve
the same hierarchy for club/football, membership, engagement, and secondary
venue utility. Rayon Sports is a reference profile, not a hardcoded shared
assumption.

## Semantic tokens and component anatomy

`packages/core/core_theme` owns the Flutter implementation through `ThemeData`,
`AfriSemanticColors`, `AfriDesignTokens` and shared components. Feature screens
compose these primitives; club configuration supplies identity and data.
The following values are **provisional measured adapters**, not claimed current
source definitions. Revise them through matched captures and component tests.

| Role | Native mobile target |
| --- | --- |
| Canvas | Neutral black tasks/settings; Home blue to deep navy, Club cyan to petrol, Fan Zone violet through blue-violet, Membership purple to neutral. Each has its own measured extent. Exact route matching keeps child tasks neutral. |
| Tonal group | Approximately `#161618` dark, stronger `#242426`; one rounded group, no separate border/shadow around each row. |
| Text | Neutral white and grey on tasks; light secondary text on tinted overview groups. UI action colours are independent of club artwork; contrast normalization remains for charts and status. |
| Command bar | 44 visual circles/search height with at least 48 hit area, own crest inside, maximum two trailing actions. |
| Bottom navigation | 64 visual height, pill enclosure, 16 horizontal inset, safe-area-aware placement, four preserved destinations. |
| Quick action | 48 circle, 24 icon, short label below; four across at standard size; adaptive wrapping for compact or enlarged text. |
| Grouped row | 56 minimum height, plain 24 icon, 16 label, 13 optional subtitle, 16 horizontal inset. Content expands with text. |
| Primary button | 52 minimum height, full pill, 16 medium label, inverse foreground/background. Secondary actions use a tonal pill. |
| Shapes | 24 ordinary card/group, 32 large hero, 24 input, full pill for buttons/search/chips/navigation. |
| Spacing | 16 screen and card inset, 24 section gap, 8 sibling gap; use one alignment column. |
| Type | 48 value, 40 proposition, 32 page title, 20 section title, 16 body/row, 13 support, 11 navigation. Normal casing and restrained weight; no blanket uppercase/italic style. |
| Font | Native platform system font adapter. `GoldenRoboto` is deterministic test-only output and is not proof of exact iOS font parity. |
| Elevation | Flat tonal content; translucency/blur confined to evidenced floating chrome and overlays. Focus/high contrast and explicit semantic boundaries remain visible. |

Motion uses the existing interruptible duration tokens and reduced-motion paths.
A still reference does not establish timing. Do not auto-advance reading content
or simulate a successful financial/action outcome for visual effect.

## App shell and route anatomy

- Home: command row, centred current football object, four primary shortcuts,
  then membership and editorial content. Preserve CMS placement controls and
  truthful loading/empty/recovery states. No duplicate match strip or fabricated
  match, score, image or club metadata.
- Club: own identity and concise proposition followed by grouped routes for
  team, news, fixtures, results, standings, history, projects, tickets and shop.
- Fan Zone: centred engagement value only when available, appropriate local
  segments, then discoveries and supporter tasks. Venue utilities remain secondary.
- Membership: own digital card/status followed by benefits, tier, fan clubs,
  contributions, projects and history. Mask identity in shared evidence.
- Profile/settings: centred own identity where applicable, a membership row,
  then full-width continuous groups. Task pages use large left-aligned titles
  and neutral surfaces. No unrelated decorative hero.
- Appearance: preview current app canvases with a local Light/Dark/System draft.
  Apply commits once. Cancel, Back and dismissal discard the draft. Selection
  is indicated semantically and by a visible ring. Follow system brightness.
- Lists/search: one query surface, relevant filters and grouped results; retain
  loading, no results, offline and retry paths. Use bounded/lazy result rendering.
- Forms: clear title, persistent field labels, tonal fields, platform keyboard,
  inline validation, draft preservation and reachable submit/cancel actions.
- Checkout/contribution/membership changes: amount and counterparty, review,
  authoritative pending/confirmed/failure status and existing receipt/history.
  Payment initiation never implies confirmation. Preserve idempotency and guards.
- Detail: one object and its actual status, metadata, primary action and history.
  Approved product images retain stable bounds, loading and failure states.
- Onboarding/auth: preserve anonymous entry and real phone/OTP flows. Do not
  copy a bank passcode flow or introduce linking/payment requirements at launch.
- Unavailable routes: generic requested-section copy, safe back/recovery, no
  hidden entitlement or provider details.

## Copy and interaction

Use `core_l10n` for static text and approved repositories for dynamic content.
Keep labels concise, normal-case and task-specific. Do not case-normalize IDs,
currency codes, backend enums or abbreviations as a visual shortcut. Errors
explain what happened and the safe next action; raw traces stay out of supporter
UI. Consequential actions retain review/confirmation or undo appropriate to the
existing workflow. Selection and status never depend on colour alone.

## State Requirements

Every screen and reusable component must cover these State Requirements:

- Loading: skeleton or progress that preserves layout and labels the pending action for assistive tech.
- Empty: clear zero-data state with one useful next action.
- Error: human-readable cause, retry, support, and technical trace only where safe.
- Offline: cached content where possible, sync status, retry, and clear disabled network actions.
- Permission denied: explain consequence, provide settings path, and keep alternate routes usable.
- Disabled: visible, semantic, and accompanied by context when the reason is not obvious.
- Focused: visible focus ring for keyboard, switch, screen reader, and desktop modes.
- Pressed: immediate tactile visual feedback.
- Selected: persistent state with semantic selection labels.
- Large text: layouts survive at least 200 percent text scale without overlap.
- Reduced motion: all motion-heavy transitions have a reduced alternative.
- Dark mode: intentional token values, not inverted light mode.
- Light mode: preserve the target dark mode feature set and accessible roles.
  Current source-native light visual fidelity is unverified.
- Syncing: nonblocking progress for background refresh.
- Conflict: explicit resolution UI for stale or conflicting data.
- Security timeout: predictable locked or re-auth state.

## Responsive And Adaptive Standard

The responsive contract covers these viewport bands:

- 320-374 dp: compact phones. Single-column layout, shorter labels, no text overlap, no horizontal scrolling except intentional carousels.
- 375-430 dp: standard phones. Primary optimized design target.
- 431-599 dp: large phones. Add breathing room without stretching controls.
- 600-719 dp: small tablets and foldable half-screen. Consider two-pane layouts only when hierarchy improves.
- 720+ dp: tablets, foldables, desktop shells. Use adaptive columns, side rails, persistent secondary panes, and larger hit areas.
- Landscape: preserve primary task flow, keyboard safety, and top/bottom chrome stability.
- Foldables: avoid hinge-obscured content, support posture changes, and preserve route state.
- Keyboard open: inputs remain visible with error text and submit controls reachable.

No text, icon, media, chip, badge, or button label may overlap or overflow its parent in these bands.

## Admin Panel Standard

Admin panels must use the same premium design system without pretending to be consumer mobile screens. The goal is calm operational density: fast scanning, strong hierarchy, safe actioning, and complete auditability.

### Admin Information Architecture

- Use a persistent side rail or sidebar on desktop and tablet, with compact top chrome for account, search, alerts, and command actions.
- Use bottom navigation only on narrow admin mobile fallback views, and only for essential admin destinations.
- Organize around queues, records, dashboards, reports, audit logs, settings, and support tools.
- Keep list surfaces summary-first; move detail, history, permissions, and destructive actions into a detail panel, drawer, sheet, or route.
- Separate consumer/user flows from admin/operator flows in route guards, navigation, copy, analytics, screenshots, and tests.

### Admin Data Surfaces

- Tables must support sorting, filtering, search, pagination or virtualization, column priority, empty/error/loading/offline states, and keyboard navigation.
- Compact card/list mode is required below tablet width; columns must not squeeze until text overlaps.
- Bulk actions require selection count, scope summary, permission check, review step, undo or confirmation, and audit event.
- Metrics must show label, value, trend, time window, freshness, and failure/degraded state.
- Audit logs must be readable by default, with raw JSON or technical metadata collapsed behind an explicit control.

### Admin Visual Language

- Use role-specific operational surfaces, concise headers, chips, badges, and shared accessible controls. The native supporter reference does not establish desktop operator layout.
- Admin may use higher density and stronger grid alignment, but it must not use unrelated colors, shapes, table styles, or modal patterns.
- Primary destructive actions must never sit visually next to harmless actions without a confirmation pattern.
- Admin routes must include permission denied, unauthenticated, out-of-role, stale data, partial failure, empty queue, and high-volume states.

## Accessibility Standard

- Meet WCAG 2.2 AA contrast for text and meaningful UI controls.
- Support screen readers with meaningful labels, roles, values, hints, and traversal order.
- Every icon-only button has a semantic label and tooltip where applicable.
- Focus order follows visual and task order.
- Touch targets are at least 48 dp, with 44 dp as the minimum only for dense icon controls.
- Dynamic type must preserve layout at 200 percent text scale.
- Color is never the only way to convey state.
- Error messages are programmatically associated with fields.
- Motion respects reduced motion settings.
- Haptics must not be required to understand state.
- Forms support autofill, platform keyboards, input masks, and validation timing appropriate to field risk.

## Visual QA Standard

Visual QA Standard gates must include:

- route screenshot coverage for every production route and critical modal/sheet state.
- golden or snapshot tests for shared components and design tokens.
- light and dark screenshots for all primary screen archetypes.
- small phone, standard phone, large phone, tablet, landscape, and keyboard-open screenshots.
- Admin screenshots for desktop, tablet, compact fallback, dense table, card/list fallback, filter open, detail panel, bulk selection, permission denied, stale data, and high-volume states.
- loading, empty, error, offline, disabled, focused, selected, and permission-denied states.
- pixel checks for blank screens, clipped text, overlapping controls, missing images, and wrong theme mode.
- accessibility scans for contrast, semantics, focus order, touch targets, keyboard operation, screen reader labels, large text, and reduced motion.
- performance checks for first frame, animation jank, scroll stability, memory pressure, large lists, and admin table virtualization.

Visual evidence must use sanitized data. Screenshots must not expose secrets, raw phone numbers, OTPs, private customer data, production tokens, or private account identifiers.

## Implementation and verification

Keep providers, repositories, domain models, server validation, role guards and
canonical routes separate from presentation. Keep the 20 app shells thin.
Use existing widget, route, golden and accessibility harnesses; do not add a
parallel test framework. Tokens and generation are not visual evidence.

For each applicable route/state:

1. Record the source image, cohort, theme, date, known viewport/build and mapping
   type: direct comparator, component/pattern, or unevidenced adaptation.
2. Capture the implementation with synthetic data at matched viewport/state.
3. Inspect both images for hierarchy, geometry, type, surfaces, logo behaviour,
   safe areas and content density; record and correct material differences.
4. Exercise the entire task, including navigation, keyboard, review, cancellation,
   recovery, outcome, screen-reader semantics and enlarged text.
5. Re-capture after changes. Record actual source revision and unresolved cells.

The existing route inventory, component inventory and governance registries
remain the evidence mechanisms. Golden updates establish regression baselines;
they do not automatically mark a reference comparison as passed. A changed
contract invalidates old design certification while retaining useful tests.

A 100% fidelity claim requires every applicable route/state to have a comparator,
no unexplained material visual mismatch, and verified corresponding interactions.
Unknown source characteristics and missing runtime evidence must be disclosed.
Any percentage must state numerator, denominator, exclusions and method.
Do not turn a checklist count into pixel equivalence.

Report design fidelity, usability, accessibility, performance, runtime resilience,
local checks, hosted CI, deployment, device UAT and store/provider acceptance
separately. No generated document, successful compile or screenshot grants
release approval. The owner's current authorization governs external actions.

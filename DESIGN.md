# AFRICLUB Universal App Design Standard 2026

This document is the single design authority for this repository. Any production mobile app, admin panel, Flutter-first web shell, native iOS or Android app, React Native app, or embedded app surface must use this file as its design contract. No secondary design folder, screenshot parity matrix, token JSON, design-system markdown, source-variant asset folder, provenance note, or archived design report may override this standard.

This standard is built from current platform guidance, local implementation evidence, and the Revolut reference grammar. Revolut is the interaction-quality benchmark for hierarchy, density, chrome, motion, and state polish; AFRICLUB remains a football-club product with its own identity, data, routes, accessibility obligations, and legal boundaries. Product teams must not copy finance, crypto, rewards, card, regulated, or account semantics merely to resemble the reference.

## Universal Design Goal

Build a world-class product suite that feels calm, fast, premium, trustworthy, and task-focused across mobile, web, venue, and admin surfaces. The interface should combine modern fintech-grade polish with universal product patterns: compact hierarchy, confident typography, thumb-first and keyboard-first actions, resilient state handling, motion that clarifies changes, inclusive accessibility, and adaptive layouts that scale from small phones to tablets, foldables, desktop shells, and dense operator consoles.

The standard is intentionally universal. Product teams must replace domain examples with their own truthful product data, but must keep the system principles, token model, component contracts, state requirements, quality gates, and Flutter implementation rules.

## Design references and verification

The design principles below govern the current product. Reference apps inform
interaction quality, not AFRICLUB content, financial semantics, or release
status. The implementation is in `packages/core/core_theme`, the app shell,
and the feature packages.

Validate source, screenshots, accessibility, and responsive states against the
candidate under review. Generated route and component inventories are coverage
reports, not approval. Capture evidence afresh when source or runtime changes;
missing captures and named reviews remain open. This design standard does not
assert a build, deployment, store, or full-design completion status.

Authoritative external references:

- Flutter adaptive and responsive design: https://docs.flutter.dev/ui/adaptive-responsive
- Flutter accessibility: https://docs.flutter.dev/ui/accessibility
- Flutter focus system: https://docs.flutter.dev/ui/interactivity/focus
- Flutter Actions and Shortcuts: https://docs.flutter.dev/ui/interactivity/actions-and-shortcuts
- Apple Human Interface Guidelines: https://developer.apple.com/design/human-interface-guidelines
- Material 3 navigation rail: https://m3.material.io/components/navigation-rail/overview
- Apple Design Awards 2026: https://developer.apple.com/design/awards/
- Revolut App Store accessibility and platform listing: https://apps.apple.com/us/app/revolut-send-spend-and-save/id932493382
- Revolut mobile banking product page: https://www.revolut.com/en-GR/ways-to-bank/mobile-banking/
- Uber App Store listing: https://apps.apple.com/us/app/uber-request-a-ride/id368677368
- Airbnb App Store listing: https://apps.apple.com/us/app/airbnb/id401626263
- Spotify App Store listing: https://apps.apple.com/us/app/spotify-music-and-podcasts/id324684580
- Microsoft Fluent 2 design tokens: https://fluent2.microsoft.design/design-tokens
- IBM Carbon data table: https://carbondesignsystem.com/components/data-table/usage/
- Shopify Polaris tables: https://polaris-react.shopify.com/components/tables
- Atlassian empty state: https://atlassian.design/components/empty-state/
- WCAG 2.2: https://www.w3.org/TR/WCAG22/

## World-Class Benchmark Synthesis

The standard is not based on taste alone. The following benchmarks convert observed leading-product behavior and official design-system guidance into enforceable product rules:

| Evidence | What It Proves | Rule For This System |
| --- | --- | --- |
| Revolut local screenshots and current public listing | A premium financial app can use a dark immersive shell, black command chrome, large numeric hero, circular actions, low-copy rows, and accessibility claims including VoiceOver, larger text, dark interface, contrast, non-color-only state, and reduced motion. | Mobile surfaces must combine high trust with low friction: first-viewport value, compact commands, semantic state colors, no color-only meaning, and large-text/dark/reduced-motion coverage. |
| Revolut mobile banking product page | A broad financial product succeeds by putting budgeting, security, support, identity verification, transfers, and account control into one mobile app without losing the central money-management job. | Complex products need a stable app shell and a clear primary value per screen; breadth belongs in navigation and secondary panels, not in the first viewport. |
| Apple Design Awards 2026 | Apple rewards apps for delight, inclusivity, innovation, interaction, social impact, and visuals, with examples emphasizing simple scanning, no-reading interactions, accessibility options, full-screen data, and strong platform integration. | World-class design must include interaction quality, inclusive defaults, platform-native behavior, and polished visual execution, not only attractive screens. |
| Uber public listing | High-scale mobility products foreground fast task completion, upfront pricing, location, safety, reliability, localization, and frequent performance fixes. | Transactional mobile flows must show destination, cost or consequence, status, safety/recovery actions, and live reliability states before ornamental content. |
| Airbnb public listing | Travel products combine discovery, personalized recommendations, booking detail, messaging, offline trip information, and host/operator tooling in one app. | Multi-sided products need role-specific information architecture, trip/task continuity, offline-readable critical details, and separate operator workflows. |
| Spotify public listing | Media products scale through search, personalization, library management, offline access, and dense content discovery. | Discovery surfaces need fast search, personal relevance, saved/recent states, media placeholders, and scalable list/grid performance. |
| Flutter, Material 3, and Apple HIG guidance | Production apps must adapt to device class, input mode, platform convention, safe area, focus, accessibility, and testing constraints. | Flutter implementation must treat responsiveness, focus, keyboard, semantics, and platform adaptation as first-order architecture. |
| Fluent 2 tokens | Large product suites separate raw/global values from semantic alias tokens so teams share a language and avoid hardcoded styling. | This system must use semantic Flutter `ThemeExtension` tokens for every color, spacing, radius, shadow, motion, density, focus, and surface role. |
| Carbon, Polaris, and Atlassian admin guidance | Admin surfaces need tables, sorting, filtering, selection, batch actions, pagination, keyboard operation, clear empty states, and next actions. | Admin design must be dense but auditable: table/list modes, filters, detail panels, bulk-review flows, empty/error states, and keyboard/screen-reader coverage are mandatory. |

World-class benchmark conclusion: the target is not "make it look like one app." The target is to combine Revolut-level premium shell quality, Apple-level inclusive interaction polish, Material/Flutter adaptive engineering, and enterprise-grade admin data handling into one coherent system.

## Reference Screenshot Lessons

The accepted live Revolut screenshot base defines the required interaction grammar for this system. It is not optional inspiration; it is the benchmark for density, hierarchy, contrast, command chrome, navigation, and polish. Motion remains a benchmark supported by public research rather than a completed matched-state capture in this run. Use the reference to extract durable UI rules while replacing all product data, copy, regulated claims, brand marks, icons, and unsupported flows with truthful product-owned content.

The visible reference grammar is:

- Put the primary user value in the first viewport.
- Use a saturated top gradient that resolves into a near-black lower shell when the product surface benefits from a premium immersive frame.
- Keep top chrome compact: avatar or identity marker, black search pill, and one or two circular command actions.
- Use one dominant hero value, object, title, or identity moment before secondary lists.
- Prefer four or fewer circular quick actions with short labels and clear icon roles.
- Prefer icon-led metadata, concise labels, and readable numbers over verbose instruction blocks.
- Use full-width dark translucent panels with restrained borders for grouped content.
- Use cards for repeated items and framed tools, not for every page section.
- Use white, black, or tonal pill CTAs before saturated rectangular buttons unless a semantic status requires color.
- Keep bottom navigation floating, dark, stable, thumb-accessible, and branch-preserving where depth requires it.
- Make empty, loading, offline, error, disabled, selected, pressed, focused, and permission states feel designed rather than bolted on.
- Use background, elevation, blur, opacity, and tonal contrast to separate zones without visual noise.
- Let each primary route use one controlled atmospheric field: Invest uses teal, Crypto uses blue, RevPoints uses purple and editorial imagery, while the stable black chrome keeps the system coherent.
- For visual preference controls, show the appearance consequence before applying it; the observed Theme flow separates phone-shaped previews from the Light, Dark, and System mode choice.
- Let Security and profile-class routes use a restrained near-black shell, one identity or trust hero, and grouped list panels rather than decorative card stacks.
- Make every screen feel production-ready in both light and dark mode, even if the primary brand expression is dark-first.

The screenshot base also defines what not to do:

- Do not fill screens with explanatory copy when a hero, action row, chip, or state panel can carry the meaning.
- Do not create generic Material pages that ignore the immersive shell.
- Do not mix an unrelated light/blue product subsystem into the same app unless the surface has an explicit, tokenized reason.
- Do not add fake finance, crypto, rewards, card, or regulated product concepts to mimic a reference screenshot.
- Do not use decorative gradients, cards, or glass effects without a role in hierarchy, state, or navigation.

## Screen Archetypes

Every app must define and implement these Screen Archetypes before feature work is considered complete:

- Home or dashboard: a compact overview with the user's next best action and current state.
- Detail screen: a focused object view with clear status, metadata, history, and primary actions.
- List or feed: scan-friendly rows or cards with filtering, sorting, pagination or lazy loading, and empty states.
- Create or edit flow: progressive fields, validation, save states, draft safety, and cancellation handling.
- Search and discovery: query input, recent items, filters, loading, empty, and no-results states.
- Transaction or checkout flow: amount, counterparty, review, confirmation, failure recovery, and receipt.
- Profile and settings: identity, preferences, privacy, security, notifications, support, and legal links.
- Permissions and onboarding: minimal steps, clear value, deny/retry paths, and no dark patterns.
- Notifications and inbox: grouped events, read/unread states, actions, and deep links.
- Help and support: self-serve answers, contact options, incident states, and escalation.
- Offline and recovery: cached data, retry affordances, sync status, and conflict handling.
- Admin or operator screens, if present: dense, accessible, auditable, and visually separate from consumer mobile surfaces.
- Admin dashboard: dense operational overview with key metrics, alerts, filters, and one clear next action.
- Admin list and queue: sortable, filterable, paginated, auditable records with bulk actions and detail panels.
- Admin detail and audit trail: object state, owner, risk, history, permissions, attachments, and reversible operator actions.

## Cross-Surface Product Architecture

Mobile, web, venue, and admin share one semantic design system while serving
different jobs:

- Flutter mobile is the supporter experience. Prioritize thumb reach,
  first-viewport football context, protected routes, and truthful recovery.
- The public website communicates club identity and hands authenticated
  supporter journeys to the mobile app.
- The venue portal is a bounded matchday operational surface.
- The Admin PWA prioritizes scanning, filtering, auditability, permission
  clarity, safe consequential actions, and desktop/tablet responsiveness.

Shared rules:

- All surfaces use the same semantic tokens, typography, icon roles, motion
  durations, state taxonomy, and accessibility requirements.
- Consumer surfaces never expose admin-only routes, data, permissions, or
  affordances.
- Football and club identity lead navigation and hierarchy; predictions are a
  secondary football-engagement surface.
- Admin surfaces may be denser than mobile but retain concise copy, stable
  navigation, tokenized panels, explicit permission states, and audit trails.
- A feature is not design-complete until its mobile, web, admin, and venue
  implications are implemented or explicitly marked not applicable.

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

## AFRICLUB Surface Applicability

The in-scope surfaces are consumer Flutter mobile apps, the public club
website, the admin/operator PWA,
and the bounded venue/operator portal. Each surface uses the shared semantic
system but must keep its own role boundary, density, input model, and route
tree. Rayon Sports is the fully governed reference club profile; other club
apps inherit the shared system through runtime club configuration.

Mobile, public web, admin, and route/state evidence are required for Rayon. Venue
routes are secondary matchday utilities and do not replace the Home, Club, Fan
Zone, or Membership hierarchy. A surface may be marked not applicable only in
the governed route matrix with a reason, owner, date, and review release.

## Design Principles

- Clarity first: a user should understand the screen's purpose in three seconds.
- Compact but breathable: use dense information hierarchy without cramping touch targets.
- One primary action per screen state: secondary actions may exist, but the main path must be obvious.
- Real data over decoration: imagery, icons, and motion must clarify product state or emotion.
- Trust through restraint: use consistent tokens, predictable patterns, and strong feedback.
- Local-first respect: design for language length, currency, region, network reliability, and device class.
- Privacy by default: mask sensitive values and avoid exposing private identifiers in UI, logs, screenshots, and analytics.
- Accessibility is structural: accessible text, focus, contrast, semantics, and reduced motion are built into components.
- Performance is a design feature: loading, animation, scroll, and input latency must feel immediate.
- The app must work before it explains itself: do not add visible instructional copy when state, layout, or action labels can carry the meaning.

## Universal Token Model

The Universal Token Model is the only approved way to express visual style. Product code must consume semantic tokens rather than hardcoded colors, radii, shadows, text styles, durations, or spacing.

### Color Tokens

- `color.background.canvas`: base app canvas.
- `color.background.elevated`: elevated surfaces.
- `color.background.overlay`: modal, sheet, and scrim overlays.
- `color.surface.default`: cards, panels, list containers.
- `color.surface.strong`: stronger grouped surfaces.
- `color.surface.glass`: translucent surfaces when supported.
- `color.text.primary`: main readable text.
- `color.text.secondary`: supporting text.
- `color.text.muted`: low-emphasis text that still passes contrast.
- `color.text.inverse`: text over dark or accent fills.
- `color.border.subtle`: dividers and quiet outlines.
- `color.border.strong`: selected, focused, or emphasized outlines.
- `color.action.primary`: main action.
- `color.action.secondary`: secondary action.
- `color.action.destructive`: destructive action.
- `color.status.success`, `warning`, `danger`, `info`, `neutral`: semantic status roles.
- `color.focus.ring`: visible focus outline.

Each token must have Light mode and Dark mode values. High contrast mode should increase contrast without changing product meaning.

### Reference Palette Seeds

These seed colors define the default premium reference family. Teams may adapt hue for their brand, but the roles and contrast relationships must remain intact:

- Deep chrome black `#050510`: bottom navigation, command pills, modal chrome, and admin shell rails.
- Immersive ink `#252044`: deep background, admin shell depth, dark text on pale export surfaces.
- Account blue `#0818A0`: high-energy account or primary-value gradient stops.
- Deep account navy `#000840`: top gradient depth and account-value hero fields.
- Payments purple `#181038`: primary dark app canvas and payment/action zones.
- Deep payments purple `#100820`: lower-shell depth, cards behind hero sections, grouped dark panels.
- Rewards violet `#7050E8` and hot violet `#9838F0`: reward, upgrade, or accent gradients when the product owns that meaning.
- Wealth teal `#204050`: invest, growth, or calm informational zones where applicable.
- Paper `#FAF8F5`: high-contrast pill CTA fill, export canvas, QR backgrounds, and readable inverse surfaces.
- Mint success `#3CD070`, orange-red warning/danger `#FF5E43`, dusty rose `#D38B96`, and periwinkle `#8885F0`: semantic accent seeds, not page-wide decoration.

Implementation rule: code must expose these as semantic roles such as `color.chrome.default`, `color.hero.gradientStart`, `color.hero.gradientEnd`, `color.surface.glass`, `color.action.pill`, `color.focus.ring`, and `color.admin.rail`, not as feature-screen hardcoded literals.

### Secondary Color Usage Matrix

Secondary colors are required, but only as semantic support for meaning, hierarchy, and state. They must never become random feature decoration or compete with the primary dark shell.

| Role | Default Seed | Allowed Uses | Not Allowed |
| --- | --- | --- | --- |
| Success | Mint `#3CD070` | Paid, verified, synced, healthy, completed, approved, available. | Page-wide success backgrounds, decorative icons, financial gain claims without data. |
| Warning | Orange-red `#FF5E43` or warmer amber derivative | Pending, delayed, expiring, partial failure, risk, attention required. | Using warning as a brand accent or for normal secondary buttons. |
| Danger | Orange-red deepened for contrast | Failed, blocked, rejected, destructive, fraud risk, permission revoked. | Low-contrast red text, destructive actions without confirmation, color-only errors. |
| Info | Periwinkle `#8885F0` or wealth teal `#204050` | Neutral guidance, sync notices, tips, scheduled states, support messages. | Replacing primary action color or turning every helper panel blue. |
| Accent | Violet `#7050E8`, hot violet `#9838F0`, dusty rose `#D38B96` | Product-owned highlight, upgrade, reward, featured item, chart series with legend. | Copying reference rewards/crypto meanings when the product does not support them. |
| Neutral | Paper, ink, muted border, glass surface | Disabled states, secondary text, dividers, chips, skeletons, table chrome. | Making disabled controls look active or hiding unavailable reasons. |
| Focus | High-contrast ring derived from periwinkle or paper | Keyboard, screen reader, and admin table focus. | Focus indicated by color alone, hover-only focus, or focus rings hidden for aesthetics. |

Secondary color gates:

- Every secondary color must have a semantic token name, light value, dark value, high-contrast value, and minimum contrast proof.
- State colors must be paired with icon, label, shape, or text; color alone is never enough.
- Charts may use expanded categorical colors only when every series has a legend, pattern or marker fallback, and accessible contrast.
- Feature teams may request a new secondary color only through the Design Exceptions Register.

### Revolut Reference And Rayon Ownership Matrix

Revolut's official 2026 Open Banking guidance publishes white `#FFFFFF`, black
`#000000`, UI background black `#161618`, deep blue `#1326FD`, mid blue
`#6FA0FF`, light blue `#C6D9FD`, purple `#9539F2`, and lime `#BFFF37`. These
values explain the reference brand's neutral/deep-blue foundation and selective
accent strategy. They are not a licence to make AFRICLUB look like a Revolut
financial product.

Rayon owns this runtime identity:

| Role | Current seed | Contract |
| --- | --- | --- |
| Club primary | `#0D63F3` | Primary action, active control, focus derivation, and brand energy. Never large body text on light backgrounds without contrast resolution. |
| Club secondary | `#0A1326` | Dark shell depth and gradient foundation. |
| Club accent | `#E2B85F` | Membership tier, trophy, achievement, and verified club emphasis. Not a generic CTA fill. |
| Chrome black | `#050510` | Search pill, floating navigation, modal chrome, and admin rails. |
| Dark canvas seed | `#100820` | Lower-shell depth blended with club primary at runtime. |
| Dark panel seed | `#181038` | Grouped immersive panels blended with club primary at runtime. |
| Dark asset seed | `#101830` | Cards and media-safe dark surfaces. |
| Light canvas | `#F7F9FC` | Base light theme. |
| Light surface lowest | `#FFFFFF` | Primary readable panels. |
| Light surfaces | `#F3F6FA`, `#EDF2F8`, `#E7EEF6`, `#DEE8F3`, `#D5E0ED` | Tonal depth sequence; do not add grey shadows to compensate for weak hierarchy. |

Rules:

- Revolut values remain in the research/reference namespace. Rayon runtime code
  consumes `ColorTokens`, `ColorScheme`, and `AfriSemanticColors`.
- Club configuration may change primary, secondary, accent, and gradient seeds.
  Every foreground is contrast-resolved across the active surface.
- Dark mode is the premium reference expression. Light mode must use the same
  hierarchy and density, not a separate pale-card design language.
- Gradients are reserved for shell atmosphere, identity, membership tiers,
  live/match state, or one hero. They are not page filler.
- Success, warning, danger, focus, and information colours keep stable semantic
  meaning across every club and surface.
- A written partnership may authorize Revolut assets or fonts, but production
  use still requires the supplied official kit, permitted contexts, and
  cross-platform licence record in the repository.

### Typography Tokens

- `type.display`: only for true hero or high-value first-viewport moments.
- `type.title.lg`, `type.title.md`, `type.title.sm`: screen and section hierarchy.
- `type.body.lg`, `type.body.md`, `type.body.sm`: readable content.
- `type.label.lg`, `type.label.md`, `type.label.sm`: controls, chips, tabs, badges.
- `type.number.lg`, `type.number.md`, `type.number.sm`: financial, metric, timer, count, and score values.
- Letter spacing is `0` unless a platform text style requires otherwise.
- Do not scale font size with viewport width. Use responsive layout, wrapping, truncation, or alternate component density.

#### AFRICLUB And Rayon Typography Profile

Production Flutter currently uses the platform UI font because
`TypographyTokens` leaves `fontFamily` unset. Golden tests alone use
`GoldenRoboto` for deterministic rendering. This is the authoritative current
decision until a licensed, packaged family is approved and implemented across
  iOS, Android, web, and admin.

Revolut's use of Aeonik Pro is a reference-brand decision, not permission to
ship that family in AFRICLUB. Do not name or package Aeonik Pro unless the
partnership supplies the exact licensed font files, allowed platforms, weights,
fallback policy, and distribution terms. Visual parity must come first from
hierarchy, metrics, weight, spacing, and motion rather than an unlicensed font.

| Flutter role | Size | Weight | Line height | Tracking | Required use |
| --- | ---: | ---: | ---: | ---: | --- |
| `displayLarge` | 48 | 700 | 0.96 | 0 | One hero result, identity, score, or value. |
| `displayMedium` | 40 | 700 | 0.98 | 0 | Compact hero on smaller screens. |
| `displaySmall` | 32 | 700 | 1.00 | 0 | Large card or detail value. |
| `headlineLarge` | 28 | 700 | 1.10 | 0 | Screen title when a hero is not present. |
| `headlineMedium` | 24 | 700 | 1.14 | 0 | Major section title. |
| `headlineSmall` | 20 | 700 | 1.18 | 0 | Dense section heading. |
| `titleLarge` | 18 | 600 | 1.22 | 0 | Sheet, panel, or route title. |
| `titleMedium` | 16 | 600 | 1.24 | Card group or emphasized row. |
| `titleSmall` | 14 | 600 | 1.25 | Compact row title. |
| `bodyLarge` | 16 | 500 | 1.48 | Important explanatory content. |
| `bodyMedium` | 14 | 500 | 1.46 | Default interface copy. |
| `bodySmall` | 13 | 500 | 1.42 | Supporting copy; never critical legal text. |
| `labelLarge` | 14 | 700 | 1.18 | Primary buttons and selected tabs. |
| `labelMedium` | 13 | 600 | 1.15 | Secondary actions, chips, and metadata. |
| `labelSmall` | 12 | 600 | 1.10 | Tertiary metadata only. |
| `metricValue` | 28 | 800 | 1.00 | Score, points, rank, or membership number. |
| `metricLabel` | 11 | 600 | 1.10 | Short uppercase metric label; tracking `0.6`. |
| `navigationLabel` | 11 | 600/800 | default | 0 | Bottom navigation; selected uses 800. |
| `badgeLabel` | 10 | 700 | 1.00 | Compact non-essential badge. |

Typography rules:

- Use one platform UI family per platform and a language-appropriate platform or
  Noto fallback. Club wordmarks and crests are brand assets, not reusable fonts.
- Use weights 500, 600, 700, and the documented 800 metric/navigation emphasis.
  Synthetic weights and route-local font families fail the design gate.
- Numbers use tabular figures where supported. Scores, membership numbers,
  timers, prices, and points remain real accessible text.
- Tracking is zero except the governed `metricLabel` role. Route-local
  all-caps or non-zero tracking needs an exception and golden evidence.
- At 200 percent text scale, important content wraps, reflows, or changes
  density. It must not disappear behind ellipsis or the floating navigation.
- Light and dark modes use identical metrics. Only semantic colours and
  elevation change.
- If a partnership font is later approved, add the font licence record, package
  files locally, map every weight explicitly, update golden baselines, and prove
  Kinyarwanda, French, English, numeric, large-text, web, and admin coverage
  before changing this profile.

### Spacing And Shape Tokens

- Base spacing step is 4 dp; common values are 4, 8, 12, 16, 20, 24, 32, 40, 48.
- Icon buttons are at least 44 x 44 dp; primary touch targets are at least 48 x 48 dp.
- Cards use 8 dp radius or less unless a platform-native component requires a larger shape.
- Large decorative rounded rectangles must not become the default layout language.
- Use aspect ratio, min/max constraints, and stable dimensions for boards, grids, counters, tiles, and toolbars.

### Elevation, Blur, And Motion Tokens

- Elevation must reflect interaction depth, not decoration.
- Blur is allowed only where readability and performance are proven.
- Motion durations: `fast` 120-180 ms, `standard` 200-280 ms, `slow` 320-420 ms.
- Motion easing should be platform-native or cubic standard; avoid bounce effects in serious workflows.
- Reduced motion replaces spatial transitions with fades, opacity, and instant layout changes.

### Motion And Transition Rules

Motion must explain state, preserve orientation, and prove performance:

- Route transitions use short fades, shared-axis movement, or platform-native transitions. Do not use decorative motion that delays task completion.
- Bottom sheets rise from the task origin where possible and return focus to the trigger on dismiss.
- Admin drawers and detail panels slide predictably from the side related to the selected row or action.
- Keyboard and directional focus movement may use scale, glow, or elevation, but the focused item must remain within its layout slot and never push neighboring items into overlap.
- Loading motion uses skeleton shimmer or progress only when it does not harm readability, reduced-motion settings, or battery/performance.
- Optimistic updates must animate into final state and provide undo or retry when network confirmation fails.
- Destructive, payment, identity, permission, and admin-bulk flows must slow down only at review/confirmation points.
- Every motion-heavy surface needs a reduced-motion equivalent and a performance check on representative low-end hardware.

## Content And Copywriting Rules

The Revolut reference screenshots and Apple Design Award examples both show that world-class interfaces reduce reading burden. Copy must be concise, stateful, and useful:

- Lead with value, amount, object, status, or action. Put explanation second.
- Use short labels for circular actions, chips, tabs, table columns, and compact tiles.
- Prefer numbers, icons, badges, and state labels over paragraphs.
- Empty states must say what happened and provide the next useful action.
- Error states must explain recovery, not expose raw backend traces unless the user is an operator on an admin surface.
- Admin copy may be denser, but it must still be scannable: table titles, column labels, filters, row summaries, and action labels should be precise.
- Avoid visible text that explains the UI itself, keyboard shortcuts, visual design, or obvious gestures.
- Do not copy reference-app product claims, regulated finance language, rewards language, crypto labels, or brand terms unless the product legally and functionally supports them.

## App Shell Standard

- The app opens directly into the usable product experience, not a marketing landing page.
- Top chrome is compact: account/profile, title or search, and one or two contextual actions.
- Bottom navigation is stable for primary destinations; nested flows preserve branch state where possible.
- Use tabs, segmented controls, menus, toggles, sliders, steppers, and icon buttons according to familiar mobile patterns.
- Avoid visible in-app text that describes UI features, keyboard shortcuts, visual styling, or how to use the app.
- Skeletons and optimistic updates must preserve layout stability.
- Sheets, dialogs, snackbars, toasts, and banners must have clear severity and recovery behavior.
- Destructive or irreversible actions require review, confirmation, or undo according to risk.
- For AFRICLUB, the primary shell must preserve Home, Club, Fan Zone, and
  Membership branch state; profile owns Settings. Temporary route aliases must
  not create multiple canonical destinations for the same club object.

### Rayon Mobile Element Anatomy

The following measurements are the current governed Flutter targets. A change
to these values starts at the token layer and requires compact, standard,
large-text, light, dark, and state evidence.

| Element | Anatomy |
| --- | --- |
| Top command control | `58 x 58` target, maximum two trailing command actions. |
| Club/avatar mark | `40 x 40` inside the command control. |
| Search command | Minimum label width `142`, icon `27`, concise query hint, full semantic label. |
| Circular command icon | `25`; notification dot `11` with tokenized inset. |
| Floating bottom navigation | Compact `66` high, regular `78` high, `18` horizontal margin, `12` bottom margin, `24` blur sigma, `42` radius. |
| Navigation item | Minimum width `64`, icon `22` or `24` at large text, label `11`, selected label weight `800`, inactive opacity `0.68`. |
| Quick action | `64` diameter, minimum `48` tap target, one icon plus one short label, maximum four in the primary row. |
| Primary button | Minimum height `56`, full pill radius, one clear verb, loading and disabled states preserve width. |
| Screen spacing | Default responsive scaffold inset `16`; large content blocks may use the semantic `24` screen inset. Do not mix both within one alignment column. |
| Card spacing | `20` internal padding, `12` sibling gap, `32` major section gap. |
| Shape scale | Card `8`, control `12`, compact panel `14`, input `20`, large surface `24`, hero `32`, chrome `42`, pill `9999`. |
| Border scale | Hairline `0.6`, standard `1`, focus `1.2`, chrome `1.15`, strong `1.5`, emphasis `2`, tab indicator `2.5`. |
| Blur scale | Subtle `12`, standard `20`, overlay `28`, atmospheric `40`. |
| Icon scale | Chip `14`, inline `18`, navigation `20-24`, medium `20`, large `28`, hero `40`, display `64`. |
| Motion | Press `80 ms`, quick `150 ms`, navigation `180 ms`, standard `250 ms`, emphasized `350 ms`, atmospheric `600 ms`. |

### Rayon Primary Route Visual Contract

Home:

- Use a compact avatar/search/notification/context-action command row.
- The first content block is current football or membership value, not a blank
  marketing hero. When no fixture exists, the empty state is compact and does
  not consume most of the first viewport.
- Keep Tickets, Members, Predict, and Shop as four primary quick actions only
  when they are enabled and truthful. Hidden capabilities do not leave empty
  slots.
- News, supporters, membership, and matchday content follow in a single scroll
  hierarchy with no floating panel covering content.

Club:

- Lead with official Rayon identity and one compact club summary.
- Team, News, Fixtures, Results, Standings, History, Projects, Tickets, and Shop
  are grouped, scan-friendly routes using the same row anatomy.
- The `CLUB` display title may use the display role, but route titles must not
  create an unrelated italic or all-caps font system.

Fan Zone:

- Lead with the user's active pick, accuracy, and points only when data is
  available and explained.
- Pick, League, and Points use a shared segmented control. Venue check-in and
  venue order remain a secondary Matchday group below football
  prediction, club competitions, and supporter activity.
- No odds, staking, payouts, probability advice, or cash language.

Membership:

- Lead with status and the digital member card, then tier progress, benefits,
  contribution history, fanclub, projects, renewal/support, and statements.
- Membership numbers and identity are masked in screenshots and analytics.
- Pending review is shown through text, icon/shape, and colour; colour alone is
  insufficient.

Search:

- Use one strong search field, a maximum of four task-relevant filters, recent
  searches where safe, loading, results, no-results, offline, and retry states.
- Search explanatory copy is limited to one short sentence. Results group by
  Club, Fixtures, Tickets/Shop, Supporters, Membership, Fan Zone, and Help.

Profile and Settings:

- Profile is the only primary entry to account, appearance, notifications,
  privacy, support, legal, language, diagnostics, export, and deletion.
- Settings use grouped full-width rows, stable icon roles, right chevrons, and
  no unrelated hero decoration.
- Appearance is a bottom sheet with System, Light, and Dark segments. The
  selected mode must remain obvious without relying on colour alone.

Unavailable, error, and recovery:

- The title says what happened; supporting copy gives the safe next step; one
  primary recovery action is visible.
- Feature-disabled routes use generic `Requested section` language and never
  reveal hidden route names, diagnostics, provider identifiers, or entitlements.
- The state panel is vertically balanced but must not float behind the status
  bar or leave the user without back navigation.

## Universal Component Library

The Universal Component Library is the minimum component inventory for any production app:

- App shell: top bar, bottom nav, side rail for large screens, safe-area wrapper, keyboard-aware scaffold.
- Buttons: primary, secondary, tertiary, destructive, icon-only, split, loading, disabled.
- Inputs: text, number, money, phone, email, password, date, time, search, multiline, OTP, file/media picker.
- Selection: checkbox, radio, switch, segmented control, chips, tabs, menus.
- Feedback: banner, snackbar, toast, inline validation, progress indicator, skeleton, empty state, error state.
- Data display: list row, card, table row, metric, avatar, badge, timeline, receipt, activity item.
- Navigation: list item, breadcrumb for large screens, back button, deep-link recovery, route transition.
- Overlays: dialog, bottom sheet, popover, action sheet, command menu.
- Media: image, video thumbnail, document preview, avatar, icon, QR or barcode surface if relevant.
- Security and privacy: masked value, reveal control, session timeout, permission prompt, consent review.
- Semantic icons: every repeated metadata concept must use one stable semantic icon role, not one-off artwork.

Each component must define default, hover where applicable, focused, pressed, selected, disabled, loading, success, warning, error, empty, offline, permission denied, and skeleton states.

## Surface Component Matrix

Components must share tokens and semantics while adapting to input mode and density:

| Component | Flutter Mobile | Admin Panel |
| --- | --- | --- |
| Shell | Safe-area scaffold, compact top chrome, bottom nav, branch state. | Sidebar or rail, top command bar, workspace grid, guarded routes. |
| Navigation | Bottom nav for primary tabs, back for depth, sheets for transient choices. | Sidebar, breadcrumbs where useful, tabs, tables, detail drawers. |
| Search | Search pill, recent queries, filters, empty/no-result states. | Global command search plus scoped table search and filters. |
| Cards and panels | Full-width translucent panels, repeated cards, clear tap target. | Dense cards, metrics, list cards below tablet width, no card-inside-card nesting. |
| Tables and lists | Lists, grouped rows, chips, no dense desktop tables. | Sortable, filterable, paginated or virtualized tables with selectable rows. |
| Forms | Progressive fields, mobile keyboards, validation, draft safety. | Dense forms with sections, inline validation, permissions, audit review. |
| Dialogs and sheets | Bottom sheets for choices, dialogs for high-risk confirmation. | Drawers, modals, review dialogs, confirmation and undo flows. |
| Empty states | One clear next action and concise reason. | Explain data scope, filters, permissions, and next operator action. |
| Focus | Visible keyboard/screen-reader focus; touch remains primary. | Keyboard focus, row focus, table control focus, command palette focus. |
| Feedback | Snackbar, banner, inline validation, optimistic update recovery. | Audit-safe banners, status chips, queue freshness, bulk action summaries. |

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
- Light mode: complete parity with dark mode.
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

- Use dark immersive shell, translucent panels, concise headers, chips, badges, and pill controls from the shared system.
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

## Flutter Implementation Standard

Flutter apps must implement this standard with a typed theme and component architecture:

- Use `ThemeData` plus one or more `ThemeExtension` classes for semantic tokens.
- Put design tokens under app/theme or an equivalent shared design package.
- Avoid raw `Color(...)`, hardcoded radii, one-off text styles, and magic spacing in feature screens.
- Use reusable scaffolds for safe area, navigation, keyboard behavior, backgrounds, and route transitions.
- Use responsive constraints through `LayoutBuilder`, `MediaQuery`, `Sliver` patterns, and adaptive breakpoints.
- Use `Semantics`, tooltips, focus nodes, and shortcuts/actions where needed.
- Use platform-aware input types, autofill hints, validation, and error semantics.
- Keep animations interruptible, testable, and disabled or simplified under reduced motion.
- Images must declare stable dimensions, placeholders, error states, and cache behavior.
- Lists must be virtualized, paged, or otherwise bounded for performance.
- State management must expose loading, data, empty, error, offline, and refreshing distinctly.
- Navigation must support deep links, back behavior, restoration where needed, and protected routes.
- Testing must cover widgets, golden/snapshot surfaces, navigation smoke, accessibility, and route screenshot coverage.

Recommended Flutter package boundaries:

- `app/theme`: tokens, typography, colors, elevations, motion, icons.
- `app/router`: routes, deep links, guards, transitions.
- `shared/widgets`: reusable components and screen scaffolds.
- `shared/state`: async state wrappers, offline/sync state, permission state.
- `features/<feature>`: product logic and feature-specific screens only.
- `test/goldens` or equivalent: component and route visual baselines.

## Robust Implementation Goal

Goal: maintain one reference-backed UI/UX system for AFRICLUB mobile, public
web, venue, and Admin surfaces while preserving football-first hierarchy,
role boundaries, accessibility, privacy, and platform-native behavior.

Completion requires shared semantic tokens, complete async/recovery states,
responsive mobile and admin layouts, football-first navigation, permission-safe
operator actions, accessibility evidence, and exact-current visual evidence for
every in-scope route.

## Robust Implementation Plan

### Phase 0: Evidence Inventory

- Collect the current Revolut reference screenshots into a stable local evidence folder with filenames, dimensions, and contact sheet.
- Collect current mobile route and Admin PWA screenshots.
- Create a route inventory for mobile and admin, including hidden, guarded,
  modal, sheet, and error routes.
- Mark every route as consumer, admin, shared, or not applicable.

### Phase 1: Token And Theme Consolidation

- Map the reference palette seeds into semantic token roles.
- Add typed Flutter `ThemeExtension` classes for color, spacing, shape, typography, motion, elevation, focus, and admin density.
- Remove hardcoded color, radius, shadow, and text-style literals from feature screens.
- Define high contrast and reduced motion token variants.

### Phase 2: Shared Shell And Components

- Build or standardize app shell, top command chrome, search pill, circular command button, quick action row, floating navigation, side rail, admin sidebar, sheets, dialogs, banners, skeletons, empty states, and error states.
- Ensure components expose all default, focused, pressed, selected, disabled, loading, offline, empty, success, warning, danger, permission denied, and skeleton states.
- Add semantic icon roles for repeated concepts.

### Phase 3: Flutter Mobile Upgrade

- Apply the shared shell to all mobile routes.
- For AFRICLUB, complete the Club module and Home, Club, Fan Zone, Membership,
  profile/settings hierarchy before treating venue or generic engagement
  expansion as primary navigation work.
- Ensure every primary mobile screen has a first-viewport value, concise top chrome, one primary action, state-safe async loading, and stable navigation.
- Verify compact, standard, large phone, tablet, landscape, keyboard-open, large-text, and offline states.
- Block admin routes and admin affordances from the consumer mobile route tree.

### Phase 4: Admin Panel Upgrade

- Apply the shared admin shell to all operator routes.
- Add dashboard, list, table, queue, detail, audit, permission, and bulk-action patterns.
- Verify desktop, tablet, compact fallback, keyboard, screen reader, high data volume, empty queue, partial failure, stale data, unauthenticated, and out-of-role states.
- Ensure every consequential action records a review, confirmation, undo where possible, and audit trail.

### Phase 5: Evidence And Release Gates

- Generate route screenshots for every mobile and admin route and critical modal/sheet state.
- Generate component goldens or snapshots for shared primitives and high-risk states.
- Run accessibility checks for contrast, semantics, focus order, target size, large text, reduced motion, and keyboard.
- Run performance checks for first frame, scroll, animation, memory pressure, and large admin datasets.
- Publish a design-compliance report that maps every route to screenshot evidence, state evidence, accessibility evidence, and remaining exceptions.

## Design Exceptions Register

Any deviation from this standard must be explicitly recorded. Exceptions are allowed only when they protect product truth, platform conventions, accessibility, performance, privacy, legal obligations, or operational safety.

Each exception must include:

- `surface`: mobile, venue, admin, web, native platform, or shared component.
- `route_or_component`: exact route, screen, modal, sheet, or component.
- `standard_rule`: the rule being varied.
- `reason`: why the standard cannot be followed.
- `approved_alternative`: the token, layout, interaction, or copy pattern that replaces it.
- `risk`: accessibility, security, privacy, performance, consistency, legal, or user-confusion risk.
- `evidence_required`: screenshots, tests, accessibility output, performance trace, or approval note.
- `expiry_or_review`: date or release when the exception must be revalidated.

Default rule: undocumented deviations fail the design gate.

## Route Evidence Matrix Template

Every production route must have evidence. Use this template in release docs, QA scripts, or generated JSON:

| Field | Required Evidence |
| --- | --- |
| Route ID | Canonical route path or route name. |
| Surface | Mobile, admin, web, shared, modal, or sheet. |
| Role Boundary | Consumer, owner, operator, admin, guest, unauthenticated, or not applicable. |
| Default Screenshot | Primary screenshot at the target viewport. |
| Responsive Screenshots | Compact phone, standard phone, large phone, tablet, landscape, and admin desktop/tablet as applicable. |
| State Screenshots | Loading, empty, error, offline, permission denied, disabled, selected, focused, success, warning, danger. |
| Accessibility Evidence | Contrast, semantics labels, focus order, target size, 200 percent text, reduced motion, and keyboard where applicable. |
| Performance Evidence | First frame, scroll, route transition, image loading, list virtualization, and admin table performance. |
| Privacy Evidence | Screenshots use sanitized data and mask phone numbers, OTPs, tokens, private IDs, and sensitive account details. |
| Platform Evidence | Android, iOS, web/admin, safe area, keyboard, status/navigation bars, and deep links. |
| Exceptions | Link to Design Exceptions Register entries or `none`. |
| Owner And Date | Person or agent, date captured, commit or build identifier. |

Routes with missing evidence are not design-complete, even if they compile and pass basic tests.

## Reference Fidelity Definition

`100 percent reference fidelity` means every approved AFRICLUB component,
screen archetype, interaction state, and motion behaviour matches the extracted
reference contract within the product's own content and platform rules. It does
not mean placing Revolut financial screens, names, assets, balances, or
regulated flows inside a football-club app.

Fidelity is measured at matched viewport and state:

1. Capture the accepted reference screen and the exact-current Rayon screen.
2. Mask private values without changing layout.
3. Compare hierarchy, safe areas, first-viewport value, spacing, type metrics,
   colour roles, shape, border, blur, icon anatomy, navigation, scroll
   continuity, motion, loading, empty, error, offline, focus, pressed,
   selected, disabled, permission, light, dark, large-text, and reduced-motion
   states.
4. Record every mismatch as fixed, accepted exception, not applicable, or open.
5. Re-capture after implementation using the same viewport and state.

The parity gate cannot pass while any of these are true:

- live reference capture is unavailable or the reference build/version is
  unknown;
- the current implementation was not built cleanly from the audited checkout;
- a screenshot comes from a stale installed build, prior chat, old artifact, or
  different viewport without explicit historical labeling;
- route/state, accessibility, performance, privacy, or responsive cells remain
  open;
- a partnership font, logo, icon, or asset is referenced without the supplied
  licensed source and allowed-use record;
- `design_complete=false` in the governed evidence output.

Current repository status:

- AFRICLUB is scoped to football, club, membership, supporter, commerce,
  contribution, ticketing, venue, and free-prediction journeys.
- Route evidence predating the single football-platform baseline must be
  regenerated before it can support a release claim.
- Physical-device, assistive-technology, live-service, clean-candidate,
  accountable approval, signing, store, deployment, and release gates remain
  external and open.

## Quality Gates

A product is not design-complete until all Quality Gates pass:

- Single design authority: this `DESIGN.md` is present and no secondary design authority exists.
- Reference grammar compliance: screenshots and implementation preserve the required dark immersive shell, compact command chrome, hero hierarchy, circular quick actions, translucent panels, stable navigation, and concise state language unless a product-specific exception is documented.
- Token compliance: runtime UI uses semantic tokens and typed theme APIs.
- Component completeness: Universal Component Library components exist or are intentionally not applicable.
- State completeness: all State Requirements are implemented for screens and components.
- Responsive coverage: 320-374, 375-430, 431-599, 600-719, 720+, Landscape, Foldables, and Keyboard open are verified.
- Admin coverage: desktop/tablet/compact admin layouts, keyboard operation, tables, filters, detail panels, bulk actions, permission states, and audit trails are verified where admin exists.
- Accessibility coverage: contrast, semantics, focus, touch targets, text scale, and reduced motion are verified.
- Visual coverage: route screenshot coverage and golden or snapshot tests exist for critical paths.
- Performance coverage: first frame, scroll, animation, and memory behavior are acceptable on representative devices.
- Privacy coverage: screenshots, logs, analytics, and UI mask sensitive data.
- Platform coverage: Android and iOS platform conventions, permissions, status bars, navigation, haptics, and safe areas are respected.
- AFRICLUB product coverage: club-first hierarchy, canonical Club routes,
  selected-match prediction taxonomy, membership/project journey, and secondary
  venue placement are verified on exact-current mobile evidence.

## Universal App Generation Prompt

When generating or rebuilding an app, use this instruction:

Create a production app using the Universal App Design Standard 2026. Use this `DESIGN.md` as the only design authority. Build the actual usable first screen, not a landing page. Use the Revolut reference screenshot grammar as the premium baseline for shell, hierarchy, command chrome, action rows, panels, navigation, density, and state polish. Implement a typed token model, app shell, Universal Component Library, all State Requirements, mobile responsive bands from 320 dp through tablet/foldable/landscape, admin panel density and auditability where applicable, accessibility support, route screenshot coverage, and golden or snapshot tests. Use domain-specific truthful content, sanitize private data, avoid unsupported regulated claims, and keep Flutter implementation aligned with semantic tokens and reusable components.

## Governance

- This file replaces all old design folders, screenshots-as-authority matrices, token JSON authority files, and provenance markdown.
- Runtime assets needed by the app may remain in the app asset tree, but their design meaning must be documented here or in code comments only where unavoidable.
- Historical release evidence may mention old work, but must not instruct current implementation to use old design authorities.
- Any new design rule must be added to this file first, then implemented in tokens, components, tests, and gates.
- External submissions, regulated claims, app-store assets, public legal notices, and customer-facing professional claims require explicit human approval.

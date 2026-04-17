# AFRICLUB Mobile Minimalist UI System

Date: 2026-04-11

## Objective

Refine the existing production Flutter app into a cleaner, lighter, more premium mobile system without changing the core product model, routes, or business logic.

The redesign is additive:

- keep existing feature modules and navigation architecture
- reduce text and visual noise
- standardize hierarchy with reusable widgets
- move from bespoke glass/clay theatrics toward calmer utility-first surfaces

## UI audit

### 1. Text is overused in structural places

Current issues:

- all-caps headings repeat across screens even when the screen context is already obvious
- helper copy often repeats what the surrounding widget already communicates
- labels such as `QUICK ACTIONS`, `LATEST INTEL`, `TOP SUPPORTERS`, `YOUR CART`, `PUBLIC IDENTITY`, and `DELIVERY ADDRESS` add density without adding meaning

Action:

- keep one clear title per screen or section
- replace verbose labels with cards, chips, icons, and placement
- use subtitle text only when it changes decision quality

### 2. Surface styling is too decorative

Current issues:

- heavy gradients, glow orbs, blur, inner shadows, and oversized radii create friction
- cards feel ornamental instead of informative
- the floating bottom nav and CTA styles compete with content

Action:

- reduce blur and glow
- use flatter premium surfaces with one border and one shadow layer
- keep accent color for focus, state, and primary action only

### 3. Hierarchy is inconsistent

Current issues:

- similar components use very different sizes and weights
- large display text appears in operational screens where medium hierarchy is enough
- some screens stack multiple equally strong calls to action

Action:

- use a tighter type scale
- reserve strong display moments for hero surfaces only
- reduce each screen to one primary action cluster

### 4. Interaction patterns are not reused enough

Current issues:

- settings rows, stat cards, quick actions, state banners, and chips are implemented differently across features
- screen-level custom styling increases drift

Action:

- standardize reusable primitives in `core_theme`
- migrate feature screens to those primitives instead of adding one-off layouts

## Core design principles

- Calm first: visual confidence should come from spacing and order, not effects.
- Fewer words: use short labels, chips, icons, and placement.
- Widget-first: prefer cards, rows, chips, segmented controls, and sheets over freeform text.
- One emphasis at a time: each section gets one dominant value or action.
- Club accent as signal: club color marks action, live state, and selected state.
- Native rhythm: compact headers, tappable rows, sticky actions, clear safe-area spacing.

## Design tokens

### Color

- Background: dark neutral ink, not theatrical blue-purple
- Surface stack:
  - `surfaceContainerLowest` for app shell
  - `surfaceContainerLow` for standard cards
  - `surfaceContainerHigh` for elevated cards and grouped controls
- Accent:
  - club primary for active state and main CTA
  - club accent for value highlights only
- Border:
  - low-contrast ghost border for separation
- Status:
  - success, warning, error, info with subtle tinted fills

### Typography

Use a controlled scale:

- `displayLarge` 48
- `displayMedium` 40
- `displaySmall` 32
- `headlineLarge` 28
- `headlineMedium` 24
- `headlineSmall` 20
- `titleLarge` 18
- `titleMedium` 16
- `titleSmall` 14
- `bodyLarge` 16
- `bodyMedium` 14
- `bodySmall` 13
- `labelLarge` 14
- `labelMedium` 13
- `labelSmall` 12

Rules:

- reserve `Space Grotesk` for hero and brand moments only
- use calmer UI typography for titles, lists, and controls
- avoid all-caps unless the element is a micro label or controlled chip

### Shape

- `radiusSm` 10
- `radiusMd` 14
- `radiusLg` 20
- `radiusXl` 24

Rules:

- cards should feel crisp and mobile-native, not inflated
- use full pill radius only for chips and primary buttons

### Spacing

Spacing remains 4pt based, but usage is stricter:

- 8 to 12 for control grouping
- 16 to 20 for card padding
- 24 to 32 for section separation

Rules:

- use spacing instead of dividers wherever possible
- every screen should have a consistent horizontal gutter

## Component library

Implemented shared primitives:

- `ClayCard`
  - default neutral card for lists, forms, summaries
- `GlassCard`
  - lighter elevated surface for profile/header groups
- `AfriButton`
  - shared button system with `primary`, `secondary`, `outline`, `ghost`, `accent`
- `ClaymorphicButton`
  - backward-compatible primary CTA with simplified styling
- `AfriIconButton`
  - compact icon action button
- `AfriClubBottomNav`
  - simplified bottom navigation with compact active pill
- `AfriSectionHeader`
  - section title + optional subtitle/trailing action
- `AfriStatusChip`
  - status, metadata, and filter chip
- `AfriMetricTile`
  - summary values and stat widgets
- `AfriListRow`
  - icon-led settings/menu row

## Icon usage rules

- every icon must communicate category, action, or state
- use icons at the start of rows, cards, and shortcuts for scan speed
- do not add icons to headings just for decoration
- use chips and icon buttons for secondary controls before adding more text

## Typography rules

- one screen title only
- one section title only when the section is not already obvious from layout
- avoid repeating nouns that already exist in navigation context
- helper text should be optional and short
- prefer value-first layouts: amount, rank, score, status, then explanation

## Spacing and hierarchy rules

- screen padding must be consistent across features
- major sections should be visually separated by 24 to 32pt
- cards should use a single alignment axis
- action areas should sit close to the content they affect
- empty and error states should be shorter and centered

## Screen-level redesign guidance

### Home

Changes applied:

- quick actions converted from ornamental circular rail into a compact shortcut system
- stats converted into reusable metric tiles with shorter labels
- supporter leaderboard simplified into cleaner list rows
- news section renamed and reduced in density
- degraded state messaging moved into reusable inline state treatment

Pattern:

- hero remains the primary visual anchor
- the next visible layer is action shortcuts
- summary metrics and community proof follow
- editorial/news content stays lower in the hierarchy

### Shop

Changes applied:

- removed breadcrumb and oversized editorial title
- shop now opens with a simple toolbar, section header, chips, and product grid
- product cards are image-first, shorter, and action-ready
- checkout bar is smaller and clearer
- cart uses shorter form sections, summary blocks, and clearer checkout messaging

Pattern:

- filters first
- products second
- cart action persistent but quiet

### Settings

Changes applied:

- replaced grouped list containers with reusable icon-led rows
- simplified profile summary into alias + status chips
- reduced section density and removed redundant descriptive copy
- edit profile screen now focuses on identity, inputs, and one clear save action

Pattern:

- profile summary
- account
- privacy/contributions
- support/about

## Reusable widget patterns

- summary cards
  - `AfriMetricTile`
- quick action rows
  - shortcut tiles + one primary CTA
- status badges
  - `AfriStatusChip`
- info cards
  - `ClayCard` or `GlassCard`
- icon-led list items
  - `AfriListRow`
- sticky action bars
  - `CheckoutBar`
- modal action panels
  - `AfriBottomSheet`
- loading/error/empty
  - `AfriSkeleton`, `AfriStateView`, `AfriEmptyView`, `AfriErrorView`

## Navigation simplification guidance

- keep the existing branch architecture and routes
- make the bottom nav quieter so content carries more emphasis
- keep labels visible only for the active destination where practical
- avoid duplicating navigation labels inside screen content unless necessary

## Incremental rollout guidance

Use this order:

1. migrate shared tokens and primitives in `core_theme`
2. migrate top-traffic screens first: home, shop, settings
3. migrate other list-based screens to `AfriListRow`, `ClayCard`, `AfriStatusChip`
4. migrate form-based screens to the simplified input and section system
5. migrate overlays and bottom sheets last

Rules for future work:

- do not introduce new gradients, shadows, or bespoke card styles in feature packages
- extend `core_theme` first if a new pattern is needed
- prefer shorter labels over additional explanatory copy
- move secondary detail into bottom sheets, chips, or collapsible areas instead of persistent paragraphs

## Result target

Every screen should now trend toward:

- less text
- fewer competing elements
- stronger reuse
- faster scanning
- clearer action hierarchy
- calmer, premium mobile-native execution

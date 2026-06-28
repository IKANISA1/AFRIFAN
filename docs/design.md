# AFRICLUB Revolut-Borrowed Design System

`docs/design.md` is the canonical UI/UX source of truth for AFRICLUB Flutter apps.

## Reference Model

AFRICLUB must borrow its mobile UI typology from the local Revolut-style Mobi,
COOL, and Collect implementations:

- route-mapped vertical gradients
- black glass top command chrome
- floating black glass bottom navigation
- compact one-line labels
- large rounded translucent finance/member cards
- icon-first actions
- bundled `RevolutBorrowed` typography from `core_theme`

## Non-Negotiables

- Do not introduce external font packages or feature-local font fixtures.
- Do not use negative letter spacing.
- Do not create screen-local gradients, nav bars, card systems, or display
  fonts when a `core_theme` token or widget exists.
- Do not reintroduce old non-borrowed design language in product docs.
- Club colors are accents only; the shell and route background come from
  `ColorTokens.screenGradientForPath`.

## Implementation Surface

- `packages/core/core_theme` owns tokens, typography, shared chrome, cards,
  buttons, route backgrounds, and navigation.
- Feature packages consume `TypographyTokens`, `GradientBackground`,
  `AfriTopCommandBar`, `AfriClubBottomNav`, `GlassCard`, and current shared
  primitives.
- Feature packages may add business-specific widgets only when they still route
  all visual decisions through `core_theme`.

## Cleanup Rule

When old typography assets, docs, or ad hoc widget styles conflict with this
system, replace them with the borrowed system or delete them. Historical docs are
not allowed to override this file.

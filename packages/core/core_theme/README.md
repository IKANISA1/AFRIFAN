# Core Theme

`packages/core/core_theme` is the single source of truth for the Flutter mobile design system and the upstream token source for the web/PWA design system.

## Tactile Monolith

The shared mobile UI is built around:

- a fixed nocturnal surface stack
- violet glass and clay depth
- Space Grotesk for display authority
- Manrope for editorial copy
- Inter for utility labels

## What belongs here

- color, blur, shadow, spacing, shape, and typography tokens
- border and outline fallbacks through `src/tokens/border_tokens.dart`
- `ThemeData` generation in `src/club_theme.dart`
- shared primitives like `GlassCard`, `ClayCard`, `ClaymorphicButton`, and `GradientBackground`

## What should not happen in feature packages

- direct `GoogleFonts.*` calls
- ad hoc surface palettes
- new button/card variants that bypass `core_theme`

If a screen needs a new visual pattern, add or extend a primitive in `core_theme` first and then consume it from the feature package.

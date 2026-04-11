# Design System: The Tactile Monolith

## Canonical Source

The web design system has one implementation source of truth:

- `apps/rayon_sports/web/src/design-system/theme.css`

The shared recipe entrypoint for JSX is:

- `apps/rayon_sports/web/src/design-system/index.ts`

Do not create new visual rules in `globals.css`, feature-level CSS, or ad hoc class strings when a semantic recipe already exists.

## Review Summary

This redesign replaced a fragmented setup:

1. The written docs described a legacy "Tactile Monolith / Tactile Monolith" system that no longer matched the live web UI.
2. The live web theme was embedded directly in `apps/rayon_sports/web/src/app/globals.css`, which made the global file both implementation and policy document.
3. Shared recipes such as glass panels, pill buttons, rounded cards, and dashboard inputs were repeated inline across many components and pages.
4. Typography drifted away from the intended authority hierarchy; the live app used a mixed stack that diluted display contrast.
5. Borders and dividers had crept back into the UI, weakening the intended molded, tactile surface language.

The current web system now consolidates those concerns under `src/design-system/`.

## Creative North Star

The system is built around **The Tactile Monolith**:

- Massive, condensed headlines in **Space Grotesk** create authority.
- **Manrope** carries body copy and makes the interface feel premium rather than utilitarian.
- **Inter** is reserved for labels, control text, and micro-copy.
- Surfaces feel carved from violet light and frosted glass, not drawn with flat panels.
- Layouts should feel editorial and asymmetrical rather than template-like.

The interface must read as a physical stack of surfaces, not a grid of boxes.

## System Rules

### 1. Color and Surfaces

- `surface-dim` is the base void. Everything else floats above it.
- Use tonal surface shifts before you use separators.
- Treat borders as ghost borders only: low-opacity accessibility outlines, not structure.
- Use glass surfaces for navigation, dialogs, overlays, and elevated cards.
- Use the violet primary gradient for hero CTAs and singular actions that deserve focus.

### 2. Typography

- Use **Space Grotesk** for `display` and `headline` moments.
- Use **Manrope** for long-form and supporting text.
- Use **Inter** for labels, navigation micro-copy, and operational UI.
- Default to dramatic scale contrast: big headline, restrained supporting copy.
- Avoid middle-weight, middle-size hierarchy that flattens the page.

### 3. Shape and Depth

- Nothing sharp. The minimum practical radius is `1.5rem`.
- Primary cards should feel molded: `2rem` to `3rem` radii.
- Use layered blur, tinted ambient shadow, and inner highlights for depth.
- Use inset shadows for inputs and sunken surfaces.
- Avoid neutral grey shadows. Depth should be violet-tinted or derived from the void.

### 4. Component Doctrine

- Primary button: glossy clay gradient, pill shape, one hero CTA per cluster.
- Secondary button: glass button, same silhouette, lower emphasis.
- Tertiary button: text-first action, no container.
- Cards: no divider lines; use whitespace and surface hierarchy.
- Inputs: sunken, heavy radius, electric-violet focus halo.
- Chips: pebble-like, pill-shaped, low-contrast surface with strong label typography.
- Header: fixed frosted-glass pane with strong blur and a ghost edge only.

## Implementation Guidance

### Use semantic recipes first

Shared JSX should prefer recipes from `@/design-system`:

- `ui.panel`
- `ui.panelElevated`
- `ui.panelInset`
- `ui.buttonPrimary`
- `ui.buttonSecondary`
- `ui.buttonTertiary`
- `ui.iconButton`
- `ui.chip`
- `ui.chipMuted`
- `ui.chipSignal`
- `ui.statCard`
- `ui.input`
- `ui.kicker`
- `ui.meta`
- `ui.monolithBleed`

### Backwards compatibility

Legacy classes remain mapped to the new system for migration:

- `glass-panel`
- `glass-panel-elevated`
- `clay-card`
- `card-interactive`
- `dashboard-input`
- `dashboard-chip`

Do not add new usage of those legacy names in new work. Use the `ui.*` recipes instead.

## Do

- Use whitespace aggressively.
- Let oversized display type bleed behind glass panels when the layout benefits from it.
- Keep the number of equally weighted actions low.
- Favor asymmetry and layered overlap over perfectly even blocks.
- Use `theme.css` for token changes rather than editing dozens of components.

## Don’t

- Do not introduce 1px structural dividers.
- Do not hardcode new radii, panel recipes, or button treatments inline if a recipe already exists.
- Do not fall back to generic SaaS blue-on-white panels.
- Do not add new font families outside the approved trio.
- Do not split design-system guidance across multiple docs again.

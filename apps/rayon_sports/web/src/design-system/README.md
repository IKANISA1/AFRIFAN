# Web Design System

The web/PWA token layer is generated from [`packages/core/core_theme`](/Volumes/PRO-G40/AFRICLUB/packages/core/core_theme).

## Source Of Truth

- `packages/core/core_theme` owns the cross-platform primitive tokens.
- `tokens.generated.css` is generated output. Do not edit it manually.
- `theme.css` contains web-specific recipes, motion, and resets only.
- `index.ts` exposes the recipe classnames components should consume.

## Workflow

Run `npm run design-system:sync` after changing Flutter token files.

Run `npm run design-system:check` in CI or before shipping to verify the generated web token file is current.

## Usage Rule

For shell chrome and shared surfaces, prefer `ui.*` recipes over local border, blur, and glass combinations inside feature components.

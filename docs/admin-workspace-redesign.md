# Admin Workspace Redesign

## Audit Summary

### Current issues
- Navigation is flat and noisy. Top-level admin links mix modules and subviews, especially under CMS.
- Screen hierarchy is oversized and brand-heavy for operations. Display typography and decorative glass effects compete with data.
- List-heavy modules rely on stacked cards instead of scan-first tables, which slows review and bulk decision-making.
- Status patterns are inconsistent across modules. Similar states use different chips, borders, and wording.
- Repeated helper copy and verbose section titles add friction without improving decisions.
- Action placement varies by screen. Edit, publish, feature, delete, and refresh controls are not standardized.

### What changed in this rollout
- Added an admin-scoped visual layer with calmer surfaces, restrained contrast, and operational spacing.
- Simplified shell navigation into grouped sections and moved CMS subviews into contextual secondary navigation.
- Standardized page headers, KPI cards, status badges, action buttons, and surface containers.
- Converted dashboard, matches, CMS, notifications, and contributions to widget-first or table-first layouts.

## Design Principles

1. Signal over description.
2. Tables over stacked management cards.
3. One primary decision zone per screen.
4. Secondary detail moves into drawers, editors, or row metadata.
5. Status is always visible and visually consistent.
6. Actions sit at row or panel edges, never buried in copy.
7. Navigation should expose modules, not internal implementation detail.
8. The workspace stays calm under pressure: low-noise chrome, strong hierarchy, restrained color.

## Admin Tokens

### Color
- Workspace background: deep neutral slate.
- Primary surface: dark graphite panel with subtle elevation.
- Secondary surface: slightly darker inset for forms and supporting controls.
- Accent: club primary for active state and primary actions only.
- Success, warning, danger, info: reserved for status and alerts.

### Typography
- Page titles: short, sentence case, high contrast.
- Eyebrows: compact uppercase labels for orientation only.
- Body copy: muted, short, operational.
- Table headers: uppercase micro-labels with consistent spacing.
- KPI values: large but not decorative.

### Spacing
- 24px base panel padding.
- 12px to 16px row rhythm inside tables and queues.
- 8px action clusters.
- 2-level hierarchy only: primary block and secondary metadata.

## Component Library

### Core primitives
- `AdminPageHeader`
- `AdminSurface`
- `AdminStateCard`
- `AdminStatusBadge`
- `AdminEmptyState`

### Operational components
- KPI cards
- Filter chip rows
- Search and action toolbars
- Sortable management tables
- Row action button sets
- Recent activity timeline cards
- Session and scope chips
- Contextual secondary navigation blocks

## Table System Rules

1. First column is always the entity and must carry the strongest identity.
2. Second-level detail stays in the same cell as subdued metadata, not in extra columns.
3. Status is always a badge, never plain text.
4. Numeric cells use strong values with muted labels underneath.
5. Row actions align right and use the same button treatment everywhere.
6. Progress uses bars only when it adds operational value.
7. Empty states explain the next operational move in one sentence.

## Status And Icon Rules

### Badge tones
- Neutral: passive state, draft, archived, standard metadata.
- Accent: highlighted or promoted state.
- Info: scheduled, informational, upcoming.
- Success: active, live, completed successfully, visible.
- Warning: queued, pending, manual review.
- Danger: failed, blocked, inactive, suspended, closed.

### Icon usage
- Icons indicate object type, state, or action.
- Icons are never used as decoration in headers.
- Destructive actions always pair the icon with a text label.

## Dashboard Guidance

- Keep four to six KPIs max.
- Use the second row for operational lanes and activity, not charts.
- Surface recent events and next actions before historical analysis.
- Avoid broad analytics blocks on the landing screen.

## User Management Guidance

When the user-management module is added or expanded, use:
- Table-first list with columns for user, role, status, membership, last activity, flags, and actions.
- Bulk selection with sticky bulk action bar.
- Filter chips for role, risk state, verification state, and account status.
- Detail drawer for profile, permissions, activity, transactions, support history, and audit trail.
- Inline role chips and suspension state badges.

## Operations And Moderation Guidance

- Use review queues, not narrative cards.
- Split tabs by action state: pending, flagged, approved, resolved, archived.
- Put approve, reject, escalate, suspend, and assign in the same action zone.
- Keep audit context in a side panel or row expansion, not inline copy.

## Reusable Widget Patterns

- KPI summary cards
- Review queue tables
- Status distribution strips
- Audit timeline cards
- Quick action grids
- Filter chip rows
- Bulk action bars
- Detail drawers
- Empty state panels
- Inline health badges

## Navigation Simplification

### Primary shell groups
- Core
- Supporters
- Content
- Platform

### Secondary navigation
- Only expose module subviews contextually.
- CMS subpages live under a dedicated contextual section instead of the primary sidebar.

## Incremental Rollout Plan

1. Roll the shared shell and status system first.
2. Migrate highest-traffic queues to table-first layouts.
3. Standardize forms and detail panels around the same surface and input styles.
4. Add drawers and bulk actions to user, moderation, and support modules.
5. Finish with analytics, logs, and configuration edge cases.

## Production Rollout Notes

- Keep current routes, data contracts, and permissions intact.
- Migrate screen by screen behind the existing module boundaries.
- Reuse the new primitives rather than inventing per-screen styling.
- Prefer additive refactors over module rewrites.

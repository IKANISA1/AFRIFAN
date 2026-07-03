# AFRICLUB Architecture Blueprint

Updated: 2026-07-02

Design authority: this document is architecture-only. `../DESIGN.md` is the
sole source for product visuals, interface rules, tokens, screen archetypes, and
state requirements.

## 1. Target State

AFRICLUB is a white-label club platform with five governed surfaces:

1. Flutter native mobile app for authenticated supporters.
2. Flutter native TV app surface for screen-safe venue and game runtime experiences.
3. Venue app/portal for venue-scoped operators.
4. Centralized admin PWA for club operators.
5. White-label public website for clubs.

Rayon Sports is the reference club profile used to seed defaults, configuration data, and example content. The platform does not support a browser fan portal.

## 2. Architectural Decisions

### ADR-001: Shared Backend, Club-Scoped Tenancy

- One Supabase project serves all clubs.
- Every club-owned table is scoped by `club_id`.
- `club_slug` is used for routing, hostname mapping, and identity lookup.
- `partner_id` remains legacy-only and must not be used for unscoped fallback queries.

### ADR-002: Native Fan Journeys

- Authenticated supporter flows live in Flutter only.
- Web may present public discovery, marketing, search, and supporter handoff.
- Ticket purchase, membership management, contributions, and authenticated fan workflows continue in the native app.

### ADR-003: Centralized Admin Workspace

- Admin lives in a single web workspace.
- Access is role-based and club-scoped.
- Admin CRUD must always include the active `club_id`.

### ADR-004: White-Label Website

- Public website resolves the active club from host mapping or slug.
- Branding, copy, and data loaders must derive from the active club context.
- Rayon-specific defaults are acceptable only as the seeded reference profile when club data is absent.

### ADR-005: Venue And TV Product Surfaces

- Native TV is a Flutter app target under `apps/rayon_sports_tv`.
- Web `/tv-display` is a browser compatibility/admin pairing surface, not the TV app of record.
- Venue app starts under `apps/rayon_sports/web/src/app/venue` to reuse auth, Supabase, CI, and PWA infrastructure.
- Venue records require `club_id`; venue-owned records also require `venue_id`.
- Venue check-in is rotating QR/code first. Foreground location is optional verification only.
- Drinks ordering is a drinks-only top-10 MVP, not full POS or delivery.
- TV surfaces are read-only and must not expose personal, order, or wallet data.

## 3. Product Surface Ownership

### Flutter Fan App

Purpose:
- Identity, membership, ticketing, supporter communities, commerce, venue check-in, and authenticated fan engagement.

Code shape:
- `apps/<club>/` contains the native shell and configuration data.
- `packages/core/` contains shared shell, auth, routing, theme, and network.
- `packages/features/` contains shared features.
- `packages/clubs/` contains per-club config.

Rules:
- No admin or venue-staff operations in the supporter app.
- Venue check-in and drinks-ordering routes stay under Fan Zone and behind launch flags.
- Foreground location is requested only after supporter action.

### Flutter Native TV App

Purpose:
- Screen-safe venue QR/code display, TV-led game runtime, and shared matchday state.

Code shape:
- `apps/rayon_sports_tv`
- `apps/rayon_sports/web/src/app/tv-display` remains browser compatibility only.
- `africlub_game` schema for game runtime.
- `venue_checkin_codes` for hashed rotating venue code contracts.

Rules:
- Read-only.
- No personal data, wallet balance, check-in identity, or live order queue.
- Supports 720p and 1080p UAT screenshots.

### Venue App / Portal

Purpose:
- Venue-scoped operator dashboard for assigned venues, check-ins, drinks-only order queue, top-10 menu, promotions, TV code, and staff role visibility.

Code shape:
- `apps/rayon_sports/web/src/app/venue`
- `public.venues`, `venue_staff_memberships`, `venue_checkins`, `venue_drink_orders`, and related event tables.

Rules:
- Venue staff access only assigned `venue_id`.
- Day-to-day menu and order handling lives here, while club-wide oversight stays in Admin PWA.
- No service-role keys or private partner/feed data in browser clients.

### Public Website

Purpose:
- Discovery, storytelling, fixtures, standings, public ticket context, approved venue discovery, supporter acquisition, and supporter-app handoff.

Code shape:
- `apps/rayon_sports/web/src/app/(site)`
- `apps/rayon_sports/web/src/lib/data/public/*`

Rules:
- No authenticated fan portal routes.
- No anonymous browser fan session bootstrapping.
- No authenticated check-in or live order queues.
- Public loaders must resolve club context first, then query by `club_id`.

### Admin PWA

Purpose:
- Publishing, operations, match control, standings, shop/catalog, membership, supporter groups, notifications, venue oversight, FET review/export, and configuration.

Code shape:
- `apps/rayon_sports/web/src/app/admin`
- `apps/rayon_sports/web/src/lib/data/admin/*`

Rules:
- Desktop/tablet-first shell.
- All writes require same-origin mutation checks and role-scoped access.
- All admin queries and mutations must be club-scoped.
- Venue mutations must write audit/event rows.

## 4. Tenant Model

### Canonical Identity

- `club_id`: primary tenant identifier in data storage.
- `club_slug`: public routing and hostname identifier.
- `club_app_config`: per-club config overrides.
- `app_config`: global defaults only.

### Safe Query Rules

- Never fall back from scoped queries to unscoped reads.
- Never resolve club scope by “first row found”.
- Never re-query records by bare `id` without `club_id` when club ownership matters.

### Club Resolution

Web resolves the active club through:

1. Explicit host override map.
2. Default club slug fallback.
3. First subdomain label normalization.

Once resolved, loaders query Supabase by `club_slug` or `club_id` and then merge:

1. Global defaults from `app_config`.
2. Club overrides from `club_app_config`.

## 5. Repo Structure

```text
apps/
  rayon_sports/
    web/
      src/app/(site)/       public website
      src/app/admin/        centralized admin PWA
      src/app/tv-display/   browser compatibility display
      src/app/venue/        venue app/portal
  rayon_sports_tv/          Flutter native TV app
  <club_flutter_apps>/

packages/
  core/
    core_app/
    core_auth/
    core_network/
    core_router/
    core_theme/
    core_utils/
  features/
    feat_home/
    feat_ticketing/
    feat_membership/
    feat_shop/
    feat_contributions/
    feat_fan_clubs/
    feat_settings/
    ...
  clubs/
    club_rayon_sports/
    club_<other clubs>/

supabase/
  migrations/
```

## 6. Mobile App Composition

Each club app is intentionally thin:

- native bundle identifiers
- compile-time config
- bootstrap entrypoint
- generated runtime brand mark and tokenized splash surfaces governed by `../DESIGN.md`

Shared business logic, routes, and modules live in packages. Feature flags determine which modules and routes are active for a club.

## 7. Web Composition

### Public Site

- Server components fetch public data through club-aware loaders.
- Metadata is generated per club context.
- Public navigation points fans toward the native app where needed.

### Admin PWA

- Client shell hydrates authenticated admin state.
- Domain modules handle scoped CRUD.
- PWA support is retained for admin operational workflows and public-site installability.

## 8. Data and Migrations

Recent tenancy hardening includes:

- removal of unsafe unscoped mobile repository fallbacks
- removal of web fan portal routes
- introduction of `club_app_config`
- club-scoped CMS/config access in public and admin loaders
- white-label host/slug resolution in the public website
- venue check-in, venue staff, drinks ordering, FET reservation, and order event foundations

Migration policy:

- schema changes land in `supabase/migrations/`
- multi-tenant tables must include `club_id` where appropriate
- club-specific configuration belongs in `club_app_config`

## 9. Validation Gates

Required checks:

- Flutter static analysis on touched packages
- Flutter package tests for touched domains
- `npm run lint`
- `npm run typecheck`
- `npm run test`
- Supabase SQL contract tests for touched schema/RPCs
- UAT evidence matrix in `docs/release/rayon_fullstack_uat_matrix.md`
- Security scan for service-role, LiveScore credential, and private feed exposure

## 10. Non-Goals

The following are intentionally out of scope for the current architecture:

- browser-based fan portal
- public web check-in or live order queues
- cross-club unscoped admin browsing without explicit club context
- duplicate per-club web codebases
- full POS, delivery, open-loop FET spend, or cash-out

## 11. Reference Implementation

Rayon Sports remains the seeded reference for:

- default club profile values
- default web environment settings
- example configuration and release evidence
- initial rollout validation

Reference defaults must not become hardcoded assumptions in shared runtime logic.

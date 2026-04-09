# AFRICLUB PLATFORM

White-label football platform with three product surfaces:

1. Flutter native mobile app for fans.
2. Centralized admin PWA for club operators.
3. White-label public website for each club.

Rayon Sports is the reference club profile and seeded default. The platform is not a browser fan portal anymore. Authenticated fan journeys belong in Flutter.

## Current Architecture

- One Melos monorepo for mobile, web, shared packages, and Supabase migrations.
- One shared Supabase backend with club-scoped tenancy.
- One canonical tenant model:
  - `club_id` for database scoping.
  - `club_slug` for routing, host mapping, and branding resolution.
  - `partner_id` treated as legacy compatibility only.

## Product Surfaces

### Flutter Native Fan App

- White-label fan app per club.
- Shared features live in `packages/features/*`.
- Per-club identity lives in `packages/clubs/*`.
- Club apps under `apps/*` are thin shells around shared modules and assets.

### Admin PWA

- Centralized multi-club operator workspace.
- Lives in `apps/rayon_sports/web/src/app/admin`.
- Club access is resolved server-side and all admin data operations are scoped by `club_id`.

### Public Website

- White-label public club website.
- Lives in `apps/rayon_sports/web/src/app/(site)`.
- Club branding and content resolve from hostname, slug, and club configuration.
- Website hands users off to the supporter app instead of hosting a fan portal.

## Repo Structure

```text
apps/
  rayon_sports/
    web/                  Next.js website + admin PWA
  <club apps>/            Flutter fan apps

packages/
  core/                   shared app shell, routing, auth, network, theme
  features/               shared product features
  clubs/                  per-club config packages

supabase/
  migrations/             schema and tenancy migrations
```

## Platform Rules

- No unscoped club queries on app data.
- No fan web portal surface.
- No frontend hardcoding that assumes Rayon outside reference defaults.
- UI changes should preserve the current visual system unless explicitly approved.

## Common Commands

```bash
melos bootstrap
melos exec -- flutter analyze
cd apps/rayon_sports/web && npm run lint
cd apps/rayon_sports/web && npm run typecheck
cd apps/rayon_sports/web && npm run test
```

## Key Docs

- [docs/blueprint.md](/Volumes/PRO-G40/AFRICLUB/docs/blueprint.md)
- [apps/rayon_sports/web/README.md](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/README.md)
- [1supabase.md](/Volumes/PRO-G40/AFRICLUB/1supabase.md)

Confidential & Proprietary — IKANISA Ltd.

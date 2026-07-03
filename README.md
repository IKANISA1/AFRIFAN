# AFRICLUB PLATFORM

White-label football platform with five product surfaces:

1. Flutter native mobile app for authenticated supporters.
2. Flutter native TV app surface for screen-safe matchday and venue code experiences.
3. Venue app/portal for venue-scoped operators.
4. Centralized admin PWA for club operators.
5. White-label public website for each club.

Rayon Sports is the reference club profile and seeded default. The platform is not a browser fan portal. Authenticated fan journeys belong in Flutter.

## Current Architecture

- One Melos monorepo for mobile, web, shared packages, and Supabase migrations.
- One shared Supabase backend with club-scoped tenancy.
- One canonical tenant model:
  - `club_id` for database scoping.
  - `club_slug` for routing, host mapping, and branding resolution.
  - `partner_id` retained only for archived migration compatibility.

## Product Surfaces

### Flutter Native Fan App

- White-label fan app per club.
- Shared features live in `packages/features/*`.
- Per-club identity lives in `packages/clubs/*`.
- Club apps under `apps/*` are thin shells around shared modules and configuration data.

### Admin PWA

- Centralized multi-club operator workspace.
- Lives in `apps/rayon_sports/web/src/app/admin`.
- Club access is resolved server-side and all admin data operations are scoped by `club_id`.

### Flutter Native TV App

- Native Flutter TV app lives in `apps/rayon_sports_tv`.
- Web `/tv-display` remains a browser compatibility/admin pairing surface only.
- Shows screen-safe game and venue code state only.
- Must not expose personal, wallet, check-in identity, or order data.

### Venue App / Portal

- Venue operator surface lives in `apps/rayon_sports/web/src/app/venue`.
- Access is scoped by `venue_staff_memberships`.
- Handles assigned-venue dashboard, check-ins, drinks-only top-10 order queue, promotions, TV code, and staff role visibility.

### Public Website

- White-label public club website.
- Lives in `apps/rayon_sports/web/src/app/(site)`.
- Club branding and content resolve from hostname, slug, and club configuration.
- Website hands users off to the supporter app instead of hosting a fan portal.
- Approved venues can be discovered publicly, but check-in and ordering stay in the supporter app.

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
- No public browser check-in or live venue order queues.
- No mobile admin or venue-staff operations in the supporter app.
- LiveScore data remains source-of-record controlled by admin/server sync.
- FET is a closed-loop monetary-equivalent reward ledger until legal/payment review approves otherwise.
- No frontend hardcoding that assumes Rayon outside reference defaults.
- UI changes must follow `DESIGN.md`, the only design authority for this repo.
- Architecture and runbook documents are operational references only. They must
  not redefine product visuals, screen inventories, token values, or interface
  rules outside `DESIGN.md`.

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
- [docs/venue_app_architecture.md](/Volumes/PRO-G40/AFRICLUB/docs/venue_app_architecture.md)
- [docs/fet_ledger_and_rewards_policy.md](/Volumes/PRO-G40/AFRICLUB/docs/fet_ledger_and_rewards_policy.md)
- [docs/release/rayon_fullstack_uat_matrix.md](/Volumes/PRO-G40/AFRICLUB/docs/release/rayon_fullstack_uat_matrix.md)
- [DESIGN.md](/Volumes/PRO-G40/AFRICLUB/DESIGN.md)
- [apps/rayon_sports/web/README.md](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/web/README.md)
- [1supabase.md](/Volumes/PRO-G40/AFRICLUB/1supabase.md)

Confidential & Proprietary — IKANISA Ltd.

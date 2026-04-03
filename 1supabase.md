

| [https://mmpbzcdhfvplxplnfucy.supabase.co](https://mmpbzcdhfvplxplnfucy.supabase.co) |
| :---- |
| eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tcGJ6Y2RoZnZwbHhwbG5mdWN5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMxNDM2MTYsImV4cCI6MjA4ODcxOTYxNn0.Ojw-vQ6aEJjyuZU4nReP4ynxJ2XjD5L6n6TxhLlzeeQ |
| eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1tcGJ6Y2RoZnZwbHhwbG5mdWN5Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzE0MzYxNiwiZXhwIjoyMDg4NzE5NjE2fQ.X6pTmm0fxmEp91j7Py75LRi02ZmqEjEiX9NbOHQDFRM |
| postgresql://postgres:hEcEZty2PfRaMZkT@db.mmpbzcdhfvplxplnfucy.supabase.co:5432/postgres |
| sbp\_a3585a6696a74512db1c58bf15ef21a11261a68f |

# Critical Audit Report: AfriClub Supabase Implementation

**Objective:** Assess the structural integrity, security, and production-readiness of the AfriClub Supabase backend, specifically regarding the Kinetic Football Authority multi-tenant mandates.

**Last Updated:** 2026-03-30

## 1. Multi-Tenant Foundation (✅ Pass)
The core isolation logic introduced in `20260330200000_phase1_multitenant_foundation.sql` is sound:
- **JWT Provider:** `custom_access_token_hook` is properly defined to inject `club_id` and `user_role` into `app_metadata`.
- **JWT Hook Enabled:** `config.toml` lines 267-269 confirm `[auth.hook.custom_access_token]` is `enabled = true`. ✅
- **Isolation Helper:** `requesting_club_id()` safely parses claims for RLS.
- **Strict Scoping:** Critical new tables (`biopay_*`, `momo_*`, `contributions`, `shop_products`, `profiles`) are properly scoped to `club_id` via robust RLS policies.

## 2. Schema Normalization (✅ Resolved)
Phase 2 migration (`20260330210000_phase2_schema_normalization.sql`) addresses all legacy issues:

### rs_* Table Renaming — ✅ Complete
All single-tenant Rayon Sports tables have been renamed to generic multi-tenant names:
- `rs_achievements` → `achievements`
- `rs_fan_clubs` → `fan_clubs`
- `rs_fan_club_members` → `fan_club_members`
- `rs_matches` → `matches`
- `rs_tickets` → `tickets`
- `rs_shop_orders` → `shop_orders`
- `rs_initiatives` → `initiatives`
- `rs_initiative_contributions` → `initiative_contributions`
- `rs_membership_packages` → `membership_packages`

### Gamification `club_id` Isolation — ✅ Complete
Phase 2 migration adds `club_id` columns and RLS policies to:
- `cool_status` (with index + multi-tenant SELECT/INSERT policies)
- `cool_achievements`
- `cool_missions`
- `cool_reward_redemptions`

### Dead Table Cleanup — ✅ Complete
Phase 2 migration drops out-of-scope tables:
- `groups` (superseded by `contribution_groups`)
- `mobility_trips` (out of scope)
- `driver_profiles` (out of scope)

## 3. Remaining Flutter Code Alignment
- **`rs_shop_products` fallback logic** in 3 Flutter files still references old table names as fallbacks. These should be cleaned up to use `shop_products` directly since the DB migration is applied.
- **`_resolvePartnerId()` in `club_repository.dart`** has duplicate table arrays that should be deduplicated.

## 4. Auth.Users Multi-Tenancy
- The `handle_new_user` trigger correctly reads `club_id` from `raw_app_meta_data` during sign-up.
- User role mapping defaults to `'fan'` via the JWT hook, with admin overrides via `admin_role_assignments`.
- Cross-club role support: A user's role is club-scoped via `app_metadata.club_id`, preventing cross-tenant role leakage.

## 5. Multi-Tenant Design System Backend (✅ Complete)
The `african_football_clubs` table serves as the source of truth for the Dynamic Color Architecture.
- **Brand Colors:** Stores `primary_color_hex`, `secondary_color_hex`, and `accent_color_hex`.
- **White-Drop Rule Backup:** The Flutter client receives these colors at bootstrap and automatically drops any white/near-white colors (`luminance > 0.9`), substituting them with dark-mode safe defaults.
- All 50+ African clubs have been inserted with their correct basic metadata and colors via `20260330100000_supported_countries.sql` and `20260330110000_teams_data.sql`.
- **Data Initialization:** The `bootstrap.dart` workflow extracts the active club's branding via the ClubConfig singleton and initializes `ColorTokens.init()` before building the UI, ensuring that all UI components reflect the correct branding immediately.

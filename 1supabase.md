# Supabase Configuration

> **⚠️ SECURITY NOTICE:** Secrets (service_role key, database connection string, anon key)
> must NEVER be stored in source control. Use environment variables or a secrets manager.

## Project Reference

| Item | Value |
|------|-------|
| Project Ref | `mmpbzcdhfvplxplnfucy` |
| Dashboard | https://supabase.com/dashboard/project/mmpbzcdhfvplxplnfucy |

## Key Locations

- **Anon key**: Set via `SUPABASE_ANON_KEY` environment variable or `production.json` flavor config
- **Service role key**: Set via `SUPABASE_SERVICE_ROLE_KEY` environment variable in Edge Function secrets only
- **Database URL**: Available in Supabase Dashboard → Settings → Database
- **Firebase runtime secrets**: Set via `FIREBASE_PROJECT_ID` and `FIREBASE_SERVICE_ACCOUNT_JSON` in Edge Function secrets

## Firebase Runtime Secrets

Rayon Sports BioPay and push notifications now rely on Firebase-backed server verification and FCM sends.

Provision local secret material from a service-account JSON file:

```bash
bash tools/scripts/provision_firebase_runtime.sh \
  --service-account-file /absolute/path/to/firebase-service-account.json
```

Push to the linked Supabase project if your CLI account has permission:

```bash
bash tools/scripts/provision_firebase_runtime.sh \
  --service-account-file /absolute/path/to/firebase-service-account.json \
  --push-supabase
```

Runbook:

- [apps/rayon_sports/FIREBASE_ROLLOUT.md](/Volumes/PRO-G40/AFRICLUB/apps/rayon_sports/FIREBASE_ROLLOUT.md)

## Critical Audit Report: AfriClub Supabase Implementation

**Objective:** Assess the structural integrity, security, and production-readiness of the AfriClub Supabase backend, specifically regarding the Tactile Monolith multi-tenant mandates.

**Last Updated:** 2026-04-04

### 1. Multi-Tenant Foundation (✅ Pass)
The core isolation logic introduced in `20260330200000_phase1_multitenant_foundation.sql` is sound:
- **JWT Provider:** `custom_access_token_hook` is properly defined to inject `club_id` and `user_role` into `app_metadata`.
- **JWT Hook Enabled:** `config.toml` lines 267-269 confirm `[auth.hook.custom_access_token]` is `enabled = true`. ✅
- **Isolation Helper:** `requesting_club_id()` safely parses claims for RLS.
- **Strict Scoping:** Critical new tables (`biopay_*`, `momo_*`, `contributions`, `shop_products`, `profiles`) are properly scoped to `club_id` via robust RLS policies.

### 2. Schema Normalization (✅ Resolved)
Phase 2 migration (`20260330210000_phase2_schema_normalization.sql`) addresses all legacy issues:

#### rs_* Table Renaming — ✅ Complete
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

#### Gamification `club_id` Isolation — ✅ Complete
Phase 2 migration adds `club_id` columns and RLS policies to:
- `cool_status` (with index + multi-tenant SELECT/INSERT policies)
- `cool_achievements`
- `cool_missions`
- `cool_reward_redemptions`

#### Dead Table Cleanup — ✅ Complete
Phase 2 migration drops out-of-scope tables:
- `groups` (superseded by `contribution_groups`)
- `mobility_trips` (out of scope)
- `driver_profiles` (out of scope)

### 3. Remaining Flutter Code Alignment
- **`rs_shop_products` fallback logic** in 3 Flutter files still references old table names as fallbacks. These should be cleaned up to use `shop_products` directly since the DB migration is applied.
- **`_resolvePartnerId()` in `club_repository.dart`** has duplicate table arrays that should be deduplicated.

### 4. Auth.Users Multi-Tenancy
- The `handle_new_user` trigger correctly reads `club_id` from `raw_app_meta_data` during sign-up.
- User role mapping defaults to `'fan'` via the JWT hook, with admin overrides via `admin_role_assignments`.
- Cross-club role support: A user's role is club-scoped via `app_metadata.club_id`, preventing cross-tenant role leakage.

### 5. Multi-Tenant Design System Backend (✅ Complete)
The `african_football_clubs` table serves as the source of truth for the Dynamic Color Architecture.
- **Brand Colors:** Stores `primary_color_hex`, `secondary_color_hex`, and `accent_color_hex`.
- **White-Drop Rule Backup:** The Flutter client receives these colors at bootstrap and automatically drops any white/near-white colors (`luminance > 0.9`), substituting them with dark-mode safe defaults.
- All 50+ African clubs have been inserted with their correct basic metadata and colors via `20260330100000_supported_countries.sql` and `20260330110000_teams_data.sql`.
- **Data Initialization:** The `bootstrap.dart` workflow extracts the active club's branding via the ClubConfig singleton and initializes `ColorTokens.init()` before building the UI, ensuring that all UI components reflect the correct branding immediately.

# Platform Feature Management Architecture & Rollout

## 1. Architecture Audit
Historically, the application and website relied on statically defined features within the codebase or rudimentary app configuration (`club_app_config` and `app_config`). This meant enabling or disabling an entire module (e.g., Ticketing, Shop) required application updates, hard-coded UI conditions, and lack of fine-grained control.

## 2. Proposed Target Architecture
We introduced a centralized, database-driven feature registry that enforces state across all boundaries (Mobile, Web, Backend, Admin).
- **Registry:** `platform_features` dictates global operations.
- **Channels:** `platform_feature_channels` splits controls for `mobile` and `web`, and governs UI behaviors (`show_in_navigation`, `show_on_home`).
- **Rules:** `platform_feature_rules` holds auth, dependency, and scheduling constraints.
- **Auditing:** `platform_feature_audit_logs` ensures every feature toggle leaves an audit trail.

## 3. Implementations
1. **Supabase Data Model:** Deployed via `20260416140000_platform_feature_management.sql`. Includes RPC `get_platform_config` which resolves the feature state effectively.
2. **Backend Guard:** Added `server-feature-guard.ts` for strict operational checking on backend mutations. Feature gating now extends to API response blocking.
3. **Web Frontend Integration:** Added `lib/features.ts` returning cached configuration fetched from `get_platform_config`. `global-nav.tsx` and `layout.tsx` were refactored to adapt the top-level navigation dynamically based on active features.
4. **Admin UI Control Panel:** Designed `apps/rayon_sports/web/src/app/admin/settings/features/page.tsx` integrating high-density data grids to give admins absolute power over features and sub-channel visibilities.
5. **Mobile App:** Leverages the pre-existing `FeatureConfigService` in `packages/core/core_feature_config` which interfaces flawlessly with the updated Supabase RPC. Module loading logic in `module_registry.dart` dynamically loads or disables entire Flutter packages based on the payload.

## 4. Rollout Notes
1. **Data Seed:** The migration automatically seeded primary features (e.g., `tickets`, `shop`, `membership`, `news`, `squad`, `biopay`). Ensure all keys match exactly what's required by the Web and Mobile code.
2. **Cache invalidation:** Frontends employ a lightweight 5-minute TTL cache (`lib/features.ts`).
3. **Graceful Fallback:** If the network fails, applications default to the last fetched cache or the statically defined `ClubConfig` map.
4. **Action Required:** Admins must configure specific channels per feature inside the Admin Dashboard `/admin/settings/features` to activate dynamic UI blocks.

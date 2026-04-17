# Platform Feature Management Audit, Architecture, and Rollout

## Scope
This document records the current-state audit, the target architecture, the Supabase schema and RLS model, and the rollout posture for the admin-controlled feature management refactor delivered on 2026-04-16.

## 1. Architecture Audit
Before this refactor, feature exposure was controlled inconsistently across the stack.

- Mobile routing and home composition depended on module registration plus hardcoded visibility checks.
- The website mixed static navigation definitions, page-level assumptions, and club-config booleans.
- Backend and API handlers did not have a single reusable feature-enforcement entry point.
- Admin tools had no unified registry for global enablement, per-channel visibility, schedule windows, dependencies, or ordering.
- Homepage blocks, quick actions, and navigation entries were only partially configurable and were not enforced consistently beyond the rendering layer.
- Existing Supabase app configuration tables were useful for bootstrap context, but they were not expressive enough to govern feature lifecycle and channel-specific exposure safely.

## 2. Target Architecture
The target architecture is a single source of truth in Supabase with consistent enforcement in database access, admin writes, backend actions, mobile routing, and website rendering.

- `platform_features` is the canonical feature registry.
- `platform_feature_channels` stores per-channel state for `mobile` and `web`.
- `platform_feature_rules` stores auth requirements, role restrictions, dependency rules, rollout metadata, and scheduling windows.
- `platform_content_blocks` stores admin-managed homepage, promo, banner, quick-action, and section content tied to placements and optionally tied to features.
- `platform_feature_audit_logs` records before/after state for feature and content-block mutations.
- `get_platform_config(...)` returns the resolved, channel-scoped configuration payload consumed by the app and website.
- `get_feature_access_state(...)` returns the resolved availability state used for backend/API enforcement.

## 3. Supabase Schema and Migrations
The feature-management schema is implemented through additive migrations.

- `20260416140000_platform_feature_management.sql`
  - creates the base feature, channel, rule, content-block, and audit tables
  - creates the initial RLS policies, triggers, helper functions, and config RPC
  - seeds the initial registry entries for the major product modules
- `20260416180000_harden_platform_feature_management.sql`
  - adds canonical key normalization for safer lookups
  - hardens uniqueness rules for global versus club-scoped content blocks
  - adds `get_feature_access_state(...)`
  - updates `check_feature_enabled(...)` to respect operational state instead of only visual visibility
  - updates `get_platform_config(...)` to resolve club overrides and emit a stable `config_version`
  - audits both feature and content-block changes through triggers
  - revokes unsafe public table access and limits direct reads to admin-only policies
- `20260416210000_feature_management_club_admin_access.sql`
  - aligns RLS with club-admin override workflows used by the mobile and web admin clients
  - allows club admins to read global defaults plus their club-scoped overrides
  - restricts writes so club admins can only create or mutate their own scoped override rows
- `20260416223000_platform_content_block_audit_fix.sql`
  - ensures `platform_content_blocks` writes are also captured in `platform_feature_audit_logs`
- `20260416224000_feature_delete_audit_fk_fix.sql`
  - prevents feature-delete audit rows from violating the audit foreign key on `DELETE`
- `20260416224500_feature_audit_missing_fk_guard.sql`
  - hardens audit logging for cascading deletes by nulling `feature_id` if the referenced feature row is already gone
- `20260416225000_restore_feature_access_state_rpc.sql`
  - restores `get_feature_access_state(...)` and its grants in environments where the hardening migration was only partially applied
- `20260416230000_restore_canonicalize_feature_key.sql`
  - restores `canonicalize_platform_feature_key(...)` and its execute grants when the hardening chain is missing that helper
- `20260416233000_preserve_explicit_fan_membership_tier.sql`
  - preserves explicit membership tiers such as `gold` or `platinum` during `fan_memberships` writes instead of forcing every row back to a points-derived `fan/bronze/gold/platinum` band

## 4. RLS and Permission Model
RLS is designed so public clients only consume sanitized configuration through RPC, while admin writes stay server-controlled.

- Raw feature tables are no longer exposed to unrestricted frontend reads.
- Public and authenticated clients use `get_platform_config(...)` and `get_feature_access_state(...)`.
- Direct writes to feature tables are restricted to authorized admins.
- Audit logs are append-only through trusted database-side trigger paths.
- Admin mutations are routed through the web admin server boundary and use the admin Supabase client instead of trusting browser writes.
- Club-scoped admin edits create scoped override rows rather than mutating global defaults when appropriate.

## 5. Feature Access Service Layer
Feature evaluation now has explicit semantics across visibility and operational state.

- `get_feature_access_state(...)` in Supabase resolves:
  - registration state
  - global enablement
  - channel enablement
  - visibility state
  - navigation and home flags
  - auth requirements
  - role restrictions
  - dependency rules
  - schedule windows
- `packages/core/core_feature_config` exposes the same logic to Flutter via `FeatureConfigService`.
- `apps/rayon_sports/web/src/lib/feature-config.ts` exposes the same logic to the website.
- `apps/rayon_sports/web/src/lib/server-feature-guard.ts` enforces feature state for backend/API handlers and fails closed on RPC or initialization errors.

## 6. Admin Panel Refactor
The admin panel is now the control surface for feature and content exposure.

- `apps/rayon_sports/web/src/app/admin/settings/features/page.tsx`
  - registry editing for global state, visibility state, per-channel nav/home flags, ordering, auth, role restrictions, dependencies, and scheduling
- `apps/rayon_sports/web/src/lib/data/admin/features.ts`
  - scoped override creation and update flow for feature rows, channel rows, and rule rows
- `apps/rayon_sports/web/src/lib/data/admin/content-blocks.ts`
  - scoped override flow for managed blocks and placements
- `apps/rayon_sports/web/src/lib/admin-api-handler.ts`
  - centralized admin auth, CSRF/rate-limit hooks, club-scope resolution, and server-side admin client setup
  - now also applies club-aware feature guards for sensitive admin mutations before they reach business logic
- `apps/rayon_sports/web/src/app/api/admin/[resource]/route.ts`
  - now covers admin-facing ticket orders, supporter registry, and membership applications on the browser API boundary
  - now fail-closes notifications sends and FET wallet balance adjustments when the underlying feature is disabled
- `apps/rayon_sports/web/src/app/api/admin/tickets/status/route.ts`
  - explicit ticket validation/cancellation endpoint used by the browser admin, guarded by `ticketing`
- `apps/rayon_sports/web/src/app/api/admin/membership-applications/review/route.ts`
  - explicit membership application review endpoint used by the browser admin, guarded by `membership`
- `apps/rayon_sports/web/src/app/api/admin/push/route.ts`
  - notification send action now respects the central feature-access RPC instead of bypassing it

## 7. Flutter Mobile Refactor
Mobile now consumes the backend registry as configuration instead of assuming feature exposure from local module structure alone.

- `PlatformFeature`, `FeatureAccessState`, and normalized-key lookup were expanded in `core_feature_config`.
- `FeatureConfigService` now distinguishes:
  - visible but hidden from UI
  - visible but operationally disabled
  - operationally enabled but auth/role blocked
  - route availability
- `FeatureGate` and `ChannelGate` now depend on `canRenderFeature(...)`.
- `FeatureModule.isEnabledForConfig(...)` keeps hidden features registered while removing operationally disabled modules.
- `AppRouter` redirects blocked routes to `/feature-unavailable`.
- `AfriClubApp` now allows `/feature-unavailable` to remain reachable for authenticated users instead of redirecting them back into the blocked route.
- `AppShell` builds navigation from admin-controlled visibility and ordering instead of assuming shell branch order.
- `FeatureConfigRepository` caches snapshots per `clubId` and `channel` and falls back to the last successful snapshot on fetch failure.

## 8. Website Refactor
The website now consumes the same source of truth and applies it consistently in layout, routing, and content composition.

- `apps/rayon_sports/web/src/lib/feature-config.ts`
  - shared feature access model
  - per-path feature resolution
  - nav/home/content-block filtering
  - last-known-valid in-memory fallback per club for server-side fetch failures
- `apps/rayon_sports/web/src/components/feature-gate.tsx`
  - uses the resolved access service instead of a legacy boolean helper
- `apps/rayon_sports/web/src/components/nav/global-nav.tsx`
  - navigation renders from admin-configured features and ordering
- `apps/rayon_sports/web/src/components/app-bottom-nav.tsx`
  - app-style bottom navigation follows the same resolved config
- `apps/rayon_sports/web/src/components/disabled-feature-fallback.tsx`
  - standardized UX for unavailable routes
- `apps/rayon_sports/web/src/lib/feature-page-guard.tsx`
  - reusable page-level gating helper used by feature landing pages and detail pages

## 9. Backend and API Enforcement
Feature state is now enforced beyond the UI layer.

- `server-feature-guard.ts` queries `get_feature_access_state(...)` instead of trusting frontend assumptions.
- Action handlers can choose `navigation`, `route`, or `action` enforcement semantics.
- Hidden features are not shown in UI routing, but can still remain operational when governance requires that distinction.
- Maintenance, disabled, dependency-blocked, auth-blocked, and role-blocked states now produce deterministic backend responses.
- The guard fails closed if feature access cannot be verified.
- Edge functions now enforce centralized feature state for:
  - `admin-send-notification`
- JWT validation now returns normalized caller roles so backend feature checks can respect role-restricted rules instead of treating every authenticated caller the same.

## 10. Content Blocks, Navigation, and UI Composition
UI composition is now driven by shared feature and content-block rules.

- home sections render from `platform_content_blocks` placements where practical
- navigation items follow channel-specific flags and sort order
- quick actions use route-aware feature availability checks
- promo cards and banners can be tied to feature visibility
- hidden or disabled features are removed from home, nav, and route entry points without relying on CSS-only hiding

## 11. Resilience and Fallback Behavior
The implementation now handles config failures without crashing the app or website.

- Mobile caches the last known valid snapshot in `SharedPreferences`, scoped by club and channel.
- Web keeps a last-known-valid in-memory snapshot per club for server-side fetch errors.
- Empty snapshots are still returned safely when no cache exists.
- Rendering helpers treat unknown features as unregistered rather than throwing.
- Backend/API enforcement fails closed instead of silently allowing a broken configuration path.
- `SafeRpc` now preserves edge-function error payloads from `FunctionException` responses instead of collapsing them to a generic fallback, so feature-disabled backend responses survive up to the app layer.
## 12. Test Coverage Added or Updated
The focused test layer was expanded around the new semantics.

- `packages/core/core_feature_config/test/service_test.dart`
  - hidden versus operational distinction
  - maintenance behavior
  - auth-gated availability
  - route availability
  - dependency-cycle safety
- `packages/core/core_app/test/app_routing_guard_test.dart`
  - disabled deep links land on the unavailable screen
- `apps/rayon_sports/web/src/lib/server-feature-guard.test.ts`
  - backend guard allow/block/fail-closed scenarios
- `apps/rayon_sports/web/src/lib/admin-api-handler.test.ts`
  - shared admin API boundary returns deterministic `403 FEATURE_DISABLED` responses for guarded mutations
  - verifies club-scoped auth context is passed into feature evaluation
- `apps/rayon_sports/web/src/lib/feature-config.test.ts`
  - web-side access semantics
  - nav/content-block filtering
  - route availability
- `apps/rayon_sports/web/src/lib/data/admin-browser-boundary.test.ts`
  - browser admin paths for notifications, wallet adjustments, ticket status, supporter registry, and membership review resolve to the correct API endpoints
- `apps/rayon_sports/web/src/lib/data/admin/membership-ops.test.ts`
  - server-side application loading hydrates profile data without relying on a nonexistent PostgREST embedded relation
  - membership approval resolves the club football partner before seeding and updating `fan_memberships`
- `supabase/recovery/20260416_platform_feature_management_smoke_checks.sql`
  - schema, function, and policy contract checks
  - RPC/grant validation
  - transactional audit-trigger and feature-access smoke checks
- `supabase/functions/*/index_test.ts`
  - edge-function fail-closed coverage for notifications and guarded operations
- `packages/core/core_network/test/safe_rpc_test.dart`
  - preserves edge-function payload errors from `FunctionException`

## 13. Known Constraints
The feature-management implementation is complete in the areas above, but full repository-wide validation is still constrained by unrelated pre-existing issues.

- There is still no automated in-repo Supabase SQL harness for RLS assertions, so database validation currently relies on the recovery smoke script above.
- The delivered changes avoid rebuilding the product from scratch and preserve the existing business logic paths that were still valid.

## 14. Rollout Notes
Rollout should remain incremental and low-risk.

- Run the two feature-management migrations in order on Supabase.
- Run the follow-up hardening migrations for:
  - club-admin RLS alignment
  - content-block audit logging
  - feature-delete audit FK safety
  - cascading-delete audit guards
- Ensure the following live-drift repairs are also present in any environment promoted from backup or partial SQL application:
  - `20260416000002_membership_applications.sql`
  - `20260416225000_restore_feature_access_state_rpc.sql`
  - `20260416230000_restore_canonicalize_feature_key.sql`
  - `20260416233000_preserve_explicit_fan_membership_tier.sql`
- Run `supabase/recovery/20260416_platform_feature_management_smoke_checks.sql` against staging or production-like data after the migrations complete.
- Confirm seeded feature keys match the actual module keys used by Flutter and web routes.
- Validate admin write permissions in staging before granting operational use.
- Populate channel flags and route keys for every major module before enabling UI composition from admin.
- Roll out backend/API guards first for sensitive business actions, then remove remaining legacy frontend-only checks.
- Monitor audit logs for feature and content-block changes during the first admin release.
- Use the release verification commands in [admin_live_uat_runbook.md](/Volumes/PRO-G40/AFRICLUB/docs/admin_live_uat_runbook.md):
  - `npm run qa:supabase:verify`
  - `npm run qa:admin:live`
- Latest Cloudflare release verified in this rollout: `ba5465ab-755b-461d-9ae5-c717ee4ba652`.
- Current live validation on `admin.gikundiro.com` includes 47 authenticated checks covering:
  - dashboard/session bootstrap
  - feature disable/enable and audit logging
  - content-block create/delete and audit logging
  - notification scheduling plus disabled-feature rejection
  - wallet adjustments plus disabled-feature rejection
  - shop create/delete
  - community chapter and contribution-circle create/delete
  - CMS content create/delete
  - ticket validate/mark-used
  - membership application approve plus supporter membership materialization
  - access control boundaries and authenticated admin API reads
- The membership applications loader now falls back from `profiles` to `users` for applicant identity so live admin review does not silently lose applicant name/phone when profile hydration is incomplete.
- Use focused backend and client regression checks after guard changes:
  - `deno test supabase/functions/admin-send-notification/index_test.ts ...`
  - `flutter test packages/core/core_network/test/safe_rpc_test.dart`
  - `flutter test packages/features/feat_contributions/test/contributions_module_test.dart`

## 15. Assumptions
These assumptions were used to keep the refactor additive.

- Existing auth and admin-role resolution remain the source of truth for who may manage configuration.
- Existing business modules remain valid and should be gated rather than rewritten.
- Existing club-level configuration still provides bootstrap context, but platform feature exposure now comes from the registry and RPCs.
- The product will continue to evolve toward more content-block-managed homepage composition over time instead of converting every page to CMS in one pass.

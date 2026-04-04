/**
 * Types barrel re-export.
 *
 * Decomposed from the 334-line monolithic types.ts:
 *   ✅ site.ts  — public-facing types (club, match, news, shop, etc.)
 *   ✅ fan.ts   — authenticated fan types (profile, membership, orders)
 *   ✅ admin.ts — admin panel types (RBAC, dashboard, CRUD interfaces)
 */
export type * from "./site";
export type * from "./fan";
export type * from "./admin";

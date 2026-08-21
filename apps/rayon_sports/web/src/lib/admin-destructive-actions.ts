import type { AdminAccess } from "@/lib/types";

export type AdminDestructivePermission =
  | "club_admin"
  | "platform_admin";
export type AdminDestructiveReviewMode =
  | "structured_confirm"
  | "review_drawer";
export type AdminDestructiveUndoDisposition =
  | "manual_recovery"
  | "not_available";
export type AdminDestructiveAuditMode =
  | "atomic_delete_rpc"
  | "transactional_domain_rpc";

export interface AdminDestructiveActionContract {
  id: string;
  label: string;
  routeResource: string | null;
  source: string;
  permission: AdminDestructivePermission;
  scope: "active_club" | "platform" | "record_and_active_club";
  selection: "single_record" | "reviewed_bulk";
  selectionLimit: number;
  review: AdminDestructiveReviewMode;
  undo: AdminDestructiveUndoDisposition;
  audit: AdminDestructiveAuditMode;
  concurrency: "loaded_version" | "domain_state_and_version";
}

const clubDelete = (
  id: string,
  label: string,
  routeResource: string,
  source: string,
): AdminDestructiveActionContract => ({
  id,
  label,
  routeResource,
  source,
  permission: "club_admin",
  scope: "active_club",
  selection: "single_record",
  selectionLimit: 1,
  review: "structured_confirm",
  undo: "not_available",
  audit: "atomic_delete_rpc",
  concurrency: "loaded_version",
});

export const adminDestructiveActions: readonly AdminDestructiveActionContract[] =
  [
    clubDelete("delete-match", "Delete match", "matches", "admin_matches"),
    clubDelete("delete-article", "Delete article", "cms", "admin_cms"),
    clubDelete(
      "delete-app-config",
      "Delete app configuration",
      "cms-config",
      "admin_cms_config",
    ),
    clubDelete(
      "delete-cms-content",
      "Delete CMS content",
      "cms-content",
      "admin_cms_content",
    ),
    clubDelete(
      "delete-membership-tier",
      "Delete membership tier",
      "membership",
      "admin_membership",
    ),
    clubDelete(
      "delete-shop-product",
      "Delete shop product",
      "shop",
      "admin_shop",
    ),
    clubDelete(
      "delete-supporter-chapter",
      "Delete supporter chapter",
      "fan-clubs",
      "admin_community",
    ),
    clubDelete(
      "delete-standing",
      "Delete standing",
      "standings",
      "admin_standings",
    ),
    clubDelete(
      "delete-contribution-group",
      "Delete contribution group",
      "contributions",
      "admin_contributions",
    ),
    clubDelete(
      "delete-squad-player",
      "Delete squad player",
      "squad",
      "admin_squad",
    ),
    clubDelete(
      "delete-fet-catalog-entry",
      "Delete FET catalog entry",
      "gamification",
      "admin_gamification",
    ),
    clubDelete(
      "delete-livescore-source",
      "Delete LiveScore source",
      "livescore-sources",
      "admin_football_sync",
    ),
    clubDelete(
      "delete-runtime-route",
      "Delete runtime route",
      "runtime-routes",
      "admin_runtime_registries",
    ),
    clubDelete(
      "delete-runtime-option-set",
      "Delete runtime option set",
      "runtime-option-sets",
      "admin_runtime_registries",
    ),
    clubDelete(
      "delete-runtime-option-value",
      "Delete runtime option value",
      "runtime-option-values",
      "admin_runtime_registries",
    ),
    clubDelete(
      "delete-runtime-copy",
      "Delete runtime copy",
      "runtime-copy",
      "admin_runtime_registries",
    ),
    clubDelete(
      "delete-runtime-navigation",
      "Delete runtime navigation",
      "runtime-navigation",
      "admin_runtime_registries",
    ),
    clubDelete(
      "delete-runtime-search",
      "Delete runtime search",
      "runtime-search",
      "admin_runtime_registries",
    ),
    clubDelete(
      "delete-runtime-venue-control",
      "Delete runtime venue control",
      "runtime-venue-controls",
      "admin_runtime_registries",
    ),
    clubDelete(
      "delete-platform-content-block",
      "Delete platform content block",
      "content-blocks",
      "admin_platform_content_blocks",
    ),
    {
      id: "delete-partner-offer",
      label: "Delete partner offer",
      routeResource: "offers",
      source: "admin_offers",
      permission: "platform_admin",
      scope: "platform",
      selection: "single_record",
      selectionLimit: 1,
      review: "structured_confirm",
      undo: "not_available",
      audit: "atomic_delete_rpc",
      concurrency: "loaded_version",
    },
    {
      id: "revoke-admin-role",
      label: "Revoke admin role",
      routeResource: "access",
      source: "admin_access",
      permission: "platform_admin",
      scope: "platform",
      selection: "single_record",
      selectionLimit: 1,
      review: "structured_confirm",
      undo: "manual_recovery",
      audit: "transactional_domain_rpc",
      concurrency: "domain_state_and_version",
    },
    {
      id: "reject-sms-review",
      label: "Reject manual SMS review",
      routeResource: null,
      source: "admin_sms_monitor",
      permission: "platform_admin",
      scope: "record_and_active_club",
      selection: "single_record",
      selectionLimit: 1,
      review: "structured_confirm",
      undo: "manual_recovery",
      audit: "transactional_domain_rpc",
      concurrency: "domain_state_and_version",
    },
    {
      id: "deduct-wallet",
      label: "Deduct supporter wallet",
      routeResource: null,
      source: "admin_gamification_wallet",
      permission: "club_admin",
      scope: "record_and_active_club",
      selection: "single_record",
      selectionLimit: 1,
      review: "structured_confirm",
      undo: "manual_recovery",
      audit: "transactional_domain_rpc",
      concurrency: "domain_state_and_version",
    },
    {
      id: "bulk-cancel-tickets",
      label: "Bulk cancel tickets",
      routeResource: null,
      source: "admin_tickets",
      permission: "club_admin",
      scope: "active_club",
      selection: "reviewed_bulk",
      selectionLimit: 100,
      review: "review_drawer",
      undo: "not_available",
      audit: "transactional_domain_rpc",
      concurrency: "domain_state_and_version",
    },
  ];

export function getAdminDestructiveActionContract(id: string) {
  return adminDestructiveActions.find((action) => action.id === id) ?? null;
}

export function getAdminDestructiveRouteContract(resource: string) {
  return (
    adminDestructiveActions.find(
      (action) => action.routeResource === resource,
    ) ?? null
  );
}

export function getAdminDestructivePermission(
  access: Pick<
    AdminAccess,
    "hasAccess" | "isSuperAdmin" | "role" | "clubId"
  >,
  contract: Pick<AdminDestructiveActionContract, "permission">,
) {
  if (!access.hasAccess) {
    return { allowed: false, reason: "Admin access is required." };
  }

  const isPlatformAdmin =
    access.isSuperAdmin ||
    access.role === "super_admin" ||
    access.role === "admin";
  if (isPlatformAdmin) {
    return { allowed: true, reason: null };
  }

  if (contract.permission === "platform_admin") {
    return {
      allowed: false,
      reason: "Platform admin access is required.",
    };
  }

  if (access.role !== "club_admin") {
    return {
      allowed: false,
      reason: "Club-admin access is required.",
    };
  }

  if (access.clubId == null || access.clubId.trim().length === 0) {
    return {
      allowed: false,
      reason: "An active club scope is required.",
    };
  }

  return { allowed: true, reason: null };
}

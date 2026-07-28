import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, PlatformFeature } from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  AdminMutationConflictError,
  adminClubIdOrNull,
  requireExpectedUpdatedAt,
  safeString,
} from "./helpers";

type FeatureChannelInput = {
  channel: "mobile" | "web";
  isEnabled?: boolean;
  isVisible?: boolean;
  showInNavigation?: boolean;
  showOnHome?: boolean;
  sortOrder?: number | null;
  routeKey?: string | null;
  placementKey?: string | null;
};

type FeatureRulesInput = {
  authRequired?: boolean;
  roleRestrictions?: string[];
  dependencyRules?: Record<string, unknown>;
  rolloutRules?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
  scheduleStartAt?: string | null;
  scheduleEndAt?: string | null;
};

type FeatureUpdateInput = Partial<{
  displayName: string;
  description: string | null;
  category: string | null;
  isEnabled: boolean;
  visibilityState: "visible" | "hidden" | "maintenance";
  channels: FeatureChannelInput[];
  rules: FeatureRulesInput;
}>;

type FeatureRow = {
  id: string;
  feature_key: string;
  display_name: string;
  description: string | null;
  category: string | null;
  club_id: number | null;
  is_enabled: boolean;
  visibility_state: "visible" | "hidden" | "maintenance";
  updated_at: string;
  channels?: Array<Record<string, unknown>> | null;
  rules?: Array<Record<string, unknown>> | Record<string, unknown> | null;
};

function normalizeFeatureRow(row: FeatureRow): PlatformFeature {
  const ruleRow = Array.isArray(row.rules) ? row.rules[0] : row.rules;

  return {
    id: row.id,
    clubId: row.club_id,
    scope: row.club_id == null ? "global" : "club",
    featureKey: row.feature_key,
    displayName: row.display_name,
    description: row.description,
    category: row.category,
    isEnabled: row.is_enabled,
    visibilityState: row.visibility_state,
    updatedAt: safeString(row.updated_at),
    channels: (row.channels ?? [])
      .map((entry) => ({
        id: safeString(entry.id) || null,
        channel: (entry.channel === "web" ? "web" : "mobile") as "web" | "mobile",
        isEnabled: entry.is_enabled === true,
        isVisible: entry.is_visible !== false,
        showInNavigation: entry.show_in_navigation === true,
        showOnHome: entry.show_on_home === true,
        sortOrder:
          typeof entry.sort_order === "number" ? entry.sort_order : null,
        routeKey: safeString(entry.route_key) || null,
        placementKey: safeString(entry.placement_key) || null,
      }))
      .sort((left, right) => left.channel.localeCompare(right.channel)),
    rules: ruleRow == null
      ? null
      : {
          authRequired: ruleRow.auth_required === true,
          roleRestrictions: Array.isArray(ruleRow.role_restrictions)
            ? ruleRow.role_restrictions.filter(
                (value): value is string => typeof value === "string",
              )
            : [],
          dependencyRules:
            typeof ruleRow.dependency_rules === "object" &&
                ruleRow.dependency_rules != null &&
                !Array.isArray(ruleRow.dependency_rules)
            ? (ruleRow.dependency_rules as Record<string, unknown>)
            : {},
          rolloutRules:
            typeof ruleRow.rollout_rules === "object" &&
                ruleRow.rollout_rules != null &&
                !Array.isArray(ruleRow.rollout_rules)
            ? (ruleRow.rollout_rules as Record<string, unknown>)
            : {},
          metadata:
            typeof ruleRow.metadata === "object" &&
                ruleRow.metadata != null &&
                !Array.isArray(ruleRow.metadata)
            ? (ruleRow.metadata as Record<string, unknown>)
            : {},
          scheduleStartAt: safeString(ruleRow.schedule_start_at) || null,
          scheduleEndAt: safeString(ruleRow.schedule_end_at) || null,
        },
  };
}

function resolveScopedRows(rows: FeatureRow[], clubId: number | null) {
  const grouped = new Map<string, FeatureRow[]>();

  for (const row of rows) {
    const bucket = grouped.get(row.feature_key) ?? [];
    bucket.push(row);
    grouped.set(row.feature_key, bucket);
  }

  return [...grouped.values()]
    .map((variants) => {
      if (clubId == null) {
        return (
          variants.find((entry) => entry.club_id == null) ??
          variants[0]
        );
      }

      return (
        variants.find((entry) => entry.club_id === clubId) ??
        variants.find((entry) => entry.club_id == null) ??
        variants[0]
      );
    })
    .sort((left, right) => {
      const categoryCompare = (left.category ?? "").localeCompare(right.category ?? "");
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      return left.feature_key.localeCompare(right.feature_key);
    });
}

async function listFeatureRows(
  client: SupabaseClient,
  clubId: number | null,
) {
  let query = client
    .from("platform_features")
    .select(`
      id,
      feature_key,
      display_name,
      description,
      category,
      club_id,
      is_enabled,
      visibility_state,
      updated_at,
      channels:platform_feature_channels (
        id,
        channel,
        is_enabled,
        is_visible,
        show_in_navigation,
        show_on_home,
        sort_order,
        route_key,
        placement_key
      ),
      rules:platform_feature_rules (
        auth_required,
        role_restrictions,
        dependency_rules,
        rollout_rules,
        metadata,
        schedule_start_at,
        schedule_end_at
      )
    `);

  query = clubId == null
    ? query.is("club_id", null)
    : query.or(`club_id.is.null,club_id.eq.${clubId}`);

  const { data, error } = await query.order("feature_key");

  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data) ? (data as FeatureRow[]) : [];
}

export async function getAdminFeatures(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<PlatformFeature[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<PlatformFeature[]>("features");
  }

  const scopedClubId = adminClubIdOrNull(access);
  const rows = await listFeatureRows(client, scopedClubId);
  return resolveScopedRows(rows, scopedClubId).map(normalizeFeatureRow);
}

export async function updateAdminFeature(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
  updates: FeatureUpdateInput,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("features/update", {
      method: "POST",
      body: { id, expectedUpdatedAt, updates },
    });
  }

  const loadedVersion = requireExpectedUpdatedAt(expectedUpdatedAt);
  const { error } = await client.rpc(
    "admin_update_platform_feature_if_unchanged",
    {
      p_feature_id: id,
      p_expected_updated_at: loadedVersion,
      p_club_id: adminClubIdOrNull(access),
      p_updates: updates,
      p_actor_id: access.userId ?? null,
    },
  );

  if (error) {
    const message = error.message.toLowerCase();
    if (
      message.includes("changed after it was loaded") ||
      message.includes("scoped override was created")
    ) {
      throw new AdminMutationConflictError(error.message);
    }
    throw new Error(error.message);
  }
}

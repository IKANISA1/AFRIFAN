import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, PlatformFeature } from "@/lib/types";
import { requestAdminApi } from "./http";
import { adminClubIdOrNull, safeString } from "./helpers";

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

async function getFeatureRowById(client: SupabaseClient, id: string) {
  const { data, error } = await client
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
        id,
        auth_required,
        role_restrictions,
        dependency_rules,
        rollout_rules,
        metadata,
        schedule_start_at,
        schedule_end_at
      )
    `)
    .eq("id", id)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as FeatureRow;
}

async function ensureScopedFeatureTarget(
  client: SupabaseClient,
  access: AdminAccess,
  source: FeatureRow,
) {
  const scopedClubId = adminClubIdOrNull(access);
  if (scopedClubId == null || source.club_id === scopedClubId) {
    return source.id;
  }

  const { data: existing, error: existingError } = await client
    .from("platform_features")
    .select("id")
    .eq("feature_key", source.feature_key)
    .eq("club_id", scopedClubId)
    .maybeSingle();

  if (existingError) {
    throw new Error(existingError.message);
  }

  if (existing?.id) {
    return safeString(existing.id);
  }

  const { data: inserted, error: insertError } = await client
    .from("platform_features")
    .insert({
      feature_key: source.feature_key,
      display_name: source.display_name,
      description: source.description,
      category: source.category,
      club_id: scopedClubId,
      is_enabled: source.is_enabled,
      visibility_state: source.visibility_state,
    })
    .select("id")
    .single();

  if (insertError) {
    throw new Error(insertError.message);
  }

  const targetId = safeString(inserted.id);
  if (!targetId) {
    throw new Error("Could not create scoped feature override.");
  }

  const sourceChannels = Array.isArray(source.channels) ? source.channels : [];
  if (sourceChannels.length > 0) {
    const { error } = await client.from("platform_feature_channels").insert(
      sourceChannels.map((channel) => ({
        feature_id: targetId,
        channel: channel.channel,
        is_enabled: channel.is_enabled,
        is_visible: channel.is_visible,
        show_in_navigation: channel.show_in_navigation,
        show_on_home: channel.show_on_home,
        sort_order: channel.sort_order,
        route_key: channel.route_key,
        placement_key: channel.placement_key,
      })),
    );
    if (error) {
      throw new Error(error.message);
    }
  }

  const sourceRule = Array.isArray(source.rules) ? source.rules[0] : source.rules;
  if (sourceRule != null) {
    const { error } = await client.from("platform_feature_rules").insert({
      feature_id: targetId,
      auth_required: sourceRule.auth_required === true,
      role_restrictions: sourceRule.role_restrictions ?? [],
      dependency_rules: sourceRule.dependency_rules ?? {},
      rollout_rules: sourceRule.rollout_rules ?? {},
      metadata: sourceRule.metadata ?? {},
      schedule_start_at: sourceRule.schedule_start_at ?? null,
      schedule_end_at: sourceRule.schedule_end_at ?? null,
    });
    if (error) {
      throw new Error(error.message);
    }
  }

  return targetId;
}

async function loadChannelsByFeatureId(client: SupabaseClient, featureId: string) {
  const { data, error } = await client
    .from("platform_feature_channels")
    .select("id, channel")
    .eq("feature_id", featureId);

  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data)
    ? (data as Array<{ id: string; channel: "mobile" | "web" }>)
    : [];
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
  updates: FeatureUpdateInput,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("features/update", {
      method: "POST",
      body: { id, updates },
    });
  }

  const source = await getFeatureRowById(client, id);
  const targetId = await ensureScopedFeatureTarget(client, access, source);

  const featurePayload: Record<string, unknown> = {};
  if (updates.displayName !== undefined) {
    featurePayload.display_name = updates.displayName.trim();
  }
  if (updates.description !== undefined) {
    featurePayload.description = updates.description;
  }
  if (updates.category !== undefined) {
    featurePayload.category = updates.category;
  }
  if (updates.isEnabled !== undefined) {
    featurePayload.is_enabled = updates.isEnabled;
  }
  if (updates.visibilityState !== undefined) {
    featurePayload.visibility_state = updates.visibilityState;
  }

  if (Object.keys(featurePayload).length > 0) {
    const { error } = await client
      .from("platform_features")
      .update(featurePayload)
      .eq("id", targetId);
    if (error) {
      throw new Error(error.message);
    }
  }

  if ((updates.channels?.length ?? 0) > 0) {
    const existingChannels = await loadChannelsByFeatureId(client, targetId);
    for (const channel of updates.channels ?? []) {
      const current = existingChannels.find(
        (entry) => entry.channel === channel.channel,
      ) ?? { id: "", channel: channel.channel };
      const payload = {
        feature_id: targetId,
        channel: channel.channel,
        is_enabled: channel.isEnabled ?? true,
        is_visible: channel.isVisible ?? true,
        show_in_navigation: channel.showInNavigation ?? false,
        show_on_home: channel.showOnHome ?? false,
        sort_order: channel.sortOrder ?? null,
        route_key:
          channel.routeKey?.trim().length === 0 ? null : channel.routeKey ?? null,
        placement_key:
          channel.placementKey?.trim().length === 0
            ? null
            : channel.placementKey ?? null,
      };

      if (safeString(current.id).length > 0) {
        const { error } = await client
          .from("platform_feature_channels")
          .update(payload)
          .eq("id", current.id);
        if (error) {
          throw new Error(error.message);
        }
      } else {
        const { error } = await client
          .from("platform_feature_channels")
          .insert(payload);
        if (error) {
          throw new Error(error.message);
        }
      }
    }
  }

  if (updates.rules != null) {
    const { data: currentRule, error: ruleLookupError } = await client
      .from("platform_feature_rules")
      .select("id")
      .eq("feature_id", targetId)
      .maybeSingle();

    if (ruleLookupError) {
      throw new Error(ruleLookupError.message);
    }

    const payload = {
      feature_id: targetId,
      auth_required: updates.rules.authRequired ?? false,
      role_restrictions: updates.rules.roleRestrictions ?? [],
      dependency_rules: updates.rules.dependencyRules ?? {},
      rollout_rules: updates.rules.rolloutRules ?? {},
      metadata: updates.rules.metadata ?? {},
      schedule_start_at: updates.rules.scheduleStartAt ?? null,
      schedule_end_at: updates.rules.scheduleEndAt ?? null,
    };

    if (currentRule?.id) {
      const { error } = await client
        .from("platform_feature_rules")
        .update(payload)
        .eq("id", currentRule.id);
      if (error) {
        throw new Error(error.message);
      }
    } else {
      const { error } = await client
        .from("platform_feature_rules")
        .insert(payload);
      if (error) {
        throw new Error(error.message);
      }
    }
  }
}

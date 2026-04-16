import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, PlatformFeature } from "@/lib/types";
import { requestAdminApi } from "./http";

export async function getAdminFeatures(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<PlatformFeature[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<PlatformFeature[]>("features");
  }

  const { data, error } = await client
    .from("platform_features")
    .select(`
      id,
      feature_key,
      display_name,
      description,
      category,
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
        rollout_rules
      )
    `)
    .order("category")
    .order("feature_key");

  if (error) throw new Error(error.message);

  return (data ?? []).map((row: any) => ({
    id: row.id,
    featureKey: row.feature_key,
    displayName: row.display_name,
    description: row.description,
    category: row.category,
    isEnabled: row.is_enabled,
    visibilityState: row.visibility_state,
    channels: (row.channels ?? []).map((c: any) => ({
      id: c.id,
      channel: c.channel,
      isEnabled: c.is_enabled,
      isVisible: c.is_visible,
      showInNavigation: c.show_in_navigation,
      showOnHome: c.show_on_home,
      sortOrder: c.sort_order,
      routeKey: c.route_key,
      placementKey: c.placement_key,
    })),
    rules: row.rules?.length > 0 ? {
      authRequired: row.rules[0].auth_required,
      roleRestrictions: row.rules[0].role_restrictions ?? [],
      dependencyRules: row.rules[0].dependency_rules ?? {},
      rolloutRules: row.rules[0].rollout_rules ?? {},
    } : null,
  }));
}

export async function updateAdminFeature(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  updates: Partial<{
    isEnabled: boolean;
    visibilityState: "visible" | "hidden" | "disabled";
    channels: any[];
  }>,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("features/update", {
      method: "POST",
      body: { id, updates },
    });
  }

  if (updates.isEnabled !== undefined || updates.visibilityState !== undefined) {
    const { error } = await client
      .from("platform_features")
      .update({
        is_enabled: updates.isEnabled,
        visibility_state: updates.visibilityState,
      })
      .eq("id", id);
    if (error) throw new Error(error.message);
  }

  if (updates.channels) {
    for (const channel of updates.channels) {
      const { error } = await client
        .from("platform_feature_channels")
        .update({
          is_enabled: channel.isEnabled,
          is_visible: channel.isVisible,
          show_in_navigation: channel.showInNavigation,
          show_on_home: channel.showOnHome,
          sort_order: channel.sortOrder,
        })
        .eq("id", channel.id);
      if (error) throw new Error(error.message);
    }
  }

  // Audit log
  await client.from("admin_audit_log").insert({
    user_id: access.userId,
    action: "update_feature",
    metadata: { feature_id: id, updates },
  });
}

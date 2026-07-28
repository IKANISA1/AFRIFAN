import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminPlatformOptionSet,
  AdminPlatformOptionValue,
  AdminPlatformRoute,
  AdminRuntimeCopyEntry,
  AdminRuntimeRegistryRecord,
  AdminRuntimeRegistrySnapshot,
  AdminSiteNavigationItem,
  AdminSiteSearchItem,
  AdminVenueGovernanceControl,
  RuntimeRegistryScope,
  RuntimeRegistrySurface,
} from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
  safeNumber,
  safeString,
} from "./helpers";

const _scopedRuntimeTables = [
  "platform_route_registry",
  "platform_option_sets",
  "runtime_copy",
  "site_navigation_items",
  "site_search_items",
  "venue_governance_controls",
] as const;

type ScopedRuntimeTable = (typeof _scopedRuntimeTables)[number];

function toRecord(value: unknown): Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function toStringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.map((entry) => safeString(entry)).filter(Boolean)
    : [];
}

function toSurface(value: unknown, fallback: RuntimeRegistrySurface) {
  const surface = safeString(value, fallback) as RuntimeRegistrySurface;
  return surface;
}

function scopeFromClubId(clubId: number | null): RuntimeRegistryScope {
  return clubId == null ? "global" : "club";
}

function mapBaseRecord(row: Record<string, unknown>): AdminRuntimeRegistryRecord {
  const clubId = row.club_id == null ? null : safeNumber(row.club_id, Number.NaN);
  const normalizedClubId = Number.isFinite(clubId) ? clubId : null;

  return {
    id: safeString(row.id),
    clubId: normalizedClubId,
    scope: scopeFromClubId(normalizedClubId),
    isActive: Boolean(row.is_active),
    metadata: toRecord(row.metadata),
    createdAt: safeString(row.created_at) || null,
    updatedAt: safeString(row.updated_at) || null,
  };
}

function mapRoute(row: Record<string, unknown>): AdminPlatformRoute {
  return {
    ...mapBaseRecord(row),
    routeKey: safeString(row.route_key),
    pathPattern: safeString(row.path_pattern),
    surface: toSurface(row.surface, "mobile"),
    featureKey: safeString(row.feature_key),
    label: safeString(row.label) || null,
    authRequired: Boolean(row.auth_required),
    requiredRoles: toStringArray(row.required_roles),
    presentation: safeString(row.presentation, "screen"),
    showInNavigation: Boolean(row.show_in_navigation),
    showOnHome: Boolean(row.show_on_home),
    sortOrder: safeNumber(row.sort_order, 0),
  };
}

function mapOptionSet(row: Record<string, unknown>): AdminPlatformOptionSet {
  const valueType = safeString(row.value_type, "text") as AdminPlatformOptionSet["valueType"];

  return {
    ...mapBaseRecord(row),
    optionSetKey: safeString(row.option_set_key),
    label: safeString(row.label),
    description: safeString(row.description) || null,
    valueType,
    surface: toSurface(row.surface, "both"),
  };
}

function mapOptionValue(row: Record<string, unknown>): AdminPlatformOptionValue {
  return {
    id: safeString(row.id),
    optionSetId: safeString(row.option_set_id),
    optionKey: safeString(row.option_key),
    label: safeString(row.label),
    value: row.value ?? null,
    sortOrder: safeNumber(row.sort_order, 0),
    isDefault: Boolean(row.is_default),
    isActive: Boolean(row.is_active),
    metadata: toRecord(row.metadata),
    createdAt: safeString(row.created_at) || null,
    updatedAt: safeString(row.updated_at) || null,
  };
}

function mapRuntimeCopy(row: Record<string, unknown>): AdminRuntimeCopyEntry {
  return {
    ...mapBaseRecord(row),
    copyKey: safeString(row.copy_key),
    surface: toSurface(row.surface, "both"),
    locale: safeString(row.locale, "en"),
    textValue: safeString(row.text_value),
    description: safeString(row.description) || null,
  };
}

function mapNavigation(row: Record<string, unknown>): AdminSiteNavigationItem {
  return {
    ...mapBaseRecord(row),
    navKey: safeString(row.nav_key),
    label: safeString(row.label),
    href: safeString(row.href),
    navGroup: safeString(row.nav_group, "primary"),
    surface: toSurface(row.surface, "web"),
    featureKey: safeString(row.feature_key) || null,
    sortOrder: safeNumber(row.sort_order, 0),
  };
}

function mapSearch(row: Record<string, unknown>): AdminSiteSearchItem {
  return {
    ...mapBaseRecord(row),
    searchKey: safeString(row.search_key),
    title: safeString(row.title),
    description: safeString(row.description),
    href: safeString(row.href),
    category: safeString(row.category, "Page"),
    metaLabel: safeString(row.meta_label) || null,
    surface: toSurface(row.surface, "web"),
    featureKey: safeString(row.feature_key) || null,
    sortOrder: safeNumber(row.sort_order, 0),
  };
}

function mapVenueControl(
  row: Record<string, unknown>,
): AdminVenueGovernanceControl {
  return {
    ...mapBaseRecord(row),
    controlKey: safeString(row.control_key),
    label: safeString(row.label),
    detail: safeString(row.detail),
    statusLabel: safeString(row.status_label, "review_required"),
    actionLabel: safeString(row.action_label) || null,
    controlGroup: safeString(row.control_group, "general"),
    venueId: safeString(row.venue_id) || null,
    sortOrder: safeNumber(row.sort_order, 0),
  };
}

async function readScopedRows(
  client: SupabaseClient,
  access: AdminAccess,
  table: ScopedRuntimeTable,
  orderColumn: string,
) {
  let query = client
    .from(table)
    .select("*")
    .order(orderColumn, { ascending: true });

  if (!access.isSuperAdmin) {
    const clubId = requireAdminClubId(access, `load ${table}`);
    query = query.or(`club_id.is.null,club_id.eq.${clubId}`);
  }

  const { data, error } = await query;
  if (error) {
    throw new Error(error.message);
  }
  return (data ?? []) as Record<string, unknown>[];
}

async function readOptionValues(
  client: SupabaseClient,
  optionSetIds: string[],
) {
  if (optionSetIds.length === 0) {
    return [];
  }

  const { data, error } = await client
    .from("platform_option_values")
    .select("*")
    .in("option_set_id", optionSetIds)
    .order("sort_order", { ascending: true })
    .order("label", { ascending: true });

  if (error) {
    throw new Error(error.message);
  }
  return (data ?? []) as Record<string, unknown>[];
}

export async function getAdminRuntimeRegistrySnapshot(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminRuntimeRegistrySnapshot> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminRuntimeRegistrySnapshot>("runtime-registry");
  }

  const [
    routeRows,
    optionSetRows,
    copyRows,
    navigationRows,
    searchRows,
    venueControlRows,
  ] = await Promise.all([
    readScopedRows(client, access, "platform_route_registry", "sort_order"),
    readScopedRows(client, access, "platform_option_sets", "option_set_key"),
    readScopedRows(client, access, "runtime_copy", "copy_key"),
    readScopedRows(client, access, "site_navigation_items", "sort_order"),
    readScopedRows(client, access, "site_search_items", "sort_order"),
    readScopedRows(client, access, "venue_governance_controls", "sort_order"),
  ]);
  const optionValues = await readOptionValues(
    client,
    optionSetRows.map((row) => safeString(row.id)).filter(Boolean),
  );

  return {
    routes: routeRows.map(mapRoute),
    optionSets: optionSetRows.map(mapOptionSet),
    optionValues: optionValues.map(mapOptionValue),
    runtimeCopy: copyRows.map(mapRuntimeCopy),
    navigation: navigationRows.map(mapNavigation),
    search: searchRows.map(mapSearch),
    venueControls: venueControlRows.map(mapVenueControl),
  };
}

function resolveWriteClubId(
  access: AdminAccess,
  input: { scope?: RuntimeRegistryScope; clubId?: number | string | null },
  action: string,
) {
  if (input.scope === "global") {
    if (!access.isSuperAdmin) {
      throw new Error("Platform admin access is required for global registry rows.");
    }
    return null;
  }

  if (access.isSuperAdmin && input.clubId == null) {
    return null;
  }

  if (access.isSuperAdmin && input.clubId != null) {
    const clubId = safeNumber(input.clubId, Number.NaN);
    return Number.isFinite(clubId) ? clubId : null;
  }

  return requireAdminClubId(access, action);
}

function scopedMatchers(access: AdminAccess, action: string) {
  return access.isSuperAdmin
    ? {}
    : { club_id: requireAdminClubId(access, action) };
}

async function saveScopedRecord(
  client: SupabaseClient,
  access: AdminAccess,
  table: ScopedRuntimeTable,
  input: Record<string, unknown>,
  payload: Record<string, unknown>,
  action: string,
) {
  const id = safeString(input.id) || null;
  const clubId = resolveWriteClubId(
    access,
    {
      scope: safeString(input.scope) as RuntimeRegistryScope,
      clubId: input.clubId as string | number | null | undefined,
    },
    action,
  );

  return mutateRecordWithVariantsIfUnchanged(
    client,
    table,
    id,
    safeString(input.expectedUpdatedAt) || null,
    [{ ...payload, club_id: clubId }],
    scopedMatchers(access, action),
  );
}

async function deleteScopedRecord(
  client: SupabaseClient,
  access: AdminAccess,
  table: ScopedRuntimeTable,
  id: string,
  expectedUpdatedAt: string,
  action: string,
) {
  const matchers = scopedMatchers(access, action);
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    table,
    id,
    expectedUpdatedAt,
    matchers,
    {
      actorId: access.userId,
      clubId: access.clubId,
      action: action.replaceAll(" ", "_"),
      source: "admin_runtime_registries",
    },
  );
}

function required(value: unknown, label: string) {
  const text = safeString(value);
  if (!text) {
    throw new Error(`${label} is required.`);
  }
  return text;
}

export async function saveAdminPlatformRoute(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminPlatformRoute>,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-routes", {
      method: "POST",
      body: input,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "platform_route_registry",
    input as Record<string, unknown>,
    {
      route_key: required(input.routeKey, "Route key"),
      path_pattern: required(input.pathPattern, "Path pattern"),
      surface: safeString(input.surface, "mobile"),
      feature_key: required(input.featureKey, "Feature key"),
      label: safeString(input.label) || null,
      auth_required: Boolean(input.authRequired),
      required_roles: Array.isArray(input.requiredRoles) ? input.requiredRoles : [],
      presentation: safeString(input.presentation, "screen"),
      show_in_navigation: Boolean(input.showInNavigation),
      show_on_home: Boolean(input.showOnHome),
      sort_order: safeNumber(input.sortOrder, 0),
      is_active: input.isActive !== false,
      metadata: toRecord(input.metadata),
    },
    "save runtime route",
  );
}

export async function deleteAdminPlatformRoute(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<{ success: true }>("runtime-routes", {
      method: "DELETE",
      query: { id, expected_updated_at: expectedUpdatedAt },
    });
  }
  await deleteScopedRecord(client, access, "platform_route_registry", id, expectedUpdatedAt, "delete runtime route");
}

export async function saveAdminPlatformOptionSet(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminPlatformOptionSet>,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-option-sets", {
      method: "POST",
      body: input,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "platform_option_sets",
    input as Record<string, unknown>,
    {
      option_set_key: required(input.optionSetKey, "Option set key"),
      label: required(input.label, "Option set label"),
      description: safeString(input.description) || null,
      value_type: safeString(input.valueType, "text"),
      surface: safeString(input.surface, "both"),
      is_active: input.isActive !== false,
      metadata: toRecord(input.metadata),
    },
    "save option set",
  );
}

export async function deleteAdminPlatformOptionSet(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<{ success: true }>("runtime-option-sets", {
      method: "DELETE",
      query: { id, expected_updated_at: expectedUpdatedAt },
    });
  }
  await deleteScopedRecord(client, access, "platform_option_sets", id, expectedUpdatedAt, "delete option set");
}

async function ensureOptionSetWriteAccess(
  client: SupabaseClient,
  access: AdminAccess,
  optionSetId: string,
) {
  const { data, error } = await client
    .from("platform_option_sets")
    .select("id, club_id")
    .eq("id", optionSetId)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }
  if (!data) {
    throw new Error("Option set does not exist.");
  }
  if (access.isSuperAdmin) {
    return;
  }

  const clubId = requireAdminClubId(access, "manage option values");
  if (safeNumber((data as Record<string, unknown>).club_id, Number.NaN) !== clubId) {
    throw new Error("Option values can only be changed for the active club.");
  }
}

export async function saveAdminPlatformOptionValue(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminPlatformOptionValue>,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-option-values", {
      method: "POST",
      body: input,
    });
  }

  const optionSetId = required(input.optionSetId, "Option set");
  await ensureOptionSetWriteAccess(client, access, optionSetId);

  return mutateRecordWithVariantsIfUnchanged(
    client,
    "platform_option_values",
    safeString(input.id) || null,
    safeString(
      (input as unknown as Record<string, unknown>).expectedUpdatedAt,
    ) || null,
    [
      {
        option_set_id: optionSetId,
        option_key: required(input.optionKey, "Option key"),
        label: required(input.label, "Option label"),
        value: input.value ?? null,
        sort_order: safeNumber(input.sortOrder, 0),
        is_default: Boolean(input.isDefault),
        is_active: input.isActive !== false,
        metadata: toRecord(input.metadata),
      },
    ],
  );
}

export async function deleteAdminPlatformOptionValue(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<{ success: true }>("runtime-option-values", {
      method: "DELETE",
      query: { id, expected_updated_at: expectedUpdatedAt },
    });
  }

  const { data, error } = await client
    .from("platform_option_values")
    .select("option_set_id")
    .eq("id", id)
    .maybeSingle();
  if (error) {
    throw new Error(error.message);
  }
  const optionSetId = safeString((data as Record<string, unknown> | null)?.option_set_id);
  await ensureOptionSetWriteAccess(client, access, optionSetId);
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    "platform_option_values",
    id,
    expectedUpdatedAt,
    {},
    {
      actorId: access.userId,
      clubId: access.clubId,
      action: "delete_option_value",
      source: "admin_runtime_registries",
    },
  );
}

export async function saveAdminRuntimeCopyEntry(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminRuntimeCopyEntry>,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-copy", {
      method: "POST",
      body: input,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "runtime_copy",
    input as Record<string, unknown>,
    {
      copy_key: required(input.copyKey, "Copy key"),
      surface: safeString(input.surface, "both"),
      locale: safeString(input.locale, "en"),
      text_value: required(input.textValue, "Copy text"),
      description: safeString(input.description) || null,
      is_active: input.isActive !== false,
      metadata: toRecord(input.metadata),
    },
    "save runtime copy",
  );
}

export async function deleteAdminRuntimeCopyEntry(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<{ success: true }>("runtime-copy", {
      method: "DELETE",
      query: { id, expected_updated_at: expectedUpdatedAt },
    });
  }
  await deleteScopedRecord(client, access, "runtime_copy", id, expectedUpdatedAt, "delete runtime copy");
}

export async function saveAdminSiteNavigationItem(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminSiteNavigationItem>,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-navigation", {
      method: "POST",
      body: input,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "site_navigation_items",
    input as Record<string, unknown>,
    {
      nav_key: required(input.navKey, "Navigation key"),
      label: required(input.label, "Navigation label"),
      href: required(input.href, "Navigation href"),
      nav_group: safeString(input.navGroup, "primary"),
      surface: safeString(input.surface, "web"),
      feature_key: safeString(input.featureKey) || null,
      sort_order: safeNumber(input.sortOrder, 0),
      is_active: input.isActive !== false,
      metadata: toRecord(input.metadata),
    },
    "save navigation item",
  );
}

export async function deleteAdminSiteNavigationItem(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<{ success: true }>("runtime-navigation", {
      method: "DELETE",
      query: { id, expected_updated_at: expectedUpdatedAt },
    });
  }
  await deleteScopedRecord(client, access, "site_navigation_items", id, expectedUpdatedAt, "delete navigation item");
}

export async function saveAdminSiteSearchItem(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminSiteSearchItem>,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-search", {
      method: "POST",
      body: input,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "site_search_items",
    input as Record<string, unknown>,
    {
      search_key: required(input.searchKey, "Search key"),
      title: required(input.title, "Search title"),
      description: safeString(input.description),
      href: required(input.href, "Search href"),
      category: safeString(input.category, "Page"),
      meta_label: safeString(input.metaLabel) || null,
      surface: safeString(input.surface, "web"),
      feature_key: safeString(input.featureKey) || null,
      sort_order: safeNumber(input.sortOrder, 0),
      is_active: input.isActive !== false,
      metadata: toRecord(input.metadata),
    },
    "save search item",
  );
}

export async function deleteAdminSiteSearchItem(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<{ success: true }>("runtime-search", {
      method: "DELETE",
      query: { id, expected_updated_at: expectedUpdatedAt },
    });
  }
  await deleteScopedRecord(client, access, "site_search_items", id, expectedUpdatedAt, "delete search item");
}

export async function saveAdminVenueGovernanceControl(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminVenueGovernanceControl>,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-venue-controls", {
      method: "POST",
      body: input,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "venue_governance_controls",
    input as Record<string, unknown>,
    {
      control_key: required(input.controlKey, "Control key"),
      label: required(input.label, "Control label"),
      detail: safeString(input.detail),
      status_label: safeString(input.statusLabel, "review_required"),
      action_label: safeString(input.actionLabel) || null,
      control_group: safeString(input.controlGroup, "general"),
      venue_id: safeString(input.venueId) || null,
      sort_order: safeNumber(input.sortOrder, 0),
      is_active: input.isActive !== false,
      metadata: toRecord(input.metadata),
    },
    "save venue control",
  );
}

export async function deleteAdminVenueGovernanceControl(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<{ success: true }>("runtime-venue-controls", {
      method: "DELETE",
      query: { id, expected_updated_at: expectedUpdatedAt },
    });
  }
  await deleteScopedRecord(
    client,
    access,
    "venue_governance_controls",
    id,
    expectedUpdatedAt,
    "delete venue control",
  );
}

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
  adminClubIdOrNull,
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
  safeNumber,
  safeString,
} from "./helpers";

export const MAX_RUNTIME_RECORDS_PER_COLLECTION = 500;

const _scopedRuntimeTables = [
  "platform_route_registry",
  "platform_option_sets",
  "runtime_copy",
  "site_navigation_items",
  "site_search_items",
  "venue_governance_controls",
] as const;

type ScopedRuntimeTable = (typeof _scopedRuntimeTables)[number];

const scopedRuntimeProjections: Record<ScopedRuntimeTable, string> = {
  platform_route_registry: [
    "id",
    "club_id",
    "route_key",
    "path_pattern",
    "surface",
    "feature_key",
    "label",
    "auth_required",
    "required_roles",
    "presentation",
    "show_in_navigation",
    "show_on_home",
    "sort_order",
    "is_active",
    "metadata",
    "created_at",
    "updated_at",
  ].join(", "),
  platform_option_sets: [
    "id",
    "club_id",
    "option_set_key",
    "label",
    "description",
    "value_type",
    "surface",
    "is_active",
    "metadata",
    "created_at",
    "updated_at",
  ].join(", "),
  runtime_copy: [
    "id",
    "club_id",
    "copy_key",
    "surface",
    "locale",
    "text_value",
    "description",
    "is_active",
    "metadata",
    "created_at",
    "updated_at",
  ].join(", "),
  site_navigation_items: [
    "id",
    "club_id",
    "nav_key",
    "label",
    "href",
    "nav_group",
    "surface",
    "feature_key",
    "sort_order",
    "is_active",
    "metadata",
    "created_at",
    "updated_at",
  ].join(", "),
  site_search_items: [
    "id",
    "club_id",
    "search_key",
    "title",
    "description",
    "href",
    "category",
    "meta_label",
    "surface",
    "feature_key",
    "sort_order",
    "is_active",
    "metadata",
    "created_at",
    "updated_at",
  ].join(", "),
  venue_governance_controls: [
    "id",
    "club_id",
    "control_key",
    "label",
    "detail",
    "status_label",
    "action_label",
    "control_group",
    "venue_id",
    "sort_order",
    "is_active",
    "metadata",
    "created_at",
    "updated_at",
  ].join(", "),
};

const surfaceValues = new Set<RuntimeRegistrySurface>([
  "mobile",
  "web",
  "tv",
  "venue",
  "admin",
  "both",
]);
const valueTypeValues = new Set<AdminPlatformOptionSet["valueType"]>([
  "text",
  "number",
  "boolean",
  "json",
]);
const keyPattern = /^[a-z][a-z0-9_.:-]{0,127}$/;
const localePattern = /^[a-z]{2,3}(?:-[A-Z]{2})?$/;
const rolePattern = /^[a-z][a-z0-9_:-]{0,63}$/;
const sensitiveKeyPattern =
  /(?:^|_)(?:authorization|cookie|credential|password|secret|session|token)(?:_|$)/i;

export class AdminRuntimeRegistryValidationError extends Error {
  constructor(
    message = "Review the runtime registry record and correct invalid values.",
  ) {
    super(message);
    this.name = "AdminRuntimeRegistryValidationError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function nullableText(value: unknown, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedText(value, maxLength) ?? undefined;
}

function boundedIsoDate(value: unknown) {
  const text = boundedText(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function boundedInteger(value: unknown) {
  return typeof value === "number" &&
    Number.isSafeInteger(value) &&
    value >= -10_000 &&
    value <= 10_000
    ? value
    : null;
}

function sanitizeJsonValue(value: unknown, depth = 0): unknown | undefined {
  if (value == null || typeof value === "boolean") return value;
  if (typeof value === "string") {
    return value.length <= 2_048 ? value : undefined;
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : undefined;
  }
  if (depth >= 4) return undefined;
  if (Array.isArray(value)) {
    if (value.length > 50) return undefined;
    const output: unknown[] = [];
    for (const item of value) {
      const sanitized = sanitizeJsonValue(item, depth + 1);
      if (sanitized === undefined) return undefined;
      output.push(sanitized);
    }
    return output;
  }
  if (!isRecord(value)) return undefined;
  const entries = Object.entries(value);
  if (entries.length > 50) return undefined;
  const output: Record<string, unknown> = {};
  for (const [key, item] of entries) {
    if (
      !/^[A-Za-z][A-Za-z0-9_.:-]{0,63}$/.test(key) ||
      sensitiveKeyPattern.test(key)
    ) {
      return undefined;
    }
    const sanitized = sanitizeJsonValue(item, depth + 1);
    if (sanitized === undefined) return undefined;
    output[key] = sanitized;
  }
  return output;
}

function toRecord(value: unknown): Record<string, unknown> {
  if (value == null) return {};
  const sanitized = sanitizeJsonValue(value);
  if (!isRecord(sanitized)) {
    throw new AdminRuntimeRegistryValidationError(
      "Registry metadata must be a bounded object without sensitive keys.",
    );
  }
  return sanitized;
}

function toStringArray(value: unknown): string[] {
  if (
    !Array.isArray(value) ||
    value.length > 20 ||
    value.some((entry) => typeof entry !== "string" || !rolePattern.test(entry))
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime role restrictions were invalid.",
    );
  }
  return [...new Set(value as string[])];
}

function toSurface(value: unknown) {
  if (
    typeof value !== "string" ||
    !surfaceValues.has(value as RuntimeRegistrySurface)
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime surface was invalid.",
    );
  }
  return value as RuntimeRegistrySurface;
}

function scopeFromClubId(clubId: number | null): RuntimeRegistryScope {
  return clubId == null ? "global" : "club";
}

function mapBaseRecord(
  row: Record<string, unknown>,
): AdminRuntimeRegistryRecord {
  const id = boundedText(row.id, 128);
  const clubId =
    row.club_id == null
      ? null
      : typeof row.club_id === "number" &&
          Number.isSafeInteger(row.club_id) &&
          row.club_id > 0
        ? row.club_id
        : undefined;
  const createdAt =
    row.created_at == null ? null : boundedIsoDate(row.created_at);
  const updatedAt =
    row.updated_at == null ? null : boundedIsoDate(row.updated_at);
  if (
    id == null ||
    clubId === undefined ||
    typeof row.is_active !== "boolean" ||
    (row.created_at != null && createdAt == null) ||
    (row.updated_at != null && updatedAt == null)
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime registry response contained an invalid base record.",
    );
  }

  return {
    id,
    clubId,
    scope: scopeFromClubId(clubId),
    isActive: row.is_active,
    metadata: toRecord(row.metadata),
    createdAt,
    updatedAt,
  };
}

function mapRoute(row: Record<string, unknown>): AdminPlatformRoute {
  const routeKey = boundedText(row.route_key, 128);
  const pathPattern = boundedText(row.path_pattern, 256);
  const featureKey = boundedText(row.feature_key, 128);
  const label = nullableText(row.label, 120);
  const presentation = boundedText(row.presentation, 64);
  const sortOrder = boundedInteger(row.sort_order);
  if (
    routeKey == null ||
    !keyPattern.test(routeKey) ||
    pathPattern == null ||
    !pathPattern.startsWith("/") ||
    featureKey == null ||
    !keyPattern.test(featureKey) ||
    label === undefined ||
    presentation == null ||
    typeof row.auth_required !== "boolean" ||
    typeof row.show_in_navigation !== "boolean" ||
    typeof row.show_on_home !== "boolean" ||
    sortOrder == null
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime route response contained an invalid record.",
    );
  }
  return {
    ...mapBaseRecord(row),
    routeKey,
    pathPattern,
    surface: toSurface(row.surface),
    featureKey,
    label,
    authRequired: row.auth_required,
    requiredRoles: toStringArray(row.required_roles),
    presentation,
    showInNavigation: row.show_in_navigation,
    showOnHome: row.show_on_home,
    sortOrder,
  };
}

function mapOptionSet(row: Record<string, unknown>): AdminPlatformOptionSet {
  const optionSetKey = boundedText(row.option_set_key, 128);
  const label = boundedText(row.label, 120);
  const description = nullableText(row.description, 1_000);
  const valueType = row.value_type as AdminPlatformOptionSet["valueType"];
  if (
    optionSetKey == null ||
    !keyPattern.test(optionSetKey) ||
    label == null ||
    description === undefined ||
    !valueTypeValues.has(valueType)
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime option-set response contained an invalid record.",
    );
  }

  return {
    ...mapBaseRecord(row),
    optionSetKey,
    label,
    description,
    valueType,
    surface: toSurface(row.surface),
  };
}

function mapOptionValue(
  row: Record<string, unknown>,
): AdminPlatformOptionValue {
  const id = boundedText(row.id, 128);
  const optionSetId = boundedText(row.option_set_id, 128);
  const optionKey = boundedText(row.option_key, 128);
  const label = boundedText(row.label, 120);
  const sortOrder = boundedInteger(row.sort_order);
  const createdAt =
    row.created_at == null ? null : boundedIsoDate(row.created_at);
  const updatedAt =
    row.updated_at == null ? null : boundedIsoDate(row.updated_at);
  const optionValue = sanitizeJsonValue(row.value);
  if (
    id == null ||
    optionSetId == null ||
    optionKey == null ||
    !keyPattern.test(optionKey) ||
    label == null ||
    sortOrder == null ||
    typeof row.is_default !== "boolean" ||
    typeof row.is_active !== "boolean" ||
    optionValue === undefined ||
    (row.created_at != null && createdAt == null) ||
    (row.updated_at != null && updatedAt == null)
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime option-value response contained an invalid record.",
    );
  }
  return {
    id,
    optionSetId,
    optionKey,
    label,
    value: optionValue,
    sortOrder,
    isDefault: row.is_default,
    isActive: row.is_active,
    metadata: toRecord(row.metadata),
    createdAt,
    updatedAt,
  };
}

function mapRuntimeCopy(row: Record<string, unknown>): AdminRuntimeCopyEntry {
  const copyKey = boundedText(row.copy_key, 128);
  const locale = boundedText(row.locale, 16);
  const textValue = boundedText(row.text_value, 4_000);
  const description = nullableText(row.description, 1_000);
  if (
    copyKey == null ||
    !keyPattern.test(copyKey) ||
    locale == null ||
    !localePattern.test(locale) ||
    textValue == null ||
    description === undefined
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime copy response contained an invalid record.",
    );
  }
  return {
    ...mapBaseRecord(row),
    copyKey,
    surface: toSurface(row.surface),
    locale,
    textValue,
    description,
  };
}

function mapNavigation(row: Record<string, unknown>): AdminSiteNavigationItem {
  const navKey = boundedText(row.nav_key, 128);
  const label = boundedText(row.label, 120);
  const href = boundedText(row.href, 256);
  const navGroup = boundedText(row.nav_group, 64);
  const featureKey = nullableText(row.feature_key, 128);
  const sortOrder = boundedInteger(row.sort_order);
  if (
    navKey == null ||
    !keyPattern.test(navKey) ||
    label == null ||
    href == null ||
    !href.startsWith("/") ||
    navGroup == null ||
    featureKey === undefined ||
    (featureKey != null && !keyPattern.test(featureKey)) ||
    sortOrder == null
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime navigation response contained an invalid record.",
    );
  }
  return {
    ...mapBaseRecord(row),
    navKey,
    label,
    href,
    navGroup,
    surface: toSurface(row.surface),
    featureKey,
    sortOrder,
  };
}

function mapSearch(row: Record<string, unknown>): AdminSiteSearchItem {
  const searchKey = boundedText(row.search_key, 128);
  const title = boundedText(row.title, 160);
  const description = boundedText(row.description, 1_000);
  const href = boundedText(row.href, 256);
  const category = boundedText(row.category, 64);
  const metaLabel = nullableText(row.meta_label, 120);
  const featureKey = nullableText(row.feature_key, 128);
  const sortOrder = boundedInteger(row.sort_order);
  if (
    searchKey == null ||
    !keyPattern.test(searchKey) ||
    title == null ||
    description == null ||
    href == null ||
    !href.startsWith("/") ||
    category == null ||
    metaLabel === undefined ||
    featureKey === undefined ||
    (featureKey != null && !keyPattern.test(featureKey)) ||
    sortOrder == null
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime search response contained an invalid record.",
    );
  }
  return {
    ...mapBaseRecord(row),
    searchKey,
    title,
    description,
    href,
    category,
    metaLabel,
    surface: toSurface(row.surface),
    featureKey,
    sortOrder,
  };
}

function mapVenueControl(
  row: Record<string, unknown>,
): AdminVenueGovernanceControl {
  const controlKey = boundedText(row.control_key, 128);
  const label = boundedText(row.label, 160);
  const detail = boundedText(row.detail, 1_000);
  const statusLabel = boundedText(row.status_label, 64);
  const actionLabel = nullableText(row.action_label, 120);
  const controlGroup = boundedText(row.control_group, 64);
  const venueId = nullableText(row.venue_id, 128);
  const sortOrder = boundedInteger(row.sort_order);
  if (
    controlKey == null ||
    !keyPattern.test(controlKey) ||
    label == null ||
    detail == null ||
    statusLabel == null ||
    actionLabel === undefined ||
    controlGroup == null ||
    venueId === undefined ||
    sortOrder == null
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime venue-control response contained an invalid record.",
    );
  }
  return {
    ...mapBaseRecord(row),
    controlKey,
    label,
    detail,
    statusLabel,
    actionLabel,
    controlGroup,
    venueId,
    sortOrder,
  };
}

function camelBaseRow(value: Record<string, unknown>) {
  return {
    id: value.id,
    club_id: value.clubId,
    is_active: value.isActive,
    metadata: value.metadata,
    created_at: value.createdAt,
    updated_at: value.updatedAt,
  };
}

function normalizeCollection<T>(
  value: unknown,
  map: (row: Record<string, unknown>) => T,
  key: (record: T) => string,
  label: string,
) {
  if (
    !Array.isArray(value) ||
    value.length > MAX_RUNTIME_RECORDS_PER_COLLECTION
  ) {
    throw new AdminRuntimeRegistryValidationError(
      `${label} exceeded its safe limit or was not a list.`,
    );
  }
  const records = value.map((entry) => {
    if (!isRecord(entry)) {
      throw new AdminRuntimeRegistryValidationError(
        `${label} contained an invalid record.`,
      );
    }
    return map(entry);
  });
  const ids = records.map((record) =>
    boundedText((record as { id?: unknown }).id, 128),
  );
  if (
    ids.some((id) => id == null) ||
    new Set(ids).size !== records.length ||
    new Set(records.map(key)).size !== records.length
  ) {
    throw new AdminRuntimeRegistryValidationError(
      `${label} contained duplicate records.`,
    );
  }
  return records;
}

export function normalizeAdminRuntimeRegistrySnapshot(
  value: unknown,
): AdminRuntimeRegistrySnapshot {
  if (!isRecord(value)) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime registry response was invalid.",
    );
  }

  return {
    routes: normalizeCollection(
      value.routes,
      (entry) =>
        mapRoute({
          ...camelBaseRow(entry),
          route_key: entry.routeKey,
          path_pattern: entry.pathPattern,
          surface: entry.surface,
          feature_key: entry.featureKey,
          label: entry.label,
          auth_required: entry.authRequired,
          required_roles: entry.requiredRoles,
          presentation: entry.presentation,
          show_in_navigation: entry.showInNavigation,
          show_on_home: entry.showOnHome,
          sort_order: entry.sortOrder,
        }),
      (record) => record.routeKey,
      "Runtime routes",
    ),
    optionSets: normalizeCollection(
      value.optionSets,
      (entry) =>
        mapOptionSet({
          ...camelBaseRow(entry),
          option_set_key: entry.optionSetKey,
          label: entry.label,
          description: entry.description,
          value_type: entry.valueType,
          surface: entry.surface,
        }),
      (record) => record.optionSetKey,
      "Runtime option sets",
    ),
    optionValues: normalizeCollection(
      value.optionValues,
      (entry) =>
        mapOptionValue({
          id: entry.id,
          option_set_id: entry.optionSetId,
          option_key: entry.optionKey,
          label: entry.label,
          value: entry.value,
          sort_order: entry.sortOrder,
          is_default: entry.isDefault,
          is_active: entry.isActive,
          metadata: entry.metadata,
          created_at: entry.createdAt,
          updated_at: entry.updatedAt,
        }),
      (record) => `${record.optionSetId}:${record.optionKey}`,
      "Runtime option values",
    ),
    runtimeCopy: normalizeCollection(
      value.runtimeCopy,
      (entry) =>
        mapRuntimeCopy({
          ...camelBaseRow(entry),
          copy_key: entry.copyKey,
          surface: entry.surface,
          locale: entry.locale,
          text_value: entry.textValue,
          description: entry.description,
        }),
      (record) => `${record.copyKey}:${record.locale}`,
      "Runtime copy",
    ),
    navigation: normalizeCollection(
      value.navigation,
      (entry) =>
        mapNavigation({
          ...camelBaseRow(entry),
          nav_key: entry.navKey,
          label: entry.label,
          href: entry.href,
          nav_group: entry.navGroup,
          surface: entry.surface,
          feature_key: entry.featureKey,
          sort_order: entry.sortOrder,
        }),
      (record) => record.navKey,
      "Runtime navigation",
    ),
    search: normalizeCollection(
      value.search,
      (entry) =>
        mapSearch({
          ...camelBaseRow(entry),
          search_key: entry.searchKey,
          title: entry.title,
          description: entry.description,
          href: entry.href,
          category: entry.category,
          meta_label: entry.metaLabel,
          surface: entry.surface,
          feature_key: entry.featureKey,
          sort_order: entry.sortOrder,
        }),
      (record) => record.searchKey,
      "Runtime search",
    ),
    venueControls: normalizeCollection(
      value.venueControls,
      (entry) =>
        mapVenueControl({
          ...camelBaseRow(entry),
          control_key: entry.controlKey,
          label: entry.label,
          detail: entry.detail,
          status_label: entry.statusLabel,
          action_label: entry.actionLabel,
          control_group: entry.controlGroup,
          venue_id: entry.venueId,
          sort_order: entry.sortOrder,
        }),
      (record) => record.controlKey,
      "Runtime venue controls",
    ),
  };
}

function resolveScopedRows(
  rows: Record<string, unknown>[],
  clubId: number | null,
  keyColumn: string,
) {
  const grouped = new Map<string, Record<string, unknown>[]>();
  for (const row of rows) {
    const key = boundedText(row[keyColumn], 128);
    if (key == null || !keyPattern.test(key)) {
      throw new AdminRuntimeRegistryValidationError(
        "Runtime registry response contained an invalid scope key.",
      );
    }
    const bucket = grouped.get(key) ?? [];
    bucket.push(row);
    grouped.set(key, bucket);
  }
  return [...grouped.values()]
    .map((variants) =>
      clubId == null
        ? variants.find((entry) => entry.club_id == null)
        : (variants.find((entry) => entry.club_id === clubId) ??
          variants.find((entry) => entry.club_id == null)),
    )
    .filter((entry): entry is Record<string, unknown> => entry != null);
}

async function readScopedRows(
  client: SupabaseClient,
  access: AdminAccess,
  table: ScopedRuntimeTable,
  orderColumn: string,
  keyColumn: string,
) {
  const clubId = adminClubIdOrNull(access);
  if (!access.isSuperAdmin && clubId == null) {
    requireAdminClubId(access, `load ${table}`);
  }
  let query = client.from(table).select(scopedRuntimeProjections[table]);

  query =
    clubId == null
      ? query.is("club_id", null)
      : query.or(`club_id.is.null,club_id.eq.${clubId}`);

  const { data, error } = await query
    .order(orderColumn, { ascending: true })
    .limit(MAX_RUNTIME_RECORDS_PER_COLLECTION + 1);
  if (error) {
    throw new Error("Runtime registry could not be loaded.");
  }
  if (!Array.isArray(data)) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime registry response was invalid.",
    );
  }
  if (data.length > MAX_RUNTIME_RECORDS_PER_COLLECTION) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime registry exceeded its safe limit.",
    );
  }
  return resolveScopedRows(
    data as unknown as Record<string, unknown>[],
    clubId,
    keyColumn,
  );
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
    .select(
      [
        "id",
        "option_set_id",
        "option_key",
        "label",
        "value",
        "sort_order",
        "is_default",
        "is_active",
        "metadata",
        "created_at",
        "updated_at",
      ].join(", "),
    )
    .in("option_set_id", optionSetIds)
    .order("sort_order", { ascending: true })
    .order("label", { ascending: true })
    .limit(MAX_RUNTIME_RECORDS_PER_COLLECTION + 1);

  if (error) {
    throw new Error("Runtime option values could not be loaded.");
  }
  if (
    !Array.isArray(data) ||
    data.length > MAX_RUNTIME_RECORDS_PER_COLLECTION
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime option values exceeded their safe limit or were invalid.",
    );
  }
  return data as unknown as Record<string, unknown>[];
}

export async function getAdminRuntimeRegistrySnapshot(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminRuntimeRegistrySnapshot> {
  if (typeof window !== "undefined") {
    const response = await requestAdminApi<unknown>("runtime-registry", {
      signal: options.signal,
    });
    return normalizeAdminRuntimeRegistrySnapshot(response);
  }

  const [
    routeRows,
    optionSetRows,
    copyRows,
    navigationRows,
    searchRows,
    venueControlRows,
  ] = await Promise.all([
    readScopedRows(
      client,
      access,
      "platform_route_registry",
      "sort_order",
      "route_key",
    ),
    readScopedRows(
      client,
      access,
      "platform_option_sets",
      "option_set_key",
      "option_set_key",
    ),
    readScopedRows(client, access, "runtime_copy", "copy_key", "copy_key"),
    readScopedRows(
      client,
      access,
      "site_navigation_items",
      "sort_order",
      "nav_key",
    ),
    readScopedRows(
      client,
      access,
      "site_search_items",
      "sort_order",
      "search_key",
    ),
    readScopedRows(
      client,
      access,
      "venue_governance_controls",
      "sort_order",
      "control_key",
    ),
  ]);
  const optionValues = await readOptionValues(
    client,
    optionSetRows.map((row) => safeString(row.id)).filter(Boolean),
  );

  return normalizeAdminRuntimeRegistrySnapshot({
    routes: routeRows.map(mapRoute),
    optionSets: optionSetRows.map(mapOptionSet),
    optionValues: optionValues.map(mapOptionValue),
    runtimeCopy: copyRows.map(mapRuntimeCopy),
    navigation: navigationRows.map(mapNavigation),
    search: searchRows.map(mapSearch),
    venueControls: venueControlRows.map(mapVenueControl),
  });
}

function resolveWriteClubId(
  access: AdminAccess,
  input: { scope?: RuntimeRegistryScope; clubId?: number | string | null },
  action: string,
) {
  requireRuntimeMutationAccess(access);
  if (input.scope === "global") {
    if (!access.isSuperAdmin) {
      throw new Error(
        "Platform admin access is required for global registry rows.",
      );
    }
    return null;
  }

  if (input.scope !== "club") {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime registry scope must be global or club.",
    );
  }

  if (access.isSuperAdmin) {
    const clubId = safeNumber(input.clubId ?? access.clubId, Number.NaN);
    if (!Number.isSafeInteger(clubId) || clubId <= 0) {
      throw new AdminRuntimeRegistryValidationError(
        "A valid club scope is required for a club registry row.",
      );
    }
    return clubId;
  }

  return requireAdminClubId(access, action);
}

function requireRuntimeMutationAccess(access: AdminAccess) {
  if (
    !access.hasAccess ||
    (!access.isSuperAdmin && access.role !== "club_admin")
  ) {
    throw new Error("Runtime registry write access is required.");
  }
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
  requireRuntimeMutationAccess(access);
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
  requireRuntimeMutationAccess(access);
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

function required(value: unknown, label: string, maxLength = 256) {
  const text = boundedText(value, maxLength);
  if (text == null) {
    throw new AdminRuntimeRegistryValidationError(
      `${label} is required and must be ${maxLength} characters or fewer.`,
    );
  }
  return text;
}

function requiredKey(value: unknown, label: string) {
  const text = required(value, label, 128);
  if (!keyPattern.test(text)) {
    throw new AdminRuntimeRegistryValidationError(`${label} was invalid.`);
  }
  return text;
}

function requiredRelativePath(value: unknown, label: string) {
  const text = required(value, label, 256);
  if (!text.startsWith("/") || text.startsWith("//")) {
    throw new AdminRuntimeRegistryValidationError(
      `${label} must be a relative application path.`,
    );
  }
  return text;
}

function requiredBoolean(value: unknown, label: string) {
  if (typeof value !== "boolean") {
    throw new AdminRuntimeRegistryValidationError(
      `${label} must be true or false.`,
    );
  }
  return value;
}

function requiredSortOrder(value: unknown) {
  const number = boundedInteger(value);
  if (number == null) {
    throw new AdminRuntimeRegistryValidationError(
      "Sort order must be a bounded integer.",
    );
  }
  return number;
}

function requiredSurface(value: unknown) {
  return toSurface(value);
}

function normalizedScopedMutationBase(input: Record<string, unknown>) {
  const scope = input.scope;
  if (scope !== "global" && scope !== "club") {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime registry scope must be global or club.",
    );
  }
  const id = input.id == null ? null : boundedText(input.id, 128);
  const expectedUpdatedAt =
    input.expectedUpdatedAt == null
      ? null
      : boundedIsoDate(input.expectedUpdatedAt);
  const clubId =
    input.clubId == null
      ? null
      : typeof input.clubId === "number" &&
          Number.isSafeInteger(input.clubId) &&
          input.clubId > 0
        ? input.clubId
        : undefined;
  if (
    (input.id != null && id == null) ||
    (input.expectedUpdatedAt != null && expectedUpdatedAt == null) ||
    clubId === undefined
  ) {
    throw new AdminRuntimeRegistryValidationError();
  }
  return { id, expectedUpdatedAt, scope, clubId };
}

function normalizedOptionValueMutationBase(input: Record<string, unknown>) {
  const id = input.id == null ? null : boundedText(input.id, 128);
  const expectedUpdatedAt =
    input.expectedUpdatedAt == null
      ? null
      : boundedIsoDate(input.expectedUpdatedAt);
  if (
    (input.id != null && id == null) ||
    (input.expectedUpdatedAt != null && expectedUpdatedAt == null)
  ) {
    throw new AdminRuntimeRegistryValidationError();
  }
  return { id, expectedUpdatedAt };
}

export async function saveAdminPlatformRoute(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminPlatformRoute>,
) {
  const inputRecord = input as unknown as Record<string, unknown>;
  const label = nullableText(input.label, 120);
  if (label === undefined) {
    throw new AdminRuntimeRegistryValidationError("Route label was invalid.");
  }
  const normalized = {
    ...normalizedScopedMutationBase(inputRecord),
    routeKey: requiredKey(input.routeKey, "Route key"),
    pathPattern: requiredRelativePath(input.pathPattern, "Path pattern"),
    surface: requiredSurface(input.surface),
    featureKey: requiredKey(input.featureKey, "Feature key"),
    label,
    authRequired: requiredBoolean(input.authRequired, "Authentication state"),
    requiredRoles: toStringArray(input.requiredRoles),
    presentation: required(input.presentation, "Presentation", 64),
    showInNavigation: requiredBoolean(
      input.showInNavigation,
      "Navigation visibility",
    ),
    showOnHome: requiredBoolean(input.showOnHome, "Home visibility"),
    sortOrder: requiredSortOrder(input.sortOrder),
    isActive: requiredBoolean(input.isActive, "Active state"),
    metadata: toRecord(input.metadata),
  };
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-routes", {
      method: "POST",
      body: normalized,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "platform_route_registry",
    normalized,
    {
      route_key: normalized.routeKey,
      path_pattern: normalized.pathPattern,
      surface: normalized.surface,
      feature_key: normalized.featureKey,
      label: normalized.label,
      auth_required: normalized.authRequired,
      required_roles: normalized.requiredRoles,
      presentation: normalized.presentation,
      show_in_navigation: normalized.showInNavigation,
      show_on_home: normalized.showOnHome,
      sort_order: normalized.sortOrder,
      is_active: normalized.isActive,
      metadata: normalized.metadata,
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
  await deleteScopedRecord(
    client,
    access,
    "platform_route_registry",
    id,
    expectedUpdatedAt,
    "delete runtime route",
  );
}

export async function saveAdminPlatformOptionSet(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminPlatformOptionSet>,
) {
  const inputRecord = input as unknown as Record<string, unknown>;
  const description = nullableText(input.description, 1_000);
  if (
    description === undefined ||
    !valueTypeValues.has(input.valueType as AdminPlatformOptionSet["valueType"])
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Option-set configuration was invalid.",
    );
  }
  const normalized = {
    ...normalizedScopedMutationBase(inputRecord),
    optionSetKey: requiredKey(input.optionSetKey, "Option set key"),
    label: required(input.label, "Option set label", 120),
    description,
    valueType: input.valueType as AdminPlatformOptionSet["valueType"],
    surface: requiredSurface(input.surface),
    isActive: requiredBoolean(input.isActive, "Active state"),
    metadata: toRecord(input.metadata),
  };
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-option-sets", {
      method: "POST",
      body: normalized,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "platform_option_sets",
    normalized,
    {
      option_set_key: normalized.optionSetKey,
      label: normalized.label,
      description: normalized.description,
      value_type: normalized.valueType,
      surface: normalized.surface,
      is_active: normalized.isActive,
      metadata: normalized.metadata,
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
  await deleteScopedRecord(
    client,
    access,
    "platform_option_sets",
    id,
    expectedUpdatedAt,
    "delete option set",
  );
}

async function ensureOptionSetWriteAccess(
  client: SupabaseClient,
  access: AdminAccess,
  optionSetId: string,
) {
  requireRuntimeMutationAccess(access);
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
  if (
    safeNumber((data as Record<string, unknown>).club_id, Number.NaN) !== clubId
  ) {
    throw new Error("Option values can only be changed for the active club.");
  }
}

export async function saveAdminPlatformOptionValue(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminPlatformOptionValue>,
) {
  const inputRecord = input as unknown as Record<string, unknown>;
  const optionValue = sanitizeJsonValue(input.value);
  if (optionValue === undefined) {
    throw new AdminRuntimeRegistryValidationError(
      "Option value was invalid or contained sensitive data.",
    );
  }
  const normalized = {
    ...normalizedOptionValueMutationBase(inputRecord),
    optionSetId: required(input.optionSetId, "Option set", 128),
    optionKey: requiredKey(input.optionKey, "Option key"),
    label: required(input.label, "Option label", 120),
    value: optionValue,
    sortOrder: requiredSortOrder(input.sortOrder),
    isDefault: requiredBoolean(input.isDefault, "Default state"),
    isActive: requiredBoolean(input.isActive, "Active state"),
    metadata: toRecord(input.metadata),
  };
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-option-values", {
      method: "POST",
      body: normalized,
    });
  }

  const optionSetId = normalized.optionSetId;
  await ensureOptionSetWriteAccess(client, access, optionSetId);

  return mutateRecordWithVariantsIfUnchanged(
    client,
    "platform_option_values",
    normalized.id,
    normalized.expectedUpdatedAt,
    [
      {
        option_set_id: optionSetId,
        option_key: normalized.optionKey,
        label: normalized.label,
        value: normalized.value,
        sort_order: normalized.sortOrder,
        is_default: normalized.isDefault,
        is_active: normalized.isActive,
        metadata: normalized.metadata,
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
  const optionSetId = safeString(
    (data as Record<string, unknown> | null)?.option_set_id,
  );
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
  const inputRecord = input as unknown as Record<string, unknown>;
  const locale = required(input.locale, "Locale", 16);
  const description = nullableText(input.description, 1_000);
  if (!localePattern.test(locale) || description === undefined) {
    throw new AdminRuntimeRegistryValidationError(
      "Runtime copy locale or description was invalid.",
    );
  }
  const normalized = {
    ...normalizedScopedMutationBase(inputRecord),
    copyKey: requiredKey(input.copyKey, "Copy key"),
    surface: requiredSurface(input.surface),
    locale,
    textValue: required(input.textValue, "Copy text", 4_000),
    description,
    isActive: requiredBoolean(input.isActive, "Active state"),
    metadata: toRecord(input.metadata),
  };
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-copy", {
      method: "POST",
      body: normalized,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "runtime_copy",
    normalized,
    {
      copy_key: normalized.copyKey,
      surface: normalized.surface,
      locale: normalized.locale,
      text_value: normalized.textValue,
      description: normalized.description,
      is_active: normalized.isActive,
      metadata: normalized.metadata,
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
  await deleteScopedRecord(
    client,
    access,
    "runtime_copy",
    id,
    expectedUpdatedAt,
    "delete runtime copy",
  );
}

export async function saveAdminSiteNavigationItem(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminSiteNavigationItem>,
) {
  const inputRecord = input as unknown as Record<string, unknown>;
  const featureKey = nullableText(input.featureKey, 128);
  if (
    featureKey === undefined ||
    (featureKey != null && !keyPattern.test(featureKey))
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Navigation feature key was invalid.",
    );
  }
  const normalized = {
    ...normalizedScopedMutationBase(inputRecord),
    navKey: requiredKey(input.navKey, "Navigation key"),
    label: required(input.label, "Navigation label", 120),
    href: requiredRelativePath(input.href, "Navigation href"),
    navGroup: required(input.navGroup, "Navigation group", 64),
    surface: requiredSurface(input.surface),
    featureKey,
    sortOrder: requiredSortOrder(input.sortOrder),
    isActive: requiredBoolean(input.isActive, "Active state"),
    metadata: toRecord(input.metadata),
  };
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-navigation", {
      method: "POST",
      body: normalized,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "site_navigation_items",
    normalized,
    {
      nav_key: normalized.navKey,
      label: normalized.label,
      href: normalized.href,
      nav_group: normalized.navGroup,
      surface: normalized.surface,
      feature_key: normalized.featureKey,
      sort_order: normalized.sortOrder,
      is_active: normalized.isActive,
      metadata: normalized.metadata,
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
  await deleteScopedRecord(
    client,
    access,
    "site_navigation_items",
    id,
    expectedUpdatedAt,
    "delete navigation item",
  );
}

export async function saveAdminSiteSearchItem(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminSiteSearchItem>,
) {
  const inputRecord = input as unknown as Record<string, unknown>;
  const metaLabel = nullableText(input.metaLabel, 120);
  const featureKey = nullableText(input.featureKey, 128);
  if (
    metaLabel === undefined ||
    featureKey === undefined ||
    (featureKey != null && !keyPattern.test(featureKey))
  ) {
    throw new AdminRuntimeRegistryValidationError(
      "Search metadata or feature key was invalid.",
    );
  }
  const normalized = {
    ...normalizedScopedMutationBase(inputRecord),
    searchKey: requiredKey(input.searchKey, "Search key"),
    title: required(input.title, "Search title", 160),
    description: required(input.description, "Search description", 1_000),
    href: requiredRelativePath(input.href, "Search href"),
    category: required(input.category, "Search category", 64),
    metaLabel,
    surface: requiredSurface(input.surface),
    featureKey,
    sortOrder: requiredSortOrder(input.sortOrder),
    isActive: requiredBoolean(input.isActive, "Active state"),
    metadata: toRecord(input.metadata),
  };
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-search", {
      method: "POST",
      body: normalized,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "site_search_items",
    normalized,
    {
      search_key: normalized.searchKey,
      title: normalized.title,
      description: normalized.description,
      href: normalized.href,
      category: normalized.category,
      meta_label: normalized.metaLabel,
      surface: normalized.surface,
      feature_key: normalized.featureKey,
      sort_order: normalized.sortOrder,
      is_active: normalized.isActive,
      metadata: normalized.metadata,
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
  await deleteScopedRecord(
    client,
    access,
    "site_search_items",
    id,
    expectedUpdatedAt,
    "delete search item",
  );
}

export async function saveAdminVenueGovernanceControl(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<AdminVenueGovernanceControl>,
) {
  const inputRecord = input as unknown as Record<string, unknown>;
  const actionLabel = nullableText(input.actionLabel, 120);
  const venueId = nullableText(input.venueId, 128);
  if (actionLabel === undefined || venueId === undefined) {
    throw new AdminRuntimeRegistryValidationError(
      "Venue control action or venue id was invalid.",
    );
  }
  const normalized = {
    ...normalizedScopedMutationBase(inputRecord),
    controlKey: requiredKey(input.controlKey, "Control key"),
    label: required(input.label, "Control label", 160),
    detail: required(input.detail, "Control detail", 1_000),
    statusLabel: required(input.statusLabel, "Status label", 64),
    actionLabel,
    controlGroup: required(input.controlGroup, "Control group", 64),
    venueId,
    sortOrder: requiredSortOrder(input.sortOrder),
    isActive: requiredBoolean(input.isActive, "Active state"),
    metadata: toRecord(input.metadata),
  };
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("runtime-venue-controls", {
      method: "POST",
      body: normalized,
    });
  }

  return saveScopedRecord(
    client,
    access,
    "venue_governance_controls",
    normalized,
    {
      control_key: normalized.controlKey,
      label: normalized.label,
      detail: normalized.detail,
      status_label: normalized.statusLabel,
      action_label: normalized.actionLabel,
      control_group: normalized.controlGroup,
      venue_id: normalized.venueId,
      sort_order: normalized.sortOrder,
      is_active: normalized.isActive,
      metadata: normalized.metadata,
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

import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, PlatformFeature } from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  AdminMutationConflictError,
  adminClubIdOrNull,
  requireExpectedUpdatedAt,
} from "./helpers";

export const MAX_ADMIN_FEATURES = 500;

const maxChannels = 2;
const maxJsonDepth = 4;
const maxJsonEntries = 50;
const sensitiveKeyPattern =
  /(?:^|_)(?:authorization|cookie|credential|password|secret|session|token)(?:_|$)/i;
const featureKeyPattern = /^[a-z][a-z0-9_]{0,63}$/;
const rolePattern = /^[a-z][a-z0-9_:-]{0,63}$/;

type JsonObject = Record<string, unknown>;

export type FeatureChannelInput = {
  channel: "mobile" | "web";
  isEnabled: boolean;
  isVisible: boolean;
  showInNavigation: boolean;
  showOnHome: boolean;
  sortOrder: number | null;
  routeKey: string | null;
  placementKey: string | null;
};

export type FeatureRulesInput = {
  authRequired: boolean;
  roleRestrictions: string[];
  dependencyRules: JsonObject;
  rolloutRules: JsonObject;
  metadata: JsonObject;
  scheduleStartAt: string | null;
  scheduleEndAt: string | null;
};

export type FeatureUpdateInput = Partial<{
  displayName: string;
  description: string | null;
  category: string | null;
  isEnabled: boolean;
  visibilityState: "visible" | "hidden" | "maintenance";
  channels: FeatureChannelInput[];
  rules: FeatureRulesInput;
}>;

type FeatureRow = {
  id: unknown;
  feature_key: unknown;
  display_name: unknown;
  description: unknown;
  category: unknown;
  club_id: unknown;
  is_enabled: unknown;
  visibility_state: unknown;
  updated_at: unknown;
  channels?: unknown;
  rules?: unknown;
};

export class AdminFeatureValidationError extends Error {
  constructor(
    message = "Review the feature configuration and correct invalid values.",
  ) {
    super(message);
    this.name = "AdminFeatureValidationError";
  }
}

function isRecord(value: unknown): value is JsonObject {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function read(
  value: JsonObject,
  camelKey: string,
  snakeKey = camelKey,
): unknown {
  return camelKey in value ? value[camelKey] : value[snakeKey];
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
  if (depth >= maxJsonDepth) return undefined;
  if (Array.isArray(value)) {
    if (value.length > maxJsonEntries) return undefined;
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
  if (entries.length > maxJsonEntries) return undefined;
  const output: JsonObject = {};
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

function normalizeJsonObject(value: unknown): JsonObject | null {
  const sanitized = sanitizeJsonValue(value);
  return isRecord(sanitized) ? sanitized : null;
}

function normalizeChannel(
  value: unknown,
): PlatformFeature["channels"][number] | null {
  if (!isRecord(value)) return null;
  const channel = read(value, "channel");
  const idValue = read(value, "id");
  const id = idValue == null ? null : boundedText(idValue, 128);
  const sortOrderValue = read(value, "sortOrder", "sort_order");
  const sortOrder =
    sortOrderValue == null ? null : boundedInteger(sortOrderValue);
  const routeKey = nullableText(read(value, "routeKey", "route_key"), 256);
  const placementKey = nullableText(
    read(value, "placementKey", "placement_key"),
    128,
  );

  if (
    (channel !== "mobile" && channel !== "web") ||
    (idValue != null && id == null) ||
    typeof read(value, "isEnabled", "is_enabled") !== "boolean" ||
    typeof read(value, "isVisible", "is_visible") !== "boolean" ||
    typeof read(value, "showInNavigation", "show_in_navigation") !==
      "boolean" ||
    typeof read(value, "showOnHome", "show_on_home") !== "boolean" ||
    (sortOrderValue != null && sortOrder == null) ||
    routeKey === undefined ||
    placementKey === undefined
  ) {
    return null;
  }

  return {
    id,
    channel,
    isEnabled: read(value, "isEnabled", "is_enabled") as boolean,
    isVisible: read(value, "isVisible", "is_visible") as boolean,
    showInNavigation: read(
      value,
      "showInNavigation",
      "show_in_navigation",
    ) as boolean,
    showOnHome: read(value, "showOnHome", "show_on_home") as boolean,
    sortOrder,
    routeKey,
    placementKey,
  };
}

function normalizeRules(
  value: unknown,
): PlatformFeature["rules"] | null | undefined {
  const ruleValue = Array.isArray(value) ? value[0] : value;
  if (ruleValue == null) return null;
  if (!isRecord(ruleValue)) return undefined;

  const authRequired = read(ruleValue, "authRequired", "auth_required");
  const roleValue = read(ruleValue, "roleRestrictions", "role_restrictions");
  const dependencyRules = normalizeJsonObject(
    read(ruleValue, "dependencyRules", "dependency_rules"),
  );
  const rolloutRules = normalizeJsonObject(
    read(ruleValue, "rolloutRules", "rollout_rules"),
  );
  const metadata = normalizeJsonObject(read(ruleValue, "metadata"));
  const startValue = read(ruleValue, "scheduleStartAt", "schedule_start_at");
  const endValue = read(ruleValue, "scheduleEndAt", "schedule_end_at");
  const scheduleStartAt =
    startValue == null ? null : boundedIsoDate(startValue);
  const scheduleEndAt = endValue == null ? null : boundedIsoDate(endValue);

  if (
    typeof authRequired !== "boolean" ||
    !Array.isArray(roleValue) ||
    roleValue.length > 20 ||
    roleValue.some(
      (role) => typeof role !== "string" || !rolePattern.test(role),
    ) ||
    dependencyRules == null ||
    rolloutRules == null ||
    metadata == null ||
    (startValue != null && scheduleStartAt == null) ||
    (endValue != null && scheduleEndAt == null) ||
    (scheduleStartAt != null &&
      scheduleEndAt != null &&
      Date.parse(scheduleStartAt) >= Date.parse(scheduleEndAt))
  ) {
    return undefined;
  }

  return {
    authRequired,
    roleRestrictions: [...new Set(roleValue as string[])],
    dependencyRules,
    rolloutRules,
    metadata,
    scheduleStartAt,
    scheduleEndAt,
  };
}

function normalizeFeature(value: unknown): PlatformFeature | null {
  if (!isRecord(value)) return null;
  const id = boundedText(read(value, "id"), 128);
  const featureKey = boundedText(read(value, "featureKey", "feature_key"), 64);
  const displayName = boundedText(
    read(value, "displayName", "display_name"),
    120,
  );
  const description = nullableText(read(value, "description"), 1_000);
  const category = nullableText(read(value, "category"), 64);
  const clubIdValue = read(value, "clubId", "club_id");
  const clubId =
    clubIdValue == null
      ? null
      : typeof clubIdValue === "number" &&
          Number.isSafeInteger(clubIdValue) &&
          clubIdValue > 0
        ? clubIdValue
        : undefined;
  const isEnabled = read(value, "isEnabled", "is_enabled");
  const visibilityState = read(value, "visibilityState", "visibility_state");
  const updatedAt = boundedIsoDate(read(value, "updatedAt", "updated_at"));
  const channelValue = read(value, "channels");
  const rules = normalizeRules(read(value, "rules"));

  if (
    id == null ||
    featureKey == null ||
    !featureKeyPattern.test(featureKey) ||
    displayName == null ||
    description === undefined ||
    category === undefined ||
    clubId === undefined ||
    typeof isEnabled !== "boolean" ||
    (visibilityState !== "visible" &&
      visibilityState !== "hidden" &&
      visibilityState !== "maintenance") ||
    updatedAt == null ||
    !Array.isArray(channelValue) ||
    channelValue.length > maxChannels ||
    rules === undefined
  ) {
    return null;
  }

  const channels = channelValue.map(normalizeChannel);
  if (
    channels.some((channel) => channel == null) ||
    new Set(channels.map((channel) => channel?.channel)).size !==
      channels.length
  ) {
    return null;
  }

  return {
    id,
    clubId,
    scope: clubId == null ? "global" : "club",
    featureKey,
    displayName,
    description,
    category,
    isEnabled,
    visibilityState,
    updatedAt,
    channels: (channels as PlatformFeature["channels"]).sort((left, right) =>
      left.channel.localeCompare(right.channel),
    ),
    rules,
  };
}

export function normalizeAdminFeatures(value: unknown): PlatformFeature[] {
  if (!Array.isArray(value) || value.length > MAX_ADMIN_FEATURES) {
    throw new AdminFeatureValidationError(
      "The feature registry response was invalid or exceeded its safe limit.",
    );
  }

  const output = value.map(normalizeFeature);
  if (output.some((feature) => feature == null)) {
    throw new AdminFeatureValidationError(
      "The feature registry response contained an invalid record.",
    );
  }

  const features = output as PlatformFeature[];
  if (
    new Set(features.map((feature) => feature.id)).size !== features.length ||
    new Set(features.map((feature) => feature.featureKey)).size !==
      features.length
  ) {
    throw new AdminFeatureValidationError(
      "The feature registry response contained duplicate records.",
    );
  }
  return features;
}

function resolveScopedRows(rows: FeatureRow[], clubId: number | null) {
  const grouped = new Map<string, FeatureRow[]>();

  for (const row of rows) {
    const featureKey = boundedText(row.feature_key, 64);
    if (featureKey == null || !featureKeyPattern.test(featureKey)) {
      throw new AdminFeatureValidationError(
        "The feature registry contained an invalid key.",
      );
    }
    const bucket = grouped.get(featureKey) ?? [];
    bucket.push(row);
    grouped.set(featureKey, bucket);
  }

  return [...grouped.values()]
    .map((variants) =>
      clubId == null
        ? variants.find((entry) => entry.club_id == null)
        : (variants.find((entry) => entry.club_id === clubId) ??
          variants.find((entry) => entry.club_id == null)),
    )
    .filter((entry): entry is FeatureRow => entry != null)
    .sort((left, right) => {
      const categoryCompare = String(left.category ?? "").localeCompare(
        String(right.category ?? ""),
      );
      return categoryCompare !== 0
        ? categoryCompare
        : String(left.feature_key).localeCompare(String(right.feature_key));
    });
}

async function listFeatureRows(client: SupabaseClient, clubId: number | null) {
  let query = client.from("platform_features").select(`
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

  query =
    clubId == null
      ? query.is("club_id", null)
      : query.or(`club_id.is.null,club_id.eq.${clubId}`);

  const { data, error } = await query
    .order("feature_key")
    .limit(MAX_ADMIN_FEATURES + 1);

  if (error) throw new Error("Feature configuration could not be loaded.");
  if (!Array.isArray(data)) {
    throw new AdminFeatureValidationError(
      "The feature registry response was invalid.",
    );
  }
  if (data.length > MAX_ADMIN_FEATURES) {
    throw new AdminFeatureValidationError(
      "The feature registry exceeded its safe limit.",
    );
  }
  return data as FeatureRow[];
}

function normalizeChannelInput(value: unknown): FeatureChannelInput | null {
  const normalized = normalizeChannel({
    ...(isRecord(value) ? value : {}),
    id: null,
  });
  if (normalized == null) return null;
  const { id: _id, ...input } = normalized;
  return input;
}

function normalizeRulesInput(value: unknown): FeatureRulesInput | null {
  const normalized = normalizeRules(value);
  return normalized == null ? null : normalized;
}

export function normalizeAdminFeatureUpdate(
  value: unknown,
): FeatureUpdateInput {
  if (!isRecord(value)) throw new AdminFeatureValidationError();

  const allowedKeys = new Set([
    "displayName",
    "description",
    "category",
    "isEnabled",
    "visibilityState",
    "channels",
    "rules",
  ]);
  const keys = Object.keys(value);
  if (keys.length === 0 || keys.some((key) => !allowedKeys.has(key))) {
    throw new AdminFeatureValidationError();
  }

  const output: FeatureUpdateInput = {};
  if ("displayName" in value) {
    const displayName = boundedText(value.displayName, 120);
    if (displayName == null) throw new AdminFeatureValidationError();
    output.displayName = displayName;
  }
  if ("description" in value) {
    const description = nullableText(value.description, 1_000);
    if (description === undefined) throw new AdminFeatureValidationError();
    output.description = description;
  }
  if ("category" in value) {
    const category = nullableText(value.category, 64);
    if (category === undefined) throw new AdminFeatureValidationError();
    output.category = category;
  }
  if ("isEnabled" in value) {
    if (typeof value.isEnabled !== "boolean") {
      throw new AdminFeatureValidationError();
    }
    output.isEnabled = value.isEnabled;
  }
  if ("visibilityState" in value) {
    if (
      value.visibilityState !== "visible" &&
      value.visibilityState !== "hidden" &&
      value.visibilityState !== "maintenance"
    ) {
      throw new AdminFeatureValidationError();
    }
    output.visibilityState = value.visibilityState;
  }
  if ("channels" in value) {
    if (!Array.isArray(value.channels) || value.channels.length > maxChannels) {
      throw new AdminFeatureValidationError();
    }
    const channels = value.channels.map(normalizeChannelInput);
    if (
      channels.some((channel) => channel == null) ||
      new Set(channels.map((channel) => channel?.channel)).size !==
        channels.length
    ) {
      throw new AdminFeatureValidationError();
    }
    output.channels = channels as FeatureChannelInput[];
  }
  if ("rules" in value) {
    const rules = normalizeRulesInput(value.rules);
    if (rules == null) throw new AdminFeatureValidationError();
    output.rules = rules;
  }
  return output;
}

function requireFeatureMutationAccess(access: AdminAccess) {
  if (
    !access.hasAccess ||
    (!access.isSuperAdmin && access.role !== "club_admin")
  ) {
    throw new Error("Feature configuration access is required.");
  }
  if (!access.isSuperAdmin && adminClubIdOrNull(access) == null) {
    throw new Error(
      "A club scope is required to update feature configuration.",
    );
  }
}

export async function getAdminFeatures(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } | SupabaseClient = {},
): Promise<PlatformFeature[]> {
  if (typeof window !== "undefined") {
    const response = await requestAdminApi<unknown>("features", {
      signal: "signal" in options ? options.signal : undefined,
    });
    return normalizeAdminFeatures(response);
  }

  if (!access.hasAccess) {
    throw new Error("Feature configuration access is required.");
  }
  const scopedClubId = adminClubIdOrNull(access);
  const rows = await listFeatureRows(client, scopedClubId);
  return normalizeAdminFeatures(resolveScopedRows(rows, scopedClubId));
}

export async function updateAdminFeature(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
  updates: FeatureUpdateInput,
) {
  const featureId = boundedText(id, 128);
  const loadedVersion = boundedIsoDate(
    requireExpectedUpdatedAt(expectedUpdatedAt),
  );
  if (featureId == null || loadedVersion == null) {
    throw new AdminFeatureValidationError();
  }
  const normalizedUpdates = normalizeAdminFeatureUpdate(updates);

  if (typeof window !== "undefined") {
    return requestAdminApi("features/update", {
      method: "POST",
      body: {
        id: featureId,
        expectedUpdatedAt: loadedVersion,
        updates: normalizedUpdates,
      },
    });
  }

  requireFeatureMutationAccess(access);
  const { error } = await client.rpc(
    "admin_update_platform_feature_if_unchanged",
    {
      p_feature_id: featureId,
      p_expected_updated_at: loadedVersion,
      p_club_id: adminClubIdOrNull(access),
      p_updates: normalizedUpdates,
      p_actor_id: access.userId ?? null,
    },
  );

  if (error) {
    const message = String(error.message ?? "").toLowerCase();
    if (
      message.includes("changed after it was loaded") ||
      message.includes("scoped override was created") ||
      message.includes("scope changed after it was loaded")
    ) {
      throw new AdminMutationConflictError();
    }
    throw new Error("Feature configuration could not be updated.");
  }
}

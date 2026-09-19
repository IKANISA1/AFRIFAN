import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { getReadOnlySupabase } from "@/lib/supabase/admin";

export interface FeatureChannelConfig {
  is_enabled: boolean;
  is_visible: boolean;
  show_in_navigation: boolean;
  show_on_home: boolean;
  sort_order: number | null;
  route_key?: string | null;
  placement_key?: string | null;
}

export interface FeatureRuleConfig {
  auth_required: boolean;
  role_restrictions: string[];
  dependency_rules: Record<string, unknown>;
  rollout_rules: Record<string, unknown>;
  schedule_start_at?: string | null;
  schedule_end_at?: string | null;
  metadata?: Record<string, unknown>;
  is_within_schedule: boolean;
}

export interface PlatformFeature {
  feature_key: string;
  display_name: string;
  description?: string | null;
  category?: string | null;
  is_enabled: boolean;
  visibility_state: "visible" | "hidden" | "maintenance";
  channel?: FeatureChannelConfig | null;
  rules?: FeatureRuleConfig | null;
}

export interface ContentBlock {
  block_key: string;
  block_type: string;
  title?: string | null;
  subtitle?: string | null;
  content: Record<string, unknown>;
  target_channel: "mobile" | "web" | "both";
  placement_key: string;
  feature_key?: string | null;
  is_active: boolean;
  sort_order: number | null;
  metadata: Record<string, unknown>;
}

export interface PlatformRouteConfig {
  route_key: string;
  path_pattern: string;
  surface: "mobile" | "web" | "admin" | "both";
  feature_key: string;
  label?: string | null;
  auth_required: boolean;
  required_roles: string[];
  presentation: string;
  show_in_navigation: boolean;
  show_on_home: boolean;
  sort_order: number | null;
  metadata: Record<string, unknown>;
}

export interface PlatformOptionValue {
  option_key: string;
  label: string;
  value: unknown;
  sort_order: number | null;
  is_default: boolean;
  metadata: Record<string, unknown>;
}

export interface PlatformOptionSet {
  option_set_key: string;
  label: string;
  description?: string | null;
  value_type: "text" | "number" | "boolean" | "json";
  surface: "mobile" | "web" | "admin" | "both";
  metadata: Record<string, unknown>;
  values: PlatformOptionValue[];
}

export interface RuntimeCopyEntry {
  copy_key: string;
  surface: "mobile" | "web" | "admin" | "both";
  locale: string;
  text_value: string;
  description?: string | null;
  metadata: Record<string, unknown>;
}

export interface SiteNavigationItem {
  nav_key: string;
  label: string;
  href: string;
  nav_group: string;
  surface: "web" | "mobile" | "admin" | "both";
  feature_key?: string | null;
  sort_order: number | null;
  metadata: Record<string, unknown>;
}

export interface SiteSearchItem {
  search_key: string;
  title: string;
  description: string;
  href: string;
  category: string;
  meta_label?: string | null;
  surface: "web" | "mobile" | "admin" | "both";
  feature_key?: string | null;
  sort_order: number | null;
  metadata: Record<string, unknown>;
}

export interface PlatformConfigSnapshot {
  features: PlatformFeature[];
  content_blocks: ContentBlock[];
  route_registry: PlatformRouteConfig[];
  option_sets: PlatformOptionSet[];
  runtime_copy: RuntimeCopyEntry[];
  site_navigation: SiteNavigationItem[];
  site_search: SiteSearchItem[];
  config_version: string;
  channel: "mobile" | "web";
  club_id: number | null;
}

export interface FeatureAccessState {
  feature: PlatformFeature | null;
  featureKey: string;
  normalizedKey: string;
  isRegistered: boolean;
  isVisible: boolean;
  isOperational: boolean;
  isAvailable: boolean;
  showInNavigation: boolean;
  showOnHome: boolean;
  routeKey: string | null;
  placementKey: string | null;
  reason:
    | "ok"
    | "unregistered"
    | "global_disabled"
    | "channel_disabled"
    | "hidden"
    | "channel_hidden"
    | "maintenance"
    | "outside_schedule"
    | "dependency_blocked"
    | "auth_required"
    | "role_restricted";
}

export interface FeatureAccessOptions {
  isAuthenticated?: boolean;
  roles?: string[];
}

const EMPTY_CONFIG: PlatformConfigSnapshot = {
  features: [],
  content_blocks: [],
  route_registry: [],
  option_sets: [],
  runtime_copy: [],
  site_navigation: [],
  site_search: [],
  config_version: new Date(0).toISOString(),
  channel: "web",
  club_id: null,
};

const lastKnownConfigByClub = new Map<number, PlatformConfigSnapshot>();

const FALLBACK_ROUTE_FEATURE_KEYS: ReadonlyArray<[string, string]> = [
  ["/tickets", "ticketing"],
  ["/membership", "membership"],
  ["/fan-clubs", "fan_clubs"],
  ["/circles", "contributions"],
  ["/groups", "contributions"],
  ["/shop", "shop"],
  ["/fixtures", "live"],
  ["/results", "live"],
  ["/standings", "live"],
  ["/news", "news"],
  ["/squad", "squad"],
  ["/admin", "admin"],
];

function emptyConfigSnapshot(
  channel: "mobile" | "web" = "web",
): PlatformConfigSnapshot {
  return {
    ...EMPTY_CONFIG,
    channel,
    config_version: new Date().toISOString(),
  };
}

function rememberConfig(snapshot: PlatformConfigSnapshot) {
  if (snapshot.club_id == null) {
    return snapshot;
  }

  lastKnownConfigByClub.set(snapshot.club_id, snapshot);
  return snapshot;
}

function getLastKnownConfig(clubId: number, channel: "mobile" | "web" = "web") {
  const cached = lastKnownConfigByClub.get(clubId);
  if (!cached) {
    return null;
  }

  return {
    ...cached,
    channel,
    club_id: cached.club_id ?? clubId,
  } satisfies PlatformConfigSnapshot;
}

export function normalizeFeatureKey(value: string | null | undefined) {
  return (value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "");
}

function normalizeRoles(roles: string[]) {
  return roles.map((role) => role.trim().toLowerCase()).filter(Boolean);
}

function normalizeStringArray(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((entry): entry is string => typeof entry === "string")
    : [];
}

function normalizeRecord(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value != null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function normalizePlatformConfigPayload(
  payload: Partial<PlatformConfigSnapshot>,
  clubId: number,
): PlatformConfigSnapshot {
  return {
    features: Array.isArray(payload.features) ? payload.features : [],
    content_blocks: Array.isArray(payload.content_blocks)
      ? payload.content_blocks
      : [],
    route_registry: Array.isArray(payload.route_registry)
      ? payload.route_registry.map((route) => ({
          ...route,
          required_roles: normalizeStringArray(route.required_roles),
          metadata: normalizeRecord(route.metadata),
        }))
      : [],
    option_sets: Array.isArray(payload.option_sets)
      ? payload.option_sets.map((set) => ({
          ...set,
          metadata: normalizeRecord(set.metadata),
          values: Array.isArray(set.values)
            ? set.values.map((value) => ({
                ...value,
                metadata: normalizeRecord(value.metadata),
              }))
            : [],
        }))
      : [],
    runtime_copy: Array.isArray(payload.runtime_copy)
      ? payload.runtime_copy.map((entry) => ({
          ...entry,
          metadata: normalizeRecord(entry.metadata),
        }))
      : [],
    site_navigation: Array.isArray(payload.site_navigation)
      ? payload.site_navigation.map((entry) => ({
          ...entry,
          metadata: normalizeRecord(entry.metadata),
        }))
      : [],
    site_search: Array.isArray(payload.site_search)
      ? payload.site_search.map((entry) => ({
          ...entry,
          metadata: normalizeRecord(entry.metadata),
        }))
      : [],
    config_version: payload.config_version ?? new Date().toISOString(),
    channel: "web",
    club_id: payload.club_id ?? clubId,
  };
}

export function getFeature(
  config: PlatformConfigSnapshot,
  key: string,
): PlatformFeature | null {
  const normalizedKey = normalizeFeatureKey(key);
  return (
    config.features.find(
      (feature) => normalizeFeatureKey(feature.feature_key) === normalizedKey,
    ) ?? null
  );
}

export function getFeatureAccess(
  config: PlatformConfigSnapshot,
  key: string,
  options: FeatureAccessOptions = {},
): FeatureAccessState {
  return _getFeatureAccess(config, key, options, new Set<string>());
}

function _getFeatureAccess(
  config: PlatformConfigSnapshot,
  key: string,
  options: FeatureAccessOptions,
  visited: Set<string>,
): FeatureAccessState {
  const normalizedKey = normalizeFeatureKey(key);
  const feature = getFeature(config, normalizedKey);

  if (!feature) {
    return {
      feature: null,
      featureKey: key,
      normalizedKey,
      isRegistered: false,
      isVisible: true,
      isOperational: true,
      isAvailable: true,
      showInNavigation: false,
      showOnHome: false,
      routeKey: null,
      placementKey: null,
      reason: "unregistered",
    };
  }

  const roles = normalizeRoles(options.roles ?? []);
  const isAuthenticated = options.isAuthenticated ?? false;
  const visibilityState = feature.visibility_state ?? "visible";
  const channel = feature.channel ?? null;
  const rules = feature.rules ?? null;

  const isVisible =
    visibilityState !== "hidden" && (channel?.is_visible ?? true);
  const dependencies = rules?.dependency_rules?.requires;
  const nextVisited = new Set<string>(visited);
  nextVisited.add(normalizedKey);
  const dependenciesSatisfied =
    !Array.isArray(dependencies) ||
    dependencies.every(
      (dependency) =>
        typeof dependency !== "string" ||
        nextVisited.has(normalizeFeatureKey(dependency)) ||
        _getFeatureAccess(config, dependency, options, nextVisited)
          .isOperational,
    );
  const isWithinSchedule = rules?.is_within_schedule ?? true;
  const roleRestrictions = Array.isArray(rules?.role_restrictions)
    ? normalizeRoles(rules?.role_restrictions ?? [])
    : [];
  const roleAllowed =
    roleRestrictions.length === 0 ||
    (isAuthenticated && roles.some((role) => roleRestrictions.includes(role)));
  const authAllowed = !(rules?.auth_required ?? false) || isAuthenticated;

  const isOperational =
    feature.is_enabled &&
    (channel?.is_enabled ?? true) &&
    visibilityState !== "maintenance" &&
    isWithinSchedule &&
    dependenciesSatisfied;
  const isAvailable = isOperational && authAllowed && roleAllowed;

  let reason: FeatureAccessState["reason"] = "ok";
  if (!feature.is_enabled) {
    reason = "global_disabled";
  } else if (!(channel?.is_enabled ?? true)) {
    reason = "channel_disabled";
  } else if (visibilityState === "hidden") {
    reason = "hidden";
  } else if (!(channel?.is_visible ?? true)) {
    reason = "channel_hidden";
  } else if (visibilityState === "maintenance") {
    reason = "maintenance";
  } else if (!isWithinSchedule) {
    reason = "outside_schedule";
  } else if (!dependenciesSatisfied) {
    reason = "dependency_blocked";
  } else if (!authAllowed) {
    reason = "auth_required";
  } else if (!roleAllowed) {
    reason = "role_restricted";
  }

  return {
    feature,
    featureKey: feature.feature_key,
    normalizedKey,
    isRegistered: true,
    isVisible,
    isOperational,
    isAvailable,
    showInNavigation: Boolean(channel?.show_in_navigation),
    showOnHome: Boolean(channel?.show_on_home),
    routeKey: channel?.route_key ?? null,
    placementKey: channel?.placement_key ?? null,
    reason,
  };
}

export function canRenderFeature(
  config: PlatformConfigSnapshot,
  key: string,
  options?: FeatureAccessOptions,
) {
  const access = getFeatureAccess(config, key, options);
  return access.isVisible && access.isAvailable;
}

export function canUseFeature(
  config: PlatformConfigSnapshot,
  key: string,
  options?: FeatureAccessOptions,
) {
  return getFeatureAccess(config, key, options).isAvailable;
}

export function getNavFeatures(
  config: PlatformConfigSnapshot,
  options?: FeatureAccessOptions,
): PlatformFeature[] {
  return config.features
    .filter((feature) => {
      const access = getFeatureAccess(config, feature.feature_key, options);
      return access.showInNavigation && access.isVisible && access.isAvailable;
    })
    .sort(
      (left, right) =>
        (left.channel?.sort_order ?? 999) - (right.channel?.sort_order ?? 999),
    );
}

export function getSiteNavigationItems(
  config: PlatformConfigSnapshot,
  navGroup = "primary",
  options?: FeatureAccessOptions,
): SiteNavigationItem[] {
  return config.site_navigation
    .filter((item) => {
      if (item.nav_group !== navGroup) {
        return false;
      }
      if (item.feature_key == null || item.feature_key.trim().length === 0) {
        return true;
      }
      return canRenderFeature(config, item.feature_key, options);
    })
    .sort((left, right) => {
      const order = (left.sort_order ?? 999) - (right.sort_order ?? 999);
      return order !== 0 ? order : left.label.localeCompare(right.label);
    });
}

export function getSiteSearchItems(
  config: PlatformConfigSnapshot,
  options?: FeatureAccessOptions,
): SiteSearchItem[] {
  return config.site_search
    .filter((item) => {
      if (item.feature_key == null || item.feature_key.trim().length === 0) {
        return true;
      }
      return canRenderFeature(config, item.feature_key, options);
    })
    .sort((left, right) => {
      const order = (left.sort_order ?? 999) - (right.sort_order ?? 999);
      return order !== 0 ? order : left.title.localeCompare(right.title);
    });
}

export function getOptionSet(
  config: PlatformConfigSnapshot,
  optionSetKey: string,
): PlatformOptionSet | null {
  const normalizedKey = normalizeFeatureKey(optionSetKey);
  return (
    config.option_sets.find(
      (set) => normalizeFeatureKey(set.option_set_key) === normalizedKey,
    ) ?? null
  );
}

export function getRuntimeCopy(
  config: PlatformConfigSnapshot,
  copyKey: string,
  _locale = "en",
): string | null {
  const normalizedKey = normalizeFeatureKey(copyKey);
  const localeFallbacks = ["en"];
  for (const candidateLocale of localeFallbacks) {
    const entry = config.runtime_copy.find(
      (copy) =>
        normalizeFeatureKey(copy.copy_key) === normalizedKey &&
        normalizeRuntimeCopyLocale(copy.locale) === candidateLocale &&
        copy.text_value.trim().length > 0,
    );
    if (entry != null) return entry.text_value;
  }
  return null;
}

function normalizeRuntimeCopyLocale(locale: string): string {
  const normalized = locale.trim().replaceAll("_", "-").toLowerCase();
  return normalized.length === 0 ? "en" : normalized;
}

export function getHomeFeatures(
  config: PlatformConfigSnapshot,
  options?: FeatureAccessOptions,
): PlatformFeature[] {
  return config.features
    .filter((feature) => {
      const access = getFeatureAccess(config, feature.feature_key, options);
      return access.showOnHome && access.isVisible && access.isAvailable;
    })
    .sort(
      (left, right) =>
        (left.channel?.sort_order ?? 999) - (right.channel?.sort_order ?? 999),
    );
}

export function getContentBlocks(
  config: PlatformConfigSnapshot,
  placement: string,
  options?: FeatureAccessOptions,
): ContentBlock[] {
  return config.content_blocks
    .filter((block) => {
      if (!block.is_active || block.placement_key !== placement) {
        return false;
      }
      if (block.feature_key == null || block.feature_key.trim().length === 0) {
        return true;
      }
      return canRenderFeature(config, block.feature_key, options);
    })
    .sort(
      (left, right) => (left.sort_order ?? 999) - (right.sort_order ?? 999),
    );
}

export function getFeatureKeyForPath(
  config: PlatformConfigSnapshot,
  pathname: string,
) {
  const normalizedPath = pathname.trim().toLowerCase() || "/";

  const registryMatch = config.route_registry
    .map((route) => ({
      featureKey: route.feature_key,
      pathPattern: route.path_pattern.trim().toLowerCase(),
    }))
    .filter((entry) => entry.pathPattern.startsWith("/"))
    .sort((left, right) => right.pathPattern.length - left.pathPattern.length)
    .find((entry) => {
      if (entry.pathPattern === normalizedPath) {
        return true;
      }
      return normalizedPath.startsWith(`${entry.pathPattern}/`);
    });

  if (registryMatch) {
    return registryMatch.featureKey;
  }

  const routeMatch = config.features
    .map((feature) => ({
      featureKey: feature.feature_key,
      routeKey: feature.channel?.route_key?.trim().toLowerCase() ?? "",
    }))
    .filter((entry) => entry.routeKey.startsWith("/"))
    .sort((left, right) => right.routeKey.length - left.routeKey.length)
    .find((entry) => {
      if (entry.routeKey === normalizedPath) {
        return true;
      }
      return normalizedPath.startsWith(`${entry.routeKey}/`);
    });

  if (routeMatch) {
    return routeMatch.featureKey;
  }

  const fallback = FALLBACK_ROUTE_FEATURE_KEYS.find(([prefix]) => {
    if (prefix === normalizedPath) {
      return true;
    }
    return normalizedPath.startsWith(`${prefix}/`);
  });

  return fallback?.[1] ?? null;
}

export function isRouteAvailable(
  config: PlatformConfigSnapshot,
  pathname: string,
  options?: FeatureAccessOptions,
) {
  const featureKey = getFeatureKeyForPath(config, pathname);
  if (!featureKey) {
    return true;
  }
  return canRenderFeature(config, featureKey, options);
}

export const getPlatformConfig = cache(
  async function getPlatformConfig(): Promise<PlatformConfigSnapshot> {
    try {
      const club = await getActiveClubReference();
      const supabase = getReadOnlySupabase();
      if (supabase == null) {
        return (
          getLastKnownConfig(club.numericId, "web") ??
          emptyConfigSnapshot("web")
        );
      }

      const rpcClient = supabase as unknown as {
        rpc: (
          name: string,
          params: Record<string, unknown>,
        ) => Promise<{ data: unknown; error: { message?: string } | null }>;
      };

      const { data, error } = await rpcClient.rpc("get_platform_config", {
        p_channel: "web",
        p_club_id: club.numericId,
      });

      if (error) {
        console.error("[feature-config] RPC error:", error.message);
        return (
          getLastKnownConfig(club.numericId, "web") ??
          emptyConfigSnapshot("web")
        );
      }

      const payload = (data as PlatformConfigSnapshot | null) ?? null;
      if (!payload) {
        return (
          getLastKnownConfig(club.numericId, "web") ??
          emptyConfigSnapshot("web")
        );
      }

      return rememberConfig(
        normalizePlatformConfigPayload(payload, club.numericId),
      );
    } catch (error) {
      console.error("[feature-config] Unexpected error:", error);
      try {
        const club = await getActiveClubReference();
        return (
          getLastKnownConfig(club.numericId, "web") ??
          emptyConfigSnapshot("web")
        );
      } catch {
        return emptyConfigSnapshot("web");
      }
    }
  },
);

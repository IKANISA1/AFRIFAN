import { getBrowserSupabase } from "./supabase/browser";

export interface PlatformFeatureConfig {
  feature_key: string;
  display_name: string;
  is_enabled: boolean;
  visibility_state: string;
  channel: {
    is_enabled: boolean;
    is_visible: boolean;
    show_in_navigation: boolean;
    show_on_home: boolean;
    route_key: string | null;
    placement_key: string | null;
    sort_order: number;
  };
  rules: {
    auth_required: boolean;
    role_restrictions: string[];
    dependency_rules: any;
    rollout_rules: any;
    is_within_schedule: boolean;
  } | null;
}

let cachedFeatures: PlatformFeatureConfig[] | null = null;
let lastFetch: number = 0;
const CACHE_TTL = 1000 * 60 * 5; // 5 minutes

export async function getActiveFeatures(channel: "web" | "mobile" = "web", clubId: number | null = null): Promise<PlatformFeatureConfig[]> {
  if (cachedFeatures && Date.now() - lastFetch < CACHE_TTL) {
    return cachedFeatures;
  }

  const supabase = getBrowserSupabase();
  if (supabase == null) {
    return cachedFeatures || [];
  }
  const { data, error } = await supabase.rpc("get_platform_config", {
    p_channel: channel,
    p_club_id: clubId,
  });

  if (error || !data) {
    console.error("Failed to load platform features:", error?.message);
    // Fallback gracefully
    return cachedFeatures || [];
  }

  const snapshot = data as any;
  cachedFeatures = snapshot.features as PlatformFeatureConfig[];
  lastFetch = Date.now();
  return cachedFeatures;
}

export async function isFeatureEnabled(featureKey: string, channel: "web" | "mobile" = "web", clubId: number | null = null): Promise<boolean> {
  const features = await getActiveFeatures(channel, clubId);
  const feature = features.find((f) => f.feature_key === featureKey);
  if (!feature) return false;
  return feature.is_enabled && (feature.channel?.is_enabled ?? false);
}

export async function isFeatureVisible(featureKey: string, channel: "web" | "mobile" = "web", clubId: number | null = null): Promise<boolean> {
  const features = await getActiveFeatures(channel, clubId);
  const feature = features.find((f) => f.feature_key === featureKey);
  if (!feature) return false;
  return (
    feature.is_enabled &&
    feature.visibility_state === "visible" &&
    (feature.channel?.is_enabled ?? false) &&
    (feature.channel?.is_visible ?? false) &&
    (feature.rules?.is_within_schedule ?? true)
  );
}

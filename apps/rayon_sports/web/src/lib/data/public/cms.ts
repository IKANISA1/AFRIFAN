/**
 * CMS data fetchers — dynamic content from home_banners, ai_content, app_config.
 *
 * All content previously hardcoded in content.ts now resolves from DB first,
 * with graceful fallbacks when tables are empty.
 */
import { cache } from "react";
import { getAdminSupabase } from "@/lib/supabase/admin";
import type { AppConfigEntry, CmsContent, HomeBanner } from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";

// ─── Mappers ─────────────────────────────────────────────

function mapHomeBanner(row: Record<string, unknown>): HomeBanner {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.title, ""),
    subtitle: safeString(row.subtitle, ""),
    badgeLabel: safeString(row.badge_label, ""),
    ctaLabel: safeString(row.cta_label, ""),
    route: safeString(row.route, "/"),
    imageUrl: safeString(row.image_url) || null,
    sortOrder: Number(row.sort_order ?? 0),
    isActive: row.is_active !== false,
  };
}

function mapCmsContent(row: Record<string, unknown>): CmsContent {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    contentType: safeString(row.content_type, "general"),
    title: safeString(row.title, ""),
    subtitle: safeString(row.subtitle, ""),
    body: safeString(row.body, ""),
    rationale: safeString(row.rationale, ""),
    iconEmoji: safeString(row.icon_emoji, ""),
    ctaAction: safeString(row.cta_action, ""),
    ctaLabel: safeString(row.cta_label, ""),
    sortOrder: Number(row.sort_order ?? 0),
    isActive: row.is_active !== false,
  };
}

function mapAppConfig(row: Record<string, unknown>): AppConfigEntry {
  return {
    key: safeString(row.key, ""),
    value: safeString(row.value, ""),
    description: safeString(row.description, ""),
    country: safeString(row.country, ""),
  };
}

// ─── Fetchers ────────────────────────────────────────────

export const getHomeBanners = cache(async function getHomeBanners(): Promise<HomeBanner[]> {
  const client = getAdminSupabase();
  if (client == null) return [];

  try {
    const { data } = await client
      .from("home_banners")
      .select("*")
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(10);

    if (!data || data.length === 0) return [];
    return data.map((row) => mapHomeBanner(row));
  } catch {
    return [];
  }
});

export const getCmsContent = cache(async function getCmsContent(
  contentType?: string,
): Promise<CmsContent[]> {
  const client = getAdminSupabase();
  if (client == null) return [];

  try {
    let query = client
      .from("ai_content")
      .select("*")
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(50);

    if (contentType) {
      query = query.eq("content_type", contentType);
    }

    const { data } = await query;
    if (!data || data.length === 0) return [];
    return data.map((row) => mapCmsContent(row));
  } catch {
    return [];
  }
});

export const getAppConfig = cache(async function getAppConfig(): Promise<
  Map<string, string>
> {
  const client = getAdminSupabase();
  if (client == null) return new Map();

  try {
    const { data } = await client
      .from("app_config")
      .select("*")
      .limit(100);

    if (!data || data.length === 0) return new Map();
    const mapped = data.map((row) => mapAppConfig(row));
    return new Map(mapped.map((entry) => [entry.key, entry.value]));
  } catch {
    return new Map();
  }
});

/**
 * Convenience: get a single CMS content block by type, returns first match or null.
 */
export const getCmsContentBlock = cache(async function getCmsContentBlock(
  contentType: string,
): Promise<CmsContent | null> {
  const items = await getCmsContent(contentType);
  return items.length > 0 ? items[0] : null;
});

/**
 * Convenience: get a config value by key with a default fallback.
 */
export async function getConfigValue(key: string, fallback: string = ""): Promise<string> {
  const config = await getAppConfig();
  return config.get(key) ?? fallback;
}

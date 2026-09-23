/**
 * CMS data fetchers — dynamic content from home_banners, ai_content, app_config.
 *
 * All content previously hardcoded in content.ts now resolves from DB first,
 * with graceful fallbacks when tables are empty.
 */
import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import type { AppConfigEntry, CmsContent, HomeBanner } from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";

type RuntimeConfigRpcClient = {
  rpc: (
    name: "get_runtime_app_config",
    params: { p_key: string | null; p_club_id: number },
  ) => Promise<{
    data: unknown;
    error: { message: string } | null;
  }>;
};

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
    distribution:
      safeString(row.distribution, "both") as HomeBanner["distribution"],
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
    distribution:
      safeString(row.distribution, "both") as CmsContent["distribution"],
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

async function getRuntimeAppConfigRows(clubId: number) {
  const client = getReadOnlySupabase();
  if (client == null) {
    return [] as AppConfigEntry[];
  }

  try {
    const { data, error } = await (
      client as unknown as RuntimeConfigRpcClient
    ).rpc("get_runtime_app_config", { p_key: null, p_club_id: clubId });
    if (error) throw new Error(error.message);

    if (!Array.isArray(data) || data.length === 0) {
      return [];
    }
    return data.map((row) => mapAppConfig(row as Record<string, unknown>));
  } catch {
    return [];
  }
}

// ─── Fetchers ────────────────────────────────────────────

export const getHomeBanners = cache(async function getHomeBanners(): Promise<HomeBanner[]> {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) return [];

  try {
    const { data } = await client
      .from("home_banners")
      .select(
        "id,title,subtitle,badge_label,cta_label,route,image_url,sort_order,is_active,created_at,updated_at,club_id,distribution",
      )
      .eq("club_id", activeClub.numericId)
      .eq("is_active", true)
      .order("sort_order", { ascending: true })
      .limit(10);

    if (!data || data.length === 0) return [];
    return data.map((row) => mapHomeBanner(row));
  } catch {
    return [];
  }
});

export const getCmsContentStrict = cache(async function getCmsContentStrict(
  contentType?: string,
): Promise<CmsContent[]> {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) return [];

  let query = client
    .from("ai_content")
    .select(
      "id,content_type,title,subtitle,body,icon_emoji,cta_action,cta_label," +
        "sort_order,status,is_active,club_id,distribution,updated_at",
    )
    .eq("club_id", activeClub.numericId)
    .eq("is_active", true)
    .order("sort_order", { ascending: true })
    .limit(50);

  if (contentType) {
    query = query.eq("content_type", contentType);
  }

  const { data, error } = await query;
  if (error) throw error;
  if (!data || data.length === 0) return [];
  return data.map((row) => mapCmsContent(row));
});

export const getCmsContent = cache(async function getCmsContent(
  contentType?: string,
): Promise<CmsContent[]> {
  try {
    return await getCmsContentStrict(contentType);
  } catch {
    return [];
  }
});

export const getAppConfig = cache(async function getAppConfig(): Promise<
  Map<string, string>
> {
  const activeClub = await getActiveClubReference();
  const entries = await getRuntimeAppConfigRows(activeClub.numericId);

  const merged = new Map<string, string>();
  for (const entry of entries) {
    merged.set(entry.key, entry.value);
  }
  return merged;
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

/**
 * Admin CMS — home banners, ai_content, and app_config CRUD.
 * These tables drive dynamic content across the public site and admin workflows.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import type { HomeBanner, CmsContent, AppConfigEntry } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import { requireAdminClubId } from "./helpers";

// ─── Home Banners ────────────────────────────────────────

function mapBanner(row: Record<string, unknown>): HomeBanner {
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
    distribution: (row.distribution as any) || "both",
  };
}

export async function getAdminBanners(client: SupabaseClient, _access: AdminAccess) {
  const clubId = requireAdminClubId(_access, "load home banners");
  const { data, error } = await client
    .from("home_banners")
    .select("*")
    .eq("club_id", clubId)
    .order("sort_order", { ascending: true });

  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => mapBanner(row as Record<string, unknown>));
}

export async function saveAdminBanner(
  client: SupabaseClient,
  _access: AdminAccess,
  input: {
    id?: string | null;
    title: string;
    subtitle?: string;
    badgeLabel?: string;
    ctaLabel?: string;
    route?: string;
    imageUrl?: string;
    sortOrder?: number;
    isActive?: boolean;
    distribution?: "web" | "app" | "both";
    },
    ) {
    const clubId = requireAdminClubId(_access, "save home banners");
    const payload: Record<string, unknown> = {
    club_id: clubId,
    title: input.title.trim(),
    subtitle: safeString(input.subtitle) || null,
    badge_label: safeString(input.badgeLabel) || null,
    cta_label: safeString(input.ctaLabel) || null,
    route: safeString(input.route, "/"),
    image_url: safeString(input.imageUrl) || null,
    sort_order: safeNumber(input.sortOrder, 0),
    is_active: input.isActive !== false,
    distribution: input.distribution || "both",
    };

  if (input.id) {
    const { error } = await client
      .from("home_banners")
      .update(payload)
      .eq("id", input.id)
      .eq("club_id", clubId);
    if (error) throw new Error(error.message);
    return input.id;
  }

  const { data, error } = await client.from("home_banners").insert(payload).select("id").single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminBanner(client: SupabaseClient, _access: AdminAccess, bannerId: string) {
  const clubId = requireAdminClubId(_access, "delete home banners");
  const { error } = await client
    .from("home_banners")
    .delete()
    .eq("id", bannerId)
    .eq("club_id", clubId);
  if (error) throw new Error(error.message);
}

// ─── AI Content Blocks ───────────────────────────────────

function mapContent(row: Record<string, unknown>): CmsContent {
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
    distribution: (row.distribution as any) || "both",
  };
}

export async function getAdminContentBlocks(client: SupabaseClient, _access: AdminAccess) {
  if (typeof window !== "undefined") {
    return requestAdminApi<CmsContent[]>("cms-content");
  }

  const clubId = requireAdminClubId(_access, "load CMS content blocks");
  const { data, error } = await client
    .from("ai_content")
    .select("*")
    .eq("club_id", clubId)
    .order("content_type", { ascending: true })
    .order("sort_order", { ascending: true });

  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => mapContent(row as Record<string, unknown>));
}

export async function saveAdminContentBlock(
  client: SupabaseClient,
  _access: AdminAccess,
  input: {
    id?: string | null;
    contentType: string;
    title: string;
    subtitle?: string;
    body?: string;
    rationale?: string;
    iconEmoji?: string;
    ctaAction?: string;
    ctaLabel?: string;
    sortOrder?: number;
    isActive?: boolean;
    distribution?: "web" | "app" | "both";
  },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("cms-content", {
      method: "POST",
      body: input,
    });
  }

  const clubId = requireAdminClubId(_access, "save CMS content blocks");
  const payload: Record<string, unknown> = {
    club_id: clubId,
    content_type: input.contentType.trim(),
    title: input.title.trim(),
    subtitle: safeString(input.subtitle) || null,
    body: safeString(input.body) || null,
    rationale: safeString(input.rationale) || null,
    icon_emoji: safeString(input.iconEmoji) || null,
    cta_action: safeString(input.ctaAction) || null,
    cta_label: safeString(input.ctaLabel) || null,
    sort_order: safeNumber(input.sortOrder, 0),
    is_active: input.isActive !== false,
    distribution: input.distribution || "both",
    status: "approved",
  };

  if (input.id) {
    const { error } = await client
      .from("ai_content")
      .update(payload)
      .eq("id", input.id)
      .eq("club_id", clubId);
    if (error) throw new Error(error.message);
    return input.id;
  }

  const { data, error } = await client.from("ai_content").insert(payload).select("id").single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminContentBlock(client: SupabaseClient, _access: AdminAccess, blockId: string) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("cms-content", {
      method: "DELETE",
      query: { id: blockId },
    });
    return;
  }

  const clubId = requireAdminClubId(_access, "delete CMS content blocks");
  const { error } = await client
    .from("ai_content")
    .delete()
    .eq("id", blockId)
    .eq("club_id", clubId);
  if (error) throw new Error(error.message);
}

// ─── App Config ──────────────────────────────────────────

function mapConfig(row: Record<string, unknown>): AppConfigEntry {
  return {
    key: safeString(row.key, ""),
    value: safeString(row.value, ""),
    description: safeString(row.description, ""),
    country: safeString(row.country, ""),
  };
}

export async function getAdminAppConfig(client: SupabaseClient, _access: AdminAccess) {
  if (typeof window !== "undefined") {
    return requestAdminApi<AppConfigEntry[]>("cms-config");
  }

  const clubId = requireAdminClubId(_access, "load app configuration");
  const { data, error } = await client
    .from("club_app_config")
    .select("*")
    .eq("club_id", clubId)
    .order("key", { ascending: true });

  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => mapConfig(row as Record<string, unknown>));
}

export async function saveAdminConfigEntry(
  client: SupabaseClient,
  _access: AdminAccess,
  input: { key: string; value: string; description?: string; country?: string },
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<string>("cms-config", {
      method: "POST",
      body: input,
    });
    return;
  }

  const clubId = requireAdminClubId(_access, "save app configuration");
  const payload = {
    club_id: clubId,
    key: input.key.trim(),
    value: input.value,
    description: safeString(input.description) || null,
    country: safeString(input.country) || null,
  };

  const { error } = await client
    .from("club_app_config")
    .upsert(payload, { onConflict: "club_id,key" });

  if (error) throw new Error(error.message);
}

export async function deleteAdminConfigEntry(client: SupabaseClient, _access: AdminAccess, key: string) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("cms-config", {
      method: "DELETE",
      query: { id: key },
    });
    return;
  }

  const clubId = requireAdminClubId(_access, "delete app configuration");
  const { error } = await client
    .from("club_app_config")
    .delete()
    .eq("club_id", clubId)
    .eq("key", key);
  if (error) throw new Error(error.message);
}

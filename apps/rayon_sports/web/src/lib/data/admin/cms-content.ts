/**
 * Admin CMS — home banners, ai_content, and app_config CRUD.
 * These tables drive all dynamic content across public site and fan portal.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import type { HomeBanner, CmsContent, AppConfigEntry } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
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
  };
}

export async function getAdminBanners(client: SupabaseClient, _access: AdminAccess) {
  const { data, error } = await client
    .from("home_banners")
    .select("*")
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
  },
) {
  const payload: Record<string, unknown> = {
    title: input.title.trim(),
    subtitle: safeString(input.subtitle) || null,
    badge_label: safeString(input.badgeLabel) || null,
    cta_label: safeString(input.ctaLabel) || null,
    route: safeString(input.route, "/"),
    image_url: safeString(input.imageUrl) || null,
    sort_order: safeNumber(input.sortOrder, 0),
    is_active: input.isActive !== false,
  };

  if (input.id) {
    const { error } = await client.from("home_banners").update(payload).eq("id", input.id);
    if (error) throw new Error(error.message);
    return input.id;
  }

  const { data, error } = await client.from("home_banners").insert(payload).select("id").single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminBanner(client: SupabaseClient, _access: AdminAccess, bannerId: string) {
  const { error } = await client.from("home_banners").delete().eq("id", bannerId);
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
  };
}

export async function getAdminContentBlocks(client: SupabaseClient, _access: AdminAccess) {
  const { data, error } = await client
    .from("ai_content")
    .select("*")
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
  },
) {
  const payload: Record<string, unknown> = {
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
    status: "approved",
  };

  if (input.id) {
    const { error } = await client.from("ai_content").update(payload).eq("id", input.id);
    if (error) throw new Error(error.message);
    return input.id;
  }

  const { data, error } = await client.from("ai_content").insert(payload).select("id").single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminContentBlock(client: SupabaseClient, _access: AdminAccess, blockId: string) {
  const { error } = await client.from("ai_content").delete().eq("id", blockId);
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
  const { data, error } = await client
    .from("app_config")
    .select("*")
    .order("key", { ascending: true });

  if (error) throw new Error(error.message);
  return (data ?? []).map((row) => mapConfig(row as Record<string, unknown>));
}

export async function saveAdminConfigEntry(
  client: SupabaseClient,
  _access: AdminAccess,
  input: { key: string; value: string; description?: string; country?: string },
) {
  const payload = {
    key: input.key.trim(),
    value: input.value,
    description: safeString(input.description) || null,
    country: safeString(input.country) || null,
  };

  const { error } = await client
    .from("app_config")
    .upsert(payload, { onConflict: "key" });

  if (error) throw new Error(error.message);
}

export async function deleteAdminConfigEntry(client: SupabaseClient, _access: AdminAccess, key: string) {
  const { error } = await client.from("app_config").delete().eq("key", key);
  if (error) throw new Error(error.message);
}

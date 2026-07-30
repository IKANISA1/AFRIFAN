/**
 * Admin CMS — home banners, ai_content, and app_config CRUD.
 * These tables drive dynamic content across the public site and admin workflows.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import type {
  HomeBanner,
  CmsContent,
  AppConfigEntry,
  CmsContentType,
} from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

type ContentDistribution = HomeBanner["distribution"];

function mapDistribution(value: unknown): ContentDistribution {
  return value === "web" || value === "app" || value === "both"
    ? value
    : "both";
}

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return null;
  }
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function boundedOptionalText(value: unknown, maxLength: number) {
  if (value == null || value === "") {
    return "";
  }
  return boundedText(value, maxLength);
}

function boundedInteger(value: unknown, minimum: number, maximum: number) {
  return typeof value === "number" &&
    Number.isInteger(value) &&
    value >= minimum &&
    value <= maximum
    ? value
    : null;
}

function boundedDate(value: unknown) {
  const text = boundedText(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function boundedImageUrl(value: unknown) {
  if (value == null || value === "") {
    return null;
  }
  const text = boundedText(value, 2_048);
  if (text == null) {
    return null;
  }
  if (text.startsWith("/") && !text.startsWith("//")) {
    return text;
  }
  try {
    const url = new URL(text);
    return url.protocol === "https:" ? url.toString() : null;
  } catch {
    return null;
  }
}

function boundedInternalRoute(value: unknown) {
  const route = boundedText(value, 512);
  return route != null && route.startsWith("/") && !route.startsWith("//")
    ? route
    : null;
}

function boundedDistribution(value: unknown): ContentDistribution | null {
  return value === "web" || value === "app" || value === "both" ? value : null;
}

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
    distribution: mapDistribution(row.distribution),
    updatedAt: safeString(row.updated_at),
  };
}

export function normalizeAdminBanners(value: unknown): HomeBanner[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const record = entry as Record<string, unknown>;
    const id = boundedText(record.id, 128);
    const title = boundedText(record.title, 200);
    const subtitle = boundedOptionalText(record.subtitle, 400);
    const badgeLabel = boundedOptionalText(record.badgeLabel, 40);
    const ctaLabel = boundedOptionalText(record.ctaLabel, 80);
    const route = boundedInternalRoute(record.route);
    const imageUrl = boundedImageUrl(record.imageUrl);
    const sortOrder = boundedInteger(record.sortOrder, -10_000, 10_000);
    const updatedAt = boundedDate(record.updatedAt);
    const distribution =
      record.distribution === "web" ||
      record.distribution === "app" ||
      record.distribution === "both"
        ? record.distribution
        : null;

    if (
      id == null ||
      title == null ||
      subtitle == null ||
      badgeLabel == null ||
      ctaLabel == null ||
      route == null ||
      sortOrder == null ||
      typeof record.isActive !== "boolean" ||
      distribution == null ||
      updatedAt == null
    ) {
      return [];
    }

    return [
      {
        id,
        title,
        subtitle,
        badgeLabel,
        ctaLabel,
        route,
        imageUrl,
        sortOrder,
        isActive: record.isActive,
        distribution,
        updatedAt,
      },
    ];
  });
}

export async function getAdminBanners(
  client: SupabaseClient,
  _access: AdminAccess,
  options: { signal?: AbortSignal } = {},
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<HomeBanner[]>("cms-banners", {
      signal: options.signal,
    });
  }
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
    expectedUpdatedAt?: string | null;
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
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("cms-banners", {
      method: "POST",
      body: input,
    });
  }
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
    return mutateRecordWithVariantsIfUnchanged(
      client,
      "home_banners",
      input.id,
      input.expectedUpdatedAt,
      [payload],
      { club_id: clubId },
    );
  }

  const { data, error } = await client
    .from("home_banners")
    .insert(payload)
    .select("id")
    .single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminBanner(
  client: SupabaseClient,
  _access: AdminAccess,
  bannerId: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("cms-banners", {
      method: "DELETE",
      query: { id: bannerId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }
  const clubId = requireAdminClubId(_access, "delete home banners");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    "home_banners",
    bannerId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: _access.userId,
      clubId,
      action: "delete_home_banner",
      source: "admin_cms_banners",
    },
  );
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
    distribution: mapDistribution(row.distribution),
    updatedAt: safeString(row.updated_at),
  };
}

function mapContentType(row: Record<string, unknown>): CmsContentType {
  return {
    contentType: safeString(row.content_type, "general"),
    label: safeString(row.label, safeString(row.content_type, "General")),
    description: row.description == null ? null : safeString(row.description),
    defaultDistribution: mapDistribution(row.default_distribution),
    sortOrder: safeNumber(row.sort_order, 0),
    isActive: row.is_active !== false,
  };
}

export function normalizeAdminContentTypes(value: unknown): CmsContentType[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 100).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const record = entry as Record<string, unknown>;
    const contentType = boundedText(record.contentType, 160);
    const label = boundedText(record.label, 200);
    const description =
      record.description == null
        ? null
        : boundedOptionalText(record.description, 500);
    const defaultDistribution = boundedDistribution(record.defaultDistribution);
    const sortOrder = boundedInteger(record.sortOrder, -10_000, 10_000);

    if (
      contentType == null ||
      label == null ||
      (record.description != null && description == null) ||
      defaultDistribution == null ||
      sortOrder == null ||
      typeof record.isActive !== "boolean"
    ) {
      return [];
    }

    return {
      contentType,
      label,
      description,
      defaultDistribution,
      sortOrder,
      isActive: record.isActive,
    };
  });
}

export function normalizeAdminContentBlocks(value: unknown): CmsContent[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const record = entry as Record<string, unknown>;
    const id = boundedText(record.id, 128);
    const contentType = boundedText(record.contentType, 160);
    const title = boundedText(record.title, 200);
    const subtitle = boundedOptionalText(record.subtitle, 400);
    const body = boundedOptionalText(record.body, 12_000);
    const rationale = boundedOptionalText(record.rationale, 1_000);
    const iconEmoji = boundedOptionalText(record.iconEmoji, 32);
    const ctaAction = boundedOptionalText(record.ctaAction, 512);
    const ctaLabel = boundedOptionalText(record.ctaLabel, 80);
    const sortOrder = boundedInteger(record.sortOrder, -10_000, 10_000);
    const distribution = boundedDistribution(record.distribution);
    const updatedAt = boundedDate(record.updatedAt);

    if (
      id == null ||
      contentType == null ||
      title == null ||
      subtitle == null ||
      body == null ||
      rationale == null ||
      iconEmoji == null ||
      ctaAction == null ||
      ctaLabel == null ||
      sortOrder == null ||
      distribution == null ||
      updatedAt == null ||
      typeof record.isActive !== "boolean"
    ) {
      return [];
    }

    return {
      id,
      contentType,
      title,
      subtitle,
      body,
      rationale,
      iconEmoji,
      ctaAction,
      ctaLabel,
      sortOrder,
      isActive: record.isActive,
      distribution,
      updatedAt,
    };
  });
}

export async function getAdminContentTypes(
  client: SupabaseClient,
  _access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<CmsContentType[]> {
  void _access;

  if (typeof window !== "undefined") {
    return requestAdminApi<CmsContentType[]>("cms-content-types", {
      signal: options.signal,
    });
  }

  const { data, error } = await client.rpc("get_platform_content_types", {
    p_include_inactive: true,
  });

  if (error) throw new Error(error.message);
  return ((data ?? []) as Record<string, unknown>[]).map((row) =>
    mapContentType(row),
  );
}

export async function getAdminContentBlocks(
  client: SupabaseClient,
  _access: AdminAccess,
  options: { signal?: AbortSignal } = {},
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<CmsContent[]>("cms-content", {
      signal: options.signal,
    });
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
    expectedUpdatedAt?: string | null;
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
    return mutateRecordWithVariantsIfUnchanged(
      client,
      "ai_content",
      input.id,
      input.expectedUpdatedAt,
      [payload],
      { club_id: clubId },
    );
  }

  const { data, error } = await client
    .from("ai_content")
    .insert(payload)
    .select("id")
    .single();
  if (error) throw new Error(error.message);
  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminContentBlock(
  client: SupabaseClient,
  _access: AdminAccess,
  blockId: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("cms-content", {
      method: "DELETE",
      query: { id: blockId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }

  const clubId = requireAdminClubId(_access, "delete CMS content blocks");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    "ai_content",
    blockId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: _access.userId,
      clubId,
      action: "delete_cms_content",
      source: "admin_cms_content",
    },
  );
}

// ─── App Config ──────────────────────────────────────────

function mapConfig(row: Record<string, unknown>): AppConfigEntry {
  return {
    id: toIdString(row.id, ""),
    key: safeString(row.key, ""),
    value: safeString(row.value, ""),
    description: safeString(row.description, ""),
    country: safeString(row.country, ""),
    updatedAt: safeString(row.updated_at),
  };
}

export function normalizeAdminAppConfig(value: unknown): AppConfigEntry[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const record = entry as Record<string, unknown>;
    const id = boundedText(record.id, 128);
    const key = boundedText(record.key, 160);
    const configValue = boundedOptionalText(record.value, 4_000);
    const description = boundedOptionalText(record.description, 500);
    const country = boundedOptionalText(record.country, 32);
    const updatedAt = boundedDate(record.updatedAt);

    if (
      id == null ||
      key == null ||
      configValue == null ||
      description == null ||
      country == null ||
      updatedAt == null
    ) {
      return [];
    }

    return {
      id,
      key,
      value: configValue,
      description,
      country,
      updatedAt,
    };
  });
}

export async function getAdminAppConfig(
  client: SupabaseClient,
  _access: AdminAccess,
  options: { signal?: AbortSignal } = {},
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<AppConfigEntry[]>("cms-config", {
      signal: options.signal,
    });
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
  input: {
    id?: string | null;
    expectedUpdatedAt?: string | null;
    key: string;
    value: string;
    description?: string;
    country?: string;
  },
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

  await mutateRecordWithVariantsIfUnchanged(
    client,
    "club_app_config",
    input.id,
    input.expectedUpdatedAt,
    [payload],
    { club_id: clubId },
  );
}

export async function deleteAdminConfigEntry(
  client: SupabaseClient,
  _access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("cms-config", {
      method: "DELETE",
      query: { id, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }

  const clubId = requireAdminClubId(_access, "delete app configuration");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    "club_app_config",
    id,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: _access.userId,
      clubId,
      action: "delete_app_config",
      source: "admin_cms_config",
    },
  );
}

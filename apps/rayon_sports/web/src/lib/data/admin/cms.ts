/**
 * Admin CMS — news article CRUD operations.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { fallbackClubProfile } from "@/lib/content";
import type { AdminAccess, AdminNewsArticle } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
  resolveNewsTable,
} from "./helpers";

function mapNewsArticle(row: Record<string, unknown>): AdminNewsArticle {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId:
      row.club_id == null ? null : safeNumber(row.club_id, fallbackClubProfile.id),
    title: safeString(row.title, "Untitled article"),
    subtitle: safeString(row.subtitle) || null,
    excerpt:
      safeString(row.excerpt) ||
      safeString(row.summary) ||
      safeString(row.body).slice(0, 140),
    body: safeString(row.body, safeString(row.content)),
    category: safeString(row.category, "News"),
    imageUrl:
      safeString(row.image_url) || safeString(row.cover_image_url) || null,
    isPublished: row.is_published === true,
    isFeatured: row.is_featured === true,
    sortOrder: safeNumber(row.sort_order, 0),
    publishedAt: safeString(row.published_at) || null,
    createdAt: safeString(row.created_at, new Date().toISOString()),
    updatedAt: safeString(row.updated_at, new Date(0).toISOString()),
  };
}

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return null;
  }
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
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

export function normalizeAdminArticles(value: unknown): AdminNewsArticle[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const record = entry as Record<string, unknown>;
    const id = boundedText(record.id, 128);
    const clubId =
      record.clubId == null
        ? null
        : boundedInteger(record.clubId, 1, 1_000_000_000);
    const title = boundedText(record.title, 200);
    const subtitle =
      record.subtitle == null ? null : boundedText(record.subtitle, 400);
    const excerpt = boundedText(record.excerpt, 1_000);
    const body = boundedText(record.body, 12_000);
    const category = boundedText(record.category, 80);
    const imageUrl = boundedImageUrl(record.imageUrl);
    const sortOrder = boundedInteger(record.sortOrder, -10_000, 10_000);
    const publishedAt =
      record.publishedAt == null ? null : boundedDate(record.publishedAt);
    const createdAt = boundedDate(record.createdAt);
    const updatedAt = boundedDate(record.updatedAt);

    if (
      id == null ||
      (record.clubId != null && clubId == null) ||
      title == null ||
      (record.subtitle != null && subtitle == null) ||
      excerpt == null ||
      body == null ||
      category == null ||
      typeof record.isPublished !== "boolean" ||
      typeof record.isFeatured !== "boolean" ||
      sortOrder == null ||
      (record.publishedAt != null && publishedAt == null) ||
      createdAt == null ||
      updatedAt == null
    ) {
      return [];
    }

    return [{
      id,
      clubId,
      title,
      subtitle,
      excerpt,
      body,
      category,
      imageUrl,
      isPublished: record.isPublished,
      isFeatured: record.isFeatured,
      sortOrder,
      publishedAt,
      createdAt,
      updatedAt,
    }];
  });
}

export async function getAdminArticles(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminNewsArticle[]>("cms", {
      signal: options.signal,
    });
  }
  const clubId = requireAdminClubId(access, "load articles");
  const table = await resolveNewsTable(client);
  const { data, error } = await client
    .from(table)
    .select("*")
    .eq("club_id", clubId)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data)
    ? data.map((row) => mapNewsArticle(row as Record<string, unknown>))
    : [];
}

export async function saveAdminArticle(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    expectedUpdatedAt?: string | null;
    title: string;
    subtitle?: string;
    excerpt?: string;
    body: string;
    category?: string;
    imageUrl?: string;
    isPublished?: boolean;
    isFeatured?: boolean;
    sortOrder?: number;
  },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("cms", {
      method: "POST",
      body: input,
    });
  }
  const clubId = requireAdminClubId(access, "save articles");
  const table = await resolveNewsTable(client);
  const now = new Date().toISOString();
  const payload = {
    club_id: clubId,
    title: input.title.trim(),
    subtitle: safeString(input.subtitle) || null,
    body: input.body.trim(),
    category: safeString(input.category, "News"),
    image_url: safeString(input.imageUrl) || null,
    is_published: input.isPublished === true,
    is_featured: input.isFeatured === true,
    sort_order: safeNumber(input.sortOrder, 0),
    published_at: input.isPublished ? now : null,
  };

  if (input.id) {
    return mutateRecordWithVariantsIfUnchanged(client, table, input.id, input.expectedUpdatedAt, [payload], {
      club_id: clubId,
    });
  }

  const { data, error } = await client
    .from(table)
    .insert(payload)
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminArticle(
  client: SupabaseClient,
  access: AdminAccess,
  articleId: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("cms", {
      method: "DELETE",
      query: { id: articleId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete articles");
  const table = await resolveNewsTable(client);
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    table,
    articleId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_article",
      source: "admin_cms",
    },
  );
}

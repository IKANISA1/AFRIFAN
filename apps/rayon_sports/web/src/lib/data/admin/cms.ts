/**
 * Admin CMS — news article CRUD operations.
 * Extracted from admin-legacy.ts for focused domain ownership.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import type { AdminAccess, AdminNewsArticle } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { resolveNewsTable } from "./helpers";

function mapNewsArticle(row: Record<string, unknown>): AdminNewsArticle {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId:
      row.club_id == null ? null : safeNumber(row.club_id, rayonClub.numericId),
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
  };
}

export async function getAdminArticles(client: SupabaseClient) {
  const table = await resolveNewsTable(client);
  const { data, error } = await client
    .from(table)
    .select("*")
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
  const table = await resolveNewsTable(client);
  const now = new Date().toISOString();
  const payload = {
    club_id: safeNumber(access.clubId, rayonClub.numericId),
    title: input.title.trim(),
    subtitle: safeString(input.subtitle) || null,
    excerpt: safeString(input.excerpt) || safeString(input.body).slice(0, 140),
    body: input.body.trim(),
    category: safeString(input.category, "News"),
    image_url: safeString(input.imageUrl) || null,
    is_published: input.isPublished === true,
    is_featured: input.isFeatured === true,
    sort_order: safeNumber(input.sortOrder, 0),
    published_at: input.isPublished ? now : null,
  };

  if (input.id) {
    const { error } = await client.from(table).update(payload).eq("id", input.id);
    if (error) {
      throw new Error(error.message);
    }
    return input.id;
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
  articleId: string,
) {
  const table = await resolveNewsTable(client);
  const { error } = await client.from(table).delete().eq("id", articleId);
  if (error) {
    throw new Error(error.message);
  }
}

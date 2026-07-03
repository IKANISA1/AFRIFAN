/**
 * Public news articles data.
 */
import { cache } from "react";
import { getActiveClubReference } from "@/lib/club-context";
import { fallbackNewsArticles } from "@/lib/content";
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import type { NewsArticle } from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { newsTableCandidates, resolveAccessibleTable, sanitizeMediaUrl } from "./helpers";

function mapNewsRow(row: Record<string, unknown>): NewsArticle {
  const rawContent =
    safeString(row.content) ||
    safeString(row.body) ||
    safeString(row.summary) ||
    safeString(row.excerpt);

  const content = rawContent || "No detailed content available for this update.";
  
  const excerptCandidate =
    safeString(row.excerpt) ||
    safeString(row.summary) ||
    (rawContent ? safeString(rawContent).replace(/\s+/g, " ").slice(0, 180).trim() : null);

  return {
    id:
      safeString(row.slug) ||
      safeString(row.article_id) ||
      toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.title, "Club Update"),
    excerpt: excerptCandidate || "Official club update from Gikundiro Media.",
    content,
    category: safeString(row.category, "General"),
    coverImageUrl: sanitizeMediaUrl(
      safeString(row.cover_image_url) || safeString(row.image_url),
      "/brand-surface.svg",
    ),
    publishedAt: safeString(
      row.published_at,
      safeString(row.created_at, new Date().toISOString()),
    ),
    author: safeString(row.author_name, "Gikundiro Media"),
  };
}

export const getNewsArticles = cache(async function getNewsArticles() {
  const client = getReadOnlySupabase();
  const activeClub = await getActiveClubReference();
  if (client == null) return fallbackNewsArticles;

  try {
    const table = await resolveAccessibleTable(client, newsTableCandidates);
    const { data } = await client
      .from(table)
      .select("*")
      .eq("club_id", activeClub.numericId)
      .eq("is_published", true)
      .order("published_at", { ascending: false })
      .limit(12);

    if (!data || data.length == 0) return fallbackNewsArticles;
    return data.map((row) => mapNewsRow(row));
  } catch {
    return fallbackNewsArticles;
  }
});

export const getNewsArticleById = cache(async function getNewsArticleById(articleId: string) {
  const articles = await getNewsArticles();
  return articles.find((article) => article.id === articleId) ?? null;
});

/**
 * Public news articles data.
 */
import { cache } from "react";
import { rayonClub } from "@/lib/config";
import { fallbackNewsArticles } from "@/lib/content";
import { getAdminSupabase } from "@/lib/supabase/admin";
import type { NewsArticle } from "@/lib/types";
import { safeString, toIdString } from "@/lib/utils";
import { newsTableCandidates, resolveAccessibleTable, sanitizeMediaUrl } from "./helpers";

function mapNewsRow(row: Record<string, unknown>): NewsArticle {
  const content =
    safeString(row.content) ||
    safeString(row.body) ||
    safeString(row.summary) ||
    safeString(row.excerpt) ||
    "Club article body not available yet.";
  const excerptCandidate =
    safeString(row.excerpt) ||
    safeString(row.summary) ||
    safeString(content)
      .replace(/\s+/g, " ")
      .slice(0, 180)
      .trim();

  return {
    id:
      safeString(row.slug) ||
      safeString(row.article_id) ||
      toIdString(row.id, crypto.randomUUID()),
    title: safeString(row.title, "Club update"),
    excerpt: excerptCandidate || "Rayon Sports club update.",
    content,
    category: safeString(row.category, "Club"),
    coverImageUrl: sanitizeMediaUrl(
      safeString(row.cover_image_url) || safeString(row.image_url),
      "/media/stadium-hero.jpg",
    ),
    publishedAt: safeString(
      row.published_at,
      safeString(row.created_at, new Date().toISOString()),
    ),
    author: safeString(row.author_name, "Club Media"),
  };
}

export const getNewsArticles = cache(async function getNewsArticles() {
  const client = getAdminSupabase();
  if (client == null) return fallbackNewsArticles;

  try {
    const table = await resolveAccessibleTable(client, newsTableCandidates);
    const { data } = await client
      .from(table)
      .select("*")
      .eq("club_id", rayonClub.numericId)
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

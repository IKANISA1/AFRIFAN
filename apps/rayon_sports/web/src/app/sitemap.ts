import type { MetadataRoute } from "next";
import { absoluteUrl } from "@/lib/config";
import { getActiveClubReference } from "@/lib/club-context";
import { getReadOnlySupabase } from "@/lib/supabase/admin";

/**
 * Dynamic sitemap — pulls live routes from DB and omits mutable content when DB is unavailable.
 */
export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const activeClub = await getActiveClubReference();
  const staticRoutes = [
    "",
    "/news",
    "/fixtures",
    "/results",
    "/standings",
    "/squad",
    "/tickets",
    "/shop",
    "/membership",
    "/supporters",
    "/Groups",
    "/fan-clubs",
    "/history",
    "/contact",
    "/privacy",
    "/terms",
    "/support",
    "/account-deletion",
  ];

  const entries: MetadataRoute.Sitemap = staticRoutes.map((route) => ({
    url: absoluteUrl(route || "/"),
    lastModified: new Date(),
    changeFrequency: route === "" ? ("daily" as const) : ("weekly" as const),
    priority: route === "" ? 1.0 : route === "/news" ? 0.9 : 0.7,
  }));

  const client = getReadOnlySupabase();

  if (client) {
    try {
      const [articlesRes, productsRes, matchesRes] = await Promise.all([
        client
          .from("news_articles")
          .select("id, published_at")
          .eq("club_id", activeClub.numericId)
          .eq("status", "published")
          .order("published_at", { ascending: false })
          .limit(50),
        client
          .from("shop_products")
          .select("id, updated_at")
          .eq("club_id", activeClub.numericId)
          .eq("is_active", true)
          .limit(50),
        client
          .from("matches")
          .select("id, match_date")
          .eq("club_id", activeClub.numericId)
          .order("match_date", { ascending: false })
          .limit(30),
      ]);

      type IdRow = { id: unknown; [k: string]: unknown };
      const articleRows = (articlesRes.data ?? []) as IdRow[];
      const productRows = (productsRes.data ?? []) as IdRow[];
      const matchRows = (matchesRes.data ?? []) as IdRow[];

      for (const row of articleRows) {
        entries.push({
          url: absoluteUrl(`/news/${row.id}`),
          lastModified: new Date(
            String(row.published_at ?? new Date().toISOString()),
          ),
          changeFrequency: "weekly",
          priority: 0.8,
        });
      }

      for (const row of productRows) {
        entries.push({
          url: absoluteUrl(`/shop/${row.id}`),
          lastModified: new Date(
            String(row.updated_at ?? new Date().toISOString()),
          ),
          changeFrequency: "weekly",
          priority: 0.6,
        });
      }

      for (const row of matchRows) {
        entries.push({
          url: absoluteUrl(`/fixtures/${row.id}`),
          lastModified: new Date(
            String(row.match_date ?? new Date().toISOString()),
          ),
          changeFrequency: "daily",
          priority: 0.7,
        });
      }
    } catch {
      return entries;
    }
  }

  return entries;
}

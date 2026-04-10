/**
 * Shared helpers for public data modules.
 */
import { getReadOnlySupabase } from "@/lib/supabase/admin";
import { safeString } from "@/lib/utils";

export type PublicClient = NonNullable<ReturnType<typeof getReadOnlySupabase>>;

const accessibleTableCache = new Map<string, Promise<string>>();

export async function resolveAccessibleTable(
  client: PublicClient,
  candidates: string[],
) {
  const cacheKey = candidates.join("|");
  const cached = accessibleTableCache.get(cacheKey);
  if (cached) {
    return cached;
  }

  const lookup = (async () => {
    for (const table of candidates) {
      const { error } = await client.from(table).select("id").limit(1);
      if (!error) {
        return table;
      }
    }

    return candidates[0];
  })();

  accessibleTableCache.set(cacheKey, lookup);
  return lookup;
}

export function sanitizeMediaUrl(value: unknown, fallback: string) {
  const candidate = safeString(value);
  if (!candidate) {
    return fallback;
  }

  if (candidate.startsWith("/")) {
    return candidate;
  }

  try {
    const parsed = new URL(candidate);
    if (parsed.hostname.endsWith(".supabase.co")) {
      return candidate;
    }
  } catch {}

  return fallback;
}

export const newsTableCandidates = ["news_articles", "rs_news_articles"];
export const productTableCandidates = ["shop_products", "rs_shop_products"];
export const squadTableCandidates = [
  "squad_players",
  "players",
  "club_players",
  "rs_squad_players",
];
export const standingsTableCandidates = [
  "standings",
  "league_standings",
  "club_standings",
  "rs_standings",
];

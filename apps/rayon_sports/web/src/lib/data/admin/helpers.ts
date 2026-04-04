/**
 * Shared helpers used across all admin data modules.
 * Extracted from the monolithic admin.ts for reuse.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import type { AdminAccess } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";

export { rayonClub, safeNumber, safeString, toIdString };

/* ────────────────────────────────────────────────────────── */
/*  Table resolution helpers                                  */
/* ────────────────────────────────────────────────────────── */

export const newsTableCandidates = ["news_articles", "rs_news_articles"];
export const productTableCandidates = ["shop_products", "rs_shop_products"];
export const standingsTableCandidates = [
  "standings",
  "league_standings",
  "club_standings",
  "rs_standings",
];
export const squadTableCandidates = [
  "squad_players",
  "players",
  "club_players",
  "rs_squad_players",
];
export const membershipTable = "membership_packages";
export const fanClubTable = "fan_clubs";
export const clubTable = "african_football_clubs";
export const contributionTable = "contribution_groups";

export async function resolveAccessibleTable(
  client: SupabaseClient,
  candidates: string[],
) {
  for (const table of candidates) {
    const { error } = await client.from(table).select("id").limit(1);
    if (!error) {
      return table;
    }
  }
  return candidates[0];
}

export async function resolveNewsTable(client: SupabaseClient) {
  return resolveAccessibleTable(client, newsTableCandidates);
}

export async function resolveProductTable(client: SupabaseClient) {
  return resolveAccessibleTable(client, productTableCandidates);
}

export async function resolveStandingsTable(client: SupabaseClient) {
  return resolveAccessibleTable(client, standingsTableCandidates);
}

export async function resolveSquadTable(client: SupabaseClient) {
  return resolveAccessibleTable(client, squadTableCandidates);
}

export async function resolveExistingColumn(
  client: SupabaseClient,
  table: string,
  candidates: string[],
) {
  for (const column of candidates) {
    const { error } = await client.from(table).select(column).limit(1);
    if (!error) {
      return column;
    }
  }
  return candidates[0] ?? null;
}

export async function hasColumn(
  client: SupabaseClient,
  table: string,
  column: string,
) {
  const { error } = await client.from(table).select(column).limit(1);
  return !error;
}

export function hasMissingColumnError(error: unknown, column: string) {
  if (error == null || typeof error !== "object") {
    return false;
  }
  const message = safeString(
    (error as { message?: unknown }).message,
  ).toLowerCase();
  return (
    message.includes(column.toLowerCase()) && message.includes("column")
  );
}

export async function safeCount(
  request: PromiseLike<{
    count: number | null;
    error: { message?: string } | null;
  }>,
) {
  const { count, error } = await request;
  if (error) {
    return 0;
  }
  return count ?? 0;
}

export async function mutateRecordWithVariants(
  client: SupabaseClient,
  table: string,
  id: string | null | undefined,
  payloadVariants: Array<Record<string, unknown>>,
  matchers: Record<string, unknown> = {},
) {
  let lastError: { message?: string } | null = null;

  for (const payload of payloadVariants) {
    if (id) {
      let query = client.from(table).update(payload);
      for (const [column, value] of Object.entries(matchers)) {
        query = query.eq(column, value);
      }
      const response = await query.eq("id", id);
      if (!response.error) {
        return id;
      }
      lastError = response.error;
      continue;
    }

    const response = await client
      .from(table)
      .insert(payload)
      .select("id")
      .single();
    if (!response.error) {
      return toIdString(response.data?.id, crypto.randomUUID());
    }
    lastError = response.error;
  }

  throw new Error(lastError?.message ?? "Could not save record.");
}

export async function deleteRecordWithMatchers(
  client: SupabaseClient,
  table: string,
  id: string,
  matchers: Record<string, unknown> = {},
) {
  let query = client.from(table).delete();
  for (const [column, value] of Object.entries(matchers)) {
    query = query.eq(column, value);
  }
  const { error } = await query.eq("id", id);
  if (error) {
    throw new Error(error.message);
  }
}

export function adminClubIdOrNull(access: Pick<AdminAccess, "clubId">) {
  if (access.clubId == null || safeString(access.clubId).length === 0) {
    return null;
  }
  const clubId = safeNumber(access.clubId, Number.NaN);
  return Number.isFinite(clubId) ? clubId : null;
}

export function requireAdminClubId(
  access: Pick<AdminAccess, "clubId">,
  action = "complete this admin action",
) {
  const clubId = adminClubIdOrNull(access);
  if (clubId == null) {
    throw new Error(`Club context is required to ${action}.`);
  }
  return clubId;
}

export function metadataSnippet(value: unknown) {
  if (typeof value === "string" && value.trim()) {
    return value.trim();
  }
  if (typeof value === "object" && value != null) {
    const pairs = Object.entries(value as Record<string, unknown>)
      .slice(0, 2)
      .map(([key, item]) => `${key}: ${String(item)}`);
    return pairs.join(" • ");
  }
  return "Recorded by admin workflow.";
}

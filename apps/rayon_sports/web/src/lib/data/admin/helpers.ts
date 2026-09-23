/**
 * Shared helpers used across all admin data modules.
 * Extracted from the monolithic admin.ts for reuse.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";

export { safeNumber, safeString, toIdString };

export class AdminMutationAuthorizationError extends Error {
  readonly code = "ADMIN_ACCESS_DENIED";

  constructor(message = "Admin access denied.") {
    super(message);
    this.name = "AdminMutationAuthorizationError";
  }
}

export class AdminMutationConflictError extends Error {
  constructor(
    message =
      "This record changed after it was loaded. Refresh the latest data, review the differences, and try again.",
  ) {
    super(message);
    this.name = "AdminMutationConflictError";
  }
}

export function requireExpectedUpdatedAt(value: string | null | undefined) {
  const expectedUpdatedAt = safeString(value);
  if (!expectedUpdatedAt) {
    throw new AdminMutationConflictError(
      "This record has no loaded version. Refresh the latest data before editing it.",
    );
  }
  return expectedUpdatedAt;
}

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
export const membershipTable = "membership_tiers";
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

export async function mutateRecordWithVariantsIfUnchanged(
  client: SupabaseClient,
  table: string,
  id: string | null | undefined,
  expectedUpdatedAt: string | null | undefined,
  payloadVariants: Array<Record<string, unknown>>,
  matchers: Record<string, unknown> = {},
) {
  if (!id) {
    return mutateRecordWithVariants(
      client,
      table,
      id,
      payloadVariants,
      matchers,
    );
  }

  const loadedVersion = requireExpectedUpdatedAt(expectedUpdatedAt);
  let lastError: { message?: string } | null = null;

  for (const payload of payloadVariants) {
    let query = client.from(table).update(payload);
    for (const [column, value] of Object.entries(matchers)) {
      query = query.eq(column, value);
    }
    const response = await query
      .eq("id", id)
      .eq("updated_at", loadedVersion)
      .select("id")
      .maybeSingle();
    if (!response.error) {
      if (response.data == null) {
        throw new AdminMutationConflictError();
      }
      return id;
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

export async function deleteRecordWithMatchersIfUnchanged(
  client: SupabaseClient,
  table: string,
  id: string,
  expectedUpdatedAt: string | null | undefined,
  matchers: Record<string, unknown> = {},
) {
  const loadedVersion = requireExpectedUpdatedAt(expectedUpdatedAt);
  let query = client.from(table).delete();
  for (const [column, value] of Object.entries(matchers)) {
    query = query.eq(column, value);
  }
  const response = await query
    .eq("id", id)
    .eq("updated_at", loadedVersion)
    .select("id")
    .maybeSingle();
  if (response.error) {
    throw new Error(response.error.message);
  }
  if (response.data == null) {
    throw new AdminMutationConflictError();
  }
}

export interface AdminDeleteAuditContext {
  actorId: string | null | undefined;
  clubId?: number | string | null;
  requiresPlatformAdmin?: boolean;
  action: string;
  source: string;
}

export async function deleteAdminRecordWithAuditIfUnchanged(
  client: SupabaseClient,
  table: string,
  id: string,
  expectedUpdatedAt: string | null | undefined,
  matchers: Record<string, unknown>,
  audit: AdminDeleteAuditContext,
) {
  const loadedVersion = requireExpectedUpdatedAt(expectedUpdatedAt);
  const actorId = safeString(audit.actorId);
  if (!actorId) {
    throw new Error("An authenticated audit actor is required.");
  }

  const matcherKeys = Object.keys(matchers);
  if (matcherKeys.some((key) => key !== "club_id")) {
    throw new Error("Governed admin deletion only supports active-club scoping.");
  }

  const matcherClubId =
    matchers.club_id == null
      ? null
      : safeNumber(matchers.club_id, Number.NaN);
  const configuredClubId =
    audit.clubId == null
      ? null
      : safeNumber(audit.clubId, Number.NaN);
  const clubId = Number.isFinite(matcherClubId as number)
    ? matcherClubId
    : Number.isFinite(configuredClubId as number)
      ? configuredClubId
      : null;

  const { error } = await client.rpc(
    "admin_delete_mutable_record_if_unchanged",
    {
      p_table_name: table,
      p_record_id: id,
      p_expected_updated_at: loadedVersion,
      p_actor_id: actorId,
      p_club_id: clubId,
      p_enforce_club_scope: matchers.club_id != null,
      p_requires_platform_admin: audit.requiresPlatformAdmin === true,
      p_action: audit.action,
      p_source: audit.source,
    },
  );

  if (error) {
    const message = safeString(error.message, "Could not delete record.");
    if (
      /changed after it was loaded|loaded version|outside the active admin scope/i.test(
        message,
      )
    ) {
      throw new AdminMutationConflictError(message);
    }
    throw new Error(message);
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

export async function resolveClubFootballPartnerId(
  client: SupabaseClient,
  clubId: number,
) {
  const clubLookup = await client
    .from(clubTable)
    .select("club_name, club_slug")
    .eq("id", clubId)
    .maybeSingle();

  if (clubLookup.error) {
    throw new Error(clubLookup.error.message);
  }

  const clubSlug = safeString(clubLookup.data?.club_slug);
  const clubName = safeString(clubLookup.data?.club_name);

  if (clubSlug) {
    const partnerBySlug = await client
      .from("partners")
      .select("id")
      .eq("category", "football")
      .eq("slug", clubSlug)
      .maybeSingle();

    if (partnerBySlug.error) {
      throw new Error(partnerBySlug.error.message);
    }

    const partnerId = safeString(partnerBySlug.data?.id);
    if (partnerId.length > 0) {
      return partnerId;
    }
  }

  if (clubName) {
    const partnerByName = await client
      .from("partners")
      .select("id")
      .eq("category", "football")
      .eq("name", clubName)
      .maybeSingle();

    if (partnerByName.error) {
      throw new Error(partnerByName.error.message);
    }

    const partnerId = safeString(partnerByName.data?.id);
    if (partnerId.length > 0) {
      return partnerId;
    }
  }

  throw new Error(`No football partner mapping exists for club ${clubId}.`);
}

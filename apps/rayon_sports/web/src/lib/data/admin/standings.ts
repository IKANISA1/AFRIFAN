/**
 * Admin standings — league table CRUD with dynamic column resolution.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminStandingRow } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
  resolveExistingColumn,
  resolveStandingsTable,
} from "./helpers";

function mapAdminStandingRow(row: Record<string, unknown>, index: number): AdminStandingRow {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    position: safeNumber(row.position, index + 1),
    club: safeString(row.club_name, safeString(row.club, safeString(row.team_name, `Club ${index + 1}`))),
    played: safeNumber(row.played, safeNumber(row.matches_played, 0)),
    goalDifference: safeNumber(row.goal_difference, safeNumber(row.gd, safeNumber(row.goal_diff, 0))),
    points: safeNumber(row.points, safeNumber(row.pts, 0)),
    form: Array.isArray(row.form) ? row.form.map((entry) => safeString(entry)).filter(Boolean).slice(0, 5) : [],
    clubSlug: safeString(row.club_slug) || null,
    updatedAt: safeString(row.updated_at, new Date(0).toISOString()),
  };
}

export async function getAdminStandings(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminStandingRow[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminStandingRow[]>("standings");
  }
  const clubId = requireAdminClubId(access, "load standings");
  const { data, error } = await client
    .from("unified_standings")
    .select("*")
    .eq("club_id", clubId)
    .order("position", { ascending: true });
  if (error) throw new Error(error.message);
  return Array.isArray(data)
    ? data.map((row, index) => mapAdminStandingRow(row as Record<string, unknown>, index))
    : [];
}

export async function saveAdminStandingRow(
  client: SupabaseClient, access: AdminAccess,
  input: { id?: string | null; expectedUpdatedAt?: string | null; position: number; club: string; played: number; goalDifference: number; points: number; form: string[]; clubSlug?: string | null },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("standings", {
      method: "POST",
      body: input,
    });
  }
  const clubId = requireAdminClubId(access, "save standings");
  const table = await resolveStandingsTable(client);
  const clubColumn = await resolveExistingColumn(client, table, ["club_name", "club", "team_name"]);
  const playedColumn = await resolveExistingColumn(client, table, ["played", "matches_played"]);
  const goalDifferenceColumn = await resolveExistingColumn(client, table, ["goal_difference", "gd", "goal_diff"]);
  const pointsColumn = await resolveExistingColumn(client, table, ["points", "pts"]);
  const clubIdColumn = await resolveExistingColumn(client, table, ["club_id"]);
  const formColumn = await resolveExistingColumn(client, table, ["form"]);
  const slugColumn = await resolveExistingColumn(client, table, ["club_slug"]);

  const payload: Record<string, unknown> = { position: safeNumber(input.position, 1) };
  if (clubColumn) payload[clubColumn] = input.club.trim();
  if (playedColumn) payload[playedColumn] = safeNumber(input.played, 0);
  if (goalDifferenceColumn) payload[goalDifferenceColumn] = safeNumber(input.goalDifference, 0);
  if (pointsColumn) payload[pointsColumn] = safeNumber(input.points, 0);
  if (clubIdColumn === "club_id") payload.club_id = clubId;
  if (formColumn === "form") payload.form = input.form.slice(0, 5);
  if (slugColumn === "club_slug") payload.club_slug = safeString(input.clubSlug) || null;

  return mutateRecordWithVariantsIfUnchanged(client, table, input.id, input.expectedUpdatedAt, [payload], {
    club_id: clubId,
  });
}

export async function deleteAdminStandingRow(
  client: SupabaseClient,
  access: AdminAccess,
  rowId: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("standings", {
      method: "DELETE",
      query: { id: rowId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete standings rows");
  const table = await resolveStandingsTable(client);
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    table,
    rowId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_standings_row",
      source: "admin_standings",
    },
  );
}

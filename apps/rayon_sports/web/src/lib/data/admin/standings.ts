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

export function normalizeAdminStandings(value: unknown): AdminStandingRow[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const record = entry as Record<string, unknown>;
    const id = boundedText(record.id, 128);
    const position = boundedInteger(record.position, 1, 1_000);
    const club = boundedText(record.club, 120);
    const played = boundedInteger(record.played, 0, 1_000);
    const goalDifference = boundedInteger(record.goalDifference, -1_000, 1_000);
    const points = boundedInteger(record.points, 0, 10_000);
    const updatedAt = boundedDate(record.updatedAt);
    const clubSlug =
      record.clubSlug == null ? null : boundedText(record.clubSlug, 128);
    const clubId =
      record.clubId == null
        ? null
        : boundedInteger(record.clubId, 1, 1_000_000_000);
    const sourceForm = Array.isArray(record.form) ? record.form : null;
    const form = sourceForm == null
      ? null
      : sourceForm.slice(0, 5).flatMap((result) =>
          result === "W" || result === "D" || result === "L" ? [result] : [],
        );

    if (
      id == null ||
      position == null ||
      club == null ||
      played == null ||
      goalDifference == null ||
      points == null ||
      updatedAt == null ||
      form == null ||
      sourceForm == null ||
      form.length !== sourceForm.length ||
      (record.clubSlug != null && clubSlug == null) ||
      (record.clubId != null && clubId == null)
    ) {
      return [];
    }

    return [{
      id,
      clubId,
      position,
      club,
      played,
      goalDifference,
      points,
      form,
      clubSlug,
      updatedAt,
    }];
  });
}

export async function getAdminStandings(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminStandingRow[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminStandingRow[]>("standings", {
      signal: options.signal,
    });
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

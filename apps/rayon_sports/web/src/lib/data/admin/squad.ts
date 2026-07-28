/**
 * Admin squad — player CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
  resolveSquadTable,
} from "./helpers";

export interface AdminSquadPlayer {
  id: string;
  clubId: number | null;
  name: string;
  role: string;
  number: number;
  nationality: string;
  bio: string;
  imageUrl: string | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

function mapAdminSquadPlayer(row: Record<string, unknown>): AdminSquadPlayer {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    name: safeString(row.name, "Squad player"),
    role: safeString(row.role) || safeString(row.position) || safeString(row.primary_position, "Player"),
    number: safeNumber(row.number, safeNumber(row.shirt_number, 0)),
    nationality: safeString(row.nationality, "Rwanda"),
    bio:
      safeString(row.bio) ||
      safeString(row.description) ||
      safeString(row.player_summary) ||
      "First-team squad member.",
    imageUrl: safeString(row.image_url) || safeString(row.photo_url) || null,
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
    updatedAt: safeString(row.updated_at, new Date(0).toISOString()),
  };
}

export async function getAdminSquad(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminSquadPlayer[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSquadPlayer[]>("squad");
  }
  const clubId = requireAdminClubId(access, "load squad");
  const { data, error } = await client
    .from("unified_roster")
    .select("*")
    .eq("club_id", clubId)
    .order("number", { ascending: true })
    .limit(50);
  if (error) throw new Error(error.message);
  return Array.isArray(data)
    ? data.map((row) => mapAdminSquadPlayer(row as Record<string, unknown>))
    : [];
}

export async function saveAdminSquadPlayer(
  client: SupabaseClient, access: AdminAccess,
  player: { id: string | null; expectedUpdatedAt?: string | null; name: string; role: string; number: number; nationality: string; bio: string; imageUrl: string; isActive: boolean },
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("squad", {
      method: "POST",
      body: player,
    });
    return;
  }
  const clubId = requireAdminClubId(access, "save squad players");
  const table = await resolveSquadTable(client);
  const payload = {
    club_id: clubId,
    name: player.name, position: player.role, shirt_number: player.number,
    nationality: player.nationality, bio: player.bio,
    image_url: player.imageUrl || null, is_active: player.isActive,
  };
  if (player.id) {
    await mutateRecordWithVariantsIfUnchanged(
      client,
      table,
      player.id,
      player.expectedUpdatedAt,
      [payload],
      { club_id: clubId },
    );
  } else {
    const { error } = await client.from(table).insert(payload);
    if (error) throw new Error(error.message);
  }
}

export async function deleteAdminSquadPlayer(
  client: SupabaseClient,
  access: AdminAccess,
  playerId: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("squad", {
      method: "DELETE",
      query: { id: playerId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete squad players");
  const table = await resolveSquadTable(client);
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    table,
    playerId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_squad_player",
      source: "admin_squad",
    },
  );
}

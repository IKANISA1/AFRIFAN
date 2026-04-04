/**
 * Admin squad — player CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import type { AdminAccess } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { resolveSquadTable } from "./helpers";

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
}

function mapAdminSquadPlayer(row: Record<string, unknown>): AdminSquadPlayer {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    name: safeString(row.name, "Squad player"),
    role: safeString(row.role) || safeString(row.position) || safeString(row.primary_position, "Player"),
    number: safeNumber(row.number, safeNumber(row.shirt_number, 0)),
    nationality: safeString(row.nationality, "Rwanda"),
    bio: safeString(row.bio) || safeString(row.description) || safeString(row.player_summary) || "Rayon Sports first-team squad member.",
    imageUrl: safeString(row.image_url) || safeString(row.photo_url) || null,
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

export async function getAdminSquad(client: SupabaseClient): Promise<AdminSquadPlayer[]> {
  const table = await resolveSquadTable(client);
  const scopedQuery = await client.from(table).select("*").eq("club_id", rayonClub.numericId).order("shirt_number", { ascending: true }).limit(50);
  if (scopedQuery.data && scopedQuery.data.length > 0) {
    return scopedQuery.data.map((row) => mapAdminSquadPlayer(row as Record<string, unknown>));
  }
  const fallbackQuery = await client.from(table).select("*").order("shirt_number", { ascending: true }).limit(50);
  if (fallbackQuery.data && fallbackQuery.data.length > 0) {
    return fallbackQuery.data.map((row) => mapAdminSquadPlayer(row as Record<string, unknown>));
  }
  return [];
}

export async function saveAdminSquadPlayer(
  client: SupabaseClient, access: AdminAccess,
  player: { id: string | null; name: string; role: string; number: number; nationality: string; bio: string; imageUrl: string; isActive: boolean },
) {
  const table = await resolveSquadTable(client);
  const payload = {
    club_id: access.clubId ? Number(access.clubId) : rayonClub.numericId,
    name: player.name, position: player.role, shirt_number: player.number,
    nationality: player.nationality, bio: player.bio,
    image_url: player.imageUrl || null, is_active: player.isActive,
  };
  if (player.id) {
    const { error } = await client.from(table).update(payload).eq("id", player.id);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await client.from(table).insert(payload);
    if (error) throw new Error(error.message);
  }
}

export async function deleteAdminSquadPlayer(client: SupabaseClient, playerId: string) {
  const table = await resolveSquadTable(client);
  const { error } = await client.from(table).delete().eq("id", playerId);
  if (error) throw new Error(error.message);
}

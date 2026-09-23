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

const allowedSquadRoles = new Set([
  "Goalkeeper",
  "Defender",
  "Midfielder",
  "Forward",
]);

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

function boundedImageUrl(value: unknown) {
  if (value == null || value === "") {
    return null;
  }
  const text = boundedText(value, 2_048);
  if (text == null) {
    return null;
  }
  if (text.startsWith("/") && !text.startsWith("//")) {
    return text;
  }
  try {
    const url = new URL(text);
    return url.protocol === "https:" ? url.toString() : null;
  } catch {
    return null;
  }
}

export function normalizeAdminSquad(value: unknown): AdminSquadPlayer[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const record = entry as Record<string, unknown>;
    const id = boundedText(record.id, 128);
    const name = boundedText(record.name, 120);
    const role = boundedText(record.role, 32);
    const number = boundedInteger(record.number, 1, 99);
    const nationality = boundedText(record.nationality, 80);
    const bio = boundedText(record.bio, 2_000);
    const createdAt = boundedDate(record.createdAt);
    const updatedAt = boundedDate(record.updatedAt);

    if (
      id == null ||
      name == null ||
      role == null ||
      !allowedSquadRoles.has(role) ||
      number == null ||
      nationality == null ||
      bio == null ||
      createdAt == null ||
      updatedAt == null ||
      typeof record.isActive !== "boolean"
    ) {
      return [];
    }

    const clubId =
      record.clubId == null
        ? null
        : boundedInteger(record.clubId, 1, 1_000_000_000);
    if (record.clubId != null && clubId == null) {
      return [];
    }

    return [{
      id,
      clubId,
      name,
      role,
      number,
      nationality,
      bio,
      imageUrl: boundedImageUrl(record.imageUrl),
      isActive: record.isActive === true,
      createdAt,
      updatedAt,
    }];
  });
}

export async function getAdminSquad(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminSquadPlayer[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminSquadPlayer[]>("squad", {
      signal: options.signal,
    });
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

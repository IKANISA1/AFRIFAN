/**
 * Admin fan clubs — CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminFanClub } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteRecordWithMatchers,
  fanClubTable,
  mutateRecordWithVariants,
  requireAdminClubId,
} from "./helpers";

function mapAdminFanClub(row: Record<string, unknown>): AdminFanClub {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    name: safeString(row.name, "Supporter chapter"),
    region: safeString(row.region, "Official"),
    description: safeString(row.description, "A Rayon Sports supporter chapter."),
    memberCount: safeNumber(row.member_count, 0),
    eventCount: safeNumber(row.event_count, 0),
    rating: safeNumber(row.rating, 0),
    bannerImageUrl: safeString(row.banner_image_url) || null,
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

export async function getAdminFanClubs(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminFanClub[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminFanClub[]>("fan-clubs");
  }
  const clubId = requireAdminClubId(access, "load supporter chapters");
  const { data, error } = await client
    .from(fanClubTable)
    .select("*")
    .eq("club_id", clubId)
    .order("member_count", { ascending: false });
  if (error) throw new Error(error.message);
  return Array.isArray(data)
    ? data.map((row) => mapAdminFanClub(row as Record<string, unknown>))
    : [];
}

export async function saveAdminFanClub(
  client: SupabaseClient, access: AdminAccess,
  input: { id?: string | null; name: string; region: string; description: string; memberCount: number; eventCount: number; rating: number; bannerImageUrl?: string; isActive: boolean },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("fan-clubs", {
      method: "POST",
      body: input,
    });
  }
  const clubId = requireAdminClubId(access, "save supporter chapters");
  return mutateRecordWithVariants(client, fanClubTable, input.id, [{
    club_id: clubId,
    name: input.name.trim(), region: input.region.trim(), description: input.description.trim(),
    member_count: safeNumber(input.memberCount, 0), event_count: safeNumber(input.eventCount, 0),
    rating: safeNumber(input.rating, 0), banner_image_url: safeString(input.bannerImageUrl) || null,
    is_active: input.isActive,
  }], { club_id: clubId });
}

export async function deleteAdminFanClub(
  client: SupabaseClient,
  access: AdminAccess,
  fanClubId: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("fan-clubs", {
      method: "DELETE",
      query: { id: fanClubId },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete supporter chapters");
  await deleteRecordWithMatchers(client, fanClubTable, fanClubId, {
    club_id: clubId,
  });
}

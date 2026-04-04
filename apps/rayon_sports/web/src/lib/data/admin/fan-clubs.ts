/**
 * Admin fan clubs — CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { rayonClub } from "@/lib/config";
import type { AdminAccess, AdminFanClub } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { fanClubTable, mutateRecordWithVariants } from "./helpers";

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

export async function getAdminFanClubs(client: SupabaseClient): Promise<AdminFanClub[]> {
  const scoped = await client.from(fanClubTable).select("*").eq("club_id", rayonClub.numericId).order("member_count", { ascending: false });
  if (!scoped.error && Array.isArray(scoped.data) && scoped.data.length > 0) {
    return scoped.data.map((row) => mapAdminFanClub(row as Record<string, unknown>));
  }
  const fallback = await client.from(fanClubTable).select("*").order("member_count", { ascending: false });
  if (fallback.error) throw new Error(fallback.error.message);
  return Array.isArray(fallback.data) && fallback.data.length > 0
    ? fallback.data.map((row) => mapAdminFanClub(row as Record<string, unknown>))
    : [];
}

export async function saveAdminFanClub(
  client: SupabaseClient, access: AdminAccess,
  input: { id?: string | null; name: string; region: string; description: string; memberCount: number; eventCount: number; rating: number; bannerImageUrl?: string; isActive: boolean },
) {
  return mutateRecordWithVariants(client, fanClubTable, input.id, [{
    club_id: safeNumber(access.clubId, rayonClub.numericId),
    name: input.name.trim(), region: input.region.trim(), description: input.description.trim(),
    member_count: safeNumber(input.memberCount, 0), event_count: safeNumber(input.eventCount, 0),
    rating: safeNumber(input.rating, 0), banner_image_url: safeString(input.bannerImageUrl) || null,
    is_active: input.isActive,
  }]);
}

export async function deleteAdminFanClub(client: SupabaseClient, fanClubId: string) {
  const { error } = await client.from(fanClubTable).delete().eq("id", fanClubId);
  if (error) throw new Error(error.message);
}

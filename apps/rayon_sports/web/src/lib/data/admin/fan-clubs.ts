/**
 * Admin fan clubs — CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, AdminFanClub } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  fanClubTable,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
  resolveClubFootballPartnerId,
} from "./helpers";

function mapAdminFanClub(row: Record<string, unknown>): AdminFanClub {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    name: safeString(row.name, "Supporter FanClubs"),
    region: safeString(row.region, "Official"),
    description: safeString(row.description, "An official supporter FanClubs."),
    memberCount: safeNumber(row.member_count, 0),
    eventCount: safeNumber(row.event_count, 0),
    rating: safeNumber(row.rating, 0),
    bannerImageUrl: safeString(row.banner_image_url) || null,
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
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

function boundedNumber(value: unknown, minimum: number, maximum: number) {
  return typeof value === "number" &&
    Number.isFinite(value) &&
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

export function normalizeAdminFanClubs(value: unknown): AdminFanClub[] {
  if (!Array.isArray(value)) {
    return [];
  }

  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const record = entry as Record<string, unknown>;
    const id = boundedText(record.id, 128);
    const name = boundedText(record.name, 160);
    const region = boundedText(record.region, 120);
    const description = boundedText(record.description, 3_000);
    const memberCount = boundedInteger(record.memberCount, 0, 1_000_000_000);
    const eventCount = boundedInteger(record.eventCount, 0, 1_000_000);
    const rating = boundedNumber(record.rating, 0, 5);
    const createdAt = boundedDate(record.createdAt);
    const updatedAt = boundedDate(record.updatedAt);
    const clubId =
      record.clubId == null
        ? null
        : boundedInteger(record.clubId, 1, 1_000_000_000);

    if (
      id == null ||
      name == null ||
      region == null ||
      description == null ||
      memberCount == null ||
      eventCount == null ||
      rating == null ||
      createdAt == null ||
      updatedAt == null ||
      typeof record.isActive !== "boolean" ||
      (record.clubId != null && clubId == null)
    ) {
      return [];
    }

    return [
      {
        id,
        clubId,
        name,
        region,
        description,
        memberCount,
        eventCount,
        rating,
        bannerImageUrl: boundedImageUrl(record.bannerImageUrl),
        isActive: record.isActive,
        createdAt,
        updatedAt,
      },
    ];
  });
}

export async function getAdminFanClubs(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminFanClub[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminFanClub[]>("fan-clubs", {
      signal: options.signal,
    });
  }
  const clubId = requireAdminClubId(access, "load supporter FanClubs");
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
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    expectedUpdatedAt?: string | null;
    name: string;
    region: string;
    description: string;
    memberCount: number;
    eventCount: number;
    rating: number;
    bannerImageUrl?: string;
    isActive: boolean;
  },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("fan-clubs", {
      method: "POST",
      body: input,
    });
  }
  const clubId = requireAdminClubId(access, "save supporter FanClubs");
  const partnerId = await resolveClubFootballPartnerId(client, clubId);
  return mutateRecordWithVariantsIfUnchanged(
    client,
    fanClubTable,
    input.id,
    input.expectedUpdatedAt,
    [
      {
        partner_id: partnerId,
        club_id: clubId,
        name: input.name.trim(),
        region: input.region.trim(),
        description: input.description.trim(),
        member_count: safeNumber(input.memberCount, 0),
        event_count: safeNumber(input.eventCount, 0),
        rating: safeNumber(input.rating, 0),
        banner_image_url: safeString(input.bannerImageUrl) || null,
        is_active: input.isActive,
      },
    ],
    { club_id: clubId },
  );
}

export async function deleteAdminFanClub(
  client: SupabaseClient,
  access: AdminAccess,
  fanClubId: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("fan-clubs", {
      method: "DELETE",
      query: { id: fanClubId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete supporter FanClubs");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    fanClubTable,
    fanClubId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_supporter_chapter",
      source: "admin_community",
    },
  );
}

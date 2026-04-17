import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, ContentBlock } from "@/lib/types";
import { requestAdminApi } from "./http";
import { adminClubIdOrNull, safeString } from "./helpers";

type ContentBlockRow = {
  id: string;
  club_id: number | null;
  block_key: string;
  block_type: string;
  title: string | null;
  subtitle: string | null;
  content: Record<string, unknown> | null;
  target_channel: "mobile" | "web" | "both";
  placement_key: string;
  feature_id: string | null;
  is_active: boolean;
  sort_order: number | null;
  metadata: Record<string, unknown> | null;
  created_at?: string;
  updated_at?: string;
  feature?: { feature_key?: string | null } | null;
};

function normalizeContentBlock(row: ContentBlockRow): ContentBlock {
  return {
    id: row.id,
    clubId: row.club_id,
    scope: row.club_id == null ? "global" : "club",
    blockKey: row.block_key,
    blockType: row.block_type,
    title: row.title,
    subtitle: row.subtitle,
    content:
      typeof row.content === "object" && row.content != null
        ? row.content
        : {},
    targetChannel: row.target_channel,
    placementKey: row.placement_key,
    featureId: row.feature_id,
    featureKey: row.feature?.feature_key ?? null,
    isActive: row.is_active,
    sortOrder: row.sort_order,
    metadata:
      typeof row.metadata === "object" && row.metadata != null
        ? row.metadata
        : {},
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function resolveScopedRows(rows: ContentBlockRow[], clubId: number | null) {
  const grouped = new Map<string, ContentBlockRow[]>();

  for (const row of rows) {
    const bucket = grouped.get(row.block_key) ?? [];
    bucket.push(row);
    grouped.set(row.block_key, bucket);
  }

  return [...grouped.values()]
    .map((variants) => {
      if (clubId == null) {
        return variants.find((entry) => entry.club_id == null) ?? variants[0];
      }

      return (
        variants.find((entry) => entry.club_id === clubId) ??
        variants.find((entry) => entry.club_id == null) ??
        variants[0]
      );
    })
    .sort((left, right) => {
      const placementCompare = left.placement_key.localeCompare(right.placement_key);
      if (placementCompare != 0) {
        return placementCompare;
      }
      return (left.sort_order ?? 999) - (right.sort_order ?? 999);
    });
}

async function listContentBlockRows(
  client: SupabaseClient,
  clubId: number | null,
) {
  let query = client
    .from("platform_content_blocks")
    .select(`
      id,
      club_id,
      block_key,
      block_type,
      title,
      subtitle,
      content,
      target_channel,
      placement_key,
      feature_id,
      is_active,
      sort_order,
      metadata,
      created_at,
      updated_at,
      feature:platform_features(feature_key)
    `);

  query = clubId == null
    ? query.is("club_id", null)
    : query.or(`club_id.is.null,club_id.eq.${clubId}`);

  const { data, error } = await query.order("placement_key").order("sort_order");
  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data) ? (data as ContentBlockRow[]) : [];
}

async function getContentBlockRowById(client: SupabaseClient, id: string) {
  const { data, error } = await client
    .from("platform_content_blocks")
    .select(`
      id,
      club_id,
      block_key,
      block_type,
      title,
      subtitle,
      content,
      target_channel,
      placement_key,
      feature_id,
      is_active,
      sort_order,
      metadata,
      created_at,
      updated_at,
      feature:platform_features(feature_key)
    `)
    .eq("id", id)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as ContentBlockRow;
}

async function ensureScopedContentBlockTarget(
  client: SupabaseClient,
  access: AdminAccess,
  source: ContentBlockRow,
) {
  const scopedClubId = adminClubIdOrNull(access);
  if (scopedClubId == null || source.club_id === scopedClubId) {
    return source.id;
  }

  const { data: existing, error: existingError } = await client
    .from("platform_content_blocks")
    .select("id")
    .eq("block_key", source.block_key)
    .eq("club_id", scopedClubId)
    .maybeSingle();

  if (existingError) {
    throw new Error(existingError.message);
  }

  if (existing?.id) {
    return safeString(existing.id);
  }

  const { data: inserted, error: insertError } = await client
    .from("platform_content_blocks")
    .insert({
      club_id: scopedClubId,
      block_key: source.block_key,
      block_type: source.block_type,
      title: source.title,
      subtitle: source.subtitle,
      content: source.content ?? {},
      target_channel: source.target_channel,
      placement_key: source.placement_key,
      feature_id: source.feature_id,
      is_active: source.is_active,
      sort_order: source.sort_order,
      metadata: source.metadata ?? {},
    })
    .select("id")
    .single();

  if (insertError) {
    throw new Error(insertError.message);
  }

  return safeString(inserted.id);
}

export async function getAdminContentBlocks(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<ContentBlock[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<ContentBlock[]>("content-blocks");
  }

  const scopedClubId = adminClubIdOrNull(access);
  const rows = await listContentBlockRows(client, scopedClubId);
  return resolveScopedRows(rows, scopedClubId).map(normalizeContentBlock);
}

export async function saveAdminContentBlock(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<ContentBlock> & { id?: string },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("content-blocks/save", {
      method: "POST",
      body: { input },
    });
  }

  const scopedClubId = adminClubIdOrNull(access);
  const payload = {
    club_id: scopedClubId,
    block_key: input.blockKey,
    block_type: input.blockType,
    title: input.title ?? null,
    subtitle: input.subtitle ?? null,
    content: input.content ?? {},
    target_channel: input.targetChannel ?? "both",
    placement_key: input.placementKey,
    feature_id: input.featureId ?? null,
    is_active: input.isActive ?? true,
    sort_order: input.sortOrder ?? null,
    metadata: input.metadata ?? {},
  };

  if (input.id) {
    const source = await getContentBlockRowById(client, input.id);
    const targetId = await ensureScopedContentBlockTarget(client, access, source);
    const { error } = await client
      .from("platform_content_blocks")
      .update(payload)
      .eq("id", targetId);
    if (error) {
      throw new Error(error.message);
    }
    return;
  }

  const { error } = await client.from("platform_content_blocks").insert(payload);
  if (error) {
    throw new Error(error.message);
  }
}

export async function deleteAdminContentBlock(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("content-blocks/delete", {
      method: "POST",
      body: { id },
    });
  }

  const scopedClubId = adminClubIdOrNull(access);
  const source = await getContentBlockRowById(client, id);

  if (scopedClubId != null && source.club_id == null) {
    const targetId = await ensureScopedContentBlockTarget(client, access, source);
    const { error } = await client
      .from("platform_content_blocks")
      .update({ is_active: false })
      .eq("id", targetId);
    if (error) {
      throw new Error(error.message);
    }
    return;
  }

  const { error } = await client
    .from("platform_content_blocks")
    .delete()
    .eq("id", source.id);

  if (error) {
    throw new Error(error.message);
  }
}

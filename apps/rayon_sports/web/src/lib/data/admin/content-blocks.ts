import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, ContentBlock } from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  AdminMutationAuthorizationError,
  AdminMutationConflictError,
  adminClubIdOrNull,
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireExpectedUpdatedAt,
} from "./helpers";

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

export type AdminContentBlockFeatureOption = {
  id: string;
  displayName: string;
};

const privateObjectKey =
  /(?:token|secret|password|email|phone|user|actor|auth|session|cookie)/i;

function boundedString(value: unknown, maximum: number) {
  return typeof value === "string" && value.length <= maximum ? value : null;
}

function boundedNullableString(value: unknown, maximum: number) {
  return value == null ? null : boundedString(value, maximum);
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
  const text = boundedString(value, 64);
  return text != null && Number.isFinite(Date.parse(text)) ? text : null;
}

function sanitizeJsonValue(value: unknown, depth = 0): unknown {
  if (depth > 4) return null;
  if (
    value == null ||
    typeof value === "boolean" ||
    (typeof value === "number" && Number.isFinite(value))
  ) {
    return value;
  }
  if (typeof value === "string") {
    return value.slice(0, 1_000);
  }
  if (Array.isArray(value)) {
    return value
      .slice(0, 50)
      .map((entry) => sanitizeJsonValue(entry, depth + 1));
  }
  if (typeof value !== "object") return null;

  return Object.fromEntries(
    Object.entries(value as Record<string, unknown>)
      .filter(([key]) => key.length <= 80 && !privateObjectKey.test(key))
      .slice(0, 50)
      .map(([key, entry]) => [key, sanitizeJsonValue(entry, depth + 1)]),
  );
}

function boundedJsonRecord(value: unknown, maximumBytes: number) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  try {
    if (JSON.stringify(value).length > maximumBytes) {
      return {};
    }
  } catch {
    return {};
  }
  const sanitized = sanitizeJsonValue(value);
  if (
    sanitized == null ||
    typeof sanitized !== "object" ||
    Array.isArray(sanitized)
  ) {
    return {};
  }
  return JSON.stringify(sanitized).length <= maximumBytes
    ? (sanitized as Record<string, unknown>)
    : {};
}

export function normalizeAdminContentBlocks(value: unknown): ContentBlock[] {
  if (!Array.isArray(value)) return [];

  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const row = entry as Record<string, unknown>;
    const id = boundedString(row.id, 128);
    const blockKey = boundedString(row.blockKey, 120);
    const blockType = boundedString(row.blockType, 40);
    const placementKey = boundedString(row.placementKey, 120);
    const targetChannel =
      row.targetChannel === "mobile" ||
      row.targetChannel === "web" ||
      row.targetChannel === "both"
        ? row.targetChannel
        : null;
    const isActive = typeof row.isActive === "boolean" ? row.isActive : null;
    const sortOrder =
      row.sortOrder == null
        ? 0
        : boundedInteger(row.sortOrder, -100_000, 100_000);
    const updatedAt = boundedDate(row.updatedAt);
    const clubId =
      row.clubId == null ? null : boundedInteger(row.clubId, 1, 2_147_483_647);
    const scope =
      row.scope === "global" || row.scope === "club" ? row.scope : null;

    if (
      id == null ||
      id.length === 0 ||
      blockKey == null ||
      blockKey.length === 0 ||
      blockType == null ||
      blockType.length === 0 ||
      placementKey == null ||
      placementKey.length === 0 ||
      targetChannel == null ||
      isActive == null ||
      sortOrder == null ||
      updatedAt == null ||
      scope == null ||
      (row.clubId != null && clubId == null)
    ) {
      return [];
    }

    return [
      {
        id,
        clubId,
        scope,
        blockKey,
        blockType,
        title: boundedNullableString(row.title, 160),
        subtitle: boundedNullableString(row.subtitle, 300),
        content: boundedJsonRecord(row.content, 12_000),
        targetChannel,
        placementKey,
        featureId: boundedNullableString(row.featureId, 128),
        featureKey: boundedNullableString(row.featureKey, 120),
        isActive,
        sortOrder,
        metadata: boundedJsonRecord(row.metadata, 4_000),
        createdAt:
          row.createdAt == null
            ? undefined
            : (boundedDate(row.createdAt) ?? undefined),
        updatedAt,
      },
    ];
  });
}

export function normalizeAdminContentBlockFeatureOptions(
  value: unknown,
): AdminContentBlockFeatureOption[] {
  if (!Array.isArray(value)) return [];
  return value.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const row = entry as Record<string, unknown>;
    const id = boundedString(row.id, 128);
    const displayName = boundedString(row.displayName, 160);
    return id != null && id.length > 0 && displayName != null
      ? [{ id, displayName }]
      : [];
  });
}

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
      typeof row.content === "object" && row.content != null ? row.content : {},
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
      const placementCompare = left.placement_key.localeCompare(
        right.placement_key,
      );
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
  let query = client.from("platform_content_blocks").select(`
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

  query =
    clubId == null
      ? query.is("club_id", null)
      : query.or(`club_id.is.null,club_id.eq.${clubId}`);

  const { data, error } = await query
    .order("placement_key")
    .order("sort_order");
  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data) ? (data as ContentBlockRow[]) : [];
}

async function getContentBlockRowById(client: SupabaseClient, id: string) {
  const { data, error } = await client
    .from("platform_content_blocks")
    .select(
      `
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
    `,
    )
    .eq("id", id)
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return data as ContentBlockRow;
}

function requireContentBlockScope(
  access: AdminAccess,
  source: ContentBlockRow,
) {
  const scopedClubId = adminClubIdOrNull(access);
  if (
    (source.club_id != null && source.club_id !== scopedClubId) ||
    (scopedClubId == null && !access.isSuperAdmin)
  ) {
    throw new AdminMutationAuthorizationError();
  }
}

async function insertScopedContentBlock(
  client: SupabaseClient,
  scopedClubId: number,
  source: ContentBlockRow,
  changes: Partial<ContentBlockRow>,
) {
  // Commit only the final override. A failed follow-up update must never leave
  // an intermediate copy, and a concurrently created override must be reloaded.
  const definedChanges = Object.fromEntries(
    Object.entries(changes).filter(([, value]) => value !== undefined),
  );
  const { error } = await client
    .from("platform_content_blocks")
    .insert({
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
      ...definedChanges,
      club_id: scopedClubId,
    });
  if (error?.code === "23505") {
    throw new AdminMutationConflictError();
  }
  if (error) {
    throw new Error(error.message);
  }
}

export async function getAdminContentBlocks(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } | SupabaseClient = {},
): Promise<ContentBlock[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<ContentBlock[]>("content-blocks", {
      signal: "signal" in options ? options.signal : undefined,
    });
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
    requireContentBlockScope(access, source);
    const loadedVersion = requireExpectedUpdatedAt(input.updatedAt);
    if (source.updated_at !== loadedVersion) {
      throw new AdminMutationConflictError();
    }
    if (scopedClubId != null && source.club_id == null) {
      await insertScopedContentBlock(client, scopedClubId, source, payload);
      return;
    }
    await mutateRecordWithVariantsIfUnchanged(
      client,
      "platform_content_blocks",
      source.id,
      loadedVersion,
      [payload],
    );
    return;
  }

  const { error } = await client
    .from("platform_content_blocks")
    .insert(payload);
  if (error) {
    throw new Error(error.message);
  }
}

export async function deleteAdminContentBlock(
  client: SupabaseClient,
  access: AdminAccess,
  id: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("content-blocks/delete", {
      method: "POST",
      body: { id, expectedUpdatedAt },
    });
  }

  const scopedClubId = adminClubIdOrNull(access);
  const source = await getContentBlockRowById(client, id);
  requireContentBlockScope(access, source);
  const loadedVersion = requireExpectedUpdatedAt(expectedUpdatedAt);
  if (source.updated_at !== loadedVersion) {
    throw new AdminMutationConflictError();
  }

  if (scopedClubId != null && source.club_id == null) {
    await insertScopedContentBlock(client, scopedClubId, source, { is_active: false });
    return;
  }

  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    "platform_content_blocks",
    source.id,
    loadedVersion,
    scopedClubId == null ? {} : { club_id: scopedClubId },
    {
      actorId: access.userId,
      clubId: scopedClubId,
      action: "delete_platform_content_block",
      source: "admin_platform_content_blocks",
    },
  );
}

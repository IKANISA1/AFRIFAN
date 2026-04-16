import type { SupabaseClient } from "@supabase/supabase-js";
import type { AdminAccess, ContentBlock } from "@/lib/types";
import { requestAdminApi } from "./http";

export async function getAdminContentBlocks(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<ContentBlock[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<ContentBlock[]>("content-blocks");
  }

  const { data, error } = await client
    .from("platform_content_blocks")
    .select("*")
    .order("placement_key")
    .order("sort_order", { ascending: true });

  if (error) throw new Error(error.message);

  return (data ?? []).map((row: any) => ({
    id: row.id,
    blockKey: row.block_key,
    blockType: row.block_type,
    title: row.title,
    subtitle: row.subtitle,
    content: row.content ?? {},
    targetChannel: row.target_channel,
    placementKey: row.placement_key,
    featureId: row.feature_id,
    isActive: row.is_active,
    sortOrder: row.sort_order,
    metadata: row.metadata ?? {},
  }));
}

export async function saveAdminContentBlock(
  client: SupabaseClient,
  access: AdminAccess,
  input: Partial<ContentBlock> & { id?: string }
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("content-blocks/save", {
      method: "POST",
      body: { input },
    });
  }

  const payload = {
    block_key: input.blockKey,
    block_type: input.blockType,
    title: input.title,
    subtitle: input.subtitle,
    content: input.content,
    target_channel: input.targetChannel,
    placement_key: input.placementKey,
    feature_id: input.featureId,
    is_active: input.isActive,
    sort_order: input.sortOrder,
    metadata: input.metadata,
  };

  if (input.id) {
    const { error } = await client
      .from("platform_content_blocks")
      .update(payload)
      .eq("id", input.id);
    if (error) throw new Error(error.message);
  } else {
    const { error } = await client
      .from("platform_content_blocks")
      .insert(payload);
    if (error) throw new Error(error.message);
  }

  await client.from("admin_audit_log").insert({
    user_id: access.userId,
    action: input.id ? "update_content_block" : "create_content_block",
    metadata: { block_key: input.blockKey },
  });
}

export async function deleteAdminContentBlock(
  client: SupabaseClient,
  access: AdminAccess,
  id: string
) {
  if (typeof window !== "undefined") {
    return requestAdminApi("content-blocks/delete", {
      method: "POST",
      body: { id },
    });
  }

  const { error } = await client
    .from("platform_content_blocks")
    .delete()
    .eq("id", id);

  if (error) throw new Error(error.message);

  await client.from("admin_audit_log").insert({
    user_id: access.userId,
    action: "delete_content_block",
    metadata: { id },
  });
}

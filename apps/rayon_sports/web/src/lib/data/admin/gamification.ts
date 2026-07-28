/**
 * Admin gamification — Fan Engagement Token catalog CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminFanEngagementTemplateScope,
  AdminFanEngagementToken,
} from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

const fanEngagementTokenTable = "fan_engagement_token_catalog";

function normalizeTemplateScope(
  value: unknown,
): AdminFanEngagementTemplateScope {
  return safeString(value).toLowerCase() === "club_specific"
    ? "club_specific"
    : "generic";
}

function normalizeCode(value: unknown) {
  return safeString(value).toUpperCase();
}

function mapAdminFanEngagementToken(
  row: Record<string, unknown>,
): AdminFanEngagementToken {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    clubId: typeof row.club_id === "number" ? row.club_id : null,
    code: normalizeCode(row.code),
    templateScope: normalizeTemplateScope(row.template_scope),
    category: safeString(row.category, "General"),
    itemName: safeString(row.item_name, "Fan engagement reward"),
    fetValue: safeNumber(row.fet_value, 0),
    triggerCondition: safeString(
      row.trigger_condition,
      "Defined by club operations.",
    ),
    activationTiming: safeString(row.activation_timing, "Always on"),
    description: safeString(row.description),
    badgeName: safeString(row.badge_name),
    implementationNotes: safeString(row.implementation_notes) || null,
    sortOrder: safeNumber(row.sort_order, 0),
    isActive: row.is_active !== false,
    createdAt: safeString(row.created_at, new Date().toISOString()),
    updatedAt: safeString(
      row.updated_at,
      safeString(row.created_at, new Date().toISOString()),
    ),
  };
}

function buildPayload(
  clubId: number,
  input: {
    code: string;
    templateScope: AdminFanEngagementTemplateScope;
    category: string;
    itemName: string;
    fetValue: number;
    triggerCondition: string;
    activationTiming: string;
    description: string;
    badgeName: string;
    implementationNotes?: string | null;
    sortOrder: number;
    isActive: boolean;
  },
) {
  const code = normalizeCode(input.code);
  if (!/^G\d{3}$/.test(code)) {
    throw new Error("FET code must follow the G000 format.");
  }

  const itemName = safeString(input.itemName);
  if (!itemName) {
    throw new Error("Gamification item name is required.");
  }

  return {
    club_id: clubId,
    code,
    template_scope: input.templateScope,
    category: safeString(input.category, "General"),
    item_name: itemName,
    fet_value: Math.max(0, safeNumber(input.fetValue, 0)),
    trigger_condition: safeString(
      input.triggerCondition,
      "Defined by club operations.",
    ),
    activation_timing: safeString(input.activationTiming, "Always on"),
    description: safeString(input.description),
    badge_name: safeString(input.badgeName),
    implementation_notes: safeString(input.implementationNotes) || null,
    sort_order: Math.max(0, safeNumber(input.sortOrder, 0)),
    is_active: input.isActive,
  };
}

export async function getAdminFanEngagementTokens(
  client: SupabaseClient,
  access: AdminAccess,
): Promise<AdminFanEngagementToken[]> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminFanEngagementToken[]>("gamification");
  }

  const clubId = requireAdminClubId(access, "load FET catalog");
  const { data, error } = await client
    .from(fanEngagementTokenTable)
    .select("*")
    .eq("club_id", clubId)
    .order("sort_order", { ascending: true })
    .order("code", { ascending: true });

  if (error) {
    throw new Error(error.message);
  }

  return Array.isArray(data)
    ? data.map((row) =>
        mapAdminFanEngagementToken(row as Record<string, unknown>),
      )
    : [];
}

export async function saveAdminFanEngagementToken(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    expectedUpdatedAt?: string | null;
    code: string;
    templateScope: AdminFanEngagementTemplateScope;
    category: string;
    itemName: string;
    fetValue: number;
    triggerCondition: string;
    activationTiming: string;
    description: string;
    badgeName: string;
    implementationNotes?: string | null;
    sortOrder: number;
    isActive: boolean;
  },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("gamification", {
      method: "POST",
      body: input,
    });
  }

  const clubId = requireAdminClubId(access, "save FET catalog entries");
  const payload = buildPayload(clubId, input);

  if (input.id) {
    return mutateRecordWithVariantsIfUnchanged(
      client,
      fanEngagementTokenTable,
      input.id,
      input.expectedUpdatedAt,
      [payload],
      { club_id: clubId },
    );
  }

  const { data, error } = await client
    .from(fanEngagementTokenTable)
    .insert(payload)
    .select("id")
    .single();

  if (error) {
    throw new Error(error.message);
  }

  return toIdString(data?.id, crypto.randomUUID());
}

export async function deleteAdminFanEngagementToken(
  client: SupabaseClient,
  access: AdminAccess,
  tokenId: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("gamification", {
      method: "DELETE",
      query: { id: tokenId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }

  const clubId = requireAdminClubId(access, "delete FET catalog entries");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    fanEngagementTokenTable,
    tokenId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_fet_catalog_entry",
      source: "admin_gamification",
    },
  );
}

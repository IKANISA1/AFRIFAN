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
const MAX_FET_RECORDS = 500;

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") return null;
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

function normalizeCode(value: unknown) {
  return safeString(value).toUpperCase();
}

function mapAdminFanEngagementToken(
  row: Record<string, unknown>,
): AdminFanEngagementToken | null {
  const id = boundedText(row.id, 128);
  const clubValue = row.club_id ?? row.clubId;
  const clubId =
    clubValue == null ? null : boundedInteger(clubValue, 1, 2_147_483_647);
  const code = boundedText(row.code, 4)?.toUpperCase() ?? null;
  const scopeValue = boundedText(
    row.template_scope ?? row.templateScope,
    32,
  )?.toLowerCase();
  const category = boundedText(row.category, 80);
  const itemName = boundedText(row.item_name ?? row.itemName, 160);
  const fetValue = boundedInteger(row.fet_value ?? row.fetValue, 0, 1_000_000);
  const triggerCondition = boundedText(
    row.trigger_condition ?? row.triggerCondition,
    500,
  );
  const activationTiming = boundedText(
    row.activation_timing ?? row.activationTiming,
    240,
  );
  const description = boundedText(row.description, 2_000);
  const badgeNameValue = row.badge_name ?? row.badgeName;
  const badgeName =
    badgeNameValue == null || badgeNameValue === ""
      ? ""
      : boundedText(badgeNameValue, 80);
  const notesValue = row.implementation_notes ?? row.implementationNotes;
  const implementationNotes =
    notesValue == null || notesValue === ""
      ? null
      : boundedText(notesValue, 2_000);
  const sortOrder = boundedInteger(
    row.sort_order ?? row.sortOrder,
    0,
    1_000_000,
  );
  const isActiveValue = row.is_active ?? row.isActive;
  const createdAt = boundedDate(row.created_at ?? row.createdAt);
  const updatedAt = boundedDate(row.updated_at ?? row.updatedAt);

  if (
    id == null ||
    (clubValue != null && clubId == null) ||
    code == null ||
    !/^G\d{3}$/.test(code) ||
    (scopeValue !== "generic" && scopeValue !== "club_specific") ||
    category == null ||
    itemName == null ||
    fetValue == null ||
    triggerCondition == null ||
    activationTiming == null ||
    description == null ||
    badgeName == null ||
    implementationNotes === undefined ||
    sortOrder == null ||
    typeof isActiveValue !== "boolean" ||
    createdAt == null ||
    updatedAt == null
  ) {
    return null;
  }

  return {
    id,
    clubId,
    code,
    templateScope: scopeValue,
    category,
    itemName,
    fetValue,
    triggerCondition,
    activationTiming,
    description,
    badgeName,
    implementationNotes,
    sortOrder,
    isActive: isActiveValue,
    createdAt,
    updatedAt,
  };
}

export function normalizeAdminFanEngagementTokens(
  value: unknown,
): AdminFanEngagementToken[] {
  if (!Array.isArray(value)) return [];
  const normalized: AdminFanEngagementToken[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_FET_RECORDS)) {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      continue;
    }
    const token = mapAdminFanEngagementToken(entry as Record<string, unknown>);
    if (token != null && !seen.has(token.id)) {
      normalized.push(token);
      seen.add(token.id);
    }
  }
  return normalized;
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
  options: { signal?: AbortSignal } = {},
): Promise<AdminFanEngagementToken[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("gamification", {
      signal: options.signal,
    });
    return normalizeAdminFanEngagementTokens(result);
  }

  const clubId = requireAdminClubId(access, "load FET catalog");
  const { data, error } = await client
    .from(fanEngagementTokenTable)
    .select("*")
    .eq("club_id", clubId)
    .order("sort_order", { ascending: true })
    .order("code", { ascending: true })
    .limit(MAX_FET_RECORDS);

  if (error) {
    throw new Error(error.message);
  }

  return normalizeAdminFanEngagementTokens(data);
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

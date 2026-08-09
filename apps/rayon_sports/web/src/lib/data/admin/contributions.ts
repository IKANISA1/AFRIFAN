/**
 * Admin contributions — public initiative snapshot, Excel export, initiative CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminContributionGroup,
  AdminContributionItem,
  AdminContributionSnapshot,
} from "@/lib/types";
import { requestAdminApi } from "./http";
import {
  contributionTable,
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

const contributionWriteTable = "groups";

function mapContributionGroup(
  row: Record<string, unknown>,
): AdminContributionGroup | null {
  const id = boundedText(row.id, 128);
  const name = boundedText(row.name, 160);
  const description = boundedOptionalText(row.description, 3_000);
  const normalizedType =
    typeof row.group_type === "string" ? row.group_type.toLowerCase() : "";
  const targetAmount = boundedNumber(
    row.target_amount,
    0,
    1_000_000_000_000_000,
  );
  const currentTotal = boundedNumber(
    row.current_total,
    0,
    1_000_000_000_000_000,
  );
  const currency =
    typeof row.currency === "string" && /^[A-Z]{3}$/.test(row.currency)
      ? row.currency
      : null;
  const memberCount = boundedInteger(row.member_count, 0, 1_000_000_000);
  const creatorId =
    row.creator_id == null ? null : boundedText(row.creator_id, 128);
  const createdAt = boundedDate(row.created_at);
  const updatedAt = boundedDate(row.updated_at);
  const isClosed =
    row.is_closed == null
      ? false
      : typeof row.is_closed === "boolean"
        ? row.is_closed
        : null;

  if (
    id == null ||
    name == null ||
    description == null ||
    (normalizedType !== "project" && normalizedType !== "community") ||
    targetAmount == null ||
    currentTotal == null ||
    currency == null ||
    memberCount == null ||
    createdAt == null ||
    updatedAt == null ||
    isClosed == null ||
    (row.creator_id != null && creatorId == null)
  ) {
    return null;
  }

  return {
    id,
    name,
    description,
    groupType: normalizedType === "project" ? "project" : "community",
    targetAmount,
    currentTotal,
    currency,
    memberCount,
    isActive: !isClosed,
    creatorId,
    createdAt,
    updatedAt,
    isClosed,
  };
}

function mapContributionItem(
  row: Record<string, unknown>,
): AdminContributionItem | null {
  const id = boundedText(row.id, 128);
  const groupId = boundedText(row.group_id, 128);
  const userId = boundedText(row.user_id, 128);
  const amount = boundedNumber(row.amount, 0, 1_000_000_000_000_000);
  const status = boundedText(row.status, 32)?.toLowerCase() ?? null;
  const createdAt = boundedDate(row.created_at);
  if (
    id == null ||
    groupId == null ||
    userId == null ||
    amount == null ||
    status == null ||
    !contributionStatuses.has(status) ||
    createdAt == null
  ) {
    return null;
  }
  return {
    id,
    groupId,
    userId,
    amount,
    status,
    createdAt,
  };
}

function boundedText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return null;
  }
  const text = value.trim();
  return text.length > 0 && text.length <= maxLength ? text : null;
}

function boundedOptionalText(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return null;
  }
  const text = value.trim();
  return text.length <= maxLength ? text : null;
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

const contributionStatuses = new Set([
  "pending",
  "confirmed",
  "completed",
  "failed",
  "reversed",
  "cancelled",
]);

function contributionCountsAsRaised(status: string) {
  return status === "confirmed" || status === "completed";
}

export function calculateContributionMonthlyTotal(
  contributions: readonly AdminContributionItem[],
  now = new Date(),
) {
  return contributions.reduce((sum, item) => {
    const createdAt = new Date(item.createdAt);
    if (
      !Number.isFinite(createdAt.getTime()) ||
      createdAt.getUTCFullYear() !== now.getUTCFullYear() ||
      createdAt.getUTCMonth() !== now.getUTCMonth() ||
      !contributionCountsAsRaised(item.status)
    ) {
      return sum;
    }
    return sum + item.amount;
  }, 0);
}

export function normalizeAdminContributionSnapshot(
  value: unknown,
): AdminContributionSnapshot {
  const empty: AdminContributionSnapshot = {
    groups: [],
    contributions: [],
    monthlyTotal: 0,
  };
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return empty;
  }

  const record = value as Record<string, unknown>;
  if (!Array.isArray(record.groups) || !Array.isArray(record.contributions)) {
    return empty;
  }

  const groups = record.groups.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const group = entry as Record<string, unknown>;
    const id = boundedText(group.id, 128);
    const name = boundedText(group.name, 160);
    const description = boundedOptionalText(group.description, 3_000);
    const groupType: AdminContributionGroup["groupType"] | null =
      group.groupType === "project" || group.groupType === "community"
        ? group.groupType
        : null;
    const targetAmount = boundedNumber(
      group.targetAmount,
      0,
      1_000_000_000_000_000,
    );
    const currentTotal = boundedNumber(
      group.currentTotal,
      0,
      1_000_000_000_000_000,
    );
    const currency =
      typeof group.currency === "string" && /^[A-Z]{3}$/.test(group.currency)
        ? group.currency
        : null;
    const memberCount = boundedInteger(group.memberCount, 0, 1_000_000_000);
    const creatorId =
      group.creatorId == null ? null : boundedText(group.creatorId, 128);
    const createdAt = boundedDate(group.createdAt);
    const updatedAt = boundedDate(group.updatedAt);

    if (
      id == null ||
      name == null ||
      description == null ||
      groupType == null ||
      targetAmount == null ||
      currentTotal == null ||
      currency == null ||
      memberCount == null ||
      createdAt == null ||
      updatedAt == null ||
      typeof group.isActive !== "boolean" ||
      typeof group.isClosed !== "boolean" ||
      (group.creatorId != null && creatorId == null)
    ) {
      return [];
    }

    return [
      {
        id,
        name,
        description,
        groupType,
        targetAmount,
        currentTotal,
        currency,
        memberCount,
        isActive: group.isActive,
        creatorId,
        createdAt,
        updatedAt,
        isClosed: group.isClosed,
      },
    ];
  });

  const groupIds = new Set(groups.map((group) => group.id));
  const contributions = record.contributions.slice(0, 500).flatMap((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      return [];
    }
    const item = entry as Record<string, unknown>;
    const id = boundedText(item.id, 128);
    const groupId = boundedText(item.groupId, 128);
    const userId = boundedText(item.userId, 128);
    const amount = boundedNumber(item.amount, 0, 1_000_000_000_000_000);
    const status = boundedText(item.status, 32);
    const createdAt = boundedDate(item.createdAt);

    if (
      id == null ||
      groupId == null ||
      !groupIds.has(groupId) ||
      userId == null ||
      amount == null ||
      status == null ||
      !contributionStatuses.has(status) ||
      createdAt == null
    ) {
      return [];
    }
    return [{ id, groupId, userId, amount, status, createdAt }];
  });

  return {
    groups,
    contributions,
    monthlyTotal:
      boundedNumber(record.monthlyTotal, 0, 1_000_000_000_000_000) ?? 0,
  };
}

export async function getAdminContributionSnapshot(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminContributionSnapshot> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminContributionSnapshot>("contributions", {
      signal: options.signal,
    });
  }
  const clubId = requireAdminClubId(access, "load contribution groups");

  // Fetch groups scoped to the admin's club
  const groupsQuery = client
    .from(contributionTable)
    .select(
      "id, name, description, group_type, target_amount, current_total, member_count, is_closed, created_at, updated_at, currency",
    )
    .eq("club_id", clubId)
    .order("created_at", { ascending: false })
    .limit(500);

  const groupsResult = await groupsQuery;
  if (groupsResult.error) throw new Error(groupsResult.error.message);

  const groups = Array.isArray(groupsResult.data)
    ? groupsResult.data.flatMap((row) => {
        const group = mapContributionGroup(row as Record<string, unknown>);
        return group == null ? [] : [group];
      })
    : [];
  const groupIds = groups.map((group) => group.id);

  // Fetch contributions scoped to this club's groups at the DB level
  let scopedContributions: AdminContributionItem[] = [];
  if (groupIds.length > 0) {
    const contributionsResult = await client
      .from("contributions")
      .select("id, group_id, user_id, amount, status, created_at")
      .in("group_id", groupIds)
      .order("created_at", { ascending: false })
      .limit(500);
    if (contributionsResult.error)
      throw new Error(contributionsResult.error.message);
    scopedContributions = Array.isArray(contributionsResult.data)
      ? contributionsResult.data.flatMap((row) => {
          const item = mapContributionItem(row as Record<string, unknown>);
          return item == null || !groupIds.includes(item.groupId) ? [] : [item];
        })
      : [];
  }

  const monthlyTotal = calculateContributionMonthlyTotal(scopedContributions);

  return { groups, contributions: scopedContributions, monthlyTotal };
}

function safeSpreadsheetText(value: string) {
  const normalized = value.replace(/[\u0000-\u001f\u007f]/g, " ").trim();
  return /^[=+\-@]/.test(normalized) ? `'${normalized}` : normalized;
}

export function buildContributionExcel(snapshot: AdminContributionSnapshot) {
  const headers = [
    "Name",
    "Type",
    "Currency",
    "Total",
    "Target",
    "Contributors",
    "Status",
    "Created",
  ];
  const rows = snapshot.groups.map((group) => [
    safeSpreadsheetText(group.name),
    group.groupType,
    group.currency,
    group.currentTotal,
    group.targetAmount,
    group.memberCount,
    group.isClosed ? "Closed" : "Active",
    new Date(group.createdAt).toLocaleDateString("en-RW", {
      year: "numeric",
      month: "short",
      day: "numeric",
    }),
  ]);
  return { headers, rows };
}

export async function downloadContributionExcel(
  snapshot: AdminContributionSnapshot,
) {
  const ExcelJS = await import("exceljs");
  const { headers, rows } = buildContributionExcel(snapshot);
  const workbook = new ExcelJS.Workbook();
  const worksheet = workbook.addWorksheet("Contributions");

  worksheet.addRow(headers);
  for (const row of rows) {
    worksheet.addRow(row);
  }

  worksheet.getRow(1).font = { bold: true };
  worksheet.columns = headers.map((header, index) => ({
    width: Math.max(
      header.length,
      ...rows.map((row) => String(row[index] ?? "").length),
      12,
    ),
  }));

  const buffer = await workbook.xlsx.writeBuffer();
  const blob = new Blob([buffer], {
    type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = `club-contributions-${new Date().toISOString().slice(0, 10)}.xlsx`;
  anchor.click();
  URL.revokeObjectURL(url);
}

export async function saveAdminContributionGroup(
  client: SupabaseClient,
  access: AdminAccess,
  input: {
    id?: string | null;
    expectedUpdatedAt?: string | null;
    name: string;
    description: string;
    groupType: AdminContributionGroup["groupType"];
    targetAmount: number;
    currentTotal: number;
    currency: string;
    memberCount: number;
    isClosed: boolean;
  },
) {
  const normalized = normalizeContributionGroupInput(input);
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("contributions", {
      method: "POST",
      body: normalized,
    });
  }
  const clubId = requireAdminClubId(access, "save contribution groups");
  return mutateRecordWithVariantsIfUnchanged(
    client,
    contributionWriteTable,
    normalized.id,
    normalized.expectedUpdatedAt,
    buildContributionGroupMutationPayload(normalized, clubId),
    { club_id: clubId },
  );
}

export function normalizeContributionGroupInput(input: {
  id?: string | null;
  expectedUpdatedAt?: string | null;
  name: string;
  description: string;
  groupType: AdminContributionGroup["groupType"];
  targetAmount: number;
  currentTotal: number;
  currency: string;
  memberCount: number;
  isClosed: boolean;
}) {
  const id = input.id == null ? null : boundedText(input.id, 128);
  const expectedUpdatedAt =
    input.expectedUpdatedAt == null
      ? null
      : boundedDate(input.expectedUpdatedAt);
  const name = boundedText(input.name, 160);
  const description = boundedOptionalText(input.description, 3_000);
  const targetAmount = boundedNumber(
    input.targetAmount,
    0,
    1_000_000_000_000_000,
  );
  const currentTotal = boundedNumber(
    input.currentTotal,
    0,
    1_000_000_000_000_000,
  );
  const currency =
    typeof input.currency === "string"
      ? input.currency.trim().toUpperCase()
      : "";
  const memberCount = boundedInteger(input.memberCount, 0, 1_000_000_000);

  if (
    (input.id != null && id == null) ||
    (input.expectedUpdatedAt != null && expectedUpdatedAt == null) ||
    name == null ||
    description == null ||
    (input.groupType !== "project" && input.groupType !== "community") ||
    targetAmount == null ||
    currentTotal == null ||
    !/^[A-Z]{3}$/.test(currency) ||
    memberCount == null ||
    typeof input.isClosed !== "boolean"
  ) {
    throw new Error("Contribution initiative fields are invalid.");
  }

  return {
    id,
    expectedUpdatedAt,
    name,
    description,
    groupType: input.groupType,
    targetAmount,
    currentTotal,
    currency,
    memberCount,
    isClosed: input.isClosed,
  };
}

export function buildContributionGroupMutationPayload(
  input: ReturnType<typeof normalizeContributionGroupInput>,
  clubId: string | number,
) {
  const derivedLedgerFields =
    input.id == null ? { current_total: 0, member_count: 0 } : {};
  const shared = {
    club_id: clubId,
    name: input.name,
    description: input.description,
    group_type: input.groupType,
    visibility: "public",
    target_amount: input.targetAmount,
    currency: input.currency,
    ...derivedLedgerFields,
    is_closed: input.isClosed,
  };
  return [{ ...shared, is_active: !input.isClosed }, shared];
}

export async function deleteAdminContributionGroup(
  client: SupabaseClient,
  access: AdminAccess,
  groupId: string,
  expectedUpdatedAt: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("contributions", {
      method: "DELETE",
      query: { id: groupId, expected_updated_at: expectedUpdatedAt },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete contribution groups");
  await deleteAdminRecordWithAuditIfUnchanged(
    client,
    contributionWriteTable,
    groupId,
    expectedUpdatedAt,
    { club_id: clubId },
    {
      actorId: access.userId,
      clubId,
      action: "delete_contribution_group",
      source: "admin_contributions",
    },
  );
}

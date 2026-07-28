/**
 * Admin contributions — public initiative snapshot, Excel export, initiative CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { fallbackClubProfile } from "@/lib/content";
import type { AdminAccess, AdminContributionGroup, AdminContributionItem, AdminContributionSnapshot } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  contributionTable,
  deleteAdminRecordWithAuditIfUnchanged,
  mutateRecordWithVariantsIfUnchanged,
  requireAdminClubId,
} from "./helpers";

const contributionWriteTable = "groups";

function mapContributionGroup(row: Record<string, unknown>): AdminContributionGroup {
  const normalizedType = safeString(row.group_type).toLowerCase();
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Public initiative"),
    description: safeString(row.description, "Admin-managed public initiative."),
    groupType: normalizedType === "project" ? "project" : "community",
    targetAmount: safeNumber(row.target_amount, 0),
    currentTotal: safeNumber(row.current_total, 0),
    currency: safeString(row.currency, fallbackClubProfile.currencyCode),
    memberCount: safeNumber(row.member_count, 0),
    isActive: row.is_closed !== true,
    creatorId: safeString(row.creator_id) || null,
    createdAt: safeString(row.created_at, new Date().toISOString()),
    updatedAt: safeString(row.updated_at, new Date(0).toISOString()),
    isClosed: row.is_closed === true,
  };
}

function mapContributionItem(row: Record<string, unknown>): AdminContributionItem {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    groupId: safeString(row.group_id),
    userId: safeString(row.user_id),
    amount: safeNumber(row.amount, 0),
    status: safeString(row.status, "pending"),
    createdAt: safeString(row.created_at, new Date().toISOString()),
  };
}

export async function getAdminContributionSnapshot(client: SupabaseClient, access: AdminAccess): Promise<AdminContributionSnapshot> {
  if (typeof window !== "undefined") {
    return requestAdminApi<AdminContributionSnapshot>("contributions");
  }
  const clubId = requireAdminClubId(access, "load contribution groups");

  // Fetch groups scoped to the admin's club
  const groupsQuery = client
    .from(contributionTable)
    .select("id, name, description, group_type, target_amount, current_total, member_count, creator_id, is_closed, created_at, updated_at, currency")
    .eq("club_id", clubId)
    .order("created_at", { ascending: false });

  const groupsResult = await groupsQuery;
  if (groupsResult.error) throw new Error(groupsResult.error.message);

  const groups = Array.isArray(groupsResult.data) ? groupsResult.data.map((row) => mapContributionGroup(row as Record<string, unknown>)) : [];
  const groupIds = groups.map((group) => group.id);

  // Fetch contributions scoped to this club's groups at the DB level
  let scopedContributions: AdminContributionItem[] = [];
  if (groupIds.length > 0) {
    const contributionsResult = await client.from("contributions").select("id, group_id, user_id, amount, status, created_at").in("group_id", groupIds).order("created_at", { ascending: false }).limit(500);
    if (contributionsResult.error) throw new Error(contributionsResult.error.message);
    scopedContributions = Array.isArray(contributionsResult.data) ? contributionsResult.data.map((row) => mapContributionItem(row as Record<string, unknown>)) : [];
  }

  const today = new Date();
  const monthlyTotal = scopedContributions.reduce((sum, item) => {
    const createdAt = new Date(item.createdAt);
    if (createdAt.getUTCFullYear() !== today.getUTCFullYear() || createdAt.getUTCMonth() !== today.getUTCMonth() || item.status === "failed" || item.status === "reversed") return sum;
    return sum + item.amount;
  }, 0);

  return { groups, contributions: scopedContributions, monthlyTotal };
}

export function buildContributionExcel(snapshot: AdminContributionSnapshot) {
  const currencyCode = fallbackClubProfile.currencyCode;
  const headers = [
    "Name",
    "Type",
    `Total (${currencyCode})`,
    `Target (${currencyCode})`,
    "Contributors",
    "Status",
    "Created",
  ];
  const rows = snapshot.groups.map((group) => [
    group.name, group.groupType, group.currentTotal, group.targetAmount, group.memberCount,
    group.isClosed ? "Closed" : "Active",
    new Date(group.createdAt).toLocaleDateString("en-RW", { year: "numeric", month: "short", day: "numeric" }),
  ]);
  return { headers, rows };
}

export async function downloadContributionExcel(snapshot: AdminContributionSnapshot) {
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
  client: SupabaseClient, access: AdminAccess,
  input: { id?: string | null; expectedUpdatedAt?: string | null; name: string; description: string; groupType: AdminContributionGroup["groupType"]; targetAmount: number; currentTotal: number; currency: string; memberCount: number; isClosed: boolean },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("contributions", {
      method: "POST",
      body: input,
    });
  }
  const clubId = requireAdminClubId(access, "save contribution groups");
  return mutateRecordWithVariantsIfUnchanged(client, contributionWriteTable, input.id, input.expectedUpdatedAt, [
    {
      club_id: clubId,
      name: input.name.trim(),
      description: input.description.trim(),
      group_type: input.groupType,
      visibility: "public",
      target_amount: safeNumber(input.targetAmount, 0),
      current_total: safeNumber(input.currentTotal, 0),
      currency: input.currency.trim() || fallbackClubProfile.currencyCode,
      member_count: safeNumber(input.memberCount, 0),
      is_closed: input.isClosed,
      is_active: input.isClosed !== true,
    },
    {
      club_id: clubId,
      name: input.name.trim(),
      description: input.description.trim(),
      group_type: input.groupType,
      visibility: "public",
      target_amount: safeNumber(input.targetAmount, 0),
      current_total: safeNumber(input.currentTotal, 0),
      currency: input.currency.trim() || fallbackClubProfile.currencyCode,
      member_count: safeNumber(input.memberCount, 0),
      is_closed: input.isClosed,
    },
  ], { club_id: clubId });
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

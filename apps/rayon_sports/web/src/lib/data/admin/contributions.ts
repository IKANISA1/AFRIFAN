/**
 * Admin contributions — circles snapshot, Excel export, group CRUD.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import { fallbackClubProfile } from "@/lib/content";
import type { AdminAccess, AdminContributionGroup, AdminContributionItem, AdminContributionSnapshot } from "@/lib/types";
import { safeNumber, safeString, toIdString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  contributionTable,
  deleteRecordWithMatchers,
  mutateRecordWithVariants,
  requireAdminClubId,
} from "./helpers";

function mapContributionGroup(row: Record<string, unknown>): AdminContributionGroup {
  return {
    id: toIdString(row.id, crypto.randomUUID()),
    name: safeString(row.name, "Support circle"),
    description: safeString(row.description, "Supporter funding circle."),
    privacy: safeString(row.privacy) === "public" ? "public" : "private",
    groupType:
      safeString(row.group_type) === "project" || safeString(row.group_type) === "savings" || safeString(row.group_type) === "emergency"
        ? (safeString(row.group_type) as AdminContributionGroup["groupType"])
        : "general",
    targetAmount: safeNumber(row.target_amount, 0),
    currentTotal: safeNumber(row.current_total, 0),
    currency: safeString(row.currency, fallbackClubProfile.currencyCode),
    memberCount: safeNumber(row.member_count, 0),
    inviteCode: safeString(row.invite_code) || null,
    isActive: row.is_closed !== true,
    creatorId: safeString(row.creator_id) || null,
    createdAt: safeString(row.created_at, new Date().toISOString()),
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
    .select("id, name, description, group_type, privacy, target_amount, current_total, member_count, creator_id, invite_code, is_closed, created_at, currency")
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

  const creatorIds = groups.map((group) => group.creatorId).filter((value): value is string => Boolean(value));
  const aliases: Record<string, string> = {};
  if (creatorIds.length > 0) {
    const { data } = await client.from("profiles").select("id, public_user_id").in("id", creatorIds);
    if (Array.isArray(data)) {
      for (const profile of data) {
        const row = profile as Record<string, unknown>;
        const id = safeString(row.id);
        const alias = safeString(row.public_user_id);
        if (id && alias) aliases[id] = alias;
      }
    }
  }

  const today = new Date();
  const monthlyTotal = scopedContributions.reduce((sum, item) => {
    const createdAt = new Date(item.createdAt);
    if (createdAt.getUTCFullYear() !== today.getUTCFullYear() || createdAt.getUTCMonth() !== today.getUTCMonth() || item.status === "failed" || item.status === "reversed") return sum;
    return sum + item.amount;
  }, 0);

  return { groups, contributions: scopedContributions, aliases, monthlyTotal };
}

export function buildContributionExcel(snapshot: AdminContributionSnapshot) {
  const headers = ["Name", "Type", "Total (RWF)", "Target (RWF)", "Contributors", "Status", "Created"];
  const rows = snapshot.groups.map((group) => [
    group.name, group.groupType, group.currentTotal, group.targetAmount, group.memberCount,
    group.isClosed ? "Closed" : "Active",
    new Date(group.createdAt).toLocaleDateString("en-RW", { year: "numeric", month: "short", day: "numeric" }),
  ]);
  return { headers, rows };
}

export async function downloadContributionExcel(snapshot: AdminContributionSnapshot) {
  const XLSX = await import("xlsx");
  const { headers, rows } = buildContributionExcel(snapshot);
  const data = [headers, ...rows];
  const workbook = XLSX.utils.book_new();
  const worksheet = XLSX.utils.aoa_to_sheet(data);
  worksheet["!cols"] = headers.map((header, i) => ({ wch: Math.max(header.length, ...rows.map((row) => String(row[i] ?? "").length), 12) }));
  XLSX.utils.book_append_sheet(workbook, worksheet, "Contributions");
  XLSX.writeFile(
    workbook,
    `club-contributions-${new Date().toISOString().slice(0, 10)}.xlsx`,
  );
}

export async function saveAdminContributionGroup(
  client: SupabaseClient, access: AdminAccess,
  input: { id?: string | null; name: string; description: string; privacy: AdminContributionGroup["privacy"]; groupType: AdminContributionGroup["groupType"]; targetAmount: number; currentTotal: number; currency: string; memberCount: number; inviteCode?: string | null; isClosed: boolean },
) {
  if (typeof window !== "undefined") {
    return requestAdminApi<string>("contributions", {
      method: "POST",
      body: input,
    });
  }
  const clubId = requireAdminClubId(access, "save contribution groups");
  return mutateRecordWithVariants(client, contributionTable, input.id, [
    { club_id: clubId, name: input.name.trim(), description: input.description.trim(), privacy: input.privacy, group_type: input.groupType, target_amount: safeNumber(input.targetAmount, 0), current_total: safeNumber(input.currentTotal, 0), currency: input.currency.trim() || fallbackClubProfile.currencyCode, member_count: safeNumber(input.memberCount, 0), invite_code: safeString(input.inviteCode) || null, is_closed: input.isClosed, is_active: input.isClosed !== true },
    { club_id: clubId, name: input.name.trim(), description: input.description.trim(), privacy: input.privacy, group_type: input.groupType, target_amount: safeNumber(input.targetAmount, 0), current_total: safeNumber(input.currentTotal, 0), currency: input.currency.trim() || fallbackClubProfile.currencyCode, member_count: safeNumber(input.memberCount, 0), invite_code: safeString(input.inviteCode) || null, is_closed: input.isClosed },
  ], { club_id: clubId });
}

export async function deleteAdminContributionGroup(
  client: SupabaseClient,
  access: AdminAccess,
  groupId: string,
) {
  if (typeof window !== "undefined") {
    await requestAdminApi<{ success: true }>("contributions", {
      method: "DELETE",
      query: { id: groupId },
    });
    return;
  }
  const clubId = requireAdminClubId(access, "delete contribution groups");
  await deleteRecordWithMatchers(client, contributionTable, groupId, {
    club_id: clubId,
  });
}

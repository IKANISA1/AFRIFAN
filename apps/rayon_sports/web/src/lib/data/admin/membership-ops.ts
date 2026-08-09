/**
 * Admin membership operations — supporter registry and application review.
 */
import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  AdminAccess,
  AdminMembershipApplication,
  AdminSupporter,
  MembershipTierSlug,
} from "@/lib/types";
import { safeString } from "@/lib/utils";
import { requestAdminApi } from "./http";
import {
  AdminMutationConflictError,
  requireAdminClubId,
  requireExpectedUpdatedAt,
} from "./helpers";

type SupporterRegistryRow = {
  id: unknown;
  user_id: string | null;
  display_name: string | null;
  tier: AdminSupporter["tier"] | null;
  status: string | null;
  points: number | null;
  chapter: string | null;
  membership_number: string | null;
  joined_at: string | null;
  profiles?: { phone?: string | null } | null;
};

type MembershipApplicationRow = {
  id: unknown;
  user_id: string | null;
  tier: string | null;
  status: string | null;
  payment_status: string | null;
  application_date: string | null;
  created_at: string | null;
  review_date: string | null;
  reviewer_id: string | null;
  notes: string | null;
  updated_at: string | null;
  metadata?:
    | {
        chapter?: string | null;
        applicant_name?: string | null;
        applicant_phone?: string | null;
        full_name?: string | null;
        phone?: string | null;
      }
    | null;
};

const MAX_SUPPORTERS = 500;
const MAX_APPLICATIONS = 500;

function boundedText(
  value: unknown,
  maxLength: number,
  allowEmpty = false,
) {
  if (typeof value !== "string") return null;
  const text = value.trim();
  if (text.length > maxLength || (!allowEmpty && text.length === 0)) return null;
  return text;
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

function nullableText(value: unknown, maxLength: number) {
  if (value == null || value === "") return null;
  return boundedText(value, maxLength);
}

function nullableDate(value: unknown) {
  if (value == null || value === "") return null;
  return boundedDate(value);
}

function normalizeMembershipTier(value: unknown): MembershipTierSlug | null {
  if (typeof value !== "string") return null;
  switch (value.trim().toLowerCase()) {
    case "ingenzi-imanzi":
    case "ingenzi_imanzi":
    case "ingenzi":
    case "imanzi":
      return "ingenzi-imanzi";
    case "inyamibwa":
      return "inyamibwa";
    case "imena":
      return "imena";
    case "bronze":
      return "bronze";
    case "silver":
      return "silver";
    case "gold":
      return "gold";
    default:
      return null;
  }
}

function normalizeSupporterStatus(value: unknown): AdminSupporter["status"] | null {
  return value === "active" ||
    value === "pending" ||
    value === "suspended" ||
    value === "expired"
    ? value
    : null;
}

function mapAdminSupporter(
  row: Record<string, unknown>,
): AdminSupporter | null {
  const id = boundedText(row.id, 128);
  const userId = boundedText(row.userId ?? row.user_id, 128);
  const displayName = boundedText(
    row.displayName ?? row.display_name,
    160,
  );
  const phone = nullableText(
    row.phone ??
      ((row.profiles as { phone?: unknown } | null | undefined)?.phone ?? null),
    32,
  );
  const tier = normalizeMembershipTier(row.tier);
  const status = normalizeSupporterStatus(row.status);
  const points = boundedInteger(row.points, 0, 1_000_000_000);
  const chapter = boundedText(row.chapter, 120);
  const membershipNumber = boundedText(
    row.membershipNumber ?? row.membership_number,
    80,
  );
  const joinedAt = boundedDate(row.joinedAt ?? row.joined_at);
  if (
    id == null ||
    userId == null ||
    displayName == null ||
    phone === undefined ||
    tier == null ||
    status == null ||
    points == null ||
    chapter == null ||
    membershipNumber == null ||
    joinedAt == null
  ) {
    return null;
  }
  return {
    id,
    userId,
    displayName,
    phone,
    tier,
    status,
    points,
    chapter,
    membershipNumber,
    joinedAt,
  };
}

export function normalizeAdminSupporters(value: unknown): AdminSupporter[] {
  if (!Array.isArray(value)) return [];
  const supporters: AdminSupporter[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_SUPPORTERS)) {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      continue;
    }
    const supporter = mapAdminSupporter(entry as Record<string, unknown>);
    if (supporter != null && !seen.has(supporter.id)) {
      supporters.push(supporter);
      seen.add(supporter.id);
    }
  }
  return supporters;
}

function normalizeApplicationStatus(
  value: unknown,
): AdminMembershipApplication["status"] | null {
  return value === "pending" || value === "approved" || value === "rejected"
    ? value
    : null;
}

function normalizePaymentStatus(
  value: unknown,
): AdminMembershipApplication["paymentStatus"] | null {
  return value === "unpaid" || value === "paid" || value === "failed"
    ? value
    : null;
}

function mapAdminMembershipApplication(
  row: Record<string, unknown>,
): AdminMembershipApplication | null {
  const id = boundedText(row.id, 128);
  const userId = boundedText(row.userId ?? row.user_id, 128);
  const clubId = boundedInteger(
    row.clubId ?? row.club_id,
    1,
    2_147_483_647,
  );
  const tier = normalizeMembershipTier(row.tier);
  const status = normalizeApplicationStatus(row.status);
  const paymentStatus = normalizePaymentStatus(
    row.paymentStatus ?? row.payment_status,
  );
  const applicationDate = boundedDate(
    row.applicationDate ?? row.application_date ?? row.created_at,
  );
  const reviewDate = nullableDate(row.reviewDate ?? row.review_date);
  const reviewerId = nullableText(row.reviewerId ?? row.reviewer_id, 128);
  const notes = nullableText(row.notes, 1_000);
  const userName = nullableText(row.userName, 160);
  const userPhone = nullableText(row.userPhone, 32);
  const updatedAt = boundedDate(row.updatedAt ?? row.updated_at);
  if (
    id == null ||
    userId == null ||
    clubId == null ||
    tier == null ||
    status == null ||
    paymentStatus == null ||
    applicationDate == null ||
    reviewDate === undefined ||
    reviewerId === undefined ||
    notes === undefined ||
    userName === undefined ||
    userPhone === undefined ||
    updatedAt == null
  ) {
    return null;
  }
  return {
    id,
    userId,
    clubId,
    tier,
    status,
    paymentStatus,
    applicationDate,
    reviewDate,
    reviewerId,
    notes,
    userName: userName ?? undefined,
    userPhone: userPhone ?? undefined,
    updatedAt,
  };
}

export function normalizeAdminMembershipApplications(
  value: unknown,
): AdminMembershipApplication[] {
  if (!Array.isArray(value)) return [];
  const applications: AdminMembershipApplication[] = [];
  const seen = new Set<string>();
  for (const entry of value.slice(0, MAX_APPLICATIONS)) {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      continue;
    }
    const application = mapAdminMembershipApplication(
      entry as Record<string, unknown>,
    );
    if (application != null && !seen.has(application.id)) {
      applications.push(application);
      seen.add(application.id);
    }
  }
  return applications;
}

type ProfileRow = {
  id: string | null;
  full_name?: string | null;
  phone?: string | null;
};

type UserRow = {
  id: string | null;
  full_name?: string | null;
  phone?: string | null;
};

export async function getAdminSupporterRegistry(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminSupporter[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("membership-supporters", {
      signal: options.signal,
    });
    return normalizeAdminSupporters(result);
  }
  const clubId = requireAdminClubId(access, "load supporters");
  
  const { data, error } = await client
    .from("fan_memberships")
    .select(`
      id,
      user_id,
      display_name,
      tier,
      status,
      points,
      chapter,
      membership_number,
      joined_at,
      profiles:user_id (phone)
    `)
    .eq("club_id", clubId)
    .order("joined_at", { ascending: false })
    .limit(MAX_SUPPORTERS);

  if (error) throw new Error(error.message);

  const rows = (data ?? []) as SupporterRegistryRow[];

  return normalizeAdminSupporters(rows);
}

export async function getAdminMembershipApplications(
  client: SupabaseClient,
  access: AdminAccess,
  options: { signal?: AbortSignal } = {},
): Promise<AdminMembershipApplication[]> {
  if (typeof window !== "undefined") {
    const result = await requestAdminApi<unknown>("membership-applications", {
      signal: options.signal,
    });
    return normalizeAdminMembershipApplications(result);
  }
  const clubId = requireAdminClubId(access, "load applications");

  const { data, error } = await client
    .from("membership_applications")
    .select("*")
    .eq("club_id", clubId)
    .order("application_date", { ascending: false })
    .limit(MAX_APPLICATIONS);

  if (error) throw new Error(error.message);

  const applicationRows = (data ?? []) as MembershipApplicationRow[];
  const userIds = Array.from(
    new Set(
      applicationRows
        .map((row) => safeString(row.user_id, ""))
        .filter((value) => value.length > 0),
    ),
  );

  let profilesById = new Map<string, { full_name?: string | null; phone?: string | null }>();
  let usersById = new Map<string, { full_name?: string | null; phone?: string | null }>();
  if (userIds.length > 0) {
    const { data: profiles, error: profilesError } = await client
      .from("profiles")
      .select("id, full_name, phone")
      .in("id", userIds);

    if (profilesError) throw new Error(profilesError.message);

    profilesById = new Map(
      ((profiles ?? []) as ProfileRow[]).map((profile) => [
        safeString(profile.id, ""),
        {
          full_name: safeString(profile.full_name) || null,
          phone: safeString(profile.phone) || null,
        },
      ]),
    );

    const { data: users, error: usersError } = await client
      .from("users")
      .select("id, full_name, phone")
      .in("id", userIds);

    if (usersError) throw new Error(usersError.message);

    usersById = new Map(
      ((users ?? []) as UserRow[]).map((user) => [
        safeString(user.id, ""),
        {
          full_name: safeString(user.full_name) || null,
          phone: safeString(user.phone) || null,
        },
      ]),
    );
  }

  return normalizeAdminMembershipApplications(applicationRows.map((row) => {
    const userId = safeString(row.user_id, "");
    const profile = userId ? profilesById.get(userId) : undefined;
    const user = userId ? usersById.get(userId) : undefined;
    const metadataName =
      safeString(row.metadata?.applicant_name) || safeString(row.metadata?.full_name);
    const metadataPhone =
      safeString(row.metadata?.applicant_phone) || safeString(row.metadata?.phone);

    return {
      id: row.id,
      userId,
      clubId,
      tier: row.tier,
      status: row.status,
      paymentStatus: row.payment_status,
      applicationDate: row.application_date ?? row.created_at,
      reviewDate: row.review_date,
      reviewerId: row.reviewer_id,
      notes: row.notes,
      userName:
        safeString(profile?.full_name) ||
        safeString(user?.full_name) ||
        metadataName ||
        null,
      userPhone:
        safeString(profile?.phone) ||
        safeString(user?.phone) ||
        metadataPhone ||
        null,
      updatedAt: row.updated_at,
    };
  }));
}

export async function reviewMembershipApplication(
  client: SupabaseClient,
  access: AdminAccess,
  applicationId: string,
  expectedUpdatedAt: string,
  decision: "approved" | "rejected",
  notes?: string,
) {
  if (decision === "approved") {
    throw new Error(
      "Membership approval is disabled until provider payment reconciliation is verified independently.",
    );
  }
  if (typeof window !== "undefined") {
    await requestAdminApi("membership-applications/review", {
      method: "POST",
      body: { applicationId, expectedUpdatedAt, decision, notes },
    });
    return;
  }
  requireAdminClubId(access, "review application");
  const loadedVersion = requireExpectedUpdatedAt(expectedUpdatedAt);
  const { error } = await client.rpc(
    "review_membership_application_if_unchanged",
    {
      p_application_id: applicationId,
      p_expected_updated_at: loadedVersion,
      p_decision: decision,
      p_payment_status: "failed",
      p_actor_id: access.userId ?? null,
      p_notes: notes ?? null,
    },
  );

  if (error) {
    const message = error.message.toLowerCase();
    if (
      message.includes("changed after it was loaded") ||
      message.includes("no longer pending")
    ) {
      throw new AdminMutationConflictError(error.message);
    }
    throw new Error(error.message);
  }
}

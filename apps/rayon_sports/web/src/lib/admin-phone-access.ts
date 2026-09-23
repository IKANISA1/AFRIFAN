import type { SupabaseClient } from "@supabase/supabase-js";
import {
  normalizeAdminPhone,
  normalizeAdminPhoneDigits,
} from "@/lib/admin-auth";

export async function findEligibleAdminPhoneCandidate(
  client: SupabaseClient,
  rawPhone: string,
) {
  const phone = normalizeAdminPhone(rawPhone);
  const normalizedPhone = normalizeAdminPhoneDigits(phone);
  const { data, error } = await client
    .from("admin_phone_access")
    .select("user_id, phone, club_ids")
    .eq("normalized_phone", normalizedPhone)
    .maybeSingle();

  if (error) {
    throw new Error(error.message);
  }

  const row = data;
  if (row == null || typeof row !== "object") {
    return null;
  }

  return {
    userId: typeof row.user_id === "string" ? row.user_id : null,
    phone,
    clubIds: Array.isArray(row.club_ids)
      ? row.club_ids.filter((value: unknown): value is number => typeof value === "number")
      : [],
  };
}

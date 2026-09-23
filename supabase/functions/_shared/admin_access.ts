import { normalizePhone } from "./phone.ts";
import { createAdminClient } from "./supabase.ts";

export async function hasActiveAdminAssignmentForAuthUser(options: {
  userId?: string | null;
  phone?: string | null;
}) {
  const adminClient = createAdminClient();
  const normalizedPhone = options.phone
    ? normalizePhone(options.phone).replace(/\D/g, "")
    : null;
  if (!normalizedPhone) {
    return false;
  }

  const { data, error } = await adminClient
    .from("admin_phone_access")
    .select("user_id")
    .eq("normalized_phone", normalizedPhone);

  if (error) {
    throw new Error(error.message);
  }

  const rows = Array.isArray(data) ? data : [];
  if (rows.length === 0) {
    return false;
  }

  if (!options.userId) {
    return true;
  }

  return rows.some((row) =>
    row != null &&
    typeof row === "object" &&
    row.user_id === options.userId
  );
}

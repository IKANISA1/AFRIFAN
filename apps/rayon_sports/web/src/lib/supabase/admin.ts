import { createClient } from "@supabase/supabase-js";
import { hasServerSupabase, serverSupabaseConfig } from "@/lib/config";

let adminClient: ReturnType<typeof createClient> | null = null;

export function getAdminSupabase() {
  if (!hasServerSupabase()) {
    return null;
  }

  if (adminClient == null) {
    adminClient = createClient(
      serverSupabaseConfig.url,
      serverSupabaseConfig.serviceRoleKey || serverSupabaseConfig.anonKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );
  }

  return adminClient;
}

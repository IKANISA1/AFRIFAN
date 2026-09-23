import { createClient } from "@supabase/supabase-js";
import {
  hasAdminSupabase,
  hasServerSupabase,
  serverSupabaseConfig,
} from "@/lib/config";

let adminClient: ReturnType<typeof createClient> | null = null;
let readOnlyClient: ReturnType<typeof createClient> | null = null;

export function getReadOnlySupabase() {
  if (!hasServerSupabase()) {
    return null;
  }

  if (readOnlyClient == null) {
    readOnlyClient = createClient(
      serverSupabaseConfig.url,
      serverSupabaseConfig.anonKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      },
    );
  }

  return readOnlyClient;
}

export function getAdminSupabase() {
  if (!hasAdminSupabase()) {
    return null;
  }

  if (adminClient == null) {
    adminClient = createClient(
      serverSupabaseConfig.url,
      serverSupabaseConfig.serviceRoleKey,
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

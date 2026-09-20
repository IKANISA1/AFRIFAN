"use client";

import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
import { hasClientSupabase, publicSupabaseConfig } from "@/lib/config";

let browserClient: SupabaseClient | null = null;

export function getBrowserSupabase(): SupabaseClient | null {
  if (!hasClientSupabase()) {
    return null;
  }

  if (browserClient == null) {
    browserClient = createBrowserClient(
      publicSupabaseConfig.url,
      publicSupabaseConfig.anonKey,
    );
  }

  return browserClient;
}

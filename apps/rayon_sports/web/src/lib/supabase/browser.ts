"use client";

import { createBrowserClient } from "@supabase/ssr";
import { hasClientSupabase, publicSupabaseConfig } from "@/lib/config";

let browserClient: ReturnType<typeof createBrowserClient> | null = null;

export function getBrowserSupabase() {
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

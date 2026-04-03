import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { hasClientSupabase, publicSupabaseConfig } from "@/lib/config";

export async function getServerSupabase() {
  if (!hasClientSupabase()) {
    return null;
  }

  const cookieStore = await cookies();

  return createServerClient(publicSupabaseConfig.url, publicSupabaseConfig.anonKey, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(entries) {
        for (const { name, value, options } of entries) {
          cookieStore.set(name, value, options);
        }
      },
    },
  });
}

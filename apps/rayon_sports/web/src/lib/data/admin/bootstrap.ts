import { cookies } from "next/headers";
import { adminClubScopeCookieName, getRequestedAdminClubId } from "@/lib/admin-club-scope";
import { emptyAdminAccess, resolveAdminAccess } from "@/lib/data/admin/access";
import { getAdminClubScopeOptions } from "@/lib/data/admin/settings";
import { getServerSupabase } from "@/lib/supabase/server";
import type { AdminPortalInitialState } from "@/lib/types";

export async function getAdminPortalInitialState(): Promise<AdminPortalInitialState> {
  const serverClient = await getServerSupabase();
  if (serverClient == null) {
    return {
      session: null,
      user: null,
      access: emptyAdminAccess,
      clubOptions: [],
      error: "Supabase browser configuration is missing.",
    };
  }

  try {
    const cookieStore = await cookies();
    const requestedClubId = getRequestedAdminClubId(
      null,
      cookieStore.get(adminClubScopeCookieName)?.value ?? null,
    );
    const {
      data: { session },
    } = await serverClient.auth.getSession();
    const user = session?.user ?? null;
    const access = await resolveAdminAccess(serverClient, user, {
      requestedClubId,
    });
    const clubOptions = access.hasAccess
      ? await getAdminClubScopeOptions(serverClient, access).catch(() => [])
      : [];

    return {
      session,
      user,
      access,
      clubOptions,
      error: null,
    };
  } catch (caught) {
    return {
      session: null,
      user: null,
      access: emptyAdminAccess,
      clubOptions: [],
      error:
        caught instanceof Error
          ? caught.message
          : "Could not initialize admin workspace.",
    };
  }
}

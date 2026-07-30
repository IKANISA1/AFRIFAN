import { cookies, headers } from "next/headers";
import {
  adminClubScopeCookieName,
  getRequestedAdminClubId,
} from "@/lib/admin-club-scope";
import { isControlledAdminEvidenceAllowed } from "@/lib/controlled-admin-evidence";
import { emptyAdminAccess, resolveAdminAccess } from "@/lib/data/admin/access";
import { getAdminClubScopeOptions } from "@/lib/data/admin/settings";
import { getServerSupabase } from "@/lib/supabase/server";
import type { AdminPortalInitialState } from "@/lib/types";

function controlledAdminEvidenceState(): AdminPortalInitialState {
  const user = {
    id: "controlled-admin-evidence",
    app_metadata: {},
    user_metadata: {
      display_name: "Controlled local admin",
    },
    aud: "authenticated",
    created_at: "2026-07-29T00:00:00.000Z",
  };

  return {
    session: null,
    user,
    access: {
      hasAccess: true,
      isAuthenticated: true,
      isSuperAdmin: true,
      userId: user.id,
      role: "super_admin",
      clubId: "24",
      availableClubIds: ["24"],
      canSelectClub: false,
      assignmentCount: 1,
    },
    clubOptions: [
      {
        id: "24",
        clubName: "Rayon Sports",
        shortName: "Rayon",
        clubSlug: "rayon-sports",
        currencyCode: "RWF",
        currencySymbol: "RWF",
      },
    ],
    error: null,
    controlledEvidence: true,
  };
}

export async function getAdminPortalInitialState(): Promise<AdminPortalInitialState> {
  const requestHeaders = await headers();
  if (
    isControlledAdminEvidenceAllowed({
      previewEnabled: process.env.AFRICLUB_ALLOW_HTTP_PREVIEW,
      adminEvidenceEnabled:
        process.env.AFRICLUB_CONTROLLED_ADMIN_EVIDENCE,
      host:
        requestHeaders.get("x-forwarded-host") ??
        requestHeaders.get("host"),
    })
  ) {
    return controlledAdminEvidenceState();
  }

  const cookieStore = await cookies();
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

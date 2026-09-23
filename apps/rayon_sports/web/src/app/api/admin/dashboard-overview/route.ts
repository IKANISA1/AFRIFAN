import type { NextRequest } from "next/server";
import { handleAdminApiRoute } from "@/lib/admin-api-handler";
import {
  getAdminDashboardActions,
  getAdminDashboardSnapshot,
} from "@/lib/data/admin";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  return handleAdminApiRoute(request, async (adminClient, access) => {
    const [snapshot, quickActions] = await Promise.all([
      getAdminDashboardSnapshot(adminClient, access),
      getAdminDashboardActions(adminClient, access),
    ]);

    return {
      snapshot,
      quickActions,
    };
  });
}

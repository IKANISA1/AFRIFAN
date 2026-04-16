import { NextRequest } from "next/server";
import { updateAdminFeature } from "@/lib/data/admin/features";
import { handleAdminApiRoute } from "@/lib/admin-api-handler";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(request, async (client, access) => {
    const body = await request.json();
    await updateAdminFeature(client, access, body.id, body.updates);
    return { success: true };
  });
}

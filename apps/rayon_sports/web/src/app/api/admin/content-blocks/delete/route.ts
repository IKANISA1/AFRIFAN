import { NextRequest } from "next/server";
import { deleteAdminContentBlock } from "@/lib/data/admin/content-blocks";
import { handleAdminApiRoute } from "@/lib/admin-api-handler";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(request, async (client, access) => {
    const body = await request.json();
    await deleteAdminContentBlock(client, access, body.id);
    return { success: true };
  });
}

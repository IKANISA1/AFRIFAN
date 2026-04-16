import { NextRequest } from "next/server";
import { getAdminContentBlocks } from "@/lib/data/admin/content-blocks";
import { handleAdminApiRoute } from "@/lib/admin-api-handler";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  return handleAdminApiRoute(request, getAdminContentBlocks);
}

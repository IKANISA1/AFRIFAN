import { NextRequest } from "next/server";
import { getAdminFeatures } from "@/lib/data/admin/features";
import { handleAdminApiRoute } from "@/lib/admin-api-handler";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  return handleAdminApiRoute(request, getAdminFeatures);
}

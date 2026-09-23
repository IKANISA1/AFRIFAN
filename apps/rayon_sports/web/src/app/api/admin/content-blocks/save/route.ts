import { NextRequest } from "next/server";
import { saveAdminContentBlock } from "@/lib/data/admin/content-blocks";
import {
  AdminApiValidationError,
  handleAdminApiRoute,
} from "@/lib/admin-api-handler";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(request, async (client, access) => {
    const body = (await request.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    if (
      typeof body.input !== "object" ||
      body.input == null ||
      Array.isArray(body.input)
    ) {
      throw new AdminApiValidationError(
        "Content block input is required.",
        "ADMIN_CONTENT_BLOCK_EMPTY",
      );
    }
    await saveAdminContentBlock(client, access, body.input);
    return { success: true };
  });
}

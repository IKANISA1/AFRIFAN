import { NextRequest } from "next/server";
import { deleteAdminContentBlock } from "@/lib/data/admin/content-blocks";
import {
  AdminApiValidationError,
  handleAdminApiRoute,
} from "@/lib/admin-api-handler";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(
    request,
    async (_serviceClient, access, client) => {
      const body = (await request.json().catch(() => ({}))) as Record<
        string,
        unknown
      >;
      if (
        typeof body.id !== "string" ||
        !body.id.trim() ||
        typeof body.expectedUpdatedAt !== "string" ||
        !body.expectedUpdatedAt.trim()
      ) {
        throw new AdminApiValidationError(
          "A content block id and loaded version are required.",
          "ADMIN_CONTENT_BLOCK_EMPTY",
        );
      }
      await deleteAdminContentBlock(
        client,
        access,
        body.id,
        body.expectedUpdatedAt,
      );
      return { success: true };
    },
    {
      destructiveActionId: "delete-platform-content-block",
    },
  );
}

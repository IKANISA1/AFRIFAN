import { NextRequest } from "next/server";
import {
  AdminFeatureValidationError,
  normalizeAdminFeatureUpdate,
  updateAdminFeature,
} from "@/lib/data/admin/features";
import {
  AdminApiAuthorizationError,
  AdminApiValidationError,
  handleAdminApiRoute,
} from "@/lib/admin-api-handler";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(request, async (_serviceClient, access, client) => {
    const body = (await request.json().catch(() => ({}))) as Record<
      string,
      unknown
    >;
    if (
      typeof body.id !== "string" ||
      !body.id.trim() ||
      typeof body.expectedUpdatedAt !== "string" ||
      !body.expectedUpdatedAt.trim() ||
      typeof body.updates !== "object" ||
      body.updates == null ||
      Array.isArray(body.updates)
    ) {
      throw new AdminApiValidationError(
        "A feature id, loaded version, and updates are required.",
        "ADMIN_FEATURE_EMPTY",
      );
    }
    if (!access.isSuperAdmin && access.role !== "club_admin") {
      throw new AdminApiAuthorizationError(
        "Feature configuration access is required.",
      );
    }
    if (!access.isSuperAdmin && access.clubId == null) {
      throw new AdminApiAuthorizationError(
        "A club scope is required to update feature configuration.",
      );
    }

    let updates;
    try {
      updates = normalizeAdminFeatureUpdate(body.updates);
    } catch (error) {
      if (error instanceof AdminFeatureValidationError) {
        throw new AdminApiValidationError(
          "Review the feature configuration and correct invalid values.",
          "ADMIN_FEATURE_INVALID",
        );
      }
      throw error;
    }
    await updateAdminFeature(
      client,
      access,
      body.id,
      body.expectedUpdatedAt,
      updates,
    );
    return { success: true };
  });
}

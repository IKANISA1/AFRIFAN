import { NextRequest } from "next/server";
import {
  AdminApiValidationError,
  handleAdminApiRoute,
} from "@/lib/admin-api-handler";
import { reviewMembershipApplication } from "@/lib/data/admin/membership-ops";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(
    request,
    async (client, access) => {
      const body = (await request.json().catch(() => ({}))) as Record<
        string,
        unknown
      >;
      const applicationId = String(body.applicationId ?? "").trim();
      const expectedUpdatedAt = String(body.expectedUpdatedAt ?? "").trim();
      const decision =
        body.decision === "approved" || body.decision === "rejected"
          ? body.decision
          : null;
      const notes =
        typeof body.notes === "string" && body.notes.trim().length > 0
          ? body.notes.trim()
          : undefined;

      if (!applicationId || !expectedUpdatedAt || decision == null) {
        throw new AdminApiValidationError(
          "A valid application id, loaded version, and decision are required.",
          "ADMIN_MEMBERSHIP_REVIEW_EMPTY",
        );
      }

      await reviewMembershipApplication(
        client,
        access,
        applicationId,
        expectedUpdatedAt,
        decision,
        notes,
      );
      return { success: true };
    },
    {
      featureGuard: {
        featureKey: "membership",
        mode: "action",
      },
      rateLimitKey: "admin:membership-review",
      mutationLimit: 45,
    },
  );
}

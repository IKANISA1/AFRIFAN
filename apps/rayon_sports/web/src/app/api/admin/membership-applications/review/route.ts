import { NextRequest } from "next/server";
import { handleAdminApiRoute } from "@/lib/admin-api-handler";
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
      const decision =
        body.decision === "approved" || body.decision === "rejected"
          ? body.decision
          : null;
      const notes =
        typeof body.notes === "string" && body.notes.trim().length > 0
          ? body.notes.trim()
          : undefined;

      if (!applicationId || decision == null) {
        throw new Error("A valid applicationId and decision are required.");
      }

      await reviewMembershipApplication(
        client,
        access,
        applicationId,
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

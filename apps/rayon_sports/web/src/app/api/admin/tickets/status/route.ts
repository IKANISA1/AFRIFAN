import { NextRequest } from "next/server";
import {
  AdminApiValidationError,
  handleAdminApiRoute,
} from "@/lib/admin-api-handler";
import {
  isAdminTicketStatusAction,
  updateTicketStatus,
} from "@/lib/data/admin/tickets";

export const dynamic = "force-dynamic";
const ticketIdPattern = /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$/;

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(
    request,
    async (client, access) => {
      const body = (await request.json().catch(() => ({}))) as Record<
        string,
        unknown
      >;
      const ticketId = String(body.ticketId ?? "").trim();
      const expectedUpdatedAt = String(body.expectedUpdatedAt ?? "").trim();
      const status = String(body.status ?? "").trim();

      if (
        !ticketIdPattern.test(ticketId) ||
        !expectedUpdatedAt ||
        expectedUpdatedAt.length > 64 ||
        Number.isNaN(Date.parse(expectedUpdatedAt)) ||
        !isAdminTicketStatusAction(status)
      ) {
        throw new AdminApiValidationError(
          "Ticket id, loaded version, and status are required.",
          "ADMIN_TICKET_STATUS_EMPTY",
        );
      }

      await updateTicketStatus(
        client,
        access,
        { id: ticketId, updatedAt: expectedUpdatedAt },
        status,
      );
      return { success: true };
    },
    {
      featureGuard: {
        featureKey: "ticketing",
        mode: "action",
      },
      rateLimitKey: "admin:ticket-status",
      mutationLimit: 45,
    },
  );
}

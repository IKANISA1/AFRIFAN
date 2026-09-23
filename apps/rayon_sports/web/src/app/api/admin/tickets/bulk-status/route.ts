import { NextRequest } from "next/server";
import {
  AdminApiValidationError,
  handleAdminApiRoute,
} from "@/lib/admin-api-handler";
import {
  bulkUpdateTicketStatus,
  isAdminTicketStatusAction,
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
      const rawTickets = Array.isArray(body.tickets) ? body.tickets : [];
      const tickets = rawTickets
        .map((value) => {
          if (
            value == null ||
            typeof value !== "object" ||
            Array.isArray(value)
          ) {
            return null;
          }
          const ticket = value as Record<string, unknown>;
          const id = String(ticket.id ?? "").trim();
          const expectedUpdatedAt = String(
            ticket.expectedUpdatedAt ?? "",
          ).trim();
          if (
            !ticketIdPattern.test(id) ||
            !expectedUpdatedAt ||
            expectedUpdatedAt.length > 64 ||
            Number.isNaN(Date.parse(expectedUpdatedAt))
          ) {
            return null;
          }
          return { id, updatedAt: expectedUpdatedAt };
        })
        .filter(
          (ticket): ticket is { id: string; updatedAt: string } =>
            ticket != null,
        );
      const uniqueTicketIds = new Set(tickets.map(({ id }) => id));
      const status = String(body.status ?? "").trim();

      if (
        tickets.length === 0 ||
        tickets.length !== rawTickets.length ||
        tickets.length > 100 ||
        uniqueTicketIds.size !== tickets.length ||
        !isAdminTicketStatusAction(status)
      ) {
        throw new AdminApiValidationError(
          "Select between 1 and 100 distinct tickets with loaded versions and a supported status action.",
          "ADMIN_TICKET_BULK_EMPTY",
        );
      }

      await bulkUpdateTicketStatus(client, access, tickets, status);
      return { success: true, updatedCount: tickets.length };
    },
    {
      featureGuard: {
        featureKey: "ticketing",
        mode: "action",
      },
      rateLimitKey: "admin:ticket-bulk-status",
      mutationLimit: 12,
    },
  );
}

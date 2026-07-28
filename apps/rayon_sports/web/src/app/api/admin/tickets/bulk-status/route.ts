import { NextRequest } from "next/server";
import { handleAdminApiRoute } from "@/lib/admin-api-handler";
import {
  bulkUpdateTicketStatus,
  isAdminTicketStatusAction,
} from "@/lib/data/admin/tickets";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(
    request,
    async (client, access) => {
      const body = (await request.json().catch(() => ({}))) as Record<
        string,
        unknown
      >;
      const ticketIds = Array.isArray(body.ticketIds)
        ? body.ticketIds
            .map((value) => String(value).trim())
            .filter(Boolean)
        : [];
      const status = String(body.status ?? "").trim();

      if (
        ticketIds.length === 0 ||
        ticketIds.length > 100 ||
        !isAdminTicketStatusAction(status)
      ) {
        throw new Error(
          "Select between 1 and 100 tickets and a supported status action.",
        );
      }

      await bulkUpdateTicketStatus(client, access, ticketIds, status);
      return { success: true, updatedCount: new Set(ticketIds).size };
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

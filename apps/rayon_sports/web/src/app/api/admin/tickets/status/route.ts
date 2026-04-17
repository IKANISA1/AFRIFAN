import { NextRequest } from "next/server";
import { handleAdminApiRoute } from "@/lib/admin-api-handler";
import { updateTicketStatus } from "@/lib/data/admin/tickets";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  return handleAdminApiRoute(
    request,
    async (client, access) => {
      const body = (await request.json().catch(() => ({}))) as Record<
        string,
        unknown
      >;
      const ticketId = String(body.ticketId ?? "").trim();
      const status = String(body.status ?? "").trim();

      if (!ticketId || !status) {
        throw new Error("Both ticketId and status are required.");
      }

      await updateTicketStatus(client, access, ticketId, status);
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

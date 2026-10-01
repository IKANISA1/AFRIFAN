import type { NextRequest } from "next/server";
import { AdminApiAuthorizationError, AdminApiValidationError, handleAdminApiRoute } from "@/lib/admin-api-handler";
import { executePaymentRefundCommand, getPaymentRefundDashboard, parsePaymentRefundCommand, PaymentRefundAuthorizationError, PaymentRefundValidationError, recoverPaymentRefundOperation } from "@/lib/data/admin/payment-refunds";

async function validated<T>(operation: () => Promise<T>): Promise<T> {
  try { return await operation(); } catch (error) {
    if (error instanceof PaymentRefundValidationError) throw new AdminApiValidationError(error.message, error.code);
    if (error instanceof PaymentRefundAuthorizationError) throw new AdminApiAuthorizationError(error.message, error.code);
    throw error;
  }
}

export async function GET(request: NextRequest) {
  return handleAdminApiRoute(request, async (_adminClient, access, caller) => {
    const operationId = request.nextUrl.searchParams.get("operation_id");
    if (operationId === null) return validated(() => getPaymentRefundDashboard(caller, access));
    return validated(() => recoverPaymentRefundOperation(caller, access, operationId));
  }, { requireSuperAdmin: true });
}
export async function POST(request: NextRequest) {
  return handleAdminApiRoute(request, async (_adminClient, access, caller) => {
    if (Number(request.headers.get("content-length") ?? 0) > 2048) throw new AdminApiValidationError("Refund command is too large.", "REFUND_INVALID_REQUEST");
    const body = await request.text();
    if (body.length > 2048) throw new AdminApiValidationError("Refund command is too large.", "REFUND_INVALID_REQUEST");
    let value: unknown;
    try { value = JSON.parse(body); } catch { throw new AdminApiValidationError("Review the refund command fields.", "REFUND_INVALID_REQUEST"); }
    return validated(() => executePaymentRefundCommand(caller, access, parsePaymentRefundCommand(value)));
  }, { requireSuperAdmin: true, rateLimitKey: "admin:refunds", mutationLimit: 12 });
}

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireAuthenticatedCaller } from "../_shared/auth.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import {
  TicketWalletValidationError,
  verifyRotatingBarcode,
} from "../_shared/ticket_wallet.ts";

type RpcClient = {
  rpc(
    name: string,
    params: Record<string, unknown>,
  ): Promise<{ data: unknown; error: { message?: string } | null }>;
};

type Dependencies = {
  requireAuthenticatedCaller: typeof requireAuthenticatedCaller;
  createAdminClient: () => RpcClient;
  enforceRateLimit: typeof enforceRateLimit;
  verifyRotatingBarcode: typeof verifyRotatingBarcode;
  getEnv: (name: string) => string | undefined;
};

const defaultDependencies: Dependencies = {
  requireAuthenticatedCaller,
  createAdminClient: () => createAdminClient() as unknown as RpcClient,
  enforceRateLimit,
  verifyRotatingBarcode,
  getEnv: (name) => Deno.env.get(name),
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const GATE_PATTERN = /^[A-Z0-9][A-Z0-9_-]{0,31}$/;

async function parseRequest(request: Request): Promise<{
  ticketCode: string;
  operationId: string;
  gateCode: string | null;
}> {
  let value: unknown;
  try {
    value = await request.json();
  } catch {
    throw new HttpError(400, "Request body must be valid JSON.");
  }
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, "Verification request is invalid.");
  }
  const source = value as Record<string, unknown>;
  const ticketCode = typeof source["ticket_code"] === "string"
    ? source["ticket_code"].trim()
    : "";
  const operationId = typeof source["operation_id"] === "string"
    ? source["operation_id"].trim().toLowerCase()
    : "";
  const gateCode = typeof source["gate_code"] === "string" &&
      source["gate_code"].trim().length > 0
    ? source["gate_code"].trim().toUpperCase()
    : null;
  if (ticketCode.length < 20 || ticketCode.length > 180) {
    throw new HttpError(400, "ticket_code is invalid.");
  }
  if (!UUID_PATTERN.test(operationId)) {
    throw new HttpError(400, "operation_id must be a valid UUID.");
  }
  if (gateCode != null && !GATE_PATTERN.test(gateCode)) {
    throw new HttpError(400, "gate_code is invalid.");
  }
  return { ticketCode, operationId, gateCode };
}

export function createVerifyTicketHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = { ...defaultDependencies, ...dependencies };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return corsPreflightResponse();
    if (request.method !== "POST") return jsonError("Method not allowed", 405);

    try {
      const caller = await deps.requireAuthenticatedCaller(request);
      const payload = await parseRequest(request);
      const adminClient = deps.createAdminClient();
      await deps.enforceRateLimit(
        adminClient as never,
        caller.userId,
        "verify-ticket",
        { maxRequests: 180, windowSeconds: 60 },
      );
      const masterSecret = deps.getEnv("GOOGLE_WALLET_TOTP_MASTER_SECRET")
        ?.trim();
      if (!masterSecret) {
        throw new Error("Ticket verification is not configured.");
      }
      const credential = await deps.verifyRotatingBarcode(
        payload.ticketCode,
        masterSecret,
      );

      const { data, error } = await adminClient.rpc(
        "redeem_ticket_for_verifier",
        {
          p_actor_id: caller.userId,
          p_credential_id: credential.credentialId,
          p_credential_version: credential.credentialVersion,
          p_operation_id: payload.operationId,
          p_gate_code: payload.gateCode,
        },
      );
      if (
        error || data == null || typeof data !== "object" ||
        Array.isArray(data)
      ) {
        throw new Error("Ticket redemption could not be confirmed.");
      }
      const result = data as Record<string, unknown>;
      if (result["status"] !== "admitted" && result["status"] !== "rejected") {
        throw new Error("Ticket redemption returned an invalid result.");
      }

      return jsonOk({ success: true, data: { result } });
    } catch (error) {
      if (error instanceof HttpError) {
        const code = error.status === 409
          ? "CODE_EXPIRED_OR_INVALID"
          : undefined;
        return jsonError(error.message, error.status, code);
      }
      if (error instanceof TicketWalletValidationError) {
        const code = error.status === 409
          ? "CODE_EXPIRED_OR_INVALID"
          : undefined;
        return jsonError(error.message, error.status, code);
      }
      console.error("verify-ticket failed");
      return jsonError(
        "Ticket verification could not be completed.",
        500,
        "VERIFICATION_FAILED",
      );
    }
  };
}

if (import.meta.main) {
  const handler = createVerifyTicketHandler();
  Deno.serve((request: Request) =>
    handler(request).then(
      (response) =>
        new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: {
            ...Object.fromEntries(response.headers.entries()),
            ...corsHeaders(),
          },
        }),
    )
  );
}

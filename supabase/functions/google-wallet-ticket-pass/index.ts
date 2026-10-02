import { errorResponse } from "../_shared/response.ts";
import { withEdgeBoundary } from "../_shared/response.ts";
import { readBoundedJson } from "../_shared/http.ts";
import { logDiagnostic } from "../_shared/diagnostics.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  getAuthorizationHeader,
  HttpError,
  requireAuthenticatedCaller,
} from "../_shared/auth.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient, createUserClient } from "../_shared/supabase.ts";
import {
  parseGoogleServiceAccount,
  parsePreparedWalletTicket,
  provisionGoogleWalletTicket,
} from "../_shared/ticket_wallet.ts";

type RpcClient = {
  rpc(
    name: string,
    params: Record<string, unknown>,
  ): Promise<{ data: unknown; error: { message?: string } | null }>;
};

type Dependencies = {
  requireAuthenticatedCaller: typeof requireAuthenticatedCaller;
  createUserClient: (authorization: string) => RpcClient;
  createAdminClient: () => RpcClient;
  enforceRateLimit: typeof enforceRateLimit;
  provisionGoogleWalletTicket: typeof provisionGoogleWalletTicket;
  getEnv: (name: string) => string | undefined;
};

const defaultDependencies: Dependencies = {
  requireAuthenticatedCaller,
  createUserClient: (authorization) =>
    createUserClient(authorization) as unknown as RpcClient,
  createAdminClient: () => createAdminClient() as unknown as RpcClient,
  enforceRateLimit,
  provisionGoogleWalletTicket,
  getEnv: (name) => Deno.env.get(name),
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

async function parseRequest(request: Request): Promise<{ ticketId: string }> {
  const value = await readBoundedJson(request);
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, "Ticket request is invalid.");
  }
  const ticketId = (value as Record<string, unknown>)["ticket_id"];
  if (typeof ticketId !== "string" || !UUID_PATTERN.test(ticketId.trim())) {
    throw new HttpError(400, "ticket_id must be a valid UUID.");
  }
  return { ticketId: ticketId.trim().toLowerCase() };
}

function requiredEnv(deps: Dependencies, name: string): string {
  const value = deps.getEnv(name)?.trim();
  if (!value) throw new Error(`${name} is not configured.`);
  return value;
}

function preparationError(value: unknown): HttpError {
  const source =
    value != null && typeof value === "object" && !Array.isArray(value)
      ? value as Record<string, unknown>
      : {};
  const code = typeof source["code"] === "string"
    ? source["code"]
    : "not_ready";
  if (code === "ticket_not_found") return new HttpError(404, code);
  if (code === "auth_required") return new HttpError(401, code);
  if (code === "club_scope_required") return new HttpError(403, code);
  return new HttpError(409, code);
}

export function createGoogleWalletTicketPassHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = { ...defaultDependencies, ...dependencies };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return corsPreflightResponse(request);
    if (request.method !== "POST") return jsonError("Method not allowed", 405);

    try {
      const caller = await deps.requireAuthenticatedCaller(request);
      const payload = await parseRequest(request);
      const authorization = getAuthorizationHeader(request);
      if (!authorization) throw new HttpError(401, "Authentication required.");

      const adminClient = deps.createAdminClient();
      await deps.enforceRateLimit(
        adminClient as never,
        caller.userId,
        "google-wallet-ticket-pass",
        { maxRequests: 8, windowSeconds: 60 },
      );

      const { data: preparedData, error: preparationRpcError } = await deps
        .createUserClient(authorization)
        .rpc("prepare_google_wallet_ticket", { p_ticket_id: payload.ticketId });
      if (preparationRpcError) {
        throw new Error("Ticket eligibility could not be confirmed.");
      }
      if (
        preparedData == null || typeof preparedData !== "object" ||
        Array.isArray(preparedData) ||
        (preparedData as Record<string, unknown>)["status"] !== "success"
      ) {
        throw preparationError(preparedData);
      }
      const ticket = parsePreparedWalletTicket(preparedData);
      if (ticket.ticketId !== payload.ticketId) {
        throw new Error("Ticket preparation scope mismatch.");
      }

      const provisioned = await deps.provisionGoogleWalletTicket({
        ticket,
        serviceAccount: parseGoogleServiceAccount(
          requiredEnv(deps, "GOOGLE_WALLET_SERVICE_ACCOUNT_JSON"),
        ),
        totpMasterSecret: requiredEnv(
          deps,
          "GOOGLE_WALLET_TOTP_MASTER_SECRET",
        ),
      });

      const { data: passId, error: recordError } = await adminClient.rpc(
        "record_google_wallet_ticket_pass",
        {
          p_ticket_id: ticket.ticketId,
          p_credential_id: ticket.credentialId,
          p_class_id: provisioned.classId,
          p_object_id: provisioned.objectId,
          p_wallet_state: "ACTIVE",
        },
      );
      if (recordError || typeof passId !== "string") {
        throw new Error("Wallet pass issuance was not recorded.");
      }

      return jsonOk({
        success: true,
        data: {
          pass_id: passId,
          ticket_id: ticket.ticketId,
          save_jwt: provisioned.saveJwt,
          save_url: provisioned.saveUrl,
        },
      });
    } catch (error) {
      if (error instanceof HttpError) {
        const code = /^[a-z0-9_]+$/.test(error.message)
          ? error.message.toUpperCase()
          : undefined;
        return errorResponse(error, undefined, code);
      }
      logDiagnostic(
        "error",
        "google_wallet_ticket_pass_google_wallet_ticket_pass_failed",
      );
      return jsonError(
        "Google Wallet pass could not be prepared.",
        502,
        "WALLET_ISSUANCE_FAILED",
      );
    }
  };
}

if (import.meta.main) {
  const handler = createGoogleWalletTicketPassHandler();
  Deno.serve(withEdgeBoundary((request: Request) =>
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
  ));
}

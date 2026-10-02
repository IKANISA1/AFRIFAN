import { errorResponse } from "../_shared/response.ts";
import { withEdgeBoundary } from "../_shared/response.ts";
import { readBoundedJson } from "../_shared/http.ts";
import { logDiagnostic } from "../_shared/diagnostics.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { HttpError, requireCronSecret } from "../_shared/auth.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import {
  GoogleWalletApiError,
  parseGoogleServiceAccount,
  updateGoogleWalletTicketState,
} from "../_shared/ticket_wallet.ts";

type RpcClient = {
  rpc(
    name: string,
    params: Record<string, unknown>,
  ): Promise<{ data: unknown; error: { message?: string } | null }>;
};

type WalletState = "ACTIVE" | "COMPLETED" | "EXPIRED" | "INACTIVE";

type ClaimedOutboxItem = {
  id: string;
  passId: string;
  objectId: string;
  desiredState: WalletState;
  attempts: number;
  claimToken: string;
};

type Dependencies = {
  createAdminClient: () => RpcClient;
  requireCronSecret: typeof requireCronSecret;
  updateGoogleWalletTicketState: typeof updateGoogleWalletTicketState;
  getEnv: (name: string) => string | undefined;
  randomUuid: () => string;
};

const defaultDependencies: Dependencies = {
  createAdminClient: () => createAdminClient() as unknown as RpcClient,
  requireCronSecret,
  updateGoogleWalletTicketState,
  getEnv: (name) => Deno.env.get(name),
  randomUuid: () => crypto.randomUUID(),
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OBJECT_ID_PATTERN = /^[0-9]{8,32}\.[A-Za-z0-9._-]{1,220}$/;
const WALLET_STATES = new Set<WalletState>([
  "ACTIVE",
  "COMPLETED",
  "EXPIRED",
  "INACTIVE",
]);

function parseLimit(value: unknown): number {
  const parsed = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number.parseInt(value.trim(), 10)
    : 25;
  if (!Number.isFinite(parsed)) return 25;
  return Math.max(1, Math.min(50, Math.trunc(parsed)));
}

function requiredUuid(value: unknown, field: string): string {
  if (typeof value !== "string" || !UUID_PATTERN.test(value.trim())) {
    throw new Error(`${field} is invalid.`);
  }
  return value.trim().toLowerCase();
}

function parseClaimedItems(value: unknown): ClaimedOutboxItem[] {
  if (!Array.isArray(value) || value.length > 50) {
    throw new Error("Wallet outbox claim result is invalid.");
  }
  return value.map((entry) => {
    if (entry == null || typeof entry !== "object" || Array.isArray(entry)) {
      throw new Error("Wallet outbox claim item is invalid.");
    }
    const row = entry as Record<string, unknown>;
    const objectId = typeof row["object_id"] === "string"
      ? row["object_id"].trim()
      : "";
    const desiredState = row["desired_state"];
    const attempts = row["attempts"];
    if (
      !OBJECT_ID_PATTERN.test(objectId) ||
      typeof desiredState !== "string" ||
      !WALLET_STATES.has(desiredState as WalletState) ||
      !Number.isSafeInteger(attempts) ||
      Number(attempts) < 1 ||
      Number(attempts) > 8
    ) {
      throw new Error("Wallet outbox claim item is invalid.");
    }
    return {
      id: requiredUuid(row["id"], "Wallet outbox id"),
      passId: requiredUuid(row["pass_id"], "Wallet pass id"),
      objectId,
      desiredState: desiredState as WalletState,
      attempts: Number(attempts),
      claimToken: requiredUuid(row["claim_token"], "Wallet claim token"),
    };
  });
}

function errorCode(error: unknown): string {
  if (error instanceof GoogleWalletApiError) {
    return `google_wallet_${error.operation}_${error.status}`;
  }
  return "google_wallet_unknown";
}

async function requestBody(request: Request): Promise<Record<string, unknown>> {
  return await readBoundedJson(request, { allowEmpty: true });
}

export function createSyncGoogleWalletTicketStateHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = { ...defaultDependencies, ...dependencies };

  return async (request: Request): Promise<Response> => {
    if (request.method === "OPTIONS") return corsPreflightResponse(request);
    if (request.method !== "POST") return jsonError("Method not allowed", 405);

    try {
      deps.requireCronSecret(request);
      const serviceAccountRaw = deps.getEnv(
        "GOOGLE_WALLET_SERVICE_ACCOUNT_JSON",
      )?.trim();
      if (!serviceAccountRaw) {
        throw new Error("Google Wallet service account is not configured.");
      }
      const serviceAccount = parseGoogleServiceAccount(serviceAccountRaw);
      const limit = parseLimit((await requestBody(request))["limit"]);
      const claimToken = deps.randomUuid();
      const adminClient = deps.createAdminClient();
      const { data: claimData, error: claimError } = await adminClient.rpc(
        "claim_google_wallet_ticket_outbox",
        { p_claim_token: claimToken, p_limit: limit },
      );
      if (claimError) {
        throw new Error("Wallet state queue could not be claimed.");
      }

      const items = parseClaimedItems(claimData);
      let synced = 0;
      let retrying = 0;
      let deadLettered = 0;

      for (const item of items) {
        let succeeded = false;
        let failureCode: string | null = null;
        try {
          await deps.updateGoogleWalletTicketState({
            objectId: item.objectId,
            state: item.desiredState,
            serviceAccount,
          });
          succeeded = true;
        } catch (error) {
          failureCode = errorCode(error);
        }

        const { data: completionState, error: completionError } =
          await adminClient
            .rpc("complete_google_wallet_ticket_outbox", {
              p_outbox_id: item.id,
              p_claim_token: item.claimToken,
              p_succeeded: succeeded,
              p_error_code: failureCode,
            });
        if (
          completionError ||
          (completionState !== "completed" &&
            completionState !== "failed" &&
            completionState !== "dead_letter")
        ) {
          throw new Error(
            "Wallet state queue completion could not be recorded.",
          );
        }
        if (completionState === "completed") synced += 1;
        if (completionState === "failed") retrying += 1;
        if (completionState === "dead_letter") deadLettered += 1;
      }

      return jsonOk({
        success: true,
        data: {
          claimed: items.length,
          synced,
          retrying,
          dead_lettered: deadLettered,
        },
      });
    } catch (error) {
      if (error instanceof HttpError) {
        return errorResponse(error);
      }
      logDiagnostic(
        "error",
        "sync_google_wallet_ticket_state_sync_google_wallet_ticket_state_failed",
      );
      return jsonError(
        "Google Wallet state synchronization failed.",
        500,
        "WALLET_STATE_SYNC_FAILED",
      );
    }
  };
}

if (import.meta.main) {
  const handler = createSyncGoogleWalletTicketStateHandler();
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

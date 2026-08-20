import { NextResponse, type NextRequest } from "next/server";
import { serverSupabaseConfig } from "@/lib/config";
import {
  edgeFunctionConfigurationResponse,
  edgeFunctionEmptyResponse,
  edgeFunctionFailureResponse,
  edgeFunctionOperationTimeoutMs,
  proxyEdgeFunctionRequest,
  withEdgeFunctionOperationTimeout,
} from "@/lib/edge-function-proxy";
import {
  rejectInsecureMutation,
  rejectRateLimitedRequest,
} from "@/lib/security";
import { getServerSupabase } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

type VerifyTicketBody = {
  ticket_code: string;
  operation_id: string;
  gate_code: string | null;
};

type Dependencies = {
  fetcher: typeof fetch;
  rejectInsecureMutation: typeof rejectInsecureMutation;
  rejectRateLimitedRequest: typeof rejectRateLimitedRequest;
  getAccessToken: () => Promise<string | null>;
  supabaseUrl: string;
  supabaseAnonKey: string;
  operationTimeoutMs: number;
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const GATE_PATTERN = /^[A-Z0-9][A-Z0-9_-]{0,31}$/;

async function serverAccessToken() {
  const client = await getServerSupabase();
  if (client == null) return null;
  const { data: userData, error: userError } = await client.auth.getUser();
  if (userError || userData.user == null) return null;
  const { data: sessionData, error: sessionError } =
    await client.auth.getSession();
  if (sessionError || sessionData.session?.access_token == null) return null;
  return sessionData.session.access_token;
}

function defaultDependencies(): Dependencies {
  return {
    fetcher: fetch,
    rejectInsecureMutation,
    rejectRateLimitedRequest,
    getAccessToken: serverAccessToken,
    supabaseUrl: serverSupabaseConfig.url,
    supabaseAnonKey: serverSupabaseConfig.anonKey,
    operationTimeoutMs: edgeFunctionOperationTimeoutMs,
  };
}

function parseBody(value: unknown): VerifyTicketBody | null {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }
  const source = value as Record<string, unknown>;
  const ticketCode =
    typeof source.ticket_code === "string" ? source.ticket_code.trim() : "";
  const operationId =
    typeof source.operation_id === "string"
      ? source.operation_id.trim().toLowerCase()
      : "";
  const gateCode =
    typeof source.gate_code === "string" && source.gate_code.trim().length > 0
      ? source.gate_code.trim().toUpperCase()
      : null;
  if (
    ticketCode.length < 20 ||
    ticketCode.length > 180 ||
    !UUID_PATTERN.test(operationId) ||
    (gateCode != null && !GATE_PATTERN.test(gateCode))
  ) {
    return null;
  }
  return {
    ticket_code: ticketCode,
    operation_id: operationId,
    gate_code: gateCode,
  };
}

export function createVerifyTicketRouteHandler(
  partialDependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = {
    ...defaultDependencies(),
    ...partialDependencies,
  };

  return async function postVerifyTicket(request: NextRequest) {
    const rejectedOrigin = deps.rejectInsecureMutation(request);
    if (rejectedOrigin) return rejectedOrigin;

    let rejectedLimit: Response | null;
    try {
      rejectedLimit = await withEdgeFunctionOperationTimeout(
        deps.rejectRateLimitedRequest(
          request,
          "venue-verify-ticket",
          240,
          60_000,
        ),
        deps.operationTimeoutMs,
      );
    } catch (error) {
      return edgeFunctionFailureResponse(error);
    }
    if (rejectedLimit) return rejectedLimit;

    const body = parseBody(await request.json().catch(() => null));
    if (body == null) {
      return edgeFunctionEmptyResponse("Invalid ticket verification payload.");
    }
    if (!deps.supabaseUrl || !deps.supabaseAnonKey) {
      return edgeFunctionConfigurationResponse();
    }

    let accessToken: string | null;
    try {
      accessToken = await withEdgeFunctionOperationTimeout(
        deps.getAccessToken(),
        deps.operationTimeoutMs,
      );
    } catch (error) {
      return edgeFunctionFailureResponse(error);
    }
    if (accessToken == null) {
      return NextResponse.json(
        {
          code: "AUTHENTICATION_REQUIRED",
          error: "Authentication is required.",
        },
        { status: 401, headers: { "Cache-Control": "no-store" } },
      );
    }

    return proxyEdgeFunctionRequest({
      fetcher: deps.fetcher,
      url: `${deps.supabaseUrl}/functions/v1/verify-ticket`,
      timeoutMs: deps.operationTimeoutMs,
      init: {
        method: "POST",
        headers: {
          apikey: deps.supabaseAnonKey,
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
        cache: "no-store",
      },
    });
  };
}

export const POST = createVerifyTicketRouteHandler();

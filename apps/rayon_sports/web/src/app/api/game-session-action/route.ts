import type { NextRequest } from "next/server";
import { serverSupabaseConfig } from "@/lib/config";
import { rejectInsecureMutation, rejectRateLimitedRequest } from "@/lib/security";
import type { GameActionBody } from "@/lib/game-runtime";
import {
  edgeFunctionFailureResponse,
  edgeFunctionConfigurationResponse,
  edgeFunctionEmptyResponse,
  edgeFunctionOperationTimeoutMs,
  proxyEdgeFunctionRequest,
  withEdgeFunctionOperationTimeout,
} from "@/lib/edge-function-proxy";

export const dynamic = "force-dynamic";

type GameActionRouteDependencies = {
  fetcher: typeof fetch;
  rejectInsecureMutation: typeof rejectInsecureMutation;
  rejectRateLimitedRequest: typeof rejectRateLimitedRequest;
  supabaseUrl: string;
  supabaseAnonKey: string;
  operationTimeoutMs: number;
};

const allowedActions = new Set([
  "get_tv_state",
  "join_session",
  "submit_answer",
  "create_session",
  "pair_tv_device",
  "revoke_tv_device",
  "review_question_draft",
  "list_question_drafts",
  "publish_question_pack",
  "list_audit_log",
  "open_question",
  "reveal_question",
  "advance_question",
  "close_session",
]);

const reviewDecisions = new Set(["approved", "rejected", "needs_changes"]);
const draftStatuses = new Set([
  "pending_review",
  "approved",
  "rejected",
  "needs_changes",
]);
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const optionKeyPattern = /^[a-z0-9_-]{1,32}$/i;
const joinCodePattern = /^[a-z0-9_-]{3,32}$/i;

function defaultDependencies(): GameActionRouteDependencies {
  return {
    fetcher: fetch,
    rejectInsecureMutation,
    rejectRateLimitedRequest,
    supabaseUrl: serverSupabaseConfig.url,
    supabaseAnonKey: serverSupabaseConfig.anonKey,
    operationTimeoutMs: edgeFunctionOperationTimeoutMs,
  };
}

function isValidBody(value: unknown): value is GameActionBody {
  if (value == null || typeof value !== "object") {
    return false;
  }

  const body = value as Record<string, unknown>;
  if (typeof body.action !== "string" || !allowedActions.has(body.action)) {
    return false;
  }

  if (body.action === "get_tv_state") {
    return isUuid(body.session_id);
  }

  if (body.action === "join_session") {
    const hasSessionId =
      body.session_id == null || body.session_id === ""
        ? false
        : isUuid(body.session_id);
    const hasJoinCode =
      typeof body.join_code === "string" && joinCodePattern.test(body.join_code);
    const hasValidClubId =
      body.club_id == null ||
      (typeof body.club_id === "number" && Number.isFinite(body.club_id));
    const hasValidDisplayName =
      body.display_name == null || typeof body.display_name === "string";
    return (hasSessionId || hasJoinCode) && hasValidClubId && hasValidDisplayName;
  }

  if (body.action === "submit_answer") {
    return (
      typeof body.session_question_id === "string" &&
      isUuid(body.session_question_id) &&
      isUuid(body.session_player_id) &&
      typeof body.selected_option_key === "string" &&
      optionKeyPattern.test(body.selected_option_key) &&
      (body.idempotency_key == null ||
        (typeof body.idempotency_key === "string" &&
          body.idempotency_key.trim().length > 0 &&
          body.idempotency_key.trim().length <= 96))
    );
  }

  if (body.action === "create_session") {
    return (
      typeof body.club_id === "number" &&
      Number.isFinite(body.club_id) &&
      typeof body.title === "string" &&
      body.title.trim().length > 0 &&
      (body.pack_id == null || isUuid(body.pack_id)) &&
      (body.tv_device_id == null || isUuid(body.tv_device_id)) &&
      (body.join_code == null ||
        (typeof body.join_code === "string" && joinCodePattern.test(body.join_code)))
    );
  }

  if (body.action === "pair_tv_device") {
    return (
      typeof body.club_id === "number" &&
      Number.isFinite(body.club_id) &&
      typeof body.device_label === "string" &&
      body.device_label.trim().length > 0 &&
      typeof body.pairing_code === "string" &&
      body.pairing_code.trim().length > 0 &&
      (body.session_id == null || isUuid(body.session_id))
    );
  }

  if (body.action === "revoke_tv_device") {
    return (
      typeof body.club_id === "number" &&
      Number.isFinite(body.club_id) &&
      isUuid(body.tv_device_id) &&
      (body.reason == null ||
        (typeof body.reason === "string" && body.reason.trim().length <= 240))
    );
  }

  if (body.action === "review_question_draft") {
    return (
      typeof body.club_id === "number" &&
      Number.isFinite(body.club_id) &&
      isUuid(body.draft_id) &&
      reviewDecisions.has(String(body.decision)) &&
      (body.notes == null || typeof body.notes === "string")
    );
  }

  if (body.action === "list_question_drafts") {
    return (
      typeof body.club_id === "number" &&
      Number.isFinite(body.club_id) &&
      (body.status == null || draftStatuses.has(String(body.status))) &&
      (body.search == null || typeof body.search === "string") &&
      (body.limit == null ||
        (typeof body.limit === "number" &&
          Number.isFinite(body.limit) &&
          body.limit > 0)) &&
      (body.offset == null ||
        (typeof body.offset === "number" &&
          Number.isFinite(body.offset) &&
          body.offset >= 0))
    );
  }

  if (body.action === "publish_question_pack") {
    return (
      typeof body.club_id === "number" &&
      Number.isFinite(body.club_id) &&
      typeof body.title === "string" &&
      body.title.trim().length > 0 &&
      Array.isArray(body.question_ids) &&
      body.question_ids.every((id) => isUuid(id)) &&
      (body.description == null || typeof body.description === "string") &&
      (body.template_id == null || isUuid(body.template_id))
    );
  }

  if (body.action === "list_audit_log") {
    return (
      typeof body.club_id === "number" &&
      Number.isFinite(body.club_id) &&
      (body.limit == null ||
        (typeof body.limit === "number" &&
          Number.isFinite(body.limit) &&
          body.limit > 0)) &&
      (body.offset == null ||
        (typeof body.offset === "number" &&
          Number.isFinite(body.offset) &&
          body.offset >= 0)) &&
      (body.action_filter == null || typeof body.action_filter === "string") &&
      (body.entity_type == null || typeof body.entity_type === "string")
    );
  }

  if (body.action === "close_session") {
    return (
      typeof body.club_id === "number" &&
      Number.isFinite(body.club_id) &&
      isUuid(body.session_id)
    );
  }

  return (
    typeof body.club_id === "number" &&
    Number.isFinite(body.club_id) &&
    isUuid(body.session_question_id)
  );
}

function isUuid(value: unknown) {
  return typeof value === "string" && uuidPattern.test(value);
}

function authHeaders(request: NextRequest, anonKey: string) {
  const authorization = request.headers.get("authorization");
  const headers: Record<string, string> = {
    apikey: anonKey,
    "Content-Type": "application/json",
  };
  if (authorization) {
    headers.Authorization = authorization;
  }
  return headers;
}

export function createGameSessionActionRouteHandler(
  partialDependencies: Partial<GameActionRouteDependencies> = {},
) {
  const deps = {
    ...defaultDependencies(),
    ...partialDependencies,
  };

  return async function postGameSessionAction(request: NextRequest) {
    const rejectedOrigin = deps.rejectInsecureMutation(request);
    if (rejectedOrigin) {
      return rejectedOrigin;
    }

    let rejectedLimit: Response | null;
    try {
      rejectedLimit = await withEdgeFunctionOperationTimeout(
        deps.rejectRateLimitedRequest(
          request,
          "game-session-action",
          120,
          60_000,
        ),
        deps.operationTimeoutMs,
      );
    } catch (error) {
      return edgeFunctionFailureResponse(error);
    }
    if (rejectedLimit) {
      return rejectedLimit;
    }

    const body = await request.json().catch(() => null);
    if (!isValidBody(body)) {
      return edgeFunctionEmptyResponse("Invalid game action payload.");
    }

    if (!deps.supabaseUrl || !deps.supabaseAnonKey) {
      return edgeFunctionConfigurationResponse();
    }

    return proxyEdgeFunctionRequest({
      fetcher: deps.fetcher,
      url: `${deps.supabaseUrl}/functions/v1/game-session-action`,
      timeoutMs: deps.operationTimeoutMs,
      init: {
        method: "POST",
        headers: authHeaders(request, deps.supabaseAnonKey),
        body: JSON.stringify(body),
        cache: "no-store",
      },
    });
  };
}

export const POST = createGameSessionActionRouteHandler();

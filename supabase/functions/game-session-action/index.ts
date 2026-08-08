import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  getAuthorizationHeader,
  HttpError,
  requireAuthenticatedCaller,
  requireClubAdminCaller,
} from "../_shared/auth.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { createAdminClient, createUserClient } from "../_shared/supabase.ts";

type GameAction =
  | "get_tv_state"
  | "join_session"
  | "submit_answer"
  | "create_session"
  | "revoke_tv_device"
  | "review_question_draft"
  | "list_question_drafts"
  | "publish_question_pack"
  | "list_audit_log"
  | "open_question"
  | "reveal_question"
  | "advance_question"
  | "close_session"
  | "get_planner_options"
  | "get_managed_sessions"
  | "create_managed_session"
  | "transition_managed_session";

type GameActionRequest = {
  action?: GameAction;
  club_id?: number | string;
  session_id?: string;
  display_name?: string;
  title?: string;
  description?: string;
  pack_id?: string;
  draft_id?: string;
  decision?: string;
  notes?: string;
  status?: string;
  search?: string;
  question_ids?: string[];
  template_id?: string;
  preview_fingerprint?: string;
  limit?: number | string;
  offset?: number | string;
  action_filter?: string;
  entity_type?: string;
  tv_device_id?: string;
  device_label?: string;
  session_question_id?: string;
  session_player_id?: string;
  selected_option_key?: string;
  idempotency_key?: string;
  scheduled_start_at?: string;
  eligibility_scope?: string;
  display_ids?: string[];
  organizer_user_ids?: string[];
  requested_phase?: string;
  expected_session_version?: number | string;
  phase_deadline?: string;
  reason?: string;
};

type Dependencies = {
  createAdminClient: typeof createAdminClient;
  createUserClient: typeof createUserClient;
  requireAuthenticatedCaller: typeof requireAuthenticatedCaller;
  requireClubAdminCaller: typeof requireClubAdminCaller;
};

const defaultDependencies: Dependencies = {
  createAdminClient,
  createUserClient,
  requireAuthenticatedCaller,
  requireClubAdminCaller,
};

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const OPTION_KEY_PATTERN = /^[a-z0-9_-]{1,32}$/i;
const SHA256_PATTERN = /^[0-9a-f]{64}$/;

function requireUuid(value: unknown, field: string): string {
  if (typeof value !== "string" || !UUID_PATTERN.test(value)) {
    throw new HttpError(400, `${field} must be a valid UUID.`);
  }
  return value;
}

function optionalUuid(value: unknown, field: string): string | null {
  if (value == null || value === "") {
    return null;
  }
  return requireUuid(value, field);
}

function requireOptionKey(value: unknown): string {
  if (typeof value !== "string" || !OPTION_KEY_PATTERN.test(value.trim())) {
    throw new HttpError(400, "selected_option_key is invalid.");
  }
  return value.trim();
}

function optionalIdempotencyKey(value: unknown): string | null {
  if (value == null || value === "") {
    return null;
  }
  if (typeof value !== "string" || value.trim().length > 96) {
    throw new HttpError(400, "idempotency_key is invalid.");
  }
  return value.trim();
}

function requireClubId(value: unknown): number {
  const parsed = typeof value === "number" ? value : Number.parseInt(`${value}`, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new HttpError(400, "club_id must be a positive integer.");
  }
  return Math.trunc(parsed);
}

function optionalPositiveInteger(
  value: unknown,
  field: string,
  fallback: number,
): number {
  if (value == null || value === "") {
    return fallback;
  }
  const parsed = typeof value === "number" ? value : Number.parseInt(`${value}`, 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    throw new HttpError(400, `${field} must be a positive integer.`);
  }
  return Math.trunc(parsed);
}

function optionalNonNegativeInteger(
  value: unknown,
  field: string,
  fallback: number,
): number {
  if (value == null || value === "") {
    return fallback;
  }
  const parsed = typeof value === "number" ? value : Number.parseInt(`${value}`, 10);
  if (!Number.isFinite(parsed) || parsed < 0) {
    throw new HttpError(400, `${field} must be a non-negative integer.`);
  }
  return Math.trunc(parsed);
}

async function parseBody(request: Request): Promise<GameActionRequest> {
  try {
    return await request.json() as GameActionRequest;
  } catch {
    throw new HttpError(400, "Request body must be valid JSON.");
  }
}

function mapRpcError(error: { message?: string; code?: string } | null) {
  if (error == null) {
    return new HttpError(500, "Game action failed.");
  }

  const message = error.message ?? "Game action failed.";
  const lowerMessage = message.toLowerCase();
  if (
    lowerMessage.includes("already answered") ||
    lowerMessage.includes("version conflict") ||
    lowerMessage.includes("idempotency conflict")
  ) {
    return new HttpError(409, message);
  }
  if (
    lowerMessage.includes("not open") ||
    lowerMessage.includes("duplicate") ||
    lowerMessage.includes("invalid") ||
    lowerMessage.includes("not joinable") ||
    lowerMessage.includes("not available")
  ) {
    return new HttpError(400, message);
  }
  if (lowerMessage.includes("not found")) {
    return new HttpError(404, message);
  }
  if (
    lowerMessage.includes("not allowed") ||
    lowerMessage.includes("not authorized") ||
    lowerMessage.includes("required")
  ) {
    return new HttpError(403, message);
  }
  return new HttpError(500, message);
}

function requireIdempotencyKey(value: unknown): string {
  const key = requireText(value, "idempotency_key", { maxLength: 96 });
  if (key.length < 8) {
    throw new HttpError(400, "idempotency_key is invalid.");
  }
  return key;
}

function requireIsoDateTime(value: unknown, field: string): string {
  const text = requireText(value, field, { maxLength: 64 });
  if (!Number.isFinite(Date.parse(text))) {
    throw new HttpError(400, `${field} is invalid.`);
  }
  return text;
}

function optionalIsoDateTime(value: unknown, field: string): string | null {
  if (value == null || value === "") {
    return null;
  }
  return requireIsoDateTime(value, field);
}

function requireNonNegativeInteger(value: unknown, field: string): number {
  const parsed =
    typeof value === "number" ? value : Number.parseInt(`${value}`, 10);
  if (!Number.isSafeInteger(parsed) || parsed < 0) {
    throw new HttpError(400, `${field} must be a non-negative integer.`);
  }
  return parsed;
}

function requireUniqueUuidList(
  value: unknown,
  field: string,
  maximum: number,
): string[] {
  if (!Array.isArray(value) || value.length > maximum) {
    throw new HttpError(400, `${field} is invalid.`);
  }
  const ids = value.map((item) => requireUuid(item, field));
  if (new Set(ids).size !== ids.length) {
    throw new HttpError(400, `${field} contains duplicate values.`);
  }
  return ids;
}

function optionalDisplayName(value: unknown): string | null {
  if (value == null || value === "") {
    return null;
  }
  if (typeof value !== "string") {
    throw new HttpError(400, "display_name is invalid.");
  }
  const trimmed = value.trim();
  if (trimmed.length < 1 || trimmed.length > 48) {
    throw new HttpError(400, "display_name is invalid.");
  }
  return trimmed;
}

function requireText(
  value: unknown,
  field: string,
  options: { maxLength: number; pattern?: RegExp } = { maxLength: 120 },
): string {
  if (typeof value !== "string") {
    throw new HttpError(400, `${field} is invalid.`);
  }
  const trimmed = value.trim();
  if (
    trimmed.length < 1 ||
    trimmed.length > options.maxLength ||
    (options.pattern != null && !options.pattern.test(trimmed))
  ) {
    throw new HttpError(400, `${field} is invalid.`);
  }
  return trimmed;
}

function optionalText(
  value: unknown,
  field: string,
  options: { maxLength: number; pattern?: RegExp },
): string | null {
  if (value == null || value === "") {
    return null;
  }
  return requireText(value, field, options);
}

async function callGameRpc<T>(
  client: ReturnType<typeof createAdminClient>,
  name: string,
  params: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await client
    .schema("africlub_game")
    .rpc(name, params);

  if (error) {
    throw mapRpcError(error);
  }

  return data as T;
}

async function callPublicGameRpc<T>(
  client: ReturnType<typeof createUserClient>,
  name: string,
  params: Record<string, unknown> = {},
): Promise<T> {
  const { data, error } = await client.rpc(name, params);

  if (error) {
    throw mapRpcError(error);
  }

  return data as T;
}

export function createGameSessionActionHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps: Dependencies = {
    ...defaultDependencies,
    ...dependencies,
  };

  return async (request: Request) => {
    if (request.method === "OPTIONS") {
      return corsPreflightResponse();
    }
    if (request.method !== "POST") {
      return jsonError("Method not allowed", 405);
    }

    try {
      const body = await parseBody(request);
      const action = body.action;

      if (action == null) {
        throw new HttpError(400, "action is required.");
      }

      if (
        action === "get_planner_options" ||
        action === "get_managed_sessions"
      ) {
        await deps.requireAuthenticatedCaller(request);
        const authorization = getAuthorizationHeader(request);
        if (authorization == null) {
          throw new HttpError(401, "Authentication required.");
        }
        const userClient = deps.createUserClient(authorization);
        const result = await callPublicGameRpc<unknown>(
          userClient,
          action === "get_planner_options"
            ? "get_game_planner_options_v2"
            : "get_managed_game_sessions_v2",
        );
        return jsonOk({ success: true, data: result });
      }

      if (action === "create_managed_session") {
        await deps.requireAuthenticatedCaller(request);
        const authorization = getAuthorizationHeader(request);
        if (authorization == null) {
          throw new HttpError(401, "Authentication required.");
        }
        const userClient = deps.createUserClient(authorization);
        const result = await callPublicGameRpc<unknown>(
          userClient,
          "create_managed_game_session_v2",
          {
            p_pack_id: requireUuid(body.pack_id, "pack_id"),
            p_scheduled_start_at: requireIsoDateTime(
              body.scheduled_start_at,
              "scheduled_start_at",
            ),
            p_eligibility_scope: requireText(
              body.eligibility_scope,
              "eligibility_scope",
              {
                maxLength: 32,
                pattern: /^(club_membership|home_owner|venue)$/,
              },
            ),
            p_display_ids: requireUniqueUuidList(
              body.display_ids,
              "display_ids",
              100,
            ),
            p_organizer_user_ids: requireUniqueUuidList(
              body.organizer_user_ids,
              "organizer_user_ids",
              100,
            ),
            p_idempotency_key: requireIdempotencyKey(body.idempotency_key),
          },
        );
        return jsonOk({ success: true, data: result });
      }

      if (action === "transition_managed_session") {
        await deps.requireAuthenticatedCaller(request);
        const authorization = getAuthorizationHeader(request);
        if (authorization == null) {
          throw new HttpError(401, "Authentication required.");
        }
        const userClient = deps.createUserClient(authorization);
        const result = await callPublicGameRpc<unknown>(
          userClient,
          "transition_managed_game_session_v2",
          {
            p_session_id: requireUuid(body.session_id, "session_id"),
            p_requested_phase: requireText(
              body.requested_phase,
              "requested_phase",
              {
                maxLength: 32,
                pattern:
                  /^(scheduled|activated_lobby|question_open|reveal|paused|completed|cancelled)$/,
              },
            ),
            p_expected_session_version: requireNonNegativeInteger(
              body.expected_session_version,
              "expected_session_version",
            ),
            p_idempotency_key: requireIdempotencyKey(body.idempotency_key),
            p_session_question_id: optionalUuid(
              body.session_question_id,
              "session_question_id",
            ),
            p_phase_deadline: optionalIsoDateTime(
              body.phase_deadline,
              "phase_deadline",
            ),
            p_reason: optionalText(body.reason, "reason", { maxLength: 240 }),
          },
        );
        return jsonOk({ success: true, data: result });
      }

      if (action === "get_tv_state") {
        await deps.requireAuthenticatedCaller(request);
        const sessionId = requireUuid(body.session_id, "session_id");
        const authorization = getAuthorizationHeader(request);
        if (authorization == null) {
          throw new HttpError(401, "Authentication required.");
        }
        const userClient = deps.createUserClient(authorization);
        const state = await callGameRpc<unknown>(userClient, "get_tv_session_state", {
          p_session_id: sessionId,
        });
        return jsonOk({ success: true, data: state });
      }

      if (action === "join_session") {
        await deps.requireAuthenticatedCaller(request);
        const authorization = getAuthorizationHeader(request);
        if (authorization == null) {
          throw new HttpError(401, "Authentication required.");
        }
        const sessionId = requireUuid(body.session_id, "session_id");
        const userClient = deps.createUserClient(authorization);
        const result = await callGameRpc<unknown>(userClient, "join_session", {
          p_session_id: sessionId,
          p_club_id: body.club_id == null || body.club_id === ""
            ? null
            : requireClubId(body.club_id),
          p_display_name: optionalDisplayName(body.display_name),
        });
        return jsonOk({ success: true, data: result });
      }

      if (action === "submit_answer") {
        await deps.requireAuthenticatedCaller(request);
        const authorization = getAuthorizationHeader(request);
        if (authorization == null) {
          throw new HttpError(401, "Authentication required.");
        }
        const userClient = deps.createUserClient(authorization);
        const result = await callGameRpc<unknown>(userClient, "submit_answer", {
          p_session_question_id: requireUuid(
            body.session_question_id,
            "session_question_id",
          ),
          p_session_player_id: requireUuid(body.session_player_id, "session_player_id"),
          p_selected_option_key: requireOptionKey(body.selected_option_key),
          p_idempotency_key: optionalIdempotencyKey(body.idempotency_key),
        });
        return jsonOk({ success: true, data: result });
      }

      if (action === "create_session") {
        const clubId = requireClubId(body.club_id);
        await deps.requireClubAdminCaller(request, clubId);
        const adminClient = deps.createAdminClient();
        const result = await callGameRpc<unknown>(adminClient, "admin_create_session", {
          p_club_id: clubId,
          p_title: requireText(body.title, "title", { maxLength: 120 }),
          p_pack_id: optionalUuid(body.pack_id, "pack_id"),
          p_tv_device_id: optionalUuid(body.tv_device_id, "tv_device_id"),
        });
        return jsonOk({ success: true, data: result });
      }

      if (action === "revoke_tv_device") {
        const clubId = requireClubId(body.club_id);
        await deps.requireClubAdminCaller(request, clubId);
        const adminClient = deps.createAdminClient();
        const result = await callGameRpc<unknown>(adminClient, "admin_revoke_tv_device", {
          p_club_id: clubId,
          p_device_id: requireUuid(body.tv_device_id, "tv_device_id"),
          p_reason: body.reason == null
            ? null
            : requireText(body.reason, "reason", { maxLength: 240 }),
        });
        return jsonOk({ success: true, data: result });
      }

      if (action === "review_question_draft") {
        const clubId = requireClubId(body.club_id);
        await deps.requireClubAdminCaller(request, clubId);
        const adminClient = deps.createAdminClient();
        const result = await callGameRpc<unknown>(
          adminClient,
          "admin_review_question_draft",
          {
            p_draft_id: requireUuid(body.draft_id, "draft_id"),
            p_decision: requireText(body.decision, "decision", {
              maxLength: 32,
              pattern: /^(approved|rejected|needs_changes)$/i,
            }),
            p_notes: body.notes == null ? null : requireText(body.notes, "notes", {
              maxLength: 1000,
            }),
          },
        );
        return jsonOk({ success: true, data: result });
      }

      if (action === "list_question_drafts") {
        const clubId = requireClubId(body.club_id);
        await deps.requireClubAdminCaller(request, clubId);
        const adminClient = deps.createAdminClient();
        const result = await callGameRpc<unknown>(
          adminClient,
          "admin_list_question_drafts",
          {
            p_club_id: clubId,
            p_status: optionalText(body.status, "status", {
              maxLength: 32,
              pattern: /^(pending_review|approved|rejected|needs_changes)$/i,
            }),
            p_search: optionalText(body.search, "search", { maxLength: 120 }),
            p_limit: optionalPositiveInteger(body.limit, "limit", 25),
            p_offset: optionalNonNegativeInteger(body.offset, "offset", 0),
          },
        );
        return jsonOk({ success: true, data: result });
      }

      if (action === "publish_question_pack") {
        const clubId = requireClubId(body.club_id);
        await deps.requireClubAdminCaller(request, clubId);
        if (!Array.isArray(body.question_ids)) {
          throw new HttpError(400, "question_ids is invalid.");
        }
        const questionIds = body.question_ids.map((id) =>
          requireUuid(id, "question_ids")
        );
        if (
          questionIds.length !== 20 ||
          new Set(questionIds).size !== questionIds.length
        ) {
          throw new HttpError(
            400,
            "question_ids must contain 20 unique questions.",
          );
        }
        if (
          typeof body.preview_fingerprint !== "string" ||
          !SHA256_PATTERN.test(body.preview_fingerprint)
        ) {
          throw new HttpError(400, "preview_fingerprint is invalid.");
        }
        const adminClient = deps.createAdminClient();
        const result = await callGameRpc<unknown>(
          adminClient,
          "admin_publish_question_pack",
          {
            p_club_id: clubId,
            p_title: requireText(body.title, "title", { maxLength: 120 }),
            p_question_ids: questionIds,
            p_description: body.description == null
              ? ""
              : requireText(body.description, "description", { maxLength: 1000 }),
            p_template_id: optionalUuid(body.template_id, "template_id"),
            p_preview_fingerprint: body.preview_fingerprint,
          },
        );
        return jsonOk({ success: true, data: result });
      }

      if (action === "list_audit_log") {
        const clubId = requireClubId(body.club_id);
        await deps.requireClubAdminCaller(request, clubId);
        const adminClient = deps.createAdminClient();
        const result = await callGameRpc<unknown>(adminClient, "admin_list_audit_log", {
          p_club_id: clubId,
          p_limit: optionalPositiveInteger(body.limit, "limit", 25),
          p_offset: optionalNonNegativeInteger(body.offset, "offset", 0),
          p_action: optionalText(body.action_filter, "action_filter", {
            maxLength: 80,
            pattern: /^[a-z0-9_:-]+$/i,
          }),
          p_entity_type: optionalText(body.entity_type, "entity_type", {
            maxLength: 80,
            pattern: /^[a-z0-9_:-]+$/i,
          }),
        });
        return jsonOk({ success: true, data: result });
      }

      if (
        action === "open_question" ||
        action === "reveal_question" ||
        action === "advance_question"
      ) {
        const clubId = requireClubId(body.club_id);
        await deps.requireClubAdminCaller(request, clubId);
        const adminClient = deps.createAdminClient();
        const rpcName = action === "open_question"
          ? "admin_open_question"
          : action === "reveal_question"
            ? "admin_reveal_question"
            : "admin_advance_question";
        const result = await callGameRpc<unknown>(adminClient, rpcName, {
          p_session_question_id: requireUuid(
            body.session_question_id,
            "session_question_id",
          ),
        });
        return jsonOk({ success: true, data: result });
      }

      if (action === "close_session") {
        const clubId = requireClubId(body.club_id);
        await deps.requireClubAdminCaller(request, clubId);
        const adminClient = deps.createAdminClient();
        const result = await callGameRpc<unknown>(adminClient, "admin_close_session", {
          p_session_id: requireUuid(body.session_id, "session_id"),
        });
        return jsonOk({ success: true, data: result });
      }

      throw new HttpError(400, "Unsupported game action.");
    } catch (error) {
      const status = error instanceof HttpError ? error.status : 500;
      const message = error instanceof Error ? error.message : "Game action failed.";
      console.error("game-session-action failed:", error);
      return jsonError(message, status);
    }
  };
}

if (import.meta.main) {
  const handler = createGameSessionActionHandler();
  Deno.serve((req: Request) =>
    handler(req).then(
      (res) =>
        new Response(res.body, {
          ...res,
          headers: {
            ...Object.fromEntries(res.headers.entries()),
            ...corsHeaders(),
          },
        }),
    )
  );
}

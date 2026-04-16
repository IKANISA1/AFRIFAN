import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";
import { HttpError } from "../_shared/auth.ts";
import { requireAppCheckToken } from "../_shared/app_check.ts";
import { normalizeBioPayEmbedding } from "../_shared/BioPay_embedding.ts";
import { validateBioPayLivenessMetadata } from "../_shared/BioPay_liveness.ts";
import {
  countRecentBioPayMatchRateEvents,
  extractClientIp,
  getBioPayMatchProtectionConfig,
  getLatestBioPayMatchRateEventAt,
  hashBioPayMatchActorKey,
  recordBioPayMatchRateEvent,
} from "../_shared/BioPay_match_abuse.ts";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import {
  generateBioPayNonce,
  signBioPayToken,
} from "../_shared/BioPay_signed_token.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import type {
  BioPayMatchProtectionConfig,
  BioPayMatchRateOutcome,
} from "../_shared/BioPay_match_abuse.ts";

type AdminClientLike = unknown;

type MatchRequest = {
  embedding?: unknown;
  liveness?: unknown;
};

type BioPayMatchRow = Record<string, unknown> & {
  profile_id?: unknown;
  score?: unknown;
  club_id?: unknown;
  route_type?: unknown;
  public_id?: unknown;
  user_id?: unknown;
  display_name?: unknown;
  recipient_value?: unknown;
  country_code?: unknown;
  consent_version?: unknown;
  consent_at?: unknown;
  created_at?: unknown;
  updated_at?: unknown;
};

type MatchEventInsert = {
  requesterUserId: string;
  clubId: number;
  matchedProfileId: string | null;
  matched: boolean;
  score: number;
  thresholdUsed: number;
  metadata: Record<string, unknown>;
};

export type BioPayMatchHandlerDependencies = {
  createAdminClient: () => AdminClientLike;
  validateRequest: typeof validateRequest;
  requireAppCheckToken: (request: Request) => Promise<string>;
  validateLiveness: typeof validateBioPayLivenessMetadata;
  now: () => Date;
  getProtectionConfig: (
    adminClient: AdminClientLike,
  ) => Promise<BioPayMatchProtectionConfig>;
  countRecentRateEvents: (
    adminClient: AdminClientLike,
    options: {
      scope: "user" | "ip";
      actorKey: string;
      windowStartIso: string;
      outcomes?: readonly BioPayMatchRateOutcome[];
    },
  ) => Promise<number>;
  getLatestRateEventAt: (
    adminClient: AdminClientLike,
    options: {
      scope: "user" | "ip";
      actorKey: string;
      outcome: BioPayMatchRateOutcome;
      windowStartIso: string;
    },
  ) => Promise<string | null>;
  recordRateEvent: (
    adminClient: AdminClientLike,
    event: {
      scope: "user" | "ip";
      actorKey: string;
      requesterUserId: string;
      outcome: BioPayMatchRateOutcome;
      metadata?: Record<string, unknown>;
    },
  ) => Promise<void>;
  recordOperationalHealthEvent: (
    adminClient: AdminClientLike,
    event: Parameters<typeof recordOperationalHealthEvent>[1],
  ) => Promise<void>;
  recordEdgeFunctionFailure: (
    adminClient: AdminClientLike,
    options: Parameters<typeof recordEdgeFunctionFailure>[1],
  ) => Promise<void>;
  runMatchRpc: (
    adminClient: AdminClientLike,
    clubId: number,
    embedding: number[],
  ) => Promise<BioPayMatchRow | null>;
  insertMatchEvent: (
    adminClient: AdminClientLike,
    event: MatchEventInsert,
  ) => Promise<void>;
};

class BioPayValidationError extends Error { }
const MATCH_RECEIPT_TTL_SECONDS = 45;

function sanitizeHeaderValue(
  value: string | null,
  maxLength = 180,
): string | null {
  const trimmed = value?.trim();
  if (!trimmed) {
    return null;
  }

  return trimmed.slice(0, maxLength);
}

function isoBefore(now: Date, seconds: number) {
  return new Date(now.getTime() - seconds * 1000).toISOString();
}

function isoAfter(startIso: string, seconds: number) {
  return new Date(Date.parse(startIso) + seconds * 1000).toISOString();
}

function secondsUntil(targetIso: string, now: Date) {
  return Math.max(1, Math.ceil((Date.parse(targetIso) - now.getTime()) / 1000));
}

async function runMatchRpc(
  adminClient: AdminClientLike,
  clubId: number,
  embedding: number[],
) {
  const { data, error } = await (adminClient as ReturnType<
    typeof createAdminClient
  >).rpc("match_BioPay_profile_server", {
    p_club_id: clubId,
    p_embedding: embedding,
  });

  if (error) {
    throw error;
  }

  const row = Array.isArray(data) ? data[0] : data;
  return row ? row as BioPayMatchRow : null;
}

async function insertMatchEvent(
  adminClient: AdminClientLike,
  event: MatchEventInsert,
) {
  const { error } = await (adminClient as ReturnType<
    typeof createAdminClient
  >).from("BioPay_match_events").insert({
    requester_user_id: event.requesterUserId,
    club_id: event.clubId,
    matched_profile_id: event.matchedProfileId,
    matched: event.matched,
    score: event.score,
    threshold_used: event.thresholdUsed,
    metadata: event.metadata,
  });

  if (error) {
    throw error;
  }
}

const defaultDependencies: BioPayMatchHandlerDependencies = {
  createAdminClient,
  validateRequest,
  requireAppCheckToken,
  validateLiveness: validateBioPayLivenessMetadata,
  now: () => new Date(),
  getProtectionConfig: (adminClient) =>
    getBioPayMatchProtectionConfig(
      adminClient as ReturnType<typeof createAdminClient>,
    ),
  countRecentRateEvents: (adminClient, options) =>
    countRecentBioPayMatchRateEvents(
      adminClient as ReturnType<typeof createAdminClient>,
      options,
    ),
  getLatestRateEventAt: (adminClient, options) =>
    getLatestBioPayMatchRateEventAt(
      adminClient as ReturnType<typeof createAdminClient>,
      options,
    ),
  recordRateEvent: (adminClient, event) =>
    recordBioPayMatchRateEvent(
      adminClient as ReturnType<typeof createAdminClient>,
      event,
    ),
  recordOperationalHealthEvent: (adminClient, event) =>
    recordOperationalHealthEvent(
      adminClient as ReturnType<typeof createAdminClient>,
      event,
    ),
  recordEdgeFunctionFailure: (adminClient, options) =>
    recordEdgeFunctionFailure(
      adminClient as ReturnType<typeof createAdminClient>,
      options,
    ),
  runMatchRpc,
  insertMatchEvent,
};

export function createBioPayMatchHandler(
  dependencies: Partial<BioPayMatchHandlerDependencies> = {},
) {
  const deps: BioPayMatchHandlerDependencies = {
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

    const adminClient = deps.createAdminClient();
    let requesterUserId: string | null = null;

    try {
      const validated = await deps.validateRequest(request, { requireClubId: true });
      if (isErrorResponse(validated)) return validated;

      const { userId, clubId } = validated;
      requesterUserId = userId;
      const numericClubId = Number(clubId);

      await deps.requireAppCheckToken(request);

      const now = deps.now();
      const body = await request.json() as MatchRequest;
      let embedding: number[];
      try {
        embedding = normalizeBioPayEmbedding(body.embedding);
      } catch (error) {
        throw new BioPayValidationError(
          error instanceof Error ? error.message : "Invalid BioPay embedding.",
        );
      }
      const liveness = await deps.validateLiveness(body.liveness, {
        adminClient: adminClient as ReturnType<typeof createAdminClient>,
        requesterUserId,
        clubId: numericClubId,
        mode: "payment",
      });
      const protectionConfig = await deps.getProtectionConfig(adminClient);
      const clientIp = extractClientIp(request);
      const userActorKey = await hashBioPayMatchActorKey(
        `match_user:${requesterUserId}`,
      );
      const ipActorKey = clientIp == null
        ? null
        : await hashBioPayMatchActorKey(`match_ip:${clientIp}`);
      const telemetryMetadata = {
        ip_actor_key: ipActorKey,
        user_actor_key: userActorKey,
        client_info: sanitizeHeaderValue(request.headers.get("x-client-info")),
        user_agent: sanitizeHeaderValue(request.headers.get("user-agent")),
        liveness,
        app_check_enforced: true,
      };
      const rateWindowStartIso = isoBefore(
        now,
        protectionConfig.rateWindowSeconds,
      );
      const missWindowStartIso = isoBefore(
        now,
        protectionConfig.missWindowSeconds,
      );
      const lockoutWindowStartIso = isoBefore(
        now,
        protectionConfig.lockoutSeconds,
      );

      const latestLockoutAt = await deps.getLatestRateEventAt(adminClient, {
        scope: "user",
        actorKey: userActorKey,
        outcome: "lockout_started",
        windowStartIso: lockoutWindowStartIso,
      });

      if (latestLockoutAt) {
        const lockoutUntil = isoAfter(
          latestLockoutAt,
          protectionConfig.lockoutSeconds,
        );
        if (Date.parse(lockoutUntil) > now.getTime()) {
          const retryAfterSeconds = secondsUntil(lockoutUntil, now);
          await deps.recordRateEvent(adminClient, {
            scope: "user",
            actorKey: userActorKey,
            requesterUserId,
            outcome: "blocked_lockout",
            metadata: {
              ...telemetryMetadata,
              lockout_until: lockoutUntil,
              retry_after_seconds: retryAfterSeconds,
            },
          });
          await deps.recordOperationalHealthEvent(adminClient, {
            service: "BioPay",
            component: "matching",
            status: "warn",
            severity: "warning",
            issueCode: "BioPay_match_locked_out",
            message: "BioPay match request blocked by an active user lockout.",
            functionName: "BioPay-match",
            userId: requesterUserId,
            subjectType: "BioPay_match_request",
            metadata: {
              ...telemetryMetadata,
              lockout_until: lockoutUntil,
            },
          });
          return jsonError(
            "Too many failed BioPay match attempts. Please wait before trying again.",
            423,
            undefined,
            { retryAfterSeconds, lockoutUntil },
          );
        }
      }

      const recentUserAttempts = await deps.countRecentRateEvents(adminClient, {
        scope: "user",
        actorKey: userActorKey,
        windowStartIso: rateWindowStartIso,
        outcomes: ["match", "miss"],
      });

      if (recentUserAttempts >= protectionConfig.userMaxAttempts) {
        await deps.recordRateEvent(adminClient, {
          scope: "user",
          actorKey: userActorKey,
          requesterUserId,
          outcome: "blocked_user_rate_limit",
          metadata: {
            ...telemetryMetadata,
            limit: protectionConfig.userMaxAttempts,
            window_seconds: protectionConfig.rateWindowSeconds,
          },
        });
        await deps.recordOperationalHealthEvent(adminClient, {
          service: "BioPay",
          component: "matching",
          status: "warn",
          severity: "warning",
          issueCode: "BioPay_match_user_rate_limited",
          message: "BioPay match request blocked by the user attempt budget.",
          functionName: "BioPay-match",
          userId: requesterUserId,
          subjectType: "BioPay_match_request",
          metadata: {
            ...telemetryMetadata,
            attempt_count: recentUserAttempts,
            limit: protectionConfig.userMaxAttempts,
          },
        });
        return jsonError(
          "Too many BioPay match attempts. Please wait a moment before trying again.",
          429,
          undefined,
          { retryAfterSeconds: protectionConfig.rateWindowSeconds },
        );
      }

      if (ipActorKey != null) {
        const recentIpAttempts = await deps.countRecentRateEvents(adminClient, {
          scope: "ip",
          actorKey: ipActorKey,
          windowStartIso: rateWindowStartIso,
          outcomes: ["match", "miss"],
        });

        if (recentIpAttempts >= protectionConfig.ipMaxAttempts) {
          await deps.recordRateEvent(adminClient, {
            scope: "ip",
            actorKey: ipActorKey,
            requesterUserId,
            outcome: "blocked_ip_rate_limit",
            metadata: {
              ...telemetryMetadata,
              limit: protectionConfig.ipMaxAttempts,
              window_seconds: protectionConfig.rateWindowSeconds,
            },
          });
          await deps.recordOperationalHealthEvent(adminClient, {
            service: "BioPay",
            component: "matching",
            status: "warn",
            severity: "warning",
            issueCode: "BioPay_match_ip_rate_limited",
            message: "BioPay match request blocked by the IP attempt budget.",
            functionName: "BioPay-match",
            userId: requesterUserId,
            subjectType: "BioPay_match_request",
            metadata: {
              ...telemetryMetadata,
              attempt_count: recentIpAttempts,
              limit: protectionConfig.ipMaxAttempts,
            },
          });
          return jsonError(
            "Too many BioPay match attempts. Please wait a moment before trying again.",
            429,
            undefined,
            { retryAfterSeconds: protectionConfig.rateWindowSeconds },
          );
        }
      }

      const row = await deps.runMatchRpc(adminClient, numericClubId, embedding);
      const score = Number(row?.score ?? 0);
      const normalizedScore = Number.isFinite(score) ? score : 0;
      const hasMatch = !!row &&
        normalizedScore >= protectionConfig.threshold &&
        row.profile_id != null;
      const outcome: BioPayMatchRateOutcome = hasMatch ? "match" : "miss";
      const decisionMetadata = {
        ...telemetryMetadata,
        decision_version: "BioPay-match-v2",
        route_type: row?.route_type ?? null,
        public_id: row?.public_id ?? null,
      };

      try {
        await deps.insertMatchEvent(adminClient, {
          requesterUserId,
          clubId: numericClubId,
          matchedProfileId: hasMatch && row?.profile_id != null
            ? row.profile_id.toString()
            : null,
          matched: hasMatch,
          score: normalizedScore,
          thresholdUsed: protectionConfig.threshold,
          metadata: decisionMetadata,
        });
      } catch (error) {
        await deps.recordOperationalHealthEvent(adminClient, {
          service: "BioPay",
          component: "matching",
          status: "warn",
          severity: "warning",
          issueCode: "BioPay_match_event_insert_failed",
          message: "BioPay match telemetry could not be persisted.",
          functionName: "BioPay-match",
          userId: requesterUserId,
          subjectType: "BioPay_match_event",
          metadata: {
            ...decisionMetadata,
            error: error instanceof Error ? error.message : String(error),
          },
        });
      }

      await deps.recordRateEvent(adminClient, {
        scope: "user",
        actorKey: userActorKey,
        requesterUserId,
        outcome,
        metadata: {
          ...decisionMetadata,
          score: normalizedScore,
          threshold: protectionConfig.threshold,
        },
      });
      if (ipActorKey != null) {
        await deps.recordRateEvent(adminClient, {
          scope: "ip",
          actorKey: ipActorKey,
          requesterUserId,
          outcome,
          metadata: {
            ...decisionMetadata,
            score: normalizedScore,
            threshold: protectionConfig.threshold,
          },
        });
      }

      if (!hasMatch) {
        const recentMisses = await deps.countRecentRateEvents(adminClient, {
          scope: "user",
          actorKey: userActorKey,
          windowStartIso: missWindowStartIso,
          outcomes: ["miss"],
        });

        if (recentMisses >= protectionConfig.maxMissesPerWindow) {
          const lockoutUntil = isoAfter(
            now.toISOString(),
            protectionConfig.lockoutSeconds,
          );
          await deps.recordRateEvent(adminClient, {
            scope: "user",
            actorKey: userActorKey,
            requesterUserId,
            outcome: "lockout_started",
            metadata: {
              ...decisionMetadata,
              miss_count: recentMisses,
              lockout_until: lockoutUntil,
            },
          });
          await deps.recordOperationalHealthEvent(adminClient, {
            service: "BioPay",
            component: "matching",
            status: "warn",
            severity: "warning",
            issueCode: "BioPay_match_lockout_started",
            message:
              "BioPay match request triggered a temporary lockout after repeated misses.",
            functionName: "BioPay-match",
            userId: requesterUserId,
            subjectType: "BioPay_match_request",
            metadata: {
              ...decisionMetadata,
              miss_count: recentMisses,
              lockout_until: lockoutUntil,
            },
          });
          return jsonError(
            "Too many failed BioPay match attempts. Please wait before trying again.",
            423,
            undefined,
            {
              retryAfterSeconds: protectionConfig.lockoutSeconds,
              lockoutUntil,
            },
          );
        }

        return jsonOk({
          success: true,
          data: {
            match: false,
            score: normalizedScore,
          },
        });
      }

      const matchReceiptExpiresAt = new Date(
        now.getTime() + MATCH_RECEIPT_TTL_SECONDS * 1000,
      ).toISOString();
      const matchReceipt = await signBioPayToken({
        kind: "match_receipt",
        v: 1,
        iat: now.toISOString(),
        exp: matchReceiptExpiresAt,
        nonce: generateBioPayNonce(),
        requester_user_id: requesterUserId,
        profile_id: row.profile_id?.toString() ?? "",
        profile_public_id: row.public_id?.toString() ?? "",
        club_id: row.club_id?.toString() ?? null,
        score: normalizedScore,
      });

      return jsonOk({
        success: true,
        data: {
          match: true,
          match_receipt: matchReceipt,
          match_receipt_expires_at: matchReceiptExpiresAt,
          ...row,
        },
      });
    } catch (error) {
      if (error instanceof SyntaxError) {
        return jsonError("Invalid JSON body", 400);
      }
      if (error instanceof HttpError) {
        return jsonError(error.message, error.status);
      }
      if (error instanceof BioPayValidationError) {
        return jsonError(error.message, 400);
      }

      await deps.recordEdgeFunctionFailure(adminClient, {
        functionName: "BioPay-match",
        error,
        issueCode: "BioPay_match_failed",
        userId: requesterUserId,
      });
      console.error("BioPay-match failed:", error);
      return jsonError(
        error instanceof Error ? error.message : "BioPay match failed.",
        500,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createBioPayMatchHandler();
  Deno.serve((req: Request) => handler(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}

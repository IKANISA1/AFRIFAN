import {
  createGameRuntimeClient,
  GameRuntimeRequestError,
  type GameAuditLogRow,
  type GameQuestionDraftQueueRow,
  type GameQuestionDraftStatus,
} from "@/lib/game-runtime";
import { AdminApiError } from "./http";

const MAX_GAME_ADMIN_ROWS = 100;
const SAFE_AUDIT_DETAIL_KEYS = new Set([
  "decision",
  "question_count",
  "question_id",
  "session_id",
  "status",
  "tv_device_id",
]);
const draftStatuses = new Set<GameQuestionDraftStatus>([
  "pending_review",
  "approved",
  "rejected",
  "needs_changes",
]);

export type AdminGameSnapshot = {
  drafts: GameQuestionDraftQueueRow[];
  audit: GameAuditLogRow[];
};

function boundedText(value: unknown, maximum: number, fallback = "") {
  if (typeof value !== "string") return fallback;
  return value
    .replace(/[\u0000-\u001f\u007f]+/g, " ")
    .trim()
    .slice(0, maximum);
}

function boundedInteger(value: unknown, maximum = Number.MAX_SAFE_INTEGER) {
  if (typeof value !== "number" || !Number.isFinite(value)) return 0;
  return Math.min(maximum, Math.max(0, Math.trunc(value)));
}

function validDate(value: unknown) {
  const text = boundedText(value, 40);
  return text && Number.isFinite(Date.parse(text)) ? text : "";
}

function safeHttpUrl(value: unknown) {
  const text = boundedText(value, 2_048);
  if (!text) return null;
  try {
    const url = new URL(text);
    if (
      (url.protocol !== "https:" && url.protocol !== "http:") ||
      url.username ||
      url.password
    ) {
      return null;
    }
    url.hash = "";
    return url.toString();
  } catch {
    return null;
  }
}

export function normalizeAdminGameDrafts(
  value: unknown,
): GameQuestionDraftQueueRow[] {
  if (!Array.isArray(value)) return [];

  return value.slice(0, MAX_GAME_ADMIN_ROWS).flatMap((entry) => {
    if (entry == null || typeof entry !== "object") return [];
    const row = entry as Record<string, unknown>;
    const id = boundedText(row["id"], 128);
    const prompt = boundedText(row["prompt"], 1_000);
    const validationStatus = boundedText(row["validationStatus"], 40);
    const createdAt = validDate(row["createdAt"]);
    if (
      !id ||
      !prompt ||
      !createdAt ||
      !draftStatuses.has(validationStatus as GameQuestionDraftStatus)
    ) {
      return [];
    }

    const duplicatePromptCount = boundedInteger(
      row["duplicatePromptCount"],
      10_000,
    );
    const similarPromptCount = boundedInteger(
      row["similarPromptCount"],
      10_000,
    );
    const risk = boundedText(row["duplicateRiskLevel"], 20);
    const duplicateRiskLevel =
      risk === "normalized" || risk === "exact" ? risk : "none";
    const sourceTitle = boundedText(row["sourceTitle"], 240) || null;
    const sourceTrustTier =
      boundedText(row["sourceTrustTier"], 80) || null;
    const generationMode =
      row["generationMode"] === "ai_assisted"
        ? "ai_assisted"
        : "human_authored";
    const qaSource =
      row["qaChecks"] != null &&
      typeof row["qaChecks"] === "object" &&
      !Array.isArray(row["qaChecks"])
        ? (row["qaChecks"] as Record<string, unknown>)
        : {};

    return [
      {
        id,
        sourceId: boundedText(row["sourceId"], 128) || null,
        prompt,
        category: boundedText(row["category"], 80, "uncategorized"),
        difficulty: boundedText(row["difficulty"], 40, "unrated"),
        language: boundedText(row["language"], 12, "en"),
        validationStatus: validationStatus as GameQuestionDraftStatus,
        validationNotes: boundedText(row["validationNotes"], 1_000),
        duplicatePromptCount,
        hasDuplicatePrompt:
          row["hasDuplicatePrompt"] === true && duplicatePromptCount > 0,
        similarPromptCount,
        hasSimilarPrompt:
          row["hasSimilarPrompt"] === true && similarPromptCount > 0,
        duplicateRiskLevel,
        normalizedPromptSignature: boundedText(
          row["normalizedPromptSignature"],
          1_000,
        ),
        sourceTitle,
        sourceUrl: safeHttpUrl(row["sourceUrl"]),
        sourceTrustTier,
        citationFragment:
          boundedText(row["citationFragment"], 500) || null,
        schemaVersion: boundedText(row["schemaVersion"], 80) || null,
        generationMode,
        modelName: boundedText(row["modelName"], 160) || null,
        reviewedAt: validDate(row["reviewedAt"]) || null,
        reviewerName: boundedText(row["reviewerName"], 160) || null,
        qaChecks: {
          sourcePresent: qaSource["sourcePresent"] === true,
          citationPresent: qaSource["citationPresent"] === true,
          sourceTrusted: qaSource["sourceTrusted"] === true,
          schemaVersionPresent:
            qaSource["schemaVersionPresent"] === true,
          modelMetadataPresent:
            qaSource["modelMetadataPresent"] === true,
          promptLengthValid: qaSource["promptLengthValid"] === true,
          exactDuplicateFree: qaSource["exactDuplicateFree"] === true,
          normalizedDuplicateFree:
            qaSource["normalizedDuplicateFree"] === true,
          ambiguitySignalsAbsent:
            qaSource["ambiguitySignalsAbsent"] === true,
          answerConsistent: qaSource["answerConsistent"] === true,
          languageSupported: qaSource["languageSupported"] === true,
          policyCompliant: qaSource["policyCompliant"] === true,
        },
        createdAt,
      },
    ];
  });
}

function normalizeAuditDetails(value: unknown) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return null;
  }

  const details: Array<[string, string | number | boolean | null]> = [];
  for (const [key, raw] of Object.entries(value as Record<string, unknown>)) {
    if (!SAFE_AUDIT_DETAIL_KEYS.has(key) || details.length >= 12) continue;
    if (raw == null || typeof raw === "boolean") {
      details.push([key, raw ?? null]);
      continue;
    }
    if (typeof raw === "number" && Number.isFinite(raw)) {
      details.push([key, Math.trunc(raw)]);
      continue;
    }
    const text = boundedText(raw, 240);
    if (text) details.push([key, text]);
  }

  return details.length > 0 ? Object.fromEntries(details) : null;
}

export function normalizeAdminGameAudit(value: unknown): GameAuditLogRow[] {
  if (!Array.isArray(value)) return [];

  return value.slice(0, MAX_GAME_ADMIN_ROWS).flatMap((entry) => {
    if (entry == null || typeof entry !== "object") return [];
    const row = entry as Record<string, unknown>;
    const id = boundedText(row["id"], 128);
    const action = boundedText(row["action"], 120);
    const entityType = boundedText(row["entityType"], 120);
    const createdAt = validDate(row["createdAt"]);
    if (!id || !action || !entityType || !createdAt) return [];

    return [
      {
        id,
        action,
        entityType,
        entityId: boundedText(row["entityId"], 128) || null,
        actorId: null,
        createdAt,
        after: normalizeAuditDetails(row["after"]),
      },
    ];
  });
}

export function normalizeAdminGameSnapshot(value: unknown): AdminGameSnapshot {
  const snapshot =
    value != null && typeof value === "object"
      ? (value as Record<string, unknown>)
      : {};
  return {
    drafts: normalizeAdminGameDrafts(snapshot["drafts"]),
    audit: normalizeAdminGameAudit(snapshot["audit"]),
  };
}

function gameFailureToAdminError(error: unknown): never {
  if (error instanceof GameRuntimeRequestError) {
    const status =
      error.status ??
      (error.kind === "permission_denied"
        ? 403
        : error.kind === "conflict"
          ? 409
          : error.kind === "security_timeout"
            ? 504
            : 502);
    throw new AdminApiError(
      "The game operations snapshot could not be loaded.",
      status,
      error.kind === "conflict"
        ? "STALE_RECORD"
        : error.kind === "security_timeout"
          ? "ADMIN_OPERATION_TIMEOUT"
          : null,
    );
  }
  throw error;
}

export async function getAdminGameSnapshot(
  clubId: number,
  options: { signal?: AbortSignal } = {},
): Promise<AdminGameSnapshot> {
  const fetcher: typeof fetch = (input, init) => {
    const requestSignal = init?.signal;
    const signal =
      options.signal && requestSignal
        ? AbortSignal.any([options.signal, requestSignal])
        : (options.signal ?? requestSignal);
    return fetch(input, { ...init, signal });
  };
  const client = createGameRuntimeClient({ fetcher });

  try {
    const [drafts, audit] = await Promise.all([
      client.listQuestionDrafts({
        clubId,
        limit: MAX_GAME_ADMIN_ROWS,
        offset: 0,
      }),
      client.listAuditLog({
        clubId,
        limit: MAX_GAME_ADMIN_ROWS,
        offset: 0,
      }),
    ]);
    return normalizeAdminGameSnapshot({ drafts, audit });
  } catch (error) {
    if (
      options.signal?.aborted &&
      !(error instanceof GameRuntimeRequestError)
    ) {
      throw new DOMException("Aborted", "AbortError");
    }
    return gameFailureToAdminError(error);
  }
}

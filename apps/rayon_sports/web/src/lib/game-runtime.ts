export type GameQuestionPhase =
  "lobby" | "queued" | "open" | "claimed" | "revealed" | "closed";

export type GameAction =
  | "get_tv_state"
  | "join_session"
  | "submit_answer"
  | "create_session"
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

export type GameAnswerOption = {
  key: string;
  label: string;
};

export type GameAnswerClaim = {
  playerName: string;
  teamName: string | null;
  claimedAt: string;
};

export type GameTvQuestion = {
  id: string;
  order: number;
  phase: GameQuestionPhase;
  prompt: string;
  category: string | null;
  difficulty: string | null;
  timeLimitSeconds: number | null;
  openedAt: string | null;
  options: GameAnswerOption[];
  claim: GameAnswerClaim | null;
};

export type GameLeaderboardRow = {
  rank: number;
  teamName: string;
  score: number;
};

export type GameTvSessionState = {
  sessionId: string;
  clubId: number;
  title: string;
  phase: GameQuestionPhase;
  questionIndex: number;
  questionTotal: number;
  currentQuestion: GameTvQuestion | null;
  leaderboard: GameLeaderboardRow[];
  updatedAt: string;
};

export type GameJoinSessionResult = {
  sessionId: string;
  sessionPlayerId: string;
  displayName: string;
  score: number;
  teamId: string | null;
  teamName: string | null;
};

export type GameCreateSessionResult = {
  sessionId: string;
  title: string;
  status: string;
  questionTotal: number;
  firstSessionQuestionId: string | null;
  tvDeviceId: string | null;
};

export type GameAdvanceQuestionResult = {
  sessionId: string;
  previousSessionQuestionId: string;
  nextSessionQuestionId: string | null;
  status: "live" | "complete" | string;
  isComplete: boolean;
};

export type GameCloseSessionResult = {
  sessionId: string;
  status: "complete" | string;
  closedQuestionCount: number;
};

export type GameQuestionDraftReviewResult = {
  draftId: string;
  decision: "approved" | "rejected" | "needs_changes";
  questionId: string | null;
};

export type GameQuestionDraftStatus =
  "pending_review" | "approved" | "rejected" | "needs_changes";

export type GameQuestionDraftQueueRow = {
  id: string;
  sourceId: string | null;
  prompt: string;
  category: string;
  difficulty: string;
  language: string;
  validationStatus: GameQuestionDraftStatus;
  validationNotes: string;
  duplicatePromptCount: number;
  hasDuplicatePrompt: boolean;
  similarPromptCount: number;
  hasSimilarPrompt: boolean;
  duplicateRiskLevel: "none" | "normalized" | "exact";
  normalizedPromptSignature: string;
  sourceTitle: string | null;
  sourceUrl: string | null;
  sourceTrustTier: string | null;
  citationFragment: string | null;
  schemaVersion: string | null;
  generationMode: "ai_assisted" | "human_authored";
  modelName: string | null;
  reviewedAt: string | null;
  reviewerName: string | null;
  qaChecks: {
    sourcePresent: boolean;
    citationPresent: boolean;
    sourceTrusted: boolean;
    schemaVersionPresent: boolean;
    modelMetadataPresent: boolean;
    promptLengthValid: boolean;
    exactDuplicateFree: boolean;
    normalizedDuplicateFree: boolean;
    ambiguitySignalsAbsent: boolean;
    answerConsistent: boolean;
    languageSupported: boolean;
    policyCompliant: boolean;
  };
  createdAt: string;
};

export type GamePublishQuestionPackResult = {
  packId: string;
  title: string;
  status: string;
  questionCount: number;
};

export type GameAuditLogRow = {
  id: string;
  action: string;
  entityType: string;
  entityId: string | null;
  actorId: string | null;
  createdAt: string;
  after: Record<string, unknown> | null;
};

export type GamePlannerPackOption = {
  id: string;
  title: string;
  description: string;
  questionCount: number;
  publishedAt: string | null;
};

export type GamePlannerQuestionOption = {
  id: string;
  prompt: string;
  category: string;
  difficulty: string;
  language: string;
  approvedAt: string | null;
  sourceTitle: string | null;
  sourceUrl: string | null;
  sourceTrustTier: string | null;
};

export type GamePlannerDisplayOption = {
  id: string;
  name: string;
  scopeType: "home" | "venue";
  venueId: string | null;
  pairingStatus: string;
  health: "online" | "offline" | "unknown" | "revoked";
  assignedSessionId: string | null;
};

export type GamePlannerOrganizerOption = {
  userId: string;
  name: string;
  venueId: string | null;
};

export type GamePlannerOptions = {
  clubId: number;
  serverTime: string;
  packs: GamePlannerPackOption[];
  questions: GamePlannerQuestionOption[];
  displays: GamePlannerDisplayOption[];
  organizers: GamePlannerOrganizerOption[];
  allowedEligibilityScopes: Array<"club_membership" | "home_owner" | "venue">;
};

export type ManagedGameDisplay = {
  id: string;
  name: string;
  scopeType: "home" | "venue";
  pairingStatus: string;
  lastSeenAt: string | null;
  health: "online" | "offline" | "unknown" | "revoked";
};

export type ManagedGameOrganizer = {
  name: string;
  assignedAt: string;
};

export type ManagedGameQuestionControl = {
  id: string;
  ordinal: number;
  state: string;
  prompt: string;
};

export type ManagedGameParticipantAggregate = {
  participantCount: number;
  answerCount: number;
  averageScore: number;
};

export type ManagedGameProjectionPreviews = {
  participant: {
    phase: string;
    sessionVersion: number;
    questionVersion: number;
  };
  tv: {
    phase: string;
    assignedDisplayCount: number;
  };
};

export type ManagedGameSession = {
  clubId: number;
  id: string;
  title: string;
  packTitle: string | null;
  phase: string;
  sessionVersion: number;
  questionVersion: number;
  eventSequence: number;
  serverTime: string;
  phaseDeadline: string | null;
  scheduledStartAt: string | null;
  eligibilityScope: string;
  allowedActions: string[];
  participantCount: number;
  assignedDisplays: ManagedGameDisplay[];
  assignedOrganizers: ManagedGameOrganizer[];
  currentQuestion: ManagedGameQuestionControl | null;
  questions: ManagedGameQuestionControl[];
  lastEventAt: string | null;
  participantAggregate: ManagedGameParticipantAggregate | null;
  projectionPreviews: ManagedGameProjectionPreviews | null;
};

export type ManagedGameSessions = {
  clubId: number;
  serverTime: string;
  canPlan: boolean;
  sessions: ManagedGameSession[];
};

export type GameQuestionDraftGenerationBody = {
  club_id: number;
  source: {
    source_title: string;
    extracted_fact: string;
    source_url?: string;
    source_date?: string;
    trust_tier?: string;
  };
  count?: number;
  language?: string;
  category?: string;
  model?: string;
  drafts?: Array<Record<string, unknown>>;
};

export type GameQuestionDraftGenerationResult = {
  sourceId: string;
  draftIds: string[];
  mode: "ai_assisted" | "manual_import";
  count: number;
};

export type GameActionBody =
  | {
      action: "get_tv_state";
      session_id: string;
    }
  | {
      action: "join_session";
      session_id: string;
      club_id?: number;
      display_name?: string;
    }
  | {
      action: "submit_answer";
      session_question_id: string;
      session_player_id: string;
      selected_option_key: string;
      idempotency_key?: string;
    }
  | {
      action: "create_session";
      club_id: number;
      title: string;
      pack_id?: string;
      tv_device_id?: string;
    }
  | {
      action: "revoke_tv_device";
      club_id: number;
      tv_device_id: string;
      reason?: string;
    }
  | {
      action: "review_question_draft";
      club_id: number;
      draft_id: string;
      decision: "approved" | "rejected" | "needs_changes";
      notes?: string;
    }
  | {
      action: "list_question_drafts";
      club_id: number;
      status?: GameQuestionDraftStatus;
      search?: string;
      limit?: number;
      offset?: number;
    }
  | {
      action: "publish_question_pack";
      club_id: number;
      title: string;
      question_ids: string[];
      description?: string;
      template_id?: string;
      preview_fingerprint: string;
    }
  | {
      action: "list_audit_log";
      club_id: number;
      limit?: number;
      offset?: number;
      action_filter?: string;
      entity_type?: string;
    }
  | {
      action: "open_question" | "reveal_question" | "advance_question";
      club_id: number;
      session_question_id: string;
    }
  | {
      action: "close_session";
      club_id: number;
      session_id: string;
    }
  | {
      action: "get_planner_options" | "get_managed_sessions";
    }
  | {
      action: "create_managed_session";
      pack_id: string;
      scheduled_start_at: string;
      eligibility_scope: "club_membership" | "home_owner" | "venue";
      display_ids: string[];
      organizer_user_ids: string[];
      idempotency_key: string;
    }
  | {
      action: "transition_managed_session";
      session_id: string;
      requested_phase: string;
      expected_session_version: number;
      idempotency_key: string;
      session_question_id?: string;
      phase_deadline?: string;
      reason?: string;
    };

export type GameRuntimeClientOptions = {
  endpoint?: string;
  draftGenerationEndpoint?: string;
  fetcher?: typeof fetch;
  timeoutMs?: number;
};

export async function createGamePackPreviewFingerprint(input: {
  title: string;
  description?: string;
  questionIds: string[];
}) {
  if (
    typeof globalThis.crypto?.subtle?.digest !== "function" ||
    typeof TextEncoder === "undefined"
  ) {
    throw new GameRuntimeRequestError(
      "error",
      "Secure game preview review is unavailable.",
    );
  }
  const reviewedProjection = [
    input.title.trim(),
    (input.description ?? "").trim(),
    input.questionIds.join(","),
  ].join("\n");
  const digest = await globalThis.crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(reviewedProjection),
  );
  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, "0"),
  ).join("");
}

export type GameRuntimeFailureKind =
  "error" | "permission_denied" | "conflict" | "security_timeout";

export class GameRuntimeRequestError extends Error {
  constructor(
    readonly kind: GameRuntimeFailureKind,
    message: string,
    readonly status: number | null = null,
  ) {
    super(message);
    this.name = "GameRuntimeRequestError";
  }
}

type SearchParamReader = {
  get(name: string): string | null;
};

const DEFAULT_GAME_RUNTIME_TIMEOUT_MS = 12_000;
const MIN_GAME_RUNTIME_TIMEOUT_MS = 250;
const MAX_GAME_RUNTIME_TIMEOUT_MS = 30_000;

function isSearchParamReader(value: unknown): value is SearchParamReader {
  return (
    value != null &&
    typeof value === "object" &&
    typeof (value as SearchParamReader).get === "function"
  );
}

const TV_PAYLOAD_FORBIDDEN_KEYS = new Set([
  "correct_answer",
  "correct_answer_key",
  "correct_option",
  "correct_option_key",
  "correctoptionkey",
  "explanation",
  "answer_explanation",
]);

function normalizeObjectKey(key: string) {
  return key.replace(/[^a-z0-9]/gi, "").toLowerCase();
}

export function findTvPayloadLeakKeys(
  value: unknown,
  path: string[] = [],
): string[] {
  if (value == null || typeof value !== "object") {
    return [];
  }

  if (Array.isArray(value)) {
    return value.flatMap((item, index) =>
      findTvPayloadLeakKeys(item, [...path, String(index)]),
    );
  }

  return Object.entries(value as Record<string, unknown>).flatMap(
    ([key, child]) => {
      const currentPath = [...path, key];
      const ownFinding = TV_PAYLOAD_FORBIDDEN_KEYS.has(normalizeObjectKey(key))
        ? [currentPath.join(".")]
        : [];
      return [...ownFinding, ...findTvPayloadLeakKeys(child, currentPath)];
    },
  );
}

export function assertTvPayloadIsSafe(value: unknown) {
  const leakKeys = findTvPayloadLeakKeys(value);
  if (leakKeys.length > 0) {
    throw new Error(
      `TV session state contains answer-only field(s): ${leakKeys.join(", ")}`,
    );
  }
}

function parseActionResponse<T>(payload: unknown): T {
  if (payload == null || typeof payload !== "object") {
    throw new GameRuntimeRequestError(
      "error",
      "Game action returned an invalid response.",
    );
  }

  const body = payload as Record<string, unknown>;
  if (body["success"] !== true) {
    throw new GameRuntimeRequestError(
      "error",
      typeof body["error"] === "string" ? body["error"] : "Game action failed.",
    );
  }

  return body["data"] as T;
}

function runtimeRecord(value: unknown, label: string) {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new GameRuntimeRequestError(
      "error",
      `Game ${label} returned an invalid response.`,
    );
  }
  return value as Record<string, unknown>;
}

function runtimeString(
  value: unknown,
  label: string,
  options: { maxLength?: number; nullable: true },
): string | null;
function runtimeString(
  value: unknown,
  label: string,
  options?: { maxLength?: number; nullable?: false },
): string;
function runtimeString(
  value: unknown,
  label: string,
  options: { maxLength?: number; nullable?: boolean } = {},
): string | null {
  if (value == null && options.nullable) return null;
  if (typeof value !== "string") {
    throw new GameRuntimeRequestError("error", `Game ${label} is invalid.`);
  }
  const normalized = value.replace(/[\u0000-\u001f\u007f]+/g, " ").trim();
  if (
    normalized.length === 0 ||
    normalized.length > (options.maxLength ?? 500)
  ) {
    throw new GameRuntimeRequestError("error", `Game ${label} is invalid.`);
  }
  return normalized;
}

function runtimeInteger(value: unknown, label: string, minimum = 0) {
  const parsed =
    typeof value === "number" ? value : Number.parseInt(String(value), 10);
  if (!Number.isSafeInteger(parsed) || parsed < minimum) {
    throw new GameRuntimeRequestError("error", `Game ${label} is invalid.`);
  }
  return parsed;
}

function runtimeNumber(value: unknown, label: string, minimum = 0) {
  const parsed = typeof value === "number" ? value : Number(value);
  if (!Number.isFinite(parsed) || parsed < minimum) {
    throw new GameRuntimeRequestError("error", `Game ${label} is invalid.`);
  }
  return parsed;
}

function runtimeArray(value: unknown, label: string, maximum: number) {
  if (!Array.isArray(value) || value.length > maximum) {
    throw new GameRuntimeRequestError("error", `Game ${label} is invalid.`);
  }
  return value;
}

function normalizePlannerOptions(value: unknown): GamePlannerOptions {
  const body = runtimeRecord(value, "planner options");
  const eligibility = runtimeArray(
    body["allowed_eligibility_scopes"],
    "eligibility scopes",
    3,
  ).map((item) => runtimeString(item, "eligibility scope", { maxLength: 32 }));
  const allowedEligibilityScopes = eligibility.filter(
    (item): item is "club_membership" | "home_owner" | "venue" =>
      item === "club_membership" || item === "home_owner" || item === "venue",
  );
  if (
    allowedEligibilityScopes.length !== eligibility.length ||
    new Set(allowedEligibilityScopes).size !== allowedEligibilityScopes.length
  ) {
    throw new GameRuntimeRequestError(
      "error",
      "Game eligibility scopes are invalid.",
    );
  }

  return {
    clubId: runtimeInteger(body["club_id"], "planner club id", 1),
    serverTime: runtimeString(body["server_time"], "planner server time", {
      maxLength: 64,
    }),
    packs: runtimeArray(body["packs"], "planner packs", 100).map((item) => {
      const row = runtimeRecord(item, "planner pack");
      return {
        id: runtimeString(row["pack_id"], "pack id", { maxLength: 64 }),
        title: runtimeString(row["title"], "pack title", { maxLength: 120 }),
        description:
          runtimeString(row["description"], "pack description", {
            maxLength: 240,
            nullable: true,
          }) ?? "",
        questionCount: runtimeInteger(
          row["question_count"],
          "pack question count",
          1,
        ),
        publishedAt: runtimeString(row["published_at"], "pack published time", {
          maxLength: 64,
          nullable: true,
        }),
      };
    }),
    questions: runtimeArray(
      body["questions"] ?? [],
      "approved questions",
      200,
    ).map((item) => {
      const row = runtimeRecord(item, "approved question");
      return {
        id: runtimeString(row["question_id"], "question id", {
          maxLength: 64,
        }),
        prompt: runtimeString(row["prompt"], "question prompt", {
          maxLength: 500,
        }),
        category: runtimeString(row["category"], "question category", {
          maxLength: 80,
        }),
        difficulty: runtimeString(row["difficulty"], "question difficulty", {
          maxLength: 32,
        }),
        language: runtimeString(row["language"], "question language", {
          maxLength: 16,
        }),
        approvedAt: runtimeString(
          row["approved_at"],
          "question approval time",
          { maxLength: 64, nullable: true },
        ),
        sourceTitle: runtimeString(
          row["source_title"],
          "question source title",
          {
            maxLength: 160,
            nullable: true,
          },
        ),
        sourceUrl: runtimeString(row["source_url"], "question source URL", {
          maxLength: 500,
          nullable: true,
        }),
        sourceTrustTier: runtimeString(
          row["source_trust_tier"],
          "question source trust tier",
          { maxLength: 48, nullable: true },
        ),
      };
    }),
    displays: runtimeArray(body["displays"], "planner displays", 100).map(
      (item) => {
        const row = runtimeRecord(item, "planner display");
        const scopeType = runtimeString(row["scope_type"], "display scope", {
          maxLength: 16,
        });
        const health = runtimeString(row["health"], "display health", {
          maxLength: 16,
        });
        if (scopeType !== "home" && scopeType !== "venue") {
          throw new GameRuntimeRequestError(
            "error",
            "Game display scope is invalid.",
          );
        }
        if (
          health !== "online" &&
          health !== "offline" &&
          health !== "unknown" &&
          health !== "revoked"
        ) {
          throw new GameRuntimeRequestError(
            "error",
            "Game display health is invalid.",
          );
        }
        return {
          id: runtimeString(row["display_id"], "display id", {
            maxLength: 64,
          }),
          name: runtimeString(row["display_name"], "display name", {
            maxLength: 80,
          }),
          scopeType,
          venueId: runtimeString(row["venue_id"], "display venue id", {
            maxLength: 64,
            nullable: true,
          }),
          pairingStatus: runtimeString(
            row["pairing_status"],
            "display pairing status",
            { maxLength: 32 },
          ),
          health,
          assignedSessionId: runtimeString(
            row["assigned_session_id"],
            "assigned session id",
            { maxLength: 64, nullable: true },
          ),
        };
      },
    ),
    organizers: runtimeArray(body["organizers"], "planner organizers", 100).map(
      (item) => {
        const row = runtimeRecord(item, "planner organizer");
        return {
          userId: runtimeString(row["user_id"], "organizer user id", {
            maxLength: 64,
          }),
          name: runtimeString(row["display_name"], "organizer display name", {
            maxLength: 120,
          }),
          venueId: runtimeString(row["venue_id"], "organizer venue id", {
            maxLength: 64,
            nullable: true,
          }),
        };
      },
    ),
    allowedEligibilityScopes,
  };
}

function normalizeManagedSession(value: unknown): ManagedGameSession {
  const row = runtimeRecord(value, "managed session");
  const currentQuestionValue = row["current_question_control"];
  const currentQuestion =
    currentQuestionValue == null
      ? null
      : (() => {
          const question = runtimeRecord(
            currentQuestionValue,
            "current question",
          );
          return {
            id: runtimeString(question["id"], "current question id", {
              maxLength: 64,
            }),
            ordinal: runtimeInteger(
              question["ordinal"],
              "current question order",
              1,
            ),
            state: runtimeString(question["state"], "current question state", {
              maxLength: 32,
            }),
            prompt: runtimeString(
              question["prompt"],
              "current question prompt",
              { maxLength: 500 },
            ),
          };
        })();
  const participantAggregateValue = row["participant_aggregate"];
  const participantAggregate =
    participantAggregateValue == null
      ? null
      : (() => {
          const aggregate = runtimeRecord(
            participantAggregateValue,
            "participant aggregate",
          );
          return {
            participantCount: runtimeInteger(
              aggregate["participant_count"],
              "participant aggregate count",
              0,
            ),
            answerCount: runtimeInteger(
              aggregate["answer_count"],
              "participant answer count",
              0,
            ),
            averageScore: runtimeNumber(
              aggregate["average_score"],
              "participant average score",
              0,
            ),
          };
        })();
  const projectionPreviewsValue = row["projection_previews"];
  const projectionPreviews =
    projectionPreviewsValue == null
      ? null
      : (() => {
          const previews = runtimeRecord(
            projectionPreviewsValue,
            "projection previews",
          );
          const participant = runtimeRecord(
            previews["participant"],
            "participant projection preview",
          );
          const tv = runtimeRecord(previews["tv"], "TV projection preview");
          return {
            participant: {
              phase: runtimeString(
                participant["phase"],
                "participant preview phase",
                { maxLength: 32 },
              ),
              sessionVersion: runtimeInteger(
                participant["session_version"],
                "participant preview session version",
                0,
              ),
              questionVersion: runtimeInteger(
                participant["question_version"],
                "participant preview question version",
                0,
              ),
            },
            tv: {
              phase: runtimeString(tv["phase"], "TV preview phase", {
                maxLength: 32,
              }),
              assignedDisplayCount: runtimeInteger(
                tv["assigned_display_count"],
                "TV preview display count",
                0,
              ),
            },
          };
        })();

  return {
    clubId: runtimeInteger(row["club_id"], "managed session club id", 1),
    id: runtimeString(row["session_id"], "managed session id", {
      maxLength: 64,
    }),
    title: runtimeString(row["session_title"], "managed session title", {
      maxLength: 120,
    }),
    packTitle: runtimeString(row["pack_title"], "managed session pack title", {
      maxLength: 120,
      nullable: true,
    }),
    phase: runtimeString(row["phase"], "managed session phase", {
      maxLength: 32,
    }),
    sessionVersion: runtimeInteger(
      row["session_version"],
      "managed session version",
      0,
    ),
    questionVersion: runtimeInteger(
      row["question_version"],
      "managed question version",
      0,
    ),
    eventSequence: runtimeInteger(
      row["event_sequence"],
      "managed event sequence",
      0,
    ),
    serverTime: runtimeString(row["server_time"], "managed server time", {
      maxLength: 64,
    }),
    phaseDeadline: runtimeString(
      row["phase_deadline"],
      "managed phase deadline",
      { maxLength: 64, nullable: true },
    ),
    scheduledStartAt: runtimeString(
      row["scheduled_start_at"],
      "managed scheduled start",
      { maxLength: 64, nullable: true },
    ),
    eligibilityScope: runtimeString(
      row["eligibility_scope"],
      "managed eligibility scope",
      { maxLength: 32 },
    ),
    allowedActions: runtimeArray(
      row["allowed_actions"],
      "managed allowed actions",
      8,
    ).map((item) =>
      runtimeString(item, "managed allowed action", { maxLength: 32 }),
    ),
    participantCount: runtimeInteger(
      row["participant_count"],
      "managed participant count",
      0,
    ),
    assignedDisplays: runtimeArray(
      row["assigned_displays"],
      "managed assigned displays",
      100,
    ).map((item) => {
      const display = runtimeRecord(item, "managed assigned display");
      const scopeType = runtimeString(
        display["scope_type"],
        "managed display scope",
        { maxLength: 16 },
      );
      const health = runtimeString(
        display["health"],
        "managed display health",
        { maxLength: 16 },
      );
      if (scopeType !== "home" && scopeType !== "venue") {
        throw new GameRuntimeRequestError(
          "error",
          "Game display scope is invalid.",
        );
      }
      if (
        health !== "online" &&
        health !== "offline" &&
        health !== "unknown" &&
        health !== "revoked"
      ) {
        throw new GameRuntimeRequestError(
          "error",
          "Game display health is invalid.",
        );
      }
      return {
        id: runtimeString(display["display_id"], "managed display id", {
          maxLength: 64,
        }),
        name: runtimeString(display["display_name"], "managed display name", {
          maxLength: 80,
        }),
        scopeType,
        pairingStatus: runtimeString(
          display["pairing_status"],
          "managed display pairing status",
          { maxLength: 32 },
        ),
        lastSeenAt: runtimeString(
          display["last_seen_at"],
          "managed display last seen",
          { maxLength: 64, nullable: true },
        ),
        health,
      };
    }),
    assignedOrganizers: runtimeArray(
      row["assigned_organizers"],
      "managed assigned organizers",
      100,
    ).map((item) => {
      const organizer = runtimeRecord(item, "managed assigned organizer");
      return {
        name: runtimeString(
          organizer["display_name"],
          "managed organizer display name",
          { maxLength: 120 },
        ),
        assignedAt: runtimeString(
          organizer["assigned_at"],
          "managed organizer assigned time",
          { maxLength: 64 },
        ),
      };
    }),
    currentQuestion,
    questions: runtimeArray(
      row["question_controls"],
      "managed question controls",
      100,
    ).map((item) => {
      const question = runtimeRecord(item, "managed question control");
      return {
        id: runtimeString(question["id"], "managed question id", {
          maxLength: 64,
        }),
        ordinal: runtimeInteger(
          question["ordinal"],
          "managed question order",
          1,
        ),
        state: runtimeString(question["state"], "managed question state", {
          maxLength: 32,
        }),
        prompt: runtimeString(question["prompt"], "managed question prompt", {
          maxLength: 500,
        }),
      };
    }),
    lastEventAt: runtimeString(
      runtimeRecord(row["freshness"] ?? {}, "managed freshness")[
        "last_event_at"
      ],
      "managed last event",
      { maxLength: 64, nullable: true },
    ),
    participantAggregate,
    projectionPreviews,
  };
}

function normalizeManagedSessions(value: unknown): ManagedGameSessions {
  const body = runtimeRecord(value, "managed sessions");
  if (typeof body["can_plan"] !== "boolean") {
    throw new GameRuntimeRequestError(
      "error",
      "Game managed planning authority is invalid.",
    );
  }
  return {
    clubId: runtimeInteger(body["club_id"], "managed sessions club id", 1),
    serverTime: runtimeString(body["server_time"], "managed sessions time", {
      maxLength: 64,
    }),
    canPlan: body["can_plan"],
    sessions: runtimeArray(body["sessions"], "managed sessions", 100).map(
      normalizeManagedSession,
    ),
  };
}

function boundedRuntimeTimeout(timeoutMs: number | undefined) {
  if (timeoutMs == null || !Number.isFinite(timeoutMs)) {
    return DEFAULT_GAME_RUNTIME_TIMEOUT_MS;
  }

  return Math.min(
    MAX_GAME_RUNTIME_TIMEOUT_MS,
    Math.max(MIN_GAME_RUNTIME_TIMEOUT_MS, Math.trunc(timeoutMs)),
  );
}

function controlledRuntimeMessage(payload: unknown, fallback: string) {
  if (payload == null || typeof payload !== "object") {
    return fallback;
  }

  const raw = (payload as Record<string, unknown>)["error"];
  if (typeof raw !== "string") {
    return fallback;
  }

  const normalized = raw.replace(/[\u0000-\u001f\u007f]+/g, " ").trim();
  return normalized ? normalized.slice(0, 240) : fallback;
}

function failureKindForStatus(status: number): GameRuntimeFailureKind {
  if (status === 401 || status === 403) return "permission_denied";
  if (status === 409) return "conflict";
  if (status === 408 || status === 504) return "security_timeout";
  return "error";
}

async function executeBoundedGameRequest<T>({
  fetcher,
  input,
  timeoutMs,
}: {
  fetcher: typeof fetch;
  input: Parameters<typeof fetch>;
  timeoutMs: number;
}) {
  const controller = new AbortController();
  let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timeoutHandle = setTimeout(() => {
      controller.abort();
      reject(
        new GameRuntimeRequestError(
          "security_timeout",
          "The game service did not respond in time.",
          504,
        ),
      );
    }, timeoutMs);
  });

  try {
    return await Promise.race([
      (async () => {
        const [url, init] = input;
        const response = await fetcher(url, {
          ...init,
          signal: controller.signal,
        });
        const payload = await response.json().catch(() => null);

        if (!response.ok) {
          const status = response.status || 500;
          throw new GameRuntimeRequestError(
            failureKindForStatus(status),
            controlledRuntimeMessage(payload, "Game action failed."),
            status,
          );
        }

        return parseActionResponse<T>(payload);
      })(),
      timeout,
    ]);
  } catch (error) {
    if (error instanceof GameRuntimeRequestError) {
      throw error;
    }
    throw new GameRuntimeRequestError(
      controller.signal.aborted ? "security_timeout" : "error",
      controller.signal.aborted
        ? "The game service did not respond in time."
        : "The game service is temporarily unavailable.",
      controller.signal.aborted ? 504 : null,
    );
  } finally {
    if (timeoutHandle != null) {
      clearTimeout(timeoutHandle);
    }
  }
}

async function postGameAction<T>(
  options: GameRuntimeClientOptions,
  body: GameActionBody,
) {
  const fetcher = options.fetcher ?? fetch;
  return executeBoundedGameRequest<T>({
    fetcher,
    timeoutMs: boundedRuntimeTimeout(options.timeoutMs),
    input: [
      options.endpoint ?? "/api/game-session-action",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify(body),
      },
    ],
  });
}

async function postQuestionDraftGeneration<T>(
  options: GameRuntimeClientOptions,
  body: GameQuestionDraftGenerationBody,
) {
  const fetcher = options.fetcher ?? fetch;
  return executeBoundedGameRequest<T>({
    fetcher,
    timeoutMs: boundedRuntimeTimeout(options.timeoutMs),
    input: [
      options.draftGenerationEndpoint ?? "/api/generate-question-drafts",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: "include",
        body: JSON.stringify(body),
      },
    ],
  });
}

export function createGameRuntimeClient(options: GameRuntimeClientOptions) {
  return {
    async getPlannerOptions() {
      const result = await postGameAction<unknown>(options, {
        action: "get_planner_options",
      });
      return normalizePlannerOptions(result);
    },

    async getManagedSessions() {
      const result = await postGameAction<unknown>(options, {
        action: "get_managed_sessions",
      });
      return normalizeManagedSessions(result);
    },

    async createManagedSession(input: {
      packId: string;
      scheduledStartAt: string;
      eligibilityScope: "club_membership" | "home_owner" | "venue";
      displayIds: string[];
      organizerUserIds: string[];
      idempotencyKey: string;
    }) {
      const result = await postGameAction<unknown>(options, {
        action: "create_managed_session",
        pack_id: input.packId,
        scheduled_start_at: input.scheduledStartAt,
        eligibility_scope: input.eligibilityScope,
        display_ids: input.displayIds,
        organizer_user_ids: input.organizerUserIds,
        idempotency_key: input.idempotencyKey,
      });
      return normalizeManagedSession(result);
    },

    async transitionManagedSession(input: {
      sessionId: string;
      requestedPhase: string;
      expectedSessionVersion: number;
      idempotencyKey: string;
      sessionQuestionId?: string;
      phaseDeadline?: string;
      reason?: string;
    }) {
      const result = await postGameAction<unknown>(options, {
        action: "transition_managed_session",
        session_id: input.sessionId,
        requested_phase: input.requestedPhase,
        expected_session_version: input.expectedSessionVersion,
        idempotency_key: input.idempotencyKey,
        session_question_id: input.sessionQuestionId,
        phase_deadline: input.phaseDeadline,
        reason: input.reason,
      });
      return normalizeManagedSession(result);
    },

    async getTvState(sessionId: string) {
      const state = await postGameAction<GameTvSessionState>(options, {
        action: "get_tv_state",
        session_id: sessionId,
      });
      assertTvPayloadIsSafe(state);
      return state;
    },

    joinSession(input: {
      sessionId: string;
      clubId?: number;
      displayName?: string;
    }) {
      return postGameAction<GameJoinSessionResult>(options, {
        action: "join_session",
        session_id: input.sessionId,
        club_id: input.clubId,
        display_name: input.displayName,
      });
    },

    submitAnswer(input: {
      sessionQuestionId: string;
      sessionPlayerId: string;
      selectedOptionKey: string;
      idempotencyKey?: string;
    }) {
      return postGameAction<unknown>(options, {
        action: "submit_answer",
        session_question_id: input.sessionQuestionId,
        session_player_id: input.sessionPlayerId,
        selected_option_key: input.selectedOptionKey,
        idempotency_key: input.idempotencyKey,
      });
    },

    createSession(input: {
      clubId: number;
      title: string;
      packId?: string;
      tvDeviceId?: string;
    }) {
      return postGameAction<GameCreateSessionResult>(options, {
        action: "create_session",
        club_id: input.clubId,
        title: input.title,
        pack_id: input.packId,
        tv_device_id: input.tvDeviceId,
      });
    },

    revokeTvDevice(input: {
      clubId: number;
      tvDeviceId: string;
      reason?: string;
    }) {
      return postGameAction<{ tvDeviceId: string; status: string }>(options, {
        action: "revoke_tv_device",
        club_id: input.clubId,
        tv_device_id: input.tvDeviceId,
        reason: input.reason,
      });
    },

    reviewQuestionDraft(input: {
      clubId: number;
      draftId: string;
      decision: "approved" | "rejected" | "needs_changes";
      notes?: string;
    }) {
      return postGameAction<GameQuestionDraftReviewResult>(options, {
        action: "review_question_draft",
        club_id: input.clubId,
        draft_id: input.draftId,
        decision: input.decision,
        notes: input.notes,
      });
    },

    publishQuestionPack(input: {
      clubId: number;
      title: string;
      questionIds: string[];
      description?: string;
      templateId?: string;
      previewFingerprint: string;
    }) {
      return postGameAction<GamePublishQuestionPackResult>(options, {
        action: "publish_question_pack",
        club_id: input.clubId,
        title: input.title,
        question_ids: input.questionIds,
        description: input.description,
        template_id: input.templateId,
        preview_fingerprint: input.previewFingerprint,
      });
    },

    listQuestionDrafts(input: {
      clubId: number;
      status?: GameQuestionDraftStatus;
      search?: string;
      limit?: number;
      offset?: number;
    }) {
      return postGameAction<GameQuestionDraftQueueRow[]>(options, {
        action: "list_question_drafts",
        club_id: input.clubId,
        status: input.status,
        search: input.search,
        limit: input.limit,
        offset: input.offset,
      });
    },

    listAuditLog(input: {
      clubId: number;
      limit?: number;
      offset?: number;
      actionFilter?: string;
      entityType?: string;
    }) {
      return postGameAction<GameAuditLogRow[]>(options, {
        action: "list_audit_log",
        club_id: input.clubId,
        limit: input.limit,
        offset: input.offset,
        action_filter: input.actionFilter,
        entity_type: input.entityType,
      });
    },

    openQuestion(input: { clubId: number; sessionQuestionId: string }) {
      return postGameAction<unknown>(options, {
        action: "open_question",
        club_id: input.clubId,
        session_question_id: input.sessionQuestionId,
      });
    },

    revealQuestion(input: { clubId: number; sessionQuestionId: string }) {
      return postGameAction<unknown>(options, {
        action: "reveal_question",
        club_id: input.clubId,
        session_question_id: input.sessionQuestionId,
      });
    },

    advanceQuestion(input: { clubId: number; sessionQuestionId: string }) {
      return postGameAction<GameAdvanceQuestionResult>(options, {
        action: "advance_question",
        club_id: input.clubId,
        session_question_id: input.sessionQuestionId,
      });
    },

    closeSession(input: { clubId: number; sessionId: string }) {
      return postGameAction<GameCloseSessionResult>(options, {
        action: "close_session",
        club_id: input.clubId,
        session_id: input.sessionId,
      });
    },

    generateQuestionDrafts(input: {
      clubId: number;
      sourceTitle: string;
      extractedFact: string;
      sourceUrl?: string;
      sourceDate?: string;
      trustTier?: string;
      count?: number;
      language?: string;
      category?: string;
    }) {
      return postQuestionDraftGeneration<GameQuestionDraftGenerationResult>(
        options,
        {
          club_id: input.clubId,
          source: {
            source_title: input.sourceTitle,
            extracted_fact: input.extractedFact,
            source_url: input.sourceUrl,
            source_date: input.sourceDate,
            trust_tier: input.trustTier,
          },
          count: input.count,
          language: input.language,
          category: input.category,
        },
      );
    },
  };
}

export function resolveTvSessionId(
  searchParams:
    SearchParamReader | Record<string, string | string[] | undefined | null>,
) {
  if (isSearchParamReader(searchParams)) {
    return (
      (
        searchParams.get("session_id") ??
        searchParams.get("sessionId") ??
        searchParams.get("session")
      )?.trim() || null
    );
  }

  const record = searchParams as Record<
    string,
    string | string[] | undefined | null
  >;
  const raw = record["session_id"] ?? record["sessionId"] ?? record["session"];
  const value = Array.isArray(raw) ? raw[0] : raw;
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : null;
}

export function buildTvDisplayViewModel(state: GameTvSessionState) {
  const question = state.currentQuestion;
  return {
    headline: state.title,
    phase: state.phase,
    questionLabel:
      state.questionTotal > 0
        ? `Question ${state.questionIndex} of ${state.questionTotal}`
        : "Waiting room",
    prompt: question?.prompt ?? "Waiting for the host to open the next round.",
    category: question?.category ?? "Matchday",
    options: question?.options ?? [],
    claimLabel: question?.claim
      ? `${question.claim.playerName} claimed it first`
      : "Waiting for answer",
    leaderboard: state.leaderboard,
  };
}

export function createDemoTvSessionState(): GameTvSessionState {
  return {
    sessionId: "00000000-0000-4000-8000-000000000001",
    clubId: 24,
    title: "Matchday Quiz Display",
    phase: "open",
    questionIndex: 4,
    questionTotal: 20,
    updatedAt: "2026-07-02T12:00:00.000Z",
    currentQuestion: {
      id: "00000000-0000-4000-8000-000000000101",
      order: 4,
      phase: "open",
      prompt:
        "Which season delivered the first league title of the modern era?",
      category: "Club history",
      difficulty: "medium",
      timeLimitSeconds: 20,
      openedAt: "2026-07-02T12:00:00.000Z",
      claim: null,
      options: [
        { key: "a", label: "1995" },
        { key: "b", label: "1998" },
        { key: "c", label: "2002" },
        { key: "d", label: "2004" },
      ],
    },
    leaderboard: [
      { rank: 1, teamName: "East Stand", score: 820 },
      { rank: 2, teamName: "Blue Zone", score: 760 },
      { rank: 3, teamName: "Away Corner", score: 610 },
    ],
  };
}

export function createTvSessionPlaceholder(
  sessionId: string,
): GameTvSessionState {
  return {
    sessionId,
    clubId: 0,
    title: "Matchday display",
    phase: "lobby",
    questionIndex: 0,
    questionTotal: 0,
    updatedAt: "",
    currentQuestion: null,
    leaderboard: [],
  };
}

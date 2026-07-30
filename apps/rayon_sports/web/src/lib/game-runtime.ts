export type GameQuestionPhase =
  | "lobby"
  | "queued"
  | "open"
  | "claimed"
  | "revealed"
  | "closed";

export type GameAction =
  | "get_tv_state"
  | "join_session"
  | "submit_answer"
  | "create_session"
  | "pair_tv_device"
  | "review_question_draft"
  | "list_question_drafts"
  | "publish_question_pack"
  | "list_audit_log"
  | "open_question"
  | "reveal_question"
  | "advance_question"
  | "close_session";

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
  joinCode: string | null;
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
  joinCode: string;
  score: number;
  teamId: string | null;
  teamName: string | null;
};

export type GameCreateSessionResult = {
  sessionId: string;
  joinCode: string;
  title: string;
  status: string;
  questionTotal: number;
  firstSessionQuestionId: string | null;
  tvDeviceId: string | null;
};

export type GamePairTvDeviceResult = {
  tvDeviceId: string;
  deviceLabel: string;
  pairingCode: string;
  sessionId: string | null;
  status: string;
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
  | "pending_review"
  | "approved"
  | "rejected"
  | "needs_changes";

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
      session_id?: string;
      join_code?: string;
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
      join_code?: string;
    }
  | {
      action: "pair_tv_device";
      club_id: number;
      device_label: string;
      pairing_code: string;
      session_id?: string;
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
    };

export type GameRuntimeClientOptions = {
  endpoint?: string;
  draftGenerationEndpoint?: string;
  fetcher?: typeof fetch;
  timeoutMs?: number;
};

export type GameRuntimeFailureKind =
  | "error"
  | "permission_denied"
  | "conflict"
  | "security_timeout";

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
      findTvPayloadLeakKeys(item, [...path, String(index)])
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
    async getTvState(sessionId: string) {
      const state = await postGameAction<GameTvSessionState>(options, {
        action: "get_tv_state",
        session_id: sessionId,
      });
      assertTvPayloadIsSafe(state);
      return state;
    },

    joinSession(input: {
      sessionId?: string;
      joinCode?: string;
      clubId?: number;
      displayName?: string;
    }) {
      return postGameAction<GameJoinSessionResult>(options, {
        action: "join_session",
        session_id: input.sessionId,
        join_code: input.joinCode,
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
      joinCode?: string;
    }) {
      return postGameAction<GameCreateSessionResult>(options, {
        action: "create_session",
        club_id: input.clubId,
        title: input.title,
        pack_id: input.packId,
        tv_device_id: input.tvDeviceId,
        join_code: input.joinCode,
      });
    },

    pairTvDevice(input: {
      clubId: number;
      deviceLabel: string;
      pairingCode: string;
      sessionId?: string;
    }) {
      return postGameAction<GamePairTvDeviceResult>(options, {
        action: "pair_tv_device",
        club_id: input.clubId,
        device_label: input.deviceLabel,
        pairing_code: input.pairingCode,
        session_id: input.sessionId,
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
    }) {
      return postGameAction<GamePublishQuestionPackResult>(options, {
        action: "publish_question_pack",
        club_id: input.clubId,
        title: input.title,
        question_ids: input.questionIds,
        description: input.description,
        template_id: input.templateId,
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
    | SearchParamReader
    | Record<string, string | string[] | undefined | null>,
) {
  if (isSearchParamReader(searchParams)) {
    return (
      searchParams.get("session_id") ??
      searchParams.get("sessionId") ??
      searchParams.get("session")
    )?.trim() || null;
  }

  const record = searchParams as Record<string, string | string[] | undefined | null>;
  const raw =
    record["session_id"] ??
    record["sessionId"] ??
    record["session"];
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
    joinCode: state.joinCode,
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
    joinCode: "RAYON24",
    questionIndex: 4,
    questionTotal: 20,
    updatedAt: "2026-07-02T12:00:00.000Z",
    currentQuestion: {
      id: "00000000-0000-4000-8000-000000000101",
      order: 4,
      phase: "open",
      prompt: "Which season delivered the first league title of the modern era?",
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
    joinCode: null,
    questionIndex: 0,
    questionTotal: 0,
    updatedAt: "",
    currentQuestion: null,
    leaderboard: [],
  };
}

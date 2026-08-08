"use client";

import { useEffect, useMemo, useState } from "react";
import {
  CalendarClock,
  CheckCircle2,
  ClipboardCheck,
  Eye,
  FileText,
  History,
  Pause,
  Play,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  Square,
  StepForward,
} from "lucide-react";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  createGamePackPreviewFingerprint,
  createGameRuntimeClient,
  GameRuntimeRequestError,
  type GameAuditLogRow,
  type GamePlannerOptions,
  type GameQuestionDraftQueueRow,
  type GameQuestionDraftStatus,
  type ManagedGameSession,
  type ManagedGameSessions,
} from "@/lib/game-runtime";
import {
  normalizeAdminGameAudit,
  normalizeAdminGameDrafts,
} from "@/lib/data/admin/games";

type GameControlActionClient = {
  getPlannerOptions(): Promise<GamePlannerOptions>;
  getManagedSessions(): Promise<ManagedGameSessions>;
  createManagedSession(input: {
    packId: string;
    scheduledStartAt: string;
    eligibilityScope: "club_membership" | "home_owner" | "venue";
    displayIds: string[];
    organizerUserIds: string[];
    idempotencyKey: string;
  }): Promise<ManagedGameSession>;
  transitionManagedSession(input: {
    sessionId: string;
    requestedPhase: string;
    expectedSessionVersion: number;
    idempotencyKey: string;
    sessionQuestionId?: string;
    phaseDeadline?: string;
    reason?: string;
  }): Promise<ManagedGameSession>;
  reviewQuestionDraft(input: {
    clubId: number;
    draftId: string;
    decision: "approved" | "rejected" | "needs_changes";
    notes?: string;
  }): Promise<{
    draftId: string;
    decision: string;
    questionId: string | null;
  }>;
  listQuestionDrafts(input: {
    clubId: number;
    status?: GameQuestionDraftStatus;
    search?: string;
    limit?: number;
    offset?: number;
  }): Promise<GameQuestionDraftQueueRow[]>;
  publishQuestionPack(input: {
    clubId: number;
    title: string;
    questionIds: string[];
    description?: string;
    previewFingerprint: string;
  }): Promise<{
    packId: string;
    title: string;
    status: string;
    questionCount: number;
  }>;
  listAuditLog(input: {
    clubId: number;
    limit?: number;
    offset?: number;
    actionFilter?: string;
    entityType?: string;
  }): Promise<GameAuditLogRow[]>;
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
  }): Promise<{
    sourceId: string;
    draftIds: string[];
    mode: "ai_assisted" | "manual_import";
    count: number;
  }>;
};

const PAGE_SIZE = 25;
const EMPTY_DRAFTS: GameQuestionDraftQueueRow[] = [];
const EMPTY_AUDIT: GameAuditLogRow[] = [];
const EMPTY_SESSIONS: ManagedGameSessions = {
  clubId: 0,
  serverTime: "",
  canPlan: false,
  sessions: [],
};

type Workspace = "content" | "planner" | "live";
type PendingAction =
  | "options"
  | "sessions"
  | "create"
  | "transition"
  | "generate"
  | "drafts"
  | "review"
  | "preview"
  | "publish"
  | "audit"
  | null;

type GamesControlClientProps = {
  defaultClubId: number;
  actionClient?: GameControlActionClient;
  initialDraftRows?: GameQuestionDraftQueueRow[];
  initialAuditRows?: GameAuditLogRow[];
  onSelectionChange?: (selected: boolean) => void;
};

function draftApprovalChecksPass(draft: GameQuestionDraftQueueRow) {
  return Object.entries(draft.qaChecks).every(
    ([checkName, passed]) => checkName === "sourceTrusted" || passed,
  );
}

function createOperationKey(scope: string) {
  const random =
    typeof crypto !== "undefined" && typeof crypto.randomUUID === "function"
      ? crypto.randomUUID()
      : `${Date.now()}-${Math.random().toString(36).slice(2)}`;
  return `${scope}-${random}`.slice(0, 96);
}

function eligibilityLabel(value: string) {
  switch (value) {
    case "club_membership":
      return "Active club members";
    case "home_owner":
      return "Registered home-display owners";
    case "venue":
      return "Selected venue audience";
    default:
      return value.replaceAll("_", " ");
  }
}

function phaseLabel(value: string) {
  switch (value) {
    case "activated_lobby":
      return "Open lobby";
    case "question_open":
      return "Open question";
    case "reveal":
      return "Reveal answer";
    case "paused":
      return "Pause session";
    case "completed":
      return "Complete session";
    case "cancelled":
      return "Cancel session";
    default:
      return value.replaceAll("_", " ");
  }
}

function primaryTransition(session: ManagedGameSession) {
  const preferred: Record<string, string> = {
    scheduled: "activated_lobby",
    activated_lobby: "question_open",
    question_open: "reveal",
    reveal: "question_open",
  };
  const candidate = preferred[session.phase];
  if (candidate && session.allowedActions.includes(candidate)) return candidate;
  return (
    session.allowedActions.find(
      (action) =>
        action !== "paused" && action !== "completed" && action !== "cancelled",
    ) ?? null
  );
}

function transitionQuestion(
  session: ManagedGameSession,
  requestedPhase: string,
) {
  if (requestedPhase !== "question_open") return undefined;
  if (session.phase === "activated_lobby" || session.currentQuestion == null) {
    return session.questions[0]?.id;
  }
  if (session.phase === "reveal") {
    return session.questions.find(
      (question) => question.ordinal > session.currentQuestion!.ordinal,
    )?.id;
  }
  return session.currentQuestion.id;
}

function authoritativeLatencyLabel(session: ManagedGameSession) {
  if (!session.lastEventAt) return "No event yet";
  const serverTime = Date.parse(session.serverTime);
  const lastEventAt = Date.parse(session.lastEventAt);
  if (!Number.isFinite(serverTime) || !Number.isFinite(lastEventAt)) {
    return "Latency unavailable";
  }
  const seconds = Math.max(0, Math.round((serverTime - lastEventAt) / 1000));
  if (seconds < 5) return "Under 5 seconds";
  if (seconds <= 30) return "5–30 seconds";
  if (seconds <= 120) return "31–120 seconds";
  return "Over 2 minutes";
}

export function GamesControlClient({
  defaultClubId,
  actionClient,
  initialDraftRows = EMPTY_DRAFTS,
  initialAuditRows = EMPTY_AUDIT,
  onSelectionChange,
}: GamesControlClientProps) {
  const defaultClient = useMemo(() => createGameRuntimeClient({}), []);
  const client = actionClient ?? defaultClient;

  const [workspace, setWorkspace] = useState<Workspace>("planner");
  const [pendingAction, setPendingAction] = useState<PendingAction>(null);
  const [status, setStatus] = useState(
    "Load authorized choices to plan or control a club game.",
  );

  const [plannerOptions, setPlannerOptions] =
    useState<GamePlannerOptions | null>(null);
  const [selectedPackId, setSelectedPackId] = useState("");
  const [scheduledStartAt, setScheduledStartAt] = useState("");
  const [eligibilityScope, setEligibilityScope] = useState<
    "club_membership" | "home_owner" | "venue"
  >("club_membership");
  const [selectedDisplayIds, setSelectedDisplayIds] = useState<string[]>([]);
  const [selectedOrganizerUserIds, setSelectedOrganizerUserIds] = useState<
    string[]
  >([]);
  const [planReviewed, setPlanReviewed] = useState(false);

  const [managedSessions, setManagedSessions] =
    useState<ManagedGameSessions>(EMPTY_SESSIONS);
  const [selectedSessionId, setSelectedSessionId] = useState("");
  const [pendingTransitionPhase, setPendingTransitionPhase] = useState("");
  const [questionDurationSeconds, setQuestionDurationSeconds] = useState(20);
  const [networkOnline, setNetworkOnline] = useState(true);
  const [reconnectRefreshRequired, setReconnectRefreshRequired] =
    useState(false);

  const [sourceTitle, setSourceTitle] = useState("Rayon matchday source");
  const [sourceFact, setSourceFact] = useState("");
  const [sourceUrl, setSourceUrl] = useState("");
  const [sourceDate, setSourceDate] = useState("");
  const [draftCount, setDraftCount] = useState("5");
  const [draftRows, setDraftRows] =
    useState<GameQuestionDraftQueueRow[]>(initialDraftRows);
  const [draftOffset, setDraftOffset] = useState(0);
  const [draftStatusFilter, setDraftStatusFilter] = useState<
    GameQuestionDraftStatus | ""
  >("pending_review");
  const [draftSearch, setDraftSearch] = useState("");
  const [selectedDraftId, setSelectedDraftId] = useState(
    initialDraftRows[0]?.id ?? "",
  );
  const [reviewDecision, setReviewDecision] = useState<
    "approved" | "rejected" | "needs_changes"
  >("approved");
  const [reviewNotes, setReviewNotes] = useState("");
  const [packTitle, setPackTitle] = useState("Rayon 20-question round");
  const [packDescription, setPackDescription] = useState("");
  const [selectedQuestionIds, setSelectedQuestionIds] = useState<string[]>([]);
  const [packPreviewFingerprint, setPackPreviewFingerprint] = useState("");

  const [auditRows, setAuditRows] =
    useState<GameAuditLogRow[]>(initialAuditRows);
  const [auditOffset, setAuditOffset] = useState(0);
  const [auditActionFilter, setAuditActionFilter] = useState("");
  const [auditEntityType, setAuditEntityType] = useState("");
  const [selectedAuditId, setSelectedAuditId] = useState(
    initialAuditRows[0]?.id ?? "",
  );

  useEffect(() => {
    setDraftRows(initialDraftRows);
    setSelectedDraftId(initialDraftRows[0]?.id ?? "");
  }, [initialDraftRows]);

  useEffect(() => {
    setAuditRows(initialAuditRows);
    setSelectedAuditId(initialAuditRows[0]?.id ?? "");
  }, [initialAuditRows]);

  useEffect(() => {
    function markOffline() {
      setNetworkOnline(false);
      setReconnectRefreshRequired(true);
    }
    function markOnline() {
      setNetworkOnline(true);
    }
    setNetworkOnline(window.navigator.onLine);
    if (!window.navigator.onLine) setReconnectRefreshRequired(true);
    window.addEventListener("offline", markOffline);
    window.addEventListener("online", markOnline);
    return () => {
      window.removeEventListener("offline", markOffline);
      window.removeEventListener("online", markOnline);
    };
  }, []);

  const selectedPack = plannerOptions?.packs.find(
    (pack) => pack.id === selectedPackId,
  );
  const selectedSession =
    managedSessions.sessions.find(
      (session) => session.id === selectedSessionId,
    ) ??
    managedSessions.sessions[0] ??
    null;
  const selectedDraft =
    draftRows.find((draft) => draft.id === selectedDraftId) ?? null;
  const selectedDraftApprovalReady = selectedDraft
    ? draftApprovalChecksPass(selectedDraft)
    : false;
  const selectedPackQuestions = useMemo(
    () =>
      selectedQuestionIds
        .map((questionId) =>
          plannerOptions?.questions.find(
            (question) => question.id === questionId,
          ),
        )
        .filter(
          (
            question,
          ): question is NonNullable<
            GamePlannerOptions["questions"][number]
          > => question != null,
        ),
    [plannerOptions?.questions, selectedQuestionIds],
  );
  const packQa = useMemo(
    () => ({
      exactCount:
        selectedQuestionIds.length === 20 &&
        selectedPackQuestions.length === 20,
      uniqueQuestions: new Set(selectedQuestionIds).size === 20,
      sourceEvidenceComplete:
        selectedPackQuestions.length === 20 &&
        selectedPackQuestions.every(
          (question) =>
            Boolean(question.sourceTitle) &&
            Boolean(question.sourceTrustTier),
        ),
      approvalProvenanceComplete:
        selectedPackQuestions.length === 20 &&
        selectedPackQuestions.every((question) =>
          Boolean(question.approvedAt),
        ),
    }),
    [selectedPackQuestions, selectedQuestionIds],
  );
  const packQaPass =
    packQa.exactCount &&
    packQa.uniqueQuestions &&
    packQa.sourceEvidenceComplete &&
    packQa.approvalProvenanceComplete;
  const selectedAudit =
    auditRows.find((row) => row.id === selectedAuditId) ?? auditRows[0] ?? null;
  const nextTransition = selectedSession
    ? primaryTransition(selectedSession)
    : null;
  const nextQuestion = selectedSession
    ? transitionQuestion(selectedSession, pendingTransitionPhase)
    : undefined;
  const scopedDisplayRequired =
    eligibilityScope === "home_owner" || eligibilityScope === "venue";
  const planIsComplete =
    selectedPack != null &&
    Number.isFinite(Date.parse(scheduledStartAt)) &&
    (!scopedDisplayRequired || selectedDisplayIds.length > 0);

  function controlledFailure(error: unknown, fallback: string) {
    if (error instanceof GameRuntimeRequestError) {
      switch (error.kind) {
        case "permission_denied":
          return "Game operation access was denied.";
        case "conflict":
          return "Game operations changed. Reload the current session before retrying.";
        case "security_timeout":
          return "The operation timed out without a confirmed change.";
        default:
          return fallback;
      }
    }
    return fallback;
  }

  function updatePlan(mutator: () => void) {
    mutator();
    setPlanReviewed(false);
  }

  async function loadPlannerOptions() {
    setPendingAction("options");
    setStatus("Loading authorized packs, questions, and displays...");
    try {
      const result = await client.getPlannerOptions();
      setPlannerOptions(result);
      setSelectedPackId((current) =>
        result.packs.some((pack) => pack.id === current)
          ? current
          : (result.packs[0]?.id ?? ""),
      );
      setSelectedQuestionIds((current) =>
        current.filter((id) =>
          result.questions.some((question) => question.id === id),
        ),
      );
      setSelectedDisplayIds((current) =>
        current.filter((id) =>
          result.displays.some((display) => display.id === id),
        ),
      );
      setSelectedOrganizerUserIds((current) =>
        current.filter((id) =>
          result.organizers.some((organizer) => organizer.userId === id),
        ),
      );
      setPlanReviewed(false);
      setStatus(
        `Loaded ${result.packs.length} published pack(s), ${result.questions.length} approved question(s), ${result.displays.length} authorized display(s), and ${result.organizers.length} assignable organizer(s).`,
      );
    } catch (error) {
      setStatus(controlledFailure(error, "Could not load authorized choices."));
    } finally {
      setPendingAction(null);
    }
  }

  async function createPlannedSession() {
    if (!planIsComplete || !planReviewed || selectedPack == null) {
      setStatus("Review a complete session plan before creating it.");
      return;
    }
    setPendingAction("create");
    setStatus("Creating the reviewed session plan...");
    try {
      const created = await client.createManagedSession({
        packId: selectedPack.id,
        scheduledStartAt: new Date(scheduledStartAt).toISOString(),
        eligibilityScope,
        displayIds: selectedDisplayIds,
        organizerUserIds: selectedOrganizerUserIds,
        idempotencyKey: createOperationKey("session-create"),
      });
      setManagedSessions((current) => ({
        clubId: created.clubId,
        serverTime: created.serverTime,
        canPlan: true,
        sessions: [
          created,
          ...current.sessions.filter((session) => session.id !== created.id),
        ],
      }));
      setSelectedSessionId(created.id);
      setPlanReviewed(false);
      setWorkspace("live");
      setStatus(
        `Session “${created.title}” created in ${phaseLabel(created.phase)}.`,
      );
    } catch (error) {
      setStatus(
        controlledFailure(error, "Could not create the planned session."),
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function loadManagedSessions() {
    setPendingAction("sessions");
    setStatus("Loading the current authorized session roster...");
    try {
      const result = await client.getManagedSessions();
      setManagedSessions(result);
      setSelectedSessionId((current) =>
        result.sessions.some((session) => session.id === current)
          ? current
          : (result.sessions[0]?.id ?? ""),
      );
      setPendingTransitionPhase("");
      setReconnectRefreshRequired(false);
      setStatus(`Loaded ${result.sessions.length} managed session(s).`);
    } catch (error) {
      setStatus(controlledFailure(error, "Could not load managed sessions."));
    } finally {
      setPendingAction(null);
    }
  }

  function stageTransition(phase: string) {
    if (!selectedSession || !selectedSession.allowedActions.includes(phase)) {
      setStatus("That action is no longer authorized for this session.");
      return;
    }
    if (
      phase === "question_open" &&
      transitionQuestion(selectedSession, phase) == null
    ) {
      setStatus("No next approved question is available for this session.");
      return;
    }
    setPendingTransitionPhase(phase);
    setStatus(`Review ${phaseLabel(phase).toLowerCase()} before confirming.`);
  }

  async function confirmTransition() {
    if (
      !selectedSession ||
      !pendingTransitionPhase ||
      !selectedSession.allowedActions.includes(pendingTransitionPhase)
    ) {
      setStatus("Reload the session before confirming this action.");
      return;
    }

    if (
      (pendingTransitionPhase === "cancelled" ||
        pendingTransitionPhase === "completed") &&
      !confirmAdminDestructiveAction({
        action: pendingTransitionPhase === "cancelled" ? "Cancel" : "Complete",
        subject: selectedSession.title,
        scope: `Club ${selectedSession.clubId}; session version ${selectedSession.sessionVersion}`,
        impact:
          pendingTransitionPhase === "cancelled"
            ? "The game will stop and cannot return to live play."
            : "The game will close with the current participant results.",
        undo: "manual_recovery",
      })
    ) {
      return;
    }

    const sessionQuestionId = transitionQuestion(
      selectedSession,
      pendingTransitionPhase,
    );
    const phaseDeadline =
      pendingTransitionPhase === "question_open"
        ? new Date(Date.now() + questionDurationSeconds * 1000).toISOString()
        : undefined;

    setPendingAction("transition");
    setStatus(
      `Confirming ${phaseLabel(pendingTransitionPhase).toLowerCase()}...`,
    );
    try {
      const updated = await client.transitionManagedSession({
        sessionId: selectedSession.id,
        requestedPhase: pendingTransitionPhase,
        expectedSessionVersion: selectedSession.sessionVersion,
        idempotencyKey: createOperationKey("session-transition"),
        sessionQuestionId,
        phaseDeadline,
        reason:
          pendingTransitionPhase === "cancelled"
            ? "Cancelled from task-oriented game control"
            : undefined,
      });
      setManagedSessions((current) => ({
        ...current,
        serverTime: updated.serverTime,
        sessions: current.sessions.map((session) =>
          session.id === updated.id ? updated : session,
        ),
      }));
      setPendingTransitionPhase("");
      setStatus(
        `Session updated to ${phaseLabel(updated.phase)} at version ${updated.sessionVersion}.`,
      );
    } catch (error) {
      setStatus(controlledFailure(error, "Could not update the session."));
    } finally {
      setPendingAction(null);
    }
  }

  async function generateDrafts() {
    const count = Number.parseInt(draftCount, 10);
    if (
      !sourceTitle.trim() ||
      !sourceFact.trim() ||
      !Number.isSafeInteger(count) ||
      count < 1 ||
      count > 10
    ) {
      setStatus("Add a verified source fact and choose 1–10 drafts.");
      return;
    }
    setPendingAction("generate");
    setStatus("Generating review-gated question drafts...");
    try {
      const result = await client.generateQuestionDrafts({
        clubId: defaultClubId,
        sourceTitle: sourceTitle.trim(),
        extractedFact: sourceFact.trim(),
        sourceUrl: sourceUrl.trim() || undefined,
        sourceDate: sourceDate || undefined,
        trustTier: "review_required",
        count,
        language: "en",
        category: "club_knowledge",
      });
      setStatus(
        `Generated ${result.count} draft question(s). Load the review queue to inspect them.`,
      );
    } catch (error) {
      setStatus(
        controlledFailure(error, "Could not generate draft questions."),
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function loadDrafts(nextOffset = draftOffset) {
    setPendingAction("drafts");
    setStatus("Loading the bounded question review queue...");
    try {
      const rows = normalizeAdminGameDrafts(
        await client.listQuestionDrafts({
          clubId: defaultClubId,
          status: draftStatusFilter || undefined,
          search: draftSearch.trim() || undefined,
          limit: PAGE_SIZE,
          offset: nextOffset,
        }),
      );
      setDraftRows(rows);
      setDraftOffset(nextOffset);
      setSelectedDraftId(rows[0]?.id ?? "");
      setStatus(`Loaded ${rows.length} draft row(s) from ${nextOffset + 1}.`);
    } catch (error) {
      setStatus(controlledFailure(error, "Could not load question drafts."));
    } finally {
      setPendingAction(null);
    }
  }

  async function reviewDraft() {
    if (!selectedDraft) {
      setStatus("Select a draft card before recording a review.");
      return;
    }
    if (reviewDecision === "approved" && !selectedDraftApprovalReady) {
      setStatus(
        "Approval is blocked until every required deterministic check passes.",
      );
      return;
    }
    setPendingAction("review");
    setStatus("Recording the human review decision...");
    try {
      const result = await client.reviewQuestionDraft({
        clubId: defaultClubId,
        draftId: selectedDraft.id,
        decision: reviewDecision,
        notes: reviewNotes.trim() || undefined,
      });
      setStatus(
        result.questionId
          ? `Draft approved and added to the approved question library.`
          : `Draft marked ${phaseLabel(result.decision)}.`,
      );
      await loadPlannerOptions();
    } catch (error) {
      setStatus(
        controlledFailure(error, "Could not review the selected draft."),
      );
    } finally {
      setPendingAction(null);
    }
  }

  function toggleQuestion(questionId: string) {
    setPackPreviewFingerprint("");
    setSelectedQuestionIds((current) => {
      if (current.includes(questionId)) {
        return current.filter((id) => id !== questionId);
      }
      return current.length < 20 ? [...current, questionId] : current;
    });
  }

  async function reviewPackPreviews() {
    if (!packTitle.trim() || !packQaPass) {
      setStatus(
        "Resolve every deterministic QA check before reviewing publication previews.",
      );
      return;
    }
    setPendingAction("preview");
    setStatus("Locking the reviewed mobile and TV publication previews...");
    try {
      const fingerprint = await createGamePackPreviewFingerprint({
        title: packTitle,
        description: packDescription,
        questionIds: selectedQuestionIds,
      });
      setPackPreviewFingerprint(fingerprint);
      setStatus(
        "Mobile and TV previews reviewed. Publication is unlocked for this exact pack order.",
      );
    } catch (error) {
      setStatus(
        controlledFailure(error, "Could not lock the publication previews."),
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function publishPack() {
    if (
      !packTitle.trim() ||
      !packQaPass ||
      !packPreviewFingerprint
    ) {
      setStatus(
        "Pass deterministic QA and review the exact mobile and TV previews before publishing.",
      );
      return;
    }
    setPendingAction("publish");
    setStatus("Publishing the reviewed 20-question pack...");
    try {
      const result = await client.publishQuestionPack({
        clubId: defaultClubId,
        title: packTitle.trim(),
        description: packDescription.trim() || undefined,
        questionIds: selectedQuestionIds,
        previewFingerprint: packPreviewFingerprint,
      });
      setSelectedQuestionIds([]);
      setPackPreviewFingerprint("");
      setStatus(
        `Pack published: ${result.title} (${result.questionCount} questions).`,
      );
      await loadPlannerOptions();
    } catch (error) {
      setStatus(
        controlledFailure(error, "Could not publish the question pack."),
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function loadAudit(nextOffset = auditOffset) {
    setPendingAction("audit");
    setStatus("Loading privacy-filtered game audit rows...");
    try {
      const rows = normalizeAdminGameAudit(
        await client.listAuditLog({
          clubId: defaultClubId,
          limit: PAGE_SIZE,
          offset: nextOffset,
          actionFilter: auditActionFilter.trim() || undefined,
          entityType: auditEntityType.trim() || undefined,
        }),
      );
      setAuditRows(rows);
      setAuditOffset(nextOffset);
      setSelectedAuditId(rows[0]?.id ?? "");
      setStatus(`Loaded ${rows.length} audit row(s) from ${nextOffset + 1}.`);
    } catch (error) {
      setStatus(controlledFailure(error, "Could not load audit rows."));
    } finally {
      setPendingAction(null);
    }
  }

  return (
    <section className="rounded-lg border border-[var(--admin-border)] bg-[var(--admin-surface)] p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="admin-page-eyebrow">Football game operations</p>
          <h2 className="text-base font-semibold text-[var(--admin-text)]">
            Content, planning, and live control
          </h2>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-[var(--admin-muted)]">
            Work with approved club content and authorized names. Technical
            identifiers stay inside the versioned game runtime.
          </p>
        </div>
        <div className="inline-flex items-center gap-2 rounded-md border border-emerald-500/30 bg-emerald-500/10 px-3 py-2 text-sm font-semibold text-[var(--admin-text-strong)]">
          <ShieldCheck className="h-4 w-4" aria-hidden="true" />
          Club {defaultClubId} · role scoped
        </div>
      </div>

      <div
        role="tablist"
        aria-label="Game operations workspaces"
        className="mt-5 grid gap-2 sm:grid-cols-3"
      >
        {(
          [
            ["content", "Content Studio", FileText],
            ["planner", "Session Planner", CalendarClock],
            ["live", "Live Control", Play],
          ] as const
        ).map(([value, label, Icon]) => (
          <button
            key={value}
            type="button"
            role="tab"
            aria-selected={workspace === value}
            onClick={() => setWorkspace(value)}
            className={`admin-button justify-center ${
              workspace === value
                ? "admin-button-primary"
                : "admin-button-secondary"
            }`}
          >
            <Icon className="h-4 w-4" aria-hidden="true" />
            {label}
          </button>
        ))}
      </div>

      {workspace === "planner" ? (
        <section className="mt-6" aria-labelledby="session-planner-title">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h3
                id="session-planner-title"
                className="text-sm font-semibold text-[var(--admin-text)]"
              >
                Session Planner
              </h3>
              <p className="mt-1 text-sm text-[var(--admin-muted)]">
                Choose a published 20-question pack, audience, start time, and
                authorized displays.
              </p>
            </div>
            <button
              type="button"
              onClick={() => void loadPlannerOptions()}
              disabled={pendingAction != null}
              className="admin-button admin-button-secondary disabled:opacity-60"
            >
              <RefreshCw className="h-4 w-4" aria-hidden="true" />
              {pendingAction === "options"
                ? "Loading choices..."
                : "Load authorized choices"}
            </button>
          </div>

          {plannerOptions == null ? (
            <p className="mt-5 rounded-md border border-dashed border-[var(--admin-border)] p-4 text-sm text-[var(--admin-muted)]">
              Load authorized choices to begin. No technical identifiers are
              required.
            </p>
          ) : (
            <>
              <div className="mt-5 grid gap-4 lg:grid-cols-2">
                <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                  Published question pack
                  <select
                    value={selectedPackId}
                    onChange={(event) =>
                      updatePlan(() => setSelectedPackId(event.target.value))
                    }
                    className="admin-input"
                    aria-label="Published question pack"
                  >
                    <option value="">Choose a published pack</option>
                    {plannerOptions.packs.map((pack) => (
                      <option key={pack.id} value={pack.id}>
                        {pack.title} · {pack.questionCount} questions
                      </option>
                    ))}
                  </select>
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                  Scheduled start
                  <input
                    type="datetime-local"
                    value={scheduledStartAt}
                    onChange={(event) =>
                      updatePlan(() => setScheduledStartAt(event.target.value))
                    }
                    className="admin-input"
                    aria-label="Scheduled start"
                  />
                </label>
                <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                  Eligible audience
                  <select
                    value={eligibilityScope}
                    onChange={(event) =>
                      updatePlan(() =>
                        setEligibilityScope(
                          event.target.value as
                            "club_membership" | "home_owner" | "venue",
                        ),
                      )
                    }
                    className="admin-input"
                    aria-label="Eligible audience"
                  >
                    {plannerOptions.allowedEligibilityScopes.map((scope) => (
                      <option key={scope} value={scope}>
                        {eligibilityLabel(scope)}
                      </option>
                    ))}
                  </select>
                </label>
                <div className="rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-4">
                  <p className="text-sm font-semibold text-[var(--admin-text)]">
                    Club context
                  </p>
                  <p className="mt-1 text-sm text-[var(--admin-muted)]">
                    Club {plannerOptions.clubId}, confirmed by the signed-in
                    role. This cannot be edited here.
                  </p>
                </div>
              </div>

              <fieldset className="mt-5">
                <legend className="text-sm font-semibold text-[var(--admin-text)]">
                  Authorized displays
                </legend>
                <p className="mt-1 text-sm text-[var(--admin-muted)]">
                  Venue and home-audience sessions require at least one display.
                </p>
                <div className="mt-3 grid gap-3 md:grid-cols-2">
                  {plannerOptions.displays.length === 0 ? (
                    <p className="text-sm text-[var(--admin-muted)]">
                      No paired displays are available to this role.
                    </p>
                  ) : (
                    plannerOptions.displays.map((display) => (
                      <label
                        key={display.id}
                        className="flex items-start gap-3 rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-3"
                      >
                        <input
                          type="checkbox"
                          checked={selectedDisplayIds.includes(display.id)}
                          onChange={() =>
                            updatePlan(() =>
                              setSelectedDisplayIds((current) =>
                                current.includes(display.id)
                                  ? current.filter((id) => id !== display.id)
                                  : [...current, display.id],
                              ),
                            )
                          }
                          aria-label={`Use ${display.name}`}
                        />
                        <span>
                          <span className="block text-sm font-semibold text-[var(--admin-text)]">
                            {display.name}
                          </span>
                          <span className="mt-1 block text-xs text-[var(--admin-muted)]">
                            {display.scopeType} · {display.health}
                            {display.assignedSessionId
                              ? " · assigned to another active session"
                              : ""}
                          </span>
                        </span>
                      </label>
                    ))
                  )}
                </div>
              </fieldset>

              <fieldset className="mt-5">
                <legend className="text-sm font-semibold text-[var(--admin-text)]">
                  Additional organizers
                </legend>
                <p className="mt-1 text-sm text-[var(--admin-muted)]">
                  The creator remains assigned. Club admins may add approved
                  organizers by name.
                </p>
                <div className="mt-3 grid gap-3 md:grid-cols-2">
                  {plannerOptions.organizers.length === 0 ? (
                    <p className="text-sm text-[var(--admin-muted)]">
                      No additional organizer profiles are available to this
                      role.
                    </p>
                  ) : (
                    plannerOptions.organizers.map((organizer) => (
                      <label
                        key={`${organizer.userId}-${organizer.venueId ?? "club"}`}
                        className="flex items-start gap-3 rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-3"
                      >
                        <input
                          type="checkbox"
                          checked={selectedOrganizerUserIds.includes(
                            organizer.userId,
                          )}
                          onChange={() =>
                            updatePlan(() =>
                              setSelectedOrganizerUserIds((current) =>
                                current.includes(organizer.userId)
                                  ? current.filter(
                                      (id) => id !== organizer.userId,
                                    )
                                  : [...current, organizer.userId],
                              ),
                            )
                          }
                          aria-label={`Assign ${organizer.name}`}
                        />
                        <span>
                          <span className="block text-sm font-semibold text-[var(--admin-text)]">
                            {organizer.name}
                          </span>
                          <span className="mt-1 block text-xs text-[var(--admin-muted)]">
                            {organizer.venueId
                              ? "Venue-scoped game organizer"
                              : "Club-wide game organizer"}
                          </span>
                        </span>
                      </label>
                    ))
                  )}
                </div>
              </fieldset>

              <div className="mt-5 flex flex-wrap gap-3">
                <button
                  type="button"
                  onClick={() => {
                    if (!planIsComplete) {
                      setStatus(
                        "Choose a pack, valid start time, and required displays first.",
                      );
                      return;
                    }
                    setPlanReviewed(true);
                    setStatus("Session plan ready for final confirmation.");
                  }}
                  disabled={pendingAction != null}
                  className="admin-button admin-button-secondary disabled:opacity-60"
                >
                  <Eye className="h-4 w-4" aria-hidden="true" />
                  Review session plan
                </button>
                <button
                  type="button"
                  onClick={() => void createPlannedSession()}
                  disabled={
                    !planReviewed || !planIsComplete || pendingAction != null
                  }
                  className="admin-button admin-button-primary disabled:opacity-60"
                >
                  <CheckCircle2 className="h-4 w-4" aria-hidden="true" />
                  {pendingAction === "create"
                    ? "Creating session..."
                    : "Confirm and create session"}
                </button>
              </div>

              {planReviewed && selectedPack ? (
                <article className="mt-4 rounded-md border border-emerald-500/30 bg-emerald-500/10 p-4">
                  <p className="text-sm font-semibold text-[var(--admin-text)]">
                    Reviewed plan
                  </p>
                  <dl className="mt-3 grid gap-3 text-sm text-[var(--admin-muted)] md:grid-cols-2">
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Pack
                      </dt>
                      <dd>{selectedPack.title} · 20 questions</dd>
                    </div>
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Audience
                      </dt>
                      <dd>{eligibilityLabel(eligibilityScope)}</dd>
                    </div>
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Start
                      </dt>
                      <dd>{new Date(scheduledStartAt).toLocaleString()}</dd>
                    </div>
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Displays
                      </dt>
                      <dd>
                        {selectedDisplayIds.length === 0
                          ? "No display assignment"
                          : `${selectedDisplayIds.length} selected`}
                      </dd>
                    </div>
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Additional organizers
                      </dt>
                      <dd>
                        {selectedOrganizerUserIds.length === 0
                          ? "Creator only"
                          : `${selectedOrganizerUserIds.length} selected`}
                      </dd>
                    </div>
                  </dl>
                </article>
              ) : null}
            </>
          )}
        </section>
      ) : null}

      {workspace === "live" ? (
        <section className="mt-6" aria-labelledby="live-control-title">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div>
              <h3
                id="live-control-title"
                className="text-sm font-semibold text-[var(--admin-text)]"
              >
                Live Control
              </h3>
              <p className="mt-1 text-sm text-[var(--admin-muted)]">
                Select a named session, review its current version, then stage
                one allowed transition.
              </p>
            </div>
            <button
              type="button"
              onClick={() => void loadManagedSessions()}
              disabled={pendingAction != null || !networkOnline}
              className="admin-button admin-button-secondary disabled:opacity-60"
            >
              <RefreshCw className="h-4 w-4" aria-hidden="true" />
              {pendingAction === "sessions"
                ? "Loading sessions..."
                : reconnectRefreshRequired
                  ? "Reconnect and refresh"
                  : "Load managed sessions"}
            </button>
          </div>

          <div
            className="mt-4 grid gap-3 rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-4 text-sm md:grid-cols-2"
            data-testid="live-connection-health"
          >
            <div>
              <p className="font-semibold text-[var(--admin-text)]">
                Reconnect health
              </p>
              <p className="mt-1 text-[var(--admin-muted)]">
                {!networkOnline
                  ? "Offline — confirmed state is retained and actions are locked."
                  : reconnectRefreshRequired
                    ? "Connection restored — refresh authoritative state before acting."
                    : "Connected — authoritative state is current."}
              </p>
            </div>
            <div>
              <p className="font-semibold text-[var(--admin-text)]">
                Last authoritative refresh
              </p>
              <p className="mt-1 text-[var(--admin-muted)]">
                {managedSessions.serverTime
                  ? new Date(managedSessions.serverTime).toLocaleString()
                  : "Not refreshed yet"}
              </p>
            </div>
          </div>

          {managedSessions.sessions.length === 0 ? (
            <p className="mt-5 rounded-md border border-dashed border-[var(--admin-border)] p-4 text-sm text-[var(--admin-muted)]">
              No managed sessions are loaded. Create a reviewed plan or refresh
              the session roster.
            </p>
          ) : (
            <>
              <label className="mt-5 grid gap-2 text-sm text-[var(--admin-muted)]">
                Managed session
                <select
                  value={selectedSession?.id ?? ""}
                  onChange={(event) => {
                    setSelectedSessionId(event.target.value);
                    setPendingTransitionPhase("");
                  }}
                  className="admin-input"
                  aria-label="Managed session"
                >
                  {managedSessions.sessions.map((session) => (
                    <option key={session.id} value={session.id}>
                      {session.title} · {phaseLabel(session.phase)}
                    </option>
                  ))}
                </select>
              </label>

              {selectedSession ? (
                <>
                  <article className="mt-4 rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-4">
                    <div className="flex flex-wrap items-start justify-between gap-3">
                      <div>
                        <h4 className="text-base font-semibold text-[var(--admin-text)]">
                          {selectedSession.title}
                        </h4>
                        <p className="mt-1 text-sm text-[var(--admin-muted)]">
                          {selectedSession.packTitle ?? "No pack title"} ·{" "}
                          {eligibilityLabel(selectedSession.eligibilityScope)}
                        </p>
                      </div>
                      <span className="admin-meta-chip">
                        {phaseLabel(selectedSession.phase)} · version{" "}
                        {selectedSession.sessionVersion}
                      </span>
                    </div>
                    <dl className="mt-4 grid gap-3 text-sm text-[var(--admin-muted)] md:grid-cols-3">
                      <div>
                        <dt className="font-semibold text-[var(--admin-text)]">
                          Participants
                        </dt>
                        <dd>{selectedSession.participantCount}</dd>
                      </div>
                      <div>
                        <dt className="font-semibold text-[var(--admin-text)]">
                          Displays
                        </dt>
                        <dd>
                          {selectedSession.assignedDisplays.length === 0
                            ? "None assigned"
                            : selectedSession.assignedDisplays
                                .map(
                                  (display) =>
                                    `${display.name} (${display.health})`,
                                )
                                .join(", ")}
                        </dd>
                      </div>
                      <div>
                        <dt className="font-semibold text-[var(--admin-text)]">
                          Organizers
                        </dt>
                        <dd>
                          {selectedSession.assignedOrganizers.length === 0
                            ? "No organizer assigned"
                            : selectedSession.assignedOrganizers
                                .map((organizer) => organizer.name)
                                .join(", ")}
                        </dd>
                      </div>
                      <div>
                        <dt className="font-semibold text-[var(--admin-text)]">
                          Last update
                        </dt>
                        <dd>
                          {selectedSession.lastEventAt
                            ? new Date(
                                selectedSession.lastEventAt,
                              ).toLocaleString()
                            : "No event yet"}
                        </dd>
                      </div>
                      <div>
                        <dt className="font-semibold text-[var(--admin-text)]">
                          Authoritative latency
                        </dt>
                        <dd>{authoritativeLatencyLabel(selectedSession)}</dd>
                      </div>
                    </dl>
                    <div className="mt-4 rounded-md border border-[var(--admin-border)] p-3">
                      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-muted)]">
                        Current question
                      </p>
                      <p className="mt-1 text-sm font-semibold text-[var(--admin-text)]">
                        {selectedSession.currentQuestion
                          ? `${selectedSession.currentQuestion.ordinal}. ${selectedSession.currentQuestion.prompt}`
                          : "Lobby — no question open"}
                      </p>
                    </div>
                    <div className="mt-4 grid gap-3 md:grid-cols-2">
                      <section
                        className="rounded-md border border-[var(--admin-border)] p-3"
                        aria-label="Participant projection preview"
                      >
                        <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-muted)]">
                          Participant preview
                        </p>
                        {selectedSession.projectionPreviews ? (
                          <dl className="mt-2 grid gap-2 text-sm text-[var(--admin-muted)]">
                            <div>
                              <dt className="font-semibold text-[var(--admin-text)]">
                                Visible phase
                              </dt>
                              <dd>
                                {phaseLabel(
                                  selectedSession.projectionPreviews.participant
                                    .phase,
                                )}
                              </dd>
                            </div>
                            <div>
                              <dt className="font-semibold text-[var(--admin-text)]">
                                Projection versions
                              </dt>
                              <dd>
                                Session{" "}
                                {
                                  selectedSession.projectionPreviews.participant
                                    .sessionVersion
                                }{" "}
                                · question{" "}
                                {
                                  selectedSession.projectionPreviews.participant
                                    .questionVersion
                                }
                              </dd>
                            </div>
                            <div>
                              <dt className="font-semibold text-[var(--admin-text)]">
                                Privacy-safe aggregate
                              </dt>
                              <dd>
                                {selectedSession.participantAggregate
                                  ? `${selectedSession.participantAggregate.participantCount} participants · ${selectedSession.participantAggregate.answerCount} answers · ${selectedSession.participantAggregate.averageScore} average score`
                                  : `${selectedSession.participantCount} participants`}
                              </dd>
                            </div>
                          </dl>
                        ) : (
                          <p className="mt-2 text-sm text-[var(--admin-muted)]">
                            Admin projection preview is unavailable for this
                            organizer-scoped session.
                          </p>
                        )}
                      </section>
                      <section
                        className="rounded-md border border-[var(--admin-border)] p-3"
                        aria-label="TV projection preview"
                      >
                        <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-muted)]">
                          TV preview
                        </p>
                        {selectedSession.projectionPreviews ? (
                          <dl className="mt-2 grid gap-2 text-sm text-[var(--admin-muted)]">
                            <div>
                              <dt className="font-semibold text-[var(--admin-text)]">
                                Visible phase
                              </dt>
                              <dd>
                                {phaseLabel(
                                  selectedSession.projectionPreviews.tv.phase,
                                )}
                              </dd>
                            </div>
                            <div>
                              <dt className="font-semibold text-[var(--admin-text)]">
                                Assigned displays
                              </dt>
                              <dd>
                                {
                                  selectedSession.projectionPreviews.tv
                                    .assignedDisplayCount
                                }
                              </dd>
                            </div>
                            <div>
                              <dt className="font-semibold text-[var(--admin-text)]">
                                Healthy displays
                              </dt>
                              <dd>
                                {
                                  selectedSession.assignedDisplays.filter(
                                    (display) => display.health === "online",
                                  ).length
                                }{" "}
                                online
                              </dd>
                            </div>
                          </dl>
                        ) : (
                          <p className="mt-2 text-sm text-[var(--admin-muted)]">
                            Admin TV preview is unavailable for this
                            organizer-scoped session.
                          </p>
                        )}
                      </section>
                    </div>
                  </article>

                  <div className="mt-5">
                    <p className="text-sm font-semibold text-[var(--admin-text)]">
                      Allowed next action
                    </p>
                    <div className="mt-3 flex flex-wrap gap-3">
                      {nextTransition ? (
                        <button
                          type="button"
                          onClick={() => stageTransition(nextTransition)}
                          disabled={
                            pendingAction != null ||
                            !networkOnline ||
                            reconnectRefreshRequired
                          }
                          className="admin-button admin-button-primary disabled:opacity-60"
                        >
                          {nextTransition === "reveal" ? (
                            <StepForward
                              className="h-4 w-4"
                              aria-hidden="true"
                            />
                          ) : (
                            <Play className="h-4 w-4" aria-hidden="true" />
                          )}
                          Review {phaseLabel(nextTransition)}
                        </button>
                      ) : null}
                      {selectedSession.allowedActions.includes("paused") ? (
                        <button
                          type="button"
                          onClick={() => stageTransition("paused")}
                          disabled={
                            pendingAction != null ||
                            !networkOnline ||
                            reconnectRefreshRequired
                          }
                          className="admin-button admin-button-secondary disabled:opacity-60"
                        >
                          <Pause className="h-4 w-4" aria-hidden="true" />
                          Review pause
                        </button>
                      ) : null}
                      {selectedSession.allowedActions.includes("completed") ? (
                        <button
                          type="button"
                          onClick={() => stageTransition("completed")}
                          disabled={
                            pendingAction != null ||
                            !networkOnline ||
                            reconnectRefreshRequired
                          }
                          className="admin-button admin-button-secondary disabled:opacity-60"
                        >
                          <CheckCircle2
                            className="h-4 w-4"
                            aria-hidden="true"
                          />
                          Review completion
                        </button>
                      ) : null}
                      {selectedSession.allowedActions.includes("cancelled") ? (
                        <button
                          type="button"
                          onClick={() => stageTransition("cancelled")}
                          disabled={
                            pendingAction != null ||
                            !networkOnline ||
                            reconnectRefreshRequired
                          }
                          className="admin-button admin-button-secondary disabled:opacity-60"
                        >
                          <Square className="h-4 w-4" aria-hidden="true" />
                          Review cancellation
                        </button>
                      ) : null}
                    </div>
                  </div>

                  {pendingTransitionPhase ? (
                    <article className="mt-4 rounded-md border border-amber-500/30 bg-amber-500/10 p-4">
                      <p className="text-sm font-semibold text-[var(--admin-text)]">
                        Confirm {phaseLabel(pendingTransitionPhase)}
                      </p>
                      <p className="mt-2 text-sm leading-6 text-[var(--admin-muted)]">
                        This applies to “{selectedSession.title}” at version{" "}
                        {selectedSession.sessionVersion}.
                        {nextQuestion
                          ? ` Question ${selectedSession.questions.find((question) => question.id === nextQuestion)?.ordinal ?? ""} will open.`
                          : ""}
                      </p>
                      {pendingTransitionPhase === "question_open" ? (
                        <label className="mt-3 grid max-w-xs gap-2 text-sm text-[var(--admin-muted)]">
                          Answer window
                          <select
                            value={questionDurationSeconds}
                            onChange={(event) =>
                              setQuestionDurationSeconds(
                                Number.parseInt(event.target.value, 10),
                              )
                            }
                            className="admin-input"
                            aria-label="Answer window"
                          >
                            <option value={15}>15 seconds</option>
                            <option value={20}>20 seconds</option>
                            <option value={30}>30 seconds</option>
                            <option value={45}>45 seconds</option>
                          </select>
                        </label>
                      ) : null}
                      <div className="mt-4 flex flex-wrap gap-3">
                        <button
                          type="button"
                          onClick={() => void confirmTransition()}
                          disabled={
                            pendingAction != null ||
                            !networkOnline ||
                            reconnectRefreshRequired
                          }
                          className="admin-button admin-button-primary disabled:opacity-60"
                        >
                          <ShieldCheck className="h-4 w-4" aria-hidden="true" />
                          {pendingAction === "transition"
                            ? "Confirming..."
                            : `Confirm ${phaseLabel(
                                pendingTransitionPhase,
                              ).toLowerCase()}`}
                        </button>
                        <button
                          type="button"
                          onClick={() => setPendingTransitionPhase("")}
                          disabled={pendingAction != null}
                          className="admin-button admin-button-secondary disabled:opacity-60"
                        >
                          Keep current state
                        </button>
                      </div>
                    </article>
                  ) : null}
                </>
              ) : null}
            </>
          )}
        </section>
      ) : null}

      {workspace === "content" ? (
        <section className="mt-6" aria-labelledby="content-studio-title">
          <div>
            <h3
              id="content-studio-title"
              className="text-sm font-semibold text-[var(--admin-text)]"
            >
              Content Studio
            </h3>
            <p className="mt-1 text-sm text-[var(--admin-muted)]">
              Generate from recorded sources, review by draft card, then build a
              pack from the approved question library.
            </p>
          </div>

          <div className="mt-5 rounded-md border border-[var(--admin-border)] p-4">
            <div className="flex items-center gap-2">
              <Sparkles className="h-4 w-4" aria-hidden="true" />
              <h4 className="text-sm font-semibold text-[var(--admin-text)]">
                Source-backed draft generation
              </h4>
            </div>
            <div className="mt-4 grid gap-4 md:grid-cols-2">
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Source title
                <input
                  value={sourceTitle}
                  onChange={(event) => setSourceTitle(event.target.value)}
                  className="admin-input"
                  aria-label="Source title"
                />
              </label>
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Source URL
                <input
                  type="url"
                  value={sourceUrl}
                  onChange={(event) => setSourceUrl(event.target.value)}
                  className="admin-input"
                  placeholder="Optional provenance URL"
                  aria-label="Source URL"
                />
              </label>
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Source date
                <input
                  type="date"
                  value={sourceDate}
                  onChange={(event) => setSourceDate(event.target.value)}
                  className="admin-input"
                  aria-label="Source date"
                />
              </label>
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Draft count
                <input
                  inputMode="numeric"
                  value={draftCount}
                  onChange={(event) => setDraftCount(event.target.value)}
                  className="admin-input"
                  aria-label="Draft count"
                />
              </label>
            </div>
            <label className="mt-4 grid gap-2 text-sm text-[var(--admin-muted)]">
              Verified source fact
              <textarea
                value={sourceFact}
                onChange={(event) => setSourceFact(event.target.value)}
                className="admin-input min-h-28"
                aria-label="Verified source fact"
              />
            </label>
            <button
              type="button"
              onClick={() => void generateDrafts()}
              disabled={pendingAction != null}
              className="admin-button admin-button-primary mt-4 disabled:opacity-60"
            >
              <Sparkles className="h-4 w-4" aria-hidden="true" />
              {pendingAction === "generate"
                ? "Generating drafts..."
                : "Generate review-gated drafts"}
            </button>
          </div>

          <div className="mt-5 rounded-md border border-[var(--admin-border)] p-4">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h4 className="text-sm font-semibold text-[var(--admin-text)]">
                  Human review queue
                </h4>
                <p className="mt-1 text-sm text-[var(--admin-muted)]">
                  Select a named draft card; duplicate and provenance signals
                  stay visible before approval.
                </p>
              </div>
              <button
                type="button"
                onClick={() => void loadDrafts(0)}
                disabled={pendingAction != null}
                className="admin-button admin-button-secondary disabled:opacity-60"
              >
                <ClipboardCheck className="h-4 w-4" aria-hidden="true" />
                {pendingAction === "drafts"
                  ? "Loading drafts..."
                  : "Load drafts"}
              </button>
            </div>
            <div className="mt-4 grid gap-4 md:grid-cols-2">
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Draft status
                <select
                  value={draftStatusFilter}
                  onChange={(event) =>
                    setDraftStatusFilter(
                      event.target.value as GameQuestionDraftStatus | "",
                    )
                  }
                  className="admin-input"
                  aria-label="Draft status"
                >
                  <option value="">All statuses</option>
                  <option value="pending_review">Pending review</option>
                  <option value="approved">Approved</option>
                  <option value="needs_changes">Needs changes</option>
                  <option value="rejected">Rejected</option>
                </select>
              </label>
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Draft search
                <input
                  value={draftSearch}
                  onChange={(event) => setDraftSearch(event.target.value)}
                  className="admin-input"
                  aria-label="Draft search"
                />
              </label>
            </div>
            <div className="mt-4 grid gap-3">
              {draftRows.length === 0 ? (
                <p className="text-sm text-[var(--admin-muted)]">
                  No draft cards are loaded.
                </p>
              ) : (
                draftRows.map((draft) => (
                  <button
                    key={draft.id}
                    type="button"
                    onClick={() => {
                      setSelectedDraftId(draft.id);
                      onSelectionChange?.(true);
                    }}
                    className={`rounded-md border p-4 text-left ${
                      selectedDraftId === draft.id
                        ? "border-[var(--admin-accent)] bg-[var(--admin-bg)]"
                        : "border-[var(--admin-border)]"
                    }`}
                    aria-pressed={selectedDraftId === draft.id}
                  >
                    <span className="block text-sm font-semibold text-[var(--admin-text)]">
                      {draft.prompt}
                    </span>
                    <span className="mt-2 block text-xs text-[var(--admin-muted)]">
                      {draft.category} · {draft.difficulty} ·{" "}
                      {draft.sourceTrustTier ?? "source review required"}
                    </span>
                    <span className="mt-2 block text-xs text-[var(--admin-muted)]">
                      {draft.hasDuplicatePrompt
                        ? `Exact duplicate (${draft.duplicatePromptCount})`
                        : draft.hasSimilarPrompt
                          ? `Similar prompt (${draft.similarPromptCount})`
                          : "No duplicate signal"}
                    </span>
                  </button>
                ))
              )}
            </div>
            {selectedDraft ? (
              <div className="mt-4 grid gap-4">
                <article className="rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-4">
                  <h5 className="text-sm font-semibold text-[var(--admin-text)]">
                    Source and approval provenance
                  </h5>
                  <dl className="mt-3 grid gap-3 text-sm text-[var(--admin-muted)] md:grid-cols-2">
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Source
                      </dt>
                      <dd>{selectedDraft.sourceTitle ?? "Missing source"}</dd>
                      <dd>
                        {selectedDraft.sourceUrl ??
                          "No source URL recorded"}
                      </dd>
                      <dd>
                        Citation: {selectedDraft.citationFragment ?? "Missing"}
                      </dd>
                    </div>
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Generation
                      </dt>
                      <dd>
                        {selectedDraft.generationMode === "ai_assisted"
                          ? `AI-assisted${selectedDraft.modelName ? ` · ${selectedDraft.modelName}` : ""}`
                          : "Human-authored"}
                      </dd>
                      <dd>
                        Schema: {selectedDraft.schemaVersion ?? "Missing"}
                      </dd>
                    </div>
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Human review
                      </dt>
                      <dd>
                        {selectedDraft.reviewedAt
                          ? `${selectedDraft.reviewerName ?? "Authorized reviewer"} · ${new Date(
                              selectedDraft.reviewedAt,
                            ).toLocaleString()}`
                          : "Pending human review"}
                      </dd>
                    </div>
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Deterministic QA
                      </dt>
                      <dd>
                        {Object.values(selectedDraft.qaChecks).every(Boolean)
                          ? "All checks pass"
                          : "Review required"}
                      </dd>
                    </div>
                  </dl>
                  <ul className="mt-3 grid gap-1 text-xs text-[var(--admin-muted)] md:grid-cols-2">
                    <li>
                      Source present:{" "}
                      {selectedDraft.qaChecks.sourcePresent ? "Pass" : "Fail"}
                    </li>
                    <li>
                      Citation fragment:{" "}
                      {selectedDraft.qaChecks.citationPresent ? "Pass" : "Fail"}
                    </li>
                    <li>
                      Trusted tier:{" "}
                      {selectedDraft.qaChecks.sourceTrusted ? "Pass" : "Fail"}
                    </li>
                    <li>
                      Schema metadata:{" "}
                      {selectedDraft.qaChecks.schemaVersionPresent
                        ? "Pass"
                        : "Fail"}
                    </li>
                    <li>
                      Model metadata:{" "}
                      {selectedDraft.qaChecks.modelMetadataPresent
                        ? "Pass"
                        : "Fail"}
                    </li>
                    <li>
                      Prompt length:{" "}
                      {selectedDraft.qaChecks.promptLengthValid
                        ? "Pass"
                        : "Fail"}
                    </li>
                    <li>
                      Exact duplicate:{" "}
                      {selectedDraft.qaChecks.exactDuplicateFree
                        ? "Pass"
                        : "Fail"}
                    </li>
                    <li>
                      Normalized duplicate:{" "}
                      {selectedDraft.qaChecks.normalizedDuplicateFree
                        ? "Pass"
                        : "Fail"}
                    </li>
                    <li>
                      Ambiguity signals:{" "}
                      {selectedDraft.qaChecks.ambiguitySignalsAbsent
                        ? "Pass"
                        : "Fail"}
                    </li>
                    <li>
                      Answer consistency:{" "}
                      {selectedDraft.qaChecks.answerConsistent ? "Pass" : "Fail"}
                    </li>
                    <li>
                      Supported language:{" "}
                      {selectedDraft.qaChecks.languageSupported ? "Pass" : "Fail"}
                    </li>
                    <li>
                      Entertainment policy:{" "}
                      {selectedDraft.qaChecks.policyCompliant ? "Pass" : "Fail"}
                    </li>
                  </ul>
                </article>
                <div className="grid gap-4 md:grid-cols-2">
                  <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                    Review decision
                    <select
                      value={reviewDecision}
                      onChange={(event) =>
                        setReviewDecision(
                          event.target.value as
                            | "approved"
                            | "rejected"
                            | "needs_changes",
                        )
                      }
                      className="admin-input"
                      aria-label="Review decision"
                    >
                      <option
                        value="approved"
                        disabled={!selectedDraftApprovalReady}
                      >
                        Approve
                      </option>
                      <option value="needs_changes">Needs changes</option>
                      <option value="rejected">Reject</option>
                    </select>
                  </label>
                  <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                    Review notes
                    <input
                      value={reviewNotes}
                      onChange={(event) => setReviewNotes(event.target.value)}
                      className="admin-input"
                      aria-label="Review notes"
                    />
                  </label>
                  <button
                    type="button"
                    onClick={() => void reviewDraft()}
                    disabled={
                      pendingAction != null ||
                      (reviewDecision === "approved" &&
                        !selectedDraftApprovalReady)
                    }
                    className="admin-button admin-button-primary disabled:opacity-60"
                  >
                    <ShieldCheck className="h-4 w-4" aria-hidden="true" />
                    {pendingAction === "review"
                      ? "Recording review..."
                      : "Review selected draft"}
                  </button>
                </div>
              </div>
            ) : null}
          </div>

          <div className="mt-5 rounded-md border border-[var(--admin-border)] p-4">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h4 className="text-sm font-semibold text-[var(--admin-text)]">
                  Approved question pack
                </h4>
                <p className="mt-1 text-sm text-[var(--admin-muted)]">
                  Select exactly 20 approved questions by prompt. Correct
                  answers are not exposed in this workspace.
                </p>
              </div>
              <button
                type="button"
                onClick={() => void loadPlannerOptions()}
                disabled={pendingAction != null}
                className="admin-button admin-button-secondary disabled:opacity-60"
              >
                <RefreshCw className="h-4 w-4" aria-hidden="true" />
                Load approved content
              </button>
            </div>
            <div className="mt-4 grid gap-4 md:grid-cols-2">
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Pack title
                <input
                  value={packTitle}
                  onChange={(event) => {
                    setPackTitle(event.target.value);
                    setPackPreviewFingerprint("");
                  }}
                  className="admin-input"
                  aria-label="Pack title"
                />
              </label>
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Pack description
                <input
                  value={packDescription}
                  onChange={(event) => {
                    setPackDescription(event.target.value);
                    setPackPreviewFingerprint("");
                  }}
                  className="admin-input"
                  aria-label="Pack description"
                />
              </label>
            </div>
            <p className="mt-4 text-sm font-semibold text-[var(--admin-text)]">
              {selectedQuestionIds.length} of 20 selected
            </p>
            <div className="mt-3 grid max-h-96 gap-2 overflow-auto">
              {plannerOptions?.questions.map((question) => (
                <label
                  key={question.id}
                  className="flex items-start gap-3 rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-3"
                >
                  <input
                    type="checkbox"
                    checked={selectedQuestionIds.includes(question.id)}
                    onChange={() => toggleQuestion(question.id)}
                    disabled={
                      !selectedQuestionIds.includes(question.id) &&
                      selectedQuestionIds.length >= 20
                    }
                    aria-label={`Select question: ${question.prompt}`}
                  />
                  <span>
                    <span className="block text-sm font-semibold text-[var(--admin-text)]">
                      {question.prompt}
                    </span>
                    <span className="mt-1 block text-xs text-[var(--admin-muted)]">
                      {question.category} · {question.difficulty} ·{" "}
                      {question.sourceTitle ?? "No source title"}
                    </span>
                  </span>
                </label>
              )) ?? (
                <p className="text-sm text-[var(--admin-muted)]">
                  Load approved content to choose questions.
                </p>
              )}
            </div>
            {selectedQuestionIds.length === 20 ? (
              <div className="mt-5 grid gap-4">
                <article className="rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-4">
                  <h5 className="text-sm font-semibold text-[var(--admin-text)]">
                    Deterministic publication QA
                  </h5>
                  <ul className="mt-3 grid gap-2 text-sm text-[var(--admin-muted)] md:grid-cols-2">
                    <li>Exactly 20 approved prompts: {packQa.exactCount ? "Pass" : "Fail"}</li>
                    <li>Unique ordered prompts: {packQa.uniqueQuestions ? "Pass" : "Fail"}</li>
                    <li>
                      Source evidence on every prompt:{" "}
                      {packQa.sourceEvidenceComplete ? "Pass" : "Fail"}
                    </li>
                    <li>
                      Human approval timestamp on every prompt:{" "}
                      {packQa.approvalProvenanceComplete ? "Pass" : "Fail"}
                    </li>
                  </ul>
                </article>

                <div className="grid gap-4 lg:grid-cols-2">
                  <article className="rounded-[1.25rem] border border-[var(--admin-border)] bg-[var(--admin-bg)] p-4">
                    <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-muted)]">
                      Mobile preview
                    </p>
                    <p className="mt-3 text-xs text-[var(--admin-muted)]">
                      Question 1 of 20
                    </p>
                    <p className="mt-2 text-base font-semibold text-[var(--admin-text)]">
                      {selectedPackQuestions[0]?.prompt}
                    </p>
                    <p className="mt-3 text-xs text-[var(--admin-muted)]">
                      {selectedPackQuestions[0]?.category} ·{" "}
                      {selectedPackQuestions[0]?.difficulty} ·{" "}
                      {selectedPackQuestions[0]?.sourceTitle}
                    </p>
                  </article>
                  <article className="rounded-md border border-[var(--admin-border)] bg-[var(--admin-surface)] p-5">
                    <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-muted)]">
                      TV preview
                    </p>
                    <p className="mt-4 text-lg font-semibold leading-7 text-[var(--admin-text)]">
                      {selectedPackQuestions[0]?.prompt}
                    </p>
                    <p className="mt-4 text-sm text-[var(--admin-muted)]">
                      Question 1 / 20 · Choices remain answer-safe until the
                      authoritative session opens.
                    </p>
                  </article>
                </div>

                <button
                  type="button"
                  onClick={() => void reviewPackPreviews()}
                  disabled={!packQaPass || pendingAction != null}
                  className="admin-button admin-button-secondary disabled:opacity-60"
                >
                  <Eye className="h-4 w-4" aria-hidden="true" />
                  {pendingAction === "preview"
                    ? "Locking previews..."
                    : packPreviewFingerprint
                      ? "Mobile and TV previews reviewed"
                      : "Review and lock mobile/TV previews"}
                </button>
              </div>
            ) : null}
            <button
              type="button"
              onClick={() => void publishPack()}
              disabled={
                !packQaPass ||
                !packPreviewFingerprint ||
                pendingAction != null
              }
              className="admin-button admin-button-primary mt-4 disabled:opacity-60"
            >
              <CheckCircle2 className="h-4 w-4" aria-hidden="true" />
              {pendingAction === "publish"
                ? "Publishing pack..."
                : "Publish reviewed pack"}
            </button>
          </div>

          <div className="mt-5 rounded-md border border-[var(--admin-border)] p-4">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <h4 className="text-sm font-semibold text-[var(--admin-text)]">
                  Privacy-filtered audit
                </h4>
                <p className="mt-1 text-sm text-[var(--admin-muted)]">
                  Inspect bounded operational outcomes without personal actor
                  details.
                </p>
              </div>
              <button
                type="button"
                onClick={() => void loadAudit(0)}
                disabled={pendingAction != null}
                className="admin-button admin-button-secondary disabled:opacity-60"
              >
                <History className="h-4 w-4" aria-hidden="true" />
                {pendingAction === "audit" ? "Loading audit..." : "Load audit"}
              </button>
            </div>
            <div className="mt-4 grid gap-4 md:grid-cols-2">
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Audit action
                <input
                  value={auditActionFilter}
                  onChange={(event) => setAuditActionFilter(event.target.value)}
                  className="admin-input"
                  aria-label="Audit action"
                />
              </label>
              <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
                Audit entity type
                <input
                  value={auditEntityType}
                  onChange={(event) => setAuditEntityType(event.target.value)}
                  className="admin-input"
                  aria-label="Audit entity type"
                />
              </label>
            </div>
            <div className="mt-4 grid gap-2">
              {auditRows.map((row) => (
                <button
                  key={row.id}
                  type="button"
                  onClick={() => {
                    setSelectedAuditId(row.id);
                    onSelectionChange?.(true);
                  }}
                  className={`rounded-md border p-3 text-left ${
                    selectedAudit?.id === row.id
                      ? "border-[var(--admin-accent)] bg-[var(--admin-bg)]"
                      : "border-[var(--admin-border)]"
                  }`}
                >
                  <span className="block text-sm font-semibold text-[var(--admin-text)]">
                    {row.action}
                  </span>
                  <span className="mt-1 block text-xs text-[var(--admin-muted)]">
                    {row.entityType} ·{" "}
                    {new Date(row.createdAt).toLocaleString()}
                  </span>
                </button>
              ))}
            </div>
            {selectedAudit ? (
              <pre className="mt-4 max-h-72 overflow-auto rounded-md bg-slate-950 p-4 text-xs leading-5 text-slate-100">
                {JSON.stringify(selectedAudit.after ?? {}, null, 2)}
              </pre>
            ) : null}
          </div>
        </section>
      ) : null}

      <div
        role="status"
        aria-live="polite"
        className="mt-6 rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] px-4 py-3 text-sm text-[var(--admin-text)]"
      >
        {status}
      </div>
    </section>
  );
}

"use client";

import { useMemo, useState } from "react";
import {
  ClipboardCheck,
  Eye,
  FileText,
  History,
  Monitor,
  Play,
  Plus,
  RotateCcw,
  ShieldCheck,
  Sparkles,
  Square,
  StepForward,
} from "lucide-react";
import { createGameRuntimeClient } from "@/lib/game-runtime";
import type {
  GameAuditLogRow,
  GameQuestionDraftQueueRow,
  GameQuestionDraftStatus,
} from "@/lib/game-runtime";

type GameControlActionClient = {
  createSession(input: {
    clubId: number;
    title: string;
    packId?: string;
    tvDeviceId?: string;
    joinCode?: string;
  }): Promise<{
    sessionId: string;
    joinCode: string;
    questionTotal: number;
    firstSessionQuestionId: string | null;
    tvDeviceId: string | null;
  }>;
  pairTvDevice(input: {
    clubId: number;
    deviceLabel: string;
    pairingCode: string;
    sessionId?: string;
  }): Promise<{
    tvDeviceId: string;
    pairingCode: string;
    sessionId: string | null;
  }>;
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
    templateId?: string;
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
  openQuestion(input: {
    clubId: number;
    sessionQuestionId: string;
  }): Promise<unknown>;
  revealQuestion(input: {
    clubId: number;
    sessionQuestionId: string;
  }): Promise<unknown>;
  advanceQuestion(input: {
    clubId: number;
    sessionQuestionId: string;
  }): Promise<{
    sessionId: string;
    previousSessionQuestionId: string;
    nextSessionQuestionId: string | null;
    status: string;
    isComplete: boolean;
  }>;
  closeSession(input: {
    clubId: number;
    sessionId: string;
  }): Promise<{
    sessionId: string;
    status: string;
    closedQuestionCount: number;
  }>;
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

const GAME_ADMIN_PAGE_SIZE = 25;

type GamesControlClientProps = {
  defaultClubId: number;
  defaultSessionQuestionId?: string;
  actionClient?: GameControlActionClient;
};

export function GamesControlClient({
  defaultClubId,
  defaultSessionQuestionId = "",
  actionClient,
}: GamesControlClientProps) {
  const defaultClient = useMemo(() => createGameRuntimeClient({}), []);
  const client = actionClient ?? defaultClient;
  const [clubId, setClubId] = useState(String(defaultClubId));
  const [sessionTitle, setSessionTitle] = useState("Rayon matchday quiz");
  const [packId, setPackId] = useState("");
  const [sessionId, setSessionId] = useState("");
  const [joinCode, setJoinCode] = useState("");
  const [tvDeviceId, setTvDeviceId] = useState("");
  const [deviceLabel, setDeviceLabel] = useState("Main TV");
  const [pairingCode, setPairingCode] = useState("");
  const [sessionQuestionId, setSessionQuestionId] = useState(
    defaultSessionQuestionId,
  );
  const [sourceTitle, setSourceTitle] = useState("Rayon matchday source");
  const [sourceFact, setSourceFact] = useState("");
  const [sourceUrl, setSourceUrl] = useState("");
  const [sourceDate, setSourceDate] = useState("");
  const [draftCount, setDraftCount] = useState("5");
  const [generatedDraftIds, setGeneratedDraftIds] = useState<string[]>([]);
  const [draftRows, setDraftRows] = useState<GameQuestionDraftQueueRow[]>([]);
  const [draftOffset, setDraftOffset] = useState(0);
  const [draftStatusFilter, setDraftStatusFilter] = useState<
    GameQuestionDraftStatus | ""
  >("pending_review");
  const [draftSearch, setDraftSearch] = useState("");
  const [draftId, setDraftId] = useState("");
  const [reviewDecision, setReviewDecision] = useState<
    "approved" | "rejected" | "needs_changes"
  >("approved");
  const [reviewNotes, setReviewNotes] = useState("");
  const [packTitle, setPackTitle] = useState("Rayon 20-question round");
  const [packDescription, setPackDescription] = useState("");
  const [templateId, setTemplateId] = useState("");
  const [questionIdsText, setQuestionIdsText] = useState("");
  const [auditActionFilter, setAuditActionFilter] = useState("");
  const [auditEntityType, setAuditEntityType] = useState("");
  const [auditOffset, setAuditOffset] = useState(0);
  const [auditRows, setAuditRows] = useState<GameAuditLogRow[]>([]);
  const [selectedAuditRowId, setSelectedAuditRowId] = useState("");
  const [pendingAction, setPendingAction] = useState<
    | "create"
    | "pair"
    | "open"
    | "reveal"
    | "advance"
    | "close"
    | "generate"
    | "drafts"
    | "review"
    | "publish"
    | "audit"
    | null
  >(null);
  const [status, setStatus] = useState(
    "Create a session, pair a display, then open a session question.",
  );

  const parsedClubId = Number.parseInt(clubId, 10);
  const hasValidClubId = Number.isFinite(parsedClubId) && parsedClubId > 0;
  const canCreateSession =
    hasValidClubId && sessionTitle.trim().length > 0 && pendingAction == null;
  const canPairDevice =
    hasValidClubId &&
    deviceLabel.trim().length > 0 &&
    pairingCode.trim().length > 0 &&
    pendingAction == null;
  const canSubmitQuestionAction =
    Number.isFinite(parsedClubId) &&
    parsedClubId > 0 &&
    sessionQuestionId.trim().length > 0 &&
    pendingAction == null;
  const canCloseSession =
    hasValidClubId && sessionId.trim().length > 0 && pendingAction == null;
  const questionIds = questionIdsText
    .split(/[\n,]+/)
    .map((id) => id.trim())
    .filter(Boolean);
  const canReviewDraft =
    hasValidClubId && draftId.trim().length > 0 && pendingAction == null;
  const canLoadDrafts = hasValidClubId && pendingAction == null;
  const parsedDraftCount = Number.parseInt(draftCount, 10);
  const canGenerateDrafts =
    hasValidClubId &&
    sourceTitle.trim().length > 0 &&
    sourceFact.trim().length > 0 &&
    Number.isFinite(parsedDraftCount) &&
    parsedDraftCount > 0 &&
    parsedDraftCount <= 10 &&
    pendingAction == null;
  const canPublishPack =
    hasValidClubId &&
    packTitle.trim().length > 0 &&
    questionIds.length === 20 &&
    pendingAction == null;
  const canLoadAudit = hasValidClubId && pendingAction == null;
  const selectedAuditRow =
    auditRows.find((row) => row.id === selectedAuditRowId) ?? auditRows[0] ?? null;

  async function createSession() {
    if (!canCreateSession) {
      setStatus("Club id and session title are required.");
      return;
    }

    setPendingAction("create");
    setStatus("Creating game session...");
    try {
      const result = await client.createSession({
        clubId: parsedClubId,
        title: sessionTitle.trim(),
        packId: packId.trim() || undefined,
        tvDeviceId: tvDeviceId.trim() || undefined,
        joinCode: joinCode.trim() || undefined,
      });
      setSessionId(result.sessionId);
      setJoinCode(result.joinCode);
      if (result.tvDeviceId) {
        setTvDeviceId(result.tvDeviceId);
      }
      if (result.firstSessionQuestionId) {
        setSessionQuestionId(result.firstSessionQuestionId);
      }
      setStatus(
        `Session created with code ${result.joinCode}. ${result.questionTotal} question(s) loaded.`,
      );
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Could not create session.",
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function pairTvDevice() {
    if (!canPairDevice) {
      setStatus("Club id, display label, and pairing code are required.");
      return;
    }

    setPendingAction("pair");
    setStatus("Pairing TV display...");
    try {
      const result = await client.pairTvDevice({
        clubId: parsedClubId,
        deviceLabel: deviceLabel.trim(),
        pairingCode: pairingCode.trim(),
        sessionId: sessionId.trim() || undefined,
      });
      setTvDeviceId(result.tvDeviceId);
      setPairingCode(result.pairingCode);
      if (result.sessionId) {
        setSessionId(result.sessionId);
      }
      setStatus(`TV display paired with code ${result.pairingCode}.`);
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Could not pair TV display.",
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function runAction(action: "open" | "reveal" | "advance") {
    if (!canSubmitQuestionAction) {
      setStatus("Club id and session-question id are required.");
      return;
    }

    setPendingAction(action);
    setStatus(
      action === "open"
        ? "Opening question..."
        : action === "reveal"
          ? "Revealing question..."
          : "Advancing question...",
    );
    try {
      const input = {
        clubId: parsedClubId,
        sessionQuestionId: sessionQuestionId.trim(),
      };
      if (action === "open") {
        await client.openQuestion(input);
        setStatus("Question opened for answers.");
      } else {
        if (action === "reveal") {
          await client.revealQuestion(input);
          setStatus("Question revealed to the display.");
        } else {
          const result = await client.advanceQuestion(input);
          if (result.nextSessionQuestionId) {
            setSessionId(result.sessionId);
            setSessionQuestionId(result.nextSessionQuestionId);
            setStatus(`Advanced to next question ${result.nextSessionQuestionId}.`);
          } else {
            setSessionId(result.sessionId);
            setSessionQuestionId("");
            setStatus("Session completed after final question.");
          }
        }
      }
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Game control action failed.",
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function closeSession() {
    if (!canCloseSession) {
      setStatus("Club id and session id are required to close the session.");
      return;
    }

    setPendingAction("close");
    setStatus("Closing game session...");
    try {
      const result = await client.closeSession({
        clubId: parsedClubId,
        sessionId: sessionId.trim(),
      });
      setSessionId(result.sessionId);
      setSessionQuestionId("");
      setStatus(
        `Session closed. ${result.closedQuestionCount} question(s) closed.`,
      );
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Could not close session.",
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function reviewDraft() {
    if (!canReviewDraft) {
      setStatus("Club id and question draft id are required.");
      return;
    }

    setPendingAction("review");
    setStatus("Reviewing question draft...");
    try {
      const result = await client.reviewQuestionDraft({
        clubId: parsedClubId,
        draftId: draftId.trim(),
        decision: reviewDecision,
        notes: reviewNotes.trim() || undefined,
      });
      setStatus(
        result.questionId
          ? `Draft ${result.decision}; approved question ${result.questionId}.`
          : `Draft ${result.decision}.`,
      );
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Could not review draft.",
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function generateDrafts() {
    if (!canGenerateDrafts) {
      setStatus("Club id, source title, source fact, and draft count are required.");
      return;
    }

    setPendingAction("generate");
    setStatus("Generating draft questions for review...");
    try {
      const result = await client.generateQuestionDrafts({
        clubId: parsedClubId,
        sourceTitle: sourceTitle.trim(),
        extractedFact: sourceFact.trim(),
        sourceUrl: sourceUrl.trim() || undefined,
        sourceDate: sourceDate.trim() || undefined,
        trustTier: "review_required",
        count: parsedDraftCount,
        language: "en",
        category: "club_knowledge",
      });
      setGeneratedDraftIds(result.draftIds);
      setDraftId(result.draftIds[0] ?? "");
      setStatus(
        `Generated ${result.count} draft question(s) for review from source ${result.sourceId}.`,
      );
    } catch (caught) {
      setStatus(
        caught instanceof Error
          ? caught.message
          : "Could not generate draft questions.",
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function loadQuestionDrafts(nextOffset = draftOffset) {
    if (!canLoadDrafts) {
      setStatus("Club id is required to load question drafts.");
      return;
    }

    setPendingAction("drafts");
    setStatus("Loading question draft queue...");
    try {
      const rows = await client.listQuestionDrafts({
        clubId: parsedClubId,
        status: draftStatusFilter || undefined,
        search: draftSearch.trim() || undefined,
        limit: GAME_ADMIN_PAGE_SIZE,
        offset: nextOffset,
      });
      setDraftRows(rows);
      setDraftOffset(nextOffset);
      if (rows[0]) {
        setDraftId(rows[0].id);
      }
      setStatus(`Loaded ${rows.length} draft row(s) from ${nextOffset + 1}.`);
    } catch (caught) {
      setStatus(
        caught instanceof Error
          ? caught.message
          : "Could not load question drafts.",
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function publishPack() {
    if (!canPublishPack) {
      setStatus("Pack title and exactly 20 approved question ids are required.");
      return;
    }

    setPendingAction("publish");
    setStatus("Publishing question pack...");
    try {
      const result = await client.publishQuestionPack({
        clubId: parsedClubId,
        title: packTitle.trim(),
        description: packDescription.trim() || undefined,
        templateId: templateId.trim() || undefined,
        questionIds,
      });
      setPackId(result.packId);
      setStatus(
        `Pack published: ${result.title} (${result.questionCount} questions).`,
      );
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Could not publish pack.",
      );
    } finally {
      setPendingAction(null);
    }
  }

  async function loadAuditLog(nextOffset = auditOffset) {
    if (!canLoadAudit) {
      setStatus("Club id is required to load audit rows.");
      return;
    }

    setPendingAction("audit");
    setStatus("Loading recent audit rows...");
    try {
      const rows = await client.listAuditLog({
        clubId: parsedClubId,
        limit: GAME_ADMIN_PAGE_SIZE,
        offset: nextOffset,
        actionFilter: auditActionFilter.trim() || undefined,
        entityType: auditEntityType.trim() || undefined,
      });
      setAuditRows(rows);
      setAuditOffset(nextOffset);
      setSelectedAuditRowId(rows[0]?.id ?? "");
      setStatus(`Loaded ${rows.length} audit row(s) from ${nextOffset + 1}.`);
    } catch (caught) {
      setStatus(
        caught instanceof Error ? caught.message : "Could not load audit rows.",
      );
    } finally {
      setPendingAction(null);
    }
  }

  return (
    <section className="rounded-lg border border-[var(--admin-border)] bg-[var(--admin-surface)] p-5 shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="admin-page-eyebrow">Control room</p>
          <h2 className="text-base font-semibold text-[var(--admin-text)]">
            Session, TV, and question actions
          </h2>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-[var(--admin-muted)]">
            Create a lobby session, pair a TV display, then run host actions
            through the same game runtime contract used by TV and mobile.
          </p>
        </div>
        <div className="inline-flex items-center gap-2 rounded-md bg-emerald-500/10 px-3 py-2 text-sm font-semibold text-emerald-700">
          <ShieldCheck className="h-4 w-4" aria-hidden="true" />
          Club scoped
        </div>
      </div>

      <div className="mt-5 grid gap-4 md:grid-cols-[160px_1fr]">
        <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
          Club id
          <input
            value={clubId}
            onChange={(event) => setClubId(event.target.value)}
            inputMode="numeric"
            className="admin-input"
            aria-label="Club id"
          />
        </label>
        <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
          Session title
          <input
            value={sessionTitle}
            onChange={(event) => setSessionTitle(event.target.value)}
            className="admin-input"
            aria-label="Session title"
          />
        </label>
      </div>

      <div className="mt-4 grid gap-4 md:grid-cols-3">
        <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
          Question pack id
          <input
            value={packId}
            onChange={(event) => setPackId(event.target.value)}
            className="admin-input"
            placeholder="Optional published pack id"
            aria-label="Question pack id"
          />
        </label>
        <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
          Join code
          <input
            value={joinCode}
            onChange={(event) => setJoinCode(event.target.value)}
            className="admin-input"
            placeholder="Auto-generated if blank"
            aria-label="Join code"
          />
        </label>
        <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
          Session id
          <input
            value={sessionId}
            onChange={(event) => setSessionId(event.target.value)}
            className="admin-input"
            placeholder="Created session id"
            aria-label="Session id"
          />
        </label>
      </div>

      <div className="mt-4 flex flex-wrap gap-3">
        <button
          type="button"
          onClick={() => {
            createSession().catch(() => {});
          }}
          disabled={!canCreateSession}
          className="admin-button admin-button-primary disabled:opacity-60"
        >
          <Plus className="h-4 w-4" aria-hidden="true" />
          {pendingAction === "create" ? "Creating..." : "Create session"}
        </button>
      </div>

      <div className="mt-6 grid gap-4 md:grid-cols-3">
        <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
          TV label
          <input
            value={deviceLabel}
            onChange={(event) => setDeviceLabel(event.target.value)}
            className="admin-input"
            aria-label="TV label"
          />
        </label>
        <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
          Pairing code
          <input
            value={pairingCode}
            onChange={(event) => setPairingCode(event.target.value)}
            className="admin-input"
            placeholder="Code shown on display"
            aria-label="Pairing code"
          />
        </label>
        <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
          TV device id
          <input
            value={tvDeviceId}
            onChange={(event) => setTvDeviceId(event.target.value)}
            className="admin-input"
            placeholder="Returned after pairing"
            aria-label="TV device id"
          />
        </label>
      </div>

      <div className="mt-4 flex flex-wrap gap-3">
        <button
          type="button"
          onClick={() => {
            pairTvDevice().catch(() => {});
          }}
          disabled={!canPairDevice}
          className="admin-button admin-button-secondary disabled:opacity-60"
        >
          <Monitor className="h-4 w-4" aria-hidden="true" />
          {pendingAction === "pair" ? "Pairing..." : "Pair TV display"}
        </button>
      </div>

      <div className="mt-6 grid gap-4">
        <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
          Session-question id
          <input
            value={sessionQuestionId}
            onChange={(event) => setSessionQuestionId(event.target.value)}
            className="admin-input"
            placeholder="00000000-0000-4000-8000-000000000101"
            aria-label="Session-question id"
          />
        </label>
      </div>

      <div className="mt-5 flex flex-wrap gap-3">
        <button
          type="button"
          onClick={() => {
            runAction("open").catch(() => {});
          }}
          disabled={!canSubmitQuestionAction}
          className="admin-button admin-button-primary disabled:opacity-60"
        >
          <Play className="h-4 w-4" aria-hidden="true" />
          {pendingAction === "open" ? "Opening..." : "Open question"}
        </button>
        <button
          type="button"
          onClick={() => {
            runAction("reveal").catch(() => {});
          }}
          disabled={!canSubmitQuestionAction}
          className="admin-button admin-button-secondary disabled:opacity-60"
        >
          <RotateCcw className="h-4 w-4" aria-hidden="true" />
          {pendingAction === "reveal" ? "Revealing..." : "Reveal question"}
        </button>
        <button
          type="button"
          onClick={() => {
            runAction("advance").catch(() => {});
          }}
          disabled={!canSubmitQuestionAction}
          className="admin-button admin-button-secondary disabled:opacity-60"
        >
          <StepForward className="h-4 w-4" aria-hidden="true" />
          {pendingAction === "advance" ? "Advancing..." : "Advance question"}
        </button>
        <button
          type="button"
          onClick={() => {
            closeSession().catch(() => {});
          }}
          disabled={!canCloseSession}
          className="admin-button admin-button-secondary disabled:opacity-60"
        >
          <Square className="h-4 w-4" aria-hidden="true" />
          {pendingAction === "close" ? "Closing..." : "Close session"}
        </button>
      </div>

      <div className="mt-8 border-t border-[var(--admin-border)] pt-6">
        <div className="flex flex-wrap items-center gap-2">
          <Sparkles className="h-4 w-4 text-[var(--admin-muted)]" aria-hidden="true" />
          <h3 className="text-sm font-semibold text-[var(--admin-text)]">
            Draft generation
          </h3>
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-[1fr_140px]">
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
            Draft count
            <input
              value={draftCount}
              onChange={(event) => setDraftCount(event.target.value)}
              inputMode="numeric"
              className="admin-input"
              aria-label="Draft count"
            />
          </label>
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-2">
          <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
            Source URL
            <input
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
              value={sourceDate}
              onChange={(event) => setSourceDate(event.target.value)}
              className="admin-input"
              placeholder="YYYY-MM-DD"
              aria-label="Source date"
            />
          </label>
        </div>
        <label className="mt-4 grid gap-2 text-sm text-[var(--admin-muted)]">
          Source fact
          <textarea
            value={sourceFact}
            onChange={(event) => setSourceFact(event.target.value)}
            className="admin-input min-h-24"
            placeholder="One verified fact to transform into draft questions"
            aria-label="Source fact"
          />
        </label>
        <div className="mt-4 flex flex-wrap gap-3">
          <button
            type="button"
            onClick={() => {
              generateDrafts().catch(() => {});
            }}
            disabled={!canGenerateDrafts}
            className="admin-button admin-button-secondary disabled:opacity-60"
          >
            <Sparkles className="h-4 w-4" aria-hidden="true" />
            {pendingAction === "generate" ? "Generating..." : "Generate drafts"}
          </button>
        </div>
        {generatedDraftIds.length > 0 ? (
          <div className="mt-4 rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-3">
            <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-muted)]">
              Draft ids awaiting review
            </p>
            <ul className="mt-2 grid gap-1 text-sm text-[var(--admin-text)]">
              {generatedDraftIds.map((id) => (
                <li key={id}>{id}</li>
              ))}
            </ul>
          </div>
        ) : null}
      </div>

      <div className="mt-8 border-t border-[var(--admin-border)] pt-6">
        <div className="flex flex-wrap items-center gap-2">
          <ClipboardCheck className="h-4 w-4 text-[var(--admin-muted)]" aria-hidden="true" />
          <h3 className="text-sm font-semibold text-[var(--admin-text)]">
            Content moderation
          </h3>
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-[180px_1fr_auto]">
          <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
            Draft status
            <select
              value={draftStatusFilter}
              onChange={(event) =>
                setDraftStatusFilter(event.target.value as GameQuestionDraftStatus | "")
              }
              className="admin-input"
              aria-label="Draft status"
            >
              <option value="">All statuses</option>
              <option value="pending_review">Pending review</option>
              <option value="needs_changes">Needs changes</option>
              <option value="approved">Approved</option>
              <option value="rejected">Rejected</option>
            </select>
          </label>
          <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
            Draft search
            <input
              value={draftSearch}
              onChange={(event) => setDraftSearch(event.target.value)}
              className="admin-input"
              placeholder="Prompt or category"
              aria-label="Draft search"
            />
          </label>
          <div className="flex items-end">
            <button
              type="button"
              onClick={() => {
                loadQuestionDrafts(0).catch(() => {});
              }}
              disabled={!canLoadDrafts}
              className="admin-button admin-button-secondary disabled:opacity-60"
            >
              <ClipboardCheck className="h-4 w-4" aria-hidden="true" />
              {pendingAction === "drafts" ? "Loading..." : "Load drafts"}
            </button>
          </div>
        </div>
        {draftRows.length > 0 ? (
          <div className="mt-4 grid gap-2">
            {draftRows.map((row) => (
              <button
                type="button"
                key={row.id}
                onClick={() => setDraftId(row.id)}
                className="rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-3 text-left hover:border-[var(--admin-accent)]"
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className="text-sm font-semibold text-[var(--admin-text)]">
                    {row.prompt}
                  </p>
                  <span className="rounded-md bg-slate-900/5 px-2 py-1 text-xs font-semibold text-[var(--admin-muted)]">
                    {row.validationStatus}
                  </span>
                  {row.hasDuplicatePrompt ? (
                    <span className="rounded-md bg-amber-500/10 px-2 py-1 text-xs font-semibold text-amber-700">
                      Exact duplicate ({row.duplicatePromptCount})
                    </span>
                  ) : row.hasSimilarPrompt ? (
                    <span className="rounded-md bg-sky-500/10 px-2 py-1 text-xs font-semibold text-sky-700">
                      Similar prompt ({row.similarPromptCount})
                    </span>
                  ) : null}
                </div>
                <p className="mt-1 text-xs text-[var(--admin-muted)]">
                  {row.category} / {row.difficulty}
                  {row.sourceTitle ? ` / ${row.sourceTitle}` : ""}
                  {row.sourceTrustTier ? ` / ${row.sourceTrustTier}` : ""}
                  {row.duplicateRiskLevel !== "none"
                    ? ` / risk: ${row.duplicateRiskLevel}`
                    : ""}
                </p>
                {row.validationNotes ? (
                  <p className="mt-2 text-xs text-[var(--admin-muted)]">
                    {row.validationNotes}
                  </p>
                ) : null}
              </button>
            ))}
            <div className="flex flex-wrap items-center justify-between gap-3 pt-2">
              <button
                type="button"
                onClick={() => {
                  loadQuestionDrafts(
                    Math.max(0, draftOffset - GAME_ADMIN_PAGE_SIZE),
                  ).catch(() => {});
                }}
                disabled={draftOffset === 0 || pendingAction != null}
                className="admin-button admin-button-secondary disabled:opacity-60"
              >
                Previous drafts
              </button>
              <span className="text-xs text-[var(--admin-muted)]">
                Showing {draftOffset + 1}-{draftOffset + draftRows.length}
              </span>
              <button
                type="button"
                onClick={() => {
                  loadQuestionDrafts(draftOffset + GAME_ADMIN_PAGE_SIZE).catch(
                    () => {},
                  );
                }}
                disabled={
                  draftRows.length < GAME_ADMIN_PAGE_SIZE || pendingAction != null
                }
                className="admin-button admin-button-secondary disabled:opacity-60"
              >
                Next drafts
              </button>
            </div>
          </div>
        ) : null}
        <div className="mt-4 grid gap-4 md:grid-cols-[1fr_180px]">
          <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
            Question draft id
            <input
              value={draftId}
              onChange={(event) => setDraftId(event.target.value)}
              className="admin-input"
              placeholder="Draft id awaiting human review"
              aria-label="Question draft id"
            />
          </label>
          <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
            Decision
            <select
              value={reviewDecision}
              onChange={(event) =>
                setReviewDecision(
                  event.target.value as "approved" | "rejected" | "needs_changes",
                )
              }
              className="admin-input"
              aria-label="Review decision"
            >
              <option value="approved">Approve</option>
              <option value="needs_changes">Needs changes</option>
              <option value="rejected">Reject</option>
            </select>
          </label>
        </div>
        <label className="mt-4 grid gap-2 text-sm text-[var(--admin-muted)]">
          Review notes
          <textarea
            value={reviewNotes}
            onChange={(event) => setReviewNotes(event.target.value)}
            className="admin-input min-h-24"
            aria-label="Review notes"
          />
        </label>
        <div className="mt-4 flex flex-wrap gap-3">
          <button
            type="button"
            onClick={() => {
              reviewDraft().catch(() => {});
            }}
            disabled={!canReviewDraft}
            className="admin-button admin-button-secondary disabled:opacity-60"
          >
            <ClipboardCheck className="h-4 w-4" aria-hidden="true" />
            {pendingAction === "review" ? "Reviewing..." : "Review draft"}
          </button>
        </div>
      </div>

      <div className="mt-8 border-t border-[var(--admin-border)] pt-6">
        <div className="flex flex-wrap items-center gap-2">
          <FileText className="h-4 w-4 text-[var(--admin-muted)]" aria-hidden="true" />
          <h3 className="text-sm font-semibold text-[var(--admin-text)]">
            Pack builder
          </h3>
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-2">
          <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
            Pack title
            <input
              value={packTitle}
              onChange={(event) => setPackTitle(event.target.value)}
              className="admin-input"
              aria-label="Pack title"
            />
          </label>
          <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
            Template id
            <input
              value={templateId}
              onChange={(event) => setTemplateId(event.target.value)}
              className="admin-input"
              placeholder="Optional template id"
              aria-label="Template id"
            />
          </label>
        </div>
        <label className="mt-4 grid gap-2 text-sm text-[var(--admin-muted)]">
          Pack description
          <input
            value={packDescription}
            onChange={(event) => setPackDescription(event.target.value)}
            className="admin-input"
            aria-label="Pack description"
          />
        </label>
        <label className="mt-4 grid gap-2 text-sm text-[var(--admin-muted)]">
          Approved question ids
          <textarea
            value={questionIdsText}
            onChange={(event) => setQuestionIdsText(event.target.value)}
            className="admin-input min-h-32 font-mono text-xs"
            placeholder="Paste 20 approved question ids, one per line"
            aria-label="Approved question ids"
          />
        </label>
        <div className="mt-3 flex flex-wrap items-center gap-3">
          <button
            type="button"
            onClick={() => {
              publishPack().catch(() => {});
            }}
            disabled={!canPublishPack}
            className="admin-button admin-button-primary disabled:opacity-60"
          >
            <FileText className="h-4 w-4" aria-hidden="true" />
            {pendingAction === "publish" ? "Publishing..." : "Publish pack"}
          </button>
          <span className="text-sm text-[var(--admin-muted)]">
            {questionIds.length}/20 questions
          </span>
        </div>
      </div>

      <div className="mt-8 border-t border-[var(--admin-border)] pt-6">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <History className="h-4 w-4 text-[var(--admin-muted)]" aria-hidden="true" />
            <h3 className="text-sm font-semibold text-[var(--admin-text)]">
              Recent audit
            </h3>
          </div>
          <button
            type="button"
            onClick={() => {
              loadAuditLog(0).catch(() => {});
            }}
            disabled={!canLoadAudit}
            className="admin-button admin-button-secondary disabled:opacity-60"
          >
            <History className="h-4 w-4" aria-hidden="true" />
            {pendingAction === "audit" ? "Loading..." : "Load audit"}
          </button>
        </div>
        <div className="mt-4 grid gap-4 md:grid-cols-2">
          <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
            Audit action
            <input
              value={auditActionFilter}
              onChange={(event) => setAuditActionFilter(event.target.value)}
              className="admin-input"
              placeholder="Optional action filter"
              aria-label="Audit action"
            />
          </label>
          <label className="grid gap-2 text-sm text-[var(--admin-muted)]">
            Audit entity type
            <input
              value={auditEntityType}
              onChange={(event) => setAuditEntityType(event.target.value)}
              className="admin-input"
              placeholder="Optional entity type"
              aria-label="Audit entity type"
            />
          </label>
        </div>
        <div className="mt-4 grid gap-2">
          {auditRows.length === 0 ? (
            <p className="text-sm text-[var(--admin-muted)]">
              Load recent game audit rows after setup or host actions.
            </p>
          ) : (
            <>
              {auditRows.map((row) => (
                <article
                  key={row.id}
                  className={`rounded-md border bg-[var(--admin-bg)] p-3 ${
                    selectedAuditRow?.id === row.id
                      ? "border-[var(--admin-accent)]"
                      : "border-[var(--admin-border)]"
                  }`}
                >
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="text-sm font-semibold text-[var(--admin-text)]">
                      {row.action}
                    </p>
                    <time className="text-xs text-[var(--admin-muted)]">
                      {row.createdAt}
                    </time>
                  </div>
                  <p className="mt-1 text-xs text-[var(--admin-muted)]">
                    {row.entityType}
                    {row.entityId ? ` / ${row.entityId}` : ""}
                  </p>
                  <div className="mt-3 flex flex-wrap items-center gap-2">
                    <button
                      type="button"
                      onClick={() => setSelectedAuditRowId(row.id)}
                      className="admin-button admin-button-secondary"
                    >
                      <Eye className="h-4 w-4" aria-hidden="true" />
                      Inspect audit
                    </button>
                    {row.actorId ? (
                      <span className="text-xs text-[var(--admin-muted)]">
                        Actor {row.actorId}
                      </span>
                    ) : null}
                  </div>
                </article>
              ))}
              {selectedAuditRow ? (
                <section className="rounded-md border border-[var(--admin-border)] bg-[var(--admin-bg)] p-4">
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-muted)]">
                        Audit detail
                      </p>
                      <h4 className="mt-1 text-sm font-semibold text-[var(--admin-text)]">
                        {selectedAuditRow.action}
                      </h4>
                    </div>
                    <time className="text-xs text-[var(--admin-muted)]">
                      {selectedAuditRow.createdAt}
                    </time>
                  </div>
                  <dl className="mt-3 grid gap-3 text-xs text-[var(--admin-muted)] md:grid-cols-3">
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Entity
                      </dt>
                      <dd>{selectedAuditRow.entityType}</dd>
                    </div>
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Entity id
                      </dt>
                      <dd className="break-all">
                        {selectedAuditRow.entityId ?? "None"}
                      </dd>
                    </div>
                    <div>
                      <dt className="font-semibold text-[var(--admin-text)]">
                        Actor id
                      </dt>
                      <dd className="break-all">
                        {selectedAuditRow.actorId ?? "System"}
                      </dd>
                    </div>
                  </dl>
                  <pre className="mt-4 max-h-80 overflow-auto rounded-md bg-slate-950 p-4 text-xs leading-5 text-slate-100">
                    {JSON.stringify(selectedAuditRow.after ?? {}, null, 2)}
                  </pre>
                </section>
              ) : null}
              <div className="flex flex-wrap items-center justify-between gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => {
                    loadAuditLog(
                      Math.max(0, auditOffset - GAME_ADMIN_PAGE_SIZE),
                    ).catch(() => {});
                  }}
                  disabled={auditOffset === 0 || pendingAction != null}
                  className="admin-button admin-button-secondary disabled:opacity-60"
                >
                  Previous audit
                </button>
                <span className="text-xs text-[var(--admin-muted)]">
                  Showing {auditOffset + 1}-{auditOffset + auditRows.length}
                </span>
                <button
                  type="button"
                  onClick={() => {
                    loadAuditLog(auditOffset + GAME_ADMIN_PAGE_SIZE).catch(
                      () => {},
                    );
                  }}
                  disabled={
                    auditRows.length < GAME_ADMIN_PAGE_SIZE ||
                    pendingAction != null
                  }
                  className="admin-button admin-button-secondary disabled:opacity-60"
                >
                  Next audit
                </button>
              </div>
            </>
          )}
        </div>
      </div>

      <p className="mt-4 text-sm text-[var(--admin-muted)]" role="status">
        {status}
      </p>
    </section>
  );
}

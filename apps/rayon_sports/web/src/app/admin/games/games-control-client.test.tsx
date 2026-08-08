import {
  fireEvent,
  render,
  screen,
  waitFor,
  within,
} from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import {
  GameRuntimeRequestError,
  type GamePlannerOptions,
  type ManagedGameSession,
} from "@/lib/game-runtime";
import {
  crossClientFixture,
  managedSessionFromState,
} from "@/test-support/live-games-v2-cross-client-fixture";
import { GamesControlClient } from "./games-control-client";

const questions = Array.from({ length: 20 }, (_, index) => ({
  id: `question-${index + 1}`,
  prompt: `Approved club question ${index + 1}`,
  category: "club_history",
  difficulty: "medium",
  language: "en",
  approvedAt: "2026-07-30T13:00:00.000Z",
  sourceTitle: "Official club archive",
  sourceUrl: "https://example.com/archive",
  sourceTrustTier: "official",
}));

const plannerOptions: GamePlannerOptions = {
  clubId: 24,
  serverTime: "2026-07-30T15:00:00.000Z",
  packs: [
    {
      id: "pack-1",
      title: "Rayon Matchday 20",
      description: "Approved matchday round",
      questionCount: 20,
      publishedAt: "2026-07-30T14:00:00.000Z",
    },
  ],
  questions,
  displays: [
    {
      id: "display-1",
      name: "Main stand screen",
      scopeType: "venue",
      venueId: "venue-1",
      pairingStatus: "paired",
      health: "online",
      assignedSessionId: null,
    },
  ],
  organizers: [
    {
      userId: "organizer-1",
      name: "Claire Matchday",
      venueId: null,
    },
  ],
  allowedEligibilityScopes: ["club_membership", "home_owner", "venue"],
};

function managedSession(
  overrides: Partial<ManagedGameSession> = {},
): ManagedGameSession {
  return {
    clubId: 24,
    id: "session-1",
    title: "Rayon Matchday Quiz",
    packTitle: "Rayon Matchday 20",
    phase: "scheduled",
    sessionVersion: 3,
    questionVersion: 0,
    eventSequence: 2,
    serverTime: "2026-07-30T15:00:00.000Z",
    phaseDeadline: null,
    scheduledStartAt: "2026-07-31T17:30:00.000Z",
    eligibilityScope: "club_membership",
    allowedActions: ["activated_lobby", "cancelled"],
    participantCount: 0,
    assignedDisplays: [],
    assignedOrganizers: [
      {
        name: "Current Admin",
        assignedAt: "2026-07-30T14:58:00.000Z",
      },
    ],
    currentQuestion: null,
    questions: [
      {
        id: "session-question-1",
        ordinal: 1,
        state: "queued",
        prompt: "First approved session question",
      },
      {
        id: "session-question-2",
        ordinal: 2,
        state: "queued",
        prompt: "Second approved session question",
      },
    ],
    lastEventAt: "2026-07-30T14:59:00.000Z",
    participantAggregate: {
      participantCount: 18,
      answerCount: 36,
      averageScore: 4.5,
    },
    projectionPreviews: {
      participant: {
        phase: "scheduled",
        sessionVersion: 3,
        questionVersion: 0,
      },
      tv: {
        phase: "scheduled",
        assignedDisplayCount: 0,
      },
    },
    ...overrides,
  };
}

function createActionClient() {
  const created = managedSession();
  return {
    getPlannerOptions: vi.fn().mockResolvedValue(plannerOptions),
    getManagedSessions: vi.fn().mockResolvedValue({
      clubId: 24,
      serverTime: "2026-07-30T15:00:00.000Z",
      canPlan: true,
      sessions: [created],
    }),
    createManagedSession: vi.fn().mockResolvedValue(created),
    transitionManagedSession: vi.fn().mockImplementation((input) =>
      Promise.resolve(
        managedSession({
          phase: input.requestedPhase,
          sessionVersion: 4,
          allowedActions:
            input.requestedPhase === "activated_lobby"
              ? ["question_open", "paused", "cancelled"]
              : [],
        }),
      ),
    ),
    reviewQuestionDraft: vi.fn().mockResolvedValue({
      draftId: "draft-1",
      decision: "approved",
      questionId: "approved-question-1",
    }),
    listQuestionDrafts: vi.fn().mockResolvedValue([
      {
        id: "draft-1",
        sourceId: "source-1",
        prompt: "Which verified fact belongs to Rayon Sports?",
        category: "club_knowledge",
        difficulty: "medium",
        language: "en",
        validationStatus: "pending_review",
        validationNotes: "",
        duplicatePromptCount: 0,
        hasDuplicatePrompt: false,
        similarPromptCount: 0,
        hasSimilarPrompt: false,
        duplicateRiskLevel: "none",
        normalizedPromptSignature:
          "which verified fact belongs to rayon sports",
        sourceTitle: "Rayon source",
        sourceUrl: null,
        sourceTrustTier: "official",
        citationFragment: "Rayon Sports verified club-history fact.",
        schemaVersion: "2026-08-01",
        generationMode: "ai_assisted" as const,
        modelName: "reviewed-draft-model",
        reviewedAt: null,
        reviewerName: null,
        qaChecks: {
          sourcePresent: true,
          citationPresent: true,
          sourceTrusted: true,
          schemaVersionPresent: true,
          modelMetadataPresent: true,
          promptLengthValid: true,
          exactDuplicateFree: true,
          normalizedDuplicateFree: true,
          ambiguitySignalsAbsent: true,
          answerConsistent: true,
          languageSupported: true,
          policyCompliant: true,
        },
        createdAt: "2026-07-02T10:00:00Z",
      },
    ]),
    publishQuestionPack: vi.fn().mockResolvedValue({
      packId: "pack-2",
      title: "Rayon 20-question round",
      status: "published",
      questionCount: 20,
    }),
    listAuditLog: vi.fn().mockResolvedValue([
      {
        id: "audit-1",
        action: "game_session_created",
        entityType: "game_session",
        entityId: "session-1",
        actorId: "private-actor",
        createdAt: "2026-07-02T10:00:00Z",
        after: {
          question_count: 20,
          tv_device_id: "display-1",
        },
      },
    ]),
    generateQuestionDrafts: vi.fn().mockResolvedValue({
      sourceId: "source-1",
      draftIds: ["draft-1", "draft-2"],
      mode: "ai_assisted" as const,
      count: 2,
    }),
  };
}

function renderSubject() {
  const actionClient = createActionClient();
  render(<GamesControlClient defaultClubId={24} actionClient={actionClient} />);
  return actionClient;
}

describe("GamesControlClient task-oriented operations", () => {
  it.each(crossClientFixture.states)(
    "GAME-QA-02 renders $id with the authoritative Admin phase/version and safe previews",
    async (state) => {
      const session = managedSessionFromState(state);
      const actionClient = createActionClient();
      actionClient.getManagedSessions.mockResolvedValue({
        clubId: 24,
        serverTime: session.serverTime,
        canPlan: true,
        sessions: [session],
      });
      render(
        <GamesControlClient defaultClubId={24} actionClient={actionClient} />,
      );

      fireEvent.click(screen.getByRole("tab", { name: "Live Control" }));
      fireEvent.click(
        screen.getByRole("button", { name: /load managed sessions/i }),
      );

      expect(
        await screen.findByText(
          `${state.admin_render_text} · version ${state.session_version}`,
        ),
      ).toBeInTheDocument();
      const participantPreview = screen.getByRole("region", {
        name: "Participant projection preview",
      });
      expect(
        within(participantPreview).getByText(state.admin_render_text),
      ).toBeInTheDocument();
      expect(
        within(participantPreview).getByText(
          `Session ${state.session_version} · question ${state.question_version}`,
        ),
      ).toBeInTheDocument();
      const tvPreview = screen.getByRole("region", {
        name: "TV projection preview",
      });
      expect(
        within(tvPreview).getByText(state.admin_render_text),
      ).toBeInTheDocument();
    },
  );

  it("starts in the session planner without routine raw-id controls", () => {
    renderSubject();

    expect(
      screen.getByRole("heading", { name: "Session Planner" }),
    ).toBeInTheDocument();
    expect(screen.getByText(/Club 24 · role scoped/)).toBeInTheDocument();
    expect(screen.queryByLabelText(/club id/i)).not.toBeInTheDocument();
    expect(screen.queryByLabelText(/session id/i)).not.toBeInTheDocument();
    expect(screen.queryByLabelText(/question.*id/i)).not.toBeInTheDocument();
    expect(screen.queryByLabelText(/device id/i)).not.toBeInTheDocument();
  });

  it("creates a reviewed plan from authorized pack and audience choices", async () => {
    const actionClient = renderSubject();

    fireEvent.click(
      screen.getByRole("button", { name: /load authorized choices/i }),
    );
    await screen.findByRole("option", { name: /Rayon Matchday 20/i });
    fireEvent.change(screen.getByLabelText(/scheduled start/i), {
      target: { value: "2026-07-31T17:30" },
    });
    fireEvent.click(screen.getByLabelText("Assign Claire Matchday"));
    fireEvent.click(
      screen.getByRole("button", { name: /review session plan/i }),
    );
    expect(screen.getByText("Reviewed plan")).toBeInTheDocument();

    fireEvent.click(
      screen.getByRole("button", { name: /confirm and create session/i }),
    );

    await waitFor(() => {
      expect(actionClient.createManagedSession).toHaveBeenCalledWith({
        packId: "pack-1",
        scheduledStartAt: "2026-07-31T15:30:00.000Z",
        eligibilityScope: "club_membership",
        displayIds: [],
        organizerUserIds: ["organizer-1"],
        idempotencyKey: expect.stringMatching(/^session-create-/),
      });
    });
    expect(
      screen.getByRole("heading", { name: "Live Control" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent(
      /created in scheduled/i,
    );
  });

  it("requires a named display for a venue-scoped plan", async () => {
    renderSubject();

    fireEvent.click(
      screen.getByRole("button", { name: /load authorized choices/i }),
    );
    await screen.findByLabelText(/eligible audience/i);
    fireEvent.change(screen.getByLabelText(/eligible audience/i), {
      target: { value: "venue" },
    });
    fireEvent.change(screen.getByLabelText(/scheduled start/i), {
      target: { value: "2026-07-31T17:30" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: /review session plan/i }),
    );
    expect(screen.getByRole("status")).toHaveTextContent(/required displays/i);

    fireEvent.click(screen.getByLabelText("Use Main stand screen"));
    fireEvent.click(
      screen.getByRole("button", { name: /review session plan/i }),
    );
    expect(screen.getByText("Reviewed plan")).toBeInTheDocument();
    expect(screen.getByText("1 selected")).toBeInTheDocument();
  });

  it("loads named sessions and applies a versioned reviewed transition", async () => {
    const actionClient = renderSubject();

    fireEvent.click(screen.getByRole("tab", { name: "Live Control" }));
    fireEvent.click(
      screen.getByRole("button", { name: /load managed sessions/i }),
    );
    await screen.findByText("Rayon Matchday Quiz");
    fireEvent.click(screen.getByRole("button", { name: /review open lobby/i }));
    expect(screen.getByText("Confirm Open lobby")).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", { name: /^confirm open lobby$/i }),
    );

    await waitFor(() => {
      expect(actionClient.transitionManagedSession).toHaveBeenCalledWith({
        sessionId: "session-1",
        requestedPhase: "activated_lobby",
        expectedSessionVersion: 3,
        idempotencyKey: expect.stringMatching(/^session-transition-/),
        sessionQuestionId: undefined,
        phaseDeadline: undefined,
        reason: undefined,
      });
    });
    expect(screen.getByRole("status")).toHaveTextContent(/version 4/i);
  });

  it("shows privacy-safe cross-surface previews and locks actions until a reconnect refresh", async () => {
    renderSubject();

    fireEvent.click(screen.getByRole("tab", { name: "Live Control" }));
    fireEvent.click(
      screen.getByRole("button", { name: /load managed sessions/i }),
    );
    await screen.findByText("Rayon Matchday Quiz");

    expect(
      screen.getByRole("region", { name: "Participant projection preview" }),
    ).toHaveTextContent("18 participants · 36 answers · 4.5 average score");
    expect(
      screen.getByRole("region", { name: "TV projection preview" }),
    ).toHaveTextContent("0 online");
    expect(screen.getByText("31–120 seconds")).toBeInTheDocument();
    expect(document.body).not.toHaveTextContent(
      /correct answer|private member|device credential/i,
    );

    fireEvent(window, new Event("offline"));
    expect(screen.getByTestId("live-connection-health")).toHaveTextContent(
      /offline.*actions are locked/i,
    );
    expect(
      screen.getByRole("button", { name: /review open lobby/i }),
    ).toBeDisabled();

    fireEvent(window, new Event("online"));
    expect(screen.getByTestId("live-connection-health")).toHaveTextContent(
      /connection restored.*refresh authoritative state/i,
    );
    expect(
      screen.getByRole("button", { name: /review open lobby/i }),
    ).toBeDisabled();
    fireEvent.click(
      screen.getByRole("button", { name: /reconnect and refresh/i }),
    );
    await waitFor(() => {
      expect(
        screen.getByRole("button", { name: /review open lobby/i }),
      ).toBeEnabled();
    });
  });

  it("opens the next ordered question without asking for its id", async () => {
    const actionClient = createActionClient();
    actionClient.getManagedSessions.mockResolvedValue({
      clubId: 24,
      serverTime: "2026-07-30T15:00:00.000Z",
      canPlan: true,
      sessions: [
        managedSession({
          phase: "activated_lobby",
          allowedActions: ["question_open", "paused", "cancelled"],
        }),
      ],
    });
    render(
      <GamesControlClient defaultClubId={24} actionClient={actionClient} />,
    );

    fireEvent.click(screen.getByRole("tab", { name: "Live Control" }));
    fireEvent.click(
      screen.getByRole("button", { name: /load managed sessions/i }),
    );
    await screen
      .findByText("First approved session question", {
        exact: false,
      })
      .catch(() => null);
    fireEvent.click(
      screen.getByRole("button", { name: /review open question/i }),
    );
    fireEvent.change(screen.getByLabelText("Answer window"), {
      target: { value: "30" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: /^confirm open question$/i }),
    );

    await waitFor(() => {
      expect(actionClient.transitionManagedSession).toHaveBeenCalledWith(
        expect.objectContaining({
          requestedPhase: "question_open",
          expectedSessionVersion: 3,
          sessionQuestionId: "session-question-1",
          phaseDeadline: expect.stringMatching(/Z$/),
        }),
      );
    });
    expect(screen.queryByLabelText(/question.*id/i)).not.toBeInTheDocument();
  });

  it("reviews a selected draft card instead of accepting a draft id", async () => {
    const actionClient = renderSubject();
    fireEvent.click(screen.getByRole("tab", { name: "Content Studio" }));
    fireEvent.change(screen.getByLabelText(/draft search/i), {
      target: { value: "Rayon" },
    });
    fireEvent.click(screen.getByRole("button", { name: /load drafts/i }));

    const draft = await screen.findByRole("button", {
      name: /Which verified fact belongs to Rayon Sports/i,
    });
    fireEvent.click(draft);
    expect(
      screen.getByText("AI-assisted · reviewed-draft-model"),
    ).toBeInTheDocument();
    expect(screen.getByText("All checks pass")).toBeInTheDocument();
    expect(screen.getByText("Rayon source")).toBeInTheDocument();
    expect(
      screen.getByText("Citation: Rayon Sports verified club-history fact."),
    ).toBeInTheDocument();
    expect(screen.getByText("Schema: 2026-08-01")).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText(/review notes/i), {
      target: { value: "Official source confirmed." },
    });
    fireEvent.click(
      screen.getByRole("button", { name: /review selected draft/i }),
    );

    await waitFor(() => {
      expect(actionClient.reviewQuestionDraft).toHaveBeenCalledWith({
        clubId: 24,
        draftId: "draft-1",
        decision: "approved",
        notes: "Official source confirmed.",
      });
    });
    expect(screen.queryByLabelText(/draft id/i)).not.toBeInTheDocument();
  });

  it("builds a pack by selecting 20 approved prompts", async () => {
    const actionClient = renderSubject();
    fireEvent.click(screen.getByRole("tab", { name: "Content Studio" }));
    fireEvent.click(
      screen.getByRole("button", { name: /load approved content/i }),
    );

    await screen.findByLabelText("Select question: Approved club question 1");
    for (const question of questions) {
      fireEvent.click(
        screen.getByLabelText(`Select question: ${question.prompt}`),
      );
    }
    expect(screen.getByText("20 of 20 selected")).toBeInTheDocument();
    expect(screen.getByText("Mobile preview")).toBeInTheDocument();
    expect(screen.getByText("TV preview")).toBeInTheDocument();
    fireEvent.click(
      screen.getByRole("button", {
        name: /review and lock mobile\/TV previews/i,
      }),
    );
    await screen.findByRole("button", {
      name: /mobile and TV previews reviewed/i,
    });
    fireEvent.click(
      screen.getByRole("button", { name: /publish reviewed pack/i }),
    );

    await waitFor(() => {
      expect(actionClient.publishQuestionPack).toHaveBeenCalledWith({
        clubId: 24,
        title: "Rayon 20-question round",
        description: undefined,
        questionIds: questions.map((question) => question.id),
        previewFingerprint: expect.stringMatching(/^[0-9a-f]{64}$/),
      });
    });
    expect(
      screen.queryByLabelText(/approved question ids/i),
    ).not.toBeInTheDocument();
  });

  it("generates source-backed drafts and loads privacy-filtered audit details", async () => {
    const actionClient = renderSubject();
    fireEvent.click(screen.getByRole("tab", { name: "Content Studio" }));
    fireEvent.change(screen.getByLabelText(/verified source fact/i), {
      target: { value: "Rayon Sports won the documented match 2–1." },
    });
    fireEvent.change(screen.getByLabelText(/draft count/i), {
      target: { value: "2" },
    });
    fireEvent.click(
      screen.getByRole("button", { name: /generate review-gated drafts/i }),
    );

    await waitFor(() => {
      expect(actionClient.generateQuestionDrafts).toHaveBeenCalledWith({
        clubId: 24,
        sourceTitle: "Rayon matchday source",
        extractedFact: "Rayon Sports won the documented match 2–1.",
        sourceUrl: undefined,
        sourceDate: undefined,
        trustTier: "review_required",
        count: 2,
        language: "en",
        category: "club_knowledge",
      });
    });

    fireEvent.click(screen.getByRole("button", { name: /load audit/i }));
    await screen.findByText("game_session_created");
    expect(screen.getByText(/question_count/)).toBeInTheDocument();
    expect(screen.queryByText("private-actor")).not.toBeInTheDocument();
  });

  it("renders controlled conflict recovery copy without provider diagnostics", async () => {
    const actionClient = createActionClient();
    actionClient.getManagedSessions.mockRejectedValue(
      new GameRuntimeRequestError(
        "conflict",
        "private provider version conflict",
        409,
      ),
    );
    render(
      <GamesControlClient defaultClubId={24} actionClient={actionClient} />,
    );

    fireEvent.click(screen.getByRole("tab", { name: "Live Control" }));
    fireEvent.click(
      screen.getByRole("button", { name: /load managed sessions/i }),
    );

    await waitFor(() => {
      expect(screen.getByRole("status")).toHaveTextContent(
        "Game operations changed. Reload the current session before retrying.",
      );
    });
    expect(screen.getByRole("status")).not.toHaveTextContent(
      "private provider",
    );
  });
});

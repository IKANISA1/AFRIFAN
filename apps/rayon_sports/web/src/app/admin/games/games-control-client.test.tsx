import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { GamesControlClient } from "./games-control-client";

function renderSubject() {
  const actionClient = {
    createSession: vi.fn().mockResolvedValue({
      sessionId: "session-1",
      joinCode: "RAYON24",
      questionTotal: 20,
      firstSessionQuestionId: "question-1",
      tvDeviceId: "tv-1",
    }),
    pairTvDevice: vi.fn().mockResolvedValue({
      tvDeviceId: "tv-1",
      pairingCode: "SCREEN24",
      sessionId: "session-1",
    }),
    reviewQuestionDraft: vi.fn().mockResolvedValue({
      draftId: "draft-1",
      decision: "approved",
      questionId: "question-approved-1",
    }),
    listQuestionDrafts: vi.fn().mockResolvedValue([
      {
        id: "draft-queue-1",
        sourceId: "source-1",
        prompt: "Which verified fact belongs to Rayon Sports?",
        category: "club_knowledge",
        difficulty: "medium",
        language: "en",
        validationStatus: "pending_review",
        validationNotes: "",
        duplicatePromptCount: 2,
        hasDuplicatePrompt: true,
        similarPromptCount: 3,
        hasSimilarPrompt: true,
        duplicateRiskLevel: "exact",
        normalizedPromptSignature: "which verified fact belongs to rayon sports",
        sourceTitle: "Rayon source",
        sourceUrl: null,
        sourceTrustTier: "official",
        createdAt: "2026-07-02T10:00:00Z",
      },
    ]),
    publishQuestionPack: vi.fn().mockResolvedValue({
      packId: "pack-1",
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
        actorId: "admin-1",
        createdAt: "2026-07-02T10:00:00Z",
        after: {
          question_count: 20,
          tv_device_id: "tv-1",
        },
      },
    ]),
    openQuestion: vi.fn().mockResolvedValue({ success: true }),
    revealQuestion: vi.fn().mockResolvedValue({ success: true }),
    advanceQuestion: vi.fn().mockResolvedValue({
      sessionId: "session-1",
      previousSessionQuestionId: "question-1",
      nextSessionQuestionId: "question-2",
      status: "live",
      isComplete: false,
    }),
    closeSession: vi.fn().mockResolvedValue({
      sessionId: "session-1",
      status: "complete",
      closedQuestionCount: 19,
    }),
    generateQuestionDrafts: vi.fn().mockResolvedValue({
      sourceId: "source-1",
      draftIds: ["draft-1", "draft-2"],
      mode: "ai_assisted",
      count: 2,
    }),
  };

  render(
    <GamesControlClient
      defaultClubId={24}
      defaultSessionQuestionId="question-1"
      actionClient={actionClient}
    />,
  );

  return actionClient;
}

describe("GamesControlClient", () => {
  it("creates a game session through the injected game action client", async () => {
    const actionClient = renderSubject();

    fireEvent.click(screen.getByRole("button", { name: /create session/i }));

    await waitFor(() => {
      expect(actionClient.createSession).toHaveBeenCalledWith({
        clubId: 24,
        title: "Rayon matchday quiz",
        packId: undefined,
        tvDeviceId: undefined,
        joinCode: undefined,
      });
    });
    expect(screen.getByLabelText(/session id/i)).toHaveValue("session-1");
    expect(screen.getByLabelText(/join code/i)).toHaveValue("RAYON24");
    expect(screen.getByRole("status")).toHaveTextContent(
      "Session created with code RAYON24. 20 question(s) loaded.",
    );
  });

  it("pairs a TV display through the injected game action client", async () => {
    const actionClient = renderSubject();

    fireEvent.change(screen.getByLabelText(/pairing code/i), {
      target: { value: "SCREEN24" },
    });
    fireEvent.click(screen.getByRole("button", { name: /pair tv display/i }));

    await waitFor(() => {
      expect(actionClient.pairTvDevice).toHaveBeenCalledWith({
        clubId: 24,
        deviceLabel: "Main TV",
        pairingCode: "SCREEN24",
        sessionId: undefined,
      });
    });
    expect(screen.getByLabelText(/tv device id/i)).toHaveValue("tv-1");
    expect(screen.getByRole("status")).toHaveTextContent(
      "TV display paired with code SCREEN24.",
    );
  });

  it("reviews a question draft through the injected game action client", async () => {
    const actionClient = renderSubject();

    fireEvent.change(screen.getByLabelText(/question draft id/i), {
      target: { value: "draft-1" },
    });
    fireEvent.change(screen.getByLabelText(/review notes/i), {
      target: { value: "Looks ready." },
    });
    fireEvent.click(screen.getByRole("button", { name: /review draft/i }));

    await waitFor(() => {
      expect(actionClient.reviewQuestionDraft).toHaveBeenCalledWith({
        clubId: 24,
        draftId: "draft-1",
        decision: "approved",
        notes: "Looks ready.",
      });
    });
    expect(screen.getByRole("status")).toHaveTextContent(
      "Draft approved; approved question question-approved-1.",
    );
  });

  it("loads the question draft queue and selects a draft for review", async () => {
    const actionClient = renderSubject();

    fireEvent.change(screen.getByLabelText(/draft search/i), {
      target: { value: "Rayon" },
    });
    fireEvent.click(screen.getByRole("button", { name: /load drafts/i }));

    await waitFor(() => {
      expect(actionClient.listQuestionDrafts).toHaveBeenCalledWith({
        clubId: 24,
        status: "pending_review",
        search: "Rayon",
        limit: 25,
        offset: 0,
      });
    });
    expect(screen.getByText("Which verified fact belongs to Rayon Sports?"))
      .toBeInTheDocument();
    expect(screen.getByText("Exact duplicate (2)")).toBeInTheDocument();
    expect(screen.getByText(/official/)).toBeInTheDocument();
    expect(screen.getByText(/risk: exact/)).toBeInTheDocument();
    expect(screen.getByLabelText(/question draft id/i)).toHaveValue(
      "draft-queue-1",
    );
    expect(screen.getByRole("status")).toHaveTextContent(
      "Loaded 1 draft row(s) from 1.",
    );
  });

  it("generates review-gated question drafts through the injected game action client", async () => {
    const actionClient = renderSubject();

    fireEvent.change(screen.getByLabelText(/source fact/i), {
      target: { value: "Rayon Sports won a documented match 2-1." },
    });
    fireEvent.change(screen.getByLabelText(/draft count/i), {
      target: { value: "2" },
    });
    fireEvent.click(screen.getByRole("button", { name: /generate drafts/i }));

    await waitFor(() => {
      expect(actionClient.generateQuestionDrafts).toHaveBeenCalledWith({
        clubId: 24,
        sourceTitle: "Rayon matchday source",
        extractedFact: "Rayon Sports won a documented match 2-1.",
        sourceUrl: undefined,
        sourceDate: undefined,
        trustTier: "review_required",
        count: 2,
        language: "en",
        category: "club_knowledge",
      });
    });
    expect(screen.getByLabelText(/question draft id/i)).toHaveValue("draft-1");
    expect(screen.getByText("draft-2")).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent(
      "Generated 2 draft question(s) for review from source source-1.",
    );
  });

  it("publishes a 20-question pack through the injected game action client", async () => {
    const actionClient = renderSubject();
    const questionIds = Array.from(
      { length: 20 },
      (_, index) => `question-${index + 1}`,
    );

    fireEvent.change(screen.getByLabelText(/approved question ids/i), {
      target: { value: questionIds.join("\n") },
    });
    fireEvent.click(screen.getByRole("button", { name: /publish pack/i }));

    await waitFor(() => {
      expect(actionClient.publishQuestionPack).toHaveBeenCalledWith({
        clubId: 24,
        title: "Rayon 20-question round",
        description: undefined,
        templateId: undefined,
        questionIds,
      });
    });
    expect(screen.getByLabelText(/question pack id/i)).toHaveValue("pack-1");
    expect(screen.getByRole("status")).toHaveTextContent(
      "Pack published: Rayon 20-question round (20 questions).",
    );
  });

  it("loads recent audit rows through the injected game action client", async () => {
    const actionClient = renderSubject();

    fireEvent.change(screen.getByLabelText(/audit action/i), {
      target: { value: "game_session_created" },
    });
    fireEvent.change(screen.getByLabelText(/audit entity type/i), {
      target: { value: "game_session" },
    });
    fireEvent.click(screen.getByRole("button", { name: /load audit/i }));

    await waitFor(() => {
      expect(actionClient.listAuditLog).toHaveBeenCalledWith({
        clubId: 24,
        limit: 25,
        offset: 0,
        actionFilter: "game_session_created",
        entityType: "game_session",
      });
    });
    expect(screen.getAllByText("game_session_created").length).toBeGreaterThan(0);
    expect(screen.getByText("Audit detail")).toBeInTheDocument();
    expect(screen.getByText("Actor admin-1")).toBeInTheDocument();
    expect(screen.getByText(/question_count/)).toBeInTheDocument();
    expect(screen.getByText(/tv_device_id/)).toBeInTheDocument();
    expect(screen.getByRole("status")).toHaveTextContent(
      "Loaded 1 audit row(s) from 1.",
    );
  });

  it("opens a session question through the injected game action client", async () => {
    const actionClient = renderSubject();

    fireEvent.click(screen.getByRole("button", { name: /open question/i }));

    await waitFor(() => {
      expect(actionClient.openQuestion).toHaveBeenCalledWith({
        clubId: 24,
        sessionQuestionId: "question-1",
      });
    });
    expect(screen.getByRole("status")).toHaveTextContent(
      "Question opened for answers.",
    );
  });

  it("reveals a session question through the injected game action client", async () => {
    const actionClient = renderSubject();

    fireEvent.click(screen.getByRole("button", { name: /reveal question/i }));

    await waitFor(() => {
      expect(actionClient.revealQuestion).toHaveBeenCalledWith({
        clubId: 24,
        sessionQuestionId: "question-1",
      });
    });
    expect(screen.getByRole("status")).toHaveTextContent(
      "Question revealed to the display.",
    );
  });

  it("advances to the next session question through the injected game action client", async () => {
    const actionClient = renderSubject();

    fireEvent.click(screen.getByRole("button", { name: /advance question/i }));

    await waitFor(() => {
      expect(actionClient.advanceQuestion).toHaveBeenCalledWith({
        clubId: 24,
        sessionQuestionId: "question-1",
      });
    });
    expect(screen.getByLabelText(/session-question id/i)).toHaveValue(
      "question-2",
    );
    expect(screen.getByRole("status")).toHaveTextContent(
      "Advanced to next question question-2.",
    );
  });

  it("closes a game session through the injected game action client", async () => {
    const actionClient = renderSubject();

    fireEvent.change(screen.getByLabelText(/session id/i), {
      target: { value: "session-1" },
    });
    fireEvent.click(screen.getByRole("button", { name: /close session/i }));

    await waitFor(() => {
      expect(actionClient.closeSession).toHaveBeenCalledWith({
        clubId: 24,
        sessionId: "session-1",
      });
    });
    expect(screen.getByLabelText(/session-question id/i)).toHaveValue("");
    expect(screen.getByRole("status")).toHaveTextContent(
      "Session closed. 19 question(s) closed.",
    );
  });

  it("shows recoverable errors from game actions", async () => {
    const actionClient = {
      createSession: vi.fn().mockResolvedValue({
        sessionId: "session-1",
        joinCode: "RAYON24",
        questionTotal: 20,
        firstSessionQuestionId: "question-1",
        tvDeviceId: null,
      }),
      pairTvDevice: vi.fn().mockResolvedValue({
        tvDeviceId: "tv-1",
        pairingCode: "SCREEN24",
        sessionId: null,
      }),
      reviewQuestionDraft: vi.fn().mockResolvedValue({
        draftId: "draft-1",
        decision: "approved",
        questionId: "question-approved-1",
      }),
      listQuestionDrafts: vi.fn().mockResolvedValue([]),
      publishQuestionPack: vi.fn().mockResolvedValue({
        packId: "pack-1",
        title: "Rayon 20-question round",
        status: "published",
        questionCount: 20,
      }),
      listAuditLog: vi.fn().mockResolvedValue([]),
      openQuestion: vi.fn().mockRejectedValue(new Error("Club admin required.")),
      revealQuestion: vi.fn().mockResolvedValue({ success: true }),
      advanceQuestion: vi.fn().mockResolvedValue({
        sessionId: "session-1",
        previousSessionQuestionId: "question-1",
        nextSessionQuestionId: null,
        status: "complete",
        isComplete: true,
      }),
      closeSession: vi.fn().mockResolvedValue({
        sessionId: "session-1",
        status: "complete",
        closedQuestionCount: 0,
      }),
      generateQuestionDrafts: vi.fn().mockResolvedValue({
        sourceId: "source-1",
        draftIds: [],
        mode: "ai_assisted",
        count: 0,
      }),
    };
    render(
      <GamesControlClient
        defaultClubId={24}
        defaultSessionQuestionId="question-1"
        actionClient={actionClient}
      />,
    );

    fireEvent.click(screen.getByRole("button", { name: /open question/i }));

    await waitFor(() => {
      expect(screen.getByRole("status")).toHaveTextContent(
        "Club admin required.",
      );
    });
  });
});

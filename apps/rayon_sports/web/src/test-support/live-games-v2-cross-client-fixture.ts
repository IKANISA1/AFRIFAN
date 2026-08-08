import { existsSync, readFileSync } from "node:fs";
import { dirname, parse, resolve } from "node:path";
import type { ManagedGameSession } from "@/lib/game-runtime";

export type CrossClientState = {
  id: string;
  phase: string;
  session_version: number;
  question_version: number;
  event_sequence: number;
  question_ordinal: number | null;
  question_prompt: string | null;
  correct_option_key: string | null;
  participant_submit_enabled: boolean;
  participant_render_text: string;
  organizer_render_text: string;
  tv_render_text: string;
  admin_render_text: string;
};

export type CrossClientFixture = {
  schema_version: string;
  contract: "GAME-QA-02";
  session_id: string;
  session_title: string;
  states: CrossClientState[];
  environment_boundary: {
    deterministic_local_fixture: true;
    shared_or_live_session_claimed: false;
    physical_device_claimed: false;
    release_claimed: false;
  };
};

export const crossClientFixture = JSON.parse(
  readFileSync(findCrossClientFixture(), "utf8"),
) as CrossClientFixture;

function findCrossClientFixture() {
  let directory = process.cwd();
  const root = parse(directory).root;
  while (true) {
    const candidate = resolve(
      directory,
      "docs/architecture/live-games-v2-cross-client-fixtures.json",
    );
    if (existsSync(candidate)) return candidate;
    if (directory === root) {
      throw new Error("Unable to locate the GAME-QA-02 fixture.");
    }
    directory = dirname(directory);
  }
}

export function managedSessionFromState(
  state: CrossClientState,
): ManagedGameSession {
  const question =
    state.question_prompt == null || state.question_ordinal == null
      ? null
      : {
          id: `question-${state.question_ordinal}`,
          ordinal: state.question_ordinal,
          state: state.phase,
          prompt: state.question_prompt,
        };
  return {
    clubId: 24,
    id: crossClientFixture.session_id,
    title: crossClientFixture.session_title,
    packTitle: "Approved matchday pack",
    phase: state.phase,
    sessionVersion: state.session_version,
    questionVersion: state.question_version,
    eventSequence: state.event_sequence,
    serverTime: `2026-08-01T14:00:0${state.event_sequence}.000Z`,
    phaseDeadline:
      state.phase === "question_open" ? "2026-08-01T14:00:30.000Z" : null,
    scheduledStartAt: "2026-08-01T14:00:00.000Z",
    eligibilityScope: "club_membership",
    allowedActions: [],
    participantCount: 18,
    assignedDisplays: [
      {
        id: "display-1",
        name: "Main stand screen",
        scopeType: "venue",
        pairingStatus: "paired",
        health: "online",
        lastSeenAt: "2026-08-01T14:00:00.000Z",
      },
    ],
    assignedOrganizers: [
      {
        name: "Current Admin",
        assignedAt: "2026-08-01T13:55:00.000Z",
      },
    ],
    currentQuestion: question,
    questions: question == null ? [] : [question],
    lastEventAt: `2026-08-01T14:00:0${state.event_sequence}.000Z`,
    participantAggregate: {
      participantCount: 18,
      answerCount: state.event_sequence * 3,
      averageScore: state.event_sequence,
    },
    projectionPreviews: {
      participant: {
        phase: state.phase,
        sessionVersion: state.session_version,
        questionVersion: state.question_version,
      },
      tv: {
        phase: state.phase,
        assignedDisplayCount: 1,
      },
    },
  };
}

export function managedSessionWireFromState(state: CrossClientState) {
  const session = managedSessionFromState(state);
  return {
    club_id: session.clubId,
    session_id: session.id,
    session_title: session.title,
    pack_title: session.packTitle,
    phase: session.phase,
    session_version: session.sessionVersion,
    question_version: session.questionVersion,
    event_sequence: session.eventSequence,
    server_time: session.serverTime,
    phase_deadline: session.phaseDeadline,
    scheduled_start_at: session.scheduledStartAt,
    eligibility_scope: session.eligibilityScope,
    allowed_actions: session.allowedActions,
    participant_count: session.participantCount,
    assigned_displays: session.assignedDisplays.map((display) => ({
      display_id: display.id,
      display_name: display.name,
      scope_type: display.scopeType,
      pairing_status: display.pairingStatus,
      health: display.health,
      last_seen_at: display.lastSeenAt,
    })),
    assigned_organizers: session.assignedOrganizers.map((organizer) => ({
      display_name: organizer.name,
      assigned_at: organizer.assignedAt,
    })),
    current_question_control:
      session.currentQuestion == null
        ? null
        : {
            id: session.currentQuestion.id,
            ordinal: session.currentQuestion.ordinal,
            state: session.currentQuestion.state,
            prompt: session.currentQuestion.prompt,
          },
    question_controls: session.questions.map((question) => ({
      id: question.id,
      ordinal: question.ordinal,
      state: question.state,
      prompt: question.prompt,
    })),
    freshness: { last_event_at: session.lastEventAt },
    participant_aggregate: {
      participant_count: session.participantAggregate?.participantCount,
      answer_count: session.participantAggregate?.answerCount,
      average_score: session.participantAggregate?.averageScore,
    },
    projection_previews: {
      participant: {
        phase: session.projectionPreviews?.participant.phase,
        session_version: session.projectionPreviews?.participant.sessionVersion,
        question_version:
          session.projectionPreviews?.participant.questionVersion,
      },
      tv: {
        phase: session.projectionPreviews?.tv.phase,
        assigned_display_count:
          session.projectionPreviews?.tv.assignedDisplayCount,
      },
    },
  };
}

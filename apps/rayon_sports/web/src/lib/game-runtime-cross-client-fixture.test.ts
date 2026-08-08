import { describe, expect, it, vi } from "vitest";
import {
  crossClientFixture,
  managedSessionWireFromState,
} from "@/test-support/live-games-v2-cross-client-fixture";
import { createGameRuntimeClient } from "./game-runtime";

describe("GAME-QA-02 Admin runtime convergence fixture", () => {
  it.each(crossClientFixture.states)(
    "parses $id at the authoritative phase and version",
    async (state) => {
      const fetcher = vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          success: true,
          data: {
            club_id: 24,
            server_time: `2026-08-01T14:00:0${state.event_sequence}.000Z`,
            can_plan: true,
            sessions: [managedSessionWireFromState(state)],
          },
        }),
      });
      const client = createGameRuntimeClient({ fetcher });

      const session = (await client.getManagedSessions()).sessions[0];

      expect(session).toMatchObject({
        id: crossClientFixture.session_id,
        phase: state.phase,
        sessionVersion: state.session_version,
        questionVersion: state.question_version,
        eventSequence: state.event_sequence,
        projectionPreviews: {
          participant: {
            phase: state.phase,
            sessionVersion: state.session_version,
            questionVersion: state.question_version,
          },
          tv: { phase: state.phase, assignedDisplayCount: 1 },
        },
      });
      expect(session?.currentQuestion?.prompt ?? null).toBe(
        state.question_prompt,
      );
    },
  );
});

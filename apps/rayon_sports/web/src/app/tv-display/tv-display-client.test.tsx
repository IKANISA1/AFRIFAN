import { render, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  createDemoTvSessionState,
  createGameRuntimeClient,
} from "@/lib/game-runtime";
import { getBrowserSupabase } from "@/lib/supabase/browser";
import { TvDisplayClient } from "./tv-display-client";

vi.mock("@/lib/supabase/browser", () => ({
  getBrowserSupabase: vi.fn(),
}));

vi.mock("@/lib/game-runtime", async () => {
  const actual = await vi.importActual<typeof import("@/lib/game-runtime")>(
    "@/lib/game-runtime",
  );
  return {
    ...actual,
    createGameRuntimeClient: vi.fn(),
  };
});

describe("TvDisplayClient", () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  it("subscribes to scoped realtime changes and refreshes TV-safe state", async () => {
    const getTvState = vi.fn().mockResolvedValue(createDemoTvSessionState());
    vi.mocked(createGameRuntimeClient).mockReturnValue(
      { getTvState } as unknown as ReturnType<typeof createGameRuntimeClient>,
    );

    const callbacks: Array<() => void> = [];
    const channel = {
      on: vi.fn((_event, _config, callback: () => void) => {
        callbacks.push(callback);
        return channel;
      }),
      subscribe: vi.fn((callback?: (status: string) => void) => {
        callback?.("SUBSCRIBED");
        return channel;
      }),
      unsubscribe: vi.fn(),
    };
    const supabase = {
      channel: vi.fn(() => channel),
      removeChannel: vi.fn(),
    };
    vi.mocked(getBrowserSupabase).mockReturnValue(
      supabase as ReturnType<typeof getBrowserSupabase>,
    );

    const { unmount } = render(
      <TvDisplayClient
        initialState={createDemoTvSessionState()}
        sessionId="00000000-0000-4000-8000-000000000001"
      />,
    );

    await waitFor(() => {
      expect(supabase.channel).toHaveBeenCalledWith(
        "africlub_game_session:00000000-0000-4000-8000-000000000001",
      );
    });
    expect(channel.on).toHaveBeenCalledWith(
      "postgres_changes",
      expect.objectContaining({
        schema: "africlub_game",
        table: "game_sessions",
        filter: "id=eq.00000000-0000-4000-8000-000000000001",
      }),
      expect.any(Function),
    );
    expect(channel.on).toHaveBeenCalledWith(
      "postgres_changes",
      expect.objectContaining({
        schema: "africlub_game",
        table: "session_questions",
        filter: "session_id=eq.00000000-0000-4000-8000-000000000001",
      }),
      expect.any(Function),
    );
    expect(channel.on).toHaveBeenCalledWith(
      "postgres_changes",
      expect.objectContaining({
        schema: "africlub_game",
        table: "answer_claims",
        filter: "session_id=eq.00000000-0000-4000-8000-000000000001",
      }),
      expect.any(Function),
    );
    expect(channel.on).toHaveBeenCalledWith(
      "postgres_changes",
      expect.objectContaining({
        schema: "africlub_game",
        table: "session_players",
        filter: "session_id=eq.00000000-0000-4000-8000-000000000001",
      }),
      expect.any(Function),
    );

    callbacks[0]?.();

    await waitFor(() => {
      expect(getTvState).toHaveBeenCalledWith(
        "00000000-0000-4000-8000-000000000001",
      );
    });

    unmount();

    expect(supabase.removeChannel).toHaveBeenCalledWith(channel);
  });

  it("renders venue check-in code without personal wallet or order data", () => {
    const getTvState = vi.fn().mockResolvedValue(createDemoTvSessionState());
    vi.mocked(createGameRuntimeClient).mockReturnValue(
      { getTvState } as unknown as ReturnType<typeof createGameRuntimeClient>,
    );
    vi.mocked(getBrowserSupabase).mockReturnValue(null);

    const { getByText, queryByText } = render(
      <TvDisplayClient
        initialState={createDemoTvSessionState()}
        sessionId={null}
        venueCheckin={{
          code: "RAY-2468",
          venueName: "Rayon Lounge",
          expiresAt: "Expires 20:45",
          rewardLabel: "25 FET check-in reward",
        }}
      />,
    );

    expect(getByText("Venue check-in")).toBeTruthy();
    expect(getByText("Rayon Lounge")).toBeTruthy();
    expect(getByText("RAY-2468")).toBeTruthy();
    expect(getByText("25 FET check-in reward")).toBeTruthy();
    expect(queryByText(/wallet/i)).toBeNull();
    expect(queryByText(/order queue/i)).toBeNull();
  });
});

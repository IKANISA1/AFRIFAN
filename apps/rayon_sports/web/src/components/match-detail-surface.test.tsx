import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  MatchDetailSurface,
  normalizeMatchDetail,
  type PublicMatchDetail,
} from "./match-detail-surface";

const copy = {
  backLabel: "Fixtures",
  eyebrow: "Fixture",
  description: "Confirmed fixture information.",
  continueInFanApp: "Continue in fan app",
  membership: "Membership",
};

const match: PublicMatchDetail = {
  id: "opening-day",
  homeTeam: "Rayon Sports",
  awayTeam: "APR FC",
  competition: "Premier League",
  venue: "Amahoro Stadium",
  matchDate: "2026-08-02T15:00:00.000Z",
  kickoffTime: "17:00",
  isOnSale: true,
  generalPrice: 5_000,
  vipPrice: 20_000,
  matchStatus: "upcoming",
  homeScore: 0,
  awayScore: 0,
  liveMinute: null,
  matchSummary: "Opening fixture.",
};

function response(status: number, body: unknown) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function renderDetail(mode: "fixture" | "ticket" = "fixture") {
  return render(
    <MatchDetailSurface
      matchId="opening-day"
      mode={mode}
      locale="en"
      currencyCode="RWF"
      copy={copy}
    />,
  );
}

describe("match detail helpers", () => {
  it("accepts only a bounded complete public match projection", () => {
    expect(normalizeMatchDetail(match)).toEqual(match);
    expect(normalizeMatchDetail({ ...match, id: "" })).toBeNull();
    expect(normalizeMatchDetail({ ...match, venue: "x".repeat(241) })).toBeNull();
    expect(normalizeMatchDetail({ ...match, generalPrice: -1 })).toBeNull();
    expect(
      normalizeMatchDetail({
        ...match,
        matchSummary: "x".repeat(2_001),
      })?.matchSummary,
    ).toBeNull();
  });
});

describe("MatchDetailSurface", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    vi.useRealTimers();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("moves from loading to ready through an encoded bounded endpoint", async () => {
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementation(() =>
        response(200, { code: "PUBLIC_FIXTURE_DETAIL_READY", item: match }),
      );

    const { container } = renderDetail();
    expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
      "data-match-status",
      "loading",
    );
    expect(screen.getByRole("button", { name: /refresh details/i })).toBeDisabled();

    await screen.findByRole("heading", { name: /rayon sports/i });
    expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
      "data-match-status",
      "ready",
    );
    expect(fetchSpy).toHaveBeenCalledWith(
      "/api/public-content?resource=fixture-detail&matchId=opening-day",
      expect.objectContaining({ cache: "no-store" }),
    );
  });

  it("renders a confirmed empty record without invented match data", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_FIXTURE_DETAIL_EMPTY", item: null }),
    );

    const { container } = renderDetail();
    await screen.findByRole("heading", {
      name: "No confirmed match detail is available.",
    });
    expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
      "data-match-status",
      "empty",
    );
    expect(screen.queryByText(/lineup/i)).not.toBeInTheDocument();
  });

  it.each([
    [403, "permission_denied", "Match access denied"],
    [409, "conflict", "Match details changed"],
    [502, "error", "Match details unavailable"],
    [504, "security_timeout", "Match request timed out"],
  ] as const)(
    "maps HTTP %s to %s and suppresses provider diagnostics",
    async (httpStatus, expectedState, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, { error: "database.internal password=private" }),
      );
      const { container } = renderDetail();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
        "data-match-status",
        expectedState,
      );
      expect(screen.queryByText(/database\.internal/i)).not.toBeInTheDocument();
    },
  );

  it("retains confirmed detail while a refresh resolves to conflict", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_FIXTURE_DETAIL_READY", item: match }),
      )
      .mockImplementationOnce(() =>
        response(409, { code: "PUBLIC_FIXTURE_DETAIL_CONFLICT" }),
      );
    const { container } = renderDetail();
    await screen.findByRole("heading", { name: /rayon sports/i });
    fireEvent.click(screen.getByRole("button", { name: /refresh details/i }));
    await screen.findAllByText("Match details changed");
    expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
      "data-match-status",
      "conflict",
    );
    expect(
      screen.getByRole("heading", { name: /rayon sports/i }),
    ).toBeInTheDocument();
  });

  it("exposes focused, pressed, selected, and ticket-mode access states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_FIXTURE_DETAIL_READY", item: match }),
    );
    const { container } = renderDetail("ticket");
    await screen.findByRole("heading", { name: /rayon sports/i });

    const back = screen.getByRole("link", { name: "Fixtures" });
    fireEvent.focus(back);
    expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
      "data-match-interaction",
      "focused",
    );
    fireEvent.pointerDown(back);
    expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
      "data-match-interaction",
      "pressed",
    );

    const overview = screen.getByRole("button", { name: "Overview" });
    fireEvent.click(overview);
    expect(overview).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
      "data-match-panel",
      "overview",
    );
    expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
      "data-match-interaction",
      "selected",
    );
  });

  it("reports offline without requesting and recovers on reconnect", async () => {
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: false,
    });
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementation(() =>
        response(200, { code: "PUBLIC_FIXTURE_DETAIL_READY", item: match }),
      );
    const { container } = renderDetail();
    await waitFor(() =>
      expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
        "data-match-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findByRole("heading", { name: /rayon sports/i });
  });

  it("uses the bounded client deadline without assuming content", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );
    const { container } = renderDetail();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".match-detail-surface")).toHaveAttribute(
      "data-match-status",
      "security_timeout",
    );
  });
});

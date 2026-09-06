import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  HistorySurface,
  normalizeHistoryMoments,
  resolveHistoryFailureStatus,
  resolveHistoryStateCopy,
  type HistoryMoment,
} from "./history-surface";

const copy = {
  eyebrow: "History",
  title: "The story of Rayon.",
  description: "Club identity, supporter culture, and history.",
  newsroom: "Club newsroom",
  supporterChapters: "Supporter chapters",
  moments: "Moments",
  identity: "Identity",
  surface: "Surface",
  surfaceValue: "Club-first",
  clubIdentity: "Club identity",
  historyAcrossClub: "History across the club",
  identityParagraph: "History belongs across the club.",
  seeMembershipIdentity: "See membership identity",
};

const moments: HistoryMoment[] = [
  {
    id: "founding",
    title: "The founding chapter",
    body: "Supporters established the club.",
  },
  {
    id: "first-title",
    title: "The first title",
    body: "The team earned its first major honour.",
  },
];

function response(status: number, body: unknown) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function renderHistory(locale = "en") {
  return render(
    <HistorySurface
      locale={locale}
      identity="Gikundiro"
      copy={copy}
    />,
  );
}

describe("history surface state helpers", () => {
  it("accepts only bounded, unique, complete public history records", () => {
    const oversized = Array.from({ length: 30 }, (_, index) => ({
      id: `chapter-${index}`,
      title: `Chapter ${index}`,
      body: `Body ${index}`,
    }));

    expect(
      normalizeHistoryMoments([
        moments[0],
        moments[0],
        { id: "", title: "Missing id", body: "Body" },
        { id: "missing-title", title: "", body: "Body" },
        ...oversized,
      ]),
    ).toEqual([moments[0], ...oversized.slice(0, 23)]);
  });

  it("maps controlled failures without exposing response diagnostics", () => {
    expect(resolveHistoryFailureStatus(403)).toBe("permission_denied");
    expect(resolveHistoryFailureStatus(409)).toBe("conflict");
    expect(resolveHistoryFailureStatus(504)).toBe("security_timeout");
    expect(resolveHistoryFailureStatus(502)).toBe("error");
  });

  it("provides the complete state vocabulary for every supported locale", () => {
    const expectedStates = [
      "loading",
      "ready",
      "empty",
      "error",
      "offline",
      "permission_denied",
      "syncing",
      "conflict",
      "security_timeout",
    ];

    for (const locale of ["en", "en", "en", "en", "unsupported"]) {
      expect(Object.keys(resolveHistoryStateCopy(locale).status)).toEqual(
        expectedStates,
      );
      expect(resolveHistoryStateCopy(locale).chapter).not.toBe("");
    }
  });
});

describe("HistorySurface", () => {
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

  it("moves from loading to confirmed chapters and exposes selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_HISTORY_READY", items: moments }),
    );

    const { container } = renderHistory();

    expect(container.querySelector("[data-history-status]")).toHaveAttribute(
      "data-history-status",
      "loading",
    );
    expect(
      screen.getByRole("button", { name: /refresh history/i }),
    ).toBeDisabled();

    await screen.findByRole("heading", { name: "The founding chapter" });
    expect(container.querySelector("[data-history-status]")).toHaveAttribute(
      "data-history-status",
      "ready",
    );
    expect(
      screen.getByRole("button", { name: /chapter\s*2\s*the first title/i }),
    ).toHaveAttribute("aria-pressed", "false");

    fireEvent.click(
      screen.getByRole("button", {
        name: /chapter\s*2\s*the first title/i,
      }),
    );
    expect(
      screen.getByRole("heading", { name: "The first title" }),
    ).toBeInTheDocument();
    expect(container.querySelector(".history-surface")).toHaveAttribute(
      "data-history-interaction",
      "selected",
    );
  });

  it("renders an explicit confirmed empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_HISTORY_EMPTY", items: [] }),
    );

    const { container } = renderHistory();

    await screen.findByText("Club history is not published yet.");
    expect(container.querySelector(".history-surface")).toHaveAttribute(
      "data-history-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "History access denied"],
    [409, "conflict", "History changed"],
    [502, "error", "History unavailable"],
    [504, "security_timeout", "History request timed out"],
  ] as const)(
    "maps HTTP %s to %s without rendering raw diagnostics",
    async (httpStatus, expectedState, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          error: "database.internal user=private",
        }),
      );

      const { container } = renderHistory();

      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".history-surface")).toHaveAttribute(
        "data-history-status",
        expectedState,
      );
      expect(screen.queryByText(/database\.internal/i)).not.toBeInTheDocument();
    },
  );

  it("reports offline immediately and recovers when the browser reconnects", async () => {
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: false,
    });
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementation(() =>
        response(200, { code: "PUBLIC_HISTORY_READY", items: moments }),
      );

    const { container } = renderHistory();

    await waitFor(() =>
      expect(container.querySelector(".history-surface")).toHaveAttribute(
        "data-history-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();

    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findByRole("heading", { name: "The founding chapter" });
  });

  it("retains confirmed chapters while a refresh is syncing", async () => {
    let releaseRefresh:
      | ((value: Response | PromiseLike<Response>) => void)
      | undefined;
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_HISTORY_READY", items: moments }),
      )
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            releaseRefresh = resolve;
          }),
      );

    const { container } = renderHistory();
    await screen.findByRole("heading", { name: "The founding chapter" });

    fireEvent.click(screen.getByRole("button", { name: /refresh history/i }));
    await waitFor(() =>
      expect(container.querySelector(".history-surface")).toHaveAttribute(
        "data-history-status",
        "syncing",
      ),
    );
    expect(
      screen.getByRole("heading", { name: "The founding chapter" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /refresh history/i }),
    ).toBeDisabled();
    expect(fetchSpy).toHaveBeenCalledTimes(2);

    releaseRefresh?.(
      new Response(
        JSON.stringify({ code: "PUBLIC_HISTORY_READY", items: moments }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
    await waitFor(() =>
      expect(container.querySelector(".history-surface")).toHaveAttribute(
        "data-history-status",
        "ready",
      ),
    );
  });

  it("retains confirmed chapters during recoverable refresh failures", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_HISTORY_READY", items: moments }),
      )
      .mockImplementationOnce(() =>
        response(409, { code: "PUBLIC_HISTORY_CONFLICT" }),
      );

    const { container } = renderHistory();
    await screen.findByRole("heading", { name: "The founding chapter" });
    fireEvent.click(screen.getByRole("button", { name: /refresh history/i }));

    await waitFor(() =>
      expect(container.querySelector(".history-surface")).toHaveAttribute(
        "data-history-status",
        "conflict",
      ),
    );
    expect(
      screen.getByRole("heading", { name: "The founding chapter" }),
    ).toBeInTheDocument();
  });

  it("records real focus and held-pointer interaction states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_HISTORY_READY", items: moments }),
    );
    const { container } = renderHistory();
    await screen.findByRole("heading", { name: "The founding chapter" });
    const newsroom = screen.getByRole("link", { name: "Club newsroom" });

    fireEvent.focus(newsroom);
    expect(container.querySelector(".history-surface")).toHaveAttribute(
      "data-history-interaction",
      "focused",
    );
    fireEvent.pointerDown(newsroom);
    expect(container.querySelector(".history-surface")).toHaveAttribute(
      "data-history-interaction",
      "pressed",
    );
    fireEvent.pointerUp(newsroom);
    expect(container.querySelector(".history-surface")).toHaveAttribute(
      "data-history-interaction",
      "idle",
    );
  });

  it("aborts a browser request after eight seconds", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () => {
            reject(new DOMException("Aborted", "AbortError"));
          });
        }),
    );

    const { container } = renderHistory();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });

    expect(container.querySelector(".history-surface")).toHaveAttribute(
      "data-history-status",
      "security_timeout",
    );
    expect(screen.queryByText(/Aborted/i)).not.toBeInTheDocument();
  });

  it("renders supported locale copy without changing the data contract", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_HISTORY_EMPTY", items: [] }),
    );

    renderHistory("en");

    await screen.findByText("Club history is not published yet.");
    expect(
      screen.getByRole("button", { name: "Refresh history" }),
    ).toBeInTheDocument();
  });
});

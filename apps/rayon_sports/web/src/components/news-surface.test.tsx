import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  NewsSurface,
  normalizeNewsArticles,
  resolveNewsFailureStatus,
  resolveNewsStateCopy,
  type PublicNewsArticle,
} from "./news-surface";

const copy = {
  eyebrow: "Newsroom",
  title: "Club news and supporter stories.",
  description: "Latest confirmed club updates.",
  newsroomStandards: "Newsroom standards",
  newsroomStandardsTitle: "Every story earns the click",
  standardsPoints: ["Every card carries a real excerpt."],
};

const articles: PublicNewsArticle[] = [
  {
    id: "opening-day",
    title: "Opening day",
    excerpt: "The club opens a new season with its supporters.",
    category: "Club",
    coverImageUrl: "/brand-surface.svg",
    publishedAt: "2026-07-28T10:00:00.000Z",
    author: "Gikundiro Media",
  },
  {
    id: "matchday-plan",
    title: "Matchday plan",
    excerpt: "Everything supporters need for the next fixture.",
    category: "Matchday",
    coverImageUrl: "/brand-surface.svg",
    publishedAt: "2026-07-27T10:00:00.000Z",
    author: "Gikundiro Media",
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

function renderNews(locale = "en") {
  return render(
    <NewsSurface locale={locale} identity="Gikundiro" copy={copy} />,
  );
}

describe("news surface state helpers", () => {
  it("accepts only bounded, unique, complete public news records", () => {
    const oversized = Array.from({ length: 30 }, (_, index) => ({
      ...articles[0],
      id: `story-${index}`,
      title: `Story ${index}`,
    }));

    expect(
      normalizeNewsArticles([
        articles[0],
        articles[0],
        { ...articles[0], id: "" },
        { ...articles[0], id: "bad-date", publishedAt: "not-a-date" },
        {
          ...articles[0],
          id: "unsafe-image",
          coverImageUrl: "https://tracker.invalid/private.png",
        },
        ...oversized,
      ]),
    ).toEqual([
      articles[0],
      { ...articles[0], id: "unsafe-image" },
      ...oversized.slice(0, 22),
    ]);
  });

  it("maps controlled failures without exposing response diagnostics", () => {
    expect(resolveNewsFailureStatus(403)).toBe("permission_denied");
    expect(resolveNewsFailureStatus(409)).toBe("conflict");
    expect(resolveNewsFailureStatus(504)).toBe("security_timeout");
    expect(resolveNewsFailureStatus(502)).toBe("error");
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

    for (const locale of ["en", "fr-FR", "rw", "sw", "unsupported"]) {
      expect(Object.keys(resolveNewsStateCopy(locale).status)).toEqual(
        expectedStates,
      );
      expect(resolveNewsStateCopy(locale).readStory).not.toBe("");
    }
  });
});

describe("NewsSurface", () => {
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

  it("moves from loading to a confirmed feed and exposes selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_NEWS_READY", items: articles }),
    );

    const { container } = renderNews();
    expect(container.querySelector(".news-surface")).toHaveAttribute(
      "data-news-status",
      "loading",
    );
    expect(
      screen.getByRole("button", { name: /refresh news/i }),
    ).toBeDisabled();

    await screen.findByRole("heading", { name: "Opening day" });
    expect(container.querySelector(".news-surface")).toHaveAttribute(
      "data-news-status",
      "ready",
    );

    const secondStory = screen.getByRole("button", {
      name: /story\s*matchday plan\s*matchday/i,
    });
    fireEvent.click(secondStory);
    expect(secondStory).toHaveAttribute("aria-pressed", "true");
    expect(
      screen.getByRole("heading", { name: "Matchday plan" }),
    ).toBeInTheDocument();
    expect(container.querySelector(".news-surface")).toHaveAttribute(
      "data-news-interaction",
      "selected",
    );
  });

  it("renders an explicit confirmed empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_NEWS_EMPTY", items: [] }),
    );

    const { container } = renderNews();
    await screen.findByText("No club news is published yet.");
    expect(container.querySelector(".news-surface")).toHaveAttribute(
      "data-news-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "News access denied"],
    [409, "conflict", "News feed changed"],
    [502, "error", "Newsroom unavailable"],
    [504, "security_timeout", "News request timed out"],
  ] as const)(
    "maps HTTP %s to %s without rendering raw diagnostics",
    async (httpStatus, expectedState, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          error: "database.internal user=private",
        }),
      );

      const { container } = renderNews();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".news-surface")).toHaveAttribute(
        "data-news-status",
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
        response(200, { code: "PUBLIC_NEWS_READY", items: articles }),
      );

    const { container } = renderNews();
    await waitFor(() =>
      expect(container.querySelector(".news-surface")).toHaveAttribute(
        "data-news-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();

    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findByRole("heading", { name: "Opening day" });
  });

  it("retains confirmed stories while a refresh is syncing", async () => {
    let releaseRefresh:
      | ((value: Response | PromiseLike<Response>) => void)
      | undefined;
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_NEWS_READY", items: articles }),
      )
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            releaseRefresh = resolve;
          }),
      );

    const { container } = renderNews();
    await screen.findByRole("heading", { name: "Opening day" });
    fireEvent.click(screen.getByRole("button", { name: /refresh news/i }));

    await waitFor(() =>
      expect(container.querySelector(".news-surface")).toHaveAttribute(
        "data-news-status",
        "syncing",
      ),
    );
    expect(
      screen.getByRole("heading", { name: "Opening day" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /refresh news/i }),
    ).toBeDisabled();
    expect(fetchSpy).toHaveBeenCalledTimes(2);

    releaseRefresh?.(
      new Response(
        JSON.stringify({ code: "PUBLIC_NEWS_READY", items: articles }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      ),
    );
    await waitFor(() =>
      expect(container.querySelector(".news-surface")).toHaveAttribute(
        "data-news-status",
        "ready",
      ),
    );
  });

  it("retains confirmed stories during recoverable refresh failures", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_NEWS_READY", items: articles }),
      )
      .mockImplementationOnce(() =>
        response(409, { code: "PUBLIC_NEWS_CONFLICT" }),
      );

    const { container } = renderNews();
    await screen.findByRole("heading", { name: "Opening day" });
    fireEvent.click(screen.getByRole("button", { name: /refresh news/i }));

    await waitFor(() =>
      expect(container.querySelector(".news-surface")).toHaveAttribute(
        "data-news-status",
        "conflict",
      ),
    );
    expect(
      screen.getByRole("heading", { name: "Opening day" }),
    ).toBeInTheDocument();
  });

  it("records real focus and held-pointer interaction states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_NEWS_READY", items: articles }),
    );

    const { container } = renderNews();
    await screen.findByRole("heading", { name: "Opening day" });
    const matchday = screen.getByRole("link", { name: "Matchday" });

    fireEvent.focus(matchday);
    expect(container.querySelector(".news-surface")).toHaveAttribute(
      "data-news-interaction",
      "focused",
    );
    fireEvent.pointerDown(matchday);
    expect(container.querySelector(".news-surface")).toHaveAttribute(
      "data-news-interaction",
      "pressed",
    );
    fireEvent.pointerUp(matchday);
    expect(container.querySelector(".news-surface")).toHaveAttribute(
      "data-news-interaction",
      "idle",
    );
  });

  it("maps a browser-side timeout to the security timeout state", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );

    const { container } = renderNews();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".news-surface")).toHaveAttribute(
      "data-news-status",
      "security_timeout",
    );
  });

  it("rejects malformed success payloads", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_NEWS_READY", items: "private" }),
    );

    const { container } = renderNews();
    await waitFor(() =>
      expect(container.querySelector(".news-surface")).toHaveAttribute(
        "data-news-status",
        "error",
      ),
    );
  });
});

import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  NewsArticleSurface,
  normalizeNewsArticle,
  type PublicNewsArticleDetail,
} from "./news-article-surface";

const copy = {
  newsroom: "Club newsroom",
  details: "Details",
  standards: "Newsroom standards",
  standardsTitle: "Every story earns the click",
  standardsPoints: ["Every story has a confirmed public source."],
  minuteRead: "min read",
  matchdayCoverage: "Matchday coverage",
};

const article: PublicNewsArticleDetail = {
  id: "opening-day",
  title: "Opening day",
  excerpt: "The season begins with supporters at the heart of the club.",
  content:
    "The gates open early for every supporter. The team begins its campaign with a clear plan.",
  category: "Club",
  coverImageUrl: "/brand-surface.svg",
  publishedAt: "2026-07-28T10:00:00.000Z",
  author: "Gikundiro Media",
};

function response(status: number, body: unknown) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function renderArticle() {
  return render(
    <NewsArticleSurface
      articleId="opening-day"
      locale="en"
      copy={copy}
    />,
  );
}

describe("news article state helpers", () => {
  it("accepts only a bounded complete public article", () => {
    expect(normalizeNewsArticle(article)).toEqual(article);
    expect(normalizeNewsArticle({ ...article, id: "" })).toBeNull();
    expect(
      normalizeNewsArticle({ ...article, content: "x".repeat(12_001) }),
    ).toBeNull();
    expect(
      normalizeNewsArticle({
        ...article,
        coverImageUrl: "https://tracker.invalid/private.png",
      }),
    ).toEqual({ ...article, coverImageUrl: "/brand-surface.svg" });
  });
});

describe("NewsArticleSurface", () => {
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

  it("moves from loading to a confirmed article and uses an encoded identifier", async () => {
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementation(() =>
        response(200, { code: "PUBLIC_NEWS_ARTICLE_READY", item: article }),
      );

    const { container } = renderArticle();
    expect(container.querySelector(".news-article-surface")).toHaveAttribute(
      "data-article-status",
      "loading",
    );
    expect(screen.getByRole("button", { name: /refresh news/i })).toBeDisabled();

    await screen.findByRole("heading", { name: "Opening day" });
    expect(container.querySelector(".news-article-surface")).toHaveAttribute(
      "data-article-status",
      "ready",
    );
    expect(fetchSpy).toHaveBeenCalledWith(
      "/api/public-content?resource=news-article&articleId=opening-day",
      expect.objectContaining({ cache: "no-store" }),
    );
  });

  it("renders an explicit confirmed missing-article state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_NEWS_ARTICLE_EMPTY", item: null }),
    );

    const { container } = renderArticle();
    await screen.findByText("Story not found");
    expect(container.querySelector(".news-article-surface")).toHaveAttribute(
      "data-article-status",
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
          error: "database.internal password=private",
        }),
      );

      const { container } = renderArticle();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".news-article-surface")).toHaveAttribute(
        "data-article-status",
        expectedState,
      );
      expect(screen.queryByText(/database\.internal/i)).not.toBeInTheDocument();
    },
  );

  it("reports offline without requesting data and recovers on reconnect", async () => {
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: false,
    });
    const fetchSpy = vi
      .spyOn(globalThis, "fetch")
      .mockImplementation(() =>
        response(200, { code: "PUBLIC_NEWS_ARTICLE_READY", item: article }),
      );

    const { container } = renderArticle();
    await waitFor(() =>
      expect(container.querySelector(".news-article-surface")).toHaveAttribute(
        "data-article-status",
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

  it("retains the confirmed article during synchronization and conflict", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_NEWS_ARTICLE_READY", item: article }),
      )
      .mockImplementationOnce(() =>
        response(409, { code: "PUBLIC_NEWS_ARTICLE_CONFLICT" }),
      );

    const { container } = renderArticle();
    await screen.findByRole("heading", { name: "Opening day" });
    fireEvent.click(screen.getByRole("button", { name: /refresh news/i }));

    await waitFor(() =>
      expect(container.querySelector(".news-article-surface")).toHaveAttribute(
        "data-article-status",
        "conflict",
      ),
    );
    expect(
      screen.getByRole("heading", { name: "Opening day" }),
    ).toBeInTheDocument();
  });

  it("exposes focused, pressed, and selected reader states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_NEWS_ARTICLE_READY", item: article }),
    );

    const { container } = renderArticle();
    await screen.findByRole("heading", { name: "Opening day" });
    const newsroom = screen.getByRole("link", { name: /club newsroom/i });
    fireEvent.focus(newsroom);
    expect(container.querySelector(".news-article-surface")).toHaveAttribute(
      "data-article-interaction",
      "focused",
    );
    fireEvent.pointerDown(newsroom);
    expect(container.querySelector(".news-article-surface")).toHaveAttribute(
      "data-article-interaction",
      "pressed",
    );

    const reader = screen.getByRole("button", { name: /reader mode/i });
    fireEvent.click(reader);
    expect(reader).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".news-article-surface")).toHaveAttribute(
      "data-reader-mode",
      "true",
    );
    expect(container.querySelector(".news-article-surface")).toHaveAttribute(
      "data-article-interaction",
      "selected",
    );
  });

  it("times out after the bounded client deadline without assuming content", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );

    const { container } = renderArticle();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".news-article-surface")).toHaveAttribute(
      "data-article-status",
      "security_timeout",
    );
    expect(screen.queryByRole("heading", { name: "Opening day" })).toBeNull();
  });
});

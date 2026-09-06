import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  normalizeSupportersSnapshot,
  resolveSupportersCopy,
  SupportersSurface,
  type PublicSupporterRanking,
  type PublicSupporterReward,
} from "./supporters-surface";

const catalog: PublicSupporterReward[] = [
  {
    id: "reward-matchday",
    code: "MATCHDAY",
    category: "Matchday",
    itemName: "Matchday attendance",
    fetValue: 250,
    triggerCondition: "Confirmed attendance in the supporter app",
    activationTiming: "After club verification",
    description: "A confirmed public reward for verified matchday attendance.",
  },
  {
    id: "reward-community",
    code: "COMMUNITY",
    category: "Community",
    itemName: "Community participation",
    fetValue: 150,
    triggerCondition: "Confirmed community activity",
    activationTiming: "After moderator verification",
    description: "A confirmed public reward for approved community activity.",
  },
  {
    id: "reward-membership",
    code: "MEMBERSHIP",
    category: "Membership",
    itemName: "Membership milestone",
    fetValue: 500,
    triggerCondition: "Confirmed membership milestone",
    activationTiming: "After account verification",
    description: "A confirmed public reward for an approved membership milestone.",
  },
];

const leaderboard: PublicSupporterRanking[] = [
  { rank: 1, supporterAlias: "blue_lion", totalFet: 3_500, tier: "inyamibwa" },
  { rank: 2, supporterAlias: "gikundiro_7", totalFet: 3_100, tier: "imena" },
  { rank: 3, supporterAlias: "rayon_star", totalFet: 2_850, tier: "imena" },
];

function response(status: number, body: unknown) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function readyResponse() {
  return response(200, {
    code: "PUBLIC_SUPPORTERS_READY",
    catalog,
    leaderboard,
  });
}

function renderSupporters(locale = "en") {
  return render(
    <SupportersSurface
      locale={locale}
      clubShortName="Rayon Sports"
      fanAppHref="/supporters"
      hasExternalAppUrl={false}
    />,
  );
}

describe("supporters helpers", () => {
  it("bounds and deduplicates public rewards and privacy-safe aliases", () => {
    const normalized = normalizeSupportersSnapshot({
      catalog: [
        ...Array.from({ length: 10 }, (_, index) => ({
          id: `reward-${index}`,
          code: `CODE_${index}`,
          category: "Matchday",
          itemName: `Reward ${index}`,
          fetValue: index,
          triggerCondition: "Confirmed action",
          activationTiming: "After verification",
          description: `Reward ${index}.`,
          implementationNotes: "private",
        })),
        {
          id: "reward-0",
          code: "DUPLICATE",
          category: "Private",
          itemName: "Duplicate",
          fetValue: 20,
          triggerCondition: "Private",
          activationTiming: "Private",
          description: "Private",
        },
      ],
      leaderboard: [
        ...Array.from({ length: 12 }, (_, index) => ({
          rank: index + 1,
          supporterAlias: `fan_${index + 1}`,
          totalFet: 2_000 - index,
          tier: "imena",
          userId: `private-${index}`,
          displayName: `Private Name ${index}`,
        })),
        {
          rank: 50,
          supporterAlias: "0788123456",
          totalFet: 1,
          tier: "imena",
        },
      ],
    });

    expect(normalized.catalog).toHaveLength(8);
    expect(normalized.leaderboard).toHaveLength(10);
    expect(normalized.catalog[0]).not.toHaveProperty("implementationNotes");
    expect(normalized.leaderboard[0]).not.toHaveProperty("userId");
    expect(normalized.leaderboard[0]).not.toHaveProperty("displayName");
    expect(
      normalized.leaderboard.some(({ supporterAlias }) =>
        /^\d{7,}$/.test(supporterAlias),
      ),
    ).toBe(false);
  });

  it("provides every controlled state in each supported locale", () => {
    const expected = [
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
      const localized = resolveSupportersCopy(locale);
      expect(Object.keys(localized.status)).toEqual(expected);
      expect(localized.refresh).not.toBe("");
      expect(localized.privacyDetail).not.toBe("");
    }
  });
});

describe("SupportersSurface", () => {
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

  it("loads a confirmed snapshot and supports real reward selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    const { container } = renderSupporters();

    expect(container.querySelector(".supporters-surface")).toHaveAttribute(
      "data-supporters-status",
      "loading",
    );
    await screen.findAllByText("Matchday attendance");
    expect(container.querySelector(".supporters-surface")).toHaveAttribute(
      "data-supporters-status",
      "ready",
    );
    expect(screen.getByText("#blue_lion")).toBeInTheDocument();

    const community = screen.getByRole("button", {
      name: /community participation/i,
    });
    fireEvent.click(community);
    expect(community).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".supporters-surface")).toHaveAttribute(
      "data-supporters-interaction",
      "selected",
    );
  });

  it("renders a confirmed empty snapshot without implying provider failure", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, {
        code: "PUBLIC_SUPPORTERS_EMPTY",
        catalog: [],
        leaderboard: [],
      }),
    );
    const { container } = renderSupporters();

    await screen.findByRole("heading", { name: "No public rewards listed" });
    expect(container.querySelector(".supporters-surface")).toHaveAttribute(
      "data-supporters-status",
      "empty",
    );
    expect(
      screen.getByRole("heading", { name: "No public ranking listed" }),
    ).toBeInTheDocument();
  });

  it.each([
    [403, "permission_denied", "Supporter data access denied"],
    [409, "conflict", "Supporter program changed"],
    [502, "error", "Supporter program unavailable"],
    [504, "security_timeout", "Supporter request timed out"],
  ] as const)(
    "maps HTTP %s to %s without exposing provider diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          error: "database.internal password=private",
        }),
      );

      const { container } = renderSupporters();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".supporters-surface")).toHaveAttribute(
        "data-supporters-status",
        expectedStatus,
      );
      expect(screen.queryByText(/database\.internal/i)).toBeNull();
    },
  );

  it("reports offline before fetching and reloads after reconnect", async () => {
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: false,
    });
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    const { container } = renderSupporters();

    await waitFor(() =>
      expect(container.querySelector(".supporters-surface")).toHaveAttribute(
        "data-supporters-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findAllByText("Matchday attendance");
  });

  it("retains confirmed data during syncing and recoverable conflict", async () => {
    let releaseRefresh:
      | ((value: Response | PromiseLike<Response>) => void)
      | undefined;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyResponse)
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            releaseRefresh = resolve;
          }),
      );

    const { container } = renderSupporters();
    await screen.findAllByText("Matchday attendance");
    fireEvent.click(screen.getByRole("button", { name: /refresh program/i }));
    await waitFor(() =>
      expect(container.querySelector(".supporters-surface")).toHaveAttribute(
        "data-supporters-status",
        "syncing",
      ),
    );
    expect(screen.getAllByText("Matchday attendance").length).toBeGreaterThan(0);
    expect(screen.getByText("#blue_lion")).toBeInTheDocument();
    releaseRefresh?.(
      new Response(JSON.stringify({ code: "PUBLIC_SUPPORTERS_CONFLICT" }), {
        status: 409,
        headers: { "Content-Type": "application/json" },
      }),
    );
    await waitFor(() =>
      expect(container.querySelector(".supporters-surface")).toHaveAttribute(
        "data-supporters-status",
        "conflict",
      ),
    );
    expect(screen.getByText("#blue_lion")).toBeInTheDocument();
  });

  it("clears previously confirmed public data when access is denied", async () => {
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(readyResponse)
      .mockImplementationOnce(() =>
        response(403, { code: "PUBLIC_SUPPORTERS_ACCESS_DENIED" }),
      );

    const { container } = renderSupporters();
    await screen.findAllByText("Matchday attendance");
    fireEvent.click(screen.getByRole("button", { name: /refresh program/i }));
    await waitFor(() =>
      expect(container.querySelector(".supporters-surface")).toHaveAttribute(
        "data-supporters-status",
        "permission_denied",
      ),
    );
    expect(screen.queryByText("#blue_lion")).toBeNull();
    expect(screen.queryByRole("button", { name: /matchday attendance/i })).toBeNull();
  });

  it("records real focus and held-pointer interaction states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(readyResponse);
    const { container } = renderSupporters();
    await screen.findAllByText("Matchday attendance");

    const primary = screen.getAllByRole("link", {
      name: /app links coming soon/i,
    })[0];
    fireEvent.focus(primary);
    expect(container.querySelector(".supporters-surface")).toHaveAttribute(
      "data-supporters-interaction",
      "focused",
    );
    fireEvent.pointerDown(primary);
    expect(container.querySelector(".supporters-surface")).toHaveAttribute(
      "data-supporters-interaction",
      "pressed",
    );
  });

  it("times out at the bounded deadline without assuming public data", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );
    const { container } = renderSupporters();

    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".supporters-surface")).toHaveAttribute(
      "data-supporters-status",
      "security_timeout",
    );
    expect(screen.queryByText("#blue_lion")).toBeNull();
  });
});

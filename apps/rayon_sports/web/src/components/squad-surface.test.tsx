import { act, fireEvent, render, screen, waitFor } from "@testing-library/react";
import {
  classifySquadPlayer,
  normalizeSquad,
  resolveSquadStateCopy,
  SquadSurface,
  type PublicSquadPlayer,
} from "./squad-surface";

const players: PublicSquadPlayer[] = [
  {
    id: "keeper-1",
    name: "Olivier Kwizera",
    role: "Goalkeeper",
    number: 1,
    nationality: "Rwanda",
    bio: "Confirmed first-team goalkeeper.",
    imageUrl: "/brand-surface.svg",
  },
  {
    id: "defender-5",
    name: "Thierry Manzi",
    role: "Defender",
    number: 5,
    nationality: "Rwanda",
    bio: "Confirmed first-team defender.",
    imageUrl: "/brand-surface.svg",
  },
  {
    id: "midfielder-8",
    name: "Kevin Muhire",
    role: "Midfielder",
    number: 8,
    nationality: "Rwanda",
    bio: "Confirmed first-team midfielder.",
    imageUrl: "/brand-surface.svg",
  },
  {
    id: "forward-9",
    name: "Musa Esenu",
    role: "Forward",
    number: 9,
    nationality: "Uganda",
    bio: "Confirmed first-team forward.",
    imageUrl: "/brand-surface.svg",
  },
];

const copy = {
  eyebrow: "Squad",
  title: "Squad, numbers, and roles.",
  description: "Meet the confirmed first-team squad.",
  fixtureHub: "Fixture hub",
  leagueTable: "League table",
  playersShown: "Players",
  unitsShown: "Core units",
  selectedNumber: "Position",
  selectedPlayer: "Unit view",
  unitView: "Unit view",
  tacticalShape: "Tactical shape at a glance",
  rosterNote: "Confirmed squad profiles remain tied to the public roster.",
  goalkeepers: "Goalkeepers",
  defenders: "Defenders",
  midfielders: "Midfielders",
  attackers: "Attackers",
  nationality: "Nationalities",
  playerRole: "Position",
};

function response(status: number, body: unknown) {
  return Promise.resolve(
    new Response(JSON.stringify(body), {
      status,
      headers: { "Content-Type": "application/json" },
    }),
  );
}

function renderSquad(locale = "en") {
  return render(<SquadSurface locale={locale} copy={copy} />);
}

describe("squad helpers", () => {
  it("normalizes, sorts, deduplicates, bounds, and sanitizes public players", () => {
    const input = [
      ...Array.from({ length: 42 }, (_, index) => ({
        id: `player-${index}`,
        name: `Player ${index}`,
        role: index % 2 === 0 ? "Midfielder" : "Defender",
        number: index === 0 ? 0 : 42 - index,
        nationality: "Rwanda",
        bio: `Confirmed player ${index}.`,
        imageUrl:
          index === 1
            ? "https://unsafe.invalid/private.png"
            : "/brand-surface.svg",
      })),
      {
        id: "player-1",
        name: "Duplicate",
        role: "Forward",
        number: 99,
        nationality: "Rwanda",
        bio: "Duplicate row.",
      },
      {
        id: "invalid",
        name: "",
        role: "Forward",
        number: -1,
        nationality: "Rwanda",
        bio: "Invalid row.",
      },
    ];

    const normalized = normalizeSquad(input);
    expect(normalized).toHaveLength(40);
    expect(new Set(normalized.map(({ id }) => id)).size).toBe(40);
    expect(normalized.at(-1)?.number).toBe(0);
    expect(
      normalized.find(({ id }) => id === "player-1")?.imageUrl,
    ).toBe("/brand-surface.svg");
  });

  it("classifies multilingual football roles into four governed units", () => {
    expect(classifySquadPlayer("Goalkeeper")).toBe("goalkeepers");
    expect(classifySquadPlayer("Défenseur central")).toBe("defenders");
    expect(classifySquadPlayer("Midfielder")).toBe("midfielders");
    expect(classifySquadPlayer("Winger")).toBe("attackers");
  });

  it("provides all controlled states in every supported locale", () => {
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
    for (const locale of ["en", "fr-FR", "rw", "sw", "unsupported"]) {
      const localized = resolveSquadStateCopy(locale);
      expect(Object.keys(localized.status)).toEqual(expected);
      expect(localized.refresh).not.toBe("");
      expect(localized.players).not.toBe("");
    }
  });
});

describe("SquadSurface", () => {
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

  it("loads confirmed players, groups units, and supports real selection", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_SQUAD_READY", items: players }),
    );

    const { container } = renderSquad();
    expect(container.querySelector(".squad-surface")).toHaveAttribute(
      "data-squad-status",
      "loading",
    );
    await screen.findAllByText("Olivier Kwizera");
    expect(container.querySelector(".squad-surface")).toHaveAttribute(
      "data-squad-status",
      "ready",
    );
    expect(screen.getByRole("heading", { name: "Goalkeepers" })).toBeVisible();
    expect(screen.getByRole("heading", { name: "Attackers" })).toBeVisible();
    const forward = screen.getByRole("button", { name: /musa esenu/i });
    fireEvent.click(forward);
    expect(forward).toHaveAttribute("aria-pressed", "true");
    expect(container.querySelector(".squad-surface")).toHaveAttribute(
      "data-squad-interaction",
      "selected",
    );
  });

  it("renders an explicit confirmed empty state", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_SQUAD_EMPTY", items: [] }),
    );

    const { container } = renderSquad();
    await screen.findByRole("heading", { name: "No squad listed" });
    expect(container.querySelector(".squad-surface")).toHaveAttribute(
      "data-squad-status",
      "empty",
    );
  });

  it.each([
    [403, "permission_denied", "Squad access denied"],
    [409, "conflict", "Squad list changed"],
    [502, "error", "Squad list unavailable"],
    [504, "security_timeout", "Squad request timed out"],
  ] as const)(
    "maps HTTP %s to %s without exposing provider diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.spyOn(globalThis, "fetch").mockImplementation(() =>
        response(httpStatus, {
          error: "database.internal password=private",
        }),
      );

      const { container } = renderSquad();
      await screen.findAllByText(expectedLabel);
      expect(container.querySelector(".squad-surface")).toHaveAttribute(
        "data-squad-status",
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
    const fetchSpy = vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_SQUAD_READY", items: players }),
    );

    const { container } = renderSquad();
    await waitFor(() =>
      expect(container.querySelector(".squad-surface")).toHaveAttribute(
        "data-squad-status",
        "offline",
      ),
    );
    expect(fetchSpy).not.toHaveBeenCalled();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
    fireEvent(window, new Event("online"));
    await screen.findAllByText("Olivier Kwizera");
  });

  it("retains confirmed players during syncing and recoverable conflict", async () => {
    let releaseRefresh:
      | ((value: Response | PromiseLike<Response>) => void)
      | undefined;
    vi.spyOn(globalThis, "fetch")
      .mockImplementationOnce(() =>
        response(200, { code: "PUBLIC_SQUAD_READY", items: players }),
      )
      .mockImplementationOnce(
        () =>
          new Promise<Response>((resolve) => {
            releaseRefresh = resolve;
          }),
      );

    const { container } = renderSquad();
    await screen.findAllByText("Olivier Kwizera");
    fireEvent.click(screen.getByRole("button", { name: /refresh squad/i }));
    await waitFor(() =>
      expect(container.querySelector(".squad-surface")).toHaveAttribute(
        "data-squad-status",
        "syncing",
      ),
    );
    expect(screen.getAllByText("Olivier Kwizera").length).toBeGreaterThan(0);
    releaseRefresh?.(
      new Response(JSON.stringify({ code: "PUBLIC_SQUAD_CONFLICT" }), {
        status: 409,
        headers: { "Content-Type": "application/json" },
      }),
    );
    await waitFor(() =>
      expect(container.querySelector(".squad-surface")).toHaveAttribute(
        "data-squad-status",
        "conflict",
      ),
    );
    expect(screen.getAllByText("Olivier Kwizera").length).toBeGreaterThan(0);
  });

  it("records real focus and held-pointer interaction states", async () => {
    vi.spyOn(globalThis, "fetch").mockImplementation(() =>
      response(200, { code: "PUBLIC_SQUAD_READY", items: players }),
    );

    const { container } = renderSquad();
    await screen.findAllByText("Olivier Kwizera");
    const primary = screen.getAllByRole("link", { name: /fixture hub/i })[0];
    fireEvent.focus(primary);
    expect(container.querySelector(".squad-surface")).toHaveAttribute(
      "data-squad-interaction",
      "focused",
    );
    fireEvent.pointerDown(primary);
    expect(container.querySelector(".squad-surface")).toHaveAttribute(
      "data-squad-interaction",
      "pressed",
    );
  });

  it("times out at the bounded deadline without assuming a roster", async () => {
    vi.useFakeTimers();
    vi.spyOn(globalThis, "fetch").mockImplementation(
      (_input, init) =>
        new Promise<Response>((_resolve, reject) => {
          init?.signal?.addEventListener("abort", () =>
            reject(new DOMException("Aborted", "AbortError")),
          );
        }),
    );

    const { container } = renderSquad();
    await act(async () => {
      await vi.advanceTimersByTimeAsync(8_000);
    });
    expect(container.querySelector(".squad-surface")).toHaveAttribute(
      "data-squad-status",
      "security_timeout",
    );
    expect(screen.queryByText("Olivier Kwizera")).toBeNull();
  });
});

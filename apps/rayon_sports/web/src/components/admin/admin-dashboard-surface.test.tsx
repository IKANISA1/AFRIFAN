import {
  act,
  fireEvent,
  render,
  screen,
  waitFor,
} from "@testing-library/react";
import { AdminApiError, requestAdminApi } from "@/lib/data/admin/http";
import {
  AdminDashboardSurface,
  normalizeAdminDashboardOverview,
  resolveAdminDashboardFailure,
} from "./admin-dashboard-surface";

vi.mock("@/lib/data/admin/http", async (importOriginal) => {
  const actual =
    await importOriginal<typeof import("@/lib/data/admin/http")>();
  return {
    ...actual,
    requestAdminApi: vi.fn(),
  };
});

vi.mock("@/components/admin/admin-portal-provider", () => ({
  useAdminPortal: () => ({
    access: {
      hasAccess: true,
      isAuthenticated: true,
      isSuperAdmin: false,
      role: "club_admin",
      clubId: "24",
      availableClubIds: ["24"],
      canSelectClub: false,
      assignmentCount: 1,
    },
    activeClub: {
      id: "24",
      clubName: "Rayon Sports",
      shortName: "Rayon",
      clubSlug: "rayon-sports",
      currencyCode: "RWF",
      currencySymbol: "RWF",
    },
  }),
}));

const overview = {
  snapshot: {
    metrics: {
      activeUsers: 120,
      pendingVerifications: 4,
      activeSupportCircles: 8,
      recentTicketSales: 52,
      totalFans: 120,
      ticketRevenue: 2_400_000,
    },
    activity: [
      {
        id: "audit-1",
        title: "Membership reviewed",
        detail: "A supporter application changed state.",
        createdAt: "2026-07-29T12:00:00.000Z",
        actorEmail: "private@example.com",
      },
    ],
  },
  quickActions: [
    {
      id: "members",
      actionKey: "review_members",
      title: "Review membership",
      subtitle: "Open pending applications.",
      route: "/admin/membership",
      iconKey: "crown",
      category: "supporters",
      clubId: 24,
      requiredRole: "club_admin",
      sortOrder: 1,
      accessToken: "private-token",
    },
  ],
  session: {
    accessToken: "private-token",
  },
};

function renderDashboard() {
  return render(<AdminDashboardSurface />);
}

describe("admin dashboard helpers", () => {
  it("bounds the DTO and excludes private fields and unsafe actions", () => {
    const normalized = normalizeAdminDashboardOverview({
      ...overview,
      snapshot: {
        ...overview.snapshot,
        activity: [
          ...overview.snapshot.activity,
          overview.snapshot.activity[0],
          { id: "invalid", title: "" },
        ],
      },
      quickActions: [
        ...overview.quickActions,
        overview.quickActions[0],
        {
          ...overview.quickActions[0],
          id: "unsafe",
          route: "https://attacker.invalid/admin",
        },
      ],
    });

    expect(normalized?.snapshot.activity).toHaveLength(1);
    expect(normalized?.quickActions).toHaveLength(1);
    expect(JSON.stringify(normalized)).not.toContain("private@example.com");
    expect(JSON.stringify(normalized)).not.toContain("private-token");
    expect(JSON.stringify(normalized)).not.toContain("attacker.invalid");
  });

  it("fails closed when the required metric contract is incomplete", () => {
    expect(
      normalizeAdminDashboardOverview({
        ...overview,
        snapshot: {
          ...overview.snapshot,
          metrics: { activeUsers: 1 },
        },
      }),
    ).toBeNull();
  });

  it("maps controlled response failures without using raw diagnostics", () => {
    expect(
      resolveAdminDashboardFailure(
        new AdminApiError("private", 403, "ADMIN_ACCESS_DENIED"),
      ),
    ).toBe("permission_denied");
    expect(
      resolveAdminDashboardFailure(
        new AdminApiError("private", 409, "STALE_RECORD"),
      ),
    ).toBe("conflict");
    expect(
      resolveAdminDashboardFailure(
        new AdminApiError("private", 504, "ADMIN_OPERATION_TIMEOUT"),
      ),
    ).toBe("security_timeout");
    expect(resolveAdminDashboardFailure(new Error("private"), false)).toBe(
      "offline",
    );
  });
});

describe("AdminDashboardSurface", () => {
  beforeEach(() => {
    vi.useRealTimers();
    vi.mocked(requestAdminApi).mockReset();
    Object.defineProperty(window.navigator, "onLine", {
      configurable: true,
      value: true,
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("renders confirmed data and supports a real selected action", async () => {
    vi.mocked(requestAdminApi).mockResolvedValue(overview);
    const { container } = renderDashboard();

    await screen.findByText("Membership reviewed");
    expect(
      container.querySelector(".admin-dashboard-state-surface"),
    ).toHaveAttribute("data-admin-dashboard-status", "ready");

    const action = screen.getByRole("button", {
      name: /review membership/i,
    });
    fireEvent.click(action);
    expect(action).toHaveAttribute("aria-pressed", "true");
    expect(
      container.querySelector(".admin-dashboard-state-surface"),
    ).toHaveAttribute("data-admin-dashboard-interaction", "selected");
    expect(
      screen.getByRole("link", {
        name: /open selected: review membership/i,
      }),
    ).toHaveAttribute("href", "/admin/membership?club=24");
  });

  it("searches, sorts, and paginates recent authenticated activity", async () => {
    vi.mocked(requestAdminApi).mockResolvedValue({
      ...overview,
      snapshot: {
        ...overview.snapshot,
        activity: [
          ...overview.snapshot.activity,
          {
            id: "audit-2",
            title: "Fixture published",
            detail: "A league fixture became visible.",
            createdAt: "2026-07-28T12:00:00.000Z",
          },
          ...Array.from({ length: 4 }, (_, index) => ({
            id: `audit-extra-${index}`,
            title: `Operational record ${index + 1}`,
            detail: "A bounded operational record was confirmed.",
            createdAt: `2026-07-${String(27 - index).padStart(2, "0")}T12:00:00.000Z`,
          })),
        ],
      },
    });
    renderDashboard();

    await screen.findByText("Membership reviewed");
    expect(screen.getAllByTestId("admin-dashboard-activity")).toHaveLength(5);
    expect(
      screen.getByRole("button", { name: /go to next page/i }),
    ).toBeEnabled();

    fireEvent.change(
      screen.getByRole("searchbox", {
        name: /search recent admin activity/i,
      }),
      { target: { value: "fixture" } },
    );
    expect(screen.getByText("Fixture published")).toBeVisible();
    expect(screen.queryByText("Membership reviewed")).toBeNull();
    expect(screen.getByText("1–1 of 1")).toBeVisible();

    fireEvent.change(
      screen.getByRole("searchbox", {
        name: /search recent admin activity/i,
      }),
      { target: { value: "" } },
    );
    fireEvent.click(screen.getByRole("button", { name: "Sort: Title" }));
    const visibleTitles = screen
      .getAllByTestId("admin-dashboard-activity")
      .map((item) => item.querySelector("p")?.textContent);
    expect(visibleTitles).toEqual([
      "Fixture published",
      "Membership reviewed",
      "Operational record 1",
      "Operational record 2",
      "Operational record 3",
    ]);
  });

  it("renders a controlled empty state", async () => {
    vi.mocked(requestAdminApi).mockResolvedValue({
      snapshot: {
        metrics: {
          activeUsers: 0,
          pendingVerifications: 0,
          activeSupportCircles: 0,
          recentTicketSales: 0,
          totalFans: 0,
          ticketRevenue: 0,
        },
        activity: [],
      },
      quickActions: [],
    });
    const { container } = renderDashboard();

    await screen.findAllByText("No admin activity yet");
    expect(
      container.querySelector(".admin-dashboard-state-surface"),
    ).toHaveAttribute("data-admin-dashboard-status", "empty");
  });

  it.each([
    [403, "permission_denied", "Dashboard access denied"],
    [409, "conflict", "Admin records changed"],
    [500, "error", "Dashboard unavailable"],
    [504, "security_timeout", "Admin request timed out"],
  ] as const)(
    "maps HTTP %s to %s and suppresses diagnostics",
    async (httpStatus, expectedStatus, expectedLabel) => {
      vi.mocked(requestAdminApi).mockRejectedValue(
        new AdminApiError(
          "database.internal service_role=private",
          httpStatus,
          httpStatus === 409
            ? "STALE_RECORD"
            : httpStatus === 504
              ? "ADMIN_OPERATION_TIMEOUT"
              : null,
        ),
      );
      const { container } = renderDashboard();

      await screen.findAllByText(expectedLabel);
      expect(
        container.querySelector(".admin-dashboard-state-surface"),
      ).toHaveAttribute("data-admin-dashboard-status", expectedStatus);
      expect(screen.queryByText(/database\.internal/i)).toBeNull();
      expect(screen.queryByText(/service_role/i)).toBeNull();
    },
  );

  it("retains confirmed data during syncing and conflict", async () => {
    let rejectRefresh: ((error: unknown) => void) | undefined;
    vi.mocked(requestAdminApi)
      .mockResolvedValueOnce(overview)
      .mockImplementationOnce(
        () =>
          new Promise<never>((_resolve, reject) => {
            rejectRefresh = reject;
          }),
      );
    const { container } = renderDashboard();
    await screen.findByText("Membership reviewed");

    fireEvent.click(
      screen.getByRole("button", { name: /refresh dashboard/i }),
    );
    await waitFor(() =>
      expect(
        container.querySelector(".admin-dashboard-state-surface"),
      ).toHaveAttribute("data-admin-dashboard-status", "syncing"),
    );
    expect(screen.getByText("Membership reviewed")).toBeVisible();

    rejectRefresh?.(new AdminApiError("private", 409, "STALE_RECORD"));
    await waitFor(() =>
      expect(
        container.querySelector(".admin-dashboard-state-surface"),
      ).toHaveAttribute("data-admin-dashboard-status", "conflict"),
    );
    expect(screen.getByText("Membership reviewed")).toBeVisible();
  });

  it("clears confirmed data after permission is revoked", async () => {
    vi.mocked(requestAdminApi)
      .mockResolvedValueOnce(overview)
      .mockRejectedValueOnce(
        new AdminApiError("private", 403, "ADMIN_ACCESS_DENIED"),
      );
    const { container } = renderDashboard();
    await screen.findByText("Membership reviewed");

    fireEvent.click(
      screen.getByRole("button", { name: /refresh dashboard/i }),
    );
    await waitFor(() =>
      expect(
        container.querySelector(".admin-dashboard-state-surface"),
      ).toHaveAttribute("data-admin-dashboard-status", "permission_denied"),
    );
    expect(screen.queryByText("Membership reviewed")).toBeNull();
  });

  it("records actual focus and pointer press states", async () => {
    vi.mocked(requestAdminApi).mockResolvedValue(overview);
    const { container } = renderDashboard();
    await screen.findByText("Membership reviewed");
    const refresh = screen.getByRole("button", {
      name: /refresh dashboard/i,
    });

    fireEvent.focus(refresh);
    expect(
      container.querySelector(".admin-dashboard-state-surface"),
    ).toHaveAttribute("data-admin-dashboard-interaction", "focused");
    fireEvent.pointerDown(refresh);
    expect(
      container.querySelector(".admin-dashboard-state-surface"),
    ).toHaveAttribute("data-admin-dashboard-interaction", "pressed");
  });

  it("maps the local operation deadline to a security timeout", async () => {
    vi.useFakeTimers();
    vi.mocked(requestAdminApi).mockImplementation(
      () => new Promise<never>(() => {}),
    );
    const { container } = renderDashboard();

    await act(async () => {
      await vi.advanceTimersByTimeAsync(12_000);
    });
    expect(
      container.querySelector(".admin-dashboard-state-surface"),
    ).toHaveAttribute("data-admin-dashboard-status", "security_timeout");
    expect(screen.queryByText("Membership reviewed")).toBeNull();
  });
});

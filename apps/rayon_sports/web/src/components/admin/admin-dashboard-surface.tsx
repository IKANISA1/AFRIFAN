"use client";

import Link from "next/link";
import {
  type PointerEvent,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from "react";
import {
  Activity,
  Bell,
  CalendarDays,
  Crown,
  HelpCircle,
  Newspaper,
  RefreshCw,
  Search,
  Settings,
  ShoppingBag,
  Users,
  type LucideIcon,
} from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { KPISummaryRibbon, KPITile } from "@/components/admin/kpi-summary-ribbon";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { withAdminClubScope } from "@/lib/admin-club-scope";
import { AdminApiError, requestAdminApi } from "@/lib/data/admin/http";
import type {
  AdminActivityRecord,
  AdminDashboardAction,
  AdminDashboardSnapshot,
  AdminRole,
} from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { cn } from "@/lib/utils";

const ADMIN_DASHBOARD_TIMEOUT_MS = 12_000;
const maxActivityRecords = 10;
const maxQuickActions = 12;

export type AdminDashboardStatus =
  | "loading"
  | "ready"
  | "empty"
  | "error"
  | "offline"
  | "permission_denied"
  | "syncing"
  | "conflict"
  | "security_timeout";

type AdminDashboardInteraction = "idle" | "focused" | "pressed" | "selected";

export type AdminDashboardOverview = {
  snapshot: AdminDashboardSnapshot;
  quickActions: AdminDashboardAction[];
};

const emptyOverview: AdminDashboardOverview = {
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
};

const statusCopy: Record<
  AdminDashboardStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading operations dashboard",
    detail: "Waiting for the first authenticated club snapshot.",
  },
  ready: {
    label: "Operations dashboard confirmed",
    detail: "Metrics, activity, and authorized actions are current.",
  },
  empty: {
    label: "No admin activity yet",
    detail: "The authenticated club scope has no operational activity.",
  },
  error: {
    label: "Dashboard unavailable",
    detail: "Confirmed data remains visible. Retry when service recovers.",
  },
  offline: {
    label: "Admin workspace is offline",
    detail: "Confirmed data remains visible until connection returns.",
  },
  permission_denied: {
    label: "Dashboard access denied",
    detail: "Previously loaded admin data has been cleared.",
  },
  syncing: {
    label: "Refreshing admin operations",
    detail: "Confirmed data remains visible during refresh.",
  },
  conflict: {
    label: "Admin records changed",
    detail: "Refresh before acting on the current club snapshot.",
  },
  security_timeout: {
    label: "Admin request timed out",
    detail: "No operation or change was confirmed.",
  },
};

const quickActionIcons: Record<string, LucideIcon> = {
  bell: Bell,
  calendar: CalendarDays,
  crown: Crown,
  newspaper: Newspaper,
  settings: Settings,
  shopping_bag: ShoppingBag,
  users: Users,
};

const adminRoles = new Set<AdminRole>([
  "super_admin",
  "admin",
  "club_admin",
  "club_moderator",
  "fan",
]);

type ActivitySortKey = "createdAt" | "title";

function activityId(item: AdminActivityRecord) {
  return item.id;
}

function activitySearchValues(item: AdminActivityRecord) {
  return [item.title, item.detail, item.createdAt];
}

function activitySortValue(
  item: AdminActivityRecord,
  key: ActivitySortKey,
) {
  return key === "createdAt" ? new Date(item.createdAt) : item.title;
}

function record(value: unknown): Record<string, unknown> | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function boundedString(value: unknown, maxLength: number) {
  if (typeof value !== "string") {
    return null;
  }
  const normalized = value.trim();
  return normalized && normalized.length <= maxLength ? normalized : null;
}

function boundedNumber(value: unknown) {
  return typeof value === "number" &&
    Number.isFinite(value) &&
    value >= 0 &&
    value <= 1_000_000_000_000
    ? value
    : null;
}

function safeAdminRoute(value: unknown) {
  const route = boundedString(value, 180);
  if (
    route == null ||
    !route.startsWith("/") ||
    route.startsWith("//") ||
    route.includes("\\")
  ) {
    return null;
  }

  try {
    const parsed = new URL(route, "https://admin.invalid");
    if (
      parsed.origin !== "https://admin.invalid" ||
      (parsed.pathname !== "/admin" &&
        !parsed.pathname.startsWith("/admin/"))
    ) {
      return null;
    }
    return `${parsed.pathname}${parsed.search}${parsed.hash}`;
  } catch {
    return null;
  }
}

function normalizeActivity(value: unknown): AdminActivityRecord | null {
  const item = record(value);
  if (item == null) {
    return null;
  }
  const id = boundedString(item.id, 120);
  const title = boundedString(item.title, 160);
  const detail = boundedString(item.detail, 360);
  const createdAt = boundedString(item.createdAt, 64);
  if (
    id == null ||
    title == null ||
    detail == null ||
    createdAt == null ||
    !Number.isFinite(Date.parse(createdAt))
  ) {
    return null;
  }
  return { id, title, detail, createdAt };
}

function normalizeAction(value: unknown): AdminDashboardAction | null {
  const item = record(value);
  if (item == null) {
    return null;
  }
  const id = boundedString(item.id, 120);
  const actionKey = boundedString(item.actionKey, 120);
  const title = boundedString(item.title, 160);
  const route = safeAdminRoute(item.route);
  const iconKey = boundedString(item.iconKey, 80);
  const category = boundedString(item.category, 80);
  const subtitle =
    item.subtitle == null ? null : boundedString(item.subtitle, 240);
  const requiredRole =
    item.requiredRole == null
      ? null
      : typeof item.requiredRole === "string" &&
          adminRoles.has(item.requiredRole as AdminRole)
        ? (item.requiredRole as AdminRole)
        : undefined;
  const sortOrder = boundedNumber(item.sortOrder);
  const clubId =
    item.clubId == null ? null : boundedNumber(item.clubId);

  if (
    id == null ||
    actionKey == null ||
    title == null ||
    route == null ||
    iconKey == null ||
    category == null ||
    subtitle === undefined ||
    requiredRole === undefined ||
    sortOrder == null ||
    clubId === undefined
  ) {
    return null;
  }

  return {
    id,
    actionKey,
    title,
    subtitle,
    route,
    iconKey,
    category,
    clubId,
    requiredRole,
    sortOrder,
  };
}

export function normalizeAdminDashboardOverview(
  value: unknown,
): AdminDashboardOverview | null {
  const payload = record(value);
  const snapshot = record(payload?.snapshot);
  const metrics = record(snapshot?.metrics);
  if (
    payload == null ||
    snapshot == null ||
    metrics == null ||
    !Array.isArray(snapshot.activity) ||
    !Array.isArray(payload.quickActions)
  ) {
    return null;
  }

  const activeUsers = boundedNumber(metrics.activeUsers);
  const pendingVerifications = boundedNumber(metrics.pendingVerifications);
  const activeSupportCircles = boundedNumber(metrics.activeSupportCircles);
  const recentTicketSales = boundedNumber(metrics.recentTicketSales);
  const totalFans = boundedNumber(metrics.totalFans);
  const ticketRevenue = boundedNumber(metrics.ticketRevenue);
  if (
    activeUsers == null ||
    pendingVerifications == null ||
    activeSupportCircles == null ||
    recentTicketSales == null ||
    totalFans == null ||
    ticketRevenue == null
  ) {
    return null;
  }

  const activity: AdminActivityRecord[] = [];
  const activityIds = new Set<string>();
  for (const raw of snapshot.activity) {
    const item = normalizeActivity(raw);
    if (item != null && !activityIds.has(item.id)) {
      activityIds.add(item.id);
      activity.push(item);
    }
    if (activity.length === maxActivityRecords) {
      break;
    }
  }

  const quickActions: AdminDashboardAction[] = [];
  const actionIds = new Set<string>();
  for (const raw of payload.quickActions) {
    const item = normalizeAction(raw);
    if (item != null && !actionIds.has(item.id)) {
      actionIds.add(item.id);
      quickActions.push(item);
    }
    if (quickActions.length === maxQuickActions) {
      break;
    }
  }

  return {
    snapshot: {
      metrics: {
        activeUsers,
        pendingVerifications,
        activeSupportCircles,
        recentTicketSales,
        totalFans,
        ticketRevenue,
      },
      activity,
    },
    quickActions,
  };
}

export function isAdminDashboardOverviewEmpty(
  overview: AdminDashboardOverview,
) {
  return (
    overview.quickActions.length === 0 &&
    overview.snapshot.activity.length === 0 &&
    Object.values(overview.snapshot.metrics).every((value) => value === 0)
  );
}

class AdminDashboardTimeoutError extends Error {
  constructor() {
    super("Admin dashboard timed out.");
    this.name = "AdminDashboardTimeoutError";
  }
}

export function resolveAdminDashboardFailure(
  error: unknown,
  online = true,
): AdminDashboardStatus {
  if (!online) {
    return "offline";
  }
  if (error instanceof AdminDashboardTimeoutError) {
    return "security_timeout";
  }
  if (error instanceof AdminApiError) {
    if (error.status === 401 || error.status === 403) {
      return "permission_denied";
    }
    if (error.status === 409 || error.code === "STALE_RECORD") {
      return "conflict";
    }
    if (error.status === 504 || error.code === "ADMIN_OPERATION_TIMEOUT") {
      return "security_timeout";
    }
  }
  return "error";
}

export function AdminDashboardSurface() {
  const { access, activeClub } = useAdminPortal();
  const [overview, setOverview] =
    useState<AdminDashboardOverview>(emptyOverview);
  const [status, setStatus] = useState<AdminDashboardStatus>("loading");
  const [interaction, setInteraction] =
    useState<AdminDashboardInteraction>("idle");
  const [hasConfirmed, setHasConfirmed] = useState(false);
  const [selectedActionId, setSelectedActionId] = useState<string | null>(null);
  const hasConfirmedRef = useRef(false);
  const activeController = useRef<AbortController | null>(null);
  const mounted = useRef(true);
  const activityCollection = useAdminCollection<
    AdminActivityRecord,
    ActivitySortKey
  >({
    records: overview.snapshot.activity,
    getId: activityId,
    getSearchValues: activitySearchValues,
    getSortValue: activitySortValue,
    initialSortKey: "createdAt" as const,
    initialSortDirection: "descending",
    pageSize: 5,
  });

  const loadDashboard = useCallback(async () => {
    if (typeof navigator !== "undefined" && !navigator.onLine) {
      setStatus("offline");
      return;
    }

    activeController.current?.abort();
    const controller = new AbortController();
    activeController.current = controller;
    setStatus(hasConfirmedRef.current ? "syncing" : "loading");
    let timeoutId: ReturnType<typeof setTimeout> | undefined;

    try {
      const result = await Promise.race([
        requestAdminApi<unknown>("dashboard-overview", {
          signal: controller.signal,
        }),
        new Promise<never>((_resolve, reject) => {
          timeoutId = setTimeout(() => {
            controller.abort();
            reject(new AdminDashboardTimeoutError());
          }, ADMIN_DASHBOARD_TIMEOUT_MS);
        }),
      ]);
      const normalized = normalizeAdminDashboardOverview(result);
      if (normalized == null) {
        throw new Error("Invalid admin dashboard response.");
      }
      if (!mounted.current) {
        return;
      }
      setOverview(normalized);
      setHasConfirmed(true);
      hasConfirmedRef.current = true;
      setSelectedActionId((current) =>
        current != null &&
        normalized.quickActions.some((item) => item.id === current)
          ? current
          : null,
      );
      setStatus(
        isAdminDashboardOverviewEmpty(normalized) ? "empty" : "ready",
      );
    } catch (caught) {
      if (
        caught instanceof DOMException &&
        caught.name === "AbortError" &&
        activeController.current !== controller
      ) {
        return;
      }
      if (!mounted.current) {
        return;
      }
      const nextStatus = resolveAdminDashboardFailure(
        caught,
        typeof navigator === "undefined" ? true : navigator.onLine,
      );
      if (nextStatus === "permission_denied") {
        setOverview(emptyOverview);
        setHasConfirmed(false);
        hasConfirmedRef.current = false;
        setSelectedActionId(null);
      }
      setStatus(nextStatus);
    } finally {
      if (timeoutId != null) {
        clearTimeout(timeoutId);
      }
      if (activeController.current === controller) {
        activeController.current = null;
      }
    }
  }, []);

  useEffect(() => {
    mounted.current = true;
    void loadDashboard();

    const markOffline = () => setStatus("offline");
    const recoverOnline = () => void loadDashboard();
    window.addEventListener("offline", markOffline);
    window.addEventListener("online", recoverOnline);
    return () => {
      mounted.current = false;
      activeController.current?.abort();
      window.removeEventListener("offline", markOffline);
      window.removeEventListener("online", recoverOnline);
    };
  }, [loadDashboard]);

  const selectedAction = useMemo(
    () =>
      overview.quickActions.find((item) => item.id === selectedActionId) ??
      null,
    [overview.quickActions, selectedActionId],
  );
  const busy = status === "loading" || status === "syncing";
  const copy = statusCopy[status];
  const showConfirmedContent = hasConfirmed;
  const metrics = overview.snapshot.metrics;

  const pointerPressed = useRef(false);
  const setPointerPressed = (event: PointerEvent<HTMLButtonElement>) => {
    event.currentTarget.setPointerCapture?.(event.pointerId);
    pointerPressed.current = true;
    setInteraction("pressed");
  };
  const restInteraction = () => {
    if (!pointerPressed.current) {
      setInteraction(selectedActionId == null ? "idle" : "selected");
    }
  };
  const finishPointer = () => {
    pointerPressed.current = false;
    restInteraction();
  };
  const focusInteraction = () => {
    if (!pointerPressed.current) setInteraction("focused");
  };

  return (
    <section
      className="admin-dashboard-state-surface section-grid !gap-6"
      data-admin-dashboard-status={status}
      data-admin-dashboard-interaction={interaction}
      data-admin-dashboard-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Control center"
        title="Operations dashboard"
        meta={
          <>
            <AdminStatusBadge
              label={access.hasAccess ? "Operational" : "Read only"}
              tone={access.hasAccess ? "success" : "warning"}
            />
            <span className="admin-meta-chip">
              {showConfirmedContent
                ? `${overview.snapshot.activity.length} recent events`
                : "Awaiting confirmed data"}
            </span>
          </>
        }
      />

      <div
        className={cn(
          "admin-dashboard-status rounded-2xl border px-4 py-3",
          status === "permission_denied" ||
            status === "error" ||
            status === "security_timeout"
            ? "border-error/30 bg-error/10"
            : status === "offline" || status === "conflict"
              ? "border-warning/30 bg-warning/10"
              : "border-[var(--admin-border)] bg-[var(--admin-widget)]",
        )}
        role={
          status === "error" ||
          status === "permission_denied" ||
          status === "security_timeout"
            ? "alert"
            : "status"
        }
        aria-live={
          status === "error" ||
          status === "permission_denied" ||
          status === "security_timeout"
            ? "assertive"
            : "polite"
        }
      >
        <div className="flex flex-wrap items-center justify-between gap-4">
          <div className="min-w-0">
            <p className="font-medium text-[var(--admin-text-strong)]">
              {copy.label}
            </p>
            <p className="mt-1 text-sm leading-6 text-[var(--admin-secondary)]">
              {copy.detail}
            </p>
          </div>
          <button
            type="button"
            disabled={busy}
            onClick={() => void loadDashboard()}
            onFocus={focusInteraction}
            onBlur={restInteraction}
            onPointerDown={setPointerPressed}
            onPointerUp={finishPointer}
            onPointerCancel={finishPointer}
            onLostPointerCapture={finishPointer}
            className="admin-dashboard-control inline-flex min-h-12 items-center justify-center gap-2 rounded-xl border border-[var(--admin-border)] px-4 py-3 text-sm font-medium text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-raised)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:cursor-not-allowed disabled:bg-[var(--admin-raised)] disabled:text-[var(--admin-text-strong)] motion-reduce:transition-none"
          >
            <RefreshCw
              size={17}
              aria-hidden="true"
              className={busy ? "animate-spin motion-reduce:animate-none" : ""}
            />
            {status === "error" ||
            status === "offline" ||
            status === "conflict" ||
            status === "security_timeout"
              ? "Try again"
              : "Refresh dashboard"}
          </button>
        </div>
      </div>

      {status === "loading" ? (
        <KPISummaryRibbon>
          {Array.from({ length: 4 }).map((_, index) => (
            <Skeleton key={index} className="h-20 rounded-xl" />
          ))}
        </KPISummaryRibbon>
      ) : showConfirmedContent ? (
        <KPISummaryRibbon>
          <KPITile
            label="Active users"
            value={metrics.activeUsers.toLocaleString()}
          />
          <KPITile
            label="Pending tickets"
            value={metrics.pendingVerifications.toLocaleString()}
            tone={metrics.pendingVerifications > 0 ? "warning" : "neutral"}
          />
          <KPITile
            label="Support circles"
            value={metrics.activeSupportCircles.toLocaleString()}
          />
          <KPITile
            label="Recent ticket sales"
            value={metrics.recentTicketSales.toLocaleString()}
          />
        </KPISummaryRibbon>
      ) : null}

      {!showConfirmedContent && status !== "loading" ? (
        <AdminErrorState
          title={copy.label}
          description={copy.detail}
          onRetry={
            status === "permission_denied"
              ? undefined
              : () => void loadDashboard()
          }
        />
      ) : null}

      {showConfirmedContent ? (
        <div className="admin-dashboard-content-grid min-w-0 gap-6">
          <AdminSurface title="Authorized quick actions">
            {overview.quickActions.length === 0 ? (
              <div className="rounded-xl border border-[var(--admin-border)] p-5 text-sm text-[var(--admin-secondary)]">
                No dashboard actions are active for this role and club scope.
              </div>
            ) : (
              <div className="admin-dashboard-actions-grid min-w-0 gap-3">
                {overview.quickActions.map((item) => {
                  const Icon = quickActionIcons[item.iconKey] ?? HelpCircle;
                  const selected = item.id === selectedActionId;
                  return (
                    <button
                      key={item.id}
                      type="button"
                      aria-pressed={selected}
                      onClick={() => {
                        setSelectedActionId(item.id);
                        setInteraction("selected");
                      }}
                      onFocus={focusInteraction}
                      onBlur={restInteraction}
                      onPointerDown={setPointerPressed}
                      onPointerUp={finishPointer}
                      onPointerCancel={finishPointer}
                      onLostPointerCapture={finishPointer}
                      className={cn(
                        "admin-dashboard-action min-h-12 min-w-0 rounded-xl border p-4 text-left transition focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent motion-reduce:transition-none",
                        selected
                          ? "border-[var(--admin-accent)] bg-[var(--admin-accent)]/10"
                          : "border-[var(--admin-border)] bg-[var(--admin-widget)] hover:bg-[var(--admin-raised)]",
                      )}
                    >
                      <span className="flex min-w-0 items-start gap-3">
                        <Icon
                          size={18}
                          aria-hidden="true"
                          className="mt-0.5 shrink-0 text-[var(--admin-accent)]"
                        />
                        <span className="min-w-0">
                          <span className="block break-words text-sm font-medium text-[var(--admin-text-strong)]">
                            {item.title}
                          </span>
                          {item.subtitle ? (
                            <span className="mt-1 block break-words text-xs leading-5 text-[var(--admin-secondary)]">
                              {item.subtitle}
                            </span>
                          ) : null}
                        </span>
                      </span>
                    </button>
                  );
                })}
              </div>
            )}
            <div className="mt-4 flex min-w-0 flex-wrap items-center gap-3">
              {selectedAction ? (
                <>
                  <AdminStatusBadge label="Selected" tone="accent" />
                  <Link
                    href={withAdminClubScope(
                      selectedAction.route,
                      activeClub?.id ?? access.clubId,
                    )}
                    className="admin-dashboard-control inline-flex min-h-12 min-w-0 items-center justify-center rounded-xl bg-action-neutral px-4 py-3 text-sm font-medium text-inverse-foreground focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-white"
                    aria-label={`Open selected: ${selectedAction.title}`}
                  >
                    <span className="break-words">
                      Open selected: {selectedAction.title}
                    </span>
                  </Link>
                </>
              ) : (
                <span
                  aria-disabled="true"
                  className="admin-dashboard-control inline-flex min-h-12 items-center rounded-xl border border-[var(--admin-border)] px-4 py-3 text-sm font-medium text-[var(--admin-secondary)]"
                >
                  Select an authorized action
                </span>
              )}
            </div>
          </AdminSurface>

          <AdminSurface
            title="Recent authenticated activity"
            toolbar={
              <AdminFilterBar>
                <label className="admin-search-field">
                  <Search size={16} aria-hidden="true" />
                  <span className="sr-only">
                    Search recent admin activity
                  </span>
                  <input
                    type="search"
                    value={activityCollection.query}
                    onChange={(event) =>
                      activityCollection.setQuery(event.target.value)
                    }
                    placeholder="Search activity or date"
                  />
                </label>
                {(
                  [
                    ["createdAt", "Date"],
                    ["title", "Title"],
                  ] as const
                ).map(([key, label]) => (
                  <button
                    key={key}
                    type="button"
                    className="dashboard-chip min-h-12"
                    data-active={activityCollection.sortKey === key}
                    aria-pressed={activityCollection.sortKey === key}
                    onClick={() => activityCollection.toggleSort(key)}
                  >
                    Sort: {label}
                  </button>
                ))}
              </AdminFilterBar>
            }
            flush
          >
            <div className="p-4 sm:p-5">
              {activityCollection.pageResult.items.length === 0 ? (
                <div className="rounded-xl border border-[var(--admin-border)] p-5 text-sm text-[var(--admin-secondary)]">
                  {activityCollection.query
                    ? "No recent activity matches the current search."
                    : "No recent activity is recorded for this club scope."}
                </div>
              ) : (
                <ol className="divide-y divide-[var(--admin-border)]">
                  {activityCollection.pageResult.items.map((item) => (
                    <li
                      key={item.id}
                      data-testid="admin-dashboard-activity"
                      className="min-w-0 py-4 first:pt-0 last:pb-0"
                    >
                      <div className="flex min-w-0 items-start gap-3">
                        <Activity
                          size={17}
                          aria-hidden="true"
                          className="mt-0.5 shrink-0 text-[var(--admin-accent)]"
                        />
                        <div className="min-w-0">
                          <p className="break-words text-sm font-medium text-[var(--admin-text-strong)]">
                            {item.title}
                          </p>
                          <p className="mt-1 break-words text-xs leading-5 text-[var(--admin-secondary)]">
                            {item.detail}
                          </p>
                          <time
                            dateTime={item.createdAt}
                            className="mt-2 block text-xs font-medium text-[var(--admin-secondary)]"
                          >
                            {new Intl.DateTimeFormat("en-RW", {
                              dateStyle: "medium",
                              timeStyle: "short",
                            }).format(new Date(item.createdAt))}
                          </time>
                        </div>
                      </div>
                    </li>
                  ))}
                </ol>
              )}
            </div>
            <AdminPagination
              page={activityCollection.pageResult}
              onPageChange={activityCollection.setPage}
              label="Recent admin activity"
            />
          </AdminSurface>
        </div>
      ) : null}
    </section>
  );
}

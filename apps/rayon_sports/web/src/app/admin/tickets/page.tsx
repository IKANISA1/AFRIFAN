"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { CheckCircle2, Clock, Eye, Search, Ticket } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminSelectionBar } from "@/components/admin/admin-selection-bar";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import {
  bulkUpdateTicketStatus,
  canAdminTransitionTicketStatus,
  getAdminTicketBulkEligibility,
  getAdminTicketOrders,
  normalizeAdminTicketOrders,
  updateTicketStatus,
  type AdminTicketOrder,
  type AdminTicketStatusAction,
} from "@/lib/data/admin/tickets";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  filterAdminRecords,
  paginateAdminRecords,
  pruneAdminSelection,
  setAdminPageSelection,
  stableSortAdminRecords,
  toggleAdminSelection,
  type AdminSortDirection,
} from "@/lib/admin-collection";
import { formatCurrency } from "@/lib/utils";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";

type TicketSortKey =
  "supporter" | "match" | "amount" | "status" | "purchasedAt";

interface PendingTicketAction {
  orders: AdminTicketOrder[];
  status: AdminTicketStatusAction;
}

const pageSize = 25;
const emptyOrders: AdminTicketOrder[] = [];
const ordersAreEmpty = (orders: AdminTicketOrder[]) => orders.length === 0;

const statusActionLabels: Record<AdminTicketStatusAction, string> = {
  valid: "Validate",
  used: "Mark used",
  cancelled: "Cancel",
};

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading ticket operations",
    detail: "Waiting for the first authenticated, club-scoped snapshot.",
  },
  ready: {
    label: "Ticket operations confirmed",
    detail: "The latest bounded ticket queue is ready for review.",
  },
  empty: {
    label: "No tickets in this club",
    detail: "The club-scoped ticket queue is confirmed and empty.",
  },
  error: {
    label: "Ticket operations unavailable",
    detail: "Confirmed orders remain visible. Retry when the service recovers.",
  },
  offline: {
    label: "Ticket operations are offline",
    detail: "Confirmed orders remain visible while refresh is unavailable.",
  },
  permission_denied: {
    label: "Ticket access denied",
    detail:
      "Orders, supporter details, filters, selections, and drawers were cleared for privacy.",
  },
  syncing: {
    label: "Refreshing ticket operations",
    detail: "Confirmed orders remain visible during the bounded refresh.",
  },
  conflict: {
    label: "Ticket operations changed",
    detail: "Review the retained queue, then refresh before acting.",
  },
  security_timeout: {
    label: "Ticket request timed out",
    detail: "No new snapshot was confirmed. Retry from the retained queue.",
  },
};

export default function AdminTicketsPage() {
  const { access, activeClub, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [filter, setFilter] = useState("");
  const [sortKey, setSortKey] = useState<TicketSortKey>("purchasedAt");
  const [sortDirection, setSortDirection] =
    useState<AdminSortDirection>("descending");
  const [page, setPage] = useState(1);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [detailOrder, setDetailOrder] = useState<AdminTicketOrder | null>(null);
  const [reviewOpen, setReviewOpen] = useState(false);
  const [pendingAction, setPendingAction] =
    useState<PendingTicketAction | null>(null);
  const [mutating, setMutating] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");
  const selectPageRef = useRef<HTMLInputElement | null>(null);

  const clearPrivateState = useCallback(() => {
    setFilter("");
    setPage(1);
    setSelectedIds(new Set());
    setDetailOrder(null);
    setReviewOpen(false);
    setPendingAction(null);
    setInteraction("idle");
  }, []);
  const loadOrders = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyOrders;
      return getAdminTicketOrders(client, access, { signal });
    },
    [access, client],
  );
  const {
    data: orders,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState<AdminTicketOrder[]>({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyOrders,
    isEmpty: ordersAreEmpty,
    load: loadOrders,
    normalize: normalizeAdminTicketOrders,
    onPermissionDenied: clearPrivateState,
    resourceLabel: "ticket operations",
  });
  const mutationLocked =
    mutating || busy || (status !== "ready" && status !== "empty");
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  useEffect(() => {
    const availableIds = new Set(orders.map((order) => order.id));
    setSelectedIds((current) => pruneAdminSelection(current, availableIds));
  }, [orders]);

  async function confirmStatusUpdate() {
    if (!client || pendingAction == null || mutationLocked) return;
    setMutating(true);
    try {
      if (pendingAction.orders.length === 1) {
        await updateTicketStatus(
          client,
          access,
          pendingAction.orders[0],
          pendingAction.status,
        );
      } else {
        await bulkUpdateTicketStatus(
          client,
          access,
          pendingAction.orders,
          pendingAction.status,
        );
      }
      showAdminToast(
        `${pendingAction.orders.length} ${
          pendingAction.orders.length === 1 ? "ticket" : "tickets"
        } updated.`,
        "success",
      );
      setPendingAction(null);
      setSelectedIds(new Set());
      await refresh();
    } catch (error) {
      if (isAdminMutationConflict(error)) {
        await refresh();
      }
      const nextStatus = applyFailure(error);
      showAdminToast(statusCopy[nextStatus].label, "error");
    } finally {
      setMutating(false);
    }
  }

  const sortedOrders = useMemo(() => {
    const filtered = filterAdminRecords(orders, filter, (order) => [
      order.userName,
      order.userPhone,
      order.matchTitle,
      order.momoReference,
      order.seatType,
      order.status,
    ]);
    return stableSortAdminRecords(
      filtered,
      (order) => {
        switch (sortKey) {
          case "supporter":
            return order.userName;
          case "match":
            return order.matchTitle;
          case "amount":
            return order.amountPaid;
          case "status":
            return order.status;
          case "purchasedAt":
            return new Date(order.purchasedAt);
        }
      },
      sortDirection,
    );
  }, [filter, orders, sortDirection, sortKey]);

  const orderPage = useMemo(
    () => paginateAdminRecords(sortedOrders, page, pageSize),
    [page, sortedOrders],
  );
  const selectedOrders = useMemo(
    () => orders.filter((order) => selectedIds.has(order.id)),
    [orders, selectedIds],
  );
  const pageIds = orderPage.items.map((order) => order.id);
  const selectedOnPage = pageIds.filter((id) => selectedIds.has(id)).length;
  const allPageSelected =
    pageIds.length > 0 && selectedOnPage === pageIds.length;

  useEffect(() => {
    if (selectPageRef.current) {
      selectPageRef.current.indeterminate =
        selectedOnPage > 0 && !allPageSelected;
    }
  }, [allPageSelected, selectedOnPage]);

  function commitSelection(next: Set<string>) {
    if (next.size > 100) {
      showAdminToast(
        "A single reviewed bulk action is limited to 100 tickets.",
        "error",
      );
      return;
    }
    setSelectedIds(next);
  }

  function changeSort(nextSortKey: TicketSortKey) {
    setPage(1);
    if (sortKey === nextSortKey) {
      setSortDirection((current) =>
        current === "ascending" ? "descending" : "ascending",
      );
      return;
    }
    setSortKey(nextSortKey);
    setSortDirection(
      nextSortKey === "purchasedAt" ? "descending" : "ascending",
    );
  }

  function sortDirectionFor(column: TicketSortKey) {
    return sortKey === column ? sortDirection : "none";
  }

  function queueStatusAction(
    actionOrders: AdminTicketOrder[],
    status: AdminTicketStatusAction,
  ) {
    if (mutationLocked) return;
    const eligibility = getAdminTicketBulkEligibility(
      access,
      actionOrders,
      status,
    );
    if (!eligibility.allowed) {
      showAdminToast(
        `${eligibility.blocked} selected ${
          eligibility.blocked === 1 ? "ticket is" : "tickets are"
        } not eligible for this transition.`,
        "error",
      );
      return;
    }
    setReviewOpen(false);
    setPendingAction({ orders: actionOrders, status });
  }

  return (
    <div
      className="admin-tickets-state-surface section-grid min-w-0 w-full max-w-full overflow-x-hidden !gap-6"
      data-admin-tickets-status={status}
      data-admin-tickets-interaction={interaction}
    >
      <AdminPageHeader eyebrow="Supporter programs" title="Ticket operations" />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh ticket operations"
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />

      <div className="grid gap-4 md:grid-cols-4">
        <AdminStateCard
          label="Total Tickets"
          value={hasConfirmed ? orders.length.toString() : "—"}
          icon={Ticket}
        />
        <AdminStateCard
          label="Pending"
          value={
            hasConfirmed
              ? orders.filter((o) => o.status === "pending").length.toString()
              : "—"
          }
          tone={
            orders.some((o) => o.status === "pending") ? "warning" : "neutral"
          }
          icon={Clock}
        />
        <AdminStateCard
          label="Validated"
          value={
            hasConfirmed
              ? orders.filter((o) => o.status === "valid").length.toString()
              : "—"
          }
          tone="success"
          icon={CheckCircle2}
        />
        <AdminStateCard
          label="Used"
          value={
            hasConfirmed
              ? orders.filter((o) => o.status === "used").length.toString()
              : "—"
          }
          tone="info"
        />
      </div>

      {initialLoading ? (
        <div
          className="admin-surface p-6"
          aria-label="Loading ticket operations"
        >
          <div className="h-64 animate-pulse rounded-2xl bg-white/5 motion-reduce:animate-none" />
        </div>
      ) : null}

      {!initialLoading && !unrecoveredFailure ? (
        <div className="flex flex-col gap-4" data-admin-tickets-state-surface>
          <div className="relative max-w-md">
            <Search
              size={16}
              className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--admin-zinc-500)]"
            />
            <input
              type="search"
              placeholder="Search by fan, match, or MoMo ref..."
              aria-label="Search ticket orders"
              value={filter}
              onChange={(event) => {
                setFilter(event.target.value);
                setPage(1);
              }}
              className="admin-input !pl-10 w-full"
            />
          </div>

          {!mutationLocked ? (
            <AdminSelectionBar
              selectedCount={selectedIds.size}
              scopeLabel={`${selectedOnPage} selected on this page; scope is the active club only.`}
              onClear={() => setSelectedIds(new Set())}
              onReview={() => setReviewOpen(true)}
              reviewLabel="Review ticket actions"
            />
          ) : null}

          <div className="admin-surface">
            <AdminDataGrid
              caption="Ticket operations queue"
              busy={busy || mutating}
              onRowActivate={(rowId) => {
                const order = orders.find(
                  (candidate) => candidate.id === rowId,
                );
                if (order) setDetailOrder(order);
              }}
              columns={[
                { key: "select", label: "Select", priority: "primary" },
                {
                  key: "fan",
                  label: "Supporter",
                  priority: "primary",
                  sortable: true,
                  sortDirection: sortDirectionFor("supporter"),
                  onSort: () => changeSort("supporter"),
                },
                {
                  key: "match",
                  label: "Match",
                  priority: "primary",
                  sortable: true,
                  sortDirection: sortDirectionFor("match"),
                  onSort: () => changeSort("match"),
                },
                { key: "seat", label: "Type", priority: "secondary" },
                {
                  key: "payment",
                  label: "Payment",
                  priority: "tertiary",
                  sortable: true,
                  sortDirection: sortDirectionFor("amount"),
                  onSort: () => changeSort("amount"),
                },
                {
                  key: "status",
                  label: "Status",
                  priority: "primary",
                  sortable: true,
                  sortDirection: sortDirectionFor("status"),
                  onSort: () => changeSort("status"),
                },
                {
                  key: "date",
                  label: "Purchased",
                  priority: "secondary",
                  sortable: true,
                  sortDirection: sortDirectionFor("purchasedAt"),
                  onSort: () => changeSort("purchasedAt"),
                },
                {
                  key: "actions",
                  label: "Actions",
                  priority: "primary",
                  className: "text-right",
                },
              ]}
            >
              {orderPage.items.length === 0 ? (
                <tr>
                  <td
                    colSpan={8}
                    className="p-12 text-center text-sm text-[var(--admin-zinc-500)]"
                  >
                    {filter
                      ? "No ticket orders match the current search."
                      : "No ticket orders are waiting in this club queue."}
                  </td>
                </tr>
              ) : (
                orderPage.items.map((order) => {
                  const selected = selectedIds.has(order.id);
                  const canValidate = canAdminTransitionTicketStatus(
                    access,
                    order.status,
                    "valid",
                  ).allowed;
                  const canMarkUsed = canAdminTransitionTicketStatus(
                    access,
                    order.status,
                    "used",
                  ).allowed;
                  const canCancel = canAdminTransitionTicketStatus(
                    access,
                    order.status,
                    "cancelled",
                  ).allowed;
                  return (
                    <tr
                      key={order.id}
                      data-row-id={order.id}
                      aria-selected={selected}
                    >
                      <td>
                        <input
                          type="checkbox"
                          className="h-5 w-5 accent-[var(--club-accent)]"
                          checked={selected}
                          disabled={mutationLocked}
                          onChange={(event) =>
                            commitSelection(
                              toggleAdminSelection(
                                selectedIds,
                                order.id,
                                event.target.checked,
                              ),
                            )
                          }
                          aria-label={`Select ticket for ${order.userName ?? "supporter"}`}
                        />
                      </td>
                      <td>
                        <p className="admin-row-title">{order.userName}</p>
                        <p className="admin-row-meta">{order.userPhone}</p>
                      </td>
                      <td>
                        <p className="text-sm font-medium text-white">
                          {order.matchTitle}
                        </p>
                        <p className="admin-row-meta">Fixture venue</p>
                      </td>
                      <td>
                        <AdminStatusBadge
                          label={order.seatType}
                          tone={
                            order.seatType.toLowerCase().includes("vip")
                              ? "accent"
                              : "neutral"
                          }
                        />
                      </td>
                      <td>
                        <p className="text-sm font-medium text-white">
                          {formatCurrency(
                            order.amountPaid,
                            activeClub?.currencyCode ?? "USD",
                          )}
                        </p>
                        <p className="admin-row-meta">
                          {order.momoReference || "—"}
                        </p>
                      </td>
                      <td>
                        <AdminStatusBadge
                          label={order.status}
                          tone={
                            order.status === "valid"
                              ? "success"
                              : order.status === "used"
                                ? "info"
                                : order.status === "pending"
                                  ? "warning"
                                  : "danger"
                          }
                        />
                      </td>
                      <td className="text-xs text-[var(--admin-zinc-500)]">
                        {new Date(order.purchasedAt).toLocaleDateString(
                          "en-RW",
                        )}
                      </td>
                      <td className="text-right">
                        <div className="flex flex-wrap justify-end gap-2">
                          <button
                            type="button"
                            onClick={() => setDetailOrder(order)}
                            className="admin-action-button"
                            aria-label={`View ticket details for ${order.userName ?? "supporter"}`}
                          >
                            <Eye size={15} aria-hidden="true" />
                            Details
                          </button>
                          {canValidate ? (
                            <button
                              type="button"
                              disabled={mutationLocked}
                              onClick={() =>
                                queueStatusAction([order], "valid")
                              }
                              className="admin-action-button !bg-emerald-500/10 !text-emerald-400"
                            >
                              Validate
                            </button>
                          ) : null}
                          {canMarkUsed ? (
                            <button
                              type="button"
                              disabled={mutationLocked}
                              onClick={() => queueStatusAction([order], "used")}
                              className="admin-action-button !bg-blue-500/10 !text-blue-400"
                            >
                              Mark used
                            </button>
                          ) : null}
                          {canCancel ? (
                            <button
                              type="button"
                              disabled={mutationLocked}
                              onClick={() =>
                                queueStatusAction([order], "cancelled")
                              }
                              className="admin-action-button !bg-rose-500/10 !text-rose-400"
                            >
                              Cancel
                            </button>
                          ) : null}
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </AdminDataGrid>
            <div className="admin-toolbar border-t border-[var(--admin-border)] !pb-4">
              <label className="flex min-h-12 items-center gap-3 text-sm text-[var(--admin-text-muted)]">
                <input
                  ref={selectPageRef}
                  type="checkbox"
                  className="h-5 w-5 accent-[var(--club-accent)]"
                  checked={allPageSelected}
                  aria-checked={
                    selectedOnPage > 0 && !allPageSelected
                      ? "mixed"
                      : allPageSelected
                  }
                  disabled={mutationLocked || pageIds.length === 0}
                  onChange={(event) =>
                    commitSelection(
                      setAdminPageSelection(
                        selectedIds,
                        pageIds,
                        event.target.checked,
                      ),
                    )
                  }
                />
                Select all {pageIds.length} records on this page
              </label>
            </div>
            <AdminPagination
              page={orderPage}
              onPageChange={setPage}
              label="Ticket orders"
            />
          </div>
        </div>
      ) : null}

      <AdminActionDrawer
        open={detailOrder != null}
        onClose={() => setDetailOrder(null)}
        title="Ticket order details"
      >
        {detailOrder ? (
          <dl className="grid gap-5 text-sm">
            <TicketDetail
              label="Supporter"
              value={detailOrder.userName ?? "Unknown"}
            />
            <TicketDetail
              label="Phone"
              value={detailOrder.userPhone ?? "Not available"}
            />
            <TicketDetail
              label="Match"
              value={detailOrder.matchTitle ?? "Not available"}
            />
            <TicketDetail label="Seat type" value={detailOrder.seatType} />
            <TicketDetail
              label="Amount paid"
              value={formatCurrency(
                detailOrder.amountPaid,
                activeClub?.currencyCode ?? "USD",
              )}
            />
            <TicketDetail
              label="Payment reference"
              value={detailOrder.momoReference || "Not available"}
            />
            <TicketDetail label="Status" value={detailOrder.status} />
            <TicketDetail
              label="Purchased"
              value={new Date(detailOrder.purchasedAt).toLocaleString("en-RW")}
            />
          </dl>
        ) : null}
      </AdminActionDrawer>

      <AdminActionDrawer
        open={reviewOpen}
        onClose={() => setReviewOpen(false)}
        title="Review selected ticket orders"
        footer={
          <button
            type="button"
            className="admin-action-button w-full"
            onClick={() => setReviewOpen(false)}
          >
            Close review
          </button>
        }
      >
        <div className="space-y-5">
          <div className="rounded-xl border border-[var(--admin-border)] bg-[var(--admin-zinc-950)] p-4">
            <p className="admin-row-title">
              {selectedOrders.length}{" "}
              {selectedOrders.length === 1 ? "ticket" : "tickets"}
            </p>
            <p className="admin-row-copy">
              Scope: active club only. Current role:{" "}
              {access.role ?? "unassigned"}. No record changes until you choose
              an action and confirm it.
            </p>
          </div>
          <div className="space-y-2" aria-label="Bulk ticket actions">
            {(["valid", "used", "cancelled"] as const).map((status) => {
              const eligibility = getAdminTicketBulkEligibility(
                access,
                selectedOrders,
                status,
              );
              return (
                <button
                  key={status}
                  type="button"
                  className={`admin-action-button w-full ${
                    status === "cancelled"
                      ? "admin-action-button-danger"
                      : "!bg-[var(--admin-zinc-800)]"
                  }`}
                  disabled={mutationLocked || !eligibility.allowed}
                  onClick={() => queueStatusAction(selectedOrders, status)}
                  title={
                    eligibility.allowed
                      ? `${statusActionLabels[status]} all selected tickets`
                      : `${eligibility.blocked} selected tickets are ineligible or your role lacks permission`
                  }
                >
                  {statusActionLabels[status]} {selectedOrders.length}
                </button>
              );
            })}
          </div>
        </div>
      </AdminActionDrawer>

      <AdminActionDrawer
        open={pendingAction != null}
        onClose={() => {
          if (!mutating) setPendingAction(null);
        }}
        title="Confirm ticket status change"
        footer={
          pendingAction ? (
            <div className="flex gap-3">
              <button
                type="button"
                className="admin-action-button flex-1"
                onClick={() => setPendingAction(null)}
                disabled={mutationLocked}
              >
                Go back
              </button>
              <button
                type="button"
                className={`admin-action-button flex-1 ${
                  pendingAction.status === "cancelled"
                    ? "admin-action-button-danger !bg-rose-500/15 !text-rose-300"
                    : "!bg-club-accent !text-white"
                }`}
                onClick={() => {
                  confirmStatusUpdate().catch(() => {});
                }}
                disabled={mutationLocked}
              >
                {mutating
                  ? "Applying…"
                  : `Confirm ${statusActionLabels[pendingAction.status]}`}
              </button>
            </div>
          ) : null
        }
      >
        {pendingAction ? (
          <div className="space-y-4">
            <p className="admin-row-copy">
              You are about to{" "}
              {statusActionLabels[pendingAction.status].toLowerCase()}{" "}
              {pendingAction.orders.length}{" "}
              {pendingAction.orders.length === 1 ? "ticket" : "tickets"} in the
              active club.
            </p>
            <div className="rounded-xl border border-[var(--admin-border)] bg-[var(--admin-zinc-950)] p-4">
              <p className="admin-row-title">Safety check</p>
              <p className="admin-row-copy">
                The server will re-check role, club scope, record count, and
                every current status. Any stale or invalid record rolls back the
                full operation. A separate immutable audit record is written for
                each ticket.
              </p>
            </div>
            {pendingAction.status === "cancelled" ? (
              <p className="rounded-xl border border-rose-500/30 bg-rose-500/10 p-4 text-sm text-rose-200">
                Cancellation is destructive and cannot be undone from this
                queue. Confirm only after checking the supporter and payment
                details.
              </p>
            ) : null}
          </div>
        ) : null}
      </AdminActionDrawer>
    </div>
  );
}

function TicketDetail({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-xs font-semibold uppercase tracking-[0.14em] text-[var(--admin-text-muted)]">
        {label}
      </dt>
      <dd className="mt-1 break-words text-[var(--admin-text-strong)]">
        {value}
      </dd>
    </div>
  );
}

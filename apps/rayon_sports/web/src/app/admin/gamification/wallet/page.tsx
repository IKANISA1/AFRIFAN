"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Coins, RefreshCcw, Search, Wallet } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminSurface } from "@/components/admin/admin-surface";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  adjustAdminFetWalletBalance,
  getAdminFetWalletSnapshot,
  normalizeAdminFetWalletSnapshot,
} from "@/lib/data/admin";
import type {
  AdminFetWalletLedgerRow,
  AdminFetWalletSnapshot,
} from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";

const emptySnapshot: AdminFetWalletSnapshot = {
  overview: [],
  ledger: [],
};
const walletSnapshotIsEmpty = (snapshot: AdminFetWalletSnapshot) =>
  snapshot.overview.length === 0 && snapshot.ledger.length === 0;

const numberFormatter = new Intl.NumberFormat("en");
const timeFormatter = new Intl.DateTimeFormat("en", {
  month: "short",
  day: "numeric",
  hour: "numeric",
  minute: "2-digit",
});

function formatFet(value: number) {
  return `${numberFormatter.format(value)} pts`;
}

function ledgerHeadline(row: AdminFetWalletLedgerRow) {
  switch (row.entryType) {
    case "transfer_in":
      return "Transfer received";
    case "transfer_out":
      return "Transfer sent";
    case "redeem":
      return "Points redemption";
    case "admin_adjustment":
      return row.direction === "credit" ? "Admin top-up" : "Admin deduction";
    case "opening_balance":
      return "Opening balance";
    case "earn":
    default:
      return "Points earned";
  }
}

function ledgerTone(row: AdminFetWalletLedgerRow) {
  return row.direction === "credit"
    ? "admin-wallet-credit"
    : "admin-wallet-debit";
}

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading points operations",
    detail: "Waiting for the first authenticated wallet snapshot.",
  },
  ready: {
    label: "Points operations confirmed",
    detail: "The bounded supporter-account and ledger windows are current.",
  },
  empty: {
    label: "No points activity in this scope",
    detail: "No supporter accounts or wallet entries matched this club scope.",
  },
  error: {
    label: "Points operations unavailable",
    detail:
      "Confirmed wallet data remains visible. Retry when service recovers.",
  },
  offline: {
    label: "Points operations are offline",
    detail:
      "Confirmed wallet data remains visible; adjustments are locked until reconnect.",
  },
  permission_denied: {
    label: "Points operations access denied",
    detail:
      "Previously loaded accounts, ledger rows, filters, selection, details, and adjustment inputs were cleared.",
  },
  syncing: {
    label: "Refreshing points operations",
    detail: "Confirmed wallet data remains visible during the bounded refresh.",
  },
  conflict: {
    label: "Points operations changed",
    detail: "Review the current wallet snapshot before restarting the action.",
  },
  security_timeout: {
    label: "Points operations request timed out",
    detail: "No balance change was confirmed.",
  },
};

export default function AdminGamificationWalletPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [searchDraft, setSearchDraft] = useState("");
  const [search, setSearch] = useState("");
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [adjustmentAmount, setAdjustmentAmount] = useState("");
  const [adjustmentReason, setAdjustmentReason] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");
  const [detailLedgerRow, setDetailLedgerRow] =
    useState<AdminFetWalletLedgerRow | null>(null);
  const adjustmentKey = useRef<string | null>(null);

  const loadSnapshot = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptySnapshot;
      return getAdminFetWalletSnapshot(client, access, {
        search,
        userId: selectedUserId,
        signal,
      });
    },
    [access, client, search, selectedUserId],
  );

  const clearDeniedState = useCallback(() => {
    setSearchDraft("");
    setSearch("");
    setSelectedUserId(null);
    setAdjustmentAmount("");
    setAdjustmentReason("");
    setDetailLedgerRow(null);
    setInteraction("idle");
    adjustmentKey.current = null;
  }, []);

  const {
    data: snapshot,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptySnapshot,
    isEmpty: walletSnapshotIsEmpty,
    load: loadSnapshot,
    normalize: normalizeAdminFetWalletSnapshot,
    onPermissionDenied: clearDeniedState,
    resourceLabel: "points operations",
  });

  const mutationLocked =
    isSubmitting || (status !== "ready" && status !== "empty");
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

  const accountCollection = useAdminCollection({
    records: snapshot.overview,
    getId: (row) => row.userId,
    getSearchValues: (row) => [
      row.displayName,
      row.publicUserId,
      row.tier,
      row.balance,
    ],
    getSortValue: (row, key: "supporter" | "tier" | "balance" | "activity") => {
      switch (key) {
        case "supporter":
          return row.displayName;
        case "tier":
          return row.tier;
        case "balance":
          return row.balance;
        case "activity":
          return row.lastTransactionAt ? new Date(row.lastTransactionAt) : null;
      }
    },
    initialSortKey: "balance" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  const ledgerCollection = useAdminCollection({
    records: snapshot.ledger,
    getId: (row) => row.id,
    getSearchValues: (row) => [
      row.displayName,
      row.publicUserId,
      row.entryType,
      row.direction,
      row.note,
      row.referenceId,
    ],
    getSortValue: (row, key: "supporter" | "type" | "amount" | "createdAt") => {
      switch (key) {
        case "supporter":
          return row.displayName;
        case "type":
          return row.entryType;
        case "amount":
          return row.amount;
        case "createdAt":
          return new Date(row.createdAt);
      }
    },
    initialSortKey: "createdAt" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  useEffect(() => {
    adjustmentKey.current = null;
  }, [adjustmentAmount, adjustmentReason, selectedUserId]);

  const selectedSupporter = useMemo(
    () =>
      snapshot.overview.find((row) => row.userId === selectedUserId) ?? null,
    [selectedUserId, snapshot.overview],
  );

  const totals = useMemo(() => {
    return snapshot.overview.reduce(
      (acc, row) => {
        acc.balance += row.balance;
        acc.earned += row.lifetimeEarned;
        acc.spent += row.lifetimeSpent;
        return acc;
      },
      { balance: 0, earned: 0, spent: 0 },
    );
  }, [snapshot.overview]);

  function selectSupporter(userId: string) {
    setSelectedUserId(userId);
    setInteraction("selected");
  }

  function inspectLedgerRow(rowId: string) {
    setDetailLedgerRow(snapshot.ledger.find((row) => row.id === rowId) ?? null);
    setInteraction("selected");
  }

  async function handleAdjustment() {
    if (client == null || mutationLocked) {
      return;
    }
    const amount = Number(adjustmentAmount);
    const targetUserId = selectedUserId;
    const reason = adjustmentReason.trim();
    if (!targetUserId) {
      showAdminToast("Choose a supporter points account first.", "error");
      return;
    }
    if (
      !Number.isInteger(amount) ||
      amount === 0 ||
      Math.abs(amount) > 1_000_000
    ) {
      showAdminToast(
        "Enter a whole-number adjustment between -1,000,000 and 1,000,000, excluding zero.",
        "error",
      );
      return;
    }
    if (!reason || reason.length > 500) {
      showAdminToast(
        "Provide an adjustment reason of no more than 500 characters.",
        "error",
      );
      return;
    }
    if (
      amount < 0 &&
      !confirmAdminDestructiveAction({
        action: "Deduct",
        subject:
          selectedSupporter?.displayName ??
          selectedSupporter?.publicUserId ??
          "supporter points account",
        scope: `Active club ${access.clubId ?? "not selected"}; one supporter account`,
        impact: `This will remove ${formatFet(Math.abs(Math.trunc(amount)))} from the points account.`,
        undo: "manual_recovery",
      })
    ) {
      return;
    }

    setIsSubmitting(true);
    showAdminToast("Applying wallet adjustment...", "info");
    try {
      adjustmentKey.current ??= `admin-adjust-${crypto.randomUUID()}`;
      const result = await adjustAdminFetWalletBalance(client, access, {
        userId: targetUserId,
        amount,
        reason,
        idempotencyKey: adjustmentKey.current,
      });
      setAdjustmentAmount("");
      setAdjustmentReason("");
      adjustmentKey.current = null;
      await refresh();
      showAdminToast(
        result.alreadyProcessed
          ? "The existing wallet adjustment was reconciled."
          : "Wallet adjustment confirmed.",
        "success",
      );
    } catch (caught) {
      applyFailure(caught);
      showAdminToast("Could not confirm the points balance change.", "error");
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <section
      className="admin-gamification-wallet-state-surface section-grid min-w-0 max-w-full"
      data-admin-gamification-wallet-status={status}
      data-admin-gamification-wallet-interaction={interaction}
      data-admin-gamification-wallet-refresh-disabled={busy}
      data-admin-gamification-wallet-mutation-disabled={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Gamification"
        title="Supporter points operations"
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh points operations"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />

      <div className="admin-gamification-wallet-metrics-grid">
        <AdminStateCard
          label="Points accounts"
          value={initialLoading ? "..." : snapshot.overview.length.toString()}
          helper="Strict supporter window, capped at 60."
          icon={Wallet}
        />
        <AdminStateCard
          label="Total balance"
          value={initialLoading ? "..." : formatFet(totals.balance)}
          helper="Current club-wide supporter balance."
          icon={Coins}
        />
        <AdminStateCard
          label="Lifetime earned"
          value={initialLoading ? "..." : formatFet(totals.earned)}
          helper="All points credits recorded so far."
        />
        <AdminStateCard
          label="Lifetime spent"
          value={initialLoading ? "..." : formatFet(totals.spent)}
          helper="Transfers out, redemptions, and deductions."
        />
      </div>

      <section className="ui-panel rounded-[32px] p-6">
        <div className="flex flex-col gap-3 md:flex-row md:items-end">
          <label className="grid flex-1 gap-2 text-sm text-[var(--admin-text)]">
            Search supporters or reference IDs
            <div className="relative">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-[var(--admin-text-muted)]" />
              <input
                disabled={busy}
                maxLength={160}
                value={searchDraft}
                onChange={(event) => setSearchDraft(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter") {
                    event.preventDefault();
                    setSearch(searchDraft.trim());
                  }
                }}
                placeholder="483912, Mukamana, transfer-ref"
                className="admin-input w-full pl-10"
              />
            </div>
          </label>
          <div className="flex gap-3">
            <button
              type="button"
              disabled={busy}
              onClick={() => setSearch(searchDraft.trim())}
              className="admin-button admin-button-primary"
            >
              Apply filter
            </button>
            <button
              type="button"
              disabled={busy}
              onClick={() => {
                setSearchDraft("");
                setSearch("");
                setSelectedUserId(null);
                setDetailLedgerRow(null);
                setInteraction("idle");
              }}
              className="admin-button admin-button-secondary"
            >
              Clear
            </button>
            <button
              type="button"
              disabled={busy || status === "permission_denied"}
              onClick={() => {
                void refresh();
              }}
              className="admin-button admin-button-secondary"
            >
              <RefreshCcw className="h-4 w-4" />
              Refresh
            </button>
          </div>
        </div>
      </section>

      {unrecoveredFailure ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
          retryLabel="Retry points operations"
        />
      ) : initialLoading ? (
        <AdminSurface title="Points operations workspace">
          <div className="space-y-4">
            {Array.from({ length: 4 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] p-4"
              >
                <Skeleton className="skeleton-text h-5 w-1/3" />
                <Skeleton className="skeleton-text mt-2 h-3 w-2/3" />
              </div>
            ))}
          </div>
        </AdminSurface>
      ) : (
        <div className="admin-gamification-wallet-content-grid">
          <section className="ui-panel rounded-[32px] p-6">
            <div className="space-y-5">
              <div>
                <p className="admin-page-eyebrow">Adjust balance</p>
                <h2 className="font-display text-3xl font-medium normal-case">
                  Admin points controls
                </h2>
                <p className="mt-2 text-sm text-[var(--admin-text-muted)]">
                  Choose a supporter from the list below, then apply a positive
                  top-up or a negative deduction with a required audit reason.
                </p>
              </div>

              <div className="grid gap-4 rounded-[28px] border border-[var(--admin-border)] bg-[var(--admin-surface-muted)] p-5">
                <div className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-surface)] p-4">
                  <p className="text-xs normal-case tracking-normal text-[var(--admin-text-muted)]">
                    Selected account
                  </p>
                  <p className="mt-2 font-display text-2xl font-medium normal-case">
                    {selectedSupporter?.displayName ?? "Choose a supporter"}
                  </p>
                  <p className="mt-1 text-sm text-[var(--admin-text-muted)]">
                    {selectedSupporter
                      ? `#${selectedSupporter.publicUserId ?? "Unavailable"} • ${selectedSupporter.tier.toUpperCase()} • ${formatFet(selectedSupporter.balance)}`
                      : "The ledger panel can be filtered per supporter."}
                  </p>
                </div>

                <label className="grid gap-2 text-sm text-[var(--admin-text)]">
                  Adjustment amount
                  <input
                    disabled={mutationLocked}
                    aria-label="Adjustment amount"
                    value={adjustmentAmount}
                    onChange={(event) =>
                      setAdjustmentAmount(event.target.value)
                    }
                    placeholder="Use +250 or -120"
                    inputMode="numeric"
                    className="admin-input"
                  />
                </label>

                <label className="grid gap-2 text-sm text-[var(--admin-text)]">
                  Audit reason
                  <textarea
                    disabled={mutationLocked}
                    maxLength={500}
                    value={adjustmentReason}
                    onChange={(event) =>
                      setAdjustmentReason(event.target.value)
                    }
                    rows={3}
                    placeholder="Explain why the balance changed."
                    className="admin-input min-h-[112px]"
                  />
                </label>

                <button
                  type="button"
                  onClick={() => {
                    handleAdjustment().catch(() => {});
                  }}
                  disabled={mutationLocked}
                  className="admin-button admin-button-primary disabled:opacity-60"
                >
                  {isSubmitting ? "Saving…" : "Apply adjustment"}
                </button>
              </div>

              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <h3 className="font-display text-2xl font-medium normal-case">
                    Supporter balances
                  </h3>
                  {selectedSupporter ? (
                    <button
                      type="button"
                      onClick={() => {
                        setSelectedUserId(null);
                        setInteraction("idle");
                      }}
                      className="admin-action-button"
                    >
                      Clear selection
                    </button>
                  ) : null}
                </div>
                <AdminFilterBar>
                  <label className="admin-search-field">
                    <Search size={16} aria-hidden="true" />
                    <span className="sr-only">
                      Filter loaded supporter accounts
                    </span>
                    <input
                      type="search"
                      maxLength={160}
                      value={accountCollection.query}
                      onChange={(event) =>
                        accountCollection.setQuery(event.target.value)
                      }
                      placeholder="Filter loaded accounts"
                    />
                  </label>
                </AdminFilterBar>
                <AdminDataGrid
                  caption="Supporter points accounts"
                  onRowActivate={selectSupporter}
                  columns={[
                    {
                      key: "supporter",
                      label: "Supporter",
                      priority: "primary",
                      sortable: true,
                      sortDirection:
                        accountCollection.sortDirectionFor("supporter"),
                      onSort: () => accountCollection.toggleSort("supporter"),
                    },
                    {
                      key: "tier",
                      label: "Tier",
                      priority: "secondary",
                      sortable: true,
                      sortDirection: accountCollection.sortDirectionFor("tier"),
                      onSort: () => accountCollection.toggleSort("tier"),
                    },
                    {
                      key: "balance",
                      label: "Balance",
                      priority: "primary",
                      sortable: true,
                      sortDirection:
                        accountCollection.sortDirectionFor("balance"),
                      onSort: () => accountCollection.toggleSort("balance"),
                    },
                    {
                      key: "activity",
                      label: "Last activity",
                      priority: "secondary",
                      sortable: true,
                      sortDirection:
                        accountCollection.sortDirectionFor("activity"),
                      onSort: () => accountCollection.toggleSort("activity"),
                    },
                    { key: "action", label: "Action", priority: "primary" },
                  ]}
                >
                  {accountCollection.pageResult.items.length === 0 ? (
                    <tr>
                      <td
                        colSpan={5}
                        className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                      >
                        No supporter points accounts matched the current filter.
                      </td>
                    </tr>
                  ) : (
                    accountCollection.pageResult.items.map((row) => (
                      <tr
                        key={row.userId}
                        data-row-id={row.userId}
                        aria-selected={row.userId === selectedUserId}
                      >
                        <td>
                          <span className="font-medium text-[var(--admin-text-strong)]">
                            {row.displayName}
                          </span>
                          <span className="block text-xs text-[var(--admin-text-muted)]">
                            #{row.publicUserId ?? "Unavailable"}
                          </span>
                        </td>
                        <td>{row.tier.toUpperCase()}</td>
                        <td className="font-semibold text-[var(--admin-accent)]">
                          {formatFet(row.balance)}
                        </td>
                        <td>
                          {row.lastTransactionAt
                            ? timeFormatter.format(
                                new Date(row.lastTransactionAt),
                              )
                            : "No ledger yet"}
                        </td>
                        <td>
                          <button
                            type="button"
                            className="admin-action-button"
                            onClick={() => selectSupporter(row.userId)}
                          >
                            {row.userId === selectedUserId
                              ? "Selected"
                              : "Select"}
                          </button>
                        </td>
                      </tr>
                    ))
                  )}
                </AdminDataGrid>
                <AdminPagination
                  page={accountCollection.pageResult}
                  onPageChange={accountCollection.setPage}
                  label="Supporter points accounts"
                />
              </div>
            </div>
          </section>

          <section className="ui-panel rounded-[32px] p-6">
            <div className="space-y-5">
              <div>
                <p className="admin-page-eyebrow">Ledger</p>
                <h2 className="font-display text-3xl font-medium normal-case">
                  Wallet activity trail
                </h2>
                <p className="mt-2 text-sm text-[var(--admin-text-muted)]">
                  Review supporter points history including transfers, reward
                  requests, earnings, and manual adjustments.
                </p>
              </div>

              <AdminFilterBar>
                <label className="admin-search-field">
                  <Search size={16} aria-hidden="true" />
                  <span className="sr-only">Filter loaded points ledger</span>
                  <input
                    type="search"
                    maxLength={160}
                    value={ledgerCollection.query}
                    onChange={(event) =>
                      ledgerCollection.setQuery(event.target.value)
                    }
                    placeholder="Filter supporter, type, note, or reference"
                  />
                </label>
              </AdminFilterBar>
              <AdminDataGrid
                caption="Points ledger activity"
                onRowActivate={inspectLedgerRow}
                columns={[
                  {
                    key: "type",
                    label: "Entry",
                    priority: "primary",
                    sortable: true,
                    sortDirection: ledgerCollection.sortDirectionFor("type"),
                    onSort: () => ledgerCollection.toggleSort("type"),
                  },
                  {
                    key: "supporter",
                    label: "Supporter",
                    priority: "primary",
                    sortable: true,
                    sortDirection:
                      ledgerCollection.sortDirectionFor("supporter"),
                    onSort: () => ledgerCollection.toggleSort("supporter"),
                  },
                  {
                    key: "amount",
                    label: "Amount",
                    priority: "primary",
                    sortable: true,
                    sortDirection: ledgerCollection.sortDirectionFor("amount"),
                    onSort: () => ledgerCollection.toggleSort("amount"),
                  },
                  { key: "balance", label: "Balance", priority: "secondary" },
                  {
                    key: "created",
                    label: "Created",
                    priority: "secondary",
                    sortable: true,
                    sortDirection:
                      ledgerCollection.sortDirectionFor("createdAt"),
                    onSort: () => ledgerCollection.toggleSort("createdAt"),
                  },
                ]}
              >
                {ledgerCollection.pageResult.items.length === 0 ? (
                  <tr>
                    <td
                      colSpan={5}
                      className="py-8 text-center text-sm text-[var(--admin-text-muted)]"
                    >
                      No points ledger entries matched the current filters.
                    </td>
                  </tr>
                ) : (
                  ledgerCollection.pageResult.items.map((row) => (
                    <tr key={row.id} data-row-id={row.id}>
                      <td>
                        <span className="font-medium text-[var(--admin-text-strong)]">
                          {ledgerHeadline(row)}
                        </span>
                        <span className="block truncate text-xs text-[var(--admin-text-muted)]">
                          {row.note ?? "No note"}
                        </span>
                      </td>
                      <td>
                        {row.displayName}
                        <span className="block text-xs text-[var(--admin-text-muted)]">
                          #{row.publicUserId ?? "Unavailable"}
                        </span>
                      </td>
                      <td>
                        <span
                          className={`inline-flex rounded-full border px-2 py-1 text-xs normal-case tracking-normal ${ledgerTone(row)}`}
                        >
                          {row.direction === "credit" ? "+" : "-"}
                          {formatFet(row.amount)}
                        </span>
                      </td>
                      <td>{formatFet(row.balanceAfter)}</td>
                      <td>{timeFormatter.format(new Date(row.createdAt))}</td>
                    </tr>
                  ))
                )}
              </AdminDataGrid>
              <AdminPagination
                page={ledgerCollection.pageResult}
                onPageChange={ledgerCollection.setPage}
                label="Points ledger"
              />
            </div>
          </section>
        </div>
      )}
      <AdminActionDrawer
        open={detailLedgerRow != null}
        onClose={() => {
          setDetailLedgerRow(null);
          setInteraction(selectedUserId == null ? "idle" : "selected");
        }}
        title="Points ledger details"
      >
        {detailLedgerRow ? (
          <dl className="grid gap-4 text-sm">
            <div>
              <dt className="text-[var(--admin-text-muted)]">Entry</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {ledgerHeadline(detailLedgerRow)}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Supporter</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {detailLedgerRow.displayName} · #
                {detailLedgerRow.publicUserId ?? "Unavailable"}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Amount</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {detailLedgerRow.direction === "credit" ? "+" : "-"}
                {formatFet(detailLedgerRow.amount)}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Balance after</dt>
              <dd className="mt-1 text-[var(--admin-text-strong)]">
                {formatFet(detailLedgerRow.balanceAfter)}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Note</dt>
              <dd className="mt-1 break-words text-[var(--admin-text-strong)]">
                {detailLedgerRow.note ?? "No note recorded."}
              </dd>
            </div>
            <div>
              <dt className="text-[var(--admin-text-muted)]">Reference</dt>
              <dd className="mt-1 break-all text-[var(--admin-text-strong)]">
                {detailLedgerRow.referenceId ?? "No reference recorded."}
              </dd>
            </div>
          </dl>
        ) : null}
      </AdminActionDrawer>
    </section>
  );
}

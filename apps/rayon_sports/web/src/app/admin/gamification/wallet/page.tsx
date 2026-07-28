"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Coins, RefreshCcw, Search, Wallet } from "lucide-react";
import { AdminActionDrawer } from "@/components/admin/admin-action-drawer";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  adjustAdminFetWalletBalance,
  getAdminFetWalletSnapshot,
} from "@/lib/data/admin";
import type {
  AdminFetWalletAdjustmentResult,
  AdminFetWalletLedgerRow,
  AdminFetWalletSnapshot,
} from "@/lib/types";
import { useAdminCollection } from "@/lib/use-admin-collection";

const emptySnapshot: AdminFetWalletSnapshot = {
  overview: [],
  ledger: [],
};

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
    ? "border-emerald-500/25 bg-emerald-500/6 text-emerald-300"
    : "border-amber-500/25 bg-amber-500/6 text-amber-200";
}

function applyWalletAdjustment(
  current: AdminFetWalletSnapshot,
  input: {
    result: AdminFetWalletAdjustmentResult;
    userId: string;
    displayName: string;
    publicUserId: string | null;
    note: string;
  },
): AdminFetWalletSnapshot {
  if (input.result.alreadyProcessed) {
    return current;
  }

  const createdAt = new Date().toISOString();
  const direction = input.result.amount < 0 ? "debit" : "credit";
  const amount = Math.abs(input.result.amount);

  return {
    overview: current.overview.map((row) => {
      if (row.userId !== input.userId) {
        return row;
      }

      return {
        ...row,
        balance: input.result.balance,
        transactionCount: row.transactionCount + 1,
        lastTransactionAt: createdAt,
        lifetimeEarned:
          direction === "credit"
            ? row.lifetimeEarned + amount
            : row.lifetimeEarned,
        lifetimeSpent:
          direction === "debit"
            ? row.lifetimeSpent + amount
            : row.lifetimeSpent,
      };
    }),
    ledger: [
      {
        id: input.result.referenceId ?? crypto.randomUUID(),
        userId: input.userId,
        publicUserId: input.publicUserId,
        displayName: input.displayName,
        entryType: "admin_adjustment",
        direction,
        amount,
        balanceAfter: input.result.balance,
        counterpartyUserId: null,
        counterpartyDisplayName: null,
        counterpartyPublicUserId: null,
        note: input.note,
        referenceType: "admin_adjustment",
        referenceId: input.result.referenceId,
        createdAt,
      },
      ...current.ledger,
    ],
  };
}

export default function AdminGamificationWalletPage() {
  const { access, client } = useAdminPortal();
  const [snapshot, setSnapshot] = useState(emptySnapshot);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [searchDraft, setSearchDraft] = useState("");
  const [search, setSearch] = useState("");
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [adjustmentAmount, setAdjustmentAmount] = useState("");
  const [adjustmentReason, setAdjustmentReason] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [detailLedgerRow, setDetailLedgerRow] =
    useState<AdminFetWalletLedgerRow | null>(null);

  const accountCollection = useAdminCollection({
    records: snapshot.overview,
    getId: (row) => row.userId,
    getSearchValues: (row) => [
      row.displayName,
      row.publicUserId,
      row.tier,
      row.balance,
    ],
    getSortValue: (
      row,
      key: "supporter" | "tier" | "balance" | "activity",
    ) => {
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
    pageSize: 15,
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
    getSortValue: (
      row,
      key: "supporter" | "type" | "amount" | "createdAt",
    ) => {
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
    pageSize: 20,
  });

  const loadSnapshot = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      const nextSnapshot = await getAdminFetWalletSnapshot(client, access, {
        search,
        userId: selectedUserId,
      });
      setSnapshot(nextSnapshot);
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error
          ? caught.message
          : "Could not load points operations.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client, search, selectedUserId]);

  useEffect(() => {
    if (client == null || !access.hasAccess) {
      return;
    }
    loadSnapshot().catch(() => { });
  }, [access.hasAccess, client, loadSnapshot]);

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

  async function handleAdjustment() {
    if (client == null) {
      return;
    }
    const amount = Number(adjustmentAmount);
    const targetUserId = selectedUserId;
    const reason = adjustmentReason.trim();
    if (!targetUserId) {
      showAdminToast("Choose a supporter points account first.", "error");
      return;
    }
    if (!Number.isFinite(amount) || Math.trunc(amount) === 0) {
      showAdminToast("Enter a non-zero FET adjustment amount.", "error");
      return;
    }
    if (!reason) {
      showAdminToast("Provide a reason for the adjustment.", "error");
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
      const result = await adjustAdminFetWalletBalance(client, access, {
        userId: targetUserId,
        amount: Math.trunc(amount),
        reason,
        idempotencyKey: `admin-adjust-${targetUserId}-${Date.now()}`,
      });
      setAdjustmentAmount("");
      setAdjustmentReason("");
      setSnapshot((current) =>
        applyWalletAdjustment(current, {
          result,
          userId: targetUserId,
          displayName: selectedSupporter?.displayName ?? "Supporter",
          publicUserId: selectedSupporter?.publicUserId ?? null,
          note: reason,
        }),
      );
      showAdminToast("Wallet adjustment saved.", "success");
      loadSnapshot().catch(() => {
        showAdminToast(
          "Wallet updated. Refresh the workspace when the network is stable to reconcile the latest totals.",
          "info",
        );
      });
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not update the points balance.",
        "error",
      );
    } finally {
      setIsSubmitting(false);
    }
  }

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="Gamification"
        title="Supporter points operations"
      />

      <div className="grid gap-5 md:grid-cols-4">
        <AdminStateCard
          label="Points accounts"
          value={loading ? "..." : snapshot.overview.length.toString()}
          helper="Supporters visible in this club scope."
          icon={Wallet}
        />
        <AdminStateCard
          label="Total balance"
          value={loading ? "..." : formatFet(totals.balance)}
          helper="Current club-wide supporter balance."
          icon={Coins}
        />
        <AdminStateCard
          label="Lifetime earned"
          value={loading ? "..." : formatFet(totals.earned)}
          helper="All points credits recorded so far."
        />
        <AdminStateCard
          label="Lifetime spent"
          value={loading ? "..." : formatFet(totals.spent)}
          helper="Transfers out, redemptions, and deductions."
        />
      </div>

      <section className="glass-panel rounded-[32px] p-6">
        <div className="flex flex-col gap-3 md:flex-row md:items-end">
          <label className="grid flex-1 gap-2 text-sm text-slate-300">
            Search supporters, , or reference ids
            <div className="relative">
              <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-500" />
              <input
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
              onClick={() => setSearch(searchDraft.trim())}
              className="admin-button admin-button-primary"
            >
              Apply filter
            </button>
            <button
              type="button"
              onClick={() => {
                setSearchDraft("");
                setSearch("");
                setSelectedUserId(null);
              }}
              className="admin-button admin-button-secondary"
            >
              Clear
            </button>
            <button
              type="button"
              onClick={() => {
                loadSnapshot().catch(() => { });
              }}
              className="admin-button admin-button-secondary"
            >
              <RefreshCcw className="h-4 w-4" />
              Refresh
            </button>
          </div>
        </div>
      </section>

      {loadError && !loading ? (
        <AdminErrorState
          title="Points operations could not be loaded"
          description={loadError}
          onRetry={() => {
            loadSnapshot().catch(() => { });
          }}
        />
      ) : null}

      <div className="grid gap-5 xl:grid-cols-[0.95fr_1.05fr]">
        <section className="glass-panel rounded-[32px] p-6">
          <div className="space-y-5">
            <div>
              <p className="admin-page-eyebrow">Adjust balance</p>
              <h2 className="font-display text-3xl font-bold uppercase">
                Admin points controls
              </h2>
              <p className="mt-2 text-sm text-slate-400">
                Choose a supporter from the list below, then apply a positive
                top-up or a negative deduction with a required audit reason.
              </p>
            </div>

            <div className="grid gap-4 rounded-[28px] border border-white/10 bg-white/5 p-5">
              <div className="rounded-[22px] border border-white/10 bg-black/15 p-4">
                <p className="text-xs uppercase tracking-[0.32em] text-slate-500">
                  Selected account
                </p>
                <p className="mt-2 font-display text-2xl font-bold uppercase">
                  {selectedSupporter?.displayName ?? "Choose a supporter"}
                </p>
                <p className="mt-1 text-sm text-slate-400">
                  {selectedSupporter
                    ? `#${selectedSupporter.publicUserId ?? "000000"} • ${selectedSupporter.tier.toUpperCase()} • ${formatFet(selectedSupporter.balance)}`
                    : "The ledger panel can be filtered per supporter."}
                </p>
              </div>

              <label className="grid gap-2 text-sm text-slate-300">
                Adjustment amount
                <input
                  value={adjustmentAmount}
                  onChange={(event) => setAdjustmentAmount(event.target.value)}
                  placeholder="Use +250 or -120"
                  inputMode="numeric"
                  className="admin-input"
                />
              </label>

              <label className="grid gap-2 text-sm text-slate-300">
                Audit reason
                <textarea
                  value={adjustmentReason}
                  onChange={(event) => setAdjustmentReason(event.target.value)}
                  rows={3}
                  placeholder="Explain why the balance changed."
                  className="admin-input min-h-[112px]"
                />
              </label>

              <button
                type="button"
                onClick={() => {
                  handleAdjustment().catch(() => { });
                }}
                disabled={isSubmitting}
                className="admin-button admin-button-primary disabled:opacity-60"
              >
                {isSubmitting ? "Saving…" : "Apply adjustment"}
              </button>
            </div>

            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <h3 className="font-display text-2xl font-bold uppercase">
                  Supporter balances
                </h3>
                {selectedSupporter ? (
                  <button
                    type="button"
                    onClick={() => setSelectedUserId(null)}
                    className="text-xs uppercase tracking-[0.28em] text-club-accent"
                  >
                    Clear selection
                  </button>
                ) : null}
              </div>
              <AdminFilterBar>
                <label className="admin-search-field">
                  <Search size={16} aria-hidden="true" />
                  <span className="sr-only">Filter loaded supporter accounts</span>
                  <input
                    type="search"
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
                onRowActivate={setSelectedUserId}
                columns={[
                  {
                    key: "supporter",
                    label: "Supporter",
                    priority: "primary",
                    sortable: true,
                    sortDirection: accountCollection.sortDirectionFor("supporter"),
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
                    sortDirection: accountCollection.sortDirectionFor("balance"),
                    onSort: () => accountCollection.toggleSort("balance"),
                  },
                  {
                    key: "activity",
                    label: "Last activity",
                    priority: "secondary",
                    sortable: true,
                    sortDirection: accountCollection.sortDirectionFor("activity"),
                    onSort: () => accountCollection.toggleSort("activity"),
                  },
                  { key: "action", label: "Action", priority: "primary" },
                ]}
              >
                {accountCollection.pageResult.items.length === 0 ? (
                  <tr>
                    <td colSpan={5} className="py-8 text-center text-sm text-slate-400">
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
                      <td><span className="font-medium text-white">{row.displayName}</span><span className="block text-xs text-slate-500">#{row.publicUserId ?? "000000"}</span></td>
                      <td>{row.tier.toUpperCase()}</td>
                      <td className="font-semibold text-club-accent">{formatFet(row.balance)}</td>
                      <td>{row.lastTransactionAt ? timeFormatter.format(new Date(row.lastTransactionAt)) : "No ledger yet"}</td>
                      <td><button type="button" className="admin-action-button" onClick={() => setSelectedUserId(row.userId)}>{row.userId === selectedUserId ? "Selected" : "Select"}</button></td>
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

        <section className="glass-panel rounded-[32px] p-6">
          <div className="space-y-5">
            <div>
              <p className="admin-page-eyebrow">Ledger</p>
              <h2 className="font-display text-3xl font-bold uppercase">
                Wallet activity trail
              </h2>
              <p className="mt-2 text-sm text-slate-400">
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
              onRowActivate={(rowId) =>
                setDetailLedgerRow(
                  snapshot.ledger.find((row) => row.id === rowId) ?? null,
                )
              }
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
                  sortDirection: ledgerCollection.sortDirectionFor("supporter"),
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
                  sortDirection: ledgerCollection.sortDirectionFor("createdAt"),
                  onSort: () => ledgerCollection.toggleSort("createdAt"),
                },
              ]}
            >
              {ledgerCollection.pageResult.items.length === 0 ? (
                <tr>
                  <td colSpan={5} className="py-8 text-center text-sm text-slate-400">
                    No points ledger entries matched the current filters.
                  </td>
                </tr>
              ) : (
                ledgerCollection.pageResult.items.map((row) => (
                  <tr key={row.id} data-row-id={row.id}>
                    <td><span className="font-medium text-white">{ledgerHeadline(row)}</span><span className="block truncate text-xs text-slate-500">{row.note ?? "No note"}</span></td>
                    <td>{row.displayName}<span className="block text-xs text-slate-500">#{row.publicUserId ?? "000000"}</span></td>
                    <td><span className={`inline-flex rounded-full border px-2 py-1 text-[11px] uppercase tracking-[0.24em] ${ledgerTone(row)}`}>{row.direction === "credit" ? "+" : "-"}{formatFet(row.amount)}</span></td>
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
      <AdminActionDrawer
        open={detailLedgerRow != null}
        onClose={() => setDetailLedgerRow(null)}
        title="Points ledger details"
      >
        {detailLedgerRow ? (
          <dl className="grid gap-4 text-sm">
            <div><dt className="text-slate-500">Entry</dt><dd className="mt-1 text-slate-100">{ledgerHeadline(detailLedgerRow)}</dd></div>
            <div><dt className="text-slate-500">Supporter</dt><dd className="mt-1 text-slate-100">{detailLedgerRow.displayName} · #{detailLedgerRow.publicUserId ?? "000000"}</dd></div>
            <div><dt className="text-slate-500">Amount</dt><dd className="mt-1 text-slate-100">{detailLedgerRow.direction === "credit" ? "+" : "-"}{formatFet(detailLedgerRow.amount)}</dd></div>
            <div><dt className="text-slate-500">Balance after</dt><dd className="mt-1 text-slate-100">{formatFet(detailLedgerRow.balanceAfter)}</dd></div>
            <div><dt className="text-slate-500">Note</dt><dd className="mt-1 break-words text-slate-100">{detailLedgerRow.note ?? "No note recorded."}</dd></div>
            <div><dt className="text-slate-500">Reference</dt><dd className="mt-1 break-all text-slate-100">{detailLedgerRow.referenceId ?? "No reference recorded."}</dd></div>
          </dl>
        ) : null}
      </AdminActionDrawer>
    </div>
  );
}

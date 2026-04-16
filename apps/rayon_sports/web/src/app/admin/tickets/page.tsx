"use client";

import { useCallback, useEffect, useState } from "react";
import { Ticket, Search, CheckCircle2, XCircle, Clock } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminStateCard } from "@/components/admin/admin-state-card";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { getAdminTicketOrders, updateTicketStatus, type AdminTicketOrder } from "@/lib/data/admin/tickets";
import { formatCurrency } from "@/lib/utils";

export default function AdminTicketsPage() {
  const { access, activeClub, client } = useAdminPortal();
  const [orders, setOrders] = useState<AdminTicketOrder[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [filter, setFilter] = useState("");

  const loadOrders = useCallback(async () => {
    if (client == null) return;
    setLoading(true);
    try {
      setOrders(await getAdminTicketOrders(client, access));
      setLoadError(null);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "Could not load ticket orders.";
      setLoadError(message);
      showAdminToast(message, "error");
    } finally {
      setLoading(false);
    }
  }, [access, client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) return;
    loadOrders().catch(() => {});
  }, [access.hasAccess, client, loadOrders]);

  async function handleStatusUpdate(ticketId: string, status: string) {
    if (!client) return;
    try {
      await updateTicketStatus(client, access, ticketId, status);
      showAdminToast(`Ticket ${status}.`, "success");
      await loadOrders();
    } catch (e) {
      showAdminToast(e instanceof Error ? e.message : "Status update failed", "error");
    }
  }

  const filteredOrders = orders.filter(o => 
    o.userName?.toLowerCase().includes(filter.toLowerCase()) ||
    o.userPhone?.toLowerCase().includes(filter.toLowerCase()) ||
    o.matchTitle?.toLowerCase().includes(filter.toLowerCase()) ||
    o.momoReference?.toLowerCase().includes(filter.toLowerCase())
  );

  return (
    <div className="section-grid !gap-6">
      <AdminPageHeader
        eyebrow="Supporter programs"
        title="Ticket operations"
      />

      <div className="grid gap-4 md:grid-cols-4">
        <AdminStateCard
          label="Total Tickets"
          value={loading ? "..." : orders.length.toString()}
          icon={Ticket}
        />
        <AdminStateCard
          label="Pending"
          value={loading ? "..." : orders.filter(o => o.status === "pending").length.toString()}
          tone={orders.some(o => o.status === "pending") ? "warning" : "neutral"}
          icon={Clock}
        />
        <AdminStateCard
          label="Validated"
          value={loading ? "..." : orders.filter(o => o.status === "valid").length.toString()}
          tone="success"
          icon={CheckCircle2}
        />
        <AdminStateCard
          label="Used"
          value={loading ? "..." : orders.filter(o => o.status === "used").length.toString()}
          tone="info"
        />
      </div>

      <div className="flex flex-col gap-4">
        <div className="relative max-w-md">
          <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-[var(--admin-zinc-500)]" />
          <input
            type="text"
            placeholder="Search by fan, match, or MoMo ref..."
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
            className="admin-input !pl-10 w-full"
          />
        </div>

        {loadError && !loading ? (
          <AdminErrorState
            title="Ticket orders could not be loaded"
            description={loadError}
            onRetry={() => { loadOrders().catch(() => {}); }}
          />
        ) : (
          <AdminDataGrid
            columns={[
              { key: "fan", label: "Supporter" },
              { key: "match", label: "Match" },
              { key: "seat", label: "Type" },
              { key: "payment", label: "Payment" },
              { key: "status", label: "Status" },
              { key: "date", label: "Purchased" },
              { key: "actions", label: "", className: "text-right" },
            ]}
          >
            {filteredOrders.map((order) => (
              <tr key={order.id}>
                <td>
                  <p className="admin-row-title">{order.userName}</p>
                  <p className="admin-row-meta">{order.userPhone}</p>
                </td>
                <td>
                  <p className="text-sm font-medium text-white">{order.matchTitle}</p>
                  <p className="admin-row-meta">Fixture venue</p>
                </td>
                <td>
                   <AdminStatusBadge label={order.seatType} tone={order.seatType.toLowerCase().includes("vip") ? "accent" : "neutral"} />
                </td>
                <td>
                  <p className="text-sm font-medium text-white">{formatCurrency(order.amountPaid, activeClub?.currencyCode ?? "USD")}</p>
                  <p className="admin-row-meta">{order.momoReference || "—"}</p>
                </td>
                <td>
                  <AdminStatusBadge 
                    label={order.status} 
                    tone={
                      order.status === "valid" ? "success" : 
                      order.status === "used" ? "info" : 
                      order.status === "pending" ? "warning" : "danger"
                    } 
                  />
                </td>
                <td className="text-xs text-[var(--admin-zinc-500)]">
                   {new Date(order.purchasedAt).toLocaleDateString()}
                </td>
                <td className="text-right">
                  <div className="flex justify-end gap-2">
                    {order.status === "pending" && (
                      <button onClick={() => handleStatusUpdate(order.id, "valid")} className="admin-action-button !bg-emerald-500/10 !text-emerald-400">Validate</button>
                    )}
                    {order.status === "valid" && (
                      <button onClick={() => handleStatusUpdate(order.id, "used")} className="admin-action-button !bg-blue-500/10 !text-blue-400">Mark Used</button>
                    )}
                    {order.status !== "cancelled" && (
                      <button onClick={() => handleStatusUpdate(order.id, "cancelled")} className="admin-action-button !bg-rose-500/10 !text-rose-400">Cancel</button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </AdminDataGrid>
        )}
      </div>
    </div>
  );
}

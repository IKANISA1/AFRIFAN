"use client";

import { useEffect, useState } from "react";
import { NotificationOptInCard } from "@/components/pwa/notification-opt-in-card";
import { PortalStateCard } from "@/components/portal/portal-state-card";
import { SectionHeading } from "@/components/section-heading";
import { useFanPortal } from "@/components/portal/fan-portal-provider";

export default function FanPortalDashboardPage() {
  const { client, user, profile, membership } = useFanPortal();
  const [counts, setCounts] = useState({
    tickets: 0,
    orders: 0,
    groups: 0,
  });

  useEffect(() => {
    if (client == null || user == null) return;
    const activeClient = client;
    const activeUser = user;

    async function loadCounts() {
      const [tickets, orders, groups] = await Promise.all([
        activeClient.from("tickets").select("id").eq("user_id", activeUser.id),
        activeClient
          .from("shop_orders")
          .select("id")
          .eq("user_id", activeUser.id),
        activeClient
          .from("group_members")
          .select("id")
          .eq("user_id", activeUser.id),
      ]);

      setCounts({
        tickets: tickets.data?.length ?? 0,
        orders: orders.data?.length ?? 0,
        groups: groups.data?.length ?? 0,
      });
    }

    loadCounts().catch(() => {});
  }, [client, user]);

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Portal dashboard"
        title={`Welcome ${profile?.displayName ?? "supporter"}.`}
        description="This area is authenticated in the browser and works off the same club-scoped data contracts as the mobile app."
      />
      <div className="grid gap-5 md:grid-cols-3">
        <PortalStateCard
          label="Membership tier"
          value={(membership?.tier ?? "fan").toUpperCase()}
          helper={
            <>
              Alias: {profile?.publicUserId ?? "Pending"}.
              <br />
              Chapter: {membership?.chapter ?? "Main"}.
            </>
          }
        />
        <PortalStateCard
          label="Tickets"
          value={counts.tickets.toString()}
          helper="Open ticket history, issue new matchday purchases, and keep your e-ticket record in sync."
        />
        <PortalStateCard
          label="Orders + groups"
          value={`${counts.orders}/${counts.groups}`}
          helper="Track shop orders and supporter circles from one account."
        />
      </div>
      <NotificationOptInCard
        surface="portal"
        path="/app"
        title="Keep the supporter reachable."
        description="Enable notifications only after you have entered the fan portal, so ticket reminders, membership confirmations, and live match moments arrive in context."
      />
    </div>
  );
}

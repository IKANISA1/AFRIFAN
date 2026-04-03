"use client";

import { useCallback, useEffect, useState } from "react";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { ProgressBar } from "@/components/progress-bar";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { cn } from "@/lib/utils";
import {
  getAdminNotificationContext,
  sendAdminNotification,
} from "@/lib/data/admin";
import type { AdminNotificationContext } from "@/lib/types";

type NotificationForm = {
  title: string;
  body: string;
  audience: "all_fans" | "by_tier" | "by_group";
  tier: string;
  groupId: string;
  deliveryMode: "send_now" | "schedule";
  scheduledAt: string;
  imageUrl: string;
};

const emptyContext: AdminNotificationContext = {
  groups: [],
  history: [],
};

const emptyForm: NotificationForm = {
  title: "",
  body: "",
  audience: "all_fans",
  tier: "bronze",
  groupId: "",
  deliveryMode: "send_now",
  scheduledAt: "",
  imageUrl: "",
};

const notifStatusColors: Record<string, string> = {
  sent: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  delivered: "bg-emerald-500/15 text-emerald-400 border-emerald-500/30",
  scheduled: "bg-amber-500/15 text-amber-400 border-amber-500/30",
  failed: "bg-rose-500/15 text-rose-300 border-rose-500/30",
  pending: "bg-white/8 text-slate-300 border-border-soft",
};

export default function AdminNotificationsPage() {
  const { access, client } = useAdminPortal();
  const [context, setContext] = useState(emptyContext);
  const [form, setForm] = useState<NotificationForm>(emptyForm);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);

  const loadContext = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setContext(await getAdminNotificationContext(client));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not load notification context.",
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [client]);

  useEffect(() => {
    if (client == null || !access.hasAccess) {
      return;
    }
    loadContext().catch(() => {});
  }, [access.hasAccess, client, loadContext]);

  function buildPayload() {
    const group = context.groups.find((item) => item.id === form.groupId);

    return {
      title: form.title.trim(),
      body: form.body.trim(),
      audience: form.audience,
      tier: form.audience === "by_tier" ? form.tier : null,
      groupId: form.audience === "by_group" ? form.groupId : null,
      groupName: form.audience === "by_group" ? group?.name ?? null : null,
      deliveryMode: form.deliveryMode,
      scheduledAt:
        form.deliveryMode === "schedule" && form.scheduledAt
          ? new Date(form.scheduledAt).toISOString()
          : null,
      imageUrl: form.imageUrl.trim() || null,
    };
  }

  function validatePayload() {
    if (!form.title.trim() || !form.body.trim()) {
      return "Add both a title and body.";
    }
    if (form.audience === "by_group" && !form.groupId) {
      return "Choose a contribution group first.";
    }
    if (form.deliveryMode === "schedule" && !form.scheduledAt) {
      return "Pick the scheduled delivery time first.";
    }
    return null;
  }

  async function submitNotification() {
    if (client == null) {
      return;
    }

    const validationError = validatePayload();
    if (validationError) {
      showAdminToast(validationError, "error");
      return;
    }

    setSubmitting(true);
    showAdminToast("Sending notification...", "info");

    try {
      const result = (await sendAdminNotification(client, buildPayload())) as {
        delivery?: { status?: string };
      };
      await loadContext();
      setForm(emptyForm);
      showAdminToast(
        result.delivery?.status === "scheduled"
          ? "Notification scheduled."
          : "Notification submitted to the delivery pipeline.",
        "success",
      );
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not submit notification.",
        "error",
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function copyPayload() {
    const validationError = validatePayload();
    if (validationError) {
      showAdminToast(validationError, "error");
      return;
    }

    try {
      await navigator.clipboard.writeText(
        JSON.stringify(buildPayload(), null, 2),
      );
      showAdminToast("Payload copied to clipboard.", "success");
    } catch {
      showAdminToast("Clipboard copy failed in this browser.", "error");
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="Notifications"
        title="Compose supporter broadcasts without leaving the web admin."
        description="Notifications are delivered through the `admin-send-notification` edge function and keep audience targeting aligned with the club-scoped mobile product."
      />

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <section className="glass-panel grid gap-4 rounded-[32px] p-6">
          <p className="font-display text-3xl font-bold uppercase leading-none">
            Compose broadcast
          </p>
          <label className="grid gap-2 text-sm">
            <div className="flex items-center justify-between">
              <span>Title</span>
              <span className="font-mono text-[10px] text-slate-400">{form.title.length}/120</span>
            </div>
            <input
              value={form.title}
              maxLength={120}
              onChange={(event) =>
                setForm((current) => ({ ...current, title: event.target.value }))
              }
              className="dashboard-input"
            />
          </label>
          <label className="grid gap-2 text-sm">
            <div className="flex items-center justify-between">
              <span>Body</span>
              <span className="font-mono text-[10px] text-slate-400">{form.body.length}/500</span>
            </div>
            <textarea
              rows={6}
              maxLength={500}
              value={form.body}
              onChange={(event) =>
                setForm((current) => ({ ...current, body: event.target.value }))
              }
              className="dashboard-input min-h-36 resize-y"
            />
          </label>
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="grid gap-2 text-sm">
              Audience
              <select
                value={form.audience}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    audience: event.target.value as typeof current.audience,
                  }))
                }
                className="dashboard-input"
              >
                <option value="all_fans">All fans</option>
                <option value="by_tier">By tier</option>
                <option value="by_group">By group</option>
              </select>
            </label>
            <label className="grid gap-2 text-sm">
              Delivery mode
              <select
                value={form.deliveryMode}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    deliveryMode: event.target.value as typeof current.deliveryMode,
                  }))
                }
                className="dashboard-input"
              >
                <option value="send_now">Send now</option>
                <option value="schedule">Schedule</option>
              </select>
            </label>
          </div>
          {form.audience === "by_tier" ? (
            <label className="grid gap-2 text-sm">
              Tier
              <select
                value={form.tier}
                onChange={(event) =>
                  setForm((current) => ({ ...current, tier: event.target.value }))
                }
                className="dashboard-input"
              >
                <option value="fan">Fan</option>
                <option value="bronze">Bronze</option>
                <option value="gold">Gold</option>
                <option value="platinum">Platinum</option>
              </select>
            </label>
          ) : null}
          {form.audience === "by_group" ? (
            <label className="grid gap-2 text-sm">
              Contribution group
              <select
                value={form.groupId}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    groupId: event.target.value,
                  }))
                }
                className="dashboard-input"
              >
                <option value="">Select a group</option>
                {context.groups.map((group) => (
                  <option key={group.id} value={group.id}>
                    {group.name}
                  </option>
                ))}
              </select>
            </label>
          ) : null}
          {form.deliveryMode === "schedule" ? (
            <label className="grid gap-2 text-sm">
              Scheduled at
              <input
                type="datetime-local"
                value={form.scheduledAt}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    scheduledAt: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          ) : null}
          <label className="grid gap-2 text-sm">
            Image URL
            <input
              value={form.imageUrl}
              onChange={(event) =>
                setForm((current) => ({ ...current, imageUrl: event.target.value }))
              }
              className="dashboard-input"
            />
          </label>
          {form.imageUrl.trim() ? (
            <div className="overflow-hidden rounded-[22px] border border-border-soft">
              {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting. */}
              <img src={form.imageUrl} alt="Notification image preview" className="h-28 w-full object-cover" />
            </div>
          ) : null}
          <div className="rounded-[24px] border border-border-soft bg-black/10 px-4 py-4 text-sm text-slate-300">
            Target:{" "}
            <span className="font-semibold text-white">
              {form.audience === "all_fans"
                ? "All supporters"
                : form.audience === "by_tier"
                  ? `Tier • ${form.tier}`
                  : context.groups.find((group) => group.id === form.groupId)?.name ??
                    "Group not selected"}
            </span>
          </div>
          <div className="flex flex-wrap gap-3">
            <button
              type="button"
              disabled={submitting}
              onClick={() => {
                submitNotification().catch(() => {});
              }}
              className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary disabled:opacity-60"
            >
              {form.deliveryMode === "schedule" ? "Schedule notification" : "Send notification"}
            </button>
            <button
              type="button"
              disabled={submitting}
              onClick={() => {
                copyPayload().catch(() => {});
              }}
              className="rounded-full border border-border-soft px-5 py-3 font-semibold text-slate-100 disabled:opacity-60 transition hover:bg-white/8"
            >
              Copy payload
            </button>
          </div>
        </section>

        <section className="glass-panel rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              Delivery history
            </p>
            <button
              type="button"
              onClick={() => loadContext().catch(() => {})}
              className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
            >
              Refresh
            </button>
          </div>

          <div className="mt-5 space-y-3">
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 3 }).map((_, i) => (
                  <div key={i} className="rounded-[26px] border border-border-soft bg-white/5 p-5">
                    <Skeleton className="skeleton-text h-6 w-2/5" />
                    <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                    <div className="mt-4 grid gap-3 sm:grid-cols-3">
                      {Array.from({ length: 3 }).map((_, j) => (
                        <Skeleton key={j} className="h-16 rounded-[22px]" />
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            ) : null}
            {!loading && context.history.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                No notifications have been recorded yet.
              </p>
            ) : null}
            {!loading && context.history.map((item) => {
              const total = item.sentCount + item.failedCount;
              const statusClass = notifStatusColors[item.status] ?? notifStatusColors.pending;

              return (
                <article
                  key={item.id}
                  className="card-interactive rounded-[26px] border border-border-soft bg-white/5 p-5"
                >
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                      <p className="font-display text-2xl font-bold uppercase leading-none">
                        {item.title}
                      </p>
                      <p className="mt-2 text-sm leading-6 text-slate-300">
                        {item.body}
                      </p>
                    </div>
                    <span className={cn("rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em]", statusClass)}>
                      {item.status}
                    </span>
                  </div>
                  {total > 0 ? (
                    <div className="mt-4">
                      <ProgressBar
                        value={item.sentCount}
                        max={total}
                        label="Delivery success"
                        compact
                      />
                    </div>
                  ) : null}
                  <div className="mt-4 grid gap-3 sm:grid-cols-3">
                    <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                      <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                        Audience
                      </p>
                      <p className="mt-2 text-sm text-slate-200">
                        {item.audienceType === "all_fans"
                          ? "All fans"
                          : item.audienceType === "by_tier"
                            ? `Tier • ${item.audienceTier}`
                            : item.audienceGroupName ?? "Group"}
                      </p>
                    </div>
                    <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                      <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                        Delivery
                      </p>
                      <p className="mt-2 text-sm text-slate-200">
                        {item.deliveryMode === "schedule" ? "Scheduled" : "Immediate"}
                      </p>
                    </div>
                    <div className="rounded-[22px] border border-border-soft bg-black/10 px-4 py-3">
                      <p className="font-mono text-[11px] uppercase tracking-[0.2em] text-club-accent">
                        Metrics
                      </p>
                      <p className="mt-2 text-sm text-slate-200">
                        <span className="text-emerald-400">{item.sentCount}</span> sent •{" "}
                        <span className={item.failedCount > 0 ? "text-rose-400" : "text-slate-400"}>{item.failedCount}</span> failed
                      </p>
                    </div>
                  </div>
                  {item.lastError ? (
                    <p className="mt-4 rounded-[22px] border border-rose-400/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-200">
                      {item.lastError}
                    </p>
                  ) : null}
                </article>
              );
            })}
          </div>
        </section>
      </div>
    </div>
  );
}

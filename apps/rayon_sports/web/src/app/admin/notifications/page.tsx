"use client";

import { useCallback, useState } from "react";
import { BellRing, Clock3, Send } from "lucide-react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
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
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import {
  getAdminNotificationContext,
  normalizeAdminNotificationContext,
  sendAdminNotification,
} from "@/lib/data/admin/notifications";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { useHydrated } from "@/lib/use-hydrated";
import {
  emptyContext,
  emptyForm,
  type NotificationForm as NotificationFormType,
} from "./_components/notification-state";
import { NotificationForm } from "./_components/notification-form";
import { NotificationList } from "./_components/notification-list";

const statusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading notification operations",
    detail: "Waiting for the first authenticated delivery snapshot.",
  },
  ready: {
    label: "Notification operations confirmed",
    detail: "The bounded club-scoped composer and delivery queue are current.",
  },
  empty: {
    label: "No notification activity in this scope",
    detail: "The composer is ready; no delivery history is currently recorded.",
  },
  error: {
    label: "Notification operations unavailable",
    detail: "Confirmed records remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Notification workspace is offline",
    detail:
      "Confirmed records remain visible; sending and scheduling are locked.",
  },
  permission_denied: {
    label: "Notification access denied",
    detail: "Delivery records, filters, and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing notification operations",
    detail: "Confirmed delivery history remains visible during refresh.",
  },
  conflict: {
    label: "Notification state changed",
    detail: "Review the refreshed queue before restarting the action.",
  },
  security_timeout: {
    label: "Notification request timed out",
    detail: "No send or schedule operation was confirmed.",
  },
};

const notificationContextIsEmpty = (value: typeof emptyContext) =>
  value.groups.length === 0 && value.history.length === 0;

export default function AdminNotificationsPage() {
  const { access, client } = useAdminPortal();
  const hydrated = useHydrated();
  const [form, setForm] = useState<NotificationFormType>(emptyForm);
  const [submitting, setSubmitting] = useState(false);
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadContext = useCallback(
    async (signal: AbortSignal) => {
      if (client == null) return emptyContext;
      return getAdminNotificationContext(client, access, { signal });
    },
    [access, client],
  );

  const clearDeniedWorkspace = useCallback(() => {
    setForm(emptyForm);
    setSubmitting(false);
    setInteraction("idle");
  }, []);

  const {
    data: context,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: hydrated && client != null && access.hasAccess,
    emptyValue: emptyContext,
    isEmpty: notificationContextIsEmpty,
    load: loadContext,
    normalize: normalizeAdminNotificationContext,
    onPermissionDenied: clearDeniedWorkspace,
    resourceLabel: "notification operations",
  });

  const mutationLocked =
    submitting || (status !== "ready" && status !== "empty");
  const unrecoveredFailure =
    !hasConfirmed &&
    (status === "error" ||
      status === "offline" ||
      status === "permission_denied" ||
      status === "conflict" ||
      status === "security_timeout");

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
        form.deliveryMode === "schedule"
          ? new Date(form.scheduledAt).toISOString()
          : null,
      imageUrl: form.imageUrl.trim() || null,
    };
  }

  function validatePayload() {
    const title = form.title.trim();
    const body = form.body.trim();
    if (!title || !body) return "Add both a title and body.";
    if (title.length > 120 || body.length > 500) {
      return "Keep the title within 120 characters and body within 500.";
    }
    if (
      form.audience === "by_group" &&
      !context.groups.some((group) => group.id === form.groupId)
    ) {
      return "Choose a current contribution group first.";
    }
    if (form.deliveryMode === "schedule") {
      const scheduledTime = Date.parse(form.scheduledAt);
      if (!Number.isFinite(scheduledTime) || scheduledTime <= Date.now()) {
        return "Choose a valid future delivery time.";
      }
    }
    return null;
  }

  async function submitNotification() {
    if (client == null || mutationLocked) return;
    const validationError = validatePayload();
    if (validationError) {
      showAdminToast(validationError, "error");
      return;
    }

    const audience =
      form.audience === "all_fans"
        ? "all supporters"
        : form.audience === "by_tier"
          ? `${form.tier} tier`
          : context.groups.find((group) => group.id === form.groupId)?.name ??
            "selected group";
    if (
      !confirmAdminDestructiveAction({
        action: form.deliveryMode === "schedule" ? "Schedule" : "Send",
        subject: `"${form.title.trim()}"`,
        scope: `${audience} · active club ${access.clubId ?? "not selected"}`,
        impact:
          form.deliveryMode === "schedule"
            ? "The notification will enter the delivery queue for the selected future time."
            : "The notification will enter delivery immediately for the selected audience.",
        undo:
          form.deliveryMode === "schedule"
            ? "manual_recovery"
            : "not_available",
      })
    ) {
      return;
    }

    setSubmitting(true);
    showAdminToast("Submitting notification...", "info");
    try {
      const result = (await sendAdminNotification(
        client,
        buildPayload(),
      )) as { delivery?: { status?: string } };
      await refresh();
      setForm(emptyForm);
      setInteraction("idle");
      showAdminToast(
        result.delivery?.status === "scheduled"
          ? "Notification scheduled."
          : "Notification submitted to the delivery pipeline.",
        "success",
      );
    } catch (caught) {
      applyFailure(caught);
      if (isAdminMutationConflict(caught)) await refresh();
      showAdminToast("Could not confirm the notification operation.", "error");
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
      showAdminToast("Clipboard copy is unavailable.", "error");
    }
  }

  const scheduledCount = context.history.filter(
    (notification) => notification.status === "scheduled",
  ).length;
  const failedCount = context.history.filter(
    (notification) => notification.status === "failed",
  ).length;

  return (
    <section
      className="admin-notifications-state-surface section-grid min-w-0 max-w-full"
      data-admin-notifications-status={status}
      data-admin-notifications-interaction={interaction}
      data-admin-notifications-refresh-disabled={busy}
      data-admin-notifications-mutation-disabled={mutationLocked}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader
        eyebrow="Broadcasts"
        title="Notification operations"
        meta={
          <span className="admin-meta-chip">
            Bounded club-scoped delivery records
          </span>
        }
      />

      <AdminResourceStatusBanner
        status={status}
        label={statusCopy[status].label}
        detail={statusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh notification operations"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
      />

      <div className="admin-notifications-metrics-grid">
        <AdminStateCard
          label="Queue window"
          value={initialLoading ? "..." : context.history.length.toString()}
          helper="Strict delivery-history window, capped at 100."
          icon={BellRing}
        />
        <AdminStateCard
          label="Scheduled"
          value={initialLoading ? "..." : scheduledCount.toString()}
          helper="Future deliveries awaiting the approved time."
          icon={Clock3}
        />
        <AdminStateCard
          label="Needs review"
          value={initialLoading ? "..." : failedCount.toString()}
          tone={failedCount > 0 ? "danger" : "neutral"}
          helper="Provider diagnostics remain private."
          icon={Send}
        />
      </div>

      {unrecoveredFailure ? (
        <AdminErrorState
          title={statusCopy[status].label}
          description={statusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
          retryLabel="Retry notification operations"
        />
      ) : initialLoading ? (
        <AdminSurface title="Notification workspace">
          <div className="grid gap-4 xl:grid-cols-2">
            {Array.from({ length: 4 }).map((_, index) => (
              <div
                key={index}
                className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-zinc-900)] p-4"
              >
                <Skeleton className="skeleton-text h-5 w-1/3" />
                <Skeleton className="skeleton-text mt-3 h-24 w-full" />
              </div>
            ))}
          </div>
        </AdminSurface>
      ) : (
        <div className="admin-notifications-workspace">
          <NotificationForm
            form={form}
            setForm={setForm}
            context={context}
            submitting={submitting}
            disabled={mutationLocked}
            onInteractionChange={setInteraction}
            onSubmit={() => void submitNotification()}
            onCopyPayload={() => void copyPayload()}
          />
          <NotificationList
            context={context}
            loading={false}
            disabled={mutationLocked}
            onInteractionChange={setInteraction}
            onRefresh={() => void refresh()}
          />
        </div>
      )}
    </section>
  );
}

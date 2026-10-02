"use client";

import { useAdminMediaDraftScope } from "@/lib/use-admin-media-draft-scope";
import type { StaffCommandReference } from "@/lib/data/admin/staff-command-journal";

import { useCallback, useEffect, useRef, useState } from "react";
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
  checkAdminNotificationStatus,
  readPendingAdminNotification,
  type AdminNotificationReceipt,
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
  const mediaDraft = useAdminMediaDraftScope(access, "notification");
  const [pending, setPending] = useState<StaffCommandReference | null>(null);
  const [commandMessage, setCommandMessage] = useState<string | null>(null);
  const [journalReady, setJournalReady] = useState(false);
  const commandBusy = useRef(false);
  const commandEpoch = useRef(0);
  const owner = `${access.userId ?? ""}:${access.clubId ?? ""}:${access.role ?? ""}`;
  const latest = useRef({ owner, client, allowed: false });
  const latestAccess = useRef(access);
  latestAccess.current = access;
  latest.current = { owner, client, allowed: access.hasAccess && access.isAuthenticated && access.isSuperAdmin };
  useEffect(() => {
    const ownedEpoch = commandEpoch;
    const epoch = ++ownedEpoch.current;
    commandBusy.current = false;
    setSubmitting(false); setForm(emptyForm); setPending(null); setCommandMessage(null); setJournalReady(false);
    if (!latest.current.allowed || !access.userId || !access.clubId) return;
    try { setPending(readPendingAdminNotification(latestAccess.current)); setJournalReady(true); }
    catch { setCommandMessage("The saved notification could not be read. Check browser storage before sending."); }
    return () => { if (ownedEpoch.current === epoch) ++ownedEpoch.current; };
  }, [owner, client, access.hasAccess, access.isAuthenticated, access.isSuperAdmin, access.userId, access.clubId]);
  function ownCommand() {
    const epoch = commandEpoch.current;
    return () => commandEpoch.current === epoch && latest.current.owner === owner && latest.current.client === client && latest.current.allowed;
  }
  function refreshPending(current: () => boolean) {
    if (!current()) return;
    try { setPending(readPendingAdminNotification(access)); }
    catch { setJournalReady(false); setCommandMessage("The original notification reference needs recovery. No new notification was sent."); }
  }
  async function acceptReceipt(receipt: AdminNotificationReceipt | null, current: () => boolean) {
    if (!current()) return;
    refreshPending(current);
    if (!receipt) { setCommandMessage("No saved notification command needs recovery."); return; }
    const state = receipt.command.state;
    if (state === "scheduled" || state === "completed") {
      const message = state === "scheduled" ? "Notification scheduled." : receipt.delivery?.status === "sent"
        ? "The provider accepted the notification. Device delivery is not confirmed."
        : receipt.delivery?.status === "partial" ? "The provider accepted part of the notification. Review the delivery queue."
        : "The notification completed with confirmed delivery failures. Review the queue.";
      setCommandMessage(message);
      showAdminToast(message, state === "completed" && receipt.delivery?.status !== "sent" ? "info" : "success");
      if (await mediaDraft.resetDraft() && current()) setForm(emptyForm);
      if (!current()) return;
      setInteraction("idle");
      await refresh();
    } else setCommandMessage(state === "not_admitted"
      ? "The original notification has not been admitted. Re-enter the exact original contents to retry its saved reference."
      : state === "unknown" ? "Delivery is unconfirmed. The original reference is retained; this notification will not be resent."
      : state === "blocked" ? "The original notification needs operator review. Keep its reference and check status."
      : "The original notification is being processed. Check status before sending another notification.");
  }
  async function checkSavedCommand() {
    if (!client || commandBusy.current || !journalReady || !latest.current.allowed) return;
    const current = ownCommand(), epoch = commandEpoch.current;
    commandBusy.current = true; setSubmitting(true);
    try { await acceptReceipt(await checkAdminNotificationStatus(client, access, { isCurrent: current }), current); }
    catch (caught) { if (current()) { refreshPending(current); setCommandMessage(caught instanceof Error ? caught.message : "The notification status is unavailable. Keep its reference."); } }
    finally { if (commandEpoch.current === epoch) { commandBusy.current = false; setSubmitting(false); } }
  }

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
    submitting || !journalReady || !access.isSuperAdmin || !mediaDraft.ready || (status !== "ready" && status !== "empty");
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
    if (client == null || mutationLocked || commandBusy.current) return;
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

    if (commandBusy.current || !latest.current.allowed) return;
    const current = ownCommand(), epoch = commandEpoch.current;
    commandBusy.current = true;
    setSubmitting(true);
    showAdminToast(pending ? "Checking original notification..." : "Submitting notification...", "info");
    try {
      const result = await mediaDraft.runSave(() => sendAdminNotification(client, buildPayload(), access, { isCurrent: current }));
      await acceptReceipt(result, current);
    } catch (caught) {
      if (!current()) return;
      refreshPending(current);
      setCommandMessage(caught instanceof Error ? caught.message : "Could not confirm the original notification operation.");
      if (isAdminMutationConflict(caught)) await refresh();
    } finally {
      if (commandEpoch.current === epoch) { commandBusy.current = false; setSubmitting(false); }
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
    (notification) => ["failed", "partial", "unknown"].includes(notification.status),
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

      {pending || commandMessage ? <AdminSurface title="Original notification command">
        <div className="grid gap-3" role="status" aria-live="polite">
          {pending ? <p className="break-all text-sm text-[var(--admin-text-muted)]">Reference: {pending.operationId}</p> : null}
          <p className="text-sm text-[var(--admin-text-muted)]">{commandMessage ?? "The original notification is retained. Check its status before sending another."}</p>
          {pending ? <button type="button" className="dashboard-button-secondary min-h-12 justify-self-start"
            disabled={submitting || !journalReady || !latest.current.allowed} onClick={() => { void checkSavedCommand(); }}>Check notification status</button> : null}
        </div>
      </AdminSurface> : null}
      {mediaDraft.error ? <p role="status" className="text-sm text-[var(--admin-text-muted)]">{mediaDraft.error}</p> : null}

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
                className="rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] p-4"
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
            mediaScopeKey={mediaDraft.scopeKey}
            mediaRecoveryOnly={mediaDraft.legacyUnbound}
            onMediaRecoveryResolved={mediaDraft.refreshRecovery}
            retryOriginal={pending !== null}
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

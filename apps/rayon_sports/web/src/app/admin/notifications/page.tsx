"use client";

import { useCallback, useEffect, useState } from "react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import {
  getAdminNotificationContext,
  sendAdminNotification,
} from "@/lib/data/admin/notifications";
import { emptyContext, emptyForm, type NotificationForm as NotificationFormType } from "./_components/notification-state";
import { NotificationForm } from "./_components/notification-form";
import { NotificationList } from "./_components/notification-list";

export default function AdminNotificationsPage() {
  const { access, client } = useAdminPortal();
  const [context, setContext] = useState(emptyContext);
  const [form, setForm] = useState<NotificationFormType>(emptyForm);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const loadContext = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setContext(await getAdminNotificationContext(client, access));
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error
          ? caught.message
          : "Could not load notification context.";
      setLoadError(message);
      showAdminToast(
        message,
        "error",
      );
    } finally {
      setLoading(false);
    }
  }, [access, client]);

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
      <AdminPageHeader
        eyebrow="Broadcasts"
        title="Notifications"
      />

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <NotificationForm
          form={form}
          setForm={setForm}
          context={context}
          submitting={submitting}
          onSubmit={() => {
            submitNotification().catch(() => {});
          }}
          onCopyPayload={() => {
            copyPayload().catch(() => {});
          }}
        />

        {loadError && !loading ? (
          <AdminErrorState
            title="Notification history could not be loaded"
            description={loadError}
            onRetry={() => {
              loadContext().catch(() => {});
            }}
          />
        ) : (
          <NotificationList
            context={context}
            loading={loading}
            onRefresh={() => loadContext().catch(() => {})}
          />
        )}
      </div>
    </div>
  );
}

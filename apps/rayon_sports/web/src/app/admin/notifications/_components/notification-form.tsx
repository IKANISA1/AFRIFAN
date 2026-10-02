import type { AdminNotificationContext } from "@/lib/types";
import type { AdminResourceInteraction } from "@/components/admin/admin-resource-status-banner";
import type { NotificationForm as NotificationFormType } from "./notification-state";
import { AdminImageField } from "@/components/admin/admin-image-field";

interface NotificationFormProps {
  form: NotificationFormType;
  setForm: (update: NotificationFormType | ((prev: NotificationFormType) => NotificationFormType)) => void;
  context: AdminNotificationContext;
  submitting: boolean;
  disabled?: boolean;
  mediaScopeKey: string | null;
  mediaRecoveryOnly?: boolean;
  onMediaRecoveryResolved?: () => void;
  retryOriginal?: boolean;
  onSubmit: () => void;
  onCopyPayload: () => void;
  onInteractionChange?: (interaction: AdminResourceInteraction) => void;
}

export function NotificationForm({
  form,
  setForm,
  context,
  submitting,
  disabled = false,
  mediaScopeKey,
  mediaRecoveryOnly = false,
  onMediaRecoveryResolved,
  retryOriginal = false,
  onSubmit,
  onCopyPayload,
  onInteractionChange,
}: NotificationFormProps) {
  return (
    <form
      className="ui-panel grid gap-4 rounded-[32px] p-6"
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit();
      }}
    >
      <p className="font-display text-3xl font-medium normal-case leading-none">
        Compose broadcast
      </p>
      <label className="grid gap-2 text-sm">
        <div className="flex items-center justify-between">
          <span>Title</span>
          <span className="font-mono text-xs font-semibold text-[var(--admin-text-muted)]">{form.title.length}/120</span>
        </div>
        <input
          value={form.title}
          maxLength={120}
          required
          disabled={disabled}
          onFocus={() => onInteractionChange?.("focused")}
          onChange={(event) =>
            setForm((current: NotificationFormType) => ({ ...current, title: event.target.value }))
          }
          className="dashboard-input"
        />
      </label>
      <label className="grid gap-2 text-sm">
        <div className="flex items-center justify-between">
          <span>Body</span>
          <span className="font-mono text-xs font-semibold text-[var(--admin-text-muted)]">{form.body.length}/500</span>
        </div>
        <textarea
          rows={6}
          maxLength={500}
          required
          disabled={disabled}
          value={form.body}
          onChange={(event) =>
            setForm((current: NotificationFormType) => ({ ...current, body: event.target.value }))
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
              {
                setForm((current: NotificationFormType) => ({
                  ...current,
                  audience: event.target.value as typeof current.audience,
                }));
                onInteractionChange?.("selected");
              }
            }
            className="dashboard-input"
            disabled={disabled}
            onFocus={() => onInteractionChange?.("focused")}
            onBlur={() => onInteractionChange?.("idle")}
            onClick={() => onInteractionChange?.("selected")}
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
              setForm((current: NotificationFormType) => ({
                ...current,
                deliveryMode: event.target.value as typeof current.deliveryMode,
              }))
            }
            className="dashboard-input"
            disabled={disabled}
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
              setForm((current: NotificationFormType) => ({ ...current, tier: event.target.value }))
            }
            className="dashboard-input"
            disabled={disabled}
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
              setForm((current: NotificationFormType) => ({
                ...current,
                groupId: event.target.value,
              }))
            }
            className="dashboard-input"
            disabled={disabled}
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
              setForm((current: NotificationFormType) => ({
                ...current,
                scheduledAt: event.target.value,
              }))
            }
            className="dashboard-input"
            disabled={disabled}
          />
        </label>
      ) : null}
      <AdminImageField
        scopeKey={mediaScopeKey ?? "unavailable"}
        recoveryOnly={mediaRecoveryOnly}
        onRecoveryResolved={onMediaRecoveryResolved}
        label="Notification image"
        value={form.imageUrl}
        onChange={(nextValue) =>
          setForm((current: NotificationFormType) => ({
            ...current,
            imageUrl: nextValue,
          }))
        }
        mediaKind="notification"
        subject={form.title}
        previewAlt="Notification preview"
        promptPlaceholder="Example: Simple promotional image for a supporter announcement, bold club colors, clean composition that still reads well when cropped."
        disabled={!mediaScopeKey || (disabled && !mediaRecoveryOnly)}
      />
      <div className="rounded-[24px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-4 text-sm text-[var(--admin-text-muted)]">
        Target:{" "}
        <span className="font-semibold text-[var(--admin-text-strong)]">
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
          type="submit"
          disabled={submitting || disabled}
          className="rounded-full bg-action-blue px-5 py-3 font-semibold text-white transition hover:bg-action-blue-hover disabled:opacity-60"
        >
          {retryOriginal ? "Retry original notification" : form.deliveryMode === "schedule" ? "Schedule notification" : "Send notification"}
        </button>
        <button
          type="button"
          disabled={submitting || disabled}
          onClick={onCopyPayload}
          className="rounded-full border border-border-soft px-5 py-3 font-semibold text-[var(--admin-text-strong)] disabled:opacity-60 transition hover:bg-[var(--admin-surface-hover)]"
        >
          Copy payload
        </button>
      </div>
    </form>
  );
}

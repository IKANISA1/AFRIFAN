import type { AdminNotificationContext } from "@/lib/types";
import type { NotificationForm as NotificationFormType } from "./notification-state";

interface NotificationFormProps {
  form: NotificationFormType;
  setForm: (update: NotificationFormType | ((prev: NotificationFormType) => NotificationFormType)) => void;
  context: AdminNotificationContext;
  submitting: boolean;
  onSubmit: () => void;
  onCopyPayload: () => void;
}

export function NotificationForm({
  form,
  setForm,
  context,
  submitting,
  onSubmit,
  onCopyPayload,
}: NotificationFormProps) {
  return (
    <form
      className="glass-panel grid gap-4 rounded-[32px] p-6"
      onSubmit={(event) => {
        event.preventDefault();
        onSubmit();
      }}
    >
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
          required
          onChange={(event) =>
            setForm((current: NotificationFormType) => ({ ...current, title: event.target.value }))
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
          required
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
              setForm((current: NotificationFormType) => ({
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
              setForm((current: NotificationFormType) => ({
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
              setForm((current: NotificationFormType) => ({ ...current, tier: event.target.value }))
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
              setForm((current: NotificationFormType) => ({
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
              setForm((current: NotificationFormType) => ({
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
            setForm((current: NotificationFormType) => ({ ...current, imageUrl: event.target.value }))
          }
          className="dashboard-input"
        />
      </label>
      {form.imageUrl.trim() ? (
        <div className="overflow-hidden rounded-[22px] border border-border-soft">
          {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs. */}
          <img src={form.imageUrl} alt="Notification preview" className="h-28 w-full object-cover" />
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
          type="submit"
          disabled={submitting}
          className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary disabled:opacity-60"
        >
          {form.deliveryMode === "schedule" ? "Schedule notification" : "Send notification"}
        </button>
        <button
          type="button"
          disabled={submitting}
          onClick={onCopyPayload}
          className="rounded-full border border-border-soft px-5 py-3 font-semibold text-slate-100 disabled:opacity-60 transition hover:bg-white/8"
        >
          Copy payload
        </button>
      </div>
    </form>
  );
}

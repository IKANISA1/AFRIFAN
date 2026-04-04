import type { CommunityForm } from "./community-state";
import { emptyForm } from "./community-state";

interface CommunityContentEditorProps {
  form: CommunityForm;
  setForm: (update: CommunityForm | ((prev: CommunityForm) => CommunityForm)) => void;
  onSubmit: (formData: FormData) => void;
}

export function CommunityContentEditor({ form, setForm, onSubmit }: CommunityContentEditorProps) {
  return (
    <form action={onSubmit} className="glass-panel grid gap-4 rounded-[32px] p-6">
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-bold uppercase leading-none">
          {form.id ? "Edit chapter" : "New chapter"}
        </p>
        {form.id ? (
          <button
            type="button"
            onClick={() => setForm(emptyForm)}
            className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
          >
            Clear
          </button>
        ) : null}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Chapter name
          <input
            name="name"
            required
            value={form.name}
            onChange={(event) =>
              setForm((current: CommunityForm) => ({ ...current, name: event.target.value }))
            }
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Region
          <input
            name="region"
            value={form.region}
            onChange={(event) =>
              setForm((current: CommunityForm) => ({ ...current, region: event.target.value }))
            }
            className="dashboard-input"
          />
        </label>
      </div>

      <label className="grid gap-2 text-sm">
        Description
        <textarea
          name="description"
          rows={3}
          value={form.description}
          onChange={(event) =>
            setForm((current: CommunityForm) => ({
              ...current,
              description: event.target.value,
            }))
          }
          className="dashboard-input min-h-20 resize-y"
        />
      </label>

      <div className="grid gap-4 sm:grid-cols-3">
        <label className="grid gap-2 text-sm">
          Members
          <input
            type="number"
            name="memberCount"
            value={form.memberCount}
            onChange={(event) =>
              setForm((current: CommunityForm) => ({
                ...current,
                memberCount: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Events
          <input
            type="number"
            name="eventCount"
            value={form.eventCount}
            onChange={(event) =>
              setForm((current: CommunityForm) => ({
                ...current,
                eventCount: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
        <label className="grid gap-2 text-sm">
          Rating
          <input
            type="number"
            name="rating"
            step="0.1"
            max="5"
            value={form.rating}
            onChange={(event) =>
              setForm((current: CommunityForm) => ({ ...current, rating: event.target.value }))
            }
            className="dashboard-input"
          />
        </label>
      </div>

      <label className="grid gap-2 text-sm">
        Banner image URL
        <input
          name="bannerImageUrl"
          value={form.bannerImageUrl}
          onChange={(event) =>
            setForm((current: CommunityForm) => ({
              ...current,
              bannerImageUrl: event.target.value,
            }))
          }
          className="dashboard-input"
        />
      </label>
      {form.bannerImageUrl.trim() ? (
        <div className="overflow-hidden rounded-[22px] border border-border-soft">
          {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs. */}
          <img src={form.bannerImageUrl} alt="Preview" className="h-28 w-full object-cover" />
        </div>
      ) : null}

      <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
        <input
          type="checkbox"
          name="isActive"
          checked={form.isActive}
          onChange={(event) =>
            setForm((current: CommunityForm) => ({
              ...current,
              isActive: event.target.checked,
            }))
          }
        />
        Active on public site
      </label>

      <button
        type="submit"
        className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
      >
        {form.id ? "Save chapter" : "Add chapter"}
      </button>
    </form>
  );
}

import type { useAdminMediaDraftScope } from "@/lib/use-admin-media-draft-scope";
import type { FormEvent } from "react";
import type { CommunityForm } from "./community-state";
import { AdminImageField } from "@/components/admin/admin-image-field";

interface CommunityContentEditorProps {
  draft: ReturnType<typeof useAdminMediaDraftScope>;
  form: CommunityForm;
  setForm: (
    update: CommunityForm | ((prev: CommunityForm) => CommunityForm),
  ) => void;
  onSubmit: (formData: FormData) => void;
  disabled?: boolean;
  onClear: () => Promise<void>;
}

export function CommunityContentEditor({
  form,
  draft,
  setForm,
  onSubmit,
  disabled = false,
  onClear,
}: CommunityContentEditorProps) {
  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formData = new FormData(event.currentTarget);
    onSubmit(formData);
  }

  return (
    <form onSubmit={handleSubmit} className="grid gap-4 p-4">
      {draft.error ? <p role="alert">{draft.error}</p> : null}
      <fieldset disabled={disabled} className="contents">
        <div className="flex items-center justify-between gap-3">
          <p className="font-display text-2xl font-medium normal-case leading-none text-[var(--admin-text-strong)]">
            {form.id ? "Edit FanClubs" : "New FanClubs"}
          </p>
          {form.id || draft.scopeKey ? (
            <button
              type="button"
              onClick={() => void onClear()}
              className="admin-action-button min-h-12"
            >
              Clear
            </button>
          ) : null}
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
            FanClubs name
            <input
              name="name"
              required
              maxLength={160}
              value={form.name}
              onChange={(event) =>
                setForm((current: CommunityForm) => ({
                  ...current,
                  name: event.target.value,
                }))
              }
              className="admin-input"
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
            Region
            <input
              name="region"
              required
              maxLength={120}
              value={form.region}
              onChange={(event) =>
                setForm((current: CommunityForm) => ({
                  ...current,
                  region: event.target.value,
                }))
              }
              className="admin-input"
            />
          </label>
        </div>

        <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
          Description
          <textarea
            name="description"
            required
            maxLength={3000}
            rows={3}
            value={form.description}
            onChange={(event) =>
              setForm((current: CommunityForm) => ({
                ...current,
                description: event.target.value,
              }))
            }
            className="admin-input min-h-24 resize-y"
          />
        </label>

        <div className="grid gap-4 sm:grid-cols-3">
          <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
            Members
            <input
              type="number"
              name="memberCount"
              min="0"
              max="1000000000"
              value={form.memberCount}
              onChange={(event) =>
                setForm((current: CommunityForm) => ({
                  ...current,
                  memberCount: event.target.value,
                }))
              }
              className="admin-input"
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
            Events
            <input
              type="number"
              name="eventCount"
              min="0"
              max="1000000"
              value={form.eventCount}
              onChange={(event) =>
                setForm((current: CommunityForm) => ({
                  ...current,
                  eventCount: event.target.value,
                }))
              }
              className="admin-input"
            />
          </label>
          <label className="grid gap-2 text-sm font-semibold text-[var(--admin-text-strong)]">
            Rating
            <input
              type="number"
              name="rating"
              step="0.1"
              min="0"
              max="5"
              value={form.rating}
              onChange={(event) =>
                setForm((current: CommunityForm) => ({
                  ...current,
                  rating: event.target.value,
                }))
              }
              className="admin-input"
            />
          </label>
        </div>

        <AdminImageField
          scopeKey={form.id || draft.scopeKey || "unavailable"}
          recoveryOnly={!form.id && draft.legacyUnbound}
          onRecoveryResolved={draft.refreshRecovery}
          disabled={!draft.ready && !draft.legacyUnbound}
          label="FanClubs banner"
          name="bannerImageUrl"
          value={form.bannerImageUrl}
          onChange={(nextValue) =>
            setForm((current: CommunityForm) => ({
              ...current,
              bannerImageUrl: nextValue,
            }))
          }
          mediaKind="fan_club"
          subject={form.name}
          previewAlt="FanClubs banner preview"
          promptPlaceholder="Example: Supporters FanClubs banner with a vibrant crowd, local community energy, club colors throughout, cinematic but welcoming."
        />

        <label className="flex min-h-12 items-center gap-3 rounded-[22px] border border-[var(--admin-border)] bg-[var(--admin-widget)] px-4 py-3 text-sm text-[var(--admin-text-strong)]">
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
          className="admin-action-button min-h-12 !bg-action-blue !text-white hover:!bg-action-blue-hover disabled:opacity-70"
        >
          {form.id ? "Save FanClubs" : "Add FanClubs"}
        </button>
      </fieldset>
    </form>
  );
}

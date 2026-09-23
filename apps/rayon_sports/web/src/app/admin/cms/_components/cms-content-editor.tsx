import type { ArticleForm } from "./cms-state";
import { emptyArticleForm, wordCount } from "./cms-state";
import { AdminImageField } from "@/components/admin/admin-image-field";
import { showAdminToast } from "@/components/admin/admin-toast";

interface CMSContentEditorProps {
  form: ArticleForm;
  setForm: (update: ArticleForm | ((prev: ArticleForm) => ArticleForm)) => void;
  onSubmit: (formData: FormData) => void;
  disabled?: boolean;
  onClear?: () => void;
}

export function CMSContentEditor({
  form,
  setForm,
  onSubmit,
  disabled = false,
  onClear,
}: CMSContentEditorProps) {
  return (
    <form action={onSubmit} className="glass-panel grid gap-4 rounded-[32px] p-6">
      <fieldset disabled={disabled} className="contents">
      <div className="flex items-center justify-between gap-3">
        <p className="font-display text-3xl font-medium normal-case leading-none">
          {form.id ? "Edit article" : "New article"}
        </p>
        {form.id ? (
          <button
            type="button"
            onClick={() => {
              setForm(emptyArticleForm);
              onClear?.();
              showAdminToast("Composer reset.", "info");
            }}
            className="min-h-12 rounded-full border border-border-soft px-4 py-3 text-sm font-semibold text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-surface-hover)]"
          >
            Clear
          </button>
        ) : null}
      </div>

      <label className="grid gap-2 text-sm">
        Title
        <input
          name="title"
          required
          value={form.title}
          onChange={(event) =>
            setForm((current: ArticleForm) => ({ ...current, title: event.target.value }))
          }
          className="dashboard-input"
        />
      </label>
      <label className="grid gap-2 text-sm">
        Subtitle
        <input
          name="subtitle"
          value={form.subtitle}
          onChange={(event) =>
            setForm((current: ArticleForm) => ({
              ...current,
              subtitle: event.target.value,
            }))
          }
          className="dashboard-input"
        />
      </label>
      <div className="grid gap-4 sm:grid-cols-2">
        <label className="grid gap-2 text-sm">
          Category
          <input
            name="category"
            value={form.category}
            onChange={(event) =>
              setForm((current: ArticleForm) => ({
                ...current,
                category: event.target.value,
              }))
            }
            className="dashboard-input"
          />
        </label>
        <AdminImageField
          label="Cover image"
          name="imageUrl"
          value={form.imageUrl}
          onChange={(nextValue) =>
            setForm((current: ArticleForm) => ({
              ...current,
              imageUrl: nextValue,
            }))
          }
          mediaKind="news_article"
          subject={form.title}
          previewAlt="Article cover preview"
          promptPlaceholder="Example: Matchday editorial hero image of celebrating supporters under floodlights, dramatic sports-photo composition, club colors visible, no watermark."
          className="sm:col-span-2"
        />
      </div>
      <label className="grid gap-2 text-sm">
        <div className="flex items-center justify-between">
          <span>Excerpt</span>
          <span className="font-mono text-xs text-[var(--admin-text-muted)]">{form.excerpt.length} chars</span>
        </div>
        <textarea
          name="excerpt"
          rows={3}
          value={form.excerpt}
          onChange={(event) =>
            setForm((current: ArticleForm) => ({
              ...current,
              excerpt: event.target.value,
            }))
          }
          className="dashboard-input min-h-24 resize-y"
        />
      </label>
      <label className="grid gap-2 text-sm">
        <div className="flex items-center justify-between">
          <span>Body</span>
          <span className="font-mono text-xs text-[var(--admin-text-muted)]">{wordCount(form.body)} words</span>
        </div>
        <textarea
          name="body"
          rows={8}
          required
          value={form.body}
          onChange={(event) =>
            setForm((current: ArticleForm) => ({ ...current, body: event.target.value }))
          }
          className="dashboard-input min-h-48 resize-y"
        />
      </label>
      <div className="grid gap-3 sm:grid-cols-2">
        <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3 text-sm">
          <input
            type="checkbox"
            name="isPublished"
            checked={form.isPublished}
            onChange={(event) =>
              setForm((current: ArticleForm) => ({
                ...current,
                isPublished: event.target.checked,
              }))
            }
          />
          Publish immediately
        </label>
        <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-[var(--admin-surface-muted)] px-4 py-3 text-sm">
          <input
            type="checkbox"
            name="isFeatured"
            checked={form.isFeatured}
            onChange={(event) =>
              setForm((current: ArticleForm) => ({
                ...current,
                isFeatured: event.target.checked,
              }))
            }
          />
          Mark as featured
        </label>
      </div>
      <button
        type="submit"
        className="min-h-12 rounded-full bg-action-blue px-5 py-3 font-semibold text-white transition hover:bg-action-blue-hover disabled:cursor-not-allowed disabled:opacity-70"
      >
        {form.id ? "Save article" : "Create article"}
      </button>
      </fieldset>
    </form>
  );
}

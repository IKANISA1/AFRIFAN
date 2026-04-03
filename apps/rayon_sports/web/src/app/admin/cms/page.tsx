"use client";

import { useCallback, useEffect, useState } from "react";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { Skeleton } from "@/components/skeleton";
import { SectionHeading } from "@/components/section-heading";
import { getAdminArticles, saveAdminArticle } from "@/lib/data/admin";
import { cn } from "@/lib/utils";
import type { AdminNewsArticle } from "@/lib/types";

const emptyArticleForm = {
  id: "",
  title: "",
  subtitle: "",
  category: "News",
  excerpt: "",
  body: "",
  imageUrl: "",
  isPublished: false,
  isFeatured: false,
};

function wordCount(text: string) {
  return text.trim() ? text.trim().split(/\s+/).length : 0;
}

export default function AdminCmsPage() {
  const { access, client } = useAdminPortal();
  const [articles, setArticles] = useState<AdminNewsArticle[]>([]);
  const [form, setForm] = useState(emptyArticleForm);
  const [loading, setLoading] = useState(true);

  const loadArticles = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setArticles(await getAdminArticles(client));
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not load articles.",
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
    loadArticles().catch(() => {});
  }, [access.hasAccess, client, loadArticles]);

  function beginEdit(article: AdminNewsArticle) {
    setForm({
      id: article.id,
      title: article.title,
      subtitle: article.subtitle ?? "",
      category: article.category,
      excerpt: article.excerpt,
      body: article.body,
      imageUrl: article.imageUrl ?? "",
      isPublished: article.isPublished,
      isFeatured: article.isFeatured,
    });
    showAdminToast(`Editing "${article.title}".`, "info");
  }

  async function submitForm(formData: FormData) {
    if (client == null) {
      return;
    }

    showAdminToast(form.id ? "Saving article..." : "Creating article...", "info");

    try {
      await saveAdminArticle(client, access, {
        id: form.id || null,
        title: String(formData.get("title") ?? ""),
        subtitle: String(formData.get("subtitle") ?? ""),
        category: String(formData.get("category") ?? "News"),
        excerpt: String(formData.get("excerpt") ?? ""),
        body: String(formData.get("body") ?? ""),
        imageUrl: String(formData.get("imageUrl") ?? ""),
        isPublished: formData.get("isPublished") === "on",
        isFeatured: formData.get("isFeatured") === "on",
      });
      setForm(emptyArticleForm);
      await loadArticles();
      showAdminToast("Article saved.", "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error ? caught.message : "Could not save article.",
        "error",
      );
    }
  }

  async function toggleArticle(article: AdminNewsArticle, field: "isPublished" | "isFeatured") {
    if (client == null) {
      return;
    }

    try {
      await saveAdminArticle(client, access, {
        id: article.id,
        title: article.title,
        subtitle: article.subtitle ?? "",
        category: article.category,
        excerpt: article.excerpt,
        body: article.body,
        imageUrl: article.imageUrl ?? "",
        isPublished:
          field === "isPublished" ? !article.isPublished : article.isPublished,
        isFeatured:
          field === "isFeatured" ? !article.isFeatured : article.isFeatured,
      });
      await loadArticles();
      const action = field === "isPublished"
        ? (article.isPublished ? "Unpublished" : "Published")
        : (article.isFeatured ? "Unfeatured" : "Featured");
      showAdminToast(`${action} "${article.title}".`, "success");
    } catch (caught) {
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not update article state.",
        "error",
      );
    }
  }

  return (
    <div className="section-grid">
      <SectionHeading
        eyebrow="CMS manager"
        title="Write once, publish to the mobile app and the web."
        description="The admin CMS is tuned for fast matchweek publishing on tablet and phone, with enough structure for featured stories and live homepage content."
      />

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <form action={submitForm} className="glass-panel grid gap-4 rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              {form.id ? "Edit article" : "New article"}
            </p>
            {form.id ? (
              <button
                type="button"
                onClick={() => {
                  setForm(emptyArticleForm);
                  showAdminToast("Composer reset.", "info");
                }}
                className="rounded-full border border-border-soft px-4 py-2 text-sm font-semibold text-slate-100 transition hover:bg-white/8"
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
                setForm((current) => ({ ...current, title: event.target.value }))
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
                setForm((current) => ({
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
                  setForm((current) => ({
                    ...current,
                    category: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
            <label className="grid gap-2 text-sm">
              Image URL
              <input
                name="imageUrl"
                value={form.imageUrl}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    imageUrl: event.target.value,
                  }))
                }
                className="dashboard-input"
              />
            </label>
          </div>
          {form.imageUrl.trim() ? (
            <div className="overflow-hidden rounded-[22px] border border-border-soft">
              {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting. */}
              <img src={form.imageUrl} alt="Cover preview" className="h-32 w-full object-cover" />
            </div>
          ) : null}
          <label className="grid gap-2 text-sm">
            <div className="flex items-center justify-between">
              <span>Excerpt</span>
              <span className="font-mono text-[10px] text-slate-400">{form.excerpt.length} chars</span>
            </div>
            <textarea
              name="excerpt"
              rows={3}
              value={form.excerpt}
              onChange={(event) =>
                setForm((current) => ({
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
              <span className="font-mono text-[10px] text-slate-400">{wordCount(form.body)} words</span>
            </div>
            <textarea
              name="body"
              rows={8}
              required
              value={form.body}
              onChange={(event) =>
                setForm((current) => ({ ...current, body: event.target.value }))
              }
              className="dashboard-input min-h-48 resize-y"
            />
          </label>
          <div className="grid gap-3 sm:grid-cols-2">
            <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
              <input
                type="checkbox"
                name="isPublished"
                checked={form.isPublished}
                onChange={(event) =>
                  setForm((current) => ({
                    ...current,
                    isPublished: event.target.checked,
                  }))
                }
              />
              Publish immediately
            </label>
            <label className="flex items-center gap-3 rounded-[22px] border border-border-soft bg-white/5 px-4 py-3 text-sm">
              <input
                type="checkbox"
                name="isFeatured"
                checked={form.isFeatured}
                onChange={(event) =>
                  setForm((current) => ({
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
            className="rounded-full bg-club-primary px-5 py-3 font-semibold text-white transition hover:bg-club-secondary"
          >
            {form.id ? "Save article" : "Create article"}
          </button>
        </form>

        <section className="glass-panel rounded-[32px] p-6">
          <div className="flex items-center justify-between gap-3">
            <p className="font-display text-3xl font-bold uppercase leading-none">
              Article feed
            </p>
            <button
              type="button"
              onClick={() => loadArticles().catch(() => {})}
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
                    <Skeleton className="skeleton-text h-6 w-3/5" />
                    <Skeleton className="skeleton-text mt-2 h-3 w-full" />
                    <div className="mt-4 flex gap-2">
                      <Skeleton className="h-6 w-16 rounded-full" />
                      <Skeleton className="h-6 w-12 rounded-full" />
                    </div>
                  </div>
                ))}
              </div>
            ) : null}
            {!loading && articles.length === 0 ? (
              <p className="rounded-[24px] border border-border-soft bg-white/5 px-4 py-4 text-sm text-slate-300">
                No articles yet. Use the composer to publish the first story.
              </p>
            ) : null}
            {!loading && articles.map((article) => (
              <article
                key={article.id}
                className={cn(
                  "card-interactive rounded-[26px] border border-border-soft p-5 transition",
                  article.isPublished ? "bg-white/5" : "bg-white/[0.02] opacity-70",
                )}
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="flex gap-4">
                    {article.imageUrl ? (
                      <div className="hidden sm:block h-16 w-16 flex-shrink-0 overflow-hidden rounded-xl border border-border-soft">
                        {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs that are not suitable for next/image allowlisting. */}
                        <img src={article.imageUrl} alt="" className="h-full w-full object-cover" />
                      </div>
                    ) : null}
                    <div className="space-y-2">
                      <p className="font-display text-2xl font-bold uppercase leading-none">
                        {article.title}
                      </p>
                      <p className="text-sm leading-6 text-slate-300">
                        {article.excerpt}
                      </p>
                    </div>
                  </div>
                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      onClick={() => beginEdit(article)}
                      className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                    >
                      Edit
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        toggleArticle(article, "isPublished").catch(() => {});
                      }}
                      className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                    >
                      {article.isPublished ? "Unpublish" : "Publish"}
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        toggleArticle(article, "isFeatured").catch(() => {});
                      }}
                      className="rounded-full border border-border-soft px-3 py-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-100 transition hover:bg-white/8"
                    >
                      {article.isFeatured ? "Unfeature" : "Feature"}
                    </button>
                  </div>
                </div>
                <div className="mt-4 flex flex-wrap items-center gap-2">
                  <span className="rounded-full bg-club-primary px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.18em] text-white">
                    {article.category}
                  </span>
                  <span className={cn(
                    "rounded-full border px-3 py-1.5 text-xs uppercase tracking-[0.18em]",
                    article.isPublished
                      ? "border-emerald-500/30 text-emerald-400"
                      : "border-border-soft text-slate-400",
                  )}>
                    {article.isPublished ? "Live" : "Draft"}
                  </span>
                  {article.isFeatured ? (
                    <span className="rounded-full border border-club-accent/40 bg-club-accent/10 px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-club-accent">
                      Featured
                    </span>
                  ) : null}
                  <span className="rounded-full border border-border-soft px-3 py-1.5 text-xs uppercase tracking-[0.18em] text-slate-400">
                    {wordCount(article.body)} words
                  </span>
                </div>
              </article>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}

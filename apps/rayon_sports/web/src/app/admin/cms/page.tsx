"use client";

import { useCallback, useState } from "react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import {
  AdminResourceStatusBanner,
  type AdminResourceInteraction,
} from "@/components/admin/admin-resource-status-banner";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminMediaDraftScope } from "@/lib/use-admin-media-draft-scope";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import {
  deleteAdminArticle,
  getAdminArticles,
  normalizeAdminArticles,
  saveAdminArticle,
} from "@/lib/data/admin/cms";
import { isAdminMutationConflict } from "@/lib/data/admin/http";
import type { AdminNewsArticle } from "@/lib/types";
import { useAdminResourceState } from "@/lib/use-admin-resource-state";
import { CMSContentEditor } from "./_components/cms-content-editor";
import { CMSContentList } from "./_components/cms-content-list";
import { emptyArticleForm } from "./_components/cms-state";

const emptyArticles: AdminNewsArticle[] = [];
const articlesAreEmpty = (articles: AdminNewsArticle[]) => articles.length === 0;

const cmsStatusCopy: Record<
  AdminResourceStatus,
  { label: string; detail: string }
> = {
  loading: {
    label: "Loading publishing operations",
    detail: "Waiting for the first authenticated article snapshot.",
  },
  ready: {
    label: "Publishing operations confirmed",
    detail: "Article drafts and publication states are current.",
  },
  empty: {
    label: "No articles in this scope",
    detail: "Use the editor to prepare the first controlled story.",
  },
  error: {
    label: "Publishing operations unavailable",
    detail: "Confirmed articles remain visible. Retry when service recovers.",
  },
  offline: {
    label: "Publishing workspace is offline",
    detail: "Confirmed articles remain visible until connection returns.",
  },
  permission_denied: {
    label: "Publishing access denied",
    detail: "Previously loaded article data and the active draft were cleared.",
  },
  syncing: {
    label: "Refreshing publishing operations",
    detail: "Confirmed articles remain visible during refresh.",
  },
  conflict: {
    label: "Article records changed",
    detail: "Refresh before editing, publishing, featuring, or deleting.",
  },
  security_timeout: {
    label: "Publishing request timed out",
    detail: "No article operation or change was confirmed.",
  },
};

export default function AdminCmsPage() {
  const { access, client } = useAdminPortal();
  const [form, setForm] = useState(emptyArticleForm);
  const draft = useAdminMediaDraftScope(access, "news_article");
  const [interaction, setInteraction] =
    useState<AdminResourceInteraction>("idle");

  const loadArticles = useCallback(
    (signal: AbortSignal) => {
      if (client == null) {
        return Promise.resolve([]);
      }
      return getAdminArticles(client, access, { signal });
    },
    [access, client],
  );
  const handlePermissionDenied = useCallback(() => {
    setForm(emptyArticleForm);
    setInteraction("idle");
  }, []);

  const {
    data: articles,
    status,
    hasConfirmed,
    busy,
    initialLoading,
    refresh,
    applyFailure,
  } = useAdminResourceState({
    enabled: client != null && access.hasAccess,
    emptyValue: emptyArticles,
    isEmpty: articlesAreEmpty,
    load: loadArticles,
    normalize: normalizeAdminArticles,
    onPermissionDenied: handlePermissionDenied,
    resourceLabel: "Publishing operations",
  });

  async function beginEdit(article: AdminNewsArticle) {
    if (!await draft.canLeaveDraft(form.id || undefined)) return;
    setForm({
      id: article.id,
      expectedUpdatedAt: article.updatedAt,
      title: article.title,
      subtitle: article.subtitle ?? "",
      category: article.category,
      excerpt: article.excerpt,
      body: article.body,
      imageUrl: article.imageUrl ?? "",
      isPublished: article.isPublished,
      isFeatured: article.isFeatured,
    });
    setInteraction("selected");
    showAdminToast(`Editing "${article.title}".`, "info");
  }

  async function submitForm(formData: FormData) {
    if (!await draft.canLeaveDraft(form.id || undefined)) return;
    if (client == null) return;
    showAdminToast(form.id ? "Saving article..." : "Creating article...", "info");

    try {
      await draft.runSave(() => saveAdminArticle(client, access, {
        id: form.id || null,
        expectedUpdatedAt: form.expectedUpdatedAt || null,
        title: String(formData.get("title") ?? ""),
        subtitle: String(formData.get("subtitle") ?? ""),
        category: String(formData.get("category") ?? "News"),
        excerpt: String(formData.get("excerpt") ?? ""),
        body: String(formData.get("body") ?? ""),
        imageUrl: String(formData.get("imageUrl") ?? ""),
        isPublished: formData.get("isPublished") === "on",
        isFeatured: formData.get("isFeatured") === "on",
      }), form.id || undefined);
      if (!await draft.resetDraft(form.id || undefined)) { showAdminToast("Saved. Recover this composer before starting another draft.", "info"); return; }
      setForm(emptyArticleForm);
      setInteraction("idle");
      await refresh();
      showAdminToast("Article saved.", "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? cmsStatusCopy.conflict.label
          : "Could not confirm the article change.",
        "error",
      );
    }
  }

  async function toggleArticle(
    article: AdminNewsArticle,
    field: "isPublished" | "isFeatured",
  ) {
    if (client == null) return;

    try {
      await saveAdminArticle(client, access, {
        id: article.id,
        expectedUpdatedAt: article.updatedAt,
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
      await refresh();
      const action =
        field === "isPublished"
          ? article.isPublished
            ? "Unpublished"
            : "Published"
          : article.isFeatured
            ? "Unfeatured"
            : "Featured";
      showAdminToast(`${action} "${article.title}".`, "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? cmsStatusCopy.conflict.label
          : "Could not confirm the article state change.",
        "error",
      );
    }
  }

  async function removeArticle(article: AdminNewsArticle) {
    if (client == null) return;
    if (
      !confirmAdminDestructiveAction({
        action: "Delete",
        subject: article.title,
        scope: `Active club ${access.clubId ?? "not selected"}`,
        impact: "The article will be removed from this club scope.",
        undo: "not_available",
      })
    ) {
      return;
    }

    try {
      await deleteAdminArticle(client, access, article.id, article.updatedAt);
      await refresh();
      showAdminToast(`Removed "${article.title}".`, "success");
    } catch (caught) {
      const nextStatus = applyFailure(caught);
      if (isAdminMutationConflict(caught)) {
        await refresh();
      }
      showAdminToast(
        nextStatus === "conflict"
          ? cmsStatusCopy.conflict.label
          : "Could not confirm article deletion.",
        "error",
      );
    }
  }

  const mutationLocked =
    busy ||
    status === "permission_denied" ||
    (!hasConfirmed && status !== "empty" && status !== "ready");

  return (
    <section
      className="admin-cms-state-surface section-grid"
      data-admin-cms-status={status}
      data-admin-cms-interaction={interaction}
      data-admin-cms-refresh-disabled={busy}
      aria-busy={busy || undefined}
    >
      <AdminPageHeader eyebrow="Publishing" title="Content" />

      <AdminResourceStatusBanner
        status={status}
        label={cmsStatusCopy[status].label}
        detail={cmsStatusCopy[status].detail}
        busy={busy}
        permissionLocked={status === "permission_denied"}
        refreshLabel="Refresh publishing"
        selected={interaction === "selected"}
        onRefresh={() => void refresh()}
        onInteractionChange={setInteraction}
        className="admin-cms-status"
      />

      {!hasConfirmed && !initialLoading ? (
        <AdminErrorState
          title={cmsStatusCopy[status].label}
          description={cmsStatusCopy[status].detail}
          onRetry={
            status === "permission_denied" ? undefined : () => void refresh()
          }
        />
      ) : (
        <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
          <CMSContentEditor
            form={form}
            setForm={setForm}
            draft={draft}
            onSubmit={submitForm}
            disabled={mutationLocked}
            onClear={async () => { if (await draft.resetDraft(form.id || undefined)) { setForm(emptyArticleForm); setInteraction("idle"); } }}
          />
          <CMSContentList
            articles={articles}
            loading={initialLoading}
            busy={busy}
            mutationLocked={mutationLocked}
            onRefresh={() => void refresh()}
            onBeginEdit={beginEdit}
            onToggleField={(article, field) =>
              void toggleArticle(article, field)
            }
            onRemove={(article) => void removeArticle(article)}
          />
        </div>
      )}
    </section>
  );
}

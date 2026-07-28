"use client";

import { useCallback, useEffect, useState } from "react";
import { AdminErrorState } from "@/components/admin/admin-error-state";
import { showAdminToast } from "@/components/admin/admin-toast";
import { useAdminPortal } from "@/components/admin/admin-portal-provider";
import { AdminPageHeader } from "@/components/admin/admin-page-header";
import { confirmAdminDestructiveAction } from "@/lib/admin-destructive-confirm";
import {
  deleteAdminArticle,
  getAdminArticles,
  saveAdminArticle,
} from "@/lib/data/admin/cms";
import type { AdminNewsArticle } from "@/lib/types";
import { emptyArticleForm } from "./_components/cms-state";
import { CMSContentEditor } from "./_components/cms-content-editor";
import { CMSContentList } from "./_components/cms-content-list";
import { isAdminMutationConflict } from "@/lib/data/admin/http";

export default function AdminCmsPage() {
  const { access, client } = useAdminPortal();
  const [articles, setArticles] = useState<AdminNewsArticle[]>([]);
  const [form, setForm] = useState(emptyArticleForm);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const loadArticles = useCallback(async () => {
    if (client == null) {
      return;
    }

    setLoading(true);
    try {
      setArticles(await getAdminArticles(client, access));
      setLoadError(null);
    } catch (caught) {
      const message =
        caught instanceof Error ? caught.message : "Could not load articles.";
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
    loadArticles().catch(() => {});
  }, [access.hasAccess, client, loadArticles]);

  function beginEdit(article: AdminNewsArticle) {
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
        expectedUpdatedAt: form.expectedUpdatedAt || null,
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
      if (isAdminMutationConflict(caught)) {
        await loadArticles();
      }
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
      await loadArticles();
      const action = field === "isPublished"
        ? (article.isPublished ? "Unpublished" : "Published")
        : (article.isFeatured ? "Unfeatured" : "Featured");
      showAdminToast(`${action} "${article.title}".`, "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await loadArticles();
      }
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not update article state.",
        "error",
      );
    }
  }

  async function removeArticle(article: AdminNewsArticle) {
    if (client == null) {
      return;
    }
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
      await deleteAdminArticle(
        client,
        access,
        article.id,
        article.updatedAt,
      );
      await loadArticles();
      showAdminToast(`Removed "${article.title}".`, "success");
    } catch (caught) {
      if (isAdminMutationConflict(caught)) {
        await loadArticles();
      }
      showAdminToast(
        caught instanceof Error
          ? caught.message
          : "Could not remove article.",
        "error",
      );
    }
  }

  return (
    <div className="section-grid">
      <AdminPageHeader
        eyebrow="Publishing"
        title="Content"
      />

      <div className="grid gap-5 xl:grid-cols-[0.9fr_1.1fr]">
        <CMSContentEditor
          form={form}
          setForm={setForm}
          onSubmit={submitForm}
        />

        {loadError && !loading ? (
          <AdminErrorState
            title="Articles could not be loaded"
            description={loadError}
            onRetry={() => {
              loadArticles().catch(() => {});
            }}
          />
        ) : (
          <CMSContentList
            articles={articles}
            loading={loading}
            onRefresh={() => loadArticles().catch(() => {})}
            onBeginEdit={beginEdit}
            onToggleField={(article, field) => toggleArticle(article, field).catch(() => {})}
            onRemove={(article) => removeArticle(article).catch(() => {})}
          />
        )}
      </div>
    </div>
  );
}

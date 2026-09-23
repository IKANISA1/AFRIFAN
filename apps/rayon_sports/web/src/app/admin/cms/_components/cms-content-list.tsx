"use client";

import { PencilLine, Search, Star, Trash2, Upload } from "lucide-react";
import { AdminDataGrid } from "@/components/admin/admin-data-grid";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminFilterBar } from "@/components/admin/admin-filter-bar";
import { AdminPagination } from "@/components/admin/admin-pagination";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { Skeleton } from "@/components/skeleton";
import type { AdminNewsArticle } from "@/lib/types";
import { wordCount } from "./cms-state";
import { useAdminCollection } from "@/lib/use-admin-collection";

interface CMSContentListProps {
  articles: AdminNewsArticle[];
  loading: boolean;
  busy: boolean;
  mutationLocked: boolean;
  onRefresh: () => void;
  onBeginEdit: (article: AdminNewsArticle) => void;
  onToggleField: (article: AdminNewsArticle, field: "isPublished" | "isFeatured") => void;
  onRemove: (article: AdminNewsArticle) => void;
}

export function CMSContentList({
  articles,
  loading,
  busy,
  mutationLocked,
  onRefresh,
  onBeginEdit,
  onToggleField,
  onRemove,
}: CMSContentListProps) {
  const articleCollection = useAdminCollection({
    records: articles,
    getId: (article) => article.id,
    getSearchValues: (article) => [
      article.title,
      article.subtitle,
      article.excerpt,
      article.category,
      article.isPublished ? "live published" : "draft",
      article.isFeatured ? "featured" : "standard",
    ],
    getSortValue: (
      article,
      key: "article" | "category" | "status" | "featured" | "words" | "updated",
    ) => {
      switch (key) {
        case "article": return article.title;
        case "category": return article.category;
        case "status": return article.isPublished;
        case "featured": return article.isFeatured;
        case "words": return wordCount(article.body);
        case "updated": return new Date(article.publishedAt ?? article.createdAt);
      }
    },
    initialSortKey: "updated" as const,
    initialSortDirection: "descending",
    pageSize: 25,
  });

  return (
    <AdminSurface
      title="Article queue"
      actions={
        <button
          type="button"
          onClick={onRefresh}
          disabled={busy}
          aria-label="Refresh article queue"
          className="admin-action-button min-h-12 min-w-12"
        >
          Refresh
        </button>
      }
      toolbar={
        <AdminFilterBar><label className="admin-search-field"><Search size={16} aria-hidden="true" /><span className="sr-only">Search article queue</span><input type="search" value={articleCollection.query} onChange={(event) => articleCollection.setQuery(event.target.value)} placeholder="Search article, category, or state" /></label></AdminFilterBar>
      }
      flush
    >
      {loading ? (
        <div className="space-y-3 p-5 sm:p-6">
          {Array.from({ length: 4 }).map((_, index) => (
            <div key={index} className="rounded-[20px] border border-border-soft bg-[var(--admin-surface-muted)] p-4">
              <Skeleton className="skeleton-text h-5 w-3/5" />
              <Skeleton className="skeleton-text mt-2 h-3 w-full" />
              <div className="mt-4 grid gap-3 sm:grid-cols-4">
                {Array.from({ length: 4 }).map((_, cellIndex) => (
                  <Skeleton key={cellIndex} className="h-10 rounded-xl" />
                ))}
              </div>
            </div>
          ))}
        </div>
      ) : (
        <>
          <AdminDataGrid
            caption="Article publishing queue"
            onRowActivate={(rowId) => {
              const article = articles.find((item) => item.id === rowId);
              if (article && !mutationLocked) onBeginEdit(article);
            }}
            columns={[
              { key: "article", label: "Article", priority: "primary", sortable: true, sortDirection: articleCollection.sortDirectionFor("article"), onSort: () => articleCollection.toggleSort("article") },
              { key: "category", label: "Category", priority: "secondary", sortable: true, sortDirection: articleCollection.sortDirectionFor("category"), onSort: () => articleCollection.toggleSort("category") },
              { key: "status", label: "Status", priority: "primary", sortable: true, sortDirection: articleCollection.sortDirectionFor("status"), onSort: () => articleCollection.toggleSort("status") },
              { key: "flags", label: "Flags", priority: "secondary", sortable: true, sortDirection: articleCollection.sortDirectionFor("featured"), onSort: () => articleCollection.toggleSort("featured") },
              { key: "words", label: "Words", priority: "tertiary", sortable: true, sortDirection: articleCollection.sortDirectionFor("words"), onSort: () => articleCollection.toggleSort("words") },
              { key: "updated", label: "Updated", priority: "secondary", sortable: true, sortDirection: articleCollection.sortDirectionFor("updated"), onSort: () => articleCollection.toggleSort("updated") },
              { key: "actions", label: "Actions", priority: "primary", className: "text-right" },
            ]}
          >
            {articleCollection.pageResult.items.length === 0 ? (
              <tr><td colSpan={7}><AdminEmptyState title="No articles yet" description={articleCollection.query ? "No articles match the current search." : "Use the editor to publish the first story."} /></td></tr>
            ) : articleCollection.pageResult.items.map((article) => (
                <tr
                  key={article.id}
                  data-row-id={article.id}
                >
                  <td>
                    <div className="flex gap-3">
                      {article.imageUrl ? (
                        <div className="hidden h-12 w-12 overflow-hidden rounded-xl border border-border-soft sm:block">
                          {/* eslint-disable-next-line @next/next/no-img-element -- Admin previews accept arbitrary remote URLs. */}
                          <img src={article.imageUrl} alt="" className="h-full w-full object-cover" />
                        </div>
                      ) : null}
                      <div>
                        <p className="admin-row-title">{article.title}</p>
                        <p className="admin-row-copy">{article.excerpt}</p>
                      </div>
                    </div>
                  </td>
                  <td>
                    <AdminStatusBadge label={article.category} tone="neutral" />
                  </td>
                  <td>
                    <AdminStatusBadge
                      label={article.isPublished ? "Live" : "Draft"}
                      tone={article.isPublished ? "success" : "neutral"}
                    />
                  </td>
                  <td>
                    <div className="flex flex-wrap gap-2">
                      {article.isFeatured ? (
                        <AdminStatusBadge label="Featured" tone="accent" />
                      ) : (
                        <span className="admin-row-meta">Standard</span>
                      )}
                    </div>
                  </td>
                  <td>
                    <p className="text-sm font-medium text-[var(--admin-text-strong)]">
                      {wordCount(article.body)}
                    </p>
                    <p className="admin-row-meta">body words</p>
                  </td>
                  <td>
                    <p className="text-sm font-medium text-[var(--admin-text-strong)]">
                      {new Date(article.publishedAt ?? article.createdAt).toLocaleDateString("en-US", {
                        month: "short",
                        day: "numeric",
                        year: "numeric",
                      })}
                    </p>
                    <p className="admin-row-meta">
                      {article.isPublished ? "published" : "created"}
                    </p>
                  </td>
                  <td>
                    <div className="flex flex-wrap justify-start gap-2 sm:justify-end">
                      <button
                        type="button"
                        disabled={mutationLocked}
                        onClick={() => onBeginEdit(article)}
                        aria-label={`Edit ${article.title}`}
                        className="admin-action-button min-h-12 min-w-12"
                      >
                        <PencilLine size={13} />
                        Edit
                      </button>
                      <button
                        type="button"
                        disabled={mutationLocked}
                        onClick={() => onToggleField(article, "isPublished")}
                        aria-label={`${article.isPublished ? "Unpublish" : "Publish"} ${article.title}`}
                        className="admin-action-button min-h-12 min-w-12"
                      >
                        <Upload size={13} />
                        {article.isPublished ? "Unpublish" : "Publish"}
                      </button>
                      <button
                        type="button"
                        disabled={mutationLocked}
                        onClick={() => onToggleField(article, "isFeatured")}
                        aria-label={`${article.isFeatured ? "Unfeature" : "Feature"} ${article.title}`}
                        className="admin-action-button min-h-12 min-w-12"
                      >
                        <Star size={13} />
                        {article.isFeatured ? "Unfeature" : "Feature"}
                      </button>
                      <button
                        type="button"
                        disabled={mutationLocked}
                        onClick={() => onRemove(article)}
                        aria-label={`Delete ${article.title}`}
                        className="admin-action-button admin-action-button-danger min-h-12 min-w-12"
                      >
                        <Trash2 size={13} />
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
          </AdminDataGrid>
          <AdminPagination page={articleCollection.pageResult} onPageChange={articleCollection.setPage} label="Article queue" />
        </>
      )}
    </AdminSurface>
  );
}

import { PencilLine, Star, Trash2, Upload } from "lucide-react";
import { AdminEmptyState } from "@/components/admin/admin-empty-state";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import { AdminSurface } from "@/components/admin/admin-surface";
import { Skeleton } from "@/components/skeleton";
import { cn } from "@/lib/utils";
import type { AdminNewsArticle } from "@/lib/types";
import { wordCount } from "./cms-state";

interface CMSContentListProps {
  articles: AdminNewsArticle[];
  loading: boolean;
  onRefresh: () => void;
  onBeginEdit: (article: AdminNewsArticle) => void;
  onToggleField: (article: AdminNewsArticle, field: "isPublished" | "isFeatured") => void;
  onRemove: (article: AdminNewsArticle) => void;
}

export function CMSContentList({
  articles,
  loading,
  onRefresh,
  onBeginEdit,
  onToggleField,
  onRemove,
}: CMSContentListProps) {
  return (
    <AdminSurface
      title="Article queue"
      description="Drafts, live stories, and featured placement."
      actions={
        <button
          type="button"
          onClick={onRefresh}
          className="admin-action-button"
        >
          Refresh
        </button>
      }
      flush
    >
      {loading ? (
        <div className="space-y-3 p-5 sm:p-6">
          {Array.from({ length: 4 }).map((_, index) => (
            <div key={index} className="rounded-[20px] border border-border-soft bg-white/5 p-4">
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
      ) : articles.length === 0 ? (
        <AdminEmptyState
          title="No articles yet"
          description="Use the editor to publish the first story."
        />
      ) : (
        <div className="admin-table-shell">
          <table className="admin-table">
            <thead>
              <tr>
                <th>Article</th>
                <th>Category</th>
                <th>Status</th>
                <th>Flags</th>
                <th>Words</th>
                <th>Updated</th>
                <th className="text-right">Actions</th>
              </tr>
            </thead>
            <tbody>
              {articles.map((article) => (
                <tr
                  key={article.id}
                  className={cn(!article.isPublished && "opacity-80")}
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
                    <p className="text-sm font-medium text-white">
                      {wordCount(article.body)}
                    </p>
                    <p className="admin-row-meta">body words</p>
                  </td>
                  <td>
                    <p className="text-sm font-medium text-white">
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
                    <div className="flex justify-end gap-2">
                      <button
                        type="button"
                        onClick={() => onBeginEdit(article)}
                        className="admin-action-button"
                      >
                        <PencilLine size={13} />
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={() => onToggleField(article, "isPublished")}
                        className="admin-action-button"
                      >
                        <Upload size={13} />
                        {article.isPublished ? "Unpublish" : "Publish"}
                      </button>
                      <button
                        type="button"
                        onClick={() => onToggleField(article, "isFeatured")}
                        className="admin-action-button"
                      >
                        <Star size={13} />
                        {article.isFeatured ? "Unfeature" : "Feature"}
                      </button>
                      <button
                        type="button"
                        onClick={() => onRemove(article)}
                        className="admin-action-button admin-action-button-danger"
                      >
                        <Trash2 size={13} />
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </AdminSurface>
  );
}

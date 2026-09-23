"use client";

import { ChevronFirst, ChevronLast, ChevronLeft, ChevronRight } from "lucide-react";
import type { AdminPage } from "@/lib/admin-collection";

interface AdminPaginationProps {
  page: Pick<
    AdminPage<unknown>,
    "page" | "pageSize" | "totalItems" | "totalPages" | "startItem" | "endItem"
  >;
  onPageChange: (page: number) => void;
  label: string;
}

export function AdminPagination({
  page,
  onPageChange,
  label,
}: AdminPaginationProps) {
  const previousDisabled = page.page <= 1;
  const nextDisabled = page.page >= page.totalPages;

  return (
    <nav
      className="admin-pagination"
      aria-label={`${label} pagination`}
      data-testid="admin-pagination"
    >
      <p className="admin-pagination-summary" aria-live="polite">
        {page.totalItems === 0
          ? "No records"
          : `${page.startItem}–${page.endItem} of ${page.totalItems}`}
      </p>
      <p className="admin-pagination-page">
        Page {page.page} of {page.totalPages}
      </p>
      <div className="admin-pagination-actions">
        <button
          type="button"
          className="admin-pagination-button"
          onClick={() => onPageChange(1)}
          disabled={previousDisabled}
          aria-label="Go to first page"
        >
          <ChevronFirst size={18} aria-hidden="true" />
        </button>
        <button
          type="button"
          className="admin-pagination-button"
          onClick={() => onPageChange(page.page - 1)}
          disabled={previousDisabled}
          aria-label="Go to previous page"
        >
          <ChevronLeft size={18} aria-hidden="true" />
        </button>
        <button
          type="button"
          className="admin-pagination-button"
          onClick={() => onPageChange(page.page + 1)}
          disabled={nextDisabled}
          aria-label="Go to next page"
        >
          <ChevronRight size={18} aria-hidden="true" />
        </button>
        <button
          type="button"
          className="admin-pagination-button"
          onClick={() => onPageChange(page.totalPages)}
          disabled={nextDisabled}
          aria-label="Go to last page"
        >
          <ChevronLast size={18} aria-hidden="true" />
        </button>
      </div>
    </nav>
  );
}

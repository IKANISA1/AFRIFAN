"use client";

import { ListChecks, X } from "lucide-react";

interface AdminSelectionBarProps {
  selectedCount: number;
  scopeLabel: string;
  onClear: () => void;
  onReview: () => void;
  reviewLabel?: string;
}

export function AdminSelectionBar({
  selectedCount,
  scopeLabel,
  onClear,
  onReview,
  reviewLabel = "Review selection",
}: AdminSelectionBarProps) {
  if (selectedCount === 0) {
    return null;
  }

  return (
    <section
      className="admin-selection-bar"
      aria-label="Selected records"
      aria-live="polite"
    >
      <div>
        <p className="admin-selection-count">
          <ListChecks size={18} aria-hidden="true" />
          {selectedCount} {selectedCount === 1 ? "record" : "records"} selected
        </p>
        <p className="admin-selection-scope">{scopeLabel}</p>
      </div>
      <div className="admin-selection-actions">
        <button type="button" className="admin-action-button" onClick={onClear}>
          <X size={16} aria-hidden="true" />
          Clear
        </button>
        <button
          type="button"
          className="admin-action-button !bg-club-accent !text-white"
          onClick={onReview}
        >
          {reviewLabel}
        </button>
      </div>
    </section>
  );
}

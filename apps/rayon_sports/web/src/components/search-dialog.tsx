"use client";

import Link from "next/link";
import { Search, Sparkles, X } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { SearchIndexItem } from "@/lib/types";
import { cn } from "@/lib/utils";
import { ui } from "@/design-system";

interface SearchDialogProps {
  open: boolean;
  onClose: () => void;
}

export function SearchDialog({ open, onClose }: SearchDialogProps) {
  const [items, setItems] = useState<SearchIndexItem[]>([]);
  const [hasLoaded, setHasLoaded] = useState(false);
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
  const dialogRef = useRef<HTMLDivElement>(null);
  const handleClose = useCallback(() => {
    setQuery("");
    onClose();
  }, [onClose]);

  useEffect(() => {
    function handleShortcut(event: KeyboardEvent) {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        if (open) {
          handleClose();
        }
      }
      if (event.key === "Escape" && open) {
        handleClose();
      }
    }

    window.addEventListener("keydown", handleShortcut);
    return () => window.removeEventListener("keydown", handleShortcut);
  }, [handleClose, open]);

  useEffect(() => {
    if (!open) {
      return;
    }

    const frame = window.requestAnimationFrame(() => {
      inputRef.current?.focus();
    });
    document.body.style.overflow = "hidden";

    return () => {
      window.cancelAnimationFrame(frame);
      document.body.style.overflow = "";
    };
  }, [open]);

  // Focus trap — cycle Tab within dialog
  useEffect(() => {
    if (!open) return;
    function handleFocusTrap(e: KeyboardEvent) {
      if (e.key !== "Tab") return;
      const dialog = dialogRef.current;
      if (!dialog) return;
      const focusable = dialog.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])',
      );
      if (focusable.length === 0) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (e.shiftKey) {
        if (document.activeElement === first) {
          e.preventDefault();
          last.focus();
        }
      } else {
        if (document.activeElement === last) {
          e.preventDefault();
          first.focus();
        }
      }
    }
    document.addEventListener("keydown", handleFocusTrap);
    return () => document.removeEventListener("keydown", handleFocusTrap);
  }, [open]);

  useEffect(() => {
    if (!open || hasLoaded) {
      return;
    }

    let cancelled = false;

    fetch("/api/search-index")
      .then((response) => response.json())
      .then((payload: { items?: SearchIndexItem[] }) => {
        if (!cancelled) {
          setItems(Array.isArray(payload.items) ? payload.items : []);
          setHasLoaded(true);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setItems([]);
          setHasLoaded(true);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [hasLoaded, open]);

  const isLoading = open && !hasLoaded;

  const results = useMemo(() => {
    const term = query.trim().toLowerCase();
    if (!term) {
      return items.slice(0, 9);
    }

    return items
      .filter((item) => {
        const haystack = `${item.title} ${item.description} ${item.meta ?? ""} ${item.category}`.toLowerCase();
        return haystack.includes(term);
      })
      .slice(0, 12);
  }, [items, query]);

  if (!open) {
    return null;
  }

  return (
    <div className="fixed inset-0 z-[70] flex items-start justify-center bg-[rgba(6,4,12,0.88)] px-4 py-10 backdrop-blur-md">
      <button
        type="button"
        className="absolute inset-0 cursor-default"
        aria-label="Close search"
        onClick={handleClose}
      />
      <div
        ref={dialogRef}
        className="relative z-10 w-full max-w-3xl animate-scale-up"
        role="dialog"
        aria-modal="true"
        aria-label="Search"
      >
        <div className={`${ui.panelElevated} overflow-hidden rounded-[32px]`}>
          <div className="flex items-center gap-3 px-5 py-4">
            <Search size={18} className="text-club-accent" />
            <input
              ref={inputRef}
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Search fixtures, news, products, circles, or pages"
              className="flex-1 bg-transparent text-base text-white outline-none placeholder:text-slate-500"
            />
            <button
              type="button"
              onClick={handleClose}
              className={`${ui.iconButton} h-10 w-10 text-slate-300`}
              aria-label="Close search"
            >
              <X size={16} />
            </button>
          </div>

          <div className={`flex items-center justify-between px-5 py-3 ${ui.meta}`}>
            <div className="flex items-center gap-2">
              <Sparkles size={14} className="text-club-accent" />
              Fast search
            </div>
            <span className="hidden sm:inline">Press ESC to close</span>
          </div>

          <div className="max-h-[65vh] overflow-y-auto p-3">
            {isLoading ? (
              <div className={`${ui.panelInset} rounded-[24px] px-5 py-10 text-center`}>
                <p className="font-display text-3xl font-bold uppercase tracking-[-0.05em] text-white">
                  Loading
                </p>
                <p className="mt-3 text-sm leading-7 text-slate-300">
                  Pulling the latest search index.
                </p>
              </div>
            ) : results.length > 0 ? (
              <div className="grid gap-2">
                {results.map((item) => (
                  <Link
                    key={item.id}
                    href={item.href}
                    onClick={handleClose}
                    className={`${ui.panelInset} ${ui.cardInteractive} rounded-[24px] px-4 py-4`}
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="space-y-2">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className={`${ui.chip} ${ui.chipSignal} px-2.5 py-1 text-[10px]`}>
                            {item.category}
                          </span>
                          {item.meta ? (
                            <span className={ui.meta}>
                              {item.meta}
                            </span>
                          ) : null}
                        </div>
                        <p className="text-lg font-semibold text-white">{item.title}</p>
                        <p className="text-sm leading-6 text-slate-300">
                          {item.description}
                        </p>
                      </div>
                      <span className="hidden text-xs uppercase tracking-[0.22em] text-slate-500 sm:inline">
                        Open
                      </span>
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <div className={`${ui.panelInset} rounded-[24px] px-5 py-10 text-center`}>
                <p className="font-display text-3xl font-bold uppercase tracking-[-0.05em] text-white">
                  No results
                </p>
                <p className="mt-3 text-sm leading-7 text-slate-300">
                  Try “APR”, “membership”, “circle”, or “shop”.
                </p>
              </div>
            )}
          </div>

          <div className="flex flex-wrap gap-2 px-5 py-4">
            {["Fixtures", "Tickets", "Membership", "Circles", "Shop"].map(
              (token) => (
                <button
                  key={token}
                  type="button"
                  onClick={() => setQuery(token)}
                  className={cn(
                    ui.chip,
                    ui.chipMuted,
                    "px-3 py-1.5 text-[11px] transition hover:text-white",
                    query === token && "bg-club-primary/20 text-white",
                  )}
                >
                  {token}
                </button>
              ),
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

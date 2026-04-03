"use client";

import Link from "next/link";
import { Search, Sparkles, X } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { SearchIndexItem } from "@/lib/types";
import { cn } from "@/lib/utils";

interface SearchDialogProps {
  open: boolean;
  onClose: () => void;
}

export function SearchDialog({ open, onClose }: SearchDialogProps) {
  const [items, setItems] = useState<SearchIndexItem[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);
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

  useEffect(() => {
    if (!open || items.length > 0 || isLoading) {
      return;
    }

    let cancelled = false;
    setIsLoading(true);

    fetch("/api/search-index")
      .then((response) => response.json())
      .then((payload: { items?: SearchIndexItem[] }) => {
        if (!cancelled) {
          setItems(Array.isArray(payload.items) ? payload.items : []);
        }
      })
      .catch(() => {
        if (!cancelled) {
          setItems([]);
        }
      })
      .finally(() => {
        if (!cancelled) {
          setIsLoading(false);
        }
      });

    return () => {
      cancelled = true;
    };
  }, [isLoading, items.length, open]);

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
    <div className="fixed inset-0 z-[70] flex items-start justify-center bg-[#020814]/88 px-4 py-10 backdrop-blur-md">
      <button
        type="button"
        className="absolute inset-0 cursor-default"
        aria-label="Close search"
        onClick={handleClose}
      />
      <div className="relative z-10 w-full max-w-3xl animate-scale-up">
        <div className="glass-panel-elevated overflow-hidden rounded-[32px] border border-border-soft">
          <div className="flex items-center gap-3 border-b border-border-soft px-5 py-4">
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
              className="flex h-10 w-10 items-center justify-center rounded-full border border-border-soft bg-white/5 text-slate-300 transition hover:bg-white/10 hover:text-white"
              aria-label="Close search"
            >
              <X size={16} />
            </button>
          </div>

          <div className="flex items-center justify-between border-b border-border-soft px-5 py-3 text-[11px] uppercase tracking-[0.24em] text-slate-400">
            <div className="flex items-center gap-2">
              <Sparkles size={14} className="text-club-accent" />
              Fast search
            </div>
            <span className="hidden sm:inline">Press ESC to close</span>
          </div>

          <div className="max-h-[65vh] overflow-y-auto p-3">
            {isLoading ? (
              <div className="rounded-[24px] border border-dashed border-border-soft bg-white/3 px-5 py-10 text-center">
                <p className="font-display text-3xl font-bold uppercase text-white">
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
                    className="card-interactive rounded-[24px] border border-border-soft bg-white/4 px-4 py-4"
                  >
                    <div className="flex items-start justify-between gap-3">
                      <div className="space-y-2">
                        <div className="flex flex-wrap items-center gap-2">
                          <span className="rounded-full bg-club-primary/18 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.22em] text-club-accent">
                            {item.category}
                          </span>
                          {item.meta ? (
                            <span className="text-[11px] uppercase tracking-[0.22em] text-slate-500">
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
              <div className="rounded-[24px] border border-dashed border-border-soft bg-white/3 px-5 py-10 text-center">
                <p className="font-display text-3xl font-bold uppercase text-white">
                  No results
                </p>
                <p className="mt-3 text-sm leading-7 text-slate-300">
                  Try “APR”, “membership”, “circle”, or “shop”.
                </p>
              </div>
            )}
          </div>

          <div className="flex flex-wrap gap-2 border-t border-border-soft px-5 py-4">
            {["Fixtures", "Tickets", "Membership", "Circles", "Shop"].map(
              (token) => (
                <button
                  key={token}
                  type="button"
                  onClick={() => setQuery(token)}
                  className={cn(
                    "rounded-full border border-border-soft px-3 py-1.5 text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-300 transition hover:bg-white/8 hover:text-white",
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

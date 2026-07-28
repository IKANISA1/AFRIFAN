"use client";

import { useEffect, useId, useRef, type ReactNode } from "react";
import { X } from "lucide-react";
import { cn } from "@/lib/utils";

const focusableSelector = [
  "a[href]",
  "button:not([disabled])",
  "textarea:not([disabled])",
  "input:not([disabled])",
  "select:not([disabled])",
  "[tabindex]:not([tabindex='-1'])",
].join(", ");

function getFocusableElements(container: HTMLElement | null) {
  if (container == null) {
    return [];
  }

  return Array.from(container.querySelectorAll<HTMLElement>(focusableSelector)).filter(
    (element) =>
      !element.hasAttribute("disabled") &&
      element.getAttribute("aria-hidden") !== "true" &&
      element.tabIndex !== -1,
  );
}

interface AdminDialogFrameProps {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: ReactNode;
  footer?: ReactNode;
  layout?: "center" | "drawer" | "sheet";
  panelClassName?: string;
  bodyClassName?: string;
  closeLabel?: string;
}

export function AdminDialogFrame({
  open,
  onClose,
  title,
  description,
  children,
  footer,
  layout = "center",
  panelClassName,
  bodyClassName,
  closeLabel = "Close dialog",
}: AdminDialogFrameProps) {
  const titleId = useId();
  const descriptionId = useId();
  const panelRef = useRef<HTMLDivElement | null>(null);
  const lastActiveRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!open) {
      return;
    }

    lastActiveRef.current =
      document.activeElement instanceof HTMLElement ? document.activeElement : null;

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const panel = panelRef.current;
    const focusTarget =
      getFocusableElements(panel).find((element) => element.dataset.autofocus === "true") ??
      getFocusableElements(panel)[0] ??
      panel;
    window.requestAnimationFrame(() => {
      focusTarget?.focus();
    });

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        event.preventDefault();
        onClose();
        return;
      }

      if (event.key !== "Tab" || panel == null) {
        return;
      }

      const focusableElements = getFocusableElements(panel);
      if (focusableElements.length === 0) {
        event.preventDefault();
        panel.focus();
        return;
      }

      const first = focusableElements[0];
      const last = focusableElements[focusableElements.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first?.focus();
      }
    };

    document.addEventListener("keydown", handleKeyDown);

    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener("keydown", handleKeyDown);
      window.requestAnimationFrame(() => {
        lastActiveRef.current?.focus();
      });
    };
  }, [onClose, open]);

  if (!open) {
    return null;
  }

  const layoutShellClassName =
    layout === "drawer"
      ? "justify-end"
      : layout === "sheet"
        ? "items-end justify-center px-0"
        : "items-center justify-center px-4";
  const layoutPanelClassName =
    layout === "drawer"
      ? "flex h-full w-full max-w-xl flex-col border-l"
      : layout === "sheet"
        ? "flex max-h-[85vh] w-full max-w-2xl flex-col rounded-t-[28px] border-t"
        : "flex w-full max-w-lg flex-col rounded-[32px] border";

  return (
    <div className={cn("fixed inset-0 z-50 flex", layoutShellClassName)}>
      <button
        type="button"
        aria-hidden="true"
        tabIndex={-1}
        className="absolute inset-0 bg-black/60 backdrop-blur-sm"
        onClick={onClose}
      />
      <div
        ref={panelRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby={titleId}
        aria-describedby={description ? descriptionId : undefined}
        tabIndex={-1}
        className={cn(
          "relative border-[var(--admin-border)] bg-[var(--admin-surface)] text-[var(--admin-text)] shadow-2xl outline-none",
          layoutPanelClassName,
          panelClassName,
        )}
      >
        <header className="flex items-start justify-between gap-4 border-b border-[var(--admin-border)] px-6 py-4">
          <div className="space-y-1">
            <h2 id={titleId} className="text-lg font-semibold text-[var(--admin-text-strong)]">
              {title}
            </h2>
            {description ? (
              <p id={descriptionId} className="text-sm text-[var(--admin-text-muted)]">
                {description}
              </p>
            ) : null}
          </div>
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-2 text-[var(--admin-text-muted)] transition hover:bg-[var(--admin-zinc-800)] hover:text-[var(--admin-text-strong)]"
            aria-label={closeLabel}
            data-autofocus="true"
          >
            <X size={18} />
          </button>
        </header>

        <div className={cn("flex-1 overflow-y-auto p-6", bodyClassName)}>{children}</div>

        {footer ? (
          <footer className="border-t border-[var(--admin-border)] bg-[var(--admin-zinc-950)] px-6 py-4">
            {footer}
          </footer>
        ) : null}
      </div>
    </div>
  );
}

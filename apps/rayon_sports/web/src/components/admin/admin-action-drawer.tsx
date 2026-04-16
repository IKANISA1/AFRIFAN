import { X } from "lucide-react";
import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

interface AdminActionDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  className?: string;
}

export function AdminActionDrawer({
  isOpen,
  onClose,
  title,
  children,
  footer,
  className,
}: AdminActionDrawerProps) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <div
        className="absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity"
        onClick={onClose}
      />
      <aside
        className={cn(
          "relative flex h-full w-full max-w-xl flex-col border-l border-[var(--admin-border)] bg-[var(--admin-surface)] shadow-2xl animate-in slide-in-from-right duration-300",
          className
        )}
      >
        <header className="flex items-center justify-between border-b border-[var(--admin-border)] px-6 py-4">
          <h2 className="text-lg font-semibold text-[var(--admin-text-strong)]">
            {title}
          </h2>
          <button
            onClick={onClose}
            className="rounded-lg p-2 text-[var(--admin-text-muted)] hover:bg-[var(--admin-zinc-800)] hover:text-[var(--admin-text-strong)] transition-colors"
          >
            <X size={20} />
          </button>
        </header>

        <div className="flex-1 overflow-y-auto p-6 custom-scrollbar">
          {children}
        </div>

        {footer ? (
          <footer className="border-t border-[var(--admin-border)] bg-[var(--admin-zinc-950)] px-6 py-4">
            {footer}
          </footer>
        ) : null}
      </aside>
    </div>
  );
}

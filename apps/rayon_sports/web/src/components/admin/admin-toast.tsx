"use client";

import { useCallback, useEffect, useState } from "react";
import { CheckCircle2, AlertTriangle, Info, X } from "lucide-react";
import { cn } from "@/lib/utils";

export type ToastVariant = "success" | "error" | "info";

interface Toast {
  id: string;
  message: string;
  variant: ToastVariant;
}

interface AdminToastContextValue {
  showToast: (message: string, variant?: ToastVariant) => void;
}

let globalShowToast: AdminToastContextValue["showToast"] | null = null;

export function showAdminToast(
  message: string,
  variant: ToastVariant = "info",
) {
  if (globalShowToast) {
    globalShowToast(message, variant);
  }
}

const icons: Record<ToastVariant, typeof Info> = {
  success: CheckCircle2,
  error: AlertTriangle,
  info: Info,
};

const variantStyles: Record<ToastVariant, string> = {
  success: "border-emerald-500/30 bg-emerald-500/10 text-emerald-200",
  error: "border-rose-400/30 bg-rose-500/10 text-rose-200",
  info: "border-border-soft bg-white/8 text-slate-200",
};

export function AdminToastProvider() {
  const [toasts, setToasts] = useState<Toast[]>([]);

  const showToast = useCallback(
    (message: string, variant: ToastVariant = "info") => {
      const id = `${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
      setToasts((current) => [...current.slice(-4), { id, message, variant }]);
    },
    [],
  );

  const dismiss = useCallback((id: string) => {
    setToasts((current) => current.filter((t) => t.id !== id));
  }, []);

  useEffect(() => {
    globalShowToast = showToast;
    return () => {
      globalShowToast = null;
    };
  }, [showToast]);

  useEffect(() => {
    if (toasts.length === 0) return;

    const timers = toasts.map((toast) => {
      const duration = toast.variant === "error" ? 8000 : 4000;
      return setTimeout(() => dismiss(toast.id), duration);
    });

    return () => timers.forEach(clearTimeout);
  }, [toasts, dismiss]);

  return (
    <div
      role="status"
      aria-live="polite"
      className="pointer-events-none fixed bottom-20 left-4 right-4 z-[80] flex max-w-sm flex-col gap-2 sm:left-auto xl:bottom-6 xl:right-6"
    >
      {toasts.map((toast) => {
        const Icon = icons[toast.variant];
        return (
          <div
            key={toast.id}
            role={toast.variant === "error" ? "alert" : undefined}
            aria-live={toast.variant === "error" ? "assertive" : undefined}
            className={cn(
              "pointer-events-auto flex items-start gap-3 rounded-2xl border px-4 py-3 shadow-lg backdrop-blur-xl animate-fade-up",
              variantStyles[toast.variant],
            )}
          >
            <Icon size={18} className="mt-0.5 flex-shrink-0" />
            <p className="flex-1 text-sm leading-6">{toast.message}</p>
            <button
              type="button"
              onClick={() => dismiss(toast.id)}
              className="mt-0.5 inline-flex min-h-12 min-w-12 flex-shrink-0 items-center justify-center rounded-full p-3 transition hover:bg-white/10"
              aria-label="Dismiss"
            >
              <X size={14} />
            </button>
          </div>
        );
      })}
    </div>
  );
}

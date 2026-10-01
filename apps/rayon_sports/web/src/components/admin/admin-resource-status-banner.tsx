"use client";

import { RefreshCw } from "lucide-react";
import { useRef, type PointerEvent } from "react";
import type { AdminResourceStatus } from "@/lib/admin-resource-state";
import { cn } from "@/lib/utils";

export type AdminResourceInteraction =
  | "idle"
  | "focused"
  | "pressed"
  | "selected";

export function AdminResourceStatusBanner({
  status,
  label,
  detail,
  busy,
  permissionLocked = false,
  refreshLabel,
  selected = false,
  onRefresh,
  onInteractionChange,
  className,
}: {
  status: AdminResourceStatus;
  label: string;
  detail: string;
  busy: boolean;
  permissionLocked?: boolean;
  refreshLabel: string;
  selected?: boolean;
  onRefresh: () => void;
  onInteractionChange: (interaction: AdminResourceInteraction) => void;
  className?: string;
}) {
  const pointerPressed = useRef(false);
  const setPressed = (event: PointerEvent<HTMLButtonElement>) => {
    event.currentTarget.setPointerCapture?.(event.pointerId);
    pointerPressed.current = true;
    onInteractionChange("pressed");
  };
  const restInteraction = () => {
    // Focus/blur can follow pointerdown in a different order across browsers.
    // A held pointer remains pressed until release, cancellation or lost capture.
    if (pointerPressed.current) return;
    onInteractionChange(selected ? "selected" : "idle");
  };
  const finishPointer = () => {
    pointerPressed.current = false;
    restInteraction();
  };

  return (
    <div
      className={cn(
        "admin-resource-status rounded-2xl border px-4 py-3",
        status === "permission_denied" ||
          status === "error" ||
          status === "security_timeout"
          ? "border-error/30 bg-error/10"
          : status === "offline" || status === "conflict"
            ? "border-warning/30 bg-warning/10"
            : "border-[var(--admin-border)] bg-[var(--admin-widget)]",
        className,
      )}
      role={
        status === "error" ||
        status === "permission_denied" ||
        status === "security_timeout"
          ? "alert"
          : "status"
      }
      aria-live={
        status === "error" ||
        status === "permission_denied" ||
        status === "security_timeout"
          ? "assertive"
          : "polite"
      }
    >
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div className="min-w-0">
          <p className="font-medium text-[var(--admin-text-strong)]">{label}</p>
          <p className="mt-1 text-sm leading-6 text-[var(--admin-secondary)]">
            {detail}
          </p>
        </div>
        <button
          type="button"
          disabled={busy || permissionLocked}
          onClick={onRefresh}
          onFocus={() => {
            if (!pointerPressed.current) onInteractionChange("focused");
          }}
          onBlur={restInteraction}
          onPointerDown={setPressed}
          onPointerUp={finishPointer}
          onPointerCancel={finishPointer}
          onLostPointerCapture={finishPointer}
          className="admin-resource-control inline-flex min-h-12 items-center justify-center gap-2 rounded-xl border border-[var(--admin-border)] px-4 py-3 text-sm font-medium text-[var(--admin-text-strong)] transition hover:bg-[var(--admin-raised)] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent disabled:cursor-not-allowed disabled:bg-[var(--admin-raised)] disabled:text-[var(--admin-text-strong)] motion-reduce:transition-none"
        >
          <RefreshCw
            size={17}
            aria-hidden="true"
            className={busy ? "animate-spin motion-reduce:animate-none" : ""}
          />
          {status === "error" ||
          status === "offline" ||
          status === "conflict" ||
          status === "security_timeout"
            ? "Try again"
            : refreshLabel}
        </button>
      </div>
    </div>
  );
}

"use client";

import { useRouter } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { ui } from "@/ui-kit";

interface BackButtonProps {
  /** Optional label next to the arrow. Defaults to no label (icon only). */
  label?: string;
  /** Optional className for custom positioning. */
  className?: string;
}

/**
 * A back-navigation button for use in standalone PWA mode where there is
 * no browser chrome. Falls back to `router.back()`.
 */
export function BackButton({ label, className }: BackButtonProps) {
  const router = useRouter();

  return (
    <button
      type="button"
      onClick={() => router.back()}
      aria-label={label ?? "Go back"}
      className={`${ui.buttonSecondary} px-3 py-2 text-sm font-medium active:scale-95 focus-ring ${className ?? ""}`}
    >
      <ArrowLeft size={18} />
      {label ? <span>{label}</span> : null}
    </button>
  );
}

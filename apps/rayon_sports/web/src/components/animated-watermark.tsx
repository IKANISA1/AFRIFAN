"use client";

import Image from "next/image";
import { useEffect, useState } from "react";
import { cn } from "@/lib/utils";

/**
 * Animated Brand Mark Watermark
 * Subtly pulsates and rotates slowly in the background of major sections.
 * Pauses if user prefers reduced motion.
 */
export function AnimatedWatermark({ 
  className,
  imageUrl = "/brand-mark.svg"
}: { 
  className?: string,
  imageUrl?: string
}) {
  const [isReducedMotion, setIsReducedMotion] = useState(() =>
    typeof window !== "undefined"
      ? window.matchMedia("(prefers-reduced-motion: reduce)").matches
      : false,
  );

  useEffect(() => {
    if (typeof window === "undefined") return;
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    const handler = (e: MediaQueryListEvent) => setIsReducedMotion(e.matches);
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, []);

  return (
    <div className={cn("pointer-events-none absolute opacity-[0.03] mix-blend-overlay", className)}>
      <Image
        src={imageUrl}
        alt=""
        aria-hidden="true"
        fill
        className={cn(
          "object-contain",
          !isReducedMotion && "animate-[spin_60s_linear_infinite]"
        )}
      />
    </div>
  );
}

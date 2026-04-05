"use client";

import Image from "next/image";
import { useEffect, useState } from "react";
import { cn } from "@/lib/utils";

/**
 * Animated Crest Watermark
 * Subtly pulsates and rotates slowly in the background of major sections.
 * Pauses if user prefers reduced motion.
 */
export function AnimatedWatermark({ 
  className,
  imageUrl = "/icons/icon-512x512.png" 
}: { 
  className?: string,
  imageUrl?: string
}) {
  const [isReducedMotion, setIsReducedMotion] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const mq = window.matchMedia("(prefers-reduced-motion: reduce)");
    setIsReducedMotion(mq.matches);
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

"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

interface PullToRefreshProps {
  onRefresh: () => Promise<void>;
  children: React.ReactNode;
  className?: string;
  /** Minimum pull distance in px to trigger refresh */
  threshold?: number;
}

/**
 * Pull-to-refresh wrapper for mobile content feeds.
 * Shows a spinner indicator when pulled past the threshold.
 * Falls back gracefully on desktop (no-op).
 */
export function PullToRefresh({
  onRefresh,
  children,
  className,
  threshold = 80,
}: PullToRefreshProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [pullDistance, setPullDistance] = useState(0);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const startYRef = useRef(0);
  const isPullingRef = useRef(false);

  const handleTouchStart = useCallback(
    (e: TouchEvent) => {
      if (isRefreshing) return;
      const container = containerRef.current;
      if (!container || container.scrollTop > 0) return;
      startYRef.current = e.touches[0].clientY;
      isPullingRef.current = true;
    },
    [isRefreshing],
  );

  const handleTouchMove = useCallback(
    (e: TouchEvent) => {
      if (!isPullingRef.current || isRefreshing) return;
      const deltaY = e.touches[0].clientY - startYRef.current;
      if (deltaY > 0) {
        // Rubber-band effect: diminishing returns past threshold
        const dampened = deltaY > threshold ? threshold + (deltaY - threshold) * 0.3 : deltaY;
        setPullDistance(dampened);
        if (deltaY > 10) {
          e.preventDefault();
        }
      }
    },
    [isRefreshing, threshold],
  );

  const handleTouchEnd = useCallback(async () => {
    isPullingRef.current = false;
    if (pullDistance >= threshold && !isRefreshing) {
      setIsRefreshing(true);
      try {
        await onRefresh();
      } catch {
        // Silently handle refresh errors
      } finally {
        setIsRefreshing(false);
      }
    }
    setPullDistance(0);
  }, [pullDistance, threshold, isRefreshing, onRefresh]);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    container.addEventListener("touchstart", handleTouchStart, { passive: true });
    container.addEventListener("touchmove", handleTouchMove, { passive: false });
    container.addEventListener("touchend", handleTouchEnd);

    return () => {
      container.removeEventListener("touchstart", handleTouchStart);
      container.removeEventListener("touchmove", handleTouchMove);
      container.removeEventListener("touchend", handleTouchEnd);
    };
  }, [handleTouchStart, handleTouchMove, handleTouchEnd]);

  const progress = Math.min(pullDistance / threshold, 1);

  return (
    <div ref={containerRef} className={cn("relative", className)}>
      {/* Pull indicator */}
      <div
        className="pointer-events-none absolute left-1/2 z-10 -translate-x-1/2 transition-opacity duration-200"
        style={{
          top: Math.max(pullDistance - 40, -40),
          opacity: progress > 0.2 ? progress : 0,
        }}
      >
        <div
          className={cn(
            "flex h-9 w-9 items-center justify-center rounded-full bg-surface-elevated border border-border-soft shadow-lg",
            isRefreshing && "animate-spin",
          )}
        >
          <svg
            className="h-5 w-5 text-club-accent"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          >
            <path d="M21 12a9 9 0 0 0-9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
            <path d="M3 3v5h5" />
            <path d="M3 12a9 9 0 0 0 9 9 9.75 9.75 0 0 0 6.74-2.74L21 16" />
            <path d="M21 21v-5h-5" />
          </svg>
        </div>
      </div>

      {/* Content wrapper */}
      <div
        style={{
          transform: pullDistance > 0 ? `translateY(${pullDistance}px)` : undefined,
          transition: isPullingRef.current ? "none" : "transform 300ms ease-out",
        }}
      >
        {children}
      </div>
    </div>
  );
}

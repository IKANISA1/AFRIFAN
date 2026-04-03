"use client";

import { useEffect, useRef, useState } from "react";

interface CountUpProps {
  value: number;
  className?: string;
  duration?: number;
  formatter?: (n: number) => string;
}

/**
 * Animates a number counting up from 0 on scroll-in.
 * Uses the existing `count-in` keyframe for the reveal animation.
 */
export function CountUp({
  value,
  className,
  duration = 1200,
  formatter,
}: CountUpProps) {
  const ref = useRef<HTMLSpanElement>(null);
  const [display, setDisplay] = useState("0");
  const [started, setStarted] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    if (typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      const frame = window.requestAnimationFrame(() => {
        setDisplay(formatter ? formatter(value) : String(value));
        setStarted(true);
      });
      return () => window.cancelAnimationFrame(frame);
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setStarted(true);
          observer.unobserve(el);
        }
      },
      { threshold: 0.3 },
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, [value, formatter]);

  useEffect(() => {
    if (!started) return;

    const start = performance.now();
    let frame: number;

    function tick(now: number) {
      const elapsed = now - start;
      const progress = Math.min(elapsed / duration, 1);
      // Ease-out cubic for smooth deceleration
      const eased = 1 - Math.pow(1 - progress, 3);
      const current = Math.round(eased * value);
      setDisplay(formatter ? formatter(current) : String(current));

      if (progress < 1) {
        frame = requestAnimationFrame(tick);
      }
    }

    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [started, value, duration, formatter]);

  return (
    <span
      ref={ref}
      className={className}
      style={{
        animation: started ? "count-in 500ms var(--ease-out-expo) both" : undefined,
      }}
    >
      {display}
    </span>
  );
}

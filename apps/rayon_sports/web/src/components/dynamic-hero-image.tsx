"use client";

import { useEffect, useState } from "react";
import Image from "next/image";

interface DynamicHeroImageProps {
  /** Array of image URLs to cycle through */
  images: string[];
  /** Interval in ms between transitions */
  intervalMs?: number;
  alt?: string;
}

/**
 * Smooth crossfading hero background image.
 * Cycles through multiple images with a dissolve transition.
 * Respects prefers-reduced-motion (shows first image only).
 */
export function DynamicHeroImage({
  images,
  intervalMs = 6000,
  alt = "Club matchday atmosphere",
}: DynamicHeroImageProps) {
  const [activeIndex, setActiveIndex] = useState(0);
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

  useEffect(() => {
    if (isReducedMotion || images.length <= 1) return;
    const timer = setInterval(() => {
      setActiveIndex((prev) => (prev + 1) % images.length);
    }, intervalMs);
    return () => clearInterval(timer);
  }, [images.length, intervalMs, isReducedMotion]);

  if (images.length === 0) return null;

  return (
    <>
      {images.map((src, i) => (
        <Image
          key={src}
          src={src}
          alt={alt}
          fill
          priority={i === 0}
          sizes="(min-width: 1280px) 80rem, calc(100vw - 2rem)"
          quality={60}
          className="object-cover transition-opacity duration-[1600ms] ease-in-out"
          style={{ opacity: i === activeIndex ? 1 : 0 }}
        />
      ))}
    </>
  );
}

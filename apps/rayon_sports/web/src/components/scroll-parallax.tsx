"use client";

import { useEffect, useRef, useState } from "react";
import { cn } from "@/lib/utils";

interface ScrollParallaxProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode;
  speed?: number; // 0 to 1, where 1 is fastest (fixed), 0 is normal scrolling. Default 0.3.
}

/**
 * A lightweight scroll parallax container without heavy dependencies.
 * Respects prefers-reduced-motion user settings.
 */
export function ScrollParallax({ 
  children, 
  speed = 0.3,
  className,
  ...props 
}: ScrollParallaxProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [offsetY, setOffsetY] = useState(0);

  useEffect(() => {
    // Check for reduced motion
    if (typeof window !== 'undefined') {
      const isReducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      if (isReducedMotion) return;
    }

    let animationFrameId: number;
    let initialTop = 0;

    const onScroll = () => {
      if (!containerRef.current) return;
      
      const scrollY = window.scrollY;
      const rect = containerRef.current.getBoundingClientRect();
      
      // Only animate if the element is near or in the viewport
      if (rect.top < window.innerHeight && rect.bottom > 0) {
        // Calculate offset based on scroll position relative to initial render
        const offset = scrollY * speed;
        setOffsetY(offset);
      }
    };

    const handleScroll = () => {
      cancelAnimationFrame(animationFrameId);
      animationFrameId = requestAnimationFrame(onScroll);
    };

    window.addEventListener("scroll", handleScroll, { passive: true });
    
    // Initial calculation setup
    if (containerRef.current) {
      initialTop = window.scrollY + containerRef.current.getBoundingClientRect().top;
      onScroll();
    }

    return () => {
      window.removeEventListener("scroll", handleScroll);
      cancelAnimationFrame(animationFrameId);
    };
  }, [speed]);

  return (
    <div 
      className={cn("relative overflow-hidden", className)} 
      {...props}
    >
      <div 
        ref={containerRef}
        className="absolute inset-[-20%] h-[140%] w-[140%] origin-center will-change-transform"
        style={{
          transform: `translate3d(0, ${offsetY}px, 0)`,
        }}
      >
        {children}
      </div>
    </div>
  );
}

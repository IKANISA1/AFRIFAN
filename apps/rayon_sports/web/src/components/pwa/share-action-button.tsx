"use client";

import { useEffect, useRef, useState } from "react";
import { shareContent } from "@/lib/share";

interface ShareActionButtonProps {
  title: string;
  text?: string;
  url: string;
  className?: string;
  defaultLabel?: string;
}

export function ShareActionButton({
  title,
  text,
  url,
  className,
  defaultLabel = "Share",
}: ShareActionButtonProps) {
  const [didShare, setDidShare] = useState(false);
  const resetTimer = useRef<number | null>(null);

  useEffect(() => {
    return () => {
      if (resetTimer.current != null) {
        window.clearTimeout(resetTimer.current);
      }
    };
  }, []);

  async function handleShare() {
    const shared = await shareContent({
      title,
      text,
      url:
        typeof window === "undefined"
          ? url
          : new URL(url, window.location.origin).toString(),
    });

    if (resetTimer.current != null) {
      window.clearTimeout(resetTimer.current);
      resetTimer.current = null;
    }

    setDidShare(shared);
    if (shared && typeof window !== "undefined") {
      resetTimer.current = window.setTimeout(() => {
        setDidShare(false);
        resetTimer.current = null;
      }, 2400);
    }
  }

  return (
    <button
      type="button"
      onClick={() => {
        handleShare().catch(() => {});
      }}
      className={className}
    >
      {didShare ? "Link ready" : defaultLabel}
    </button>
  );
}

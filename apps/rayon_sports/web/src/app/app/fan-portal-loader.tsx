"use client";

import dynamic from "next/dynamic";
import type { ReactNode } from "react";

const FanPortalFrame = dynamic(
  () => import("./fan-portal-frame").then((mod) => mod.FanPortalFrame),
  {
    ssr: false,
    loading: () => (
      <div className="page-shell flex min-h-[60vh] flex-col items-center justify-center gap-6 py-10">
        {/* Club crest */}
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src="/icons/icon-192x192.png"
          alt=""
          width={64}
          height={64}
          className="animate-pulse rounded-2xl"
        />
        {/* Shimmer skeleton blocks */}
        <div className="w-full max-w-sm space-y-3">
          <div className="h-4 w-3/4 animate-pulse rounded-full bg-white/8" />
          <div className="h-4 w-1/2 animate-pulse rounded-full bg-white/6" />
          <div className="h-12 w-full animate-pulse rounded-[20px] bg-white/5" />
        </div>
        <p className="text-sm text-slate-300">Starting your matchday base…</p>
      </div>
    ),
  },
);

export function FanPortalLoader({ children }: { children: ReactNode }) {
  return <FanPortalFrame>{children}</FanPortalFrame>;
}

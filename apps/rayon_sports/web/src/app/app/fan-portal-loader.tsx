"use client";

import dynamic from "next/dynamic";
import type { ReactNode } from "react";

const FanPortalFrame = dynamic(
  () => import("./fan-portal-frame").then((mod) => mod.FanPortalFrame),
  {
    ssr: false,
    loading: () => (
      <div className="page-shell py-10 text-sm text-slate-400">
        Loading fan portal…
      </div>
    ),
  },
);

export function FanPortalLoader({ children }: { children: ReactNode }) {
  return <FanPortalFrame>{children}</FanPortalFrame>;
}

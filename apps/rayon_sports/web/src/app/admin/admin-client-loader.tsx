"use client";

import dynamic from "next/dynamic";
import type { ReactNode } from "react";

const AdminClientFrame = dynamic(
  () => import("./admin-client-frame").then((mod) => mod.AdminClientFrame),
  {
    ssr: false,
    loading: () => (
      <div className="page-shell py-10 text-sm text-slate-400">
        Loading admin workspace…
      </div>
    ),
  },
);

export function AdminClientLoader({ children }: { children: ReactNode }) {
  return <AdminClientFrame>{children}</AdminClientFrame>;
}

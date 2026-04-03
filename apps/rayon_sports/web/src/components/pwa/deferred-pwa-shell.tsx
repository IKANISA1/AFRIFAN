"use client";

import dynamic from "next/dynamic";

const PwaShell = dynamic(
  () => import("./pwa-shell").then((mod) => mod.PwaShell),
  { ssr: false, loading: () => null },
);

export function DeferredPwaShell() {
  return <PwaShell />;
}

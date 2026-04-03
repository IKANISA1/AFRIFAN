"use client";

import dynamic from "next/dynamic";

const Breadcrumbs = dynamic(
  () => import("./breadcrumbs").then((mod) => mod.Breadcrumbs),
  { ssr: false, loading: () => null },
);

export function DeferredBreadcrumbs() {
  return <Breadcrumbs />;
}

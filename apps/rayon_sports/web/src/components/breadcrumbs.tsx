"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { ChevronRight, Home } from "lucide-react";

const labelMap: Record<string, string> = {
  news: "News",
  fixtures: "Fixtures",
  standings: "Standings",
  squad: "Squad",
  tickets: "Tickets",
  shop: "Shop",
  membership: "Membership",
  circles: "Support Circles",
  "fan-clubs": "Fan Clubs",
  history: "History",
  contact: "Contact",
  privacy: "Privacy",
  terms: "Terms",
  results: "Results",
  admin: "Admin",
};

export function Breadcrumbs() {
  const pathname = usePathname();

  if (pathname === "/") return null;

  const segments = pathname.split("/").filter(Boolean);
  if (segments.length === 0) return null;

  const crumbs = segments.map((seg, i) => {
    const href = "/" + segments.slice(0, i + 1).join("/");
    const label =
      labelMap[seg] ??
      seg
        .replace(/-/g, " ")
        .replace(/\b\w/g, (letter) => letter.toUpperCase());
    const isLast = i === segments.length - 1;
    return { href, label, isLast };
  });

  return (
    <nav
      aria-label="Breadcrumb"
      className="page-shell flex items-center gap-1.5 py-3 text-xs"
    >
      <Link
        href="/"
        className="flex items-center gap-1 text-slate-300 transition hover:text-white"
      >
        <Home size={12} />
        <span className="sr-only">Home</span>
      </Link>
      {crumbs.map((crumb) => (
        <span key={crumb.href} className="flex items-center gap-1.5">
          <ChevronRight size={11} className="text-slate-500" />
          {crumb.isLast ? (
            <span className="font-semibold uppercase tracking-[0.18em] text-slate-200">
              {crumb.label}
            </span>
          ) : (
            <Link
              href={crumb.href}
              className="uppercase tracking-[0.18em] text-slate-300 transition hover:text-white"
            >
              {crumb.label}
            </Link>
          )}
        </span>
      ))}
    </nav>
  );
}

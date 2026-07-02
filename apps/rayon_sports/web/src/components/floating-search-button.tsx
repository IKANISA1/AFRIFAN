"use client";

import { Search } from "lucide-react";
import dynamic from "next/dynamic";
import { useState } from "react";
import { ui } from "@/ui-kit";

const SearchDialog = dynamic(
  () => import("./search-dialog").then((mod) => mod.SearchDialog),
  { ssr: false },
);

export function FloatingSearchButton({ label = "Search" }: { label?: string }) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        aria-label={label}
        className={`fixed bottom-[calc(env(safe-area-inset-bottom)+68px)] right-4 z-50 h-12 w-12 ${ui.buttonPrimary} px-0 shadow-lg shadow-club-primary/30 active:scale-90 lg:hidden`}
      >
        <Search size={20} strokeWidth={2} />
      </button>
      {open && <SearchDialog open={open} onClose={() => setOpen(false)} />}
    </>
  );
}

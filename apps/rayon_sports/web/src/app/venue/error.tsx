"use client";

import { useEffect } from "react";
import { ui } from "@/ui-kit";

export default function VenueError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Venue route failed", { digest: error.digest ?? "unavailable" });
  }, [error]);

  return (
    <main className="mx-auto max-w-7xl px-5 py-8 lg:px-8">
      <section
        className={`${ui.panelElevated} rounded-lg border border-red-400/40 p-6`}
        role="alert"
      >
        <p className={ui.kicker}>Venue operations</p>
        <h1 className="mt-3 text-2xl font-bold uppercase">
          This workflow could not load
        </h1>
        <p className="mt-3 max-w-2xl text-sm leading-6 text-slate-300">
          No venue change was made. Retry after checking the connection. If the
          problem continues, share the support reference shown below.
        </p>
        <p className="mt-3 font-mono text-xs text-slate-400">
          Reference: {error.digest ?? "unavailable"}
        </p>
        <button
          type="button"
          className={`${ui.buttonPrimary} mt-5`}
          onClick={reset}
        >
          Retry workflow
        </button>
      </section>
    </main>
  );
}

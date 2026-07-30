import { ui } from "@/ui-kit";

export default function VenueLoading() {
  return (
    <main
      className="mx-auto grid max-w-7xl gap-6 px-5 py-8 lg:px-8"
      aria-busy="true"
      aria-live="polite"
    >
      <section className={`${ui.panelElevated} rounded-lg p-5`}>
        <p className={ui.kicker}>Venue operations</p>
        <h1 className="mt-3 font-display text-4xl font-bold uppercase md:text-6xl">
          Loading assigned venue
        </h1>
        <p className="mt-4 max-w-2xl text-sm leading-7 text-slate-300">
          Confirming your current assignment and the latest operational state.
        </p>
      </section>
      <section className="grid gap-4 md:grid-cols-3" aria-hidden="true">
        {Array.from({ length: 3 }, (_value, index) => (
          <div
            key={index}
            className={`${ui.panel} min-h-32 animate-pulse rounded-lg p-5`}
          />
        ))}
      </section>
      <span className="sr-only">Loading venue operations</span>
    </main>
  );
}

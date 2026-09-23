import { SkeletonTable } from "@/components/skeleton";

export default function StandingsLoading() {
  return (
    <div className="site-loading page-shell section-grid py-12" role="status" aria-busy="true">
      <span className="sr-only">Loading page…</span>
      <SkeletonTable />
    </div>
  );
}

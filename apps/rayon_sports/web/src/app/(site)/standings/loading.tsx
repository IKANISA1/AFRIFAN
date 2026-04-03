import { SkeletonTable } from "@/components/skeleton";

export default function StandingsLoading() {
  return (
    <div className="page-shell section-grid py-12">
      <SkeletonTable />
    </div>
  );
}

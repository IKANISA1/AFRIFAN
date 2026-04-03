import { SkeletonCard } from "@/components/skeleton";

export default function FanClubsLoading() {
  return (
    <div className="page-shell section-grid py-12">
      <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
        <SkeletonCard />
        <SkeletonCard />
        <SkeletonCard />
      </div>
    </div>
  );
}

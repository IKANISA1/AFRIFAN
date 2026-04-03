import { SkeletonCard } from "@/components/skeleton";

export default function FixturesLoading() {
  return (
    <div className="page-shell section-grid py-12">
      <div className="grid gap-5 lg:grid-cols-3">
        <SkeletonCard />
        <SkeletonCard />
        <SkeletonCard />
      </div>
    </div>
  );
}

import { SkeletonCard, SkeletonHero, SkeletonTable } from "@/components/skeleton";

export default function SiteLoading() {
  return (
    <div className="page-shell section-grid py-12">
      <SkeletonHero />
      <div className="grid gap-5 lg:grid-cols-3">
        <SkeletonCard />
        <SkeletonCard />
        <SkeletonCard />
      </div>
      <SkeletonTable />
    </div>
  );
}

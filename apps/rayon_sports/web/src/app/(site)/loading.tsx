import { SkeletonCard, SkeletonHero, SkeletonTable } from "@/components/skeleton";

export default function SiteLoading() {
  return (
    <div className="site-loading page-shell section-grid py-12" role="status" aria-busy="true">
      <span className="sr-only">Loading page…</span>
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

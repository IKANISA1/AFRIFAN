import { SkeletonCard } from "@/components/skeleton";

export default function MembershipLoading() {
  return (
    <div className="page-shell section-grid py-12">
      <div className="grid gap-5 lg:grid-cols-2">
        <SkeletonCard />
        <SkeletonCard />
      </div>
    </div>
  );
}

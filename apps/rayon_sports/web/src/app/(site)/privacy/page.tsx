import { buildPageMetadata } from "@/lib/metadata";
import { SectionHeading } from "@/components/section-heading";

export const metadata = buildPageMetadata({
  title: "Privacy policy",
  description:
    "How Rayon Sports handles supporter data across the public website and fan portal.",
  path: "/privacy",
});

export default function PrivacyPage() {
  return (
    <div className="page-shell section-grid py-12">
      <SectionHeading
        eyebrow="Privacy"
        title="Supporter data with clear boundaries."
      />
      <div className="glass-panel rounded-[30px] p-6 text-sm leading-7 text-slate-300">
        <p>
          The Gikundiro web experience stores only the minimum supporter data
          required to run portal services such as membership, tickets, shop
          orders, and support circles. Sensitive payment and private contact
          details remain segmented from public profile data.
        </p>
      </div>
    </div>
  );
}

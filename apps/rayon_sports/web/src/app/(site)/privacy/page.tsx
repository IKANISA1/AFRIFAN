import { buildPageMetadata } from "@/lib/metadata";
import { SectionHeading } from "@/components/section-heading";
import { getCmsContentBlock } from "@/lib/data/public";

export const metadata = buildPageMetadata({
  title: "Privacy policy",
  description:
    "How Rayon Sports handles supporter data across the public website and fan portal.",
  path: "/privacy",
});

const fallbackPrivacy =
  "The Gikundiro web experience stores only the minimum supporter data required to run portal services such as membership, tickets, shop orders, and support circles. Sensitive payment and private contact details remain segmented from public profile data.";

export default async function PrivacyPage() {
  const cmsBlock = await getCmsContentBlock("privacy_policy");
  const content = cmsBlock?.body || fallbackPrivacy;
  const title = cmsBlock?.title || "Supporter data with clear boundaries.";

  return (
    <div className="page-shell section-grid py-12">
      <SectionHeading
        eyebrow="Privacy"
        title={title}
      />
      <div className="glass-panel rounded-[30px] p-6 text-sm leading-7 text-slate-300">
        {content.split("\n\n").map((paragraph, i) => (
          <p key={i} className={i > 0 ? "mt-4" : ""}>
            {paragraph}
          </p>
        ))}
      </div>
    </div>
  );
}

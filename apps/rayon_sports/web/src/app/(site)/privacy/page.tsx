import { buildPageMetadata } from "@/lib/metadata";
import { SectionHeading } from "@/components/section-heading";
import { getClubProfile, getCmsContentBlock } from "@/lib/data/public";

export async function generateMetadata() {
  const club = await getClubProfile();
  return buildPageMetadata({
    title: "Privacy policy",
    description: `How ${club.shortName} handles supporter data across the public website and fan app.`,
    path: "/privacy",
  });
}

export default async function PrivacyPage() {
  const [club, cmsBlock] = await Promise.all([
    getClubProfile(),
    getCmsContentBlock("privacy_policy"),
  ]);
  const fallbackPrivacy =
    `The ${club.shortName} web experience stores only the minimum supporter data required to run website and fan app services such as membership, tickets, shop orders, and support circles. Sensitive payment and private contact details remain segmented from public profile data.`;
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

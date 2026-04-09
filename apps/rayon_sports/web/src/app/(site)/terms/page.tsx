import { buildPageMetadata } from "@/lib/metadata";
import { SectionHeading } from "@/components/section-heading";
import { getClubProfile, getCmsContentBlock } from "@/lib/data/public";

export async function generateMetadata() {
  const club = await getClubProfile();
  return buildPageMetadata({
    title: "Terms and conditions",
    description: `Terms for tickets, memberships, shop orders, and supporter activity across the ${club.shortName} website and fan app.`,
    path: "/terms",
  });
}

export default async function TermsPage() {
  const [club, cmsBlock] = await Promise.all([
    getClubProfile(),
    getCmsContentBlock("terms"),
  ]);
  const fallbackTerms =
    `Ticketing, shop orders, memberships, and contribution records created through the website are part of the same ${club.shortName} supporter platform used by the mobile app. Availability, pricing, and supporter eligibility remain subject to club policy and live operational status.`;
  const content = cmsBlock?.body || fallbackTerms;
  const title = cmsBlock?.title || "One supporter platform across web and mobile.";

  return (
    <div className="page-shell section-grid py-12">
      <SectionHeading
        eyebrow="Terms"
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

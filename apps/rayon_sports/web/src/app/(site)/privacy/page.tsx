import { buildPageMetadata } from "@/lib/metadata";
import { SectionHeading } from "@/components/section-heading";
import { getClubProfile, getCmsContentBlock } from "@/lib/data/public";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.privacy.metaTitle,
    description: copy.pages.privacy.metaDescription(club),
    path: "/privacy",
  });
}

export default async function PrivacyPage() {
  const [club, cmsBlock] = await Promise.all([
    getClubProfile(),
    getCmsContentBlock("privacy_policy"),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);
  const fallbackPrivacy =
    `${club.shortName}: ${copy.pages.privacy.fallbackBody}`;
  const content = cmsBlock?.body || fallbackPrivacy;
  const title = cmsBlock?.title || copy.pages.privacy.fallbackTitle;

  return (
    <div className="page-shell section-grid py-12">
      <SectionHeading
        eyebrow={copy.pages.privacy.eyebrow}
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

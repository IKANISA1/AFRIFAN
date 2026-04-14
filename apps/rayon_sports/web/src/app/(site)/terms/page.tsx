import { buildPageMetadata } from "@/lib/metadata";
import { SectionHeading } from "@/components/section-heading";
import { getClubProfile, getCmsContentBlock } from "@/lib/data/public";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    title: copy.pages.terms.metaTitle,
    description: copy.pages.terms.metaDescription(club),
    path: "/terms",
  });
}

export default async function TermsPage() {
  const [club, cmsBlock] = await Promise.all([
    getClubProfile(),
    getCmsContentBlock("terms"),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);
  const fallbackTerms =
    `${club.shortName}: ${copy.pages.terms.fallbackBody}`;
  const content = cmsBlock?.body || fallbackTerms;
  const title = cmsBlock?.title || copy.pages.terms.fallbackTitle;

  return (
    <div className="page-shell section-grid py-12">
      <SectionHeading
        eyebrow={copy.pages.terms.eyebrow}
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

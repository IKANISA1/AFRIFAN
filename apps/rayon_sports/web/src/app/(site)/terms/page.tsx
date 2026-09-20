import { buildPageMetadata } from "@/lib/metadata";
import {
  LegalDocument,
  resolveLegalDocumentText,
} from "@/components/legal-document";
import { getClubProfile, getCmsContentBlock } from "@/lib/data/public";
import { getSiteCopy } from "@/lib/site-copy";
import {
  policyLastUpdated,
  supportEmail,
  termsSections,
} from "@/lib/release-legal-content";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    club,
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
  const content = resolveLegalDocumentText(cmsBlock?.body, fallbackTerms);
  const title = resolveLegalDocumentText(
    cmsBlock?.title,
    copy.pages.terms.fallbackTitle,
  );

  return (
    <LegalDocument
      eyebrow={copy.pages.terms.eyebrow}
      title={title}
      content={content}
      documentKind="terms"
      lastUpdated={policyLastUpdated}
      sections={termsSections}
      actions={[
        { href: "/privacy", label: "Read the Privacy Policy" },
        { href: `mailto:${supportEmail}`, label: "Contact support" },
      ]}
    />
  );
}

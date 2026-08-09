import { buildPageMetadata } from "@/lib/metadata";
import {
  LegalDocument,
  resolveLegalDocumentText,
} from "@/components/legal-document";
import { getClubProfile, getCmsContentBlock } from "@/lib/data/public";
import { getSiteCopy } from "@/lib/site-copy";
import {
  policyLastUpdated,
  privacyPolicySections,
  supportEmail,
} from "@/lib/release-legal-content";

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
  const content = resolveLegalDocumentText(cmsBlock?.body, fallbackPrivacy);
  const title = resolveLegalDocumentText(
    cmsBlock?.title,
    copy.pages.privacy.fallbackTitle,
  );

  return (
    <LegalDocument
      eyebrow={copy.pages.privacy.eyebrow}
      title={title}
      content={content}
      documentKind="privacy"
      lastUpdated={policyLastUpdated}
      sections={privacyPolicySections}
      actions={[
        { href: "/account-deletion", label: "Request account deletion" },
        { href: `mailto:${supportEmail}`, label: "Contact privacy support" },
      ]}
    />
  );
}

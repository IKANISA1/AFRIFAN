import { ContactSurface } from "@/components/contact-surface";
import { hasFanAppDestination, resolveFanAppHref } from "@/lib/config";
import { getClubProfile, getCmsContent } from "@/lib/data/public";
import { buildPageMetadata } from "@/lib/metadata";
import { getSiteCopy } from "@/lib/site-copy";

export async function generateMetadata() {
  const club = await getClubProfile();
  const copy = getSiteCopy(club.defaultLanguage);
  return buildPageMetadata({
    club,
    title: copy.pages.contact.metaTitle(club),
    description: copy.pages.contact.metaDescription(club),
    path: "/contact",
  });
}

const fallbackSupportBlocks = [
  "Membership and confirmed contribution history are available in the member area. Other account follow-up depends on the released supporter features.",
  "Public contact stays focused on club communication, media, and general supporter questions.",
];

export default async function ContactPage() {
  const [club, cmsBlocks] = await Promise.all([
    getClubProfile(),
    getCmsContent("contact_support"),
  ]);
  const copy = getSiteCopy(club.defaultLanguage);

  const socialLinks = [
    { label: "Facebook", href: club.facebookUrl },
    { label: "Instagram", href: club.instagramUrl },
    { label: "X", href: club.xUrl },
    { label: "TikTok", href: club.tiktokUrl },
  ];

  // Use CMS content for support blocks if available
  const supportBlocks =
    cmsBlocks.length > 0
      ? cmsBlocks.map((block) => block.body || block.title)
      : fallbackSupportBlocks;

  const digitalSupportTitle =
    cmsBlocks.length > 0
      ? cmsBlocks[0]?.subtitle || copy.pages.contact.digitalSupport
      : copy.pages.contact.digitalSupport;

  const digitalSupportDescription =
    cmsBlocks.length > 0
      ? cmsBlocks[0]?.rationale ||
      copy.pages.contact.digitalSupportDescription
      : copy.pages.contact.digitalSupportDescription;

  return (
    <ContactSurface
      eyebrow={copy.pages.contact.eyebrow}
      title={copy.pages.contact.title}
      description={copy.pages.contact.description}
      fanAppHref={resolveFanAppHref(club.clubSlug)}
      openFanAppLabel={hasFanAppDestination(club.clubSlug) ? copy.openFanApp : "Check supporter app availability"}
      membershipSupportLabel={copy.pages.contact.membershipSupport}
      officialContact={club.officialContact}
      languages={club.supportedLanguages}
      digitalSupportTitle={digitalSupportTitle}
      digitalSupportDescription={digitalSupportDescription}
      supportBlocks={supportBlocks}
      socialChannelsLabel={copy.pages.contact.socialChannels}
      newsroomLabel={copy.common.clubNewsroom}
      socialLinks={socialLinks}
    />
  );
}

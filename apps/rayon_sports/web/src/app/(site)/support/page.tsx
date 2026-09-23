import { SupportSurface } from "@/components/support-surface";
import { getClubProfile } from "@/lib/data/public";
import { buildPageMetadata, getClubWebsiteIdentity } from "@/lib/metadata";
import { supportEmail } from "@/lib/release-legal-content";

export async function generateMetadata() {
  const club = await getClubProfile();
  const brand = getClubWebsiteIdentity(club).name;
  return buildPageMetadata({
    club,
    title: `${brand} support`,
    description:
      `Official ${brand} support routes for accounts, membership, tickets, orders, privacy, and account deletion.`,
    path: "/support",
  });
}

export default async function SupportPage() {
  const brand = getClubWebsiteIdentity(await getClubProfile()).name;
  return (
    <SupportSurface
      kind="support"
      eyebrow="Support"
      title={`Get help through the right ${brand} channel.`}
      description="Authenticated account, membership, ticket, order, and contribution questions are safest in the mobile app. Public support remains available when you cannot sign in."
      steps={[
        {
          heading: "Use the mobile app when you can sign in",
          body: "Open the relevant membership, ticket, shop, contribution, or profile journey so the request remains attached to the correct supporter account.",
        },
        {
          heading: "Use public support if access is unavailable",
          body: `Email ${supportEmail} with a short description and a safe callback address. Support will use an approved account-control verification process before discussing protected information.`,
        },
        {
          heading: "Use the dedicated privacy route for deletion",
          body: "The account-deletion page explains the in-app deletion flow, the public request route, what is removed, and what may be lawfully retained.",
        },
      ]}
      notice="Never email a password, one-time code, payment credential, full identity document, biometric material, or private recovery secret. Support will not ask for them through this page."
      actions={[
        {
          href: `mailto:${supportEmail}?subject=${encodeURIComponent(`${brand} support request`)}`,
          label: `Email ${brand} support`,
          primary: true,
        },
        { href: "/account-deletion", label: "Account deletion" },
        { href: "/privacy", label: "Privacy Policy" },
      ]}
    />
  );
}

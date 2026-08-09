import { SupportSurface } from "@/components/support-surface";
import { buildPageMetadata } from "@/lib/metadata";
import { supportEmail } from "@/lib/release-legal-content";

export const metadata = buildPageMetadata({
  title: "Gikundiro support",
  description:
    "Official Gikundiro support routes for accounts, membership, tickets, orders, privacy, and account deletion.",
  path: "/support",
});

export default function SupportPage() {
  return (
    <SupportSurface
      kind="support"
      eyebrow="Support"
      title="Get help through the right Gikundiro channel."
      description="Authenticated account, membership, ticket, order, and contribution questions are safest in the mobile app. Public support remains available when you cannot sign in or need help with an approved Gikundiro TV display."
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
        {
          heading: "Request support for an approved TV display",
          body: "An authorized display owner can request pairing, assignment, revocation, or provisioning-data support. Share only the public display alias or approved callback details; never email the display credential or pairing challenge.",
        },
      ]}
      notice="Never email a password, one-time code, payment credential, full identity document, biometric material, or private recovery secret. Support will not ask for them through this page."
      actions={[
        {
          href: `mailto:${supportEmail}?subject=Gikundiro%20support%20request`,
          label: "Email Gikundiro support",
          primary: true,
        },
        { href: "/account-deletion", label: "Account deletion" },
        { href: "/privacy", label: "Privacy Policy" },
      ]}
    />
  );
}

import { SupportSurface } from "@/components/support-surface";
import { buildPageMetadata } from "@/lib/metadata";
import { supportEmail } from "@/lib/release-legal-content";

export const metadata = buildPageMetadata({
  title: "Delete your Gikundiro account",
  description:
    "Delete an accessible Gikundiro account in the mobile app or start a privacy-safe public deletion request.",
  path: "/account-deletion",
});

export default function AccountDeletionPage() {
  return (
    <SupportSurface
      kind="account-deletion"
      eyebrow="Account deletion"
      title="Delete your account and linked personal data."
      description="The authenticated in-app flow is immediate and safest. If you cannot access the app, public support can start a verified deletion request without collecting credentials on this website."
      steps={[
        {
          heading: "Delete an accessible account in the app",
          body: "Open Profile, choose Settings, select Delete Account, read the consequences, type DELETE, and confirm. The app calls the protected deletion service for the currently authenticated account and signs the device out.",
        },
        {
          heading: "Request deletion when the app is inaccessible",
          body: `Email ${supportEmail} with the subject “Gikundiro account deletion request.” Include only the display name or phone number you previously chose to associate with the account and a safe callback address.`,
        },
        {
          heading: "Complete privacy-safe account-control verification",
          body: "Support must verify that the requester controls the account before deleting it. The team will use the approved recovery channel and will never ask for a password, one-time code, payment credential, biometric sample, or full identity document by email.",
        },
        {
          heading: "Receive completion or retention information",
          body: "The active profile and account-linked application data are removed through the governed deletion workflow. Confirmed transaction, fraud-prevention, security, and audit records may remain access-restricted only when an applicable legal or documented operational obligation requires retention.",
        },
      ]}
      notice="Account deletion is irreversible. Do not send passwords, verification codes, payment credentials, biometric material, or identity documents with a public request."
      actions={[
        {
          href: `mailto:${supportEmail}?subject=Gikundiro%20account%20deletion%20request`,
          label: "Start a deletion request",
          primary: true,
        },
        { href: "/privacy#account-deletion", label: "Read deletion and retention terms" },
        { href: "/support", label: "General support" },
      ]}
    />
  );
}

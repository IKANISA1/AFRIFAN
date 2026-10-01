import type { LegalDocumentSection } from "@/components/legal-document";

export const policyLastUpdated = "9 August 2026";
export const supportEmail = "support@ikanisa.com";

export function getPrivacyPolicySections(clubName: string): LegalDocumentSection[] { return [
  {
    heading: "Information we process",
    paragraphs: [
      `${clubName} supports guest and authenticated supporter journeys. The information processed depends on the features a supporter chooses to use.`,
    ],
    items: [
      "Optional profile details, including display name and phone number.",
      "Membership, ticket, shop-order, contribution, prediction, reward, and support history.",
      "Account, installation, device-attestation, push-delivery, security, and fraud-prevention identifiers.",
      "Consent-controlled product-interaction, crash, and performance diagnostics when those services are enabled for the release.",
    ],
  },
  {
    heading: "How information is used",
    items: [
      "Provide the supporter features requested in the website or mobile app.",
      "Authenticate accounts, enforce club and role boundaries, protect transactions, and prevent abuse.",
      "Deliver requested notifications and reconcile confirmed memberships, tickets, orders, and contributions.",
      "Maintain reliability and improve the product using only the diagnostics permitted by the selected consent and release configuration.",
    ],
  },
  {
    heading: "Mobile permissions and diagnostics",
    paragraphs: [
      "The current public mobile release candidate does not request SMS or Call Log access and does not provide SMS auto-read. A future or separately distributed release must provide its own disclosure, consent and control flow, platform-policy approval, and updated store declarations before processing payment messages.",
      "Firebase App Check, push delivery, crash reporting, performance monitoring, and analytics operate only when the relevant service is included and enabled for the release and, where applicable, the supporter has provided consent.",
    ],
  },
  {
    heading: "Service providers and sharing",
    paragraphs: [
      "We do not sell personal information or use it for cross-app advertising. Supabase provides account, database, storage, and server-function services. Configured Firebase services may provide app attestation, push delivery, and consent-controlled diagnostics. These providers process information only to operate, secure, and support the service under their applicable terms.",
    ],
  },
  {
    heading: "Security and retention",
    paragraphs: [
      "Network traffic uses HTTPS/TLS. Application authorization and database access controls are designed to separate supporter, club, and administrative data. No Internet service can guarantee absolute security.",
      "Account data is retained while an account remains active. Confirmed transaction, fraud-prevention, security, and audit records may be retained after deletion where required by law or a documented operational obligation; retained records are access-restricted and removed under the approved schedule.",
    ],
  },
  {
    id: "account-deletion",
    heading: "Your choices and account deletion",
    items: [
      "Access or correct profile information through the app where the feature is available.",
      "Withdraw optional notification or diagnostics consent through device or app settings.",
      "Delete an accessible account from Profile > Settings > Delete Account in the mobile app.",
      "If the app is inaccessible, use the public account-deletion page to start a privacy-safe support request.",
    ],
  },
  {
    heading: "Children, changes, and contact",
    paragraphs: [
      `${clubName} is not directed to children under 13. If you believe a child has provided personal information contrary to this policy, contact support.`,
      `Policy or data-rights questions can be sent to ${supportEmail}. Material changes will be reflected by updating the date on this page.`,
    ],
  },
]; }

export function getTermsSections(clubName: string): LegalDocumentSection[] { return [
  {
    heading: `Using ${clubName}`,
    paragraphs: [
      "By using the website or mobile app, you agree to use the service lawfully, provide accurate information for protected transactions, and follow the published club, community, and product rules that apply to the journey you select.",
    ],
  },
  {
    heading: "Accounts and security",
    items: [
      "Keep account access and device credentials secure and report suspected unauthorized use promptly.",
      "Do not share passwords, one-time codes, payment credentials, or identity documents through public support channels.",
      "Guest or anonymous access may have limited recovery options until the supporter adds an approved recovery method.",
    ],
  },
  {
    heading: "Memberships, tickets, shop orders, and contributions",
    paragraphs: [
      "Availability, eligibility, price, fulfillment, refund, transfer, venue-entry, and cancellation terms shown before confirmation form part of the transaction. Physical goods, event tickets, memberships, and contributions remain subject to club operations and applicable mandatory law.",
    ],
  },
  {
    heading: "Community content and conduct",
    items: [
      "Do not post unlawful, abusive, deceptive, discriminatory, infringing, or privacy-invasive content.",
      "Use reporting and blocking controls where available. Moderators may restrict or remove content and accounts to protect supporters and the service.",
      "Do not attempt to bypass security, club scope, rate limits, moderation, or transaction controls.",
    ],
  },
  {
    heading: "Predictions and rewards",
    paragraphs: [
      "Predictions, points, badges, and Fan Engagement Tokens are entertainment and supporter-engagement features. Unless a separately published promotion expressly states otherwise, they have no cash value, are not transferable, and are not a wager, deposit, or financial product.",
    ],
  },
  {
    heading: "Availability, changes, and responsibility",
    paragraphs: [
      "Features may be interrupted for maintenance, security, connectivity or provider availability. We may change or retire features while preserving confirmed obligations and providing notices required by applicable law.",
      "Nothing in these terms excludes rights or responsibilities that cannot lawfully be excluded. Support questions can be sent to support@ikanisa.com.",
    ],
  },
  {
    heading: "Suspension and account closure",
    paragraphs: [
      "Access may be restricted for material rule violations, fraud, security threats, legal requirements, or misuse. Supporters may delete their account using the mobile-app flow or the public deletion-request route, subject to the retention terms described in the Privacy Policy.",
    ],
  },
]; }

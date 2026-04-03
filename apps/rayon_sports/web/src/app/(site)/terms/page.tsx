import { buildPageMetadata } from "@/lib/metadata";
import { SectionHeading } from "@/components/section-heading";

export const metadata = buildPageMetadata({
  title: "Terms and conditions",
  description:
    "Terms for tickets, memberships, shop orders, and supporter activity across the Rayon Sports website and portal.",
  path: "/terms",
});

export default function TermsPage() {
  return (
    <div className="page-shell section-grid py-12">
      <SectionHeading
        eyebrow="Terms"
        title="One supporter platform across web and portal."
      />
      <div className="glass-panel rounded-[30px] p-6 text-sm leading-7 text-slate-300">
        <p>
          Ticketing, shop orders, memberships, and contribution records created
          through the website are part of the same Rayon Sports supporter
          platform used by the mobile app. Availability, pricing, and supporter
          eligibility remain subject to club policy and live operational status.
        </p>
      </div>
    </div>
  );
}

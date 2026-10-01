import Link from "next/link";
import { getClubProfile } from "@/lib/data/public";
import { getFanAppDestinations } from "@/lib/config";
import { buildPageMetadata } from "@/lib/metadata";

export async function generateMetadata() {
  const club = await getClubProfile();
  return buildPageMetadata({ club, title: `${club.shortName} supporter app`,
    description: `Supporter app availability and member access for ${club.shortName}.`, path: "/app" });
}

export default async function SupporterAppPage() {
  const club = await getClubProfile();
  const destinations = getFanAppDestinations(club.clubSlug);
  const links = [
    ["ios", "Open iOS app listing"],
    ["android", "Open Android app listing"],
    ["web", "Open supporter app"],
  ] as const;
  return (
    <section className="circles-surface">
      <div className="page-shell section-grid pb-20">
        <header className="circles-hero">
          <p className="circles-eyebrow">{club.shortName}</p>
          <h1>Supporter app</h1>
          <p className="circles-description">Choose an available app destination for {club.shortName}, or continue to your member area on this website.</p>
        </header>
        <section className="circles-content" aria-label={`${club.shortName} app availability`}>
          {links.map(([platform, label]) => destinations[platform] ? (
            <p key={platform}><a className="membership-action circles-action circles-action-primary" href={destinations[platform]}>{label}</a></p>
          ) : (
            <p key={platform}>{platform === "ios" ? "iOS" : platform === "android" ? "Android" : "Supporter web app"}: no release link is available yet.</p>
          ))}
          <Link className="membership-action circles-action circles-action-secondary" href="/membership">Open member area</Link>
        </section>
      </div>
    </section>
  );
}

import { getClubProfile } from "@/lib/data/public/club";
import { teamCrestUrl, teamInitials } from "@/lib/team-identity";

/** Legacy logo URL resolves to the active club's published artwork. */
export async function GET() {
  const club = await getClubProfile();
  const crest = teamCrestUrl(club.clubName);
  if (!crest) {
    const initials = teamInitials(club.clubName).replace(/[^A-Z0-9]/g, "").slice(0, 4);
    const color = /^#[0-9a-f]{6}$/i.test(club.primaryColorHex)
      ? club.primaryColorHex : "#144B8B";
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128" role="img" aria-label="${initials} initials mark"><rect width="128" height="128" rx="24" fill="${color}"/><text x="64" y="73" text-anchor="middle" fill="#061A36" font-family="Arial,sans-serif" font-size="38" font-weight="800">${initials}</text></svg>`;
    return new Response(svg, { headers: {
      "Content-Type": "image/svg+xml",
      "Cache-Control": "public, max-age=3600",
      Vary: "Host, X-Forwarded-Host",
      "X-Content-Type-Options": "nosniff",
    } });
  }
  return new Response(null, {
    status: 307,
    headers: {
      Location: crest,
      "Cache-Control": "public, max-age=3600",
      Vary: "Host, X-Forwarded-Host",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

import { getClubProfile } from "@/lib/data/public/club";
import { buildClubThemeStyle } from "@/lib/club-theme";

export async function GET() {
  const club = await getClubProfile();
  const escape = (value: string) => value.replace(/[&<>"']/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;",
  })[character]!);
  const label = escape(club.shortName);
  const primary = buildClubThemeStyle(club)["--club-primary"];
  const initials = escape(club.shortName.slice(0, 2).toUpperCase());
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512" role="img" aria-label="${label} brand mark"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${primary}"/><stop offset="1" stop-color="#100820"/></linearGradient></defs><rect width="512" height="512" rx="132" fill="url(#g)"/><circle cx="256" cy="256" r="206" fill="none" stroke="rgba(255,255,255,.24)" stroke-width="14"/><text x="50%" y="53%" dominant-baseline="middle" text-anchor="middle" font-family="Inter,Arial,sans-serif" font-size="148" font-weight="900" fill="#FAF8F5">${initials}</text></svg>`;

  return new Response(svg, {
    headers: {
      "Content-Type": "image/svg+xml",
      "Cache-Control": "public, max-age=3600",
      "Vary": "Host, X-Forwarded-Host",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

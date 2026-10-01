import { getClubProfile } from "@/lib/data/public/club";

export async function GET() {
  const club = await getClubProfile();
  const escape = (value: string) => value.replace(/[&<>"']/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&apos;",
  })[character]!);
  const label = escape(club.shortName);
  const primary = "#1326FD";
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="900" viewBox="0 0 1600 900" role="img" aria-label="${label} generated brand surface"><defs><radialGradient id="a" cx="28%" cy="18%" r="72%"><stop offset="0" stop-color="${primary}"/><stop offset=".48" stop-color="#161618"/><stop offset="1" stop-color="#000000"/></radialGradient><linearGradient id="b" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="rgba(244,244,244,.18)"/><stop offset="1" stop-color="rgba(244,244,244,0)"/></linearGradient></defs><rect width="1600" height="900" fill="url(#a)"/><path d="M0 630C260 520 420 560 640 650C880 748 1110 760 1600 560V900H0Z" fill="rgba(0,0,0,.62)"/><circle cx="1240" cy="250" r="210" fill="url(#b)"/><circle cx="1280" cy="244" r="146" fill="none" stroke="rgba(244,244,244,.16)" stroke-width="18"/><text x="9%" y="77%" font-family="Inter,Arial,sans-serif" font-size="74" font-weight="500" fill="#F4F4F4" opacity=".92">${label}</text></svg>`;

  return new Response(svg, {
    headers: {
      "Content-Type": "image/svg+xml",
      "Cache-Control": "public, max-age=3600",
      "Vary": "Host, X-Forwarded-Host",
      "X-Content-Type-Options": "nosniff",
    },
  });
}

import { rayonClub } from "@/lib/config";

export function GET() {
  const initials = rayonClub.shortName.slice(0, 2).toUpperCase();
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512" role="img" aria-label="${rayonClub.shortName} brand mark"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${rayonClub.primaryColorHex}"/><stop offset="1" stop-color="#100820"/></linearGradient></defs><rect width="512" height="512" rx="132" fill="url(#g)"/><circle cx="256" cy="256" r="206" fill="none" stroke="rgba(255,255,255,.24)" stroke-width="14"/><text x="50%" y="53%" dominant-baseline="middle" text-anchor="middle" font-family="Inter,Arial,sans-serif" font-size="148" font-weight="900" fill="#FAF8F5">${initials}</text></svg>`;

  return new Response(svg, {
    headers: {
      "Content-Type": "image/svg+xml",
      "Cache-Control": "public, max-age=3600",
    },
  });
}

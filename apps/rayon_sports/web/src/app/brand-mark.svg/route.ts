import { getClubProfile } from "@/lib/data/public/club";
import { teamCrestUrl } from "@/lib/team-identity";

/** Legacy logo URL resolves to the active club's published artwork. */
export async function GET() {
  const club = await getClubProfile();
  const crest = teamCrestUrl(club.clubName);
  if (!crest) return new Response(null, { status: 404 });
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

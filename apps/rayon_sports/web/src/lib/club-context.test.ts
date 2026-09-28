import { teamCrestUrl } from "./team-identity";
import { getActiveClubReference } from "./club-context";
import { getClubProfile } from "./data/public/club";
import { GET as getBrandMark } from "@/app/brand-mark.svg/route";
import { GET as getBrandSurface } from "@/app/brand-surface.svg/route";

const context = vi.hoisted(() => ({ host: "gikundiro.com", client: null as unknown }));
vi.mock("next/headers", () => ({ headers: async () => new Headers({ host: context.host }) }));
vi.mock("@/lib/supabase/admin", () => ({ getReadOnlySupabase: () => context.client }));

describe("retained club website identity", () => {
  beforeEach(() => { context.client = null; });

  it.each([
    ["vitalo.example.test", 44, "Vital'O FC", "BI", "BIF"],
    ["rayon-sports.example.test", 24, "Rayon Sports FC", "RW", "RWF"],
    ["nkana.example.test", 26, "Nkana FC", "ZM", "ZMW"],
    ["as-vita.example.test", 6, "AS Vita Club", "CD", "CDF"],
    ["costa-do-sol.example.test", 1001, "CD Costa do Sol", "MZ", "MZN"],
  ])("keeps %s identity while the public backend is unavailable", async (host, id, name, country, currency) => {
    context.host = String(host);
    expect(await getActiveClubReference()).toMatchObject({ numericId: id, name });
    expect(await getClubProfile()).toMatchObject({ id, clubName: name, countryCode: country, currencyCode: currency });
    if (id !== 24) expect((await getClubProfile()).xUrl ?? "").not.toContain("rayon");
    const crestResponse = await getBrandMark();
    if (id === 1001) {
      expect(crestResponse.status).toBe(200);
      expect(crestResponse.headers.get("content-type")).toContain("image/svg+xml");
      expect(await crestResponse.text()).toContain("CDS");
    } else {
      expect(crestResponse.status).toBe(307);
      expect(crestResponse.headers.get("location")).toBe(teamCrestUrl(String(name)));
    }
    for (const handler of [getBrandSurface]) {
      const response = await handler();
      const svg = new DOMParser().parseFromString(await response.text(), "image/svg+xml");
      expect(svg.querySelector("parsererror")).toBeNull();
      expect(svg.documentElement.getAttribute("aria-label")).toContain((await getClubProfile()).shortName);
      expect(response.headers.get("vary")).toContain("X-Forwarded-Host");
    }
  });

  it("does not turn a shared opponent record into a supported website", async () => {
    context.host = "retired-opponent.example.test";
    const query = { select: vi.fn().mockReturnThis(), eq: vi.fn().mockReturnThis(),
      maybeSingle: async () => ({ data: { id: 999, club_slug: "retired_opponent", club_name: "Shared opponent" } }) };
    context.client = { from: () => query };
    expect((await getActiveClubReference()).numericId).toBe(24);
    expect(query.eq.mock.calls.some((args) => args[1] === "retired_opponent")).toBe(false);
  });

  it("uses published club contact and media fields while retaining the short brand label", async () => {
    context.host = "gikundiro.com";
    const query = {
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      maybeSingle: async () => ({
        data: {
          id: 24,
          club_name: "Rayon Sports FC",
          nickname_brand_identity: "Gikundiro",
          official_contact: "Published supporter desk",
          facebook_url: "https://facebook.com/published-rayon",
          x_twitter_url: "https://x.com/published-rayon",
          instagram_url: "https://instagram.com/published-rayon",
          tiktok_url: "https://tiktok.com/@published-rayon",
          official_logo_url: "https://assets.supabase.co/approved-crest.png",
        },
      }),
    };
    context.client = { from: () => query };

    const club = await getClubProfile();
    expect(query.select).toHaveBeenCalledWith(expect.stringContaining("official_contact,"));
    expect(query.select).toHaveBeenCalledWith(expect.stringContaining("official_logo_url,"));
    expect(club).toMatchObject({
      clubName: "Rayon Sports FC",
      shortName: "Rayon Sports",
      nickname: "Gikundiro",
      officialContact: "Published supporter desk",
      facebookUrl: "https://facebook.com/published-rayon",
      xUrl: "https://x.com/published-rayon",
      instagramUrl: "https://instagram.com/published-rayon",
      tiktokUrl: "https://tiktok.com/@published-rayon",
      officialLogoUrl: "https://assets.supabase.co/approved-crest.png",
    });
  });
});

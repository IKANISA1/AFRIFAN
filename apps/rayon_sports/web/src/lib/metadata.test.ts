import {
  buildPageMetadata,
  buildSiteJsonLd,
  buildNewsArticleJsonLd,
  getClubWebsiteIdentity,
  renderJsonLdScriptContent,
} from "@/lib/metadata";
import { getSupportedClubProfile } from "@/lib/content";
import { siteConfig } from "@/lib/config";
import type { NewsArticle } from "@/lib/types";

describe("metadata", () => {
  for (const id of [44, 24, 26, 6]) {
    it(`keeps club ${id} identity in titles and structured data`, () => {
      const club = getSupportedClubProfile(id)!;
      const identity = getClubWebsiteIdentity(club);
      const metadata = buildPageMetadata({ club, title: "Support", description: "Help with your club account", path: "/support" });
      expect(metadata.title).toEqual({ absolute: `Support | ${identity.name}` });
      expect(metadata.openGraph).toMatchObject({ siteName: identity.name });
      const structured = buildSiteJsonLd(club);
      expect(structured["@graph"][1].name).toBe(club.clubName);
      if (id !== 24) {
        expect(JSON.stringify([metadata, structured])).not.toMatch(/Gikundiro|Rayon|gikundiro\.com/);
        expect(metadata.alternates?.canonical).toBeUndefined();
        expect(metadata.robots).toEqual({ index: false, follow: false });
      }
    });
  }

  it("uses a configured club domain without borrowing the default club origin", () => {
    const before = siteConfig.clubHostMap;
    try {
      siteConfig.clubHostMap = { "nkana.example.test": "nkana", "evil.example/path": "as_vita", "attacker@example.test": "vitalo" };
      const club = getSupportedClubProfile(26)!;
      const result = buildPageMetadata({ club, title: "Privacy", description: "Privacy", path: "/privacy" });
      expect(result.alternates?.canonical).toBe("https://nkana.example.test/privacy");
      expect(getClubWebsiteIdentity(getSupportedClubProfile(6)!).url).toBeUndefined();
      expect(getClubWebsiteIdentity(getSupportedClubProfile(44)!).url).toBeUndefined();
    } finally { siteConfig.clubHostMap = before; }
  });

  it("escapes script-breaking characters in JSON-LD output", () => {
    const article = {
      id: "story-1",
      title: '</script><script>alert("owned")</script>',
      excerpt: "Match recap",
      content: "Body copy",
      category: "News",
      author: "Editorial",
      coverImageUrl: null,
      publishedAt: "2026-04-10T10:00:00.000Z",
    } satisfies NewsArticle;

    const payload = renderJsonLdScriptContent(buildNewsArticleJsonLd(article));

    expect(payload).toContain("\\u003C/script\\u003E");
    expect(payload).not.toContain("</script>");
    expect(payload).not.toContain("<script>");
  });
});

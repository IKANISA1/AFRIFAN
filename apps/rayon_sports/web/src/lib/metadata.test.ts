import {
  buildNewsArticleJsonLd,
  renderJsonLdScriptContent,
} from "@/lib/metadata";
import type { NewsArticle } from "@/lib/types";

describe("metadata", () => {
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

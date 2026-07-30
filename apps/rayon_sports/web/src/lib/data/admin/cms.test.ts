import { describe, expect, it } from "vitest";
import { normalizeAdminArticles } from "./cms";

const validArticle = {
  id: "article-1",
  clubId: 24,
  title: "Competition update",
  subtitle: "Confirmed club announcement",
  excerpt: "A bounded public summary.",
  body: "This is the confirmed article body for the controlled CMS queue.",
  category: "Club news",
  imageUrl: "https://cdn.example.com/article.webp",
  isPublished: true,
  isFeatured: false,
  sortOrder: 2,
  publishedAt: "2026-07-29T12:00:00.000Z",
  createdAt: "2026-07-20T12:00:00.000Z",
  updatedAt: "2026-07-29T12:00:00.000Z",
  authorEmail: "private@example.com",
  accessToken: "private-token",
};

describe("admin CMS response normalization", () => {
  it("keeps only bounded article fields and drops private extras", () => {
    const [result] = normalizeAdminArticles([validArticle]);

    expect(result).toEqual({
      id: "article-1",
      clubId: 24,
      title: "Competition update",
      subtitle: "Confirmed club announcement",
      excerpt: "A bounded public summary.",
      body: "This is the confirmed article body for the controlled CMS queue.",
      category: "Club news",
      imageUrl: "https://cdn.example.com/article.webp",
      isPublished: true,
      isFeatured: false,
      sortOrder: 2,
      publishedAt: "2026-07-29T12:00:00.000Z",
      createdAt: "2026-07-20T12:00:00.000Z",
      updatedAt: "2026-07-29T12:00:00.000Z",
    });
    expect(JSON.stringify(result)).not.toContain("authorEmail");
    expect(JSON.stringify(result)).not.toContain("private-token");
  });

  it("rejects invalid required fields, dates, flags, and malformed rows", () => {
    expect(
      normalizeAdminArticles([
        { ...validArticle, id: "" },
        { ...validArticle, id: "long-body", body: "x".repeat(12_001) },
        { ...validArticle, id: "bad-date", updatedAt: "not-a-date" },
        { ...validArticle, id: "bad-flag", isPublished: "yes" },
        null,
      ]),
    ).toEqual([]);
  });

  it("caps the collection and removes unsafe media", () => {
    const unsafeScheme = ["java", "script:alert(1)"].join("");
    const safeLocalMedia = "/admin/cms/article-cover";
    const articles = Array.from({ length: 510 }, (_, index) => ({
      ...validArticle,
      id: `article-${index + 1}`,
      imageUrl: index === 0 ? unsafeScheme : safeLocalMedia,
    }));
    const normalized = normalizeAdminArticles(articles);

    expect(normalized).toHaveLength(500);
    expect(normalized[0]?.imageUrl).toBeNull();
    expect(normalized[1]?.imageUrl).toBe(safeLocalMedia);
  });

  it("fails closed for a non-array response", () => {
    expect(normalizeAdminArticles({ data: [validArticle] })).toEqual([]);
  });
});

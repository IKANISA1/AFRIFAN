describe("public data", () => {
  const previousEnv = { ...process.env };

  beforeEach(() => {
    vi.resetModules();
    delete process.env.NEXT_PUBLIC_SUPABASE_URL;
    delete process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    delete process.env.SUPABASE_URL;
    delete process.env.SUPABASE_ANON_KEY;
    delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  });

  afterEach(() => {
    Object.assign(process.env, previousEnv);
  });

  it(
    "falls back to embedded club content when Supabase config is missing",
    async () => {
      const { getHomePageData } = await import("@/lib/data/public");

      const data = await getHomePageData();

      expect(data.club.clubSlug).toBe("rayon_sports_rw");
      expect(data.club.clubName).toBe("Rayon Sports FC");
      expect(data.matches.length).toBeGreaterThan(0);
      expect(data.news.length).toBeGreaterThan(0);
      expect(data.products.length).toBeGreaterThan(0);
      expect(data.featuredMatch).not.toBeNull();
    },
    15000,
  );

  it("returns fallback detail records by identifier", async () => {
    const {
      getMatchById,
      getNewsArticleById,
      getProductById,
    } = await import("@/lib/data/public");
    const { fallbackClubProfile } = await import("@/lib/content");

    const match = await getMatchById("featured-home-fixture");
    const article = await getNewsArticleById("membership-gikundiro-Group");
    const product = await getProductById("replica-home-26");

    expect(match?.homeTeam).toBe(fallbackClubProfile.shortName);
    expect(article?.content).toContain("digital-first");
    expect(product?.name).toContain("Replica Jersey");
  });
});

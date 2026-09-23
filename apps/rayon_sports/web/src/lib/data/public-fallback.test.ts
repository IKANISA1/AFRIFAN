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

  it("uses only bootstrap club defaults when Supabase config is missing", async () => {
    const { getHomePageData } = await import("@/lib/data/public");

    const data = await getHomePageData();

    expect(data.club.clubSlug).toBe("rayon_sports_rw");
    expect(data.club.clubName).toBe("Rayon Sports FC");
    expect(data.matches).toEqual([]);
    expect(data.news).toEqual([]);
    expect(data.products).toEqual([]);
    expect(data.featuredMatch).toBeNull();
  }, 15000);

  it("does not synthesize detail records when Supabase config is missing", async () => {
    const { getMatchById, getNewsArticleById, getProductById } =
      await import("@/lib/data/public");

    const match = await getMatchById("featured-home-fixture");
    const article = await getNewsArticleById("membership-gikundiro-Group");
    const product = await getProductById("replica-home-26");

    expect(match).toBeNull();
    expect(article).toBeNull();
    expect(product).toBeNull();
  });
});

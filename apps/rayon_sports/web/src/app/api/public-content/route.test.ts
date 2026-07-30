const mocks = vi.hoisted(() => ({
  getCmsContentStrict: vi.fn(),
  getContributionGroupsStrict: vi.fn(),
  getFanClubsStrict: vi.fn(),
  getMatchByIdStrict: vi.fn(),
  getMatchesStrict: vi.fn(),
  getMembershipPackagesStrict: vi.fn(),
  getNewsArticleByIdStrict: vi.fn(),
  getNewsArticlesStrict: vi.fn(),
  getProductByIdStrict: vi.fn(),
  getProductsStrict: vi.fn(),
  getSquadStrict: vi.fn(),
  getStandingsStrict: vi.fn(),
  getApprovedPublicVenuesStrict: vi.fn(),
  getFanEngagementTokensStrict: vi.fn(),
  getFanEngagementLeaderboardStrict: vi.fn(),
}));

vi.mock("@/lib/data/public", () => ({
  getCmsContentStrict: mocks.getCmsContentStrict,
  getContributionGroupsStrict: mocks.getContributionGroupsStrict,
  getFanClubsStrict: mocks.getFanClubsStrict,
  getMatchByIdStrict: mocks.getMatchByIdStrict,
  getMatchesStrict: mocks.getMatchesStrict,
  getMembershipPackagesStrict: mocks.getMembershipPackagesStrict,
  getNewsArticleByIdStrict: mocks.getNewsArticleByIdStrict,
  getNewsArticlesStrict: mocks.getNewsArticlesStrict,
  getProductByIdStrict: mocks.getProductByIdStrict,
  getProductsStrict: mocks.getProductsStrict,
  getSquadStrict: mocks.getSquadStrict,
  getStandingsStrict: mocks.getStandingsStrict,
}));

vi.mock("@/lib/data/venue", () => ({
  getApprovedPublicVenuesStrict: mocks.getApprovedPublicVenuesStrict,
}));

vi.mock("@/lib/data/public/gamification", () => ({
  getFanEngagementTokensStrict: mocks.getFanEngagementTokensStrict,
  getFanEngagementLeaderboardStrict: mocks.getFanEngagementLeaderboardStrict,
}));

import { GET } from "./route";

const request = () =>
  new Request("https://africlub.invalid/api/public-content?resource=history");
const homeRequest = () =>
  new Request("https://africlub.invalid/api/public-content?resource=home");
const newsRequest = () =>
  new Request("https://africlub.invalid/api/public-content?resource=news");
const fixturesRequest = () =>
  new Request("https://africlub.invalid/api/public-content?resource=fixtures");
const circlesRequest = () =>
  new Request("https://africlub.invalid/api/public-content?resource=circles");
const fanClubsRequest = () =>
  new Request("https://africlub.invalid/api/public-content?resource=fan-clubs");
const membershipRequest = () =>
  new Request(
    "https://africlub.invalid/api/public-content?resource=membership",
  );
const shopRequest = () =>
  new Request("https://africlub.invalid/api/public-content?resource=shop");
const shopProductRequest = (productId = "home-shirt") =>
  new Request(
    `https://africlub.invalid/api/public-content?resource=shop-product&productId=${encodeURIComponent(productId)}`,
  );
const standingsRequest = () =>
  new Request("https://africlub.invalid/api/public-content?resource=standings");
const squadRequest = () =>
  new Request("https://africlub.invalid/api/public-content?resource=squad");
const venuesRequest = () =>
  new Request("https://africlub.invalid/api/public-content?resource=venues");
const supportersRequest = () =>
  new Request(
    "https://africlub.invalid/api/public-content?resource=supporters",
  );
const fixtureDetailRequest = (matchId = "opening-day") =>
  new Request(
    `https://africlub.invalid/api/public-content?resource=fixture-detail&matchId=${encodeURIComponent(matchId)}`,
  );
const newsArticleRequest = (articleId = "opening-day") =>
  new Request(
    `https://africlub.invalid/api/public-content?resource=news-article&articleId=${encodeURIComponent(articleId)}`,
  );

describe("GET /api/public-content", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useRealTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("rejects unsupported resources before reading CMS data", async () => {
    const response = await GET(
      new Request(
        "https://africlub.invalid/api/public-content?resource=private",
      ),
    );

    expect(response.status).toBe(400);
    expect(mocks.getCmsContentStrict).not.toHaveBeenCalled();
    await expect(response.json()).resolves.toMatchObject({
      code: "PUBLIC_CONTENT_INVALID_RESOURCE",
      change_confirmed: false,
    });
  });

  it("returns one bounded home snapshot without private or transactional data", async () => {
    mocks.getMatchesStrict.mockResolvedValue([
      {
        id: "match-1",
        homeTeam: "Rayon Sports",
        awayTeam: "APR FC",
        competition: "Premier League",
        venue: "Amahoro Stadium",
        matchDate: "2026-08-02T15:00:00.000Z",
        kickoffTime: "17:00",
        matchStatus: "scheduled",
        privateLineup: "not-public",
      },
    ]);
    mocks.getNewsArticlesStrict.mockResolvedValue([
      {
        id: "news-1",
        title: "Confirmed club update",
        excerpt: "A confirmed public update.",
        category: "Club",
        coverImageUrl: "/brand-surface.svg",
        publishedAt: "2026-07-29T12:00:00.000Z",
        author: "Club Media",
        internalDraft: "not-public",
      },
    ]);
    mocks.getProductsStrict.mockResolvedValue([
      {
        id: "product-1",
        name: "Home shirt",
        subtitle: "Official home shirt.",
        description: "Confirmed public product description.",
        category: "Jerseys",
        collection: "2026",
        price: 35_000,
        imageUrl: "/brand-surface.svg",
        sizes: ["S", "M"],
        isActive: true,
        stockQuantity: 90,
        paymentReference: "private-payment",
      },
    ]);
    mocks.getMembershipPackagesStrict.mockResolvedValue([
      {
        id: "tier-1",
        tier: "bronze",
        title: "Bronze",
        description: "Confirmed public membership tier.",
        sortOrder: 0,
        annualPrice: 10_000,
        perks: ["Ticket priority"],
        supporterId: "private-user",
      },
    ]);

    const response = await GET(homeRequest());
    const body = await response.json();
    expect(response.status).toBe(200);
    expect(body).toMatchObject({
      code: "PUBLIC_HOME_READY",
      matches: [{ id: "match-1", homeTeam: "Rayon Sports" }],
      news: [{ id: "news-1", title: "Confirmed club update" }],
      products: [{ id: "product-1", isAvailable: true }],
      memberships: [{ id: "tier-1", title: "Bronze" }],
    });
    expect(body.matches).toHaveLength(1);
    expect(body.news).toHaveLength(1);
    expect(body.products).toHaveLength(1);
    expect(body.memberships).toHaveLength(1);
    const text = JSON.stringify(body);
    expect(text).not.toContain("privateLineup");
    expect(text).not.toContain("internalDraft");
    expect(text).not.toContain("stockQuantity");
    expect(text).not.toContain("private-payment");
    expect(text).not.toContain("private-user");
  });

  it("returns controlled empty and sanitized home failure states", async () => {
    mocks.getMatchesStrict.mockResolvedValueOnce([]);
    mocks.getNewsArticlesStrict.mockResolvedValueOnce([]);
    mocks.getProductsStrict.mockResolvedValueOnce([]);
    mocks.getMembershipPackagesStrict.mockResolvedValueOnce([]);
    const emptyResponse = await GET(homeRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_HOME_EMPTY",
      matches: [],
      news: [],
      products: [],
      memberships: [],
    });

    mocks.getMatchesStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    mocks.getNewsArticlesStrict.mockResolvedValueOnce([]);
    mocks.getProductsStrict.mockResolvedValueOnce([]);
    mocks.getMembershipPackagesStrict.mockResolvedValueOnce([]);
    const failedResponse = await GET(homeRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_HOME_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a bounded fixture-detail projection without internal live data", async () => {
    mocks.getMatchByIdStrict.mockResolvedValue({
      id: "opening-day",
      homeTeam: "Rayon Sports",
      awayTeam: "APR FC",
      competition: "Premier League",
      venue: "Amahoro Stadium",
      matchDate: "2026-08-02T15:00:00.000Z",
      kickoffTime: "17:00",
      isOnSale: true,
      generalPrice: 5_000,
      vipPrice: 20_000,
      matchStatus: "upcoming",
      homeScore: 0,
      awayScore: 0,
      liveMinute: null,
      matchSummary: "Opening fixture.",
      liveEvents: [{ label: "private" }],
      liveStats: { private: true },
      imageUrl: "https://private.invalid/image.jpg",
    });

    const response = await GET(fixtureDetailRequest());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.code).toBe("PUBLIC_FIXTURE_DETAIL_READY");
    expect(body.item).toEqual({
      id: "opening-day",
      homeTeam: "Rayon Sports",
      awayTeam: "APR FC",
      competition: "Premier League",
      venue: "Amahoro Stadium",
      matchDate: "2026-08-02T15:00:00.000Z",
      kickoffTime: "17:00",
      isOnSale: true,
      generalPrice: 5_000,
      vipPrice: 20_000,
      matchStatus: "upcoming",
      homeScore: 0,
      awayScore: 0,
      liveMinute: null,
      matchSummary: "Opening fixture.",
    });
    expect(JSON.stringify(body)).not.toContain("private");
  });

  it("returns empty, rejects invalid ids, and sanitizes fixture-detail failures", async () => {
    mocks.getMatchByIdStrict.mockResolvedValueOnce(null);
    const emptyResponse = await GET(fixtureDetailRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_FIXTURE_DETAIL_EMPTY",
      item: null,
    });

    const invalidResponse = await GET(fixtureDetailRequest(""));
    expect(invalidResponse.status).toBe(400);
    expect(mocks.getMatchByIdStrict).toHaveBeenCalledTimes(1);

    mocks.getMatchByIdStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    const failedResponse = await GET(fixtureDetailRequest("provider-failure"));
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_FIXTURE_DETAIL_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns the controlled empty history state", async () => {
    mocks.getCmsContentStrict.mockResolvedValue([]);

    const response = await GET(request());

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=300");
    await expect(response.json()).resolves.toEqual({
      code: "PUBLIC_HISTORY_EMPTY",
      items: [],
    });
  });

  it("returns a bounded public projection without CMS-only fields", async () => {
    mocks.getCmsContentStrict.mockResolvedValue(
      Array.from({ length: 26 }, (_, index) => ({
        id: `history-${index}`,
        title: `Chapter ${index}`,
        body: `Body ${index}`,
        rationale: "server-only editorial rationale",
        ctaAction: "private-action",
      })),
    );

    const response = await GET(request());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(body.code).toBe("PUBLIC_HISTORY_READY");
    expect(body.items).toHaveLength(24);
    expect(body.items[0]).toEqual({
      id: "history-0",
      title: "Chapter 0",
      body: "Body 0",
    });
    expect(JSON.stringify(body)).not.toContain("rationale");
    expect(JSON.stringify(body)).not.toContain("private-action");
  });

  it("does not confirm readiness while CMS content is unsettled", async () => {
    let release: ((items: unknown[]) => void) | undefined;
    mocks.getCmsContentStrict.mockReturnValue(
      new Promise((resolve) => {
        release = resolve;
      }),
    );

    let settled = false;
    const responsePromise = GET(request()).finally(() => {
      settled = true;
    });
    await Promise.resolve();

    expect(settled).toBe(false);
    release?.([]);
    expect((await responsePromise).status).toBe(200);
  });

  it("returns a stable permission-denied response", async () => {
    mocks.getCmsContentStrict.mockRejectedValue({
      status: 403,
      message: "policy=private_history",
    });

    const response = await GET(request());
    const body = await response.json();

    expect(response.status).toBe(403);
    expect(body.code).toBe("PUBLIC_HISTORY_ACCESS_DENIED");
    expect(JSON.stringify(body)).not.toContain("private_history");
  });

  it("returns a stable conflict response", async () => {
    mocks.getCmsContentStrict.mockRejectedValue({
      status: 409,
      message: "revision=private-history-version",
    });

    const response = await GET(request());
    const body = await response.json();

    expect(response.status).toBe(409);
    expect(body).toMatchObject({
      code: "PUBLIC_HISTORY_CONFLICT",
      change_confirmed: false,
    });
    expect(JSON.stringify(body)).not.toContain("private-history-version");
  });

  it("sanitizes provider failures", async () => {
    mocks.getCmsContentStrict.mockRejectedValue(
      new Error("database.internal password=secret"),
    );

    const response = await GET(request());
    const text = JSON.stringify(await response.json());

    expect(response.status).toBe(502);
    expect(text).toContain("PUBLIC_HISTORY_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a deterministic eight-second timeout", async () => {
    vi.useFakeTimers();
    mocks.getCmsContentStrict.mockReturnValue(new Promise(() => {}));

    const responsePromise = GET(request());
    const expectation = expect(responsePromise).resolves.toMatchObject({
      status: 504,
    });
    await vi.advanceTimersByTimeAsync(8_000);
    await expectation;
  });

  it("returns a bounded public news projection without article content", async () => {
    mocks.getNewsArticlesStrict.mockResolvedValue(
      Array.from({ length: 26 }, (_, index) => ({
        id: `story-${index}`,
        title: `Story ${index}`,
        excerpt: `Excerpt ${index}`,
        content: "Private long-form draft field",
        category: "Club",
        coverImageUrl: "/brand-surface.svg",
        publishedAt: "2026-07-28T10:00:00.000Z",
        author: "Gikundiro Media",
      })),
    );

    const response = await GET(newsRequest());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=120");
    expect(body.code).toBe("PUBLIC_NEWS_READY");
    expect(body.items).toHaveLength(24);
    expect(body.items[0]).toEqual({
      id: "story-0",
      title: "Story 0",
      excerpt: "Excerpt 0",
      category: "Club",
      coverImageUrl: "/brand-surface.svg",
      publishedAt: "2026-07-28T10:00:00.000Z",
      author: "Gikundiro Media",
    });
    expect(JSON.stringify(body)).not.toContain("Private long-form");
  });

  it("returns the controlled empty news state", async () => {
    mocks.getNewsArticlesStrict.mockResolvedValue([]);

    const response = await GET(newsRequest());

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      code: "PUBLIC_NEWS_EMPTY",
      items: [],
    });
  });

  it("sanitizes news provider failures with a resource-specific code", async () => {
    mocks.getNewsArticlesStrict.mockRejectedValue(
      new Error("database.internal password=secret"),
    );

    const response = await GET(newsRequest());
    const text = JSON.stringify(await response.json());

    expect(response.status).toBe(502);
    expect(text).toContain("PUBLIC_NEWS_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a bounded published article projection", async () => {
    mocks.getNewsArticleByIdStrict.mockResolvedValue({
      id: "opening-day",
      title: "Opening day",
      excerpt: "The season begins.",
      content: "A".repeat(12_100),
      category: "Club",
      coverImageUrl: "/brand-surface.svg",
      publishedAt: "2026-07-28T10:00:00.000Z",
      author: "Gikundiro Media",
      editorialNotes: "server only",
    });

    const response = await GET(newsArticleRequest());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=120");
    expect(body.code).toBe("PUBLIC_NEWS_ARTICLE_READY");
    expect(body.item.content).toHaveLength(12_000);
    expect(body.item).not.toHaveProperty("editorialNotes");
    expect(mocks.getNewsArticleByIdStrict).toHaveBeenCalledWith("opening-day");
  });

  it("returns a controlled empty article result when no published story matches", async () => {
    mocks.getNewsArticleByIdStrict.mockResolvedValue(null);

    const response = await GET(newsArticleRequest("missing"));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      code: "PUBLIC_NEWS_ARTICLE_EMPTY",
      item: null,
    });
  });

  it("rejects missing or oversized article identifiers before data access", async () => {
    const missing = await GET(
      new Request(
        "https://africlub.invalid/api/public-content?resource=news-article",
      ),
    );
    const oversized = await GET(newsArticleRequest("x".repeat(201)));

    expect(missing.status).toBe(400);
    expect(oversized.status).toBe(400);
    expect(mocks.getNewsArticleByIdStrict).not.toHaveBeenCalled();
    await expect(missing.json()).resolves.toMatchObject({
      code: "PUBLIC_NEWS_ARTICLE_INVALID_ID",
      change_confirmed: false,
    });
  });

  it("sanitizes article provider failures with a resource-specific code", async () => {
    mocks.getNewsArticleByIdStrict.mockRejectedValue(
      new Error("database.internal password=secret"),
    );

    const response = await GET(newsArticleRequest());
    const text = JSON.stringify(await response.json());

    expect(response.status).toBe(502);
    expect(text).toContain("PUBLIC_NEWS_ARTICLE_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a bounded public fixture projection without live-event internals", async () => {
    mocks.getMatchesStrict.mockResolvedValue(
      Array.from({ length: 22 }, (_, index) => ({
        id: `match-${index}`,
        homeTeam: "Rayon Sports",
        awayTeam: `Opponent ${index}`,
        competition: "Premier League",
        venue: "Kigali Pelé Stadium",
        matchDate: "2026-08-01T15:00:00.000Z",
        kickoffTime: "17:00",
        isOnSale: true,
        generalPrice: 5000,
        vipPrice: 15000,
        imageUrl: "/brand-surface.svg",
        matchStatus: "scheduled",
        homeScore: 0,
        awayScore: 0,
        liveMinute: null,
        matchSummary: "A confirmed fixture.",
        liveEvents: [{ minute: "12", event: "Private feed event" }],
        liveStats: { possession: "51" },
        isFeatured: false,
      })),
    );

    const response = await GET(fixturesRequest());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=60");
    expect(body.code).toBe("PUBLIC_FIXTURES_READY");
    expect(body.items).toHaveLength(20);
    expect(body.items[0]).toEqual({
      id: "match-0",
      homeTeam: "Rayon Sports",
      awayTeam: "Opponent 0",
      competition: "Premier League",
      venue: "Kigali Pelé Stadium",
      matchDate: "2026-08-01T15:00:00.000Z",
      kickoffTime: "17:00",
      isOnSale: true,
      generalPrice: 5000,
      matchStatus: "scheduled",
      homeScore: 0,
      awayScore: 0,
      liveMinute: null,
      matchSummary: "A confirmed fixture.",
    });
    expect(JSON.stringify(body)).not.toContain("Private feed event");
    expect(JSON.stringify(body)).not.toContain("liveStats");
    expect(JSON.stringify(body)).not.toContain("vipPrice");
  });

  it("returns the controlled empty fixture state", async () => {
    mocks.getMatchesStrict.mockResolvedValue([]);

    const response = await GET(fixturesRequest());

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      code: "PUBLIC_FIXTURES_EMPTY",
      items: [],
    });
  });

  it("sanitizes fixture provider failures with a resource-specific code", async () => {
    mocks.getMatchesStrict.mockRejectedValue(
      new Error("database.internal password=secret"),
    );

    const response = await GET(fixturesRequest());
    const text = JSON.stringify(await response.json());

    expect(response.status).toBe(502);
    expect(text).toContain("PUBLIC_FIXTURES_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns bounded circles without contributor, payment, or internal fields", async () => {
    mocks.getContributionGroupsStrict.mockResolvedValue(
      Array.from({ length: 10 }, (_, index) => ({
        id: `circle-${index}`,
        name: `Campaign ${index}`,
        description: `Confirmed campaign ${index}.`,
        groupType: index % 2 === 0 ? "project" : "community",
        targetAmount: 1_000_000 + index,
        currentTotal: 500_000 + index,
        currency: "rwf",
        memberCount: 100 + index,
        contributorIds: ["private-user"],
        paymentReference: "private-payment",
      })),
    );
    mocks.getFanClubsStrict.mockResolvedValue(
      Array.from({ length: 14 }, (_, index) => ({
        id: `chapter-${index}`,
        name: `Chapter ${index}`,
        region: "Kigali",
        description: `Official chapter ${index}.`,
        memberCount: 50 + index,
        eventCount: 5 + index,
        bannerImageUrl: "https://private.invalid/image.jpg",
        moderatorContact: "+250700000000",
      })),
    );

    const response = await GET(circlesRequest());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=120");
    expect(body.code).toBe("PUBLIC_CIRCLES_READY");
    expect(body.groups).toHaveLength(8);
    expect(body.chapters).toHaveLength(12);
    expect(body.groups[0]).toEqual({
      id: "circle-0",
      name: "Campaign 0",
      description: "Confirmed campaign 0.",
      groupType: "project",
      targetAmount: 1_000_000,
      currentTotal: 500_000,
      currency: "RWF",
      memberCount: 100,
    });
    expect(body.chapters[0]).toEqual({
      id: "chapter-0",
      name: "Chapter 0",
      region: "Kigali",
      description: "Official chapter 0.",
      memberCount: 50,
      eventCount: 5,
    });
    const serialized = JSON.stringify(body);
    expect(serialized).not.toContain("private-user");
    expect(serialized).not.toContain("private-payment");
    expect(serialized).not.toContain("moderatorContact");
    expect(serialized).not.toContain("private.invalid");
  });

  it("returns controlled empty and sanitized circles failure states", async () => {
    mocks.getContributionGroupsStrict.mockResolvedValueOnce([]);
    mocks.getFanClubsStrict.mockResolvedValueOnce([]);
    const emptyResponse = await GET(circlesRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_CIRCLES_EMPTY",
      groups: [],
      chapters: [],
    });

    mocks.getContributionGroupsStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    mocks.getFanClubsStrict.mockResolvedValueOnce([]);
    const failedResponse = await GET(circlesRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_CIRCLES_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("uses the same bounded public projection with fan-club-specific response codes", async () => {
    mocks.getContributionGroupsStrict.mockResolvedValueOnce([]);
    mocks.getFanClubsStrict.mockResolvedValueOnce([]);
    const emptyResponse = await GET(fanClubsRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_FAN_CLUBS_EMPTY",
      groups: [],
      chapters: [],
    });

    mocks.getContributionGroupsStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    mocks.getFanClubsStrict.mockResolvedValueOnce([]);
    const failedResponse = await GET(fanClubsRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_FAN_CLUBS_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a bounded membership catalog without private application or payment fields", async () => {
    mocks.getMembershipPackagesStrict.mockResolvedValue(
      Array.from({ length: 8 }, (_, index) => ({
        id: `tier-${index}`,
        tier: [
          "bronze",
          "silver",
          "gold",
          "imena",
          "inyamibwa",
          "ingenzi-imanzi",
        ][index % 6],
        title: `Tier ${index}`,
        description: `Confirmed public tier ${index}.`,
        sortOrder: index,
        annualPrice: 10_000 + index,
        perks: ["Ticket priority", "Club updates"],
        applicantId: "private-user",
        paymentReference: "private-payment",
      })),
    );

    const response = await GET(membershipRequest());
    const body = await response.json();
    expect(response.status).toBe(200);
    expect(body.code).toBe("PUBLIC_MEMBERSHIP_READY");
    expect(body.packages).toHaveLength(6);
    expect(body.packages[0]).toEqual({
      id: "tier-0",
      tier: "bronze",
      title: "Tier 0",
      description: "Confirmed public tier 0.",
      sortOrder: 0,
      annualPrice: 10_000,
      perks: ["Ticket priority", "Club updates"],
    });
    expect(JSON.stringify(body)).not.toContain("private-user");
    expect(JSON.stringify(body)).not.toContain("private-payment");
  });

  it("returns controlled empty and sanitized membership failure states", async () => {
    mocks.getMembershipPackagesStrict.mockResolvedValueOnce([]);
    const emptyResponse = await GET(membershipRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_MEMBERSHIP_EMPTY",
      packages: [],
    });

    mocks.getMembershipPackagesStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    const failedResponse = await GET(membershipRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_MEMBERSHIP_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a bounded public shop projection without inventory, order, or payment internals", async () => {
    mocks.getProductsStrict.mockResolvedValue(
      Array.from({ length: 14 }, (_, index) => ({
        id: `product-${index}`,
        name: `Product ${index}`,
        subtitle: "Official supporter merchandise.",
        description: "Confirmed public product description.",
        category: index % 2 === 0 ? "Jerseys" : "Accessories",
        collection: "Home",
        price: 25_000 + index,
        imageUrl: "/brand-surface.svg",
        sizes: ["S", "M", "M", "L"],
        isActive: index !== 1,
        stockQuantity: 99,
        supplierCost: 1,
        paymentReference: "private-payment",
        customerId: "private-user",
      })),
    );

    const response = await GET(shopRequest());
    const body = await response.json();
    expect(response.status).toBe(200);
    expect(body.code).toBe("PUBLIC_SHOP_READY");
    expect(body.items).toHaveLength(12);
    expect(body.items[0]).toEqual({
      id: "product-0",
      name: "Product 0",
      subtitle: "Official supporter merchandise.",
      description: "Confirmed public product description.",
      category: "Jerseys",
      collection: "Home",
      price: 25_000,
      imageUrl: "/brand-surface.svg",
      sizes: ["S", "M", "L"],
      isAvailable: true,
    });
    expect(body.items[1].isAvailable).toBe(false);
    const text = JSON.stringify(body);
    expect(text).not.toContain("stockQuantity");
    expect(text).not.toContain("supplierCost");
    expect(text).not.toContain("private-payment");
    expect(text).not.toContain("private-user");
  });

  it("rejects invalid shop products and returns controlled empty and failure states", async () => {
    mocks.getProductsStrict.mockResolvedValueOnce([
      {
        id: "",
        name: "",
        subtitle: "",
        description: "",
        category: "",
        collection: null,
        price: -1,
        imageUrl: "https://tracker.invalid/private.jpg",
        sizes: [],
        isActive: true,
      },
    ]);
    const emptyResponse = await GET(shopRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_SHOP_EMPTY",
      items: [],
    });

    mocks.getProductsStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    const failedResponse = await GET(shopRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_SHOP_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("validates product identifiers and returns one bounded public product", async () => {
    const invalidResponse = await GET(shopProductRequest(""));
    expect(invalidResponse.status).toBe(400);
    await expect(invalidResponse.json()).resolves.toMatchObject({
      code: "PUBLIC_SHOP_PRODUCT_INVALID_ID",
      change_confirmed: false,
    });

    mocks.getProductByIdStrict.mockResolvedValue({
      id: "home-shirt",
      name: "Home shirt",
      subtitle: "Official home shirt.",
      description: "Confirmed public product description.",
      category: "Jerseys",
      collection: "2026",
      price: 35_000,
      imageUrl: "/brand-surface.svg",
      sizes: ["S", "M", "L"],
      isActive: true,
      stockQuantity: 40,
      orderId: "private-order",
    });
    const response = await GET(shopProductRequest());
    const body = await response.json();
    expect(response.status).toBe(200);
    expect(body).toEqual({
      code: "PUBLIC_SHOP_PRODUCT_READY",
      item: {
        id: "home-shirt",
        name: "Home shirt",
        subtitle: "Official home shirt.",
        description: "Confirmed public product description.",
        category: "Jerseys",
        collection: "2026",
        price: 35_000,
        imageUrl: "/brand-surface.svg",
        sizes: ["S", "M", "L"],
        isAvailable: true,
      },
    });
    expect(JSON.stringify(body)).not.toContain("private-order");
  });

  it("returns controlled product-detail empty and sanitized failure states", async () => {
    mocks.getProductByIdStrict.mockResolvedValueOnce(null);
    const emptyResponse = await GET(shopProductRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_SHOP_PRODUCT_EMPTY",
      item: null,
    });

    mocks.getProductByIdStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    const failedResponse = await GET(shopProductRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_SHOP_PRODUCT_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a bounded sanitized standings projection", async () => {
    mocks.getStandingsStrict.mockResolvedValue(
      Array.from({ length: 26 }, (_, index) => ({
        position: index + 1,
        club: `Club ${index + 1}`,
        played: 18,
        goalDifference: 12 - index,
        points: 40 - index,
        form: ["w", "D", "invalid", "L", "W", "D"],
        highlight: index === 2,
        privateNotes: "server-only",
      })),
    );

    const response = await GET(standingsRequest());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=120");
    expect(body.code).toBe("PUBLIC_STANDINGS_READY");
    expect(body.items).toHaveLength(24);
    expect(body.items[2]).toEqual({
      position: 3,
      club: "Club 3",
      played: 18,
      goalDifference: 10,
      points: 38,
      form: ["W", "D", "L", "W", "D"],
      highlight: true,
    });
    expect(JSON.stringify(body)).not.toContain("server-only");
  });

  it("returns controlled empty and sanitized standings failure states", async () => {
    mocks.getStandingsStrict.mockResolvedValueOnce([]);
    const emptyResponse = await GET(standingsRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_STANDINGS_EMPTY",
      items: [],
    });

    mocks.getStandingsStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    const failedResponse = await GET(standingsRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_STANDINGS_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a bounded sanitized public squad projection", async () => {
    mocks.getSquadStrict.mockResolvedValue(
      Array.from({ length: 42 }, (_, index) => ({
        id: `player-${index}`,
        name: `Player ${index}`,
        role: index % 2 === 0 ? "Midfielder" : "Defender",
        number: index,
        nationality: "Rwanda",
        bio: `Confirmed player profile ${index}.`,
        imageUrl: "/brand-surface.svg",
        privateNotes: "server-only",
      })),
    );

    const response = await GET(squadRequest());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=300");
    expect(body.code).toBe("PUBLIC_SQUAD_READY");
    expect(body.items).toHaveLength(40);
    expect(body.items[0]).toEqual({
      id: "player-0",
      name: "Player 0",
      role: "Midfielder",
      number: 0,
      nationality: "Rwanda",
      bio: "Confirmed player profile 0.",
      imageUrl: "/brand-surface.svg",
    });
    expect(JSON.stringify(body)).not.toContain("server-only");
  });

  it("returns controlled empty and sanitized squad failure states", async () => {
    mocks.getSquadStrict.mockResolvedValueOnce([]);
    const emptyResponse = await GET(squadRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_SQUAD_EMPTY",
      items: [],
    });

    mocks.getSquadStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    const failedResponse = await GET(squadRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_SQUAD_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a bounded public venue projection without operational fields", async () => {
    mocks.getApprovedPublicVenuesStrict.mockResolvedValue(
      Array.from({ length: 14 }, (_, index) => ({
        id: `venue-${index}`,
        displayName: `Matchday venue ${index}`,
        slug: `matchday-venue-${index}`,
        city: "Kigali",
        summary: `Approved public venue profile ${index}.`,
        status: "approved",
        liveOrders: 42,
        preciseCoordinates: "-1.0,30.0",
      })),
    );

    const response = await GET(venuesRequest());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=300");
    expect(body.code).toBe("PUBLIC_VENUES_READY");
    expect(body.items).toHaveLength(12);
    expect(body.items[0]).toEqual({
      id: "venue-0",
      displayName: "Matchday venue 0",
      slug: "matchday-venue-0",
      city: "Kigali",
      summary: "Approved public venue profile 0.",
    });
    expect(JSON.stringify(body)).not.toContain("liveOrders");
    expect(JSON.stringify(body)).not.toContain("preciseCoordinates");
  });

  it("returns controlled empty and sanitized venue failure states", async () => {
    mocks.getApprovedPublicVenuesStrict.mockResolvedValueOnce([]);
    const emptyResponse = await GET(venuesRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_VENUES_EMPTY",
      items: [],
    });

    mocks.getApprovedPublicVenuesStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    const failedResponse = await GET(venuesRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_VENUES_FAILED");
    expect(text).not.toContain("database.internal");
  });

  it("returns a bounded supporters projection without identity or internal fields", async () => {
    mocks.getFanEngagementTokensStrict.mockResolvedValue(
      Array.from({ length: 10 }, (_, index) => ({
        id: `reward-${index}`,
        clubId: 99,
        code: `REWARD_${index}`,
        templateScope: "club_specific",
        category: index % 2 === 0 ? "Matchday" : "Community",
        itemName: `Reward ${index}`,
        fetValue: 100 + index,
        triggerCondition: "Confirmed club action",
        activationTiming: "After verification",
        description: `Confirmed public reward ${index}.`,
        badgeName: "Internal badge",
        implementationNotes: "server-only",
        sortOrder: index,
        isActive: true,
      })),
    );
    mocks.getFanEngagementLeaderboardStrict.mockResolvedValue(
      Array.from({ length: 12 }, (_, index) => ({
        rank: index + 1,
        userId: `private-user-${index}`,
        supporterAlias: `fan_${index + 1}`,
        displayName: `Private Name ${index}`,
        totalFet: 1_000 - index,
        tier: "imena",
        isCurrentUser: index === 0,
      })),
    );

    const response = await GET(supportersRequest());
    const body = await response.json();

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toContain("s-maxage=120");
    expect(body.code).toBe("PUBLIC_SUPPORTERS_READY");
    expect(body.catalog).toHaveLength(8);
    expect(body.leaderboard).toHaveLength(10);
    expect(body.catalog[0]).toEqual({
      id: "reward-0",
      code: "REWARD_0",
      category: "Matchday",
      itemName: "Reward 0",
      fetValue: 100,
      triggerCondition: "Confirmed club action",
      activationTiming: "After verification",
      description: "Confirmed public reward 0.",
    });
    expect(body.leaderboard[0]).toEqual({
      rank: 1,
      supporterAlias: "fan_1",
      totalFet: 1_000,
      tier: "imena",
    });
    expect(JSON.stringify(body)).not.toContain("private-user");
    expect(JSON.stringify(body)).not.toContain("Private Name");
    expect(JSON.stringify(body)).not.toContain("server-only");
    expect(JSON.stringify(body)).not.toContain("isCurrentUser");
  });

  it("returns controlled empty and sanitized supporters failure states", async () => {
    mocks.getFanEngagementTokensStrict.mockResolvedValueOnce([]);
    mocks.getFanEngagementLeaderboardStrict.mockResolvedValueOnce([]);
    const emptyResponse = await GET(supportersRequest());
    await expect(emptyResponse.json()).resolves.toEqual({
      code: "PUBLIC_SUPPORTERS_EMPTY",
      catalog: [],
      leaderboard: [],
    });

    mocks.getFanEngagementTokensStrict.mockRejectedValueOnce(
      new Error("database.internal password=secret"),
    );
    mocks.getFanEngagementLeaderboardStrict.mockResolvedValueOnce([]);
    const failedResponse = await GET(supportersRequest());
    const text = JSON.stringify(await failedResponse.json());
    expect(failedResponse.status).toBe(502);
    expect(text).toContain("PUBLIC_SUPPORTERS_FAILED");
    expect(text).not.toContain("database.internal");
  });
});

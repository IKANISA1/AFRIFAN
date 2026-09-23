const mocks = vi.hoisted(() => ({
  getPlatformConfig: vi.fn(),
  getFeatureAccess: vi.fn(),
  normalizeFeatureKey: vi.fn((value: string) => value),
}));

vi.mock("@/lib/feature-config", () => mocks);

import { getFeaturePageGuard } from "./feature-page-guard";

describe("getFeaturePageGuard controlled route evidence", () => {
  const originalPreview = process.env.AFRICLUB_ALLOW_HTTP_PREVIEW;
  const originalEvidence = process.env.AFRICLUB_CONTROLLED_ROUTE_EVIDENCE;

  afterEach(() => {
    if (originalPreview === undefined) {
      delete process.env.AFRICLUB_ALLOW_HTTP_PREVIEW;
    } else {
      process.env.AFRICLUB_ALLOW_HTTP_PREVIEW = originalPreview;
    }
    if (originalEvidence === undefined) {
      delete process.env.AFRICLUB_CONTROLLED_ROUTE_EVIDENCE;
    } else {
      process.env.AFRICLUB_CONTROLLED_ROUTE_EVIDENCE = originalEvidence;
    }
    vi.clearAllMocks();
  });

  it("allows evidence only when both explicit local-preview keys are enabled", async () => {
    process.env.AFRICLUB_ALLOW_HTTP_PREVIEW = "1";
    process.env.AFRICLUB_CONTROLLED_ROUTE_EVIDENCE = "1";

    await expect(
      getFeaturePageGuard("news", {
        allowControlledRouteEvidence: true,
      }),
    ).resolves.toBeNull();
    expect(mocks.getPlatformConfig).not.toHaveBeenCalled();
  });

  it.each([
    ["0", "1"],
    ["1", "0"],
    [undefined, "1"],
    ["1", undefined],
  ])(
    "preserves the runtime feature guard when preview=%s and evidence=%s",
    async (preview, evidence) => {
      if (preview === undefined) {
        delete process.env.AFRICLUB_ALLOW_HTTP_PREVIEW;
      } else {
        process.env.AFRICLUB_ALLOW_HTTP_PREVIEW = preview;
      }
      if (evidence === undefined) {
        delete process.env.AFRICLUB_CONTROLLED_ROUTE_EVIDENCE;
      } else {
        process.env.AFRICLUB_CONTROLLED_ROUTE_EVIDENCE = evidence;
      }
      mocks.getPlatformConfig.mockResolvedValue({});
      mocks.getFeatureAccess.mockReturnValue({
        isVisible: true,
        isAvailable: true,
      });

      await expect(
        getFeaturePageGuard("news", {
          allowControlledRouteEvidence: true,
        }),
      ).resolves.toBeNull();
      expect(mocks.getPlatformConfig).toHaveBeenCalledTimes(1);
      expect(mocks.getFeatureAccess).toHaveBeenCalledTimes(1);
    },
  );
});

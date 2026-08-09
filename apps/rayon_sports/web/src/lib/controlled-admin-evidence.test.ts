import { isControlledAdminEvidenceAllowed } from "./controlled-admin-evidence";

describe("controlled admin evidence boundary", () => {
  it.each(["127.0.0.1:3200", "localhost:3200", "[::1]:3200"])(
    "allows the explicit two-key evidence mode only on loopback host %s",
    (host) => {
      expect(
        isControlledAdminEvidenceAllowed({
          previewEnabled: "1",
          adminEvidenceEnabled: "1",
          evidenceRequested: true,
          host,
        }),
      ).toBe(true);
    },
  );

  it.each([
    ["0", "1", true, "127.0.0.1:3200"],
    ["1", "0", true, "127.0.0.1:3200"],
    [undefined, "1", true, "127.0.0.1:3200"],
    ["1", undefined, true, "127.0.0.1:3200"],
    ["1", "1", false, "127.0.0.1:3200"],
    ["1", "1", undefined, "127.0.0.1:3200"],
    ["1", "1", true, "admin.gikundiro.com"],
    ["1", "1", true, "127.0.0.1:3200, admin.gikundiro.com"],
    ["1", "1", true, null],
  ])(
    "fails closed for preview=%s evidence=%s requested=%s host=%s",
    (previewEnabled, adminEvidenceEnabled, evidenceRequested, host) => {
      expect(
        isControlledAdminEvidenceAllowed({
          previewEnabled,
          adminEvidenceEnabled,
          evidenceRequested,
          host,
        }),
      ).toBe(false);
    },
  );
});

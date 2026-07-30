import { isControlledAdminEvidenceAllowed } from "./controlled-admin-evidence";

describe("controlled admin evidence boundary", () => {
  it.each(["127.0.0.1:3200", "localhost:3200", "[::1]:3200"])(
    "allows the explicit two-key evidence mode only on loopback host %s",
    (host) => {
      expect(
        isControlledAdminEvidenceAllowed({
          previewEnabled: "1",
          adminEvidenceEnabled: "1",
          host,
        }),
      ).toBe(true);
    },
  );

  it.each([
    ["0", "1", "127.0.0.1:3200"],
    ["1", "0", "127.0.0.1:3200"],
    [undefined, "1", "127.0.0.1:3200"],
    ["1", undefined, "127.0.0.1:3200"],
    ["1", "1", "admin.gikundiro.com"],
    ["1", "1", "127.0.0.1:3200, admin.gikundiro.com"],
    ["1", "1", null],
  ])(
    "fails closed for preview=%s evidence=%s host=%s",
    (previewEnabled, adminEvidenceEnabled, host) => {
      expect(
        isControlledAdminEvidenceAllowed({
          previewEnabled,
          adminEvidenceEnabled,
          host,
        }),
      ).toBe(false);
    },
  );
});

import { isControlledVenueEvidenceAllowed } from "./controlled-venue-evidence";

describe("controlled venue evidence boundary", () => {
  it.each(["127.0.0.1:3200", "localhost:3200", "[::1]:3200"])(
    "allows explicit two-key evidence mode only on loopback host %s",
    (host) => {
      expect(
        isControlledVenueEvidenceAllowed({
          previewEnabled: "1",
          venueEvidenceEnabled: "1",
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
    ["1", "1", "venue.gikundiro.com"],
    ["1", "1", "127.0.0.1:3200, venue.gikundiro.com"],
    ["1", "1", null],
  ])(
    "fails closed for preview=%s evidence=%s host=%s",
    (previewEnabled, venueEvidenceEnabled, host) => {
      expect(
        isControlledVenueEvidenceAllowed({
          previewEnabled,
          venueEvidenceEnabled,
          host,
        }),
      ).toBe(false);
    },
  );
});

import {
  buildUssdTelHref,
  confirmedContributionTotal,
  normalizeRwandaPhone,
} from "./member-portal";

describe("member portal safeguards", () => {
  it.each([
    ["0788 123 456", "+250788123456"],
    ["788123456", "+250788123456"],
    ["+250 788 123 456", "+250788123456"],
  ])("normalizes supported Rwanda phone entry %s", (input, expected) => {
    expect(normalizeRwandaPhone(input)).toBe(expected);
  });

  it("rejects incomplete and non-Rwanda phone values", () => {
    expect(normalizeRwandaPhone("0788 123")).toBeNull();
    expect(normalizeRwandaPhone("+254 700 123 456")).toBeNull();
  });

  it("builds a dialer-safe tel URI only for bounded USSD routes", () => {
    expect(buildUssdTelHref("*182*8*1*123456*5000#")).toBe(
      "tel:*182*8*1*123456*5000%23",
    );
    expect(buildUssdTelHref("javascript:alert(1)")).toBeNull();
  });

  it("counts only independently confirmed contributions", () => {
    expect(
      confirmedContributionTotal([
        {
          id: "confirmed",
          initiative_id: "initiative",
          amount: 10_000,
          status: "confirmed",
          momo_reference: "GKD-1",
          created_at: "2026-08-23T00:00:00Z",
          confirmed_at: "2026-08-23T00:01:00Z",
        },
        {
          id: "pending",
          initiative_id: "initiative",
          amount: 25_000,
          status: "pending",
          momo_reference: "GKD-2",
          created_at: "2026-08-23T00:02:00Z",
          confirmed_at: null,
        },
      ]),
    ).toBe(10_000);
  });
});

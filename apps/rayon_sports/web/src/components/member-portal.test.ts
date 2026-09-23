import {
  buildUssdTelHref,
  parseContributionHistory,
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
    expect(buildUssdTelHref("182*8*1*123456*5000#")).toBeNull();
  });

  it("preserves an exact total beyond JavaScript number precision", () => {
    expect(parseContributionHistory({confirmed_total: "9007199254740993", entries: [], next_cursor: null}).confirmedTotal)
      .toBe(BigInt("9007199254740993"));
  });

  it.each([
    {confirmed_total: 1000, entries: [], next_cursor: null},
    {confirmed_total: "1000.50", entries: [], next_cursor: null},
    {confirmed_total: "1000", entries: [], next_cursor: {id: "invalid", created_at: "today"}},
    {confirmed_total: "1000", entries: [{amount: 1000}], next_cursor: null},
  ])("rejects incomplete or ambiguous history payloads", value => {
    expect(() => parseContributionHistory(value)).toThrow();
  });
});

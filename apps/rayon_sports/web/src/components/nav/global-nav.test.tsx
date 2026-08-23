import { fireEvent, render, screen } from "@testing-library/react";
import { getSiteChromeCopy } from "@/lib/site-copy";
import type { ClubProfile } from "@/lib/types";
import { GlobalNav } from "./global-nav";

vi.mock("next/navigation", () => ({
  usePathname: () => "/",
}));

const club: ClubProfile = {
  id: 1,
  clubName: "Rayon Sports FC",
  clubSlug: "rayon-sports",
  shortName: "Rayon Sports",
  nickname: "Gikundiro",
  countryCode: "RW",
  league: "Rwanda Premier League",
  region: "Kigali",
  currencyCode: "RWF",
  currencySymbol: "RWF",
  defaultLanguage: "en",
  supportedLanguages: ["en", "fr"],
  officialContact: "+250 700 000 000",
  officialLogoUrl: null,
  primaryColorHex: "#174dbb",
  secondaryColorHex: "#ffffff",
  accentColorHex: "#f3bf42",
  featureFlags: {},
};

describe("GlobalNav", () => {
  beforeEach(() => {
    Object.defineProperty(window, "matchMedia", {
      configurable: true,
      value: vi.fn().mockImplementation(() => ({
        matches: true,
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
      })),
    });
  });

  it("keeps primary routes available and opens the mobile drawer when runtime configuration is unavailable", () => {
    render(
      <GlobalNav
        club={club}
        copy={getSiteChromeCopy("en")}
        features={[]}
        navigationItems={[]}
      />,
    );

    expect(screen.getAllByRole("link", { name: "Fixtures" }).length).toBeGreaterThan(0);

    const menu = screen.getByRole("button", { name: "Open menu" });
    fireEvent.click(menu);

    expect(menu).toHaveAttribute("aria-expanded", "true");
    expect(screen.getByRole("dialog", { name: "Navigation menu" })).toHaveAttribute(
      "aria-hidden",
      "false",
    );
    expect(screen.getAllByRole("link", { name: "Membership" }).length).toBeGreaterThan(0);
  });
});

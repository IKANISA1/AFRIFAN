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
  supportedLanguages: ["en"],
  officialContact: "+250 700 000 000",
  officialLogoUrl: null,
  primaryColorHex: "#174dbb",
  secondaryColorHex: "#ffffff",
  accentColorHex: "#f3bf42",
  featureFlags: {},
};

describe("GlobalNav", () => {
  beforeEach(() => {
    vi.stubGlobal("ResizeObserver", class {
      observe() {}
      disconnect() {}
    });
    Object.defineProperty(window, "matchMedia", {
      configurable: true,
      value: vi.fn().mockImplementation(() => ({
        matches: true,
        addEventListener: vi.fn(),
        removeEventListener: vi.fn(),
      })),
    });
  });

  afterEach(() => { vi.unstubAllGlobals(); vi.restoreAllMocks(); });

  it("keeps primary routes available and opens the mobile drawer when runtime configuration is unavailable", () => {
    render(
      <GlobalNav
        club={club}
        copy={getSiteChromeCopy("en")}
        features={[]}
        navigationItems={[]}
      />,
    );

    expect(screen.getAllByRole("link", { name: "Fixtures", hidden: true }).length).toBeGreaterThan(0);

    const menu = screen.getByRole("button", { name: "Open menu" });
    fireEvent.click(menu);

    expect(menu).toHaveAttribute("aria-expanded", "true");
    expect(screen.getByRole("dialog", { name: "Navigation menu" })).toHaveAttribute(
      "aria-hidden",
      "false",
    );
    expect(screen.getAllByRole("link", { name: "Membership" }).length).toBeGreaterThan(0);
    expect(screen.getByRole("link", { name: "Fan Portal" })).toHaveAttribute("href", "/membership");
  });

  it("offers a separate keyboard disclosure, reaches submenu links and restores focus on Escape", () => {
    vi.spyOn(HTMLElement.prototype, "clientWidth", "get").mockReturnValue(3000);
    const getStyle = window.getComputedStyle.bind(window);
    vi.spyOn(window, "getComputedStyle").mockImplementation(element => new Proxy(getStyle(element), { get(style, key) { if (["paddingLeft", "paddingRight", "columnGap"].includes(String(key))) return "0"; const value = Reflect.get(style, key, style); return typeof value === "function" ? value.bind(style) : value; } }));
    const items = [{nav_key: "live", label: "Match centre", href: "/fixtures", nav_group: "primary", surface: "both", feature_key: "live", sort_order: 0, metadata: {hasMega: true}}] as const;
    render(<GlobalNav club={club} copy={getSiteChromeCopy("en")} navigationItems={[...items]} />);
    const toggle = screen.getByRole("button", { name: "Open Match centre navigation" });
    toggle.focus(); fireEvent.click(toggle);
    expect(toggle).toHaveAttribute("aria-expanded", "true");
    expect(toggle).toHaveAttribute("aria-controls", "site-mega-menu");
    const result = screen.getByRole("link", { name: "Results" });
    expect(result).toHaveAttribute("href", "/results");
    result.focus(); fireEvent.keyDown(result, {key: "Escape"});
    expect(toggle).toHaveFocus(); expect(toggle).toHaveAttribute("aria-expanded", "false");
    fireEvent.click(toggle); expect(toggle).toHaveAttribute("aria-expanded", "true");
    fireEvent.click(toggle); expect(toggle).toHaveAttribute("aria-expanded", "false");
  });
});

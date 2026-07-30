import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import {
  ContactSurface,
  normalizeContactExternalHref,
  normalizeContactSupportBlocks,
} from "./contact-surface";

const defaultProps = {
  eyebrow: "Contact",
  title: "Stay close to the club",
  description: "Use the right channel for every supporter task.",
  fanAppHref: "/fan-app",
  openFanAppLabel: "Open fan app",
  membershipSupportLabel: "Membership support",
  officialContact: "support@example.test",
  languages: ["en", "rw"],
  digitalSupportTitle: "Digital support",
  digitalSupportDescription: "Authenticated tasks stay in the fan app.",
  supportBlocks: ["Membership help", "General questions"],
  socialChannelsLabel: "Social channels",
  newsroomLabel: "Club newsroom",
  socialLinks: [
    { label: "Safe", href: "https://example.test/club" },
    { label: "Unsafe", href: "javascript:alert(1)" },
  ],
};

describe("ContactSurface", () => {
  it("renders one heading, fallback support content, and only safe actions", () => {
    const { container } = render(<ContactSurface {...defaultProps} />);

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "Stay close to the club",
      }),
    ).toBeVisible();
    expect(screen.getByText("Membership help")).toBeVisible();
    expect(screen.getByRole("link", { name: /safe/i })).toHaveAttribute(
      "href",
      "https://example.test/club",
    );
    expect(screen.queryByRole("link", { name: /unsafe/i })).toBeNull();
    expect(container.querySelector("[data-contact-surface]")).toBeTruthy();
  });

  it("accepts only HTTP or HTTPS social destinations", () => {
    expect(normalizeContactExternalHref("https://example.test")).toBe(
      "https://example.test/",
    );
    expect(normalizeContactExternalHref("http://example.test/path")).toBe(
      "http://example.test/path",
    );
    expect(normalizeContactExternalHref("javascript:alert(1)")).toBeNull();
    expect(normalizeContactExternalHref("/relative")).toBeNull();
    expect(normalizeContactExternalHref(null)).toBeNull();
  });

  it("removes blank and duplicate support messages", () => {
    expect(
      normalizeContactSupportBlocks([
        " Membership help ",
        "",
        "Membership help",
        "General questions",
      ]),
    ).toEqual(["Membership help", "General questions"]);
  });
});

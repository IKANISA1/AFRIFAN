import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { isSafeSupportHref, SupportSurface } from "./support-surface";

describe("SupportSurface", () => {
  it("renders ordered guidance and only governed support actions", () => {
    render(
      <SupportSurface
        kind="account-deletion"
        eyebrow="Privacy request"
        title="Delete your Gikundiro account"
        description="Use the authenticated path when possible."
        steps={[{ heading: "Open settings", body: "Choose Delete Account." }]}
        notice="Never send a password or one-time code."
        actions={[
          {
            href: "mailto:support@ikanisa.com?subject=Deletion",
            label: "Email support",
            primary: true,
          },
          { href: "javascript:alert(1)", label: "Unsafe" },
        ]}
      />,
    );

    expect(
      screen.getByRole("heading", {
        level: 1,
        name: "Delete your Gikundiro account",
      }),
    ).toBeVisible();
    expect(screen.getByText("Open settings")).toBeVisible();
    expect(screen.getByRole("link", { name: "Email support" })).toHaveAttribute(
      "href",
      "mailto:support@ikanisa.com?subject=Deletion",
    );
    expect(screen.queryByRole("link", { name: "Unsafe" })).toBeNull();
  });

  it("allows only controlled internal, canonical, or support-email destinations", () => {
    expect(isSafeSupportHref("/privacy")).toBe(true);
    expect(isSafeSupportHref("https://gikundiro.com/support")).toBe(true);
    expect(isSafeSupportHref("mailto:support@ikanisa.com?subject=Help")).toBe(true);
    expect(isSafeSupportHref("mailto:attacker@example.test")).toBe(false);
    expect(isSafeSupportHref("mailto:support@ikanisa.com.attacker.test")).toBe(
      false,
    );
    expect(isSafeSupportHref("//attacker.example.test/support")).toBe(false);
    expect(isSafeSupportHref("javascript:alert(1)")).toBe(false);
  });
});

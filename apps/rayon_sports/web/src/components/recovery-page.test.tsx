import fs from "node:fs";
import path from "node:path";
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { RecoveryPage } from "./recovery-page";

describe("RecoveryPage", () => {
  it("exposes a labelled recovery landmark and reachable actions", () => {
    render(
      <RecoveryPage
        eyebrow="Offline mode"
        title="Cached pages stay available"
        description="Recent content remains available."
        primaryAction={{ href: "/", label: "Cached homepage" }}
        secondaryAction={{ href: "/fixtures", label: "Cached fixtures" }}
      />,
    );

    expect(screen.getByRole("main").querySelector("section")).toHaveAttribute(
      "aria-labelledby",
      "recovery-title",
    );
    expect(
      screen.getByRole("heading", { name: "Cached pages stay available" }),
    ).toBeVisible();
    expect(screen.getByRole("status")).toHaveTextContent("Offline mode");
    expect(
      screen.getByRole("link", { name: "Cached homepage" }),
    ).toHaveAttribute("href", "/");
    expect(
      screen.getByRole("link", { name: "Cached fixtures" }),
    ).toHaveAttribute("href", "/fixtures");
  });

  it("retains real light, focus, press, reduced-motion, and compact contracts", () => {
    const css = fs.readFileSync(
      path.join(process.cwd(), "src/ui-kit/theme.css"),
      "utf8",
    );

    expect(css).toContain("@media (prefers-color-scheme: light)");
    expect(css).toContain(".recovery-action:focus-visible");
    expect(css).toContain(".recovery-action:active");
    expect(css).toContain("@media (prefers-reduced-motion: reduce)");
    expect(css).toContain("@media (max-width: 420px)");
  });
});

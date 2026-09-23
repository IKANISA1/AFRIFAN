import fs from "node:fs";
import path from "node:path";
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { RecoveryPage } from "./recovery-page";
import SiteError from "@/app/(site)/error";
import NotFound from "@/app/not-found";
import SiteLoading from "@/app/(site)/loading";

describe("RecoveryPage", () => {
  it("retries the failed page without displaying internal error details", () => {
    const reset = vi.fn();
    render(<SiteError error={new Error("Internal service diagnostic")} reset={reset} />);
    fireEvent.click(screen.getByRole("button", { name: "Retry" }));
    expect(reset).toHaveBeenCalledOnce();
    expect(screen.queryByText("Internal service diagnostic")).not.toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Return home" })).toHaveAttribute("href", "/");
  });

  it("provides useful navigation when a page is missing", () => {
    render(<NotFound />);
    expect(screen.getByRole("main")).toContainElement(screen.getByRole("heading", { name: "Page not found" }));
    expect(screen.getByRole("link", { name: "Fixtures" })).toHaveAttribute("href", "/fixtures");
    expect(screen.getByRole("link", { name: "Return home" })).toHaveAttribute("href", "/");
  });

  it("announces a route that is still loading", () => {
    render(<SiteLoading />);
    expect(screen.getByRole("status")).toHaveAttribute("aria-busy", "true");
    expect(screen.getByRole("status")).toHaveTextContent("Loading page…");
  });

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

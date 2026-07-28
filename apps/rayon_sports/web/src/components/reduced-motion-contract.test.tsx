import fs from "node:fs";
import path from "node:path";
import { render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { CountUp } from "./count-up";
import { AdminDialogFrame } from "./admin/admin-dialog-frame";

function installMatchMedia(matches: boolean) {
  Object.defineProperty(window, "matchMedia", {
    configurable: true,
    value: vi.fn().mockImplementation((query: string) => ({
      matches,
      media: query,
      onchange: null,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
      addListener: vi.fn(),
      removeListener: vi.fn(),
      dispatchEvent: vi.fn(),
    })),
  });
}

describe("reduced-motion contract", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("renders count-up results immediately without scheduling decorative frames", async () => {
    installMatchMedia(true);
    const requestFrame = vi.spyOn(window, "requestAnimationFrame");

    render(<CountUp value={1250} formatter={(value) => `${value} FET`} />);

    await waitFor(() => {
      expect(screen.getByText("1250 FET")).toBeInTheDocument();
    });
    expect(requestFrame).not.toHaveBeenCalled();
    expect(screen.getByText("1250 FET").style.animation).toBe("");
  });

  it("removes CSS transition and stagger delays for reduced motion", () => {
    const css = fs.readFileSync(
      path.join(process.cwd(), "src/ui-kit/theme.css"),
      "utf8",
    );
    const reducedBlock = css.slice(
      css.indexOf("@media (prefers-reduced-motion: reduce)"),
      css.indexOf("body {"),
    );

    expect(reducedBlock).toContain("animation-delay: 0ms !important");
    expect(reducedBlock).toContain("transition-delay: 0ms !important");
    expect(reducedBlock).toContain("animation-iteration-count: 1 !important");
  });

  it("keeps admin drawer tasks available immediately", () => {
    installMatchMedia(true);

    render(
      <AdminDialogFrame
        open
        onClose={() => {}}
        title="Ticket actions"
        layout="drawer"
      >
        <button type="button">Resolve selected tickets</button>
      </AdminDialogFrame>,
    );

    expect(screen.getByRole("dialog", { name: "Ticket actions" })).toBeVisible();
    expect(
      screen.getByRole("button", { name: "Resolve selected tickets" }),
    ).toBeEnabled();
  });
});

import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { AdminStatusBadge } from "./admin-status-badge";

describe("AdminStatusBadge color-independent contract", () => {
  it.each([
    ["neutral", "Status"],
    ["accent", "Highlighted"],
    ["info", "Information"],
    ["success", "Success"],
    ["warning", "Warning"],
    ["danger", "Danger"],
  ] as const)("announces the %s tone independently of color", (tone, name) => {
    render(<AdminStatusBadge label="Payment pending" tone={tone} pulse />);

    const prefix = screen.getByText(`${name} status:`, { exact: true });
    const badge = prefix.parentElement!;
    expect(prefix).toHaveClass("sr-only");
    expect(badge).toHaveTextContent(`${name} status: Payment pending`);
    expect(badge).toHaveAttribute("data-status-tone", tone);
    expect(badge.querySelector(".admin-status-dot")).toHaveAttribute(
      "aria-hidden",
      "true",
    );
  });
});

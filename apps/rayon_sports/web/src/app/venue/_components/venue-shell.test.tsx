import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import type { VenueAccessResult } from "@/lib/data/venue-access";
import {
  VenueAccessBoundary,
  VenueDataError,
  VenueEmptyState,
} from "./venue-shell";
import { MenuItemForm } from "./venue-forms";

vi.mock("next/navigation", () => ({
  usePathname: () => "/venue",
}));

beforeEach(() => {
  Object.defineProperty(navigator, "onLine", {
    configurable: true,
    value: true,
  });
});

describe("VenueAccessBoundary", () => {
  it.each([
    ["not_configured", "Venue operations unavailable"],
    ["signed_out", "Secure sign-in required"],
    ["forbidden", "No active venue assignment"],
  ] as const)("renders the %s fail-closed state", (status, heading) => {
    render(
      <VenueAccessBoundary result={{ status }}>
        <p>private workflow</p>
      </VenueAccessBoundary>,
    );
    expect(screen.getByRole("alert")).toHaveTextContent(heading);
    expect(screen.queryByText("private workflow")).not.toBeInTheDocument();
  });

  it("shows a support-safe correlation id for authorization service errors", () => {
    render(
      <VenueAccessBoundary
        result={{ status: "service_error", correlationId: "venue-contract-123" }}
      >
        <p>private workflow</p>
      </VenueAccessBoundary>,
    );
    expect(screen.getByRole("alert")).toHaveTextContent("venue-contract-123");
    expect(screen.getByRole("link", { name: "Retry" })).toHaveAttribute(
      "href",
      "/venue",
    );
  });

  it("shows assigned venue scope and all seven operator destinations", () => {
    const result = {
      status: "ready",
      access: {
        userId: "user-1",
        clubId: 24,
        venueId: "venue-1",
        venueName: "Amahoro Hospitality",
        venueCity: "Kigali",
        role: "manager",
        canManageMenu: true,
        canOperateOrders: true,
        canLaunchPromotions: true,
      },
      client: {},
      user: {},
    } as unknown as VenueAccessResult;
    render(
      <VenueAccessBoundary result={result}>
        <p>private workflow</p>
      </VenueAccessBoundary>,
    );
    expect(screen.getByText("Amahoro Hospitality")).toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Venue operations" })).toBeInTheDocument();
    expect(screen.getAllByRole("link")).toHaveLength(7);
    expect(screen.getByRole("link", { name: "Today" })).toHaveAttribute(
      "aria-current",
      "page",
    );
    expect(screen.getByText("private workflow")).toBeInTheDocument();
  });

  it("retains confirmed content and disables venue mutations while offline", () => {
    Object.defineProperty(navigator, "onLine", {
      configurable: true,
      value: false,
    });
    const result = {
      status: "ready",
      access: {
        userId: "11111111-1111-4111-8111-111111111111",
        clubId: 24,
        venueId: "22222222-2222-4222-8222-222222222222",
        venueName: "Amahoro Hospitality",
        venueCity: "Kigali",
        role: "manager",
        canManageMenu: true,
        canOperateOrders: true,
        canLaunchPromotions: true,
      },
      client: {},
      user: {},
    } as unknown as VenueAccessResult;
    render(
      <VenueAccessBoundary result={result}>
        <p>confirmed venue data</p>
        <MenuItemForm />
      </VenueAccessBoundary>,
    );
    expect(screen.getByRole("status")).toHaveTextContent(
      "Confirmed venue information remains visible",
    );
    expect(screen.getByText("confirmed venue data")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Add drink" })).toBeDisabled();
  });
});

describe("venue workflow states", () => {
  it("distinguishes genuinely empty data from service failure", () => {
    const { rerender } = render(
      <VenueEmptyState title="No orders" body="The queue is genuinely empty." />,
    );
    expect(screen.queryByRole("alert")).not.toBeInTheDocument();
    rerender(<VenueDataError correlationId="venue-data-456" />);
    expect(screen.getByRole("alert")).toHaveTextContent("venue-data-456");
  });
});

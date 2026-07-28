import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import type { VenueAccessResult } from "@/lib/data/venue-access";
import {
  VenueAccessBoundary,
  VenueDataError,
  VenueEmptyState,
} from "./venue-shell";

describe("VenueAccessBoundary", () => {
  it.each([
    ["not_configured", "Venue service is not configured"],
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
    expect(screen.getByText("private workflow")).toBeInTheDocument();
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

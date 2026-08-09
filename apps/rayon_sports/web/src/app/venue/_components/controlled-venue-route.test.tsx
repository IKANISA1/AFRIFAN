import { fireEvent, render, screen } from "@testing-library/react";
import {
  ControlledVenueRoutePage,
  type ControlledVenueRoute,
} from "./controlled-venue-route";

const routes: Array<[ControlledVenueRoute, RegExp, RegExp]> = [
  ["overview", /today at the venue/i, /refresh venue summary/i],
  ["orders", /drinks orders/i, /refresh drinks orders/i],
  ["menu", /drinks menu/i, /refresh drinks menu/i],
  ["checkins", /check-ins/i, /refresh check-ins/i],
  ["promotions", /promotions/i, /refresh promotions/i],
  ["staff", /venue staff/i, /refresh venue staff/i],
  ["tv-code", /tv code status/i, /refresh tv code status/i],
];

describe("controlled venue route evidence", () => {
  it.each(routes)(
    "renders the %s route with route-specific confirmed data",
    (route, heading, action) => {
      render(<ControlledVenueRoutePage route={route} initialState="ready" />);
      expect(
        screen.getByRole("heading", { name: heading }),
      ).toBeInTheDocument();
      expect(screen.getByRole("button", { name: action })).toBeEnabled();
      expect(screen.getByText("Synthetic non-production")).toBeInTheDocument();
    },
  );

  it("clears operational records when permission is denied", () => {
    const { container } = render(
      <ControlledVenueRoutePage
        route="orders"
        initialState="permission_denied"
      />,
    );
    expect(screen.getByRole("alert")).toHaveTextContent("Venue access denied");
    expect(screen.queryByText("Order 7A3F")).not.toBeInTheDocument();
    expect(container.firstChild).toHaveAttribute(
      "data-venue-sensitive-data",
      "withheld",
    );
  });

  it("retains confirmed records and locks actions during synchronization", () => {
    const { container } = render(
      <ControlledVenueRoutePage route="checkins" initialState="syncing" />,
    );
    expect(screen.getByRole("status")).toHaveTextContent(
      "Refreshing venue operations",
    );
    expect(screen.getByText("18:42")).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: /refresh check-ins/i }),
    ).toBeDisabled();
    expect(container.firstChild).toHaveAttribute("data-venue-state", "syncing");
  });

  it("exposes real focus, pressed, and selected interaction states", () => {
    const { container } = render(
      <ControlledVenueRoutePage route="overview" initialState="ready" />,
    );
    const surface = container.firstChild;
    const refresh = screen.getByRole("button", {
      name: /refresh venue summary/i,
    });

    fireEvent.focus(refresh);
    expect(surface).toHaveAttribute("data-venue-state", "focused");
    fireEvent.pointerDown(refresh);
    expect(surface).toHaveAttribute("data-venue-state", "pressed");
    fireEvent.pointerUp(refresh);
    expect(surface).toHaveAttribute("data-venue-state", "focused");
    fireEvent.mouseDown(refresh);
    expect(surface).toHaveAttribute("data-venue-state", "pressed");
    fireEvent.mouseUp(refresh);
    expect(surface).toHaveAttribute("data-venue-state", "focused");
    fireEvent.blur(refresh);

    const confirmed = screen.getByRole("button", {
      name: /confirmed snapshot/i,
    });
    fireEvent.click(confirmed);
    expect(confirmed).toHaveAttribute("aria-pressed", "true");
    expect(surface).toHaveAttribute("data-venue-state", "selected");
  });

  it.each([
    ["error", "Venue workflow unavailable"],
    ["conflict", "Venue data changed"],
    ["security_timeout", "Venue request timed out"],
  ])("renders a bounded %s recovery state", (state, copy) => {
    render(
      <ControlledVenueRoutePage route="promotions" initialState={state} />,
    );
    expect(screen.getByRole("alert")).toHaveTextContent(copy);
    expect(
      screen.queryByText(/private|token|provider/i),
    ).not.toBeInTheDocument();
  });
});

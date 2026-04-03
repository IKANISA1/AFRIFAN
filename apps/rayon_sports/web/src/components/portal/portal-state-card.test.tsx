import { render, screen } from "@testing-library/react";
import { PortalStateCard } from "@/components/portal/portal-state-card";

describe("PortalStateCard", () => {
  it("renders the supplied label, value, and helper", () => {
    render(
      <PortalStateCard
        label="Membership tier"
        value="GOLD"
        helper="Shared fan identity is active."
      />,
    );

    expect(screen.getByText("Membership tier")).toBeInTheDocument();
    expect(screen.getByText("GOLD")).toBeInTheDocument();
    expect(
      screen.getByText("Shared fan identity is active."),
    ).toBeInTheDocument();
  });
});

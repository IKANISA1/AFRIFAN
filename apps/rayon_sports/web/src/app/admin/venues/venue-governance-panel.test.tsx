import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { emptyVenueGovernanceSnapshot } from "@/lib/data/venue";
import { VenueGovernancePanel } from "./venue-governance-panel";

describe("VenueGovernancePanel", () => {
  it("renders venue admin governance controls and export affordance", () => {
    render(<VenueGovernancePanel snapshot={emptyVenueGovernanceSnapshot} />);

    expect(screen.getByText("Onboarding approvals")).toBeInTheDocument();
    expect(screen.getByText("Staff assignment")).toBeInTheDocument();
    expect(screen.getByText("Campaign controls")).toBeInTheDocument();
    expect(screen.getByText("FET export and reversals")).toBeInTheDocument();
    expect(screen.getByText("Audit detail")).toBeInTheDocument();
    expect(screen.getByText("Compliance flags")).toBeInTheDocument();

    expect(
      screen.getByRole("button", { name: "Approve profile" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Assign staff" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Approve campaign" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Disable" })).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "Prepare reversal" }),
    ).toBeInTheDocument();
    expect(
      screen.getByRole("button", { name: "View audit" }),
    ).toBeInTheDocument();
    expect(screen.getByRole("link", { name: /export csv/i })).toHaveAttribute(
      "download",
      "rayon-venue-fet-export.csv",
    );
  });

  it("keeps regulated release gates visible", () => {
    render(<VenueGovernancePanel snapshot={emptyVenueGovernanceSnapshot} />);

    expect(screen.getByText("Location retention")).toBeInTheDocument();
    expect(screen.getByText("Alcohol age gate")).toBeInTheDocument();
    expect(screen.getByText("Review required")).toBeInTheDocument();
    expect(screen.getByText("Blocked")).toBeInTheDocument();
  });
});

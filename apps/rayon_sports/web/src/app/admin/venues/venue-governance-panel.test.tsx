import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { emptyVenueGovernanceSnapshot } from "@/lib/data/venue";
import { VenueGovernancePanel } from "./venue-governance-panel";

describe("VenueGovernancePanel", () => {
  it("renders venue governance gates without fake action controls", () => {
    render(<VenueGovernancePanel snapshot={emptyVenueGovernanceSnapshot} />);

    expect(screen.getByText("Onboarding approvals")).toBeInTheDocument();
    expect(screen.getByText("Staff assignment")).toBeInTheDocument();
    expect(screen.getByText("Campaign controls")).toBeInTheDocument();
    expect(screen.getByText("FET export and reversals")).toBeInTheDocument();
    expect(screen.getByText("Audit detail")).toBeInTheDocument();
    expect(screen.getByText("Compliance flags")).toBeInTheDocument();

    expect(screen.queryAllByRole("button")).toHaveLength(0);
    expect(screen.getByText("Next gate: Approve profile")).toBeInTheDocument();
    expect(screen.getByText("Next gate: Assign staff")).toBeInTheDocument();
    expect(screen.getByText("Next gate: Approve campaign")).toBeInTheDocument();
    expect(screen.getByText("Next gate: Disable")).toBeInTheDocument();
    expect(screen.getByText("Next gate: Prepare reversal")).toBeInTheDocument();
    expect(screen.getByText("Next gate: View audit")).toBeInTheDocument();
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

  it("reports the export interaction states to the route surface", () => {
    const onInteractionChange = vi.fn();
    render(
      <VenueGovernancePanel
        snapshot={emptyVenueGovernanceSnapshot}
        onInteractionChange={onInteractionChange}
      />,
    );

    const exportLink = screen.getByRole("link", { name: /export csv/i });
    fireEvent.focus(exportLink);
    fireEvent.pointerDown(exportLink);
    fireEvent.click(exportLink);

    expect(onInteractionChange).toHaveBeenNthCalledWith(1, "focused");
    expect(onInteractionChange).toHaveBeenNthCalledWith(2, "pressed");
    expect(onInteractionChange).toHaveBeenNthCalledWith(3, "selected");
  });
});

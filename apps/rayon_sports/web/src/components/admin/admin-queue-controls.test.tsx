import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AdminPagination } from "./admin-pagination";
import { AdminSelectionBar } from "./admin-selection-bar";

describe("admin queue controls", () => {
  it("announces the bounded result range and supports first/previous/next/last", () => {
    const onPageChange = vi.fn();
    render(
      <AdminPagination
        label="Ticket orders"
        page={{
          page: 2,
          pageSize: 25,
          totalItems: 80,
          totalPages: 4,
          startItem: 26,
          endItem: 50,
        }}
        onPageChange={onPageChange}
      />,
    );

    expect(screen.getByRole("navigation", { name: "Ticket orders pagination" }))
      .toBeInTheDocument();
    expect(screen.getByText("26–50 of 80")).toHaveAttribute("aria-live", "polite");
    fireEvent.click(screen.getByRole("button", { name: "Go to first page" }));
    fireEvent.click(screen.getByRole("button", { name: "Go to previous page" }));
    fireEvent.click(screen.getByRole("button", { name: "Go to next page" }));
    fireEvent.click(screen.getByRole("button", { name: "Go to last page" }));
    expect(onPageChange.mock.calls.map(([page]) => page)).toEqual([1, 1, 3, 4]);
  });

  it("exposes selection count, scope, review, and clear actions", () => {
    const onClear = vi.fn();
    const onReview = vi.fn();
    const { rerender } = render(
      <AdminSelectionBar
        selectedCount={0}
        scopeLabel="Active club"
        onClear={onClear}
        onReview={onReview}
      />,
    );
    expect(screen.queryByRole("region", { name: "Selected records" })).toBeNull();

    rerender(
      <AdminSelectionBar
        selectedCount={3}
        scopeLabel="Active club"
        onClear={onClear}
        onReview={onReview}
      />,
    );
    expect(screen.getByText("3 records selected")).toBeInTheDocument();
    expect(screen.getByText("Active club")).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Clear" }));
    fireEvent.click(screen.getByRole("button", { name: "Review selection" }));
    expect(onClear).toHaveBeenCalledTimes(1);
    expect(onReview).toHaveBeenCalledTimes(1);
  });
});

import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AdminDataGrid } from "./admin-data-grid";

describe("AdminDataGrid", () => {
  it("exposes caption, busy state, semantic sorting, and responsive priority", () => {
    const onSort = vi.fn();
    render(
      <AdminDataGrid
        caption="Ticket operations queue"
        busy
        columns={[
          {
            key: "supporter",
            label: "Supporter",
            sortable: true,
            sortDirection: "ascending",
            onSort,
            priority: "primary",
          },
          { key: "details", label: "Details", priority: "tertiary" },
        ]}
      >
        <tr>
          <td>Alpha Fan</td>
          <td>Pending</td>
        </tr>
      </AdminDataGrid>,
    );

    expect(screen.getByRole("table", { name: "Ticket operations queue" })).toHaveAttribute(
      "aria-busy",
      "true",
    );
    expect(screen.getByRole("columnheader", { name: /supporter/i })).toHaveAttribute(
      "aria-sort",
      "ascending",
    );
    expect(screen.getByRole("columnheader", { name: "Details" })).toHaveAttribute(
      "data-column-priority",
      "tertiary",
    );
    fireEvent.click(screen.getByRole("button", { name: /sort by supporter/i }));
    expect(onSort).toHaveBeenCalledTimes(1);
  });

  it("opens an interactive row with Enter or Space without hijacking child controls", () => {
    const onRowActivate = vi.fn();
    render(
      <AdminDataGrid
        columns={[{ key: "record", label: "Record" }]}
        onRowActivate={onRowActivate}
      >
        <tr data-row-id="record-1">
          <td>
            <button type="button">Child action</button>
          </td>
        </tr>
      </AdminDataGrid>,
    );

    const row = screen.getByRole("row", { name: /child action/i });
    expect(row).toHaveAttribute("tabindex", "0");
    fireEvent.keyDown(row, { key: "Enter" });
    fireEvent.keyDown(row, { key: " " });
    expect(onRowActivate).toHaveBeenCalledTimes(2);
    expect(onRowActivate).toHaveBeenNthCalledWith(1, "record-1");

    fireEvent.keyDown(screen.getByRole("button", { name: "Child action" }), {
      key: "Enter",
    });
    expect(onRowActivate).toHaveBeenCalledTimes(2);
  });
});

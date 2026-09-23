import { describe, expect, it } from "vitest";
import {
  filterAdminRecords,
  normalizeAdminSearch,
  paginateAdminRecords,
  pruneAdminSelection,
  setAdminPageSelection,
  stableSortAdminRecords,
  toggleAdminSelection,
} from "./admin-collection";

describe("admin collection contract", () => {
  const records = [
    { id: "1", name: "Alpha Fan", status: "pending", amount: 100 },
    { id: "2", name: "beta fan", status: "valid", amount: 50 },
    { id: "3", name: "Alpha Coach", status: "pending", amount: 100 },
  ];

  it("normalizes multi-space and case-insensitive search terms", () => {
    expect(normalizeAdminSearch("  ALPHA   Pending ")).toBe("alpha pending");
    expect(
      filterAdminRecords(records, "alpha pending", (record) => [
        record.name,
        record.status,
      ]).map((record) => record.id),
    ).toEqual(["1", "3"]);
  });

  it("sorts naturally and preserves source order for equal values", () => {
    expect(
      stableSortAdminRecords(records, (record) => record.amount, "ascending").map(
        (record) => record.id,
      ),
    ).toEqual(["2", "1", "3"]);
    expect(
      stableSortAdminRecords(records, (record) => record.name, "descending").map(
        (record) => record.id,
      ),
    ).toEqual(["2", "1", "3"]);
  });

  it("bounds pages and reports a screen-reader-friendly item range", () => {
    expect(paginateAdminRecords(records, 99, 2)).toEqual({
      items: [records[2]],
      page: 2,
      pageSize: 2,
      totalItems: 3,
      totalPages: 2,
      startItem: 3,
      endItem: 3,
    });
    expect(paginateAdminRecords([], -1, 0)).toMatchObject({
      items: [],
      page: 1,
      pageSize: 1,
      totalItems: 0,
      totalPages: 1,
      startItem: 0,
      endItem: 0,
    });
  });

  it("persists, clears, and prunes selection without mutating prior state", () => {
    const original = new Set(["1"]);
    const toggled = toggleAdminSelection(original, "2", true);
    expect([...original]).toEqual(["1"]);
    expect([...toggled]).toEqual(["1", "2"]);

    const pageSelected = setAdminPageSelection(toggled, ["2", "3"], true);
    expect([...pageSelected]).toEqual(["1", "2", "3"]);
    expect([...setAdminPageSelection(pageSelected, ["1", "2"], false)]).toEqual([
      "3",
    ]);
    expect([...pruneAdminSelection(pageSelected, new Set(["2", "3"]))]).toEqual([
      "2",
      "3",
    ]);
  });
});

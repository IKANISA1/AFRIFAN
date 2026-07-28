import { act, renderHook } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { useAdminCollection } from "./use-admin-collection";

const records = [
  { id: "1", name: "Zulu", status: "pending" },
  { id: "2", name: "Alpha", status: "ready" },
  { id: "3", name: "Bravo", status: "pending" },
];

describe("useAdminCollection", () => {
  it("coordinates search, stable sorting, bounded paging, and persistent selection", () => {
    const { result } = renderHook(() =>
      useAdminCollection({
        records,
        getId: (record) => record.id,
        getSearchValues: (record) => [record.name, record.status],
        getSortValue: (record, key: "name" | "status") => record[key],
        initialSortKey: "name" as const,
        pageSize: 2,
      }),
    );

    expect(result.current.pageResult.items.map((record) => record.id)).toEqual([
      "2",
      "3",
    ]);

    act(() => {
      result.current.toggleSelection("2", true);
      result.current.setPage(2);
    });
    expect(result.current.selectedRecords.map((record) => record.id)).toEqual(["2"]);
    expect(result.current.pageResult.items.map((record) => record.id)).toEqual(["1"]);

    act(() => result.current.setQuery("pending"));
    expect(result.current.pageResult.page).toBe(1);
    expect(result.current.pageResult.items.map((record) => record.id)).toEqual([
      "3",
      "1",
    ]);

    act(() => result.current.toggleSort("name"));
    expect(result.current.pageResult.items.map((record) => record.id)).toEqual([
      "1",
      "3",
    ]);
  });

  it("fails closed when a selection would exceed the reviewed limit", () => {
    const { result } = renderHook(() =>
      useAdminCollection({
        records,
        getId: (record) => record.id,
        getSearchValues: (record) => [record.name],
        getSortValue: (record) => record.name,
        initialSortKey: "name",
        selectionLimit: 1,
      }),
    );

    act(() => {
      expect(result.current.toggleSelection("1", true)).toBe(true);
    });
    act(() => {
      expect(result.current.toggleSelection("2", true)).toBe(false);
    });
    expect([...result.current.selectedIds]).toEqual(["1"]);
  });
});

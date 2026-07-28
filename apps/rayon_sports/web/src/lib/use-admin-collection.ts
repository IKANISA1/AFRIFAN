"use client";

import { useMemo, useState } from "react";
import {
  filterAdminRecords,
  paginateAdminRecords,
  pruneAdminSelection,
  setAdminPageSelection,
  stableSortAdminRecords,
  toggleAdminSelection,
  type AdminSortDirection,
} from "@/lib/admin-collection";

interface UseAdminCollectionOptions<T, SortKey extends string> {
  records: readonly T[];
  getId: (record: T) => string;
  getSearchValues: (record: T) => readonly unknown[];
  getSortValue: (record: T, sortKey: SortKey) => string | number | boolean | Date | null | undefined;
  initialSortKey: SortKey;
  initialSortDirection?: AdminSortDirection;
  pageSize?: number;
  selectionLimit?: number;
}

export function useAdminCollection<T, SortKey extends string>({
  records,
  getId,
  getSearchValues,
  getSortValue,
  initialSortKey,
  initialSortDirection = "ascending",
  pageSize = 25,
  selectionLimit = 100,
}: UseAdminCollectionOptions<T, SortKey>) {
  const [query, setQueryState] = useState("");
  const [sortKey, setSortKey] = useState<SortKey>(initialSortKey);
  const [sortDirection, setSortDirection] =
    useState<AdminSortDirection>(initialSortDirection);
  const [page, setPage] = useState(1);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  const sortedRecords = useMemo(() => {
    const filtered = filterAdminRecords(records, query, getSearchValues);
    return stableSortAdminRecords(
      filtered,
      (record) => getSortValue(record, sortKey),
      sortDirection,
    );
  }, [getSearchValues, getSortValue, query, records, sortDirection, sortKey]);

  const pageResult = useMemo(
    () => paginateAdminRecords(sortedRecords, page, pageSize),
    [page, pageSize, sortedRecords],
  );

  const availableIds = useMemo(
    () => new Set(records.map(getId)),
    [getId, records],
  );
  const effectiveSelectedIds = useMemo(
    () => pruneAdminSelection(selectedIds, availableIds),
    [availableIds, selectedIds],
  );
  const selectedRecords = useMemo(
    () => records.filter((record) => effectiveSelectedIds.has(getId(record))),
    [effectiveSelectedIds, getId, records],
  );

  const pageIds = useMemo(
    () => pageResult.items.map(getId),
    [getId, pageResult.items],
  );
  const selectedOnPage = pageIds.filter((id) =>
    effectiveSelectedIds.has(id),
  ).length;
  const allPageSelected =
    pageIds.length > 0 && selectedOnPage === pageIds.length;

  function setQuery(nextQuery: string) {
    setPage(1);
    setQueryState(nextQuery);
  }

  function toggleSort(nextSortKey: SortKey) {
    setPage(1);
    if (sortKey === nextSortKey) {
      setSortDirection((current) =>
        current === "ascending" ? "descending" : "ascending",
      );
      return;
    }
    setSortKey(nextSortKey);
    setSortDirection("ascending");
  }

  function sortDirectionFor(column: SortKey) {
    return sortKey === column ? sortDirection : "none";
  }

  function commitSelection(next: Set<string>) {
    if (next.size > selectionLimit) {
      return false;
    }
    setSelectedIds(next);
    return true;
  }

  return {
    query,
    setQuery,
    sortKey,
    sortDirection,
    toggleSort,
    sortDirectionFor,
    pageResult,
    setPage,
    selectedIds: effectiveSelectedIds,
    selectedRecords,
    selectedOnPage,
    allPageSelected,
    pageIds,
    selectionLimit,
    clearSelection: () => setSelectedIds(new Set()),
    toggleSelection: (recordId: string, selected?: boolean) =>
      commitSelection(
        toggleAdminSelection(effectiveSelectedIds, recordId, selected),
      ),
    setPageSelection: (selected: boolean) =>
      commitSelection(
        setAdminPageSelection(effectiveSelectedIds, pageIds, selected),
      ),
  };
}

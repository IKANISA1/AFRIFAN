export type AdminSortDirection = "ascending" | "descending";

export interface AdminPage<T> {
  items: T[];
  page: number;
  pageSize: number;
  totalItems: number;
  totalPages: number;
  startItem: number;
  endItem: number;
}

type SortableValue = string | number | boolean | Date | null | undefined;

export function normalizeAdminSearch(value: string) {
  return value.trim().replace(/\s+/g, " ").toLocaleLowerCase("en");
}

export function filterAdminRecords<T>(
  records: readonly T[],
  query: string,
  getSearchValues: (record: T) => readonly unknown[],
) {
  const normalizedQuery = normalizeAdminSearch(query);
  if (!normalizedQuery) {
    return [...records];
  }

  const terms = normalizedQuery.split(" ");
  return records.filter((record) => {
    const haystack = getSearchValues(record)
      .filter((value) => value != null)
      .map((value) => normalizeAdminSearch(String(value)))
      .join(" ");
    return terms.every((term) => haystack.includes(term));
  });
}

function normalizedSortValue(value: SortableValue): string | number {
  if (value instanceof Date) {
    return value.getTime();
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : Number.NEGATIVE_INFINITY;
  }
  if (typeof value === "boolean") {
    return value ? 1 : 0;
  }
  return value == null ? "" : String(value).toLocaleLowerCase("en");
}

export function stableSortAdminRecords<T>(
  records: readonly T[],
  getValue: (record: T) => SortableValue,
  direction: AdminSortDirection,
) {
  const multiplier = direction === "ascending" ? 1 : -1;
  return records
    .map((record, index) => ({
      index,
      record,
      value: normalizedSortValue(getValue(record)),
    }))
    .sort((left, right) => {
      if (typeof left.value === "number" && typeof right.value === "number") {
        const result = left.value - right.value;
        return result === 0 ? left.index - right.index : result * multiplier;
      }

      const result = String(left.value).localeCompare(String(right.value), "en", {
        numeric: true,
        sensitivity: "base",
      });
      return result === 0 ? left.index - right.index : result * multiplier;
    })
    .map(({ record }) => record);
}

export function paginateAdminRecords<T>(
  records: readonly T[],
  requestedPage: number,
  requestedPageSize: number,
): AdminPage<T> {
  const pageSize = Math.max(1, Math.floor(requestedPageSize));
  const totalItems = records.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));
  const page = Math.min(totalPages, Math.max(1, Math.floor(requestedPage)));
  const startIndex = (page - 1) * pageSize;
  const items = records.slice(startIndex, startIndex + pageSize);

  return {
    items,
    page,
    pageSize,
    totalItems,
    totalPages,
    startItem: totalItems === 0 ? 0 : startIndex + 1,
    endItem: totalItems === 0 ? 0 : startIndex + items.length,
  };
}

export function toggleAdminSelection(
  selectedIds: ReadonlySet<string>,
  recordId: string,
  selected?: boolean,
) {
  const next = new Set(selectedIds);
  const shouldSelect = selected ?? !next.has(recordId);
  if (shouldSelect) {
    next.add(recordId);
  } else {
    next.delete(recordId);
  }
  return next;
}

export function setAdminPageSelection(
  selectedIds: ReadonlySet<string>,
  pageRecordIds: readonly string[],
  selected: boolean,
) {
  const next = new Set(selectedIds);
  pageRecordIds.forEach((recordId) => {
    if (selected) {
      next.add(recordId);
    } else {
      next.delete(recordId);
    }
  });
  return next;
}

export function pruneAdminSelection(
  selectedIds: ReadonlySet<string>,
  availableRecordIds: ReadonlySet<string>,
) {
  return new Set([...selectedIds].filter((recordId) => availableRecordIds.has(recordId)));
}

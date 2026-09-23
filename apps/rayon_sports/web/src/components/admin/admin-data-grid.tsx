"use client";

import {
  Children,
  cloneElement,
  isValidElement,
  type ReactNode,
  type ReactElement,
  type HTMLAttributes,
  type KeyboardEvent,
  type MouseEvent,
  type TdHTMLAttributes,
} from "react";
import { ArrowDown, ArrowUp, ArrowUpDown } from "lucide-react";
import { cn } from "@/lib/utils";
import type { AdminSortDirection } from "@/lib/admin-collection";

type TableCellProps = TdHTMLAttributes<HTMLTableCellElement> & {
  "data-column-label"?: string;
};

type TableRowProps = HTMLAttributes<HTMLTableRowElement> & {
  "data-row-id"?: string;
};

interface AdminDataGridProps {
  columns: {
    key: string;
    label: string;
    className?: string;
    priority?: "primary" | "secondary" | "tertiary";
    sortable?: boolean;
    sortDirection?: AdminSortDirection | "none";
    onSort?: () => void;
  }[];
  children: ReactNode;
  className?: string;
  tableClassName?: string;
  caption?: string;
  busy?: boolean;
  onRowActivate?: (rowId: string) => void;
}

export function AdminDataGrid({
  columns,
  children,
  className,
  tableClassName,
  caption,
  busy = false,
  onRowActivate,
}: AdminDataGridProps) {
  const decoratedRows = Children.map(children, (row) => {
    if (!isValidElement<TableRowProps>(row) || row.type !== "tr") {
      return row;
    }

    const decoratedCells = Children.map(row.props.children, (cell, index) => {
      if (!isValidElement<TableCellProps>(cell)) {
        return cell;
      }

      const cellType = typeof cell.type === "string" ? cell.type : null;
      if (cellType !== "td" && cellType !== "th") {
        return cell;
      }

      const colSpan =
        typeof cell.props.colSpan === "number" ? cell.props.colSpan : 1;
      return cloneElement(cell as ReactElement<TableCellProps>, {
        "data-column-label":
          colSpan > 1 ? undefined : (columns[index]?.label ?? ""),
        className: cn(
          cell.props.className,
          "admin-table-cell",
          colSpan > 1 && "admin-table-cell-full-span",
        ),
      });
    });

    const rowId = row.props["data-row-id"];
    const isInteractive = onRowActivate != null && typeof rowId === "string";
    const originalClick = row.props.onClick;
    const originalKeyDown = row.props.onKeyDown;
    const handleClick = isInteractive
      ? (event: MouseEvent<HTMLTableRowElement>) => {
          originalClick?.(event);
          if (event.defaultPrevented) {
            return;
          }

          const target = event.target;
          const interactiveDescendant =
            target instanceof Element
              ? target.closest(
                  "a, button, input, select, textarea, summary, [role='button'], [role='link']",
                )
              : null;
          if (
            interactiveDescendant &&
            interactiveDescendant !== event.currentTarget
          ) {
            return;
          }

          onRowActivate(rowId);
        }
      : originalClick;
    const handleKeyDown = isInteractive
      ? (event: KeyboardEvent<HTMLTableRowElement>) => {
          originalKeyDown?.(event);
          if (
            !event.defaultPrevented &&
            event.target === event.currentTarget &&
            (event.key === "Enter" || event.key === " ")
          ) {
            event.preventDefault();
            onRowActivate(rowId);
          }
        }
      : originalKeyDown;

    return cloneElement(row as ReactElement<TableRowProps>, {
      className: cn(row.props.className, "admin-table-row"),
      children: decoratedCells,
      tabIndex: isInteractive ? (row.props.tabIndex ?? 0) : row.props.tabIndex,
      onClick: handleClick,
      onKeyDown: handleKeyDown,
    });
  });

  return (
    <div className={cn("admin-table-shell", className)}>
      <table
        className={cn("admin-table", tableClassName)}
        aria-busy={busy ? "true" : undefined}
      >
        {caption ? <caption className="sr-only">{caption}</caption> : null}
        <thead>
          <tr>
            {columns.map((column) => {
              const sortDirection = column.sortDirection ?? "none";
              const SortIcon =
                sortDirection === "ascending"
                  ? ArrowUp
                  : sortDirection === "descending"
                    ? ArrowDown
                    : ArrowUpDown;
              return (
                <th
                  key={column.key}
                  className={column.className}
                  scope="col"
                  data-column-priority={column.priority ?? "secondary"}
                  aria-sort={column.sortable ? sortDirection : undefined}
                >
                  {column.sortable && column.onSort ? (
                    <button
                      type="button"
                      className="admin-sort-button"
                      onClick={column.onSort}
                      aria-label={`Sort by ${column.label}${
                        sortDirection === "ascending"
                          ? ", currently ascending"
                          : sortDirection === "descending"
                            ? ", currently descending"
                            : ""
                      }`}
                    >
                      <span>{column.label}</span>
                      <SortIcon size={15} aria-hidden="true" />
                    </button>
                  ) : (
                    column.label
                  )}
                </th>
              );
            })}
          </tr>
        </thead>
        <tbody>{decoratedRows}</tbody>
      </table>
    </div>
  );
}

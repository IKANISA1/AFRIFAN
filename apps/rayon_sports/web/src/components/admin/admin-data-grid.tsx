import {
  Children,
  cloneElement,
  isValidElement,
  type ReactNode,
  type ReactElement,
  type HTMLAttributes,
  type TdHTMLAttributes,
} from "react";
import { cn } from "@/lib/utils";

type TableCellProps = TdHTMLAttributes<HTMLTableCellElement> & {
  "data-column-label"?: string;
};

interface AdminDataGridProps {
  columns: {
    key: string;
    label: string;
    className?: string;
  }[];
  children: ReactNode;
  className?: string;
  tableClassName?: string;
}

export function AdminDataGrid({
  columns,
  children,
  className,
  tableClassName,
}: AdminDataGridProps) {
  const decoratedRows = Children.map(children, (row) => {
    if (!isValidElement<HTMLAttributes<HTMLTableRowElement>>(row) || row.type !== "tr") {
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

      const colSpan = typeof cell.props.colSpan === "number" ? cell.props.colSpan : 1;
      return cloneElement(cell as ReactElement<TableCellProps>, {
        "data-column-label": colSpan > 1 ? undefined : columns[index]?.label ?? "",
        className: cn(
          cell.props.className,
          "admin-table-cell",
          colSpan > 1 && "admin-table-cell-full-span",
        ),
      });
    });

    return cloneElement(row as ReactElement<HTMLAttributes<HTMLTableRowElement>>, {
      className: cn(row.props.className, "admin-table-row"),
      children: decoratedCells,
    });
  });

  return (
    <div className={cn("admin-table-shell", className)}>
      <table className={cn("admin-table", tableClassName)}>
        <thead>
          <tr>
            {columns.map((column) => (
              <th key={column.key} className={column.className}>
                {column.label}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>{decoratedRows}</tbody>
      </table>
    </div>
  );
}

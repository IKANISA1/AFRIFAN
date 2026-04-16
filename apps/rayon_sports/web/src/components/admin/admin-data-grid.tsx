import type { ReactNode } from "react";
import { cn } from "@/lib/utils";

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
        <tbody>{children}</tbody>
      </table>
    </div>
  );
}

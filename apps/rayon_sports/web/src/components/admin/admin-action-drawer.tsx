import type { ReactNode } from "react";
import { AdminDialogFrame } from "@/components/admin/admin-dialog-frame";

interface AdminActionDrawerProps {
  isOpen?: boolean;
  open?: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
  footer?: ReactNode;
  className?: string;
}

export function AdminActionDrawer({
  isOpen,
  open,
  onClose,
  title,
  children,
  footer,
  className,
}: AdminActionDrawerProps) {
  const resolvedOpen = isOpen ?? open ?? false;
  return (
    <AdminDialogFrame
      open={resolvedOpen}
      onClose={onClose}
      title={title}
      layout="drawer"
      panelClassName={className}
      bodyClassName="custom-scrollbar"
      footer={footer}
      closeLabel={`Close ${title}`}
    >
      {children}
    </AdminDialogFrame>
  );
}

export type AdminDestructiveUndoMode =
  | "available"
  | "manual_recovery"
  | "not_available";

export interface AdminDestructiveConfirmOptions {
  action: string;
  subject: string;
  scope: string;
  impact: string;
  undo: AdminDestructiveUndoMode;
  confirmationLabel?: string;
}

export function buildAdminDestructiveConfirmation({
  action,
  subject,
  scope,
  impact,
  undo,
  confirmationLabel = "Continue only after reviewing the scope and impact.",
}: AdminDestructiveConfirmOptions): string {
  const undoLabel = {
    available: "An undo or restoration path is available.",
    manual_recovery: "Recovery requires a separate manual admin action.",
    not_available: "This action cannot be undone.",
  }[undo];

  return [
    `${action} ${subject}?`,
    `Scope: ${scope}`,
    `Impact: ${impact}`,
    `Recovery: ${undoLabel}`,
    confirmationLabel,
  ].join("\n\n");
}

export function confirmAdminDestructiveAction(
  options: AdminDestructiveConfirmOptions,
) {
  if (typeof window === "undefined") {
    return false;
  }

  return window.confirm(buildAdminDestructiveConfirmation(options));
}

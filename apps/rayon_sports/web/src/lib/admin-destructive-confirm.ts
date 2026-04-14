interface AdminDestructiveConfirmOptions {
  action?: string;
  subject: string;
  detail?: string;
}

export function confirmAdminDestructiveAction({
  action = "Delete",
  subject,
  detail = "This action cannot be undone.",
}: AdminDestructiveConfirmOptions) {
  if (typeof window === "undefined") {
    return true;
  }

  return window.confirm(`${action} ${subject}?\n\n${detail}`);
}

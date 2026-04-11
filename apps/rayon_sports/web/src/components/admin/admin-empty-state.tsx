interface AdminEmptyStateProps {
  title: string;
  description?: string;
}

export function AdminEmptyState({
  title,
  description,
}: AdminEmptyStateProps) {
  return (
    <div className="admin-empty-state">
      <p className="admin-empty-title">{title}</p>
      {description ? (
        <p className="admin-empty-copy">{description}</p>
      ) : null}
    </div>
  );
}

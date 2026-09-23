import { RecoveryPage } from "@/components/recovery-page";

export default function AdminOfflinePage() {
  return (
    <RecoveryPage
      eyebrow="Admin offline"
      title="Admin data needs a live connection"
      description="The admin workspace is intentionally network-first so operators never act on stale club data. Reconnect to continue publishing, editing, or reconciling supporter activity."
      primaryAction={{ href: "/admin", label: "Retry admin workspace" }}
      secondaryAction={{ href: "/", label: "Open public site" }}
    />
  );
}

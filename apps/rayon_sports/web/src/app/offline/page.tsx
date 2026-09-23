import { RecoveryPage } from "@/components/recovery-page";

export default function OfflinePage() {
  return (
    <RecoveryPage
      eyebrow="Offline mode"
      title="Cached pages stay available"
      description="You are offline right now. Core pages, media, and recent site content remain available from cache, while live match state and authenticated mutations resume when connectivity returns."
      primaryAction={{ href: "/", label: "Cached homepage" }}
      secondaryAction={{ href: "/fixtures", label: "Cached fixtures" }}
    />
  );
}

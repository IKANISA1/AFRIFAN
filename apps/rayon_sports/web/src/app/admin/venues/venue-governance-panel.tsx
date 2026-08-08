import {
  ClipboardCheck,
  Download,
  FileWarning,
  ShieldAlert,
  UserRoundCog,
} from "lucide-react";
import { AdminStatusBadge } from "@/components/admin/admin-status-badge";
import type { AdminResourceInteraction } from "@/components/admin/admin-resource-status-banner";
import { AdminSurface } from "@/components/admin/admin-surface";
import type {
  VenueGovernanceItem,
  VenueGovernanceSnapshot,
} from "@/lib/data/venue";
import { ui } from "@/ui-kit";

interface VenueGovernancePanelProps {
  snapshot: VenueGovernanceSnapshot;
  onInteractionChange?: (interaction: AdminResourceInteraction) => void;
}

const sections: Array<{
  key: keyof Pick<
    VenueGovernanceSnapshot,
    | "onboardingQueue"
    | "staffAssignments"
    | "campaignControls"
    | "fetControls"
    | "auditEvents"
    | "complianceFlags"
  >;
  title: string;
  icon: typeof ClipboardCheck;
}> = [
  {
    key: "onboardingQueue",
    title: "Onboarding approvals",
    icon: ClipboardCheck,
  },
  { key: "staffAssignments", title: "Staff assignment", icon: UserRoundCog },
  { key: "campaignControls", title: "Campaign controls", icon: ShieldAlert },
  { key: "fetControls", title: "FET export and reversals", icon: Download },
  { key: "auditEvents", title: "Audit detail", icon: ClipboardCheck },
  { key: "complianceFlags", title: "Compliance flags", icon: FileWarning },
];

export function VenueGovernancePanel({
  snapshot,
  onInteractionChange,
}: VenueGovernancePanelProps) {
  const csvHref = `data:text/csv;charset=utf-8,${encodeURIComponent(
    snapshot.exportCsv,
  )}`;

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {sections.map(({ key, title, icon: Icon }) => (
        <AdminSurface
          key={key}
          title={title}
          actions={
            key === "fetControls" ? (
              <a
                className={ui.buttonSecondary}
                href={csvHref}
                download="rayon-venue-fet-export.csv"
                onFocus={() => onInteractionChange?.("focused")}
                onBlur={() => onInteractionChange?.("idle")}
                onPointerDown={() => onInteractionChange?.("pressed")}
                onClick={() => onInteractionChange?.("selected")}
              >
                <Download size={16} aria-hidden="true" />
                Export CSV
              </a>
            ) : null
          }
        >
          <div className="space-y-3">
            {snapshot[key].map((item) => (
              <VenueGovernanceRow key={item.id} item={item} Icon={Icon} />
            ))}
          </div>
        </AdminSurface>
      ))}
    </div>
  );
}

function VenueGovernanceRow({
  item,
  Icon,
}: {
  item: VenueGovernanceItem;
  Icon: typeof ClipboardCheck;
}) {
  return (
    <article className="rounded-lg border border-[var(--admin-border-subtle)] bg-[var(--admin-surface-raised)] p-4">
      <div className="flex items-start gap-3">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-club-primary/15 text-club-accent">
          <Icon size={18} aria-hidden="true" />
        </span>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-2">
            <h3 className="text-sm font-bold text-[var(--admin-text-strong)]">
              {item.label}
            </h3>
            <AdminStatusBadge label={item.status} tone={toneFor(item.status)} />
          </div>
          <p className="mt-2 text-sm leading-6 text-[var(--admin-text-muted)]">
            {item.detail}
          </p>
          <p className={`${ui.buttonTertiary} mt-3 inline-flex cursor-default`}>
            Next gate: {item.actionLabel}
          </p>
        </div>
      </div>
    </article>
  );
}

function toneFor(status: string) {
  const normalized = status.toLowerCase();
  if (normalized.includes("blocked") || normalized.includes("required")) {
    return "warning" as const;
  }
  if (normalized.includes("closed") || normalized.includes("event")) {
    return "success" as const;
  }
  return "info" as const;
}

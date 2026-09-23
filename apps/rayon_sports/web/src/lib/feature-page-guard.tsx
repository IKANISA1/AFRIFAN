import { DisabledFeatureFallback } from "@/components/disabled-feature-fallback";
import {
  getFeatureAccess,
  getPlatformConfig,
  normalizeFeatureKey,
} from "@/lib/feature-config";

type FeaturePageGuardOptions = {
  title?: string;
  description?: string;
  allowControlledRouteEvidence?: boolean;
};

const FEATURE_LABELS: Record<string, string> = {
  ticketing: "Tickets",
  membership: "Membership",
  fan_clubs: "Fan clubs",
  contributions: "Support circles",
  shop: "Shop",
  news: "Newsroom",
  squad: "Squad",
  live: "Match center",
};

function defaultDescription(label: string, reason: string) {
  switch (reason) {
    case "maintenance":
      return `${label} is temporarily in maintenance. Please check back shortly.`;
    case "outside_schedule":
      return `${label} is not currently scheduled to be available on the website.`;
    case "auth_required":
      return `${label} is available only to signed-in users right now.`;
    case "role_restricted":
      return `${label} is currently limited to a different audience.`;
    case "channel_disabled":
      return `${label} is not enabled on the website at the moment.`;
    default:
      return `${label} is currently unavailable from this channel.`;
  }
}

export async function getFeaturePageGuard(
  featureKey: string,
  options: FeaturePageGuardOptions = {},
) {
  const controlledRouteEvidenceAllowed =
    options.allowControlledRouteEvidence === true &&
    process.env.AFRICLUB_ALLOW_HTTP_PREVIEW === "1" &&
    process.env.AFRICLUB_CONTROLLED_ROUTE_EVIDENCE === "1";
  if (controlledRouteEvidenceAllowed) {
    return null;
  }

  const config = await getPlatformConfig();
  const access = getFeatureAccess(config, featureKey);

  if (access.isVisible && access.isAvailable) {
    return null;
  }

  const normalizedKey = normalizeFeatureKey(featureKey);
  const featureLabel =
    options.title ??
    access.feature?.display_name ??
    FEATURE_LABELS[normalizedKey] ??
    "This feature";

  return (
    <DisabledFeatureFallback
      title={`${featureLabel} unavailable`}
      description={
        options.description ?? defaultDescription(featureLabel, access.reason)
      }
    />
  );
}

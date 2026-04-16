import type { ReactNode } from "react";
import type { PlatformConfigSnapshot } from "@/lib/feature-config";
import { isFeatureEnabled } from "@/lib/feature-config";

interface FeatureGateProps {
  /** The platform config snapshot (fetched via getPlatformConfig). */
  config: PlatformConfigSnapshot;
  /** The feature key to check. */
  featureKey: string;
  /** Content to render when the feature is enabled. */
  children: ReactNode;
  /** Optional fallback when disabled (default: nothing). */
  fallback?: ReactNode;
}

/**
 * Server component wrapper for feature-gated sections.
 *
 * Renders `children` only if the feature is enabled in the platform config.
 * Otherwise renders `fallback` (defaults to null).
 *
 * Usage:
 * ```tsx
 * <FeatureGate config={config} featureKey="ticketing">
 *   <TicketingSection />
 * </FeatureGate>
 * ```
 */
export function FeatureGate({
  config,
  featureKey,
  children,
  fallback = null,
}: FeatureGateProps) {
  if (isFeatureEnabled(config, featureKey)) {
    return <>{children}</>;
  }
  return <>{fallback}</>;
}

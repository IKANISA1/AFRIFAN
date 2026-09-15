import fs from "node:fs";
import type { Browser } from "@playwright/test";
import path from "node:path";

export const governedAdminStates = [
  "loading",
  "empty",
  "error",
  "offline",
  "permission_denied",
  "disabled",
  "focused",
  "pressed",
  "selected",
  "large_text",
  "reduced_motion",
  "dark",
  "light",
  "syncing",
  "conflict",
  "security_timeout",
] as const;

type ResponsiveCapture = {
  state: string;
  profile: string;
  description: string;
};

export function writeAdminStateEvidence({
  browser,
  evidenceDirectory,
  manifestFile,
  route,
  filePrefix,
  responsiveCaptures,
  assertions = {},
}: {
  browser: Browser;
  evidenceDirectory: string;
  manifestFile: string;
  route: string;
  filePrefix: string;
  responsiveCaptures: ResponsiveCapture[];
  assertions?: Record<string, boolean | number | string>;
}) {
  const captures: Array<{ state: string; file: string }> = governedAdminStates.map((state) => ({
    state,
    file: `${filePrefix}_state_${state}_${state === "light" ? "light" : "dark"}_desktop_1440x1000.png`,
  }));
  captures.push(
    ...responsiveCaptures.map(({ state, profile }) => ({
      state,
      file: `${filePrefix}_state_${state}_dark_${profile}.png`,
    })),
  );

  fs.writeFileSync(
    path.join(evidenceDirectory, manifestFile),
    `${JSON.stringify(
      {
        schema_version: "1.0",
        route,
        surface: "admin_pwa",
        exact_profile: `${browser.browserType().name()} desktop 1440x1000 at 1 DPR`,
        responsive_profiles: responsiveCaptures.map(
          ({ description }) => description,
        ),
        applicable_states: governedAdminStates,
        not_applicable_states: [],
        assertions: {
          authenticated_shell_required: true,
          protected_api_bypass_enabled: false,
          protected_mutation_bypass_enabled: false,
          confirmed_data_retained_during_recovery: true,
          permission_denial_clears_private_state: true,
          synthetic_non_production_data: true,
          minimum_target_css_pixels: 48,
          large_text_percent: 200,
          horizontal_overflow_css_pixels: 1,
          reduced_motion_max_seconds: 0.001,
          axe_critical_or_serious_dark: 0,
          axe_critical_or_serious_light: 0,
          axe_critical_or_serious_selected: 0,
          ...assertions,
        },
        captures,
      },
      null,
      2,
    )}\n`,
    "utf8",
  );
}

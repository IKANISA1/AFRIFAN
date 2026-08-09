#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const evidenceRoot = "output/implementation_goal_20260724";
const toWholeSecondIso = (value) =>
  new Date(value).toISOString().replace(/\.\d{3}Z$/, "Z");
const generatedAt = toWholeSecondIso(Date.now());
const reviewedAt = generatedAt.slice(0, 10);
const baselineCommit = "5016c8896bbb78b293dc89aaebd8d831c9ac7c4e";
const pubspec = fs.readFileSync(
  path.join(root, "apps/rayon_sports/pubspec.yaml"),
  "utf8",
);
const pubspecVersionMatch = pubspec.match(
  /^version:\s*([^+\s]+)\+([^\s#]+)(?:\s*#.*)?$/m,
);
if (!pubspecVersionMatch) {
  throw new Error(
    "apps/rayon_sports/pubspec.yaml must declare version as <app-version>+<build-number>",
  );
}
const [, appVersion, buildNumber] = pubspecVersionMatch;
const admissionRequested = process.argv.includes("--admit-reviewed");
const unknownArguments = process.argv
  .slice(2)
  .filter((argument) => argument !== "--admit-reviewed");
if (unknownArguments.length > 0) {
  throw new Error(`Unknown arguments: ${unknownArguments.join(", ")}`);
}
const states = [
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
];

const routes = [
  ["admin-pwa-predictions-rendered-states", "admin_pwa", "/admin/predictions", "admin_pwa_predictions_states", "apps/rayon_sports/web/e2e/admin-predictions-state-evidence.spec.ts"],
  ["admin-pwa-settings-rendered-states", "admin_pwa", "/admin/settings", "admin_pwa_settings_states", "apps/rayon_sports/web/e2e/admin-settings-state-evidence.spec.ts"],
  ["admin-pwa-settings-audit-rendered-states", "admin_pwa", "/admin/settings/audit", "admin_pwa_settings_audit_states", "apps/rayon_sports/web/e2e/admin-settings-audit-state-evidence.spec.ts"],
  ["admin-pwa-settings-features-rendered-states", "admin_pwa", "/admin/settings/features", "admin_pwa_settings_features_states", "apps/rayon_sports/web/e2e/admin-settings-features-state-evidence.spec.ts"],
  ["admin-pwa-settings-runtime-rendered-states", "admin_pwa", "/admin/settings/runtime", "admin_pwa_settings_runtime_states", "apps/rayon_sports/web/e2e/admin-settings-runtime-state-evidence.spec.ts"],
  ["admin-pwa-shop-rendered-states", "admin_pwa", "/admin/shop", "admin_pwa_shop_states", "apps/rayon_sports/web/e2e/admin-shop-state-evidence.spec.ts"],
  ["admin-pwa-sms-monitor-rendered-states", "admin_pwa", "/admin/sms-monitor", "admin_pwa_sms_monitor_states", "apps/rayon_sports/web/e2e/admin-sms-monitor-state-evidence.spec.ts"],
  ["admin-pwa-tickets-rendered-states", "admin_pwa", "/admin/tickets", "admin_pwa_tickets_states", "apps/rayon_sports/web/e2e/admin-tickets-state-evidence.spec.ts"],
  ["admin-pwa-venues-rendered-states", "admin_pwa", "/admin/venues", "admin_pwa_venues_states", "apps/rayon_sports/web/e2e/admin-venues-state-evidence.spec.ts"],
  ["venue-portal-overview-rendered-states", "venue_portal", "/venue", "venue_portal_overview_states", "apps/rayon_sports/web/e2e/venue-route-state-evidence.spec.ts"],
  ["venue-portal-orders-rendered-states", "venue_portal", "/venue/orders", "venue_portal_orders_states", "apps/rayon_sports/web/e2e/venue-route-state-evidence.spec.ts"],
  ["venue-portal-menu-rendered-states", "venue_portal", "/venue/menu", "venue_portal_menu_states", "apps/rayon_sports/web/e2e/venue-route-state-evidence.spec.ts"],
  ["venue-portal-checkins-rendered-states", "venue_portal", "/venue/checkins", "venue_portal_checkins_states", "apps/rayon_sports/web/e2e/venue-route-state-evidence.spec.ts"],
  ["venue-portal-promotions-rendered-states", "venue_portal", "/venue/promotions", "venue_portal_promotions_states", "apps/rayon_sports/web/e2e/venue-route-state-evidence.spec.ts"],
  ["venue-portal-staff-rendered-states", "venue_portal", "/venue/staff", "venue_portal_staff_states", "apps/rayon_sports/web/e2e/venue-route-state-evidence.spec.ts"],
  ["venue-portal-tv-code-rendered-states", "venue_portal", "/venue/tv-code", "venue_portal_tv_code_states", "apps/rayon_sports/web/e2e/venue-route-state-evidence.spec.ts"],
];

function readJson(relativePath) {
  return JSON.parse(fs.readFileSync(path.join(root, relativePath), "utf8"));
}

function writeJson(relativePath, value) {
  fs.writeFileSync(
    path.join(root, relativePath),
    `${JSON.stringify(value, null, 2)}\n`,
  );
}

function evidenceFiles(directory, requiredSourcePaths) {
  const absoluteDirectory = path.join(root, evidenceRoot, directory);
  const files = fs.readdirSync(absoluteDirectory).sort();
  const screenshots = files
    .filter((file) => file.endsWith(".png"))
    .map((file) => `${evidenceRoot}/${directory}/${file}`);
  const evidenceJson = files.find(
    (file) => file.endsWith(".json") && file !== "build-provenance.json",
  );
  if (!evidenceJson) {
    throw new Error(`${directory} must contain a machine-readable state-evidence JSON file`);
  }
  const evidence = readJson(
    `${evidenceRoot}/${directory}/${evidenceJson}`,
  );
  const applicableStates = evidence.applicable_states;
  if (
    !Array.isArray(applicableStates) ||
    applicableStates.length !== states.length ||
    !states.every(
      (state, index) => applicableStates[index] === state,
    )
  ) {
    throw new Error(
      `${directory} must declare the exact ordered sixteen-state catalog`,
    );
  }
  if (
    !Array.isArray(evidence.not_applicable_states) ||
    evidence.not_applicable_states.length !== 0
  ) {
    throw new Error(`${directory} must not mark governed route states N/A`);
  }
  if (!Array.isArray(evidence.captures)) {
    throw new Error(`${directory} must declare its screenshot captures`);
  }
  for (const state of states) {
    const matching = evidence.captures.filter(
      (capture) => capture?.state === state,
    );
    if (matching.length !== 1) {
      throw new Error(
        `${directory} must declare exactly one ${state} capture, found ${matching.length}`,
      );
    }
  }
  const responsiveCaptures = evidence.captures.filter((capture) =>
    capture?.state?.startsWith("responsive_"),
  );
  if (responsiveCaptures.length < 2) {
    throw new Error(
      `${directory} must declare at least tablet and compact responsive captures`,
    );
  }
  const declaredScreenshots = evidence.captures
    .map((capture) => capture?.file)
    .filter((file) => typeof file === "string")
    .sort();
  const actualScreenshots = screenshots
    .map((file) => path.basename(file))
    .sort();
  if (
    declaredScreenshots.length !== evidence.captures.length ||
    JSON.stringify(declaredScreenshots) !== JSON.stringify(actualScreenshots)
  ) {
    throw new Error(
      `${directory} screenshot files must exactly match the state-evidence manifest`,
    );
  }
  const capturedAtMs = Math.max(
    ...screenshots.map((file) =>
      fs.statSync(path.join(root, file)).mtime.getTime(),
    ),
    fs.statSync(path.join(absoluteDirectory, evidenceJson)).mtime.getTime(),
  );
  const requiredSourceMtimeMs = Math.max(
    ...requiredSourcePaths.map((sourcePath) =>
      fs.statSync(path.join(root, sourcePath)).mtime.getTime(),
    ),
  );
  if (capturedAtMs < requiredSourceMtimeMs) {
    throw new Error(
      `${directory} evidence predates a required route/spec source and must be rerun`,
    );
  }
  const capturedAt = toWholeSecondIso(capturedAtMs);
  return {
    screenshots,
    supportingEvidence: `${evidenceRoot}/${directory}/${evidenceJson}`,
    capturedAt,
  };
}

const validatedRouteEvidence = new Map(
  routes.map(([, surface, , directory, testEvidence]) => [
    directory,
    evidenceFiles(directory, [
      testEvidence,
      ...(surface === "venue_portal"
        ? ["apps/rayon_sports/web/src/app/venue/_components/venue-shell-client.tsx"]
        : ["apps/rayon_sports/web/e2e/admin-state-evidence-manifest.ts"]),
    ]),
  ]),
);

if (!admissionRequested) {
  console.log(
    `Preflight passed for ${routes.length} web route-state bundles; registries were not changed. Re-run with --admit-reviewed only after visual review.`,
  );
  process.exit(0);
}

const routeRegistryPath = "docs/governance/route-state-evidence.json";
const routeRegistry = readJson(routeRegistryPath);
const routeIds = new Set(routes.map(([id]) => id));
routeRegistry.groups = routeRegistry.groups.filter(
  (group) => !routeIds.has(group.id),
);

for (const [id, surface, route, directory, testEvidence] of routes) {
  const { screenshots, supportingEvidence } = validatedRouteEvidence.get(
    directory,
  );
  const proof = supportingEvidence;
  const isVenue = surface === "venue_portal";
  routeRegistry.groups.push({
    id,
    admission_status: "admitted",
    cells: states.map((state) => `${surface}|${route}|next_page|${state}`),
    test_evidence: [
      testEvidence,
      ...(isVenue
        ? ["apps/rayon_sports/web/src/lib/controlled-venue-evidence.test.ts"]
        : ["apps/rayon_sports/web/src/lib/controlled-admin-evidence.test.ts"]),
      "packages/app_registry/test/route_inventory_generation_test.dart",
    ],
    screenshot_evidence: screenshots,
    accessibility_evidence: [proof],
    performance_evidence: [proof],
    privacy_evidence: [
      `${evidenceRoot}/evidence-privacy-validation.json`,
      proof,
    ],
    platform_build_evidence: [proof],
    disposition_note: isVenue
      ? "The football-secondary venue operations route has exact controlled production-build evidence for all sixteen governed states plus tablet and compact layouts. The reviewed evidence proves deterministic synthetic records, retained safe snapshots, authorization denial, offline, conflict and timeout consequences, real focus, held press and selection, 200-percent reflow, reduced motion, dark and light contrast, 48-pixel controls, and privacy-safe venue copy. Live venue authorization and records, payment/order integration, alcohol and age-policy approval, physical assistive technology, named review, pinned CI, deployment, signing, stores, and release approval remain open."
      : "The authenticated Admin PWA route has exact controlled production-build evidence for all sixteen governed states plus tablet and compact layouts. The reviewed evidence proves bounded synthetic records, retained safe snapshots, authorization denial, offline, conflict and timeout consequences, real focus, held press and selection, 200-percent reflow, reduced motion, dark and light contrast, 48-pixel controls, and privacy-safe operator copy. Live role and RLS behavior, cross-role mutation UAT, physical assistive technology, named review, pinned CI, deployment, signing, stores, and release approval remain open.",
    owner: isVenue
      ? "Venue portal operations, authorization, privacy, accessibility, responsive, and evidence QA"
      : "Admin PWA authorization, privacy, accessibility, responsive, and evidence QA",
    reviewed_at: reviewedAt,
  });
}
routeRegistry.generated_at = generatedAt;
writeJson(routeRegistryPath, routeRegistry);

const bundleRegistryPath = "docs/governance/evidence-bundles.json";
const bundleRegistry = readJson(bundleRegistryPath);
const bundleDirectories = new Set(
  routes.map(([, , , directory]) => `${evidenceRoot}/${directory}`),
);
bundleRegistry.bundles = bundleRegistry.bundles.filter(
  (bundle) => !bundleDirectories.has(bundle.directory),
);

for (const [id, surface, route, directory] of routes) {
  const isVenue = surface === "venue_portal";
  const { capturedAt } = validatedRouteEvidence.get(directory);
  bundleRegistry.bundles.push({
    id: `${id}-20260802`,
    admission_status: "admitted",
    directory: `${evidenceRoot}/${directory}`,
    artifact_scope: "immediate",
    task_ids: [
      "STATE-01",
      "EVID-02",
      "EVID-03",
      "EVID-04",
      "EVID-05",
      "EVID-08",
      isVenue ? "VENUE-PORTAL-LOCAL" : "ADMIN-PWA-LOCAL",
      "REL-07",
    ],
    baseline_commit: baselineCommit,
    dirty_state: true,
    app_version: appVersion,
    build_number: buildNumber,
    flavor: `${surface}_production_local_controlled_${directory}_evidence`,
    platform: "nextjs_production_build_playwright_chromium",
    runtime_device:
      "Node 24.18.0; npm 11.16.0; Next.js 16.2.10; Playwright 1.59.1; Chromium desktop, tablet, and compact profiles",
    viewport_profiles: [
      { width: 1440, height: 1000, device_pixel_ratio: 1 },
      { width: 1024, height: 900, device_pixel_ratio: 1 },
      { width: 390, height: 844, device_pixel_ratio: 1 },
    ],
    locale: "en",
    themes: [
      "dark",
      "light",
      "large_text_200_percent",
      "reduced_motion",
      "offline",
    ],
    captured_at: capturedAt,
    data_source: `current_dirty_local_source_and_synthetic_non_production_browser_states_for_${surface}_${route.replaceAll("/", "_")}_with_explicit_two_key_loopback_only_evidence_and_no_protected_api_or_mutation_bypass_or_live_release_claim`,
  });
}
writeJson(bundleRegistryPath, bundleRegistry);

console.log(`Registered ${routes.length} web route-state groups and bundles.`);

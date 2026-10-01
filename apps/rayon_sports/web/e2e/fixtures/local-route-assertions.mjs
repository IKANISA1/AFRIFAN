import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

export const localClubs = [
  { slug: "as_vita", id: 6, host: "as-vita.example.test", name: "AS Vita Club" },
  { slug: "costa_do_sol", id: 1001, host: "costa-do-sol.example.test", name: "CD Costa do Sol" },
  { slug: "nkana", id: 26, host: "nkana.example.test", name: "Nkana FC" },
  { slug: "rayon_sports", id: 24, host: "rayon-sports.example.test", name: "Rayon Sports FC" },
  { slug: "vitalo", id: 44, host: "vitalo.example.test", name: "Vital'O FC" },
];

/** @param {import("@playwright/test").TestInfo} [testInfo] */
export function localClub(testInfo = test.info()) {
  const slug = testInfo.project.metadata?.localClub;
  return localClubs.find((club) => club.slug === slug);
}
export function localClubId() { return localClub()?.id ?? 24; }

/** @param {import("@playwright/test").TestInfo} testInfo
 * @returns {import("@playwright/test").BrowserContextOptions} */
export function localStateContextOptions(testInfo, admin = false) {
  const club = localClub(testInfo);
  if (!club) return {};
  const origin = new URL(String(testInfo.project.use.baseURL ?? "http://127.0.0.1:3200"));
  return {
    extraHTTPHeaders: { "x-forwarded-host": admin ? origin.host : club.host },
    storageState: { origins: [], cookies: [{ name: "africlub_admin_club", value: String(club.id), domain: origin.hostname, path: "/", expires: -1, httpOnly: false, secure: false, sameSite: "Lax" }] },
  };
}

/** Bind controlled API fixture identity fields to the selected declared tenant. */
export function bindLocalClubFixtures(value) {
  const club = localClub();
  if (!club) return value;
  if (Array.isArray(value)) return value.map(bindLocalClubFixtures);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.entries(value).map(([key, item]) => [key,
    (key === "clubId" || key === "club_id") && (item === 24 || item === "24")
      ? typeof item === "string" ? String(club.id) : club.id
      : bindLocalClubFixtures(item),
  ]));
}

const states = ["permission_denied", "security_timeout", "reduced_motion", "large_text", "loading", "empty", "error", "offline", "disabled", "focused", "pressed", "selected", "dark", "light", "syncing", "conflict"];
const accessibilityTags = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"];

/** Called after the original suite has asserted its concrete state behavior. */
/** @param {import("@playwright/test").Page} page
 * @param {string} filename
 * @param {string} evidenceDirectory */
export async function assertLocalRouteState(page, filename, evidenceDirectory) {
  const club = localClub();
  // Static source previews inserted into another page retain screenshots and
  // Axe assertions, but cannot provide route-state evidence for their host.
  const componentFixture = await page.locator("[data-local-component-fixture]").count() > 0;
  const suffix = path.basename(filename).split("_state_").slice(1).join("_state_").replace(/\.png$/, "");
  const state = states.find((candidate) => suffix === candidate || suffix.startsWith(`${candidate}_`));
  const pathname = new URL(page.url()).pathname;
  let route;
  if (club && state && !componentFixture) {
    const inventoryPath = process.env.AFRICLUB_LOCAL_ROUTE_INVENTORY;
    if (!inventoryPath) throw new Error("Current source inventory is required for local route assertions");
    const inventory = JSON.parse(fs.readFileSync(inventoryPath, "utf8"));
    const candidates = inventory.routes.filter((candidate) => candidate.kind === "next_page" && new RegExp(`^${candidate.path.split("/").map((part) => part.startsWith(":") ? "[^/]+" : part.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("/")}$`).test(pathname));
    expect(candidates, `One declared rendered route for ${pathname}`).toHaveLength(1);
    route = candidates[0];
  }
  await expect(page.locator("body")).toBeVisible();
  const result = await new AxeBuilder({ page }).withTags(accessibilityTags).analyze();
  // Retain the complete result before the failure gate, including incomplete
  // checks and every impact level. Automatic checks do not establish conformance.
  const axeFile = path.basename(filename).replace(/\.png$/, ".axe.json");
  const axeBytes = `${JSON.stringify(result, null, 2)}\n`;
  fs.writeFileSync(path.join(evidenceDirectory, axeFile), axeBytes, { flag: "wx" });
  const impactCounts = Object.fromEntries(["critical", "serious", "moderate", "minor", "unknown"].map((impact) => [impact,
    result.violations.filter((violation) => (violation.impact ?? "unknown") === impact).length,
  ]));
  const scope = componentFixture ? "static_component_fixture_without_product_admission"
    : route ? "declared_rendered_route_state" : "unmapped_capture_without_product_admission";
  console.log(JSON.stringify({ localAxeDiagnostic: 1, state: state ?? null, club: club?.slug ?? null,
    impact_counts: impactCounts, scope }));
  expect(result.violations.filter((violation) => violation.impact === "critical" || violation.impact === "serious"), `${club?.slug ?? "diagnostic"} ${pathname} ${state ?? "unmapped_capture"}`).toEqual([]);
  // Responsive/default/alias screenshots receive diagnostics, while only an
  // exact declared state and club can emit the unchanged route assertion.
  if (route && club && state) {
    console.log(JSON.stringify({ localRouteAssertion: 1, surface: route.surface, route: route.path, kind: route.kind, state, club: club.slug,
      assertions: ["existing controlled state preparation and behavioral checks", "actual rendered state boundary", "axe wcag2a wcag2aa wcag22aa critical and serious"],
    }));
  }
  return {
    file: axeFile,
    sha256: createHash("sha256").update(axeBytes).digest("hex"),
    tags: accessibilityTags,
    route: route?.path ?? null, state: state ?? null, club: club?.slug ?? null, scope,
    impact_counts: impactCounts,
    failure_gate: "critical_and_serious_violations",
    assessment: "automatic_checks_without_conformance_or_human_acceptance",
  };
}

import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import type { Browser, BrowserContextOptions, Page, TestInfo } from "@playwright/test";
import { assertLocalRouteState, localClub, localStateContextOptions } from "./fixtures/local-route-assertions.mjs";
import { guardStateEvidenceContext } from "./fixtures/local-browser-network.mjs";
export { createStateEvidenceContext } from "./fixtures/local-browser-network.mjs";

const sha256 = (bytes: Buffer) => createHash("sha256").update(bytes).digest("hex");

export function trackedSourceHash(workspace: string) {
  // Stream the complete binary diff in a child process: neither a fixed output
  // buffer nor a temporary diff file can truncate a large visual revision.
  return execFileSync(process.execPath, ["-e", `
    const { spawn } = require("node:child_process");
    const { createHash } = require("node:crypto");
    const hash = createHash("sha256");
    const git = spawn("git", ["diff", "--binary", "HEAD"], {
      cwd: process.argv[1], stdio: ["ignore", "pipe", "inherit"],
    });
    git.stdout.on("data", chunk => hash.update(chunk));
    git.on("error", error => { console.error(error.message); process.exitCode = 1; });
    git.on("close", code => {
      if (code !== 0) process.exitCode = code || 1;
      else process.stdout.write(hash.digest("hex"));
    });
  `, workspace], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
}

function validateProductionBuild(web: string): Record<string, string> {
  // Run the shared verifier with Node directly. Playwright's CommonJS test
  // transform must not rewrite the build pipeline's native ESM module.
  return JSON.parse(execFileSync(process.execPath,
    [path.join(web, "scripts/web-build-provenance.mjs"), "check"],
    { cwd: web, encoding: "utf8" }));
}

export function stateEvidenceContextOptions(testInfo: TestInfo): BrowserContextOptions {
  const profile = testInfo.project.use;
  return {
    ...localStateContextOptions(testInfo),
    // Controlled route responses require the browser request to reach the
    // interceptor. Actual service-worker lifecycle is exercised separately.
    serviceWorkers: "block",
    viewport: profile.viewport ?? { width: 1440, height: 900 },
    deviceScaleFactor: profile.deviceScaleFactor ?? 1,
    isMobile: profile.isMobile ?? false,
    hasTouch: profile.hasTouch ?? false,
    userAgent: profile.userAgent,
  };
}

export async function navigateStateEvidence(
  page: Page,
  url: string,
  options?: Parameters<Page["goto"]>[1],
) {
  // Playwright's default page fixture also receives the same fence before its
  // first navigation; all manual contexts use the explicit factory above.
  await guardStateEvidenceContext(page.context());
  const club = localClub();
  if (club && /^\/admin(?:\/|\?|$)/.test(url)) {
    const target = new URL(url, "http://127.0.0.1:3200");
    target.searchParams.set("club", String(club.id));
    url = `${target.pathname}${target.search}${target.hash}`;
  }
  const media = await page.evaluate(() => ({
    colorScheme: matchMedia("(prefers-color-scheme: dark)").matches ? "dark" as const : "light" as const,
    reducedMotion: matchMedia("(prefers-reduced-motion: reduce)").matches ? "reduce" as const : "no-preference" as const,
  }));
  const response = await page.goto(url, options);
  // Firefox loses media emulation when COOP changes the document process.
  // Keep the product's security header and restore the requested test profile.
  await page.emulateMedia(media);
  // The restored scheme can start finite colour transitions. Measure the
  // settled declared state without disabling continuous loading animations.
  await page.evaluate(() => new Promise<void>((resolve) => {
    requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
  }));
  await page.waitForFunction(() => !document.getAnimations().some((animation) =>
    animation instanceof CSSTransition &&
    (animation.pending || animation.playState === "running")), undefined, { timeout: 2_000 });
  return response;
}

function untrackedSource(workspace: string) {
  return execFileSync("git", ["ls-files", "--others", "--exclude-standard", "-z"], { cwd: workspace, encoding: "utf8" })
    .split("\0").filter(Boolean).sort().map((file) => ({
      file, sha256: sha256(fs.readFileSync(path.join(workspace, file))),
    }));
}

async function readCaptureProfile(page: Page) {
  return page.evaluate(() => ({
    viewport: { width: innerWidth, height: innerHeight },
    document: {
      width: Math.max(document.documentElement.scrollWidth, document.body.scrollWidth),
      height: Math.max(document.documentElement.scrollHeight, document.body.scrollHeight),
    },
    device_pixel_ratio: devicePixelRatio,
    user_agent: navigator.userAgent,
    max_touch_points: navigator.maxTouchPoints,
    coarse_pointer: matchMedia("(pointer: coarse)").matches,
    prefers_color_scheme: matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light",
    prefers_reduced_motion: matchMedia("(prefers-reduced-motion: reduce)").matches,
    root_font_size: getComputedStyle(document.documentElement).fontSize,
    surface_color_scheme: getComputedStyle(document.querySelector(".admin-workspace") ?? document.documentElement).colorScheme,
  }));
}

export async function captureStateScreenshot(
  page: Page,
  options: { path: string; fullPage?: boolean; animations?: "disabled" | "allow" },
) {
  const directory = path.dirname(options.path);
  const file = path.basename(options.path);
  const metadataPath = path.join(directory, "capture-profiles.json");
  const existingProfiles = fs.existsSync(metadataPath) ? JSON.parse(fs.readFileSync(metadataPath, "utf8")) : {};
  if (fs.existsSync(options.path) || Object.hasOwn(existingProfiles, file)) {
    throw new Error("Capture filename already has retained evidence");
  }
  const expectedTheme = file.match(/_(dark|light)_(?:desktop|tablet|compact|mobile|viewport)/)?.[1];
  for (let attempt = 1; attempt <= 3; attempt++) {
    await page.evaluate(async () => {
      await document.fonts.ready;
      await new Promise<void>((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => resolve())));
    });
    const profile = await readCaptureProfile(page);
    if (expectedTheme && profile.prefers_color_scheme !== expectedTheme) {
      throw new Error(`Capture theme differs from filename: ${file} (${profile.prefers_color_scheme})`);
    }
    // Keep unstable attempts outside the evidence directory. They remain
    // inspectable, and cannot be mistaken for a finalized route capture.
    const temporary = fs.mkdtempSync(path.join(directory, "../capture-attempt-"));
    const tiles: Array<{ file: string; y: number; height: number }> = [];
    // Preserve every row of long pages within each browser's pixel limits.
    if (options.fullPage && profile.document.height * profile.device_pixel_ratio > 30000) {
      const tileHeight = Math.floor(12000 / profile.device_pixel_ratio);
      for (let y = 0; y < profile.document.height; y += tileHeight) {
        const tile = tiles.length === 0 ? file : file.replace(/\.png$/, `.tile-${tiles.length + 1}.png`);
        const height = Math.min(tileHeight, profile.document.height - y);
        await page.screenshot({ ...options, path: path.join(temporary, tile),
          clip: { x: 0, y, width: profile.document.width, height } });
        tiles.push({ file: tile, y, height });
      }
    } else {
      await page.screenshot({ ...options, path: path.join(temporary, file) });
      tiles.push({ file, y: 0, height: options.fullPage ? profile.document.height : profile.viewport.height });
    }
    const after = await readCaptureProfile(page);
    const dimensions = tiles.map((tile) => {
      const png = fs.readFileSync(path.join(temporary, tile.file));
      return { file: tile.file, width: png.readUInt32BE(16), height: png.readUInt32BE(20),
        expectedWidth: (options.fullPage ? profile.document.width : profile.viewport.width) * profile.device_pixel_ratio,
        expectedHeight: tile.height * profile.device_pixel_ratio };
    });
    const stable = JSON.stringify(profile) === JSON.stringify(after) && dimensions.every((tile) =>
      Math.abs(tile.width - tile.expectedWidth) <= 1 && Math.abs(tile.height - tile.expectedHeight) <= 1);
    if (!stable) {
      fs.writeFileSync(path.join(temporary, "unstable-layout.json"), `${JSON.stringify({
        status: "rejected_unstable_capture", file, attempt, before: profile, after, dimensions,
      }, null, 2)}\n`);
      if (attempt === 3) throw new Error(`Capture geometry did not stabilize: ${file}; inspect ${temporary}`);
      continue;
    }
    const accessibility = await assertLocalRouteState(page, file, directory);
    for (const tile of tiles) fs.renameSync(path.join(temporary, tile.file), path.join(directory, tile.file));
    fs.rmdirSync(temporary);
    const metadata = fs.existsSync(metadataPath) ? JSON.parse(fs.readFileSync(metadataPath, "utf8")) : {};
    metadata[file] = { ...profile, full_page: options.fullPage === true, tiles, accessibility,
      capture_validation: { attempts: attempt, fonts_ready: true, geometry_before_after_stable: true, png_dimensions_verified: true } };
    fs.writeFileSync(metadataPath, `${JSON.stringify(metadata, null, 2)}\n`);
    return;
  }
}

export function prepareStateEvidence(
  browser: Browser,
  testInfo: TestInfo,
  slug: string,
) {
  if (!/^[a-z0-9_]+$/.test(slug)) throw new Error("Invalid evidence directory name");
  // Playwright owns an isolated directory for each project, test and retry.
  // Raw captures stay outside the governed, visually reviewed evidence registry.
  const directory = testInfo.outputPath(slug);
  fs.mkdirSync(directory, { recursive: true });
  const web = process.cwd();
  const productionBuild = validateProductionBuild(web);
  const workspace = path.resolve(web, "../../..");
  const packageVersion = (name: string) => JSON.parse(
    fs.readFileSync(path.join(web, "node_modules", name, "package.json"), "utf8"),
  ).version as string;
  const buildId = fs.readFileSync(path.join(web, ".next/BUILD_ID"), "utf8").trim();
  const record = {
    schema_version: "1.0",
    status: "capture_started_unreviewed",
    started_at: new Date().toISOString(),
    project: testInfo.project.name,
    test_id: testInfo.testId,
    retry: testInfo.retry,
    browser: { name: browser.browserType().name(), version: browser.version() },
    node: process.version,
    next: packageVersion("next"),
    playwright: packageVersion("@playwright/test"),
    next_build_id: buildId,
    production_build: productionBuild,
    package_lock_sha256: sha256(fs.readFileSync(path.join(web, "package-lock.json"))),
    source_commit: execFileSync("git", ["rev-parse", "HEAD"], { cwd: workspace, encoding: "utf8" }).trim(),
    tracked_worktree_diff_sha256: trackedSourceHash(workspace),
    untracked_source: untrackedSource(workspace),
    test_source_sha256: sha256(fs.readFileSync(testInfo.file)),
    test_source_file: path.relative(workspace, testInfo.file),
    provenance_helper_sha256: sha256(fs.readFileSync(path.join(web, "e2e/state-evidence-provenance.ts"))),
    capture_profiles: "Use each state manifest's explicit context dimensions; the project default is not proof of the capture viewport.",
    data_source: "controlled_synthetic_browser_states",
    acceptance: "unreviewed_engineering_evidence",
  };
  fs.writeFileSync(path.join(directory, "runtime-provenance.json"), `${JSON.stringify(record, null, 2)}\n`);
  return directory;
}

export function finalizeStateEvidence(directory: string) {
  const provenancePath = path.join(directory, "runtime-provenance.json");
  const record = JSON.parse(fs.readFileSync(provenancePath, "utf8"));
  const currentBuildId = fs.readFileSync(path.resolve(".next/BUILD_ID"), "utf8").trim();
  if (record.next_build_id !== currentBuildId) throw new Error("Build changed during capture");
  if (JSON.stringify(record.production_build) !== JSON.stringify(validateProductionBuild(process.cwd()))) {
    throw new Error("Production build provenance changed during capture");
  }
  const files = fs.readdirSync(directory).filter((file) => file !== "runtime-provenance.json").sort();
  const manifests = files.filter((file) => file.endsWith("state-evidence.json"));
  const screenshots = files.filter((file) => file.endsWith(".png"));
  if (screenshots.length === 0 || manifests.length !== 1) {
    throw new Error("Evidence needs both screenshots and a state manifest");
  }
  const manifest = JSON.parse(fs.readFileSync(path.join(directory, manifests[0]), "utf8"));
  const profilesPath = path.join(directory, "capture-profiles.json");
  const profiles = fs.existsSync(profilesPath) ? JSON.parse(fs.readFileSync(profilesPath, "utf8")) : {};
  const declared: unknown = manifest.captures?.flatMap((capture: { file: string }) =>
    profiles[capture.file]?.tiles?.map((tile: { file: string }) => tile.file) ?? [capture.file]);
  if (!Array.isArray(declared) || !declared.every((file) => typeof file === "string") ||
      JSON.stringify(declared.sort()) !== JSON.stringify(screenshots)) {
    throw new Error("State manifest and captured screenshot files differ");
  }
  const workspace = path.resolve(process.cwd(), "../../..");
  const currentSource = trackedSourceHash(workspace);
  if (record.tracked_worktree_diff_sha256 !== currentSource) throw new Error("Source changed during capture");
  if (JSON.stringify(record.untracked_source) !== JSON.stringify(untrackedSource(workspace))) {
    throw new Error("Untracked source changed during capture");
  }
  for (const capture of manifest.captures) {
    if (profiles[capture.file]) capture.capture_profile = profiles[capture.file];
  }
  const axeFiles = files.filter((file) => file.endsWith(".axe.json"));
  const captureNames = manifest.captures.map((capture: { file: string }) => capture.file).sort();
  if (new Set(captureNames).size !== captureNames.length ||
      JSON.stringify(Object.keys(profiles).sort()) !== JSON.stringify(captureNames)) {
    throw new Error("State manifest and capture profiles differ");
  }
  const declaredAxe = Object.values(profiles).flatMap((profile) => {
    const accessibility = (profile as { accessibility?: { file: string; sha256: string; tags: string[]; impact_counts: Record<string, number> } }).accessibility;
    if (!accessibility) throw new Error("Explicit capture lacks its full accessibility result");
    if (accessibility.file !== path.basename(accessibility.file)) {
      throw new Error("Accessibility result path leaves the capture directory");
    }
    if (!fs.lstatSync(path.join(directory, accessibility.file)).isFile()) {
      throw new Error("Accessibility result is not a regular retained file");
    }
    const bytes = fs.readFileSync(path.join(directory, accessibility.file));
    const result = JSON.parse(bytes.toString("utf8"));
    const tags = ["wcag2a", "wcag2aa", "wcag21a", "wcag21aa", "wcag22aa"];
    const environment = result.testEnvironment;
    const nonempty = (value: unknown): value is string => typeof value === "string" && value.trim().length > 0;
    let validUrl = false;
    if (nonempty(result.url)) {
      try { new URL(result.url); validUrl = true; } catch { /* Invalid native result URL. */ }
    }
    const parsedTimestamp = nonempty(result.timestamp) ? Date.parse(result.timestamp) : NaN;
    const canonicalTimestamp = Number.isFinite(parsedTimestamp) &&
      new Date(parsedTimestamp).toISOString() === result.timestamp;
    const impacts = ["critical", "serious", "moderate", "minor", "unknown"];
    const impactCounts = Array.isArray(result.violations) ? Object.fromEntries(impacts.map((impact) => [impact,
      result.violations.filter((violation: { impact?: string }) => (violation.impact ?? "unknown") === impact).length,
    ])) : null;
    if (sha256(bytes) !== accessibility.sha256 ||
        JSON.stringify(accessibility.tags) !== JSON.stringify(tags) ||
        result.toolOptions?.runOnly?.type !== "tag" ||
        JSON.stringify(result.toolOptions.runOnly.values) !== JSON.stringify(tags) ||
        !["violations", "incomplete", "passes", "inapplicable"].every((key) => Array.isArray(result[key])) ||
        !nonempty(result.testEngine?.name) || !nonempty(result.testEngine?.version) ||
        !environment || typeof environment !== "object" || Array.isArray(environment) ||
        !nonempty(environment.userAgent) ||
        ![environment.windowWidth, environment.windowHeight].every((value) => Number.isFinite(value) && value > 0) ||
        (environment.orientationAngle !== undefined && !Number.isFinite(environment.orientationAngle)) ||
        (environment.orientationType !== undefined && !nonempty(environment.orientationType)) ||
        !validUrl || !canonicalTimestamp ||
        JSON.stringify(accessibility.impact_counts) !== JSON.stringify(impactCounts) ||
        result.violations.some((violation: { impact?: string }) =>
          violation.impact === "critical" || violation.impact === "serious")) {
      throw new Error("Raw accessibility result or declared WCAG policy differs");
    }
    return [accessibility.file];
  });
  if (JSON.stringify(declaredAxe.sort()) !== JSON.stringify(axeFiles)) {
    throw new Error("Raw accessibility results and capture metadata differ");
  }
  fs.writeFileSync(path.join(directory, manifests[0]), `${JSON.stringify(manifest, null, 2)}\n`);
  record.artifacts = files.map((file) => ({ file, sha256: sha256(fs.readFileSync(path.join(directory, file))) }));
  record.finished_at = new Date().toISOString();
  record.status = "capture_complete_unreviewed";
  fs.writeFileSync(provenancePath, `${JSON.stringify(record, null, 2)}\n`);
}

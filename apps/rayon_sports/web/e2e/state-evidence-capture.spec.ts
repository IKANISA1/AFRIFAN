import fs from "node:fs";
import path from "node:path";
import { expect, test } from "@playwright/test";
import { captureStateScreenshot, finalizeStateEvidence, prepareStateEvidence, navigateStateEvidence } from "./state-evidence-provenance";

test("long pages retain complete screenshot coverage on every engine", async ({ browser, page }, testInfo) => {
  const directory = prepareStateEvidence(browser, testInfo, "capture_regression");
  await page.setViewportSize({ width: 800, height: 600 });
  await page.emulateMedia({ colorScheme: "dark" });
  await page.setContent('<meta name="viewport" content="width=device-width, initial-scale=1"><style>html,body{margin:0;background:#fff}main{height:40000px;background:linear-gradient(#123,#cde)}</style><main>Top of a long accessibility fixture</main><button>End of document</button>');
  const file = "fixture_large_text_dark_desktop_800x600.png";
  await captureStateScreenshot(page, { path: path.join(directory, file), fullPage: true, animations: "disabled" });
  fs.writeFileSync(path.join(directory, "fixture-state-evidence.json"), JSON.stringify({ captures: [{ state: "large_text", file }] }));
  finalizeStateEvidence(directory);
  const manifest = JSON.parse(fs.readFileSync(path.join(directory, "fixture-state-evidence.json"), "utf8"));
  const profile = manifest.captures[0].capture_profile;
  expect(profile.tiles.length).toBeGreaterThan(1);
  let coveredHeight = 0;
  for (const tile of profile.tiles) {
    expect(tile.y).toBe(coveredHeight);
    const png = fs.readFileSync(path.join(directory, tile.file));
    // Fractional DPR clips are quantized to physical pixels by each engine.
    expect(Math.abs(png.readUInt32BE(16) - 800 * profile.device_pixel_ratio)).toBeLessThanOrEqual(1);
    expect(Math.abs(png.readUInt32BE(20) - tile.height * profile.device_pixel_ratio)).toBeLessThanOrEqual(1);
    coveredHeight += tile.height;
  }
  expect(coveredHeight).toBe(profile.document.height);
  await page.getByRole("button", { name: "End of document" }).scrollIntoViewIfNeeded();
  await expect(page.getByRole("button", { name: "End of document" })).toBeVisible();
});

test("a mismatched theme cannot be labelled as a dark capture", async ({ page }, testInfo) => {
  await page.emulateMedia({ colorScheme: "light" });
  await page.setContent("<button>Visible light-mode fixture</button>");
  const file = testInfo.outputPath("fixture_default_dark_desktop_800x600.png");
  await expect(captureStateScreenshot(page, { path: file, fullPage: true })).rejects.toThrow(/Capture theme differs/);
  expect(fs.existsSync(file)).toBe(false);
});

test("COOP navigation preserves dark/light and reduced-motion evidence profiles", async ({ page }) => {
  await page.route("https://qa.invalid/**", (route) => route.fulfill({
    contentType: "text/html",
    headers: { "Cross-Origin-Opener-Policy": "same-origin-allow-popups" },
    body: "<!doctype html><p>Controlled navigation fixture</p>",
  }));
  for (const dark of [true, false]) {
    await page.emulateMedia({ colorScheme: dark ? "dark" : "light", reducedMotion: dark ? "reduce" : "no-preference" });
    await navigateStateEvidence(page, `https://qa.invalid/${dark}`);
    expect(await page.evaluate(() => matchMedia("(prefers-color-scheme: dark)").matches)).toBe(dark);
    expect(await page.evaluate(() => matchMedia("(prefers-reduced-motion: reduce)").matches)).toBe(dark);
  }
});

test("navigation settles finite theme transitions while keeping loading motion active", async ({ page }) => {
  await page.route("https://qa.invalid/**", (route) => route.fulfill({
    contentType: "text/html",
    headers: { "Cross-Origin-Opener-Policy": "same-origin-allow-popups" },
    body: `<!doctype html><style>
      button { background: rgb(14, 116, 144); transition: background-color 500ms linear; }
      html[data-ready] button { background: rgb(165, 243, 252); }
      i { display: block; animation: spin 1s linear infinite; }
      @keyframes spin { to { transform: rotate(360deg); } }
    </style><button>Theme action</button><i>Loading</i><script>
      requestAnimationFrame(() => {
        getComputedStyle(document.querySelector('button')).backgroundColor;
        requestAnimationFrame(() => document.documentElement.dataset.ready = 'true');
      });
    </script>`,
  }));
  await navigateStateEvidence(page, "https://qa.invalid/theme-transition", { waitUntil: "domcontentloaded" });
  await expect(page.getByRole("button")).toHaveCSS("background-color", "rgb(165, 243, 252)", { timeout: 1 });
  expect(await page.locator("i").evaluate((element) => element.getAnimations().some((animation) => animation.playState === "running"))).toBe(true);
});

test("layout changes during a screenshot cannot retain stale geometry", async ({ browser, page }, testInfo) => {
  const directory = prepareStateEvidence(browser, testInfo, "geometry_race_regression");
  await page.setViewportSize({ width: 800, height: 600 });
  await page.emulateMedia({ colorScheme: "dark" });
  await page.setContent('<meta name="viewport" content="width=device-width, initial-scale=1"><style>body{margin:0}main{height:2000px;background:#123;color:#fff}</style><main>Layout race fixture</main>');
  const originalScreenshot = page.screenshot.bind(page);
  let injected = false;
  page.screenshot = async (options) => {
    if (!injected) {
      injected = true;
      await page.locator("main").evaluate((element) => { element.style.height = "3000px"; });
    }
    return originalScreenshot(options);
  };
  const file = "geometry_dark_desktop_800x600.png";
  try {
    await captureStateScreenshot(page, { path: path.join(directory, file), fullPage: true });
  } finally {
    page.screenshot = originalScreenshot;
  }
  const profile = JSON.parse(fs.readFileSync(path.join(directory, "capture-profiles.json"), "utf8"))[file];
  expect(profile.document.height).toBe(3000);
  const png = fs.readFileSync(path.join(directory, file));
  expect(Math.abs(png.readUInt32BE(20) - profile.document.height * profile.device_pixel_ratio)).toBeLessThanOrEqual(1);
  fs.writeFileSync(path.join(directory, "fixture-state-evidence.json"), JSON.stringify({ route: "/fixture", captures: [{ state: "dark", file }] }));
  finalizeStateEvidence(directory);
});

test("persistent layout instability cannot produce a completed capture", async ({ browser, page }, testInfo) => {
  const directory = prepareStateEvidence(browser, testInfo, "unstable_geometry_regression");
  await page.emulateMedia({ colorScheme: "dark" });
  await page.setContent('<style>body{margin:0}main{height:2000px;background:#123}</style><main>Unstable fixture</main>');
  const originalScreenshot = page.screenshot.bind(page);
  let screenshots = 0;
  page.screenshot = async (options) => {
    screenshots++;
    await page.locator("main").evaluate((element, height) => { element.style.height = `${height}px`; }, 2000 + screenshots * 500);
    return originalScreenshot(options);
  };
  const file = "unstable_dark_desktop_800x600.png";
  try {
    await expect(captureStateScreenshot(page, { path: path.join(directory, file), fullPage: true })).rejects.toThrow(/Capture geometry did not stabilize/);
  } finally {
    page.screenshot = originalScreenshot;
  }
  expect(screenshots).toBe(3);
  expect(fs.existsSync(path.join(directory, file))).toBe(false);
  expect(fs.existsSync(path.join(directory, "capture-profiles.json"))).toBe(false);
  expect(JSON.parse(fs.readFileSync(path.join(directory, "runtime-provenance.json"), "utf8")).status).toBe("capture_started_unreviewed");
});

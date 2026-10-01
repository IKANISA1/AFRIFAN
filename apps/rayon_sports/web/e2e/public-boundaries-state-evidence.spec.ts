import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";
import { prepareStateEvidence, finalizeStateEvidence, captureStateScreenshot, navigateStateEvidence } from "./state-evidence-provenance";

let evidenceDirectory: string;

test.beforeEach(async ({ browser }, testInfo) => {
  test.setTimeout(360_000);
  evidenceDirectory = prepareStateEvidence(browser, testInfo, "consumer_web_boundary_states");
});
test.afterEach(async ({}, testInfo) => {
  if (testInfo.status === "passed") finalizeStateEvidence(evidenceDirectory);
});

const components = [
  ["site-error", "src/app/(site)/error.tsx"],
  ["site-loading", "src/app/(site)/loading.tsx"],
  ...["fixtures", "fan-clubs", "membership", "squad", "shop", "news", "standings"].map((name) => [
    `${name}-loading`, `src/app/(site)/${name}/loading.tsx`,
  ]),
];
let componentMarkup: Record<string, string>;
test.beforeAll(() => {
  // Playwright transforms TSX into its component-test descriptor, not React
  // elements. Render the real source with the installed React/esbuild runtime
  // in Node so this visual fixture contains actual production component markup.
  const entry = `import {createElement} from 'react';
    import {renderToStaticMarkup} from 'react-dom/server';
    ${components.map(([, file], index) => `import C${index} from ${JSON.stringify(path.resolve(file))};`).join("\n")}
    module.exports = {${components.map(([name], index) => `${JSON.stringify(name)}: renderToStaticMarkup(createElement(C${index}, ${index === 0 ? "{error:new Error('Private diagnostic'), reset(){}}" : "{}"}))`).join(",")}};`;
  componentMarkup = JSON.parse(execFileSync(process.execPath, ["--input-type=module", "-e", `
    import {buildSync} from 'esbuild';
    import {createRequire} from 'node:module';
    const result = buildSync({stdin:{contents:${JSON.stringify(entry)},resolveDir:process.cwd()},bundle:true,write:false,platform:'node',format:'cjs',jsx:'automatic',packages:'external'});
    const mod={exports:{}};
    new Function('require','module','exports',result.outputFiles[0].text)(createRequire(process.cwd()+'/package.json'),mod,mod.exports);
    process.stdout.write(JSON.stringify(mod.exports));
  `], { encoding: "utf8" }));
});
const cases = [
  { name: "not-found", route: "/not-found", kind: "Rendered missing-route response" },
  ...components.map(([name]) => ({name, route: `/__components__/${name}`, kind: name === 'site-error'
    ? "Rendered component fixture; boundary triggering is not exercised"
    : "Rendered component fixture; asynchronous routing is not exercised"})),
];

for (const fixture of cases) {
  test(`${fixture.name} exposes responsive, themed frontend evidence`, async ({ page }) => {
    const captures: Array<{ state: string; file: string; fixture_kind: string }> = [];
    for (const state of ["dark", "light", "large_text", "reduced_motion"] as const) {
      await page.emulateMedia({ colorScheme: state === "light" ? "light" : "dark", reducedMotion: state === "reduced_motion" ? "reduce" : "no-preference" });
      const response = await navigateStateEvidence(page, fixture.name !== "not-found" ? "/contact" : fixture.route, { waitUntil: "networkidle" });
      if (fixture.name !== "not-found") {
        // Keep the real document, compiled CSS, fonts and navigation. Only the
        // route body is a static rendering of the actual production component.
        // These captures are explicitly not runtime boundary/lifecycle proof.
        await page.locator("#main-content").evaluate((element, markup) => {
          element.setAttribute("data-local-component-fixture", "true");
          element.innerHTML = markup;
        }, componentMarkup[fixture.name]);
      } else {
        expect(response?.status()).toBe(404);
        await expect(page.getByRole("heading", { name: "Page not found" })).toBeVisible();
        await expect(page.getByRole("link", { name: "Return home" })).toHaveAttribute("href", "/");
        // This deliberately missing destination is outside the declared route
        // catalog; preserve its boundary evidence without crediting a route.
        await page.locator("body").evaluate((element) => element.setAttribute("data-local-component-fixture", "missing-route-boundary"));
      }
      if (fixture.name.endsWith("loading")) await expect(page.getByRole("status")).toContainText("Loading page…");
      if (fixture.name === "site-error") {
        await expect(page.getByRole("button", { name: "Retry" })).toBeVisible();
        await expect(page.getByText("Private diagnostic")).toHaveCount(0);
      }
      if (state === "large_text") await page.evaluate(() => {
    document.documentElement.style.setProperty("font-size", "200%", "important");
  });
      await expect.poll(() => page.evaluate(() => document.documentElement.scrollWidth - innerWidth)).toBeLessThanOrEqual(1);
      for (const action of await page.locator(".recovery-action").all()) expect((await action.boundingBox())!.height).toBeGreaterThanOrEqual(48);
      const results = await new AxeBuilder({ page }).withTags(["wcag2a", "wcag2aa", "wcag22aa"]).analyze();
      expect(results.violations.filter((item) => item.impact === "serious" || item.impact === "critical")).toEqual([]);
      const file = `${fixture.name.replaceAll("-", "_")}_state_${state}_${state === "light" ? "light" : "dark"}_viewport.png`;
      await captureStateScreenshot(page, { path: path.join(evidenceDirectory, file), fullPage: true, animations: "disabled" });
      captures.push({ state, file, fixture_kind: fixture.kind });
    }
    fs.writeFileSync(path.join(evidenceDirectory, "boundary-state-evidence.json"), JSON.stringify({
      route: fixture.route, surface: "consumer_web", fixture_kind: fixture.kind,
      applicable_states: ["dark", "light", "large_text", "reduced_motion"],
      not_applicable_states: [],
      scope: "Visual component review. Retry behavior is covered by the existing recovery-page unit suite; static fixtures do not certify boundary triggering or route loading lifecycle.",
      captures,
    }, null, 2));
  });
}

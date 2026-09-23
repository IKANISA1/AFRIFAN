import { expect, test } from "@playwright/test";
import { createServer, request as httpRequest } from "node:http";
import type { AddressInfo } from "node:net";
import { writeFile } from "node:fs/promises";
import AxeBuilder from "@axe-core/playwright";

// Drop the actual origin connection after activation. Browser offline emulation
// does not consistently reach service-worker fetches in all three engines.
async function originConnection(controlledCms = false) {
  let disconnected = false;
  let workerRevision = 1;
  const server = createServer((request, response) => {
    if (disconnected) { request.socket.destroy(); return; }
    const pathname = new URL(request.url ?? "/", "http://127.0.0.1").pathname;
    if (controlledCms && pathname === "/api/admin/cms" && request.method === "GET") {
      response.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
      response.end(JSON.stringify({ data: [] }));
      return;
    }
    const upstream = httpRequest({
      hostname: "127.0.0.1", port: 3200, path: request.url,
      method: request.method, headers: { ...request.headers, host: "127.0.0.1:3200", "accept-encoding": "identity" },
    }, (result) => {
      if (pathname === "/sw.js") {
        const chunks: Buffer[] = [];
        result.on("data", (chunk: Buffer) => chunks.push(chunk));
        result.on("end", () => {
          // Exercise actual browser worker installation without changing the
          // production artifact or claiming a deployed version migration.
          response.writeHead(200, { "Content-Type": "text/javascript", "Cache-Control": "no-store" });
          response.end(Buffer.concat(chunks).toString() + `\n// controlled-worker-revision-${workerRevision}\n`);
        });
        return;
      }
      response.writeHead(result.statusCode ?? 502, result.headers);
      result.pipe(response);
    });
    upstream.on("error", () => response.destroy());
    request.pipe(upstream);
  });
  await new Promise<void>((resolve, reject) => { server.once("error", reject); server.listen(0, "127.0.0.1", resolve); });
  return {
    origin: `http://127.0.0.1:${(server.address() as AddressInfo).port}`,
    disconnect: () => { disconnected = true; },
    reconnect: () => { disconnected = false; },
    updateWorker: () => { workerRevision += 1; },
    close: () => { server.closeAllConnections(); server.close(); },
  };
}

test("PWA offline controls survive unavailable preference storage", async ({ page, context }) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.addInitScript(() => {
    for (const method of ["getItem", "setItem", "removeItem"] as const) {
      const original = Storage.prototype[method];
      Object.defineProperty(Storage.prototype, method, {
        configurable: true,
        value(key: string, ...values: string[]) {
          if (/^africlub-(?:pwa|.*install)/.test(key)) {
            throw new DOMException("QA preference storage denied", "SecurityError");
          }
          return Reflect.apply(original, this, [key, ...values]);
        },
      });
    }
  });
  await page.goto("/admin", { waitUntil: "domcontentloaded" });
  await expect(page.locator("html")).toHaveAttribute("data-africlub-network-observer", "ready", { timeout: 20_000 });
  await context.setOffline(true);
  await expect(page.getByText(/You’re offline\. The admin shell/)).toBeVisible();
  await context.setOffline(false);
  await expect(page.getByText(/You’re offline\. The admin shell/)).toHaveCount(0);
  expect(errors).toEqual([]);
});

test("worker updates preserve unfinished CMS drafts in the editing and older tabs", async ({ page, context }, testInfo) => {
  const connection = await originConnection(true);
  const other = await context.newPage();
  const url = connection.origin + "/admin/cms?evidence=pwa-update";
  try {
    await page.goto(url, { waitUntil: "domcontentloaded" });
    await expect.poll(() => page.evaluate(() => navigator.serviceWorker.controller?.state), { timeout: 20_000 }).toBe("activated");
    await other.goto(url, { waitUntil: "domcontentloaded" });
    await page.getByRole("textbox", { name: "Title", exact: true }).fill("Unfinished current-tab article");
    await other.getByRole("textbox", { name: "Title", exact: true }).fill("Unfinished older-tab article");
    connection.updateWorker();
    await page.evaluate(async () => { await (await navigator.serviceWorker.ready).update(); });
    await page.getByRole("button", { name: "Refresh app", exact: true }).click();
    await expect(page.getByRole("button", { name: "Keep editing" })).toBeFocused();
    await page.getByRole("button", { name: "Keep editing" }).click();
    await expect(page.getByRole("textbox", { name: "Title", exact: true })).toHaveValue("Unfinished current-tab article");
    expect(await page.evaluate(async () => (await navigator.serviceWorker.ready).waiting?.state)).toBe("installed");
    await page.getByRole("button", { name: "Refresh app", exact: true }).click();
    for (const name of ["Keep editing", "Refresh now"]) {
      const box = await page.getByRole("button", { name, exact: true }).boundingBox();
      expect(box?.height).toBeGreaterThanOrEqual(48);
      expect(box?.width).toBeGreaterThanOrEqual(48);
    }
    for (const colorScheme of ["light", "dark"] as const) {
      await page.emulateMedia({ colorScheme, reducedMotion: "reduce" });
      const result = await new AxeBuilder({ page }).include("[data-pwa-shell]").withRules(["color-contrast", "button-name"]).analyze();
      expect(result.violations, `${colorScheme} update controls`).toEqual([]);
      await page.screenshot({ path: testInfo.outputPath(`update-${colorScheme}.png`) });
    }
    const confirmation = testInfo.outputPath("unfinished-update-confirmation.png");
    await page.screenshot({ path: confirmation });
    await testInfo.attach("unfinished-update-confirmation.png", { path: confirmation, contentType: "image/png" });
    const navigation = page.waitForEvent("framenavigated", (frame) => frame === page.mainFrame());
    await page.getByRole("button", { name: "Refresh now", exact: true }).click();
    await navigation;
    await expect(page.getByRole("textbox", { name: "Title", exact: true })).toHaveValue("");
    await expect(other.getByRole("textbox", { name: "Title", exact: true })).toHaveValue("Unfinished older-tab article");
    expect(await page.evaluate(async () => (await navigator.serviceWorker.ready).waiting)).toBeNull();
    const olderDraft = testInfo.outputPath("older-tab-draft-preserved.png");
    await other.screenshot({ path: olderDraft });
    await testInfo.attach("older-tab-draft-preserved.png", { path: olderDraft, contentType: "image/png" });
  } finally { await other.close(); connection.close(); }
});

test("actual service worker protects private membership after origin connection loss", async ({ page }, testInfo) => {
  const connection = await originConnection();
  try {
  await page.goto(connection.origin + "/", { waitUntil: "domcontentloaded" });
  expect(await page.evaluate(() => "serviceWorker" in navigator)).toBe(true);
  await expect.poll(() => page.evaluate(() => navigator.serviceWorker.controller?.state), { timeout: 20_000 }).toBe("activated");
  await page.goto(connection.origin + "/membership", { waitUntil: "domcontentloaded" });
  await expect(page.locator(".member-portal")).toBeVisible();
  const privateSnapshots = await page.evaluate(async () => {
    const paths: string[] = [];
    for (const name of await caches.keys()) {
      if (!/^gikundiro-pages-/.test(name)) continue;
      for (const request of await (await caches.open(name)).keys()) {
        const pathname = new URL(request.url).pathname;
        if (/^\/(?:admin|supporters|membership)(?:\/|$)/.test(pathname)) paths.push(pathname);
      }
    }
    return paths;
  });
  expect(privateSnapshots).toEqual([]);
  connection.disconnect();
  const response = await page.goto(connection.origin + "/membership", { waitUntil: "domcontentloaded" });
  const originEvidence = testInfo.outputPath("worker-origin-loss.json");
  await writeFile(originEvidence, JSON.stringify({ status: response?.status(), fromServiceWorker: response?.fromServiceWorker(), privateSnapshots, scope: "Actual origin socket loss through a loopback forwarding proxy; no browser offline-emulation claim." }, null, 2));
  await testInfo.attach("worker-origin-loss.json", { contentType: "application/json", path: originEvidence });
  expect(response?.fromServiceWorker()).toBe(true);
  expect(response?.headers()["x-africlub-offline"]).toBe("1");
  await expect(page.locator(".member-portal")).toHaveCount(0);
  await expect(page.getByRole("heading", { name: "Cached pages stay available" })).toBeVisible();
  await page.screenshot({ path: testInfo.outputPath("offline-recovery.png") });
  connection.reconnect();
  await page.goto(connection.origin + "/membership", { waitUntil: "domcontentloaded" });
  await expect(page.locator(".member-portal")).toBeVisible();
  } finally { connection.close(); }
});

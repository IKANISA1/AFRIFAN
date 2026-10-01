import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import test from "node:test";
import { chromium } from "@playwright/test";
import { createStateEvidenceContext, guardStateEvidenceContext, stateEvidenceNetworkCounts } from "./local-browser-network.mjs";

test("every manual state context uses the explicit guarded factory", () => {
  const directory = path.resolve("e2e");
  const suites = fs.readdirSync(directory).filter((file) => file.endsWith("state-evidence.spec.ts"));
  assert.equal(suites.length, 46);
  for (const file of suites) {
    const source = fs.readFileSync(path.join(directory, file), "utf8");
    assert.equal(source.includes("browser.newContext("), false, file);
  }
  assert.match(fs.readFileSync(path.join(directory, "state-evidence-provenance.ts"), "utf8"), /await guardStateEvidenceContext\(page.context\(\)\)/);
});

test("actual Chromium permits loopback and controlled fulfillment while denying other HTTP and WebSocket origins", { timeout: 30_000 }, async () => {
  const server = http.createServer((_, response) => {
    response.writeHead(200, { "content-type": "text/html" });
    response.end("<!doctype html><title>Local fixture</title><p>Local response</p>");
  });
  let allowedWebSocketRequests = 0;
  let disallowedWebSocketRequests = 0;
  const upgradedSockets = new Set();
  const disallowedOrigin = http.createServer((_, response) => {
    response.writeHead(403);
    response.end();
  });
  server.on("upgrade", (request, socket) => {
    upgradedSockets.add(socket);
    socket.once("close", () => upgradedSockets.delete(socket));
    allowedWebSocketRequests++;
    const accept = createHash("sha1").update(request.headers["sec-websocket-key"] + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").digest("base64");
    socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
    socket.end(Buffer.from([0x88, 0x02, 0x03, 0xe8]));
  });
  disallowedOrigin.on("upgrade", (_, socket) => {
    upgradedSockets.add(socket);
    socket.once("close", () => upgradedSockets.delete(socket));
    disallowedWebSocketRequests++;
    socket.end("HTTP/1.1 403 Forbidden\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
  });
  await new Promise((resolve, reject) => server.listen(3200, "127.0.0.1", resolve).once("error", reject));
  let browser;
  try {
    await new Promise((resolve, reject) => disallowedOrigin.listen(0, "127.0.0.1", resolve).once("error", reject));
    browser = await chromium.launch({ channel: "chromium" });
    const context = await createStateEvidenceContext(browser, {});
    const page = await context.newPage();
    assert.equal((await page.goto("http://127.0.0.1:3200"))?.status(), 200);
    assert.equal(await page.locator("p").textContent(), "Local response");
    for (const denied of ["https://unhandled-fixture.invalid", "http://127.0.0.1:3201"]) {
      const probe = await context.newPage();
      await assert.rejects(probe.goto(denied, { timeout: 5_000 }), /ERR_BLOCKED_BY_CLIENT/);
      await probe.close();
    }
    await context.route("https://controlled-fixture.invalid/**", (route) => route.fulfill({ contentType: "text/html", body: "<p>Controlled response</p>" }));
    assert.equal((await page.goto("https://controlled-fixture.invalid/asset"))?.status(), 200);
    assert.equal(await page.locator("p").textContent(), "Controlled response");
    // Default page fixture guard is idempotent and cannot replace handlers.
    await guardStateEvidenceContext(context);
    assert.equal((await page.goto("http://127.0.0.1:3200"))?.status(), 200);
    for (const port of [3200, disallowedOrigin.address().port]) {
      const outcome = await page.evaluate((ownedPort) => new Promise((resolve) => {
        const socket = new WebSocket(`ws://127.0.0.1:${ownedPort}/transport-probe`);
        const timeout = setTimeout(() => { socket.close(); resolve("timeout"); }, 3000);
        socket.onerror = () => { clearTimeout(timeout); resolve("error"); };
        socket.onclose = () => { clearTimeout(timeout); resolve("closed"); };
      }), port);
      assert.notEqual(outcome, "timeout");
    }
    assert.equal(allowedWebSocketRequests, 1);
    assert.equal(disallowedWebSocketRequests, 0);
    assert.deepEqual(stateEvidenceNetworkCounts(context), {
      httpAllowed: 2, httpBlocked: 2, webSocketAllowed: 1, webSocketBlocked: 1,
    });
    console.log(JSON.stringify({
      actualChromiumTransport: true, allowedWebSocketRequests,
      disallowedWebSocketRequests, finiteFenceCounts: stateEvidenceNetworkCounts(context),
    }));
    await context.close();
    const raw = await browser.newContext();
    await guardStateEvidenceContext(raw);
    await assert.rejects((await raw.newPage()).goto("https://default-fixture.invalid", { timeout: 5_000 }), /ERR_BLOCKED_BY_CLIENT/);
    await raw.close();
  } finally {
    await browser?.close();
    // HTTP server.close() does not own sockets transferred by Upgrade.
    for (const socket of upgradedSockets) socket.destroy();
    await new Promise((resolve) => server.close(resolve));
    if (disallowedOrigin.listening) await new Promise((resolve) => disallowedOrigin.close(resolve));
  }
});

import assert from "node:assert/strict";
import { createServer } from "node:http";
import { after, before, test } from "node:test";
import {
  parseArguments,
  validateReleaseUrl,
} from "./validate-cloudflare-release.mjs";

let server;
let baseUrl;

const securityHeaders = {
  "content-security-policy": "default-src 'self'; frame-ancestors 'none'",
  "referrer-policy": "strict-origin-when-cross-origin",
  "x-content-type-options": "nosniff",
  "x-frame-options": "DENY",
  "x-permitted-cross-domain-policies": "none",
};
const associationHeaders = {
  "access-control-allow-origin": "*",
  "cache-control": "public, max-age=300, s-maxage=3600",
  "content-type": "application/json; charset=utf-8",
  "cross-origin-resource-policy": "cross-origin",
  "x-content-type-options": "nosniff",
};
const playAppSigningFingerprint =
  "B8:B4:84:C9:3D:80:83:12:9C:90:1B:D4:9C:BE:35:65:7B:C1:4D:38:F3:D9:19:04:75:45:83:B5:AB:BC:E5:D9";
const absentPlayFingerprint =
  "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";

before(async () => {
  server = createServer((request, response) => {
    if (request.url === "/.well-known/assetlinks.json") {
      response.writeHead(200, associationHeaders);
      response.end(
        JSON.stringify([
          {
            relation: ["delegate_permission/common.handle_all_urls"],
            target: {
              namespace: "android_app",
              package_name: "rw.gikundiro.app",
              sha256_cert_fingerprints: [playAppSigningFingerprint],
            },
          },
        ]),
      );
      return;
    }
    if (request.url === "/.well-known/apple-app-site-association") {
      response.writeHead(200, associationHeaders);
      response.end(
        JSON.stringify({
          applinks: {
            details: [
              {
                appIDs: ["63STJ5N27W.rw.ikanisa.rayonSports"],
                components: [
                  { "/": "/account-deletion*", exclude: true },
                  { "/": "/*" },
                ],
              },
            ],
          },
        }),
      );
      return;
    }
    if (request.url === "/api/admin/tickets") {
      response.writeHead(401, {
        "cache-control": "no-store",
        "content-type": "application/json; charset=utf-8",
      });
      response.end(
        JSON.stringify({ code: "ADMIN_AUTHENTICATION_REQUIRED" }),
      );
      return;
    }

    const markers = {
      "/privacy": 'data-legal-document="privacy"',
      "/terms": 'data-legal-document="terms"',
      "/support": 'data-support-kind="support"',
      "/account-deletion": 'data-support-kind="account-deletion"',
    };
    const marker = markers[request.url ?? ""];
    if (marker) {
      response.writeHead(200, {
        "content-type": "text/html; charset=utf-8",
        ...securityHeaders,
      });
      response.end(`<html><body><main ${marker}></main></body></html>`);
      return;
    }
    response.writeHead(404).end();
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  await new Promise((resolve, reject) =>
    server.close((error) => (error ? reject(error) : resolve())),
  );
});

test("parses repeated URLs and optional output controls", () => {
  assert.deepEqual(
    parseArguments([
      "--url",
      "https://gikundiro.com/privacy",
      "--url",
      "https://admin.gikundiro.com",
      "--output",
      "report.json",
    ]),
    {
      help: false,
      urls: ["https://gikundiro.com", "https://admin.gikundiro.com"],
      output: "report.json",
      expectedAndroidFingerprint: null,
    },
  );
});

test("accepts a complete local release contract", async () => {
  const report = await validateReleaseUrl(baseUrl);
  assert.equal(report.pass, true, JSON.stringify(report.failures));
  assert.equal(report.checks.length, 6);
});

test("fails when the requested Play fingerprint is absent", async () => {
  const report = await validateReleaseUrl(baseUrl, {
    expectedAndroidFingerprint: absentPlayFingerprint,
  });
  assert.equal(report.pass, false);
  assert.ok(
    report.failures.includes(
      "/.well-known/assetlinks.json: Play app-signing fingerprint missing",
    ),
  );
});

test("validates the unauthenticated JSON boundary on the admin hostname", async () => {
  const fetchImpl = (input, init) => {
    const requested = new URL(input);
    const local = new URL(baseUrl);
    local.pathname = requested.pathname;
    local.search = requested.search;
    return fetch(local, init);
  };
  const report = await validateReleaseUrl("http://admin.gikundiro.com", {
    fetchImpl,
  });

  assert.equal(report.pass, true, JSON.stringify(report.failures));
  assert.equal(report.checks.length, 7);
  assert.equal(report.checks.at(-1).path, "/api/admin/tickets");
});

test("rejects a malformed Play certificate fingerprint argument", () => {
  assert.throws(
    () =>
      parseArguments([
        "--url",
        "https://gikundiro.com",
        "--play-fingerprint",
        "FF:EE",
      ]),
    /colon-delimited SHA-256/,
  );
});

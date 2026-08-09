#!/usr/bin/env node

import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const htmlContracts = [
  { path: "/privacy", marker: 'data-legal-document="privacy"' },
  { path: "/terms", marker: 'data-legal-document="terms"' },
  { path: "/support", marker: 'data-support-kind="support"' },
  {
    path: "/account-deletion",
    marker: 'data-support-kind="account-deletion"',
  },
];

const requiredSecurityHeaders = new Map([
  ["content-security-policy", /default-src 'self'/],
  ["referrer-policy", /strict-origin-when-cross-origin/],
  ["x-content-type-options", /^nosniff$/i],
  ["x-frame-options", /^DENY$/i],
  ["x-permitted-cross-domain-policies", /^none$/i],
]);
const sha256FingerprintPattern = /^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$/;

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

export function parseArguments(argv) {
  const urls = [];
  let output = null;
  let expectedAndroidFingerprint = null;

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === "--url") {
      urls.push(argv[index + 1] ?? "");
      index += 1;
    } else if (argument === "--output") {
      output = argv[index + 1] ?? null;
      index += 1;
    } else if (argument === "--play-fingerprint") {
      expectedAndroidFingerprint = (argv[index + 1] ?? "")
        .trim()
        .toUpperCase();
      if (!sha256FingerprintPattern.test(expectedAndroidFingerprint)) {
        throw new Error(
          "--play-fingerprint must be a colon-delimited SHA-256 certificate fingerprint.",
        );
      }
      index += 1;
    } else if (argument === "--help" || argument === "-h") {
      return { help: true, urls: [], output: null, expectedAndroidFingerprint: null };
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }

  const normalizedUrls = urls.map((value) => {
    const parsed = new URL(value);
    parsed.pathname = "/";
    parsed.search = "";
    parsed.hash = "";
    return parsed.toString().replace(/\/$/, "");
  });

  return {
    help: false,
    urls: normalizedUrls,
    output,
    expectedAndroidFingerprint,
  };
}

function headerCheck(headers, name, pattern, failures) {
  const value = headers.get(name);
  if (!value || !pattern.test(value)) {
    failures.push(`${name} missing or invalid`);
  }
}

function associationHeaderChecks(result, failures) {
  if (result.headers.get("access-control-allow-origin") !== "*") {
    failures.push("public CORS header is not wildcard");
  }
  headerCheck(
    result.headers,
    "cache-control",
    /(?:^|,\s*)s-maxage=\d+/i,
    failures,
  );
  headerCheck(
    result.headers,
    "cross-origin-resource-policy",
    /^cross-origin$/i,
    failures,
  );
  headerCheck(
    result.headers,
    "x-content-type-options",
    /^nosniff$/i,
    failures,
  );
}

async function fetchContract(baseUrl, contract, fetchImpl) {
  const url = new URL(contract.path, `${baseUrl}/`).toString();
  const response = await fetchImpl(url, {
    method: contract.method ?? "GET",
    redirect: contract.direct ? "manual" : "follow",
    signal: AbortSignal.timeout(15_000),
    headers: { Accept: contract.accept },
  });
  const body = await response.text();
  return {
    url,
    status: response.status,
    redirected: response.redirected,
    location: response.headers.get("location"),
    headers: response.headers,
    body,
    bodySha256: sha256(body),
  };
}

export async function validateReleaseUrl(
  baseUrl,
  { fetchImpl = fetch, expectedAndroidFingerprint = null } = {},
) {
  const failures = [];
  const checks = [];
  const releaseUrl = new URL(baseUrl);
  const isWorkerPreview = releaseUrl.hostname.endsWith(".workers.dev");

  for (const contract of htmlContracts) {
    const result = await fetchContract(
      baseUrl,
      { ...contract, accept: "text/html", direct: false },
      fetchImpl,
    );
    const contractFailures = [];
    if (result.status !== 200) contractFailures.push(`status ${result.status}`);
    if (!result.headers.get("content-type")?.includes("text/html")) {
      contractFailures.push("content-type is not text/html");
    }
    if (!result.body.includes(contract.marker)) {
      contractFailures.push(`missing rendered marker ${contract.marker}`);
    }
    for (const [name, pattern] of requiredSecurityHeaders) {
      headerCheck(result.headers, name, pattern, contractFailures);
    }
    if (releaseUrl.protocol === "https:") {
      headerCheck(
        result.headers,
        "strict-transport-security",
        /max-age=\d+/,
        contractFailures,
      );
    }
    if (isWorkerPreview) {
      headerCheck(
        result.headers,
        "x-robots-tag",
        /(?:^|,\s*)noindex(?:,|$)/i,
        contractFailures,
      );
    }

    failures.push(...contractFailures.map((failure) => `${contract.path}: ${failure}`));
    checks.push({
      path: contract.path,
      status: result.status,
      contentType: result.headers.get("content-type"),
      bodySha256: result.bodySha256,
      pass: contractFailures.length === 0,
      failures: contractFailures,
    });
  }

  const android = await fetchContract(
    baseUrl,
    {
      path: "/.well-known/assetlinks.json",
      accept: "application/json",
      direct: true,
    },
    fetchImpl,
  );
  const androidFailures = [];
  if (android.status !== 200) androidFailures.push(`status ${android.status}`);
  if (android.location || android.redirected) androidFailures.push("response redirected");
  if (!android.headers.get("content-type")?.includes("application/json")) {
    androidFailures.push("content-type is not application/json");
  }
  associationHeaderChecks(android, androidFailures);
  try {
    const document = JSON.parse(android.body);
    const statement = document.find?.(
      (candidate) =>
        candidate?.target?.package_name === "rw.gikundiro.app" &&
        candidate?.target?.namespace === "android_app" &&
        candidate?.relation?.includes?.(
          "delegate_permission/common.handle_all_urls",
        ),
    );
    const target = statement?.target;
    if (!target) {
      androidFailures.push("rw.gikundiro.app handle-all-urls statement missing");
    }
    const fingerprints = target?.sha256_cert_fingerprints ?? [];
    if (!Array.isArray(fingerprints) || fingerprints.length === 0) {
      androidFailures.push("certificate fingerprints missing");
    } else if (
      fingerprints.some(
        (fingerprint) =>
          typeof fingerprint !== "string" ||
          !sha256FingerprintPattern.test(fingerprint),
      )
    ) {
      androidFailures.push("certificate fingerprint format is invalid");
    }
    if (
      expectedAndroidFingerprint &&
      !fingerprints.includes(expectedAndroidFingerprint)
    ) {
      androidFailures.push("Play app-signing fingerprint missing");
    }
  } catch {
    androidFailures.push("invalid JSON");
  }
  failures.push(
    ...androidFailures.map(
      (failure) => `/.well-known/assetlinks.json: ${failure}`,
    ),
  );
  checks.push({
    path: "/.well-known/assetlinks.json",
    status: android.status,
    contentType: android.headers.get("content-type"),
    bodySha256: android.bodySha256,
    pass: androidFailures.length === 0,
    failures: androidFailures,
  });

  const apple = await fetchContract(
    baseUrl,
    {
      path: "/.well-known/apple-app-site-association",
      accept: "application/json",
      direct: true,
    },
    fetchImpl,
  );
  const appleFailures = [];
  if (apple.status !== 200) appleFailures.push(`status ${apple.status}`);
  if (apple.location || apple.redirected) appleFailures.push("response redirected");
  if (!apple.headers.get("content-type")?.includes("application/json")) {
    appleFailures.push("content-type is not application/json");
  }
  associationHeaderChecks(apple, appleFailures);
  try {
    const document = JSON.parse(apple.body);
    const details = document?.applinks?.details;
    const productionDetail = details?.find?.((detail) =>
      detail?.appIDs?.includes?.("63STJ5N27W.rw.ikanisa.rayonSports"),
    );
    if (!productionDetail) {
      appleFailures.push("production Apple application id missing");
    } else {
      const components = productionDetail.components ?? [];
      const hasPublicDeletionExclusion = components.some(
        (component) =>
          component?.["/"] === "/account-deletion*" &&
          component?.exclude === true,
      );
      const hasSupportedLinkCatchAll = components.some(
        (component) =>
          component?.["/"] === "/*" && component?.exclude !== true,
      );
      if (!hasPublicDeletionExclusion) {
        appleFailures.push("public account-deletion exclusion missing");
      }
      if (!hasSupportedLinkCatchAll) {
        appleFailures.push("supported-link catch-all missing");
      }
    }
  } catch {
    appleFailures.push("invalid JSON");
  }
  failures.push(
    ...appleFailures.map(
      (failure) => `/.well-known/apple-app-site-association: ${failure}`,
    ),
  );
  checks.push({
    path: "/.well-known/apple-app-site-association",
    status: apple.status,
    contentType: apple.headers.get("content-type"),
    bodySha256: apple.bodySha256,
    pass: appleFailures.length === 0,
    failures: appleFailures,
  });

  if (releaseUrl.hostname === "admin.gikundiro.com") {
    const adminBoundary = await fetchContract(
      baseUrl,
      {
        path: "/api/admin/tickets",
        accept: "application/json",
        direct: true,
      },
      fetchImpl,
    );
    const adminFailures = [];
    if (adminBoundary.status !== 401) {
      adminFailures.push(`expected unauthenticated status 401, received ${adminBoundary.status}`);
    }
    if (!adminBoundary.headers.get("content-type")?.includes("application/json")) {
      adminFailures.push("content-type is not application/json");
    }
    headerCheck(
      adminBoundary.headers,
      "cache-control",
      /(?:^|,\s*)no-store(?:,|$)/i,
      adminFailures,
    );
    try {
      const document = JSON.parse(adminBoundary.body);
      if (document?.code !== "ADMIN_AUTHENTICATION_REQUIRED") {
        adminFailures.push("controlled authentication code missing");
      }
    } catch {
      adminFailures.push("invalid JSON");
    }
    failures.push(
      ...adminFailures.map(
        (failure) => `/api/admin/tickets: ${failure}`,
      ),
    );
    checks.push({
      path: "/api/admin/tickets",
      status: adminBoundary.status,
      contentType: adminBoundary.headers.get("content-type"),
      bodySha256: adminBoundary.bodySha256,
      pass: adminFailures.length === 0,
      failures: adminFailures,
    });
  }

  return {
    baseUrl,
    hostname: releaseUrl.hostname,
    pass: failures.length === 0,
    failures,
    checks,
  };
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    console.log(
      "Usage: npm run validate:cloudflare-release -- --url https://host [--url https://host] [--play-fingerprint AA:..] [--output report.json]",
    );
    return;
  }
  if (options.urls.length === 0) {
    throw new Error("Provide at least one --url.");
  }

  const hosts = [];
  for (const url of options.urls) {
    hosts.push(
      await validateReleaseUrl(url, {
        expectedAndroidFingerprint: options.expectedAndroidFingerprint,
      }),
    );
  }
  const report = {
    schemaVersion: 1,
    generatedAt: new Date().toISOString(),
    pass: hosts.every((host) => host.pass),
    expectedAndroidFingerprint: options.expectedAndroidFingerprint,
    hosts,
  };

  if (options.output) {
    const outputPath = path.resolve(options.output);
    await fs.mkdir(path.dirname(outputPath), { recursive: true });
    await fs.writeFile(outputPath, `${JSON.stringify(report, null, 2)}\n`);
  }

  console.log(JSON.stringify(report, null, 2));
  if (!report.pass) process.exitCode = 1;
}

const invokedDirectly =
  process.argv[1] &&
  path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);

if (invokedDirectly) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}

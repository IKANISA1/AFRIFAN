import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import * as chromeLauncher from "chrome-launcher";
import lighthouse from "lighthouse";

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(scriptDirectory, "..");
const require = createRequire(import.meta.url);
const configuration = require(path.join(projectRoot, ".lighthouserc.js"));

export function categoryThresholds(assertions) {
  const thresholds = new Map();
  for (const [key, assertion] of Object.entries(assertions ?? {})) {
    if (!key.startsWith("categories:")) continue;
    const category = key.slice("categories:".length);
    const options = Array.isArray(assertion) ? assertion[1] : undefined;
    if (typeof options?.minScore === "number") {
      thresholds.set(category, options.minScore);
    }
  }
  return thresholds;
}

export function artifactName(url, runNumber, extension) {
  const parsed = new URL(url);
  const route = parsed.pathname === "/" ? "home" : parsed.pathname;
  const slug = route.replace(/^\/+|\/+$/g, "").replace(/[^a-z0-9]+/gi, "-");
  return `${slug || "home"}-run-${runNumber}.${extension}`;
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function waitForServer(url, server, timeoutMilliseconds = 60_000) {
  const deadline = Date.now() + timeoutMilliseconds;
  while (Date.now() < deadline) {
    if (server.exitCode !== null) {
      throw new Error(`Next server exited before becoming ready (${server.exitCode}).`);
    }
    try {
      const response = await fetch(url, { redirect: "manual" });
      if (response.status > 0) return;
    } catch {
      // The server is still starting.
    }
    await wait(250);
  }
  throw new Error(`Next server did not become ready within ${timeoutMilliseconds}ms.`);
}

function stopProcess(processHandle) {
  if (processHandle && processHandle.exitCode === null) {
    processHandle.kill("SIGTERM");
  }
}

export async function runLighthouseAudit() {
  const collect = configuration.ci?.collect ?? {};
  const assertions = configuration.ci?.assert?.assertions ?? {};
  const urls = collect.url ?? [];
  const numberOfRuns = collect.numberOfRuns ?? 1;
  const thresholds = categoryThresholds(assertions);
  const categories = [...thresholds.keys()];
  if (urls.length === 0 || categories.length === 0) {
    throw new Error("Lighthouse configuration must define URLs and category thresholds.");
  }

  const outputDirectory = path.join(projectRoot, ".lighthouseci");
  await mkdir(outputDirectory, { recursive: true });

  const nextBinary = path.join(projectRoot, "node_modules", "next", "dist", "bin", "next");
  const server = spawn(
    process.execPath,
    [nextBinary, "start", "--hostname", "127.0.0.1", "--port", "3310"],
    {
      cwd: projectRoot,
      env: { ...process.env, NODE_ENV: "production" },
      stdio: ["ignore", "pipe", "pipe"],
    },
  );
  let serverOutput = "";
  server.stdout.on("data", (chunk) => {
    serverOutput += chunk.toString();
  });
  server.stderr.on("data", (chunk) => {
    serverOutput += chunk.toString();
  });

  let chrome;
  try {
    await waitForServer(urls[0], server);
    chrome = await chromeLauncher.launch({
      chromeFlags: ["--headless=new", "--no-sandbox", "--disable-dev-shm-usage"],
    });

    const failures = [];
    for (const url of urls) {
      for (let runNumber = 1; runNumber <= numberOfRuns; runNumber += 1) {
        const result = await lighthouse(
          url,
          {
            port: chrome.port,
            logLevel: "error",
            output: ["json", "html"],
          },
          {
            extends: "lighthouse:default",
            settings: {
              ...collect.settings,
              onlyCategories: categories,
            },
          },
        );
        if (!result) throw new Error(`Lighthouse returned no result for ${url}.`);

        const reports = Array.isArray(result.report) ? result.report : [result.report];
        await writeFile(
          path.join(outputDirectory, artifactName(url, runNumber, "json")),
          reports[0],
        );
        await writeFile(
          path.join(outputDirectory, artifactName(url, runNumber, "html")),
          reports[1],
        );

        const scoreSummary = [];
        for (const [category, minimum] of thresholds) {
          const score = result.lhr.categories[category]?.score;
          scoreSummary.push(`${category}=${score ?? "missing"}`);
          if (typeof score !== "number" || score < minimum) {
            failures.push(`${url} run ${runNumber}: ${category} ${score ?? "missing"} < ${minimum}`);
          }
        }
        console.log(`${url} run ${runNumber}: ${scoreSummary.join(", ")}`);
      }
    }

    if (failures.length > 0) {
      throw new Error(`Lighthouse thresholds failed:\n${failures.join("\n")}`);
    }
  } catch (error) {
    if (serverOutput.trim()) process.stderr.write(serverOutput);
    throw error;
  } finally {
    if (chrome) await chrome.kill();
    stopProcess(server);
  }
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  runLighthouseAudit().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}

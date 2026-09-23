import { existsSync, rmSync } from "node:fs";
import { resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { beginProductionBuild, markProductionCompilationComplete } from "./web-build-provenance.mjs";

const root = resolve(process.cwd());
const maxAttempts = 4;
const transientBuildPatterns = [
  "Failed to collect page data for /_not-found",
  ".next/build-manifest.json",
  ".next/server/app/_not-found/page.js.nft.json",
  ".next/server/app/(site)/history/page.js",
  ".next/server/app/(site)/terms/page.js",
  "pages-manifest.json",
  "proxy.js.nft.json",
];

function cleanBuildOutputs() {
  for (const entry of ["tmp/deploy-check", ".next", ".open-next"]) {
    rmSync(resolve(root, entry), { recursive: true, force: true });
  }
}

function isTransientBuildRace(output) {
  return transientBuildPatterns.some((pattern) => output.includes(pattern));
}

function hasCompleteProductionArtifacts() {
  return [
    ".next/BUILD_ID",
    ".next/static",
    ".next/server/app",
    ".next/standalone/server.js",
  ].every((entry) => existsSync(resolve(root, entry)));
}

for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
  cleanBuildOutputs();
  beginProductionBuild(root, [process.execPath, "./node_modules/next/dist/bin/next", "build", "--webpack"]);
  console.log(
    `[build] Next.js production build attempt ${attempt}/${maxAttempts}`,
  );

  const result = spawnSync(
    process.execPath,
    [
      "--max-old-space-size=6144",
      "./node_modules/next/dist/bin/next",
      "build",
      "--webpack",
    ],
    {
      cwd: root,
      stdio: "pipe",
      encoding: "utf8",
      env: process.env,
    },
  );

  if (result.stdout) {
    process.stdout.write(result.stdout);
  }
  if (result.stderr) {
    process.stderr.write(result.stderr);
  }

  if ((result.status ?? 1) === 0) {
    if (hasCompleteProductionArtifacts()) {
      markProductionCompilationComplete(root);
      process.exit(0);
    }
    if (attempt === maxAttempts) {
      console.error(
        "[build] Next.js exited successfully without a complete production artifact set.",
      );
      process.exit(1);
    }
    console.warn(
      `[build] Retrying after incomplete Next.js production artifacts on attempt ${attempt}.`,
    );
    continue;
  }

  const combinedOutput = `${result.stdout ?? ""}\n${result.stderr ?? ""}`;
  if (!isTransientBuildRace(combinedOutput) || attempt === maxAttempts) {
    process.exit(result.status ?? 1);
  }

  console.warn(
    `[build] Retrying after transient Next.js artifact race on attempt ${attempt}.`,
  );
}

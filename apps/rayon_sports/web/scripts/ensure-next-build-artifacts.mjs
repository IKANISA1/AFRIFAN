import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";

const root = resolve(process.cwd());
const nextDir = resolve(root, process.env.NEXT_BUILD_DIR || ".next");

function ensureParent(targetPath) {
  mkdirSync(dirname(targetPath), { recursive: true });
}

function findBuildId() {
  const staticDir = join(nextDir, "static");
  if (!existsSync(staticDir)) {
    return null;
  }

  for (const entry of readdirSync(staticDir)) {
    const entryPath = join(staticDir, entry);
    if (!statSync(entryPath).isDirectory()) {
      continue;
    }
    if (existsSync(join(entryPath, "_buildManifest.js"))) {
      return entry;
    }
  }

  return null;
}

const buildIdPath = join(nextDir, "BUILD_ID");
if (!existsSync(buildIdPath)) {
  const buildId = findBuildId();
  if (buildId) {
    writeFileSync(buildIdPath, `${buildId}\n`);
    console.log(`Synthesized ${buildIdPath.replace(`${root}/`, "")}`);
  }
}

for (const [fallbackRelative, targetRelative] of [
  ["dev/prerender-manifest.json", "prerender-manifest.json"],
  ["dev/routes-manifest.json", "routes-manifest.json"],
]) {
  const targetPath = join(nextDir, targetRelative);
  const fallbackPath = join(nextDir, fallbackRelative);
  if (existsSync(targetPath) || !existsSync(fallbackPath)) {
    continue;
  }

  ensureParent(targetPath);
  copyFileSync(fallbackPath, targetPath);
  console.log(`Copied ${targetPath.replace(`${root}/`, "")}`);
}

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

const standaloneNextDir = join(nextDir, "standalone", ".next");
if (existsSync(buildIdPath)) {
  const standaloneBuildIdPath = join(standaloneNextDir, "BUILD_ID");
  if (!existsSync(standaloneBuildIdPath)) {
    ensureParent(standaloneBuildIdPath);
    copyFileSync(buildIdPath, standaloneBuildIdPath);
    console.log(
      `Copied ${standaloneBuildIdPath.replace(`${root}/`, "")}`,
    );
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

for (const relativePath of [
  "prerender-manifest.json",
  "routes-manifest.json",
  "build-manifest.json",
]) {
  const sourcePath = join(nextDir, relativePath);
  const standalonePath = join(standaloneNextDir, relativePath);
  if (!existsSync(sourcePath) || existsSync(standalonePath)) {
    continue;
  }

  ensureParent(standalonePath);
  copyFileSync(sourcePath, standalonePath);
  console.log(`Copied ${standalonePath.replace(`${root}/`, "")}`);
}

// Ensure pages-manifest.json exists (App Router-only Projects + @opennextjs/aws compatibility)
for (const subPath of [
  join(nextDir, "server", "pages-manifest.json"),
  join(nextDir, "standalone", ".next", "server", "pages-manifest.json"),
]) {
  if (!existsSync(subPath)) {
    ensureParent(subPath);
    writeFileSync(subPath, "{}");
    console.log(`Synthesized ${subPath.replace(`${root}/`, "")}`);
  }
}

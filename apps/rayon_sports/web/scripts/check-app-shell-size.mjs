import fs from "node:fs";
import path from "node:path";
import zlib from "node:zlib";

const projectRoot = process.cwd();
const nextDir = path.join(projectRoot, ".next");
const manifestPath = path.join(nextDir, "build-manifest.json");
const jsLimitKb = 170;
const cssLimitKb = 30;

function formatKb(bytes) {
  return `${(bytes / 1024).toFixed(2)} kB`;
}

function gzipBytes(filePath) {
  return zlib.gzipSync(fs.readFileSync(filePath)).length;
}

function walkFiles(directory, predicate, files = []) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolutePath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      walkFiles(absolutePath, predicate, files);
      continue;
    }
    if (predicate(absolutePath)) {
      files.push(absolutePath);
    }
  }
  return files;
}

if (!fs.existsSync(manifestPath)) {
  console.error("Missing .next/build-manifest.json. Run `npm run build` first.");
  process.exit(1);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const appShellFiles = [
  ...(manifest.polyfillFiles ?? []),
  ...(manifest.rootMainFiles ?? []),
].map((relativePath) => path.join(nextDir, relativePath));

const cssFiles = walkFiles(
  path.join(nextDir, "static"),
  (filePath) => filePath.endsWith(".css"),
);

const appShellSize = appShellFiles.reduce(
  (total, filePath) => total + gzipBytes(filePath),
  0,
);
const cssSize = cssFiles.reduce((total, filePath) => total + gzipBytes(filePath), 0);

console.log("App shell (critical first load)");
for (const filePath of appShellFiles) {
  console.log(`- ${formatKb(gzipBytes(filePath))}  ${path.relative(projectRoot, filePath)}`);
}
console.log(`Total: ${formatKb(appShellSize)} / limit ${jsLimitKb} kB`);
console.log("");
console.log("First-load CSS");
for (const filePath of cssFiles) {
  console.log(`- ${formatKb(gzipBytes(filePath))}  ${path.relative(projectRoot, filePath)}`);
}
console.log(`Total: ${formatKb(cssSize)} / limit ${cssLimitKb} kB`);

const failed = [];
if (appShellSize > jsLimitKb * 1024) {
  failed.push(
    `App shell critical first load exceeded by ${formatKb(
      appShellSize - jsLimitKb * 1024,
    )}`,
  );
}
if (cssSize > cssLimitKb * 1024) {
  failed.push(
    `First-load CSS exceeded by ${formatKb(cssSize - cssLimitKb * 1024)}`,
  );
}

if (failed.length > 0) {
  console.error("");
  for (const failure of failed) {
    console.error(failure);
  }
  process.exit(1);
}

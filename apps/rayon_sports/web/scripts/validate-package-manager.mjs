import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const packageJson = JSON.parse(readFileSync(path.join(projectRoot, "package.json"), "utf8"));
const packageLock = JSON.parse(
  readFileSync(path.join(projectRoot, "package-lock.json"), "utf8"),
);

function fail(message) {
  throw new Error(`Package-manager contract failed: ${message}`);
}

function runNpmJson(arguments_) {
  const npmExecutable = process.env.npm_execpath;
  if (!npmExecutable) fail("run this gate through `corepack npm run check:dependencies`");
  const result = spawnSync(process.execPath, [npmExecutable, ...arguments_], {
    cwd: projectRoot,
    encoding: "utf8",
    env: process.env,
  });
  let parsed;
  try {
    parsed = JSON.parse(result.stdout);
  } catch {
    fail(`npm ${arguments_.join(" ")} returned invalid JSON: ${result.stderr.trim()}`);
  }
  return { parsed, status: result.status, stderr: result.stderr };
}

const expectedManager = packageJson.packageManager;
const actualManager = process.env.npm_config_user_agent
  ?.split(" ")[0]
  ?.replace("npm/", "npm@");
if (actualManager !== expectedManager) {
  fail(`expected ${expectedManager}, received ${actualManager ?? "unknown npm"}`);
}

if (packageLock.lockfileVersion !== 3) fail("package-lock.json must use lockfile v3");
if (packageLock.packages?.[""]?.engines?.npm !== packageJson.engines.npm) {
  fail("package-lock.json does not match the npm engine contract");
}
if (packageLock.packages?.[""]?.devDependencies?.lighthouse !== "^13.4.1") {
  fail("Lighthouse 13 must remain a direct governed dependency");
}

const forbiddenLockPaths = Object.keys(packageLock.packages ?? {}).filter(
  (entry) => entry.includes("node_modules/@lhci/cli") || entry.endsWith("node_modules/extract-zip"),
);
if (forbiddenLockPaths.length > 0) {
  fail(`retired vulnerable Lighthouse-CI chain returned: ${forbiddenLockPaths.join(", ")}`);
}

const tree = runNpmJson(["ls", "--all", "--json"]);
const graphProblems = tree.parsed.problems ?? [];
if (tree.status !== 0 || graphProblems.length > 0) {
  fail(`dependency graph problems: ${graphProblems.join("; ") || tree.stderr.trim()}`);
}

const audit = runNpmJson(["audit", "--json", "--audit-level=high"]);
const vulnerabilityCounts = audit.parsed.metadata?.vulnerabilities;
const totalVulnerabilities = vulnerabilityCounts?.total;
if (audit.status !== 0 || totalVulnerabilities !== 0) {
  fail(`npm audit reports ${totalVulnerabilities ?? "unknown"} vulnerabilities`);
}

const approvals = runNpmJson(["install-scripts", "ls", "--json"]);
const uncoveredScripts = approvals.parsed.allowScripts ?? [];
if (approvals.status !== 0 || uncoveredScripts.length > 0) {
  fail(
    `unreviewed dependency install scripts: ${uncoveredScripts
      .map((entry) => entry.name)
      .join(", ")}`,
  );
}

console.log(
  `Package-manager contract ok (${expectedManager}, lockfile v${packageLock.lockfileVersion}, zero vulnerabilities, all install scripts reviewed).`,
);

import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

export function hasCoverageExclusion(output) {
  return /Failed to parse[^\n]*Excluding it from coverage/i.test(output);
}

export const requiredCoverageFiles = [
  "src/lib/web-observation-server.ts",
  "src/lib/admin-role-assignments.ts",
  "src/lib/membership-payment.ts",
  "src/app/auth/callback/route.ts",
  "src/app/api/admin/[resource]/route.ts",
  "src/app/api/admin/auth/eligible/route.ts",
  "src/app/api/admin/features/update/route.ts",
  "src/app/api/pwa/events/route.ts",
];

export function missingCriticalCoverage(summary, root) {
  return requiredCoverageFiles.filter(file => !Object.hasOwn(summary, path.resolve(root, file)));
}

export async function runUnitTests(args = []) {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
  const child = spawn(process.execPath, [path.join(root, "node_modules/vitest/vitest.mjs"), "run", "--coverage", ...args], {
    cwd: root, stdio: ["inherit", "pipe", "pipe"], env: process.env,
  });
  let parseFailed = false;
  const tails = new Map();
  for (const [name, stream, destination] of [["out", child.stdout, process.stdout], ["err", child.stderr, process.stderr]]) {
    stream.on("data", chunk => {
      destination.write(chunk);
      const tail = ((tails.get(name) || "") + chunk.toString()).slice(-32768);
      tails.set(name, tail);
      if (hasCoverageExclusion(tail)) parseFailed = true;
    });
  }
  const outcome = await new Promise(resolve => {
    child.once("error", error => { console.error(error.message); resolve(1); });
    child.once("exit", (code, signal) => resolve(signal ? 1 : (code ?? 1)));
  });
  if (outcome !== 0) return outcome;
  if (parseFailed) {
    console.error("Coverage admission failed: an included source file was excluded after an instrumentation error.");
    return 1;
  }
  // Focused runs intentionally cannot establish whole-application coverage.
  // The canonical complete test command admits each consequential route/helper.
  if (args.length === 0) {
    try {
      const summary = JSON.parse(await readFile(path.join(root, "coverage/coverage-summary.json"), "utf8"));
      const missing = missingCriticalCoverage(summary, root);
      if (missing.length) {
        console.error("Coverage admission failed: missing critical sources: " + missing.join(", "));
        return 1;
      }
    } catch (error) {
      console.error("Coverage admission failed: " + error.message);
      return 1;
    }
  }
  return 0;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exitCode = await runUnitTests(process.argv.slice(2));
}

import { createServer } from "node:http";
import { spawn } from "node:child_process";
import { resolve } from "node:path";

const appPort = Number(process.argv[2] ?? 3200);
const readyPort = Number(process.argv[3] ?? 3201);
const root = resolve(process.cwd());
const nextBin = resolve(root, "node_modules/next/dist/bin/next");
const ensureArtifacts = resolve(root, "scripts/ensure-next-build-artifacts.mjs");
const warmupPaths = ["/manifest.webmanifest", "/admin", "/offline", "/admin/matches"];

let ready = false;
let shuttingDown = false;
let childExited = false;

function log(message) {
  process.stdout.write(`[playwright-webserver] ${message}\n`);
}

async function wait(ms) {
  await new Promise((resolveWait) => setTimeout(resolveWait, ms));
}

async function checkPath(pathname) {
  const response = await fetch(`http://127.0.0.1:${appPort}${pathname}`);
  const body = await response.text();
  return response.ok && !body.includes("Internal Server Error");
}

async function warmServer() {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    try {
      const checks = [];
      for (const pathname of warmupPaths) {
        checks.push(checkPath(pathname));
      }
      const statuses = await Promise.all(checks);
      if (statuses.every(Boolean)) {
        ready = true;
        log(`ready after warm-up on ${warmupPaths.join(", ")}`);
        return;
      }
    } catch {
      // Ignore until the server is accepting traffic.
    }

    await wait(1000);
  }

  throw new Error("Timed out warming Next production routes for Playwright.");
}

const readyServer = createServer((request, response) => {
  if (request.url === "/ready") {
    response.writeHead(ready ? 200 : 503, { "content-type": "text/plain" });
    response.end(ready ? "ready" : "warming");
    return;
  }

  response.writeHead(404, { "content-type": "text/plain" });
  response.end("not found");
});

readyServer.listen(readyPort, "127.0.0.1");
log(`readiness probe listening on http://127.0.0.1:${readyPort}/ready`);

const ensureArtifactsProcess = spawn(process.execPath, [ensureArtifacts], {
  cwd: root,
  env: process.env,
  stdio: "inherit",
});

const ensureExitCode = await new Promise((resolveExit) => {
  ensureArtifactsProcess.on("exit", (code) => resolveExit(code ?? 1));
});

if (ensureExitCode !== 0) {
  process.exit(ensureExitCode);
}

const child = spawn(
  process.execPath,
  [nextBin, "start", "--hostname", "127.0.0.1", "--port", String(appPort)],
  {
    cwd: root,
    env: process.env,
    stdio: "inherit",
  },
);

child.on("exit", (code, signal) => {
  childExited = true;
  ready = false;

  if (shuttingDown) {
    process.exit(code ?? 0);
  }

  log(`Next server exited before shutdown (code=${code}, signal=${signal}).`);
  process.exit(code ?? 1);
});

function shutdown(signal) {
  if (shuttingDown) {
    return;
  }

  shuttingDown = true;
  ready = false;
  log(`received ${signal}, stopping Next server`);

  if (!childExited) {
    child.kill(signal);
  }

  readyServer.close(() => {
    if (childExited) {
      process.exit(0);
    }
  });
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

try {
  await warmServer();
} catch (error) {
  console.error(error);
  shutdown("SIGTERM");
}

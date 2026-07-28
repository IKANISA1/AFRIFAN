import { spawn } from "node:child_process";
import { resolve } from "node:path";

const root = resolve(process.cwd());
const supervisorScript = resolve(root, "scripts/start-playwright-server.mjs");
const playwrightCli = resolve(root, "node_modules/playwright/cli.js");
const appPort = 3200;
const readyPort = 3201;
const testArgs = process.argv.slice(2);

function log(message) {
  process.stdout.write(`[playwright-runner] ${message}\n`);
}

async function wait(ms) {
  await new Promise((resolveWait) => setTimeout(resolveWait, ms));
}

async function waitForReady() {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    try {
      const response = await fetch(`http://127.0.0.1:${readyPort}/ready`);
      if (response.ok) {
        return;
      }
    } catch {
      // Ignore until the readiness probe comes online.
    }

    await wait(1000);
  }

  throw new Error("Timed out waiting for the Playwright server supervisor.");
}

function stopChild(child, signal = "SIGTERM") {
  if (child.exitCode != null) {
    return;
  }

  child.kill(signal);
}

async function stopServer() {
  if (server.exitCode != null) {
    return;
  }

  stopChild(server, "SIGTERM");

  const exited = await Promise.race([
    new Promise((resolveExit) => {
      server.once("exit", () => resolveExit(true));
    }),
    wait(7_000).then(() => false),
  ]);

  if (!exited) {
    if (server.exitCode != null) {
      return;
    }
    stopChild(server, "SIGKILL");
    await new Promise((resolveExit) => {
      server.once("exit", () => resolveExit());
    });
  }
}

const server = spawn(
  process.execPath,
  [supervisorScript, String(appPort), String(readyPort)],
  {
    cwd: root,
    env: process.env,
    stdio: "inherit",
  },
);

let testsFinished = false;

server.on("exit", (code, signal) => {
  if (testsFinished) {
    return;
  }

  console.error(
    `[playwright-runner] supervised server exited unexpectedly (code=${code}, signal=${signal})`,
  );
  process.exit(code ?? 1);
});

process.on("SIGINT", () => stopChild(server, "SIGINT"));
process.on("SIGTERM", () => stopChild(server, "SIGTERM"));

try {
  await waitForReady();
  log("server is ready; starting Playwright");

  const runner = spawn(process.execPath, [playwrightCli, "test", ...testArgs], {
    cwd: root,
    env: process.env,
    stdio: "inherit",
  });

  const runnerExitCode = await new Promise((resolveExit) => {
    runner.on("exit", (code) => resolveExit(code ?? 1));
  });

  testsFinished = true;
  await stopServer();

  process.exit(runnerExitCode);
} catch (error) {
  console.error(error);
  await stopServer();
  process.exit(1);
}

import { spawnSync } from "node:child_process";

const ports = [3200, 3201];

for (const port of ports) {
  const result = spawnSync(
    "lsof",
    ["-ti", `tcp:${port}`, "-sTCP:LISTEN"],
    { encoding: "utf8" },
  );

  if (result.status !== 0 || !result.stdout.trim()) {
    continue;
  }

  const pids = result.stdout
    .split(/\s+/)
    .map((value) => Number.parseInt(value, 10))
    .filter(Number.isFinite);

  for (const pid of pids) {
    try {
      process.kill(pid, "SIGTERM");
      console.log(`[playwright-cleanup] Stopped pid ${pid} on port ${port}`);
    } catch {
      // Ignore already-exited processes.
    }
  }
}

import { readdirSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

export function readNormalizedFootballBaseline(): string {
  const migrationDirectory = resolve(
    process.cwd(),
    "../../../supabase/migrations",
  );
  const baselines = readdirSync(migrationDirectory).filter((fileName) =>
    fileName.endsWith("_football_only_baseline.sql"),
  );

  if (baselines.length !== 1) {
    throw new Error(
      `Expected one football-only baseline; found ${baselines.length}.`,
    );
  }

  return readFileSync(resolve(migrationDirectory, baselines[0]), "utf8")
    .replaceAll('"', "")
    .toLowerCase();
}

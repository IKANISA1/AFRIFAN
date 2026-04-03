import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(process.cwd());
const sourcePath = [".env.local", ".env"]
  .map((file) => resolve(root, file))
  .find((file) => existsSync(file));

const keys = [
  "NEXT_PUBLIC_SITE_URL",
  "NEXT_PUBLIC_SUPABASE_URL",
  "NEXT_PUBLIC_SUPABASE_ANON_KEY",
  "SUPABASE_URL",
  "SUPABASE_ANON_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
];

function parseEnv(source) {
  return source
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"))
    .reduce((env, line) => {
      const separator = line.indexOf("=");
      if (separator === -1) {
        return env;
      }

      const key = line.slice(0, separator).trim();
      let value = line.slice(separator + 1).trim();

      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1);
      }

      env[key] = value;
      return env;
    }, {});
}

const parsed = sourcePath ? parseEnv(readFileSync(sourcePath, "utf8")) : {};
const lines = ["NEXTJS_ENV=development"];

for (const key of keys) {
  const value = parsed[key] ?? process.env[key] ?? "";
  if (value) {
    lines.push(`${key}=${value}`);
  }
}

writeFileSync(resolve(root, ".dev.vars"), `${lines.join("\n")}\n`, "utf8");
console.log(`Wrote .dev.vars from ${sourcePath ? sourcePath.split("/").pop() : "process environment"}.`);

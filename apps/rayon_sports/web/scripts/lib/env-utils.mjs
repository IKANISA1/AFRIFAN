import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

function resolveDefaultEnvPath() {
  return path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "../../.env.local",
  );
}

export function loadLocalEnv(envPath = resolveDefaultEnvPath()) {
  if (!fs.existsSync(envPath)) {
    return process.env;
  }

  for (const line of fs.readFileSync(envPath, "utf8").split(/\n+/)) {
    if (!line || line.startsWith("#")) {
      continue;
    }

    const separatorIndex = line.indexOf("=");
    if (separatorIndex <= 0) {
      continue;
    }

    const key = line.slice(0, separatorIndex).trim();
    const rawValue = line.slice(separatorIndex + 1).trim();
    if (!key || process.env[key] != null) {
      continue;
    }

    process.env[key] = rawValue.replace(/^['"]|['"]$/g, "");
  }

  return process.env;
}

export function getFirstEnvValue(...keys) {
  for (const key of keys) {
    const value = process.env[key]?.trim();
    if (value) {
      return value;
    }
  }

  return "";
}

export function resolveSupabaseProjectRef(supabaseUrl) {
  const hostname = new URL(supabaseUrl).hostname;
  return hostname.split(".")[0] ?? "";
}

export function loadSupabaseAccessToken() {
  const direct = process.env.SUPABASE_ACCESS_TOKEN?.trim();
  if (direct) {
    return direct;
  }

  const tokenPath = path.join(os.homedir(), ".supabase", ".access-token");
  if (!fs.existsSync(tokenPath)) {
    return "";
  }

  return fs.readFileSync(tokenPath, "utf8").trim();
}

import { createClient } from "npm:@supabase/supabase-js@2";

function requireEnv(...names: string[]): string {
  for (const name of names) {
    const value = Deno.env.get(name)?.trim();
    if (value) {
      return value;
    }
  }

  throw new Error(`Missing environment variable: ${names.join(" or ")}`);
}

export function parseNamedApiKeySet(
  raw: string,
  variableName: string,
  keyName = "default",
): string {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`${variableName} must contain a JSON object.`);
  }

  if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(`${variableName} must contain a JSON object.`);
  }

  const value = (parsed as Record<string, unknown>)[keyName];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error(`${variableName} is missing the ${keyName} key.`);
  }
  return value.trim();
}

export function parseNamedApiKeys(
  raw: string,
  variableName: string,
): string[] {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error(`${variableName} must contain a JSON object.`);
  }

  if (parsed == null || typeof parsed !== "object" || Array.isArray(parsed)) {
    throw new Error(`${variableName} must contain a JSON object.`);
  }

  const keys = Object.values(parsed as Record<string, unknown>)
    .filter((value): value is string =>
      typeof value === "string" && value.trim().length > 0
    )
    .map((value) => value.trim());
  if (keys.length === 0) {
    throw new Error(`${variableName} does not contain any usable keys.`);
  }
  return Array.from(new Set(keys));
}

function preferNamedApiKeySet(
  variableName: string,
  legacyNames: string[],
): string {
  const keySet = Deno.env.get(variableName)?.trim();
  if (keySet) {
    return parseNamedApiKeySet(keySet, variableName);
  }
  return requireEnv(...legacyNames);
}

export function getSupabaseUrl() {
  return requireEnv("SUPABASE_URL", "COOL_PROJECT_SUPABASE_URL");
}

export function getSupabasePublishableKey() {
  return preferNamedApiKeySet("SUPABASE_PUBLISHABLE_KEYS", [
    "SUPABASE_ANON_KEY",
    "COOL_PROJECT_SUPABASE_ANON_KEY",
  ]);
}

export function getSupabaseSecretKey() {
  return preferNamedApiKeySet("SUPABASE_SECRET_KEYS", [
    "SUPABASE_SERVICE_ROLE_KEY",
    "COOL_PROJECT_SUPABASE_SERVICE_ROLE_KEY",
  ]);
}

export function getSupabaseSecretKeys() {
  const keys: string[] = [];
  const namedKeys = Deno.env.get("SUPABASE_SECRET_KEYS")?.trim();
  if (namedKeys) {
    keys.push(...parseNamedApiKeys(namedKeys, "SUPABASE_SECRET_KEYS"));
  }
  for (
    const name of [
      "SUPABASE_SERVICE_ROLE_KEY",
      "COOL_PROJECT_SUPABASE_SERVICE_ROLE_KEY",
    ]
  ) {
    const value = Deno.env.get(name)?.trim();
    if (value) keys.push(value);
  }
  if (keys.length === 0) {
    throw new Error(
      "Missing environment variable: SUPABASE_SECRET_KEYS or SUPABASE_SERVICE_ROLE_KEY or COOL_PROJECT_SUPABASE_SERVICE_ROLE_KEY",
    );
  }
  return Array.from(new Set(keys));
}

export function createAdminClient() {
  return createClient(
    getSupabaseUrl(),
    getSupabaseSecretKey(),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
      db: {
        schema: "public",
      },
    },
  );
}

/**
 * Admin client pre-configured for the football schema.
 * Use when you need to query football.* tables directly.
 */
export function createFootballAdminClient() {
  return createClient(
    getSupabaseUrl(),
    getSupabaseSecretKey(),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
      db: {
        schema: "football",
      },
    },
  );
}

export function createAnonClient() {
  return createClient(
    getSupabaseUrl(),
    getSupabasePublishableKey(),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );
}

export function createUserClient(authorization: string) {
  return createClient(
    getSupabaseUrl(),
    getSupabasePublishableKey(),
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
      global: {
        headers: {
          Authorization: authorization,
        },
      },
    },
  );
}

import { parseNamedApiKeys, parseNamedApiKeySet } from "./supabase.ts";

function assertEquals(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

Deno.test("parseNamedApiKeySet selects the controlled default key", () => {
  assertEquals(
    parseNamedApiKeySet(
      JSON.stringify({ default: " sb_publishable_example ", mobile: "other" }),
      "SUPABASE_PUBLISHABLE_KEYS",
    ),
    "sb_publishable_example",
    "default key",
  );
});

Deno.test("parseNamedApiKeySet rejects malformed or missing key sets", () => {
  for (const raw of ["not-json", "[]", "{}", '{"default":""}']) {
    let failed = false;
    try {
      parseNamedApiKeySet(raw, "SUPABASE_SECRET_KEYS");
    } catch {
      failed = true;
    }
    assertEquals(failed, true, `invalid key set ${raw}`);
  }
});

Deno.test("parseNamedApiKeys returns every unique controlled key", () => {
  const keys = parseNamedApiKeys(
    JSON.stringify({
      default: " sb_secret_current ",
      previous: "sb_secret_previous",
      duplicate: "sb_secret_current",
    }),
    "SUPABASE_SECRET_KEYS",
  );
  assertEquals(keys.join(","), "sb_secret_current,sb_secret_previous", "keys");
});

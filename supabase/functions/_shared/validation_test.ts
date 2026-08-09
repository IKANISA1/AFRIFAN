import { extractTrustedClubId } from "./validation.ts";

function assertEquals(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

Deno.test("extractTrustedClubId accepts only positive trusted app metadata ids", () => {
  assertEquals(extractTrustedClubId({ club_id: 42 }), "42", "numeric id");
  assertEquals(extractTrustedClubId({ club_id: " 42 " }), "42", "string id");
  for (const value of [null, "", "0", "-1", "1.5", "club-42", 0, -1, 1.5]) {
    assertEquals(
      extractTrustedClubId({ club_id: value }),
      null,
      `invalid id ${String(value)}`,
    );
  }
});

Deno.test("tenant scope cannot be derived from user metadata", () => {
  const user = {
    app_metadata: {},
    user_metadata: { club_id: "999" },
  };
  assertEquals(
    extractTrustedClubId(user.app_metadata),
    null,
    "user metadata must not establish tenant scope",
  );
});

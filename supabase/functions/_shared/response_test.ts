import { assertEquals } from "jsr:@std/assert";
import { HttpError } from "./auth.ts";
import {
  corsPreflightResponse,
  errorResponse,
  jsonOk,
  withEdgeBoundary,
} from "./response.ts";

Deno.test("typed rate limits preserve status and Retry-After with private headers", async () => {
  const response = errorResponse(
    new HttpError(429, "Please wait.", { "Retry-After": "37" }),
  );
  assertEquals(response.status, 429);
  assertEquals(response.headers.get("retry-after"), "37");
  assertEquals(response.headers.get("cache-control"), "private, no-store");
  assertEquals((await response.json()).code, "RATE_LIMITED");
});
Deno.test("unknown and server errors expose a stable code without provider details", async () => {
  for (
    const error of [
      new Error("secret-provider-token"),
      new HttpError(500, "private SQL detail"),
    ]
  ) {
    const response = errorResponse(error);
    assertEquals(response.status, 500);
    assertEquals(await response.json(), {
      error: "The service could not complete this request.",
      code: "INTERNAL_ERROR",
    });
  }
});
Deno.test("deployed boundary admits exact approved browser origin and native requests", async () => {
  const original = Deno.env.get("EDGE_ALLOWED_ORIGINS");
  Deno.env.set("EDGE_ALLOWED_ORIGINS", "https://approved.example.test");
  try {
    let calls = 0;
    const handler = withEdgeBoundary(() => {
      calls++;
      return jsonOk({ success: true });
    });
    const native = await handler(new Request("https://service.test"));
    assertEquals(native.status, 200);
    assertEquals(native.headers.get("access-control-allow-origin"), null);
    const browser = await handler(
      new Request("https://service.test", {
        headers: { origin: "https://approved.example.test" },
      }),
    );
    assertEquals(
      browser.headers.get("access-control-allow-origin"),
      "https://approved.example.test",
    );
    for (
      const origin of [
        "https://approved.example.test.evil.test",
        "https://unapproved.test",
        "null",
      ]
    ) {
      const rejected = await handler(
        new Request("https://service.test", { headers: { origin } }),
      );
      assertEquals(rejected.status, 403);
      assertEquals(rejected.headers.get("access-control-allow-origin"), null);
    }
    assertEquals(calls, 2);
    const preflight = (extra: Record<string, string>) =>
      corsPreflightResponse(
        new Request("https://service.test", {
          method: "OPTIONS",
          headers: { origin: "https://approved.example.test", ...extra },
        }),
      );
    assertEquals(
      preflight({
        "access-control-request-method": "POST",
        "access-control-request-headers": "authorization, content-type",
      }).status,
      204,
    );
    assertEquals(
      preflight({ "access-control-request-method": "DELETE" }).status,
      403,
    );
    assertEquals(
      preflight({ "access-control-request-headers": "x-unapproved" }).status,
      403,
    );
  } finally {
    if (original === undefined) Deno.env.delete("EDGE_ALLOWED_ORIGINS");
    else Deno.env.set("EDGE_ALLOWED_ORIGINS", original);
  }
});

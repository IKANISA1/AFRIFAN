import { assertEquals } from "jsr:@std/assert";
import { createGenerateAdminImageHandler } from "./index.ts";
import {
  generationHarness,
  generationOperation,
} from "../_shared/admin_image_generation_test_support.ts";
function request(authorization: string, body: Record<string, unknown> = {}) {
  return new Request("https://qa.invalid/edge", {
    method: "POST",
    headers: { authorization, "content-type": "application/json" },
    body: JSON.stringify({
      operation_id: generationOperation,
      clubId: 24,
      kind: "home_banner",
      prompt: "Synthetic",
      ...body,
    }),
  });
}
for (
  const scenario of [
    "fresh",
    "stale",
    "missing",
    "foreign",
    "provider_failure",
    "no_role",
  ] as const
) {
  Deno.test(`actual admin image ${scenario} provider-verified JWT guards original command before paid work`, async () => {
    const now = Math.floor(Date.now() / 1000);
    const h = await generationHarness({
      jwtOverrides: scenario === "stale"
        ? { amr: [{ method: "totp", timestamp: now - 301 }] }
        : scenario === "missing"
        ? { amr: [] }
        : scenario === "foreign"
        ? { sub: "99968000-0000-4000-8000-000000000099" }
        : {},
      authFailure: scenario === "provider_failure",
      forbiddenAssignment: scenario === "no_role",
    });
    try {
      const response = await createGenerateAdminImageHandler()(
        request(h.authorization),
      );
      assertEquals(
        response.status,
        scenario === "fresh"
          ? 200
          : scenario === "provider_failure"
          ? 401
          : 403,
      );
      assertEquals(h.counts().provider, scenario === "fresh" ? 1 : 0);
      assertEquals(
        h.calls.some((c) => c.name === "admit_admin_image_generation"),
        scenario === "fresh",
      );
      if (scenario === "fresh") {
        const receipt = await response.json();
        assertEquals(receipt.operation_id, generationOperation);
        assertEquals(receipt.request.aspectRatio, "16:9");
        assertEquals("dispatch_proof_id" in receipt, false);
      }
    } finally {
      h.restore();
    }
  });
}
Deno.test("actual admin image original UUID is mandatory and status does not call Gemini", async () => {
  const h = await generationHarness();
  try {
    assertEquals(
      (await createGenerateAdminImageHandler()(
        request(h.authorization, { operation_id: undefined }),
      )).status,
      400,
    );
    const response = await createGenerateAdminImageHandler()(
      request(h.authorization, {
        mode: "status",
        prompt: undefined,
        kind: undefined,
      }),
    );
    assertEquals(response.status, 200);
    assertEquals((await response.json()).status, "pending");
    assertEquals(h.counts(), { provider: 0, published: 0 });
  } finally {
    h.restore();
  }
});
Deno.test("actual admin image provider uncertainty returns original unknown receipt without URL", async () => {
  const h = await generationHarness({ providerFailure: true });
  try {
    const response = await createGenerateAdminImageHandler()(
      request(h.authorization),
    );
    assertEquals(response.status, 202);
    const r = await response.json();
    assertEquals(r.status, "unknown");
    assertEquals(r.image_url, undefined);
    assertEquals(
      (await createGenerateAdminImageHandler()(request(h.authorization)))
        .status,
      202,
    );
    assertEquals(h.counts().provider, 1);
  } finally {
    h.restore();
  }
});

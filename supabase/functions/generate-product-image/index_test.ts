import { assertEquals } from "jsr:@std/assert";
import { createGenerateProductImageHandler } from "./index.ts";
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
      productType: "kit",
      ...body,
    }),
  });
}
Deno.test("actual product generation preserves product prompt and immutable command via caller admission", async () => {
  const h = await generationHarness();
  try {
    const response = await createGenerateProductImageHandler()(
      request(h.authorization, { productName: "Synthetic Kit" }),
    );
    assertEquals(response.status, 200);
    const r = await response.json();
    assertEquals(r.operation_id, generationOperation);
    assertEquals(r.domain, "product_image");
    assertEquals(r.request, {
      productType: "kit",
      productName: "Synthetic Kit",
      targetTable: null,
      targetId: null,
    });
    assertEquals(r.product_type, "kit");
    assertEquals(r.prompt_used.includes("Synthetic Kit"), true);
    assertEquals(h.counts(), { provider: 1, published: 1 });
  } finally {
    h.restore();
  }
});
Deno.test("actual product generation stale MFA cannot admit, contact Google, or publish", async () => {
  const h = await generationHarness({ jwtOverrides: { amr: [] } });
  try {
    assertEquals(
      (await createGenerateProductImageHandler()(request(h.authorization)))
        .status,
      403,
    );
    assertEquals(h.calls.length, 0);
    assertEquals(h.counts(), { provider: 0, published: 0 });
  } finally {
    h.restore();
  }
});
Deno.test("actual product target conflict remains staged without version-blind overwrite or repeated cost", async () => {
  const h = await generationHarness({ targetConflict: true });
  try {
    const response = await createGenerateProductImageHandler()(
      request(h.authorization, {
        targetTable: "shop_products",
        targetId: "99968000-0000-4000-8000-000000000009",
      }),
    );
    assertEquals(response.status, 202);
    const r = await response.json();
    assertEquals(r.target_conflict, true);
    assertEquals(r.image_url, undefined);
    assertEquals(
      h.calls.some((c) => c.name === "commit_admin_image_generation"),
      true,
    );
    assertEquals(h.calls.some((c) => c.name === "update"), false);
  } finally {
    h.restore();
  }
});
Deno.test("actual product status retains original domain and needs no provider key", async () => {
  const h = await generationHarness();
  try {
    await createGenerateProductImageHandler()(request(h.authorization));
    Deno.env.delete("GEMINI_API_KEY");
    const response = await createGenerateProductImageHandler()(
      request(h.authorization, { mode: "status" }),
    );
    assertEquals(response.status, 200);
    assertEquals((await response.json()).domain, "product_image");
    assertEquals(h.counts().provider, 1);
  } finally {
    h.restore();
  }
});
Deno.test("product generation authenticates before any JSON parsing", async () => {
  const req = new Request("https://qa.invalid/edge", {
    method: "POST",
    body: "{}",
  });
  const response = await createGenerateProductImageHandler({
    validateRequest: async () => new Response(null, { status: 401 }),
  })(req);
  assertEquals(response.status, 401);
  assertEquals(req.bodyUsed, false);
});

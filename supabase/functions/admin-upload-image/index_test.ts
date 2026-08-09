import { createAdminUploadImageHandler } from "./index.ts";

function assertEquals(actual: unknown, expected: unknown, message: string) {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${expected}, got ${actual}`);
  }
}

const png = btoa(String.fromCharCode(
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  1,
));

Deno.test("admin-upload-image binds upload to authorized club path", async () => {
  const paths: string[] = [];
  const handler = createAdminUploadImageHandler({
    requireClubAdminCaller: async (_request, clubId) => {
      assertEquals(clubId, 24, "club id");
      return {} as never;
    },
    createAdminClient: () =>
      ({
        storage: {
          from: (bucket: string) => ({
            upload: async (path: string) => {
              assertEquals(bucket, "africlub-product-images", "bucket");
              paths.push(path);
              return { error: null };
            },
            getPublicUrl: (path: string) => ({
              data: { publicUrl: `https://storage.test/${path}` },
            }),
          }),
        },
      }) as never,
    now: () => 123,
    randomId: () => "deadbeef",
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({
        club_id: 24,
        kind: "shop_product",
        mime_type: "image/png",
        image_data_base64: png,
      }),
    }),
  );
  assertEquals(response.status, 200, "status");
  assertEquals(paths[0], "club-24/admin/shop_product/123-deadbeef.png", "path");
});

Deno.test("admin-upload-image rejects MIME spoofing before storage", async () => {
  let storageCalled = false;
  const handler = createAdminUploadImageHandler({
    requireClubAdminCaller: async () => ({} as never),
    createAdminClient: () => {
      storageCalled = true;
      return {} as never;
    },
  });
  const response = await handler(
    new Request("https://example.test", {
      method: "POST",
      body: JSON.stringify({
        club_id: 24,
        kind: "shop_product",
        mime_type: "image/png",
        image_data_base64: btoa("not-a-png"),
      }),
    }),
  );
  assertEquals(response.status, 400, "status");
  assertEquals(storageCalled, false, "storage called");
});

import { assertEquals, assertRejects } from "jsr:@std/assert";
import { fetchBoundedJson, readBoundedJson, readBoundedText } from "./http.ts";
import { HttpError } from "./http_error.ts";

function request(body: BodyInit, headers: Record<string, string> = {}) {
  return new Request("https://example.test", {
    method: "POST",
    body,
    headers: { "content-type": "application/json", ...headers },
  });
}
async function rejectedStatus(operation: Promise<unknown>, status: number) {
  const error = await assertRejects(() => operation, HttpError);
  assertEquals(error.status, status);
}
Deno.test("streamed JSON counts bytes independently of Content-Length", async () => {
  let cancelled = false;
  const body = new ReadableStream({
    start(c) {
      c.enqueue(new TextEncoder().encode('{"a":"'));
      c.enqueue(new TextEncoder().encode("x".repeat(64)));
    },
    cancel() {
      cancelled = true;
    },
  });
  await rejectedStatus(readBoundedJson(request(body), { maxBytes: 16 }), 413);
  assertEquals(cancelled, true);
});
Deno.test("slow JSON body reaches a deadline and cancels the stream", async () => {
  let cancelled = false;
  const body = new ReadableStream({
    cancel() {
      cancelled = true;
    },
  });
  await rejectedStatus(readBoundedJson(request(body), { timeoutMs: 20 }), 408);
  assertEquals(cancelled, true);
});
Deno.test("JSON ingress rejects oversized declared length, encoding, and non-JSON types", async () => {
  await rejectedStatus(
    readBoundedJson(request("{}", { "content-length": "70000" })),
    413,
  );
  await rejectedStatus(
    readBoundedJson(request("{}", { "content-encoding": "gzip" })),
    415,
  );
  await rejectedStatus(
    readBoundedJson(request("{}", { "content-type": "text/plain" })),
    415,
  );
});
Deno.test("malformed, non-object and invalid UTF-8 JSON never enter business work", async () => {
  for (const body of ["{bad", "[]", "null"]) {
    await rejectedStatus(readBoundedJson(request(body)), 400);
  }
  await rejectedStatus(readBoundedText(request(new Uint8Array([0xff]))), 400);
  assertEquals(await readBoundedJson(request('{"a":1}')), { a: 1 });
});
Deno.test("provider deadline bounds headers even when a provider ignores cancellation", async () => {
  let signal: AbortSignal | null | undefined;
  await rejectedStatus(
    fetchBoundedJson(
      (_url, options) => {
        signal = options?.signal;
        return new Promise<Response>(() => {});
      },
      "https://provider.test",
      {},
      { timeoutMs: 20 },
    ),
    504,
  );
  assertEquals(signal?.aborted, true);
});
Deno.test("provider error bodies and oversized successful bodies stay private", async () => {
  await rejectedStatus(
    fetchBoundedJson(
      async () =>
        new Response("private SQL/provider credential", { status: 500 }),
      "https://provider.test",
      {},
    ),
    502,
  );
  await rejectedStatus(
    fetchBoundedJson(
      async () =>
        new Response(JSON.stringify({ text: "x".repeat(32) }), {
          headers: { "content-type": "application/json" },
        }),
      "https://provider.test",
      {},
      { maxBytes: 16 },
    ),
    502,
  );
});

Deno.test("provider body deadline cancels its response stream", async () => {
  let cancelled = false;
  await rejectedStatus(
    fetchBoundedJson(
      async () =>
        new Response(
          new ReadableStream({
            cancel() {
              cancelled = true;
            },
          }),
          { headers: { "content-type": "application/json" } },
        ),
      "https://provider.test",
      {},
      { timeoutMs: 20 },
    ),
    504,
  );
  assertEquals(cancelled, true);
});

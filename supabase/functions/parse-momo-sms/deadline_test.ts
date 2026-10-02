import { callGemini, callOpenAi } from "./ai_parser.ts";

for (
  const [provider, call] of [["OpenAI", callOpenAi], [
    "Gemini",
    callGemini,
  ]] as const
) {
  for (const phase of ["connection", "body"]) {
    Deno.test(`${provider} bounds stalled ${phase} and permits unchanged-input retry`, async () => {
      let signal: AbortSignal | null | undefined;
      let bodyRelease: (() => void) | undefined;
      const fetchFn: typeof fetch = (_input, init) => {
        signal = init?.signal;
        if (phase === "connection") return new Promise(() => {});
        return Promise.resolve(
          new Response(
            new ReadableStream({
              start(controller) {
                bodyRelease = () => controller.close();
              },
              cancel() {
                bodyRelease = undefined;
              },
            }),
            { status: 200, headers: { "content-type": "application/json" } },
          ),
        );
      };
      let observed: unknown;
      let guard: ReturnType<typeof setTimeout> | undefined;
      try {
        await Promise.race([
          call("Unchanged synthetic SMS", {
            apiKey: "test",
            model: "test",
            fetchFn,
            ...{ timeoutMs: 10 },
          }),
          new Promise((_, reject) => {
            guard = setTimeout(
              () =>
                reject(
                  new Error("Test guard: provider never reached a deadline"),
                ),
              300,
            );
          }),
        ]);
      } catch (error) {
        observed = error;
      } finally {
        clearTimeout(guard);
        bodyRelease?.();
      }
      if (
        !(observed instanceof Error) ||
        observed.message !== "SMS parse provider request timed out."
      ) {
        throw new Error(
          "Stalled provider did not fail through its bounded deadline: " +
            observed,
        );
      }
      if (!signal?.aborted) {
        throw new Error("Underlying provider request must be aborted");
      }
      const text = '{"parse_status":"needs_review"}';
      const result = await call("Unchanged synthetic SMS", {
        apiKey: "test",
        model: "test",
        fetchFn: () =>
          Promise.resolve(
            Response.json(
              provider === "OpenAI"
                ? { output: [{ content: [{ text }] }] }
                : { candidates: [{ content: { parts: [{ text }] } }] },
            ),
          ),
        ...{ timeoutMs: 500 },
      });
      if (result.text !== text) {
        throw new Error("Retry did not preserve the valid provider output");
      }
    });
  }
}

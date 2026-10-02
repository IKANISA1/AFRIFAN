import { handleRequest } from "./index.ts";
import { assertEquals as compare } from "./reconciliation_test_support.ts";
const assertEquals = (
  actual: unknown,
  expected: unknown,
  message = "Expected contract value",
) => compare(actual, expected, message);
import { HttpError } from "../_shared/http_error.ts";
const secret = btoa("a".repeat(32)),
  eventId = "99964000-0000-4000-8000-000000000001";
for (
  const scenario of [
    "supporter",
    "wrong_secret",
    "disabled",
    "foreign_event",
    "legacy_raw",
    "AI_override",
    "rate_store_failed",
    "processing_failed",
    "wrong_receipt",
    "unknown_status",
    "confirmed",
    "allocated",
    "manual_review",
    "replay",
  ] as const
) {
  Deno.test(`actual processor capability ${scenario}`, async () => {
    const saved = [
      Deno.env.get("SMS_PROCESSOR_SECRET"),
      Deno.env.get("TRUSTED_SMS_INGRESS_ENABLED"),
    ];
    Deno.env.set("SMS_PROCESSOR_SECRET", secret);
    Deno.env.set(
      "TRUSTED_SMS_INGRESS_ENABLED",
      scenario === "disabled" ? "false" : "true",
    );
    let processes = 0, rates = 0;
    const request = new Request(
      "https://qa.invalid/functions/v1/parse-momo-sms",
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: "Bearer supporter-jwt",
          ...(scenario === "supporter" ? {} : {
            "x-sms-processor-secret": scenario === "wrong_secret"
              ? btoa("b".repeat(32))
              : secret,
          }),
        },
        body: JSON.stringify(
          scenario === "legacy_raw"
            ? { rawSmsId: eventId }
            : scenario === "AI_override"
            ? { eventId, provider: "openai", forceReparse: true }
            : { eventId },
        ),
      },
    );
    try {
      const response = await handleRequest(request, {
        createAdminClient: () => ({
          rpc: async (name: string, params: any) => {
            assertEquals(params.p_event_id, eventId);
            if (name === "get_trusted_sms_gateway_event") {
              return {
                data: scenario === "foreign_event" ? null : {
                  gateway_id: "99964000-0000-4000-8000-000000000020",
                  club_id: 9996401,
                },
                error: null,
              };
            }
            if (name === "process_trusted_sms_gateway_evidence") {
              processes++;
              return {
                data: {
                  event_id: scenario === "wrong_receipt" ? "foreign" : eventId,
                  status: ["allocated", "manual_review"].includes(scenario)
                    ? scenario
                    : scenario === "unknown_status"
                    ? "pending"
                    : "confirmed",
                  replay: scenario === "replay",
                },
                error: scenario === "processing_failed"
                  ? new Error("secret SQL detail")
                  : null,
              };
            }
            throw new Error("Unexpected call");
          },
        }),
        enforceRateLimit: async (_a, subject, name, config) => {
          rates++;
          assertEquals(subject, "99964000-0000-4000-8000-000000000020");
          assertEquals(name, "parse-momo-sms");
          assertEquals(config.clubId, 9996401);
          if (scenario === "rate_store_failed") {
            throw new HttpError(503, "Admission unavailable");
          }
        },
      });
      const expected = ["supporter", "wrong_secret"].includes(scenario)
        ? 401
        : ["disabled", "rate_store_failed"].includes(scenario)
        ? 503
        : scenario === "foreign_event"
        ? 404
        : ["legacy_raw", "AI_override"].includes(scenario)
        ? 400
        : ["processing_failed", "wrong_receipt", "unknown_status"].includes(
            scenario,
          )
        ? 500
        : 200;
      assertEquals(response.status, expected);
      const body = await response.json();
      assertEquals(JSON.stringify(body).includes("secret SQL detail"), false);
      if (expected === 200) {
        assertEquals(processes, 1);
        assertEquals(
          body.status,
          ["allocated", "manual_review"].includes(scenario)
            ? scenario
            : "confirmed",
        );
      }
      if (
        ["supporter", "wrong_secret", "disabled", "legacy_raw", "AI_override"]
          .includes(scenario)
      ) {
        assertEquals(rates, 0);
        assertEquals(processes, 0);
      }
    } finally {
      saved[0] === undefined
        ? Deno.env.delete("SMS_PROCESSOR_SECRET")
        : Deno.env.set("SMS_PROCESSOR_SECRET", saved[0]);
      saved[1] === undefined
        ? Deno.env.delete("TRUSTED_SMS_INGRESS_ENABLED")
        : Deno.env.set("TRUSTED_SMS_INGRESS_ENABLED", saved[1]);
    }
  });
}

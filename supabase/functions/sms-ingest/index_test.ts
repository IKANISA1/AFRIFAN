import { handleRequest } from "./index.ts";
import { signGatewayEvidence } from "./gateway_client.ts";
import { evidence, keyId, secret, target } from "./test_support.ts";
import { assertEquals as compare } from "../parse-momo-sms/reconciliation_test_support.ts";
const assertEquals = (
  actual: unknown,
  expected: unknown,
  message = "Expected contract value",
) => compare(actual, expected, message);
import { HttpError } from "../_shared/http_error.ts";
const values = {
  SUPABASE_URL: "https://qa.invalid",
  TRUSTED_SMS_INGRESS_ENABLED: "true",
  SMS_GATEWAY_KEY_QA: secret,
  SMS_PROCESSOR_SECRET: secret,
};
for (
  const scenario of [
    "supporter",
    "disabled",
    "unprovisioned",
    "tampered",
    "wrong_receiver",
    "admission_failed",
    "rate_denied",
    "rate_store_failed",
    "processing_failed",
    "accepted",
    "identical_redelivery",
  ] as const
) {
  Deno.test(`actual trusted ingress ${scenario}`, async () => {
    const saved = Object.fromEntries(
      Object.keys(values).map((k) => [k, Deno.env.get(k)]),
    );
    for (const [k, v] of Object.entries(values)) Deno.env.set(k, v);
    let admissions = 0, processing = 0, rates = 0;
    const admin = {
      rpc: (name: string, params: any) => {
        if (name === "get_trusted_sms_gateway_key") {
          return Promise.resolve({
            data: scenario === "unprovisioned" ? null : {
              gateway_id: "99964000-0000-4000-8000-000000000020",
              club_id: 9996401,
              secret_env_name: "SMS_GATEWAY_KEY_QA",
            },
            error: null,
          });
        }
        if (name === "admit_trusted_sms_gateway_evidence") {
          admissions++;
          assertEquals(
            JSON.stringify(params.p_projection),
            JSON.stringify(evidence),
          );
          return Promise.resolve({
            data: {
              event_id: evidence.eventId,
              raw_sms_id: "99964000-0000-4000-8000-000000000030",
              replay: scenario === "identical_redelivery",
            },
            error: ["wrong_receiver", "admission_failed"].includes(scenario)
              ? new Error("private database detail")
              : null,
          });
        }
        throw new Error("Unexpected RPC");
      },
    };
    try {
      if (scenario === "disabled") {
        Deno.env.set("TRUSTED_SMS_INGRESS_ENABLED", "false");
      }
      let request = await signGatewayEvidence(target, keyId, secret, evidence);
      if (scenario === "supporter") {
        request = new Request(target, {
          method: "POST",
          headers: {
            authorization: "Bearer supporter-jwt",
            "content-type": "application/json",
          },
          body: JSON.stringify({ sender: "M-Money", smsBody: "forged" }),
        });
      }
      if (scenario === "tampered") {
        request = new Request(target, {
          method: "POST",
          headers: request.headers,
          body: "{}",
        });
      }
      const response = await handleRequest(request, {
        createAdminClient: () => admin,
        enforceRateLimit: async (_a, subject, name, config) => {
          rates++;
          assertEquals(subject, "99964000-0000-4000-8000-000000000020");
          assertEquals(config.clubId, 9996401);
          assertEquals(name, "sms-ingest");
          if (scenario === "rate_denied") {
            throw new HttpError(429, "Limited", { "Retry-After": "10" });
          }
          if (scenario === "rate_store_failed") {
            throw new HttpError(503, "Admission unavailable");
          }
        },
        processEvidence: async (request) => {
          processing++;
          assertEquals(request.headers.get("x-sms-processor-secret"), secret);
          return new Response("{}", {
            status: scenario === "processing_failed" ? 500 : 200,
          });
        },
      });
      const expected =
        scenario === "supporter" || scenario === "unprovisioned" ||
          scenario === "tampered"
          ? 401
          : scenario === "disabled" || scenario === "rate_store_failed"
          ? 503
          : scenario === "rate_denied"
          ? 429
          : scenario === "wrong_receiver" || scenario === "admission_failed"
          ? 500
          : 202;
      assertEquals(response.status, expected);
      const body = await response.json();
      assertEquals(
        JSON.stringify(body).includes("private database detail"),
        false,
      );
      if (expected === 202) {
        assertEquals(body.accepted, true);
        assertEquals(
          body.processing,
          scenario === "processing_failed" ? "pending" : "processed",
        );
        assertEquals(processing, 1);
      }
      if (
        ["supporter", "disabled", "unprovisioned", "tampered"].includes(
          scenario,
        )
      ) {
        assertEquals(admissions, 0);
        assertEquals(processing, 0);
        assertEquals(rates, 0);
      }
      if (scenario === "rate_denied") {
        assertEquals(response.headers.get("retry-after"), "10");
        assertEquals(admissions, 0);
      }
    } finally {
      for (const [k, v] of Object.entries(saved)) {
        v === undefined ? Deno.env.delete(k) : Deno.env.set(k, v);
      }
    }
  });
}

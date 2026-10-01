import { assertEquals, assertFalse } from "jsr:@std/assert";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "./observability.ts";

const privateValue =
  "actor-77 sms-22 person@example.test +250788123456 https://private.invalid/?token=secret";

function client(insert: (row: Record<string, unknown>) => unknown) {
  return {
    from(table: string) {
      assertEquals(table, "operational_health_events");
      return { insert };
    },
  } as unknown as Parameters<typeof recordOperationalHealthEvent>[0];
}

Deno.test("stored failure diagnostics remove identities and raw error details while retaining safe triage facts", async () => {
  const rows: Record<string, unknown>[] = [];
  const error = new TypeError(privateValue);
  await recordEdgeFunctionFailure(
    client((row) => {
      rows.push(row);
      return { error: null };
    }),
    {
      functionName: "sms-ingest",
      error,
      userId: privateValue,
      subjectType: "momo_sms_raw",
      subjectId: privateValue,
      issueCode: "sms_ingest_failed",
      metadata: {
        sender: privateValue,
        url: privateValue,
        count: 2,
        parser_provider: "openai",
        error: privateValue,
      },
    },
  );
  assertEquals(rows.length, 1);
  const row = rows[0];
  assertEquals(row.service, "edge_function");
  assertEquals(row.function_name, "sms-ingest");
  assertEquals(row.issue_code, "sms_ingest_failed");
  assertEquals(row.status, "error");
  assertEquals(row.severity, "critical");
  assertEquals(row.message, "Operational health failure.");
  assertEquals(row.user_id, null);
  assertEquals(row.subject_id, null);
  assertEquals(row.subject_type, null);
  assertEquals(row.metadata, {
    parser_provider: "openai",
    error_name: "TypeError",
    count: 2,
  });
  assertFalse(JSON.stringify(row).includes(privateValue));
});

Deno.test("stored mobile and direct health diagnostics reject arbitrary caller strings and metadata", async () => {
  let row: Record<string, unknown> = {};
  await recordOperationalHealthEvent(
    client((value) => {
      row = value;
      return { error: null };
    }),
    {
      service: privateValue,
      component: privateValue,
      status: "warn",
      message: privateValue,
      functionName: privateValue,
      issueCode: privateValue,
      userId: privateValue,
      subjectType: privateValue,
      subjectId: privateValue,
      metadata: {
        payload: privateValue,
        parse_status: "failed",
        matched_reference: privateValue,
      },
      occurredAt: privateValue,
      ingestOrigin: "mobile_app",
    },
  );
  assertEquals(row.service, "client");
  assertEquals(row.component, "general");
  assertEquals(row.function_name, null);
  assertEquals(row.issue_code, "operational_event");
  assertEquals(row.status, "warn");
  assertEquals(row.severity, "warning");
  assertEquals(row.ingest_origin, "mobile_app");
  assertEquals(row.metadata, { parse_status: "failed" });
  assertFalse(JSON.stringify(row).includes(privateValue));
});

for (const thrown of [false, true]) {
  Deno.test(`health diagnostic insert ${thrown ? "exception" : "error"} stays safe and resolves without changing caller flow`, async () => {
    const logs: string[] = [];
    const saved = console.error;
    try {
      console.error = (value) => logs.push(String(value));
      await recordOperationalHealthEvent(
        client(() => {
          if (thrown) throw new Error(privateValue);
          return { error: { message: privateValue, details: privateValue } };
        }),
        { service: "momo_parsing", status: "error", message: privateValue },
      );
      assertEquals(logs.length, 1);
      assertFalse(logs[0].includes(privateValue));
      assertEquals(
        JSON.parse(logs[0]).error_name,
        thrown ? "Error" : "UnknownError",
      );
    } finally {
      console.error = saved;
    }
  });
}

Deno.test("safe health success retains reviewed enums and the supplied ISO occurrence", async () => {
  let row: Record<string, unknown> = {};
  await recordOperationalHealthEvent(
    client((value) => {
      row = value;
      return { error: null };
    }),
    {
      service: "momo_parsing",
      component: "parse-momo-sms",
      status: "ok",
      message: privateValue,
      occurredAt: "2026-09-30T10:00:00Z",
      metadata: {
        parser_provider: "gemini",
        parse_status: "parsed",
        match_status: "matched",
        parsed_sms_id: privateValue,
      },
    },
  );
  assertEquals(row.status, "ok");
  assertEquals(row.severity, "info");
  assertEquals(row.issue_code, null);
  assertEquals(row.occurred_at, "2026-09-30T10:00:00Z");
  assertEquals(row.metadata, {
    parser_provider: "gemini",
    parse_status: "parsed",
    match_status: "matched",
  });
  assertFalse(JSON.stringify(row).includes(privateValue));
});

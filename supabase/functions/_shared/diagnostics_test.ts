import { assert, assertEquals, assertFalse } from "jsr:@std/assert";
import {
  diagnosticError,
  diagnosticMetadata,
  logDiagnostic,
} from "./diagnostics.ts";
import { DIAGNOSTIC_EVENTS } from "./diagnostic_events.ts";

const privateValue =
  "person@example.test +250788123456 https://private.invalid/path?token=secret user-77 receipt-11";

Deno.test("diagnostic logs exclude raw messages, stacks, identity, URLs and metadata at every level", () => {
  const events: unknown[][] = [];
  const saved = {
    error: console.error,
    warn: console.warn,
    info: console.info,
    debug: console.debug,
  };
  try {
    for (const level of ["error", "warn", "info", "debug"] as const) {
      console[level] = (...args) => events.push(args);
    }
    const error = new TypeError(privateValue);
    Object.assign(error, {
      http_status: 503,
      token: privateValue,
      user_id: privateValue,
      stack: privateValue,
    });
    for (const level of ["error", "warn", "info", "debug"] as const) {
      logDiagnostic(
        level,
        "observability_operational_health_event_insert_failed",
        error,
        {
          count: 3,
          retryable: true,
          parser_provider: "openai",
          arbitrary: { raw: privateValue },
          path: privateValue,
          phone: privateValue,
          userId: privateValue,
          subjectId: privateValue,
        },
      );
    }
    assertEquals(events.length, 4);
    for (const args of events) {
      assertEquals(args.length, 1);
      const text = String(args[0]);
      assertFalse(text.includes(privateValue));
      assertEquals(JSON.parse(text), {
        event: "observability_operational_health_event_insert_failed",
        parser_provider: "openai",
        count: 3,
        retryable: true,
        http_status: 503,
        error_name: "TypeError",
      });
    }
  } finally {
    Object.assign(console, saved);
  }
});

Deno.test("unknown diagnostic event labels and custom error names fail closed", () => {
  let output = "";
  const saved = console.error;
  try {
    console.error = (value) => {
      output = String(value);
    };
    const error = new Error(privateValue);
    error.name = privateValue;
    logDiagnostic("error", privateValue, error);
    assertEquals(JSON.parse(output), {
      event: "unknown_diagnostic",
      error_name: "UnknownError",
    });
  } finally {
    console.error = saved;
  }
});

Deno.test("metadata rejects nested/cyclic data, unsafe enums, nonfinite and oversized metrics", () => {
  const cyclic: Record<string, unknown> = {};
  cyclic.self = cyclic;
  assertEquals(
    diagnosticMetadata({
      count: Infinity,
      attempt: -1,
      duration_ms: 1e12,
      http_status: 600,
      parser_provider: privateValue,
      error_name: privateValue,
      retryable: "true",
      raw: cyclic,
    }),
    {},
  );
  assertEquals(diagnosticError({ status: 429, message: privateValue }), {
    http_status: 429,
    error_name: "UnknownError",
  });
  assertEquals(
    diagnosticMetadata({
      count: 0,
      duration_ms: 125,
      http_status: 429,
      parse_status: "failed",
      parser_provider: "gemini",
    }),
    {
      parser_provider: "gemini",
      parse_status: "failed",
      count: 0,
      duration_ms: 125,
      http_status: 429,
    },
  );
});

Deno.test("diagnostic sinks never invoke getters, serializers or inherited metadata", () => {
  let reads = 0;
  const input = Object.create({ count: 88 });
  Object.defineProperties(input, {
    parser_provider: {
      get() {
        reads++;
        throw new Error(privateValue);
      },
    },
    name: {
      get() {
        reads++;
        throw new Error(privateValue);
      },
    },
    toJSON: {
      value() {
        reads++;
        throw new Error(privateValue);
      },
    },
  });
  assertEquals(diagnosticMetadata(input), {});
  assertEquals(diagnosticError(input), { error_name: "UnknownError" });
  assertEquals(reads, 0);
  const proxy = new Proxy({}, {
    ownKeys() {
      throw new Error(privateValue);
    },
  });
  assertEquals(diagnosticMetadata(proxy), {});
});

Deno.test("every deployed function diagnostic call uses a fixed catalog event and the shared sink", async () => {
  const root = new URL("../", import.meta.url);
  let calls = 0;
  for await (const directory of Deno.readDir(root)) {
    if (!directory.isDirectory) continue;
    for await (
      const file of Deno.readDir(new URL(directory.name + "/", root))
    ) {
      if (
        !file.isFile || !file.name.endsWith(".ts") ||
        /(?:_test|\.test)\.ts$/.test(file.name) ||
        ["diagnostics.ts", "diagnostic_events.ts"].includes(file.name)
      ) continue;
      const source = await Deno.readTextFile(
        new URL(directory.name + "/" + file.name, root),
      );
      assertFalse(
        /\bconsole\s*(?:\.|\[)/.test(source),
        `${directory.name}/${file.name} bypasses diagnostics`,
      );
      for (
        const match of source.matchAll(
          /logDiagnostic\s*\(\s*"(?:error|warn|info|debug)",\s*"([^"]+)"/g,
        )
      ) {
        calls++;
        assert(
          DIAGNOSTIC_EVENTS.has(match[1]),
          "diagnostic code absent from catalog",
        );
      }
    }
  }
  assertEquals(calls, 61);
});

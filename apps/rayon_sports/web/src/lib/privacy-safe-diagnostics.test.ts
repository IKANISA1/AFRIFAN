import { afterEach, describe, expect, it, vi } from "vitest";
import { recordProductDiagnostic, type ProductDiagnostic } from "./privacy-safe-diagnostics";

afterEach(() => vi.restoreAllMocks());

describe("privacy safe product diagnostics", () => {
  it("emits one finite event with no error, transport or actor context", () => {
    const sink = vi.spyOn(console, "error").mockImplementation(() => {});
    expect(recordProductDiagnostic("feature_config_rpc_failed")).toBe(true);
    expect(sink).toHaveBeenCalledExactlyOnceWith({ schemaVersion: 1,
      service: "web", event: "feature_config_rpc_failed", level: "error" });
    expect(Object.isFrozen(sink.mock.calls[0][0])).toBe(true);
  });
  it.each(["synthetic-private-token", "https://private.invalid/?token=synthetic", "+250700000099", "__proto__"])(
    "rejects arbitrary diagnostic input %s", value => {
      const sink = vi.spyOn(console, "error").mockImplementation(() => {});
      expect(recordProductDiagnostic(value as ProductDiagnostic)).toBe(false);
      expect(sink).not.toHaveBeenCalled();
    });
  it("never reads or serializes a foreign error object", () => {
    const toString = vi.fn(() => "private error");
    expect(recordProductDiagnostic({ toString } as unknown as ProductDiagnostic)).toBe(false);
    expect(toString).not.toHaveBeenCalled();
  });
  it("a diagnostic sink failure cannot throw into a command", () => {
    vi.spyOn(console, "error").mockImplementation(() => { throw Error("private sink"); });
    expect(recordProductDiagnostic("push_subscription_failed")).toBe(false);
  });
});

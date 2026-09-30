import { afterEach, describe, expect, it, vi } from "vitest";
import { shareContent } from "./share";

vi.mock("@/lib/config", () => ({ siteConfig: { shortTitle: "Synthetic club" } }));
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals(); });

describe("share cancellation and finite diagnostics", () => {
  it("native cancellation does not copy content or log an error", async () => {
    const copy = vi.fn(), share = vi.fn().mockRejectedValue(new DOMException("private context", "AbortError"));
    vi.stubGlobal("navigator", { share, clipboard: { writeText: copy } });
    const log = vi.spyOn(console, "warn").mockImplementation(() => {});
    expect(await shareContent({ title: "private", url: "https://private.invalid" })).toBe(false);
    expect(copy).not.toHaveBeenCalled(); expect(log).not.toHaveBeenCalled();
    expect(share).toHaveBeenCalledTimes(1);
  });
  it("a failed share falls back once without logging private error or shared content", async () => {
    const copy = vi.fn().mockResolvedValue(undefined), url = "https://private.invalid/?token=synthetic";
    vi.stubGlobal("navigator", { share: vi.fn().mockRejectedValue(Error("private token +250700000099")),
      clipboard: { writeText: copy } });
    const log = vi.spyOn(console, "warn").mockImplementation(() => {});
    expect(await shareContent({ title: "private title", url })).toBe(true);
    expect(copy).toHaveBeenCalledExactlyOnceWith(url);
    expect(log).toHaveBeenCalledExactlyOnceWith({ schemaVersion: 1, service: "web",
      event: "share_fallback", level: "warn" });
    expect(JSON.stringify(log.mock.calls)).not.toContain("private");
    expect(JSON.stringify(log.mock.calls)).not.toContain("+250700000099");
  });
  it.each([false, "throws"])("legacy clipboard %s cannot claim success and removes its temporary field", async result => {
    vi.stubGlobal("navigator", {});
    const command = vi.fn(() => { if (result === "throws") throw Error("private clipboard"); return false; });
    vi.stubGlobal("document", { createElement: () => ({ style: {}, select: vi.fn(), value: "" }),
      body: { appendChild: vi.fn(), removeChild: vi.fn() }, execCommand: command });
    expect(await shareContent({ title: "private", url: "private" })).toBe(false);
    expect(command).toHaveBeenCalledExactlyOnceWith("copy");
    expect(document.body.removeChild).toHaveBeenCalledTimes(1);
  });
});

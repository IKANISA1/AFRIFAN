import { act, fireEvent, render, screen } from "@testing-library/react";
import { PwaShell } from "./pwa-shell";
import { IosSafariInstallGuide } from "./ios-safari-install-guide";

vi.mock("next/navigation", () => ({ usePathname: () => "/admin/content" }));
vi.mock("@/lib/pwa-analytics", () => ({
  currentDisplayMode: () => "browser",
  trackPwaEvent: vi.fn(),
}));

describe("PWA storage recovery", () => {
  beforeEach(() => {
    vi.stubGlobal("matchMedia", vi.fn(() => ({ matches: false })));
    vi.spyOn(navigator, "onLine", "get").mockReturnValue(false);
  });

  afterEach(() => {
    vi.restoreAllMocks();
    vi.unstubAllGlobals();
    vi.unstubAllEnvs();
  });

  it.each(["getItem", "setItem"] as const)(
    "keeps offline recovery usable when browser storage %s throws",
    async (method) => {
      const pending: VoidFunction[] = [];
      vi.spyOn(globalThis, "queueMicrotask").mockImplementation((callback) => { pending.push(callback); });
      vi.spyOn(Storage.prototype, method).mockImplementation(() => {
        throw new DOMException("Storage unavailable", method === "getItem" ? "SecurityError" : "QuotaExceededError");
      });
      render(<PwaShell />);
      await act(async () => {
        for (const callback of pending) expect(callback).not.toThrow();
      });
      expect(screen.getByText(/You’re offline/)).toBeVisible();
      fireEvent(window, new Event("online"));
      expect(screen.queryByText(/You’re offline/)).not.toBeInTheDocument();
    },
  );

  it("keeps the iOS guide dismissible when session storage is denied", async () => {
    vi.spyOn(navigator, "userAgent", "get").mockReturnValue("iPhone Safari/605.1");
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => { throw new DOMException("Denied", "SecurityError"); });
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => { throw new DOMException("Denied", "SecurityError"); });
    render(<IosSafariInstallGuide showAfterMs={0} />);
    expect(await screen.findByRole("dialog", { name: "Install the club site on your device" })).toBeVisible();
    fireEvent.click(screen.getByRole("button", { name: /got it|not now|dismiss/i }));
    expect(screen.queryByRole("dialog")).not.toBeInTheDocument();
  });

  it("keeps unfinished form input and leaves the waiting worker untouched when refresh is cancelled", async () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.spyOn(navigator, "onLine", "get").mockReturnValue(true);
    const postMessage = vi.fn();
    const registration = Object.assign(new EventTarget(), { waiting: { postMessage } });
    vi.stubGlobal("navigator", Object.assign(Object.create(navigator), {
      serviceWorker: Object.assign(new EventTarget(), { register: vi.fn().mockResolvedValue(registration) }),
    }));
    render(<><label>Article title<input defaultValue="Unfinished article" /></label><PwaShell /></>);
    fireEvent.click(await screen.findByRole("button", { name: "Refresh app" }));
    expect(screen.getByRole("button", { name: "Keep editing" })).toHaveFocus();
    expect(postMessage).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole("button", { name: "Keep editing" }));
    expect(screen.getByLabelText("Article title")).toHaveValue("Unfinished article");
    expect(postMessage).not.toHaveBeenCalled();
    expect(screen.queryByRole("button", { name: "Refresh now" })).not.toBeInTheDocument();
  });
});

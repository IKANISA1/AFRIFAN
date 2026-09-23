import {
  buildAdminDestructiveConfirmation,
  confirmAdminDestructiveAction,
} from "./admin-destructive-confirm";

const options = {
  action: "Delete",
  subject: "the selected record",
  scope: "Active club only",
  impact: "The record disappears from the supporter app.",
  undo: "not_available" as const,
};

describe("admin destructive confirmation", () => {
  it("shows the action, subject, scope, impact, and recovery disposition", () => {
    expect(buildAdminDestructiveConfirmation(options)).toBe(
      [
        "Delete the selected record?",
        "Scope: Active club only",
        "Impact: The record disappears from the supporter app.",
        "Recovery: This action cannot be undone.",
        "Continue only after reviewing the scope and impact.",
      ].join("\n\n"),
    );
  });

  it("fails closed when invoked outside the browser", () => {
    const originalWindow = globalThis.window;
    vi.stubGlobal("window", undefined);
    expect(confirmAdminDestructiveAction(options)).toBe(false);
    vi.stubGlobal("window", originalWindow);
  });

  it("passes the governed review text to the browser confirmation", () => {
    const confirm = vi.fn().mockReturnValue(true);
    vi.stubGlobal("window", { confirm });

    expect(
      confirmAdminDestructiveAction({
        ...options,
        undo: "manual_recovery",
      }),
    ).toBe(true);
    expect(confirm).toHaveBeenCalledWith(
      expect.stringContaining(
        "Recovery: Recovery requires a separate manual admin action.",
      ),
    );
    vi.unstubAllGlobals();
  });
});

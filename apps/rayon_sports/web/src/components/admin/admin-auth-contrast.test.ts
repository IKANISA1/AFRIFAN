import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

function luminance(hex: string) {
  const channels =
    hex
      .replace("#", "")
      .match(/.{2}/g)
      ?.map((value) => Number.parseInt(value, 16) / 255) ?? [];
  const linear = channels.map((value) =>
    value <= 0.04045
      ? value / 12.92
      : Math.pow((value + 0.055) / 1.055, 2.4),
  );
  return (
    linear[0]! * 0.2126 + linear[1]! * 0.7152 + linear[2]! * 0.0722
  );
}

function contrast(foreground: string, background: string) {
  const values = [luminance(foreground), luminance(background)].sort(
    (left, right) => right - left,
  );
  return (values[0]! + 0.05) / (values[1]! + 0.05);
}

describe("Admin authentication contrast contract", () => {
  it("keeps every sign-in text role at WCAG AA or better in light and dark", () => {
    const pairs = [
      ["#f6f8fc", "#0e172a"],
      ["#9eabc2", "#0e172a"],
      ["#25d366", "#0e172a"],
      ["#0d1627", "#ffffff"],
      ["#526277", "#ffffff"],
      ["#087a42", "#ffffff"],
      ["#ffffff", "#0f766e"],
      ["#ffffff", "#075e54"],
    ] as const;

    for (const [foreground, background] of pairs) {
      expect(contrast(foreground, background)).toBeGreaterThanOrEqual(4.5);
    }
  });

  it("uses semantic theme roles and library icons instead of light-only copy or drawn assets", () => {
    const shell = readFileSync(
      join(
        process.cwd(),
        "src/components/admin/admin-shell.tsx",
      ),
      "utf8",
    );
    const authCard = shell.slice(
      shell.indexOf("function AdminAuthCard"),
      shell.indexOf("function AdminUnauthorizedCard"),
    );
    const theme = readFileSync(
      join(process.cwd(), "src/ui-kit/admin.css"),
      "utf8",
    );

    expect(authCard).toContain("var(--admin-text-strong)");
    expect(authCard).toContain("var(--admin-text-muted)");
    expect(authCard).toContain("var(--admin-auth-accent)");
    expect(authCard).toContain("var(--admin-danger-text)");
    expect(authCard).toContain("RW +250");
    expect(authCard).not.toContain("text-slate-");
    expect(authCard).not.toContain("WhatsAppIcon");
    expect(authCard).not.toContain("<svg");
    expect(authCard).not.toContain("🇷🇼");
    expect(authCard).toContain("text-[1.75rem]");
    expect(authCard).toContain("sm:text-[2.6rem]");
    expect(authCard).toContain("tracking-[0.14em]");
    expect(authCard).toContain("sm:tracking-[0.2em]");
    expect(theme).toContain("--admin-auth-accent: #25d366");
    expect(theme).toContain("--admin-auth-accent: #087a42");
  });
});

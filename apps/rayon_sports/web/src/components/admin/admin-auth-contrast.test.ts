import { readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import postcss from "postcss";

function luminance(hex: string) {
  const channels =
    hex
      .replace(/^#([a-f0-9])([a-f0-9])([a-f0-9])$/i, "#$1$1$2$2$3$3")
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
    for (const light of [false, true]) {
      const values = new Map<string, string>();
      for (const file of ["tokens.css", "admin.css"]) {
        const css = postcss.parse(readFileSync(join(process.cwd(), "src/ui-kit", file), "utf8"));
        css.walkRules((rule) => {
          if (![":root", ".admin-workspace"].includes(rule.selector)) return;
          const media = rule.parent;
          if (media?.type === "atrule" && media.name === "media" &&
              (!light || !media.params.includes("prefers-color-scheme: light"))) return;
          rule.walkDecls((declaration) => { values.set(declaration.prop, declaration.value); });
        });
      }
      const resolve = (role: string): string => {
        const value = values.get(role)!;
        return value.startsWith("var(") ? resolve(value.slice(4, -1)) : value;
      };
      for (const role of ["--admin-text-strong", "--admin-text-muted", "--admin-auth-accent", "--admin-danger-text"]) {
        expect(contrast(resolve(role), resolve("--admin-surface")), `${light ? "light" : "dark"} ${role}`).toBeGreaterThanOrEqual(4.5);
      }
      expect(contrast(resolve("--admin-canvas"), resolve("--admin-foreground"))).toBeGreaterThanOrEqual(4.5);
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
    expect(authCard).toContain("<OtpDigitInput value={code} length={6}");
    expect(theme).toContain("--admin-auth-accent: var(--accent)");
    expect(theme).toContain("--admin-auth-accent: var(--inverse-accent)");
  });
});

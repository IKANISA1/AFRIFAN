import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "../../../..");

const sourceFiles = {
  colors: path.join(
    repoRoot,
    "packages/core/core_theme/lib/src/tokens/color_tokens.dart",
  ),
  shapes: path.join(
    repoRoot,
    "packages/core/core_theme/lib/src/tokens/shape_tokens.dart",
  ),
  blur: path.join(
    repoRoot,
    "packages/core/core_theme/lib/src/tokens/blur_tokens.dart",
  ),
  borders: path.join(
    repoRoot,
    "packages/core/core_theme/lib/src/tokens/border_tokens.dart",
  ),
};

const outputFile = path.join(
  repoRoot,
  "apps/rayon_sports/web/src/design-system/tokens.generated.css",
);

function readFile(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function escapePattern(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractHex(source, tokenName) {
  const pattern = new RegExp(
    `(?:static\\s+(?:const\\s+)?Color\\s+${escapePattern(tokenName)}\\s*=\\s*(?:const\\s+)?Color\\(0xFF([0-9A-Fa-f]{6})\\);)`,
  );
  const match = source.match(pattern);
  if (!match) {
    throw new Error(`Unable to resolve color token "${tokenName}".`);
  }
  return `#${match[1].toLowerCase()}`;
}

function extractGetterHex(source, getterName) {
  const pattern = new RegExp(
    `static\\s+Color\\s+get\\s+${escapePattern(getterName)}\\s*=>\\s*isDark\\s*\\?\\s*const\\s+Color\\(0xFF([0-9A-Fa-f]{6})\\)`,
  );
  const match = source.match(pattern);
  if (!match) {
    throw new Error(`Unable to resolve getter token "${getterName}".`);
  }
  return `#${match[1].toLowerCase()}`;
}

function extractDouble(source, tokenName) {
  const pattern = new RegExp(
    `static\\s+const\\s+double\\s+${escapePattern(tokenName)}\\s*=\\s*([0-9.]+);`,
  );
  const match = source.match(pattern);
  if (!match) {
    throw new Error(`Unable to resolve numeric token "${tokenName}".`);
  }
  return Number(match[1]);
}

function hexToRgb(hex) {
  const value = hex.replace("#", "");
  return {
    r: Number.parseInt(value.slice(0, 2), 16),
    g: Number.parseInt(value.slice(2, 4), 16),
    b: Number.parseInt(value.slice(4, 6), 16),
  };
}

function rgba(hex, alpha) {
  const { r, g, b } = hexToRgb(hex);
  return `rgba(${r}, ${g}, ${b}, ${alpha.toFixed(2).replace(/0+$/, "").replace(/\.$/, "")})`;
}

function mix(hexA, hexB, weightB) {
  const a = hexToRgb(hexA);
  const b = hexToRgb(hexB);
  const weightA = 1 - weightB;
  const toChannel = (left, right) =>
    Math.round(left * weightA + right * weightB)
      .toString(16)
      .padStart(2, "0");

  return `#${toChannel(a.r, b.r)}${toChannel(a.g, b.g)}${toChannel(a.b, b.b)}`;
}

function alphaBlend(foreground, background) {
  const fg = typeof foreground === "string" ? { ...hexToRgb(foreground), a: 1 } : foreground;
  const bg = typeof background === "string" ? { ...hexToRgb(background), a: 1 } : background;
  const outAlpha = fg.a + bg.a * (1 - fg.a);

  if (outAlpha <= 0) {
    return { r: 0, g: 0, b: 0, a: 0 };
  }

  return {
    r: Math.round((fg.r * fg.a + bg.r * bg.a * (1 - fg.a)) / outAlpha),
    g: Math.round((fg.g * fg.a + bg.g * bg.a * (1 - fg.a)) / outAlpha),
    b: Math.round((fg.b * fg.a + bg.b * bg.a * (1 - fg.a)) / outAlpha),
    a: outAlpha,
  };
}

function shadowValue({ x = 0, y = 0, blur = 0, spread = 0, color }) {
  return `${x}px ${y}px ${blur}px ${spread}px ${color}`;
}

const colorSource = readFile(sourceFiles.colors);
const shapeSource = readFile(sourceFiles.shapes);
const blurSource = readFile(sourceFiles.blur);
const borderSource = readFile(sourceFiles.borders);

const tokens = {
  voidBase: extractHex(colorSource, "_voidBase"),
  defaultSecondary: extractHex(colorSource, "_defaultSecondary"),
  surfaceContainerLowest: extractHex(colorSource, "_darkSurfaceContainerLowest"),
  surfaceContainerLow: extractHex(colorSource, "_darkSurfaceContainerLow"),
  surfaceContainer: extractHex(colorSource, "_darkSurfaceContainer"),
  surface: extractHex(colorSource, "_darkSurface"),
  surfaceContainerHigh: extractHex(colorSource, "_darkSurfaceContainerHigh"),
  surfaceContainerHighest: extractHex(colorSource, "_darkSurfaceContainerHighest"),
  surfaceBright: extractHex(colorSource, "_darkSurfaceBright"),
  primary: extractHex(colorSource, "_monolithViolet"),
  primaryContainer: extractHex(colorSource, "_monolithOrchid"),
  secondaryContainer: extractHex(colorSource, "_darkSecondaryContainer"),
  onSurface: extractGetterHex(colorSource, "onSurface"),
  onSurfaceVariant: extractGetterHex(colorSource, "onSurfaceVariant"),
  success: extractHex(colorSource, "success"),
  warning: extractHex(colorSource, "warning"),
  error: extractHex(colorSource, "error"),
  info: extractHex(colorSource, "info"),
  radiusSm: extractDouble(shapeSource, "radiusSm"),
  radiusMd: extractDouble(shapeSource, "radiusMd"),
  radiusLg: extractDouble(shapeSource, "radiusLg"),
  radiusXl: extractDouble(shapeSource, "radiusXl"),
  radiusFull: extractDouble(shapeSource, "radiusFull"),
  blurSubtle: extractDouble(blurSource, "subtle"),
  blurStandard: extractDouble(blurSource, "standard"),
  blurOverlay: extractDouble(blurSource, "overlay"),
  blurAtmospheric: extractDouble(blurSource, "atmospheric"),
  borderHairline: extractDouble(borderSource, "hairline"),
  borderFocus: extractDouble(borderSource, "focus"),
};

const ambient = alphaBlend(
  { ...hexToRgb(tokens.defaultSecondary), a: 0.22 },
  { ...hexToRgb("#080614"), a: 0.92 },
);
const ambientHex = `#${[ambient.r, ambient.g, ambient.b]
  .map((channel) => channel.toString(16).padStart(2, "0"))
  .join("")}`;

const generated = `/* AUTO-GENERATED FILE. DO NOT EDIT.
 * Source of truth:
 * - packages/core/core_theme/lib/src/tokens/color_tokens.dart
 * - packages/core/core_theme/lib/src/tokens/shape_tokens.dart
 * - packages/core/core_theme/lib/src/tokens/blur_tokens.dart
 * - packages/core/core_theme/lib/src/tokens/border_tokens.dart
 */

:root {
  color-scheme: dark;

  --void: ${tokens.voidBase};
  --background: ${tokens.voidBase};
  --surface-dim: ${tokens.voidBase};
  --surface-container-lowest: ${tokens.surfaceContainerLowest};
  --surface-container-low: ${tokens.surfaceContainerLow};
  --surface-container: ${tokens.surfaceContainer};
  --surface: ${tokens.surface};
  --surface-container-high: ${tokens.surfaceContainerHigh};
  --surface-container-highest: ${tokens.surfaceContainerHighest};
  --surface-bright: ${tokens.surfaceBright};
  --surface-variant: ${rgba(tokens.surfaceContainerHigh, 0.18)};
  --surface-strong: ${rgba(tokens.surfaceContainerLowest, 0.88)};
  --surface-card: ${rgba(tokens.surfaceContainer, 0.78)};
  --surface-elevated: ${rgba(tokens.surfaceContainerHighest, 0.88)};
  --surface-hero: ${rgba(tokens.primary, 0.08)};

  --primary: ${tokens.primary};
  --primary-container: ${tokens.primaryContainer};
  --secondary-container: ${tokens.secondaryContainer};
  --outline-variant: ${rgba("#ffffff", 0.12)};
  --outline-ghost: ${rgba(tokens.primaryContainer, 0.15)};
  --outline-focus: ${rgba(tokens.primaryContainer, 0.4)};
  --glass-fill: ${rgba(tokens.surfaceBright, 0.6)};

  --foreground: ${tokens.onSurface};
  --foreground-muted: ${rgba(tokens.onSurfaceVariant, 0.92)};
  --foreground-soft: ${rgba(tokens.onSurfaceVariant, 0.72)};
  --foreground-faint: ${rgba(tokens.onSurfaceVariant, 0.52)};

  --border-soft: ${rgba(tokens.primaryContainer, 0.15)};
  --border-hover: ${rgba(tokens.primaryContainer, 0.22)};

  --club-primary: ${tokens.primary};
  --club-primary-light: ${tokens.primaryContainer};
  --club-primary-dark: ${mix(tokens.primary, tokens.voidBase, 0.28)};
  --club-primary-glow: ${rgba(tokens.primary, 0.34)};
  --club-secondary: ${tokens.onSurfaceVariant};
  --club-accent: ${tokens.onSurface};
  --club-accent-light: #ffffff;
  --club-ink: ${mix(tokens.surfaceContainerLowest, tokens.voidBase, 0.24)};

  --success: ${tokens.success};
  --warning: ${tokens.warning};
  --error: ${tokens.error};
  --info: ${tokens.info};

  --radius-sm: ${tokens.radiusSm}px;
  --radius-md: ${tokens.radiusMd}px;
  --radius-lg: ${tokens.radiusLg}px;
  --radius-xl: ${tokens.radiusXl}px;
  --radius-pill: ${tokens.radiusFull}px;

  --blur-subtle: ${tokens.blurSubtle}px;
  --blur-standard: ${tokens.blurStandard}px;
  --blur-overlay: ${tokens.blurOverlay}px;
  --blur-atmospheric: ${tokens.blurAtmospheric}px;

  --border-hairline: ${tokens.borderHairline}px;
  --border-focus: ${tokens.borderFocus}px;

  --shadow-standard: ${shadowValue({
    y: 10,
    blur: 28,
    spread: -6,
    color: rgba(ambientHex, 0.24),
  })};
  --shadow-floating: ${shadowValue({
    y: 20,
    blur: 80,
    spread: -10,
    color: rgba(ambientHex, 0.42),
  })};
  --shadow-glass: ${shadowValue({
    y: 20,
    blur: 80,
    spread: -10,
    color: rgba(ambientHex, 0.4),
  })};
  --shadow-primary-glow-token: ${shadowValue({
    y: 10,
    blur: 36,
    spread: -6,
    color: rgba(tokens.primary, 0.34),
  })};
  --shadow-clay-highlight: ${shadowValue({
    x: -6,
    y: -6,
    blur: 14,
    spread: -6,
    color: rgba("#ffffff", 0.18),
  })};
  --shadow-clay-depth: ${shadowValue({
    x: 10,
    y: 12,
    blur: 20,
    spread: -8,
    color: rgba(ambientHex, 0.28),
  })};
}
`;

const checkOnly = process.argv.includes("--check");
const current = fs.existsSync(outputFile) ? readFile(outputFile) : "";

if (checkOnly) {
  if (current !== generated) {
    console.error(
      "Generated design tokens are out of date. Run `npm run design-system:sync`.",
    );
    process.exit(1);
  }
  process.stdout.write("Design tokens are up to date.\n");
  process.exit(0);
}

fs.writeFileSync(outputFile, generated);
process.stdout.write(`Wrote ${path.relative(repoRoot, outputFile)}.\n`);

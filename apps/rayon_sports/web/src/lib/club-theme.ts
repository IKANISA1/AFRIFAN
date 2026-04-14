import type { CSSProperties } from "react";
import type { ClubProfile } from "@/lib/types";

type ThemeStyle = CSSProperties & Record<`--${string}`, string>;

const DEFAULT_PRIMARY = "#0038A8";
const DEFAULT_ACCENT = "#D4A017";
const DEFAULT_INK = "#F8FBFF";

function clampChannel(value: number) {
  return Math.max(0, Math.min(255, Math.round(value)));
}

function normalizeHexColor(value: string | null | undefined, fallback: string) {
  const candidate = (value ?? "").trim();
  if (!/^#?[0-9a-fA-F]{6}$/.test(candidate)) {
    return fallback;
  }

  return candidate.startsWith("#") ? candidate.toUpperCase() : `#${candidate.toUpperCase()}`;
}

function hexToRgb(hex: string) {
  const normalized = normalizeHexColor(hex, DEFAULT_PRIMARY).slice(1);
  return {
    red: Number.parseInt(normalized.slice(0, 2), 16),
    green: Number.parseInt(normalized.slice(2, 4), 16),
    blue: Number.parseInt(normalized.slice(4, 6), 16),
  };
}

function rgbToHex({
  red,
  green,
  blue,
}: {
  red: number;
  green: number;
  blue: number;
}) {
  return `#${[red, green, blue]
    .map((channel) => clampChannel(channel).toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase()}`;
}

function mixHex(base: string, overlay: string, weight: number) {
  const ratio = Math.max(0, Math.min(1, weight));
  const baseRgb = hexToRgb(base);
  const overlayRgb = hexToRgb(overlay);

  return rgbToHex({
    red: baseRgb.red + (overlayRgb.red - baseRgb.red) * ratio,
    green: baseRgb.green + (overlayRgb.green - baseRgb.green) * ratio,
    blue: baseRgb.blue + (overlayRgb.blue - baseRgb.blue) * ratio,
  });
}

function alpha(hex: string, opacity: number) {
  const { red, green, blue } = hexToRgb(hex);
  return `rgba(${red}, ${green}, ${blue}, ${Math.max(0, Math.min(1, opacity))})`;
}

function resolveInkColor(primary: string, accent: string) {
  const { red, green, blue } = hexToRgb(primary);
  const luminance = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255;
  if (luminance > 0.66) {
    return mixHex(primary, "#05101D", 0.86);
  }

  const accentLuminance = (() => {
    const accentRgb = hexToRgb(accent);
    return (0.2126 * accentRgb.red + 0.7152 * accentRgb.green + 0.0722 * accentRgb.blue) / 255;
  })();

  return accentLuminance > 0.58 ? "#06111F" : DEFAULT_INK;
}

export function buildClubThemeStyle(
  club: Pick<
    ClubProfile,
    | "primaryColorHex"
    | "secondaryColorHex"
    | "accentColorHex"
    | "defaultLanguage"
  >,
): ThemeStyle {
  const primary = normalizeHexColor(club.primaryColorHex, DEFAULT_PRIMARY);
  const secondary = normalizeHexColor(
    club.secondaryColorHex,
    mixHex(primary, "#5A6ACF", 0.34),
  );
  const accent = normalizeHexColor(club.accentColorHex, DEFAULT_ACCENT);
  const ink = resolveInkColor(primary, accent);
  const primaryLight = mixHex(primary, "#FFFFFF", 0.24);
  const primaryDark = mixHex(primary, "#07111E", 0.46);
  const secondarySoft = mixHex(secondary, "#F6F9FF", 0.3);
  const accentSoft = mixHex(accent, "#FFFFFF", 0.4);
  const backgroundStart = mixHex(primary, "#03050A", 0.84);
  const backgroundMid = mixHex(secondary, "#07111E", 0.78);
  const backgroundEnd = mixHex(primaryDark, "#02040A", 0.7);
  const surface = alpha(mixHex(primary, "#0A1523", 0.7), 0.8);
  const surfaceStrong = alpha(mixHex(primaryDark, "#030509", 0.5), 0.92);
  const surfaceRaised = alpha(mixHex(secondary, "#111C2E", 0.48), 0.72);

  return {
    "--club-primary": primary,
    "--club-primary-light": primaryLight,
    "--club-primary-dark": primaryDark,
    "--club-secondary": secondarySoft,
    "--club-accent": accent,
    "--club-accent-light": accentSoft,
    "--club-ink": ink,
    "--club-primary-glow": alpha(primary, 0.36),
    "--site-bg-start": backgroundStart,
    "--site-bg-mid": backgroundMid,
    "--site-bg-end": backgroundEnd,
    "--site-surface": surface,
    "--site-surface-strong": surfaceStrong,
    "--site-surface-raised": surfaceRaised,
    "--site-shell-border": alpha(primaryLight, 0.24),
    "--site-glow-primary": alpha(primary, 0.26),
    "--site-glow-secondary": alpha(secondary, 0.18),
    "--site-glow-accent": alpha(accent, 0.16),
    "--site-copy-language": `"${club.defaultLanguage}"`,
  };
}

import { clsx } from "clsx";

import { rayonClub } from "@/lib/config";

export function cn(...values: Array<string | false | null | undefined>) {
  return clsx(values);
}

export function formatCurrency(
  value: number,
  currency = rayonClub.currencyCode,
  locale = "en-RW",
) {
  return new Intl.NumberFormat(locale, {
    style: "currency",
    currency,
    maximumFractionDigits: 0,
  }).format(value);
}

export function formatDate(value: string) {
  return new Intl.DateTimeFormat("en-RW", {
    weekday: "short",
    month: "short",
    day: "numeric",
  }).format(new Date(value));
}

export function formatDateTime(value: string) {
  return new Intl.DateTimeFormat("en-RW", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

export function formatCompactNumber(value: number, locale = "en-RW") {
  return new Intl.NumberFormat(locale, {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(value);
}

export function formatPercent(value: number, fractionDigits = 0) {
  return `${value.toFixed(fractionDigits)}%`;
}

export function getProgressPercent(current: number, target: number) {
  if (!Number.isFinite(current) || !Number.isFinite(target) || target <= 0) {
    return 0;
  }

  const raw = (current / target) * 100;
  return Math.max(0, Math.min(100, raw));
}

export function normalizeMatchStatus(status: string) {
  return safeString(status, "scheduled").toLowerCase();
}

export function isLiveMatch(status: string) {
  return normalizeMatchStatus(status) === "live";
}

export function isResultMatch(status: string) {
  const normalized = normalizeMatchStatus(status);
  return normalized === "fulltime" || normalized === "finished";
}

export function isUpcomingMatch(status: string) {
  return !isLiveMatch(status) && !isResultMatch(status);
}

export function formatMatchStatusLabel(status: string) {
  const normalized = normalizeMatchStatus(status);
  if (normalized === "fulltime") return "Full time";
  if (normalized === "live") return "Live";
  if (normalized === "scheduled") return "Upcoming";
  return normalized.replace(/[_-]+/g, " ");
}

export function getReadingTime(text: string) {
  const words = safeString(text).split(/\s+/).filter(Boolean).length;
  return Math.max(1, Math.round(words / 180));
}

export function slugify(value: string) {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function safeString(value: unknown, fallback = "") {
  return typeof value == "string" && value.trim().length > 0
    ? value.trim()
    : fallback;
}

export function isValidHexColor(value: string) {
  return /^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(value.trim());
}

export function sanitizeHexColorDraft(value: string) {
  const trimmed = value.trim();
  if (!trimmed) {
    return "";
  }

  const stripped = trimmed
    .replace(/^#/, "")
    .replace(/[^0-9a-fA-F]/g, "")
    .slice(0, 6)
    .toUpperCase();

  return stripped ? `#${stripped}` : "";
}

export function normalizeHexColorInput(value: string) {
  const sanitized = sanitizeHexColorDraft(value);
  if (!sanitized) {
    return "";
  }

  const hex = sanitized.slice(1);
  if (hex.length === 3) {
    return `#${hex
      .split("")
      .map((channel) => `${channel}${channel}`)
      .join("")}`;
  }

  return sanitized;
}

export function safeNumber(value: unknown, fallback = 0) {
  if (typeof value == "number" && Number.isFinite(value)) {
    return value;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function toIdString(value: unknown, fallback: string) {
  if (typeof value == "string" && value.trim()) {
    return value;
  }
  if (typeof value == "number" && Number.isFinite(value)) {
    return value.toString();
  }
  return fallback;
}

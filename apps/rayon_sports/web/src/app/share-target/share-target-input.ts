const CONTROL_CHARACTER_PATTERN = /[\u0000-\u001F\u007F]/g;

function firstValue(value: string | string[] | undefined) {
  if (Array.isArray(value)) {
    return value[0] ?? "";
  }

  return value ?? "";
}

export function boundedSharedText(
  value: string | string[] | undefined,
  maxLength: number,
) {
  return firstValue(value)
    .replace(CONTROL_CHARACTER_PATTERN, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

export function safeSharedWebUrl(
  value: string | string[] | undefined,
): string | null {
  const candidate = boundedSharedText(value, 2048);
  if (!candidate) return null;

  try {
    const parsed = new URL(candidate);
    return parsed.protocol === "https:" || parsed.protocol === "http:"
      ? parsed.toString()
      : null;
  } catch {
    return null;
  }
}

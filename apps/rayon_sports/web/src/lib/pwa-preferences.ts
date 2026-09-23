"use client";

type StorageArea = "local" | "session";

// Install preferences are optional. Private browsing, policy and quota errors
// must not prevent network recovery or leave a dismiss button unusable.
export function readPwaPreference(area: StorageArea, key: string): string | null {
  try {
    return (area === "local" ? window.localStorage : window.sessionStorage).getItem(key);
  } catch {
    return null;
  }
}

export function writePwaPreference(area: StorageArea, key: string, value: string | null): void {
  try {
    const storage = area === "local" ? window.localStorage : window.sessionStorage;
    if (value === null) storage.removeItem(key);
    else storage.setItem(key, value);
  } catch {
    // The component still keeps its current preference in memory.
  }
}

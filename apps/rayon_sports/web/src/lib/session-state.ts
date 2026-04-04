/**
 * Session state persistence helpers.
 *
 * Saves scroll position and form drafts to sessionStorage
 * so state is preserved across page navigations and
 * accidental refreshes (cross-device continuity within session).
 */

const SESSION_PREFIX = "gikundiro-session:";

/* ─── Scroll Position ────────────────────────────────────── */

/**
 * Save the current scroll position for a route.
 */
export function saveScrollPosition(routeKey: string): void {
  try {
    sessionStorage.setItem(
      `${SESSION_PREFIX}scroll:${routeKey}`,
      JSON.stringify({ x: window.scrollX, y: window.scrollY }),
    );
  } catch {
    // sessionStorage might be full or unavailable
  }
}

/**
 * Restore scroll position for a route.
 * Returns true if position was restored.
 */
export function restoreScrollPosition(routeKey: string): boolean {
  try {
    const raw = sessionStorage.getItem(`${SESSION_PREFIX}scroll:${routeKey}`);
    if (!raw) return false;

    const { x, y } = JSON.parse(raw) as { x: number; y: number };

    // Use requestAnimationFrame to wait for DOM render
    requestAnimationFrame(() => {
      window.scrollTo(x, y);
    });

    return true;
  } catch {
    return false;
  }
}

/* ─── Form Draft Persistence ─────────────────────────────── */

/**
 * Save a form draft to sessionStorage.
 */
export function saveFormDraft<T>(formKey: string, data: T): void {
  try {
    sessionStorage.setItem(
      `${SESSION_PREFIX}form:${formKey}`,
      JSON.stringify({ data, savedAt: Date.now() }),
    );
  } catch {
    // sessionStorage might be full
  }
}

/**
 * Load a form draft from sessionStorage.
 * Returns null if no draft exists or it's older than maxAgeMs.
 */
export function loadFormDraft<T>(
  formKey: string,
  maxAgeMs = 30 * 60 * 1000, // 30 minutes default
): T | null {
  try {
    const raw = sessionStorage.getItem(`${SESSION_PREFIX}form:${formKey}`);
    if (!raw) return null;

    const { data, savedAt } = JSON.parse(raw) as { data: T; savedAt: number };

    // Expire old drafts
    if (Date.now() - savedAt > maxAgeMs) {
      sessionStorage.removeItem(`${SESSION_PREFIX}form:${formKey}`);
      return null;
    }

    return data;
  } catch {
    return null;
  }
}

/**
 * Clear a specific form draft.
 */
export function clearFormDraft(formKey: string): void {
  try {
    sessionStorage.removeItem(`${SESSION_PREFIX}form:${formKey}`);
  } catch {
    // Ignore
  }
}

/**
 * Clear all session state.
 */
export function clearAllSessionState(): void {
  try {
    const keys: string[] = [];
    for (let i = 0; i < sessionStorage.length; i++) {
      const key = sessionStorage.key(i);
      if (key?.startsWith(SESSION_PREFIX)) {
        keys.push(key);
      }
    }
    for (const key of keys) {
      sessionStorage.removeItem(key);
    }
  } catch {
    // Ignore
  }
}

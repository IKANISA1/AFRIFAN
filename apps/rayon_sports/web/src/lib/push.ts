/**
 * Web Push subscription helpers.
 *
 * Usage:
 *   const sub = await subscribeToPush(registration);
 *   await sendSubscriptionToServer(sub);
 */

/* ─── VAPID public key (env-driven) ──────────────────────── */

function getVapidPublicKey(): string {
  const key = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY ?? "";
  if (!key) {
    console.warn("[push] NEXT_PUBLIC_VAPID_PUBLIC_KEY is not set — push disabled.");
  }
  return key;
}

function urlBase64ToUint8Array(base64String: string): Uint8Array<ArrayBuffer> {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const raw = atob(base64);
  const output = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) {
    output[i] = raw.charCodeAt(i);
  }
  return output as Uint8Array<ArrayBuffer>;
}

/* ─── Subscribe to push ──────────────────────────────────── */

export async function subscribeToPush(
  registration: ServiceWorkerRegistration,
): Promise<PushSubscription | null> {
  const vapidKey = getVapidPublicKey();
  if (!vapidKey) return null;

  try {
    const existing = await registration.pushManager.getSubscription();
    if (existing) return existing;

    const subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(vapidKey),
    });

    return subscription;
  } catch (error) {
    console.error("[push] Subscription failed:", error);
    return null;
  }
}

/* ─── Check push support ─────────────────────────────────── */

export function isPushSupported(): boolean {
  return (
    typeof window !== "undefined" &&
    "serviceWorker" in navigator &&
    "PushManager" in window &&
    "Notification" in window
  );
}

export function getPushPermissionState(): NotificationPermission | "unsupported" {
  if (!isPushSupported()) return "unsupported";
  return Notification.permission;
}

/* ─── Request permission ─────────────────────────────────── */

export async function requestPushPermission(): Promise<NotificationPermission> {
  if (!isPushSupported()) return "denied";
  return Notification.requestPermission();
}

/* ─── Send subscription to server ─────────────────────────── */

export async function sendSubscriptionToServer(
  subscription: PushSubscription,
  metadata?: { surface?: string; path?: string },
): Promise<boolean> {
  try {
    const response = await fetch("/api/pwa/push", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Gikundiro-CSRF": "1",
      },
      body: JSON.stringify({
        action: "subscribe",
        subscription: subscription.toJSON(),
        surface: metadata?.surface,
        path: metadata?.path,
      }),
    });
    return response.ok;
  } catch {
    console.error("[push] Failed to send subscription to server");
    return false;
  }
}

/* ─── Unsubscribe ─────────────────────────────────────────── */

export async function unsubscribeFromPush(
  registration: ServiceWorkerRegistration,
): Promise<boolean> {
  try {
    const subscription = await registration.pushManager.getSubscription();
    if (!subscription) return true;

    const success = await subscription.unsubscribe();
    if (success) {
      await fetch("/api/pwa/push", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Gikundiro-CSRF": "1",
        },
        body: JSON.stringify({
          action: "unsubscribe",
          endpoint: subscription.endpoint,
        }),
      });
    }
    return success;
  } catch {
    return false;
  }
}

export async function sendTestPush(
  subscription: PushSubscription,
  payload?: {
    title?: string;
    body?: string;
    url?: string;
  },
): Promise<boolean> {
  try {
    const response = await fetch("/api/pwa/push", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-Gikundiro-CSRF": "1",
      },
      body: JSON.stringify({
        action: "test",
        subscription: subscription.toJSON(),
        ...payload,
      }),
    });

    return response.ok;
  } catch {
    return false;
  }
}

/* ─── Badging API ────────────────────────────────────────── */

export async function setBadgeCount(count: number): Promise<void> {
  if ("setAppBadge" in navigator) {
    try {
      if (count > 0) {
        await (navigator as Navigator & { setAppBadge: (n: number) => Promise<void> }).setAppBadge(count);
      } else {
        await (navigator as Navigator & { clearAppBadge: () => Promise<void> }).clearAppBadge();
      }
    } catch {
      // Silently fail — Badging API is best-effort
    }
  }
}

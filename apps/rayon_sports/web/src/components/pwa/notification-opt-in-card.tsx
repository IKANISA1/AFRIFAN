"use client";

import { useEffect, useMemo, useState } from "react";
import {
  getPushPermissionState,
  isPushSupported,
  requestPushPermission,
  sendSubscriptionToServer,
  sendTestPush,
  subscribeToPush,
  unsubscribeFromPush,
} from "@/lib/push";
import { trackPwaEvent } from "@/lib/pwa-analytics";

interface NotificationOptInCardProps {
  surface: "portal" | "live" | "site";
  path: string;
  title: string;
  description: string;
}

export function NotificationOptInCard({
  surface,
  path,
  title,
  description,
}: NotificationOptInCardProps) {
  const [supported, setSupported] = useState(false);
  const [permission, setPermission] = useState<NotificationPermission | "unsupported">(
    "unsupported",
  );
  const [subscribed, setSubscribed] = useState(false);
  const [working, setWorking] = useState(false);
  const [message, setMessage] = useState<string | null>(null);

  useEffect(() => {
    if (typeof window === "undefined") {
      return;
    }

    const nextSupported = isPushSupported();
    setSupported(nextSupported);
    setPermission(getPushPermissionState());

    if (!nextSupported || !("serviceWorker" in navigator)) {
      return;
    }

    navigator.serviceWorker.ready
      .then((registration) => registration.pushManager.getSubscription())
      .then((subscription) => {
        setSubscribed(subscription != null);
      })
      .catch(() => {});
  }, []);

  const helperCopy = useMemo(() => {
    if (!supported) {
      return "This browser cannot receive PWA push alerts yet.";
    }
    if (permission === "denied") {
      return "Notifications are blocked in this browser. Re-enable them in site settings to receive match alerts.";
    }
    if (subscribed) {
      return "Alerts are active for this device. You can send a test notification or disable them at any time.";
    }
    return description;
  }, [description, permission, subscribed, supported]);

  async function enableAlerts() {
    if (!supported || !("serviceWorker" in navigator)) {
      return;
    }

    setWorking(true);
    setMessage(null);

    try {
      const permissionResult = await requestPushPermission();
      setPermission(permissionResult);
      trackPwaEvent({
        eventType: "push-permission-requested",
        surface,
        path,
        payload: { permission: permissionResult },
      });

      if (permissionResult !== "granted") {
        setMessage("Notifications stay off until permission is granted.");
        return;
      }

      const registration = await navigator.serviceWorker.ready;
      const subscription = await subscribeToPush(registration);
      if (subscription == null) {
        setMessage("Could not create the browser subscription.");
        return;
      }

      const saved = await sendSubscriptionToServer(subscription, {
        surface,
        path,
      });
      if (!saved) {
        setMessage("Subscription created, but server storage failed.");
        return;
      }

      setSubscribed(true);
      setMessage("Match alerts are enabled on this device.");
      trackPwaEvent({
        eventType: "push-subscribed",
        surface,
        path,
      });
    } finally {
      setWorking(false);
    }
  }

  async function disableAlerts() {
    if (!("serviceWorker" in navigator)) {
      return;
    }

    setWorking(true);
    setMessage(null);
    try {
      const registration = await navigator.serviceWorker.ready;
      const removed = await unsubscribeFromPush(registration);
      if (!removed) {
        setMessage("Could not disable notifications for this browser.");
        return;
      }

      setSubscribed(false);
      setMessage("Notifications disabled for this device.");
      trackPwaEvent({
        eventType: "push-unsubscribed",
        surface,
        path,
      });
    } finally {
      setWorking(false);
    }
  }

  async function sendPreview() {
    if (!("serviceWorker" in navigator)) {
      return;
    }

    setWorking(true);
    setMessage(null);
    try {
      const registration = await navigator.serviceWorker.ready;
      const subscription = await registration.pushManager.getSubscription();
      if (subscription == null) {
        setMessage("Enable alerts before sending a preview.");
        return;
      }

      const success = await sendTestPush(subscription, {
        title: "Official club alerts",
        body: "Your browser is ready for live match, ticket, and supporter updates.",
        url: path,
      });

      setMessage(
        success
          ? "Preview notification sent."
          : "Preview delivery was not available from this environment.",
      );
      trackPwaEvent({
        eventType: "push-preview-sent",
        surface,
        path,
        payload: { success },
      });
    } finally {
      setWorking(false);
    }
  }

  return (
    <section className="glass-panel rounded-[32px] p-6">
      <p className="font-mono text-xs uppercase tracking-[0.24em] text-club-accent">
        Match alerts
      </p>
      <h2 className="mt-3 font-display text-4xl font-bold uppercase leading-none text-white">
        {title}
      </h2>
      <p className="mt-4 text-sm leading-7 text-slate-300">{helperCopy}</p>
      {message ? (
        <p className="mt-4 rounded-[20px] border border-border-soft bg-white/5 px-4 py-3 text-sm text-slate-200">
          {message}
        </p>
      ) : null}
      <div className="mt-5 flex flex-wrap gap-3">
        {!subscribed ? (
          <button
            type="button"
            disabled={working || permission === "denied" || !supported}
            onClick={() => {
              enableAlerts().catch(() => {});
            }}
            className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light disabled:cursor-not-allowed disabled:opacity-60"
          >
            {working ? "Connecting alerts..." : "Enable alerts"}
          </button>
        ) : (
          <>
            <button
              type="button"
              disabled={working}
              onClick={() => {
                sendPreview().catch(() => {});
              }}
              className="rounded-full bg-club-primary px-5 py-3 text-sm font-semibold text-white transition hover:bg-club-primary-light disabled:cursor-not-allowed disabled:opacity-60"
            >
              {working ? "Sending preview..." : "Send preview"}
            </button>
            <button
              type="button"
              disabled={working}
              onClick={() => {
                disableAlerts().catch(() => {});
              }}
              className="rounded-full border border-border-soft px-5 py-3 text-sm font-semibold text-white transition hover:bg-white/8 disabled:cursor-not-allowed disabled:opacity-60"
            >
              Disable alerts
            </button>
          </>
        )}
      </div>
    </section>
  );
}

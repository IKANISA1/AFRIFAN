import { getAccessToken } from "./fcm.ts";
import { fetchBoundedJson } from "./http.ts";
import { HttpError } from "./auth.ts";
import { type NotificationDeviceSender } from "./notification_dispatch.ts";

/** Single-device adapter: recipients/cleanup/retry authority belongs to SQL29. */
export async function prepareNotificationDeviceSender(
  deadlineAt: number,
): Promise<NotificationDeviceSender> {
  if (Date.now() >= deadlineAt) {
    throw new HttpError(408, "Notification worker deadline expired.");
  }
  const account = JSON.parse(
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON") ?? "{}",
  );
  const project = Deno.env.get("FIREBASE_PROJECT_ID") ?? account.project_id;
  if (
    typeof project !== "string" ||
    project.length < 1 || project.length > 128 || /[\s/]/.test(project)
  ) {
    throw new HttpError(
      503,
      "Notification provider configuration is unavailable.",
    );
  }
  const accessToken = await getAccessToken();
  if (Date.now() >= deadlineAt) {
    throw new HttpError(408, "Notification worker deadline expired.");
  }
  return async (device, deviceDeadline) => {
    const end = Math.min(deadlineAt, deviceDeadline);
    if (Date.now() >= end) return { outcome: "unknown", error_code: "UNKNOWN" };
    const response = await fetchBoundedJson<{
      name?: string;
      error?: { status?: string; details?: Array<{ errorCode?: string }> };
    }>(
      fetch,
      `https://fcm.googleapis.com/v1/projects/${
        encodeURIComponent(project)
      }/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: device.token,
            notification: {
              title: device.title,
              body: device.body,
              ...(device.image_url ? { image: device.image_url } : {}),
            },
            android: {
              priority: "high",
              notification: {
                channel_id: "cool_default",
                default_sound: true,
                default_vibrate_timings: true,
              },
            },
            data: {
              notification_id: device.notification_id,
              club_id: String(device.club_id),
              audience_type: device.audience_type,
              ...(device.audience_tier
                ? { audience_tier: device.audience_tier }
                : {}),
              ...(device.audience_group_id
                ? { audience_group_id: device.audience_group_id }
                : {}),
            },
          },
        }),
      },
      {
        maxBytes: 16384,
        timeoutMs: Math.min(5000, Math.max(1, end - Date.now())),
        acceptErrorResponse: true,
      },
    );
    if (
      typeof response.name === "string" &&
      response.name.startsWith(`projects/${project}/messages/`) &&
      response.name.length <= 512 && !response.error
    ) {
      return { outcome: "accepted", provider_message_name: response.name };
    }
    const code = response.error?.details?.[0]?.errorCode ??
      response.error?.status;
    if (code === "UNREGISTERED" || code === "NOT_FOUND") {
      return { outcome: "rejected", error_code: code };
    }
    return { outcome: "unknown", error_code: "UNKNOWN" };
  };
}

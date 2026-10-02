import { errorResponse, jsonOk } from "../_shared/response.ts";
import { HttpError } from "../_shared/auth.ts";
import { createAdminClient } from "../_shared/supabase.ts";
import { enforceRateLimit } from "../_shared/rate_limit.ts";
import { withEdgeBoundary } from "../_shared/response.ts";
import { readBoundedJson } from "../_shared/http.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { sendToTopic, sendToUser } from "../_shared/fcm.ts";
import type { FcmData, FcmNotification, SendResult } from "../_shared/fcm.ts";
import { getSupabaseSecretKeys } from "../_shared/supabase.ts";

type Dependencies = {
  createAdminClient: typeof createAdminClient;
  enforceRateLimit: typeof enforceRateLimit;
  getSecretKeys: () => string[];
  sendToUser: (
    userId: string,
    notification: FcmNotification,
    data?: FcmData,
  ) => Promise<SendResult>;
  sendToTopic: (
    topic: string,
    notification: FcmNotification,
    data?: FcmData,
  ) => Promise<SendResult>;
};

const defaultDependencies: Dependencies = {
  createAdminClient,
  enforceRateLimit,
  getSecretKeys: getSupabaseSecretKeys,
  sendToUser,
  sendToTopic,
};

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const topicPattern = /^[A-Za-z0-9-_.~%]{1,200}$/;

function response(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function requiredText(value: unknown, field: string, maximum: number) {
  if (typeof value !== "string") {
    throw new HttpError(400, `${field} is required.`);
  }
  const text = value.trim();
  if (!text || text.length > maximum) {
    throw new HttpError(400, `${field} is invalid.`);
  }
  return text;
}

function optionalData(value: unknown): FcmData | undefined {
  if (value == null) return undefined;
  if (typeof value !== "object" || Array.isArray(value)) {
    throw new HttpError(400, "data is invalid.");
  }
  const entries = Object.entries(value as Record<string, unknown>);
  if (entries.length > 50) throw new HttpError(400, "data is invalid.");
  const data: FcmData = {};
  for (const [key, item] of entries) {
    if (
      !key || key.length > 128 || typeof item !== "string" || item.length > 1024
    ) {
      throw new HttpError(400, "data is invalid.");
    }
    data[key] = item;
  }
  return data;
}

function authorized(request: Request, secretKeys: string[]) {
  const authorization = request.headers.get("authorization") ?? "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  return token.length > 0 &&
    secretKeys.some((candidate) => candidate === token);
}

export function createSendNotificationHandler(
  dependencies: Partial<Dependencies> = {},
) {
  const deps = { ...defaultDependencies, ...dependencies };
  return async (request: Request) => {
    if (request.method !== "POST") {
      return response({ error: "Method not allowed." }, 405);
    }

    let secretKeys: string[];
    try {
      secretKeys = deps.getSecretKeys();
    } catch {
      return response(
        { error: "Notification delivery is not configured." },
        503,
      );
    }
    if (!authorized(request, secretKeys)) {
      return response({ error: "Unauthorized." }, 401);
    }

    try {
      const body = await readBoundedJson(request) as Record<string, unknown>;
      const type = body.type == null
        ? "user"
        : requiredText(body.type, "type", 16);
      const title = requiredText(body.title, "title", 120);
      const bodyText = requiredText(body.body, "body", 1000);
      const data = optionalData(body.data);
      const image = body.image_url == null
        ? undefined
        : requiredText(body.image_url, "image_url", 2048);
      if (image != null) {
        const url = new URL(image);
        if (url.protocol !== "https:") {
          throw new HttpError(400, "image_url is invalid.");
        }
      }
      const notification: FcmNotification = {
        title,
        body: bodyText,
        ...(image == null ? {} : { image }),
      };

      let result: SendResult;
      if (type === "topic") {
        const topic = requiredText(body.topic, "topic", 200);
        if (!topicPattern.test(topic)) {
          throw new HttpError(400, "topic is invalid.");
        }
        await deps.enforceRateLimit(
          deps.createAdminClient(),
          "internal-notification",
          "send-notification",
          {
            maxRequests: 120,
            windowSeconds: 60,
          },
        );
        result = await deps.sendToTopic(topic, notification, data);
      } else if (type === "user") {
        const userId = requiredText(body.user_id, "user_id", 64);
        if (!uuidPattern.test(userId)) {
          throw new HttpError(400, "user_id is invalid.");
        }
        await deps.enforceRateLimit(
          deps.createAdminClient(),
          "internal-notification",
          "send-notification",
          {
            maxRequests: 120,
            windowSeconds: 60,
          },
        );
        result = await deps.sendToUser(userId, notification, data);
      } else {
        throw new HttpError(400, "type is invalid.");
      }

      return jsonOk({
        ...result,
        errors: result.errors.length ? ["Notification delivery failed."] : [],
      }, result.success ? 200 : 502);
    } catch (error) {
      return errorResponse(error);
    }
  };
}

if (import.meta.main) {
  Deno.serve(withEdgeBoundary(createSendNotificationHandler()));
}

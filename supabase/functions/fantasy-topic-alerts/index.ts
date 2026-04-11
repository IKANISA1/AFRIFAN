import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { sendToTopic } from "../_shared/fcm.ts";
import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
} from "../_shared/response.ts";

type TopicAlertRequest = {
  topic?: string;
  title?: string;
  body?: string;
  data?: Record<string, string>;
  image?: string;
};

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return corsPreflightResponse();
  }

  if (request.method !== "POST") {
    return jsonError("Method not allowed", 405);
  }

  try {
    const authHeader = request.headers.get("Authorization");
    const expectedBearer = `Bearer ${
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    }`;
    if (authHeader !== expectedBearer) {
      return jsonError("Unauthorized", 401);
    }

    const body = await request.json() as TopicAlertRequest;
    const topic = body.topic?.trim();
    const title = body.title?.trim();
    const message = body.body?.trim();
    const trimmedImage = body.image?.trim();

    if (!topic || !title || !message) {
      return jsonError("topic, title, and body are required", 400);
    }

    const result = await sendToTopic(
      topic,
      {
        title,
        body: message,
        ...(trimmedImage != null && trimmedImage.length > 0
          ? { image: trimmedImage }
          : {}),
      },
      body.data,
    );

    return new Response(JSON.stringify(result), {
      status: result.success ? 200 : 502,
      headers: {
        ...corsHeaders(),
        "Content-Type": "application/json",
      },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error
          ? error.message
          : "Fantasy topic alert failed.",
      }),
      {
        status: 500,
        headers: {
          ...corsHeaders(),
          "Content-Type": "application/json",
        },
      },
    );
  }
});

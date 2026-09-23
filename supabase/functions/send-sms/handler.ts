import { verifyStandardWebhook } from "../_shared/standard_webhook.ts";

type SendOtpTemplate = (options: {
  phone: string;
  code: string;
  language: string;
  signal?: AbortSignal;
}) => Promise<void>;

type SendSmsDependencies = {
  sendOtpTemplate: SendOtpTemplate;
  getHookSecret: () => string | undefined;
  nowSeconds?: () => number;
  deliveryTimeoutMs?: number;
};

type SendSmsHookPayload = {
  user?: {
    phone?: unknown;
  };
  sms?: {
    otp?: unknown;
  };
};

const defaultDeliveryTimeoutMs = 4_000;
const phonePattern = /^\+[1-9]\d{7,14}$/;
const otpPattern = /^\d{4,10}$/;

class OtpDeliveryTimeoutError extends Error {
  constructor() {
    super("OTP delivery timed out.");
    this.name = "OtpDeliveryTimeoutError";
  }
}

function hookJson(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}

function hookError(
  message: string,
  status: number,
  code: string,
  options: {
    retryable?: boolean;
    changeConfirmed?: boolean;
  } = {},
) {
  return hookJson(
    {
      code,
      error: {
        http_code: status,
        message,
      },
      ...(options.retryable == null
        ? {}
        : { retryable: options.retryable }),
      ...(options.changeConfirmed == null
        ? {}
        : { change_confirmed: options.changeConfirmed }),
    },
    status,
  );
}

async function deliverWithTimeout({
  sendOtpTemplate,
  phone,
  otp,
  timeoutMs,
}: {
  sendOtpTemplate: SendOtpTemplate;
  phone: string;
  otp: string;
  timeoutMs: number;
}) {
  const controller = new AbortController();
  let timeoutId: ReturnType<typeof setTimeout> | undefined;

  try {
    await Promise.race([
      sendOtpTemplate({
        phone,
        code: otp,
        language: "en_US",
        signal: controller.signal,
      }),
      new Promise<never>((_resolve, reject) => {
        timeoutId = setTimeout(() => {
          controller.abort();
          reject(new OtpDeliveryTimeoutError());
        }, timeoutMs);
      }),
    ]);
  } finally {
    if (timeoutId != null) clearTimeout(timeoutId);
  }
}

export function createSendSmsHandler(dependencies: SendSmsDependencies) {
  const deliveryTimeoutMs =
    dependencies.deliveryTimeoutMs ?? defaultDeliveryTimeoutMs;
  const nowSeconds =
    dependencies.nowSeconds ?? (() => Math.floor(Date.now() / 1000));

  return async function handleSendSms(request: Request) {
    if (request.method !== "POST") {
      return hookError("Method not allowed.", 405, "METHOD_NOT_ALLOWED");
    }

    const rawPayload = await request.text();
    const hookSecret = dependencies.getHookSecret()?.trim();
    if (!hookSecret) {
      return hookError(
        "OTP delivery is not configured.",
        503,
        "SEND_SMS_HOOK_NOT_CONFIGURED",
        { retryable: false, changeConfirmed: false },
      );
    }

    const verified = await verifyStandardWebhook({
      payload: rawPayload,
      headers: request.headers,
      secret: hookSecret,
      nowSeconds: nowSeconds(),
    });
    if (!verified) {
      return hookError(
        "Webhook authentication failed.",
        401,
        "INVALID_WEBHOOK_SIGNATURE",
        { retryable: false, changeConfirmed: false },
      );
    }

    let payload: SendSmsHookPayload;
    try {
      payload = JSON.parse(rawPayload) as SendSmsHookPayload;
    } catch {
      return hookError(
        "Invalid Send SMS Hook payload.",
        400,
        "INVALID_SEND_SMS_PAYLOAD",
        { retryable: false, changeConfirmed: false },
      );
    }

    const phone =
      typeof payload.user?.phone === "string"
        ? payload.user.phone.trim()
        : "";
    const otp =
      typeof payload.sms?.otp === "string" ? payload.sms.otp.trim() : "";
    if (!phonePattern.test(phone) || !otpPattern.test(otp)) {
      return hookError(
        "Invalid Send SMS Hook payload.",
        400,
        "INVALID_SEND_SMS_PAYLOAD",
        { retryable: false, changeConfirmed: false },
      );
    }

    try {
      await deliverWithTimeout({
        sendOtpTemplate: dependencies.sendOtpTemplate,
        phone,
        otp,
        timeoutMs: deliveryTimeoutMs,
      });
      return new Response(null, {
        status: 200,
        headers: {
          "Cache-Control": "no-store",
        },
      });
    } catch (error) {
      if (error instanceof OtpDeliveryTimeoutError) {
        return hookError(
          "OTP delivery timed out.",
          504,
          "OTP_DELIVERY_TIMEOUT",
          { retryable: true, changeConfirmed: false },
        );
      }
      return hookError(
        "OTP delivery failed.",
        502,
        "OTP_DELIVERY_FAILED",
        { retryable: true, changeConfirmed: false },
      );
    }
  };
}

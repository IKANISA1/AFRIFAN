import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsHeaders,
  errorResponse,
  handleCors,
  jsonResponse,
} from "../_shared/http.ts";
import { buildBiopayPaymentCode } from "../_shared/biopay_payment.ts";
import {
  type SignedBiopayTokenPayload,
  verifyBiopayToken,
} from "../_shared/biopay_signed_token.ts";

type ResolvePayload = SignedBiopayTokenPayload & {
  channel?: unknown;
  amount?: unknown;
  reference?: unknown;
  public_id?: unknown;
  display_name?: unknown;
  route_type?: unknown;
  recipient_value?: unknown;
  country_code?: unknown;
  currency_code?: unknown;
  currency_symbol?: unknown;
  payment_method?: unknown;
  payment_template?: unknown;
  sender_name?: unknown;
};

export type BiopayResolveHandoffDependencies = {
  verifyBiopayToken: (
    token: string,
    options: { expectedKind: string },
  ) => Promise<SignedBiopayTokenPayload>;
  buildPaymentCode: (options: {
    paymentTemplate: string;
    routeType: string;
    recipientValue: string;
    amount?: number | null;
  }) => string;
};

function buildDialUri(paymentCode: string) {
  return `tel:${paymentCode.replaceAll("#", "%23")}`;
}

function redirectResponse(location: string) {
  return new Response(null, {
    status: 302,
    headers: {
      ...corsHeaders,
      "Cache-Control": "no-store",
      Location: location,
    },
  });
}

const defaultDependencies: BiopayResolveHandoffDependencies = {
  verifyBiopayToken,
  buildPaymentCode: buildBiopayPaymentCode,
};

export function createBiopayResolveHandoffHandler(
  dependencies: Partial<BiopayResolveHandoffDependencies> = {},
) {
  const deps: BiopayResolveHandoffDependencies = {
    ...defaultDependencies,
    ...dependencies,
  };

  return async (request: Request) => {
    const corsResponse = handleCors(request);
    if (corsResponse) {
      return corsResponse;
    }

    try {
      let token: string | null = null;
      if (request.method === "GET") {
        token = request.url
          ? new URL(request.url).searchParams.get("token")
          : null;
      } else if (request.method === "POST") {
        const body = await request.json() as { token?: string };
        token = body.token ?? null;
      } else {
        return errorResponse("Method not allowed", 405, {
          allowed: "GET, POST",
        });
      }

      if (token == null || token.trim().length == 0) {
        return errorResponse("token is required.", 400);
      }

      const payload = await deps.verifyBiopayToken(token, {
        expectedKind: "handoff_request",
      }) as ResolvePayload;
      const amount = typeof payload.amount === "number" && payload.amount > 0
        ? Math.trunc(payload.amount)
        : null;
      const paymentMethod = payload.payment_method?.toString() ?? "ussd_dial";
      const paymentTemplate = payload.payment_template?.toString() ?? "";
      const paymentCode = deps.buildPaymentCode({
        paymentTemplate,
        routeType: payload.route_type?.toString() ?? "",
        recipientValue: payload.recipient_value?.toString() ?? "",
        amount,
      });

      if (request.method === "GET") {
        return redirectResponse(buildDialUri(paymentCode));
      }

      return jsonResponse({
        success: true,
        data: {
          channel: payload.channel?.toString() ?? "qr",
          amount,
          reference: payload.reference?.toString() ?? null,
          display_name: payload.display_name?.toString() ?? "",
          public_id: payload.public_id?.toString() ?? "",
          route_type: payload.route_type?.toString() ?? "phone_number",
          recipient_value: payload.recipient_value?.toString() ?? "",
          country_code: payload.country_code?.toString() ?? "RW",
          currency_code: payload.currency_code?.toString() ?? "USD",
          currency_symbol: payload.currency_symbol?.toString() ?? "USD",
          payment_code: paymentCode,
          payment_method: paymentMethod,
          sender_name: payload.sender_name?.toString() ?? null,
          expires_at: payload.exp,
        },
      });
    } catch (error) {
      return errorResponse(
        error instanceof Error
          ? error.message
          : "BioPay handoff resolution failed.",
        400,
      );
    }
  };
}

if (import.meta.main) {
  Deno.serve(createBiopayResolveHandoffHandler());
}

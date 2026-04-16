import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { buildBioPayPaymentCode } from "../_shared/BioPay_payment.ts";
import {
  type SignedBioPayTokenPayload,
  verifyBioPayToken,
} from "../_shared/BioPay_signed_token.ts";

type ResolvePayload = SignedBioPayTokenPayload & {
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

export type BioPayResolveHandoffDependencies = {
  verifyBioPayToken: (
    token: string,
    options: { expectedKind: string },
  ) => Promise<SignedBioPayTokenPayload>;
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
      ...corsHeaders(),
      "Cache-Control": "no-store",
      Location: location,
    },
  });
}

const defaultDependencies: BioPayResolveHandoffDependencies = {
  verifyBioPayToken,
  buildPaymentCode: buildBioPayPaymentCode,
};

export function createBioPayResolveHandoffHandler(
  dependencies: Partial<BioPayResolveHandoffDependencies> = {},
) {
  const deps: BioPayResolveHandoffDependencies = {
    ...defaultDependencies,
    ...dependencies,
  };

  return async (request: Request) => {
    if (request.method === "OPTIONS") {
      return corsPreflightResponse();
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
        return jsonError("Method not allowed", 405, undefined, {
          allowed: "GET, POST",
        });
      }

      if (token == null || token.trim().length == 0) {
        return jsonError("token is required.", 400);
      }

      const payload = await deps.verifyBioPayToken(token, {
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

      return jsonOk({
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
      return jsonError(
        error instanceof Error
          ? error.message
          : "BioPay handoff resolution failed.",
        400,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createBioPayResolveHandoffHandler();
  Deno.serve((req: Request) => handler(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}

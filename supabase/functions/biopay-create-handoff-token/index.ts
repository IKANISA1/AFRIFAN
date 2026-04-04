import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsPreflightResponse,
  corsHeaders,
  jsonOk,
  jsonError,
} from "../_shared/response.ts";
import { validateRequest, isErrorResponse } from "../_shared/validation.ts";
import { HttpError } from "../_shared/auth.ts";
import { requireAppCheckToken } from "../_shared/app_check.ts";
import {
  resolveBiopayPaymentRouting,
  type BiopayPaymentRouting,
} from "../_shared/biopay_payment.ts";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import {
  generateBiopayNonce,
  signBiopayToken,
  type SignedBiopayTokenPayload,
} from "../_shared/biopay_signed_token.ts";
import {
  createAdminClient,
  getSupabaseUrl,
} from "../_shared/supabase.ts";

type CreateHandoffTokenRequest = {
  channel?: string;
  amount?: number;
  reference?: string;
};

type HandoffProfileRow = {
  id: string;
  club_id: number | null;
  public_id: string;
  display_name: string | null;
  route_type: string;
  recipient_value: string;
  country_code: string | null;
};

type AdminClientLike = ReturnType<typeof createAdminClient> | any;

export type BiopayCreateHandoffTokenDependencies = {
  createAdminClient: () => AdminClientLike;
  validateRequest: typeof validateRequest;
  requireAppCheckToken: (request: Request) => Promise<string>;
  signBiopayToken: (
    payload: SignedBiopayTokenPayload,
  ) => Promise<string>;
  resolvePaymentRouting: (
    adminClient: AdminClientLike,
    options: {
      clubId?: number | null;
      countryCode?: string | null;
      routeType?: string | null;
    },
  ) => Promise<BiopayPaymentRouting>;
  recordOperationalHealthEvent: (
    adminClient: AdminClientLike,
    event: Parameters<typeof recordOperationalHealthEvent>[1],
  ) => Promise<void>;
  recordEdgeFunctionFailure: (
    adminClient: AdminClientLike,
    options: Parameters<typeof recordEdgeFunctionFailure>[1],
  ) => Promise<void>;
  buildResolverUrl: (token: string) => string;
  now: () => Date;
};

const HANDOFF_TTL_SECONDS = 60;

function buildResolverUrl(token: string) {
  const resolver = new URL(
    "/functions/v1/biopay-resolve-handoff",
    getSupabaseUrl(),
  );
  resolver.searchParams.set("token", token);
  return resolver.toString();
}

const defaultDependencies: BiopayCreateHandoffTokenDependencies = {
  createAdminClient,
  validateRequest,
  requireAppCheckToken,
  signBiopayToken,
  resolvePaymentRouting: resolveBiopayPaymentRouting,
  recordOperationalHealthEvent,
  recordEdgeFunctionFailure,
  buildResolverUrl,
  now: () => new Date(),
};

export function createBiopayCreateHandoffTokenHandler(
  dependencies: Partial<BiopayCreateHandoffTokenDependencies> = {},
) {
  const deps: BiopayCreateHandoffTokenDependencies = {
    ...defaultDependencies,
    ...dependencies,
  };

  return async (request: Request) => {
    if (request.method === "OPTIONS") {
      return corsPreflightResponse();
    }

    if (request.method !== "POST") {
      return jsonError("Method not allowed", 405);
    }

    const adminClient = deps.createAdminClient();
    let requesterUserId: string | null = null;

    try {
      const validated = await deps.validateRequest(request, { requireClubId: true });
      if (isErrorResponse(validated)) return validated;
      
      const { userId, clubId } = validated;
      requesterUserId = userId;

      await deps.requireAppCheckToken(request);

      const body = await request.json() as CreateHandoffTokenRequest;
      const channel = (body.channel ?? "qr").trim().toLowerCase();
      if (channel !== "qr" && channel !== "nfc") {
        return jsonError("channel must be qr or nfc.", 400);
      }

      const amount = typeof body.amount === "number" && body.amount > 0
        ? Math.trunc(body.amount)
        : null;
      const reference = body.reference?.trim().slice(0, 72);
      const numericClubId = Number(clubId);

      const { data: profile, error: profileError } = await adminClient
        .from("biopay_profiles")
        .select(
          "id, club_id, public_id, display_name, route_type, recipient_value, country_code",
        )
        .eq("user_id", userId)
        .eq("club_id", numericClubId)
        .eq("active", true)
        .maybeSingle();

      if (profileError || !profile) {
        return jsonError(
          "Active BioPay enrollment required before sharing a payment request.",
          409,
        );
      }

      const now = deps.now();
      const expiresAt = new Date(
        now.getTime() + HANDOFF_TTL_SECONDS * 1000,
      ).toISOString();
      const paymentRouting = await deps.resolvePaymentRouting(adminClient, {
        clubId: profile.club_id,
        countryCode: profile.country_code,
        routeType: profile.route_type,
      });
      const token = await deps.signBiopayToken({
        kind: "handoff_request",
        v: 1,
        iat: now.toISOString(),
        exp: expiresAt,
        nonce: generateBiopayNonce(),
        channel,
        amount,
        reference: reference ?? null,
        profile_id: profile.id,
        public_id: profile.public_id,
        display_name: profile.display_name,
        club_id: profile.club_id,
        route_type: profile.route_type,
        recipient_value: profile.recipient_value,
        country_code: paymentRouting.countryCode,
        currency_code: paymentRouting.currencyCode,
        currency_symbol: paymentRouting.currencySymbol,
        payment_method: paymentRouting.paymentMethod,
        payment_template: paymentRouting.paymentTemplate,
        sender_name: paymentRouting.senderName,
      });

      const resolverUrl = deps.buildResolverUrl(token);

      await deps.recordOperationalHealthEvent(adminClient, {
        service: "biopay",
        component: "handoff_token",
        status: "ok",
        severity: "info",
        message: "BioPay handoff token created.",
        functionName: "biopay-create-handoff-token",
        userId: userId,
        subjectType: "biopay_profile",
        subjectId: profile.id?.toString() ?? null,
        metadata: {
          channel,
          amount,
          expires_at: expiresAt,
        },
      });

      return jsonOk({
        success: true,
        data: {
          token,
          resolver_url: resolverUrl,
          expires_at: expiresAt,
          channel,
          amount,
          reference,
          display_name: profile.display_name,
          public_id: profile.public_id,
          country_code: paymentRouting.countryCode,
          currency_code: paymentRouting.currencyCode,
          currency_symbol: paymentRouting.currencySymbol,
          payment_method: paymentRouting.paymentMethod,
          sender_name: paymentRouting.senderName,
        },
      });
    } catch (error) {
      if (error instanceof SyntaxError) {
        return jsonError("Invalid JSON body.", 400);
      }
      if (error instanceof HttpError) {
        return jsonError(error.message, error.status);
      }

      await deps.recordEdgeFunctionFailure(adminClient, {
        functionName: "biopay-create-handoff-token",
        error,
        issueCode: "biopay_create_handoff_token_failed",
        userId: requesterUserId,
      });
      console.error("biopay-create-handoff-token failed:", error);
      return jsonError(
        error instanceof Error
          ? error.message
          : "BioPay handoff token creation failed.",
        400,
      );
    }
  };
}

if (import.meta.main) {
  const handler = createBiopayCreateHandoffTokenHandler();
  Deno.serve((req: Request) => handler(req).then(
    (res) => new Response(res.body, { ...res, headers: { ...Object.fromEntries(res.headers.entries()), ...corsHeaders() } })
  ));
}

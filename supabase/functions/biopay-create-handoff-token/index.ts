import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  errorResponse,
  handleCors,
  jsonResponse,
  methodNotAllowed,
} from "../_shared/http.ts";
import { HttpError } from "../_shared/auth.ts";
import { requireAppCheckToken } from "../_shared/app_check.ts";
import {
  resolveBiopayPaymentRouting,
  type BiopayPaymentRouting,
} from "../_shared/biopay_payment.ts";
import { resolveClubIdFromMetadata } from "../_shared/club.ts";
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
  createUserClient,
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
type UserClientLike = {
  auth: {
    getUser(): Promise<{
      data: {
        user: { id: string; app_metadata?: Record<string, unknown> } | null;
      };
      error: unknown;
    }>;
  };
};

export type BiopayCreateHandoffTokenDependencies = {
  createAdminClient: () => AdminClientLike;
  createUserClient: (authorization: string) => UserClientLike;
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
  createUserClient: (authorization) =>
    createUserClient(authorization) as unknown as UserClientLike,
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
    const corsResponse = handleCors(request);
    if (corsResponse) {
      return corsResponse;
    }

    if (request.method !== "POST") {
      return methodNotAllowed("POST");
    }

    const adminClient = deps.createAdminClient();
    let requesterUserId: string | null = null;

    try {
      const authorization = request.headers.get("authorization") ??
        request.headers.get("Authorization");
      if (!authorization) {
        return errorResponse("Missing authorization header.", 401);
      }

      const userClient = deps.createUserClient(authorization);
      const { data: authData, error: authError } = await userClient.auth
        .getUser();
      if (authError || !authData.user) {
        return errorResponse("Unauthorized.", 401);
      }
      requesterUserId = authData.user.id;

      await deps.requireAppCheckToken(request);
      const clubId = await resolveClubIdFromMetadata(
        adminClient,
        authData.user.app_metadata,
      );

      const body = await request.json() as CreateHandoffTokenRequest;
      const channel = (body.channel ?? "qr").trim().toLowerCase();
      if (channel !== "qr" && channel !== "nfc") {
        return errorResponse("channel must be qr or nfc.", 400);
      }

      const amount = typeof body.amount === "number" && body.amount > 0
        ? Math.trunc(body.amount)
        : null;
      const reference = body.reference?.trim().slice(0, 72);

      const { data: profile, error: profileError } = await adminClient
        .from("biopay_profiles")
        .select(
          "id, club_id, public_id, display_name, route_type, recipient_value, country_code",
        )
        .eq("user_id", authData.user.id)
        .eq("club_id", clubId)
        .eq("active", true)
        .maybeSingle();

      if (profileError || !profile) {
        return errorResponse(
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
        userId: authData.user.id,
        subjectType: "biopay_profile",
        subjectId: profile.id?.toString() ?? null,
        metadata: {
          channel,
          amount,
          expires_at: expiresAt,
        },
      });

      return jsonResponse({
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
        return errorResponse("Invalid JSON body.", 400);
      }
      if (error instanceof HttpError) {
        return errorResponse(error.message, error.status);
      }

      await deps.recordEdgeFunctionFailure(adminClient, {
        functionName: "biopay-create-handoff-token",
        error,
        issueCode: "biopay_create_handoff_token_failed",
        userId: requesterUserId,
      });
      return errorResponse(
        error instanceof Error
          ? error.message
          : "BioPay handoff token creation failed.",
        400,
      );
    }
  };
}

if (import.meta.main) {
  Deno.serve(createBiopayCreateHandoffTokenHandler());
}

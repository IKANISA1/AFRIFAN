import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import {
  corsHeaders,
  corsPreflightResponse,
  jsonError,
  jsonOk,
} from "../_shared/response.ts";
import { isErrorResponse, validateRequest } from "../_shared/validation.ts";
import { HttpError } from "../_shared/auth.ts";
import { requireAppCheckToken } from "../_shared/app_check.ts";
import {
  type BioPayPaymentRouting,
  resolveBioPayPaymentRouting,
} from "../_shared/BioPay_payment.ts";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import {
  generateBioPayNonce,
  signBioPayToken,
  type SignedBioPayTokenPayload,
} from "../_shared/BioPay_signed_token.ts";
import { createAdminClient, getSupabaseUrl } from "../_shared/supabase.ts";

type CreateHandoffTokenRequest = {
  channel?: string;
  amount?: number;
  reference?: string;
  route_type?: string;
  recipient_value?: string;
  country_code?: string;
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

type HandoffIdentityRow = {
  id: string;
  club_id: number | null;
  public_user_id: string | null;
  display_name: string | null;
  country_code: string | null;
};

type AdminClientLike = ReturnType<typeof createAdminClient> | any;

export type BioPayCreateHandoffTokenDependencies = {
  createAdminClient: () => AdminClientLike;
  validateRequest: typeof validateRequest;
  requireAppCheckToken: (request: Request) => Promise<string>;
  signBioPayToken: (
    payload: SignedBioPayTokenPayload,
  ) => Promise<string>;
  resolvePaymentRouting: (
    adminClient: AdminClientLike,
    options: {
      clubId?: number | null;
      countryCode?: string | null;
      routeType?: string | null;
    },
  ) => Promise<BioPayPaymentRouting>;
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

function trimToNull(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function normalizeRouteType(value: unknown): string | null {
  const normalized = trimToNull(value)?.toLowerCase();
  if (normalized == null) {
    return null;
  }
  if (
    normalized == "phone_number" || normalized == "phone" ||
    normalized == "number"
  ) {
    return "phone_number";
  }
  if (normalized == "code") {
    return "code";
  }
  throw new HttpError(400, "route_type must be phone_number or code.");
}

function buildResolverUrl(token: string) {
  const resolver = new URL(
    "/functions/v1/BioPay-resolve-handoff",
    getSupabaseUrl(),
  );
  resolver.searchParams.set("token", token);
  return resolver.toString();
}

const defaultDependencies: BioPayCreateHandoffTokenDependencies = {
  createAdminClient,
  validateRequest,
  requireAppCheckToken,
  signBioPayToken,
  resolvePaymentRouting: resolveBioPayPaymentRouting,
  recordOperationalHealthEvent,
  recordEdgeFunctionFailure,
  buildResolverUrl,
  now: () => new Date(),
};

export function createBioPayCreateHandoffTokenHandler(
  dependencies: Partial<BioPayCreateHandoffTokenDependencies> = {},
) {
  const deps: BioPayCreateHandoffTokenDependencies = {
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
      const validated = await deps.validateRequest(request, {
        requireClubId: true,
      });
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
      const manualRouteType = normalizeRouteType(body.route_type);
      const manualRecipientValue = trimToNull(body.recipient_value);
      const requestedCountryCode =
        trimToNull(body.country_code)?.toUpperCase() ?? null;

      if ((manualRouteType == null) !== (manualRecipientValue == null)) {
        return jsonError(
          "route_type and recipient_value must be provided together.",
          400,
        );
      }

      const { data: profile, error: profileError } = await adminClient
        .from("BioPay_profiles")
        .select(
          "id, club_id, public_id, display_name, route_type, recipient_value, country_code",
        )
        .eq("user_id", userId)
        .eq("club_id", numericClubId)
        .eq("active", true)
        .maybeSingle();

      if (profileError) {
        throw profileError;
      }

      let identity: HandoffIdentityRow | null = null;
      if (!profile || manualRouteType != null) {
        const { data: identityRow, error: identityError } = await adminClient
          .from("profiles")
          .select("id, club_id, public_user_id, display_name, country_code")
          .eq("id", userId)
          .eq("club_id", numericClubId)
          .maybeSingle();

        if (identityError) {
          throw identityError;
        }
        identity = identityRow;
      }

      const effectiveRouteType = manualRouteType ?? profile?.route_type ?? null;
      const effectiveRecipientValue = manualRecipientValue ??
        trimToNull(profile?.recipient_value) ?? null;

      if (effectiveRouteType == null || effectiveRecipientValue == null) {
        return jsonError(
          "Enter a payment route or complete Face ID enrollment before sharing a payment request.",
          409,
        );
      }

      const effectiveClubId = profile?.club_id ?? identity?.club_id ??
        numericClubId;
      const effectivePublicId = trimToNull(profile?.public_id) ??
        trimToNull(identity?.public_user_id) ??
        "";
      const effectiveDisplayName = trimToNull(profile?.display_name) ??
        trimToNull(identity?.display_name) ??
        "";
      const effectiveCountryCode = requestedCountryCode ??
        trimToNull(profile?.country_code)?.toUpperCase() ??
        trimToNull(identity?.country_code)?.toUpperCase() ??
        null;

      const now = deps.now();
      const expiresAt = new Date(
        now.getTime() + HANDOFF_TTL_SECONDS * 1000,
      ).toISOString();
      const paymentRouting = await deps.resolvePaymentRouting(adminClient, {
        clubId: effectiveClubId,
        countryCode: effectiveCountryCode,
        routeType: effectiveRouteType,
      });
      const token = await deps.signBioPayToken({
        kind: "handoff_request",
        v: 1,
        iat: now.toISOString(),
        exp: expiresAt,
        nonce: generateBioPayNonce(),
        channel,
        amount,
        reference: reference ?? null,
        profile_id: profile?.id ?? null,
        public_id: effectivePublicId,
        display_name: effectiveDisplayName,
        club_id: effectiveClubId,
        route_type: effectiveRouteType,
        recipient_value: effectiveRecipientValue,
        country_code: paymentRouting.countryCode,
        currency_code: paymentRouting.currencyCode,
        currency_symbol: paymentRouting.currencySymbol,
        payment_method: paymentRouting.paymentMethod,
        payment_template: paymentRouting.paymentTemplate,
        sender_name: paymentRouting.senderName,
      });

      const resolverUrl = deps.buildResolverUrl(token);

      await deps.recordOperationalHealthEvent(adminClient, {
        service: "BioPay",
        component: "handoff_token",
        status: "ok",
        severity: "info",
        message: "BioPay handoff token created.",
        functionName: "BioPay-create-handoff-token",
        userId: userId,
        subjectType: profile != null ? "BioPay_profile" : "profile",
        subjectId: profile?.id?.toString() ?? identity?.id?.toString() ?? null,
        metadata: {
          channel,
          amount,
          expires_at: expiresAt,
          route_type: effectiveRouteType,
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
          display_name: effectiveDisplayName,
          public_id: effectivePublicId,
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
        functionName: "BioPay-create-handoff-token",
        error,
        issueCode: "BioPay_create_handoff_token_failed",
        userId: requesterUserId,
      });
      console.error("BioPay-create-handoff-token failed:", error);
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
  const handler = createBioPayCreateHandoffTokenHandler();
  Deno.serve((req: Request) =>
    handler(req).then(
      (res) =>
        new Response(res.body, {
          ...res,
          headers: {
            ...Object.fromEntries(res.headers.entries()),
            ...corsHeaders(),
          },
        }),
    )
  );
}

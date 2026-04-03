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
  buildBiopayPaymentCode,
  resolveBiopayPaymentRouting,
  type BiopayPaymentRouting,
} from "../_shared/biopay_payment.ts";
import {
  type SignedBiopayTokenPayload,
  verifyBiopayToken,
} from "../_shared/biopay_signed_token.ts";
import {
  recordEdgeFunctionFailure,
  recordOperationalHealthEvent,
} from "../_shared/observability.ts";
import { createAdminClient, createUserClient } from "../_shared/supabase.ts";

type CreateIntentRequest = {
  match_receipt?: string;
  amount?: number;
};

type MatchReceiptPayload = SignedBiopayTokenPayload & {
  requester_user_id?: unknown;
  profile_public_id?: unknown;
  score?: unknown;
};

type ProfileRow = {
  id: string;
  club_id: number | null;
  recipient_value: string;
  route_type: string;
  display_name: string | null;
  public_id: string;
  country_code: string | null;
};

type IntentRow = {
  id: string;
  nonce: string;
  payment_code: string;
  payment_method: string;
  expires_at: string;
  amount: number | null;
};

type AdminClientLike = ReturnType<typeof createAdminClient> | any;
type UserClientLike = {
  auth: {
    getUser(): Promise<{
      data: {
        user: { id: string } | null;
      };
      error: unknown;
    }>;
  };
};

export type BiopayCreatePaymentIntentDependencies = {
  createAdminClient: () => AdminClientLike;
  createUserClient: (authorization: string) => UserClientLike;
  requireAppCheckToken: (request: Request) => Promise<string>;
  verifyBiopayToken: (
    token: string,
    options: { expectedKind: string },
  ) => Promise<SignedBiopayTokenPayload>;
  resolvePaymentRouting: (
    adminClient: AdminClientLike,
    options: {
      clubId?: number | null;
      countryCode?: string | null;
      routeType?: string | null;
    },
  ) => Promise<BiopayPaymentRouting>;
  buildPaymentCode: (options: {
    paymentTemplate: string;
    routeType: string;
    recipientValue: string;
    amount?: number | null;
  }) => string;
  recordOperationalHealthEvent: (
    adminClient: AdminClientLike,
    event: Parameters<typeof recordOperationalHealthEvent>[1],
  ) => Promise<void>;
  recordEdgeFunctionFailure: (
    adminClient: AdminClientLike,
    options: Parameters<typeof recordEdgeFunctionFailure>[1],
  ) => Promise<void>;
  generateNonce: () => string;
  now: () => Date;
};

function generateNonce(): string {
  const bytes = new Uint8Array(24);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

const INTENT_TTL_SECONDS = 300;

const defaultDependencies: BiopayCreatePaymentIntentDependencies = {
  createAdminClient,
  createUserClient: (authorization) =>
    createUserClient(authorization) as unknown as UserClientLike,
  requireAppCheckToken,
  verifyBiopayToken,
  resolvePaymentRouting: resolveBiopayPaymentRouting,
  buildPaymentCode: buildBiopayPaymentCode,
  recordOperationalHealthEvent,
  recordEdgeFunctionFailure,
  generateNonce,
  now: () => new Date(),
};

export function createBiopayCreatePaymentIntentHandler(
  dependencies: Partial<BiopayCreatePaymentIntentDependencies> = {},
) {
  const deps: BiopayCreatePaymentIntentDependencies = {
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

      const body = await request.json() as CreateIntentRequest;
      const matchReceipt = body.match_receipt?.trim() ?? "";
      if (matchReceipt.length == 0) {
        return errorResponse("match_receipt is required.", 400);
      }
      const requestedAmount = typeof body.amount === "number" &&
          Number.isFinite(body.amount) && body.amount > 0
        ? Math.trunc(body.amount)
        : null;

      const receipt = await deps.verifyBiopayToken(matchReceipt, {
        expectedKind: "match_receipt",
      }) as MatchReceiptPayload;
      if (receipt.requester_user_id?.toString() != requesterUserId) {
        return errorResponse(
          "This BioPay match receipt does not belong to the current user.",
          403,
        );
      }

      const profilePublicId = receipt.profile_public_id?.toString() ?? "";
      const matchScore = Number(receipt.score ?? 0);

      const { data: profile, error: profileError } = await adminClient
        .from("biopay_profiles")
        .select(
          "id, user_id, club_id, recipient_value, route_type, display_name, public_id, country_code",
        )
        .eq("public_id", profilePublicId)
        .eq("active", true)
        .maybeSingle();

      if (profileError || !profile) {
        return errorResponse("BioPay profile not found or inactive.", 404);
      }

      await adminClient
        .from("biopay_payment_intents")
        .update({ status: "cancelled" })
        .eq("user_id", requesterUserId)
        .eq("status", "pending");

      const paymentRouting = await deps.resolvePaymentRouting(adminClient, {
        clubId: profile.club_id,
        countryCode: profile.country_code,
        routeType: profile.route_type,
      });
      const paymentCode = deps.buildPaymentCode({
        paymentTemplate: paymentRouting.paymentTemplate,
        routeType: profile.route_type,
        recipientValue: profile.recipient_value,
        amount: requestedAmount,
      });
      const nonce = deps.generateNonce();
      const now = deps.now();
      const expiresAt = new Date(
        now.getTime() + INTENT_TTL_SECONDS * 1000,
      ).toISOString();

      const { data: intent, error: insertError } = await adminClient
        .from("biopay_payment_intents")
        .insert({
          user_id: requesterUserId,
          club_id: profile.club_id,
          profile_id: profile.id,
          match_score: matchScore,
          recipient_value: profile.recipient_value,
          route_type: profile.route_type,
          payment_code: paymentCode,
          payment_method: paymentRouting.paymentMethod,
          amount: requestedAmount,
          nonce,
          status: "pending",
          expires_at: expiresAt,
        })
        .select("id, nonce, payment_code, payment_method, expires_at, amount")
        .single();

      if (insertError || !intent) {
        throw insertError ?? new Error("Failed to create payment intent.");
      }

      await deps.recordOperationalHealthEvent(adminClient, {
        service: "biopay",
        component: "payment_intent",
        status: "ok",
        severity: "info",
        message: "Payment intent created.",
        functionName: "biopay-create-payment-intent",
        userId: requesterUserId,
        subjectType: "biopay_payment_intent",
        subjectId: intent.id,
        metadata: {
          profile_public_id: profilePublicId,
          nonce,
          expires_at: expiresAt,
          amount: requestedAmount,
          match_receipt_exp: receipt.exp ?? null,
        },
      });

      return jsonResponse({
        success: true,
        data: {
          intent_id: intent.id,
          nonce: intent.nonce,
          ussd_code: intent.payment_code,
          payment_code: intent.payment_code,
          expires_at: intent.expires_at,
          amount: intent.amount,
          display_name: profile.display_name,
          public_id: profile.public_id,
          recipient_value: profile.recipient_value,
          route_type: profile.route_type,
          country_code: paymentRouting.countryCode,
          currency_code: paymentRouting.currencyCode,
          currency_symbol: paymentRouting.currencySymbol,
          payment_method: intent.payment_method,
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
        functionName: "biopay-create-payment-intent",
        error,
        issueCode: "biopay_create_intent_failed",
        userId: requesterUserId,
      });
      return errorResponse(
        error instanceof Error
          ? error.message
          : "Payment intent creation failed.",
        400,
      );
    }
  };
}

if (import.meta.main) {
  Deno.serve(createBiopayCreatePaymentIntentHandler());
}

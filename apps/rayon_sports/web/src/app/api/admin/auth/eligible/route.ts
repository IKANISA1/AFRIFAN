import type { NextRequest } from "next/server";
import { normalizeAdminPhone } from "@/lib/admin-auth";
import { findEligibleAdminPhoneCandidate } from "@/lib/admin-phone-access";
import {
  controlledApiFailureResponse,
  controlledApiJson,
  withControlledApiTimeout,
} from "@/lib/controlled-api-response";
import { rejectInsecureMutation, rejectRateLimitedRequest } from "@/lib/security";
import { getAdminSupabase } from "@/lib/supabase/admin";
import { getServerSupabase } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  const rejectedOrigin = rejectInsecureMutation(request);
  if (rejectedOrigin) {
    return rejectedOrigin;
  }

  const rejectedLimit = await rejectRateLimitedRequest(
    request,
    "admin-auth-eligible",
    12,
    60_000,
  );
  if (rejectedLimit) {
    return rejectedLimit;
  }

  try {
    const payload = (await request.json().catch(() => ({}))) as {
      phone?: unknown;
    };
    const phone = normalizeAdminPhone(String(payload.phone ?? ""));
    const adminClient = getAdminSupabase();
    if (adminClient == null) {
      throw new Error("Admin access verification is unavailable.");
    }
    const candidate = await withControlledApiTimeout(
      findEligibleAdminPhoneCandidate(adminClient, phone),
    );

    if (candidate != null) {
      const serverClient = await withControlledApiTimeout(getServerSupabase());
      if (serverClient == null) {
        throw new Error("Admin OTP delivery is unavailable.");
      }
      const { error: authError } = await withControlledApiTimeout(
        serverClient.auth.signInWithOtp({
          phone,
          options: {
            shouldCreateUser: false,
            channel: "whatsapp",
          },
        }),
      );
      if (authError) {
        throw authError;
      }
    }

    // Deliberately identical for approved and unapproved phones to prevent
    // unauthenticated enumeration of the admin allowlist.
    return controlledApiJson(
      {
        code: "ADMIN_OTP_REQUEST_ACCEPTED",
        accepted: true,
        message:
          "If this phone is approved, a verification code will arrive shortly.",
      },
      202,
    );
  } catch (error) {
    if (
      error instanceof Error &&
      (error.message === "Enter the admin phone number." ||
        error.message === "Use a valid phone number in international format.")
    ) {
      return controlledApiJson(
        {
          code: "ADMIN_OTP_EMPTY",
          error: error.message,
        },
        400,
      );
    }
    return controlledApiFailureResponse(error, "ADMIN_OTP");
  }
}

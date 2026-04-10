import { NextRequest, NextResponse } from "next/server";
import {
  adminPhoneAccessDeniedMessage,
  normalizeAdminPhone,
} from "@/lib/admin-auth";
import { findEligibleAdminPhoneCandidate } from "@/lib/admin-phone-access";
import { rejectInsecureMutation, rejectRateLimitedRequest } from "@/lib/security";
import { getAdminSupabase } from "@/lib/supabase/admin";

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

  const adminClient = getAdminSupabase();
  if (adminClient == null) {
    return NextResponse.json(
      { error: "Server admin client is not configured." },
      { status: 500 },
    );
  }

  try {
    const payload = (await request.json().catch(() => ({}))) as {
      phone?: unknown;
    };
    const phone = normalizeAdminPhone(String(payload.phone ?? ""));
    const candidate = await findEligibleAdminPhoneCandidate(adminClient, phone);

    if (candidate == null) {
      return NextResponse.json(
        { error: adminPhoneAccessDeniedMessage() },
        { status: 403 },
      );
    }

    return NextResponse.json({
      data: {
        ok: true,
        phone: candidate.phone,
      },
    });
  } catch (error) {
    return NextResponse.json(
      {
        error:
          error instanceof Error ? error.message : "Could not verify admin phone access.",
      },
      { status: 400 },
    );
  }
}
